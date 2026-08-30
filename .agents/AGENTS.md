# SharedAgentSkills — Repository-Local Agent Rules

> [!CAUTION]
> **This file governs edits to the SharedAgentSkills repository itself.**
> It is **NEVER** linked, junctioned, copied, or inlined into any harness
> configuration. `setup.ps1` reads only `skills/`, `skills-claude/`,
> `skills-gemini/`, and `rules/`.
>
> - Content for every project, both harnesses -> `skills/` or `rules/AGENTS.md`.
> - Content for one harness -> `skills-claude/` / `skills-gemini/`, or
>   `rules/CLAUDE.md` / `rules/GEMINI.md`.
> - Content about maintaining *this* repository -> here.
> - **Never** move a file from a linked directory into `.agents/` — that
>   silently uninstalls it from that harness on every machine.
> - **Never** add a repository-maintenance note to a linked directory — it
>   becomes a globally-triggering skill in every project on the machine.

## What This Repository Is

A small repository of shared rules and skills for AI coding agents, distributed
to two harnesses on Windows by NTFS junction and by inlined copy. It is not a
platform. Keep additions proportionate to the content they govern.

## The Placement Matrix

|  | Both harnesses | Claude Code only | Antigravity / Gemini only |
|---|---|---|---|
| **Always-on rules** | `rules/AGENTS.md` | `rules/CLAUDE.md` | `rules/GEMINI.md` |
| **Triggered skills** | `skills/` | `skills-claude/` | `skills-gemini/` |

Two tests decide the cell:

- **Scope** — strip every proper noun. Does it still say something useful? If
  yes it is shared; if it names a file, project, or build tool of one repository
  it belongs in that repository, not here.
- **Harness** — does it name a tool, path, mode, or agent type that only one
  harness has (`ExitPlanMode`, `~/.claude/plans/`, `Explore` agents,
  `<appDataDir>/brain/`, `write_to_file`, `skills.json`)? Then it is
  harness-specific.

**The ten-line inline exception.** A harness note of ten lines or fewer inside an
otherwise-shared skill stays there rather than fragmenting into its own file.
`agent-powershell-guidelines` section 10 is the model case. Promote to a
harness-only skill only when the content is substantial enough to stand alone
**and** would mislead under the other harness.

Full reasoning for humans: `docs/ai-skill-management.md`. Placement precedents
for every harness-specific item: `docs/harness-matrix.md`.

## Hard Rules

- **Do not write a tier-to-model table anywhere in this repository.** Tiers are
  roles; each session resolves them against the models it actually offers. A
  written roster has no owner, cannot be verified from the other harness, and
  goes stale unnoticed — `subagent_guidelines/SKILL.md` in GnollHack said
  "Gemini 3.1 Pro" within the same month it was written. The validator enforces
  this: no concrete model name may appear under `skills/` or `rules/`, and at
  most one parenthetical hint in each harness skill.
- **Rules files are capped at 3 KB each.** They load into every context window in
  every project. Anything longer is a triggered skill.
- **`.ps1` files are ASCII-only** and UTF-8 without BOM. Windows PowerShell 5.1
  parses BOM-less scripts using the system ANSI code page.
- **Line endings: LF.** This repository's `.editorconfig` specifies `lf`, unlike
  the CRLF working trees of `GnollHack` and `MobileGnollHackLogger`. An agent
  arriving from either project repository will get this wrong by habit. Verify by
  byte count, never with `grep`, `head`, or `file`.
- **Run `python tools/validate_skills.py` before handing work back.**

## Regeneration Boundaries

Three changes do not take effect until `setup.ps1` runs again:

| Change | Effect without re-running |
|--------|---------------------------|
| Edit `rules/AGENTS.md` or `rules/GEMINI.md` | Antigravity keeps reading the **old** text — it receives an inlined copy, not a link |
| Add, rename, or move a skill directory | No junction exists, so neither harness can see it |
| Rename or delete a skill | The old junction survives; run `setup.ps1 -Prune` |

Editing a file **inside** an already-junctioned skill is live for both harnesses
and needs nothing. Claude Code reads `rules/` through a live junction, so rules
edits reach Claude immediately and Antigravity only after a re-run. That
asymmetry is the most common source of "why is Gemini ignoring my rule".

## Adding or Changing a Skill

1. Decide the cell from the matrix above.
2. Create `<dir>/<kebab-case-name>/SKILL.md` with `name:` matching the directory
   and a `description:` of 40-1024 characters written for **triggering** — it is
   what both harnesses index to decide whether to load the skill.
3. Prefix by scope: `agent-` for shared, `claude-` / `gemini-` for
   harness-specific. Un-prefixed generic names are reserved for shared skills.
   Project repositories use `server_` (MobileGnollHackLogger) and `client_`
   (GnollHack).
4. Run the validator, then `.\setup.ps1` (a new directory needs a new junction).

## Project Repositories

`GnollHack` and `MobileGnollHackLogger` keep canonical skill bodies in
`.agents/skills/<underscore_name>/SKILL.md` with a pointer stub in
`.claude/skills/<kebab-name>/SKILL.md`. **Regenerate stubs, never hand-edit
them:**

```powershell
.\tools\sync_stubs.ps1 -Repo C:\hmp\MobileGnollHackLogger
```

A stub whose `description` has drifted from its canonical will trigger on stale
wording, or not at all.
