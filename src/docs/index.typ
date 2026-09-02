// docs/index.typ — the root of this repository's own documentation tree.
//
// The Ranke Documentation Format binds this site as a chapter author as well as
// a backend: these chapters are written with the same constructs as a part's
// manual and built by the same step. `vocabulary.typ` and `handbook.typ` are
// placed by the build (G-SUPPLIED) and gitignored.

#import "handbook.typ": *
#import "vocabulary.typ": *

#show: handbook.with(
  title: "Concepts",
  subtitle: [What a Ranke-Graph is, and how a system is composed from the parts
             that serve one],
  date: "2026-09-01",
)

The part manuals tell you how to configure and run each piece. This document is
what sits above them: what the data structure is, what provenance means here,
and how a server, a library and a client compose into something you can run.

Read it before the manuals if the model is new to you, and skip to the manuals
if it is not. Every term links to the #link("/docs/glossary/")[glossary], which
is the vocabulary the papers, the specification and every manual share.

#part[Part I — Concepts]

#include "01-concepts.typ"

#part[Part II — Guides]

#include "02-guides.typ"
