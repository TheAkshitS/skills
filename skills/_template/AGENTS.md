# AGENTS.md — your-skill-name skill

This folder defines the `your-skill-name` skill. When editing this skill, read `SKILL.md` first.

## Domain glossary

Use terms from [CONTEXT.md](../../CONTEXT.md) consistently in skill instructions.

## Companion files

Put long-form material in companion files loaded on demand:

- `references/*.md` — method docs, templates, rubrics
- `scripts/` — utility scripts for deterministic operations
- Format specs (e.g. `CONTEXT-FORMAT.md`) — output templates

Point to them from `SKILL.md` with "read when" instructions. Do not preload all companion files.

## Style

- Keep instructions direct and specific.
- Put trigger phrases and activation criteria in the frontmatter `description`.
- Update companion files alongside `SKILL.md` when rules change.
- Use concrete examples over abstract descriptions.

## Validation

Run `bash scripts/validate-skills.sh` from the repo root before committing.
