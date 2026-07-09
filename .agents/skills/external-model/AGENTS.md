# AGENTS.md — external-model skill

This folder defines the `external-model` skill. When editing this skill, read `SKILL.md` first.

## References

- `references/cli-matrix.md` — per-CLI install checks, invocation flags, model-name formats, auth/timeout gotchas for `opencode`, `cursor-agent`, `kiro-cli`.

Load on demand rather than all at once — it is not preloaded into `SKILL.md`.

## Scripts

- `scripts/run-model.sh` — dispatcher normalizing `opencode`, `cursor-agent`, `kiro-cli` behind one interface. Safety model: read-only temp-dir sandbox by default, `--write` opts into real repo cwd and edit permission, 120s timeout wrapper around every CLI invocation.

Keep this the single source of CLI invocation logic; don't inline CLI details into `SKILL.md`.

## Style

- `set -euo pipefail`, `local` declarations inside functions, 2-space indent.
- Read config by parsing `KEY=VALUE` lines — never `source` the file.
- Build CLI argv as arrays, then expand `"${arr[@]}"`, for injection-safety.

## Validation

Run `bash scripts/validate-skills.sh` from the repo root before committing. Also `bash -n scripts/run-model.sh` for syntax.
