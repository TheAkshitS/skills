# Repo layout

## Current structure (flat)

- `skills/<skill-name>/SKILL.md` — one folder per skill. Companion files
  (`references/*.md`, `scripts/`) sit beside `SKILL.md`.
- `skills/_template/SKILL.md.template` — copy this to start a new skill. Not
  a real skill; excluded from `link-skills.sh`, `validate-skills.sh`, and
  `plugin.json`. Named `.template` (not `SKILL.md`) so the `skills.sh`
  installer's filename-based scan skips it too.

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
- `docs/pi-install.md` — pi install recipes
- `.out-of-scope/` — rejected feature requests and skill ideas
- `.claude-plugin/plugin.json` — skills.sh plugin manifest
- `.claude/skills/` — in-repo mirror (see [Mirror](../CONTEXT.md#terms) in
  the glossary) for Claude Code
- `.agents/skills/` — in-repo mirror for pi and any Agent Skills spec
  harness
- `scripts/validate-skills.sh` — frontmatter, eval, and mirror consistency;
  invokes `scripts/eval-triggers.sh` for per-skill trigger evals
- `scripts/link-skills.sh` — symlink skills into every supported harness's
  global dir (`~/.claude/skills`, `~/.pi/agent/skills`, `~/.agents/skills`)
- `scripts/install-pi.sh` — pi-specific install: `link`, `settings`, or
  `project` mode
- `scripts/sync-copied-skills.sh` — refresh in-repo mirror copies via
  `rsync --delete` so removed skills vanish from `.claude/skills/` and
  `.agents/skills/` too
- `scripts/eval-triggers.sh` — asserts each skill's `evals/triggers.json`
  positive/negative prompts match its declared trigger phrases; invoked
  automatically by `validate-skills.sh`, not run standalone
- `scripts/list-skills.sh` — list all active skill paths
- `.github/workflows/release-please.yml` — release-please CI trigger
- `release-please-config.json` — release-please strategy config
- `.release-please-manifest.json` — current released version (single source of truth)
