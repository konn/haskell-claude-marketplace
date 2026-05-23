# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

A third-party **Claude Code marketplace** for Haskell development. There is no application
or library to build here — the repository *is* a registry of Claude Code plugins and skills.
`.claude-plugin/marketplace.json` is the source of truth: each entry in its `plugins` array
points (via a relative `source`) at a plugin directory in this repo. The marketplace name is
`konn-haskell-claude-tools`.

The marketplace bundles tools that together cover an end-to-end Haskell workflow. Editing this
repo means editing JSON manifests and Markdown `SKILL.md` files, not Haskell source.

## Components and their status

| Path | Kind | Status | Role |
| --- | --- | --- | --- |
| `haskell-lsp-plugin/` | LSP plugin | **exists** | Launches `haskell-language-server-wrapper --lsp` for fast typecheck, symbol lookup, rename, diagnostics |
| `haskell-haddock-skill/` | skill plugin | **planned** | Read local Haddock HTML docs and package source for dependencies |
| `haskell-skill/` | skill plugin | **planned** | Orchestrating "super skill" that drives a full Haskell dev workflow |
| `haskell-cabal-gild-skill/` | skill plugin + hook | **exists** | `/haskell-cabal-gild`: format `.cabal`/`cabal.project` with cabal-gild; on-save hook reformats cabal files and refreshes `discover` module lists |
| `haskell-format-skill/` | skill plugin + hook | **exists** | `/haskell-format`: format `.hs`/`.lhs`/`.hsig` with fourmolu/ormolu/stylish-haskell; on-save hook formats sources |
| `claude-hoogle` (external) | dependency | external | Provides `hoogle:search` + `hoogle:remote`; lives at https://github.com/m4dc4p/claude-hoogle |

When you add a planned component, create it as a plugin directory at the repo root and register
it as a new object in `marketplace.json`'s `plugins` array (mirror the existing
`haskell-lsp-plugin` entry).

## How the components fit together

`haskell-skill` is the intended entry point. Its design delegates to the other tools rather than
reimplementing them, in this order of preference:

1. **`haskell-lsp-plugin` before a full build** — use the LSP for typecheck, go-to-definition,
   symbol search, and rename. Only fall back to `cabal build` when the LSP cannot answer.
2. **`haskell-haddock-skill` + `/hoogle:search` for API discovery** — look up signatures, docs,
   and source.
3. **Local information over remote** — read on-disk Haddock/source and use the local LSP before
   hitting Hackage or remote Hoogle, to avoid hammering Haskell's public infrastructure.

Core development principles the `haskell-skill` is meant to encode (relevant when authoring its
`SKILL.md`):
- Treat `cabal.project` and cabal **nix-style** builds as the source of truth.
- For multi-package projects, proceed **package by package**.
- Apply the formatter **before** compiling — `/haskell-format` for sources, `/haskell-cabal-gild`
  for `.cabal`/`cabal.project` files (both also run via on-save hooks).
- Prefer `(<>)` over `(++)`; run `hpack` after editing any `package.yaml`.

## haskell-haddock-skill: resolving local docs and source (the non-trivial part)

This skill maps a dependency to on-disk Haddock HTML or unpacked source. The intended algorithm:

1. Ensure docs are configured: `cabal.project.local` must have `documentation: True`
   (`cabal configure --enable-documentation` sets this).
2. Get cabal's critical paths via `cabal path`:
   - `compiler-store-path` — directory of HTML documentation for Hackage/Stackage packages.
   - `remote-repo-cache` — cache of source tarballs for Hackage/Stackage packages.
3. Run `cabal build all` once after any dependency change so the plan and store are populated.
4. Read `{project-root}/dist-newstyle/cache/plan.json` (build first if absent) to enumerate
   dependencies and their kind (Hackage, `source-repository-package`, etc.) and their `UnitId`.
5. Resolve per dependency:
   - **Hackage/Stackage**: combine the `UnitId` with `compiler-store-path` (HTML docs) or
     `remote-repo-cache` (source tarball) to locate files.
   - **Other kinds** (e.g. `source-repository-package`): find them under
     `{project-root}/dist-newstyle`.
   - **Outside the dependency set**: fall back to Hackage (https://hackage.haskell.org).

## File-format conventions

When authoring or editing manifests, follow these schemas (existing files are the reference):

- **`.claude-plugin/marketplace.json`** — top level: `name`, `owner.name`, `plugins[]`. Each plugin
  entry needs `name`, `description`, and `source` (here a relative path string like
  `"./haskell-lsp-plugin"`); optional `category`, `tags`, `author`, `version`. To let a plugin here
  depend on a plugin from another marketplace, list that marketplace in the top-level
  `allowCrossMarketplaceDependenciesOn` array (we allow `"claude-hoogle"`).
- **`<plugin>/.claude-plugin/plugin.json`** — `name` + `description` required; optional `version`,
  `author`, and `dependencies[]`. A dependency is a plugin name string, or
  `{ "name", "version"?, "marketplace"? }`; cross-marketplace deps require the target marketplace
  to be allowlisted in `marketplace.json` (see above). Example: `haskell-skill` depends on
  `{ "name": "hoogle", "marketplace": "claude-hoogle" }`, which provides `/hoogle:search` and
  `/hoogle:remote`.
- **`<plugin>/.lsp.json`** — language-server config: a map of language name → `{ command, args,
  extensionToLanguage }`. See `haskell-lsp-plugin/.lsp.json`.
- **`<plugin>/hooks/hooks.json`** — hook config (same schema as `settings.json`'s `hooks`): a
  top-level `hooks` object keyed by event (e.g. `PostToolUse`), each holding `[{ matcher, hooks:
  [{ type: "command", command, timeout? }] }]`. `matcher` is a pipe-separated tool-name pattern
  (e.g. `"Write|Edit|MultiEdit"`); reference plugin files via `${CLAUDE_PLUGIN_ROOT}`. A `command`
  hook reads the event JSON from stdin (e.g. `.tool_input.file_path`) and may print a JSON object
  with `hookSpecificOutput.additionalContext` to feed text back to Claude. See
  `haskell-cabal-gild-skill/hooks/hooks.json` and `haskell-format-skill/hooks/hooks.json`.
- **`<plugin>/skills/<name>/SKILL.md`** — YAML frontmatter (`name`, `description`; optional
  `allowed-tools`, `version`) followed by Markdown instructions. The `description` should state
  *when to trigger* and include trigger words, since it is what Claude matches against.

## Testing changes locally

Load this repo as a marketplace and install a plugin from it:

```
/plugin marketplace add /Users/hiromi/Documents/Programming/Haskell/git/haskell-claude-marketplace
/plugin install haskell-lsp-plugin@konn-haskell-claude-tools
```

Validate manifests are well-formed JSON before committing, e.g.:

```
cat .claude-plugin/marketplace.json | jq . >/dev/null
```
