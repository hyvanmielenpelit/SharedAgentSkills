---
name: codex-conventions
description: >-
  Codex-specific conventions for delivering and implementing plans, resolving subagent
  tiers and roles, requesting sandbox escalations, discovering skills and project rules,
  linking local documents, and handling scratch files, line endings, and generated global
  instructions. Read when planning, delegating, or implementing repository work in Codex.
---

# Codex Conventions

Codex only. Shared plan structure and storage rules remain in
`agent-implementation-planning`; shared delegation guidance remains in
`agent-subagent-guidelines`.

---

## Delivering a Plan in Default Mode

Default mode is the normal mode for a plan that must enter the shared lifecycle.

1. Decide the storage tier before writing.
2. Finish the canonical plan at that tier.
3. For tier 1, commit and push the complete planning round in the plans repository. These
   Git operations require an approved sandbox escalation in Codex.
4. Report every document as a canonical clickable link and give its full path.
5. Request approval and stop. Do not mutate project files before approval.

If the plans-repository commit or push cannot complete, describe the exact state. A refused
escalation leaves the document uncommitted and must be reported as **not shared**. Do not
move it to `.plans/`: refusal after tier 1 was selected is not a storage fallback.

### Reconciliation after Plan mode

Plan mode is non-mutating. Complete its response with the plan inside a
`<proposed_plan>` block; do not write the canonical file from that mode.

After the user accepts and Codex returns to Default mode, make canonicalization the first
mutation: resolve the storage tier, write the accepted plan to its canonical location, and,
for tier 1, commit and push it through an approved escalation. Only then begin project
changes. Preserve the accepted plan's substance while applying the canonical document
format and versioning rules.

---

## Storage Tiers and Plans-Root Access

`agent-implementation-planning` owns the complete eligibility and path rules. In summary:

| Tier | Storage | Codex behavior |
|------|---------|----------------|
| **1** | Shared plans repository | Use for eligible repository work when the plans root resolves. The canonical document is committed and pushed once per round. |
| **2** | Main repository's gitignored `.plans/` | Use only when tier 1 does not apply and Git confirms `.plans/` is ignored in the main repository. Do not commit it. |
| **3** | Conversation only | Use when neither disk location qualifies. Write the full plan in chat, create no document files, and say it will not survive the session. |

Never substitute the current working repository's `.plans/` for the main repository's
fallback. A push failure after writing to tier 1 is also not a fallback condition.

Grant Codex access to the plans directory itself through
`sandbox_workspace_write.writable_roots`, `--add-dir`, or an app-added workspace folder.
Never grant the parent directory that contains other repositories. On Windows, a configured
writable root may still produce an approval prompt. If write access is denied before the
plan is stored, follow the tier fallback rules instead of widening access or repeatedly
asking.

---

## Protected Paths and Escalation

Within every writable root, `.git`, `.agents`, and `.codex` remain read-only to the Codex
sandbox. Use Codex's `require_escalated` execution path and its user-facing approval prompt
for operations that must write there, including:

- `pull`, `commit`, and `push` in the plans repository;
- edits to a project's `.agents/AGENTS.md` or `.agents/skills/`; and
- other in-scope commands whose required output is blocked by those protected paths.

The user may approve a single invocation or, when the client offers it, persist approval
for a suitably narrow command prefix. Workflow approval does not pre-approve an escalation:
request it immediately before the operation. If approval for a protected project edit is
refused, stop that step and report the blocked operation. Do not bypass the sandbox or
redirect the edit to a different file.

---

## Linking a Local Document

Use the absolute forward-slash Markdown form confirmed to open in the Codex desktop viewer:

```markdown
[implementation_plan_v4.md](C:/hmp/plans/hyvanmielenpelit/SharedAgentSkills/2026-09-18/codex_harness_support/implementation_plan_v4.md)
```

The label is the document name and version; the href is the canonical absolute path. Give
the full path in plain text as well so another session can copy it. Link every document in
the round, not just the plan. If Codex's native open-file action would help the user inspect
the result, use it in addition to this canonical link, never instead of the link.

---

## Implementing a Plan Authored Elsewhere

- Read the latest `_v<N>` for the task from the plans repository first, then from the main
  repository's `.plans/` fallback. Do not browse other scopes or superseded versions unless
  the task requires them.
- Follow the approved step order and regeneration boundaries.
- Ask when an ambiguity materially affects the implementation rather than reconstructing
  context that is not present in the document.
- Stop and re-confirm before a material deviation. Do not silently expand scope or report a
  different implementation as the approved one.

---

## Subagents: Tier, Role, and Spawn Boundary

### Resolve tiers at runtime

Tiers describe capability, not product names. Resolve them only against the models offered
by the current Codex session:

| Tier | Resolve to |
|------|------------|
| `deep` | The session's strongest reasoning option for work requiring subsystem-wide judgment. |
| `standard` | A capable execution option for well-specified implementation work. |
| `mechanical` | The least expensive available option adequate for deterministic work. |
| `inherit` | Match the orchestrator by omitting both model and reasoning overrides. |

Do not commit a tier-to-model roster. Available models and reasoning controls are runtime
facts.

### Keep roles separate from tiers

Codex's built-in roles are `explorer`, `worker`, and `default`. Role is the kind of work;
tier is the capability needed. Select each independently when the active spawning surface
supports both. A client or tool surface may expose model and reasoning overrides without a
role override, so plans must not promise a role the active API cannot select. Use an
available execution-capable interface for implementation assignments.

### Spawn only on an explicit request

Spawn subagents only when the user, an applicable `AGENTS.md`, or a loaded skill explicitly
asks for subagents, delegation, or parallel agent work. General permission to implement a
task is not enough.

An approved implementation plan counts as the request only when its **Subagent Use** section
explicitly says that approval authorizes the named assignments. Plans intended for Codex
must include that sentence when they require delegation; a table of possible assignments by
itself does not authorize spawning.

Codex can spawn only models available to the current Codex session. A person performs any
handoff to another application. Do not represent a local subagent as a cross-application
handoff.

---

## Skill and Project-Rule Discovery

This installation distributes user skills to `$CODEX_HOME/skills` through per-skill NTFS
junctions. That Codex-only root was selected because cross-application visibility of the
documented shared root could not be confirmed. Repository skills are discovered from
`.agents/skills/` while Codex walks from the current directory toward the repository root.

Use kebab-case for globally distributed skill directories in this repository. That is a
repository distribution and validation convention, not a claim that Codex rejects project
skill names containing underscores; the installed version loads those names.

A repository-root `AGENTS.md` is discovered as a project instruction file. In repositories
that keep their maintenance rules in `.agents/AGENTS.md`, the root file is an adapter that
instructs Codex to read the canonical file explicitly. It is not a Markdown import. Follow
that instruction before editing, and edit the canonical `.agents/` source rather than the
adapter when the rule itself changes.

---

## Generated Rules, Scratch Files, and the CLI

`$CODEX_HOME/AGENTS.md` contains a generated marked region assembled from this repository's
shared and Codex-specific rules. It is a copy, not a live link, and can be stale until
`setup.ps1` runs again. Never hand-edit inside the generated markers. A non-empty
`$CODEX_HOME/AGENTS.override.md` shadows `$CODEX_HOME/AGENTS.md` entirely; surface that fact
instead of assuming the generated rules are active.

Put disposable scripts and files under the session's `%TEMP%` directory, never inside a
repository. Use `apply_patch` for repository edits. On this Windows installation,
`apply_patch` can convert only the edited lines of a CRLF file to LF, leaving mixed line
endings. After patching, normalize every changed Markdown and PowerShell file to CRLF and
verify raw CR/LF byte counts. Preserve documented LF-only exceptions.

If `codex` is not on `PATH`, resolve the executable with `Get-Command codex` first, then use
the most recently written `codex.exe` under
`$env:LOCALAPPDATA\OpenAI\Codex\bin\*\codex.exe`. Never hardcode the hash-named directory.
`codex debug prompt-input` uses the process's current directory, so bracket a
directory-specific probe with `Push-Location` and `Pop-Location`.
