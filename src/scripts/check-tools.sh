#!/usr/bin/env bash
# Name what a build needs and does not fetch for itself, so a missing one says
# so rather than surfacing as an error from whatever reached for it first.
#
# typst and hugo are absent from this list on purpose: scripts/get-tool.sh
# fetches those at the pinned version. So is brokkr: `make tools` installs it
# right after this runs, which is what lets a runner reach the lint gate.

set -uo pipefail

missing=0
need() {
	if ! command -v "$1" > /dev/null 2>&1; then
		echo "  missing: $1 — $2" >&2
		missing=$((missing + 1))
	fi
}

need curl    "any package manager; the build fetches typst, hugo and the imports with it"
need tar     "any package manager"
need jq      "https://jqlang.github.io/jq/ — the manifests are JSON and the scripts read them"
need python3 "https://python.org — scripts/check-site.py checks the built pages"
need go      "https://go.dev/dl/ — src/tools builds the one adapter between typst and Hugo"

if [ "$missing" -gt 0 ]; then
	echo "check-tools: $missing tool(s) missing" >&2
	exit 1
fi
echo "tools ok — curl, tar, jq, python3, go"
