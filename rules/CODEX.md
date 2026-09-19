# Codex Global Additions

These rules extend the neutral global rules for Codex sessions.

## Scratch Files and Line Endings

- Put disposable files and scripts under the session's `%TEMP%` directory, never in a
  repository. The Windows sandbox exposes that directory as writable.
- Use `apply_patch` for repository edits. On this installation it can turn individual
  edited CRLF lines into LF and leave a file mixed, so normalize every changed Markdown
  and PowerShell file to CRLF afterward and verify the raw CR/LF byte counts. Keep the
  repository's documented LF exceptions unchanged.

## Plans and Protected Paths

- Give Codex access only to the shared plans directory, using
  `sandbox_workspace_write.writable_roots`, `--add-dir`, or an app-added workspace folder.
  Do not grant its parent. A known Windows sandbox issue can still produce an approval
  prompt for a configured writable root; if approval is denied, follow the planning
  fallback rules instead of widening access.
- `.git`, `.agents`, and `.codex` remain read-only inside every writable root. Plans
  repository Git operations and edits under `.agents/` therefore require the active
  Codex escalation mechanism and explicit user approval.

## Installed Skills

- `agent-implementation-planning` defines canonical plan placement and lifecycle.
- `agent-subagent-guidelines` defines delegation tiers and orchestration boundaries.
- `agent-powershell-guidelines` defines Windows command, encoding, and exit-code rules.
- `agent-secret-hygiene` prevents secret-shaped literals from entering artifacts.
- `codex-conventions` defines Codex plan modes, sandboxing, discovery, linking, and spawn
  behavior. Skills prefixed `claude-` or `gemini-` are not installed into Codex.

## Generated Copy

This text is copied into a marked region of `$CODEX_HOME/AGENTS.md` by `setup.ps1`.
Editing that generated region is temporary: change the repository sources and rerun setup.
If a non-empty `$CODEX_HOME/AGENTS.override.md` exists, it shadows this generated file.
