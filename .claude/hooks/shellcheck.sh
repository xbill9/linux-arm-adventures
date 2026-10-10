#!/bin/sh
# PostToolUse hook: shellcheck a shell script just written/edited under
# c630/{scripts,initramfs,system}/. Findings go back to Claude (exit 2).
f=$(jq -r '.tool_response.filePath // .tool_input.file_path // empty')
case "$f" in
  */c630/scripts/*|*/c630/initramfs/*|*/c630/system/*) ;;
  *) exit 0 ;;
esac
[ -f "$f" ] || exit 0
head -n1 "$f" | grep -Eq '^#!.*(/|env )(ba|da)?sh' || exit 0
command -v shellcheck >/dev/null || exit 0
out=$(shellcheck -f gcc -e SC1091 "$f") && exit 0
printf 'shellcheck %s:\n%s\n' "$f" "$out" >&2
exit 2
