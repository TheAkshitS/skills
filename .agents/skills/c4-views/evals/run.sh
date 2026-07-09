#!/usr/bin/env bash
set -euo pipefail

# c4-views/evals/run.sh — hermetic, executable grader for the c4-views skill.
#
# The c4-views skill produces diagrams in an LLM-driven authoring loop, so its
# observable behavior is genuinely subjective: element naming, level selection,
# notation choice, label specificity. The agentskills.io "Evaluating skill
# output quality" guide is explicit that such qualities are reserved for human
# or LLM-assisted review, not pass/fail assertions. An LLM-graded eval path is
# deliberately NOT built here: it would require an API key at eval time and
# would break the hermetic, zero-dependency principle the external-model evals
# already enforce (they pass with none of the real CLIs installed).
#
# Instead, this grader encodes the objective invariants of the skill itself: the
# three reference files exist and carry the templates and check alphabet the
# SKILL.md instructs the agent to author from. If a refactor trims a template
# or drops a check id, this grader catches it before the skill silently loses
# coverage. Mechanical-only by design; add an LLM-graded quality eval when a
# regression in diagram quality shows up in practice.

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$HERE/.." && pwd)"
NOTATIONS="$SKILL_DIR/references/notations.md"
RUBRIC="$SKILL_DIR/references/review-rubric.md"
SKILL_MD="$SKILL_DIR/SKILL.md"

PASS=0; FAIL=0
note_pass() { printf 'PASS %s: %s\n' "$1" "$2"; PASS=$((PASS + 1)); }
note_fail() { printf 'FAIL %s: %s\n' "$1" "$2" >&2; FAIL=$((FAIL + 1)); }

# assert <id> <desc> <ok-int>   (1 = pass, 0 = fail)
assert() { if [ "$3" -eq 1 ]; then note_pass "$1" "$2"; else note_fail "$1" "$2"; fi; }
contains() { [ -f "$1" ] && grep -qF "$2" "$1"; }
contains_re() { [ -f "$1" ] && grep -qE "$2" "$1"; }

# eval-1: Mermaid native C4 templates present in notations.md
e1_ok=1
for sym in C4Context C4Container C4Component; do contains "$NOTATIONS" "$sym" || e1_ok=0; done
assert 1 "Mermaid native C4 templates (L1–L3) present" $(( e1_ok ))

# eval-2: Structurizr DSL template present
e2_ok=0; contains "$NOTATIONS" "workspace {" && e2_ok=1
assert 2 "Structurizr DSL template present" $(( e2_ok ))

# eval-3: C4-PlantUML includes for all static levels
e3_ok=1
for inc in C4_Context.puml C4_Container.puml C4_Component.puml; do contains "$NOTATIONS" "$inc" || e3_ok=0; done
assert 3 "C4-PlantUML templates (Context/Container/Component) present" $(( e3_ok ))

# eval-4: review-rubric.md carries the full G1–G6 / E1–E9 / R1–R6 alphabet
e4_ok=1; missing=""
for id in G1 G2 G3 G4 G5 G6 E1 E2 E3 E4 E5 E6 E7 E8 E9 R1 R2 R3 R4 R5 R6; do
  # check id appears as a boundary-bounded token (e.g. "**G1**" or " G1 ")
  if ! grep -qE "(^|[^A-Za-z0-9])${id}([^A-Za-z0-9]|\$)" "$RUBRIC"; then
    e4_ok=0; missing="$missing $id"
  fi
done
if [ $e4_ok -eq 1 ]; then
  note_pass 4 "review-rubric.md has full G/E/R check alphabet"
else
  note_fail 4 "review-rubric.md missing check ids:$missing"
fi

# eval-5: SKILL.md names all three reference files and mandates the L1+L2 default
e5_ok=1
for ref in "references/c4-method.md" "references/notations.md" "references/review-rubric.md"; do
  contains "$SKILL_MD" "$ref" || e5_ok=0
done
# "Produce L1 + L2 by default" is the normative directive in §2(b).
contains_re "$SKILL_MD" "Produce L1 \+ L2 by default" || contains_re "$SKILL_MD" "Default to L1 \+ L2" || e5_ok=0
assert 5 "SKILL.md names all references and mandates L1+L2 default" $(( e5_ok ))

echo ""
echo "c4-views evals: $PASS passed, $FAIL failed (5 total)"
[ "$FAIL" -gt 0 ] && exit 1
echo "All c4-views evals passed."