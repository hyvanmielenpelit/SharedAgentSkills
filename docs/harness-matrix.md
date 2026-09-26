# Harness-Specificity Matrix

Where every harness-bound instruction lives, and why. This is the **precedent
file**: when you are unsure whether something Claude-, Gemini-, or Codex-specific
belongs in a shared skill, a harness skill, or a rules file, find the closest row
here.

The original Claude/Gemini audit was performed 2026-08-30 across
`SharedAgentSkills`, `GnollHack`, and `MobileGnollHackLogger`; the Codex audit
was added 2026-09-18. If an item is not listed here, it is not harness-specific.

---

## The rule these rows follow

An instruction is **harness-specific** when it names a tool, path, mode, or agent
type that only one harness has. If stripping the harness name leaves the
instruction meaningless, it is harness-bound.

An instruction is **inlined** (kept inside a shared skill, in a per-harness
subsection) when it is **ten lines or fewer** and the surrounding method is
shared. It is **promoted** to a harness-only skill when it is substantial enough
to stand alone *and* would mislead under another harness — in particular when
it is a competing procedure for the same task, not just a different tool name.

---

## Claude Code

| # | Content | Destination | Why |
|---|---------|-------------|-----|
| C1 | Plan mode: `~/.claude/plans/<slug>.md` is the only editable file; copy to the plans repository **before** `ExitPlanMode`; the "why the copy is allowed" rationale; reaching the root via `additionalDirectories`; in-place editing vs `_v<N>` | `claude-plan-mode` | ~45 lines, and a competing procedure for plan delivery. Was duplicated in both project repositories' `CLAUDE.md` |
| C2 | Plan mode prescribes `Explore` agents for research and a `Plan` agent for design; both read-only, need no plan approval | `claude-plan-mode` | Meaningless without plan mode |
| C3 | Format scaling under plan mode — "concise" means no verbosity *within* the mandatory format | `claude-plan-mode` | Same |
| C4 | Approval is requested with the `ExitPlanMode` tool, not a chat question | `claude-plan-mode` | The neutral form ("use the harness's approval mechanism") stays in `agent-implementation-planning` |
| C5 | Resolving a tier to a concrete model | `claude-code-conventions`, **as a runtime rule, not a table** | See "Why there is no roster" below |
| C6 | Agent types `Explore` / `Plan` / `general-purpose` and which may edit files | `claude-code-conventions` | Claude Code's own agent taxonomy |
| C7 | The `.claude/skills/` pointer-stub contract; the stub `description` is what Claude Code indexes for **triggering**; regenerate, never hand-edit | `claude-code-conventions` | Describes a Claude Code mechanism |
| C8 | Native file tools `Write` / `Edit` / `Read` / `Grep` / `Glob`; `Write` emits LF and needs normalizing in a CRLF tree | `agent-powershell-guidelines` section 11 | **Inlined** — 4 lines, shell/IO adjacent |
| C9 | Both PowerShell and a Git Bash `Bash` tool exist and are not interchangeable; default to PowerShell | `agent-powershell-guidelines` section 11 | **Inlined** |
| C10 | Claude Code pre-sets `$PSDefaultParameterValues['Out-File:Encoding']`; the session runs `Bypass`; only cwd persists | `agent-powershell-guidelines` section 11 | **Inlined** — one line each |
| C11 | Claude Code has no `brain/` directory; use the session scratchpad it reports | `rules/CLAUDE.md` | Always-relevant fact, not a procedure |
| C12 | `~/.claude/skills/` discovery and the `@rules/...` import mechanism | `docs/`, plus one line in `rules/CLAUDE.md` | Installation detail, not task guidance |
| C13 | How a document becomes a clickable link here: Markdown link syntax, href written as an absolute forward-slash path (`C:/hmp/plans/...`) rather than working-directory-relative, `SendUserFile` as the side-panel presentation, and the `Artifact` tool ruled out because it publishes to claude.ai | `claude-code-conventions` | Names Claude Code tools and its own link rendering. The shared requirements (never a bare path, always an absolute href) stay in `agent-implementation-planning` |
| C14 | Quota budgeting against the active subscription, **loaded on request only** since a Premium Team seat or a Max plan has quota to spare: `claude-budget.js` reads `~/.claude/projects` transcripts, attributes each request to the paying subscription via `bridge-session` records, and the stop rule decides whether the next plan step will fit | `claude-usage-quota-budget` | Reads a transcript store and a rate-limit model only Claude Code has. The shared half -- stopping at a step boundary rather than mid-step -- is a consequence of Phase 4 and needs no restating in `agent-implementation-planning` |
| C15 | Subagent model families: never a Sonnet subagent, only the Opus and Fable families, and the model passed explicitly on every spawn so an agent type's default cannot pick a disallowed one | `rules/CLAUDE.md`, restated as the constraint every tier resolves within in `claude-code-conventions` | A standing user policy that must bind every spawn, so it is always loaded. It is an exclusion list, not a tier-to-model roster, and names families, never versions |

## Antigravity / Gemini

| # | Content | Destination | Why |
|---|---------|-------------|-----|
| G1 | Plan and report artifacts go to `<appDataDir>/brain/<conversation-id>/` **and** are copied to the plans repository; adding it as a project folder; present the artifact and wait for approval | `gemini-antigravity-conventions` | Competing procedure for plan delivery — the mirror of C1 |
| G2 | Scratch directory `<appDataDir>\brain\<conversation-id>\scratch\` | `rules/GEMINI.md`, and **inlined** in `agent-powershell-guidelines` section 11 | Always-relevant path. **Was leaking into `rules/AGENTS.md`**, which is supposed to be tool-neutral |
| G3 | `~/.gemini/config/skills.json` explicitly registers absolute paths to the source skill directories | `gemini-antigravity-conventions` + `docs/` | Discovery mechanism |
| G4 | `skills.json` configuration requirement, and project-level `.agents/skills.json` | `gemini-antigravity-conventions` | Gemini-only mechanism |
| G5 | Native file tools `write_to_file`, `replace_file_content`, `view_file` | `agent-powershell-guidelines` section 11 | **Inlined** — 3 lines |
| G6 | Execution-policy check before falling back to `powershell.exe -ExecutionPolicy Bypass` | `agent-powershell-guidelines` section 11 | **Inlined** |
| G7 | `.agents/` is canonical; `.claude/` in a project is an adapter layer, not content | `gemini-antigravity-conventions` + `docs/` | Tells a Gemini session which tree to trust |
| G8 | `~/.gemini/config/AGENTS.md` is an **inlined copy** regenerated between markers; re-run `setup.ps1` after any rules change | `rules/GEMINI.md` + `gemini-antigravity-conventions` (self-check) + `docs/` warning box | The highest-likelihood failure in the whole system |
| G9 | How a document becomes a clickable link here: the artifact directory copy is delivered through the app's artifact mechanism, and the plans repository copy is linked by absolute path — which the app can only open because `C:\hmp\plans` is a project folder | `gemini-antigravity-conventions` | The mirror of C13, and the second reason the project folder is mandatory |

## OpenAI Codex

| # | Content | Destination | Why |
|---|---------|-------------|-----|
| X1 | Plans are written and committed to the canonical plans repository in Default mode before approval is requested | `codex-conventions` | Codex's plan-delivery procedure differs from the other two harnesses |
| X2 | Plan mode is non-mutating and returns a `<proposed_plan>`; after acceptance and return to Default mode, copying and committing the canonical plan is the first mutation | `codex-conventions` | Codex Plan mode cannot perform the shared lifecycle's pre-approval write itself |
| X3 | The plans repository is granted as a narrow `sandbox_workspace_write.writable_roots` entry, `--add-dir`, or app-added workspace folder; never grant its parent | `rules/CODEX.md` + `codex-conventions` | Codex-specific sandbox configuration and least-privilege boundary |
| X4 | `.git`, `.agents`, and `.codex` remain protected within writable roots; affected edits and plans-repository Git writes use the active approved-escalation mechanism | `rules/CODEX.md` + `codex-conventions` | Codex sandbox protection persists even when the containing root is writable |
| X5 | Resolving a tier to a concrete model | `codex-conventions`, **as a runtime rule, not a table** | Codex exposes a session-dependent roster, so a committed mapping would go stale |
| X6 | Built-in roles `default`, `worker`, and `explorer`, plus custom roles under user or project `.codex/agents/` | `codex-conventions` | Codex's agent taxonomy and configuration are harness-specific |
| X7 | Spawning is gated unless the user or applicable `AGENTS.md`/skill explicitly requests subagents, delegation, or parallel work | `codex-conventions` | The installed harness injects this constraint even though subagents are otherwise enabled |
| X8 | Global skills are linked per skill under the selected Codex-only `$CODEX_HOME/skills`; project `.agents/skills/` are discovered directly | `codex-conventions` + `docs/` | `$HOME/.agents/skills` also worked, but the Codex-only root avoids unresolved cross-harness visibility |
| X9 | Global instruction precedence uses `$CODEX_HOME/AGENTS.override.md` then `AGENTS.md`; a repository root `AGENTS.md` can direct Codex to the canonical `.agents/AGENTS.md` | `codex-conventions` + root `AGENTS.md` adapter | Codex has no Markdown import syntax, so the project adapter is an explicit-read instruction |
| X10 | `$CODEX_HOME/AGENTS.md` contains an **inlined copy** of `rules/AGENTS.md` plus `rules/CODEX.md`; setup warns when a non-empty override shadows it | `rules/CODEX.md` + `codex-conventions` + `docs/` warning | The copy goes stale until setup runs and can be silently shadowed |
| X11 | Clickable local documents use ordinary Markdown links whose href is an absolute forward-slash path such as `C:/hmp/plans/...` | `codex-conventions` | This is the Codex desktop viewer's supported canonical local-link form |
| X12 | `%TEMP%` is writable; `apply_patch` can produce mixed line endings and requires CRLF normalization; the CLI is resolved from `Get-Command` or the newest desktop-bundled executable | `agent-powershell-guidelines` section 11 + `codex-conventions` + `docs/` | Codex-specific editing and executable-discovery behavior |

---

## Deliberately shared — not harness-specific

| Content | Why it stays shared |
|---------|--------------------|
| The plans repository as source of truth; copy the plan there before requesting approval; `.plans/` only as fallback | True under every harness; only the *private* location differs |
| `_v<N>` versioning, `_A`/`_B` rounds, `task.md`, `walkthrough.md` | Filesystem conventions |
| Five-phase lifecycle, plan template, plans research isolation, version harmonization, the commit protocol | Method, not mechanism |
| Tier **names** and selection criteria | Roles, not model names — each harness skill supplies the resolution rule |
| File-level exclusivity, protecting uncommitted changes, build-boundary sequencing | Coordination rules |
| Everything in `agent-powershell-guidelines` sections 1-10 | Windows and PowerShell 5.1 behavior shared by all three harnesses |
| Every document reported as a clickable link that opens in the application's own viewer, never a bare path; an **absolute** href for anything in the plans repository, never a relative one; link the whole round; re-link on every `_v<N>` | The requirement is universal — a relative href resolves against a current directory no harness guarantees, and the plans repository is outside the working repository under all three. Only the link *mechanism* differs, and C13/G9/X11 supply it |

---

## Why there is no roster (C5 and its Gemini and Codex counterparts)

These were originally planned as a dated tier-to-model table. They are now a
**runtime resolution rule** in each harness skill instead:

> Tiers are roles, not model names. Resolve them against the models this session
> actually offers — never against a written table, which cannot know what is
> installed today.

The table form was abandoned because it would not be reviewed on any cadence, and
because no application can verify another harness's roster. Evidence from this
codebase: `GnollHack/.agents/skills/subagent_guidelines/SKILL.md:48` said
"Gemini 3.1 Pro" against a team running 3.7 Flash — written and stale in the same
month.

Each harness skill also states the **spawn boundary**: every harness can spawn
only agents it exposes in that session, Codex additionally honors its explicit
spawn gate, and a cross-application handoff is performed by a person opening
another application.

The validator enforces the absence: no concrete model name may appear under
`skills/` or `rules/`, and at most one parenthetical hint in each harness skill.
