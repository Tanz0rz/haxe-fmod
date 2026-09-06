#!/usr/bin/env python3
"""Writes the module pages dox links to but does not generate.

dox renders one page per type and links each type to the module it was
declared in. A module that holds several types (haxefmod.studio.Types,
haxefmod.core.DspParameters, ...) has no page of its own, so those links
were dead. This reads the type XML dox consumed, finds every module of
the documented package whose name differs from its types, and writes a
page per module listing the types it declares, in the shell of the
package index so it looks like the rest of the reference.

Usage: python3 ci/api-module-pages.py <types.xml> <site-api dir> [package]
"""

import html
import os
import re
import sys

# Opening tag of a documented type in Haxe's --xml output, attributes in
# any order (the output is not well-formed enough for an XML parser)
TYPE_TAG = re.compile(r'<(class|typedef|abstract|enum)\b([^>]*)>')
ATTR = re.compile(r'(\w+)="([^"]*)"')
DOC = re.compile(r'<haxe_doc><!\[CDATA\[(.*?)\]\]></haxe_doc>', re.S)


def main():
    xml_path, out = sys.argv[1], sys.argv[2]
    package = sys.argv[3] if len(sys.argv) > 3 else "haxefmod"
    text = open(xml_path, encoding="utf-8", errors="replace").read()
    modules = {}
    for match in TYPE_TAG.finditer(text):
        attrs = dict(ATTR.findall(match.group(2)))
        path = attrs.get("path", "")
        module = attrs.get("module")
        if not module or not path.startswith(package + ".") or module == path:
            continue
        if not module.startswith(package + "."):
            continue
        doc = DOC.search(text, match.end(), match.end() + 4000)
        summary = doc.group(1).strip().split("\n")[0].strip() if doc else ""
        modules.setdefault(module, []).append((path, match.group(1), summary))
    written = 0
    for module, types in sorted(modules.items()):
        parts = module.split(".")
        page = os.path.join(out, *parts) + ".html"
        if os.path.exists(page):
            continue
        package_index = os.path.join(out, *parts[:-1], "index.html")
        if not os.path.exists(package_index):
            continue
        shell = open(package_index, encoding="utf-8").read()
        head = shell[:shell.index("<h1>")]
        tail = shell[shell.index("</table>") + len("</table>"):]
        head = head.replace("<title>" + ".".join(parts[:-1]) + " - ", "<title>" + module + " - ")
        rows = []
        for path, kind, summary in sorted(types):
            name = path.split(".")[-1]
            href = "/".join(path.split(".")[-1:]) + ".html"
            # dox writes no page for private types and abstract
            # implementation classes, so they are not listed either
            if not os.path.exists(os.path.join(out, *path.split(".")) + ".html"):
                continue
            rows.append(f'<tr class="{html.escape(kind)}"><td style="width:200px;"><a href="{html.escape(href)}" title="{html.escape(path)}">{html.escape(name)}</a></td><td><p>{html.escape(summary)}</p></td></tr>')
        body = (f"<h1>{html.escape(module)}</h1><p>Module of package "
                f'<a href="index.html" title="{html.escape(".".join(parts[:-1]))}">{html.escape(".".join(parts[:-1]))}</a>, declaring the types below. '
                f"Import the module (<code>import {html.escape(module)};</code>) to use all of them.</p>"
                f'<table class="table table-condensed"><tbody>{"".join(rows)}</tbody></table>')
        with open(page, "w", encoding="utf-8") as fh:
            fh.write(head + body + tail)
        written += 1
        print(f"api-module-pages: {module} ({len(types)} types)")
    print(f"api-module-pages: {written} module page(s) written")


if __name__ == "__main__":
    main()
