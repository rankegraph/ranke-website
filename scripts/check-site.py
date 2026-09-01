#!/usr/bin/env python3
# The site's own checks — what a hand-written static site can be wrong about.
#
# Three groups, run as three make targets so a failure names itself:
#
#   pages    every page carries the head the others carry, and its tags close
#   links    every local link, asset and fragment resolves
#   classes  every class a page uses has a rule, and every rule is used
#
# Errors fail the gate; warnings print and pass. The split is deliberate: an
# unreferenced asset or an unused rule is housekeeping, while a dead link is a
# reader hitting a 404. Only the second should stop a merge.
#
# Standard library only, so the gate needs nothing installed in a fresh checkout.

import sys
import re
import urllib.error
import urllib.request
from html.parser import HTMLParser
from pathlib import Path

SRC = Path(__file__).resolve().parent.parent / "src"
SITE = "https://rankegraph.org"

VOID = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link",
        "meta", "source", "track", "wbr"}

errors: list[str] = []
warnings: list[str] = []


def error(page: Path, message: str) -> None:
    errors.append(f"{page.relative_to(SRC.parent)}: {message}")


def warn(page: Path, message: str) -> None:
    warnings.append(f"{page.relative_to(SRC.parent)}: {message}")


class Page(HTMLParser):
    """One page, read once: the facts every check needs."""

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.stack: list[tuple[str, int]] = []
        self.unclosed: list[tuple[str, int]] = []
        self.stray: list[tuple[str, int]] = []
        self.ids: set[str] = set()
        self.classes: set[str] = set()
        self.links: list[tuple[str, int]] = []      # href and src values
        self.metas: dict[str, str] = {}             # meta name -> content
        self.rels: list[tuple[str, str]] = []       # (rel, href)
        self.title = ""
        self.html_lang = ""
        self.has_doctype = False
        self.has_charset = False
        self._in_title = False

    def handle_decl(self, decl: str) -> None:
        if decl.lower().startswith("doctype html"):
            self.has_doctype = True

    def handle_starttag(self, tag: str, attrs_list: list) -> None:
        attrs = {k: (v or "") for k, v in attrs_list}
        line = self.getpos()[0]

        if tag not in VOID:
            self.stack.append((tag, line))
        if tag == "title":
            self._in_title = True
        if tag == "html":
            self.html_lang = attrs.get("lang", "")
        if tag == "meta":
            if "charset" in attrs:
                self.has_charset = True
            if "name" in attrs:
                self.metas[attrs["name"]] = attrs.get("content", "")
        if tag == "link":
            self.rels.append((attrs.get("rel", ""), attrs.get("href", "")))

        if "id" in attrs:
            self.ids.add(attrs["id"])
        if "class" in attrs:
            self.classes.update(attrs["class"].split())
        for name in ("href", "src"):
            if name in attrs:
                self.links.append((attrs[name], line))

    def handle_endtag(self, tag: str) -> None:
        if tag == "title":
            self._in_title = False
        if tag in VOID:
            return
        for depth in range(len(self.stack) - 1, -1, -1):
            if self.stack[depth][0] == tag:
                self.unclosed.extend(self.stack[depth + 1:])
                del self.stack[depth:]
                return
        self.stray.append((tag, self.getpos()[0]))

    def handle_data(self, data: str) -> None:
        if self._in_title:
            self.title += data


def read_pages() -> dict[Path, Page]:
    pages = {}
    for path in sorted(SRC.glob("*.html")):
        parser = Page()
        parser.feed(path.read_text(encoding="utf-8"))
        parser.close()
        pages[path] = parser
    return pages


# ── pages ───────────────────────────────────────────────────────────────

def check_pages(pages: dict[Path, Page]) -> None:
    """The head every page carries, and tags that close.

    The five pages written by hand share one head down to the order of its
    lines. A sixth that omits the canonical link or the description is the
    likely mistake, and neither shows up in a browser."""
    for path, page in pages.items():
        if not page.has_doctype:
            error(path, "no <!doctype html>")
        if page.html_lang != "en":
            error(path, f'<html lang> is "{page.html_lang}", expected "en"')
        if not page.has_charset:
            error(path, "no <meta charset>")
        if "viewport" not in page.metas:
            error(path, "no <meta name=viewport> — the page will not reflow on a phone")
        if not page.title.strip():
            error(path, "no <title>")
        if not page.metas.get("description", "").strip():
            error(path, "no <meta name=description> — this is what a search result shows")

        # The canonical URL is derivable from the filename, so a copied page
        # that kept its source's canonical is a mistake a machine can catch.
        want = f"{SITE}/" if path.name == "index.html" else f"{SITE}/{path.name}"
        canonical = [href for rel, href in page.rels if rel == "canonical"]
        if not canonical:
            error(path, "no <link rel=canonical>")
        elif canonical[0] != want:
            error(path, f"canonical is {canonical[0]}, expected {want}")

        for rel, sizes in (("icon", "32x32"), ("icon", "16x16"), ("apple-touch-icon", None)):
            if not any(r == rel for r, _ in page.rels):
                error(path, f"no <link rel={rel}>")
        if not any(rel == "stylesheet" for rel, _ in page.rels):
            error(path, "no stylesheet")

        for tag, line in page.unclosed + page.stack:
            error(path, f"<{tag}> opened at line {line} and never closed")
        for tag, line in page.stray:
            error(path, f"</{tag}> at line {line} closes nothing")


# ── links ───────────────────────────────────────────────────────────────

def check_links(pages: dict[Path, Page]) -> None:
    """Every local target resolves — a file that exists, a fragment that does.

    External links are left alone: they need the network, they fail for reasons
    outside this repository, and a gate that depends on somebody else's uptime
    stops meaning anything. `make links-external` checks those on demand."""
    referenced: set[Path] = set()

    for path, page in pages.items():
        for value, line in page.links:
            if re.match(r"^(https?:|mailto:|tel:|data:|//)", value):
                continue

            target, _, fragment = value.partition("#")
            if target:
                dest = (path.parent / target).resolve()
                if not dest.exists():
                    error(path, f"line {line}: {value} names no file")
                    continue
                referenced.add(dest)
                if fragment:
                    if dest.suffix == ".html" and dest in pages:
                        if fragment not in pages[dest].ids:
                            error(path, f"line {line}: {value} — no id \"{fragment}\" in {dest.name}")
            elif fragment and fragment not in page.ids:
                error(path, f"line {line}: #{fragment} matches no id on this page")

    for asset in sorted((SRC / "assets").iterdir()):
        if asset.is_file() and asset.resolve() not in referenced:
            warn(asset, "referenced by no page")


# ── classes ─────────────────────────────────────────────────────────────

def check_classes(pages: dict[Path, Page]) -> None:
    """The two directions of drift between the pages and the stylesheet.

    A class with no rule is invisible breakage: the markup is there and the
    styling silently is not, which is exactly what will happen when a docs
    backend starts emitting construct classes. That direction is an error. A
    rule with no user is dead weight, so it warns — `.todo` and `.sub` are
    scaffolding the pages have not needed yet."""
    css = (SRC / "style.css").read_text(encoding="utf-8")
    # Strip comments before reading selectors, so a class named in prose does
    # not count as a definition.
    css = re.sub(r"/\*.*?\*/", "", css, flags=re.S)
    defined = set(re.findall(r"\.([a-zA-Z][a-zA-Z0-9_-]*)", css))

    used: dict[str, Path] = {}
    for path, page in pages.items():
        for name in page.classes:
            used.setdefault(name, path)

    for name, path in sorted(used.items()):
        if name not in defined:
            error(path, f'class "{name}" has no rule in style.css')
    for name in sorted(defined - set(used)):
        warn(SRC / "style.css", f'.{name} is defined and unused')


# ── external ────────────────────────────────────────────────────────────

def check_external(pages: dict[Path, Page]) -> None:
    """Outbound links, asked one at a time.

    Kept out of `verify` because it needs the network. Its own failure mode is
    real, though: this site points at release assets by their `latest/download`
    name, and upstream renames one now and then — ranke-graph v0.22.0 renamed
    `ranke-docs-format.pdf` to `ranke-docs-spec.pdf`, which turns a link here
    into a 404 with nothing in this repository having changed."""
    urls: dict[str, Path] = {}
    for path, page in pages.items():
        for value, _ in page.links:
            if value.startswith(("http://", "https://")):
                urls.setdefault(value.partition("#")[0], path)

    for url, path in sorted(urls.items()):
        # A browser-shaped agent: GitHub answers a bare python one with 403.
        request = urllib.request.Request(url, method="HEAD", headers={
            "User-Agent": "Mozilla/5.0 (compatible; rankegraph-linkcheck)",
        })
        try:
            with urllib.request.urlopen(request, timeout=20) as response:
                status = response.status
        except urllib.error.HTTPError as failure:
            # HEAD is optional; a 4xx that is not 404 may mean only that.
            if failure.code in (403, 405, 501):
                try:
                    request.method = "GET"
                    with urllib.request.urlopen(request, timeout=20) as response:
                        status = response.status
                except Exception as second:
                    error(path, f"{url} — {second}")
                    continue
            else:
                error(path, f"{url} — HTTP {failure.code}")
                continue
        except Exception as failure:
            error(path, f"{url} — {failure}")
            continue
        print(f"  {status}  {url}")

    print(f">> asked {len(urls)} external URL(s)")


CHECKS = {"pages": check_pages, "links": check_links, "classes": check_classes,
          "external": check_external}


def main() -> int:
    if len(sys.argv) != 2 or sys.argv[1] not in CHECKS:
        print(f"usage: check-site.py <{'|'.join(CHECKS)}>", file=sys.stderr)
        return 2

    name = sys.argv[1]
    pages = read_pages()
    if not pages:
        print(f"check-site: no pages under {SRC} — nothing to check", file=sys.stderr)
        return 1

    CHECKS[name](pages)

    for line in warnings:
        print(f"warn: {line}")
    for line in errors:
        print(f"FAIL: {line}", file=sys.stderr)

    print(f">> {name}: {len(pages)} page(s), {len(errors)} error(s), {len(warnings)} warning(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
