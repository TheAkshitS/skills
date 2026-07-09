# Authoring a skill

## Required `SKILL.md` frontmatter

- `name`: kebab-case, matches the folder name.
- `description`: what the skill does **and when to trigger it** — concrete
  phrases or situations that should activate it. Max 1024 chars.

Both fields are required by the
[Agent Skills spec](https://agentskills.io/specification) and by every
supported harness (Claude Code, pi, opencode).

## Optional frontmatter

Spec fields (per the
[Agent Skills spec](https://agentskills.io/specification)):

- `license`: short license name or reference to a bundled license file
  (e.g. `MIT`). Optional but recommended.
- `compatibility`: free-text environment requirements (e.g. `"requires
  opencode or cursor-agent on PATH"`). Max 500 chars.
- `metadata`: arbitrary key-value map for client-specific extra fields.
  No skill in this repo uses it yet; add per-skill only when a real use
  appears (YAGNI — empty metadata would be pure boilerplate).
- `allowed-tools`: space-separated pre-approved tools (e.g. `bash`).
  Experimental; support varies by harness.

skills.sh conventions (widely adopted, **not** in the agentskills.io
spec — check the host harness before relying on them):

- `argument-hint`: placeholder text shown in the slash-command UI
  (e.g. `"What system do you want to diagram?"`).
- `disable-model-invocation: true`: prevents the model from auto-invoking
  the skill. Use for skills that should only run via explicit slash-command
  (e.g. setup wizards, teaching sessions).

See `skills/_template/SKILL.md.template` for a full example.

## Cross-harness notes

The skills in this repo target every Agent Skills spec harness (Claude Code,
pi, opencode, skills.sh-compatible). To keep a skill portable:

- **Stick to spec frontmatter.** `name` + `description` are the only fields
  every harness is guaranteed to read; optional spec fields (`license`,
  `compatibility`, `allowed-tools`) are best-effort.
- **Use relative paths** for scripts and references. `scripts/run.sh` works
  in every harness; an absolute path breaks the moment someone clones the
  repo elsewhere.
- **No harness-locked markup** in `SKILL.md` body. Plain Markdown only. No
  Claude-specific XML, no pi-specific directives, no opencode conventions.
- **Slash-command names will differ** across harnesses: `/c4-views` in
  Claude Code, `/skill:c4-views` in pi. Document both in the per-skill
  README if the difference matters to your workflow.
- **`name` must match the folder name** in this repo (the spec allows
  divergence; we don't, because it makes mirror sync and validation
  trivial). The validator enforces this.

## Adding a new skill

1. Copy `skills/_template/SKILL.md.template` to `skills/<name>/SKILL.md`
   (or `skills/<bucket>/<name>/SKILL.md` once buckets are adopted).
2. Add a linked entry under **Skills** in `README.md` with trigger phrases.
3. Add the skill path to `.claude-plugin/plugin.json` under `"skills"`.
4. Optionally add a nested `AGENTS.md` in `skills/<name>/` for skill-specific instructions.
5. Run `bash scripts/validate-skills.sh` to check frontmatter and consistency.
6. Run `bash scripts/sync-copied-skills.sh` to refresh the in-repo mirrors
   under `.claude/skills/` and `.agents/skills/`.

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

See [Local workflow & PR](./local-workflow.md) for branching, validation, and
PR steps once a skill is authored.
