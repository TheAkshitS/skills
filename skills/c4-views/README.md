# c4-views

Generate and review C4 model architecture diagrams in Mermaid, Structurizr DSL, and C4-PlantUML.

## What it does

- **Generate** Level 1 (System Context), Level 2 (Container), and Level 3 (Component) diagrams from a plain-language description or by inspecting a codebase.
- **Review** existing diagrams against the C4 method — checking notation correctness, boundary accuracy, naming conventions, and (when a codebase is available) consistency with the code itself.
- **Multi-format output**: Mermaid, Structurizr DSL, or C4-PlantUML — specify your preference or let the skill choose the best fit.

## Install

### Via skills.sh (multi-harness)

```bash
# From this GitHub repo
npx skills@latest add TheAkshitS/skills

# Just this skill
npx skills@latest add TheAkshitS/skills -s c4-views -y

# From a local path
npx skills add ./path/to/c4-views
```

`npx skills@latest add` auto-discovers `SKILL.md` — no manifest needed. It installs by symlink (default) or `--copy`. Use `--list` to preview what would be installed before running.

#### Per-tool install targets

| Tool | Project-local | Global |
|---|---|---|
| Claude Code | `.claude/skills/` | `~/.claude/skills/` |
| Codex | `.agents/skills/` | `~/.codex/skills/` |
| opencode | `.agents/skills/` | `~/.config/opencode/skills/` |
| Cursor | `.agents/skills/` | `~/.cursor/skills/` |
| GitHub Copilot | `.agents/skills/` | `~/.copilot/skills/` |
| Windsurf | `.windsurf/skills/` | `~/.codeium/windsurf/skills/` |

> **Important — writes ≠ activates:** `skills.sh` reliably places `SKILL.md` in the target directory for every tool, and skill-native harnesses (Claude Code, opencode, Codex) will pick it up and execute it automatically. Rules-based tools (Cursor, GitHub Copilot, Windsurf) natively consume `.mdc` rules, prompt files, or workflow files — they may not read a raw `SKILL.md` dropped in their skills directory. If the skill is ignored by one of these tools, a thin native adapter (e.g. a `.cursor/rules/*.mdc` file) is required; none is included here.

### Manual install

Copy the `c4-views/` folder into the tool's skills directory from the table above.

## Usage

```
Generate a C4 container diagram for a hotel booking system in Mermaid.
```

```
Review this C4 diagram against the codebase and flag any notation or boundary errors.
```

```
Create C4 Level 1 and Level 2 diagrams for this microservices architecture in Structurizr DSL.
```

## Structure

```
c4-views/
├── SKILL.md                  # Skill definition (frontmatter + instructions)
└── references/
    ├── c4-method.md          # C4 model method summary
    ├── notations.md          # Shape, line, and label conventions
    └── review-rubric.md      # Criteria used when reviewing diagrams
```

## Standard

This package follows the [agentskills.io](https://agentskills.io) directory conventions. The directory name matches the `name:` field in `SKILL.md`.
