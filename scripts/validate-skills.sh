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
    # Count characters, not bytes: bash's ${#var} is locale-dependent and
    # counts bytes under a C/POSIX locale, which would falsely flag multibyte
    # UTF-8 descriptions (em dashes, accents, non-Latin scripts) as over the
    # spec's 1024-*character* limit. python3 is already a hard dependency here.
    desc_len="$(python3 -c 'import sys; print(len(sys.argv[1]))' "$fm_desc")"
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

# --- Run per-skill eval graders (generic) ---
# Any active skill that ships an executable evals/run.sh gets it run here; a
# non-zero exit counts as an error. The SKILL.md dir is the skill source dir.
for idx in "${!ACTIVE_PATHS[@]}"; do
  eval_runner="$REPO/${ACTIVE_PATHS[$idx]}/evals/run.sh"
  if [ -x "$eval_runner" ]; then
    if out="$("$eval_runner" 2>&1)"; then
      echo "OK   ${ACTIVE_SKILLS[$idx]}: evals"
    else
      printf 'FAIL %s: evals\n' "${ACTIVE_SKILLS[$idx]}" >&2
      printf '  output:\n%s\n' "$out" >&2
      ERRORS=$((ERRORS + 1))
    fi
  fi
done

# --- Description-trigger evals (hermetic proxy) ---
# Runs scripts/eval-triggers.sh: asserts each skill's declared trigger_phrases
# appear in its description and that declared positive/negative prompts
# correctly do/don't overlap those phrases. A real activation eval calls an
# LLM; this is the structural prerequisite. Skills with no evals/triggers.json
# are skipped silently (the file is recommended, not required).
if [ -x "$REPO/scripts/eval-triggers.sh" ]; then
  if out="$("$REPO/scripts/eval-triggers.sh" 2>&1)"; then
    :   # eval-triggers.sh prints its own per-skill OK lines
  else
    printf '%s\n' "$out" >&2
    ERRORS=$((ERRORS + 1))
  fi
fi

# --- skills-ref (optional) ---
# The agentskills.io spec points at the `skills-ref validate` reference
# validator (https://github.com/agentskills/agentskills, skills-ref/). It is
# not on npm; users install it separately. If it is on PATH, run it against
# each skill and surface failures. If it is absent, emit one informational
# line and continue — the in-repo frontmatter parser already enforces the
# spec-required rules (kebab name + dir match + description length + trigger
# phrases), so this is a complementary, not load-bearing, check.
if command -v skills-ref >/dev/null 2>&1; then
  for idx in "${!ACTIVE_PATHS[@]}"; do
    skill_dir="$REPO/${ACTIVE_PATHS[$idx]}"
    if out="$(skills-ref validate "$skill_dir" 2>&1)"; then
      echo "OK   ${ACTIVE_SKILLS[$idx]}: skills-ref"
    else
      printf 'FAIL %s: skills-ref\n' "${ACTIVE_SKILLS[$idx]}" >&2
      printf '  %s\n' "$out" >&2
      ERRORS=$((ERRORS + 1))
    fi
  done
else
  echo "note: skills-ref not on PATH (optional, install from agentskills/agentskills)"
fi

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

# --- Check in-repo distribution mirrors ---
# .claude/skills/ and .agents/skills/ are committed copies that let the repo
# work as a drop-in folder for Claude Code + pi + opencode. Each active
# skill must have a copy in both, and the SKILL.md must match. Drift here
# means a user who clones the repo gets stale skills. Fix: run
# scripts/sync-copied-skills.sh.
for mirror_rel in .claude/skills .agents/skills; do
  mirror_abs="$REPO/$mirror_rel"
  if [ ! -d "$mirror_abs" ]; then
    echo "WARN $mirror_rel/ missing — run scripts/sync-copied-skills.sh" >&2
    WARNINGS=$((WARNINGS + 1))
    continue
  fi

  for idx in "${!ACTIVE_PATHS[@]}"; do
    skill_path="${ACTIVE_PATHS[$idx]}"
    # Use the same relative path the plugin.json/README checks use, so bucketed
    # skills (skills/<bucket>/<name>) that the find walk supports are compared
    # against the right mirror file. The mirror preserves the sub-tree under
    # skills/, so strip that prefix to get the path relative to the mirror root.
    rel_skill="${skill_path#skills/}"
    src_skill="$REPO/$skill_path/SKILL.md"
    mirror_skill="$mirror_abs/$rel_skill/SKILL.md"

    if [ ! -f "$mirror_skill" ]; then
      echo "WARN $mirror_rel/$rel_skill/SKILL.md missing — run scripts/sync-copied-skills.sh" >&2
      WARNINGS=$((WARNINGS + 1))
      continue
    fi

    # Compare just the frontmatter (between the two --- delimiters at the top).
    # The full bodies can legitimately differ in trailing whitespace, but the
    # metadata block is what determines what the harness sees.
    src_fm="$(awk 'NR==1 && /^---$/ {f=1; next} f && /^---$/ {exit} f {print}' "$src_skill")"
    mirror_fm="$(awk 'NR==1 && /^---$/ {f=1; next} f && /^---$/ {exit} f {print}' "$mirror_skill")"
    if [ "$src_fm" != "$mirror_fm" ]; then
      echo "WARN $mirror_rel/$rel_skill frontmatter drifted from $skill_path — run scripts/sync-copied-skills.sh" >&2
      WARNINGS=$((WARNINGS + 1))
    fi
  done
done

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
