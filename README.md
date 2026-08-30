# SharedAgentSkills

Shared rules and skills for AI coding agents across two harnesses on Windows:
**Google Antigravity / Gemini** and **Anthropic Claude Code**.

New here? Read [docs/ai-skill-management.md](docs/ai-skill-management.md) — it is
the guide to where guidance belongs and how it reaches each harness.

---

## Repository Structure

```text
SharedAgentSkills/
├── skills/            # LINKED to both harnesses
├── skills-claude/     # LINKED to Claude Code only
├── skills-gemini/     # LINKED to Antigravity only
├── rules/
│   ├── AGENTS.md      # neutral baseline - reaches BOTH harnesses
│   ├── CLAUDE.md      # Claude Code only
│   └── GEMINI.md      # Antigravity only
├── docs/              # NEVER LINKED - human-facing guidance
├── .agents/           # NEVER LINKED - rules for editing THIS repository
├── .claude/           # NEVER LINKED - Claude adapter for the above
├── tools/
│   ├── validate_skills.py   # frontmatter, naming, no-model-names, size caps
│   └── sync_stubs.ps1       # regenerate a project repo's .claude/ stubs
├── setup.ps1          # idempotent bootstrap; -DryRun and -Prune
└── sync.ps1           # git pull --ff-only, then setup.ps1
```

> [!IMPORTANT]
> `.agents/`, `.claude/`, `docs/`, and `.plans/` are **never** linked, copied, or
> inlined into any harness configuration. Only `skills/`, `skills-claude/`,
> `skills-gemini/`, and `rules/` are distributed.

### The placement matrix

|  | Both harnesses | Claude Code only | Antigravity only |
|---|---|---|---|
| **Always-on rules** | `rules/AGENTS.md` | `rules/CLAUDE.md` | `rules/GEMINI.md` |
| **Triggered skills** | `skills/` | `skills-claude/` | `skills-gemini/` |

---

## Installation

### Windows

```powershell
.\setup.ps1
```

Preview without writing anything:

```powershell
.\setup.ps1 -DryRun -Prune
```

`setup.ps1`:

1. Creates NTFS junctions from each source directory into the harness
   directories it is routed to (`~/.claude/skills/`,
   `~/.gemini/config/skills/`), and junctions `rules/` into `~/.claude/rules`.
2. Regenerates the marked region of `~/.claude/CLAUDE.md` to import
   `@rules/AGENTS.md` and `@rules/CLAUDE.md`, backing the file up first, and
   asserts exactly one marked region survives.
3. Inlines `rules/AGENTS.md` followed by `rules/GEMINI.md` into
   `~/.gemini/config/AGENTS.md` between the same markers, preserving anything
   outside them.
4. With `-Prune`, removes junctions pointing at skills of this repository that no
   longer exist (after a rename or deletion). Scoped to targets under this
   repository, so nothing installed from elsewhere is touched.

### Linux / macOS

```bash
mkdir -p ~/.claude/skills ~/.gemini/config/skills
for d in skills/*/ skills-claude/*/; do ln -s "$(pwd)/${d%/}" ~/.claude/skills/; done
for d in skills/*/ skills-gemini/*/; do ln -s "$(pwd)/${d%/}" ~/.gemini/config/skills/; done
ln -s "$(pwd)/rules" ~/.claude/rules
```

Then add `@rules/AGENTS.md` and `@rules/CLAUDE.md` to `~/.claude/CLAUDE.md`, and
inline `rules/AGENTS.md` + `rules/GEMINI.md` into `~/.gemini/config/AGENTS.md`.

---

## Live vs. copied

> [!WARNING]
> **Everything Claude Code reads is live. Antigravity's *rules* are a copy.**
>
> Skills reach both harnesses by junction, so editing a file inside an existing
> skill takes effect immediately, on every session, before any commit.
>
> `rules/AGENTS.md` and `rules/GEMINI.md` reach Antigravity as an **inlined
> copy**. Antigravity keeps reading the previous text until `setup.ps1` or
> `sync.ps1` runs again. This is the most common source of "why is Gemini
> ignoring my rule".
>
> Adding, renaming, or deleting a skill directory also needs a re-run — with
> `-Prune` for a rename or deletion.

---

## Updating

```powershell
.\sync.ps1
```

Fast-forward pull, then re-runs `setup.ps1` so junctions are repaired and the
inlined rules are refreshed.

---

## Contributing

1. **Placement** — pick a cell from the matrix above. The two tests are in
   [docs/ai-skill-management.md](docs/ai-skill-management.md); the precedents for
   harness-specific content are in
   [docs/harness-matrix.md](docs/harness-matrix.md).
2. **Naming** — kebab-case directory matching `^[a-z0-9]+(-[a-z0-9]+)*$`; `name:`
   in the frontmatter must equal the directory. Prefix `agent-` for shared,
   `claude-` / `gemini-` for harness-specific.
3. **Description** — 40 to 1024 characters, written to describe **trigger
   conditions**. It is what both harnesses index to decide whether to load the
   skill.
4. **No model names.** Tiers are roles, resolved by each session against the
   models it actually offers. The validator rejects concrete model names in
   `skills/` and `rules/`.
5. **Encoding** — UTF-8 without BOM; LF line endings (`.editorconfig`); `.ps1`
   files ASCII-only for Windows PowerShell 5.1.
6. **Validate** before submitting:

   ```powershell
   python tools/validate_skills.py
   ```

   And, for a project repository's pointer stubs:

   ```powershell
   .\tools\sync_stubs.ps1 -Repo C:\path\to\repo -Check
   ```
