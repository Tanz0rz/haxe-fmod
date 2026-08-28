#!/usr/bin/env python3
"""Builds and checks the Haxe side of every code location on fmod.com.

extension/catalog/<page>.md (written by extension/test/catalog-site.js)
lists every code block on a page of the FMOD API reference under a key
(see extension/keys.js) with the snippet of each language the site
shows. extension/haxe/<page>.md holds the Haxe side for the blocks that
are not function entries, one section per key:

    ## FMOD_STUDIO_TIMELINE_BEAT_PROPERTIES
    verdict: bound
    Type: haxefmod.studio.Types.FmodTimelineBeatProperties

    ## 10.2 Extracting PCM Data from a Sound
    verdict: bound
    A note shown as comment lines above the code, one per line.
    ```haxe
    var read = sound.readData(buffer);
    ```

    ## FMOD_CODEC_DESCRIPTION
    verdict: cannot Codec plug-ins run on FMOD's threads, no Haxe target can host them.

`verdict:` is required. `bound` means the fence or the `Type:` line is
the Haxe equivalent (a `Type:` line copies the declaration out of the
sources, so a struct or enum shown on the page cannot drift from the
library). `cannot`, `library`, and `covered` carry a reason and mean no
Haxe code stands for the block, the reason is shown as a comment. A
type definition (struct, enum, define block, callback typedef) accepts
only `bound` with a `Type:` line or `cannot` with the reason it cannot
exist on the Haxe side: every FMOD type the game can touch has a Haxe
declaration with the same members. `library` and `covered` are for
examples where the library performs the step or another call is the
Haxe form of it. A type definition is one shown under an FMOD_ heading
of the API reference, a guide example that opens with a helper struct
of its own is an example and takes a fence.

Function entries take their Haxe side from bindings-data.js and their
notes from extension/functions.md, whose sections use the same format
under the function id.

The checks fail when:
  - a catalog key has no section (nothing on the site is left blank),
  - a section names a key the catalog does not have (stale entry),
  - a section has no verdict, or a category verdict has no reason,
  - a bound section has neither a fence nor a Type: line, or a Type:
    line names a type missing from the sources,
  - a type definition on the site (struct, enum, define, callback) has a
    hand-written fence, a Shape: line, or a library or covered verdict,
  - a bound Haxe declaration lacks a member the site's snippet declares
    (unless native/manifest/types.txt lists it after skip:),
  - a bound Haxe fence uses none of the Haxe methods that reach an FMOD
    call the site's snippet makes,
  - a function entry has neither a binding nor a functions.md section.

Run: python3 ci/haxe-catalog.py          rewrite extension/examples-data.js
     python3 ci/haxe-catalog.py --check  fail if it is out of date or a
                                         check above fails
"""

import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CATALOG_DIR = os.path.join(ROOT, "extension", "catalog")
HAXE_DIR = os.path.join(ROOT, "extension", "haxe")
FUNCTIONS_MD = os.path.join(ROOT, "extension", "functions.md")
DATA_JS = os.path.join(ROOT, "extension", "examples-data.js")
BINDINGS_JS = os.path.join(ROOT, "extension", "bindings-data.js")
TYPES_TABLE = os.path.join(ROOT, "native", "manifest", "types.txt")

CATEGORIES = ("cannot", "library", "covered")
CATEGORY_TEXT = {
    "cannot": "Cannot be bound.",
    "library": "No Haxe declaration, the library owns this choice.",
    "covered": "No Haxe declaration, another call plays this role.",
}
# Calls the library makes itself, which a translation has no reason to show
LIBRARY_CALLS = {"create", "init", "initialize", "update", "release", "close", "getCoreSystem",
                 "setSoftwareFormat", "setDSPBufferSize", "setOutput", "setCallback", "setUserData",
                 "getUserData", "setFileSystem", "setAdvancedSettings", "getVersion"}
DECL = re.compile(r"^(typedef\s+(struct|enum)|enum\s|struct\s|#define\s|typedef\s+\w[\w\s*]*\(|FMOD_RESULT\s+\(F_CALL)")

SECTION = re.compile(r"^## (.+?)\s*$", re.M)
COMMENT = re.compile(r"<!--(.*?)-->", re.S)
FENCE = re.compile(r"```haxe\n(.*?)```", re.S)
DIRECTIVE = re.compile(r"^(verdict|Type|Shape):\s*(.*?)\s*$", re.M)


def read(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def normalize(text):
    return re.sub(r"[^a-z0-9]", "", text.lower())


# ---------------------------------------------------------------- catalog

def parse_catalog(text):
    """key -> {kind, index, heading, blocks: {language: code}}"""
    entries = {}
    matches = list(SECTION.finditer(text))
    for i, match in enumerate(matches):
        end = matches[i + 1].start() if i + 1 < len(matches) else len(text)
        body = text[match.end():end]
        entry = {"kind": "", "index": -1, "heading": "", "blocks": {}}
        for line in body.splitlines():
            if line.startswith("kind: "):
                entry["kind"] = line[6:]
            elif line.startswith("index: "):
                entry["index"] = int(line[7:])
            elif line.startswith("heading: "):
                entry["heading"] = line[9:]
        for block in re.finditer(r"^### (.+?)\n```\w*\n(.*?)\n?```", body, re.S | re.M):
            entry["blocks"][block.group(1)] = block.group(2)
        entries[match.group(1)] = entry
    return entries


def read_catalog():
    pages = {}
    if not os.path.isdir(CATALOG_DIR):
        return pages
    for name in sorted(os.listdir(CATALOG_DIR)):
        if name.endswith(".md"):
            pages[name[:-3]] = parse_catalog(read(os.path.join(CATALOG_DIR, name)))
    return pages


def native_snippet(entry):
    """The C++ snippet, or the shared C/C++ one, or C as a last resort."""
    blocks = entry["blocks"]
    for language in ("C++", "C/C++", "C"):
        if language in blocks:
            return blocks[language]
    return next(iter(blocks.values()), "")


def is_type_definition(code):
    first = code.strip().split("\n")[0].strip() if code.strip() else ""
    return bool(DECL.match(first))


def is_fmod_type_definition(entry):
    """An FMOD type shown under its own heading on an API reference page.
    A guide example that opens with a helper struct of its own (a context
    the sample threads through a callback) is an example, not a type."""
    if not re.search(r"\b(?:FMOD|FSBANK)_[A-Z0-9_]+\b", entry["heading"]):
        return False
    return is_type_definition(native_snippet(entry))


def snippet_members(code):
    """Members a type definition declares: struct fields or enum values."""
    body = re.sub(r"/\*.*?\*/", "", code, flags=re.S)
    body = re.sub(r"//[^\n]*", "", body)
    first = code.strip().split("\n")[0].strip()
    if re.match(r"^(typedef\s+struct|struct\s)", first):
        return re.findall(r"\b([A-Za-z_]\w*)\s*(?:\[[^\]]*\])?\s*;", body)
    names = re.findall(r"\b((?:FMOD|FSBANK)_[A-Z0-9_]+)\b", body)
    out = []
    for name in names:
        if name not in out and name not in first:
            out.append(name)
    return out


def snippet_calls(code):
    body = re.sub(r"/\*.*?\*/", "", code, flags=re.S)
    body = re.sub(r"//[^\n]*", "", body)
    calls = re.findall(r"(?:::|->|\.)\s*([a-z]\w*)\s*\(", body)
    out = []
    for call in calls:
        if call not in out:
            out.append(call)
    return out


# ------------------------------------------------------------- haxe side

def declaration_of(path):
    """The declaration of a Haxe type as written in its source file:
    from the doc comment or the declaration keyword through the matching
    closing brace (or the semicolon of a typedef alias). None when the
    type is not in the sources."""
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
    return None


def parse_sections(text):
    """key -> {heading, verdict, reason, notes, code, type, shape}"""
    sections = {}
    matches = list(SECTION.finditer(text))
    for i, match in enumerate(matches):
        key = match.group(1)
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
        section = {"heading": heading, "verdict": None, "reason": "", "notes": [], "code": code, "type": None, "shape": None}
        rest = []
        for line in body.splitlines():
            directive = DIRECTIVE.match(line)
            if directive:
                name, value = directive.group(1), directive.group(2)
                if name == "verdict":
                    parts = value.split(None, 1)
                    section["verdict"] = parts[0] if parts else ""
                    section["reason"] = parts[1] if len(parts) > 1 else ""
                elif name == "Type":
                    section["type"] = value
                else:
                    section["shape"] = value
            elif line.strip():
                rest.append(line.strip())
        section["notes"] = rest
        sections[key] = section
    return sections


def read_haxe():
    pages = {}
    if not os.path.isdir(HAXE_DIR):
        return pages
    for name in sorted(os.listdir(HAXE_DIR)):
        if name.endswith(".md"):
            pages[name[:-3]] = parse_sections(read(os.path.join(HAXE_DIR, name)))
    return pages


def read_functions():
    return parse_sections(read(FUNCTIONS_MD)) if os.path.exists(FUNCTIONS_MD) else {}


def read_bindings():
    if not os.path.exists(BINDINGS_JS):
        return {}
    source = read(BINDINGS_JS)
    return json.loads(source[source.index("{"):source.rindex("}") + 1])["entries"]


def bindings_by_method(bindings):
    """lowercased FMOD method name -> Haxe method names that reach it."""
    table = {}
    for entry in bindings.values():
        for fmod_name in (entry["fmod"].split(", ") if entry["fmod"] else []):
            table.setdefault(fmod_name.split("_")[-1].lower(), set()).update(m["name"] for m in entry["haxe"])
    return table


def table_skips():
    skips = {}
    if not os.path.exists(TYPES_TABLE):
        return skips
    for raw in read(TYPES_TABLE).splitlines():
        match = re.search(r"skip:\s*([\w,]+)", raw)
        if match and not raw.startswith("#"):
            skips[raw.split()[0]] = {normalize(s) for s in match.group(1).split(",")}
    return skips


def declaration_members(code):
    body = re.sub(r"/\*.*?\*/", "", code, flags=re.S)
    body = re.sub(r"//[^\n]*", "", body)
    return set(re.findall(r"^\s*(?:public\s+)?(?:static\s+)?(?:inline\s+)?(?:@:optional\s+)?var\s+(\w+)", body, re.M))


# ---------------------------------------------------------------- output

def resolve(section, problems, label, type_definition=False):
    """The record the extension shows for a section."""
    verdict = section["verdict"]
    if verdict is None or verdict == "":
        problems.append(f"{label}: no verdict line")
        return None
    if verdict in CATEGORIES:
        if not section["reason"]:
            problems.append(f"{label}: verdict {verdict} needs a reason")
        if type_definition and verdict != "cannot":
            problems.append(f"{label}: a type definition is declared in Haxe or cannot be, verdict {verdict} is not an answer")
        notes = [CATEGORY_TEXT[verdict] + " " + section["reason"]] + section["notes"]
        return {"verdict": verdict, "notes": notes, "code": None, "type": None}
    if verdict != "bound":
        problems.append(f"{label}: unknown verdict {verdict}")
        return None
    code = section["code"]
    if section["type"]:
        declared = declaration_of(section["type"])
        if declared is None:
            problems.append(f"{label}: Type: {section['type']} is not in the sources")
            return None
        if code is None:
            code = declared
    if code is None:
        problems.append(f"{label}: verdict bound with neither a haxe fence nor a Type: line")
        return None
    return {"verdict": "bound", "notes": section["notes"], "code": code, "type": section["type"]}


def strip_imports(record):
    """The fence keeps its import lines so it compiles, the tab shows the
    imported type paths under the code the way function entries do."""
    if record["code"] is None:
        return record
    lines = record["code"].split("\n")
    types = [record["type"]] if record["type"] else []
    while lines and (lines[0].startswith("import ") or lines[0].strip() == ""):
        line = lines.pop(0).strip()
        if line.startswith("import "):
            types.append(line[len("import "):].rstrip(";").strip())
    shown = dict(record)
    shown["code"] = "\n".join(lines)
    shown["type"] = ", ".join(types) if types else None
    return shown


def check_type_definition(entry, section, record, skips, problems, label):
    if section["shape"]:
        problems.append(f"{label}: Shape: lines are not accepted, a type definition shows its Haxe declaration through a Type: line")
        return 0
    if section["type"] is None:
        problems.append(f"{label}: a type definition on the site needs a Type: line, not a hand-written fence")
        return 0
    members = snippet_members(native_snippet(entry))
    if not members:
        return 1
    have = {normalize(m) for m in declaration_members(record["code"])}
    heading = entry["heading"]
    match = re.search(r"\b((?:FMOD|FSBANK)_[A-Z0-9_]+)\b", heading)
    own = match.group(1) if match else ""
    values = [m for m in members if m != own]
    if own and values and all(v.startswith(own + "_") for v in values):
        prefix = own + "_"
    else:
        prefix = os.path.commonprefix(members) if len(members) > 1 else ""
        if "_" in prefix:
            prefix = prefix[:prefix.rfind("_") + 1]
    skipped = skips.get(own, set())
    for member in members:
        if member.endswith("_FORCEINT") or member.endswith("_MAX") or member == own:
            continue
        short = normalize(member[len(prefix):] if member.startswith(prefix) else member)
        # types.txt lists skips by their short name (the value without the
        # family prefix), the full define name is accepted too
        if normalize(member) in skipped or short in skipped:
            continue
        if short in have or normalize(member) in have:
            continue
        if any(h.endswith(short) and short[0].isdigit() for h in have):
            continue
        if not prefix and any(normalize(member).endswith(h) for h in have):
            continue
        problems.append(f"{label}: Haxe declaration lacks {member}")
    return 1


def check_calls(entry, record, methods, problems, label):
    fence = record["code"].lower()
    checked = 0
    for call in snippet_calls(native_snippet(entry)):
        if call in LIBRARY_CALLS:
            continue
        haxe_names = methods.get(call.lower())
        if not haxe_names:
            continue
        checked += 1
        if not any(name.lower() in fence for name in haxe_names) and call.lower() not in fence:
            problems.append(f"{label}: FMOD calls {call}() but the Haxe code uses none of {sorted(haxe_names)}")
    return checked


def build():
    """(pages for examples-data.js, problems, stats)"""
    catalog = read_catalog()
    haxe = read_haxe()
    functions = read_functions()
    bindings = read_bindings()
    methods = bindings_by_method(bindings)
    skips = table_skips()
    problems = []
    stats = {"functions": 0, "examples": 0, "types": 0, "calls": 0, "bound": 0, "categorized": 0}
    output = {}
    for page, entries in sorted(catalog.items()):
        sections = haxe.get(page, {})
        for key in sections:
            if key not in entries:
                problems.append(f"{page}: section \"{key}\" names a key the catalog does not have")
        for key, entry in entries.items():
            label = f"{page}: \"{key}\""
            if entry["kind"] == "function":
                stats["functions"] += 1
                binding = bindings.get(key)
                section = functions.get(key)
                if section is not None:
                    record = resolve(section, problems, f"functions.md: \"{key}\"")
                    if record and record["verdict"] == "bound":
                        stats["bound"] += 1
                    elif record:
                        stats["categorized"] += 1
                elif binding and binding["haxe"]:
                    stats["bound"] += 1
                else:
                    problems.append(f"{label}: no binding and no functions.md section")
                continue
            stats["examples"] += 1
            section = sections.get(key)
            if section is None:
                problems.append(f"{label}: no section in extension/haxe/{page}.md")
                continue
            record = resolve(section, problems, label, is_fmod_type_definition(entry))
            if record is None:
                continue
            output.setdefault(page, {})[key] = strip_imports(record)
            if record["verdict"] != "bound":
                stats["categorized"] += 1
                continue
            stats["bound"] += 1
            if is_fmod_type_definition(entry):
                stats["types"] += check_type_definition(entry, section, record, skips, problems, label)
            else:
                stats["calls"] += check_calls(entry, record, methods, problems, label)
    for page in haxe:
        if page not in catalog:
            problems.append(f"extension/haxe/{page}.md has no catalog page")
    for key, section in functions.items():
        if not any(key in entries for entries in catalog.values()):
            problems.append(f"functions.md: \"{key}\" is not a function on any catalog page")
        elif section["verdict"] is None:
            problems.append(f"functions.md: \"{key}\": no verdict line")
    return output, problems, stats


def render(pages):
    body = json.dumps(pages, indent=1, sort_keys=True)
    return ("// Generated by ci/haxe-catalog.py from extension/haxe/*.md.\n"
            "// Do not edit by hand.\n"
            f"const HAXEFMOD_EXAMPLES = {body};\n")


def main():
    check = "--check" in sys.argv[1:]
    pages, problems, stats = build()
    for problem in problems:
        print("FAIL: " + problem)
    content = render(pages)
    current = read(DATA_JS) if os.path.exists(DATA_JS) else None
    if current != content:
        if check:
            print("haxe-catalog: extension/examples-data.js is out of date (run python3 ci/haxe-catalog.py)")
            problems.append("stale")
        else:
            with open(DATA_JS, "w", encoding="utf-8") as fh:
                fh.write(content)
            print("wrote extension/examples-data.js")
    print(f"haxe-catalog: {stats['functions']} function entries and {stats['examples']} other code locations, "
          f"{stats['bound']} bound, {stats['categorized']} with a reason, {stats['types']} declarations and "
          f"{stats['calls']} calls compared, {len(problems)} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
