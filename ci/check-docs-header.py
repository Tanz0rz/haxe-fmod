#!/usr/bin/env python3
"""Fails when docs/overrides/partials/header.html is anything other than
Material's own header with the example games include added before the
palette toggle. A Material upgrade that changes its header then fails the
docs build until the override is copied again. With a site directory it
also fails when a built docs page lacks the header link or its inline
style. The style ships in the page because browsers cache an extra
stylesheet for hours, and a stale copy once tripled the header height.

Usage: python3 ci/check-docs-header.py [site dir]
Run it with the Python that has mkdocs-material installed.
"""

import os
import sys

import material

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OVERRIDE = os.path.join(ROOT, "docs", "overrides", "partials", "header.html")
UPSTREAM = os.path.join(os.path.dirname(material.__file__), "templates", "partials", "header.html")
INCLUDE = '    {% include "partials/example-games-link.html" %}\n'
ANCHOR = "    {% if config.theme.palette %}\n"
LINK = 'class="md-header__button md-icon md-header__games"'
STYLE = ".md-header__button.md-header__games {"


def main():
    failed = False
    upstream = open(UPSTREAM, encoding="utf-8").read()
    override = open(OVERRIDE, encoding="utf-8").read()
    if upstream.count(ANCHOR) != 1:
        print(f"FAIL: Material's header no longer has one palette block to anchor on ({UPSTREAM})")
        failed = True
    elif override != upstream.replace(ANCHOR, INCLUDE + ANCHOR):
        print("FAIL: the header override differs from Material's header plus the example games include")
        print(f"  copy {UPSTREAM} again and put the include line before the palette block")
        failed = True
    else:
        print("ok: the header override is Material's header plus the example games include")
    if len(sys.argv) > 1:
        site = sys.argv[1]
        pages = missing = 0
        for d, dirs, files in os.walk(site):
            rel = os.path.relpath(d, site)
            # dox writes the API reference, and the games carry their own pages
            if rel == ".":
                dirs[:] = [x for x in dirs if x not in ("api", "games")]
            for f in files:
                if not f.endswith(".html"):
                    continue
                pages += 1
                html = open(os.path.join(d, f), encoding="utf-8").read()
                if LINK not in html or STYLE not in html:
                    print(f"FAIL: {os.path.join(rel, f)} has no example games link with its inline style")
                    missing += 1
        if pages == 0 or missing:
            failed = True
        print(f"check-docs-header: {pages} pages, {missing} without the link")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
