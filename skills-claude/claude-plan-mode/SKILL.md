---
name: claude-plan-mode
description: >-
  Claude Code plan mode mechanics and how they reconcile with the .plans/ directory.
  Covers the harness plan file, copying the finished plan to .plans/ before calling
  ExitPlanMode, why that copy is permitted while plan mode restricts editing, in-place
  editing versus _v<N> versioning, the Explore and Plan research agents, and what
  "concise" means inside a mandatory plan format. Read when planning under Claude Code.
---

# Claude Code Plan Mode

Claude Code only. Antigravity has no plan mode; its equivalent artifact workflow is in
`gemini-antigravity-conventions`.

This skill covers **how Claude Code's plan mode reconciles with `.plans/`**. The plan
lifecycle, document format, naming, and versioning are in
`agent-implementation-planning`; the project's own build boundaries are in its planning
skill.

---

## The Conflict

Plan mode restricts editing to its own plan file, `~/.claude/plans/<slug>.md`. The
`.plans/` convention says the canonical document lives in the repository. **The harness
wins** -- and both are satisfiable.

## The Resolution

1. **Write** the plan to the harness plan file. **In-place editing of that file is
   expected and does not violate the `_v<N>` rule** -- versioning binds to the `.plans/`
   copy only.
2. **Copy** the finished plan to
   `.plans/YYYY-MM-DD/task_name/implementation_plan_v<N>.md` -- **before** asking for
   approval, not after. Creating the task directory is part of this step.
3. **Print** both paths in chat, plus a brief summary -- not the full document.
4. **Request approval with the `ExitPlanMode` tool.** Do not ask "is this plan okay?" in
   chat text; that is what the tool is for.
5. **On approval**, create `task.md`, execute, and finish with `walkthrough.md`.

> [!NOTE]
> **Why step 2 is allowed during plan mode.** Plan mode's restriction exists to keep the
> agent from changing the *project* before the user approves the work. Copying the
> planning artifact to its canonical location touches no source file, build file, or data
> file. Everything that would actually change the project still waits for approval.
>
> `.plans/` is the source of truth because other agents -- in other sessions and other
> applications -- read revisions from there and never look inside `~/.claude/`. The copy
> also means the document survives a rejection or a lost session.

---

## Versioning Is Per-Location

| Location | Naming | Revising |
|----------|--------|----------|
| `~/.claude/plans/<slug>.md` | Whatever the harness assigns | Edit **in place** |
| `.plans/` | `<document_name>_v<N>.md` | **Never overwrite** -- increment |

---

## Research Agents Under Plan Mode

Plan mode prescribes `Explore` agents for research and a `Plan` agent for design. Follow
the harness on whether and when to spawn them.

Those agents are **read-only and run before the plan exists**. They are *not* covered by
the plan's mandatory **Subagent Use** section and need no user approval -- the harness
already authorized them. The Subagent Use section governs execution-phase agents, the ones
that edit files after approval.

`agent-subagent-guidelines` governs only *how*: which tier, which agent type, and
file-level exclusivity.

---

## What "Concise" Means Here

Plan mode asks for a plan "concise enough to scan quickly". That means **no excessive
verbosity within the mandatory format** -- not a smaller format. Keep every mandatory
section; keep each one tight. Never trim the Affected Files table.

For genuinely trivial work, the harness's own concise form (or no plan at all) is
acceptable. Say in chat that the shortcut was taken because the task was trivial, and
produce the full format as the next revision if the user asks.
