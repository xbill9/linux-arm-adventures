#!/bin/sh
# Bring a new machine's Claude Code setup and personal config up to date from one
# or more older installs, so standing preferences do not have to be repeated.
#
# From each OLD_HOST, over SSH (the old host needs only tar):
#   ~/.claude/CLAUDE.md          global instructions: the newest copy among the
#                                hosts wins, and this machine's "# Standing
#                                preferences" section is kept on top if the
#                                winner lacks one
#   ~/.claude/settings*.json, ~/.claude/statusline-command.sh, ~/.claude/skills/
#   ~/.claude/projects/*/memory/ per-project memories, merged across hosts
#   ~/publishing-kit/            the publishing plugin, only if not a git checkout here
#   ~/.devto.key                 dev.to API key (chmod 600)
# Everything except CLAUDE.md keeps whichever copy is newest, local included.
# git user.name/user.email are set from the first host that has them, if unset.
#
# Run as the normal user, not root:
#   sh setup/new-machine.sh [-n] user@old-host [user@other-old-host ...]
# -n: dry run, show what would change and change nothing.
# A backup of ~/.claude's top-level config goes to ~/.claude/backups/ first.
set -e

DRY=
if [ "$1" = "-n" ]; then DRY=-n; shift; fi
[ $# -gt 0 ] || { echo "usage: $0 [-n] user@old-host [user@old-host ...]" >&2; exit 2; }
[ "$(id -u)" -ne 0 ] || { echo "run as your user, not root" >&2; exit 2; }
command -v rsync >/dev/null || { echo "rsync missing: sudo apt install rsync" >&2; exit 1; }

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

# Paths are relative to $HOME on the old host.
# One command per line: a line break inside a command runs the rest as a new one.
P='.claude/CLAUDE.md .claude/settings.json .claude/settings.local.json .claude/statusline-command.sh .claude/skills publishing-kit .devto.key'
LIST="ls -d $P 2>/dev/null; find .claude/projects -path '*/memory/*' -type f 2>/dev/null"

i=0
for H in "$@"; do
  i=$((i + 1))
  ssh -o BatchMode=yes "$H" true || { echo "cannot ssh to $H without a prompt" >&2; exit 1; }
  mkdir -p "$STAGE/$i"
  ssh "$H" "{ $LIST; } | tar cf - --exclude=__pycache__ -T -" | tar xf - -C "$STAGE/$i"
  echo "staged $H: $(find "$STAGE/$i" -type f | wc -l) files"
done

if [ -z "$DRY" ]; then
  B=~/.claude/backups/pre-new-machine-$(date +%Y%m%d-%H%M%S)
  mkdir -p "$B"
  for f in CLAUDE.md settings.json settings.local.json statusline-command.sh; do
    if [ -e ~/.claude/$f ]; then cp -p ~/.claude/$f "$B/"; fi
  done
  echo "backup: $B"
fi

echo "== CLAUDE.md"
NEWEST=$(ls -t "$STAGE"/*/.claude/CLAUDE.md 2>/dev/null | head -1)
if [ -n "$NEWEST" ]; then
  echo "newest: host $(basename "$(dirname "$(dirname "$NEWEST")")") of $*"
  NEW=$STAGE/CLAUDE.md
  if [ -e ~/.claude/CLAUDE.md ] && grep -q '^# Standing preferences' ~/.claude/CLAUDE.md \
     && ! grep -q '^# Standing preferences' "$NEWEST"; then
    awk '/^# Standing preferences/{p=1; print; next} p && /^# /{exit} p' ~/.claude/CLAUDE.md > "$NEW"
    cat "$NEWEST" >> "$NEW"
  else
    cp "$NEWEST" "$NEW"
  fi
  if cmp -s "$NEW" ~/.claude/CLAUDE.md; then
    echo "unchanged"
  else
    diff ~/.claude/CLAUDE.md "$NEW" | grep -c '^[<>]' | sed 's/$/ line(s) differ/' || true
    grep '^# ' "$NEW" | sed 's/^/  section: /'
    [ -n "$DRY" ] || { mkdir -p ~/.claude; cp "$NEW" ~/.claude/CLAUDE.md; echo "written"; }
  fi
fi

echo "== publishing kit"
# A git checkout is compared by commit: copying it by timestamp rewrites
# hundreds of identical files.
KITX=
if [ -d ~/publishing-kit/.git ]; then
  KITX=--exclude=/publishing-kit
  echo "local: $(git -C ~/publishing-kit log -1 --format='%h %ad' --date=short)"
  for H in "$@"; do
    echo "$H: $(ssh "$H" "git -C publishing-kit log -1 --format='%h %ad' --date=short 2>/dev/null" || true)"
  done
  echo "not copied; update with: git -C ~/publishing-kit pull"
fi

echo "== everything else (newest copy wins)"
# skills/publishing is a link to the kit's own skill, which the publishing
# plugin already provides; copying it would list the skill twice.
for d in "$STAGE"/[0-9]*; do
  rsync -a -u -i $DRY $KITX --exclude=/.claude/CLAUDE.md --exclude=/.claude/skills/publishing \
    "$d/" ~/ | grep -v -E '^[.c]d' || true
done
[ -n "$DRY" ] || [ ! -e ~/.devto.key ] || chmod 600 ~/.devto.key

echo "== git identity"
for k in user.name user.email; do
  if git config --global "$k" >/dev/null; then
    echo "$k already set: $(git config --global "$k")"
    continue
  fi
  v=
  for H in "$@"; do
    v=$(ssh "$H" git config --global "$k" || true)
    [ -z "$v" ] || break
  done
  if [ -z "$v" ]; then
    echo "$k not set on any host"
  elif [ -n "$DRY" ]; then
    echo "would set $k = $v (from $H)"
  else
    git config --global "$k" "$v"; echo "set $k = $v (from $H)"
  fi
done
