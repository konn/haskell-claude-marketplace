---
name: haddock
description: |
  Read Haskell package documentation (Haddock HTML) and source code for the dependencies of a cabal nix-style project, preferring locally-built/cached files over the network. Use when: (1) looking up the API or docs of a dependency, (2) reading the source of a dependency, (3) understanding how a library function is implemented, (4) inspecting the types/instances a package exposes. Prefers the local cabal store and repo-cache; falls back to Hackage only for packages outside the project's dependency set. Trigger: "/haddock <package> [module]".
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - WebFetch
---

# Haskell Haddock & Source Reader

Read documentation (Haddock HTML) and source code for the dependencies of a cabal
nix-style project, **preferring local files over the network**. Always exhaust local
sources before fetching from Hackage, to avoid loading Haskell's public infrastructure.

## Which source to use
- Package **is a dependency** of the current project → read locally (steps below).
- Package is **outside** the project's dependencies → fall back to Hackage
  (`https://hackage.haskell.org/package/<pkg>`).

## One-time setup (per project)
1. Ensure documentation is enabled — `cabal.project.local` must contain `documentation: True`:
   ```
   cabal configure --enable-documentation
   ```
2. Build once after any dependency change so docs/source are materialised:
   ```
   cabal build all
   ```
3. Grab the critical paths (JSON form is easiest to parse):
   ```
   cabal path --output-format=json
   ```
   - `compiler.store-path` (a.k.a. `compiler-store-path`) → directory of built packages **and
     their HTML docs**, e.g. `~/.cabal/store/ghc-9.10.3-fe9c`.
   - `remote-repo-cache` → directory of downloaded **source tarballs**, e.g.
     `~/Library/Haskell/repo-cache`.

## Resolving a dependency
cabal abbreviates and hashes package names in the store (e.g. `splitmix-0.1.1` →
`spltmx-0.1.1-b2e11b56`), so **never construct store paths from the package name** — read the
exact `UnitId` from the build plan:

1. Open `{project-root}/dist-newstyle/cache/plan.json` (run `cabal build all` first if absent).
2. Find the package's entry in `install-plan[]`; note its `id` (the UnitId), `pkg-name`,
   `pkg-version`, and `pkg-src.type` (the dependency kind).

### `pkg-src.type` = `repo-tar` (Hackage / Stackage)
- **HTML docs**: `<compiler-store-path>/<UnitId>/share/doc/**/html/index.html`.
  Module pages use the dotted module name with `.`→`-`, e.g. `System.Random.SplitMix` →
  `System-Random-SplitMix.html`. The exact subdirectory varies, so `Glob` under the unit's
  `share/` directory rather than hardcoding it.
- **Source**: extract the tarball at
  `<remote-repo-cache>/hackage.haskell.org/<pkg-name>/<pkg-version>/<pkg-name>-<pkg-version>.tar.gz`.
  Stream a single file without unpacking everything:
  ```
  tar -xzOf <tarball> <pkg>-<ver>/<path/to/File.hs>
  ```
  or list members with `tar -tzf <tarball>`.

### `pkg-src.type` = `source-repo` or `local` (source-repository-package, local packages)
- These are unpacked under `{project-root}/dist-newstyle/` (e.g.
  `dist-newstyle/src/<pkg>-<hash>/` for source-repository-packages). Locate with `Glob` and
  `Read` the `.hs` files directly. Local packages live at their path in `cabal.project`.

### Package outside the dependency set
- Docs: `WebFetch https://hackage.haskell.org/package/<pkg>` (module page:
  `/<pkg>-<ver>/docs/<Dotted-As-Dashes-Module>.html`).
- Prefer `/hoogle:search` for symbol/type lookup before fetching full pages.

## Notes
- If local docs are missing, the likely cause is that `documentation: True` was not set or
  `cabal build all` has not run since the dependency was added — redo the setup steps.
