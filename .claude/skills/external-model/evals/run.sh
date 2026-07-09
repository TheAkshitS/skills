#!/usr/bin/env bash
set -euo pipefail

# run.sh — hermetic, executable grader for the external-model evals.
#
# Encodes the assertions[] arrays from evals.json as concrete checks
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

# Minimal `timeout` shim so eval-12's real-exec timeout assertion is
# deterministic on any host, including macOS dev machines that ship neither
# GNU `timeout` nor `gtimeout`. It's placed on STUB_DIR, which is prepended
# to PATH below, so it wins over any real timeout/gtimeout the host has.
# Mirrors just enough of GNU coreutils' `timeout DURATION cmd...` (DURATION
# as "Ns") for run-model.sh's own usage: run cmd, and if it's still alive
# after DURATION, TERM it.
cat >"$STUB_DIR/timeout" <<'STUB'
#!/usr/bin/env bash
dur="${1%s}"; shift
"$@" &
pid=$!
( sleep "$dur"; kill -TERM "$pid" 2>/dev/null ) &
watcher=$!
if wait "$pid" 2>/dev/null; then rc=0; else rc=$?; fi
kill "$watcher" 2>/dev/null
wait "$watcher" 2>/dev/null
exit "$rc"
STUB
chmod +x "$STUB_DIR/timeout"

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
  local errfile="$FAKE_HOME/em_e1.err"
  out="$("$DISPATCH" --all "second opinion on retry backoff" 2>"$errfile")" || rc=$?
  err="$(cat "$errfile")"; rm -f "$errfile"
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
  local out err rc=0
  local errfile="$FAKE_HOME/em_e2.err"
  out="$("$DISPATCH" --cli cursor-agent --write \
    "refactor: split src/legacy/billing.py into billing_core.py, billing_tax.py, and billing_report.py" \
    2>"$errfile")" || rc=$?
  err="$(cat "$errfile")"; rm -f "$errfile"
  local ok=0
  expect "missing DRYRUN cli=cursor-agent" contains "DRYRUN cli=cursor-agent" "$out" || ok=1
  expect "missing mode=repo:$REPO_ROOT" contains "mode=repo:$REPO_ROOT" "$out" || ok=1
  expect "cmd array lacks cursor-agent" contains "[cursor-agent]" "$out" || ok=1
  expect "cmd array lacks --force" contains "[--force]" "$out" || ok=1
  expect "prompt lacks billing_core" contains "billing_core" "$out" || ok=1
  expect "prompt lacks billing_tax" contains "billing_tax" "$out" || ok=1
  expect "prompt lacks billing_report" contains "billing_report" "$out" || ok=1
  expect "missing -- delimiter in cursor-agent cmd" contains "[--] [refactor:" "$out" || ok=1
  expect "missing --write warning" contains "warning: --write allows cursor-agent" "$err" || ok=1
  expect "--write did not override sandbox" not_contains "sandbox(temp-dir)" "$out" || ok=1
  return $ok
}

# --- eval-3: per-CLI gpt-5 model mapping ------------------------------------
eval_3() {
  local oc ca kc kc_err rc=0 ok=0
  local errfile="$FAKE_HOME/em_e3.err"
  oc="$("$DISPATCH" --cli opencode --model gpt-5 "Postgres indexing question" 2>/dev/null)" || rc=$?
  ca="$("$DISPATCH" --cli cursor-agent --model gpt-5 "Postgres indexing question" 2>/dev/null)" || rc=$?
  kc="$("$DISPATCH" --cli kiro-cli --model gpt-5 "Postgres indexing question" 2>"$errfile")" || rc=$?
  kc_err="$(cat "$errfile")"; rm -f "$errfile"

  expect "opencode cmd mismatch" contains \
    "DRYRUN cmd: [opencode] [run] [-m] [gpt-5] [--] [Postgres indexing question]" "$oc" || ok=1
  expect "cursor-agent cmd mismatch" contains \
    "DRYRUN cmd: [cursor-agent] [-p] [--output-format] [text] [-m] [gpt-5] [--trust] [--] [Postgres indexing question]" "$ca" || ok=1
  expect "missing kiro-cli model-select warning" \
    contains "kiro-cli headless has no model-select flag" "$kc_err" || ok=1
  expect "kiro-cli cmd mismatch" contains \
    "DRYRUN cmd: [kiro-cli] [chat] [--no-interactive] [--] [Postgres indexing question]" "$kc" || ok=1
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
  rm -rf "$FAKE_HOME/.claude" 2>/dev/null || true
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

# --- eval-7: dash-prefixed prompt accepted without explicit -- -----------------
eval_7() {
  local out rc=0 ok=0
  out="$("$DISPATCH" --cli opencode "-explain this code" 2>/dev/null)" || rc=$?
  expect "exit code not 0" test "$rc" -eq 0 || ok=1
  expect "missing opencode dry-run header" \
    contains "DRYRUN cli=opencode" "$out" || ok=1
  # The dispatcher must pass the prompt through; the child CLI gets `--` delimiter.
  expect "cmd does not contain [--] delimiter" \
    contains "[--]" "$out" || ok=1
  expect "dash-prefixed prompt not in final cmd element" \
    contains "[-explain this code]" "$out" || ok=1
  return $ok
}

# --- eval-8: --context pointing at a directory ------------------------------
eval_8() {
  local out err rc=0 ok=0
  local errfile="$FAKE_HOME/em_e8.err"
  out="$("$DISPATCH" --context "$FAKE_HOME" "summarize these notes" 2>"$errfile")" || rc=$?
  err="$(cat "$errfile")"; rm -f "$errfile"
  expect "exit code not non-zero" test "$rc" -ne 0 || ok=1
  expect "missing not-a-regular-file die message" \
    contains "--context file is not a regular file: $FAKE_HOME" "$err" || ok=1
  expect "unexpectedly reached DRYRUN output" not_contains "DRYRUN" "$out" || ok=1
  return $ok
}

# --- eval-9: --context file over the 256 KiB cap ----------------------------
eval_9() {
  local out err rc=0 ok=0
  local bigfile="$FAKE_HOME/em_e9_huge.log"
  local errfile="$FAKE_HOME/em_e9.err"
  head -c 300000 /dev/zero >"$bigfile"
  out="$("$DISPATCH" --context "$bigfile" "what broke?" 2>"$errfile")" || rc=$?
  err="$(cat "$errfile")"; rm -f "$errfile"
  expect "exit code not non-zero" test "$rc" -ne 0 || ok=1
  expect "missing too-large die message" \
    contains "--context file is too large: $bigfile" "$err" || ok=1
  expect "missing limit-bytes text" contains "limit is 262144 bytes" "$err" || ok=1
  expect "unexpectedly reached DRYRUN output" not_contains "DRYRUN" "$out" || ok=1
  rm -f "$bigfile"
  return $ok
}

# --- eval-10: invalid --timeout value ---------------------------------------
eval_10() {
  local out err rc=0 ok=0
  local errfile="$FAKE_HOME/em_e10.err"
  out="$("$DISPATCH" --timeout abc "quick question" 2>"$errfile")" || rc=$?
  err="$(cat "$errfile")"; rm -f "$errfile"
  expect "exit code not non-zero" test "$rc" -ne 0 || ok=1
  expect "missing bad-timeout die message" \
    contains "--timeout must be a positive integer (got 'abc')" "$err" || ok=1
  expect "unexpectedly reached DRYRUN output" not_contains "DRYRUN" "$out" || ok=1
  return $ok
}

# --- eval-11: unknown --cli value -------------------------------------------
eval_11() {
  local out err rc=0 ok=0
  local errfile="$FAKE_HOME/em_e11.err"
  out="$("$DISPATCH" --cli nonexistent-tool "quick question" 2>"$errfile")" || rc=$?
  err="$(cat "$errfile")"; rm -f "$errfile"
  expect "exit code not non-zero" test "$rc" -ne 0 || ok=1
  expect "missing unknown-cli die message" \
    contains "unknown --cli 'nonexistent-tool' (valid: opencode, cursor-agent, kiro-cli)" "$err" || ok=1
  expect "unexpectedly reached DRYRUN output" not_contains "DRYRUN" "$out" || ok=1
  return $ok
}

# --- eval-12: real execution (no DRYRUN) -- exit code + timeout enforcement -
# Every eval above runs with EXTERNAL_MODEL_DRYRUN=1, so none of them ever
# executed run_one's real-run branch (build_cmd's timeout-wrapper selection,
# the kiro-cli env hint gate, and the actual sandboxed exec). This is the one
# eval that unsets it and lets the dispatcher really exec the stub CLI.
eval_12() {
  local out err rc=0 ok=0 start end elapsed
  local errfile="$FAKE_HOME/em_e12.err"

  # -- (a) exit code propagation: stub exits 42, no timeout involved. --
  # Route the dispatcher's stdout to a regular file, not a command
  # substitution: the real-run path backgrounds the CLI under `set -m`, and
  # capturing that through a `$(...)` pipe wedges the pipe open (the harness
  # is itself often run under an outer capture, e.g. validate-skills.sh) — a
  # plain file has no reader to block. All the other evals are dry-run and
  # never hit this, so they can keep using `$(...)`.
  local outfile="$FAKE_HOME/em_e12.out"
  printf '#!/usr/bin/env bash\nexit 42\n' >"$STUB_DIR/opencode"
  chmod +x "$STUB_DIR/opencode"
  env -u EXTERNAL_MODEL_DRYRUN "$DISPATCH" --cli opencode "ping" >"$outfile" 2>"$errfile" || rc=$?
  out="$(cat "$outfile")"; err="$(cat "$errfile")"; rm -f "$outfile" "$errfile"
  expect "exit code did not propagate from stub (got $rc, want 42)" test "$rc" -eq 42 || ok=1
  expect "unexpectedly printed DRYRUN output on a real run" not_contains "DRYRUN" "$out" || ok=1

  # -- (b) a hanging CLI is actually killed once --timeout elapses. --------
  # Timeout enforcement delegates to a `timeout`/`gtimeout` binary; the harness
  # puts a portable `timeout` shim on STUB_DIR (see top of file) so this runs
  # deterministically on every host, coreutils or not.
  # `exec sleep 10` (not a plain `sleep 10`) so the stub's own bash process is
  # replaced by `sleep` rather than spawning it as a child: a real CLI binary
  # is a single process, and a bare `sleep` child would survive its parent
  # bash getting killed (orphaned) since a kill of the direct PID alone
  # doesn't reach a foreground child.
  printf '#!/usr/bin/env bash\nexec sleep 10\n' >"$STUB_DIR/opencode"
  chmod +x "$STUB_DIR/opencode"
  rc=0
  start=$SECONDS
  env -u EXTERNAL_MODEL_DRYRUN "$DISPATCH" --cli opencode --timeout 2 "ping" >/dev/null 2>"$errfile" || rc=$?
  end=$SECONDS
  elapsed=$(( end - start ))
  err="$(cat "$errfile")"; rm -f "$errfile"
  expect "hanging stub was not killed in time (took ${elapsed}s, wanted well under 10s)" \
    test "$elapsed" -lt 6 || ok=1
  expect "exit code 0 despite timeout (stub was not actually killed)" \
    test "$rc" -ne 0 || ok=1

  # Restore the opencode stub so it doesn't affect any later eval run.
  printf '#!/usr/bin/env bash\nexit 0\n' >"$STUB_DIR/opencode"
  chmod +x "$STUB_DIR/opencode"
  return $ok
}

# --- Drive ------------------------------------------------------------------
run_eval 1 "--all fans out read-only"
run_eval 2 "--cli cursor-agent --write edits repo with --force"
run_eval 3 "per-CLI gpt-5 model mapping"
run_eval 4 "config set writes global default only"
run_eval 5 "config show reports no-config state"
run_eval 6 "detect lists installed CLIs"
run_eval 7 "dash-prefixed prompt accepted without explicit --"
run_eval 8 "--context pointing at a directory is rejected"
run_eval 9 "--context file over the 256 KiB cap is rejected"
run_eval 10 "invalid --timeout value is rejected"
run_eval 11 "unknown --cli value is rejected"
run_eval 12 "real execution: exit code propagates and --timeout actually kills"

echo ""
echo "external-model evals: $PASSES passed, $FAILS failed (12 total)"
if [[ $FAILS -gt 0 ]]; then
  exit 1
fi
echo "All external-model evals passed."
