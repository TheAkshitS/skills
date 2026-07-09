# Domain Glossary

Shared language for this repository. Use these terms consistently in skills,
documentation, and agent instructions.

## Terms

**Skill**:
A folder under `skills/` containing a `SKILL.md` and optional companion files
(references, scripts). Loaded by an agent as behavioral instructions when the
skill's trigger condition is met.
_Avoid_: plugin, extension, addon, module

**Trigger**:
The activation condition described in a skill's frontmatter `description`.
The agent reads trigger descriptions across all installed skills and loads the
matching one based on the user's request.
_Avoid_: activation, hook, entry point

**Frontmatter**:
The YAML block between `---` delimiters at the top of `SKILL.md`. Contains
metadata the agent reads before loading the skill body: `name`, `description`,
and optional fields like `argument-hint`, `compatibility`, `license`,
`allowed-tools`, and `disable-model-invocation`. The
[Agent Skills spec](https://agentskills.io/specification) defines only
`name` and `description` as required, with `license`, `compatibility`,
`metadata`, and `allowed-tools` as optional. `argument-hint` and
`disable-model-invocation` are **skills.sh conventions, not spec fields**
— widely adopted but check the host harness before relying on them.

**Harness**:
The agent runtime that loads and runs skills. Examples: Claude Code,
pi, opencode, Codex, anything implementing the Agent Skills spec.
A skill is harness-agnostic; the install path and slash-command prefix
vary per harness. See [README.md](./README.md#harness-support) for the
supported matrix.
_Avoid_: agent (ambiguous with the LLM the harness wraps), platform, runtime

**Bucket**:
A category folder under `skills/` that groups related skills. Current
buckets: none (flat structure). See
[repo layout](./docs/repo-layout.md#planned-structure-at-3-skills) for the
planned bucket names and [ADR-0001](./docs/adr/0001-flat-then-bucket-structure.md)
for the rationale.
_Avoid_: category, group, folder (when referring to buckets specifically)

**Mirror**:
A committed copy of every active skill under `.claude/skills/` and
`.agents/skills/`. Lets a fresh clone of the repo work as a drop-in folder
for Claude Code and pi without running any installer. Kept in sync by
`scripts/sync-copied-skills.sh`; drift or an orphaned mirror entry is a
`validate-skills.sh` error.
_Avoid_: distribution copy (use the shorter **mirror**)

**Reference**:
Long-form material in companion files alongside `SKILL.md` (e.g.
`references/c4-method.md`). Loaded on demand by the agent, not preloaded with
the skill body. Keeps `SKILL.md` concise.
_Avoid_: appendix, attachment, supplement

**Companion file**:
Any non-`SKILL.md` file in a skill folder: references, scripts, templates,
format specs. Same concept as "reference" but broader — includes scripts and
data files, not just documentation.

## Relationships

- A **Skill** lives in a **Bucket** (or at the flat root when no buckets exist)
- A **Skill** has one **Frontmatter** block defining metadata
- A **Frontmatter** `description` contains one or more **Triggers**
- A **Skill** may have zero or more **Companion files** as **References**
- A **Skill** is consumed by one or more **Harnesses** (same `SKILL.md`, different install paths)
- A **Skill** is reflected as a **Mirror** under `.claude/skills/` and `.agents/skills/`

## Flagged ambiguities

- "plugin" was considered but rejected — too overloaded (browser plugins, npm
  plugins, Claude plugins). Use **Skill**.
- "category" vs "bucket" — resolved: **Bucket** is the canonical term, matching
  the mattpocock/skills convention.
- "reference" vs "companion file" — both valid. **Reference** for documentation
  companion files; **Companion file** for the broader set including scripts.
- "activation" vs "trigger" — resolved: **Trigger** is canonical. "Activation"
  is no longer used as a domain term.
- "agent" vs "harness" — **Harness** is canonical for the runtime that loads
  skills (Claude Code, pi, opencode). **Agent** is reserved for the LLM
  itself (or for the runtime+LLM pair when the distinction doesn't matter).
- "distribution copy" vs "mirror" — **mirror** is the canonical term; shorter
  and avoids the ambiguity of "distribution" (tarball? npm package? git
  mirror?).
