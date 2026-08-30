---
name: claude-code-conventions
description: >-
  Claude Code specifics for subagents and project skill wiring. Covers resolving an
  abstract model tier against the models this session offers, the boundary that Claude Code
  can spawn only Claude models and cannot reach another vendor's, agent types Explore and
  Plan and general-purpose versus model tier, and the .claude/skills pointer-stub contract
  where the stub description is what Claude Code indexes for triggering. Read before
  spawning a subagent or adding a skill to a project repository.
---

# Claude Code Conventions

Claude Code only. The Antigravity equivalents are in `gemini-antigravity-conventions`.

---

## Resolving a Tier to a Model

`agent-subagent-guidelines` defines the tiers as roles. This is how to resolve them here.

> Tiers are roles, not model names. Resolve them against the models **this session
> actually offers** -- never against a written table, which cannot know what is installed
> today.

| Tier | Resolve to |
|------|-----------|
| `deep` | A model that can hold a whole subsystem in view and reason about consequences the instructions did not enumerate. In practice this session's top reasoning tier (currently the Opus family). |
| `standard` | A capable mid-tier: strong enough to follow an approved plan without supervision, fast enough for routine work. |
| `mechanical` | The cheapest tier available to the session. |
| `inherit` | **Omit the model override entirely** so the subagent matches the orchestrator. |

The parenthetical above is a hint, not the instruction. The instruction is the property.
If the roster has changed, the property still selects correctly and the hint does not.

---

## The Spawn Boundary

> [!IMPORTANT]
> **This session can spawn only Claude models.** Claude Code has no access to Gemini
> models, and no configuration makes it so.

A plan whose **Execution Target** names Antigravity is handed over by **a person opening
that application** -- not by spawning a subagent, which is impossible. The plan document
in the plans repository is the entire interface between the two.

If asked to hand work to the other application, say plainly that this
application cannot spawn another vendor's models, and point at the Execution Target line
as the way to record the intent for whoever opens the other application. Do not silently
substitute a Claude model and report it as done, and do not claim a handoff occurred.

---

## Agent Type vs. Model Tier

**Type and tier are independent axes.** The tier is *how capable* the subagent is; the
type is *what it is allowed to do*. Pick both.

| Agent type | Use for | Can edit files? |
|------------|---------|-----------------|
| `Explore` | Read-only fan-out search -- locating code across many files or naming conventions | No |
| `Plan` | Design work -- producing an approach from research already gathered | No |
| `general-purpose` | Execution -- the multi-file changes an approved plan calls for | Yes |

A plan's Subagent Assignments table names the **tier**; name the **type** as well.

---

## The `.claude/skills/` Pointer-Stub Contract

Project repositories keep AI configuration in a tool-neutral `.agents/` directory so other
agents can be pointed at the same files. `.claude/` is a thin adapter over it.

- **Canonical bodies** live in `.agents/skills/<underscore_name>/SKILL.md`.
- **Each one needs a matching stub** at `.claude/skills/<kebab-name>/SKILL.md`, which
  exists purely so Claude Code discovers and triggers the skill. A canonical with no stub
  **can never fire in Claude Code**.
- Skill bodies cross-reference each other by the underscore folder name. That is correct
  and refers to the canonical file.

> [!IMPORTANT]
> **The stub's `description` is what Claude Code indexes for triggering.** A canonical
> whose description changes without its stub being regenerated will trigger on stale
> wording, or stop triggering. The body is never duplicated -- only the frontmatter.

**Regenerate stubs; never hand-edit them:**

```powershell
C:\hmp\SharedAgentSkills\tools\sync_stubs.ps1 -Repo <path-to-repo>
```

```powershell
C:\hmp\SharedAgentSkills\tools\sync_stubs.ps1 -Repo <path-to-repo> -Check
```

`-Check` reports canonicals with no stub, stubs with no canonical, and stale descriptions,
exiting non-zero instead of writing.

---

## Scratch Files

Claude Code has no `brain/` directory. Use the session scratchpad directory Claude Code
reports in its own environment. **Never** write temporary files, scratch scripts, or
guidance files anywhere inside a repository.

Planning documents no longer live in-tree either: they go to the shared `plans`
repository. The one in-tree exception left is `.plans/`, and only as the **fallback** when
that repository cannot be reached -- not as a home. See `agent-implementation-planning`.

### Reaching the plans repository

The plans root sits outside the project directory, so a session needs it granted:

- **Committed, per repository:** `.claude/settings.json` with
  `"permissions": { "additionalDirectories": ["../plans"] }`. This grants the plans
  directory specifically and nothing above it -- never grant the parent that holds every
  repository on the machine.
- **One-off:** `/add-dir` in the session.
- **Refused or unavailable:** that is a fallback case. Write to the working repository's
  `.plans/`, say so in chat, and record the intended scope in the document.
