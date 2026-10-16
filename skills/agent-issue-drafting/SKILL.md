---
name: agent-issue-drafting
description: >-
  How to draft a GitHub issue -- a bug report against a framework or library, or an issue
  in one of our own repositories -- and the comments and pull request descriptions that go
  with it, so that each can be filed as is. Covers searching for duplicates and existing
  fixes first, mirroring the target repository's issue form field by field, a self-driving
  minimal reproduction handed over for the public repository the user creates, with a
  verified .gitignore, putting the symptom, mechanism, expected and actual behavior and
  workaround in the fields made for them, wording that matches the evidence, keeping
  personal data and secrets out, and paste-ready text for GitHub forms: no hard line wraps,
  because GitHub renders every line break there, and no fences in fields GitHub fences
  itself. Also covers what happens after filing. Read before drafting any issue, comment,
  or pull request description, when an analysis finds that a bug belongs to another
  project, or before writing text to paste into a GitHub form.
---

# Issue Drafting

## Purpose

An issue draft is a document that a person files. The agent researches, reproduces, and
writes it; the person decides whether, when, and where it goes public.

Creating a repository, pushing, filing an issue, and commenting are all outward-facing:
once published, the content may be cached or indexed even if it is later deleted.

- **The user creates repositories and pushes.** The agent never does either for a draft.
- **Filing and commenting happen only on the user's explicit approval**, each time. An
  approval for one issue does not cover the next.

The same method serves an upstream report and an issue in one of our own repositories.
Only the duplicate search and the target form differ.

---

## Before Drafting

1. **Confirm whose bug it is.** It is the other project's bug only when its code, at the
   version you actually ship, fails on valid use. If your use is outside its documented
   contract, the bug is yours and no issue is warranted. If the project keeps a skill for
   reading its dependencies' source, follow it.
2. **Check whether it is already fixed.** Read the history of the relevant file from the
   shipped tag to the default branch. A fix there changes the report into "please backport"
   or makes it unnecessary.
3. **Search for duplicates.** Search the repository's open and closed issues, and its test
   suite, for the exact error message and for the behavior. If an issue already exists, add
   new evidence there, or just a reaction if you have none, instead of filing a duplicate.

---

## Read the Form

- Issue templates live in `.github/ISSUE_TEMPLATE/` of the target repository. A `*.yml` or
  `*.yaml` file is an issue form, with fields, `required` flags, and dropdown `options`; a
  `*.md` file is a free-text template. `config.yml` says whether blank issues are allowed
  at all.
- Read the repository's contribution guide and any reproduction guide it links to. They
  often say what a reproduction must contain.
- **Mirror the form in the draft:** one heading per input field (`input`, `textarea`,
  `dropdown`, `checkboxes`), in the order the form shows them; `type: markdown` entries are
  banners, not fields. Copy dropdown values **verbatim** from the template's `options` list;
  a paraphrased value matches nothing in the form.
- **Several forms:** when `.github/ISSUE_TEMPLATE/` holds more than one form, the filer
  notes name the one the draft mirrors, by its `name:` and file name. The filer picks it on
  GitHub's template chooser.
- **Prefilled values:** a form's `title:` prefills the title; keep a prefix such as
  `[BUG]` and replace any placeholder text. A dropdown
  with `multiple: true` takes several values, each copied verbatim. Checkboxes, such as a
  code of conduct, go in the filer notes for the filer to tick.
- **Fields GitHub fences itself:** a `textarea` with `render:` set (log fields often use
  `render: shell`) is wrapped in a code block when submitted. Text for it gets no fence and
  no `<details>` of its own: an inner fence closes GitHub's early, and `<details>` shows up
  as literal text. In the draft, put that text in a fence and tell the filer, above the
  separator, to copy only the lines inside it.
- **Attachments:** files the form asks for -- a binlog, a long log as `.txt`, a screenshot
  -- are listed in the filer notes with their local paths. The agent cannot attach them.

---

## The Minimal Reproduction

A reproduction is what turns a report into something a maintainer can act on.

**Its form follows the bug.** A project when the bug needs one -- build, runtime, or
platform behavior. A self-contained snippet in the form's code field when a few lines show
it. None for a documentation or API-contract issue, where the source citation is the
evidence. For an issue in one of our own repositories, the steps or a branch there are the
reproduction, and the repro repository below does not apply.

- **Start from the stock project template** and change as little as possible. Say which
  files changed, so a reviewer can ignore the rest.
- **Make it self-driving.** It triggers the bug by itself, with no manual steps, and
  writes what happened to a log file outside the repository, such as the temp directory,
  or to an ignored path. A reviewer runs it once and reads the log; manual steps get
  skipped or done differently.
- **Pin the versions** the bug was seen on: package versions in the project file and, when
  the SDK or toolchain matters, the SDK too (`global.json` for .NET).
- **Run it yourself before writing "Actual"**, and paste its real output. Never describe
  output you have not seen.

### The repro repository

When the bug needs a project, forms usually ask for a link to a public repository and
refuse zip files.

**The user always creates the repro repository**, on GitHub or with `gh repo create`, and
tells the agent when it exists and where its local clone is. The handoff, in order:

1. **The agent proposes a name and a one-line description.** Name it after the bug, not the
   platform alone, and check the spelling before it is created: the URL ends up in the issue.
2. **The agent recommends creating it empty**, with no generated README, `.gitignore`, or
   license, so that the first push needs no merge.
3. **The user creates it** and reports the local path.
4. **The agent fills it:** copies the project in, adds a README with the steps and the
   expected output, and builds and runs it **from that location**.
5. **The agent hands over** the `git add`, `git commit`, and `git push` commands.
6. **The user pushes and reports back.** Only then does the draft get the URL, as a new
   version of the draft document.

### The `.gitignore`

**A repro needs one.** Build output, IDE folders, and per-user files must never reach a
public repository.

- Use **one `.gitignore` at the repository root.** A stock project template often puts its
  own `.gitignore` inside the project folder, while IDEs create their folders at the
  repository root, out of its reach. Move it up, or add one at the root.
- Before handing over the commit commands, **while the build output and IDE folders from
  the verification run are still on disk**: `git check-ignore -v` confirms they are
  ignored, and `git status --short --untracked-files=all` lists only source files. Only
  then delete the build output. Checking after deletion proves nothing.

---

## Writing It

- **Title:** the exact error messages or the symptom, plus the platform tag the repository
  uses in its titles, if any. People and triage tools search by the exact message text.
- **Description** opens with one or two sentences on the observable failure: what happens,
  where, and since which version. This is a statement of the symptom, not a restatement of
  the title. Then, in this order:
  1. The mechanism, when known, with citations to the source at the shipped tag (file and
     line). When it is not known, say so.
  2. Expected versus actual behavior.
  3. Impact, from telemetry if you have it, as aggregate counts only.
  4. A workaround, if one exists.
  5. Possible fixes, offered for the maintainers to judge, not prescribed.
- **That list is the content, not the layout.** When the form has a field for an item --
  Expected behavior, Actual behavior, Known Workarounds, "Why is this important?", Other
  information -- the item goes there and is not repeated in Description. Only what has no
  field of its own stays in Description.
- **Related issues:** inside the same repository a bare `#123` links correctly; another
  repository needs `owner/repo#123`.
- **Start with the problem.** No greeting, no "I'd like to report", no sign-off; stop after
  the last technical point. A short thanks is fine when replying to someone who helped.
- **Write like a developer on an issue tracker.** Plain words and short paragraphs;
  headings only where the form or the length calls for them. No filler ("It's worth
  noting", "Furthermore", "In summary") and no closing summary of a short text.
- **Let the wording carry the confidence.** "This is caused by" only when a test confirmed
  it; "this seems to be", "this is probably", "this may be", and "perhaps" as the evidence
  weakens. Say what was and was not verified, and on which versions and platforms.

---

## Comments and Pull Request Descriptions

- **A comment** opens with the new information. When it answers an earlier comment, link to
  that comment or quote the part it answers. New evidence on an existing issue meets the
  same confidence and privacy rules as a new issue.
- **Closing your own issue:** say briefly what the cause turned out to be, or what fixed it.
- **A pull request description** follows `.github/PULL_REQUEST_TEMPLATE.md`, or a file in
  `.github/PULL_REQUEST_TEMPLATE/`, when the repository has one, mirroring its headings and
  checkboxes. It links the issue it fixes with a closing keyword (`Fixes #123`) and says
  what was tested.
- The formatting, privacy, and delivery rules below apply to all of them.

---

## Formatting for GitHub Forms

- **No hard line wraps in pasted prose.** GitHub renders every line break in issue, pull
  request, comment, and discussion bodies, so text wrapped at a fixed column breaks
  mid-sentence once pasted. Write **one line per paragraph** and one per list item.
  Repository `.md` files behave differently: GitHub joins their lines, so wrapping there,
  as in this file, is fine.
- **Code, logs, and tables** go in fenced blocks, exactly as they are. Collapse long code in
  `<details><summary>...</summary>`, with a blank line before the opening fence. The
  exception is a field with `render:`, which GitHub fences itself -- see Read the Form.
- **Clean logs before pasting:** strip local paths, user names, and machine names; trim
  framework noise with `[...]` and say that you did.
- **Separate the two audiences in the draft file.** Notes for the filer, such as steps
  before filing and what was verified, go above a separator line in normal document style.
  Everything to be pasted goes below it, one section per form field.
- **Git commit messages are the opposite case:** they keep the conventional wrap at about
  72 columns.

---

## Privacy and Security

- **No personal data from telemetry or crash reports:** user IDs, names, device names,
  locations, IP addresses, or anything a user typed. Aggregate counts and device models are
  fine.
- **No secrets,** real or synthetic -- see `agent-secret-hygiene`.
- **No internal host names** or links to private repositories.
- **Attachments too.** A binlog records environment variables and full paths. The filer
  reviews it before attaching, and the filer notes say so.

---

## Delivery

The draft is a document. Store and version it as `agent-implementation-planning`
specifies: every revision is a new `_v<N>` file, reported to the user as a link. Never file
it, or post any part of it, without the user's approval.

**Its scope is the repository the work came from**, not the project the issue is filed
against. A draft that comes out of work in one of our repositories is stored under that
repository's scope, in the task directory of the analysis or workaround that produced it,
if there is one. Whether the upstream project's organization is allowed does not matter
then. Only a draft written with no repository of ours involved takes its scope from the
upstream repository, under the usual tier rules.

---

## After Filing

- Put the issue URL in the workaround's code comment and in the repro README.
- Record the issue wherever the project tracks upstream reports, if it keeps such a list.
  Do not start one.
- When upstream ships a fix, plan the removal of the workaround.

---

## Checklist

- It is the other project's bug, at the shipped version, and not already fixed upstream.
- No existing issue covers it.
- The draft mirrors the target form, with dropdown values copied verbatim.
- Every form field has its own content, with nothing repeated in Description.
- The repro is minimal and self-driving, pinned to the affected version, and was run by the
  agent; "Actual" is real output.
- When a repro repository is used: the user created it, a root `.gitignore` is verified,
  and the repro was run from its published location.
- Paste-ready text has one line per paragraph; code and logs are fenced and cleaned, except
  in fields GitHub fences itself.
- Attachments the form asks for are listed in the filer notes.
- No personal data, secrets, or internal links.
- The draft is stored as a versioned document, and filing waits for the user.
