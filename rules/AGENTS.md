# Global Agent Rules

These rules apply to every project and every harness, and load into every context window.

## Temporary Files and Scratch Scripts

- **Never write temporary files, scratch scripts, or intermediate data into a repository**
  -- not the root, not a scratch directory inside it, not anywhere in the source tree. Use
  the agent's own scratch directory; **your harness rules name the exact path.**
- If a build truly needs temporary files inside the project, use a gitignored `tmp/` or
  `build/` directory, and clean up.

## Git Operations

- **Do NOT commit or push unless the user explicitly asks.** Leave changes in the working
  tree, staged or untracked, and present the commands in the handoff.
- **The `plans` repository is the ONLY one you may commit or push to** -- everywhere else,
  including a `.plans/` fallback, only when the user asks.

## Implementation Plans

- Plans, reviews, and walkthroughs go to the shared `plans` repository, and **only** for
  repositories in an **allowed organization**; never create the root yourself. Layout and
  versioning: `agent-implementation-planning`.
- **Otherwise** the **main** repository's `.plans/`, and only where
  `git check-ignore -q .plans` succeeds; if not, keep the plan in the chat, write no file.
- **Say which of the three applies**; link each document by absolute path, never bare.

## Windows, Encodings, and Line Endings

Details: `agent-powershell-guidelines`.

- **Windows**: use PowerShell cmdlets or standard Windows executables; do not assume Unix
  coreutils are present.
- **BOM**: write text, JSON, and source files in **UTF-8 without a BOM**, unless a
  toolchain requires one (Visual Studio `.sln` and `.vcxproj`).
- **Line endings**: **CRLF**, except files a Linux CI job consumes (`*.yml`, `*.py`),
  which stay LF. Never mix styles in one file; verify by byte count, never with `grep`
  or `file`.

## Important Warnings

- **Use US English spelling** in all English text: behavior, license, normalize.
- **Preserve existing comments and documentation** unless explicitly asked to change them.
- **Comments describe the code's current state**, briefly -- never the change or its
  reason, which belong in the commit description.
- **Never overwrite uncommitted changes** without explicit permission; if work is at
  risk, ask the user to commit first.
- **Do not hardcode version numbers or model names in AI skills.** Name the
  source-of-truth file, or the selection rule the session resolves at runtime; written
  rosters drift silently.
- **Never write a secret-shaped literal** -- a vendor token prefix plus a random-looking
  body -- into source, tests, comments, documentation, or plans, even when synthetic.
  GitHub push protection blocks the whole push. See `agent-secret-hygiene`.

## Where Guidance Lives

Skills and rules are distributed from the `SharedAgentSkills` repository; guidance about
one project belongs in that project's own `.agents/` directory.
