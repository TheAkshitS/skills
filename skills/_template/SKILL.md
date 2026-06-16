---
name: your-skill-name
description: >
  One or two sentences — what this skill does and when to trigger it.
  Use when the user says "X", mentions "Y", or needs "Z".
# argument-hint: "Optional placeholder shown in slash-command UI"
# disable-model-invocation: true  # Uncomment to require explicit slash-command invocation
---

# Skill Name

Write the agent's instructions here in plain prose. This whole file is loaded
into the agent's context when the skill triggers, so be direct and specific
about what it should do.

## Workflow

Step-by-step process with checklists for complex tasks:

1. First step
2. Second step
3. Verify result

## Companion files

When this file exceeds 100 lines or covers distinct domains, split into
companion files loaded on demand:

- `references/*.md` — long-form material (method docs, templates, rubrics)
- `scripts/` — utility scripts for deterministic operations

Point to them from here with clear "read when" instructions.

## Checklist

Before shipping, verify:

- [ ] `name` matches folder name
- [ ] `description` includes trigger phrases ("Use when...")
- [ ] `description` under 1024 chars
- [ ] Companion files referenced, not inlined
- [ ] Entry added to `README.md` and `.claude-plugin/plugin.json`
- [ ] `bash scripts/validate-skills.sh` passes
