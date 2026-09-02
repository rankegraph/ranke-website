# Changelog

What each release changed for someone who depends on this repository: the pages
the site publishes, the licences they are published under, and the anchors other
documents link to. A change earns an entry when it alters what the repo
requires, provides, or removes; rewording does not.

## Unreleased

**A page of neighbours compares the project against nineteen systems, one at a
time.** `/neighbours.html` groups them by the tradition each comes from, version
control through databases, agent memory, supply-chain evidence, incident
forensics, preservation, content addressing and transparency logs, and answers
the same four questions about every one: what it is for, where it goes further
than Ranke, where Ranke goes further, and how the two compose. The landing page
links it from the paragraph that names the gap. Each entry states where the other
system is further along, and the page says once that the compositions are design
sketches, since `ranke-git` is the only adapter that exists. Fifteen project
logos are committed under `src/static/assets/logos/` to identify the projects
they name.

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
