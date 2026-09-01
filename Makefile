# Ranke-Graph — the website.
#
# Usage:
#   make             # the quality gate
#   make help        # list every target with a one-line description
#   make serve       # read the site at http://localhost:8000
#   make release     # make release <major|minor|patch>
#
# `make help` reads this file: a target followed by `## text` is listed under
# the nearest `##@ heading` above it.
#
# The site is hand-written HTML against one stylesheet — no framework, no
# JavaScript, and (so far) no build step. So the gate checks what a
# hand-written site can be wrong about: a page that drifts from the pattern the
# others follow, a link to a file that is not there, a class with no rule. When
# the docs section lands, its compile joins `check` here.

SRC   := src
CHECK := python3 scripts/check-site.py

.PHONY: help all verify check pages links classes lint links-external serve \
        release major minor patch breaking feature fix

##@ Checks

all: check ## Default: the quality gate

# What the hub runs before anything merges (.sindri/config.yaml names it), and
# what `release` runs before it tags. `check` is the outer gate here as it is in
# the sibling repos; they keep `verify` for an inner step, and this repository
# has only the one.
check: lint pages links classes ## The whole gate: brokkr, then the site's own checks
	@echo "check: pages consistent, links resolve, every class has a rule."

verify: check ## Alias of check, for the habit of typing either

pages: ## Every page carries the head the others carry, and its tags close
	@$(CHECK) pages

links: ## Every local link, asset reference and fragment resolves
	@$(CHECK) links

classes: ## Every class a page uses has a rule, and every rule has a user
	@$(CHECK) classes

# Runs whatever it finds: today it reports no Go and no shell, and starts
# checking scripts/ the moment one arrives.
lint: ## brokkr's static analysis over whatever this repo holds
	@brokkr lint

# OUT OF `check` ON PURPOSE. These need the network and fail for reasons
# outside this repository — a rate limit, somebody else's outage, a release
# asset renamed upstream. A gate that depends on that stops meaning anything.
# Run it when touching links, and before a release.
links-external: ## Check outbound links (needs the network; not part of check)
	@$(CHECK) external

##@ Working on it

serve: ## Serve src/ at http://localhost:8000
	@echo ">> http://localhost:8000 — Ctrl-C to stop"
	@python3 -m http.server -d $(SRC) 8000

##@ Release

# Same cycle as the sibling repos: verify, then merge to the default branch via
# a PR so the tag names merged code, tag it, push.
#
# WHAT A TAG DOES NOT DO YET: nothing deploys on it. How src/ reaches the host
# is unwired in this repo — there is no workflow here, and Pages cannot serve a
# subdirectory on its own. Until that is settled (task sd-aae040), a release
# marks a state rather than publishing one.
release: check ## make release <major|minor|patch> — check, merge to the default branch, tag, push
	@./scripts/release.sh $(filter major minor patch breaking feature fix,$(MAKECMDGOALS))

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
