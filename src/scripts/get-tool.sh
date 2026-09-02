#!/usr/bin/env bash
# Print the path of a pinned tool, fetching it into .cache/bin/ if there is none.
#
# The site is built by two binaries it does not carry: typst compiles the Typst
# sources and hugo assembles the pages. Both are pinned — a minor typst lays a
# document out its own way, and a Hugo release changes template lookup — so
# "whatever is installed" is not an answer, and a fresh checkout should not have
# to be prepared by hand either.
#
#   get-tool.sh typst    the version src/data/tools.json names
#   get-tool.sh hugo

set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$root"

tool="${1:-}"
[ -n "$tool" ] || { echo "get-tool: which tool? typst or hugo" >&2; exit 2; }

want=$(jq -r --arg t "$tool" '.[$t] // empty' src/data/tools.json)
[ -n "$want" ] || { echo "get-tool: src/data/tools.json pins no $tool" >&2; exit 1; }

# typst answers --version, hugo answers version; ask both rather than remember.
installed() {
	{ "$1" version 2>/dev/null || "$1" --version 2>/dev/null; } \
		| grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1
}

# typst is held to its series, since a patch release renders the same page; hugo
# is held exactly, because template lookup has changed within a minor before.
matches() {
	local have; have=$(installed "$1") || return 1
	case "$tool" in
		typst) [ "${have%.*}" = "${want%.*}" ] ;;
		*)     [ "$have" = "$want" ] ;;
	esac
}

for candidate in "$tool" ".cache/bin/$tool"; do
	if command -v "$candidate" > /dev/null 2>&1 && matches "$candidate"; then
		command -v "$candidate"
		exit 0
	fi
done

case "$(uname -s)-$(uname -m)" in
	Linux-x86_64)  typst_target=x86_64-unknown-linux-musl; hugo_target=linux-amd64 ;;
	Linux-aarch64) typst_target=aarch64-unknown-linux-musl; hugo_target=linux-arm64 ;;
	Darwin-arm64)  typst_target=aarch64-apple-darwin; hugo_target=darwin-universal ;;
	Darwin-x86_64) typst_target=x86_64-apple-darwin; hugo_target=darwin-universal ;;
	*) echo "get-tool: no build known for $(uname -s)-$(uname -m) — install $tool $want yourself" >&2; exit 1 ;;
esac

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
echo ">> fetching $tool $want" >&2
case "$tool" in
	typst)
		curl -fsSL --retry 2 -m 300 -o "$tmp/t.tar.xz" \
			"https://github.com/typst/typst/releases/download/v$want/typst-$typst_target.tar.xz"
		tar -xf "$tmp/t.tar.xz" -C "$tmp"
		mkdir -p .cache/bin && mv "$tmp/typst-$typst_target/typst" .cache/bin/typst
		;;
	hugo)
		curl -fsSL --retry 2 -m 300 -o "$tmp/h.tar.gz" \
			"https://github.com/gohugoio/hugo/releases/download/v$want/hugo_extended_${want}_${hugo_target}.tar.gz"
		tar -xzf "$tmp/h.tar.gz" -C "$tmp" hugo
		mkdir -p .cache/bin && mv "$tmp/hugo" .cache/bin/hugo
		;;
	*) echo "get-tool: no such tool '$tool'" >&2; exit 2 ;;
esac
chmod +x ".cache/bin/$tool"
matches ".cache/bin/$tool" || { echo "get-tool: .cache/bin/$tool is not $want" >&2; exit 1; }
echo "$root/.cache/bin/$tool"
