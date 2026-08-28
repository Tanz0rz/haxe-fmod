#!/usr/bin/env python3
"""Builds the example translations the fmod.com docs extension shows on
guide pages.

The FMOD guides carry code examples with C, C++, C#, and JS tabs that are
not function entries, so the bindings table cannot cover them. Their Haxe
versions are written by hand in extension/examples/<page>.md, one file
per fmod.com page (the html file name without the extension). Inside,
each example is a section:

    ## 3
    <!-- 10.2 Extracting PCM Data from a Sound -->
    An optional note shown above the code, one paragraph per line.
    ```haxe
    var sound = ...
    ```

A section may carry a `Shape: indices` line with its fence when the C
enum it stands beside is a parameter index list (the DSP effect
parameter enums), where a fence showing setParameter by index is the
right Haxe form, or `Shape: usage` when the type has no Haxe
declaration and the fence shows the call that plays its role. Either
line declares on purpose that the fence is not a declaration. A section may carry a `Type: haxefmod.studio.FmodResult` line instead of
a fence. The generator then copies that type's declaration out of the
source file, so a page that shows a C struct or enum shows the real
Haxe declaration beside it and cannot drift from the library.

The number is the example's position among the page's example units
(every language selector, and every single-language code block that has
no selector) counted from zero in document order, function entries
included. The extension counts the same way to find it.
The HTML comment records the heading the example sits under. A section
with a note and no code marks an example haxefmod cannot express (the
note says what to do instead). A `## *` section is the page default,
shown for every example on the page that has no section of its own.

Every ```haxe fence is compiled by ci/check-readme-snippets.py, so the
translations stay valid as the library changes.

Run: python3 ci/haxe-examples.py          rewrite extension/examples-data.js
     python3 ci/haxe-examples.py --check  fail if it is out of date
"""

import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE_DIR = os.path.join(ROOT, "extension", "examples")
DATA_JS = os.path.join(ROOT, "extension", "examples-data.js")

SECTION = re.compile(r"^## (\S+)\s*$", re.M)
TYPE_LINE = re.compile(r"^Type:\s*([\w.]+)\s*$", re.M)
SHAPE_LINE = re.compile(r"^Shape:\s*(\w+)\s*$", re.M)
COMMENT = re.compile(r"<!--(.*?)-->", re.S)
FENCE = re.compile(r"```haxe\n(.*?)```", re.S)


def read(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def declaration_of(path):
    """The declaration of a Haxe type as written in its source file:
    from the doc comment or the declaration keyword through the matching
    closing brace (or the semicolon of a typedef alias)."""
    parts = path.split(".")
    name = parts[-1]
    candidates = [os.path.join(ROOT, *parts) + ".hx"]
    if len(parts) > 1:
        candidates.append(os.path.join(ROOT, *parts[:-1]) + ".hx")
    for file in candidates:
        if not os.path.exists(file):
            continue
        text = read(file)
        match = re.search(r"^(?:@:\w+(?:\([^)]*\))?\s*)*(?:enum\s+)?(?:abstract|class|typedef|enum|interface)\s+" + re.escape(name) + r"\b[^\n]*", text, re.M)
        if not match:
            continue
        start = match.start()
        # include a doc comment that sits right above
        before = text[:start].rstrip()
        if before.endswith("*/"):
            doc_start = before.rfind("/**")
            if doc_start >= 0:
                start = doc_start
        brace = text.find("{", match.end() - len(match.group(0)))
        semicolon = text.find(";", match.start())
        if brace < 0 or (0 <= semicolon < brace):
            return text[start:semicolon + 1]
        depth = 0
        for i in range(brace, len(text)):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    return text[start:i + 1]
    raise SystemExit(f"haxe-examples: type {path} not found in the sources")


def parse_page(text):
    examples = {}
    matches = list(SECTION.finditer(text))
    for i, match in enumerate(matches):
        # Keys stay strings ("*" and digits alike), which is what JSON
        # gives the extension anyway
        index = match.group(1)
        end = matches[i + 1].start() if i + 1 < len(matches) else len(text)
        body = text[match.end():end]
        heading = ""
        comment = COMMENT.search(body)
        if comment:
            heading = comment.group(1).strip()
            body = body[:comment.start()] + body[comment.end():]
        fence = FENCE.search(body)
        code = fence.group(1).rstrip("\n") if fence else None
        if fence:
            body = body[:fence.start()] + body[fence.end():]
        type_line = TYPE_LINE.search(body)
        type_path = None
        if type_line:
            type_path = type_line.group(1)
            body = body[:type_line.start()] + body[type_line.end():]
            if code is None:
                code = declaration_of(type_path)
        shape_line = SHAPE_LINE.search(body)
        shape = None
        if shape_line:
            shape = shape_line.group(1)
            body = body[:shape_line.start()] + body[shape_line.end():]
        notes = [line.strip() for line in body.splitlines() if line.strip()]
        examples[index] = {"heading": heading, "notes": notes, "code": code, "type": type_path, "shape": shape}
    return examples


def build():
    pages = {}
    if not os.path.isdir(SOURCE_DIR):
        return pages
    for name in sorted(os.listdir(SOURCE_DIR)):
        if not name.endswith(".md"):
            continue
        page = name[:-3]
        pages[page] = parse_page(read(os.path.join(SOURCE_DIR, name)))
    return pages


def render(pages):
    body = json.dumps(pages, indent=1, sort_keys=True)
    return ("// Generated by ci/haxe-examples.py from extension/examples/*.md.\n"
            "// Do not edit by hand.\n"
            f"const HAXEFMOD_EXAMPLES = {body};\n")


def main():
    check = "--check" in sys.argv[1:]
    pages = build()
    content = render(pages)
    total = sum(len(p) for p in pages.values())
    current = read(DATA_JS) if os.path.exists(DATA_JS) else None
    if current != content:
        if check:
            print("haxe-examples: extension/examples-data.js is out of date (run python3 ci/haxe-examples.py)")
            return 1
        with open(DATA_JS, "w", encoding="utf-8") as fh:
            fh.write(content)
        print("wrote extension/examples-data.js")
    print(f"haxe-examples: {total} examples on {len(pages)} pages")
    return 0


if __name__ == "__main__":
    sys.exit(main())
