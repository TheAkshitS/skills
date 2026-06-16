#!/usr/bin/env bash
set -euo pipefail

for cmd in python3 jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "error: $cmd is required to run these tests" >&2
    exit 1
  fi
done

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# Bootstrap a mini repo in temp space.
mkdir -p "$TMPDIR/skills"
cp -R "$REPO/scripts" "$TMPDIR/scripts"
mkdir -p "$TMPDIR/.claude-plugin"

# Minimal plugin.json and README for sync checks.
cat > "$TMPDIR/.claude-plugin/plugin.json" <<'EOF'
{
  "name": "test-skills",
  "skills": []
}
EOF

cat > "$TMPDIR/README.md" <<'EOF'
# Test Skills
EOF

FAILURES=0

# $1 = test name
# $2 = expected exit code (0 or 1)
# $3 = expected substring in output (optional)
run_test() {
  local name="$1"
  local expected="$2"
  local want="${3:-}"
  local out
  local code=0

  out="$(cd "$TMPDIR" && bash scripts/validate-skills.sh 2>&1)" || code=$?

  if [ "$code" -ne "$expected" ]; then
    echo "FAIL $name: expected exit $expected, got $code"
    echo "$out"
    FAILURES=$((FAILURES + 1))
    return
  fi

  if [ -n "$want" ] && ! echo "$out" | grep -qF "$want"; then
    echo "FAIL $name: expected output containing '$want'"
    echo "$out"
    FAILURES=$((FAILURES + 1))
    return
  fi

  echo "PASS $name"
}

write_skill() {
  local skill_dir="$TMPDIR/skills/$1"
  mkdir -p "$skill_dir"
  cat > "$skill_dir/SKILL.md" <<EOF
$2
EOF
}

update_plugin() {
  local skills_json=""
  for path in "$@"; do
    [ -n "$skills_json" ] && skills_json="$skills_json,"
    skills_json="$skills_json\"./skills/$path\""
  done
  printf '{"name":"test-skills","skills":[%s]}\n' "$skills_json" | jq . > "$TMPDIR/.claude-plugin/plugin.json"
}

update_readme() {
  for path in "$@"; do
    echo "- [$path](./skills/$path/SKILL.md)" >> "$TMPDIR/README.md"
  done
}

# --- Tests ---

# 1. Valid skill passes.
write_skill "valid-skill" '---
name: valid-skill
description: Use when the user wants a valid skill.
---'
update_plugin "valid-skill"
update_readme "valid-skill"
run_test "valid skill passes" 0 "OK   valid-skill"
rm -rf "$TMPDIR/skills/valid-skill"

# Reset manifest files.
cat > "$TMPDIR/.claude-plugin/plugin.json" <<'EOF'
{"name":"test-skills","skills":[]}
EOF
printf '# Test Skills\n' > "$TMPDIR/README.md"

# 2. Missing name fails.
write_skill "no-name" '---
description: Use when the user wants a skill with no name.
---'
run_test "missing name fails" 1 "missing 'name'"
rm -rf "$TMPDIR/skills/no-name"

# 3. Name mismatch fails.
write_skill "mismatch" '---
name: wrong-name
description: Use when the user wants a mismatch.
---'
run_test "name mismatch fails" 1 "does not match folder name"
rm -rf "$TMPDIR/skills/mismatch"

# 4. Missing description fails.
write_skill "no-desc" '---
name: no-desc
---'
run_test "missing description fails" 1 "missing 'description'"
rm -rf "$TMPDIR/skills/no-desc"

# 5. Description too long fails (>1024 chars).
write_skill "long-desc" "---
name: long-desc
description: $(python3 -c 'print("x" * 1025)')
---"
run_test "description too long fails" 1 "description too long"
rm -rf "$TMPDIR/skills/long-desc"

# 6. Missing trigger phrase warns but exits 0.
write_skill "no-trigger" '---
name: no-trigger
description: This skill does something important.
---'
run_test "missing trigger phrase warns" 0 "may lack trigger phrases"
rm -rf "$TMPDIR/skills/no-trigger"

# 7. Missing frontmatter delimiter fails.
write_skill "no-fm" 'name: no-fm
description: Use when the user wants no frontmatter.
---'
run_test "missing frontmatter delimiter fails" 1 "missing opening frontmatter"
rm -rf "$TMPDIR/skills/no-fm"

# 8. Folded description parses correctly and length is exact.
write_skill "folded" '---
name: folded
description: >
  Use when the user wants a folded
  description that spans lines.
---'
run_test "folded description parses" 0 "OK   folded"
rm -rf "$TMPDIR/skills/folded"

# 9. plugin.json missing skill warns.
write_skill "missing-plugin" '---
name: missing-plugin
description: Use when the user wants a skill missing from plugin.json.
---'
update_readme "missing-plugin"
run_test "plugin.json missing skill warns" 0 "not found in plugin.json"
rm -rf "$TMPDIR/skills/missing-plugin"
printf '# Test Skills\n' > "$TMPDIR/README.md"

# 10. README missing skill warns.
write_skill "missing-readme" '---
name: missing-readme
description: Use when the user wants a skill missing from README.
---'
update_plugin "missing-readme"
run_test "README missing skill warns" 0 "not linked in README.md"
rm -rf "$TMPDIR/skills/missing-readme"

echo ""
if [ "$FAILURES" -eq 0 ]; then
  echo "All tests passed."
else
  echo "$FAILURES test(s) failed." >&2
  exit 1
fi
