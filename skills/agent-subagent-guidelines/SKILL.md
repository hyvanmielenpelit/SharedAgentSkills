---
name: agent-subagent-guidelines
description: >-
  How to use AI subagents and human pair programming in implementation plans. Covers the
  mandatory Subagent Use plan section, role-based model tiers (deep, standard, mechanical,
  inherit) and how to resolve them at runtime, the difference between within-session
  subagents and cross-application handoff, file-level exclusivity, the strict rule that
  subagents never build, test, lint, or verify -- the orchestrator owns every such
  command and runs it only after all subagents have returned -- build-boundary
  sequencing, the concise comment style every spawn prompt must state, and protecting
  uncommitted changes. Read before assigning work to any subagent or writing a plan's
  Subagent Use section.
---

# Subagent and Pair Programming Guidelines

## Overview

Development is a **pair programming** model. The orchestrating agent works together with
**subagents** for parallelizable work and, rarely, with **the human user** for tasks where
humans clearly outperform agents.

Every implementation plan MUST include a **Subagent Use** section, even when no subagents
are needed -- state "No" and explain why.

> [!IMPORTANT]
> **The harness decides *whether* and *when* subagents may be spawned -- always follow the
> harness.** If it prescribes subagents for a phase, use them. If it forbids or restricts
> them, that restriction wins.
>
> This skill governs only **how** to use them once the harness permits: which tier, which
> agent type, file-level exclusivity, and build-dependency sequencing.

---

## The Mandatory Plan Section

```markdown
## Subagent Use

### Subagents Needed
[Yes / No -- if no, explain why (e.g. "single-file change, not worth the overhead")]

### Subagent Assignments
| Task | Tier | Files | Rationale |
|------|------|-------|-----------|

### Human Assignments (if any)
| Task | Rationale | Fallback if Not Approved |
|------|-----------|--------------------------|
```

When human tasks are listed, the plan MUST explicitly ask the user to approve or reject
each one. If the user rejects a human assignment, the orchestrator handles it directly.

---

## Model Tiers

Tiers are **roles**, named by the property the work needs -- not by vendor, model name, or
relationship to the orchestrator.

| Tier | The property wanted | Use for |
|------|--------------------|---------|
| `deep` | Can hold a whole subsystem in view and reason about consequences the instructions did not enumerate | Planning, architecture, cross-layer and interop design, ambiguous debugging, anything the plan flags as risky or underspecified |
| `standard` | Strong enough to follow an approved plan without supervision; fast enough for routine work | Executing well-specified steps from an approved plan; multi-file edits following existing patterns; routine feature work |
| `mechanical` | Cheapest tier that applies a pre-specified edit accurately | An identical, pre-specified replacement across many files |
| `inherit` | The orchestrator's own capability *and* its accumulated context | When a subagent genuinely needs both, or the harness offers no model override |

### Choosing a tier -- both halves of this rule matter equally

**A well-specified step from an approved plan is `standard` work.** That is the default
for execution-phase subagents, and it is what most plan steps are.

**Escalate to `deep` whenever the step is ambiguous, spans a layer boundary, touches an
interop or serialization contract, or the plan itself flags it as risky.** Neither half is
the footnote. In a repository with a high share of cross-layer work, escalation is the
common case rather than the exception -- check whether the project's own overlay says so.

**Drop to `mechanical` only when the subagent decides nothing** -- it is told exactly what
string to write and only needs to find the places. Any ambiguity, adaptation, or
context-sensitivity means `standard`.

### Resolving a tier to a model

> Tiers are **roles, not model names**. Resolve them against the models **your session
> actually offers** -- never against a written table, which cannot know what is installed
> today. Your harness's own skill states how to do this for your application.

There is deliberately no tier-to-model roster anywhere in the shared skills. A written
roster has no owner, cannot be verified from another application, and goes stale without
anyone noticing.

Plans keep writing the **tier name** in the assignment table. The orchestrator translates
at spawn time.

---

## Two Different Mechanisms

Do not conflate these. A plan that promises the second as if it were the first is
promising something no harness can do.

| Mechanism | What it is | Bounded by |
|-----------|-----------|-----------|
| **Within-session subagents** | The orchestrator spawns helpers inside one application | That application's own model roster. **No application can spawn another vendor's models.** |
| **Cross-application phase handoff** | Plan in one application, implement in the other | **A person opening the other application.** The plan document is the entire interface. |

The **Subagent Use** section governs the first. The second is recorded in the plan's
**Execution Target** line (see `agent-implementation-planning`) and executed by a human.

### Research agents are not what the plan governs

Where a harness prescribes research subagents during planning, those agents are
**read-only** and run *before* the plan exists. They are not covered by the plan's
Subagent Use section and need no user approval -- the harness already authorized them.

The Subagent Use section governs **execution-phase** subagents: the ones that will edit
files after the plan is approved. Those require the user's approval through the plan.

---

## Planning Constraints

### File-level exclusivity (STRICT)

**No two agents -- including the orchestrator -- may edit the same file concurrently.**

- When decomposing for parallel subagents, assign each a **non-overlapping set of files**.
- If two tasks touch the same file, they must be **sequenced**, not parallelized.
- The orchestrator must not edit a file a subagent is also editing.

### Build dependency chains

Some work is inherently sequential because one step's output is the next step's input --
code generators, migrations, stylesheet compilers, client bundlers. The plan must identify
these chains and **not parallelize across them**. A regeneration boundary falls *between*
plan steps, never inside one.

**The orchestrator executes every regeneration step itself**, at the boundary, once the
subagents working on the preceding step have all returned. A subagent never runs one --
see the next section.

The specific chains are project-specific: consult the repository's own planning skill for
its Build Impact section.

### Plans isolation (STRICT)

**Subagents must NOT read files in the plans repository, or in any `.plans/` fallback**,
unless the orchestrator provides a specific file path and instructs them to read it -- and
never a path outside the current task's directory. Pass the relevant plan context **in the
subagent's prompt** instead. Old and superseded plans corrupt a subagent's understanding of
its task, and the shared store now puts other repositories' plans one directory away.

### Subagents never build, test, or verify (STRICT)

> [!CAUTION]
> **A subagent does not run a build, a test suite, a linter, a code generator, a
> migration, or any other command whose purpose is to produce artifacts or to check that
> the work is correct. The orchestrator runs all of them, itself, after every subagent in
> the round has returned.**

A subagent **writes** code -- including test code, build files, and generator inputs. It
never **runs** the toolchain over them.

Why this is flat rather than a matter of judgement:

- **Parallel builds collide.** Two agents invoking the same toolchain share output
  directories, lock files, caches, and package restores. The failures that produces look
  like code defects and are not.
- **A subagent cannot know the order.** Regeneration boundaries fall *between* plan
  steps. A subagent that builds right after its own edit builds a tree in which some
  other agent's half of the change does not exist yet, then reports a breakage the round
  was always going to resolve two steps later.
- **A subagent cannot know when the round is finished.** This is the same reason it may
  not commit: it sees its own files, not the round.
- **Green from a subagent means nothing.** It was measured against a tree that no longer
  exists by the time the orchestrator reads the report.

What the subagent does instead:

1. Make its file edits.
2. **Report** what it changed, anything it could not resolve, and any build, regeneration,
   or test step its change now requires.
3. Stop. It does not iterate against a compiler or a test run until things go green.

**Say it in the spawn prompt.** A subagent will otherwise reach for a build to check its
own work, because that is ordinarily good practice. Every spawn prompt must state that
the subagent must not build, test, or lint, and must report instead.

Reading stays unrestricted: file reads, searches, `git status`, `git diff`, and inspecting
build output that already exists are all fine. The prohibition is on **executing** the
toolchain.

### Subagents never commit (STRICT)

> [!CAUTION]
> **A subagent does not run `git commit` or `git push`. Not in a project repository, not
> in the plans repository, not anywhere.**

State it flatly rather than as a delegation detail: a subagent handed a file-writing task
has no way to know whether its orchestrator has already committed the round, or is about
to. The orchestrator owns the round and makes its single commit after every subagent has
returned.

The wider rule -- that the `plans` repository is the **only** repository any agent may
commit or push to, and that committing is forbidden everywhere else -- is in
`agent-implementation-planning`.

### Comment style in subagent output (STRICT)

**Every spawn prompt must state the comment rule**, the same way it states the build
prohibition: comments describe the code as it now stands, concisely, and never narrate the
change or the reason for it -- that goes in the commit description the orchestrator writes
into the walkthrough. The rule itself is in `agent-implementation-planning`.

Say it explicitly even though it is a baseline rule. A subagent is the likeliest source of
change-narrating comments in the whole round: its entire task description is *a change*,
its output is not reviewed by the other subagents, and explaining itself in the file is
how it signals that it did the work it was asked to do.

### Communication overhead

For work that takes under about 30 seconds to do directly, spawning a subagent is slower
because of setup and message-passing latency. Do those yourself.

### Protecting uncommitted changes (STRICT)

**No agent may overwrite uncommitted changes in a file without explicit user permission.**
This includes restoring a file to an earlier repository version, regenerating contents
from scratch, or any operation that discards prior edits.

Before editing, consider whether uncommitted changes exist. If the planned work risks
corrupting or losing them:

1. The **subagent** reports the risk to the **orchestrator**.
2. The **orchestrator** asks the user either to **commit first** (preferred), or to
   **explicitly approve** proceeding with the understanding that changes may be lost.
3. Only after approval does the agent proceed.

This applies equally to user-made and agent-made changes, since the two cannot always be
distinguished.

---

## Human Pair Programming Tasks

### When to assign to the human

Assigning work to the human is the **rare exception**. The main case:

**Very extensive cut-and-paste (move) operations.** Agents struggle with large moves
because they require coordinating a deletion in one location with an insertion in another,
potentially across files. When the block is large, the agent is likely to get it wrong and
waste significant tokens retrying. A human does it atomically in an editor.

**Assign to the human when**: a large block (50+ lines) must be *relocated*, especially
across files, **and** agent failure is likely enough that retries would cost more than the
handoff.

> [!IMPORTANT]
> For small moves, simple find-and-replace, or anything an agent handles reliably, the
> orchestrator or a subagent does the work -- not the human. The threshold is high.

### Fallback when the human declines

The orchestrator handles it directly.

---

## Example Subagent Use Section

```markdown
## Subagent Use

### Subagents Needed
Yes -- the task spans 8 files across 3 components with no shared files between groups.

### Subagent Assignments
| Task | Tier | Files | Rationale |
|------|------|-------|-----------|
| Add the same feature-flag constant to all platform config headers | mechanical | `config/a.h`, `config/b.h`, `config/c.h` | Identical pre-specified line; the subagent decides nothing |
| Implement the new repository method and its tests | standard | `Data/ThingRepository.cs`, `Tests/ThingRepositoryTests.cs` | Well-specified step following an existing pattern |
| Extend the serialization contract across the interop boundary | deep | `include/contract.h`, `Client/Interop.cs` | Cross-layer, and a versioned contract: consequences are not enumerable in advance |

### Human Assignments
None -- no large relocation operations.
```

The second row **writes** the test file; it does not run it. The orchestrator runs the
suite, the build, and the linters once all three subagents have returned.
