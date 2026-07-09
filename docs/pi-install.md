# Installing skills for pi

[pi](https://github.com/earendil-works/pi) implements the
[Agent Skills spec](https://agentskills.io/specification), so the skills in
this repo work in pi without any rewrites. Three install paths — pick the
one that matches your workflow.

## TL;DR

```bash
bash scripts/install-pi.sh link            # symlink into ~/.pi/agent/skills
bash scripts/install-pi.sh settings --write  # merge into ~/.pi/agent/settings.json
bash scripts/install-pi.sh project         # write .pi/settings.json in cwd
```

The `link` mode is the same as `bash scripts/link-skills.sh` (which also
links into `~/.claude/skills` and `~/.agents/skills`). The `settings` and
`project` modes are no-symlink alternatives that point pi at the repo's
`skills/` directory instead.

## What pi loads from where

Pi scans these locations, in order, for skills. Project dirs are trust-gated
on first run (use `/trust` to save the decision).

| Scope | Locations |
|---|---|
| Global | `~/.pi/agent/skills/`, `~/.agents/skills/` |
| Project | `.pi/skills/`, `.agents/skills/` (cwd and ancestors up to git root) |
| Packages | npm/git packages, or `pi.skills` in `package.json` |
| Settings | `skills` array in `~/.pi/agent/settings.json` or `.pi/settings.json` |
| CLI | `--skill <path>` (repeatable) |

`~/.agents/skills/` and `.agents/skills/` are the cross-harness fallback —
pi, opencode, and any other Agent Skills spec agent reads them.

The repo also ships committed mirror copies under `.claude/skills/` and
`.agents/skills/` (see [Mirror](../CONTEXT.md#terms) in the glossary), so a
fresh clone works as a drop-in folder for either agent without running any
installer. Just point pi at the path.

## Mode 1: link (default)

```bash
bash scripts/install-pi.sh link
```

Symlinks every skill under `skills/` into `~/.pi/agent/skills/`. Re-running
is safe — it overwrites stale symlinks and warns before replacing real
directories. Also links into `~/.claude/skills/` and `~/.agents/skills/`
in the same pass; one script, three targets.

**Best for**: local dev, frequent skill edits, one source of truth.

**Caveat**: skills load for every project, not just the repo. If you keep
personal skills elsewhere, scope with a settings path instead.

## Mode 2: settings (no symlinks)

```bash
bash scripts/install-pi.sh settings --write
```

Merges a `skills` entry into `~/.pi/agent/settings.json` pointing at
`/absolute/path/to/this/repo/skills`. Pi reads this on every startup; no
symlinks, no copies. Use `--write` to apply; omit it to print the snippet.

The merge is idempotent — re-running won't duplicate the path. If `jq` is
not available and the file already exists, the script refuses to overwrite
and asks you to edit by hand.

**Best for**: a single machine where the repo lives at a stable absolute
path; no symlink bookkeeping.

## Mode 3: project-local

```bash
cd /path/to/some/project
bash /path/to/this/repo/scripts/install-pi.sh project
```

Writes a `.pi/settings.json` in cwd with `{"skills": ["./skills"]}`.
Replace `./skills` with the path to the cloned repo (relative or absolute).

Pi will ask to `/trust` the project on first run. Trust the parent folder
once and pi will load skills for every subdir in that tree.

**Best for**: per-project control; skills that should only follow a
specific repo, not your whole machine.

## Using the skills in pi

Once installed, skills are available two ways:

1. **Auto-invocation** — pi reads every skill's `description` frontmatter
   at startup and matches it against the user's request. If the description
   triggers, pi loads the full `SKILL.md` and follows its instructions.
2. **Explicit slash command** — every skill registers as `/skill:<name>`:

   ```bash
   /skill:c4-views
   /skill:external-model "what would GPT-5 say about this design?"
   ```

   Toggle via `/settings` -> `enableSkillCommands` (default: on).

## Validating

```bash
bash scripts/validate-skills.sh
```

Checks every active skill's frontmatter, the in-repo mirror copies under
`.claude/skills/` and `.agents/skills/`, and runs per-skill evals. Run
before committing a skill change; CI runs it on every PR.

If a `WARN ... frontmatter drifted` line shows up, the mirror copies are
stale. Fix with:

```bash
bash scripts/sync-copied-skills.sh
```

## Troubleshooting

**Skills not loading in pi:**
- `pi` itself not installed — `npm install -g --ignore-scripts @earendil-works/pi-coding-agent`
- Project not trusted — run `/trust` in interactive mode
- Symlink broken — `ls -la ~/.pi/agent/skills/<name>` should point at the repo's `skills/<name>`
- `enableSkillCommands: false` — toggle via `/settings`

**Name collision warnings:** two skills with the same `name` from different
locations. Pi keeps the first one it found. Rename the duplicate or move
it to a non-scanned dir.

**Frontmatter validation warnings:** `name` over 64 chars, non-kebab-case
name, or `description` over 1024 chars. `validate-skills.sh` flags all of
these; pi will warn too. Fix the source in `skills/<name>/SKILL.md` and
re-run `sync-copied-skills.sh`.
