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
and optional fields like `argument-hint` and `disable-model-invocation`.

**Bucket**:
A category folder under `skills/` that groups related skills. Current buckets:
none (flat structure). Planned buckets (adopt at 3+ skills): `engineering/`
(daily code work), `productivity/` (general workflow), `misc/` (rarely used).
_Avoid_: category, group, folder (when referring to buckets specifically)

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

## Flagged ambiguities

- "plugin" was considered but rejected — too overloaded (browser plugins, npm
  plugins, Claude plugins). Use **Skill**.
- "category" vs "bucket" — resolved: **Bucket** is the canonical term, matching
  the mattpocock/skills convention.
- "reference" vs "companion file" — both valid. **Reference** for documentation
  companion files; **Companion file** for the broader set including scripts.
- "activation" vs "trigger" — resolved: **Trigger** is canonical. "Activation"
  is no longer used as a domain term.
