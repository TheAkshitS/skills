# Eval scaffold for `external-model`

These evals cover the skill's objectively verifiable behaviors: CLI dispatch,
config resolution, error paths, dry-run output, `--all` fanout, and real
(non-dry-run) execution. Eleven realistic user-style prompts (evals 1-11,
`evals.json`) plus one grader-only real-execution eval (12, `run.sh` only —
see below) — one per behavior — drafted to match the skill-creator workflow.

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
7. **Dash-prefixed prompt** — a prompt starting with `-` (e.g. `-explain this
   code`) is accepted as the prompt, not parsed as an unknown flag, and still
   reaches the child CLI behind a `--` delimiter.
8. **`--context` pointing at a directory** — rejected with a clear
   not-a-regular-file error instead of trying to read it.
9. **`--context` file over the 256 KiB cap** — rejected rather than silently
   truncated, so the user always knows exactly what was (or wasn't) sent.
10. **Invalid `--timeout` value** — a non-numeric/non-positive `--timeout` is
    rejected at parse time with a clear error.
11. **Unknown `--cli` value** — an unrecognized `--cli` is rejected at parse
    time with a clear error naming the valid CLIs.
12. **Real execution (no dry-run)** — the only eval that unsets
    `EXTERNAL_MODEL_DRYRUN` and actually execs a stub CLI, so the real-run
    code path (not just `--dry-run` output) gets exercised: (a) the
    dispatcher's exit code matches the stub's own exit code, and (b) with a
    short `--timeout`, a hanging stub is actually killed rather than left to
    run to completion. `run.sh` installs its own minimal `timeout` shim on
    the stub `PATH` so this is deterministic even on hosts without GNU
    `timeout`/`gtimeout` on `PATH`. This eval lives only in `run.sh` (not
    `evals.json`), since it targets `run-model.sh`'s real-execution
    machinery rather than a user-facing prompt scenario.

## Status

All 11 prompt-driven evals (`evals.json`) plus the grader-only real-execution
eval 12 have machine-checkable `assertions[]`-equivalent checks, encoded as
an executable grader in `evals/run.sh`. Each assertion is a single verifiable
string or condition — the grader scores runs by matching them against
dry-run output, captured stderr, exit codes, elapsed time, and config-file
state.

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
