---
name: external-model
description: Run a prompt through a different AI model via the opencode, cursor-agent, or kiro-cli command-line tools. Use whenever the user wants a second opinion from another model, asks "what would GPT-5 / Gemini / another model say", wants to delegate a task to cursor / opencode / kiro, run a prompt with a specific external model, get a different take or second opinion on code/design/approach, ask another model to review or weigh in, or set / switch the default external-model CLI — even when the user doesn't explicitly name a CLI or say "second opinion", as long as they want a different AI model's input.
argument-hint: "<prompt> | config show | config set --cli <cli> [--model <m>] | detect"
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

```
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
