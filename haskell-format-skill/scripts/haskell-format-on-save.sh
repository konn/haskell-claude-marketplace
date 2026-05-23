#!/usr/bin/env bash
# PostToolUse hook: format Haskell source (.hs/.lhs/.hsig) in place after it is written.
#
# Formatter is chosen by walking up from the file: a fourmolu/stylish config selects that tool,
# otherwise the first of fourmolu -> ormolu -> stylish-haskell found on PATH is used. All three
# accept `-i` for in-place editing. Always exits 0. Reads the PostToolUse JSON from stdin.
set -u

input="$(cat)"
file="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')"
[ -n "$file" ] && [ -f "$file" ] || exit 0
case "$(basename "$file")" in
  *.hs | *.lhs | *.hsig ) ;;
  * ) exit 0 ;;
esac

fmt=""
dir="$(cd "$(dirname "$file")" && pwd)"
while :; do
  if { [ -f "$dir/fourmolu.yaml" ] || [ -f "$dir/.fourmolu.yaml" ]; } && command -v fourmolu >/dev/null 2>&1; then
    fmt="fourmolu"; break
  fi
  if [ -f "$dir/.stylish-haskell.yaml" ] && command -v stylish-haskell >/dev/null 2>&1; then
    fmt="stylish-haskell"; break
  fi
  [ "$dir" = "/" ] && break
  dir="$(dirname "$dir")"
done
if [ -z "$fmt" ]; then
  for f in fourmolu ormolu stylish-haskell; do
    command -v "$f" >/dev/null 2>&1 && { fmt="$f"; break; }
  done
fi
[ -z "$fmt" ] && exit 0

b="$(shasum "$file" 2>/dev/null | awk '{print $1}')"
"$fmt" -i "$file" >/dev/null 2>&1 || true
a="$(shasum "$file" 2>/dev/null | awk '{print $1}')"
if [ "$b" != "$a" ]; then
  printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s was reformatted by %s on disk; re-read before further edits."}}\n' "$file" "$fmt"
fi
exit 0
