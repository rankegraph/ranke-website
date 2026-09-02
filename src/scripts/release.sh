#!/usr/bin/env bash
# Cut a release as a self-contained cycle: ensure the tree is clean; (if on a
# feature branch) push it, open and merge a PR into the default branch so the
# tag points at MERGED code; tag the merged tip; push the tag; then return to
# the branch you started on. It never leaves you on — or commits directly to —
# the default branch: you release from it, you do not push to it.
#
# The same shape as the sibling repos, minus the changelog stamping. This
# repository publishes no artifact a reader depends on, so there is nothing for
# a changelog entry to be about; the git log is the record.
#
# WHAT A TAG DOES NOT DO YET: nothing deploys on it. How src/ reaches the host
# is unwired here — there is no workflow in this repository, and Pages cannot
# serve a subdirectory on its own. Until that is settled, a tag marks a state
# rather than publishing one, and the script says so when it finishes.
#
# Usage: make release <major|minor|patch>   (aliases: breaking|feature|fix)
#   Needs `gh` when run from a feature branch.
set -euo pipefail

bump="${1:-}"
case "$bump" in
	major | breaking) bump=major ;; # a reorganisation a reader would notice
	minor | feature)  bump=minor ;; # new pages or sections
	patch | fix)      bump=patch ;; # corrections to what is there
	*)
		echo "usage: make release <major|breaking | minor|feature | patch|fix>" >&2
		exit 1
		;;
esac

# 1. Clean tree — a release must capture a committed state.
if [ -n "$(git status --porcelain)" ]; then
	echo "working tree is dirty — commit or stash before releasing" >&2
	exit 1
fi

git fetch --tags --force origin >/dev/null 2>&1 || true

# 2. The version this run cuts, bumped from the latest release tag and ignoring
#    non-semver and prerelease tags.
# `|| true`: with no tags at all, grep matches nothing and exits 1, which under
# pipefail would abort the assignment before the `:-v0.0.0` fallback applies.
latest="$(git tag --list 'v*' --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -n1 || true)"
latest="${latest:-v0.0.0}"
IFS=. read -r maj min pat <<<"${latest#v}"
case "$bump" in
	major) maj=$((maj + 1)); min=0; pat=0 ;;
	minor) min=$((min + 1)); pat=0 ;;
	patch) pat=$((pat + 1)) ;;
esac
next="v${maj}.${min}.${pat}"

default="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')"
default="${default:-main}"
start="$(git rev-parse --abbrev-ref HEAD)"

echo ">> releasing $latest → $next from $start"

# 3. Reach the default branch with the work on it. From a feature branch that
#    means a PR, so the tag names a commit that went through review; from the
#    default branch itself there is nothing to merge.
if [ "$start" != "$default" ]; then
	command -v gh >/dev/null 2>&1 || { echo "gh not found — needed to merge $start into $default" >&2; exit 1; }
	git push -u origin "$start"
	gh pr create --base "$default" --head "$start" \
		--title "release $next" \
		--body "Cut $next from \`$start\`." >/dev/null 2>&1 || true
	gh pr merge "$start" --squash --delete-branch=false
fi

git checkout -q "$default"
git pull --ff-only origin "$default"

# 4. Tag the merged tip and push the tag.
git tag -a "$next" -m "$next"
git push origin "$next"

# 5. Back where you started, so releasing does not move you.
git checkout -q "$start" 2>/dev/null || true

echo ""
echo ">> tagged $next on $default"
echo "   Nothing deploys on this tag yet: the path from src/ to the host is"
echo "   unwired in this repository. Publish by whatever means the site"
echo "   currently uses."
