# External CLI Reference Matrix

These are three external agentic CLIs — `opencode`, `cursor-agent`, and
`kiro-cli` — each wrapping a different model/provider behind its own
headless invocation, flags, and auth flow. `scripts/run-model.sh`
normalizes the differences below into one interface. Read this file when
you need the raw per-CLI details or are debugging a specific invocation.

## Comparison table

| | Install check | Headless/non-interactive invocation | Model-select flag | Read-only behavior | Write/edit flag | Output-format flag | Auth requirement |
|---|---|---|---|---|---|---|---|
| **opencode** | `command -v opencode` | `opencode run "prompt"` (prompt is a positional argument) | `-m <provider/model>` (e.g. `-m anthropic/claude-...`, `-m openai/gpt-5`) | None built in — it's an agent that can edit; isolation must come from running it in a throwaway cwd | N/A (always can edit; no opt-in flag) | `--format` (default text output is fine for scripts; there is no `-q`/`--quiet` flag) | Configured per provider via `opencode auth` / config (provider API keys) |
| **cursor-agent** | `command -v cursor-agent` | `cursor-agent -p "prompt"` (a.k.a. `--print`) | `-m`/`--model` (e.g. `sonnet-4`, `sonnet-4-thinking`, `gpt-5`) | NOT read-only by default — print mode has access to all tools (including file write and shell), gated only by approval, which `--force`/`--yolo` removes. The only repo protection here is the temp-dir sandbox (same caveat as opencode) | `--yolo` (a.k.a. `--force`) to allow file edits without approval | `--output-format text\|json` (use `text` for the final answer only) | `cursor-agent login` (Cursor account); supports headless in CI. **Known issue:** `-p` has been reported to hang indefinitely in some environments — always wrap in a timeout |
| **kiro-cli** | `command -v kiro-cli` | `kiro-cli chat --no-interactive "prompt"`; context can be piped, e.g. `git diff \| kiro-cli chat --no-interactive "Review these changes"` (note: the `run-model.sh` dispatcher passes the prompt positionally only and does NOT pipe stdin context through, so this raw-CLI piping trick is not available via the dispatcher) | None — no interactive `/model` or `/agent` picker in this mode | Default (no trust flag) | `--trust-all-tools` to enable write/trusted tools | None documented for this mode | Headless requires `KIRO_API_KEY` env var — when set, Kiro skips the browser login flow entirely; that single env var is what enables headless mode. Interactive mode uses browser login |

Sources: <https://opencode.ai/docs/cli>, <https://cursor.com/docs/cli>, <https://kiro.dev/docs/cli/headless>

## How the dispatcher maps these

`run-model.sh` builds the following commands per CLI:

| CLI | Read-only mode | Write mode (`--write`) |
|---|---|---|
| opencode | `opencode run [-m <model>] "prompt"`; safety comes from a temp-dir sandbox, not a flag | same command run in the repo cwd — the temp-dir sandbox is the only read-only protection; opencode itself has no read-only flag |
| cursor-agent | `cursor-agent -p --output-format text [-m <model>] "prompt"` | `cursor-agent -p --output-format text [-m <model>] --force "prompt"` |
| kiro-cli | `kiro-cli chat --no-interactive "prompt"` (requires `KIRO_API_KEY`) | `kiro-cli chat --no-interactive --trust-all-tools "prompt"` (requires `KIRO_API_KEY`) |

The prompt is always passed as the final positional argument (never on stdin).
With `--all`, `--model` is not forwarded — each CLI runs with its own default
model, because model names are not portable across these CLIs (see Gotchas).

## Gotchas

- **cursor-agent `-p` can hang indefinitely** in some environments — always invoke it under a timeout wrapper.
- **opencode has no read-only flag** — it can edit files by default; the dispatcher's only isolation mechanism is running it inside a throwaway temp-dir sandbox.
- **kiro-cli headless requires `KIRO_API_KEY`** to be set in the environment, or it falls back to the interactive browser login flow and headless invocation will fail/hang.
- **Model names are not portable across CLIs**: opencode expects `provider/model` (e.g. `anthropic/claude-...`, `openai/gpt-5`), while cursor-agent expects bare names (e.g. `gpt-5`, `sonnet-4`). kiro-cli's headless mode has no model-select flag at all.
