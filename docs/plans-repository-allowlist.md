# The Plans Repository Allowlist

Which repositories may have plans stored in the shared
[`hyvanmielenpelit/plans`](https://github.com/hyvanmielenpelit/plans) repository, and how
to change that list.

---

## The list

| Organization | Why it is here |
|--------------|----------------|
| `hyvanmielenpelit` | Our own repositories |
| `dotnet` | Upstream .NET work, usually done from a fork |
| `mono` | Upstream Mono work, usually done from a fork |

Every repository inside these organizations qualifies. Nothing outside them does.

**The list is of organizations, not repositories.** That keeps it to a handful of entries
that a person can hold in their head. A repository-level list would be a roster nobody
maintains, and this repository already has a rule against written rosters that go stale
unnoticed -- see [ai-skill-management.md](ai-skill-management.md).

**Eligibility is read from the remote**, not from the folder name:
`git -C <repository> remote get-url origin`. For a fork, if `origin` is a personal account
but an `upstream` remote points at an allowed organization, `upstream` decides -- that is
the normal shape of contributing to `dotnet` or `mono`.

---

## Why the store is restricted at all

Two reasons, and neither is obvious from the outside.

**The store should hold work the team owns.** A shared, private repository of plans is
useful in proportion to how much of it is relevant to the people reading it. Plans about
repositories nobody here can act on dilute that.

**The tiers below it exist for safety.** When a repository is not eligible, the plan falls
to the repository's own `.plans/` -- and that is allowed **only when Git confirms `.plans/`
is ignored there**:

```powershell
git -C <repository> check-ignore -q .plans
```

In our repositories `.plans/` is ignored and this always succeeds. In an upstream
repository such as `dotnet/runtime` it is **not** ignored, and writing there would put
agent-generated documents into the working tree of a repository you are preparing a pull
request from -- one `git add -A` away from the PR. When the check fails the plan stays in
the conversation and no file is written anywhere.

So the allowlist is not only about tidiness. Widening it changes which repositories get
files written into them.

---

## Where the list is written

Two operational copies. **Both must be changed together.**

| # | File | Audience |
|---|------|----------|
| 1 | `skills/agent-implementation-planning/SKILL.md`, section *"What may be stored in the plans repository"* | Agents -- the authority they read before writing any plan |
| 2 | `C:\hmp\plans\README.md`, section *"What may be stored here"* | People -- the store explaining what it accepts |

`rules/AGENTS.md` deliberately does **not** name the organizations. It says "an allowed
organization, listed in `agent-implementation-planning`" and stops there: it loads into
every context window, so a third copy there would be the most expensive to carry and the
likeliest to drift. An agent must load the planning skill before writing a plan anyway.

---

## Adding an organization

1. Edit **both** files in the table above. Add a row to each table, with a short reason --
   "why it is here" is the column that stops the list growing by accident.
2. Validate:

   ```powershell
   cd C:\hmp\SharedAgentSkills
   python tools\validate_skills.py
   ```

3. Regenerate the inlined rules (see the boundary below):

   ```powershell
   .\setup.ps1
   ```

4. Commit both repositories. Nothing else is needed -- **no directory has to be created**
   in the plans repository. The first plan for a repository in the new organization
   creates `<organization>/<repository>/` on its way past.

---

## Removing an organization

1. Edit **both** files in the table above.
2. Run the same two commands.
3. **Leave the existing plan directories in place.**

> [!IMPORTANT]
> Removing an organization means *"no new plans here"*. It does not mean deleting the
> plans already stored for it. Those are the revision history of work that really
> happened, and deleting them to enforce a present-day rule loses more than it gains --
> the same reasoning that forbids overwriting a `_v<N>` document.

If a directory really must go, that is a separate, deliberate decision, taken with the
knowledge that the history is not recoverable from anywhere else.

---

## The regeneration boundary

> [!WARNING]
> `rules/AGENTS.md` reaches Antigravity as an **inlined copy**, regenerated only when
> `setup.ps1` or `sync.ps1` runs. Claude Code reads the same file through a live junction.
>
> Between editing the list and running `setup.ps1`, the two applications **disagree** --
> Claude Code applies the new list, Antigravity applies the old one, and nothing reports
> the disagreement. Because the rules file does not name the organizations, this affects
> the surrounding wording rather than the list itself, but run the script anyway: it is
> one command, and the asymmetry is the most common source of "why is Gemini ignoring my
> rule".

---

## Related

- [ai-skill-management.md](ai-skill-management.md) -- where guidance belongs and how it
  reaches each harness.
- `skills/agent-implementation-planning/SKILL.md` -- the tiers, the scope layout, and
  everything else about how plans are stored.
- The plans repository's own `README.md` -- the same rules written for a person opening
  the store.
