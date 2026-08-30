# Harness-Specificity Matrix

Where every harness-bound instruction lives, and why. This is the **precedent
file**: when you are unsure whether something Claude-specific or Gemini-specific
belongs in a shared skill, a harness skill, or a rules file, find the closest row
here.

Audit performed 2026-08-30 across `SharedAgentSkills`, `GnollHack`, and
`MobileGnollHackLogger`. If an item is not listed here, it is not
harness-specific.

---

## The rule these rows follow

An instruction is **harness-specific** when it names a tool, path, mode, or agent
type that only one harness has. If stripping the harness name leaves the
instruction meaningless, it is harness-bound.

An instruction is **inlined** (kept inside a shared skill, in a per-harness
subsection) when it is **ten lines or fewer** and the surrounding method is
shared. It is **promoted** to a harness-only skill when it is substantial enough
to stand alone *and* would mislead under the other harness — in particular when
it is a competing procedure for the same task, not just a different tool name.

---

## Claude Code

| # | Content | Destination | Why |
|---|---------|-------------|-----|
| C1 | Plan mode: `~/.claude/plans/<slug>.md` is the only editable file; copy to `.plans/` **before** `ExitPlanMode`; the "why the copy is allowed" rationale; in-place editing vs `_v<N>` | `claude-plan-mode` | ~45 lines, and a competing procedure for plan delivery. Was duplicated in both project repositories' `CLAUDE.md` |
| C2 | Plan mode prescribes `Explore` agents for research and a `Plan` agent for design; both read-only, need no plan approval | `claude-plan-mode` | Meaningless without plan mode |
| C3 | Format scaling under plan mode — "concise" means no verbosity *within* the mandatory format | `claude-plan-mode` | Same |
| C4 | Approval is requested with the `ExitPlanMode` tool, not a chat question | `claude-plan-mode` | The neutral form ("use the harness's approval mechanism") stays in `agent-implementation-planning` |
| C5 | Resolving a tier to a concrete model | `claude-code-conventions`, **as a runtime rule, not a table** | See "Why there is no roster" below |
| C6 | Agent types `Explore` / `Plan` / `general-purpose` and which may edit files | `claude-code-conventions` | Claude Code's own agent taxonomy |
| C7 | The `.claude/skills/` pointer-stub contract; the stub `description` is what Claude Code indexes for **triggering**; regenerate, never hand-edit | `claude-code-conventions` | Describes a Claude Code mechanism |
| C8 | Native file tools `Write` / `Edit` / `Read` / `Grep` / `Glob`; `Write` emits LF and needs normalising in a CRLF tree | `agent-powershell-guidelines` section 10 | **Inlined** — 4 lines, shell/IO adjacent |
| C9 | Both PowerShell and a Git Bash `Bash` tool exist and are not interchangeable; default to PowerShell | `agent-powershell-guidelines` section 10 | **Inlined** |
| C10 | Claude Code pre-sets `$PSDefaultParameterValues['Out-File:Encoding']`; the session runs `Bypass`; only cwd persists | `agent-powershell-guidelines` section 10 | **Inlined** — one line each |
| C11 | Claude Code has no `brain/` directory; use the session scratchpad it reports | `rules/CLAUDE.md` | Always-relevant fact, not a procedure |
| C12 | `~/.claude/skills/` discovery and the `@rules/...` import mechanism | `docs/`, plus one line in `rules/CLAUDE.md` | Installation detail, not task guidance |

## Antigravity / Gemini

| # | Content | Destination | Why |
|---|---------|-------------|-----|
| G1 | Plan and report artifacts go to `<appDataDir>/brain/<conversation-id>/` **and** are copied to `.plans/`; present the artifact and wait for approval | `gemini-antigravity-conventions` | Competing procedure for plan delivery — the mirror of C1 |
| G2 | Scratch directory `<appDataDir>\brain\<conversation-id>\scratch\` | `rules/GEMINI.md`, and **inlined** in `agent-powershell-guidelines` section 10 | Always-relevant path. **Was leaking into `rules/AGENTS.md`**, which is supposed to be tool-neutral |
| G3 | `~/.gemini/config/skills/` mounts skills at Global Discovery Priority 3 | `gemini-antigravity-conventions` + `docs/` | Discovery mechanism |
| G4 | `skills.json` fallback, and project-level `.agents/skills.json` | `gemini-antigravity-conventions` | Gemini-only mechanism |
| G5 | Native file tools `write_to_file`, `replace_file_content`, `view_file` | `agent-powershell-guidelines` section 10 | **Inlined** — 3 lines |
| G6 | Execution-policy check before falling back to `powershell.exe -ExecutionPolicy Bypass` | `agent-powershell-guidelines` section 10 | **Inlined** |
| G7 | `.agents/` is canonical; `.claude/` in a project is an adapter layer, not content | `gemini-antigravity-conventions` + `docs/` | Tells a Gemini session which tree to trust |
| G8 | `~/.gemini/config/AGENTS.md` is an **inlined copy** regenerated between markers; re-run `setup.ps1` after any rules change | `rules/GEMINI.md` + `gemini-antigravity-conventions` (self-check) + `docs/` warning box | The highest-likelihood failure in the whole system |

---

## Deliberately shared — not harness-specific

| Content | Why it stays shared |
|---------|--------------------|
| `.plans/` as source of truth; copy the plan there before requesting approval | True under every harness; only the *private* location differs |
| `_v<N>` versioning, `_A`/`_B` rounds, `task.md`, `walkthrough.md` | Filesystem conventions |
| Five-phase lifecycle, plan template, `.plans/` research isolation | Method, not mechanism |
| Tier **names** and selection criteria | Roles, not model names — each harness skill supplies the resolution rule |
| File-level exclusivity, protecting uncommitted changes, build-boundary sequencing | Coordination rules |
| Everything in `agent-powershell-guidelines` sections 1-9 | Windows and PowerShell 5.1 behaviour, identical under both |

---

## Why there is no roster (C5 and its Gemini counterpart)

Both were originally planned as a dated tier-to-model table. They are now a
**runtime resolution rule** in each harness skill instead:

> Tiers are roles, not model names. Resolve them against the models this session
> actually offers — never against a written table, which cannot know what is
> installed today.

The table form was abandoned because it would not be reviewed on any cadence, and
because neither application can verify the other's roster. Evidence from this
codebase: `GnollHack/.agents/skills/subagent_guidelines/SKILL.md:48` said
"Gemini 3.1 Pro" against a team running 3.7 Flash — written and stale in the same
month.

Each harness skill also states the **spawn boundary**: Claude Code can spawn only
Claude models, Antigravity only Gemini models, and the cross-application handoff
is performed by a person opening the other application.

The validator enforces the absence: no concrete model name may appear under
`skills/` or `rules/`, and at most one parenthetical hint in each harness skill.
