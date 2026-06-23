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
| **cursor-agent** | `command -v cursor-agent` | `cursor-agent -p "prompt"` (a.k.a. `--print`) | `-m`/`--model` (e.g. `sonnet-4`, `sonnet-4-thinking`, `gpt-5`) | NOT read-only by default — print mode has access to all tools (including file write and shell), gated only by approval, which `--force`/`--yolo` removes. The only repo protection here is the temp-dir sandbox (same caveat as opencode). **Since the January 2026 release, non-interactive runs in an untrusted workspace (e.g. a fresh temp dir) fail with guidance unless `--trust` or `--force` is passed** — so the dispatcher's read-only mode must pass `--trust` | `--yolo` (a.k.a. `--force`) to allow file edits without approval; `--force` also satisfies the workspace-trust gate | `--output-format text\|json\|stream-json` (use `text` for the final answer only) | `cursor-agent login` (Cursor account) or `--api-key`/`CURSOR_API_KEY`; supports headless in CI. **Past known issue (fixed Feb 2026):** `-p` runs no longer block when spawned with an open stdin pipe (Node/Python/CI runners) — the old "can hang indefinitely" caveat is no longer current |
| **kiro-cli** | `command -v kiro-cli` | `kiro-cli chat --no-interactive "prompt"`; context can be piped, e.g. `git diff \| kiro-cli chat --no-interactive "Review these changes"` (note: the `run-model.sh` dispatcher passes the prompt positionally only and does NOT pipe stdin context through, so this raw-CLI piping trick is not available via the dispatcher) | None — no interactive `/model` or `/agent` picker in this mode | Default (no trust flag) | `--trust-all-tools` to enable write/trusted tools | None documented for this mode | Headless requires `KIRO_API_KEY` env var — when set, Kiro skips the browser login flow entirely; that single env var is what enables headless mode. Interactive mode uses browser login |

Sources: <https://opencode.ai/docs/cli>, <https://opencode.ai/docs/models>, <https://opencode.ai/docs/config>, <https://cursor.com/docs/cli/headless>, <https://cursor.com/docs/cli/using>, <https://cursor.com/docs/cli/reference/parameters>, <https://cursor.com/docs/cli/changelog>, <https://kiro.dev/docs/cli/headless>, <https://kiro.dev/docs/cli/reference/cli-commands>, <https://kiro.dev/docs/cli/authentication> (all accessed 2026-06-23 via context7 / WebFetch)

## How the dispatcher maps these

`run-model.sh` builds the following commands per CLI:

| CLI | Read-only mode | Write mode (`--write`) |
|---|---|---|
| opencode | `opencode run [-m <model>] "prompt"`; safety comes from a temp-dir sandbox, not a flag | same command run in the repo cwd — the temp-dir sandbox is the only read-only protection; opencode itself has no read-only flag |
| cursor-agent | `cursor-agent -p --output-format text --trust [-m <model>] "prompt"` | `cursor-agent -p --output-format text [-m <model>] --force "prompt"` |
| kiro-cli | `kiro-cli chat --no-interactive "prompt"` (requires `KIRO_API_KEY`) | `kiro-cli chat --no-interactive --trust-all-tools "prompt"` (requires `KIRO_API_KEY`) |

The prompt is always passed as the final positional argument (never on stdin).
With `--all`, `--model` is not forwarded — each CLI runs with its own default
model, because model names are not portable across these CLIs (see Gotchas).

## Gotchas

- **cursor-agent non-interactive runs now require `--trust` (or `--force`) in an untrusted workspace** (e.g. a fresh temp dir), per the cursor-agent January 2026 release: "Non-interactive runs in untrusted workspaces fail with guidance unless `--trust` (or `--force`) is passed." (<https://cursor.com/docs/cli/changelog>). The dispatcher's temp-dir sandbox is untrusted on every run, so read-only mode passes `--trust`; write mode's `--force` already satisfies this gate, so it needs no separate `--trust`.
- **The old "`cursor-agent -p` can hang indefinitely" caveat is no longer current** — fixed in the February 2026 release: "`-p` runs no longer block when spawned with an open stdin pipe (Node, Python, CI runners)" (<https://cursor.com/docs/cli/changelog>). A timeout wrapper is still kept as defense-in-depth, but it is no longer compensating for a known/open hang bug.
- **opencode has no read-only flag** — it can edit files by default (permissions default to "allow"); the dispatcher's only isolation mechanism is running it inside a throwaway temp-dir sandbox. (<https://opencode.ai/docs/config>)
- **kiro-cli headless requires `KIRO_API_KEY`** to be set in the environment, or it falls back to the interactive browser login flow and headless invocation will fail/hang. (<https://kiro.dev/docs/cli/authentication>)
- **Model names are not portable across CLIs**: opencode expects `provider_id/model_id` (e.g. `anthropic/claude-...`, `openai/gpt-5`), while cursor-agent expects bare/slug names (e.g. `gpt-5`, `sonnet-4`). kiro-cli's headless mode has no model-select flag (only `--list-models`/`--agent`, which the dispatcher does not use).
