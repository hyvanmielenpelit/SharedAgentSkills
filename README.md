# SharedAgentSkills

A centralized repository of shared skills, rules, and best practices for AI coding agents across multiple developer harnesses, including **Google Antigravity / Gemini Agents** and **Anthropic Claude Code**.

---

## Repository Structure

```text
SharedAgentSkills/
├── .github/
│   └── workflows/
│       └── validate-skills.yml            # CI validation workflow
├── rules/
│   ├── AGENTS.md                          # Tool-neutral global baseline rules
│   └── CLAUDE.md                          # Claude Code global configuration & import sentinel
├── skills/
│   ├── agent-implementation-planning/     # Project-neutral planning lifecycle baseline
│   │   └── SKILL.md
│   └── powershell-agent-guidelines/       # Windows & PowerShell execution guidelines
│       └── SKILL.md
├── tools/
│   └── validate_skills.py                 # Skill specification and formatting validator
├── .editorconfig                          # Enforces line endings, indentation, and no BOM
├── .gitattributes                         # Git text attribute configuration
├── .gitignore                             # Ignores IDE and transient files
├── README.md                              # This document
├── setup.ps1                              # Idempotent Windows bootstrap script
└── sync.ps1                               # Fast-forward sync and rule refresh script
```

---

## Installation & Setup

### Windows (Automated)

Run the bootstrap script from PowerShell:

```powershell
.\setup.ps1
```

To see what the script will do without making changes:

```powershell
.\setup.ps1 -DryRun
```

#### What `setup.ps1` Does

1. **Claude Code Discovery**:
   - Creates `~/.claude/skills/` as a real directory (if absent).
   - Creates NTFS directory junctions pointing each shared skill (`~/.claude/skills/<skill>`) to this repository.
   - Creates an NTFS junction for `~/.claude/rules` pointing to `SharedAgentSkills\rules`.
   - Adds a marked import (`@rules/CLAUDE.md`) in `~/.claude/CLAUDE.md`.
2. **Antigravity Discovery**:
   - Creates `~/.gemini/config/skills/` as a real directory (if absent).
   - Creates NTFS directory junctions pointing each shared skill (`~/.gemini/config/skills/<skill>`) to this repository. This mounts skills under **Global Discovery (Priority 3)**, higher than built-in defaults.
   - Updates `~/.gemini/config/AGENTS.md` by regenerating the inlined global rules from `rules/AGENTS.md` between marked delimiters (`<!-- BEGIN SharedAgentSkills -->` and `<!-- END SharedAgentSkills -->`), preserving any existing rules outside the markers.

### Linux / macOS (POSIX)

On POSIX platforms, symlink each skill and include the rule files:

```bash
# Claude Code
mkdir -p ~/.claude/skills
ln -s "$(pwd)/skills/powershell-agent-guidelines" ~/.claude/skills/
ln -s "$(pwd)/skills/agent-implementation-planning" ~/.claude/skills/
ln -s "$(pwd)/rules" ~/.claude/rules

# Antigravity / Gemini
mkdir -p ~/.gemini/config/skills
ln -s "$(pwd)/skills/powershell-agent-guidelines" ~/.gemini/config/skills/
ln -s "$(pwd)/skills/agent-implementation-planning" ~/.gemini/config/skills/
```

---

## Synchronization

To pull updates from the remote repository and refresh global rules on Windows:

```powershell
.\sync.ps1
```

`sync.ps1` runs `git pull --ff-only` and re-executes `setup.ps1` to ensure all junctions are healthy and the latest rules in `rules/AGENTS.md` are refreshed into `~/.gemini/config/AGENTS.md`.

---

## Antigravity `skills.json` Fallback

Antigravity also supports declaring skills via `skills.json`. While directory junctions in `~/.gemini/config/skills/` are preferred for local discovery (Priority 3), `skills.json` can be used:

1. When the repository is cloned directly inside the user's home directory (e.g. `~/SharedAgentSkills`), where `{"entries":[{"path":"~/SharedAgentSkills/skills"}]}` avoids junctions.
2. In project-level repositories committed as `.agents/skills.json` referencing workspace-relative paths.

---

## Contribution & Skill Guidelines

1. **Skill Directory & Naming**:
   - Skill folder names **must be kebab-case** matching `^[a-z0-9]+(-[a-z0-9]+)*$` (e.g. `my-awesome-skill`).
   - The `name:` field in `SKILL.md` frontmatter **must exactly match the folder name**.
   - The `description:` field must be between 40 and 1024 characters and clearly describe trigger conditions.
2. **Encodings & Line Endings**:
   - All files must be saved in **UTF-8 without BOM**.
   - Scripts (`.ps1`) must contain **ASCII-only** characters to ensure compatibility with Windows PowerShell 5.1 parsers.
3. **Local Validation**:
   - Run the validator before submitting changes:
     ```powershell
     python tools/validate_skills.py
     ```
