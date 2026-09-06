@../.agents/AGENTS.md

## Claude Code

> [!CAUTION]
> **`.claude/` and `.agents/` in this repository are never installed anywhere.**
> They configure agents *editing this repository*. `setup.ps1` links only
> `skills/`, `skills-claude/`, `skills-gemini/`, and `rules/`. Moving a file out
> of one of those into here silently uninstalls it from every machine; adding a
> maintenance note to one of those turns it into a globally-triggering skill in
> every project.

The repository rules live in `.agents/AGENTS.md`, imported at the top of this
file. Edit them there, not here. This file exists so Claude Code picks them up.

- **This repository is CRLF**, like every other repository here. Claude Code's
  `Write` tool emits LF, so a file it creates or rewrites needs converting before
  you hand the work back. The exceptions are `.github/workflows/*.yml` and
  `tools/*.py`, which stay **LF** because GitHub Actions runs them on Linux.
  Check before writing, and never use `grep`, `head`, or `file` to detect line
  endings — Git Bash strips CR silently.
- **You are editing the globally installed skills.** `~/.claude/skills/*` are
  junctions into this working tree, and `~/.gemini/config/skills.json` points to it, so an edit to
  a file inside an existing skill is live for every session on this machine
  immediately — before any commit. What is *not* live: new or renamed skill
  directories (need `setup.ps1`), and `rules/AGENTS.md` / `rules/GEMINI.md` for
  Antigravity, which receives an inlined copy.
- **Pushing is what shares the change with other developers.** Because a local
  edit already works for you, it is easy to forget. Do not commit or push unless
  the user asks.
- **No model names.** Do not write a tier-to-model table. See `.agents/AGENTS.md`.

Before handing work back: `python tools/validate_skills.py`.
