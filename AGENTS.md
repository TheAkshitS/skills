# AGENTS.md

Shareable agent skills. Plain Markdown, no build step. Works with Claude Code
and any [skills.sh](https://skills.sh)-compatible agent.

## Layered instructions

If multiple `AGENTS.md` apply, the closest one to the edited file wins. Explicit
chat prompts override everything. Treat this file as living documentation.

## Security

Skill scripts may read the repo or write to `~/.claude/skills` only. Never
commit secrets, credentials, or personal data. Review external links before
shipping.

## Reference

- [Domain glossary](./CONTEXT.md)
- [Authoring a skill](./docs/skill-authoring.md)
- [Repo layout](./docs/repo-layout.md)
- [Local workflow & PR](./docs/local-workflow.md)
- [Architecture decisions](./docs/adr/)
