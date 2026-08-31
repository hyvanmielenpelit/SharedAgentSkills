---
name: gemini-antigravity-conventions
description: >-
  Antigravity Standalone App specifics. Covers delivering plans and reports to the artifact
  directory while copying them to the shared plans repository, adding that directory as a
  project folder, implementing a plan authored in another
  application, resolving an abstract model tier against the models this session offers, the
  boundary that this app can spawn only its own vendor's models, skill discovery and the
  skills.json fallback, why .agents/ is canonical and .claude/ is not, and checking whether
  the inlined global rules have gone stale. Read when planning or implementing here.
---

# Antigravity Conventions

Antigravity Standalone App only. The Claude Code equivalents are in `claude-plan-mode` and
`claude-code-conventions`.

---

## Delivering Plans and Reports

The artifact guidelines say to save extensive reports and analysis summaries to the
artifact directory (`<appDataDir>/brain/<conversation-id>/`). The convention says the
canonical document lives in the shared `plans` repository. **Both receive the file.**

1. **Create the artifact** in the artifact directory, so the UI can present it. This
   happens in every case.
2. **Copy it** to
   `<plans-root>/<organization>/<repository>/YYYY-MM-DD/task_name/<document_name>_v<N>.md`.
3. **Commit the round** in the plans repository, per `agent-implementation-planning`.
4. **Present the artifact and wait for approval** before editing any project file.

> [!IMPORTANT]
> **Steps 2 and 3 apply to tier 1 only.** `agent-implementation-planning` decides the tier
> before you write anything: under **tier 2** the copy goes to the main repository's
> gitignored `.plans/` and nothing is committed; under **tier 3** there is no copy at all
> and the plan lives in the conversation. Step 1 and step 4 are unchanged in all three.

The plans repository is canonical. Other agents -- in other sessions and in the other
application, on other machines -- read revisions from there and never look inside the
artifact directory. The copy also means the document survives a rejection or a lost
session.

### Reaching the plans repository

**Add `C:\hmp\plans` to every project as an additional project folder.** If it was not
added, this application asks for access to the directory the first time it writes there;
granting that prompt is the fix.

> [!CAUTION]
> The grant is for the **plans directory itself**. Never open or grant access to its
> parent -- that holds every repository on the machine plus unrelated data, and an agent
> must not be handed it. A **denied** prompt is not a reason to ask again: it is a
> fallback case -- see `agent-implementation-planning` for which tier applies. A tier 2
> copy goes to the **main** repository's `.plans/`, never to whichever repository happens
> to be writable.

Scope directories, naming, `_v<N>` versioning and harmonization, follow-up rounds, the
commit protocol, the fallback, and the plan template are all in
`agent-implementation-planning`.

---

## Implementing a Plan Authored Elsewhere

This is the common case: plans are frequently written in the other application and
implemented here.

- Read the **latest `_v<N>`** for the specific task you are continuing -- in the plans
  repository first, then the main repository's `.plans/`. Do not browse other task
  directories, do not read another repository's scope, and do not read superseded versions
  unless asked.
- **If the plan is ambiguous, ask rather than improvise.** The planning session's context
  is not recoverable from here, and its author is in a different application. A guess that
  looks reasonable is far more expensive than a question.
- Follow the plan's step order. Regeneration boundaries fall between steps for a reason.
- If you find something requiring significant deviation, stop and re-confirm rather than
  silently diverging from what the user approved.

---

## Resolving a Tier to a Model

`agent-subagent-guidelines` defines the tiers as roles. This is how to resolve them here.

> Tiers are roles, not model names. Resolve them against the models **this session actually
> offers** -- never against a written table, which cannot know what is installed today.

| Tier | Resolve to |
|------|-----------|
| `deep` | A model that can hold a whole subsystem in view and reason about consequences the instructions did not enumerate -- this session's top reasoning tier. |
| `standard` | A capable mid-tier: strong enough to follow an approved plan without supervision, fast enough for routine work. This is the default for well-specified plan steps, and the workhorse here. |
| `mechanical` | The cheapest tier available to the session. |
| `inherit` | Match the orchestrator; omit the override. |

---

## The Spawn Boundary

> [!IMPORTANT]
> **This session can spawn only this application's own models.** Antigravity has no access
> to Claude models, and no configuration makes it so.

A plan whose **Execution Target** names Claude Code is handed over by **a person opening
that application** -- not by spawning a subagent, which is impossible. The plan document in
the plan document is the entire interface.

If asked to hand work to the other application, say plainly that this one cannot, and point
at the Execution Target line as the way to record the intent.

---

## Skill Discovery

- Skills mount from `~/.gemini/config/skills/` at **Global Discovery (Priority 3)**, above
  built-in defaults. Each entry is a junction into the `SharedAgentSkills` working tree, so
  edits to a file inside an existing skill are live immediately.
- **`skills.json` fallback** -- skills may also be declared via `skills.json`, which is
  useful when the repository is cloned inside the home directory, or as a project-level
  `.agents/skills.json` referencing workspace-relative paths. Directory junctions are
  preferred where they work.
- Skills whose names begin with `claude-` are deliberately **not** installed here. They
  describe mechanics this application does not have.

---

## `.agents/` Is Canonical

In a project repository:

- **`.agents/AGENTS.md`** is the project rules file, and **`.agents/skills/`** holds the
  full skill bodies. This is what you read and what you edit.
- **`.claude/`** is an adapter layer for the other application. Its `skills/` entries are
  pointer stubs, not content. **Do not edit them and do not treat them as a source of
  truth.** If a skill body needs changing, change the `.agents/` canonical; the stubs are
  regenerated by a script.

---

## The Inlined Global Rules Can Be Stale

> [!WARNING]
> `~/.gemini/config/AGENTS.md` is a **generated copy** of `SharedAgentSkills/rules/AGENTS.md`
> and `rules/GEMINI.md`, regenerated only when `setup.ps1` or `sync.ps1` runs. It can be
> silently out of date -- the other application reads the same rules through a live link and
> is never affected, which is why this goes unnoticed.

- **Never hand-edit inside the `<!-- BEGIN SharedAgentSkills -->` markers.** The next run
  overwrites it.
- When you are working **inside the `SharedAgentSkills` repository**, compare the region
  between those markers against `rules/AGENTS.md` and `rules/GEMINI.md`, and **tell the user
  to run `.\setup.ps1` if they differ.**
- After any edit to either rules file, say so regardless of whether you can verify the
  inlined copy from where you are.

---

## Scratch Files

Save temporary files and scratch scripts to `<appDataDir>\brain\<conversation-id>\scratch\`.
**Never** write them anywhere inside a repository. Planning documents go to the shared
`plans` repository; the one in-tree exception left is `.plans/`, and only as the fallback
when that repository cannot be reached.

Native file tools are `write_to_file`, `replace_file_content`, and `view_file`. Prefer them
over shell redirection, which produces the wrong encoding and line endings. Full Windows and
PowerShell rules are in `agent-powershell-guidelines`.
