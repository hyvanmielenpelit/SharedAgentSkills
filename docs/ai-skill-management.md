# Managing AI Skills Across Repositories and Harnesses

How to decide where a piece of AI guidance lives, how to change it, and how to
share it. Written for humans; the agent-facing form of the same rules is in
`../.agents/AGENTS.md`.

---

## The 60-Second Version

| I want to change... | Edit this | Re-run `setup.ps1`? |
|---------------------|-----------|---------------------|
| Guidance for every project, both harnesses | `skills/<name>/SKILL.md` | No — junctions are live |
| A short always-on rule for everything | `rules/AGENTS.md` | **Yes** — Antigravity gets a copy |
| Something only Claude Code has | `skills-claude/<name>/SKILL.md` | No |
| Something only Antigravity has | `skills-gemini/<name>/SKILL.md` | No |
| An always-on rule for one harness | `rules/CLAUDE.md` / `rules/GEMINI.md` | **Yes** for GEMINI, no for CLAUDE |
| Guidance about one project | `<repo>/.agents/skills/<name>/SKILL.md`, then regenerate its stub | No |
| Something about maintaining this repository | `.agents/AGENTS.md` | Never — it is not linked |
| **Add or rename** any skill directory | the directory | **Yes**, with `-Prune` for a rename |

---

## The Placement Matrix

|  | **Both harnesses** | **Claude Code only** | **Antigravity / Gemini only** |
|---|---|---|---|
| **Always-on rules** (every context window) | `rules/AGENTS.md` | `rules/CLAUDE.md` | `rules/GEMINI.md` |
| **Triggered skills** (loaded on match) | `skills/` | `skills-claude/` | `skills-gemini/` |

Project-specific guidance sits outside this matrix, in each repository's own
`.agents/skills/`.

### Axis 1 — scope

**Strip every proper noun. Does it still say something useful?**

If yes, it is shared. If it names a file path, project, build tool, framework, or
domain concept of one repository — `makedefs`, `site2.scss`,
`GnollHackServer.Data`, P/Invoke — it belongs in that repository.

Most valuable guidance is *generic method with project-specific examples*. The
rule: **the method goes up, the examples stay down, and the project skill opens
by delegating the method by name.**

### Axis 2 — harness

**Does it name a tool, path, mode, or agent type that only one harness has?**

`ExitPlanMode`, `~/.claude/plans/`, `Explore` agents, `<appDataDir>/brain/`,
`write_to_file`, `skills.json` are all harness-bound. If stripping the harness
name leaves the instruction meaningless, it is harness-specific.

### The ten-line inline exception

A harness note of **ten lines or fewer** inside an otherwise-shared skill stays
there rather than fragmenting into its own file. `agent-powershell-guidelines`
section 10 keeps a short subsection per harness and is the model case.

Promote to a harness-only skill when the content is substantial enough to stand
alone **and** would mislead under the other harness. Claude Code's plan-mode
workflow (about 45 lines, meaningless to Antigravity, and a *competing procedure*
for the same task) clears the bar. "Claude Code pre-sets `Out-File:Encoding`" does
not.

---

## How Guidance Reaches Each Harness

| | Antigravity / Gemini | Claude Desktop + Claude Code |
|---|---|---|
| Shared skills | `~/.gemini/config/skills/` (junction, **live**) | `~/.claude/skills/` (junction, **live**) |
| Harness skills | `skills-gemini/*` -> same directory | `skills-claude/*` -> same directory |
| Neutral rules | `~/.gemini/config/AGENTS.md`, **inlined copy** | `@rules/AGENTS.md`, **live** |
| Harness rules | `rules/GEMINI.md`, **inlined copy** | `@rules/CLAUDE.md`, **live** |
| Project rules | `<repo>/.agents/AGENTS.md` | `<repo>/.claude/CLAUDE.md`, importing `../.agents/AGENTS.md` |
| Project skills | `<repo>/.agents/skills/<underscore>/` | `<repo>/.claude/skills/<kebab>/` pointer stub |

> [!WARNING]
> **Everything Claude reads is live. Antigravity's *rules* are a copy.**
>
> Edit `rules/AGENTS.md` and Claude Code picks it up on the next session with no
> further action. Antigravity keeps reading the previous text until `setup.ps1`
> (or `sync.ps1`) runs and regenerates the inlined region in
> `~/.gemini/config/AGENTS.md`.
>
> This is the most common source of "why is Gemini ignoring my rule". Antigravity's
> *skills* are junctions and are live; only the rules are copied.

---

## Why the Duplication Matters

The planning workflow was, before this restructuring, stated **four times**: in
the shared skill, in a project's own skill, in that project's `CLAUDE.md`, and in
its `AGENTS.md`. The last two are **always-on** — roughly 30 KB, about 7,500
tokens, loaded into every session in that repository whether or not the task
involves planning.

That is the cost worth attacking first, and it is why a rules file that restates a
skill is an anti-pattern rather than a convenience. Rules are capped at 3 KB each
for the same reason.

---

## Why There Is No Model Roster Here

Tiers (`deep`, `standard`, `mechanical`, `inherit`) are **roles**. Which concrete
model fills a role is resolved by each session against the models it actually
offers — there is no table anywhere in this repository, and the validator fails
any shared skill that names a model.

The reason, from this codebase:

> `GnollHack/.agents/skills/subagent_guidelines/SKILL.md:48` read "(e.g., Claude
> Opus spawns Claude Opus subagents, Gemini 3.1 Pro spawns Gemini 3.1 Pro
> subagents)" — against a team actually running Gemini 3.7 Flash. That line was
> written in August 2026 and was stale in the same month.

A written cross-harness roster is the worst case of all: it has no owner, it
cannot be verified from either side (a Claude Code session cannot check what
Antigravity offers), and so it rots with nobody positioned to notice. A selection
rule — "a capable mid-tier, strong enough to follow an approved plan without
supervision" — self-corrects when the roster changes.

---

## How the Work Actually Flows

Plans are authored on the **deep** tier in one application and frequently
implemented on the **standard** tier in the other, with `.plans/` as the
interchange format.

The two applications **cannot reach each other's models**. Claude Code spawns only
Claude models; Antigravity spawns only Gemini models. The handoff between phases
is **a person opening the other application** — no agent performs it, and no plan
should imply one can. A plan records the intent with an optional line:

```markdown
## Execution Target
Planned in: Claude Code (deep)
Intended implementer: Antigravity (standard)
```

It names a harness and tier, never a model version, because the planning session
cannot verify the implementing application's roster.

This is also why plan quality is load-bearing: the implementer is a different
model in a different application, with none of the planning session's context and
no way to ask its author. Plans are written for a reader who has neither.

---

## Naming

One flat global namespace covers user-level skills, both repositories, and
plugins. When two repositories are open as working directories in the same
session, all sets load together and the loser of a name collision is **silently
never loaded**.

| Scope | Prefix | Example |
|-------|--------|---------|
| Shared, both harnesses | `agent-` | `agent-implementation-planning` |
| Shared, Claude only | `claude-` | `claude-plan-mode` |
| Shared, Gemini only | `gemini-` | `gemini-antigravity-conventions` |
| MobileGnollHackLogger | `server_` | `server_implementation_planning` |
| GnollHack | `client_` | `client_implementation_planning` |

Un-prefixed generic names are reserved for shared skills.

---

## Lifecycle

### Creating a skill

1. Pick the cell from the matrix.
2. Create `<dir>/<kebab-name>/SKILL.md`. The `name:` must match the directory.
   The `description:` (40-1024 characters) is what both harnesses index to decide
   whether to load it — **write it for triggering, not for a human reader.**
3. `python tools/validate_skills.py`
4. `.\setup.ps1` — a new directory needs a new junction.
5. For a project repository, create the canonical under `.agents/skills/` and
   generate the stub with `tools/sync_stubs.ps1`.

### Editing a skill

Edit the canonical only. Never edit a `.claude/skills/` stub by hand — regenerate
it. Re-run `setup.ps1` if you touched `rules/AGENTS.md` or `rules/GEMINI.md`.

### Sharing with other developers

`git commit` and `git push` here; other developers run `.\sync.ps1`.

Because your own edit is already live through the junction, **pushing is the step
that is easy to forget.** Nothing on your machine will remind you.

---

## Review Checklist

- Correct cell in the matrix; correct prefix.
- `name:` matches the directory; `description:` describes trigger conditions.
- No concrete model name outside a single parenthetical hint in a harness skill.
- Rules files still under 3 KB.
- No project noun in a shared skill; no harness noun in `skills/` or
  `rules/AGENTS.md`.
- Stubs regenerated if a canonical description changed.
- UTF-8 without BOM; LF in this repository, CRLF in the project repositories.
- `python tools/validate_skills.py` passes.

---

## Anti-Patterns

- **Restating a skill in a rules file.** It is always-on cost for triggered
  content.
- **Copying a shared skill into a repository "for safety".** Use the six-line
  fallback block in the overlay instead.
- **Editing a `.claude/skills/` stub body.** It will be overwritten; and if you
  changed the description there, the canonical and the trigger now disagree.
- **Writing a tier-to-model table.** See above.
- **Fragmenting a four-line harness note into its own skill.** See the ten-line
  exception.
- **Putting repository-maintenance notes in `skills/`.** They become
  globally-triggering skills in every project on the machine.
- **Moving a shared skill into `.agents/`.** It is silently uninstalled everywhere.

---

## What Is Deliberately Absent

Recorded so the gaps read as decisions rather than oversights:

- **No skill registry file.** The validator's namespace check does the work a
  registry would; a hand-maintained file describing the filesystem would drift.
- **No skill-authoring skill.** The placement rules are here for humans and in
  `.agents/AGENTS.md` for agents editing this repository, which is where the
  decision is actually made.
- **No scaffolding script.** Two files by hand is cheaper than a generator that
  drifts from the validator.
- **No `docs/model-tiers.md`.** See above.

Revisit any of these when the core is in use and the pressure is demonstrated
rather than anticipated. All are additive.
