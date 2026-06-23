# external-model

Run a prompt through an external agentic CLI to get a second opinion, delegate a task, pick the best model for a job, or just run a different model.

## What it does

The skill shells out to one of three external agentic CLIs — `opencode`, `cursor-agent`, `kiro-cli` — and runs your prompt through a different AI model. Use cases:

- **Second opinion** — run the same prompt across multiple installed CLIs and compare answers.
- **Delegate a task** — send complex work to a model known for one specialty (e.g., GPT-5 for reasoning, Claude for code).
- **Pick the best model** — test a prompt with different models to see which one solves it best.
- **Raw model run** — execute a prompt in another tool's environment to see how it behaves.

The dispatcher (`run-model.sh`) wraps calls with safe defaults: **read-only**, runs in a throwaway temp dir, and times out after 120s.

## Install

```bash
npx skills@latest add TheAkshitS/skills -s external-model -y
```

## Prerequisites

At least one of these CLIs installed and authenticated:

- `opencode` — authenticate via `opencode auth login`; see [references/cli-matrix.md](./references/cli-matrix.md).
- `cursor-agent` — authenticate via your Cursor IDE; see [references/cli-matrix.md](./references/cli-matrix.md).
- `kiro-cli` — authenticate via `kiro-cli auth login` or set `KIRO_API_KEY` for headless mode; see [references/cli-matrix.md](./references/cli-matrix.md).

Each CLI authenticates separately. No setup required for the skill itself.

## Usage

### Via dispatcher script

```bash
# Run prompt through the default CLI and model
bash scripts/run-model.sh "Explain this regex: ^\d{3}-\d{4}$"

# Specify a CLI and model
bash scripts/run-model.sh --cli cursor-agent --model gpt-5 "Refactor this function..."

# Get a second opinion: run across all installed CLIs
# (--all uses each CLI's own default model; --model is not forwarded)
bash scripts/run-model.sh --all "Is this approach sound? Can we optimize it?"

# Let the external model edit files in your repo (opt-in)
bash scripts/run-model.sh --write "Refactor foo.py to use asyncio"

# Set global defaults (opencode needs a provider-qualified model id)
bash scripts/run-model.sh config set --cli opencode --model openai/gpt-5
bash scripts/run-model.sh config show
```

### Via slash commands (Claude Code)

```
/external-model Explain this regex: ^\d{3}-\d{4}$

/external-model --cli cursor-agent --model gpt-5 Refactor this function...

/external-model --all Is this approach sound?

/external-model config set --cli opencode --model openai/gpt-5

/external-model config show
```

`set` and `show` also work as aliases for `config set` / `config show` —
the dispatcher maps `run-model.sh set ...` to `config set` and
`run-model.sh show` to `config show`, so neither is ever interpreted as a
prompt sent to a live model.

## Defaults & safety

- **Read-only by default** — the external model runs in a throwaway temp dir and cannot touch or see your repo. If you need the model to edit files, use `--write` to opt in.
- **120s timeout** — each call is wrapped in a timeout to prevent runaway processes.
- **Config files** — defaults live in `~/.claude/skills/external-model/config` (global). Override per-repo with `.claude/external-model.config` at your project root.

## Reference

- **[SKILL.md](./SKILL.md)** — full skill definition and implementation.
- **[references/cli-matrix.md](./references/cli-matrix.md)** — which CLIs support which models, auth steps, and env var options.

## License

MIT
