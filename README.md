# SharedAgentSkills

Shared rules and skills for AI coding agents across three harnesses on Windows:
**Google Antigravity / Gemini**, **Anthropic Claude Code**, and **OpenAI Codex**.

New here? Read [docs/ai-skill-management.md](docs/ai-skill-management.md) — it is
the guide to where guidance belongs and how it reaches each harness.

---

## Repository Structure

```text
SharedAgentSkills/
├── skills/            # DISTRIBUTED to all three harnesses
├── skills-claude/     # LINKED to Claude Code only
├── skills-gemini/     # REGISTERED with Antigravity only
├── skills-codex/      # LINKED to Codex only
├── rules/
│   ├── AGENTS.md      # neutral baseline - reaches ALL harnesses
│   ├── CLAUDE.md      # Claude Code only
│   ├── GEMINI.md      # Antigravity only
│   └── CODEX.md       # Codex only
├── AGENTS.md          # NEVER INSTALLED - root adapter for this repository
├── docs/              # NEVER LINKED - human-facing guidance
├── .agents/           # NEVER LINKED - rules for editing THIS repository
├── .claude/           # NEVER LINKED - Claude adapter for the above
├── tools/
│   ├── validate_skills.py   # frontmatter, naming, no-model-names, size caps
│   ├── sync_stubs.ps1       # regenerate a project repo's .claude/ stubs
│   └── claude-budget.js     # run BY agents, not on this repo - see claude-usage-quota-budget
├── setup.ps1          # idempotent bootstrap; -DryRun and -Prune
└── sync.ps1           # git pull --ff-only, then setup.ps1
```

> [!IMPORTANT]
> The root `AGENTS.md`, `.agents/`, `.claude/`, `docs/`, and the fallback
> `.plans/` are **never** linked, copied, or inlined into any global harness
> configuration. Only `skills/`, `skills-claude/`, `skills-gemini/`,
> `skills-codex/`, and `rules/` are distributed.

### The placement matrix

|  | All harnesses | Claude Code only | Antigravity only | Codex only |
|---|---|---|---|---|
| **Always-on rules** | `rules/AGENTS.md` | `rules/CLAUDE.md` | `rules/GEMINI.md` | `rules/CODEX.md` |
| **Triggered skills** | `skills/` | `skills-claude/` | `skills-gemini/` | `skills-codex/` |

---

## Installation

### Prerequisite: the shared plans repository

Implementation plans, reviews, and walkthroughs live in the private
[`hyvanmielenpelit/plans`](https://github.com/hyvanmielenpelit/plans) repository, not
inside any project repository. Clone it beside the others:

```powershell
git clone https://github.com/hyvanmielenpelit/plans.git C:\hmp\plans
```

Agents resolve its root as `AGENT_PLANS_ROOT`, else `C:\hmp\plans`, else a `plans`
directory beside the repository being worked on. **Without it, every agent silently falls
back to each repository's gitignored `.plans/`** -- work continues, but the documents stay
on one machine. `setup.ps1` warns when the clone is missing.

### Prerequisite: Python and PyYAML

The validator requires Python and PyYAML. Install PyYAML for the Python you use
to run it if `python -c "import yaml"` fails:

```powershell
python -m pip install --user pyyaml
```

### Codex CLI resolution

Codex desktop bundles its CLI, but a normal terminal may not have `codex` on
`PATH`. Scripts and diagnostics resolve it with `Get-Command codex` first, then
select the newest `%LOCALAPPDATA%\OpenAI\Codex\bin\*\codex.exe`; never hardcode
the versioned directory name. `$CODEX_HOME` means an explicit environment value
when set, otherwise the user's `~/.codex` directory.

### Windows

```powershell
.\setup.ps1
```

Preview without writing anything:

```powershell
.\setup.ps1 -DryRun -Prune
```

`setup.ps1`:

1. Creates NTFS junctions for each shared or harness-specific skill under
   `~/.claude/skills/` and the selected Codex-only user root,
   `$CODEX_HOME/skills/`. It also junctions `rules/` into `~/.claude/rules`.
   For Antigravity, it adds source-directory absolute paths directly to
   `~/.gemini/config/skills.json`.
2. Regenerates the marked region of `~/.claude/CLAUDE.md` to import
   `@rules/AGENTS.md` and `@rules/CLAUDE.md`, backing the file up first, and
   asserts exactly one marked region survives.
3. Inlines `rules/AGENTS.md` followed by `rules/GEMINI.md` into
   `~/.gemini/config/AGENTS.md` between the same markers, preserving anything
   outside them.
4. Inlines `rules/AGENTS.md` followed by `rules/CODEX.md` into
   `$CODEX_HOME/AGENTS.md`, also preserving user-owned text outside the marked
   region. A non-empty `$CODEX_HOME/AGENTS.override.md` shadows that file, so
   setup warns when one exists.
5. Warns when the plans clone is absent from Codex's
   `sandbox_workspace_write.writable_roots` and prints a safe TOML append or
   merge instruction. It never edits `$CODEX_HOME/config.toml`.
6. With `-Prune`, removes junctions pointing at skills of this repository that no
   longer exist (after a rename or deletion). Scoped to targets under this
   repository, so nothing installed from elsewhere is touched.

On Codex, `setup.ps1`, edits below `.agents/`, and Git operations that write a
`.git` directory require an approved escalation: `.git`, `.agents`, and `.codex`
remain protected even inside a configured writable root. A known Windows issue
may also prompt for approval on an otherwise configured writable root; do not
widen access to the parent directory to suppress it.

Codex can write disposable files under `%TEMP%`. Its `apply_patch` operation can
leave a CRLF file with mixed endings, so normalize changed Markdown and
PowerShell files to CRLF afterward. When linking a local document in Codex, use
Markdown with an absolute forward-slash href such as
`[plan](C:/hmp/plans/organization/repository/plan.md)`.

### Linux / macOS

```bash
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
mkdir -p ~/.claude/skills ~/.gemini/config/skills "$CODEX_HOME/skills"
for d in skills/*/ skills-claude/*/; do ln -s "$(pwd)/${d%/}" ~/.claude/skills/; done
for d in skills/*/ skills-gemini/*/; do ln -s "$(pwd)/${d%/}" ~/.gemini/config/skills/; done
for d in skills/*/ skills-codex/*/; do ln -s "$(pwd)/${d%/}" "$CODEX_HOME/skills/"; done
ln -s "$(pwd)/rules" ~/.claude/rules
```

Then add `@rules/AGENTS.md` and `@rules/CLAUDE.md` to `~/.claude/CLAUDE.md`, and
inline `rules/AGENTS.md` + `rules/GEMINI.md` into `~/.gemini/config/AGENTS.md`
and `rules/AGENTS.md` + `rules/CODEX.md` into `$CODEX_HOME/AGENTS.md`. Preserve
text outside the generated markers and back up each target before replacing the
marked region.

---

## Live vs. copied

> [!WARNING]
> **Claude Code's rules are live. Antigravity's and Codex's rules are copies.**
>
> Skills reach Claude Code and Codex by per-skill links, and Antigravity by
> absolute source-directory paths in `skills.json`, so editing a file inside an
> existing skill takes effect without re-running setup.
>
> `rules/AGENTS.md` and `rules/GEMINI.md` reach Antigravity as an **inlined
> copy**. Antigravity keeps reading the previous text until `setup.ps1` or
> `sync.ps1` runs again. Codex has the same boundary for `rules/AGENTS.md` and
> `rules/CODEX.md` in `$CODEX_HOME/AGENTS.md`.
>
> Adding or renaming a skill needs a re-run to create Claude and Codex links;
> Antigravity's existing source-directory registration needs no new entry, though
> a fresh session may be needed for discovery. Use `-Prune` after a rename or
> deletion to remove obsolete links.

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
   `claude-` / `gemini-` / `codex-` for harness-specific.
3. **Description** — 40 to 1024 characters, written to describe **trigger
   conditions**. It is what all three harnesses index to decide whether to load
   the skill.
4. **No model names.** Tiers are roles, resolved by each session against the
   models it actually offers. The validator rejects concrete model names in
   `skills/` and `rules/`.
5. **Encoding** — UTF-8 without BOM; CRLF line endings, except `*.yml`,
   `*.yaml`, and `*.py`, which stay LF for Linux CI; `.ps1` files ASCII-only for
   Windows PowerShell 5.1.
6. **Validate** before submitting:

   ```powershell
   python tools/validate_skills.py
   ```

   And, for a project repository's pointer stubs:

   ```powershell
   .\tools\sync_stubs.ps1 -Repo C:\path\to\repo -Check
   ```
