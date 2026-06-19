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

[release-please](https://github.com/googleapis/release-please) runs on push to
`main` only — not on pull requests. Merging a conventional PR into `main`
opens a single Release PR; merging the Release PR tags the commit and
publishes a GitHub Release.

### Files

- `release-please-config.json` — strategy + tag format. Current config uses
  `release-type: simple` (single package at the repo root, no `package.json`
  required) with `v`-prefixed tags and `CHANGELOG.md` output.
- `.release-please-manifest.json` — current released version. Initial: `0.1.0`.
- `.github/workflows/release-please.yml` — triggers `googleapis/release-please-action@v4`
  on `push` to `main`. Reads config from `main`, not the PR branch.

> **Don't add a `package.json` to the repo root.** release-please will
> silently switch the strategy from `simple` to `node` and look for a
> `version` field there. If you need a `package.json`, move it under
> `skills/<name>/` and add a matching `packages` entry in
> `release-please-config.json` — do not change the root strategy without
> updating this section.

### Bump rules

| Commit type                    | Semver bump |
| ------------------------------ | ----------- |
| `!` or `BREAKING CHANGE:`      | major       |
| `feat`                         | minor       |
| `fix`, `perf`                  | patch       |
| anything else                  | none        |

Tags are `v`-prefixed (e.g. `v0.2.0`). `CHANGELOG.md` is regenerated on
each release.

### Bootstrap

The first time release-please runs on a fresh repo it will fail with
`Missing required manifest config` if either config file is missing from
`main`. Both files must land on `main` before the first release push — the
bootstrap PR is responsible for this. After merge, the first Release PR
will cut `v0.1.0` → next-version based on the first conventional commit
on `main`.
