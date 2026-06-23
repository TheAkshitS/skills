#!/usr/bin/env bash
set -euo pipefail

# Propagate SIGINT/SIGTERM to the whole process group so the sandbox
# subshell's EXIT trap fires and the temp dir is removed. Without this,
# Ctrl-C leaks /tmp/tmp.XXXX dirs because the subshell never gets the
# signal and never runs its cleanup trap.
trap 'kill 0 2>/dev/null || true; exit 130' INT
trap 'kill 0 2>/dev/null || true; exit 143' TERM

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
  -h, --help         this help

RESOLUTION PRECEDENCE (highest first)
  --cli/--model flags
  repo config   <repo-root>/.claude/external-model.config   (read from git root, falls back to PWD)
  global config ~/.claude/skills/external-model/config
  the single installed CLI (if exactly one)
  otherwise: error listing detected CLIs, asking for --cli

SAFETY
  Default mode is read-only: the CLI runs inside a throwaway temp dir, so it
  cannot mutate the real repo regardless of its own flags. --write runs in the
  repo cwd and passes the CLI's trust/force flag.

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
if [[ -n "$TIMEOUT" && ! "$TIMEOUT" =~ ^[0-9]+$ ]]; then
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
        if [[ -n "$CONFIG_VERSION_ERROR" ]]; then
          die "$CONFIG_VERSION_ERROR"
        fi
        IFS="$RD_SEP" read -r r_cli r_model r_src <<<"$out"
        printf 'cli:    %s\n' "$r_cli"
        if [[ -n "$r_model" ]]; then printf 'model:  %s\n' "$r_model"; else printf 'model:  (CLI default)\n'; fi
        printf 'source: %s\n' "$r_src"
      else
        if [[ -n "$CONFIG_VERSION_ERROR" ]]; then
          die "$CONFIG_VERSION_ERROR"
        fi
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
      if [[ "$write" -eq 1 ]]; then CMD+=(--force); fi
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
  # Prompt is always the final positional argument.
  CMD+=("$PROMPT")
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
  else
    cwd_kind="sandbox(temp-dir)"
  fi

  # kiro env hint (don't block; let the real error surface, but help the caller).
  # Only on real runs — a dry-run shouldn't emit env warnings.
  if [[ -z "${EXTERNAL_MODEL_DRYRUN:-}" && "$cli" == "kiro-cli" && -z "${KIRO_API_KEY:-}" ]]; then
    err "hint: kiro-cli requires KIRO_API_KEY; it is not set in the environment."
  fi

  build_cmd "$cli" "$model" "$write"

  # Build the full command (timeout wrapper + CMD) for both dry-run and real run.
  local full=()
  if [[ -n "$TIMEOUT_BIN" && -n "$TIMEOUT" ]]; then
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
    local sandbox
    sandbox="$(mktemp -d)"
    (
      cd "$sandbox"
      # Subshell EXIT trap keeps cleanup self-contained; doesn't leak to parent.
      # The script-level INT/TERM trap (set near the top of this file)
      # propagates signals to this subshell so the trap fires on Ctrl-C too.
      trap 'rm -rf "$sandbox"' EXIT
      "${full[@]}"
    )
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

  declare -a cli_pids=() cli_outf=() cli_errf=() cli_starts=()
  for i in "${!cli_list[@]}"; do
    c="${cli_list[$i]}"
    cli_outf[$i]="$(mktemp)"
    cli_errf[$i]="$(mktemp)"
    cli_starts[$i]=$SECONDS
    run_one "$c" "" 0 >"${cli_outf[$i]}" 2>"${cli_errf[$i]}" &
    cli_pids[$i]=$!
  done
  # Clean up temp files on INT/TERM — the script-level trap kills children
  # but exits immediately, so the per-file rm at the end never runs.
  trap 'for f in "${cli_outf[@]}" "${cli_errf[@]}"; do rm -f "$f"; done; kill 0 2>/dev/null || true' INT TERM

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

if [[ "$RES_CLI" == "kiro-cli" && $ARG_MODEL_SET -eq 1 && -n "$ARG_MODEL" ]]; then
  err "warning: kiro-cli headless has no model-select flag; --model '$ARG_MODEL' will be ignored"
fi

run_one "$RES_CLI" "$RES_MODEL" "$WRITE"
