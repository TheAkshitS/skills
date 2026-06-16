#!/usr/bin/env bash
set -euo pipefail

# Links every skill in this repo into ~/.claude/skills so the local Claude CLI
# can use them. Safe to re-run.
#
# This script targets Claude Code only. Other agents (opencode, Codex, Cursor)
# use different skill directories — install via `npx skills add` for those.

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$HOME/.claude/skills"

# If ~/.claude/skills is a symlink that points back into this repo, linking
# would write the per-skill symlinks into our own skills/ tree. Bail out.
if [ -L "$DEST" ]; then
  resolved="$(cd "$DEST" 2>/dev/null && pwd -P || true)"
  case "$resolved" in
    "$REPO"|"$REPO"/*)
      echo "error: $DEST is a symlink into this repo ($resolved)." >&2
      echo "Remove it (rm \"$DEST\") and re-run; it'll be recreated as a real dir." >&2
      exit 1
      ;;
  esac
fi

mkdir -p "$DEST"

while IFS= read -r -d '' skill_md; do
  src="$(dirname "$skill_md")"
  name="$(basename "$src")"
  target="$DEST/$name"

  if [ -e "$target" ] && [ ! -L "$target" ]; then
    echo "warning: replacing non-symlink $target" >&2
    rm -rf "$target"
  fi

  ln -sfn "$src" "$target"
  echo "linked $name -> $src"
done < <(find "$REPO/skills" -name SKILL.md \
  -not -path '*/node_modules/*' \
  -not -path '*/_template/*' \
  -not -path '*/deprecated/*' \
  -not -path '*/in-progress/*' \
  -not -path '*/personal/*' -print0)
