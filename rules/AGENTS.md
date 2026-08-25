# Global Agent Rules

## Temporary Files and Scratch Scripts

- **Do NOT write temporary files, scratch scripts, or intermediate data to the repository root or project source tree.**
- For any temporary files or one-off scripts, ALWAYS use the agent's dedicated scratch directory: `<appDataDir>\brain\<conversation-id>\scratch\` (or the harness session scratchpad).
- If you absolutely must create temporary files within a project for build processes, place them in a dedicated `tmp\` or `build\` directory and ensure they are cleaned up or ignored by Git.

## Git Operations

- **Do NOT commit anything to a git repository or make a `git push` unless explicitly requested by the user.**
- Leave modified or newly created files staged or untracked as appropriate, and present the final commit / push commands to the user in the handoff.

## Environment Constraints

- **Operating System:** On Windows environments, when running shell or terminal commands, **only use commands that are available on Windows** (e.g., PowerShell cmdlets or standard Windows executables). Do not assume Unix/Linux coreutils exist.

## Encodings and Line Endings

- **BOM Policy:** Write all text, JSON, and source files in **UTF-8 without a Byte Order Mark (BOM)**, unless a specific toolchain (such as Visual Studio solution files) explicitly requires a BOM.
- **Line Endings:** Match the repository's `.gitattributes` convention (LF in Git, CRLF in the Windows working tree when text=auto). Never mix line ending styles within the same file.
