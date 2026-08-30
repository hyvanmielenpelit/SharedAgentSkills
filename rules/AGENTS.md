# Global Agent Rules

These rules apply to every project and every harness. They are short by design: this text
loads into every context window.

## Temporary Files and Scratch Scripts

- **Never write temporary files, scratch scripts, or intermediate data into a repository**
  -- not the root, not a scratch directory inside it, not anywhere in the source tree.
- Use the agent's dedicated scratch directory. **Your harness rules name the exact path.**
- The sole in-tree exception is `.plans/`, which is gitignored and is the intended home
  for AI-produced planning documents.
- If a build genuinely requires temporary files inside the project, put them in a
  dedicated `tmp/` or `build/` directory that is gitignored, and clean up.

## Git Operations

- **Do NOT commit or push unless the user explicitly asks.** Leave modified and new files
  staged or untracked as appropriate, and present the commands in the handoff.

## Environment Constraints

- **Windows**: use commands that exist on Windows -- PowerShell cmdlets or standard
  Windows executables. Do not assume Unix coreutils are present. See
  `agent-powershell-guidelines`.

## Encodings and Line Endings

- **BOM**: write text, JSON, and source files in **UTF-8 without a BOM**, unless a
  specific toolchain requires one (for example Visual Studio `.sln` and `.vcxproj` files).
- **Line endings**: match the repository's existing convention. Never mix styles within a
  file, and never guess from the OS -- check the file you are editing.

## Important Warnings

- **Preserve existing comments and documentation** unless explicitly asked to change them.
- **Never overwrite uncommitted changes** without explicit user permission. If work is at
  risk, ask the user to commit first.
- **Do not hardcode version numbers in AI skills** -- package versions, SDK builds, or
  model names. Reference the source-of-truth file, or state the selection rule and let the
  session resolve it. Written rosters drift silently.

## Where Guidance Lives

Skills and rules are distributed from the `SharedAgentSkills` repository. Guidance that is
true everywhere belongs there; guidance about one project belongs in that project's own
`.agents/` directory. When editing that repository, its `.agents/AGENTS.md` explains the
placement rules.
