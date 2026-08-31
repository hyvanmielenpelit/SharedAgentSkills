---
name: claude-plan-mode
description: >-
  Claude Code plan mode mechanics and how they reconcile with the shared plans
  repository. Covers the harness plan file, copying the finished plan there before
  calling ExitPlanMode, why that copy is permitted while plan mode restricts editing,
  the additionalDirectories prerequisite and /add-dir, when the round is committed,
  in-place editing versus _v<N> versioning, reporting the plan as a clickable link rather
  than a bare path, the Explore and Plan research agents, and what "concise" means inside
  a mandatory plan format. Read when planning under Claude Code.
---

# Claude Code Plan Mode

Claude Code only. Antigravity has no plan mode; its equivalent artifact workflow is in
`gemini-antigravity-conventions`.

This skill covers **how Claude Code's plan mode reconciles with the shared plans
repository**. The plan
lifecycle, document format, naming, and versioning are in
`agent-implementation-planning`; the project's own build boundaries are in its planning
skill.

---

## The Conflict

Plan mode restricts editing to its own plan file, `~/.claude/plans/<slug>.md`. The
convention says the canonical document lives in the shared `plans` repository. **The
harness wins** -- and both are satisfiable.

## The Resolution

1. **Write** the plan to the harness plan file. **In-place editing of that file is
   expected and does not violate the `_v<N>` rule** -- versioning binds to the plans
   repository copy only.
2. **Copy** the finished plan to
   `<plans-root>/<organization>/<repository>/YYYY-MM-DD/task_name/implementation_plan_v<N>.md`
   -- **before** asking for approval, not after. Creating the task directory is part of
   this step.
3. **Commit the planning round** in the plans repository, per
   `agent-implementation-planning`. This happens **after** the copy and **before**
   `ExitPlanMode`, so the plan is already shared when you ask for approval.
4. **Post a clickable link to the plans repository copy**, with an **absolute** href --
   a relative one into the plans root does not reliably resolve -- plus both paths in
   plain text and a brief summary, not the full document. A bare path is not a report;
   the link mechanism is in `claude-code-conventions` (Linking a Document the User
   Should Open).
5. **Request approval with the `ExitPlanMode` tool.** Do not ask "is this plan okay?" in
   chat text; that is what the tool is for.
6. **On approval**, create `task.md`, execute, and finish with `walkthrough.md`.

> [!IMPORTANT]
> **Steps 2 and 3 apply to tier 1 only.** `agent-implementation-planning` decides the
> tier before you write anything:
>
> - **Tier 2** (gitignored `.plans/`): the copy goes there instead, and **nothing is
>   committed** -- the commit carve-out belongs to the plans repository alone.
> - **Tier 3** (chat only): there is no copy and no commit. Call `ExitPlanMode` with the
>   plan in the conversation, which is the harness working exactly as designed.
>
> The harness plan file is written the same way in all three cases.

> [!IMPORTANT]
> **For tier 1, the plans root must be reachable from this session.** It sits outside the
> project directory, so it needs `permissions.additionalDirectories` in the repository's
> `.claude/settings.json` (committed, `"../plans"`), or `/add-dir` for a one-off session.
> If neither is available and the write is refused, drop to tier 2 or 3 and **say so**.

> [!NOTE]
> **Why step 2 is allowed during plan mode.** Plan mode's restriction exists to keep the
> agent from changing the *project* before the user approves the work. Copying the
> planning artifact to its canonical location touches no source file, build file, or data
> file. Everything that would actually change the project still waits for approval.
>
> The plans repository is the source of truth because other agents -- in other sessions
> and other applications, on other machines -- read revisions from there and never look
> inside `~/.claude/`. The copy also means the document survives a rejection or a lost
> session.

---

## Versioning Is Per-Location

| Location | Naming | Revising |
|----------|--------|----------|
| `~/.claude/plans/<slug>.md` | Whatever the harness assigns | Edit **in place** |
| Plans repository (or a `.plans/` fallback) | `<document_name>_v<N>.md` | **Never overwrite** -- increment |

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
