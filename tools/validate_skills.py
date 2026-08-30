#!/usr/bin/env python3
"""
Skill and repository validator for SharedAgentSkills.
Validates skill directory conventions, YAML frontmatter, character sets, BOMs, and markdown links.
"""

import os
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("Error: PyYAML is required. Run 'pip install pyyaml'.", file=sys.stderr)
    sys.exit(1)

NAME_REGEX = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
LINK_REGEX = re.compile(r"\[([^\]]+)\]\(([^)]+)\)")


def check_no_bom(path: Path) -> bool:
    with open(path, "rb") as f:
        header = f.read(3)
        if header == b"\xef\xbb\xbf":
            print(f"FAIL [BOM]: {path} has a UTF-8 BOM.", file=sys.stderr)
            return False
    return True


def check_ascii_only(path: Path) -> bool:
    with open(path, "rb") as f:
        content = f.read()
        try:
            content.decode("ascii")
        except UnicodeDecodeError as e:
            print(f"FAIL [ASCII]: {path} contains non-ASCII characters: {e}", file=sys.stderr)
            return False
    return True


def validate_markdown_links(file_path: Path, content: str) -> bool:
    success = True
    base_dir = file_path.parent
    for match in LINK_REGEX.finditer(content):
        url = match.group(2).strip()
        # Ignore external URLs, anchors, mailto, etc.
        if url.startswith(("http://", "https://", "mailto:", "#")):
            continue
        # Strip anchor from target file if present
        clean_target = url.split("#")[0]
        if not clean_target:
            continue
        target_path = (base_dir / clean_target).resolve()
        if not target_path.exists():
            print(
                f"FAIL [Link]: In {file_path}, relative link '{url}' -> target '{target_path}' not found.",
                file=sys.stderr,
            )
            success = False
    return success


def validate_rules(repo_root: Path) -> bool:
    success = True
    agents_rule = repo_root / "rules" / "AGENTS.md"
    if not agents_rule.exists():
        print(f"FAIL [Missing]: {agents_rule} not found.", file=sys.stderr)
        return False

    if not check_no_bom(agents_rule):
        success = False

    text = agents_rule.read_text(encoding="utf-8")
    if text.startswith("---"):
        print(f"FAIL [Frontmatter]: {agents_rule} must not contain YAML frontmatter.", file=sys.stderr)
        success = False

    # Check for relative links in rules/AGENTS.md
    for match in LINK_REGEX.finditer(text):
        url = match.group(2).strip()
        if not url.startswith(("http://", "https://", "mailto:", "#")):
            print(f"FAIL [Link]: {agents_rule} must not contain relative links ('{url}').", file=sys.stderr)
            success = False

    claude_rule = repo_root / "rules" / "CLAUDE.md"
    if claude_rule.exists():
        if not check_no_bom(claude_rule):
            success = False
        c_text = claude_rule.read_text(encoding="utf-8")
        if "<!-- shared-agent-skills-import-ok -->" not in c_text:
            print(f"FAIL [Sentinel]: {claude_rule} missing sentinel comment.", file=sys.stderr)
            success = False

    return success


MODEL_NAME_REGEX = re.compile("(?<![A-Za-z0-9_./-])(Opus|Sonnet|Haiku|Gemini|Flash|GPT)(?![A-Za-z0-9_./-])", re.IGNORECASE)

# Directories whose skills are linked into a single harness. Each may carry at
# most one concrete model mention, as a parenthetical hint.
HARNESS_SKILL_DIRS = ("skills-claude", "skills-gemini")

RULES_MAX_BYTES = 3 * 1024


def check_no_model_names(path: Path, allowance: int) -> bool:
    """Tier-to-model mappings must not be written down: rosters change and this
    repository has no review cadence. Tiers are resolved at runtime against the
    models a session actually offers."""
    text = path.read_text(encoding="utf-8")
    hits = MODEL_NAME_REGEX.findall(text)
    if len(hits) > allowance:
        print(
            f"FAIL [Model Names]: {path} mentions {len(hits)} concrete model name(s) "
            f"({', '.join(sorted(set(hits)))}); at most {allowance} allowed here. "
            f"State the selection rule and let the session resolve it.",
            file=sys.stderr,
        )
        return False
    return True


def normalized_size(path: Path) -> int:
    """Byte length with line endings normalized to LF.

    The cap below measures content, not representation. These repositories use
    CRLF working trees, which would otherwise charge one byte per line for a
    convention that carries no meaning -- and would silently tighten the cap
    again if the convention ever changed."""
    text = path.read_text(encoding="utf-8")
    return len(text.replace("\r\n", "\n").encode("utf-8"))


def validate_rules_size(repo_root: Path) -> bool:
    """Rules files load into every context window in every project, so they are
    capped. Anything longer belongs in a triggered skill."""
    success = True
    for name in ("AGENTS.md", "CLAUDE.md", "GEMINI.md"):
        path = repo_root / "rules" / name
        if not path.exists():
            continue
        size = normalized_size(path)
        if size > RULES_MAX_BYTES:
            print(
                f"FAIL [Rules Size]: {path} is {size} bytes LF-normalized "
                f"(cap {RULES_MAX_BYTES}). Move the excess into a triggered skill.",
                file=sys.stderr,
            )
            success = False
    return success


FALLBACK_TOKEN = ".plans/"
PRIMARY_TOKENS = ("AGENT_PLANS_ROOT", "plans repository")


def check_fallback_has_primary(path: Path) -> bool:
    """`.plans/` is the FALLBACK location for planning documents, never their
    home -- that is the shared `plans` repository.

    A file may name the fallback, but never on its own. Describing `.plans/`
    without naming the primary is exactly what a silent regression to the old
    per-repository arrangement looks like, and it reads as correct."""
    # Backticks are markdown, not meaning: `plans` repository must match too.
    text = path.read_text(encoding="utf-8").replace("`", "")
    if FALLBACK_TOKEN not in text:
        return True
    if any(token in text for token in PRIMARY_TOKENS):
        return True
    print(
        f"FAIL [Plans Location]: {path} mentions '{FALLBACK_TOKEN}' without naming the "
        f"shared plans repository (expected one of: {', '.join(PRIMARY_TOKENS)}). "
        f"`.plans/` is the fallback, not the destination -- see "
        f"agent-implementation-planning.",
        file=sys.stderr,
    )
    return False


def validate_skill(skill_dir: Path) -> bool:
    success = True
    dir_name = skill_dir.name

    if not NAME_REGEX.match(dir_name) or len(dir_name) > 64:
        print(
            f"FAIL [Dir Name]: '{dir_name}' must be lowercase kebab-case (<= 64 chars).",
            file=sys.stderr,
        )
        success = False

    skill_md = skill_dir / "SKILL.md"
    if not skill_md.exists():
        print(f"FAIL [Missing]: {skill_md} not found.", file=sys.stderr)
        return False

    if not check_no_bom(skill_md):
        success = False

    content = skill_md.read_text(encoding="utf-8")
    if not content.startswith("---"):
        print(f"FAIL [Frontmatter]: {skill_md} does not start with frontmatter.", file=sys.stderr)
        return False

    parts = content.split("---", 2)
    if len(parts) < 3:
        print(f"FAIL [Frontmatter]: {skill_md} frontmatter is malformed.", file=sys.stderr)
        return False

    try:
        frontmatter = yaml.safe_load(parts[1])
    except Exception as e:
        print(f"FAIL [YAML]: {skill_md} YAML parsing error: {e}", file=sys.stderr)
        return False

    name = frontmatter.get("name")
    if not name or name != dir_name:
        print(
            f"FAIL [Name Mismatch]: {skill_md} 'name: {name}' does not match directory '{dir_name}'.",
            file=sys.stderr,
        )
        success = False

    desc = frontmatter.get("description", "")
    if not isinstance(desc, str):
        print(f"FAIL [Description]: {skill_md} description is not a string.", file=sys.stderr)
        success = False
    else:
        desc_len = len(desc.strip())
        if desc_len < 40 or desc_len > 1024:
            print(
                f"FAIL [Description Length]: {skill_md} description length is {desc_len} (must be 40..1024).",
                file=sys.stderr,
            )
            success = False

    if not validate_markdown_links(skill_md, parts[2]):
        success = False

    return success


def main() -> int:
    repo_root = Path(__file__).resolve().parent.parent

    skill_trees = [
        (repo_root / "skills", 0),
        (repo_root / "skills-claude", 3),
        (repo_root / "skills-gemini", 3),
    ]

    if not (repo_root / "skills").is_dir():
        print(f"FAIL: Skills directory not found at {repo_root / 'skills'}", file=sys.stderr)
        return 1

    all_ok = True

    if not validate_rules(repo_root):
        all_ok = False

    if not validate_rules_size(repo_root):
        all_ok = False

    # rules/AGENTS.md is the neutral baseline: no model name at all. The harness rules
    # files may name the other application when stating what is deliberately not
    # installed -- enough for a sentence, not enough for a roster.
    for name, allowance in (("AGENTS.md", 0), ("CLAUDE.md", 2), ("GEMINI.md", 2)):
        rule_path = repo_root / "rules" / name
        if rule_path.exists():
            if not check_no_model_names(rule_path, allowance):
                all_ok = False
            if not check_fallback_has_primary(rule_path):
                all_ok = False

    for ps1 in repo_root.glob("*.ps1"):
        if not check_no_bom(ps1) or not check_ascii_only(ps1):
            all_ok = False
    for ps1 in (repo_root / "tools").glob("*.ps1"):
        if not check_no_bom(ps1) or not check_ascii_only(ps1):
            all_ok = False

    total = 0
    seen_names: dict = {}
    for tree, model_allowance in skill_trees:
        if not tree.is_dir():
            continue
        for s_dir in sorted(d for d in tree.iterdir() if d.is_dir()):
            total += 1
            if not validate_skill(s_dir):
                all_ok = False
            skill_md = s_dir / "SKILL.md"
            if skill_md.exists():
                if not check_no_model_names(skill_md, model_allowance):
                    all_ok = False
                if not check_fallback_has_primary(skill_md):
                    all_ok = False
            if s_dir.name in seen_names:
                print(
                    f"FAIL [Namespace]: skill '{s_dir.name}' exists in both "
                    f"'{seen_names[s_dir.name]}' and '{tree.name}'.",
                    file=sys.stderr,
                )
                all_ok = False
            else:
                seen_names[s_dir.name] = tree.name

    # A repository-local skill must never shadow a linked one.
    local_skills = repo_root / ".agents" / "skills"
    if local_skills.is_dir():
        for local in local_skills.iterdir():
            if local.is_dir() and local.name in seen_names:
                print(
                    f"FAIL [Never-Linked]: repository-local skill '{local.name}' "
                    f"shadows the linked skill in '{seen_names[local.name]}'.",
                    file=sys.stderr,
                )
                all_ok = False

    if total == 0:
        print("FAIL: No skills found.", file=sys.stderr)
        return 1

    if all_ok:
        print(f"OK: Validated {total} skills and all rules successfully.")
        return 0
    print("FAIL: Validation errors encountered.", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
