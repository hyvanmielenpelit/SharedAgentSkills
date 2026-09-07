#!/usr/bin/env node
/*
 * claude-budget.js - estimate remaining Claude plan headroom from local transcripts,
 * separately for each subscription the desktop app signs into.
 *
 * Every Claude subscription (organization) carries its own rate-limit window, so a
 * blended figure across both is wrong for either. Sessions are attributed to an
 * organization through the bridge-session records the desktop app writes into each
 * transcript; subagent transcripts repeat their parent's sessionId and resolve through
 * the same map.
 *
 * The /usage panel reports a percentage but not the token capacity behind it. This
 * script measures absolute consumption locally and uses one pasted /usage percentage
 * per subscription to calibrate that percentage to a scale.
 *
 *   node claude-budget.js orgs
 *   node claude-budget.js calibrate --pct 80
 *   node claude-budget.js calibrate --pct 40 --org team --limit weekly --reset 2026-09-11T09:00:00Z
 *   node claude-budget.js check --stop 90
 *   node claude-budget.js status --stdin-hook
 *   node claude-budget.js raw --hours 24
 *
 * Exit code 1 when usage is at or past --stop, so it can gate a loop. 'status' never
 * exits nonzero, so it is safe to wire into a hook.
 */

const fs = require("fs");
const os = require("os");
const path = require("path");

const HOME = os.homedir();
const PROJECTS = path.join(HOME, ".claude", "projects");
const STATE = path.join(HOME, ".claude", "usage-budget.json");
const CONFIG = path.join(HOME, ".claude.json");

/* Relative cost of each token class against a plain input token. These are an
   assumption, not published values; calibration absorbs the error as long as the
   workload mix stays roughly constant. */
const WEIGHTS = { input: 1, cacheRead: 0.1, cacheWrite: 2, output: 5 };

/* Rate-limit tracks a plan enforces. Each is calibrated separately.

   'rolling' says how the window is placed. The five-hour one opens at the first request
   after the previous closed, so it is derived from local activity - checked against four
   resets the API reported, it matches all four. The weekly one does not behave that way:
   a reported weekly reset landed on a fixed wall-clock hour that no activity-derived
   window predicts, so it is carried forward from a known anchor instead of guessed at. */
const LIMITS = {
    five_hour: { hours: 5, title: "5h window", rolling: true },
    seven_day: { hours: 168, title: "weekly window", rolling: false }
};

const LIMIT_ALIASES = {
    "5h": "five_hour", "five_hour": "five_hour", "session": "five_hour", "hourly": "five_hour",
    "7d": "seven_day", "seven_day": "seven_day", "week": "seven_day", "weekly": "seven_day"
};

/* Friendly names for the organizationType the profile reports. */
const PLAN_LABELS = {
    claude_pro: "Pro",
    claude_max: "Max",
    claude_team: "Team",
    claude_enterprise: "Enterprise",
    claude_free: "Free"
};

function parseArgs(argv)
{
    const out = { _: [] };
    for (let i = 0; i < argv.length; i++)
    {
        if (argv[i].indexOf("--") === 0)
        {
            const next = argv[i + 1];
            out[argv[i].slice(2)] = (next && next.indexOf("--") !== 0) ? argv[++i] : true;
        }
        else
        {
            out._.push(argv[i]);
        }
    }
    return out;
}

function opt(a, key)
{
    return (a[key] !== undefined && a[key] !== true) ? String(a[key]) : null;
}

function limitKey(v)
{
    if (v === undefined || v === true)
        return "five_hour";
    const k = LIMIT_ALIASES[String(v).toLowerCase()];
    if (!k)
    {
        console.error("Unknown --limit '" + v + "'. Use five_hour (5h) or seven_day (weekly).");
        process.exit(2);
    }
    return k;
}

function readJson(file)
{
    try { return JSON.parse(fs.readFileSync(file, "utf8")); }
    catch (e) { return null; }
}

/* The profile block of ~/.claude.json describes only the subscription the app is signed
   into right now, so it is a naming source and a last-resort fallback - not the
   authority on which subscription paid for any given request. */
function activeProfile()
{
    const cfg = readJson(CONFIG);
    const acct = cfg && cfg.oauthAccount;
    if (!acct || !acct.organizationUuid)
        return null;
    return {
        org: acct.organizationUuid,
        type: acct.organizationType || null,
        name: acct.organizationName || null
    };
}

function transcripts()
{
    const found = [];
    if (!fs.existsSync(PROJECTS))
        return found;
    walk(PROJECTS);
    return found;

    function walk(dir)
    {
        let entries;
        try { entries = fs.readdirSync(dir, { withFileTypes: true }); }
        catch (e) { return; }
        for (let i = 0; i < entries.length; i++)
        {
            const e = entries[i];
            const p = path.join(dir, e.name);
            if (e.isDirectory())
            {
                walk(p);
            }
            else if (e.name.slice(-6) === ".jsonl")
            {
                try { found.push({ path: p, mtimeMs: fs.statSync(p).mtimeMs }); }
                catch (e2) { /* file vanished mid-scan */ }
            }
        }
    }
}

let INDEX = null;

/* Session-to-subscription map, built from the bridge-session records the desktop app
   writes. Also collects the resets the API reported when it rejected a request, which
   anchor each window exactly and remove the need to type one in. */
function index()
{
    if (INDEX)
        return INDEX;

    const orgBySession = {};
    const lastSeen = {};
    const quota = {};
    const times = {};
    const files = transcripts();

    for (let f = 0; f < files.length; f++)
    {
        let text;
        try { text = fs.readFileSync(files[f].path, "utf8"); }
        catch (e) { continue; }
        const lines = text.split(/\r?\n/);
        for (let l = 0; l < lines.length; l++)
        {
            const line = lines[l];
            if (!line)
                continue;
            const marker = line.indexOf("ownerOrganizationUuid") !== -1 || line.indexOf("quotaLimits") !== -1;
            if (!marker && line.indexOf("\"usage\"") === -1)
                continue;
            let rec;
            try { rec = JSON.parse(line); }
            catch (e) { continue; }
            if (rec.sessionId && rec.ownerOrganizationUuid)
            {
                orgBySession[rec.sessionId] = rec.ownerOrganizationUuid;
                const ts = rec.timestamp ? Date.parse(rec.timestamp) : files[f].mtimeMs;
                if (!lastSeen[rec.ownerOrganizationUuid] || ts > lastSeen[rec.ownerOrganizationUuid])
                    lastSeen[rec.ownerOrganizationUuid] = ts;
            }
            if (rec.type === "assistant" && rec.message && rec.message.usage && rec.timestamp && rec.sessionId)
            {
                times[rec.sessionId] = times[rec.sessionId] || [];
                times[rec.sessionId].push(Date.parse(rec.timestamp));
            }
            if (rec.quotaLimits && rec.quotaLimits.resetsAt && rec.sessionId)
            {
                quota[rec.sessionId] = quota[rec.sessionId] || [];
                quota[rec.sessionId].push({
                    at: rec.timestamp ? Date.parse(rec.timestamp) : files[f].mtimeMs,
                    resetsAt: rec.quotaLimits.resetsAt * 1000,
                    type: rec.quotaLimits.rateLimitType || "five_hour"
                });
            }
        }
    }

    /* Fold the per-session rejections into per-subscription, per-limit anchors. Every
       event is kept: each is an independent capacity observation, and their spread is
       what says how far any one of them can be trusted. */
    const resets = {};
    const events = {};
    const sessions = Object.keys(quota);
    for (let i = 0; i < sessions.length; i++)
    {
        const org = orgBySession[sessions[i]];
        if (!org)
            continue;
        const list = quota[sessions[i]];
        for (let j = 0; j < list.length; j++)
        {
            const e = list[j];
            const key = LIMIT_ALIASES[e.type] || e.type;
            if (!LIMITS[key])
                continue;
            resets[org] = resets[org] || {};
            if (!resets[org][key] || e.at > resets[org][key].at)
                resets[org][key] = e;
            events[org] = events[org] || {};
            events[org][key] = events[org][key] || {};
            /* One rejection per window; the earliest is the moment the limit was reached. */
            const w = String(e.resetsAt);
            if (!events[org][key][w] || e.at < events[org][key][w].at)
                events[org][key][w] = e;
        }
    }

    INDEX = { orgBySession: orgBySession, lastSeen: lastSeen, resets: resets, events: events, times: times, files: files };
    return INDEX;
}

function units(u)
{
    const i = u.input !== undefined ? u.input : (u.input_tokens || 0);
    const o = u.output !== undefined ? u.output : (u.output_tokens || 0);
    const r = u.cacheRead !== undefined ? u.cacheRead : (u.cache_read_input_tokens || 0);
    const w = u.cacheWrite !== undefined ? u.cacheWrite : (u.cache_creation_input_tokens || 0);
    return i * WEIGHTS.input + o * WEIGHTS.output + r * WEIGHTS.cacheRead + w * WEIGHTS.cacheWrite;
}

function emptyBucket()
{
    return {
        total: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, requests: 0 },
        bySession: {},
        units: 0
    };
}

const TALLIES = {};

/* Sum every billed request at or after sinceMs, split by owning subscription.

   Each requestId is counted ONCE. A single billed request is written to the transcript
   several times over - once per content block of the response - and the desktop app
   mirrors an entire session into a second transcript file under its own sessionId, so
   the same request can appear four or six times. Every copy carries identical usage
   totals, which is what identifies them as copies rather than as separate charges.
   Counting them raw inflated consumption several-fold.

   Consumption from a session with no bridge-session record lands in 'unattributed'.
   Results are memoised because one 'check' asks for the same spans repeatedly.
   untilMs bounds the span at the top, which a closed historical window needs. */
function tally(sinceMs, untilMs)
{
    const cacheKey = sinceMs + ":" + (untilMs === undefined ? "" : untilMs);
    if (TALLIES[cacheKey])
        return TALLIES[cacheKey];

    const idx = index();
    const byOrg = {};
    const seen = {};
    let unattributed = 0;
    let unattributedRequests = 0;
    let duplicates = 0;

    for (let f = 0; f < idx.files.length; f++)
    {
        if (idx.files[f].mtimeMs < sinceMs)
            continue;
        let text;
        try { text = fs.readFileSync(idx.files[f].path, "utf8"); }
        catch (e) { continue; }
        const key = path.basename(idx.files[f].path, ".jsonl").slice(0, 8);
        const lines = text.split(/\r?\n/);
        for (let l = 0; l < lines.length; l++)
        {
            const line = lines[l];
            if (!line || line.indexOf("\"usage\"") === -1)
                continue;
            let rec;
            try { rec = JSON.parse(line); }
            catch (e) { continue; }
            if (rec.type !== "assistant" || !rec.message || !rec.message.usage || !rec.timestamp)
                continue;
            const ts = Date.parse(rec.timestamp);
            if (ts < sinceMs || (untilMs !== undefined && ts > untilMs))
                continue;

            const id = rec.requestId || (rec.message && rec.message.id) || rec.uuid;
            if (id)
            {
                if (seen[id]) { duplicates++; continue; }
                seen[id] = true;
            }

            const u = rec.message.usage;
            const n = units(u);
            const org = idx.orgBySession[rec.sessionId];
            if (!org)
            {
                unattributed += n;
                unattributedRequests++;
                continue;
            }
            const b = byOrg[org] = byOrg[org] || emptyBucket();
            b.total.requests++;
            b.total.input += u.input_tokens || 0;
            b.total.output += u.output_tokens || 0;
            b.total.cacheRead += u.cache_read_input_tokens || 0;
            b.total.cacheWrite += u.cache_creation_input_tokens || 0;
            b.units += n;
            b.bySession[key] = (b.bySession[key] || 0) + n;
        }
    }
    TALLIES[cacheKey] = { byOrg: byOrg, unattributed: unattributed, unattributedRequests: unattributedRequests, duplicates: duplicates };
    return TALLIES[cacheKey];
}

function orgTally(t, org)
{
    return t.byOrg[org] || emptyBucket();
}

const TIMES = {};

/* Every billed request time for one subscription, ascending. */
function requestTimes(org)
{
    if (TIMES[org])
        return TIMES[org];
    const idx = index();
    const out = [];
    const sessions = Object.keys(idx.times);
    for (let i = 0; i < sessions.length; i++)
    {
        if (idx.orgBySession[sessions[i]] !== org)
            continue;
        const list = idx.times[sessions[i]];
        for (let j = 0; j < list.length; j++)
            out.push(list[j]);
    }
    out.sort(function (x, y) { return x - y; });
    TIMES[org] = out;
    return out;
}

/* A window opens on the first request made after the previous one closed, and runs for
   the limit's span. It is NOT a fixed grid: after an idle stretch longer than the span,
   the next request opens a fresh window wherever it falls. Checked against the resets the
   API itself reported, this model predicts each one to within ten minutes, whereas a
   fixed grid agrees only for as long as usage stays continuous.

   Any gap of a full span resets the phase, so the walk starts at the most recent such gap
   and nothing earlier can affect the answer. */
function windowFor(org, limit, nowMs)
{
    if (!LIMITS[limit].rolling)
        return null;

    const span = LIMITS[limit].hours * 3600000;
    const ts = requestTimes(org);
    if (!ts.length)
        return null;

    let from = 0;
    for (let i = ts.length - 1; i > 0; i--)
    {
        if (ts[i] - ts[i - 1] >= span) { from = i; break; }
    }

    let open = ts[from];
    for (let i = from; i < ts.length; i++)
    {
        if (ts[i] >= open + span)
            open = ts[i];
    }

    /* Every reset the API has reported sits on a ten-minute boundary, and the first
       request of a window always follows the window's true opening by a few seconds.
       Flooring recovers the real boundary: four observed resets, four matches. */
    const GRAIN = 600000;
    open = Math.floor(open / GRAIN) * GRAIN;
    const close = open + span;

    /* An observed rejection is the API's own word for where a window ends; prefer it
       whenever it belongs to the window just derived. */
    const idx = index();
    const byWindow = (idx.events[org] && idx.events[org][limit]) || {};
    const windows = Object.keys(byWindow);
    for (let i = 0; i < windows.length; i++)
    {
        const r = byWindow[windows[i]].resetsAt;
        if (Math.abs(r - close) < span / 2)
            return { start: r - span, reset: r, source: "observed reset", open: open };
    }

    if (nowMs >= close)
        return { start: close, reset: null, source: "idle - no window open", open: null };
    return { start: open, reset: close, source: "derived from local activity", open: open };
}

/* Fallback for a subscription with no local activity at all: roll a stored anchor forward
   on a fixed grid, which is the most that can be said without evidence. */
function windowStart(resetISO, windowHours, nowMs)
{
    const span = windowHours * 3600 * 1000;
    let reset = Date.parse(resetISO);
    while (reset <= nowMs) reset += span;
    while (reset - span > nowMs) reset -= span;
    return { start: reset - span, reset: reset };
}

function loadState()
{
    const raw = readJson(STATE);
    if (!raw)
        return { version: 2, weights: WEIGHTS, orgs: {}, defaultOrg: null };

    /* A version-1 file held a single flat calibration with no notion of which
       subscription it described; adopt it for whichever one is signed in now. */
    if (!raw.version && raw.capacityUnits)
    {
        const p = activeProfile();
        const migrated = { version: 2, weights: raw.weights || WEIGHTS, orgs: {}, defaultOrg: null };
        if (p)
        {
            migrated.orgs[p.org] = {
                label: null, type: p.type, name: p.name, seenAt: new Date().toISOString(),
                limits: {
                    five_hour: {
                        windowHours: raw.windowHours || 5,
                        reset: raw.reset,
                        capacityUnits: raw.capacityUnits,
                        calibratedAt: raw.calibratedAt,
                        calibratedPct: raw.calibratedPct,
                        unitsAtCalibration: raw.unitsAtCalibration
                    }
                }
            };
            migrated.defaultOrg = p.org;
        }
        return migrated;
    }
    raw.orgs = raw.orgs || {};
    return raw;
}

function saveState(state)
{
    fs.writeFileSync(STATE, JSON.stringify(state, null, 2) + "\n", "utf8");
}

/* Records what the profile knows about the subscription signed in right now, so a later
   run can still name it after the user has switched to the other one. */
function rememberProfile(state)
{
    const p = activeProfile();
    if (!p)
        return state;
    const e = state.orgs[p.org] = state.orgs[p.org] || { label: null, limits: {} };
    e.type = p.type || e.type || null;
    e.name = p.name || e.name || null;
    e.seenAt = new Date().toISOString();
    if (!state.defaultOrg)
        state.defaultOrg = p.org;
    return state;
}

function orgLabel(state, org)
{
    const e = state.orgs[org];
    if (e && e.label)
        return e.label;
    if (e && e.type && PLAN_LABELS[e.type])
        return PLAN_LABELS[e.type];
    return org.slice(0, 8);
}

function orgDisplay(state, org)
{
    const e = state.orgs[org] || {};
    const label = orgLabel(state, org);
    const plan = e.type && PLAN_LABELS[e.type] ? PLAN_LABELS[e.type] : null;
    return (plan && plan !== label ? label + " / " + plan : label) + " [" + org.slice(0, 8) + "]";
}

function knownOrgs(state)
{
    const idx = index();
    const set = {};
    Object.keys(state.orgs).forEach(function (o) { set[o] = true; });
    Object.keys(idx.orgBySession).forEach(function (s) { set[idx.orgBySession[s]] = true; });
    return Object.keys(set);
}

/* Resolves a --org selector against a uuid prefix, a label prefix, or a plan type. */
function matchOrg(state, sel)
{
    const wanted = String(sel).toLowerCase();
    const hits = knownOrgs(state).filter(function (o)
    {
        return o.toLowerCase().indexOf(wanted) === 0
            || orgLabel(state, o).toLowerCase().indexOf(wanted) === 0
            || (state.orgs[o] && String(state.orgs[o].type).toLowerCase() === wanted);
    });
    if (hits.length === 1)
        return hits[0];
    if (hits.length > 1)
    {
        console.error("'" + sel + "' matches " + hits.length + " subscriptions: "
            + hits.map(function (o) { return orgDisplay(state, o); }).join(", "));
        process.exit(2);
    }
    console.error("No subscription matches '" + sel + "'. Run 'orgs' to list what is known.");
    process.exit(2);
}

/* Hook payloads arrive on stdin as JSON; transcript_path identifies the calling session
   exactly, which is the only fully reliable way to know which subscription is paying. */
function readHookStdin()
{
    try
    {
        const j = JSON.parse(fs.readFileSync(0, "utf8"));
        return {
            transcript: j.transcript_path || j.transcriptPath || null,
            session: j.session_id || j.sessionId || null
        };
    }
    catch (e) { return { transcript: null, session: null }; }
}

function sessionIdFromTranscript(file)
{
    const idx = index();
    let text;
    try { text = fs.readFileSync(file, "utf8"); }
    catch (e) { return path.basename(file, ".jsonl"); }
    const lines = text.split(/\r?\n/);
    for (let i = 0; i < lines.length; i++)
    {
        if (!lines[i])
            continue;
        let rec;
        try { rec = JSON.parse(lines[i]); }
        catch (e) { continue; }
        if (rec.sessionId && (rec.ownerOrganizationUuid || idx.orgBySession[rec.sessionId]))
            return rec.sessionId;
    }
    return path.basename(file, ".jsonl");
}

/* Which subscription this run is about, in descending order of trust: an explicit
   selector, the session the caller names, the session that ran most recently, and
   finally whichever subscription the app profile is signed into. */
function resolveOrg(a, state)
{
    const idx = index();

    const sel = opt(a, "org");
    if (sel && sel.toLowerCase() !== "auto")
        return { org: matchOrg(state, sel), how: "--org" };

    let session = opt(a, "session");
    let transcript = opt(a, "transcript");
    if (a["stdin-hook"])
    {
        const h = readHookStdin();
        transcript = transcript || h.transcript;
        session = session || h.session;
    }
    if (transcript && !session)
        session = sessionIdFromTranscript(transcript);
    if (session && idx.orgBySession[session])
        return { org: idx.orgBySession[session], how: "session " + session.slice(0, 8) };

    const seen = Object.keys(idx.lastSeen);
    if (seen.length)
    {
        seen.sort(function (x, y) { return idx.lastSeen[y] - idx.lastSeen[x]; });
        return { org: seen[0], how: "most recent session" };
    }

    const p = activeProfile();
    if (p)
        return { org: p.org, how: "signed-in profile" };

    if (state.defaultOrg)
        return { org: state.defaultOrg, how: "last calibrated subscription" };

    return { org: null, how: "unresolved" };
}

/* Hints are meant to be pasted, and the script is normally invoked by absolute path from
   somewhere else entirely, so quote the path this process was actually started from. */
function invocation()
{
    const p = process.argv[1] || "claude-budget.js";
    return "node " + (p.indexOf(" ") === -1 ? p : "\"" + p + "\"");
}

function n(x)
{
    return Math.round(x).toLocaleString("en-US");
}

function compact(x)
{
    if (x >= 1e9) return (x / 1e9).toFixed(2) + "B";
    if (x >= 1e6) return (x / 1e6).toFixed(1) + "M";
    if (x >= 1e3) return (x / 1e3).toFixed(0) + "k";
    return String(Math.round(x));
}

function pct(x)
{
    return x.toFixed(1) + "%";
}

function human(ms)
{
    if (!isFinite(ms))
        return "never";
    if (ms < 0)
        return "now";
    const h = Math.floor(ms / 3600000);
    const m = Math.round((ms % 3600000) / 60000);
    return h ? h + "h " + m + "m" : m + "m";
}

/* The reset the API itself reported when it last rejected a request beats anything the
   user types, and it needs no pasting at all once a limit has been hit once. */
function knownReset(state, org, limit)
{
    const idx = index();
    const observed = idx.resets[org] && idx.resets[org][limit];
    if (observed)
        return { iso: new Date(observed.resetsAt).toISOString(), source: "observed rate-limit reset" };
    const stored = limitState(state, org, limit);
    if (stored && stored.reset)
        return { iso: stored.reset, source: "stored calibration" };
    return null;
}

/* Each rejection implies a capacity: the window was full at that instant, so whatever was
   billed in that window up to it is roughly what the window holds. Two cautions make this
   an approximation rather than a reading. Any overage credits spent in a window inflate
   its figure above the base allowance, and the weights that price a cache read against an
   output token are an assumption, so a window of unusual workload mix prices differently.
   Taking the minimum keeps the estimate on the conservative side of both. */
function impliedCapacities(org, limit)
{
    const idx = index();
    const byWindow = (idx.events[org] && idx.events[org][limit]) || {};
    const hours = LIMITS[limit].hours;
    const out = [];
    const windows = Object.keys(byWindow);
    for (let i = 0; i < windows.length; i++)
    {
        const e = byWindow[windows[i]];
        const start = e.resetsAt - hours * 3600000;
        const b = orgTally(tally(start, e.at), org);
        if (b.units > 0)
            out.push({ at: e.at, resetsAt: e.resetsAt, units: b.units, requests: b.total.requests });
    }
    out.sort(function (x, y) { return x.at - y.at; });
    return out;
}

const MONTHS = {
    jan: 0, feb: 1, mar: 2, apr: 3, may: 4, jun: 5,
    jul: 6, aug: 7, sep: 8, oct: 9, nov: 10, dec: 11
};

/* Anthropic occasionally raises a limit for a period and the client caches a notice for
   it. Reading that notice means a promotional capacity can be recognised as temporary
   without anyone having to spot the banner and say so.

   This is an undocumented internal cache: the key may be renamed or restructured at any
   time, so everything here is best-effort and absent notices are normal, not an error.
   The cache is also a single blob for whichever subscription was last signed in, so a
   notice cannot be attributed to one subscription - it is reported, never assumed. */
function promoNotices()
{
    const cfg = readJson(CONFIG);
    const raw = cfg && cfg.cachedGrowthBookFeatures
        && cfg.cachedGrowthBookFeatures.tengu_rate_limit_promo_notices;
    if (!Array.isArray(raw))
        return [];
    const out = [];
    for (let i = 0; i < raw.length; i++)
    {
        const text = raw[i] && typeof raw[i].text === "string" ? raw[i].text : null;
        if (!text)
            continue;
        const bar = LIMIT_ALIASES[String(raw[i].bar || "").toLowerCase()] || null;
        out.push({ limit: bar, text: text, endsAt: promoEnd(text) });
    }
    return out;
}

/* The end date is free text ('... through Sep 13') with no year and no timezone. Take the
   month and day, assume the year that puts it nearest to now, and treat the promotion as
   ending when that day ends in UTC. Returns null when nothing parses - a promotion with
   no readable end is still worth reporting, just not worth acting on. */
function promoEnd(text)
{
    const m = /through\s+([A-Za-z]{3})[a-z]*\s+(\d{1,2})/.exec(text);
    if (!m)
        return null;
    const mon = MONTHS[m[1].toLowerCase()];
    if (mon === undefined)
        return null;
    const day = parseInt(m[2], 10);
    const now = new Date();
    let year = now.getUTCFullYear();
    let end = Date.UTC(year, mon, day + 1);
    /* A date far behind us means the notice names next year's occurrence, and vice versa. */
    const half = 183 * 86400000;
    if (end < now.getTime() - half) end = Date.UTC(year + 1, mon, day + 1);
    else if (end > now.getTime() + half) end = Date.UTC(year - 1, mon, day + 1);
    return new Date(end).toISOString();
}

function promoFor(limit)
{
    const all = promoNotices();
    for (let i = 0; i < all.length; i++)
        if (all[i].limit === limit)
            return all[i];
    return null;
}

function limitState(state, org, limit)
{
    const e = state.orgs[org];
    return (e && e.limits && e.limits[limit]) || null;
}

/* Everything 'check' and 'status' report about one subscription and one limit. */
function measure(state, org, limit, nowMs)
{
    const ls = limitState(state, org, limit);
    if (!ls)
        return null;
    const w = windowFor(org, limit, nowMs) || windowStart(ls.reset, ls.windowHours, nowMs);
    if (!w.source) w.source = "stored anchor, rolled forward";
    const t = orgTally(tally(w.start, w.reset === null ? nowMs : undefined), org);
    const remaining = ls.capacityUnits - t.units;
    const recent = orgTally(tally(nowMs - 15 * 60 * 1000), org);
    const perHour = recent.units * 4;
    /* A rejection is ground truth: the window was full. If the stored capacity disagrees
       badly with what the rejections imply, the calibration has drifted or the plan
       changed, and the percentage on screen is not to be trusted. */
    let drift = null;
    const seen = impliedCapacities(org, limit);
    if (seen.length)
    {
        const newest = seen[seen.length - 1];
        const ratio = newest.units / ls.capacityUnits;
        if (ratio < 0.75 || ratio > 1.25)
            drift = { impliedUnits: Math.round(newest.units), at: newest.at, ratio: Number(ratio.toFixed(2)) };
    }

    const expired = ls.expiresAt && Date.parse(ls.expiresAt) <= nowMs ? ls.expiresAt : null;

    return {
        limit: limit,
        window: w,
        expired: expired,
        idle: w.reset === null,
        tally: t,
        capacity: ls.capacityUnits,
        source: ls.source || "usage-reading",
        drift: drift,
        used: 100 * t.units / ls.capacityUnits,
        remaining: remaining,
        perHour: perHour,
        eta: perHour > 0 ? (remaining / perHour) * 3600 * 1000 : Infinity,
        calibratedAt: ls.calibratedAt
    };
}

/* ---------------------------------------------------------------- commands ---- */

function cmdOrgs()
{
    const state = rememberProfile(loadState());
    saveState(state);
    const idx = index();
    const p = activeProfile();
    const day = tally(Date.now() - 24 * 3600000);
    const orgs = knownOrgs(state);

    if (!orgs.length)
    {
        console.log("No subscription could be identified from the local transcripts.");
        console.log("Sessions are attributed through the bridge-session records the desktop app writes;");
        console.log("older transcripts predate them.");
        return;
    }

    console.log("Subscriptions seen locally:");
    console.log("");
    for (let i = 0; i < orgs.length; i++)
    {
        const o = orgs[i];
        const e = state.orgs[o] || {};
        const t = orgTally(day, o);
        console.log((p && p.org === o ? "* " : "  ") + orgDisplay(state, o));
        console.log("      uuid          " + o);
        if (e.name)
            console.log("      name          " + e.name);
        if (e.type)
            console.log("      plan          " + e.type);
        console.log("      last 24h      " + compact(t.units) + " units over " + t.total.requests + " requests");
        if (idx.lastSeen[o])
            console.log("      last active   " + new Date(idx.lastSeen[o]).toISOString().slice(0, 16).replace("T", " ") + "Z");
        const keys = Object.keys(LIMITS);
        for (let k = 0; k < keys.length; k++)
        {
            const ls = limitState(state, o, keys[k]);
            const r = knownReset(state, o, keys[k]);
            let how = "not calibrated";
            if (ls && ls.source === "observed-rejection")
                how = "approximated from " + ls.observations + " rejection(s) on "
                    + ls.calibratedAt.slice(0, 16).replace("T", " ") + "Z";
            else if (ls)
                how = "calibrated at " + pct(ls.calibratedPct) + " on "
                    + ls.calibratedAt.slice(0, 16).replace("T", " ") + "Z";
            console.log("      " + (LIMITS[keys[k]].title + "              ").slice(0, 14) + how
                + (r ? "   anchor " + r.iso.slice(0, 16).replace("T", " ") + "Z (" + r.source + ")" : ""));
        }
        console.log("");
    }
    console.log("* = signed in right now, per " + CONFIG);
    const notices = promoNotices();
    for (let i = 0; i < notices.length; i++)
        console.log("Promotion: " + notices[i].text
            + (notices[i].endsAt ? "  (read as ending " + notices[i].endsAt.slice(0, 10) + ")" : "  (no end date could be read)"));
    if (day.unattributed > 0)
        console.log("Unattributed in the last 24h: " + compact(day.unattributed) + " units over "
            + day.unattributedRequests + " requests (sessions with no bridge-session record).");
    console.log("");
    console.log("Name one with:  " + invocation() + " label --org <uuid-prefix> --name \"Team business\"");
}

function cmdLabel(a)
{
    const state = rememberProfile(loadState());
    const sel = opt(a, "org");
    const name = opt(a, "name");
    if (!sel || !name)
    {
        console.error("usage: label --org <uuid-prefix|label> --name \"<friendly name>\"");
        process.exit(2);
    }
    const org = matchOrg(state, sel);
    state.orgs[org] = state.orgs[org] || { limits: {} };
    state.orgs[org].label = name;
    saveState(state);
    console.log("Labelled " + org.slice(0, 8) + " as \"" + name + "\".");
}

function cmdCalibrate(a)
{
    const state = rememberProfile(loadState());
    const limit = limitKey(a.limit);
    const r = resolveOrg(a, state);
    if (!r.org)
    {
        console.error("Cannot tell which subscription to calibrate. Pass --org <uuid-prefix|label>.");
        process.exit(2);
    }
    if (a["from-limit"])
        return calibrateFromLimit(state, r, limit);

    if (opt(a, "pct") === null)
    {
        console.error("usage: calibrate --pct <0-100> [--org <sel>] [--limit five_hour|weekly] [--reset <ISO8601>] [--at <ISO8601>] [--window <hours>]");
        console.error("       calibrate --from-limit [--org <sel>] [--limit five_hour|weekly]");
        console.error("The percentage comes from the /usage panel while signed into that subscription.");
        console.error("--from-limit needs no reading, but only approximates the capacity - see below.");
        process.exit(2);
    }

    const percent = parseFloat(a.pct);
    const given = opt(a, "reset");
    const anchor = given ? { iso: given, source: "--reset" } : knownReset(state, r.org, limit);
    if (!anchor)
    {
        console.error("No reset time known for " + orgDisplay(state, r.org) + " (" + LIMITS[limit].title + ").");
        console.error("Pass --reset <ISO8601> with the reset time the /usage panel shows. It is picked up");
        console.error("automatically once the API has rejected a request for this subscription.");
        process.exit(2);
    }
    const windowHours = opt(a, "window") ? parseFloat(a.window) : LIMITS[limit].hours;
    const now = Date.now();
    const w = given
        ? windowStart(anchor.iso, windowHours, now)
        : (windowFor(r.org, limit, now) || windowStart(anchor.iso, windowHours, now));
    if (w.reset === null)
    {
        console.error("No window is open for " + orgDisplay(state, r.org) + " right now."
            + " The last one has closed, so there is no consumption to scale a percentage against.");
        process.exit(2);
    }
    const atRaw = opt(a, "at");
    let at = now;
    if (atRaw)
    {
        at = Date.parse(atRaw);
        if (isNaN(at))
        {
            console.error("Cannot parse --at '" + atRaw + "'. Use an ISO 8601 timestamp.");
            process.exit(2);
        }
    }
    const expRaw = opt(a, "expires");
    let expires = null;
    if (expRaw)
    {
        const e = Date.parse(expRaw);
        if (isNaN(e))
        {
            console.error("Cannot parse --expires '" + expRaw + "'. Use an ISO 8601 date.");
            process.exit(2);
        }
        expires = new Date(e).toISOString();
    }

    const promo = promoFor(limit);
    if (!expires && promo && promo.endsAt)
        expires = promo.endsAt;
    const t = orgTally(tally(w.start, at), r.org);

    if (!(percent > 0))
    {
        console.error("Cannot calibrate from " + a.pct + "% - no consumption to scale against.");
        process.exit(2);
    }
    if (t.units === 0)
    {
        console.error("No usage found for " + orgDisplay(state, r.org) + " in this window; nothing to calibrate against.");
        process.exit(2);
    }

    const capacity = t.units / (percent / 100);
    const e = state.orgs[r.org] = state.orgs[r.org] || { label: null, limits: {} };
    e.limits = e.limits || {};
    e.limits[limit] = {
        windowHours: windowHours,
        reset: new Date(w.reset).toISOString(),
        capacityUnits: Math.round(capacity),
        calibratedAt: new Date(now).toISOString(),
        calibratedPct: percent,
        unitsAtCalibration: Math.round(t.units),
        source: "usage-reading",
        expiresAt: expires,
        weights: WEIGHTS
    };
    state.defaultOrg = r.org;
    saveState(state);

    console.log("Calibrated " + orgDisplay(state, r.org) + "  (" + LIMITS[limit].title + ")");
    console.log("  subscription      resolved by " + r.how);
    console.log("  reported          " + pct(percent) + " as of " + new Date(at).toISOString()
        + (atRaw ? "  (--at)" : "  (now)"));
    console.log("  reset anchor      " + anchor.iso + "  (" + anchor.source + ")");
    console.log("  window start      " + new Date(w.start).toISOString() + "  (" + windowHours + "h window)");
    console.log("  measured locally  " + n(t.units) + " units over " + t.total.requests + " requests");
    console.log("  implied capacity  " + n(capacity) + " units per window");
    console.log("  headroom now      " + n(capacity - t.units) + " units (" + pct(100 - percent) + ")");
    if (promo)
        console.log("  promotion         " + promo.text);
    if (expires)
        console.log("  expires           " + expires
            + (expRaw ? "  (--expires)" : "  (from the promotion notice)")
            + "  - recalibrate after this, the allowance changes");
    if (promo && !promo.endsAt && !expRaw)
    {
        console.log("");
        console.log("A promotion is active on this limit but its end date could not be read from the");
        console.log("notice. Pass --expires <ISO> so the capacity is not treated as permanent.");
    }
    console.log("");
    console.log("Saved to " + STATE + " - run 'check' from here on.");
}

/* Calibration with no reading from the user, derived from windows the API actually
   rejected. Approximate by construction -- see impliedCapacities -- so it is recorded as
   such and every later report says so. */
function calibrateFromLimit(state, r, limit)
{
    const seen = impliedCapacities(r.org, limit);
    if (!seen.length)
    {
        console.error("No rate-limit rejection has been observed for " + orgDisplay(state, r.org)
            + " (" + LIMITS[limit].title + "), so there is nothing to derive a capacity from.");
        console.error("Open /usage while signed into it and calibrate with --pct instead.");
        process.exit(2);
    }

    let lo = seen[0].units, hi = seen[0].units;
    for (let i = 1; i < seen.length; i++)
    {
        if (seen[i].units < lo) lo = seen[i].units;
        if (seen[i].units > hi) hi = seen[i].units;
    }
    const spread = lo > 0 ? (hi - lo) / lo : 0;
    const latest = seen[seen.length - 1];
    const now = Date.now();
    const w = windowStart(new Date(latest.resetsAt).toISOString(), LIMITS[limit].hours, now);

    const e = state.orgs[r.org] = state.orgs[r.org] || { label: null, limits: {} };
    e.limits = e.limits || {};
    e.limits[limit] = {
        windowHours: LIMITS[limit].hours,
        reset: new Date(w.reset).toISOString(),
        capacityUnits: Math.round(lo),
        calibratedAt: new Date(now).toISOString(),
        calibratedPct: null,
        unitsAtCalibration: null,
        source: "observed-rejection",
        observations: seen.length,
        spread: Number(spread.toFixed(3)),
        weights: WEIGHTS
    };
    state.defaultOrg = r.org;
    saveState(state);

    console.log("Calibrated " + orgDisplay(state, r.org) + "  (" + LIMITS[limit].title + ")  APPROXIMATE");
    console.log("  subscription      resolved by " + r.how);
    console.log("  derived from      " + seen.length + " observed rate-limit rejection(s), no /usage reading");
    for (let i = 0; i < seen.length; i++)
        console.log("    " + new Date(seen[i].at).toISOString().slice(0, 16).replace("T", " ") + "Z  "
            + n(seen[i].units) + " units over " + seen[i].requests + " requests");
    console.log("  capacity taken    " + n(lo) + " units  (the lowest, deliberately)");
    if (seen.length > 1)
        console.log("  spread            " + pct(spread * 100) + " between highest and lowest");
    else
        console.log("  spread            unknown - a single observation cannot disagree with itself");
    console.log("");
    console.log("This is an estimate, not a reading. A window partly funded by extra-usage");
    console.log("credits reports more than the plan's own allowance, and the token weights are");
    console.log("an assumption. Sharpen it when you can:");
    console.log("  " + invocation() + " calibrate --pct <n> --org " + r.org.slice(0, 8));
    if (seen.length === 1)
    {
        console.log("");
        console.log("Only one rejection was observed, so nothing here contradicts it - which is not");
        console.log("the same as it being right. A single observation has been off by 40% or more in");
        console.log("practice. Get a reading before letting a stop decision rest on this.");
    }
    if (spread > 0.4)
    {
        console.log("");
        console.log("The observations disagree by " + pct(spread * 100) + ", too wide to plan against.");
        console.log("Treat the percentage as a rough bound only, and get a /usage reading");
        console.log("before relying on it to decide whether a step will fit.");
    }
}

function cmdCheck(a)
{
    const state = rememberProfile(loadState());
    saveState(state);
    const limit = limitKey(a.limit);
    const stop = opt(a, "stop") ? parseFloat(a.stop) : 90;
    const now = Date.now();
    const r = resolveOrg(a, state);

    if (!r.org)
        return fail("Cannot tell which subscription is active. Pass --org <uuid-prefix|label>.");

    const m = measure(state, r.org, limit, now);
    if (!m)
        return fail("No calibration for " + orgDisplay(state, r.org) + " (" + LIMITS[limit].title + ")."
            + " Open /usage while signed into it, then run: " + invocation() + " calibrate --pct <n> --org " + r.org.slice(0, 8)
            + (limit === "five_hour" ? "" : " --limit " + limit));

    if (a.json)
    {
        console.log(JSON.stringify({
            org: r.org,
            label: orgLabel(state, r.org),
            plan: (state.orgs[r.org] || {}).type || null,
            resolvedBy: r.how,
            limit: limit,
            windowOpen: !m.idle,
            windowSource: m.window.source,
            windowStart: m.idle ? null : new Date(m.window.start).toISOString(),
            resetsAt: m.idle ? null : new Date(m.window.reset).toISOString(),
            resetsInMs: m.idle ? null : m.window.reset - now,
            usedUnits: Math.round(m.tally.units),
            capacityUnits: m.capacity,
            calibrationSource: m.source,
            calibrationApproximate: m.source !== "usage-reading",
            calibrationDrift: m.drift,
            calibrationExpired: m.expired,
            usedPct: Number(m.used.toFixed(2)),
            remainingUnits: Math.round(m.remaining),
            requests: m.tally.total.requests,
            burnPerHour: Math.round(m.perHour),
            etaMs: isFinite(m.eta) ? Math.round(m.eta) : null,
            stopThreshold: stop,
            overThreshold: m.used >= stop
        }, null, 2));
        if (m.used >= stop)
            process.exit(1);
        return;
    }

    console.log("Plan     " + orgDisplay(state, r.org) + "   (resolved by " + r.how + ")");
    if (m.idle)
        console.log("Window   none open - the last " + LIMITS[limit].title + " has closed."
            + " A new one starts with the next request, at full headroom.");
    else
    {
        const wide = LIMITS[limit].hours > 24;
        const cut = wide ? 16 : 16;
        const from = new Date(m.window.start).toISOString();
        const to = new Date(m.window.reset).toISOString();
        console.log("Window   " + (wide ? from.slice(0, cut).replace("T", " ") : from.slice(11, 16)) + "Z -> "
            + (wide ? to.slice(0, cut).replace("T", " ") : to.slice(11, 16)) + "Z   " + LIMITS[limit].title
            + ", resets in " + human(m.window.reset - now)
            + "   (" + m.window.source + ")");
    }
    console.log("Used     " + n(m.tally.units) + " / " + n(m.capacity) + " units = " + pct(m.used)
        + "   over " + m.tally.total.requests + " requests"
        + (m.source === "observed-rejection" ? "   (capacity approximate)" : ""));
    console.log("Left     " + n(m.remaining) + " units");
    console.log("Burn     " + n(m.perHour) + " units/hour (last 15 min)"
        + (isFinite(m.eta) ? "  -> limit in " + human(m.eta) : "  -> idle"));

    if (m.expired)
        console.log("Expired  the allowance this was calibrated against ended " + m.expired.slice(0, 10)
            + " - the capacity below is out of date, recalibrate from a fresh reading");
    if (m.drift)
        console.log("Drift    a rejection on " + new Date(m.drift.at).toISOString().slice(0, 16).replace("T", " ")
            + "Z implies " + n(m.drift.impliedUnits) + " units, " + m.drift.ratio + "x the stored capacity"
            + " - recalibrate from a fresh /usage reading");

    const width = 40;
    const filled = Math.max(0, Math.min(width, Math.round(width * m.used / 100)));
    console.log("");
    console.log("[" + new Array(filled + 1).join("#") + new Array(width - filled + 1).join("-") + "] " + pct(m.used));

    const sessions = Object.keys(m.tally.bySession)
        .map(function (k) { return [k, m.tally.bySession[k]]; })
        .sort(function (x, y) { return y[1] - x[1]; });
    if (sessions.length > 1)
    {
        console.log("");
        console.log("By session this window:");
        for (let i = 0; i < Math.min(6, sessions.length); i++)
        {
            const row = sessions[i];
            console.log("  " + row[0] + "  " + n(row[1]) + "  (" + pct(100 * row[1] / m.tally.units) + ")");
        }
    }

    /* What the other subscription is doing, so a switch is an informed one. */
    const others = knownOrgs(state).filter(function (o) { return o !== r.org; });
    if (others.length)
    {
        console.log("");
        console.log("Other subscriptions, same limit:");
        for (let i = 0; i < others.length; i++)
        {
            const om = measure(state, others[i], limit, now);
            console.log("  " + orgDisplay(state, others[i]) + "  "
                + (!om ? "not calibrated"
                    : om.idle ? "idle, no window open"
                        : pct(om.used) + " used, resets in " + human(om.window.reset - now)));
        }
    }

    /* Rough coverage signal, now that each request is counted once. It should be in the
       same territory as what /usage reports rather than a multiple of it. */
    const day = tally(now - 24 * 3600000);
    console.log("");
    console.log("Billed requests seen locally for this subscription: " + orgTally(day, r.org).total.requests + " (24h).");
    if (day.unattributed > 0)
        console.log("Unattributed: " + compact(day.unattributed) + " units in 24h, charged to no subscription here.");
    if (day.duplicates)
        console.log("Ignored " + day.duplicates + " duplicate records of those requests"
            + " (mirrored transcripts and per-block repeats).");

    if (m.used >= stop)
    {
        console.log("");
        console.log("STOP: at or past the " + stop + "% threshold. Recalibrate with a fresh /usage before continuing.");
        process.exit(1);
    }
    console.log("");
    console.log("OK: under the " + stop + "% threshold.");

    function fail(msg)
    {
        if (a.json)
            console.log(JSON.stringify({ error: msg }, null, 2));
        else
            console.error(msg);
        process.exit(2);
    }
}

/* One line, safe to inject into an agent's context from a hook. Never exits nonzero:
   a quota probe must not be able to break the session it is advising. */
function cmdStatus(a)
{
    let state;
    try { state = rememberProfile(loadState()); }
    catch (e) { console.log("[quota] unavailable: " + e.message); return; }

    const now = Date.now();
    const r = resolveOrg(a, state);
    if (!r.org)
    {
        console.log("[quota] The active Claude subscription could not be identified from local transcripts.");
        return;
    }

    const who = orgDisplay(state, r.org);
    const parts = [];
    let uncalibrated = 0;
    let approximate = false;
    let lapsed = false;
    const keys = Object.keys(LIMITS);
    for (let i = 0; i < keys.length; i++)
    {
        const m = measure(state, r.org, keys[i], now);
        if (!m)
        {
            uncalibrated++;
            continue;
        }
        if (m.source === "observed-rejection")
            approximate = true;
        if (m.expired)
            lapsed = true;
        if (m.idle)
        {
            parts.push(LIMITS[keys[i]].title + " not open - full headroom until the next request");
            continue;
        }
        parts.push(LIMITS[keys[i]].title + " " + pct(m.used) + (m.source === "observed-rejection" ? "~" : "") + " used ("
            + compact(m.tally.units) + "/" + compact(m.capacity) + " units), resets in "
            + human(m.window.reset - now)
            + (isFinite(m.eta) && m.eta < m.window.reset - now
                ? ", exhausted in " + human(m.eta) + " at the current burn rate" : ""));
    }

    if (!parts.length)
    {
        console.log("[quota] Active subscription: " + who + " - not calibrated. Open /usage and run: "
            + invocation() + " calibrate --pct <n> --org " + r.org.slice(0, 8));
        return;
    }
    console.log("[quota] Active subscription: " + who + " - " + parts.join("; ") + "."
        + (approximate ? " Percentages marked ~ rest on a capacity estimated from past rate-limit"
            + " rejections, not a /usage reading." : ""));
    if (lapsed)
        console.log("[quota] A calibrated allowance has lapsed - the capacity behind one of those"
            + " figures is out of date. Recalibrate before relying on it.");
    const notices = promoNotices();
    for (let i = 0; i < notices.length; i++)
        console.log("[quota] Promotion in effect: " + notices[i].text
            + " (which subscription it applies to is not recorded locally).");
    if (uncalibrated)
        console.log("[quota] " + uncalibrated + " limit track(s) not yet calibrated for this subscription.");
}

/* --since exists so a step's true cost can be measured: note the time, run the step,
   then ask what has been billed since. --hours is the standing-back view. */
function cmdRaw(a)
{
    const state = rememberProfile(loadState());
    const since = opt(a, "since");
    let start, span;
    if (since)
    {
        start = Date.parse(since);
        if (isNaN(start))
        {
            console.error("Cannot parse --since '" + since + "'. Use an ISO 8601 timestamp.");
            process.exit(2);
        }
        span = "since " + new Date(start).toISOString();
    }
    else
    {
        const hours = opt(a, "hours") ? parseFloat(a.hours) : 24;
        start = Date.now() - hours * 3600000;
        span = "last " + hours + "h";
    }

    const t = tally(start);
    const orgs = Object.keys(t.byOrg).sort(function (x, y) { return t.byOrg[y].units - t.byOrg[x].units; });

    if (a.json)
    {
        const r = resolveOrg(a, state);
        if (!r.org)
        {
            console.log(JSON.stringify({ error: "Cannot tell which subscription to report. Pass --org <uuid-prefix|label>." }, null, 2));
            process.exit(2);
        }
        const b = orgTally(t, r.org);
        console.log(JSON.stringify({
            since: new Date(start).toISOString(),
            org: r.org,
            label: orgLabel(state, r.org),
            resolvedBy: r.how,
            units: Math.round(b.units),
            requests: b.total.requests,
            input: b.total.input,
            output: b.total.output,
            cacheRead: b.total.cacheRead,
            cacheWrite: b.total.cacheWrite,
            others: orgs.filter(function (o) { return o !== r.org; }).map(function (o)
            {
                return { org: o, label: orgLabel(state, o), units: Math.round(t.byOrg[o].units), requests: t.byOrg[o].total.requests };
            }),
            unattributedUnits: Math.round(t.unattributed)
        }, null, 2));
        return;
    }

    console.log(span.charAt(0).toUpperCase() + span.slice(1) + ", by subscription:");
    for (let i = 0; i < orgs.length; i++)
    {
        const b = t.byOrg[orgs[i]];
        console.log("");
        console.log("  " + orgDisplay(state, orgs[i]) + "   " + b.total.requests + " requests");
        console.log("    input        " + n(b.total.input));
        console.log("    output       " + n(b.total.output));
        console.log("    cache read   " + n(b.total.cacheRead));
        console.log("    cache write  " + n(b.total.cacheWrite));
        console.log("    effective    " + n(b.units) + " units");
    }
    if (t.unattributed > 0)
    {
        console.log("");
        console.log("  unattributed   " + n(t.unattributed) + " units over " + t.unattributedRequests + " requests");
        console.log("                 (sessions with no bridge-session record - typically older transcripts)");
    }
}

const a = parseArgs(process.argv.slice(2));
const cmd = a._[0];
if (cmd === "orgs")
    cmdOrgs(a);
else if (cmd === "label")
    cmdLabel(a);
else if (cmd === "calibrate")
    cmdCalibrate(a);
else if (cmd === "check")
    cmdCheck(a);
else if (cmd === "status")
    cmdStatus(a);
else if (cmd === "raw")
    cmdRaw(a);
else
{
    console.log("claude-budget.js - estimate Claude plan headroom per subscription, from local transcripts");
    console.log("");
    console.log("  orgs                                                  list the subscriptions seen locally");
    console.log("  label --org <sel> --name <text>                       give a subscription a friendly name");
    console.log("  calibrate --pct <n> [--org <sel>] [--limit <l>]       scale a /usage percentage");
    console.log("            [--reset <ISO>] [--at <ISO>] [--window <hours>]");
    console.log("  calibrate --from-limit [--org <sel>] [--limit <l>]    approximate it from past rejections");
    console.log("            [--expires <ISO>] on --pct, for a boosted allowance");
    console.log("  check [--org <sel>] [--limit <l>] [--stop <pct>]      report headroom; exit 1 past threshold");
    console.log("        [--json]");
    console.log("  status [--transcript <p>|--session <id>|--stdin-hook] one context line; never exits nonzero");
    console.log("  raw [--hours <n>|--since <ISO>] [--org <sel>]         raw token counts per subscription");
    console.log("      [--json]");
    console.log("");
    console.log("<sel> is a uuid prefix, a label, or 'auto' (the default: the calling session's own");
    console.log("subscription). <l> is five_hour (default) or weekly.");
}
