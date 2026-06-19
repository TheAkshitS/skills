#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_DIR="$REPO/skills"
PARSER="$REPO/scripts/lib/parse-frontmatter.py"
ERRORS=0
WARNINGS=0
SKILL_COUNT=0
ACTIVE_SKILLS=()
ACTIVE_PATHS=()

if ! command -v python3 >/dev/null 2>&1; then
  echo "error: python3 is required to parse frontmatter" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is required to read plugin.json" >&2
  exit 1
fi

# --- Discover skills (flat and bucketed) ---

while IFS= read -r -d '' skill_md; do
  src="$(dirname "$skill_md")"
  name="$(basename "$src")"
  rel_path="${src#$REPO/}"

  SKILL_COUNT=$((SKILL_COUNT + 1))
  ACTIVE_SKILLS+=("$name")
  ACTIVE_PATHS+=("$rel_path")

  skill_errors=0

  # --- Parse frontmatter with a small parser ---
  parsed="$(python3 "$PARSER" "$skill_md")"
  error="$(printf '%s' "$parsed" | jq -r '.error // empty')"

  if [ -n "$error" ]; then
    echo "FAIL $name: $error" >&2
    ERRORS=$((ERRORS + 1))
    skill_errors=$((skill_errors + 1))
    continue
  fi

  fm_name="$(printf '%s' "$parsed" | jq -r '.data.name // empty')"
  fm_desc="$(printf '%s' "$parsed" | jq -r '.data.description // empty')"

  # --- Validate name ---
  # Kebab-case pattern: lowercase letters or digits, with optional single
  # hyphens between segments. No leading/trailing hyphen, no consecutive
  # hyphens. Matches the agentskills.io convention.
  if [ -z "$fm_name" ]; then
    echo "FAIL $name: missing 'name' in frontmatter" >&2
    ERRORS=$((ERRORS + 1))
    skill_errors=$((skill_errors + 1))
  elif ! echo "$fm_name" | grep -qE '^[a-z0-9](-?[a-z0-9])*$'; then
    echo "FAIL $name: name '$fm_name' must be kebab-case (lowercase letters, digits, optional single hyphens)" >&2
    ERRORS=$((ERRORS + 1))
    skill_errors=$((skill_errors + 1))
  elif [ "$fm_name" != "$name" ]; then
    echo "FAIL $name: frontmatter name '$fm_name' does not match folder name" >&2
    ERRORS=$((ERRORS + 1))
    skill_errors=$((skill_errors + 1))
  fi

  # --- Validate description ---
  if [ -z "$fm_desc" ]; then
    echo "FAIL $name: missing 'description' in frontmatter" >&2
    ERRORS=$((ERRORS + 1))
    skill_errors=$((skill_errors + 1))
  else
    desc_len=${#fm_desc}
    if [ "$desc_len" -gt 1024 ]; then
      echo "FAIL $name: description too long ($desc_len chars, max 1024)" >&2
      ERRORS=$((ERRORS + 1))
      skill_errors=$((skill_errors + 1))
    fi

    # Trigger-phrase check is intentionally broad (8+ phrases, case-insensitive)
    # and a WARNING, not an error: false positives are fine, but a missing
    # trigger phrase means the model may never load the skill. Do not tighten
    # this regex without updating docs/skill-authoring.md and the template's
    # "Use when..." guidance in tandem.
    if ! echo "$fm_desc" | grep -qiE '(use when|trigger|activate|invoke|run when|user says|user wants|user needs|mentions|asks for)'; then
      echo "WARN $name: description may lack trigger phrases (e.g. 'Use when...')" >&2
      WARNINGS=$((WARNINGS + 1))
    fi
  fi

  if [ "$skill_errors" -eq 0 ]; then
    echo "OK   $name"
  fi
done < <(find "$SKILLS_DIR" -name SKILL.md \
  -not -path '*/node_modules/*' \
  -not -path '*/_template/*' \
  -not -path '*/deprecated/*' \
  -not -path '*/in-progress/*' \
  -not -path '*/personal/*' \
  -print0)

# --- Check plugin.json sync ---
PLUGIN_JSON="$REPO/.claude-plugin/plugin.json"
if [ -f "$PLUGIN_JSON" ]; then
  for idx in "${!ACTIVE_PATHS[@]}"; do
    skill_path="${ACTIVE_PATHS[$idx]}"
    if ! jq -e --arg path "./$skill_path" '.skills | index($path)' "$PLUGIN_JSON" >/dev/null 2>&1; then
      echo "WARN ${ACTIVE_SKILLS[$idx]}: path './$skill_path' not found in plugin.json skills list" >&2
      WARNINGS=$((WARNINGS + 1))
    fi
  done
fi

# --- Check README.md sync ---
README_MD="$REPO/README.md"
if [ -f "$README_MD" ]; then
  for idx in "${!ACTIVE_PATHS[@]}"; do
    skill_name="${ACTIVE_SKILLS[$idx]}"
    skill_path="${ACTIVE_PATHS[$idx]}"
    if ! grep -qF "./$skill_path" "$README_MD"; then
      echo "WARN $skill_name: not linked in README.md (expected './$skill_path')" >&2
      WARNINGS=$((WARNINGS + 1))
    fi
  done
fi

# --- Summary ---
echo ""
echo "$SKILL_COUNT skill(s) checked."

if [ "$ERRORS" -gt 0 ]; then
  echo "$ERRORS error(s) found." >&2
fi
if [ "$WARNINGS" -gt 0 ]; then
  echo "$WARNINGS warning(s)." >&2
fi

if [ "$ERRORS" -gt 0 ]; then
  exit 1
fi

echo "All skills valid."
