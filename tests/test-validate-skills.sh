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
# Include _template so the exclusion paths in validate / list / link are all
# exercised against a real excluded entry.
cp -R "$REPO/skills/_template" "$TMPDIR/skills/_template"
mkdir -p "$TMPDIR/.claude-plugin"

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

# Write a SKILL.md with the given body to $TMPDIR/skills/<name>/SKILL.md.
write_skill() {
  local skill_dir="$TMPDIR/skills/$1"
  mkdir -p "$skill_dir"
  cat > "$skill_dir/SKILL.md" <<EOF
$2
EOF
}

# Write a SKILL.md verbatim, used for content that needs literal tab / control
# characters that the heredoc-based write_skill would mangle.
write_skill_raw() {
  local skill_dir="$TMPDIR/skills/$1"
  mkdir -p "$skill_dir"
  printf '%s' "$2" > "$skill_dir/SKILL.md"
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

# Reset both manifest files to a known empty state. Tests call this at the
# start so each test's plugin.json / README expectations are independent —
# no test inherits state from the previous one.
reset_manifests() {
  cat > "$TMPDIR/.claude-plugin/plugin.json" <<'EOF'
{"name":"test-skills","skills":[]}
EOF
  printf '# Test Skills\n' > "$TMPDIR/README.md"
}

# --- Tests ---

# 1. Valid skill passes.
reset_manifests
write_skill "valid-skill" '---
name: valid-skill
description: Use when the user wants a valid skill.
---'
update_plugin "valid-skill"
update_readme "valid-skill"
run_test "valid skill passes" 0 "OK   valid-skill"
rm -rf "$TMPDIR/skills/valid-skill"

# 2. Missing name fails.
reset_manifests
write_skill "no-name" '---
description: Use when the user wants a skill with no name.
---'
run_test "missing name fails" 1 "missing 'name'"
rm -rf "$TMPDIR/skills/no-name"

# 3. Name mismatch fails.
reset_manifests
write_skill "mismatch" '---
name: wrong-name
description: Use when the user wants a mismatch.
---'
run_test "name mismatch fails" 1 "does not match folder name"
rm -rf "$TMPDIR/skills/mismatch"

# 4. Missing description fails.
reset_manifests
write_skill "no-desc" '---
name: no-desc
---'
run_test "missing description fails" 1 "missing 'description'"
rm -rf "$TMPDIR/skills/no-desc"

# 5. Description too long fails (>1024 chars).
reset_manifests
write_skill "long-desc" "---
name: long-desc
description: $(python3 -c 'print("x" * 1025)')
---"
run_test "description too long fails" 1 "description too long"
rm -rf "$TMPDIR/skills/long-desc"

# 6. Missing trigger phrase warns but exits 0.
reset_manifests
write_skill "no-trigger" '---
name: no-trigger
description: This skill does something important.
---'
run_test "missing trigger phrase warns" 0 "may lack trigger phrases"
rm -rf "$TMPDIR/skills/no-trigger"

# 7. Missing frontmatter delimiter fails.
reset_manifests
write_skill "no-fm" 'name: no-fm
description: Use when the user wants no frontmatter.
---'
run_test "missing frontmatter delimiter fails" 1 "missing opening frontmatter"
rm -rf "$TMPDIR/skills/no-fm"

# 8. Folded description parses correctly and length is exact.
reset_manifests
write_skill "folded" '---
name: folded
description: >
  Use when the user wants a folded
  description that spans lines.
---'
run_test "folded description parses" 0 "OK   folded"
rm -rf "$TMPDIR/skills/folded"

# 9. plugin.json missing skill warns.
reset_manifests
write_skill "missing-plugin" '---
name: missing-plugin
description: Use when the user wants a skill missing from plugin.json.
---'
update_readme "missing-plugin"
run_test "plugin.json missing skill warns" 0 "not found in plugin.json"
rm -rf "$TMPDIR/skills/missing-plugin"

# 10. README missing skill warns.
reset_manifests
write_skill "missing-readme" '---
name: missing-readme
description: Use when the user wants a skill missing from README.
---'
update_plugin "missing-readme"
run_test "README missing skill warns" 0 "not linked in README.md"
rm -rf "$TMPDIR/skills/missing-readme"

# 11. Duplicate frontmatter key fails.
reset_manifests
write_skill "dup-key" '---
name: dup-key
description: First description.
description: Second description (duplicate).
---'
run_test "duplicate frontmatter key fails" 1 "duplicate key"
rm -rf "$TMPDIR/skills/dup-key"

# 12. Non-kebab-case name fails.
reset_manifests
write_skill "NotKebab" '---
name: NotKebab
description: Use when the user wants a non-kebab-case skill.
---'
run_test "non-kebab-case name fails" 1 "kebab-case"
rm -rf "$TMPDIR/skills/NotKebab"

# 13. list-skills.sh output is correct (includes /SKILL.md suffix, no
# repo-prefix bleed-through).
reset_manifests
write_skill "valid-skill" '---
name: valid-skill
description: Use when the user wants a valid skill.
---'
list_out="$(cd "$TMPDIR" && bash scripts/list-skills.sh)"
if [ "$list_out" = "skills/valid-skill/SKILL.md" ]; then
  echo "PASS list-skills output is correct"
else
  echo "FAIL list-skills expected 'skills/valid-skill/SKILL.md' got '$list_out'"
  FAILURES=$((FAILURES + 1))
fi
if (cd "$TMPDIR" && bash scripts/list-skills.sh) | grep -q "_template"; then
  echo "FAIL list-skills includes _template (should be excluded)"
  FAILURES=$((FAILURES + 1))
else
  echo "PASS list-skills excludes _template"
fi
rm -rf "$TMPDIR/skills/valid-skill"

# 14. link-skills.sh creates correct symlinks, excludes _template, and bails
# out when $DEST already points back into the repo.
reset_manifests
write_skill "valid-skill" '---
name: valid-skill
description: Use when the user wants a valid skill.
---'
TMP_HOME="$TMPDIR/home"
mkdir -p "$TMP_HOME"
(cd "$TMPDIR" && HOME="$TMP_HOME" bash scripts/link-skills.sh >/dev/null 2>&1) || true
link_target="$TMP_HOME/.claude/skills/valid-skill"
# Use pwd -P for both expected and got to handle macOS /var -> /private/var
# symlink resolution, matching the script's pwd -P in REPO computation.
expected_target="$(cd "$TMPDIR" && pwd -P)/skills/valid-skill"
if [ ! -L "$link_target" ]; then
  echo "FAIL link-skills creates symlink"
  FAILURES=$((FAILURES + 1))
elif [ "$(readlink "$link_target")" != "$expected_target" ]; then
  echo "FAIL link-skills target wrong: got '$(readlink "$link_target")' expected '$expected_target'"
  FAILURES=$((FAILURES + 1))
else
  echo "PASS link-skills creates correct symlink"
fi
if [ -e "$TMP_HOME/.claude/skills/_template" ]; then
  echo "FAIL link-skills linked _template (should be excluded)"
  FAILURES=$((FAILURES + 1))
else
  echo "PASS link-skills excludes _template"
fi
# Repo-symlink guard: if $DEST is already a symlink into the repo, the
# script must refuse to run instead of writing symlinks back into skills/.
guard_home="$TMPDIR/guard-home"
mkdir -p "$guard_home/.claude/skills"
ln -sfn "$TMPDIR" "$guard_home/.claude/skills-link"
# Point $DEST (which is $HOME/.claude/skills) at $guard_home/.claude/skills,
# which is a real dir that contains a symlink pointing into the repo's skills
# tree. Simpler: make $DEST itself a symlink into the repo.
guard_dest="$guard_home/.claude/skills"
rm -rf "$guard_dest"
ln -sfn "$TMPDIR" "$guard_dest"
guard_out="$(cd "$TMPDIR" && HOME="$guard_home" bash scripts/link-skills.sh 2>&1)" || guard_code=$?
guard_code=${guard_code:-0}
if [ "$guard_code" -ne 0 ] && echo "$guard_out" | grep -q "symlink into this repo"; then
  echo "PASS link-skills guards against symlinked \$HOME/.claude/skills pointing into repo"
else
  echo "FAIL link-skills should have refused repo-symlink DEST (code=$guard_code out=$guard_out)"
  FAILURES=$((FAILURES + 1))
fi
rm -rf "$TMPDIR/skills/valid-skill"

# 15. Tab in block-scalar indentation fails.
reset_manifests
write_skill_raw "tab-indent" $'---\nname: tab-indent\ndescription: |\n\tindented with tab\n\tstill indented\n---\n'
run_test "tab in block scalar fails" 1 "tab in block-scalar"
rm -rf "$TMPDIR/skills/tab-indent"

echo ""
if [ "$FAILURES" -eq 0 ]; then
  echo "All tests passed."
else
  echo "$FAILURES test(s) failed." >&2
  exit 1
fi
