#!/usr/bin/env python3
"""Add the analytics tags to every API reference page.

MkDocs pages get them from overrides/partials/integrations/analytics/custom.html.
dox renders the reference with its own templates, so this script copies the
same tags into each generated page before </head>.

Usage: python3 ci/docs-analytics.py site/api
"""
import pathlib
import os
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
PARTIAL = ROOT / "overrides" / "partials" / "integrations" / "analytics" / "custom.html"


def tags():
    lines = [l for l in PARTIAL.read_text().splitlines() if l.lstrip().startswith("<script")]
    if not lines:
        sys.exit(f"no script tags in {PARTIAL}")
    return "\n".join(lines) + "\n"


def main():
    # The site build carries the tags only when the docs workflow asks
    if not os.environ.get("DOCS_ANALYTICS"):
        print("docs-analytics: DOCS_ANALYTICS is unset, no tags added")
        return
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    api = pathlib.Path(sys.argv[1])
    snippet = tags()
    done = 0
    for page in api.rglob("*.html"):
        html = page.read_text(encoding="utf-8")
        if "data-website-id" in html:
            continue
        if "</head>" not in html:
            sys.exit(f"{page}: no </head>")
        page.write_text(html.replace("</head>", snippet + "</head>", 1), encoding="utf-8")
        done += 1
    print(f"analytics tags added to {done} API pages")


if __name__ == "__main__":
    main()
