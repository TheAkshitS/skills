# Contributing

Thanks for considering a contribution.

## For skill contributions

1. Read [docs/skill-authoring.md](./docs/skill-authoring.md) — covers frontmatter
   requirements, companion files, and composition conventions.
2. Read [docs/local-workflow.md](./docs/local-workflow.md) — covers the local
   validation, linking, and PR workflow.
3. Read [CONTEXT.md](./CONTEXT.md) — the domain glossary. Use **Bucket**,
   **Trigger**, **Reference** consistently.

## Before opening a PR

- `bash scripts/validate-skills.sh` must pass clean.
- `bash tests/test-validate-skills.sh` must pass clean.
- New domain terms get added to `CONTEXT.md`.
- New skills are added to both `README.md` and `.claude-plugin/plugin.json`.
- Bucketing decisions follow
  [ADR-0001](./docs/adr/0001-flat-then-bucket-structure.md).
- Use [Conventional Commits](https://www.conventionalcommits.org/).
  release-please reads commit types to bump semver and write
  `CHANGELOG.md`.

## Questions

Open an issue or check [`.out-of-scope/`](./.out-of-scope/) for previously
rejected proposals.
