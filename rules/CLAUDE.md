<!-- shared-agent-skills-import-ok -->

# Global Claude Code Rules

Claude Code additions to the shared baseline. The baseline itself is imported separately
as `@rules/AGENTS.md` and is not repeated here.

## Scratch Files

Claude Code has no `brain/` directory. Use the **session scratchpad directory Claude Code
reports in its own environment**. The baseline rule still binds: never write temporary
files anywhere inside a repository. Plans go to the shared `plans` repository; `.plans/`
is only the fallback when it cannot be reached.

## Globally Installed Skills

Shared, both harnesses:

- `agent-implementation-planning` -- the planning lifecycle, plan template, the plans
  repository layout and versioning, the commit protocol, follow-up rounds, isolation.
- `agent-subagent-guidelines` -- the mandatory Subagent Use section, model tiers and how
  to resolve them, file-level exclusivity, protecting uncommitted changes.
- `agent-powershell-guidelines` -- Windows and PowerShell 5.1 syntax, encoding, line
  endings, non-interactive execution.

Claude Code only:

- `claude-plan-mode` -- how plan mode reconciles with the plans repository, reaching it
  via `additionalDirectories`, and `ExitPlanMode`.
- `claude-code-conventions` -- resolving a tier here, the spawn boundary, agent types, and
  the `.claude/skills/` pointer-stub contract.
- `claude-usage-quota-budget` -- **on request only**: checking the active
  subscription's remaining quota at every plan step boundary, and stopping cleanly
  rather than mid-step. Worth it on a standard seat; a Premium seat has quota to spare.

A project's own skills override these wherever they differ.

## Editing the Shared Rules

`rules/AGENTS.md` reaches Claude Code through a live junction, so an edit takes effect
immediately. It reaches Antigravity as an **inlined copy** that does not.

**If you edit `rules/AGENTS.md` or `rules/GEMINI.md`, tell the user to run
`.\setup.ps1` in `SharedAgentSkills`**, or Antigravity keeps reading the old text.
