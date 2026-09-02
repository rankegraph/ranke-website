#import "vocabulary.typ": *

= The model <ch:concepts>

A #gls("ranke-graph") is a Merkle DAG of attributed claims. Everything else in
the series follows from that sentence, so it is worth taking apart.

== A claim, and what makes it one <sec:claim>

#concept("Claim")[
  A #gls("node") together with its content and its edges: the atom of the graph,
  written in one atomic transaction and addressed by its #gls("id").
]

A #gls("claim") carries a #gls("type"), an encoding, a creation time, a
#gls("height"), its content, and its #glspl("edge"). An #gls("edge") is a typed
link from the claim that owns it to the claim it points at, which is that edge's
#gls("reference").

The #gls("id") is not a name somebody chose. It is $op("id")(v) = H(S("env"(v)))$
— the hash of the #gls("envelope") the archive stores, which is the claim's
canonical bytes paired with the signature over them. Two consequences follow, and
they are the whole reason for the construction:

#item("identity is content")[
  Recomputing the id from the stored bytes either gives you the same id or tells
  you the bytes changed. Nothing has to be trusted to check it.
]

#item("authorship travels with the claim")[
  The signature is inside the bytes the id is taken over, so it cannot be
  detached from what it attests.
]

#note[
  #gls("height") is the longest path from a claim down its references, and an
  #gls("initial-claim") carries zero. It rises strictly along every reference,
  so a set of claims bounded by height is closed under references — which is
  what makes a bounded read a complete one.
]

== Closures, and why reads are shaped like them <sec:closure>

#concept("Closure")[
  The transitive set of claims reachable from a claim by following its edges to
  their references.
]

A single claim is rarely the answer to a question. What a reader wants is the
claim and everything it stands on, which is its #gls("closure"). Because every
edge points at a content address, a closure is exactly reproducible: fetch it
twice, from two archives, and you have the same set or a detectable difference.

== Provenance is the type vocabulary <sec:provenance>

Provenance here is structure rather than metadata. Three node classes carry it:

#item("source/*")[An external data artifact captured into the graph — a
#gls("source").]

#item("entity/*")[An identifiable thing in the world — an #gls("entity").]

#item("derivation/*")[A claim built from other claims, together with the
provenance edges citing them — a #gls("derivation").]

A #gls("contributor") is the actor whose work brings a claim into the graph,
human or program or agent, and is deliberately distinct from an #gls("entity")
the graph describes. Asking where a statement came from is therefore a graph
traversal rather than a lookup in a side table that can fall out of step.

== Archives, branches, and what is mutable <sec:archive>

#concept("Universe")[
  $cal(U)$, a content-addressed set holding #glspl("envelope") under their ids
  and externalised content under its hash. It is monotone: entries accumulate
  and never change.
]

A #gls("ranke-archive") is a pair — the #gls("universe") and one head id — where
the head is a #gls("branch-table") claim indexing the archive's #glspl("branch").
Adding to an archive yields a new pair rather than changing the old one, so
"the archive at 09:00" stays meaningful after 09:01.

#warning[
  The only thing that moves is which head id is current. Claims never change, so
  a reader holding an id holds it for good; a reader holding a branch name holds
  a question whose answer changes.
]

== Validity and verification <sec:verify>

#gls("valid") is a structural property: the #gls("id") recomputes, references
resolve, the construction rules hold. It says nothing about whether the content
is true, which is a judgement no data structure can make.

#gls("verify") is checking that property across a graph, recomputing each id and
confirming the rules. Integrity and authenticity fall out of the same pass.
#gls("anchoring") is the separate act of witnessing a head externally, an RFC
3161 timestamp among the options, which fixes a closure in time for anyone who
did not see it happen.

#dref[the foundation paper, for the definitions and the proofs behind them]
