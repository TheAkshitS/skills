# AGENTS.md

Shareable agent skills. Plain Markdown, no build step. Works with Claude Code,
[pi](https://github.com/earendil-works/pi), and any
[Agent Skills spec](https://agentskills.io/specification)-compatible harness
(including anything [skills.sh](https://skills.sh)-compatible).

## Layered instructions

If multiple `AGENTS.md` apply, the closest one to the edited file wins. Explicit
chat prompts override everything. Treat this file as living documentation.

## Validate

Before committing any skill change: `bash scripts/validate-skills.sh` — must
pass clean. This also checks the mirrors (see [Mirror](./CONTEXT.md#terms)
in the glossary): drift from `skills/`, or an orphaned mirror entry with no
`skills/` source, is a hard **error** (re-run `scripts/sync-copied-skills.sh`
to refresh the mirrors), so cloned-repo users never get stale skills.

## Branching

PRs target `develop`. `main` is release-only and is updated by the
release-please bot, not by feature PRs. Treat `main` as immutable from a
contributor's perspective — if a workflow reads config from `main`, the
config must already be on `main`, not waiting on the PR to merge.

## Security

Skill scripts may read the repo or write to `~/.claude/skills`,
`~/.pi/agent/skills`, or `~/.agents/skills` only. Never commit secrets,
credentials, or personal data. Review external links before shipping.

## Reference

- [Domain glossary](./CONTEXT.md)
- [Authoring a skill](./docs/skill-authoring.md)
- [Repo layout](./docs/repo-layout.md)
- [Installing for pi](./docs/pi-install.md)
- [Local workflow & PR](./docs/local-workflow.md) — see **Releases** for
  the release-please file layout, `release-type: simple` rules, and
  bootstrap requirements
- [Architecture decisions](./docs/adr/)
