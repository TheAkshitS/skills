# Authoring a skill

## Required `SKILL.md` frontmatter

- `name`: kebab-case, matches the folder name.
- `description`: what the skill does **and when to trigger it** — concrete
  phrases or situations that should activate it. Max 1024 chars.

## Optional frontmatter

- `argument-hint`: placeholder text shown in the slash-command UI
  (e.g. `"What system do you want to diagram?"`).
- `disable-model-invocation: true`: prevents the model from auto-invoking
  the skill. Use for skills that should only run via explicit slash-command
  (e.g. setup wizards, teaching sessions).

See `skills/_template/SKILL.md` for a full example.

## Adding a new skill

1. Create `skills/<name>/SKILL.md` (or `skills/<bucket>/<name>/SKILL.md` once buckets are adopted).
2. Add a linked entry under **Skills** in `README.md` with trigger phrases.
3. Add the skill path to `.claude-plugin/plugin.json` under `"skills"`.
4. Optionally add a nested `AGENTS.md` in `skills/<name>/` for skill-specific instructions.
5. Run `bash scripts/validate-skills.sh` to check frontmatter and consistency.

## Companion files

When `SKILL.md` exceeds 100 lines or covers distinct knowledge domains,
split into companion files loaded on demand:

- `references/*.md` — long-form reference material (method docs, templates, rubrics)
- `scripts/` — utility scripts for deterministic operations
- Format specs (e.g. `CONTEXT-FORMAT.md`, `ADR-FORMAT.md`) — templates the agent uses to produce structured output

Point to companion files from `SKILL.md` with clear "read when" instructions
so the agent loads them only when needed, not on every invocation.

## Skill composition

Skills may reference each other to form a composition graph. For example:

- A `triage` skill might invoke `/grill-me` to flesh out issues
- A `diagnose` skill might hand off to `/improve-codebase-architecture`
- A `to-issues` skill might reference `/setup` for issue tracker config

Reference other skills by their slash-command name. The agent resolves these
from installed skills at runtime. Design skills to be **composable, not
dependent** — each should work standalone, enhanced when others are present.

## Per-skill README

Each skill may carry its own `README.md` for standalone distribution (e.g.
someone installing just that skill via `npx skills add`). This intentionally
duplicates root-level install instructions — the per-skill README must work
independently.

## Contributing

1. Fork and branch from `main`.
2. Follow the steps above.
3. Run `bash scripts/validate-skills.sh` — must pass clean.
4. Open a PR with a description of the skill and example triggers.
