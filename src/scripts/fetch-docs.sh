#!/usr/bin/env bash
# Bring each part's authored documentation into vendor/, at the release
# src/data/parts.json pins, and place the two files its chapters import.
#
# The fetching itself is one curl and one tar per part: a part publishes what it
# authored as a release asset, and this unpacks it. Everything longer than that
# is marked WORKAROUND below and has a matching request on the feature — each
# exists because something upstream is not published, and each is deleted rather
# than improved when it is.
#
#   --update   move each pin to the newest release before fetching
#   --place    write the supplied files and touch nothing else. No network

set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$root"

manifest=src/data/parts.json
imported=src/data/imported.json
mode=fetch
case "${1:-}" in
	--update) mode=update ;;
	--place)  mode=place ;;
	"") ;;
	*) echo "fetch-docs: unknown argument '$1' — --update or --place" >&2; exit 2 ;;
esac

for tool in curl jq tar; do
	command -v "$tool" > /dev/null 2>&1 \
		|| { echo "fetch-docs: $tool is not installed, and this needs it" >&2; exit 1; }
done

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
today=$(date -u +%Y-%m-%d)
fail() { echo "fetch-docs: $*" >&2; exit 1; }
note() { echo ">> $*"; }

api() {
	local -a auth=()
	if [ -n "${GITHUB_TOKEN:-}" ]; then auth=(-H "Authorization: Bearer $GITHUB_TOKEN"); fi
	local code
	code=$(curl -sSL --retry 2 -m 60 -o "$2" -w '%{http_code}' \
		-H "Accept: application/vnd.github+json" "${auth[@]}" "$1" 2>/dev/null) || code=000
	case "$code" in
		200) return 0 ;;
		404) return 3 ;;
		403|429) fail "GitHub refused $1 (HTTP $code) — the unauthenticated limit is 60 an hour" ;;
		*) fail "GitHub answered HTTP $code for $1" ;;
	esac
}

# Replaced whole, so a chapter withdrawn upstream disappears here too. A part
# bundle drops the two supplied names; ranke-graph's shared/ authors both.
unpack() {
	local -a excludes=(--exclude='*/.*')
	if [ "${3:-part}" = part ]; then
		excludes+=(--exclude='*/vocabulary.typ' --exclude='*/handbook.typ')
	fi
	rm -rf "$2"
	mkdir -p "$2"
	tar -xzf "$1" -C "$2" --strip-components=1 "${excludes[@]}"
}

download() { curl -fsSL --retry 2 -m 300 -o "$2" "$1"; }

asset_url() { echo "https://github.com/$1/releases/download/$2/$3"; }

# ── the parts ────────────────────────────────────────────────────────────────

fetch_part() {
	local name repo tag asset
	name=$1 repo=$2 tag=$3 asset=$4
	if [ "$tag" = null ]; then
		note "$name: no docs release pinned yet"
		return 0
	fi
	download "$(asset_url "$repo" "$tag" "$asset")" "$tmp/$asset" \
		|| fail "$repo $tag attaches no $asset"
	unpack "$tmp/$asset" "vendor/parts/$name/docs"

	local released=""
	if api "https://api.github.com/repos/$repo/releases/tags/$tag" "$tmp/rel.json"; then
		released=$(jq -r '.published_at | split("T")[0]' "$tmp/rel.json")
	fi
	jq --arg n "$name" --arg t "$tag" --arg r "$released" --arg i "$today" \
		'.[$n] = {tag: $t, released: $r, imported: $i}' "$imported" > "$tmp/imported" \
		&& mv "$tmp/imported" "$imported"
	note "$name: $repo $tag → vendor/parts/$name/docs"
}

# ── the framework ────────────────────────────────────────────────────────────

fetch_framework() {
	local repo tag asset
	repo=$(jq -r '.framework.repo' "$manifest")
	tag=$(jq -r '.framework.tag' "$manifest")
	asset=$(jq -r '.framework.asset' "$manifest")
	download "$(asset_url "$repo" "$tag" "$asset")" "$tmp/framework.tar.gz" \
		|| fail "$repo $tag attaches no $asset"
	unpack "$tmp/framework.tar.gz" "$tmp/framework" framework
	# Flat, because every shared/ here is a copy the build placed and is
	# gitignored on that basis; a committed one would be swallowed by the rule.
	rm -rf vendor/framework
	mkdir -p vendor/framework
	cp -R "$tmp/framework/shared/." vendor/framework/
	note "framework: $repo $tag → vendor/framework"

	# WORKAROUND (upstream request 1): the tarball omits docs-spec/examples, so
	# the reference tree is taken file by file through the trees API.
	local path=docs-spec/examples/docs-tree
	api "https://api.github.com/repos/$repo/git/trees/$tag?recursive=1" "$tmp/tree.json" \
		|| fail "cannot list $repo at $tag"
	rm -rf vendor/example/docs
	local file
	while read -r file; do
		mkdir -p "vendor/example/docs/$(dirname "${file#"$path/"}")"
		download "https://raw.githubusercontent.com/$repo/$tag/$file" \
			"vendor/example/docs/${file#"$path/"}" || fail "cannot download $file"
	done < <(jq -r --arg p "$path/" '.tree[] | select(.type == "blob")
		| select(.path | startswith($p)) | .path' "$tmp/tree.json")
	# Its diagram paths name ranke-graph's own layout, which its header tells a
	# reader to update when copying the tree. `sed -i` differs on BSD, hence mv.
	local chapter
	for chapter in vendor/example/docs/*.typ; do
		sed "s|/$path/assets/|/docs/assets/|g" "$chapter" > "$tmp/chapter" \
			&& mv "$tmp/chapter" "$chapter"
	done
	note "fixture: $path at $tag → vendor/example/docs"
}

# WORKAROUND (upstream request 2): shared/glossary.typ imports glossarium at its
# top level, so reading the entries drags in a package no web backend calls.
fetch_packages() {
	local ns name version dest
	while read -r ns name version; do
		dest="vendor/typst-packages/$ns/$name/$version"
		[ -f "$dest/typst.toml" ] && { note "package $ns/$name:$version is present"; continue; }
		download "https://packages.typst.org/$ns/$name-$version.tar.gz" "$tmp/pkg.tar.gz" \
			|| fail "cannot download @$ns/$name:$version"
		rm -rf "$dest" && mkdir -p "$dest" && tar -xzf "$tmp/pkg.tar.gz" -C "$dest"
		note "package $ns/$name:$version"
	done < <(jq -r '.packages[] | "\(.namespace) \(.name) \(.version)"' "$manifest")
}

# ── the supplied files ───────────────────────────────────────────────────────

# The two names a chapter imports, pointed at this repository's rendering, plus
# the shared/ that rendering itself imports. Gitignored in every root.
place() {
	local dir name
	[ -d vendor/framework ] || fail "vendor/framework is missing — run \`make docs\` once with a network"
	for dir in vendor/parts/*/ vendor/example/ src; do
		[ -d "$dir/docs" ] || continue
		rm -rf "$dir/shared"
		mkdir -p "$dir/shared"
		cp -R vendor/framework/. "$dir/shared/"
		# src/typst is the backend itself, not a copy of it.
		if [ "$dir" != src ]; then
			rm -rf "$dir/typst"
			mkdir -p "$dir/typst"
			cp src/typst/vocabulary.typ src/typst/handbook.typ src/typst/check-backend.typ "$dir/typst/"
		fi
		for name in vocabulary handbook; do
			cat > "$dir/docs/$name.typ" <<-SHIM
				// Written by scripts/fetch-docs.sh. Edits here are overwritten.
				// The HTML rendering of the docs constructs; see typst/$name.typ.
				#import "/typst/$name.typ": *
			SHIM
		done
	done
	note "placed the supplied files in every typst root"
}

# ── --update ─────────────────────────────────────────────────────────────────

# Moves the pins in the manifest, so a bump is a line review sees.
bump() {
	local name repo tag newest
	while read -r name repo tag; do
		api "https://api.github.com/repos/$repo/releases/latest" "$tmp/rel.json" || continue
		newest=$(jq -r .tag_name "$tmp/rel.json")
		[ "$newest" = "$tag" ] && { note "$name: $tag is the newest release"; continue; }
		jq --arg n "$name" --arg t "$newest" \
			'(.parts[] | select(.name == $n) | .tag) = $t' "$manifest" > "$tmp/manifest" \
			&& mv "$tmp/manifest" "$manifest"
		note "$name: pinned ${tag/null/nothing} → $newest"
	done < <(jq -r '.parts[] | "\(.name) \(.repo) \(.tag)"' "$manifest")

	local repo tag newest
	repo=$(jq -r '.framework.repo' "$manifest")
	tag=$(jq -r '.framework.tag' "$manifest")
	if api "https://api.github.com/repos/$repo/releases/latest" "$tmp/rel.json"; then
		newest=$(jq -r .tag_name "$tmp/rel.json")
		if [ "$newest" != "$tag" ]; then
			jq --arg t "$newest" '.framework.tag = $t' "$manifest" > "$tmp/manifest" \
				&& mv "$tmp/manifest" "$manifest"
			note "framework: pinned $tag → $newest"
		else
			note "framework: $tag is the newest release"
		fi
	fi

	# WORKAROUND (upstream request 4): a part's typst version is only in its
	# Makefile, so this reads it there and reports a drift rather than moving it.
	local pin part
	part=$(jq -r '.parts[0].repo' "$manifest")
	tag=$(jq -r '.parts[0].tag' "$manifest")
	if [ "$tag" != null ] && download "https://raw.githubusercontent.com/$part/$tag/Makefile" "$tmp/mk"; then
		pin=$(sed -n 's/^TYPST_VERSION[[:space:]]*:=[[:space:]]*\([0-9][^[:space:]]*\).*/\1/p' "$tmp/mk" | head -1)
		if [ -n "$pin" ] && [ "$pin" != "$(jq -r .typst src/data/tools.json)" ]; then
			echo "   ! $part $tag builds with typst $pin; src/data/tools.json pins $(jq -r .typst src/data/tools.json)" >&2
		fi
	fi
}

# ── the run ──────────────────────────────────────────────────────────────────

[ -f "$imported" ] || echo '{}' > "$imported"

if [ "$mode" = place ]; then
	place
	exit 0
fi

[ "$mode" = update ] && bump
fetch_framework
fetch_packages
while read -r name repo tag asset; do
	fetch_part "$name" "$repo" "$tag" "$asset"
done < <(jq -r '.parts | sort_by(.weight)[] | "\(.name) \(.repo) \(.tag) \(.asset)"' "$manifest")
place
