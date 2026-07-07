#!/usr/bin/env bash
set -euo pipefail

# eval-triggers.sh — hermetic proxy for the description-trigger evals the
# agentskills.io "Optimizing skill descriptions" guide recommends.
#
# A real activation eval loads the description into an agent and checks it
# activates on positive prompts and does NOT on negative prompts. That needs
# a model call. This cheaper, fully hermetic check asserts the structural
# prerequisite: every trigger phrase you declared appears in the
# representative positive prompts (so your prompts exercise the triggers)
# and none appears in the negative prompts (so the negatives actually
# exercise non-activation). It also asserts each declared trigger phrase is
# present in the SKILL.md description (so the triggers the skill relies on
# are spelled out for the agent to read).
#
# Per-skill file: skills/<name>/evals/triggers.json
#   {
#     "skill_name": "<name>",
#     "trigger_phrases": ["C4", "Mermaid", "diagram"],   # each must be in description
#     "positive": ["draw an architecture diagram", "..."], # each must contain >=1 trigger
#     "negative": ["refactor this fn", "..."]              # each must contain NO trigger
#   }
#
# Exits 1 if any skill fails; 0 otherwise. Skills without triggers.json are
# skipped silently (the file is recommended, not required).

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_DIR="$REPO/skills"
PARSER="$REPO/scripts/lib/parse-frontmatter.py"

if ! command -v python3 >/dev/null 2>&1; then echo "error: python3 required" >&2; exit 1; fi
if ! command -v jq     >/dev/null 2>&1; then echo "error: jq required"     >&2; exit 1; fi

PASS=0; FAIL=0

# lower-case substring test: phrase_in $haystack $needle
phrase_in() { case "$1" in *"$2"*) return 0;; *) return 1;; esac; }
lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

while IFS= read -r -d '' skill_md; do
  src="$(dirname "$skill_md")"
  name="$(basename "$src")"
  [ "$name" = "_template" ] && continue

  triggers="$src/evals/triggers.json"
  [ -f "$triggers" ] || continue

  desc="$(python3 "$PARSER" "$skill_md" | jq -r '.data.description // ""')"
  desc_lc="$(lower "$desc")"

  phrases=(); while IFS= read -r line; do phrases+=("$line"); done < <(jq -r '.trigger_phrases[]?' "$triggers")
  pos=();     while IFS= read -r line; do pos+=("$line");     done < <(jq -r '.positive[]?'        "$triggers")
  neg=();     while IFS= read -r line; do neg+=("$line");     done < <(jq -r '.negative[]?'        "$triggers")

  skill_fail=0

  # 1. Each declared trigger phrase must appear in the description.
  for phrase in ${phrases[@]+"${phrases[@]}"}; do
    phrase_in "$desc_lc" "$(lower "$phrase")" || {
      echo "FAIL $name: trigger phrase '$phrase' not present in description" >&2
      skill_fail=1
    }
  done

  # 2. Each positive prompt must contain >=1 trigger phrase.
  for prompt in ${pos[@]+"${pos[@]}"}; do
    p_lc="$(lower "$prompt")"; hit=0
    for phrase in ${phrases[@]+"${phrases[@]}"}; do
      if phrase_in "$p_lc" "$(lower "$phrase")"; then hit=1; break; fi
    done
    [ "$hit" -eq 0 ] && {
      echo "FAIL $name: positive prompt '$prompt' contains no trigger phrase" >&2
      skill_fail=1
    }
  done

  # 3. Each negative prompt must contain NO trigger phrase.
  for prompt in ${neg[@]+"${neg[@]}"}; do
    p_lc="$(lower "$prompt")"; bad=""
    for phrase in ${phrases[@]+"${phrases[@]}"}; do
      if phrase_in "$p_lc" "$(lower "$phrase")"; then bad="$bad $phrase"; fi
    done
    [ -n "$bad" ] && {
      echo "FAIL $name: negative prompt '$prompt' leaks trigger(s):$bad" >&2
      skill_fail=1
    }
  done

  if [ "$skill_fail" -eq 0 ]; then
    echo "OK   $name: triggers"
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
  fi
done < <(find "$SKILLS_DIR" -name SKILL.md \
  -not -path '*/node_modules/*' \
  -not -path '*/_template/*' \
  -not -path '*/deprecated/*' \
  -not -path '*/in-progress/*' \
  -not -path '*/personal/*' \
  -print0)

echo ""
echo "trigger evals: $PASS passed, $FAIL failed"
[ "$FAIL" -gt 0 ] && exit 1
exit 0
