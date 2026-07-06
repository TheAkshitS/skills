#!/usr/bin/env bash
set -euo pipefail

# Script-global: lazily created (see ensure_run_tmpdir) on first sandbox use
# as the SINGLE parent temp dir for every per-CLI sandbox in this invocation.
# Each sandbox is `mktemp -d -p "$RUN_TMPDIR"` rather than a bare top-level
# `mktemp -d`. This matters for --all: each CLI's run_one executes inside a
# forked subshell (`run_one ... &`), so a per-call variable set inside that
# child is invisible to the parent shell whose signal trap actually fires.
# Nesting every sandbox under one parent dir that the PARENT shell created
# (and remembers in this variable) lets the top-level trap below remove every
# sandbox with a single `rm -rf "$RUN_TMPDIR"`, regardless of which shell —
# parent or forked child — created the sandbox subdirectory inside it.
RUN_TMPDIR=""

ensure_run_tmpdir() {
  if [[ -z "$RUN_TMPDIR" ]]; then
    RUN_TMPDIR="$(mktemp -d)"
  fi
}

# Propagate SIGINT/SIGTERM to the whole process group so all CLI children
# die (single-CLI and every forked --all child alike), then remove
# RUN_TMPDIR (sweeping every per-CLI sandbox in one shot) before exiting.
# Without the process-group kill + RUN_TMPDIR sweep, Ctrl-C/SIGTERM leaks
# running children and their /tmp/tmp.XXXX sandboxes because a foreground
# child blocks this trap from running until the child itself exits.
#
# `trap '' INT TERM EXIT` is the first thing this does, before `kill 0`.
# `kill 0` sends the signal to this process's own group, which includes
# itself — so without disarming the traps first, a SIGINT handler's own
# `kill 0` re-delivers SIGTERM to this very shell, re-entering this function
# via the TERM trap, which would run to completion and `exit 143` before the
# original INT call's `exit 130` is ever reached. Disarming first makes the
# handler non-reentrant and preserves the originally-intended exit code.
cleanup_and_exit() {
  local code="$1"
  trap '' INT TERM EXIT
  kill 0 2>/dev/null || true
  if [[ -n "$RUN_TMPDIR" ]]; then
    rm -rf "$RUN_TMPDIR"
    RUN_TMPDIR=""
  fi
  exit "$code"
}
trap 'cleanup_and_exit 130' INT
trap 'cleanup_and_exit 143' TERM
trap 'rm -rf "$RUN_TMPDIR"' EXIT

# run-model.sh — dispatcher that normalizes three external agentic CLIs
# (opencode, cursor-agent, kiro-cli) behind one stable interface.
#
# See -h/--help for usage.

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
CLIS=(opencode cursor-agent kiro-cli)
DEFAULT_TIMEOUT=120
GLOBAL_CONFIG="${HOME}/.claude/skills/external-model/config"

# Repo-root resolution: anchor per-repo config and --write cwd at the git
# repo root when inside one, otherwise at the user's PWD. This way a
# `cd src/ && run-model.sh` still finds ./.claude/external-model.config at
# the repo root, and --write still edits files in the real repo, not a
# subdir the agent happened to be in.
repo_root() {
  git rev-parse --show-toplevel 2>/dev/null || printf '%s' "$PWD"
}
REPO_ROOT="$(repo_root)"
REPO_CONFIG="${REPO_ROOT}/.claude/external-model.config"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
err() { printf '%s\n' "$*" >&2; }
die() { err "$*"; exit 1; }

# Warnings are emitted to stderr for risky operations (--write, --context).
# Set NO_WARN=1 (via --no-warn) to suppress them in automation.
warn() {
  if [[ "${NO_WARN:-0}" -eq 0 ]]; then
    err "$*"
  fi
}

usage() {
  cat <<'EOF'
run-model.sh — run a prompt through an external AI CLI (opencode, cursor-agent, kiro-cli)

USAGE
  run-model.sh [options] "prompt"          run a prompt (prompt may also come from stdin)
  run-model.sh detect                      list installed CLIs (command -v only)
  run-model.sh config show                 print resolved default cli/model and its source
  run-model.sh show                        alias for 'config show'
  run-model.sh config set --cli X [--model M]
                                           write GLOBAL default; --cli without --model clears MODEL
  run-model.sh set --cli X [--model M]     alias for 'config set'

OPTIONS
  --cli <name>       force CLI: opencode | cursor-agent | kiro-cli
  --model <name>     force model (passed to the CLI; omitted -> CLI default)
  --write            run in the real repo cwd and allow file edits (trust/force flag)
  --all              fan out to ALL installed CLIs, forced read-only, side-by-side
                     (each CLI uses its own default model; --model is not forwarded)
  --dry-run          print resolved command/cwd/timeout instead of running
  --context <file>   read file and prepend contents to prompt (use - for stdin)
  --timeout <secs>   per-invocation timeout (default 120; env EXTERNAL_MODEL_TIMEOUT)
  --no-warn          suppress trust/content warnings on stderr
  -h, --help         this help

RESOLUTION PRECEDENCE (highest first)
  --cli/--model flags
  repo config   <repo-root>/.claude/external-model.config   (read from git root, falls back to PWD)
  global config ~/.claude/skills/external-model/config
  the single installed CLI (if exactly one)
  otherwise: error listing detected CLIs, asking for --cli

SAFETY & TRUST
  Default mode is read-only: the CLI runs inside a throwaway temp dir, so it
  cannot mutate the real repo regardless of its own flags. --write runs in the
  repo cwd and passes the CLI's trust/force flag, giving the external model the
  ability to edit files. Prompts and any --context file contents are sent to
  the third-party CLI/model. Use --no-warn to suppress these warnings.

ENV
  EXTERNAL_MODEL_TIMEOUT   default timeout in seconds
  EXTERNAL_MODEL_DRYRUN=1  print the resolved command/cwd/timeout instead of running
  KIRO_API_KEY             required by kiro-cli
EOF
}

is_installed() { command -v "$1" >/dev/null 2>&1; }

installed_clis() {
  local c
  for c in "${CLIS[@]}"; do
    if is_installed "$c"; then printf '%s\n' "$c"; fi
  done
}

# Safe config read: never `source`. Read only known KEY= lines, first match wins.
# $1 = file, $2 = KEY -> prints value (may be empty / absent)
#
# Format: lines of `KEY=VALUE`. Required `v=1` header (older configs without
# `v=` are tolerated as v1 for back-compat). Unknown keys are ignored. If
# `v=` is present and != 1, this function prints nothing AND sets the
# caller's CONFIG_VERSION_ERROR to a non-empty diagnostic.
CONFIG_VERSION_ERROR=""

config_get() {
  local file="$1" key="$2" line val
  [[ -f "$file" ]] || return 0
  # First pass: detect version if explicitly set.
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    case "$line" in
      v=*)
        val="${line#*=}"
        val="${val#"${val%%[![:space:]]*}"}"
        val="${val%"${val##*[![:space:]]}"}"
        if [[ "$val" != "1" ]]; then
          CONFIG_VERSION_ERROR="config $file declares v=$val; this build only understands v=1"
          return 0
        fi
        ;;
    esac
  done <"$file"
  # Second pass: read the requested key.
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    case "$line" in
      "${key}="*)
        val="${line#*=}"
        val="${val#"${val%%[![:space:]]*}"}"
        val="${val%"${val##*[![:space:]]}"}"
        val="${val%\"}"; val="${val#\"}"
        val="${val%\'}"; val="${val#\'}"
        printf '%s' "$val"
        return 0
        ;;
    esac
  done <"$file"
  return 0
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
ARG_CLI=""
ARG_MODEL=""
ARG_MODEL_SET=0
WRITE=0
ALL=0
NO_WARN=0
TIMEOUT="${EXTERNAL_MODEL_TIMEOUT:-$DEFAULT_TIMEOUT}"
PROMPT=""
PROMPT_SET=0
SUBCMD=""          # detect | config
CONFIG_ACTION=""   # show | set
CONTEXT_FILE=""

# First, peel off subcommands when they appear as the first token.
if [[ $# -gt 0 ]]; then
  case "$1" in
    detect)
      SUBCMD="detect"; shift ;;
    config)
      SUBCMD="config"; shift
      [[ $# -gt 0 ]] || die "config: expected 'show' or 'set'"
      CONFIG_ACTION="$1"; shift
      case "$CONFIG_ACTION" in show|set) ;; *) die "config: unknown action '$CONFIG_ACTION' (use show|set)";; esac
      ;;
    set|show)
      # Bare aliases for `config set` / `config show`. Prevents an agent that
      # translates the docs literally (`run-model.sh set ...`, `run-model.sh
      # show`) from accidentally running a live model with the prompt "set"/"show".
      SUBCMD="config"; CONFIG_ACTION="$1"; shift ;;
    -h|--help)
      usage; exit 0 ;;
  esac
fi

# Parse remaining flags/positionals.
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cli)     [[ $# -ge 2 ]] || die "--cli requires a value"; ARG_CLI="$2"; shift 2 ;;
    --model)   [[ $# -ge 2 ]] || die "--model requires a value"; ARG_MODEL="$2"; ARG_MODEL_SET=1; shift 2 ;;
    --write)   WRITE=1; shift ;;
    --all)     ALL=1; shift ;;
    --context) [[ $# -ge 2 ]] || die "--context requires a value"; CONTEXT_FILE="$2"; shift 2 ;;
    --dry-run) export EXTERNAL_MODEL_DRYRUN=1; shift ;;
    --no-warn) NO_WARN=1; shift ;;
    --timeout) [[ $# -ge 2 ]] || die "--timeout requires a value"; TIMEOUT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    --)        shift; if [[ $# -gt 0 ]]; then PROMPT="$1"; PROMPT_SET=1; shift; fi ;;
    -*)        die "unknown option: $1" ;;
    *)
      if [[ $PROMPT_SET -eq 0 ]]; then PROMPT="$1"; PROMPT_SET=1; shift
      else die "unexpected extra argument: $1"; fi
      ;;
  esac
done

# Validate --cli value early if provided.
if [[ -n "$ARG_CLI" ]]; then
  case "$ARG_CLI" in
    opencode|cursor-agent|kiro-cli) ;;
    *) die "unknown --cli '$ARG_CLI' (valid: opencode, cursor-agent, kiro-cli)";;
  esac
fi

# Numeric timeout sanity.
if [[ -n "$TIMEOUT" && ! "$TIMEOUT" =~ ^[1-9][0-9]*$ ]]; then
  die "--timeout must be a positive integer (got '$TIMEOUT')"
fi

# ---------------------------------------------------------------------------
# Subcommand: detect
# ---------------------------------------------------------------------------
if [[ "$SUBCMD" == "detect" ]]; then
  found=0
  while IFS= read -r c; do
    [[ -n "$c" ]] || continue
    printf '%s\n' "$c"
    found=1
  done < <(installed_clis)
  if [[ $found -eq 0 ]]; then
    err "no external CLIs installed (looked for: ${CLIS[*]})"
    exit 1
  fi
  exit 0
fi

# ---------------------------------------------------------------------------
# Subcommand: config
# ---------------------------------------------------------------------------
# Field separator for resolve_default output: a non-whitespace char so that
# `read` preserves empty fields (whitespace IFS like \t collapses them).
RD_SEP=$'\x1f'

resolve_default() {
  # Prints "CLI<SEP>MODEL<SEP>SOURCE". MODEL may be empty.
  local cli model
  if [[ -f "$REPO_CONFIG" ]]; then
    cli="$(config_get "$REPO_CONFIG" CLI)"
    if [[ -n "$cli" ]]; then
      model="$(config_get "$REPO_CONFIG" MODEL)"
      printf '%s%s%s%s%s\n' "$cli" "$RD_SEP" "$model" "$RD_SEP" "repo config ($REPO_CONFIG)"
      return 0
    fi
  fi
  if [[ -f "$GLOBAL_CONFIG" ]]; then
    cli="$(config_get "$GLOBAL_CONFIG" CLI)"
    if [[ -n "$cli" ]]; then
      model="$(config_get "$GLOBAL_CONFIG" MODEL)"
      printf '%s%s%s%s%s\n' "$cli" "$RD_SEP" "$model" "$RD_SEP" "global config ($GLOBAL_CONFIG)"
      return 0
    fi
  fi
  # single installed CLI?
  local -a list=()
  local c
  while IFS= read -r c; do
    list+=("$c")
  done < <(installed_clis)
  if [[ "${#list[@]}" -eq 1 ]]; then
    printf '%s%s%s%s%s\n' "${list[0]}" "$RD_SEP" "" "$RD_SEP" "only installed CLI"
    return 0
  fi
  return 1
}

if [[ "$SUBCMD" == "config" ]]; then
  case "$CONFIG_ACTION" in
    show)
      # Pre-scan GLOBAL/REPO configs for an explicit bad version. The check
      # must happen in the current shell (not a `$(...)` subshell) so the
      # CONFIG_VERSION_ERROR side effect from config_get is visible here.
      config_get "$GLOBAL_CONFIG" v >/dev/null
      [[ -z "$CONFIG_VERSION_ERROR" ]] && config_get "$REPO_CONFIG" v >/dev/null
      if [[ -n "$CONFIG_VERSION_ERROR" ]]; then
        die "$CONFIG_VERSION_ERROR"
      fi
      if out="$(resolve_default)"; then
        IFS="$RD_SEP" read -r r_cli r_model r_src <<<"$out"
        printf 'cli:    %s\n' "$r_cli"
        if [[ -n "$r_model" ]]; then printf 'model:  %s\n' "$r_model"; else printf 'model:  (CLI default)\n'; fi
        printf 'source: %s\n' "$r_src"
      else
        printf 'cli:    (none resolved)\n'
        printf 'model:  (CLI default)\n'
        printf 'source: no config; installed: %s\n' "$(installed_clis | tr '\n' ' ')"
      fi
      exit 0
      ;;
    set)
      [[ -n "$ARG_CLI" ]] || die "config set: --cli is required"
      [[ $PROMPT_SET -eq 0 ]] || die "config set: unexpected argument '$PROMPT' (config set takes only --cli and --model)"
      if [[ "$ARG_CLI" == "kiro-cli" && -z "${KIRO_API_KEY:-}" ]]; then
        err "hint: kiro-cli requires KIRO_API_KEY; it is not set in the environment."
      fi
      mkdir -p "$(dirname "$GLOBAL_CONFIG")"
      {
        printf 'v=1\n'
        printf 'CLI=%s\n' "$ARG_CLI"
        if [[ $ARG_MODEL_SET -eq 1 && -n "$ARG_MODEL" ]]; then
          printf 'MODEL=%s\n' "$ARG_MODEL"
        fi
      } >"$GLOBAL_CONFIG"
      if [[ $ARG_MODEL_SET -eq 1 && -n "$ARG_MODEL" ]]; then
        printf 'wrote global default: CLI=%s MODEL=%s -> %s\n' "$ARG_CLI" "$ARG_MODEL" "$GLOBAL_CONFIG"
      else
        printf 'wrote global default: CLI=%s (model cleared) -> %s\n' "$ARG_CLI" "$GLOBAL_CONFIG"
      fi
      exit 0
      ;;
  esac
fi

# ---------------------------------------------------------------------------
# Prompt acquisition (run path)
# ---------------------------------------------------------------------------
if [[ "$CONTEXT_FILE" == "-" && $PROMPT_SET -eq 0 && ! -t 0 ]]; then
  die "cannot use --context - when prompt also comes from stdin; pass prompt as argument"
fi
if [[ $PROMPT_SET -eq 0 ]]; then
  if [[ ! -t 0 ]]; then
    PROMPT="$(cat)"
    PROMPT_SET=1
  fi
fi
if [[ $PROMPT_SET -eq 0 || -z "$PROMPT" ]]; then
  die "no prompt provided (pass as an argument or on stdin)"
fi

# ---------------------------------------------------------------------------
# Context injection
# ---------------------------------------------------------------------------
if [[ -n "$CONTEXT_FILE" ]]; then
  ctx=""
  if [[ "$CONTEXT_FILE" == "-" ]]; then
    if [[ ! -t 0 ]]; then
      ctx="$(cat)"
    else
      die "--context - requires data on stdin"
    fi
  else
    [[ -e "$CONTEXT_FILE" ]] || die "--context file not found: $CONTEXT_FILE"
    [[ -r "$CONTEXT_FILE" ]] || die "--context file not readable: $CONTEXT_FILE"
    ctx="$(<"$CONTEXT_FILE")"
  fi
  if [[ -n "$ctx" ]]; then
    PROMPT="${ctx}

---

${PROMPT}"
  fi
  warn "warning: --context forwards the contents of '$CONTEXT_FILE' to an external model."
fi

# ---------------------------------------------------------------------------
# Timeout wrapper resolution
# ---------------------------------------------------------------------------
TIMEOUT_BIN=""
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_BIN="timeout"
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_BIN="gtimeout"
fi
WARNED_NO_TIMEOUT=0
warn_no_timeout_once() {
  if [[ $WARNED_NO_TIMEOUT -eq 0 ]]; then
    err "warning: no 'timeout'/'gtimeout' found; running without a timeout"
    WARNED_NO_TIMEOUT=1
  fi
}

# ---------------------------------------------------------------------------
# Build the CLI command array for a given cli + model + write-mode.
# Sets global array CMD=( ... ). The prompt is appended as the LAST element of
# CMD (a positional argv arg) for every CLI — all three take the prompt as a
# positional argument and break if it is piped on stdin. An argv array element
# is immune to word-splitting / glob / $()/backtick expansion, so this stays
# injection-safe.
# ---------------------------------------------------------------------------
build_cmd() {
  local cli="$1" model="$2" write="$3"
  CMD=()
  case "$cli" in
    opencode)
      # opencode has no headless read-only flag; read-only safety comes from
      # the temp-dir sandbox, not from a CLI flag.
      CMD=(opencode run)
      if [[ -n "$model" ]]; then CMD+=(-m "$model"); fi
      ;;
    cursor-agent)
      CMD=(cursor-agent -p --output-format text)
      if [[ -n "$model" ]]; then CMD+=(-m "$model"); fi
      if [[ "$write" -eq 1 ]]; then
        # --force already satisfies the workspace-trust gate (see below).
        CMD+=(--force)
      else
        # Since the cursor-agent January 2026 release, non-interactive runs
        # in an untrusted workspace fail unless --trust or --force is passed
        # (https://cursor.com/docs/cli/changelog). The dispatcher's read-only
        # mode always runs inside a fresh mktemp -d sandbox, which is an
        # untrusted workspace on every invocation, so --trust is required
        # here to avoid a hard failure instead of a clean read-only run.
        CMD+=(--trust)
      fi
      ;;
    kiro-cli)
      CMD=(kiro-cli chat --no-interactive)
      # kiro-cli takes no model flag in this mapping.
      if [[ "$write" -eq 1 ]]; then CMD+=(--trust-all-tools); fi
      ;;
    *)
      die "internal: unknown cli '$cli'"
      ;;
  esac
  # End-of-options delimiter prevents a prompt starting with '-' from being
  # parsed as a CLI flag; the prompt is always the final positional argument.
  CMD+=(-- "$PROMPT")
}

# ---------------------------------------------------------------------------
# Run one CLI. Args: cli model write
# Honors EXTERNAL_MODEL_DRYRUN, sandbox isolation, and timeout.
# Returns the CLI's exit code (or 0 on dry-run).
# ---------------------------------------------------------------------------
run_one() {
  local cli="$1" model="$2" write="$3"
  local cwd_kind

  if [[ "$write" -eq 1 ]]; then
    cwd_kind="repo:$REPO_ROOT"
    warn "warning: --write allows $cli to edit files in the repo and bypasses approval prompts; you are trusting a third-party binary."
  else
    cwd_kind="sandbox(temp-dir)"
  fi

  # kiro env hint (don't block; let the real error surface, but help the caller).
  # Only on real runs — a dry-run shouldn't emit env warnings.
  if [[ -z "${EXTERNAL_MODEL_DRYRUN:-}" && "$cli" == "kiro-cli" && -z "${KIRO_API_KEY:-}" ]]; then
    err "hint: kiro-cli requires KIRO_API_KEY; it is not set in the environment."
  fi

  build_cmd "$cli" "$model" "$write"

  # Build the full command. In dry-run, omit the `timeout` wrapper — it's a
  # runtime safeguard, not part of the command semantics, and including it
  # would make dry-run output depend on whether the host has GNU `timeout`
  # installed (Linux yes, macOS no). On real runs, wrap when both TIMEOUT_BIN
  # and TIMEOUT are set.
  local full=()
  if [[ -z "${EXTERNAL_MODEL_DRYRUN:-}" && -n "$TIMEOUT_BIN" && -n "$TIMEOUT" ]]; then
    full=("$TIMEOUT_BIN" "${TIMEOUT}s" "${CMD[@]}")
  else
    if [[ -z "$TIMEOUT_BIN" && -z "${EXTERNAL_MODEL_DRYRUN:-}" ]]; then
      warn_no_timeout_once
    fi
    full=("${CMD[@]}")
  fi

  if [[ "${EXTERNAL_MODEL_DRYRUN:-}" == "1" ]]; then
    # Minimal, clearly-marked dry-run: print resolved cwd, timeout, command array.
    local resolved_cwd
    if [[ "$write" -eq 1 ]]; then resolved_cwd="$REPO_ROOT"; else resolved_cwd="<temp sandbox dir>"; fi
    printf 'DRYRUN cli=%s mode=%s cwd=%s timeout=%s\n' \
      "$cli" "$cwd_kind" "$resolved_cwd" "${TIMEOUT:-none}"
    printf 'DRYRUN cmd:'
    local a
    for a in "${full[@]}"; do printf ' [%s]' "$a"; done
    printf '\n'
    return 0
  fi

  # Real run. The prompt is the final element of "${full[@]}" (an argv arg),
  # never on stdin — all three CLIs take it positionally.
  if [[ "$write" -eq 1 ]]; then
    # Stay in the repo cwd so the CLI can read/edit the real working tree.
    "${full[@]}"
  else
    local sandbox rc
    # Every sandbox nests under the single parent RUN_TMPDIR (created here on
    # first use) instead of being its own top-level mktemp -d. That parent
    # dir is known to the dispatcher's own (top-level-trap-owning) shell even
    # when run_one itself executes inside a forked --all subshell, so the
    # top-level INT/TERM trap can always find and remove it — see RUN_TMPDIR
    # above. A local EXIT trap on the sandbox dir is kept too, belt and
    # suspenders, for prompt cleanup on normal (non-signal) completion of
    # this specific run, independent of when the rest of run_one finishes.
    ensure_run_tmpdir
    sandbox="$(mktemp -d -p "$RUN_TMPDIR")"
    trap 'rm -rf "$sandbox"' EXIT
    # Run the CLI as a BACKGROUND job and `wait` on it (mirrors the --all
    # fan-out path) rather than running it as a foreground command. A
    # foreground child blocks bash from servicing signals until the child
    # exits, so the top-level INT/TERM trap couldn't fire until the CLI
    # finished on its own — leaking both the child and the sandbox dir on
    # Ctrl-C/SIGTERM. `wait` on a background job, by contrast, is
    # interrupted immediately when a trapped signal arrives, so the trap
    # runs right away (see cleanup_and_exit at the top of this file), kills
    # the process group (the child included), and removes RUN_TMPDIR (which
    # contains $sandbox).
    ( cd "$sandbox" && "${full[@]}" ) &
    rc=0
    wait "$!" || rc=$?
    rm -rf "$sandbox"
    trap - EXIT
    return "$rc"
  fi
}

# ---------------------------------------------------------------------------
# --all : fan out to every installed CLI, forced read-only.
# ---------------------------------------------------------------------------
if [[ $ALL -eq 1 ]]; then
  if [[ $WRITE -eq 1 ]]; then
    err "note: --all is forced read-only; --write is ignored"
  fi
  if [[ $ARG_MODEL_SET -eq 1 ]]; then
    err "note: --all ignores --model; each CLI uses its own default"
  fi
  any=0
  cli_list=()
  while IFS= read -r c; do
    [[ -n "$c" ]] || continue
    cli_list+=("$c")
    any=1
  done < <(installed_clis)
  if [[ $any -eq 0 ]]; then
    die "no external CLIs installed (looked for: ${CLIS[*]})"
  fi

  # Emit the no-timeout warning once, here, in the parent before the fanout
  # loop launches children. Each child runs run_one in its own forked
  # subshell (via `&`), so WARNED_NO_TIMEOUT=1 set here is inherited by copy
  # at fork time and the children's own warn_no_timeout_once calls become
  # no-ops — instead of one warning per installed CLI.
  if [[ -z "$TIMEOUT_BIN" && -z "${EXTERNAL_MODEL_DRYRUN:-}" ]]; then
    warn_no_timeout_once
  fi

  declare -a cli_pids=() cli_outf=() cli_errf=() cli_starts=()
  for i in "${!cli_list[@]}"; do
    c="${cli_list[$i]}"
    cli_outf[$i]="$(mktemp)"
    cli_errf[$i]="$(mktemp)"
    cli_starts[$i]=$SECONDS
    run_one "$c" "" 0 >"${cli_outf[$i]}" 2>"${cli_errf[$i]}" &
    cli_pids[$i]=$!
  done
  # Clean up the --all-specific per-CLI stdout/err temp files on INT/TERM,
  # then delegate to the same top-level cleanup_and_exit used everywhere
  # else, instead of doing its own ad hoc `kill 0` here. Two reasons this
  # must delegate rather than duplicate:
  #   1. RUN_TMPDIR sweep: cleanup_and_exit is what removes RUN_TMPDIR (the
  #      single parent dir holding every forked child's sandbox — see
  #      RUN_TMPDIR above). A trap here that only `kill 0`s and returns
  #      would kill every child but never reach an `exit`, leaking every
  #      per-CLI sandbox dir and leaving the shell to die from the raw
  #      signal instead of the documented 130/143 exit code.
  #   2. Non-reentrancy: cleanup_and_exit disarms INT/TERM/EXIT before its
  #      own `kill 0`, so the self-delivered signal from that `kill 0` can't
  #      re-enter any handler and clobber the originally-intended exit code.
  # The previous (per-loop-iteration) trap value is irrelevant here — we're
  # intentionally overriding it for the duration of the fanout/wait below,
  # same as before, just routing to the shared handler instead of inlining.
  trap 'for f in "${cli_outf[@]}" "${cli_errf[@]}"; do rm -f "$f"; done; cleanup_and_exit 130' INT
  trap 'for f in "${cli_outf[@]}" "${cli_errf[@]}"; do rm -f "$f"; done; cleanup_and_exit 143' TERM

  declare -a cli_rcs=() cli_elapsed=()
  for i in "${!cli_list[@]}"; do
    rc=0
    wait "${cli_pids[$i]}" || rc=$?
    cli_rcs[$i]=$rc
    cli_elapsed[$i]=$(( SECONDS - ${cli_starts[$i]} ))
  done

  for i in "${!cli_list[@]}"; do
    c="${cli_list[$i]}"
    printf -- '---- %s ----\n' "$c"
    cat "${cli_outf[$i]}"
    printf -- '---- %s done in %ds (exit %d) ----\n' "$c" "${cli_elapsed[$i]}" "${cli_rcs[$i]}"
    if [[ ${cli_rcs[$i]} -ne 0 ]]; then
      err "(${c} failed; stderr follows)"
      if [[ -s "${cli_errf[$i]}" ]]; then
        printf -- '---- %s stderr ----\n' "$c" >&2
        cat "${cli_errf[$i]}" >&2
        printf -- '---- end %s stderr ----\n' "$c" >&2
      fi
    fi
    rm -f "${cli_outf[$i]}" "${cli_errf[$i]}"
    printf '\n'
  done
  # Propagate worst exit code so CI/pipelines detect --all degradation.
  max_rc=0
  for i in "${!cli_list[@]}"; do
    if [[ ${cli_rcs[$i]} -gt $max_rc ]]; then max_rc=${cli_rcs[$i]}; fi
  done
  exit "$max_rc"
fi

# ---------------------------------------------------------------------------
# Single run: resolve cli + model per precedence.
# ---------------------------------------------------------------------------
RES_CLI=""
RES_MODEL=""

# Pre-scan GLOBAL/REPO configs for an explicit bad version BEFORE the
# --cli/no-default-config branch below, so an explicit `--cli` can no longer
# bypass the version gate. Must run in the current shell (not a `$(...)`
# subshell) so the CONFIG_VERSION_ERROR side effect from config_get is
# visible here. `--all` and `detect` exit earlier and are unaffected.
config_get "$GLOBAL_CONFIG" v >/dev/null
[[ -z "$CONFIG_VERSION_ERROR" ]] && config_get "$REPO_CONFIG" v >/dev/null
[[ -z "$CONFIG_VERSION_ERROR" ]] || die "$CONFIG_VERSION_ERROR"

if [[ -n "$ARG_CLI" ]]; then
  RES_CLI="$ARG_CLI"
  # model: explicit flag wins; otherwise leave empty (flags don't inherit config model here
  # unless the same cli is the configured default — keep simple: explicit cli => explicit/none model).
  if [[ $ARG_MODEL_SET -eq 1 ]]; then RES_MODEL="$ARG_MODEL"; fi
else
  if out="$(resolve_default)"; then
    IFS="$RD_SEP" read -r RES_CLI RES_MODEL _src <<<"$out"
  else
    die "no default CLI resolved. Installed CLIs: $(installed_clis | tr '\n' ' ')
Re-invoke with --cli <opencode|cursor-agent|kiro-cli>, or set a default with:
  $(basename "$0") config set --cli <cli> [--model <model>]"
  fi
  # An explicit --model overrides the config model even when cli came from config.
  if [[ $ARG_MODEL_SET -eq 1 ]]; then RES_MODEL="$ARG_MODEL"; fi
fi

[[ -n "$RES_CLI" ]] || die "could not resolve a CLI to run (use --cli)."

# Warn regardless of where the model came from (explicit --model or a
# config-sourced default) — kiro-cli headless drops it either way.
if [[ "$RES_CLI" == "kiro-cli" && -n "$RES_MODEL" ]]; then
  err "warning: kiro-cli headless has no model-select flag; --model '$RES_MODEL' will be ignored"
fi

run_one "$RES_CLI" "$RES_MODEL" "$WRITE"
