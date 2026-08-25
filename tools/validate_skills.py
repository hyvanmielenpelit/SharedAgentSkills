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
    skills_dir = repo_root / "skills"

    if not skills_dir.exists() or not skills_dir.is_dir():
        print(f"FAIL: Skills directory not found at {skills_dir}", file=sys.stderr)
        return 1

    all_ok = True

    # Validate rules
    if not validate_rules(repo_root):
        all_ok = False

    # Validate PS1 files for ASCII only and no BOM
    for ps1 in repo_root.glob("*.ps1"):
        if not check_no_bom(ps1) or not check_ascii_only(ps1):
            all_ok = False

    # Validate skills
    skill_dirs = [d for d in skills_dir.iterdir() if d.is_dir()]
    if not skill_dirs:
        print(f"FAIL: No skills found under {skills_dir}", file=sys.stderr)
        return 1

    for s_dir in skill_dirs:
        if not validate_skill(s_dir):
            all_ok = False

    if all_ok:
        print(f"OK: Validated {len(skill_dirs)} skills and all rules successfully.")
        return 0
    else:
        print("FAIL: Validation errors encountered.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
