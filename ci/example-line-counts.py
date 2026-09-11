#!/usr/bin/env python3
"""Compares the line count of every fmod.com snippet with the Haxe tab.

For every example unit in extension/catalog (the site's code blocks
under their keys) with a Haxe fence or a Type: declaration in
extension/haxe, this counts the lines of the site's C# block and the
lines the Haxe tab shows (imports stripped, notes on top, the way
content.js renders them). A unit without a C# block is counted against
the C++ block, then C/C++, then C, then whatever the site has (guide
pages mark their C++ samples as text), and the report names the
language. Three layout differences stay out of the count on both
sides: a line that holds only an opening brace joins the line before
it, a line that holds only a C# attribute ([Flags]) is metadata, and
the package header a declaration shows is not counted.

A different count is not wrong by itself. Haxe folds an out parameter
into a return value, drops the result check the C# sample spells out,
or needs a helper the C# sample gets from the integration. Every
mismatch is reviewed by hand once. The ones that are right are recorded
in extension/test/line-count-waivers.md with the two counts and the
reason, one table row per unit. The report then lists only:

  - mismatches with no row (new, review them),
  - rows whose counts moved (the site or the fence changed, review again),
  - rows whose unit now matches or is gone (delete the row).

Run: python3 ci/example-line-counts.py            report
     python3 ci/example-line-counts.py --all      every unit, matched or not
     python3 ci/example-line-counts.py --show <page> <key>
                                                  both snippets side by side
     python3 ci/example-line-counts.py --fetch <dir>
                                                  download the page fragments
                                                  from the docs content origin
                                                  into <dir> and refresh the
                                                  catalog from them (needs
                                                  node and playwright)

Exit status is 1 when the report is not empty, so it can gate CI.
"""

import importlib.util
import os
import re
import subprocess
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
WAIVERS = os.path.join(ROOT, "extension", "test", "line-count-waivers.md")
ORIGIN = "https://d1s9dnlmdewoh1.cloudfront.net/2.03/api/"
FALLBACK = ("C++", "C/C++", "C")
ATTRIBUTE = re.compile(r"^\s*\[[A-Za-z]\w*(?:\([^)]*\))?\]\s*$")

spec = importlib.util.spec_from_file_location("haxe_catalog", os.path.join(HERE, "haxe-catalog.py"))
hc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hc)


def counted_lines(code):
    """The lines that carry content. A line holding only an opening
    brace joins the line before it: C# samples put the brace on its own
    line where the Haxe declarations open on the same line, and that is
    layout, not information. A line holding only a C# attribute
    ([Flags], [StructLayout]) is metadata Haxe has no spelling for. The
    package line a declaration shows (with the blank under it) is the
    tab's own header, not part of the snippet, so it stays out too."""
    lines = code.rstrip("\n").split("\n") if code.strip() else []
    if lines and lines[0].startswith("package "):
        lines = lines[1:]
        while lines and not lines[0].strip():
            lines = lines[1:]
    return [line for line in lines if line.strip() != "{" and not ATTRIBUTE.match(line)]


def line_count(code):
    return len(counted_lines(code))


def shown_text(record):
    """The text the tab shows, as renderExample in content.js builds it."""
    lines = ["// " + note for note in record["notes"]]
    if record["code"] is not None:
        if lines:
            lines.append("")
        lines.append(record["code"])
    return "\n".join(lines)


def site_block(entry):
    if "C#" in entry["blocks"]:
        return "C#", entry["blocks"]["C#"]
    for language in FALLBACK:
        if language in entry["blocks"]:
            return language, entry["blocks"][language]
    language = next(iter(entry["blocks"]), "")
    return language, entry["blocks"].get(language, "")


def collect():
    """[(page, key, language, site lines, haxe lines, site code, haxe code)]
    for every unit the tab shows code for."""
    catalog = hc.read_catalog()
    haxe = hc.read_haxe()
    out = []
    for page, entries in sorted(catalog.items()):
        groups = hc.variant_groups(entries)
        members = {m for ms in groups.values() for m in ms[1:]}
        sections = haxe.get(page, {})
        for key, entry in entries.items():
            if entry["kind"] != "example" or key in members:
                continue
            if key in groups:
                entry = hc.merged_entry(entries, groups[key])
            section = sections.get(key)
            if section is None:
                continue
            record = hc.resolve(section, [], f"{page}: \"{key}\"", hc.is_fmod_type_definition(entry))
            if record is None or record["verdict"] != "bound" or record["code"] is None:
                continue
            shown = shown_text(hc.strip_imports(record))
            language, code = site_block(entry)
            out.append((page, key, language, line_count(code), line_count(shown), code, shown))
    return out


ROW = re.compile(r"^\|\s*(.*?)\s*\|\s*(.*?)\s*\|\s*(.*?)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(.*?)\s*\|$")


def read_waivers():
    """(page, key) -> (language, site lines, haxe lines, reason)"""
    waivers = {}
    if not os.path.exists(WAIVERS):
        return waivers
    with open(WAIVERS, encoding="utf-8") as fh:
        for line in fh:
            row = ROW.match(line.rstrip("\n"))
            if not row or row.group(1) in ("Page", "") or set(row.group(1)) <= {"-"}:
                continue
            waivers[(row.group(1), row.group(2))] = (row.group(3), int(row.group(4)), int(row.group(5)), row.group(6))
    return waivers


def report(units, waivers, everything=False):
    lines = []
    seen = set()
    for page, key, language, site, haxe, _, _ in units:
        waiver = waivers.get((page, key))
        seen.add((page, key))
        if site == haxe:
            if waiver:
                lines.append(f"DELETE  {page} | {key}: counts match now ({site}), drop the waiver row")
            elif everything:
                lines.append(f"ok      {page} | {key}: {language} {site} = Haxe {haxe}")
            continue
        if waiver is None:
            lines.append(f"REVIEW  {page} | {key}: {language} {site} lines, Haxe {haxe} lines")
        elif waiver[1:3] != (site, haxe):
            lines.append(f"MOVED   {page} | {key}: {language} {site} lines, Haxe {haxe} lines "
                         f"(waived at {waiver[1]} and {waiver[2]}: {waiver[3]})")
        elif everything:
            lines.append(f"waived  {page} | {key}: {language} {site} lines, Haxe {haxe} lines: {waiver[3]}")
    for (page, key), waiver in waivers.items():
        if (page, key) not in seen:
            lines.append(f"DELETE  {page} | {key}: no such unit with a Haxe fence any more, drop the waiver row")
    return lines


def show(units, page, key):
    for upage, ukey, language, site, haxe, code, shown in units:
        if upage == page and ukey == key:
            print(f"[{language}] {site} lines counted, {len(code.split(chr(10)))} shown")
            for line in code.split("\n"):
                print("    " + line)
            print(f"[Haxe] {haxe} lines counted, {len(shown.split(chr(10)))} shown")
            for line in shown.split("\n"):
                print("    " + line)
            return 0
    print(f"no unit {page} | {key} with a Haxe fence")
    return 1


def fetch(directory):
    """Every fragment the catalog knows, plus welcome.html, from the docs
    content origin. The crawler then rebuilds the catalog from them."""
    os.makedirs(directory, exist_ok=True)
    catalog_dir = os.path.join(ROOT, "extension", "catalog")
    names = sorted(n[:-3] for n in os.listdir(catalog_dir) if n.endswith(".md"))
    for name in ["welcome"] + names:
        url = ORIGIN + name + ".html"
        target = os.path.join(directory, name + ".html")
        with urllib.request.urlopen(url, timeout=60) as response:
            data = response.read()
        with open(target, "wb") as fh:
            fh.write(data)
        print(f"fetched {name}.html ({len(data)} bytes)")
    return subprocess.call(["node", os.path.join(ROOT, "extension", "test", "catalog-site.js"), "--update", "--from", directory])


def main():
    args = sys.argv[1:]
    if args[:1] == ["--fetch"] and len(args) == 2:
        return fetch(args[1])
    units = collect()
    if args[:1] == ["--show"] and len(args) == 3:
        return show(units, args[1], args[2])
    everything = "--all" in args
    waivers = read_waivers()
    lines = report(units, waivers, everything)
    for line in lines:
        print(line)
    mismatched = sum(1 for u in units if u[3] != u[4])
    pending = sum(1 for line in lines if not line.startswith(("ok", "waived")))
    print(f"line-counts: {len(units)} units compared, {mismatched} with different counts, "
          f"{len(waivers)} waived, {pending} to act on")
    return 1 if pending else 0


if __name__ == "__main__":
    sys.exit(main())
