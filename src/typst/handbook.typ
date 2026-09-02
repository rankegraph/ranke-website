// typst/handbook.typ — the HTML document root a part's docs/index.typ applies.
//
// The counterpart of shared/handbook.typ, and a much shorter one: a web page
// takes its navigation from the site around it, and its glossary from
// /docs/glossary/, so this writes the front matter and nothing else.
//
// Everything it says about the document comes from the build rather than the
// source (G-VERSION), because the source is vendored from a release and cannot
// know which release it was vendored at.

#import "vocabulary.typ": *

#let version = sys.inputs.at("version", default: "dev")
#let source = sys.inputs.at("source", default: none)
#let imported = sys.inputs.at("imported", default: none)

#let _months = ("January", "February", "March", "April", "May", "June", "July",
  "August", "September", "October", "November", "December")

// 2026-09-01 as "1 September 2026"; anything else is passed through as written.
#let _long-date(iso) = {
  let p = iso.split("-")
  if p.len() != 3 { return iso }
  let m = int(p.at(1))
  if m < 1 or m > 12 { return iso }
  str(int(p.at(2))) + " " + _months.at(m - 1) + " " + p.at(0)
}

// Where the chapters came from, in the words a reader needs to go upstream.
#let _provenance = if source != none and imported != none {
  html.elem("p", attrs: (class: "provenance"), {
    [Imported from ]
    html.elem("a", attrs: (href: source), source.split("/").last())
    [ #version on #_long-date(imported) — see the repository for anything newer.]
  })
}

#let handbook(title: "", subtitle: none, date: none, body) = {
  set document(title: title)
  // G-XREF-B: numbered headings, so a chapter's `@sec:integrity` resolves here
  // as it does in print. Unnumbered breaks every section reference in the book.
  set heading(numbering: "1.1")

  // The heading element, named by its own words. Typst anchors a reference on
  // the element's id when it has one, so `@sec:storage` resolves to a URL that
  // says what it points at and survives a section being added above it. The
  // document's own h1 is the title below, so a chapter starts at h2.
  show heading: it => html.elem("h" + str(it.level + 1), attrs: (id: slug(it.body)), {
    if it.numbering != none {
      html.elem("span", attrs: (class: "num"), context counter(heading).display(it.numbering))
      [ ]
    }
    it.body
  })

  html.elem("header", attrs: (class: "handbook-front"), {
    html.elem("h1", title)
    if subtitle != none { html.elem("p", attrs: (class: "subtitle"), subtitle) }
    html.elem("p", attrs: (class: "edition"), {
      html.elem("span", attrs: (class: "version"), version)
      if date != none { html.elem("span", attrs: (class: "dated"), _long-date(date)) }
    })
    if _provenance != none { _provenance }
  })

  body
}
