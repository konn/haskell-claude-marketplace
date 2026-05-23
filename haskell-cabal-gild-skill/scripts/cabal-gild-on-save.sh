#!/usr/bin/env bash
# PostToolUse hook: keep cabal/project files formatted with cabal-gild.
#
# - `.cabal` / `cabal.project*` saved -> reformat that file with `cabal-gild --io`.
# - `.hs` / `.lhs` / `.hsig` saved    -> reformat the nearest enclosing `.cabal` ONLY if it uses a
#                                        `-- cabal-gild: discover` pragma (refresh discovered modules).
#
# Always exits 0 so it never blocks an edit. Reads the PostToolUse JSON from stdin.
set -u

input="$(cat)"
file="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')"
[ -n "$file" ] && [ -f "$file" ] || exit 0
command -v cabal-gild >/dev/null 2>&1 || exit 0

gild() { cabal-gild --io "$1" >/dev/null 2>&1 || true; }

changed=""
case "$(basename "$file")" in
  *.cabal | cabal.project | cabal.project.* )
    b="$(shasum "$file" 2>/dev/null | awk '{print $1}')"
    gild "$file"
    a="$(shasum "$file" 2>/dev/null | awk '{print $1}')"
    [ "$b" != "$a" ] && changed="$file"
    ;;
  *.hs | *.lhs | *.hsig )
    dir="$(cd "$(dirname "$file")" && pwd)"
    while :; do
      if ls "$dir"/*.cabal >/dev/null 2>&1; then
        for c in "$dir"/*.cabal; do
          grep -Eq 'cabal-gild:[[:space:]]*discover' "$c" 2>/dev/null || continue
          b="$(shasum "$c" 2>/dev/null | awk '{print $1}')"
          gild "$c"
          a="$(shasum "$c" 2>/dev/null | awk '{print $1}')"
          [ "$b" != "$a" ] && changed="$c"
        done
        break
      fi
      [ "$dir" = "/" ] && break
      dir="$(dirname "$dir")"
    done
    ;;
esac

if [ -n "$changed" ]; then
  printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"cabal-gild reformatted %s on disk; re-read before further edits."}}\n' "$changed"
fi
exit 0
