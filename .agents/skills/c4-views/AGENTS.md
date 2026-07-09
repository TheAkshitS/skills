# AGENTS.md — c4-views skill

This folder defines the `c4-views` skill. When editing this skill, read `SKILL.md` first.

## References

Long-form reference material lives in `references/`:

- `references/c4-method.md` — C4 definitions, container edge cases, anti-patterns.
- `references/notations.md` — copy-pasteable L1/L2/L3 templates for Mermaid, Structurizr DSL, and C4-PlantUML.
- `references/review-rubric.md` — pass/fail review checks and the exact verdict format.

Load these on demand rather than all at once.

## Style

- Keep diagram rules notation-independent in the prose instructions.
- Use concrete examples (e.g. "replace 'Uses' with 'Submits payment request [HTTPS/REST]'").
- Update the element catalog, review rubric, and notation templates together when rules change.

## Validation

Run `bash scripts/validate-skills.sh` from the repo root before committing.
