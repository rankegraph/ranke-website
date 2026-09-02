// typst/check-backend.typ — the construct contract, checked against this backend.
//
// The mirror of ranke-graph's docs-spec/check-backends.typ, run here so a name
// added upstream fails our build rather than a reader's page. It checks names,
// which is what a machine can check; whether a construct renders sensibly is
// settled by compiling the reference tree and the real chapters through it.
//
// Compile:  typst compile --root <a part root> typst/check-backend.typ

#import "/shared/constructs.typ": common, manual, constructs, paper, unbound
#import "/typst/vocabulary.typ" as backend

#let missing = unbound(backend, names: constructs)
#if missing.len() > 0 {
  panic("typst/vocabulary.typ leaves " + str(missing.len())
    + " construct(s) unbound: " + missing.join(", "))
}

// The paper group belongs to the print backend, and binding it here would
// invite a chapter to use it — which G-CONSTRUCTS forbids.
#let overreach = paper.filter(name => name in dictionary(backend))
#if overreach.len() > 0 {
  panic("typst/vocabulary.typ binds print-only construct(s): " + overreach.join(", "))
}

#set page(width: 14cm, height: auto, margin: 1cm)
= Construct contract

- `typst/vocabulary.typ` binds all #constructs.len() of common + manual.
- it binds none of the #paper.len() print-only constructs.

/ common: #common.map(raw).join(", ")
/ manual: #manual.map(raw).join(", ")
