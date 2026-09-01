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

Function entries take their Haxe side from bindings-data.js. A function
with no binding has a section in extension/functions.md under the
function id holding one verdict line (`cannot`, `covered`, or `library`
with the reason), which the tab shows as a single comment line. A
section never carries a fence or note lines: the tab shows generated
signatures or that one line, nothing hand-written.

Some examples appear on the site once per language, as adjacent lone
blocks under one heading that the selector shows one at a time. Such a
run is one unit: the Haxe side holds a single section under the first
block's key, and a section under a later member's key is an error. The
fold mirrors grouped() in extension/keys.js and only applies to the
languages the site's selector toggles.

The checks fail when:
  - a catalog key has no section (nothing on the site is left blank),
  - a section names a key the catalog does not have (stale entry),
  - a section sits on a later member of a per-language run (the run is
    one unit under its first key),
  - a section has no verdict, or a category verdict has no reason,
  - a bound section has neither a fence nor a Type: line, or a Type:
    line names a type missing from the sources,
  - a type definition on the site (struct, enum, define, callback) has a
    hand-written fence, note lines, a Shape: line, or a library or
    covered verdict (the tab shows the declaration alone, like the C#
    tab shows the struct),
  - a bound Haxe declaration lacks a member the site's snippet declares
    (unless native/manifest/types.txt lists it after skip:),
  - a bound Haxe fence steps outside the site's snippet: a string
    literal the snippet does not contain, a number (other than 0 and 1,
    which C spells for false and true) absent from every language's
    block, a number in the primary block that the fence dropped, an
    FMOD call made out of the snippet's order or not at all, a call the
    snippet never makes, or more statements than the snippet plus two,
  - a waive: line names a check that did not fire (stale waiver),
  - a function entry has neither a binding nor a functions.md section.

A parity check that fires on a translation that is right anyway is
silenced in place with a reason:

    waive: numbers the C example reads the rate from a macro the page defines earlier

The rules are numbers, strings, missing-numbers, calls, extra-calls,
and shape. The reason stays part of the entry, so every deviation from
the site's snippet is explicit and reviewable.

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
DECL = re.compile(r"^(typedef\s+(struct|enum)|enum\s|struct\s|#define\s|typedef\s+\w[\w\s*]*\(|FMOD_RESULT\s+\(F_CALL|\w+\s+F_CALL\s+\w+\()")

SECTION = re.compile(r"^## (.+?)\s*$", re.M)
COMMENT = re.compile(r"<!--(.*?)-->", re.S)
FENCE = re.compile(r"```haxe\n(.*?)```", re.S)
DIRECTIVE = re.compile(r"^(verdict|Type|Shape):\s*(.*?)\s*$", re.M)
WAIVE = re.compile(r"^waive:\s*(\S+)\s+(.+?)\s*$")
PARITY_RULES = ("numbers", "strings", "missing-numbers", "calls", "extra-calls", "shape")


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


# The language names whose blocks the site's selector shows and hides.
# Mirrors SITE_LANGS in extension/keys.js.
GROUP_LANGS = ("C", "C++", "C/C++", "C#", "JavaScript")


def variant_groups(entries):
    """base key -> member keys, for every run of per-language variants:
    adjacent lone example blocks under one heading, each in a different
    site language. Mirrors grouped() in extension/keys.js."""
    items = sorted(entries.items(), key=lambda kv: kv[1]["index"])
    groups = {}
    i = 0
    while i < len(items):
        key, entry = items[i]
        langs = list(entry["blocks"])
        if entry["kind"] != "example" or len(langs) != 1 or langs[0] not in GROUP_LANGS:
            i += 1
            continue
        members = [key]
        seen_langs = {langs[0]}
        j = i + 1
        while j < len(items):
            nkey, nentry = items[j]
            nlangs = list(nentry["blocks"])
            if (nentry["kind"] != "example" or len(nlangs) != 1 or nlangs[0] not in GROUP_LANGS
                    or nentry["heading"] != entry["heading"] or nlangs[0] in seen_langs):
                break
            members.append(nkey)
            seen_langs.add(nlangs[0])
            j += 1
        if len(members) > 1:
            groups[key] = members
        i = j
    return groups


def merged_entry(entries, members):
    """One entry standing for a per-language run: the first member with
    every member's block under its language."""
    base = dict(entries[members[0]])
    blocks = {}
    for member in members:
        for language, code in entries[member]["blocks"].items():
            blocks.setdefault(language, code)
    base["blocks"] = blocks
    return base


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
    """The declaration of a Haxe type as written in its source file, from
    the declaration keyword through the matching closing brace (or the
    semicolon of a typedef alias). The doc comment above it stays out,
    the tab shows code the way the other language tabs do. None when the
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
        section = {"heading": heading, "verdict": None, "reason": "", "notes": [], "code": code, "type": None, "shape": None, "waivers": {}}
        rest = []
        for line in body.splitlines():
            directive = DIRECTIVE.match(line)
            waive = WAIVE.match(line)
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
            elif waive:
                section["waivers"][waive.group(1)] = waive.group(2)
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
        if section["notes"]:
            problems.append(f"{label}: the reason on the verdict line is the whole entry, drop the note lines")
        if type_definition and verdict != "cannot":
            problems.append(f"{label}: a type definition is declared in Haxe or cannot be, verdict {verdict} is not an answer")
        notes = [CATEGORY_TEXT[verdict] + " " + section["reason"]] + section["notes"]
        return {"verdict": verdict, "notes": notes, "code": None, "type": None}
    if verdict != "bound":
        problems.append(f"{label}: unknown verdict {verdict}")
        return None
    if section["notes"]:
        problems.append(f"{label}: a bound entry shows code only, drop the note lines")
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
    if record["type"]:
        # A declaration shows where it lives the way the C# tab prefixes
        # the namespace: as the package line of a Haxe module. The module
        # itself is an import detail the guides cover.
        package = ".".join(record["type"].split(".")[:2])
        shown = dict(record)
        shown["code"] = "package " + package + ";\n\n" + "\n".join(lines)
        shown["type"] = None
        return shown
    types = []
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
    if section["code"] is not None or section["notes"]:
        problems.append(f"{label}: a type definition shows its declaration alone, drop the fence and the note lines")
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


def strip_code_comments(code):
    code = re.sub(r"/\*.*?\*/", " ", code, flags=re.S)
    return re.sub(r"//[^\n]*", "", code)


NUMBER = re.compile(r"(?<![\w.])(\d+\.\d+|\d+)(?=[fFuUlL]*\b)")
STRING = re.compile(r'"((?:[^"\\\n]|\\.)*)"')


def snippet_numbers(code):
    """Numeric literals, as values. 0 and 1 stay out: C spells booleans,
    null handles, and first indices with them, and every language of a
    snippet differs there without the meaning changing. Bracketed
    indices and array sizes ([3]) are structure, not data, and Haxe
    spells them differently or not at all. Hex literals never match,
    both sides skip them the same way."""
    out = set()
    body = re.sub(r"\[\s*\d+\s*\]", "[]", strip_code_comments(code))
    for token in NUMBER.findall(body):
        value = float(token)
        if value not in (0.0, 1.0):
            out.add(value)
    return out


def snippet_strings(code):
    return {s for s in STRING.findall(strip_code_comments(code)) if s.strip()}


def snippet_call_sequence(code):
    """Method calls in snippet order, repeats kept. The C flavor
    (FMOD_Object_Method) counts as its method name, so a C-only snippet
    still yields its calls."""
    out = []
    for dotted, flat in re.findall(r"(?:(?:::|->|\.)\s*([a-z]\w*)|\bFMOD_(?:[A-Za-z0-9]+_)+([A-Z][a-z]\w*))\s*\(", strip_code_comments(code)):
        out.append(dotted or flat)
    return out


def statement_count(code):
    """Semicolons outside comments and strings. Wrapping an argument
    list over lines is layout, a semicolon is a statement in C, C#, JS,
    and Haxe alike."""
    body = strip_code_comments(code)
    body = re.sub(r'"(?:[^"\\\n]|\\.)*"', '""', body)
    body = re.sub(r"^import [^\n]*;", "", body, flags=re.M)
    return body.count(";")


def check_parity(entry, section, record, methods, reverse, problems, label):
    """The fence against the site's snippet: same literals, same calls in
    the same order, no invented work. A finding a reviewer has judged
    right anyway is silenced by a waive: line, and a waive: line whose
    check passes is itself a finding, so the set of deviations stays
    exact in both directions."""
    fence = record["code"]
    fired = set()
    primary = native_snippet(entry)
    all_blocks = list(entry["blocks"].values())

    union_numbers = set().union(*[snippet_numbers(c) for c in all_blocks]) if all_blocks else set()
    union_strings = set().union(*[snippet_strings(c) for c in all_blocks]) if all_blocks else set()
    extra_numbers = snippet_numbers(fence) - union_numbers
    if extra_numbers:
        fired.add("numbers")
        if "numbers" not in section["waivers"]:
            listed = ", ".join(str(int(v)) if v == int(v) else str(v) for v in sorted(extra_numbers))
            problems.append(f"{label}: the fence uses numbers the site's snippet does not have: {listed}")
    extra_strings = snippet_strings(fence) - union_strings
    if extra_strings:
        fired.add("strings")
        if "strings" not in section["waivers"]:
            listed = ", ".join('"' + s + '"' for s in sorted(extra_strings)[:4])
            problems.append(f"{label}: the fence uses strings the site's snippet does not have: {listed}")
    missing_numbers = snippet_numbers(primary) - snippet_numbers(fence)
    if missing_numbers:
        fired.add("missing-numbers")
        if "missing-numbers" not in section["waivers"]:
            listed = ", ".join(str(int(v)) if v == int(v) else str(v) for v in sorted(missing_numbers))
            problems.append(f"{label}: the snippet's numbers {listed} are not in the fence")

    fence_lower = fence.lower()
    position = 0
    for call in snippet_call_sequence(primary):
        if call in LIBRARY_CALLS or call.lower() in {c.lower() for c in LIBRARY_CALLS}:
            continue
        mapped = methods.get(call.lower())
        if not mapped:
            continue
        names = set(mapped) | {call}
        found = -1
        for name in names:
            index = fence_lower.find(name.lower(), position)
            if index >= 0 and (found < 0 or index < found):
                found = index
        if found >= 0:
            position = found + 1
            continue
        fired.add("calls")
        if "calls" not in section["waivers"]:
            anywhere = any(fence_lower.find(name.lower()) >= 0 for name in names)
            how = "out of the snippet's order" if anywhere else "not at all"
            problems.append(f"{label}: the snippet calls {call}() but the fence reaches it {how}")

    native_calls = set()
    for code in all_blocks:
        native_calls.update(c.lower() for c in snippet_call_sequence(code))
    for call in dict.fromkeys(re.findall(r"\.\s*([a-zA-Z_]\w*)\s*\(", strip_code_comments(fence))):
        lowered = call.lower()
        if lowered in native_calls or lowered in {c.lower() for c in LIBRARY_CALLS}:
            continue
        mapped = reverse.get(lowered)
        if not mapped or mapped & native_calls or mapped & {c.lower() for c in LIBRARY_CALLS}:
            continue
        fired.add("extra-calls")
        if "extra-calls" not in section["waivers"]:
            problems.append(f"{label}: the fence calls {call}() but the snippet reaches no FMOD function behind it")

    if statement_count(fence) > statement_count(primary) + 2:
        fired.add("shape")
        if "shape" not in section["waivers"]:
            problems.append(f"{label}: the fence has {statement_count(fence)} statements to the snippet's {statement_count(primary)}, translate what the snippet shows")

    return fired


def check_waivers(section, fired, problems, label):
    for rule, _ in section["waivers"].items():
        if rule not in PARITY_RULES:
            problems.append(f"{label}: waive: {rule} is not a check ({', '.join(PARITY_RULES)})")
        elif rule not in fired:
            problems.append(f"{label}: waive: {rule} but that check passes, delete the line")


def build():
    """(pages for examples-data.js, problems, stats)"""
    catalog = read_catalog()
    haxe = read_haxe()
    functions = read_functions()
    bindings = read_bindings()
    methods = bindings_by_method(bindings)
    reverse = {}
    for method, names in methods.items():
        for name in names:
            reverse.setdefault(name.lower(), set()).add(method)
    skips = table_skips()
    problems = []
    stats = {"functions": 0, "examples": 0, "groups": 0, "types": 0, "compared": 0, "bound": 0, "categorized": 0}
    output = {}
    for page, entries in sorted(catalog.items()):
        sections = haxe.get(page, {})
        groups = variant_groups(entries)
        stats["groups"] += len(groups)
        member_of = {}
        for base, members in groups.items():
            for member in members[1:]:
                member_of[member] = base
        for key in sections:
            if key not in entries:
                problems.append(f"{page}: section \"{key}\" names a key the catalog does not have")
            elif key in member_of:
                problems.append(f"{page}: \"{key}\" is a per-language variant of \"{member_of[key]}\", the run is one unit under that key")
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
            if key in member_of:
                continue
            if key in groups:
                entry = merged_entry(entries, groups[key])
            section = sections.get(key)
            if section is None:
                problems.append(f"{label}: no section in extension/haxe/{page}.md")
                continue
            record = resolve(section, problems, label, is_fmod_type_definition(entry))
            if record is None:
                continue
            output.setdefault(page, {})[key] = strip_imports(record)
            fired = set()
            if record["verdict"] == "bound":
                stats["bound"] += 1
                if is_fmod_type_definition(entry):
                    stats["types"] += check_type_definition(entry, section, record, skips, problems, label)
                elif section["code"] is not None:
                    fired = check_parity(entry, section, record, methods, reverse, problems, label)
                    stats["compared"] += 1
            else:
                stats["categorized"] += 1
            check_waivers(section, fired, problems, label)
    for page in haxe:
        if page not in catalog:
            problems.append(f"extension/haxe/{page}.md has no catalog page")
    for key, section in functions.items():
        if not any(key in entries for entries in catalog.values()):
            problems.append(f"functions.md: \"{key}\" is not a function on any catalog page")
        elif section["verdict"] is None:
            problems.append(f"functions.md: \"{key}\": no verdict line")
        # A function entry shows its generated signatures, or one comment line
        # with the reason it has none. The notes file never carries code or prose.
        if section["code"] is not None or section["notes"] or section["waivers"]:
            problems.append(f"functions.md: \"{key}\": a function section is a verdict line only, drop the fence and the note lines")
        if section["verdict"] == "bound":
            problems.append(f"functions.md: \"{key}\": bound is implied by the bindings table, a section is for cannot, covered, or library")
        binding = bindings.get(key)
        if section["verdict"] in ("cannot", "covered") and binding and binding["haxe"]:
            problems.append(f"functions.md: \"{key}\": says {section['verdict']} but the bindings table reaches it, delete the section")
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
    print(f"haxe-catalog: {stats['functions']} function entries and {stats['examples']} other code locations "
          f"({stats['groups']} per-language runs), {stats['bound']} bound, {stats['categorized']} with a reason, "
          f"{stats['types']} declarations and {stats['compared']} fences compared, {len(problems)} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
