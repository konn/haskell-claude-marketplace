---
name: haskell
description: |
  Super-skill for developing Haskell projects with cabal nix-style builds. Orchestrates the Haskell Language Server, Haddock, and Hoogle tools into one workflow instead of duplicating them. Use when: (1) writing/editing/refactoring Haskell (.hs/.lhs/.hsig/.cabal/package.yaml) code, (2) building or typechecking a cabal project, (3) fixing compiler or type errors, (4) renaming or looking up symbols, (5) adding or changing dependencies. Treats cabal.project as the source of truth, prefers the LSP before full builds, and local docs over remote. Trigger: "/haskell" or any Haskell development task.
---

# Haskell Development Super-Skill

The entry point for Haskell development in this environment. It **coordinates** the other
tools in the `konn-haskell-claude-tools` marketplace (plus the external Hoogle marketplace)
rather than reimplementing them.

## Ground rules
- **cabal nix-style builds only.** `cabal.project` (+ `cabal.project.local`) is the source of
  truth. Do not use stack or invoke `ghc` directly.
- **Package by package.** In a multi-package project, work on and build one package at a time
  (`cabal build <pkg>`), getting it green before moving on — not `cabal build all`.
- **Format before compiling.** Run the project's configured formatter (fourmolu / ormolu /
  stylish-haskell) on changed files before building.
- **`(<>)` over `(++)`** for all concatenation, including lists and strings.
- After editing any `package.yaml`, run `hpack` to regenerate the `.cabal` file.

## Workflow
1. **Edit** the code (format first).
2. **Typecheck with the LSP before any full build.** With `haskell-lsp-plugin` installed, use
   the Haskell Language Server via the LSP tools for diagnostics, hover/types,
   go-to-definition, find-references, and rename. This is far faster than `cabal build` and is
   the default for quick feedback and refactors — reach for it *before* a full-scale build.
3. **Look up APIs** when you need a signature, instance, or implementation. Prefer local
   information over remote to avoid loading Haskell's public infrastructure:
   - `/haddock <pkg> [module]` — local Haddock docs and source for project dependencies (preferred).
   - `/hoogle:search` — search by name or type signature.
   - `/hoogle:remote` — remote Hoogle, only when local search is insufficient.
4. **Build** with cabal once the LSP is clean: `cabal build <pkg>`. Fix errors, then move to the
   next package.
5. **Test**: `cabal test <pkg>` (or `cabal run <pkg>:<test-suite>`).

## Adding / changing dependencies
- Edit `package.yaml` / `*.cabal` (or `cabal.project` for `source-repository-package`s), run
  `hpack` if the project uses hpack, then run `cabal build all` once so the build plan and local
  docs refresh.
- After dependencies change, `/haddock` will not resolve new packages locally until
  `cabal build all` has run (and `documentation: True` is set).

## Companion tools
| Need | Use |
| --- | --- |
| Typecheck, types, definitions, references, rename | `haskell-lsp-plugin` (LSP tools) |
| Docs / source of a dependency | `/haddock` |
| Find a function by name or type | `/hoogle:search`, then `/hoogle:remote` |
