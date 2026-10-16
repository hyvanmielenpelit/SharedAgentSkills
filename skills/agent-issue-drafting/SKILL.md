---
name: agent-issue-drafting
description: >-
  How to draft a GitHub issue -- a bug report against a framework or library, or an issue
  in one of our own repositories -- so that it can be filed as is. Covers reading the target
  repository's issue form templates and mirroring their fields, searching for duplicates and
  existing fixes first, building and running a self-driving minimal reproduction and handing
  it over for the public repository the user creates, with a verified .gitignore, writing
  the title, mechanism, expected and actual behavior and workaround, keeping personal data
  and secrets out, and formatting paste-ready text for GitHub forms: no hard line wraps in
  issue, pull request, or comment text, because GitHub renders every line break there. Also
  covers what happens after filing. Read before drafting any issue or pull request
  description, when an analysis concludes that a bug belongs to another project, or before
  writing text meant to be pasted into a GitHub form.
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

- Issue templates live in `.github/ISSUE_TEMPLATE/` of the target repository. A `*.yml` file
  is an issue form, with fields, `required` flags, and dropdown `options`; a `*.md` file is a
  free-text template. `config.yml` says whether blank issues are allowed at all.
- Read the repository's contribution guide and any reproduction guide it links to. They
  often say what a reproduction must contain.
- **Mirror the form in the draft:** one heading per field, in the order the form shows
  them. Copy dropdown values **verbatim** from the template's `options` list; a paraphrased
  value matches nothing in the form.

---

## The Minimal Reproduction

A reproduction is what turns a report into something a maintainer can act on.

- **Start from the stock project template** and change as little as possible. Say which
  files changed, so a reviewer can ignore the rest.
- **Make it self-driving.** It triggers the bug by itself, with no manual steps, and
  writes what happened to a log file. A reviewer runs it once and reads the log; manual
  steps get skipped or done differently.
- **Pin the version** the bug was seen on.
- **Run it yourself before writing "Actual"**, and paste its real output. Never describe
  output you have not seen.

### The repro repository

Forms usually ask for a link to a public repository and refuse zip files.

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
- Before handing over the commit commands, check what will be committed:
  - `git check-ignore` confirms that the IDE folder and the build output are ignored;
  - `git status --short --untracked-files=all` lists only source files;
  - the build output from the verification run has been deleted.

---

## Writing It

- **Title:** the exact error messages or the symptom, plus the platform tag the repository
  uses in its titles, if any. People and triage tools search by the exact message text.
- **Description,** in this order:
  1. The mechanism, with citations to the source at the shipped tag (file and line).
  2. Expected versus actual behavior.
  3. Impact, from telemetry if you have it, as aggregate counts only.
  4. A workaround, if one exists.
  5. Possible fixes, offered for the maintainers to judge, not prescribed.
- **Related issues:** inside the same repository a bare `#123` links correctly; another
  repository needs `owner/repo#123`.
- **Confidence:** keep every claim at the level the evidence supports. Say what was and
  was not verified, and on which versions and platforms.

---

## Formatting for GitHub Forms

- **No hard line wraps in pasted prose.** GitHub renders every line break in issue, pull
  request, comment, and discussion bodies, so text wrapped at a fixed column breaks
  mid-sentence once pasted. Write **one line per paragraph** and one per list item.
  Repository `.md` files behave differently: GitHub joins their lines, so wrapping there,
  as in this file, is fine.
- **Code, logs, and tables** go in fenced blocks, exactly as they are. Collapse long code in
  `<details><summary>...</summary>`, with a blank line before the opening fence.
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

---

## Delivery

The draft is a document. Store and version it as `agent-implementation-planning`
specifies: every revision is a new `_v<N>` file, reported to the user as a link. Never file
it, or post any part of it, without the user's approval.

---

## After Filing

- Put the issue URL in the workaround's code comment and in the repro README.
- Record the issue wherever the project tracks upstream reports.
- When upstream ships a fix, plan the removal of the workaround.

---

## Checklist

- It is the other project's bug, at the shipped version, and not already fixed upstream.
- No existing issue covers it.
- The draft mirrors the target form, with dropdown values copied verbatim.
- The repro is minimal and self-driving, pinned to the affected version, and was run by the
  agent; "Actual" is real output.
- The user created the repro repository; a root `.gitignore` is verified; the repro was run
  from its published location.
- Paste-ready text has one line per paragraph; code and logs are fenced and cleaned.
- No personal data, secrets, or internal links.
- The draft is stored as a versioned document, and filing waits for the user.
