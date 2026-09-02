#import "vocabulary.typ": *

= Composing a system <ch:guides>

The parts divide by what they do to an archive, so the shape of a system follows
from which of those you need.

== What each part is <sec:parts>

#item("RankeDB")[
  The server. One instance serves one #gls("ranke-archive") from one
  configuration file, over REST. It owns the #gls("sequencer") — the mechanism
  that verifies a #gls("contribution"), persists it, and advances the head — and
  the account roster that decides who may do what.
  #dref[the RankeDB manual, at #link("/docs/rankedb/")[/docs/rankedb/]]
]

#item("Ranke-Go")[
  The reference implementation, as a Go library: the claim construction rules,
  #gls("verify"), and the query language. A program that builds claims or checks
  a #gls("closure") without running a server links this.
]

#item("Ranke-TS")[
  The TypeScript client, for browsers and for worker agents that reach an
  instance over its REST surface rather than in process.
]

#item("Ranke-Tools")[
  Command-line tools over an archive. `ranke-git` is the first of them.
]

#todo[Ranke-Go, Ranke-TS and Ranke-Tools have no manual in this section yet.
Each gains one when its repository publishes a docs tree, and the importer
already watches for it.]

== The usual shape <sec:shape>

One instance holds the archive. Everything else talks to it:

#listing[
```
  writers                     RankeDB                 readers
  ───────                     ───────                 ───────
  capture tools  ──REST──▶  sequencer  ◀──REST──  browser (Ranke-TS)
  agents         ──REST──▶  storage    ◀──REST──  agents
  programs (Ranke-Go, in process)
```
]

A writer opens a #gls("contribution") against a #gls("base") — the head id and a
stamped time — and the sequencer either merges the whole set or none of it. A
reader asks for a claim, or for a #gls("closure"), or for a filtered path across
one. Because every answer is content-addressed, a reader can check what it was
given without trusting the instance that gave it.

#note[
  An instance is configured once, at launch, and never reconfigured while it
  runs. The administrative cycle is edit, run, observe, stop, edit again — so
  two configurations are two processes.
]

== Choosing storage <sec:storage>

The archive rests on a #gls("blob-store"), and which one is the main decision in
a deployment. RankeDB names several, and composes them: `stack` layers one over
another and `partition` sends different content to different stores.

#item("A laptop or a test")[`mem` or `fs`. Nothing to run beside the server.]

#item("One machine, kept")[`fs` or `sqlite`, backed up like any other file.]

#item("Shared, or large")[`s3` for the bytes, with a faster store stacked in
front of it.]

The manual states what each adapter takes, field by field.
#dref[RankeDB, #emph[The ports the server drives]]

== Identity and access <sec:access>

Two separate questions, and they are answered in different places. The `signer`
section says which identity merges are attested under — that is what a reader
checks a signature against. The account roster says who may act on the archive
at all, as grants that can be attenuated rather than as roles.

#warning[
  A grant is about reaching the instance. It is not a claim about the archive's
  contents: the graph records who contributed what, and no configuration change
  rewrites that.
]

== Where to start <sec:start>

#example(title: "a first archive")[
  Install the RankeDB binary, write a configuration with `fs` storage and one
  account, run `ranke-db verify config.json`, then `ranke-db run config.json`.
  The manual's first chapter is that walk, in full.
]

#todo[A tutorial that carries the reader from an empty archive to a queried one
belongs here. It waits on the clients having manuals of their own, so that it can
end somewhere rather than stopping at the REST surface.]
