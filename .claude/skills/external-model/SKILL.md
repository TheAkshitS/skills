---
name: external-model
description: Get input from a different AI model (GPT-5, Gemini, Claude variants, or any model reachable via opencode/cursor-agent/kiro-cli) on a question, plan, or piece of code. Trigger this whenever the user wants another model's take, opinion, or judgment — "what would GPT-5/Gemini/another model say/think", "is this safe/right, get another opinion", "ask another model to check/review/weigh in", wants to delegate or run a prompt through cursor/opencode/kiro, wants to pick the best model for a task and run it, or wants to switch/set the default external-model CLI. Applies even without naming a CLI or model, and even when the ask is implicit ("before I ship this", "am I sure about this approach") rather than an explicit request for a "second opinion." Not for: re-running the user's own code/tests, asking Claude itself to reconsider, or general questions about what a CLI tool is/does.
argument-hint: "<prompt> | config show | config set --cli <cli> [--model <m>] | detect"
compatibility: "Requires at least one of opencode, cursor-agent, or kiro-cli installed and authenticated on PATH. kiro-cli headless mode also requires KIRO_API_KEY."
license: MIT
allowed-tools: bash
---

# External Model

Shells out to a different AI model via one of three external agentic CLIs —
`opencode`, `cursor-agent`, `kiro-cli` — and returns its answer. Four common
requests all reduce to this **same mechanism**, just framed differently:

1. **Second opinion** — "what would GPT-5/Gemini say about this?"
2. **Delegate a task** — "have cursor handle this", "let kiro do it"
3. **Pick the best model** — "which model is best for this, then run it"
4. **Raw run** — "run this prompt through opencode"

Don't overthink which framing applies — resolve a CLI/model (see
**Resolution** below) and invoke the dispatcher.

## Invocation

Call `scripts/run-model.sh`, resolved to an absolute path relative to this
skill's own directory (e.g. `<skill-dir>/scripts/run-model.sh`). The prompt is
a single positional argument; quote it so multi-line or complex prompts arrive
as one argv element.

```bash
run-model.sh "prompt"                                   # default: read-only, sandboxed, 120s timeout
run-model.sh --cli <opencode|cursor-agent|kiro-cli> --model <m> "prompt"
run-model.sh --write "prompt"                            # allow file edits in the repo
run-model.sh --all "prompt"                              # every installed CLI, forced read-only, side-by-side
run-model.sh --dry-run "prompt"                            # print resolved command without running
run-model.sh --context <file> "prompt"                     # prepend file contents to prompt
run-model.sh --timeout <sec> "prompt"
run-model.sh detect                                      # list installed CLIs
run-model.sh config show                                 # show resolved config
run-model.sh config set --cli <cli> [--model <m>]        # persist a default
```

## Read-only sandbox tradeoff

Default runs execute in a throwaway temp directory: the external model
**cannot mutate the repo**, but it also **cannot see repo files** — it has
no access to your working tree at all. So a read-only "opinion about this
code" request only works if you **embed the relevant code/context directly
in the prompt** yourself before calling the dispatcher. Use `--write` only
when you genuinely want the external model to read and edit files in the
real repo — it then runs with repo access and edit permission, not in the
sandbox.

`--all` is the best choice for second-opinion requests: it fans the same
prompt out to every installed CLI **in parallel** and returns the answers
side by side, always read-only regardless of `--write`. It does **not**
forward `--model`: each CLI runs with its own default model, because model
names are not portable across these CLIs. If you also pass `--write`, the
dispatcher prints a one-line note that `--write` is ignored and proceeds
with read-only mode.

## Security & Trust

This skill delegates your prompt (and any `--context` file contents) to a
third-party CLI/binary and its associated model provider. That is its
purpose, but it also expands the trust boundary: the external CLI runs with
its own credentials, code, and safety policy.

- **Read-only by default**: every run lands in a throwaway temp dir, so the
  external model cannot read or edit your real repo unless you explicitly opt
  in.
- **`--write` is an explicit trust escalation**: it runs the external CLI at
  the repo root (via `git rev-parse --show-toplevel`, regardless of which
  subdirectory you invoked from) and passes its force/trust flag where the CLI has one
  (cursor-agent `--force`, kiro-cli `--trust-all-tools`), allowing it to edit
  files and bypass any approval prompts the CLI would normally show. opencode
  has no trust flag and is unrestricted whenever it isn't sandboxed, so
  `--write` for opencode lifts the sandbox without passing a flag. Only use
  `--write` when you want the external model to mutate the repo.
- **`--context` exposes file contents**: the contents of the named file are
  prepended to the prompt and sent to the external model. Do not use it on
  files you would not paste into that model's chat UI.
- **Official CLIs only**: only use `opencode`, `cursor-agent`, or `kiro-cli`
  installed from their official sources. The skill has no way to verify the
  provenance of an arbitrary binary on `PATH`.
- **Prompt boundary**: the dispatcher passes the prompt as a positional argv
  argument separated by `--`, so a prompt starting with `-` cannot be
  misinterpreted as a CLI flag. Still, treat the prompt itself as untrusted
  third-party content when it originates from outside the current session.

## Slash usage

- `/external-model <prompt>` — run a prompt through the resolved default CLI
- `/external-model config set --cli opencode --model openai/gpt-5` — persist a default
- `/external-model config show` — print the resolved config

The shorthands `set` / `show` are accepted as aliases for `config set` /
`config show` (the script treats `run-model.sh set ...` exactly like
`run-model.sh config set ...`, and `run-model.sh show` like `config show`),
so neither ever runs a model with a literal `"set"`/`"show"` prompt.

## Resolution precedence

When the user doesn't pin a CLI explicitly, resolve in this order:

1. Explicit flags on the command (`--cli`, `--model`)
2. Repo config `.claude/external-model.config`
3. Global config `~/.claude/skills/external-model/config`
4. If exactly one CLI is installed, use it
5. If several are installed and none is configured as default, **ask the
   user which one** — then re-invoke with `--cli <their choice>`. Do not
   guess.

Passing `--cli` alone (no `--model`) uses that CLI's own default model — it
does **not** inherit a `MODEL` from config.

## Config

`config set` writes only the **global** file
(`~/.claude/skills/external-model/config`). A **per-repo** override at
`.claude/external-model.config` (lines of `KEY=VALUE`: `CLI=...`,
`MODEL=...`) is hand-authored by the user — the skill reads it but never
writes it. Don't create or edit that file on the user's behalf.

Omitting `--model` from `config set --cli X` clears any previously-stored
`MODEL=` line in the global config and leaves the new state as
`CLI=X` only. To restore a model later, run `config set --cli X --model M`.

## Prerequisites

Each CLI (`opencode`, `cursor-agent`, `kiro-cli`) must be installed and
authenticated independently of this skill; `kiro-cli` headless mode
specifically requires `KIRO_API_KEY` to be set. Read
`references/cli-matrix.md` when you need exact per-CLI install checks,
invocation flags, model-name formats, or auth/timeout gotchas — don't
inline that detail here.

## Checklist

Before shipping a change to this skill, verify:

- [ ] `name` matches the folder name (`external-model`)
- [ ] `description` includes trigger phrases ("Use when...") and is under 1024 chars
- [ ] Companion files (`scripts/run-model.sh`, `references/cli-matrix.md`) are referenced, not inlined
- [ ] Entry added to `README.md` and `.claude-plugin/plugin.json`
- [ ] `bash scripts/validate-skills.sh` passes
