# Ranke-Graph — the website.
#
# Usage:
#   make             # the quality gate
#   make help        # list every target with a one-line description
#   make serve       # read the site at http://localhost:1313, rebuilding as you edit
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
# Nothing here deploys. What is produced is dist/.

SCRIPTS := src/scripts
CHECK   := python3 $(SCRIPTS)/check-site.py
HUGO     = $$($(SCRIPTS)/get-tool.sh hugo)

.PHONY: help all verify check pages links classes lint links-external docs-check tools \
        site serve docs upgrade place clean \
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

tools: ## Name anything the build needs that is not installed
	@$(SCRIPTS)/check-tools.sh

lint: ## brokkr's static analysis over whatever this repo holds
	@brokkr lint

# OUT OF `check` ON PURPOSE. These need the network and fail for reasons outside
# this repository — a rate limit, somebody else's outage, a release asset renamed
# upstream. A gate that depends on that stops meaning anything.
links-external: site ## Check outbound links (needs the network; not part of check)
	@$(CHECK) external

##@ The site

# --cleanDestinationDir, because a page that is renamed otherwise leaves its old
# URL in dist/ serving what it used to say.
site: ## Build the whole site into dist/
	@$(SCRIPTS)/build-docs.sh
	@$(HUGO) --quiet --cleanDestinationDir
	@echo ">> dist/ — $$(find dist -type f | wc -l) file(s)"

serve: ## Build, then serve at http://localhost:1313 and rebuild as you edit
	@$(SCRIPTS)/build-docs.sh
	@$(HUGO) server

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
	@rm -rf dist .cache/content .cache/typst
	@echo ">> removed dist/ and the build's intermediates"

##@ Release

release: check ## make release <major|minor|patch> — check, merge to the default branch, tag, push
	@$(SCRIPTS)/release.sh $(filter major minor patch breaking feature fix,$(MAKECMDGOALS))

# Absorb the positional bump word so it is not read as a missing target.
major minor patch breaking feature fix:
	@:

##@ Help

# Reads this file rather than a written list, so a target and its description
# travel together and the listing cannot drift from the rules.
help: ## List these targets
	@awk 'BEGIN { FS = ":.*##" } \
	     /^##@/               { printf "\n%s\n", substr($$0, 5); next } \
	     /^[a-z0-9_.-]+:.*##/ { printf "  %-16s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""
