---
name: haskell-cabal-gild
description: |
  Format Haskell package descriptions and project files with cabal-gild — `*.cabal`,
  `cabal.project`, `cabal.project.local`, `cabal.project.freeze`. Normalises layout, sorts
  `build-depends`, and expands `-- cabal-gild: discover` module lists. Use when: (1) formatting or
  tidying a `.cabal` or `cabal.project` file, (2) after editing dependencies or stanzas, (3)
  refreshing auto-discovered module lists after adding/removing a module, (4) checking whether
  cabal files are already formatted. Trigger: "/haskell-cabal-gild", "cabal-gild", "format cabal".
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
---

# cabal-gild — format .cabal and cabal.project files

`cabal-gild` is the formatter for Haskell **package descriptions** (`*.cabal`) and **project
files** (`cabal.project`, `cabal.project.local`, `cabal.project.freeze`). It normalises field
layout, sorts and de-duplicates `build-depends`, and can generate module lists from the
filesystem via `discover` pragmas.

## Format in place
Run on each cabal/project file you touched:
```
cabal-gild --io <file>
```
`--io` sets input and output to the same path. Format **before** compiling.

## Check without writing
To verify formatting (non-zero exit if it would change the file), e.g. in CI or before committing:
```
cabal-gild -m check --io <file>
```

## Auto-discovered module lists
cabal-gild can fill in a module list by scanning a directory. Put a pragma directly above the
field:
```
-- cabal-gild: discover src
exposed-modules:
```
When you **add or remove a module**, the list is stale until cabal-gild is re-run on the owning
`.cabal` file. Re-running `cabal-gild --io <pkg>.cabal` refreshes it.

## Automatic on save
This plugin installs a `PostToolUse` hook (`scripts/cabal-gild-on-save.sh`) that runs on every
file write:
- a `.cabal` / `cabal.project*` save → that file is `cabal-gild`-formatted;
- a `.hs` / `.lhs` / `.hsig` save → the nearest enclosing `.cabal` is re-formatted **only if** it
  uses a `-- cabal-gild: discover` pragma, so discovered module lists stay current.

Manual invocation is therefore mainly for bulk/initial formatting or `check` mode. After the hook
reformats a file, re-read it before editing again.

## Companion
Source files (`.hs`/`.lhs`/`.hsig`) are formatted by `/haskell-format`, not cabal-gild.
