#!/usr/bin/env bash
set -euo pipefail

# run.sh — hermetic, executable grader for the external-model evals.
#
# Encodes the expectations[] arrays from evals.json as concrete checks
# against the dispatcher's dry-run output. Runs with NONE of the real CLIs
# installed: we stub opencode/cursor-agent/kiro-cli on a temp PATH (so
# `command -v` and `detect`/`--all` resolve them) and use a temp HOME (so
# config set/show touch a throwaway config, never the real one). The run
# path never execs the stubs because EXTERNAL_MODEL_DRYRUN=1 short-circuits.

HERE="$(cd "$(dirname "$0")" && pwd)"
DISPATCH="$HERE/../scripts/run-model.sh"

# --- Hermetic environment ---------------------------------------------------
STUB_DIR="$(mktemp -d)"
FAKE_HOME="$(mktemp -d)"
cleanup() { rm -rf "$STUB_DIR" "$FAKE_HOME"; }
trap cleanup EXIT

for cli in opencode cursor-agent kiro-cli; do
  printf '#!/usr/bin/env bash\nexit 0\n' >"$STUB_DIR/$cli"
  chmod +x "$STUB_DIR/$cli"
done

export PATH="$STUB_DIR:$PATH"
export HOME="$FAKE_HOME"
export EXTERNAL_MODEL_DRYRUN=1

# The dispatcher anchors --write cwd and per-repo config at the git repo root.
# Stay in the real repo so eval-2's mode=repo:<root> and eval-4's per-repo
# absence assertions resolve against the actual repo paths the evals encode.
REPO_ROOT="$(git -C "$HERE" rev-parse --show-toplevel)"
cd "$REPO_ROOT"

FAILS=0
PASSES=0

# assert <eval-label> <description> <ok-bool> -> records pass/fail
pass_eval() { printf 'PASS %s: %s\n' "$1" "$2"; PASSES=$((PASSES + 1)); }
fail_eval() { printf 'FAIL %s: %s\n' "$1" "$2" >&2; FAILS=$((FAILS + 1)); }

# check <label> <desc> tests... : run a block of assertions; any failure fails
# the eval. Each assertion call appends to a per-eval reason buffer.
REASON=""
expect() {
  # expect "<human reason>" <test-command...>
  local reason="$1"; shift
  if "$@"; then return 0; fi
  REASON="${REASON:+$REASON; }$reason"
  return 1
}
contains() { case "$2" in *"$1"*) return 0;; *) return 1;; esac; }
not_contains() { case "$2" in *"$1"*) return 1;; *) return 0;; esac; }

run_eval() {
  local label="$1" desc="$2"
  REASON=""
  if "eval_$label"; then
    pass_eval "$label" "$desc"
  else
    fail_eval "$label" "$desc -- $REASON"
  fi
}

# --- eval-1: --all fans out read-only ---------------------------------------
eval_1() {
  local out err rc=0
  out="$("$DISPATCH" --all "second opinion on retry backoff" 2>/tmp/em_e1.err)" || rc=$?
  err="$(cat /tmp/em_e1.err)"; rm -f /tmp/em_e1.err
  local ok=0
  expect "missing ---- opencode ---- header" contains "---- opencode ----" "$out" || ok=1
  expect "missing ---- cursor-agent ---- header" contains "---- cursor-agent ----" "$out" || ok=1
  expect "missing ---- kiro-cli ---- header" contains "---- kiro-cli ----" "$out" || ok=1
  expect "missing opencode done-in line" \
    grep -qE '\-\-\-\- opencode done in [0-9]+s \(exit [0-9]+\) \-\-\-\-' <<<"$out" || ok=1
  expect "missing read-only sandbox marker for opencode" \
    contains "DRYRUN cli=opencode mode=sandbox(temp-dir)" "$out" || ok=1
  expect "stderr not empty in dry-run" test -z "$err" || ok=1
  return $ok
}

# --- eval-2: --cli cursor-agent --write -------------------------------------
eval_2() {
  local out rc=0
  out="$("$DISPATCH" --cli cursor-agent --write \
    "refactor: split src/legacy/billing.py into billing_core.py, billing_tax.py, and billing_report.py" \
    2>/dev/null)" || rc=$?
  local ok=0
  expect "missing DRYRUN cli=cursor-agent" contains "DRYRUN cli=cursor-agent" "$out" || ok=1
  expect "missing mode=repo:$REPO_ROOT" contains "mode=repo:$REPO_ROOT" "$out" || ok=1
  expect "cmd array lacks cursor-agent" contains "[cursor-agent]" "$out" || ok=1
  expect "cmd array lacks --force" contains "[--force]" "$out" || ok=1
  expect "prompt lacks billing_core" contains "billing_core" "$out" || ok=1
  expect "prompt lacks billing_tax" contains "billing_tax" "$out" || ok=1
  expect "prompt lacks billing_report" contains "billing_report" "$out" || ok=1
  expect "--write did not override sandbox" not_contains "sandbox(temp-dir)" "$out" || ok=1
  return $ok
}

# --- eval-3: per-CLI gpt-5 model mapping ------------------------------------
eval_3() {
  local oc ca kc kc_err rc=0 ok=0
  oc="$("$DISPATCH" --cli opencode --model gpt-5 "Postgres indexing question" 2>/dev/null)" || rc=$?
  ca="$("$DISPATCH" --cli cursor-agent --model gpt-5 "Postgres indexing question" 2>/dev/null)" || rc=$?
  kc="$("$DISPATCH" --cli kiro-cli --model gpt-5 "Postgres indexing question" 2>/tmp/em_e3.err)" || rc=$?
  kc_err="$(cat /tmp/em_e3.err)"; rm -f /tmp/em_e3.err

  expect "opencode cmd mismatch" contains \
    "DRYRUN cmd: [opencode] [run] [-m] [gpt-5] [Postgres indexing question]" "$oc" || ok=1
  expect "cursor-agent cmd mismatch" contains \
    "DRYRUN cmd: [cursor-agent] [-p] [--output-format] [text] [-m] [gpt-5] [--trust] [Postgres indexing question]" "$ca" || ok=1
  expect "missing kiro-cli model-select warning" \
    contains "kiro-cli headless has no model-select flag" "$kc_err" || ok=1
  expect "kiro-cli cmd mismatch" contains \
    "DRYRUN cmd: [kiro-cli] [chat] [--no-interactive] [Postgres indexing question]" "$kc" || ok=1
  # The kiro-cli DRYRUN cmd line must not carry [-m] (model dropped).
  local kc_cmdline
  kc_cmdline="$(grep 'DRYRUN cmd:' <<<"$kc" || true)"
  expect "kiro-cli cmd still contains [-m]" not_contains "[-m]" "$kc_cmdline" || ok=1
  return $ok
}

# --- eval-4: config set writes global only ----------------------------------
eval_4() {
  local out rc=0 ok=0
  local gconf="$HOME/.claude/skills/external-model/config"
  local repoconf="$REPO_ROOT/.claude/external-model.config"
  local repoconf_pre=0
  [[ -e "$repoconf" ]] && repoconf_pre=1
  out="$("$DISPATCH" config set --cli opencode --model openai/gpt-5 2>/dev/null)" || rc=$?

  expect "missing wrote-global confirmation" contains \
    "wrote global default: CLI=opencode MODEL=openai/gpt-5 -> $gconf" "$out" || ok=1
  expect "global config file not written" test -f "$gconf" || ok=1
  expect "first line not v=1" test "$(head -n1 "$gconf" 2>/dev/null)" = "v=1" || ok=1
  expect "missing CLI=opencode line" grep -qx 'CLI=opencode' "$gconf" || ok=1
  expect "missing MODEL=openai/gpt-5 line" grep -qx 'MODEL=openai/gpt-5' "$gconf" || ok=1
  # Per-repo config must not be created by the run. (It is outside FAKE_HOME,
  # so if it pre-existed in the repo we tolerate that pre-existence; we only
  # assert the run did not newly create it.)
  if [[ $repoconf_pre -eq 0 ]]; then
    expect "per-repo config was created" test ! -e "$repoconf" || ok=1
  fi
  return $ok
}

# --- eval-5: config show, no-config case ------------------------------------
eval_5() {
  # Fresh temp HOME with no config, and force resolution to the no-config
  # branch by ensuring there is more than one installed CLI (all stubs are).
  local out rc=0 ok=0
  rm -rf "$HOME/.claude" 2>/dev/null || true
  out="$("$DISPATCH" config show 2>/dev/null)" || rc=$?
  expect "missing cli: (none resolved) line" \
    contains "cli:    (none resolved)" "$out" || ok=1
  expect "missing model: (CLI default) line" \
    contains "model:  (CLI default)" "$out" || ok=1
  expect "missing source: no config line" \
    contains "source: no config; installed:" "$out" || ok=1
  expect "exit code not 0" test "$rc" -eq 0 || ok=1
  return $ok
}

# --- eval-6: detect lists installed CLIs ------------------------------------
eval_6() {
  local out rc=0 ok=0
  out="$("$DISPATCH" detect 2>/dev/null)" || rc=$?
  expect "missing opencode line" grep -qx 'opencode' <<<"$out" || ok=1
  expect "missing cursor-agent line" grep -qx 'cursor-agent' <<<"$out" || ok=1
  expect "missing kiro-cli line" grep -qx 'kiro-cli' <<<"$out" || ok=1
  expect "detect emitted DRYRUN" not_contains "DRYRUN" "$out" || ok=1
  expect "exit code not 0" test "$rc" -eq 0 || ok=1
  return $ok
}

# --- Drive ------------------------------------------------------------------
run_eval 1 "--all fans out read-only"
run_eval 2 "--cli cursor-agent --write edits repo with --force"
run_eval 3 "per-CLI gpt-5 model mapping"
run_eval 4 "config set writes global default only"
run_eval 5 "config show reports no-config state"
run_eval 6 "detect lists installed CLIs"

echo ""
echo "external-model evals: $PASSES passed, $FAILS failed (6 total)"
if [[ $FAILS -gt 0 ]]; then
  exit 1
fi
echo "All external-model evals passed."
