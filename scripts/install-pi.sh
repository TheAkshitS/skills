#!/usr/bin/env bash
set -euo pipefail

# Pi-specific installer for the skills in this repo.
#
# Three install modes; pick with the first arg (or use the default):
#
#   link    Link skills into ~/.pi/agent/skills via link-skills.sh.
#           (Default.) Simplest. Skills load for every project.
#
#   settings Print a settings.json snippet for ~/.pi/agent/settings.json
#           pointing at this repo's skills/ dir. No symlinks, no copies.
#           Use --write to write it to disk (existing file is merged, not
#           overwritten).
#
#   project Write a .pi/settings.json in the current dir pointing at
#           ./skills. Repo-local. Requires `pi /trust` on first run.
#
# Use --dry-run / -n to preview. Use --help for this message.

REPO="$(cd "$(dirname "$0")/.." && pwd -P)"

usage() {
  sed -n '4,/^$/p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

MODE="link"
WRITE=0
DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
    --help|-h) usage 0 ;;
    --dry-run|-n) DRY_RUN=1 ;;
    --write) WRITE=1 ;;
    link|settings|project) MODE="$arg" ;;
    *)
      echo "error: unknown argument '$arg'" >&2
      usage 1
      ;;
  esac
done

warn_if_no_pi() {
  if ! command -v pi >/dev/null 2>&1; then
    echo "note: 'pi' is not on PATH. Install with:" >&2
    echo "  npm install -g --ignore-scripts @earendil-works/pi-coding-agent" >&2
    echo "Continuing anyway — you can use these skills with any Agent Skills" >&2
    echo "spec harness (opencode, Codex, etc.) via the same paths." >&2
    echo "" >&2
  fi
}

do_link() {
  warn_if_no_pi
  echo "Linking skills into pi's global dir + others via link-skills.sh..."
  if [ "$DRY_RUN" -eq 1 ]; then
    bash "$REPO/scripts/link-skills.sh" --dry-run
  else
    bash "$REPO/scripts/link-skills.sh"
  fi
  echo ""
  echo "Done. Skills now load under pi in any project."
  echo "Slash command form: /skill:<name>  (e.g. /skill:external-model)"
  echo "Toggle via /settings -> enableSkillCommands (default: on)."
}

do_settings() {
  warn_if_no_pi
  local target="$HOME/.pi/agent/settings.json"
  local repo_skills="$REPO/skills"
  local snippet
  snippet="$(cat <<JSON
{
  "skills": ["$repo_skills"]
}
JSON
)"

  echo "Add this to $target (merge with any existing keys):"
  echo ""
  printf '%s\n' "$snippet"
  echo ""

  if [ "$WRITE" -eq 1 ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "[dry-run] would merge into $target"
      return 0
    fi
    mkdir -p "$(dirname "$target")"
    if [ -f "$target" ]; then
      if command -v jq >/dev/null 2>&1; then
        # Merge: append the repo's skills path to any existing array (or create).
        local tmp
        tmp="$(mktemp)"
        trap 'rm -f "$tmp"' EXIT
        if jq --arg path "$repo_skills" '
          .skills = ((.skills // []) | if index($path) then . else . + [$path] end)
        ' "$target" > "$tmp"; then
          mv "$tmp" "$target"
          echo "merged into existing $target"
        else
          echo "warning: $target exists and jq failed to process it." >&2
          echo "  Please edit it manually and add the 'skills' key above." >&2
          exit 1
        fi
      else
        echo "warning: $target exists and jq is not available to merge safely." >&2
        echo "  Please edit it manually and add the 'skills' key above." >&2
        exit 1
      fi
    else
      printf '%s\n' "$snippet" > "$target"
      echo "wrote $target"
    fi
  else
    echo "Re-run with --write to apply."
  fi
}

do_project() {
  warn_if_no_pi
  local target=".pi/settings.json"
  local snippet
  snippet="$(cat <<JSON
{
  "skills": ["./skills"]
}
JSON
)"

  echo "Would write $target in $(pwd) with:"
  echo ""
  printf '%s\n' "$snippet"
  echo ""

  if [ "$DRY_RUN" -eq 1 ]; then
    return 0
  fi

  if [ -f "$target" ]; then
    echo "error: $target already exists. Edit it manually to add the 'skills' key." >&2
    echo "" >&2
    cat "$target" >&2
    exit 1
  fi

  mkdir -p .pi
  printf '%s\n' "$snippet" > "$target"
  echo "wrote $target"
  echo ""
  echo "First run of pi in this dir will ask you to /trust the project."
}

case "$MODE" in
  link) do_link ;;
  settings) do_settings ;;
  project) do_project ;;
esac
