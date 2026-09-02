# rankegraph.org

The project's website, and the documentation section built from the Typst
sources each part repository publishes with its releases.

## Building it

```
make          # the quality gate
make site     # build the whole site into dist/
make dev      # build, then serve it and rebuild as you edit
make help     # every target, with a line each
```

Nothing needs installing first. Hugo assembles the pages and typst compiles the
documentation trees; both are pinned in `src/data/tools.json` and fetched into
`.cache/bin` by `src/scripts/get-tool.sh` when they are not already there.

## Where things are

| Path | What it holds |
| --- | --- |
| `src/content/` | the pages written here, as Hugo content |
| `src/layouts/` | the templates every page is poured into |
| `src/static/` | the stylesheet, the images, the CNAME |
| `src/data/` | the manifest of parts, what the import recorded, and the tool pins |
| `src/typst/` | the HTML rendering of the documentation constructs — this repository's backend |
| `src/docs/` | this repository's own chapters, written in the same format as a part's |
| `src/scripts/` | the import, the build and the checks |
| `src/tools/` | the one Go program: a compiled Typst document into a Hugo content file |
| `vendor/` | what other repositories published and this one imported |
| `dist/` | the site. Generated, and not committed |
| `.cache/` | what the build needed on the way. Generated, and not committed |

## The documentation section

Each part repository authors its manual, releases it as a tarball, and this
repository imports that tarball at a pinned release:

```
make docs      # import every part at the release src/data/parts.json pins
make upgrade   # move every pin to its newest release and import it
```

The imported trees are committed, so an upstream docs change arrives here as a
diff somebody reads, and a build needs no part repository to be reachable.

A tree is compiled by typst through the backend in `src/typst/`, which decides
what the HTML looks like: every heading carries an anchor made from its own
words, a diagram names its picture rather than inlining it, and a glossary term
links to `/docs/glossary/`. What comes out is a Hugo content file, and Hugo does
the rest — the shell, the navigation, the breadcrumb, previous and next.

The format those chapters are written in is the Ranke Documentation Format,
specified in ranke-graph's `docs-spec/`. This repository is bound by it twice
over: as the author of the HTML backend, and as the author of chapters of its
own.
