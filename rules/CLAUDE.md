<!-- shared-agent-skills-import-ok -->

# Global Claude Code Rules

These rules apply globally to all Claude Code sessions across projects.

## Global Rules Baseline

- **Scratch Files**: Never write temporary files, scripts, or test data to the repository root. Use the session scratchpad directory. The only permitted in-tree location for AI documents is `.plans/`.
- **Git Operations**: Never run `git commit` or `git push` unless explicitly asked by the user.
- **Windows Environment**: Default to PowerShell. Do not assume Unix tools exist (`grep`, `sed`, `awk`, `file`, etc.). Avoid PowerShell 5.1 language traps (`&&`, `||`, `?:`, `??`, `?.`).
- **Encodings**: Write files in UTF-8 without BOM. When modifying files, preserve the existing line ending style (CRLF / LF).

## Global Skills

The following shared skills are installed globally and available to all sessions:
- `powershell-agent-guidelines`: Windows PowerShell syntax rules, escaping, JSON serialization, and file I/O best practices.
- `agent-implementation-planning`: Standard multi-phase implementation planning lifecycle, subagent constraints, and `.plans/` artifact conventions. Project-specific planning rules override this baseline wherever they differ.
