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

# Timeout wrapper for per-skill eval runners (mirrors the gtimeout/timeout
# detection pattern in skills/external-model/scripts/run-model.sh): prefer
# GNU 'timeout', fall back to macOS's 'gtimeout' (coreutils via brew), else
# run unwrapped so a missing binary never blocks validation.
TIMEOUT_BIN=""
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_BIN="timeout"
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_BIN="gtimeout"
fi
EVAL_TIMEOUT_SECS=60

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
  rel_path="${src#"$REPO"/}"

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
  elif ! printf '%s\n' "$fm_name" | grep -qE '^[a-z0-9](-?[a-z0-9])*$'; then
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
    # Count characters, not bytes: jq's `length` on a string counts Unicode
    # codepoints, which matches the spec's 1024-*character* limit even for
    # multibyte UTF-8 descriptions (em dashes, accents, non-Latin scripts).
    # $parsed is already-parsed JSON from the frontmatter parser above, so
    # this reuses it instead of spawning a second python3 process per skill.
    desc_len="$(printf '%s' "$parsed" | jq -r '.data.description | length')"
    if [ "$desc_len" -gt 1024 ]; then
      echo "FAIL $name: description too long ($desc_len chars, max 1024)" >&2
      ERRORS=$((ERRORS + 1))
      skill_errors=$((skill_errors + 1))
    fi

    # A single-line, unquoted description containing ": " (colon-space) is
    # invalid YAML for strict parsers — GitHub renders SKILL.md frontmatter and
    # errors ("mapping values are not allowed in this context"). Our own parser
    # is lenient and accepts it, so guard against the class here. Quoted values
    # ("/') and block scalars (|/>) may legitimately contain ": ".
    raw_desc="$(sed -n '/^---$/,/^---$/p' "$skill_md" | grep -m1 '^description:')"
    desc_val="${raw_desc#description:}"
    desc_val="${desc_val# }"
    case "$desc_val" in
      '"'*|"'"*|'|'*|'>'*) : ;;  # quoted or block scalar — colons are safe
      *': '*)
        echo "FAIL $name: description has an unquoted ': ' — invalid YAML for strict parsers (e.g. GitHub); rephrase (use — ) or quote the value" >&2
        ERRORS=$((ERRORS + 1))
        skill_errors=$((skill_errors + 1))
        ;;
    esac

    # Trigger-phrase check is intentionally broad (8+ phrases, case-insensitive)
    # and a WARNING, not an error: false positives are fine, but a missing
    # trigger phrase means the model may never load the skill. Do not tighten
    # this regex without updating docs/skill-authoring.md and the template's
    # "Use when..." guidance in tandem.
    if ! printf '%s\n' "$fm_desc" | grep -qiE '(use when|trigger|activate|invoke|run when|user says|user wants|user needs|mentions|asks for)'; then
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

# --- Check for duplicate skill names (leaf-name collisions) ---
# link-skills.sh links skills into a flat directory by basename, so two
# bucketed skills that share a leaf name (skills/foo/x and skills/bar/x)
# would silently collide there even though `find` happily discovers both.
# `${ACTIVE_SKILLS[@]+"${ACTIVE_SKILLS[@]}"}` guards against bash 3.2's
# "unbound variable" error on an empty array under `set -u`.
dup_names="$(printf '%s\n' ${ACTIVE_SKILLS[@]+"${ACTIVE_SKILLS[@]}"} | sort | uniq -d)"
if [ -n "$dup_names" ]; then
  while IFS= read -r dup; do
    [ -z "$dup" ] && continue
    echo "FAIL $dup: duplicate skill name — multiple skills share this leaf name (link-skills.sh links by basename)" >&2
    ERRORS=$((ERRORS + 1))
  done <<< "$dup_names"
fi

# --- Run per-skill eval graders (generic) ---
# Any active skill that ships an executable evals/run.sh gets it run here; a
# non-zero exit counts as an error. The SKILL.md dir is the skill source dir.
if [ -z "$TIMEOUT_BIN" ]; then
  echo "note: no 'timeout'/'gtimeout' on PATH — per-skill evals run without a timeout" >&2
fi
for idx in "${!ACTIVE_PATHS[@]}"; do
  eval_runner="$REPO/${ACTIVE_PATHS[$idx]}/evals/run.sh"
  if [ -x "$eval_runner" ]; then
    if [ -n "$TIMEOUT_BIN" ]; then
      runner_cmd=("$TIMEOUT_BIN" "${EVAL_TIMEOUT_SECS}s" "$eval_runner")
    else
      runner_cmd=("$eval_runner")
    fi
    # A hanging eval must not stall validation forever.
    if out="$("${runner_cmd[@]}" 2>&1)"; then
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
  # Run uncaptured so its per-skill OK/FAIL lines actually surface, on
  # success and failure alike, instead of being swallowed on the happy path.
  "$REPO/scripts/eval-triggers.sh" || ERRORS=$((ERRORS + 1))
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
# skill must have a byte-for-byte (modulo trailing whitespace) copy in both,
# and every mirror entry must trace back to a skills/ source — no orphans
# left behind by a skill that was deleted from skills/ without re-running
# the sync. Since committing mirrors now depends on this check, drift and
# orphans are ERRORS (not warnings) so CI actually fails on them. Only a
# wholly absent mirror directory stays a WARNING, so a fresh checkout before
# the first sync doesn't hard-fail local dev. Fix: run
# scripts/sync-copied-skills.sh.
for mirror_rel in .claude/skills .agents/skills; do
  mirror_abs="$REPO/$mirror_rel"
  if [ ! -d "$mirror_abs" ]; then
    echo "WARN $mirror_rel/ missing — run scripts/sync-copied-skills.sh" >&2
    WARNINGS=$((WARNINGS + 1))
    continue
  fi

  # Forward direction: every active skills/ source has a matching mirror
  # copy, and the copy's full contents (whitespace-normalized) match the
  # source. Compares the whole file, not just frontmatter, so a drifted body
  # (the actual instructions) is caught too.
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
      echo "FAIL $mirror_rel/$rel_skill/SKILL.md missing — run scripts/sync-copied-skills.sh" >&2
      ERRORS=$((ERRORS + 1))
      continue
    fi

    if ! diff -q \
        <(sed -e 's/[[:space:]]*$//' "$src_skill") \
        <(sed -e 's/[[:space:]]*$//' "$mirror_skill") >/dev/null 2>&1; then
      echo "FAIL $mirror_rel/$rel_skill drifted from $skill_path — run scripts/sync-copied-skills.sh" >&2
      ERRORS=$((ERRORS + 1))
    fi
  done

  # Reverse direction: every mirror entry must trace back to a skills/
  # source. A mirror SKILL.md with no counterpart under skills/ is an
  # orphan (most likely deleted from skills/ without re-running the sync
  # script's --delete pass). -L: a mirror entry may be a symlink (e.g. left
  # over from a manual test or a partial migration) rather than a real
  # copy; follow it so an orphan hiding behind a symlinked directory is
  # still caught.
  while IFS= read -r -d '' mirror_md; do
    mdir="$(dirname "$mirror_md")"
    rel_skill="${mdir#"$mirror_abs"/}"
    src_skill="$REPO/skills/$rel_skill/SKILL.md"
    if [ ! -f "$src_skill" ]; then
      echo "FAIL $mirror_rel/$rel_skill has no skills/$rel_skill source — orphaned mirror entry, delete it or run scripts/sync-copied-skills.sh" >&2
      ERRORS=$((ERRORS + 1))
    fi
  done < <(find -L "$mirror_abs" -name SKILL.md -print0)
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
