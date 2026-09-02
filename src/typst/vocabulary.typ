// typst/vocabulary.typ — the HTML rendering of the Ranke documentation constructs.
//
// The web half of the two-backend contract. shared/constructs.typ names what a
// chapter may use — common + manual, thirteen names — and G-BACKEND makes every
// one of them this file's obligation; typst/check-backend.typ fails the build
// while one is unbound. The paper group stays out: G-CONSTRUCTS keeps theorems
// and proofs in the papers, and a manual that proves one has mistaken its kind.
//
// Structure and classes only, with the look in src/style.css, so a change of
// appearance never becomes a change of markup. Two constructs work differently
// here than in print, and both are the reason a second backend exists at all:
// `diagram` names its picture rather than inlining it, and `gls` links to the
// glossary page rather than to an appendix this document would have to print.

#import "/shared/glossary.typ": entries

#let glossary-page = "/docs/glossary/"

// Content as a plain string, so a heading can name its own anchor.
#let plain(it) = {
  if type(it) == str { it }
  else if it == none { "" }
  else if it.has("text") { it.text }
  else if it.has("children") { it.children.map(plain).join("") }
  else if it.has("body") { plain(it.body) }
  else { "" }
}

// The anchor a heading is addressed by. Made from the heading's own words, so it
// says what it points at and survives a section being added above it.
#let slug(it) = lower(plain(it)).replace(regex("[^a-z0-9]+"), "-").trim("-")

#let _by-key = {
  let m = (:)
  for e in entries { m.insert(e.key, e) }
  m
}

// The anchor is the entry key, which is what the glossary page must anchor on.
#let _term(key, plural: false) = {
  let e = _by-key.at(key, default: none)
  if e == none { panic("gls: no glossary entry for '" + key + "'") }
  let word = if plural { e.short + "s" } else { e.short }
  html.elem("a", attrs: (href: glossary-page + "#" + key, class: "gls"), word)
}

#let gls(key) = _term(key)
#let glspl(key) = _term(key, plural: true)

// A prose-level definition. The term is a span rather than a heading, since the
// templater lifts every heading into the sidebar and a concept is not a section.
#let concept(term, body) = html.elem("aside", attrs: (class: "concept"), {
  html.elem("span", attrs: (class: "concept-term"), term)
  html.elem("div", attrs: (class: "concept-body"), body)
})

#let part(label) = html.elem("div", attrs: (class: "part"), {
  html.elem("span", label)
})

// `image()` inlines the file as a base64 data URI under HTML export, which puts
// the bytes of every picture into the page, so this names the file instead. The
// figure around it stays: it carries the caption, and it is what `@fig:x`
// resolves against, which a bare html.elem cannot.
//
// G-ASSETS makes the path project-absolute — `/docs/assets/x.svg` — and the page
// is published with the tree's assets/ beside it, so dropping the tree's own
// `docs/` prefix gives a URL that resolves against the page itself.
#let diagram(path, caption, width: 100%) = {
  assert(
    path.starts-with("/docs/assets/"),
    message: "diagram: path must be project-absolute under the tree's assets, "
      + "as in \"/docs/assets/x.svg\"; got \"" + path + "\"",
  )
  figure(
    html.elem("img", attrs: (
      src: path.slice("/docs/".len()),
      alt: "",
      style: "width: " + repr(width),
    )),
    caption: caption,
    kind: image,
    supplement: [Figure],
  )
}

// Wide content scrolls inside its own box, so the page never scrolls sideways.
#let listing(body) = html.elem("div", attrs: (class: "listing"), body)

// G-CITE asks that a guarantee be citable, so the id is the anchor a reader links to.
#let rule(id, tier, body) = html.elem("div", attrs: (class: "rule", id: lower(id)), {
  html.elem("div", attrs: (class: "rule-head"), {
    html.elem("a", attrs: (class: "rule-id", href: "#" + lower(id)), id)
    html.elem("span", attrs: (class: "rule-tier"), tier)
  })
  html.elem("div", attrs: (class: "rule-body"), body)
})

#let dref(label) = html.elem("span", attrs: (class: "dref"), label)

#let todo(body) = html.elem("span", attrs: (class: "todo"), body)

// The label is markup rather than CSS, so an agent reading the page as text sees
// which of the two levels it is.
#let _admonition(class, label, body) = html.elem("aside", attrs: (class: class), {
  html.elem("span", attrs: (class: "admon-label"), label)
  html.elem("div", attrs: (class: "admon-body"), body)
})

#let note(body) = _admonition("note", "Note", body)
#let warning(body) = _admonition("warning", "Warning", body)

// A flag, a configuration key, an API field: the signature, then what it does.
#let item(signature, body) = html.elem("div", attrs: (class: "item"), {
  html.elem("code", attrs: (class: "signature"), signature)
  html.elem("div", attrs: (class: "item-body"), body)
})

#let example(body, title: none) = html.elem("div", attrs: (class: "example"), {
  html.elem("span", attrs: (class: "example-label"),
    if title != none [Example — #title] else [Example])
  html.elem("div", attrs: (class: "example-body"), body)
})
