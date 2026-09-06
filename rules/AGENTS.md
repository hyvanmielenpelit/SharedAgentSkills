# Global Agent Rules

These rules apply to every project and every harness. They are short by design: this text
loads into every context window.

## Temporary Files and Scratch Scripts

- **Never write temporary files, scratch scripts, or intermediate data into a repository**
  -- not the root, not a scratch directory inside it, not anywhere in the source tree.
- Use the agent's dedicated scratch directory. **Your harness rules name the exact path.**
- If a build truly needs temporary files inside the project, use a gitignored `tmp/` or
  `build/` directory, and clean up.

## Git Operations

- **Do NOT commit or push unless the user explicitly asks.** Leave the changes in the
  working tree, staged or untracked, and present the commands in the handoff.
- **The `plans` repository is the ONLY one you may commit or push to.** Everywhere else --
  including a `.plans/` fallback -- it is forbidden unless the user asks.

## Implementation Plans

- Plans, reviews, and walkthroughs go to the shared `plans` repository -- but **only** for
  repositories in an **allowed organization**, listed in `agent-implementation-planning`:
  `<root>/<organization>/<repository>/YYYY-MM-DD/task_name/`. Resolve `<root>` as
  `AGENT_PLANS_ROOT`, else `C:\hmp\plans`, else a `plans` directory beside your
  repository; never create it.
- **Otherwise** the **main** repository's `.plans/`, and only if
  `git check-ignore -q .plans` succeeds there; if not, keep the plan in the chat and write
  no file.
- **Say which of the three applies**; link each document by absolute path, never bare.

## Environment Constraints

- **Windows**: use PowerShell cmdlets or standard Windows executables; do not assume Unix
  coreutils are present. See `agent-powershell-guidelines`.

## Encodings and Line Endings

- **BOM**: write text, JSON, and source files in **UTF-8 without a BOM**, unless a
  specific toolchain requires one (for example Visual Studio `.sln` and `.vcxproj` files).
- **Line endings**: **CRLF**, except files a Linux CI job consumes (`*.yml`, `*.py`),
  which stay LF. Never mix styles in one file; verify by byte count, never with `grep`
  or `file`. Details: `agent-powershell-guidelines`.

## Important Warnings

- **Preserve existing comments and documentation** unless explicitly asked to change them.
- **Comments describe the code's current state**, briefly. Never narrate the change or why
  it was made -- that belongs in the commit description.
- **Never overwrite uncommitted changes** without explicit user permission. If work is at
  risk, ask the user to commit first.
- **Do not hardcode version numbers in AI skills** -- package versions, SDK builds, or
  model names. Name the source-of-truth file, or the selection rule the session resolves
  at runtime. Written rosters drift silently.

## Where Guidance Lives

Skills and rules are distributed from the `SharedAgentSkills` repository; guidance about
one project belongs in that project's own `.agents/` directory. When editing that
repository, its `.agents/AGENTS.md` explains the placement rules.
