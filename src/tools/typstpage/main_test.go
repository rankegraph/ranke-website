package main

import (
	"strings"
	"testing"
)

const compiled = `<!DOCTYPE html><html lang="en"><head><meta charset="utf-8">` +
	`<title>The Manual</title><style>math { font-style: normal; }</style></head>` +
	`<body><header class="handbook-front"><h1>The Manual</h1></header>` +
	`<h2 id="running-an-instance"><span class="num">1</span> Running an instance</h2>` +
	`<p>Prose with <a href="#the-shape">a reference</a>.</p>` +
	`<h3 id="the-shape"><span class="num">1.1</span> The shape of the document</h3>` +
	`<h4 id="deeper">Too deep for a contents list</h4>` +
	`</body></html>`

func TestSplitKeepsTheBodyAndDropsTheHead(t *testing.T) {
	body, _, _, err := split([]byte(compiled))
	if err != nil {
		t.Fatal(err)
	}
	got := string(body)
	if strings.Contains(got, "<head>") || strings.Contains(got, "<title>") {
		t.Errorf("the head reached the content file: %s", got)
	}
	if !strings.Contains(got, `<h2 id="running-an-instance">`) {
		t.Errorf("the body is missing its headings: %s", got)
	}
	if !strings.Contains(got, `href="#the-shape"`) {
		t.Errorf("an in-page reference was lost: %s", got)
	}
}

// Typst emits the MathML rules in the head it writes; dropping them leaves
// every formula unstyled.
func TestSplitCarriesTheStyleTypstWrote(t *testing.T) {
	_, styles, _, err := split([]byte(compiled))
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(styles, "font-style: normal") {
		t.Errorf("the style block was dropped: %q", styles)
	}
}

func TestSplitListsTheHeadingsALayoutCanShow(t *testing.T) {
	_, _, headings, err := split([]byte(compiled))
	if err != nil {
		t.Fatal(err)
	}
	want := []heading{
		{Level: 2, ID: "running-an-instance", Text: "Running an instance"},
		{Level: 3, ID: "the-shape", Text: "The shape of the document"},
	}
	if len(headings) != len(want) {
		t.Fatalf("got %d heading(s), want %d: %+v", len(headings), len(want), headings)
	}
	for i, h := range headings {
		if h != want[i] {
			t.Errorf("heading %d is %+v, want %+v", i, h, want[i])
		}
	}
}

// A heading with no id cannot be linked, so it has no place in a contents list.
func TestSplitSkipsAnUnnamedHeading(t *testing.T) {
	_, _, headings, err := split([]byte(`<html><body><h2>Unnamed</h2></body></html>`))
	if err != nil {
		t.Fatal(err)
	}
	if len(headings) != 0 {
		t.Errorf("an unnamed heading was listed: %+v", headings)
	}
}

func TestAnchoredRefusesTwoHeadingsOnOneAnchor(t *testing.T) {
	err := anchored([]heading{
		{Level: 2, ID: "the-shape", Text: "The shape"},
		{Level: 3, ID: "the-shape", Text: "The shape"},
	})
	if err == nil {
		t.Fatal("two headings sharing an anchor were accepted; one of them is unreachable")
	}
	if !strings.Contains(err.Error(), "the-shape") {
		t.Errorf("the error does not name the anchor: %v", err)
	}
}

// A heading whose words render to nothing leaves id="", which no link can reach.
func TestAnchoredRefusesAHeadingWithNoAnchor(t *testing.T) {
	if err := anchored([]heading{{Level: 2, ID: "", Text: ""}}); err == nil {
		t.Fatal("a heading with no anchor was accepted")
	}
}
