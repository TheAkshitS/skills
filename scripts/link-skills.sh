#!/usr/bin/env bash
set -euo pipefail

# Links every skill in this repo into the global skill directories used by
# supported agent harnesses. Safe to re-run.
#
# Targets (created if missing, skipped if absent):
#   ~/.claude/skills/        Claude Code
#   ~/.pi/agent/skills/      pi (preferred global dir)
#   ~/.agents/skills/        pi + opencode fallback global dir
#
# Each target is independently guarded against the symlink-into-repo trap
# (see the per-target block). Use --dry-run to print without writing.

# -P resolves symlinks so REPO matches `pwd -P` in the symlink-guard below
# (macOS: /var -> /private/var; without -P the guard can fail to trip and
# the script would write symlinks back into the repo).
REPO="$(cd "$(dirname "$0")/.." && pwd -P)"

DRY_RUN=0
if [ "${1:-}" = "--dry-run" ] || [ "${1:-}" = "-n" ]; then
  DRY_RUN=1
fi

# Collect the list of skill sources once, then iterate per target. The find
# excludes match validate-skills.sh: _template / deprecated / in-progress /
# personal are never linked.
SKILL_SRCS=()
while IFS= read -r -d '' skill_md; do
  SKILL_SRCS+=("$skill_md")
done < <(find "$REPO/skills" -name SKILL.md \
  -not -path '*/node_modules/*' \
  -not -path '*/_template/*' \
  -not -path '*/deprecated/*' \
  -not -path '*/in-progress/*' \
  -not -path '*/personal/*' -print0)

link_into() {
  local dest="$1"
  local label="$2"

  # If the target dir itself is a symlink that points back into this repo,
  # linking would write the per-skill symlinks into our own skills/ tree.
  # Bail out for this target only; other targets still proceed.
  if [ -L "$dest" ]; then
    local resolved
    resolved="$(cd "$dest" 2>/dev/null && pwd -P || true)"
    case "$resolved" in
      "$REPO"|"$REPO"/*)
        echo "warning: $dest is a symlink into this repo ($resolved); skipping" >&2
        echo "  fix: rm \"$dest\" and re-run; it'll be recreated as a real dir." >&2
        return 0
        ;;
    esac
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] would link into $label ($dest)"
    for skill_md in ${SKILL_SRCS[@]+"${SKILL_SRCS[@]}"}; do
      local name
      name="$(basename "$(dirname "$skill_md")")"
      echo "[dry-run]   $name -> $(dirname "$skill_md")"
    done
    return 0
  fi

  mkdir -p "$dest"

  for skill_md in ${SKILL_SRCS[@]+"${SKILL_SRCS[@]}"}; do
    local src
    local name
    local target
    src="$(dirname "$skill_md")"
    name="$(basename "$src")"
    target="$dest/$name"

    if [ -e "$target" ] && [ ! -L "$target" ]; then
      echo "warning: replacing non-symlink $target" >&2
      rm -rf "$target"
    fi

    ln -sfn "$src" "$target"
    echo "linked [$label] $name -> $src"
  done
}

link_into "$HOME/.claude/skills" "claude"
link_into "$HOME/.pi/agent/skills" "pi"
# ~/.agents/skills is shared with opencode and other Agent Skills spec agents;
# linking there is harmless if no such harness is installed.
link_into "$HOME/.agents/skills" "agents-shared"
