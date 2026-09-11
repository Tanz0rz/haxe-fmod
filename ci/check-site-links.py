#!/usr/bin/env python3
"""Fails when a page of the built documentation site links to a file that
is not in the site. Internal hrefs and srcs only, external URLs are not
fetched. Absolute links are resolved under the site_url prefix mkdocs
writes (/haxe-fmod/).

Usage: python3 ci/check-site-links.py <site dir> [prefix]
"""

import html
import os
import re
import sys


def main():
    root = sys.argv[1]
    prefix = sys.argv[2] if len(sys.argv) > 2 else "/haxe-fmod/"
    broken = []
    pages = 0
    for d, _, files in os.walk(root):
        for f in files:
            if not f.endswith(".html"):
                continue
            pages += 1
            page = os.path.join(d, f)
            text = open(page, encoding="utf-8", errors="replace").read()
            for match in re.finditer(r'(?:href|src)="([^"#?]+)', text):
                url = html.unescape(match.group(1))
                if re.match(r"^[a-z]+:", url) or url.startswith("//"):
                    continue
                if url.startswith(prefix):
                    target = os.path.join(root, url[len(prefix):])
                elif url.startswith("/"):
                    broken.append((page, url))
                    continue
                else:
                    target = os.path.normpath(os.path.join(d, url))
                if os.path.isdir(target):
                    target = os.path.join(target, "index.html")
                if not os.path.exists(target):
                    broken.append((page, url))
    for page, url in broken[:50]:
        print(f"FAIL: {page} links to {url}")
    print(f"check-site-links: {pages} pages, {len(broken)} broken link(s)")
    return 1 if broken else 0


if __name__ == "__main__":
    sys.exit(main())
