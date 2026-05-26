#!/usr/bin/env bash
# locate-dep.sh — resolve the local Haddock docs and source of a cabal dependency.
#
# Usage:   locate-dep.sh <package-name>
# Run from the project root (so `cabal` and dist-newstyle/cache/plan.json resolve).
#
# Regenerates the build plan, reads cabal's store/repo-cache paths, finds the package's
# UnitId in plan.json, and emits a JSON object on stdout:
#
#   {
#     "store_path": "<cabal store>/<UnitId>",          # always (the resolved unit dir)
#     "doc_dir":    "<store_path>/share/doc/html" | null, # Haddock HTML dir, if built
#     "source":     "<repo-cache>/.../<pkg>-<ver>.tar.gz" # Hackage/Stackage source tarball
#                 | { ...source-repo... }                 # source-repository-package metadata
#                 | { "type": "local", "path": "<dir>" }  # project's own (local) package source
#                 | null
#   }
#
# For a **local package** (one of the project's own packages, "pkg-src.type" == "local"),
# nothing lives in the cabal store. Instead the build/doc dir is reconstructed from plan.json's
# root "arch"/"os"/"compiler-id" fields plus the package name/version:
#
#   dist-newstyle/build/<arch>-<os>/<compiler-id>/<pkg>-<ver>
#
# `store_path` is that build dir, `doc_dir` is "<build-dir>/doc/html/<pkg>" (when Haddock has been
# generated — local docs require `cabal haddock`, not `cabal build`), and `source` is the local
# source tree from "pkg-src.path".
#
# Exits 1 with `null` on stdout when the package is not in the store (e.g. a GHC boot
# library such as `base`, which lives in the global package db, not the cabal store).
set -euo pipefail

PACKAGE="${1:-}"
if [[ -z "${PACKAGE}" ]]; then
  echo "usage: locate-dep.sh <package-name>" >&2
  exit 2
fi
for tool in cabal jq; do
  command -v "${tool}" >/dev/null 2>&1 || { echo "error: '${tool}' not found on PATH" >&2; exit 2; }
done

# First regenerate plan.json
cabal build -v0 --dry-run all

PLAN_JSON_FILE=dist-newstyle/cache/plan.json
QUERY=".\"install-plan\" | .[] | select(.\"pkg-name\" == \"${PACKAGE}\")"

declare -g COMPONENT=""

PLAN_JSON=$(jq -crM "${QUERY}" "${PLAN_JSON_FILE}")

# Local package? (one of the project's own packages — never in the cabal store)
FIRST_COMPONENT=$(head -n1 <<< "${PLAN_JSON}")
PKG_SRC_TYPE=$(jq -rcM '."pkg-src"."type" // empty' <<< "${FIRST_COMPONENT}")

if [[ "${PKG_SRC_TYPE}" == "local" ]]; then
  SRC_PATH=$(jq -rcM '."pkg-src"."path"' <<< "${FIRST_COMPONENT}")
  PKG_VERSION=$(jq -rcM '."pkg-version"' <<< "${FIRST_COMPONENT}")

  # Reconstruct the package build dir from plan.json's root arch/os/compiler-id fields:
  #   dist-newstyle/build/<arch>-<os>/<compiler-id>/<pkg>-<ver>
  ARCH=$(jq -rcM '.arch' "${PLAN_JSON_FILE}")
  OS=$(jq -rcM '.os' "${PLAN_JSON_FILE}")
  COMPILER_ID=$(jq -rcM '."compiler-id"' "${PLAN_JSON_FILE}")
  BUILD_DIR="${PWD}/dist-newstyle/build/${ARCH}-${OS}/${COMPILER_ID}/${PACKAGE}-${PKG_VERSION}"

  if [[ -d "${BUILD_DIR}" ]]; then
    STORE_PATH=$(jq -rcM --raw-input '@json' <<< "${BUILD_DIR}")
  else
    STORE_PATH="null"
  fi

  DOC_HTML_DIR="${BUILD_DIR}/doc/html/${PACKAGE}"
  if [[ -d "${DOC_HTML_DIR}" ]]; then
    DOC_DIR=$(jq -rcM --raw-input '@json' <<< "${DOC_HTML_DIR}")
  else
    DOC_DIR="null"
  fi

  SOURCE=$(jq -ncM --arg p "${SRC_PATH}" '{type: "local", path: $p}')

  jq -nrcM "{store_path: ${STORE_PATH}, doc_dir: ${DOC_DIR}, source: ${SOURCE}}"
  exit 0
fi

# Non-local: read cabal's store and repo-cache paths for the store lookup below.
PATH_JSON=$(cabal path --output-format=json)
STORE_DIR=$(jq -crM '.compiler | ."store-path"' <<< "${PATH_JSON}")
REMOTE_REPO_CACHE=$(jq -crM '."remote-repo-cache"' <<< "${PATH_JSON}")

while read -r CUR_COMPONENT; do
  ID=$(jq -rcM '.id' <<< "${CUR_COMPONENT}")
  CUR_PKG_STORE_PATH="${STORE_DIR}/${ID}"
  if [[ -d  "${CUR_PKG_STORE_PATH}" ]]; then
    COMPONENT="${CUR_COMPONENT}"
    break
  fi
done < <(echo "${PLAN_JSON}")

if [[ -z "${COMPONENT}" ]]; then
  echo "null"
  exit 1
fi

PKG_STORE_PATH="${STORE_DIR}/${ID}"
PKG_SRC=$(jq -rcM '."pkg-src"' <<< "${COMPONENT}")
PKG_VERSION=$(jq -rcM '."pkg-version"' <<< "${COMPONENT}")
PKG_TYPE=$(jq -rcM '."type"' <<< "${PKG_SRC}")

declare -g SOURCE=""

case "${PKG_TYPE}" in
  "repo-tar")
    URI=$(jq -rc '."repo"."uri"' <<< "${PKG_SRC}")
    # Extract hostname of URI as REPO_HOST
    REPO_HOST=$(echo "${URI}" | awk -F/ '{print $3}')
    SOURCE_TARBALL="${REMOTE_REPO_CACHE}/${REPO_HOST}/${PACKAGE}/${PKG_VERSION}/${PACKAGE}-${PKG_VERSION}.tar.gz"
    cabal fetch -v0 "${PACKAGE}-${PKG_VERSION}"
    if [[ -f "${SOURCE_TARBALL}" ]]; then
      SOURCE=$(jq -rcM --raw-input '@json' <<< "${SOURCE_TARBALL}")
    else
      SOURCE="null"
    fi
    ;;
  "source-repo")
    SOURCE=$(jq -rcM '."source-repo"' <<< "${PKG_SRC}")
    ;;
  *)
    SOURCE="null"
    ;;
esac

PKG_DOC_DIR="${PKG_STORE_PATH}/share/doc/html"
if [[ -d "${PKG_DOC_DIR}" ]]; then
  PKG_DOC_DIR=$(jq -rcM --raw-input '@json' <<< "${PKG_DOC_DIR}")
else
  PKG_DOC_DIR="null"
fi

PKG_STORE_PATH_ESCAPED="$(jq -rcM --raw-input '@json' <<< "${PKG_STORE_PATH}")"

jq -nrcM "{store_path: ${PKG_STORE_PATH_ESCAPED}, doc_dir: ${PKG_DOC_DIR}, source: ${SOURCE}}"
