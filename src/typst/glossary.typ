// typst/glossary.typ — the glossary page, generated from the series' terms.
//
// Every `gls` in every chapter resolves to /docs/glossary/#<key>, so the anchors
// here are the entry keys and nothing else may take that name.
//
// An entry's description names further terms, and those calls are glossarium's
// rather than ours — the description content was built inside shared/glossary.typ
// and carries that closure. Registering the entries and labelling each term with
// its own key is what makes them resolve, and typst then points each one at the
// dt's id, so a description links to the neighbouring definitions on this page.

#import "/typst/handbook.typ": handbook
#import "/shared/glossary.typ": entries, use-glossary

#let _groups = {
  let seen = ()
  for e in entries { if e.group not in seen { seen.push(e.group) } }
  seen
}

// "01 · Ranke-Graph" is the paper that introduces the terms; the number orders
// the groups and the name is what a reader wants to read.
#let _group-name(group) = group.split(" · ").last()
#let _group-id(group) = "group-" + lower(_group-name(group))

#show: handbook.with(
  title: "Glossary",
  subtitle: [The vocabulary the papers, the specification and every manual share],
  date: "2026-09-01",
)

#show: use-glossary

Each term is defined once, in the series' single source of truth, and every
`gls` link in every chapter lands on the entry below that owns it.

#for group in _groups [
  #html.elem("h2", attrs: (id: _group-id(group)), _group-name(group))
  #html.elem("dl", attrs: (class: "glossary"), {
    for e in entries.filter(x => x.group == group) [
      #html.elem("dt", attrs: (id: e.key), {
        html.elem("a", attrs: (href: "#" + e.key, class: "term"), e.short)
      })#label(e.key)
      #html.elem("dd", e.description)
    ]
  })
]
