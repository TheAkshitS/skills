# Local workflow

## Symlink skills

Symlink every real skill into `~/.claude/skills`:

```bash
bash scripts/link-skills.sh
```

This targets Claude Code only. Other agents (opencode, Codex, Cursor) use
different skill directories — install via `npx skills add` for those.

## Validate skills

Check frontmatter and consistency before committing:

```bash
bash scripts/validate-skills.sh
```

Verifies every skill folder has `SKILL.md` with valid `name` (matching folder)
and `description` (under 1024 chars, with trigger phrases) in frontmatter.
Also checks that all active skills are listed in `plugin.json` and linked in
`README.md`.

## List skills

Show all active skill paths:

```bash
bash scripts/list-skills.sh
```

Useful for debugging and verifying skill discovery after adding or reorganizing
skills.

## PR workflow

1. Run `bash scripts/validate-skills.sh` — must pass clean.
2. Update `README.md` and `docs/repo-layout.md` if adding, removing, or
   reorganizing skills.
3. Keep diffs minimal and focused on one skill or one change category.
4. Update `CONTEXT.md` if you introduce a new domain term.
5. Use [Conventional Commits](https://www.conventionalcommits.org/) for the PR
   title and squash-merge message. release-please reads them to bump semver.

## Releases

[release-please](https://github.com/googleapis/release-please) watches `main`
and opens a single Release PR. Merging the Release PR tags the commit and
publishes a GitHub Release.

| Commit type    | Semver bump |
| -------------- | ----------- |
| `!` or `BREAKING CHANGE:` | major |
| `feat`         | minor       |
| `fix`, `perf`  | patch       |
| anything else  | none        |

Current version lives in `.release-please-manifest.json`. Initial version:
`0.1.0`. Tags are prefixed with `v` (e.g. `v0.2.0`).
