# Changelog

What each release changed for someone who depends on this repository: the pages
the site publishes, the licences they are published under, and the anchors other
documents link to. A change earns an entry when it alters what the repo
requires, provides, or removes; rewording does not.

## Unreleased

**The landing page states where Ranke stops and where tooling begins.** The
hero is "Keeping today's records for tomorrow's tools": the archive is the
stage before an analysis system, and the material outlives whichever one is
chosen. It promises the
keeping — every record, structured and navigable, with everything it rests on
— and names the two ways an answer comes: a client traversing the graph in
place, or a scoped export handed to the analysis system of your choice. Two paragraphs under 'What Ranke does with it' spell
that boundary out: the archive stays behind both ways in, so a system adopted
next year, or one still to be written, starts from the whole record; and
choosing what goes into a cut is archive work the graph carries natively, since
a claim states what it rests on and the selection can be filed as a claim too.
The cards section returns to say what runs today, `ranke-git`, and what comes
next, further adapters and a generic filtered export. Release documentation
serves as the hero's example, and the sources named as
next are the ones an enterprise loses to a retention policy it does not
control: email and chat threads, issue trackers, build logs, and scan reports.
`/docs/getting-started/` names the same set.

**A page of neighbours compares the project against twenty systems, one at a
time.** `/neighbours.html` groups them by the tradition each comes from, version
control through databases, extracted knowledge graphs, supply-chain evidence,
incident forensics, preservation, content addressing and transparency logs, and answers
the same five questions about every one: what it is for, where it goes further
than Ranke, where Ranke goes further, how the two compose, and the terms it
comes on. The terms say whether a system is self-hosted or reached as a service,
whether its source is open, and what it costs, stated in full because a single
word would lose the truth: Datomic is closed source and free, since Nubank ships
the binaries under Apache 2.0 and not the source; Fluree's Business Source
Licence withholds only the hosted-service use, and for four years per version;
and C2PA is royalty-free to implement while a certificate that validates against
its trust list is priced by the issuing authority. Each entry states where the
other system is further along, and the page says once that the compositions are
design sketches, since `ranke-git` is the only adapter that exists. Twenty
project logos are committed under `src/static/assets/logos/` to identify the
projects they name.

**DeepLethe's Utopia is among the neighbours, at `#utopia`.** An Apache 2.0
bitemporal knowledge graph that extracts entities and facts from documents
against an editable ontology, holds provenance on every fact, corrects by
supersession rather than overwrite, and carries precision on each end of a
validity interval. It is the closest structural neighbour on the page, and the
entry says so: the foundation paper names Graphiti as the nearest because it was
written before Utopia existed. The section holding it and Zep is now "Extracted
knowledge graphs", since Utopia's own agent memory is a roadmap item and "agent
memory" described neither system's whole job.

**A section of the landing page indexes those systems by their logos.**
"Similar technologies" carries a short paragraph and a grid of marks, each
linking to the entry it names, in place of the sentence that carried the link
inside the prose above it. It sits between what Ranke does and the standards it
aligns with.

**Every entry on the neighbours page has an id, and a link naming one opens
it.** `#git`, `#fluree`, `#chainloop` and the rest address the entries. A
browser scrolls to a closed entry without opening it and CSS cannot open one, so
the page carries four lines of JavaScript, the first script this site ships, to
open the entry a link names. Without it the entry is reached and stays shut,
tinted by `.nb:target` so it can be found by eye.

**The standards the format aligns with are on the landing page.** W3C PROV-DM,
CASE and UCO, and EDTF sit between what Ranke does and where to go next, rather
than among the neighbours, where none of them was a neighbour.

**The site's licence is split in two.** `LICENSE` is CC BY 4.0, covering the
content and design, which is what the footer of every page states and what
ranke-graph publishes under. `LICENSE-CODE` is Apache 2.0, covering the Hugo
layouts, `src/scripts/`, `src/tools/` and `bin/`. `README.md` says which applies
where, and records that the logos fall under neither.

**The research page carries anchors, and every reference to the papers points at
one.** `#foundation`, `#rankedb`, `#unwritten` and `#specification` name the two
paper cards, the note on the three unwritten papers, and the normative
specification. References across the site now read "the foundation paper", the
name paper 02 and the specification use, in place of the shorthand "Paper 01".
