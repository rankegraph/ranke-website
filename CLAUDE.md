# ranke-website — Agent Instructions

## Starting a session

A new session begins by learning the project, before any task:

1. Run `make docs` to import every documentation part at the release
   `src/data/parts.json` pins.
2. Read every file under `src/docs/` in full — whole files, top to bottom,
   with the Read tool rather than grep or sed excerpts. Depth of
   understanding is what the session runs on; reading shallowly costs more
   time than the reading saves.
3. Read the website itself: the pages under `src/content/`.

## Changelog

`CHANGELOG.md` records what each release changed for someone who depends on
this repository. A change earns an entry when it alters what the repo requires,
provides, or removes; rewording does not. Write the entry under `## Unreleased`
in the same change, and summarise: one entry per change that matters to a
reader, not a log of every edit it took to get there.

`make release <bump>` stamps that section with the version it cuts, leaves a
fresh `## Unreleased` behind, and commits it on the branch being released, so
a version heading is never written by hand. A release whose `## Unreleased`
section is empty is refused, since it would record nothing. The stamping lives
in ranke-graph's shared `release-cycle.sh`, which this repo caches under
`bin/`, and where `CHANGELOG.md` is missing the first release writes it.
