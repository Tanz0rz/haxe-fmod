#!/usr/bin/env python3
"""Fails when a page of the GitHub Pages redirect stub sends a visitor
anywhere but the home page of the docs site. The stub drops the old path
on purpose, so the structure of the docs site can change without
breaking old links. Every page must redirect by script and by meta
refresh, carry noindex, and name only the home page. index.html and
404.html must both exist, since 404.html catches every deep link.

Usage: python3 ci/check-pages-redirect.py <stub dir>
"""

import os
import re
import sys

HOME = "https://www.tanz0rz.com/haxe-fmod/"


def check(page):
    text = open(page, encoding="utf-8").read()
    problems = []
    if '<meta name="robots" content="noindex">' not in text:
        problems.append("no noindex meta tag")
    if f'<link rel="canonical" href="{HOME}">' not in text:
        problems.append("no canonical link to the home page")
    if f'<script>location.replace("{HOME}");</script>' not in text:
        problems.append("no script redirect to the home page")
    if f'<meta http-equiv="refresh" content="0; url={HOME}">' not in text:
        problems.append("no meta refresh to the home page")
    if "location.pathname" in text or "location.search" in text or "location.hash" in text:
        problems.append("the page reads the old path")
    for url in re.findall(r"https?://[^\s\"'<>)]+", text):
        if url != HOME:
            problems.append(f"names {url}")
    return problems


def main():
    root = sys.argv[1]
    failed = False
    for required in ("index.html", "404.html"):
        if not os.path.isfile(os.path.join(root, required)):
            print(f"FAIL: {root} has no {required}")
            failed = True
    pages = sorted(f for f in os.listdir(root) if f.endswith(".html"))
    for name in pages:
        for problem in check(os.path.join(root, name)):
            print(f"FAIL: {name}: {problem}")
            failed = True
    print(f"check-pages-redirect: {len(pages)} pages")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
