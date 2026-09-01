#!/usr/bin/env python3
"""Tracks which docs-tab entries have been reviewed against the site.

The mechanical checks in ci/haxe-catalog.py hold literals, calls, and
shape in line with the catalog, but whether a fence is the right way to
do the same thing in haxefmod is a judgment. This ledger records that
judgment per entry: a stamp is a sha1 over the catalog entry, the Haxe
side, and the checker rules version, stored in
extension/test/vet-ledger.json. When fmod.com changes and the catalog
is refreshed, the hashes of the touched entries stop matching, so
exactly those entries come back up for review. The same happens when
someone edits a Haxe section or the rules tighten.

Entries covered: every example key (per-language runs count once, under
their first key) and every function note in extension/functions.md.
Generated content (signatures from bindings-data.js, declarations from
Type: lines) is not stamped, the generators and their checks keep it
in line with the sources.

Run: python3 ci/example-ledger.py --status [--require-all]
         counts per page. --require-all exits 1 when any entry is
         unstamped or stale, for CI once the first full review lands.
     python3 ci/example-ledger.py --next [N]
         the next N unstamped entries with the site's snippets and the
         current Haxe side, ready to review.
     python3 ci/example-ledger.py --stamp <page> <key>
         records the entry's hash after a review. Refuses while
         ci/haxe-catalog.py reports problems. functions.md notes use
         page "functions".
     python3 ci/example-ledger.py --stamp-page <page>
         stamps every entry of one page in one go, for a page reviewed
         top to bottom.
     python3 ci/example-ledger.py --prune
         drops ledger rows whose entry no longer exists.
"""

import hashlib
import importlib.util
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
LEDGER = os.path.join(ROOT, "extension", "test", "vet-ledger.json")

# Bump when the parity rules change enough that old reviews should not
# stand (every entry then reads as stale).
RULES_VERSION = "1"

spec = importlib.util.spec_from_file_location("haxe_catalog", os.path.join(HERE, "haxe-catalog.py"))
hc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hc)


def section_text(section):
    if section is None:
        return ""
    return json.dumps(section, sort_keys=True)


def entry_text(entries, key, groups):
    keys = groups.get(key, [key])
    parts = []
    for member in keys:
        entry = entries[member]
        parts.append(member)
        for language in sorted(entry["blocks"]):
            parts.append(language)
            parts.append(entry["blocks"][language])
    return "\n".join(parts)


def collect():
    """[(page, key, hash)] for every reviewable entry."""
    catalog = hc.read_catalog()
    haxe = hc.read_haxe()
    functions = hc.read_functions()
    out = []
    for page, entries in sorted(catalog.items()):
        groups = hc.variant_groups(entries)
        members = {m for ms in groups.values() for ms_key in [ms] for m in ms_key[1:]}
        sections = haxe.get(page, {})
        for key, entry in entries.items():
            if key in members:
                continue
            if entry["kind"] == "function":
                section = functions.get(key)
                if section is None:
                    continue
                digest = hashlib.sha1(("\n".join([RULES_VERSION, entry_text(entries, key, groups), section_text(section)])).encode()).hexdigest()
                out.append(("functions", key, digest))
                continue
            section = sections.get(key)
            digest = hashlib.sha1(("\n".join([RULES_VERSION, entry_text(entries, key, groups), section_text(section)])).encode()).hexdigest()
            out.append((page, key, digest))
    return out


def read_ledger():
    if not os.path.exists(LEDGER):
        return {}
    with open(LEDGER, encoding="utf-8") as fh:
        return json.load(fh)


def write_ledger(ledger):
    with open(LEDGER, "w", encoding="utf-8") as fh:
        json.dump(ledger, fh, indent=1, sort_keys=True)
        fh.write("\n")


def checks_pass():
    _, problems, _ = hc.build()
    stale = hc.render(hc.build()[0]) != hc.read(hc.DATA_JS) if os.path.exists(hc.DATA_JS) else True
    return not problems and not stale


def show_entry(page, key):
    catalog = hc.read_catalog()
    if page == "functions":
        for name, entries in catalog.items():
            if key in entries:
                page = name
                break
    entries = catalog[page]
    groups = hc.variant_groups(entries)
    haxe = hc.read_haxe().get(page, {})
    functions = hc.read_functions()
    for member in groups.get(key, [key]):
        entry = entries[member]
        for language, code in entry["blocks"].items():
            print(f"  [{language}]")
            for line in code.splitlines():
                print("    " + line)
    section = functions.get(key) if entries[key]["kind"] == "function" else haxe.get(key)
    if section is None:
        print("  [Haxe] (no section)")
        return
    print(f"  [Haxe] verdict: {section['verdict']} {section['reason']}".rstrip())
    if section["type"]:
        print(f"  Type: {section['type']}")
    for rule, reason in section["waivers"].items():
        print(f"  waive: {rule} {reason}")
    if section["code"]:
        for line in section["code"].splitlines():
            print("    " + line)


def main():
    args = sys.argv[1:]
    rows = collect()
    ledger = read_ledger()
    if "--stamp" in args:
        page, key = args[args.index("--stamp") + 1:args.index("--stamp") + 3]
        if not checks_pass():
            print("ledger: ci/haxe-catalog.py reports problems, fix them before stamping")
            return 1
        for row_page, row_key, digest in rows:
            if row_page == page and row_key == key:
                ledger[f"{page}/{key}"] = digest
                write_ledger(ledger)
                print(f"stamped {page}/{key}")
                return 0
        print(f"ledger: no entry {page}/{key}")
        return 1
    if "--stamp-page" in args:
        page = args[args.index("--stamp-page") + 1]
        if not checks_pass():
            print("ledger: ci/haxe-catalog.py reports problems, fix them before stamping")
            return 1
        count = 0
        for row_page, row_key, digest in rows:
            if row_page == page:
                ledger[f"{row_page}/{row_key}"] = digest
                count += 1
        if not count:
            print(f"ledger: no entries on page {page}")
            return 1
        write_ledger(ledger)
        print(f"stamped {count} entries on {page}")
        return 0
    if "--prune" in args:
        live = {f"{page}/{key}" for page, key, _ in rows}
        dropped = [k for k in ledger if k not in live]
        for k in dropped:
            del ledger[k]
        write_ledger(ledger)
        print(f"pruned {len(dropped)} rows")
        return 0
    if "--next" in args:
        index = args.index("--next")
        count = int(args[index + 1]) if index + 1 < len(args) and args[index + 1].isdigit() else 1
        shown = 0
        for page, key, digest in rows:
            if ledger.get(f"{page}/{key}") == digest:
                continue
            state = "stale" if f"{page}/{key}" in ledger else "unreviewed"
            print(f"== {page}/{key} ({state})")
            show_entry(page, key)
            print()
            shown += 1
            if shown >= count:
                break
        if not shown:
            print("ledger: everything is stamped at its current hash")
        return 0
    # --status
    pages = {}
    stale = 0
    unstamped = 0
    for page, key, digest in rows:
        good = ledger.get(f"{page}/{key}") == digest
        pages.setdefault(page, [0, 0])
        pages[page][0] += 1 if good else 0
        pages[page][1] += 1
        if not good:
            if f"{page}/{key}" in ledger:
                stale += 1
            else:
                unstamped += 1
    for page in sorted(pages):
        done, total = pages[page]
        mark = "ok " if done == total else "   "
        print(f"{mark}{page}: {done}/{total}")
    print(f"ledger: {len(rows)} entries, {len(rows) - stale - unstamped} stamped, {stale} stale, {unstamped} unreviewed")
    if "--require-all" in args and (stale or unstamped):
        print("ledger: entries above need review (python3 ci/example-ledger.py --next)")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
