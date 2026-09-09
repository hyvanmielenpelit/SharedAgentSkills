---
name: claude-usage-quota-budget
description: >-
  ON REQUEST ONLY -- never load this skill automatically. Load it when the user's own
  prompt asks for quota budgeting by name or in its own words: quota, usage limit, rate
  limit, the 5-hour or weekly window, budget this plan, how much quota is left, what did
  this step cost, /usage, claude-budget. Do NOT load it because a plan is long, because
  an execution phase reached a step boundary, or because agent-implementation-planning
  names quota budgeting -- a Premium Team seat or a Max plan holds far more quota than a
  plan consumes, so tracking is overhead there and earns its place only on a standard
  seat, only when asked. Once invoked: budgeting a plan against the subscription's usage
  quota with claude-budget.js so work stops at a step boundary rather than part-way
  through a step -- calibration, per-subscription attribution, measuring a step and
  estimating the next from it, the stop rule and its margin, the push notification when
  the budget will not cover the next step, and reporting what the plan consumed.
---

# Claude Usage Quota Budget

Claude Code only. The tool reads the transcripts Claude Code writes under
`~/.claude/projects`; no other harness has them.

---

## When to Use This Skill

**On request only. This skill does not apply unless the user asks for it.**

Load it when the user's prompt asks for quota budgeting -- by name, or in its own words:
quota, usage limit, rate limit, the 5-hour or weekly window, "budget this plan", "how
much quota is left", "what did that step cost", `/usage`, `claude-budget`. Load it too
when a project's own rules, or a plan document already in hand, asks for quota tracking.

**Do not load it on your own initiative**, and in particular not because:

- a plan is long, fans out to subagents, or looks expensive;
- an execution phase reached a step boundary;
- `agent-implementation-planning` names quota budgeting among Phase 4's duties. That
  requirement is conditional on quota tracking being in effect. With no tracking in
  effect, execute the plan and skip the readings -- there is nothing to measure and
  nothing to decide.

**Why:** a **Premium Team seat** carries so much usage quota that a plan of the size
these skills describe never comes near the limit, and a personal **Max** plan is the
same. Tracking against it spends context and user attention on a question that cannot
change what happens. It earns its place on a **standard Team seat**, where a long plan
genuinely can hit the 5-hour window mid-step -- and there the user, who is the one who
knows which seat they are on, is the one who asks.

Everything below assumes the skill has been asked for.

---

## What This Is

```
C:\hmp\SharedAgentSkills\tools\claude-budget.js
```

A Node script that estimates how much of the active subscription's rate-limit window is
left. It reads local transcript files only -- it never calls the API, and it consumes no
quota itself. Invoke it with `node`; there is nothing to install.

> [!IMPORTANT]
> **Each subscription has its own window, and a blended figure is wrong for both.** The
> tool attributes every billed request to the subscription that paid for it, through the
> `bridge-session` records the desktop app writes into each transcript; a subagent
> transcript inherits its parent session's attribution. The default `--org auto` resolves
> **the calling session's own subscription**, so nobody has to state which plan is active.
> Pass `--org <uuid-prefix|label>` only to ask about a different one.

---

## Getting Calibrated: Once, Not Per Plan

The `/usage` panel gives a percentage but never the capacity behind it, so the tool needs a
capacity from somewhere before a percentage means anything. **That capacity persists** in
`~/.claude/usage-budget.json`, per subscription. It is not a per-plan step, and the user
should not be asked for a reading they have already given.

Resolve it in this order at the start of an execution phase. Stop at the first step that
succeeds.

### 1. Is it already calibrated?

```powershell
node C:\hmp\SharedAgentSkills\tools\claude-budget.js check --json
```

Exit 0 or 1 means yes -- proceed, and say what basis you are on (`calibrationSource` in the
JSON). Exit 2 means no. **Do not ask the user anything before running this.**

### 2. Can it be derived without asking?

```powershell
node C:\hmp\SharedAgentSkills\tools\claude-budget.js calibrate --from-limit
```

Once the API has rejected a request on a subscription, the window was provably full at that
instant, so what was billed in it approximates what it holds. This needs no reading and no
user involvement.

> [!IMPORTANT]
> **It is an estimate, and every report built on it says so.** Two things distort it: a
> window partly funded by extra-usage credits totals more than the plan's own allowance, and
> the token weights are an assumption, so a window of unusual workload mix prices
> differently. The tool takes the **lowest** capacity across observed rejections for that
> reason, and prints the spread. **Past about 40% spread the tool says outright that the
> figure is too wide to plan against** -- report that, and ask for a reading rather than
> letting a stop decision rest on it.
>
> **One observation is the dangerous case, not the safe one.** With a single rejection
> there is no spread to report, and that silence reads as confidence it has not earned:
> measured against a real reading, a one-observation estimate came out **42% low**. The
> tool now says so explicitly. Treat one observation as a hint, not a budget.
>
> `check` marks it `(capacity approximate)`, `status` marks the percentage `32.2%~`, and the
> JSON carries `calibrationApproximate: true`. **Never present an approximated percentage as
> a measured one.**

### 3. Ask -- once, and take no for an answer

Only if both of the above fail. Put the choice to the user plainly, at the start, before any
work begins:

> This plan looks long enough to run into the 5-hour limit. Want me to track quota as I go
> and stop cleanly at a step boundary rather than mid-step? If so, open `/usage` and tell me
> the two percentages it shows. If not, I will not run any quota commands
> during this plan.

On a number, calibrate and proceed:

```powershell
node C:\hmp\SharedAgentSkills\tools\claude-budget.js calibrate --pct <number>
```

**`/usage` does not look the same on every plan.** Ask for what the user actually has in
front of them rather than for a format their plan does not offer.

**On an individual plan (Pro, Max)** it is a card with a copy-to-clipboard button, and
what it copies is worth more than the percentage alone -- both limits, both reset times
as ISO timestamps, the report's own timestamp, and the client's 24h request count:

```powershell
node ...\claude-budget.js calibrate --pct 71 --org pro --reset <5h reset> --at <report time>
node ...\claude-budget.js calibrate --pct 8 --org pro --limit weekly --reset <weekly reset> --at <report time>
```

**On a Team or Enterprise plan there is no card and no copy button.** `/usage` opens a
settings page showing two percentages, a relative reset ("Resets in 1 hr 7 min") and a
local wall-clock one ("Resets Thu 3:00 AM"). So:

- **Ask only for the two percentages.** They are the part that cannot be derived.
- **Do not ask for the 5h reset.** The tool derives that window from local activity and
  it has matched the page exactly. Run `check` first and compare its "resets in" against
  what the user reports -- agreement confirms both, and no ISO conversion is needed.
- **Convert the weekly reset yourself.** It is local wall-clock, so apply the machine's
  offset (`Get-Date -Format o` shows it) and pass the result to `--reset`.
- **Derive `--at` from the relative reset** rather than guessing: reading time = the
  derived reset minus the "resets in" figure the user read.

> [!IMPORTANT]
> **A promotional allowance is handled for you, but check that it was.** Anthropic
> raises a limit for a period from time to time ("+50% weekly limits promo through Sep
> 13"). A capacity calibrated during one is not the plan's ordinary capacity and lapses
> on a known date.
>
> The client caches these notices locally, so `calibrate` detects an active promotion on
> the limit being calibrated, adopts its end date, and prints both. `orgs` and `status`
> list any promotion in effect. Once the date passes, `check` prints an `Expired` line,
> `status` says an allowance has lapsed, and the JSON carries `calibrationExpired`.
>
> Two things it cannot do, so watch for them: **the notice is not attributed to a
> subscription** (the cache is one blob for whichever plan was last signed in), and a
> notice whose end date will not parse is reported with a prompt to pass `--expires`
> by hand. Override the detected date with `--expires <ISO>` whenever the user knows
> better.

**`--at` matters on either plan.** A percentage is true at the instant it was read;
calibrating without it measures consumption up to *now* and folds everything spent in
between into the capacity.

**On a decline, run no quota commands for the rest of the plan.** Record the decision in
`task.md` so a resumed session does not ask again:

```markdown
Quota tracking: declined by user on 2026-09-07. Do not re-ask for this plan.
```

Do not ask again at the next boundary, do not ask again after a compaction, and do not
substitute a silent `--from-limit` for the tracking they turned down.

### Ask only when it can matter

A three-step refactor will not exhaust a 5-hour window. **Skip the question entirely for
short plans** -- it is noise. Raise it when the plan is long, when it fans out to subagents,
or when the current window is already well used.

### Keeping it honest afterwards

Nothing needs re-doing on a schedule. Two signals say a stored capacity has gone stale, and
the tool watches for both:

- **Drift.** A later rejection is ground truth. If it implies a capacity more than 25% away
  from the stored one, `check` prints a `Drift` line and the JSON carries
  `calibrationDrift`. Surface it and offer a fresh reading; do not quietly keep reporting a
  percentage you have been told is wrong.
- **A plan change.** An upgrade or downgrade changes capacity outright, and nothing local
  announces it. If the user mentions changing plan, recalibrate.

---

## How Resets Are Handled

**A window is not a fixed daily grid.** It opens on the first request made after the
previous one closed, runs for the limit's span, and closes. After an idle stretch longer
than the span, the next request opens a fresh window wherever it happens to fall -- so
two subscriptions, or the same one on different days, sit on entirely different phases.

The tool derives the current window from local activity rather than from a stored
timetable: it walks back to the most recent gap of a full span (which provably closed a
window) and rolls forward from there. Checked against the resets the API itself reported
at rejections, this predicts each one to within ten minutes.

Three consequences worth knowing:

- **A reset needs no action.** Consumption is only ever summed from the current window's
  start, so the moment a window turns over the used figure returns to near zero on its
  own. Calibration is untouched -- the capacity does not change, only which requests
  count towards it.
- **An idle subscription has no open window.** `check` says so and reports full headroom;
  the JSON carries `windowOpen: false` with `resetsAt: null`. Do not read that as an
  error, and do not report a percentage: nothing is spent, and a new window begins with
  the next request.
- **`resetsInMs` is the cheapest way out of trouble.** When the next step will not fit,
  waiting for the turnover usually costs less than any other remedy. Give the user the
  time and let them decide.

`check` names the basis it used on the Window line -- `derived from local activity`, or
`observed reset` when a rejection pinned that window exactly, or `stored anchor, rolled
forward` in the fallback case where the subscription has no local activity to derive
from. Only the last is guesswork.

**The weekly window is placed by a different rule and must not be derived.** A reported
weekly reset landed on a fixed wall-clock hour a week out (`2026-09-14T02:00:00Z`) that
no activity-derived window predicts. It is carried forward from a known anchor instead,
which is why `check` reports `stored anchor, rolled forward` for it rather than
`derived from local activity`. Give it an anchor once, with
`calibrate --limit weekly --reset <the reset the panel shows>`.

---

## The Cadence During Phase 4

`agent-implementation-planning` requires a reading at three moments and forbids readings
inside a step. This is how each one is taken. Every command is the tool above; `--org auto`
is the default and resolves the calling session's own subscription.

Keep three values in the session as you go. They are the whole method:

| Held value | How it is obtained |
|------------|--------------------|
| `baseline` | The ISO timestamp taken before the first step |
| `stepStart` | The ISO timestamp taken before the current step |
| `costs[]` | The measured cost of every step finished so far |

Take a timestamp with `Get-Date -Format o`; any ISO 8601 string the tool can parse will do.

### Before the first step

```powershell
node C:\hmp\SharedAgentSkills\tools\claude-budget.js check --json
```

This is also the call that answers whether tracking is possible at all -- see Getting
Calibrated. Record `remainingUnits`, `resetsInMs` and `calibrationSource`, and set
`baseline` to now. There is no measured
step yet, so **do not invent an estimate for the first step.** Say that the first step is
unmeasured and apply the bootstrap floor: begin only above **20% remaining**. Tell the user
the headroom you are starting with and that the first step's cost is unknown until it has
run once.

### At each step boundary

Two commands -- what the step just cost, then what is left:

```powershell
node C:\hmp\SharedAgentSkills\tools\claude-budget.js raw --since <stepStart> --json
node C:\hmp\SharedAgentSkills\tools\claude-budget.js check --json
```

Append the `units` from the first to `costs[]`. Then decide, in this order:

1. `worst` = the largest value in `costs[]`. **The estimate for the next step is `worst`,
   not the average.** An average is the wrong statistic here: it is the expensive step that
   exhausts the window, and steps are not interchangeable.
2. Proceed only if `remainingUnits >= 1.5 * worst`. The margin covers a step that turns out
   harder than every predecessor -- without it, the first above-average step is the one that
   dies half-finished.
3. Widen the margin for a step that must not be interrupted -- a migration, a multi-file
   rename, anything leaving the tree unbuildable midway. Say which margin you used and why.
4. Reset `stepStart` to now and continue.

**Take the boundary reading after subagents have returned, never before.** A fan-out can
consume more between two orchestrator readings than several sequential steps, so a reading
taken before it describes a world that no longer exists.

### When the budget will not cover the next step

Stop **before** starting it. Then, in one report:

```
Stopping before step 6 of 9 (migrate the settings schema).

  consumed this session   12.4M units   (since <baseline>)
  previous step (step 5)   3.1M units
  remaining                3.9M units   (17.8% of the 5h window)
  estimated for step 6     3.1M units   -> 4.7M with the 1.5x margin
  window resets in         1h 12m

task.md is current; step 6 is unticked and resumes cleanly.
```

Then **send a notification**, because the user has very likely walked away during a long
execution phase and in-line text will not reach them:

- Use the `PushNotification` tool. It raises a desktop notification and, with Remote
  Control connected, reaches their phone.
- Keep it under 200 characters, one line, no markdown, and lead with the decision:
  `"Stopped before step 6/9: 3.9M units left, step needs ~4.7M. Window resets in 1h 12m."`
- A `not sent` result means the user is at the terminal and already saw the report. That is
  a success, not a failure -- do not retry it or fall back to another channel.

This is one of the cases the tool's own `--stop` gate exists for: `check --stop 80` exits 1
at or past 80%, so a scripted execution loop can be gated on the exit code rather than on
the agent's judgement.

### After the last step

```powershell
node C:\hmp\SharedAgentSkills\tools\claude-budget.js raw --since <baseline> --json
```

That is the whole plan's cost. Report it with the Phase 5 verification results and in
`walkthrough.md`: units consumed end to end, the number of steps, the most expensive step,
and the headroom left. It is also the only honest input anyone has for estimating the next
plan of similar shape.

---

## Estimating Without Measurements

The tool measures; it does not predict. Two situations have no measured basis, and both are
answered by saying so rather than by producing a number:

- **The first step of a plan.** Nothing has been measured. Bootstrap floor only.
- **A step unlike every step before it** -- the first one to fan out to subagents, or the
  first to touch a large generated file. `worst` understates it. Say the estimate is
  unreliable, widen the margin, and re-measure at the next boundary.

A step's cost is dominated by cache reads, which scale with how much context the step
carries rather than with how many lines it edits. A large edit late in a long session
routinely costs several times the same edit made early. Do not reason about cost from the
size of the diff.

---

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Under the `--stop` threshold (default 90%). |
| `1` | At or past `--stop`. A gate firing as designed, not a failure. |
| `2` | **Could not answer** -- no calibration for this subscription, or the subscription could not be resolved. |

> [!CAUTION]
> **Exit 2 does not mean the quota is fine.** It means the tool has no idea. Report the
> headroom as unknown, offer to calibrate, and carry on without a budget if the user
> prefers -- but never present an unanswered check as a clear result.

---

## Command Reference

| Command | Purpose |
|---------|---------|
| `orgs` | Subscriptions seen locally, which one is signed in, and what is calibrated. |
| `label --org <sel> --name <text>` | Give a subscription a readable name. |
| `calibrate --pct <n> [--org <sel>] [--limit weekly] [--reset <ISO>]` | Scale a `/usage` percentage into a capacity. |
| `calibrate --from-limit [--org <sel>] [--limit weekly]` | Approximate the capacity from past rate-limit rejections, with no reading. |
| `check [--org <sel>] [--limit weekly] [--stop <pct>] [--json]` | Headroom now; exits 1 past the threshold. |
| `status [--session <id>]` | One line, never exits nonzero. |
| `raw [--since <ISO>\|--hours <n>] [--org <sel>] [--json]` | Consumption over a span. `--json` reports the one resolved subscription, with `units` at the top level, zero when it was idle. |

`<sel>` is a uuid prefix, a label prefix, or `auto`.

---

## What It Cannot See

- **The turn in flight.** Transcripts are written as the session runs, so the newest
  reading trails the current turn by roughly one turn. Immaterial across a step; misleading
  if polled inside one.
- **Usage from other machines** on the same subscription, and anything the API charged that
  never reached a local transcript.
- **Sessions predating the `bridge-session` records.** Older transcripts carry no
  attribution; `orgs` and `raw` report those units as unattributed. Irrelevant to a 5-hour
  window, and worth stating aloud when reasoning about the weekly one.
- **Promotion detection is best-effort.** It reads an undocumented client feature cache
  that may be renamed or restructured at any time, and which is refreshed only for the
  subscription last signed in. No notice means *none was cached*, never *none exists* -
  so if the user mentions a boost the tool has not reported, believe the user and pass
  `--expires` by hand.
- **Roughly a third of billed tokens never reach a transcript.** Measured against a
  `/usage` report covering the same window, the local tally came to 62-85% of the
  reported tokens depending on the class - auxiliary calls the client makes (titles,
  summaries) are billed but are not assistant turns. This does not break the
  percentages: calibration divides one local measure by another, so a steady shortfall
  cancels. It does mean **the unit totals are a proxy, not a ledger** - never quote them
  as what was actually billed, and never compare them to a cost figure.
- **Units are a weighted score, not tokens.** They are comparable with each other and with
  `remainingUnits`, and with nothing else.
- **One conversation can be written to two transcript files**, under different session
  ids, and each billed request is written once per content block on top of that. The tool
  counts each `requestId` once and reports how many duplicates it ignored. The per-session
  breakdown can therefore split one conversation across two names; the totals are right,
  that split is not something to reason from.

---

## When the Other Subscription Has Headroom

`check` prints the other subscription's percentage and reset alongside the active one.
**Report it; do not act on it.** A session cannot change the subscription it runs under --
that happens in the desktop app, and whether to switch is the user's call, not a step the
plan can take.
