#!/usr/bin/env python3
"""Extract and parse the YAML frontmatter block from a SKILL.md file.

This is a small, dependency-free parser for the restricted frontmatter grammar
used by this repository:

  - key: scalar value
  - key: "quoted value"
  - key: 'single-quoted value'
  - key: |
      literal block
  - key: >
      folded block

It is intentionally not a full YAML parser; it covers the patterns skill
authors actually use and fails cleanly when it sees something unexpected.
"""

import json
import re
import sys


def _dedent(lines):
    """Remove the common leading indentation from a block-scalar body."""
    non_blank = [ln for ln in lines if ln.strip()]
    if not non_blank:
        return [ln.rstrip() for ln in lines]
    min_indent = min(len(ln) - len(ln.lstrip(" ")) for ln in non_blank)
    return [ln[min_indent:].rstrip() if ln.strip() else "" for ln in lines]


def _strip_quotes(value):
    """Remove matching outer quotes from a scalar value."""
    if len(value) >= 2 and value[0] == value[-1] and value[0] in ('"', "'"):
        return value[1:-1]
    return value


def parse_frontmatter(path):
    with open(path, "r", encoding="utf-8") as f:
        lines = f.readlines()

    if not lines or lines[0].rstrip() != "---":
        return {"error": "missing opening frontmatter delimiter '---'"}

    end = None
    for i in range(1, len(lines)):
        if lines[i].rstrip() == "---":
            end = i
            break

    if end is None:
        return {"error": "missing closing frontmatter delimiter '---'"}

    fm_lines = lines[1:end]
    data = {}
    i = 0

    while i < len(fm_lines):
        raw = fm_lines[i]
        stripped = raw.strip()

        # Skip blank lines and comments.
        if not stripped or stripped.startswith("#"):
            i += 1
            continue

        m = re.match(r"^([A-Za-z0-9_-]+)\s*:\s*(.*)$", raw)
        if not m:
            return {"error": f"invalid frontmatter line {i + 2}: {raw.strip()!r}"}

        key = m.group(1)
        rest = m.group(2).strip()

        # Block scalar (| or >).
        if rest in ("|", ">"):
            i += 1
            block_lines = []
            while i < len(fm_lines):
                candidate = fm_lines[i]
                if candidate.strip() and not candidate.startswith((" ", "\t")):
                    break
                block_lines.append(candidate)
                i += 1

            # Trim trailing blank lines, then dedent.
            while block_lines and not block_lines[-1].strip():
                block_lines.pop()
            block_lines = _dedent(block_lines)

            if rest == "|":
                value = "".join(ln + "\n" for ln in block_lines)
            else:
                value = " ".join(ln.strip() for ln in block_lines if ln.strip())

            data[key] = value
            continue

        # Inline scalar.
        value = _strip_quotes(rest)
        data[key] = value
        i += 1

    return {"data": data, "end_line": end}


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"usage: {sys.argv[0]} <SKILL.md> [<SKILL.md> ...]", file=sys.stderr)
        sys.exit(2)
    for p in sys.argv[1:]:
        print(json.dumps({"path": p, **parse_frontmatter(p)}))
