#!/usr/bin/env bash
# The documentation half of `make check`: what only the Typst side can be wrong
# about. scripts/check-site.py checks the pages this produces and brokkr checks
# the code; what is here is the contract and the trees behind them.
#
# The construct contract is checked by compiling it, in the language that owns
# the format — src/typst/check-backend.typ reads shared/constructs.typ itself
# rather than this script reading it a second way.

set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$root"

fails=0
bad() { echo "  FAIL $*" >&2; fails=$((fails + 1)); }
ok()  { echo "  ok   $*"; }

typst=$(./src/scripts/get-tool.sh typst)
./src/scripts/fetch-docs.sh --place > /dev/null

# Under .cache, where the build already writes, rather than a system temp
# directory: the outputs are then inspectable after a failure, and there is one
# less thing about the environment for a check to depend on.
out=.cache/check
rm -rf "$out"
mkdir -p "$out"

echo "== the tools"
if go test -C src/tools ./... > "$out/test" 2>&1; then
	ok "go test"
else
	bad "go test: $(grep -m3 -E '^(---|\s+main_test)' "$out/test" | tr '\n' ' ')"
fi

echo "== the construct contract"
if "$typst" compile --root vendor/example --package-path vendor/typst-packages \
	vendor/example/typst/check-backend.typ "$out/contract.pdf" 2>"$out/err"; then
	ok "every name in common + manual is bound, and no print-only one is"
else
	bad "check-backend.typ: $(tr '\n' ' ' < "$out/err")"
fi

# The reference tree calls every construct once, so it catches one that renders
# to nothing here rather than in a reader's page. It is a fixture rather than a
# page of the book, which is why the site build leaves it out.
echo "== the trees"
if "$typst" compile --features html --format html --root vendor/example \
	--package-path vendor/typst-packages --input version=dev \
	vendor/example/docs/index.typ "$out/example.html" 2>"$out/err"; then
	if grep -q 'base64' "$out/example.html"; then
		bad "the reference tree inlines an image as base64"
	else
		ok "the reference tree compiles, with every construct called once"
	fi
else
	bad "the reference tree: $(tr '\n' ' ' < "$out/err")"
fi

echo
if [ "$fails" -gt 0 ]; then
	echo "FAIL: $fails check(s)" >&2
	exit 1
fi
echo "OK"
