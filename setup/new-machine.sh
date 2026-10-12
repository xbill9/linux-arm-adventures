#!/bin/sh
# Bring a new machine's Claude Code setup and personal config up to date from an
# older install, so standing preferences do not have to be repeated.
#
# Copies from OLD_HOST over SSH, keeping any local file that is newer:
#   ~/.claude/CLAUDE.md          global instructions, incl. "Standing preferences"
#   ~/.claude/settings*.json, ~/.claude/statusline-command.sh, ~/.claude/skills/
#   ~/.claude/projects/*/memory/ per-project memories
#   ~/publishing-kit/            the publishing plugin (settings.json points at it)
#   ~/.devto.key                 dev.to API key (chmod 600)
# and sets git user.name/user.email from OLD_HOST's global git config if unset.
#
# Run as the normal user, not root:
#   sh setup/new-machine.sh [-n] user@old-host
# -n: dry run, show what would be copied and change nothing.
# A backup of ~/.claude's top-level config goes to ~/.claude/backups/ first.
set -e

DRY=
if [ "$1" = "-n" ]; then DRY=-n; shift; fi
OLD=$1
[ -n "$OLD" ] || { echo "usage: $0 [-n] user@old-host" >&2; exit 2; }
[ "$(id -u)" -ne 0 ] || { echo "run as your user, not root" >&2; exit 2; }
command -v rsync >/dev/null || { echo "rsync missing: sudo apt install rsync" >&2; exit 1; }
ssh -o BatchMode=yes "$OLD" true || { echo "cannot ssh to $OLD without a prompt" >&2; exit 1; }
ssh "$OLD" command -v rsync >/dev/null || { echo "rsync missing on $OLD" >&2; exit 1; }

# -u: never overwrite a newer local file
R="rsync -a -u -i $DRY"

if [ -z "$DRY" ]; then
  B=~/.claude/backups/pre-new-machine-$(date +%Y%m%d-%H%M%S)
  mkdir -p "$B"
  for f in CLAUDE.md settings.json settings.local.json statusline-command.sh; do
    [ -e ~/.claude/$f ] && cp -p ~/.claude/$f "$B/"
  done
  echo "backup: $B"
fi

mkdir -p ~/.claude
echo "== ~/.claude config"
for f in CLAUDE.md settings.json settings.local.json statusline-command.sh; do
  ssh "$OLD" test -e ".claude/$f" && $R "$OLD:.claude/$f" ~/.claude/
done
ssh "$OLD" test -d .claude/skills && $R "$OLD:.claude/skills/" ~/.claude/skills/

echo "== memories"
$R -m --include='*/' --include='*/memory/***' --exclude='*' \
  "$OLD:.claude/projects/" ~/.claude/projects/

echo "== publishing kit"
ssh "$OLD" test -d publishing-kit && $R --exclude='__pycache__' "$OLD:publishing-kit/" ~/publishing-kit/

echo "== dev.to key"
if ssh "$OLD" test -e .devto.key; then
  $R "$OLD:.devto.key" ~/
  [ -n "$DRY" ] || chmod 600 ~/.devto.key
fi

echo "== git identity"
for k in user.name user.email; do
  if git config --global "$k" >/dev/null; then
    echo "$k already set: $(git config --global "$k")"
  else
    v=$(ssh "$OLD" git config --global "$k" || true)
    if [ -z "$v" ]; then
      echo "$k not set on $OLD either"
    elif [ -n "$DRY" ]; then
      echo "would set $k = $v"
    else
      git config --global "$k" "$v"; echo "set $k = $v"
    fi
  fi
done

echo "== check"
grep -q '^# Standing preferences' ~/.claude/CLAUDE.md \
  && echo "standing preferences present in ~/.claude/CLAUDE.md" \
  || echo "WARNING: no '# Standing preferences' section in ~/.claude/CLAUDE.md" >&2
