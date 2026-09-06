---
name: gemini-skill-inclusion
description: >-
  Explains how Antigravity handles skill discovery and inclusion.
  Covers the skills.json file schema, the difference between Antigravity
  and Claude Code discovery mechanisms, and how to configure global
  skills using ~/.gemini/config/skills.json.
---

# Antigravity Skill Inclusion

This skill explains how Antigravity manages and discovers AI skills via `skills.json` configuration files, and how that mechanism differs from other agent harnesses.

## Customization Roots & Scopes

Antigravity resolves skills across three different scopes:

1. **Workspace Level**: Skills specific to the current project repository. Found at `.agents/skills/` or declared via `.agents/skills.json`.
2. **Global Level**: General skills available across all projects. Configured via `~/.gemini/config/skills.json` and typically placed in `~/.gemini/config/skills/`.
3. **Plugin Level**: Skills provided by installed plugins (e.g. `plugins/<name>/plugin.json` and `plugins/<name>/skills/`).

## Why `skills.json` Is Required Globally

Unlike Claude Code, which automatically discovers and follows directory junctions placed under `~/.claude/skills/`, **Antigravity uses a progressive skill discovery system that requires explicit configuration for loose global skills.** 

For Antigravity to recognize global skills (including those created by directory junctions), they must be declared in the `entries` array of the `~/.gemini/config/skills.json` file. If this configuration file is missing, the agent will not expose those global skills in the active session's context window.

## The `skills.json` Schema

The JSON configuration allows you to explicitly register customization paths. Both `.agents/skills.json` and `~/.gemini/config/skills.json` use the same schema:

```json
{
  "inherits": [
    {
      "path": "/path/to/shared/skills.json",
      "include_only": ["linter-skill"],
      "exclude": ["deprecated-skill"]
    }
  ],
  "entries": [
    {
      "path": "~/personal-skills"
    },
    {
      "path": "C:/Users/<username>/.gemini/config/skills",
      "exclude": ["experimental-.*"]
    }
  ]
}
```

### Path Resolution Rules

The `path` field is resolved based on the following rules:
1. **Absolute Paths**: Paths starting with `/` or Windows drive letters (`C:/...`) are treated as absolute local filesystem paths.
2. **Home-Relative Paths**: Paths starting with `~/` are resolved relative to the user's home directory on Unix-like systems. On Windows, Antigravity's Go runtime checks `filepath.IsAbs()` directly and does **not** expand `~`, causing path validation to fail (`must be an absolute path: path is not absolute`). Therefore, on Windows, `skills.json` entries must always be configured with full absolute paths using forward slashes (e.g., `C:/Users/<username>/.gemini/config/skills`).
3. **Workspace-Relative Paths**: Paths not starting with `/`, `~/`, or a drive letter are resolved relative to the repository root (the folder containing `.git`).

## Setup & Synchronization Lifecycle

In the `SharedAgentSkills` repository, `setup.ps1` manages the global `skills.json` configuration. 

When run, `setup.ps1`:
1. Idempotently creates or updates `~/.gemini/config/skills.json` so that every
   Gemini-routed source directory in the repository -- `skills/` and
   `skills-gemini/` -- is registered under `entries` as an absolute path written
   with forward slashes. It prunes the legacy `~/.gemini/config/skills` entry,
   both unexpanded and expanded, and rewrites any surviving backslash path.
2. Writes the file as **UTF-8 without a BOM**. Antigravity's JSON decoder is Go's
   `encoding/json`, which rejects a leading `EF BB BF` and can silently load no
   global skills at all. In PowerShell that means `New-Object
   System.Text.UTF8Encoding($false)`; `[System.Text.Encoding]::UTF8` emits a BOM.
3. Automatically backs up previous versions of `skills.json` into `~/.gemini/config/backups/`.

It no longer creates directory junctions under `~/.gemini/config/skills/`;
`skills.json` points at the repository directories directly.

## The Slash Menu Is the Test

A discovered skill gets a first-class slash command: typing `/<name>` in the chat
input box invokes it, alongside semantic discovery from its `description`. So the
`/` menu is a reliable check -- **a skill that is installed but absent from `/`
was not discovered**, and the fault is in `skills.json` or in the path it names,
not in the skill body.

When a skill is missing from `/`, check in this order:

1. **BOM** -- `Format-Hex -Path skills.json -Count 3`. Leading `EF BB BF` means
   the whole file failed to parse and *no* global entry loaded.
2. **Every source directory is listed** -- both `skills/` and `skills-gemini/`
   need their own `entries` element. One missing element loses that whole tree
   silently while the other tree keeps working.
3. **The path is the real directory.** Point `entries` at the repository
   directories themselves. Do not point them at a directory of NTFS junctions
   and expect the walker to follow them the way Claude Code does -- that is the
   difference between the two harnesses, and the reason `~/.gemini/config/skills/`
   was abandoned.
4. **Restart Antigravity.** `skills.json` is read when the customization set is
   built, not per turn.

To add a new skill to Antigravity, add it to the `SharedAgentSkills` repository (either under `skills/` for shared skills or `skills-gemini/` for Gemini-specific skills) and run `setup.ps1` to sync the junctions and config file.

## Validation

All skills and rules must pass validation constraints enforced by `tools/validate_skills.py`:
- **Naming**: Skill directories must use kebab-case (`[a-z0-9]+(-[a-z0-9]+)*`).
- **YAML Frontmatter**: The `SKILL.md` file must contain a `name` matching the directory and a `description` between 40 and 1024 characters.
- **Encoding**: Files must be ASCII-only (no BOM) with CRLF line endings.
- **Model Agnostic**: No concrete model names should be hardcoded in the skill text.
