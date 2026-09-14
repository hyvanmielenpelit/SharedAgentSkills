---
name: agent-secret-hygiene
description: >-
  How to write credentials, API keys, and access tokens into code, tests, fixtures,
  comments, documentation, and plans without tripping GitHub push protection. Covers what
  makes a string "secret-shaped", why a single synthetic token blocks the entire push and
  not just the offending file, the two-concatenated-literals technique for a fixture that
  must scan as a real token at runtime, describing a token's shape in words instead of
  quoting one, placeholder forms that are safe, what to do when a push has already been
  rejected by secret scanning, and why the bypass link is the wrong answer. Read before
  writing an example key, an authentication test fixture, a connection string, or any
  documentation that shows a token.
---

# Secret Hygiene

## Purpose

The always-on rule in `rules/AGENTS.md` is short: **never write a secret-shaped literal**.
This skill is the reasoning and the technique behind it -- what counts as secret-shaped,
why the cost is disproportionate, and how to write the fixture you actually needed.

The rule covers **synthetic** values. There is no exception for "it is obviously fake",
"it is only a test", or "it is only a comment".

---

## What "Secret-Shaped" Means

A scanner does not know what is real. It matches **shape**: a recognizable vendor prefix
followed by a body of the right length and character class.

| Element | Example prefixes |
|---------|------------------|
| Vendor prefix | `sk_live_`, `sk_test_`, `ghp_`, `github_pat_`, `glpat-`, `xoxb-`, `AKIA`, `ya29.`, `AIza` |
| Body | 20-100 characters of random-looking base62, base64, or hex |

**Prefix plus random-looking body is the trigger.** A prefix on its own, named in prose as
this table does, is not a secret and is safe to write. What is unsafe is completing the
shape -- and a plausible-looking body you invented completes it just as well as a real one.

Connection strings, private keys (`-----BEGIN ... PRIVATE KEY-----`), and JWTs are scanned
on the same principle.

---

## Why the Rule Is Absolute

**Push protection scans the pushed text and rejects the whole push.** Not the file, not the
commit -- the push. Consequences, in the order they usually bite:

1. Everything else in the push is blocked with it, including a colleague's commits that
   happened to be on the same branch.
2. The literal is already in the local history, so removing it in a follow-up commit does
   not clear the block. The history has to be rewritten, or the branch rebuilt.
3. Rewriting history is exactly the operation these repositories forbid elsewhere, and it
   is being performed under time pressure, on work that was finished.

A fake token that costs an hour of history surgery is more expensive than every test it was
supposed to serve.

**This applies to documents too.** Plans, reviews, and walkthroughs are pushed to the
shared `plans` repository without waiting for a human, so a token quoted in a plan reaches
a remote just as fast as one in source.

---

## Writing the Fixture You Needed

### A value that must scan as a token at runtime

Some tests exist precisely to check that a token is detected, redacted, or rejected. Build
the string at runtime from two literals; the source file then contains neither the prefix
followed by a body, nor anything a scanner matches:

```csharp
// Assembled at runtime: neither half is secret-shaped on its own.
const string prefix = "gh" + "p_";
const string body = new string('a', 36);
var token = prefix + body;
```

```python
PREFIX = "gh" + "p_"
BODY = "a" * 36
TOKEN = PREFIX + BODY
```

The same works in any language. What matters is that no single literal in the file carries
a complete token shape.

### A value that only needs to look like a setting

Use an obvious placeholder that does not imitate a vendor format:

```json
{ "ApiKey": "<your-api-key>" }
```

`<placeholder>`, `REPLACE_ME`, `xxxxx`, and an empty string are all fine. A repeated
character (`"aaaa...."`) is fine. What is not fine is a realistic-looking random body.

### A token in documentation

**Describe the shape in words.** "A personal access token is the `ghp_` prefix followed by
36 base62 characters" tells the reader everything an example would, and contains no secret.
If a rendered example is unavoidable, truncate hard: `ghp_...`.

---

## Real Credentials

Nothing above is about real secrets. Those never enter a repository in any form -- not
commented out, not in a `.local` file that happens to be gitignored today, not in a plan
document. They live in environment variables, the platform's user-secrets or key-vault
store, or CI secrets. If you find a real one already committed, say so plainly and stop:
it must be **rotated**, not merely deleted, because the history is already published.

---

## When the Push Has Already Been Rejected

1. **Read the rejection.** It names the file, the line, and the detected provider.
2. **Fix the content** using the techniques above.
3. **Clean the history**, because the blocked commit still contains the literal. If the
   commits are local only, that is an interactive rebase or a soft reset and recommit.
   **Do not rewrite anything already pushed**, and do not do this to a shared branch --
   ask the user first.
4. **Never use the bypass link**, even when the value is provably fake. Bypassing
   allow-lists that exact string permanently, so the next occurrence -- which may be real
   -- is waved through, and it records a person as having approved a secret. If you believe
   a bypass is genuinely warranted, that is a decision for the user, not the agent.

---

## Checklist

- No literal in the file completes a vendor prefix plus a random-looking body.
- Fixtures that must scan as tokens are assembled from two literals at runtime.
- Documentation describes a token's shape in words, or truncates it.
- Placeholders are obviously placeholders.
- No real credential anywhere, including in plans and walkthroughs.
