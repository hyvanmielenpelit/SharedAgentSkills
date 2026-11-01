---
name: agent-developer-runbook
description: >-
  How an AI agent hands a person everything its finished work still leaves for them: manual
  tests, device checks, builds only a person can run, issues to file, other developers to brief,
  and checks that can only happen later. Covers the Developer Runbook document, its At a Glance
  table, step cards and test sessions, the fixed Runbook status table in the walkthrough, its
  states, recording a person's result, and listing every open step across tasks with
  Get-OpenRunbookSteps.ps1. Read when writing a plan's manual verification, before reporting work
  as finished while a person still has something to do, when the user asks which tests are pending
  or what to test next, and when the user reports a test result.
---

# Developer Runbook

The work is finished, the agent has built and tested what it can, and something is left that only
a person can do. Without a fixed home, those steps end up in a chat message, in a differently
named walkthrough section each time, or in an agent's private memory, where nobody finds them
again. A **Developer Runbook** gives them one document per task, and its status table gives them
one place to be listed from.

> [!IMPORTANT]
> **A project's own skills override this one wherever they differ.** A project names its step kinds
> and its `Where` values, may replace the format for a specialized kind of work, and may say that it
> does not use runbooks for some of its work or does not use the lister at all. This skill holds the
> method, and it is what applies where a project says nothing more.

---

## When a Runbook Is Required

Write one whenever the work leaves a person **anything beyond the commit**.

| Situation | Runbook |
|-----------|---------|
| A plan's work needs a manual test, a device, a person-only build, a filing, a handoff or a later check | **Yes**, written with the plan, a member of its document set |
| A fix made with no plan needs any of those | **Yes**, in a task directory of its own with a short `walkthrough.md`, unless the user reports the result in the same session |
| The only thing left is the commit | **No.** The walkthrough's commit description already covers it |
| The agent can run the check itself | **No.** It belongs in the plan's Automated verification |

---

## Rules

- **One list, in the order of doing.** Everything the person does is one entry of one list. The
  position of an entry is its dependency order, and `Needs` names what must be finished first.
- **Only what an agent cannot do.** A build, test or deploy the agent can run is the agent's job.
  One exception: a step the agent expects to run itself but that can fail for reasons outside its
  control, such as a deploy to a device that may be asleep, is listed so that the failure has a
  home. The agent then records it `done`, or leaves it for the person.
- **For a reader who has opened nothing else.** A step that needs the content of another document
  repeats it. Paths are absolute, UI labels are verbatim, and commands sit in their own fenced
  blocks.
- **Only the person's report makes a check pass.** An agent records a result the person gave it. It
  never marks a person's check `done` from its own inference.
- **The runbook says what to do; the status table says what happened.** Results never go in the
  runbook, which is versioned and not edited once written.
- **Private agent memory is not the record.** A memory note may point at a task. The status lives
  in the table.

---

## When Each Document Is Written

| Moment | Document |
|--------|----------|
| With the plan | `developer_runbook_v<N>.md`, a member of the document set |
| **When the agent's own work ends, before the first step is handed over** | `walkthrough.md` with its status table. Results arrive after this, sometimes weeks after |
| When the person reports a result | The status rows, and nothing else |
| A plan revision changes a step after the walkthrough exists | The next `_v<N>` of the set, and the status table in the same commit |
| A plan is abandoned after its runbook was written | A short walkthrough saying so, with every row `waived`: otherwise it stays in the list as planned |

---

## The Document

`developer_runbook_v<N>.md` in the task directory, beside the plan. A follow-up round's is
`developer_runbook_A_v<N>.md`. It is an ordinary versioned document: revise it only when a step's
content changes, and bump the set when you do.

```markdown
# Developer Runbook: <what the work was>

Plan: `implementation_plan_v<N>.md`, or "No plan: <one-line description of the fix>".
What this changed, in two lines, and what the steps below establish.

## At a Glance

| ID | Kind | Where | What | Needs |
|----|------|-------|------|-------|
| S1 | DEPLOY | Test device | Put the build on the device | - |
| M1 | TEST | Test device | The new button opens the menu | S1 |
| M2 | TEST | Test device | The old shortcut still works | S1 |
| S2 | COMMIT | Git | Commit the change | - |

## Steps

### S1 -- DEPLOY: Put the build on the device
...

### TEST: Test device (M1-M2)
...

### S2 -- COMMIT: Commit the change
...
```

**IDs.** Steps are `S1`, `S2` and so on, each under a `### S<n> -- <KIND>: <title>` heading. Checks
are `M1`, `M2` and so on, each in a session's table. IDs are unique within one round, and a result
names the task, its round if it has one, and the ID. `At a Glance` has **one row per ID**, in the
order of doing, and a test session has no ID or row of its own: its checks have them.

**Kinds and `Where`.** Kinds are capitalized and come from the project's list. With no project list,
use `BUILD`, `DEPLOY`, `TEST`, `HANDOFF`, `COMMIT`, `WATCH` and `AGENT`. `Where` is the device or
place, spelled the same way every time, because the list groups and filters on it.

### The step card

One step is one action in one place with one expected result. If it needs "and then" to reach a
different result, it is two steps.

```text
### S<n> -- <KIND>: <imperative title>
- Who: You | <another named role> | A new agent session opened on <absolute path>
- Needs: S<k> finished (or: nothing)
- Where: <exact place: device, application and UI path, or absolute directory and shell>
- Do: <numbered actions, labels verbatim, or the exact command in a fenced block>
- Expect: <what appears when it worked: a message, a count, a line of output>
- If not: <the one thing to do, usually: stop and tell the agent what you see>
- Takes: <rough time, and cost when the step spends money>
```

### The test session

Checks that share a device and a setup are one session, so a long test list does not need one card
per check.

```text
### TEST: <Where> (M<a>-M<b>)
- Who: You
- Needs: <the steps that put the build in place>
- Setup: <the build, the starting state, anything to prepare>

| ID | Do | Expect |
|----|----|--------|
| M1 | <press this, in this place> | <what is visible when it passed> |

- If a check fails: <what to capture: a log path, a screenshot; then tell the agent the ID>
```

Every `Expect` is observable. "It works" is not an expectation; "the menu opens with Save first" is.
Include what should still work next to the change.

---

## The Runbook Status Table

The walkthrough carries the status, because `walkthrough.md` is the singular, editable document of
the round. It has this section **exactly**, as one unbroken table, because a tool parses it:

```markdown
## Runbook status

| ID | Kind | Where | What | State | Date | Note |
|----|------|-------|------|-------|------|------|
| S1 | DEPLOY | Test device | Put the build on the device | done | 2026-11-01 | <the version it put there> |
| M1 | TEST | Test device | The new button opens the menu | failed | 2026-11-02 | Opens the old menu |
| M2 | TEST | Test device | The old shortcut still works | remaining | | |
| S2 | COMMIT | Git | Commit the change | remaining | | |
```

Every ID of `At a Glance` has exactly one row with the same `Kind` and `Where`, and the table has no
other rows. Write a literal `|` in a cell as `\|`.

| State | Open? | Meaning | Who sets it |
|-------|-------|---------|-------------|
| `remaining` | Open | Not done yet | The agent, when its own work ends |
| `failed` | Open | Tried; did not meet `Expect`. The note says how | The person's report |
| `blocked` | Open | Cannot be done now. The note says what it waits for | Either |
| `done` | Closed | Done, and met `Expect` | The person's report, or the agent for a step it ran itself |
| `waived` | Closed | Deliberately not done. The note says the user decided it, and why | **The user's decision only** |
| `superseded` | Closed | Replaced. The note names the round or task that replaced it | The agent |

Values that became known during execution, such as a version or a commit, go in the `Note`.

**A failed check stays `failed`** until something closes it. Its fix is a follow-up round or a new
task with its own runbook, and then the old row becomes `superseded`, naming the replacement.

---

## Recording a Result

When the person reports results, in any words:

1. Find the task and round. If they did not name them, list the open steps below and match. If the
   same ID is open in two rounds, ask.
2. Pull the plans repository, edit the rows in that round's walkthrough, and set `State`, `Date` and
   `Note`.
3. Commit and push in the plans repository under its usual protocol, with the message
   `<scope>: runbook status for <task_name>`. A result is a round of its own, one commit per report,
   and it does not bump any `_v<N>`. The walkthrough may be another session's: that is expected here.
4. Run the lister with `-Task <task_name>` and say what is still open for that task.

If the report does not match the runbook, for example a check that was run differently, say so and
ask rather than choosing a state.

---

## Listing Open Steps

Pull the plans repository first, so the list includes other sessions' and developers' results, then:

```powershell
& C:\hmp\SharedAgentSkills\tools\Get-OpenRunbookSteps.ps1 -Scope <organization>/<repository>
```

The path is wherever `SharedAgentSkills` is checked out. `-Where <text>` keeps the steps whose `Where`
contains the text, `-Kind <KIND>` keeps one kind, and `-Task <text>` keeps the tasks whose name
contains the text. Run this whenever the user asks what is pending, unless the project's skills say
it does not use the lister, and show the result as it is, with its links.

The output is grouped by `Where`, oldest task first, and a follow-up round's task reads `<task> (A)`.
A runbook with no walkthrough is listed apart as planned, because its steps have no status yet. A
filter reports what it left out, including the other `Where` and `Kind` values, so a misspelled value
shows up there.

Exit code 1 and `ERROR:` lines mean something could not be trusted, so **a step may be missing from
the list**. Fix what it names, or say that the list is incomplete. Exit code 2 means the script could
not run: no plans repository, or no such scope.

Running the lister is allowed during research. It is status, not plan content, so it does not weaken
plans isolation. Do not use it as a reason to read the runbooks it names unless you are working on
their steps.

**A location other than the plans repository.** Under the `.plans/` fallback the same files are
written there, nothing is committed, and the lister does not see them: say so when handing over.
Where a plan stays in the chat, the runbook does too, and it does not survive the session.

---

## Handing Over

The message that reports the finished work repeats the `At a Glance` table in short form, one line
per ID, after the links to the documents. Report the state honestly: "implemented, M1-M9 pending",
never "verified", until the person's results say so.

---

## Self-Check

- [ ] Every action left to a person is exactly one entry of the list, and none lives only in a chat
      message, another document or a private memory.
- [ ] Nothing in the list is something the agent could have done, unless it is listed so that a
      failure has a home.
- [ ] Every step has `Who`, `Needs`, `Where`, `Do`, `Expect` and `If not`; every session has `Setup`.
- [ ] Every `Expect` is observable.
- [ ] Every path is absolute and exists; every label was checked against its source.
- [ ] The walkthrough and its status table exist before the first step is handed over, and the lister
      reports no error for the task.
- [ ] The message reporting the work says what is still open.

## Related Skills

- **`agent-implementation-planning`** -- document sets, versioning, the plans repository, the
  commit protocol, and the walkthrough that carries the status table
- The project's own runbook skill, when it has one: its step kinds and `Where` values
