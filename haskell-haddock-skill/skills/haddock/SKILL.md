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

## Resolving a dependency
Run the bundled resolver **from the project root** — it regenerates the build plan, reads
cabal's store and repo-cache paths, looks up the package's exact `UnitId` in
`dist-newstyle/cache/plan.json` (cabal abbreviates/hashes names in the store, e.g.
`splitmix-0.1.1` → `spltmx-0.1.1-b2e11b56`, so paths cannot be guessed), and prints a JSON
object:

```
"${CLAUDE_PLUGIN_ROOT}/scripts/locate-dep.sh" <package>
```

Output shape:
```json
{
  "store_path": "<cabal-store>/<UnitId>",
  "doc_dir":    "<store_path>/share/doc/html",
  "source":     "<repo-cache>/.../<pkg>-<ver>.tar.gz"
}
```
- `store_path` — the resolved unit directory in the cabal store (always present on success). For a
  **local package** (one of the project's own packages) it is instead the package's build dir,
  `dist-newstyle/build/<arch>-<os>/<compiler-id>/<pkg>-<ver>` (reconstructed from the root
  `arch`/`os`/`compiler-id` fields of `plan.json`).
- `doc_dir` — Haddock HTML directory, or `null` if docs were not built (see *Notes*). For a local
  package this is `<store_path>/doc/html/<pkg>`.
- `source` — one of: a **string** path to a Hackage/Stackage source tarball; a **JSON object** with
  `source-repository-package` metadata (VCS `type`, i.e. `git`/`hg`/…); a **JSON object**
  `{"type":"local","path":...}` for a local package's source tree; or `null`.

Parse the JSON, then act on the fields below.

### Reading the docs (`doc_dir`)
When `doc_dir` is non-null, the module pages sit directly inside it. A module's page is its
dotted name with `.`→`-` plus `.html`, e.g. `System.Random.SplitMix` →
`<doc_dir>/System-Random-SplitMix.html`; `<doc_dir>/index.html` lists everything. `Glob`
`<doc_dir>/*.html` if unsure of the exact module name, then `Read` the page.

### Reading the source (`source`)
- **String (tarball path)** — stream a single file without unpacking everything:
  ```
  tar -xzOf <source> <pkg>-<ver>/<path/to/File.hs>
  ```
  or list members with `tar -tzf <source>`.
- **Object — branch on `.type`.**
- **`{"type":"local","path":...}` (local package)** — one of the project's own packages. Its
  source is the project source tree at `path`; read it directly. `Glob <path>/**/*.hs` (or
  `<path>/src/**/*.hs`) to find a module, then `Read`. No unpacking or checkout needed.
- **`source-repository-package` (VCS `type`: `git`/`hg`/…)** — the object is
  `{ type, location, tag, subdir }`, e.g.
  ```json
  {"type":"git","location":"https://github.com/konn/linear-extra.git","tag":"032fd21d…","subdir":"linear-array-extra"}
  ```
  `location` + `tag` pin the repo and revision — `tag` is whatever was written in the
  `source-repository-package` stanza: a commit SHA, a git tag, or a branch name. `subdir` is the
  package's path **within** the repo (absent or `"."` → repo root). cabal checks the repo out
  under
  `{project-root}/dist-newstyle/src/` in a directory named from the repo plus a content hash
  (**not** the tag), so don't build the path — `Glob` for the `subdir`:
  ```
  {project-root}/dist-newstyle/src/*/<subdir>/**/*.hs
  ```
  (drop `/<subdir>` when it is absent), then `Read`. cabal also packs a source tarball
  `dist-newstyle/src/<checkout-dir>-<pkg>-<ver>.tar.gz` beside each checkout if you prefer
  `tar -xzOf` / `tar -tzf`.
  If the glob matches **more than one** checkout (the same repo pinned at several revisions lives
  in several `src/` dirs), pick the one actually built — resolve `tag` to a commit *inside that
  checkout* and compare to its HEAD, which handles `tag` being a SHA, tag, or branch:
  ```
  [ "$(git -C <checkout> rev-parse HEAD)" = "$(git -C <checkout> rev-parse "<tag>^{commit}")" ]
  ```
  The non-matching checkouts hold a different commit of the same repo.

### Script prints `null` / exits non-zero
The package is not in the cabal store and is not a local package — most often a **GHC boot
library** (`base`, `ghc-prim`, `containers`, `template-haskell`, …). Its docs ship with the
compiler, not the store. Get the dir from the project's compiler:
```
ghc-pkg-<ver> field <pkg> haddock-html
```
Derive `<ver>` and the binary's location from `cabal path --output-format=json`
(`.compiler.id` is `ghc-<ver>`; `.compiler.path` is the `ghc-<ver>` binary, so its sibling
`ghc-pkg-<ver>` is the right `ghc-pkg`). The reported dir contains `index.html` and the
per-module pages.

(Local packages resolve normally now — see the `{"type":"local",…}` `source` form above.)

### Package outside the dependency set
- Docs: `WebFetch https://hackage.haskell.org/package/<pkg>` (module page:
  `/<pkg>-<ver>/docs/<Dotted-As-Dashes-Module>.html`).
- Prefer `/hoogle:search` for symbol/type lookup before fetching full pages.

## Notes
- If `doc_dir` is `null` for a real dependency, the likely cause is that `documentation: True`
  was not set or `cabal build all` has not run since the dependency was added — redo the setup
  steps, then re-run the resolver.
- If `doc_dir` is `null` for a **local package**, its Haddock simply hasn't been generated yet —
  `cabal build` does **not** produce local docs. Run `cabal haddock <pkg>` (or `cabal haddock all`),
  then re-run the resolver. The source is still readable from `source.path` regardless.
