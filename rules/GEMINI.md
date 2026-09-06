# Global Antigravity Rules

Antigravity additions to the shared baseline above. The baseline is inlined immediately
before this section and is not repeated here.

## Scratch and Artifact Directories

- **Scratch files and one-off scripts**: `<appDataDir>\brain\<conversation-id>\scratch\`.
- **Plans, reports, and analyses**: create the artifact in
  `<appDataDir>\brain\<conversation-id>\` so the UI can present it, **and copy it** to
  the shared `plans` repository, which is the canonical location. **Add `C:\hmp\plans` to
  every project as a project folder** -- never grant access to its parent. See
  `gemini-antigravity-conventions` for the full flow.

The baseline rule still binds: never write temporary files anywhere inside a repository,
except `.plans/`, the fallback when the `plans` repository is unreachable.

## Globally Installed Skills

Shared, both harnesses:

- `agent-implementation-planning` -- the planning lifecycle, plan template, the plans
  repository layout and versioning, the commit protocol, follow-up rounds, isolation.
- `agent-subagent-guidelines` -- the mandatory Subagent Use section, model tiers and how
  to resolve them, file-level exclusivity, protecting uncommitted changes.
- `agent-powershell-guidelines` -- Windows and PowerShell 5.1 syntax, encoding, line
  endings, non-interactive execution.

Antigravity only:

- `gemini-antigravity-conventions` -- artifact delivery, implementing a plan authored
  elsewhere, resolving a tier here, the spawn boundary, skill discovery, and checking
  whether these inlined rules have gone stale.
- `gemini-skill-inclusion` -- pattern for registering and including skills in Antigravity via
  skills.json, workspace discovery, and setup synchronization.

Skills whose names begin with `claude-` exist but are **deliberately not installed here**;
they describe mechanics this application does not have.

A project's own skills override these wherever they differ.

## This Text Is a Generated Copy

> [!WARNING]
> Everything between the `<!-- BEGIN SharedAgentSkills -->` markers in this file is
> **generated** from `SharedAgentSkills/rules/AGENTS.md` and `rules/GEMINI.md`, and is
> refreshed only when `setup.ps1` or `sync.ps1` runs. **Never hand-edit inside the
> markers** -- the next run overwrites it. Edit the source files and re-run the script.
