---
name: haskell-format
description: |
  Format Haskell source files — `*.hs`, `*.lhs`, `*.hsig` — with the project's configured
  formatter (fourmolu, ormolu, or stylish-haskell). Use when: (1) formatting Haskell source before
  compiling, (2) tidying code after edits, (3) applying a project's fourmolu/stylish style. Picks
  the formatter from project config, falling back to the first available. Trigger:
  "/haskell-format", "format Haskell", "fourmolu", "ormolu", "stylish-haskell".
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
---

# Format Haskell source (.hs / .lhs / .hsig)

Formats Haskell **source** files with the project's formatter. (`.cabal` / `cabal.project` files
are handled by `/haskell-cabal-gild`, not here.) Always format **before** compiling.

## Choosing the formatter
Walk up from the file's directory and pick by config, else the first tool available:
1. `fourmolu.yaml` / `.fourmolu.yaml` present → **fourmolu**
2. `.stylish-haskell.yaml` present → **stylish-haskell**
3. otherwise the first of **fourmolu → ormolu → stylish-haskell** found on `PATH`.

## Format in place
All three accept `-i` as the in-place shortcut:
```
fourmolu -i <file>        # or: ormolu -i <file> / stylish-haskell -i <file>
```

## Automatic on save
This plugin installs a `PostToolUse` hook (`scripts/haskell-format-on-save.sh`) that formats any
`.hs`/`.lhs`/`.hsig` file in place right after it is written. After the hook reformats a file,
re-read it before editing again. Manual invocation is mainly for bulk formatting.

## Companion
`.cabal` / `cabal.project` files are formatted by `/haskell-cabal-gild`.
