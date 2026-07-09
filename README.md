# Skills

Small, composable agent skills for real engineering work. Each skill is
independent, trigger-activated, and works with any
[Agent Skills spec](https://agentskills.io/specification)-compatible
harness — Claude Code, [pi](https://github.com/earendil-works/pi),
opencode, and anything
[skills.sh](https://skills.sh)-compatible.

 [![skills.sh](https://skills.sh/b/TheAkshitS/skills)](https://skills.sh/TheAkshitS/skills)
[![Release](https://img.shields.io/github/v/release/TheAkshitS/skills)](https://github.com/TheAkshitS/skills/releases)

## Why

Monolithic agent frameworks (GSD, BMAD, Spec-Kit) try to own your entire
workflow. They work until they don't — then debugging the framework is harder
than doing the work yourself.

These skills take the opposite approach:

- **Small** — each skill does one thing well (diagram, debug, grill, handoff)
- **Composable** — skills reference each other when useful, never depend on each other
- **Adaptable** — fork, modify, keep what works, discard what doesn't
- **Model-agnostic** — plain markdown instructions, no vendor lock-in
- **Harness-agnostic** — Agent Skills spec frontmatter, same `SKILL.md` for every runtime

## Install

### Any Agent Skills harness (recommended)

```bash
npx skills@latest add TheAkshitS/skills
```

Pick the skills and agents you want. To grab one skill non-interactively:

```bash
npx skills@latest add TheAkshitS/skills -s c4-views -y
```

### Claude Code

```bash
bash scripts/link-skills.sh
```

Symlinks every skill into `~/.claude/skills`. Re-runnable; safe to overwrite.

### pi

```bash
bash scripts/install-pi.sh link            # symlink into ~/.pi/agent/skills
```

Also symlinks into `~/.claude/skills` and `~/.agents/skills` in the same
pass. Two more install modes (no-symlink alternatives) and full
troubleshooting are in [docs/pi-install.md](./docs/pi-install.md), the
canonical recipe.

### Manual / drop-in

The repo ships committed mirror copies under `.claude/skills/` and
`.agents/skills/` (see [Mirror](./CONTEXT.md#terms) in the glossary). Copy
either folder into your harness's skill directory and the skills just work.

## Skills

- **[c4-views](./skills/c4-views/SKILL.md)** — Generate and review C4 model architecture diagrams in Mermaid, Structurizr DSL, or C4-PlantUML. _Trigger: "diagram", "architecture", "C4", "system context", "container diagram", "component diagram"_
- **[external-model](./skills/external-model/SKILL.md)** — Run a prompt through a different AI model via the opencode, cursor-agent, or kiro-cli command-line tools. _Trigger: "second opinion", "what would GPT-5/Gemini say", "delegate to cursor/opencode/kiro", "run with model X", "ask another model"_

## Harness support

| Harness | Install | Slash command | Notes |
|---|---|---|---|
| Claude Code | `bash scripts/link-skills.sh` | `/c4-views`, `/external-model` | `~/.claude/skills` |
| pi | `bash scripts/install-pi.sh link` | `/skill:c4-views`, `/skill:external-model` | `~/.pi/agent/skills` |
| opencode | drop into `~/.agents/skills` | `/skill:c4-views` | same as pi global fallback |
| skills.sh (installer) | `npx skills add TheAkshitS/skills` | depends on host | installer, not a client — picks the host harness |

All four rows read the same `SKILL.md`; only the install path and slash-command
prefix differ. Many more harnesses support the format — Claude, Cursor, Codex,
Gemini CLI, GitHub Copilot, Goose, Roo Code, Amp, and others. See the official
[Agent Skills client showcase](https://agentskills.io/clients) for the full
list. This repo documents install for the four it tests against.

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

Symlink every skill into all supported harnesses' global skill dirs:

```bash
bash scripts/link-skills.sh
```

Validate frontmatter and mirror sync before committing:

```bash
bash scripts/validate-skills.sh
```

Refresh the in-repo distribution mirrors after editing a skill:

```bash
bash scripts/sync-copied-skills.sh
```

## Releases

Automated via [release-please](https://github.com/googleapis/release-please)
on push to `main`. See [docs/local-workflow.md](./docs/local-workflow.md#releases)
for the file layout, semver bump rules, and bootstrap notes.

## License

MIT — see [LICENSE](./LICENSE).
