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
     python3 ci/example-line-counts.py --html <file>
                                                  write a page that shows every
                                                  waived unit side by side with
                                                  its reason, for review by eye
     python3 ci/example-line-counts.py --fetch <dir>
                                                  download the page fragments
                                                  from the docs content origin
                                                  into <dir> and refresh the
                                                  catalog from them (needs
                                                  node and playwright)

Exit status is 1 when the report is not empty, so it can gate CI.
"""

import html
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


def html_lines(code):
    """One row per shown line. A line the count leaves out is marked so
    the reader can reconcile the two numbers by eye."""
    counted = counted_lines(code)
    rows = []
    shown = code.rstrip("\n").split("\n") if code.strip() else []
    skipped = len(shown) - len(counted)
    header = 0
    if shown and shown[0].startswith("package "):
        header = 1
        while header < len(shown) and not shown[header].strip():
            header += 1
    for i, line in enumerate(shown):
        out = i < header or line.strip() == "{" or bool(ATTRIBUTE.match(line))
        cls = ' class="out"' if out else ""
        rows.append(f"<span{cls}>{html.escape(line) or ' '}</span>")
    return "\n".join(rows), skipped


def write_html(units, waivers, path):
    by_page = {}
    for page, key, language, site, haxe, code, shown in units:
        waiver = waivers.get((page, key))
        if waiver is None or site == haxe:
            continue
        by_page.setdefault(page, []).append((key, language, site, haxe, code, shown, waiver[3]))
    total = sum(len(v) for v in by_page.values())
    parts = []
    nav = "".join(f'<a href="#{html.escape(page)}">{html.escape(page)}<b>{len(items)}</b></a>' for page, items in by_page.items())
    for page, items in by_page.items():
        parts.append(f'<section id="{html.escape(page)}"><h2>{html.escape(page)}</h2>')
        for key, language, site, haxe, code, shown, reason in items:
            left, left_skipped = html_lines(code)
            right, right_skipped = html_lines(shown)
            note = lambda n: f' <small>({n} not counted)</small>' if n else ""
            parts.append(
                f'<article><h3>{html.escape(key)}</h3><p class="why">{html.escape(reason)}</p>'
                f'<div class="pair"><div><div class="tag site">{html.escape(language)} <span>{site} lines{note(left_skipped)}</span></div>'
                f'<pre>{left}</pre></div>'
                f'<div><div class="tag haxe">Haxe <span>{haxe} lines{note(right_skipped)}</span></div>'
                f'<pre>{right}</pre></div></div></article>')
        parts.append("</section>")
    body = "\n".join(parts)
    page = HTML_PAGE.replace("%TOTAL%", str(total)).replace("%PAGES%", str(len(by_page))).replace("%NAV%", nav).replace("%BODY%", body)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(page)
    print(f"wrote {path}: {total} waived units on {len(by_page)} pages")
    return 0


HTML_PAGE = """<title>Line-count waivers</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans:wght@400;500;600&family=JetBrains+Mono:wght@400;500&display=swap">
<style>
:root { --bg:#f6f7f4; --panel:#ffffff; --ink:#1f2421; --mute:#68716b; --rule:#d8ddd7; --out:#a3aaa4;
        --site:#3d5f80; --site-bg:#e8eef4; --haxe:#b8561a; --haxe-bg:#f8ebe1; --why-bg:#eef1ec; }
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) {
  --bg:#151816; --panel:#1c201d; --ink:#e4e7e1; --mute:#98a19a; --rule:#2d332f; --out:#5d665f;
  --site:#8fb4d6; --site-bg:#1f2b36; --haxe:#e8935a; --haxe-bg:#352419; --why-bg:#22271f; } }
:root[data-theme="dark"] { --bg:#151816; --panel:#1c201d; --ink:#e4e7e1; --mute:#98a19a; --rule:#2d332f; --out:#5d665f;
  --site:#8fb4d6; --site-bg:#1f2b36; --haxe:#e8935a; --haxe-bg:#352419; --why-bg:#22271f; }
body { background:var(--bg); color:var(--ink); font-family:"IBM Plex Sans", system-ui, sans-serif; font-size:14px; line-height:1.5; }
header { padding:28px 32px 20px; border-bottom:1px solid var(--rule); }
header h1 { margin:0 0 6px; font-size:22px; font-weight:600; letter-spacing:-0.01em; }
header p { margin:0; color:var(--mute); max-width:70ch; }
nav { display:flex; flex-wrap:wrap; gap:6px 14px; padding:14px 32px; border-bottom:1px solid var(--rule); position:sticky; top:0; background:var(--bg); z-index:1; }
nav a { color:var(--ink); text-decoration:none; font-size:12.5px; }
nav a b { color:var(--mute); font-weight:500; margin-left:4px; font-variant-numeric:tabular-nums; }
nav a:hover, nav a:focus-visible { color:var(--haxe); outline:none; }
main { padding:8px 32px 60px; }
section h2 { font-size:12px; text-transform:uppercase; letter-spacing:0.08em; color:var(--mute); margin:34px 0 10px; font-weight:600; }
article { border:1px solid var(--rule); background:var(--panel); border-radius:6px; margin:0 0 16px; overflow:hidden; }
article h3 { margin:0; padding:12px 16px 2px; font-size:15px; font-weight:600; text-wrap:balance; }
.why { margin:0; padding:4px 16px 12px; color:var(--mute); max-width:90ch; }
.pair { display:grid; grid-template-columns:1fr 1fr; border-top:1px solid var(--rule); }
.pair > div { min-width:0; }
.pair > div + div { border-left:1px solid var(--rule); }
.tag { font-size:11.5px; font-weight:600; text-transform:uppercase; letter-spacing:0.06em; padding:6px 14px; display:flex; justify-content:space-between; }
.tag span { font-weight:500; text-transform:none; letter-spacing:0; color:var(--mute); font-variant-numeric:tabular-nums; }
.tag small { font-size:11px; }
.tag.site { color:var(--site); background:var(--site-bg); }
.tag.haxe { color:var(--haxe); background:var(--haxe-bg); }
pre { margin:0; padding:10px 0 12px; overflow-x:auto; font-family:"JetBrains Mono", ui-monospace, monospace; font-size:12px; line-height:1.55; counter-reset:ln; }
pre span { display:block; padding:0 14px 0 48px; position:relative; white-space:pre; }
pre span::before { counter-increment:ln; content:counter(ln); position:absolute; left:0; width:34px; text-align:right; color:var(--out); font-variant-numeric:tabular-nums; }
pre span.out { color:var(--out); font-style:italic; }
pre span.out::before { content:"\\00b7"; }
@media (max-width: 860px) { .pair { grid-template-columns:1fr; } .pair > div + div { border-left:0; border-top:1px solid var(--rule); } }
</style>
<header>
  <h1>Line-count waivers</h1>
  <p>%TOTAL% units on %PAGES% pages where the site's snippet and the Haxe tab differ in line count for a stated reason. Dimmed lines are the ones the count leaves out: lone braces, C# attributes, and the package header.</p>
</header>
<nav>%NAV%</nav>
<main>%BODY%</main>
"""


def main():
    args = sys.argv[1:]
    if args[:1] == ["--fetch"] and len(args) == 2:
        return fetch(args[1])
    units = collect()
    if args[:1] == ["--show"] and len(args) == 3:
        return show(units, args[1], args[2])
    everything = "--all" in args
    waivers = read_waivers()
    if args[:1] == ["--html"] and len(args) == 2:
        return write_html(units, waivers, args[1])
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
