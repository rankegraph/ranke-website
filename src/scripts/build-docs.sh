#!/usr/bin/env bash
# Compile every Typst tree into Hugo content.
#
# One compile per tree, because typst resolves labels within a single compile —
# split a manual and every `@sec:` reference in it stops resolving. Each part is
# compiled from its own root, since G-ASSETS makes diagram paths project-
# absolute and two parts under one root would read /docs/assets/x.svg as one
# file.
#
# What comes out is a Hugo leaf bundle per tree, under .cache/content: index.html
# carrying the body and its front matter, with the tree's assets and its
# generated contract beside it as page resources, published under the page's own
# URL. Hugo mounts that directory, so nothing generated lands in src/.

set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$root"

manifest=src/data/parts.json
imported=src/data/imported.json
cache=.cache
content=$cache/content/docs
packages=vendor/typst-packages

typst=$(./src/scripts/get-tool.sh typst)
go build -C src/tools -o "$root/.cache/bin/typstpage" ./typstpage

rm -rf "$content"
mkdir -p "$cache/typst"

# One tree: compile it, then make a page of it.
page() {
	local slug=$1 source=$2 typst_root=$3 title=$4 weight=$5 description=$6
	shift 6
	local compiled="$cache/typst/$slug.html"
	mkdir -p "$(dirname "$compiled")"
	"$typst" compile --features html --format html --root "$typst_root" \
		--package-path "$packages" "$@" "$source" "$compiled"
	./.cache/bin/typstpage -in "$compiled" -out "$content/$slug/index.html" \
		-title "$title" -weight "$weight" -description "$description" "${extra[@]}"
	echo ">> $content/$slug/index.html"
}

# ── the chapters this site writes ────────────────────────────────────────────

extra=(-param kind=written -param meta="The model")
page concepts src/docs/index.typ src "Concepts" 50 \
	"What a Ranke-Graph is, what provenance means here, and how a server, a library and a client compose into a system you can run." \
	--input version=dev

extra=(-param kind=written -param meta=Reference)
framework_tag=$(jq -r '.framework.tag' "$manifest")
framework_repo=$(jq -r '.framework.repo' "$manifest")
page glossary src/typst/glossary.typ src "Glossary" 90 \
	"The vocabulary the papers, the specification and every manual share, defined once and linked from every chapter." \
	--input version="$framework_tag" \
	--input source="https://github.com/$framework_repo" \
	--input imported="$(date -u +%Y-%m-%d)"

# ── the imported manuals ─────────────────────────────────────────────────────

# G-VERSION: what a page says about its own provenance comes from the build that
# made it, never from the vendored source.
extra=()
while IFS=$'\t' read -r name title weight blurb; do
	tree="vendor/parts/$name"
	[ -f "$tree/docs/index.typ" ] || continue
	tag=$(jq -r --arg n "$name" '.[$n].tag' "$imported")
	when=$(jq -r --arg n "$name" '.[$n].imported' "$imported")
	repo=$(jq -r --arg n "$name" '.parts[] | select(.name == $n) | .repo' "$manifest")
	page "$name" "$tree/docs/index.typ" "$tree" "$title" "$weight" "$blurb" \
		--input version="$tag" \
		--input source="https://github.com/$repo" \
		--input imported="$when"

	# Page resources: what the chapters name, published under the page's URL.
	if [ -d "$tree/docs/assets" ]; then
		cp -R "$tree/docs/assets" "$content/$name/assets"
	fi
	if [ -f "$tree/docs/openapi/openapi.gen.yaml" ]; then
		cp "$tree/docs/openapi/openapi.gen.yaml" "$content/$name/openapi.gen.yaml"
		echo ">> $content/$name/openapi.gen.yaml"
	fi
done < <(jq -r '.parts | sort_by(.weight)[] | [.name, .title, .weight, .blurb] | @tsv' "$manifest")
