# Eval scaffold for `c4-views`

These evals encode the **objective invariants** of the skill: the three
reference files exist and carry the templates and check alphabet the
`SKILL.md` instructs the agent to author from. If a refactor trims a
template or drops a check id, the grader catches it before the skill
silently loses coverage.

## Why no LLM-graded quality evals

The c4-views skill produces diagrams in an LLM-driven authoring loop, so
its observable output quality is genuinely subjective — element naming,
level selection, notation choice, label specificity. The
[agentskills.io "Evaluating skill output quality"](https://agentskills.io/skill-creation/evaluating-skills)
guide is explicit that such qualities are reserved for **human or
LLM-assisted review**, not pass/fail assertions:

> Some qualities — writing style, visual design, whether the output "feels
> right" — are hard to decompose into pass/fail checks. … Reserve
> assertions for things that can be checked objectively.

An LLM-graded eval path is therefore deliberately not built here. It would
require an API key at eval time and would break the hermetic,
zero-dependency principle the `external-model` evals already enforce (they
pass with none of the real CLIs installed). Add an LLM-graded quality eval
**when a regression in diagram quality shows up in practice** — not
preemptively.

## Behaviors covered

1. **Mermaid native C4 templates (L1–L3)** — `C4Context` / `C4Container` /
   `C4Component` all present in `references/notations.md`.
2. **Structurizr DSL template** — `workspace {` block present.
3. **C4-PlantUML templates** — `!include` directives for `C4_Context.puml`,
   `C4_Container.puml`, `C4_Component.puml`.
4. **Review-rubric check alphabet** — every id in `G1–G6`, `E1–E9`, `R1–R6`
   appears as a bounded token in `references/review-rubric.md`.
5. **SKILL.md self-consistency** — names all three reference files and
   carries the normative "Produce L1 + L2 by default" directive.

## Running

    bash evals/run.sh

Hermetic: reads only the skill's own reference files. No network, no LLM,
no external toolchain. Passes on a fresh clone with nothing installed.