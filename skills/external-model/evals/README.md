# Eval scaffold for `external-model`

These evals cover the skill's objectively verifiable behaviors: CLI dispatch,
config resolution, error paths, dry-run output, and `--all` fanout. Six
realistic user-style prompts — one per behavior — drafted to match the
skill-creator workflow.

## Behaviors covered

1. **Second opinion across all CLIs** — `--all` fanout, forced read-only,
   `--model` not forwarded.
2. **Delegate to a specific CLI** — `--cli cursor-agent --write`, repo cwd,
   `--force` passed.
3. **Pick a specific model** — per-CLI `--model gpt-5` dispatch and name
   mapping: opencode/cursor-agent receive bare `-m gpt-5`; kiro-cli headless
   drops `-m` and warns on stderr.
4. **Config: set a default** — `config set --cli opencode --model openai/gpt-5`,
   writes global config only.
5. **Config: show current default** — `config show`, precedence resolution +
   source reporting.
6. **Detect installed CLIs** — `detect` subcommand, `command -v` per CLI,
   non-zero exit when none installed.

## Status

All 6 evals have machine-checkable `expectations[]` arrays, encoded as an
executable grader in `evals/run.sh`. Each expectation is a single verifiable
string — the grader scores runs by matching them against dry-run output,
captured stderr, exit codes, and config-file state.

## Running

    bash evals/run.sh

This runs the suite hermetically: it stubs `opencode`, `cursor-agent`, and
`kiro-cli` on a temp `PATH` (so `command -v` and `detect`/`--all` resolve
them), points `HOME` at a throwaway dir (so `config set`/`config show` never
touch the real `~/.claude/skills/external-model/config`), and sets
`EXTERNAL_MODEL_DRYRUN=1` so the run path prints the resolved command instead
of executing anything. It passes with **none of the real CLIs installed** —
that is the CI case. Both temp dirs are cleaned up on exit.

It prints one `PASS`/`FAIL` line per eval, a summary, and exits non-zero if
any assertion fails.

`scripts/validate-skills.sh` runs this grader automatically for every skill
that ships an executable `evals/run.sh`, so the evals are checked on every
validation run.
