# Ranke-Graph — the website.
#
# Usage:
#   make             # the quality gate
#   make help        # list every target with a one-line description
#   make dev         # read the site at http://localhost:1313, rebuilding as you edit
#   make release     # make release <major|minor|patch>
#
# `make help` reads this file: a target followed by `## text` is listed under
# the nearest `##@ heading` above it.
#
# WHAT BUILDS THE SITE. Hugo assembles the pages; typst compiles the Typst
# sources of the documentation section into content Hugo mounts. Both are pinned
# in src/data/tools.json and fetched by scripts/get-tool.sh, so a fresh checkout
# needs nothing installed.
#
# WHERE THINGS ARE. src/ is everything written by hand — content, layouts,
# static files, data, the Typst backend and this repository's own chapters.
# vendor/ is what other repositories published and this one imported. dist/ is
# the site, and .cache/ is what the build needed on the way. Nothing generated
# is committed.
#
# Nothing here deploys. What is produced is dist/, and `site-bundle` packs that
# into the pair a release publishes; the host fetches it from GitHub and unpacks
# it itself.

SCRIPTS := src/scripts
CHECK   := python3 $(SCRIPTS)/check-site.py
HUGO     = $$($(SCRIPTS)/get-tool.sh hugo)

# brokkr comes from `make tools`, the same install a contributor gets, so a
# runner and a workstation cannot drift. Where the environment already provides
# one there is nothing to fetch and nothing that can fail.
BROKKR_PROVIDED  := $(shell command -v brokkr 2>/dev/null)
BROKKR           := $(if $(BROKKR_PROVIDED),$(BROKKR_PROVIDED),bin/tools/brokkr)
BROKKR_INSTALLER := https://raw.githubusercontent.com/flocko-motion/sindri/master/scripts/install-brokkr.sh

# The release cycle is ranke-graph's, fetched rather than copied. The git
# mechanics of a release — branch resolution, the merge-then-tag dance, the wait
# for CI — are written once there and serve every consumer, so a fix reaches this
# repository by being fetched. bin/ is gitignored: the script is infrastructure,
# never vendored, so this repository cannot drift from the shared one.
RANKE_GRAPH_REF    ?= main
RELEASE_CYCLER     := bin/release-cycle.sh
RELEASE_CYCLER_URL ?= https://raw.githubusercontent.com/rankegraph/ranke-graph/$(RANKE_GRAPH_REF)/scripts/release-cycle.sh

# What the built site says it was built from. A release passes the tag it is
# cutting (SITE_VERSION=v1.2.3); every other build derives one from git, so a
# page states the commit behind it rather than claiming a release.
#
# --always because a checkout with no tags still has to yield something: CI
# clones one commit deep and fetches none, so `git describe` has nothing to
# describe against and falls back to the abbreviated hash.
SITE_VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo unknown)

# What a release publishes, and what the host fetches from GitHub. The siblings
# stage their assets in dist/; here dist/ IS the site, so an asset staged there
# would end up publishing itself. release/ is that staging area.
SITE_BUNDLE_NAME := site
SITE_BUNDLE      := release/$(SITE_BUNDLE_NAME).tar.gz
SITE_BUNDLE_SUM  := $(SITE_BUNDLE).sha256

.PHONY: help all verify check pages links classes lint links-external docs-check tools \
        site dev docs upgrade place clean \
        site-bundle check-clean-tree check-release-bump \
        release major minor patch breaking feature fix

##@ Checks

all: check ## Default: the quality gate

# What the hub runs before anything merges (.sindri/config.yaml names it), and
# what `release` runs before it tags.
check: tools lint docs-check site pages links classes ## The whole gate
	@echo "check: the trees compile, the pages are consistent, every link resolves."

verify: check ## Alias of check, for the habit of typing either

pages: site ## Every page carries the head the others carry, and its tags close
	@$(CHECK) pages

links: site ## Every local link, asset reference and fragment resolves
	@$(CHECK) links

classes: site ## Every class a page uses has a rule, and every rule has a user
	@$(CHECK) classes

docs-check: ## The construct contract, the reference tree, and the tools' own tests
	@$(SCRIPTS)/check-docs.sh

# pipefail is what makes a failed download fail here: without it bash reads an
# empty script, exits 0, and the missing binary surfaces one target later as a
# puzzle.
tools: ## Name what the build needs and does not fetch, and install brokkr
	@$(SCRIPTS)/check-tools.sh
ifneq ($(BROKKR_PROVIDED),)
	@echo "brokkr provided by the environment: $(BROKKR_PROVIDED)"
else
	@bash -o pipefail -c 'curl -fsSL $(BROKKR_INSTALLER) | bash -s -- $(BROKKR)'
endif

lint: tools ## brokkr's static analysis over whatever this repo holds
	@$(BROKKR) lint

# OUT OF `check` ON PURPOSE. These need the network and fail for reasons outside
# this repository — a rate limit, somebody else's outage, a release asset renamed
# upstream. A gate that depends on that stops meaning anything.
links-external: site ## Check outbound links (needs the network; not part of check)
	@$(CHECK) external

##@ The site

# --cleanDestinationDir, because a page that is renamed otherwise leaves its old
# URL in dist/ serving what it used to say.
#
# `| place` is order-only: the files place writes are gitignored, so a fresh
# checkout — a clone, or CI's own — has vendor/ committed and the typst roots
# empty, and build-docs.sh dies on a missing handbook.typ. Placing first makes a
# checkout build. It only copies, so running it every time costs nothing.
site: | place ## Build the whole site into dist/
	@$(SCRIPTS)/build-docs.sh
	@HUGO_PARAMS_VERSION='$(SITE_VERSION)' $(HUGO) --quiet --cleanDestinationDir
	@echo ">> dist/ — $$(find dist -type f | wc -l) file(s), built from $(SITE_VERSION)"

dev: ## Build, then serve at http://localhost:1313 and rebuild as you edit
	@$(SCRIPTS)/build-docs.sh
	@HUGO_PARAMS_VERSION='$(SITE_VERSION)' $(HUGO) server

##@ Documentation

# The section is compiled from the Typst sources each part repository publishes
# with its releases. src/data/parts.json says which release; the trees it fetches
# are committed, so a checkout builds the site that is live rather than nothing.

docs: ## Import every part at the release src/data/parts.json pins
	@$(SCRIPTS)/fetch-docs.sh

upgrade: ## Move every pin to its newest release and import it
	@$(SCRIPTS)/fetch-docs.sh --update

place: ## Write the supplied files into every typst root. No network
	@$(SCRIPTS)/fetch-docs.sh --place

clean: ## Remove everything a build produced, keeping the fetched tools
	@rm -rf dist release .cache/content .cache/typst
	@echo ">> removed dist/, release/ and the build's intermediates"

##@ Release

# What a release carries: the built site, whole, at one version, and a checksum
# beside it so a deploy can verify what it downloaded before it serves it.
#
# The site is tarred from INSIDE dist/, so index.html is a top-level member and
# a deploy unpacks straight into its docroot:
#
#   tar -xzf site.tar.gz -C <docroot>
#
# Named members rather than `tar -C dist . `, because that spells every entry
# ./index.html, and the listener that receives this reads the member names and
# refuses an archive without index.html among them. `ls -A` is what keeps a
# dotfile in the bundle while leaving . and .. out of it.
#
# The sum is written from inside release/, so the name in it carries no path and
# `sha256sum -c site.tar.gz.sha256` works wherever the two files sit together.
site-bundle: site ## Pack the built site as release/site.tar.gz, with its .sha256
	@rm -rf release && mkdir -p release
	@tar -C dist -czf $(SITE_BUNDLE) $$(ls -A dist)
	@tar -tzf $(SITE_BUNDLE) | grep -qx 'index.html' || \
		{ echo "$(SITE_BUNDLE): no index.html at the archive root" >&2; exit 1; }
	@cd release && sha256sum $(SITE_BUNDLE_NAME).tar.gz > $(SITE_BUNDLE_NAME).tar.gz.sha256
	@echo ">> wrote $(SITE_BUNDLE) — $$(tar -tzf $(SITE_BUNDLE) | grep -cv '/$$') file(s), index.html at its root"
	@echo ">> wrote $(SITE_BUNDLE_SUM) — $$(cut -d' ' -f1 $(SITE_BUNDLE_SUM))"

# check-clean-tree and check-release-bump run ahead of check, because both are
# free and instant and check is a whole build. A dirty tree or a missing bump
# word should not cost one first. release-cycle.sh validates the bump word too,
# but only once check has already run.
check-clean-tree:
	@[ -z "$$(git status --porcelain)" ] || { echo "working tree is dirty — commit or stash before releasing" >&2; exit 1; }

check-release-bump:
	@[ -n "$(filter major minor patch breaking feature fix,$(MAKECMDGOALS))" ] || \
		{ echo "usage: make release <major|breaking | minor|feature | patch|fix>" >&2; exit 1; }

# Nothing here differs from another consumer: no scripts/release-next-version.sh,
# no scripts/release-pretag.sh, no scripts/release-feature-branch-only. So this
# repository's release is exactly the shared cycle. A changelog is the one thing
# a sibling stamps and this does not — the site publishes no artifact a reader
# depends on, so the git log is the record.
release: check-clean-tree check-release-bump check $(RELEASE_CYCLER) ## make release <major|minor|patch> — check, merge to the default branch, tag, push
	@$(RELEASE_CYCLER) $(filter major minor patch breaking feature fix,$(MAKECMDGOALS))

# Absorb the positional bump word so it is not read as a missing target.
major minor patch breaking feature fix:
	@:

# A file target with no prerequisite, so a cached copy is never re-fetched on its
# own. Deleting bin/ is what asks for a fresh one.
$(RELEASE_CYCLER): ## Cache release-cycle.sh from ranke-graph (bin/ is gitignored — infra, never vendored)
	@mkdir -p $(dir $(RELEASE_CYCLER))
	@curl -fsSL $(RELEASE_CYCLER_URL) -o $(RELEASE_CYCLER)
	@chmod +x $(RELEASE_CYCLER)

##@ Help

# Reads this file rather than a written list, so a target and its description
# travel together and the listing cannot drift from the rules.
help: ## List these targets
	@awk 'BEGIN { FS = ":.*##" } \
	     /^##@/               { printf "\n%s\n", substr($$0, 5); next } \
	     /^[a-z0-9_.-]+:.*##/ { printf "  %-16s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""
