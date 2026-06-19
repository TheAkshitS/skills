# Repo layout

## Current structure (flat)

- `skills/<skill-name>/SKILL.md` — one folder per skill. Companion files
  (`references/*.md`, `scripts/`) sit beside `SKILL.md`.
- `skills/_template/SKILL.md` — copy this to start a new skill. Not a real
  skill; excluded from `link-skills.sh`, `validate-skills.sh`, and `plugin.json`.

## Planned structure (at 3+ skills)

Adopt buckets under `skills/`:

- `skills/engineering/<skill-name>/` — daily code work (diagrams, TDD, debugging, architecture)
- `skills/productivity/<skill-name>/` — general workflow tools (grilling, handoff, teaching)
- `skills/misc/<skill-name>/` — kept around but rarely used

Buckets excluded from `plugin.json` and README:

- `skills/personal/<skill-name>/` — tied to individual setup, not promoted
- `skills/in-progress/<skill-name>/` — drafts not yet ready to ship
- `skills/deprecated/<skill-name>/` — no longer maintained

See [ADR-0001](./adr/0001-flat-then-bucket-structure.md) for the reasoning
behind this approach.

## Supporting files

- `CONTEXT.md` — domain glossary and shared language (at repo root)
- `docs/adr/` — architecture decision records
- `.out-of-scope/` — rejected feature requests and skill ideas
- `.claude-plugin/plugin.json` — skills.sh plugin manifest
- `scripts/validate-skills.sh` — frontmatter and consistency validation
- `scripts/link-skills.sh` — symlink skills into `~/.claude/skills`
- `scripts/list-skills.sh` — list all active skill paths
