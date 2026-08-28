#!/usr/bin/env python3
"""Ties every example translation to the page it sits on.

extension/test/site-snapshot.json records, per fmod.com page, each code
example's position, the heading it sits under, and (for struct, enum,
define, and callback typedef examples) the first line of its C source.
extension/examples/<page>.md holds the Haxe side, keyed by position.

This check fails when:
  - an example on the page has no section and no page default,
  - a section's heading comment does not match the page's heading at
    that position (the index drifted or the section is on the wrong
    page),
  - a type definition example has a hand-written fence instead of a
    `Type:` directive (the declaration must come from the sources),
    unless the section declares `Shape: indices` (a parameter index
    enum, shown as setParameter by index) or `Shape: usage` (a type
    with no Haxe declaration, shown as the call that plays its role),
    or has no content at all,
  - a `Type:` directive names a type that is not in the sources.

Run: python3 ci/check-example-types.py
"""

import importlib.util
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SNAPSHOT = os.path.join(ROOT, "extension", "test", "site-snapshot.json")


def load_examples_module():
    spec = importlib.util.spec_from_file_location("haxe_examples", os.path.join(ROOT, "ci", "haxe-examples.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main():
    module = load_examples_module()
    with open(SNAPSHOT, encoding="utf-8") as fh:
        snapshot = json.load(fh)
    pages = module.build()
    problems = []
    checked = 0
    types = 0
    for page, data in sorted(snapshot.items()):
        examples = data.get("examples", [])
        if not examples:
            continue
        sections = pages.get(page)
        if sections is None:
            problems.append(f"{page}: {len(examples)} example(s) on the page and no extension/examples/{page}.md")
            continue
        default = sections.get("*")
        for example in examples:
            checked += 1
            key = str(example["index"])
            section = sections.get(key)
            if section is None and default is None:
                problems.append(f"{page}: example {key} under \"{example['heading']}\" has no section and no page default")
                continue
            if section is not None and section["heading"] and example["heading"] and section["heading"] != example["heading"]:
                problems.append(f"{page}: section {key} says \"{section['heading']}\" but the page says \"{example['heading']}\"")
            if example.get("decl"):
                types += 1
                target = section if section is not None else default
                if target.get("type") or target.get("shape") in ("indices", "usage"):
                    continue
                if target.get("code") is not None:
                    problems.append(f"{page}: example {key} is a type definition ({example['decl'][:40]}) and needs a Type: directive, not a hand-written fence")
                elif not target.get("notes"):
                    problems.append(f"{page}: example {key} is a type definition ({example['decl'][:40]}) with no Haxe type and no note")
    for problem in problems:
        print("FAIL: " + problem)
    print(f"check-example-types: {checked} examples, {types} type definitions, {len(problems)} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
