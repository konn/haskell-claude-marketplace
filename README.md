# Haskell Claude Tools

An opinionated, third-party [Claude Code](https://claude.com/claude-code) plugin marketplace for **Haskell
development**. It bundles a Language Server plugin, a local documentation/source reader, on-save
formatters for sources and cabal files, and an orchestrating "super-skill" that ties them together
into one cabal-native workflow.

Marketplace name: `konn-haskell-claude-tools`.

## What's inside

| Plugin | Provides | Invoke |
| --- | --- | --- |
| `haskell-lsp-plugin` | Haskell Language Server (HLS) — diagnostics, hover/types, go-to-definition, find-references, rename | LSP tools (automatic once installed) |
| `haskell-haddock-skill` | Read **local** Haddock HTML docs and package source for your cabal dependencies; falls back to Hackage for the rest | `/haddock <package> [module]` |
| `haskell-format-skill` | Format `.hs`/`.lhs`/`.hsig` sources with the project's formatter (fourmolu/ormolu/stylish-haskell); on-save hook formats automatically | `/haskell-format` |
| `haskell-cabal-gild-skill` | Format `.cabal`/`cabal.project` files with [cabal-gild](https://github.com/tfausak/cabal-gild); on-save hook formats automatically and refreshes `discover` module lists | `/haskell-cabal-gild` |
| `haskell-skill` | Orchestrating super-skill for cabal nix-style development; drives the LSP, Haddock, Hoogle, and the formatters | `/haskell` (or any Haskell dev task) |

The Hoogle search skills (`/hoogle:search`, `/hoogle:remote`) come from the external
[`claude-hoogle`](https://github.com/m4dc4p/claude-hoogle) marketplace, which `haskell-skill`
declares as a dependency.

## Requirements

- **Claude Code** with plugin support.
- **[haskell-language-server](https://haskell-language-server.readthedocs.io/)** — `haskell-language-server-wrapper` must be on your `PATH` (e.g. installed via [GHCup](https://www.haskell.org/ghcup/)) for `haskell-lsp-plugin`.
- **cabal ≥ 3.12** and GHC, used in nix-style (`cabal.project`) mode. `haskell-haddock-skill` relies on `cabal path` and `dist-newstyle/cache/plan.json`.
- For the formatting plugins (used by their on-save hooks): **[cabal-gild](https://github.com/tfausak/cabal-gild)** for `haskell-cabal-gild-skill`, and one of **[fourmolu](https://github.com/fourmolu/fourmolu)** / **[ormolu](https://github.com/tweag/ormolu)** / **[stylish-haskell](https://github.com/haskell/stylish-haskell)** for `haskell-format-skill`. If a tool isn't on your `PATH`, its hook quietly does nothing.
- The **[`claude-hoogle`](https://github.com/m4dc4p/claude-hoogle)** marketplace, for the Hoogle skills (see Installation).

## Installation

Add this marketplace, then install the plugin(s) you want:

```text
/plugin marketplace add https://github.com/konn/haskell-claude-marketplace
/plugin install haskell-skill@konn-haskell-claude-tools
```

`haskell-skill` depends on the `hoogle` plugin from another marketplace. Because Claude Code does
not silently pull plugins across marketplaces, **add `claude-hoogle` first** so the dependency can
resolve:

```text
/plugin marketplace add https://github.com/m4dc4p/claude-hoogle
/plugin install haskell-skill@konn-haskell-claude-tools
```

Install individual pieces instead if you prefer:

```text
/plugin install haskell-lsp-plugin@konn-haskell-claude-tools
/plugin install haskell-haddock-skill@konn-haskell-claude-tools
/plugin install haskell-format-skill@konn-haskell-claude-tools
/plugin install haskell-cabal-gild-skill@konn-haskell-claude-tools
```

## Using the tools

### `/haskell` — development workflow
The entry point for Haskell work. It treats `cabal.project` as the source of truth, works
package-by-package, formats before compiling (via `/haskell-format` and `/haskell-cabal-gild`),
prefers the LSP over a full `cabal build` for quick feedback, and prefers local documentation over
remote lookups. It delegates to `/haddock` and the Hoogle skills for API discovery.

### `/haddock` — local docs & source
Reads documentation and source for your project's dependencies from cabal's local store and
repo-cache, so you avoid hitting Hackage. One-time setup per project:

```sh
cabal configure --enable-documentation   # ensures `documentation: True`
cabal build all                           # materialises docs/source for dependencies
```

It then resolves each dependency through `cabal path` and the `UnitId` recorded in
`dist-newstyle/cache/plan.json` (cabal abbreviates package names in the store, so paths cannot be
guessed from the package name). Packages outside the dependency set fall back to
[Hackage](https://hackage.haskell.org).

### `/haskell-format` — format sources
Formats `.hs`/`.lhs`/`.hsig` with the project's formatter, chosen by config (`fourmolu.yaml` /
`.fourmolu.yaml` → fourmolu, `.stylish-haskell.yaml` → stylish-haskell) or the first of
fourmolu → ormolu → stylish-haskell found on `PATH`. An on-save hook runs it automatically whenever
such a file is written, so code stays formatted without an explicit call.

### `/haskell-cabal-gild` — format cabal & project files
Formats `.cabal` and `cabal.project*` files with [cabal-gild](https://github.com/tfausak/cabal-gild)
(`cabal-gild --io`). An on-save hook reformats these files when they're written and — when a
`.hs`/`.lhs`/`.hsig` file is saved — refreshes the nearest enclosing `.cabal` if it uses a
`-- cabal-gild: discover` pragma, keeping auto-generated module lists in sync as you add or remove
modules.

### `haskell-lsp-plugin` — language server
Launches `haskell-language-server-wrapper --lsp` for `.hs`, `.lhs`, `.hsig`, and `.cabal` files.
Once installed, Claude uses it automatically for type information and refactors.

## Development

This repository is itself a marketplace — see [`CLAUDE.md`](./CLAUDE.md) for the architecture and
the manifest conventions (`marketplace.json`, `plugin.json`, `.lsp.json`, `SKILL.md`). To test
changes locally, point Claude Code at your working copy:

```text
/plugin marketplace add /path/to/haskell-claude-marketplace
```

## Author

Hiromi Ishii ([@konn](https://github.com/konn))
