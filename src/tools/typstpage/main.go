// package: typstpage / website
// type:    logic
// job:     turns a compiled Typst document into a Hugo content file
// limits:  rewrites nothing in the body — the backend emits what it should
//
// Typst writes a whole HTML document; Hugo wants a fragment with front matter.
// This is the adapter between them, and only that: the anchors, heading levels,
// numbering and asset URLs are the typst backend's, because it is ours and
// knows what it meant. What is left is to keep the body, carry the style block
// typst emits for MathML, and list the headings so a layout can build a table
// of contents — Hugo derives fragments only from markdown it renders itself.
//
//	typstpage -in <compiled.html> -out <content.html> -title T -weight N [-description D]
package main

import (
	"bytes"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"golang.org/x/net/html"
	"golang.org/x/net/html/atom"
	"gopkg.in/yaml.v3"
)

// The front matter a docs page carries. Hugo reads Title and Weight itself; TOC
// and Styles are for the layout.
type frontMatter struct {
	Title       string    `yaml:"title"`
	Description string    `yaml:"description,omitempty"`
	Weight      int       `yaml:"weight"`
	TOC         []heading `yaml:"toc,omitempty"`
	Styles      string    `yaml:"styles,omitempty"`

	// Whatever else the build wants on the page, as -param key=value. The
	// layouts read these; this program only carries them.
	Extra map[string]string `yaml:",inline"`
}

type heading struct {
	Level int    `yaml:"level"`
	ID    string `yaml:"id"`
	Text  string `yaml:"text"`
}

func main() {
	in := flag.String("in", "", "the compiled typst document")
	out := flag.String("out", "", "the content file to write")
	title := flag.String("title", "", "the page's title")
	description := flag.String("description", "", "the page's description")
	weight := flag.Int("weight", 0, "where the page sits in its section")
	var params params
	flag.Var(&params, "param", "an extra front matter field, as key=value (repeatable)")
	flag.Parse()
	if *in == "" || *out == "" || *title == "" {
		fmt.Fprintln(os.Stderr, "typstpage: -in, -out and -title are required")
		os.Exit(2)
	}
	source, err := os.ReadFile(*in)
	if err == nil {
		err = write(*out, source, frontMatter{
			Title: *title, Description: *description, Weight: *weight, Extra: params,
		})
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, "typstpage:", err)
		os.Exit(1)
	}
}

// A repeatable -param flag.
type params map[string]string

func (p params) String() string { return "" }

func (p *params) Set(value string) error {
	key, val, ok := strings.Cut(value, "=")
	if !ok {
		return fmt.Errorf("want key=value, got %q", value)
	}
	if *p == nil {
		*p = params{}
	}
	(*p)[key] = val
	return nil
}

func write(out string, source []byte, front frontMatter) error {
	body, styles, headings, err := split(source)
	if err != nil {
		return err
	}
	front.TOC, front.Styles = headings, styles
	if err := anchored(headings); err != nil {
		return err
	}

	var page bytes.Buffer
	meta, err := yaml.Marshal(front)
	if err != nil {
		return err
	}
	page.WriteString("---\n")
	page.Write(meta)
	page.WriteString("---\n")
	page.Write(body)
	if err := os.MkdirAll(filepath.Dir(out), 0o755); err != nil {
		return err
	}
	return os.WriteFile(out, page.Bytes(), 0o644)
}

// The body, the CSS typst put in the head, and the headings a layout can list.
func split(source []byte) (body []byte, styles string, headings []heading, err error) {
	doc, err := html.Parse(bytes.NewReader(source))
	if err != nil {
		return nil, "", nil, err
	}
	var rendered bytes.Buffer
	var css strings.Builder
	var visit func(*html.Node) error
	visit = func(n *html.Node) error {
		switch {
		case n.DataAtom == atom.Style:
			if n.FirstChild != nil {
				css.WriteString(n.FirstChild.Data)
			}
			return nil
		case n.DataAtom == atom.Body:
			for c := n.FirstChild; c != nil; c = c.NextSibling {
				if err := html.Render(&rendered, c); err != nil {
					return err
				}
			}
			collect(n, &headings)
			return nil
		}
		for c := n.FirstChild; c != nil; c = c.NextSibling {
			if err := visit(c); err != nil {
				return err
			}
		}
		return nil
	}
	if err := visit(doc); err != nil {
		return nil, "", nil, err
	}
	return rendered.Bytes(), css.String(), headings, nil
}

// The backend makes an anchor out of a heading's own words, so a heading whose
// words render to nothing, or to what another heading rendered to, would leave a
// link pointing at the wrong section or at none. Neither is visible in the page.
func anchored(headings []heading) error {
	seen := map[string]string{}
	for _, h := range headings {
		if h.ID == "" || h.Text == "" {
			return fmt.Errorf("the heading %q has no anchor", h.Text)
		}
		if first, ok := seen[h.ID]; ok {
			return fmt.Errorf("%q and %q both anchor on #%s", first, h.Text, h.ID)
		}
		seen[h.ID] = h.Text
	}
	return nil
}

// h2 and h3 are the chapters and their sections; deeper is detail a contents
// list does not carry. The backend numbers a heading in its own span, which is
// styling rather than title, so the number is left out of the text.
var listed = map[atom.Atom]int{atom.H2: 2, atom.H3: 3}

func collect(n *html.Node, into *[]heading) {
	if level, ok := listed[n.DataAtom]; ok {
		if id := attr(n, "id"); id != "" {
			*into = append(*into, heading{Level: level, ID: id, Text: titleOf(n)})
		}
		return
	}
	for c := n.FirstChild; c != nil; c = c.NextSibling {
		collect(c, into)
	}
}

func titleOf(n *html.Node) string {
	var b strings.Builder
	var visit func(*html.Node)
	visit = func(n *html.Node) {
		if n.Type == html.TextNode {
			b.WriteString(n.Data)
			return
		}
		if hasClass(n, "num") {
			return
		}
		for c := n.FirstChild; c != nil; c = c.NextSibling {
			visit(c)
		}
	}
	visit(n)
	return strings.Join(strings.Fields(b.String()), " ")
}

func attr(n *html.Node, name string) string {
	for _, a := range n.Attr {
		if a.Key == name {
			return a.Val
		}
	}
	return ""
}

func hasClass(n *html.Node, name string) bool {
	for _, c := range strings.Fields(attr(n, "class")) {
		if c == name {
			return true
		}
	}
	return false
}
