# Skills

Small, composable agent skills for real engineering work. Each skill is
independent, trigger-activated, and designed to work with Claude Code and any
[skills.sh](https://skills.sh)-compatible agent.

[![skills.sh](https://skills.sh/b/TheAkshitS/skills)](https://skills.sh/TheAkshitS/skills)

## Why

Monolithic agent frameworks (GSD, BMAD, Spec-Kit) try to own your entire
workflow. They work until they don't — then debugging the framework is harder
than doing the work yourself.

These skills take the opposite approach:

- **Small** — each skill does one thing well (diagram, debug, grill, handoff)
- **Composable** — skills reference each other when useful, never depend on each other
- **Adaptable** — fork, modify, keep what works, discard what doesn't
- **Model-agnostic** — plain markdown instructions, no vendor lock-in

## Install

```bash
npx skills@latest add TheAkshitS/skills
```

Pick the skills and agents you want.

## Skills

- **[c4-diagrams](./skills/c4-diagrams/SKILL.md)** — Generate and review C4 model architecture diagrams in Mermaid, Structurizr DSL, or C4-PlantUML. _Trigger: "diagram", "architecture", "C4", "system context", "container diagram", "component diagram"_

## Skill structure

```
skills/<skill-name>/
├── SKILL.md           # Instructions loaded by the agent (required)
├── AGENTS.md          # Skill-specific agent hints (optional)
├── README.md          # Standalone distribution docs (optional)
├── references/        # Long-form material loaded on demand (optional)
└── scripts/           # Utility scripts (optional)
```

Skills stay flat under `skills/` until 3+ skills exist, then organize into
buckets: `engineering/`, `productivity/`, `misc/`. See
[docs/repo-layout.md](./docs/repo-layout.md) for details.

## Develop locally

Symlink every skill into your local agent (`~/.claude/skills`):

```bash
bash scripts/link-skills.sh
```

Validate frontmatter before committing:

```bash
bash scripts/validate-skills.sh
```

## License

MIT — see [LICENSE](./LICENSE).
