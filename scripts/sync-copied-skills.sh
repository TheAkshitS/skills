#!/usr/bin/env bash
set -euo pipefail

# Refreshes the in-repo distribution mirrors that let the repo be dropped
# into any agent's skill directory and just work, without symlinks:
#
#   .claude/skills/<name>/  -> Claude Code + skills.sh installers
#   .agents/skills/<name>/  -> pi + opencode + any Agent Skills spec agent
#
# Sources of truth: skills/<name>/ (excluding _template, deprecated,
# in-progress, personal).
#
# Operation: rsync --delete so removed skills vanish from the mirrors too.
# Real copies, not symlinks — these are committed to git so the repo can be
# cloned anywhere and used as a drop-in folder.
#
# Safety: before syncing, aborts if a mirror contains a skill dir with no
# skills/ counterpart (e.g. something installed out-of-band) rather than
# silently deleting it. Pass --force / --prune to proceed anyway.
#
# Idempotent. Use --dry-run / -n to preview without writing.

REPO="$(cd "$(dirname "$0")/.." && pwd)"

DRY_RUN=0
FORCE=0
for arg in "$@"; do
  case "$arg" in
    --dry-run|-n) DRY_RUN=1 ;;
    --force|--prune) FORCE=1 ;;
    *)
      echo "error: unknown argument '$arg'" >&2
      exit 1
      ;;
  esac
done

if ! command -v rsync >/dev/null 2>&1; then
  echo "error: rsync is required (use --delete for prune, handles all the edge cases)" >&2
  exit 1
fi

RSYNC_FLAGS=(-a --delete --exclude='.DS_Store')
if [ "$DRY_RUN" -eq 1 ]; then
  RSYNC_FLAGS+=(--dry-run --itemize-changes)
fi

# Aborts with a listing if $mirror_abs contains a skill dir that has no
# counterpart under skills/. An unanchored name isn't enough here — a
# missing skills/ entry means rsync --delete would silently remove it.
check_orphans() {
  local mirror_abs="$1"
  local label="$2"
  local orphans=()
  local entry name

  if [ -d "$mirror_abs" ]; then
    for entry in "$mirror_abs"/*/; do
      [ -d "$entry" ] || continue
      name="$(basename "$entry")"
      if [ ! -d "$REPO/skills/$name" ]; then
        orphans+=("$name")
      fi
    done
  fi

  if [ "${#orphans[@]}" -gt 0 ]; then
    echo "error: $label mirror ($mirror_abs) has skill dir(s) with no skills/ counterpart:" >&2
    local o
    for o in "${orphans[@]}"; do
      echo "  - $o" >&2
    done
    echo "  Remove them intentionally if they're stale, or if they were" >&2
    echo "  installed out-of-band and should stay, move them into skills/." >&2
    echo "  Re-run with --force (or --prune) to let this sync delete them." >&2
    return 1
  fi
  return 0
}

sync_mirror() {
  local mirror_rel="$1"
  local label="$2"
  local mirror_abs="$REPO/$mirror_rel"
  local source_dir="$REPO/skills"

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] would refresh $label mirror at $mirror_rel/"
  else
    mkdir -p "$mirror_abs"
  fi

  # Build the --exclude list for the skill folders that are not part of the
  # public set. An unanchored 'name/' pattern already matches at any depth,
  # so a single flag per skip entry is enough.
  local flags=("${RSYNC_FLAGS[@]}")
  for skip in _template deprecated in-progress personal node_modules; do
    flags+=(--exclude="$skip/")
  done

  rsync "${flags[@]}" "$source_dir/" "$mirror_abs/"
}

if [ "$FORCE" -eq 0 ]; then
  orphans_found=0
  check_orphans "$REPO/.claude/skills" "claude" || orphans_found=1
  check_orphans "$REPO/.agents/skills" "agents-shared" || orphans_found=1
  if [ "$orphans_found" -eq 1 ]; then
    exit 1
  fi
fi

sync_mirror ".claude/skills" "claude"
sync_mirror ".agents/skills" "agents-shared"

if [ "$DRY_RUN" -eq 1 ]; then
  echo ""
  echo "Re-run without --dry-run to apply."
fi
