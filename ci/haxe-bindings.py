#!/usr/bin/env python3
"""Builds the FMOD-function-to-haxefmod-method table from the sources.

The table drives two artifacts:

  extension/bindings-data.js   the data the fmod.com docs extension injects
                               as a "Haxe" language tab on every API page
  extension/haxefmod-fmod-docs.user.js
                               the same data and script as one userscript
  docs/coverage.md             the coverage matrix page of the docs site
  docs/unsupported.md          every FMOD function haxefmod does not expose,
                               with the reason, from extension/functions.md

The chain is FMOD function <- native shim function <- Haxe wrapper method:

  1. native/hlaxe/hlaxe_fmod.c: each HL_NAME(<native>) body (and the
     static helpers it calls) names the FMOD_* functions it invokes.
  2. haxefmod/**/*.hx: each public method names the NativeStudio.<native>
     calls in its body.
  3. native/jaxe/jaxe.js: a fmod_<native> body that can report
     ERR_UNSUPPORTED marks the entry as limited on HTML5.

Functions the shim never calls still get an entry when
extension/functions.md has a section for them (same format as the
example files, keyed by the fmod.com heading id): lifecycle calls the
library makes on the game's behalf, settings that FmodSettings covers,
and features that are deliberately left out, each with a note and an
optional Haxe fence.

Keys are the ids fmod.com gives function headings: the C name without
its FMOD_ prefix, lowercased (FMOD_Studio_EventInstance_Start becomes
studio_eventinstance_start). Channel and ChannelGroup functions are also
filed under the shared channelcontrol_* page.

Run: python3 ci/haxe-bindings.py          rewrite both artifacts
     python3 ci/haxe-bindings.py --check  fail if either is out of date
"""

import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHIM = os.path.join(ROOT, "native", "hlaxe", "hlaxe_fmod.c")
JAXE = os.path.join(ROOT, "native", "jaxe", "jaxe.js")
HAXE_ROOT = os.path.join(ROOT, "haxefmod")
DATA_JS = os.path.join(ROOT, "extension", "bindings-data.js")
COVERAGE_MD = os.path.join(ROOT, "docs", "coverage.md")
FUNCTIONS_MD = os.path.join(ROOT, "extension", "functions.md")
UNSUPPORTED_MD = os.path.join(ROOT, "docs", "unsupported.md")
CONTENT_JS = os.path.join(ROOT, "extension", "content.js")
USERSCRIPT = os.path.join(ROOT, "extension", "haxefmod-fmod-docs.user.js")

SKIP_PACKAGES = ("haxefmod/studio/native", "haxefmod/tools")
# Public for the library's own layering, not part of the API games call
INTERNAL_TYPES = {"CallbackDispatcher", "ChannelCallbacks", "FmodSettingsResolver", "AttachedInstances"}

FMOD_CALL = re.compile(r"\b(FMOD_(?:Studio_)?[A-Z][A-Za-z0-9]*_[A-Z][A-Za-z0-9]*)\s*\(")
# Types and macros that look like calls but are not API functions
NOT_FUNCTIONS = {"FMOD_Studio_ParseID"}


def read(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def body_after(text, open_index):
    """The text between the brace at open_index and its match."""
    depth = 0
    for i in range(open_index, len(text)):
        c = text[i]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return text[open_index + 1:i]
    return text[open_index + 1:]


def haxelib_version():
    with open(os.path.join(ROOT, "haxelib.json"), encoding="utf-8") as fh:
        return json.load(fh)["version"]


def fmod_version():
    """The marker file holds FMOD's BCD version (0x00020312 is 2.03.12)."""
    raw = read(os.path.join(ROOT, "fmod_expected_version")).strip()
    value = int(raw, 16)
    return f"{value >> 16:x}.{(value >> 8) & 0xFF:02x}.{value & 0xFF:02x}"


# --- native shim ---------------------------------------------------------

C_FUNCTION = re.compile(
    r"^(?:static\s+)?(?:HL_PRIM\s+)?[A-Za-z_][\w\s\*]*?\b(?:HL_NAME\((\w+)\)|(\w+))\s*\([^;{)]*\)\s*\{",
    re.M)


def shim_functions():
    """native name -> set of FMOD functions reached from its body."""
    text = read(SHIM)
    bodies = {}
    natives = []
    for match in C_FUNCTION.finditer(text):
        native, plain = match.group(1), match.group(2)
        name = native or plain
        body = body_after(text, match.end() - 1)
        bodies[name] = body
        if native:
            natives.append(native)

    def reach(name, seen):
        found = set()
        body = bodies.get(name, "")
        for call in FMOD_CALL.findall(body):
            if call not in NOT_FUNCTIONS:
                found.add(call)
        for helper in re.findall(r"\b([a-z][A-Za-z0-9_]*)\s*\(", body):
            if helper in bodies and helper not in seen and helper != name:
                seen.add(helper)
                found |= reach(helper, seen)
        return found

    return {native: reach(native, {native}) for native in natives}


# --- html5 shim ----------------------------------------------------------

def html5_limited():
    text = read(JAXE)
    limited = set()
    for match in re.finditer(r"^\s*static fmod_(\w+)\s*\([^)]*\)\s*\{", text, re.M):
        body = body_after(text, match.end() - 1)
        if "ERR_UNSUPPORTED" in body:
            limited.add(match.group(1))
    return limited


# --- haxe wrappers -------------------------------------------------------

TYPE_DECL = re.compile(r"^(?:@:\w+(?:\([^)]*\))?\s*)*(?:enum\s+)?(class|abstract|typedef|interface)\s+(\w+)", re.M)
FUNCTION = re.compile(
    r"(?:/\*\*(?P<doc>(?:(?!\*/).)*)\*/\s*)?(?:@:\w+(?:\([^)]*\))?\s*)*"
    r"(?:override\s+)?public\s+(?P<static>static\s+)?(?:inline\s+)?(?:override\s+)?"
    r"function\s+(?P<name>\w+)\s*(?P<generics><[^>]*>)?\s*\((?P<args>(?:[^()]|\([^()]*\))*)\)",
    re.S)


def return_type_and_body(text, index):
    """Reads an optional `:Type` after the argument list, then the body.
    Anonymous structures put braces inside the type, so the body brace is
    the first one at angle-bracket depth zero that does not follow a
    colon, comma, or opening bracket."""
    i = index
    while i < len(text) and text[i].isspace():
        i += 1
    ret_start = None
    if i < len(text) and text[i] == ":":
        ret_start = i + 1
    depth = 0
    previous = ""
    while i < len(text):
        c = text[i]
        if c == "<":
            depth += 1
        elif c == ">" and text[i - 1] != "-":
            depth -= 1
        elif c == "{":
            if depth == 0 and previous not in (":", ",", "<", "("):
                ret = text[ret_start:i].strip() if ret_start is not None else "Void"
                return ret, body_after(text, i)
            # a brace inside the type: skip its contents
            inner = body_after(text, i)
            i += len(inner) + 2
            previous = "}"
            continue
        elif c == ";":
            return None, None
        if not c.isspace():
            previous = c
        i += 1
    return None, None
NATIVE_CALL = re.compile(r"\bNativeStudio\.(\w+)\s*\(")
GATE_OPEN = "#if (macro || (js && !haxefmod_html5_allow_unsupported))"


def gated_ranges(text):
    """Character ranges of the real (#else) branches of the HTML5 gate, so
    a method declared inside one is known to be a compile error on js."""
    ranges = []
    depth = 0
    gate_depth = -1
    start = None
    pos = 0
    for line in text.splitlines(keepends=True):
        stripped = line.strip()
        if stripped.startswith("#if"):
            depth += 1
            if stripped == GATE_OPEN:
                gate_depth = depth
        elif stripped.startswith("#else") and depth == gate_depth:
            start = pos
        elif stripped.startswith("#end"):
            if depth == gate_depth:
                if start is not None:
                    ranges.append((start, pos))
                start = None
                gate_depth = -1
            depth -= 1
        pos += len(line)
    return ranges


def first_sentence(doc):
    if not doc:
        return ""
    text = " ".join(line.strip().lstrip("*").strip() for line in doc.strip().splitlines())
    text = re.sub(r"\s+", " ", text).strip()
    text = re.sub(r"`", "", text)
    match = re.match(r"(.+?[.!?])(\s|$)", text)
    return (match.group(1) if match else text).strip()


def haxe_methods():
    """native name -> list of wrapper entries."""
    wrappers = {}
    # Public methods with no NativeStudio call of their own. They inherit
    # the natives of a static wrapper they call (one hop), which is how
    # EventInstance.setCallback reaches the dispatcher's registration.
    indirect = []
    static_natives = {}
    for dirpath, _dirnames, filenames in os.walk(HAXE_ROOT):
        rel = os.path.relpath(dirpath, ROOT).replace(os.sep, "/")
        if rel.startswith(SKIP_PACKAGES):
            continue
        for filename in sorted(filenames):
            if not filename.endswith(".hx"):
                continue
            path = os.path.join(dirpath, filename)
            text = read(path)
            package = rel.replace("/", ".")
            type_starts = [(m.start(), m.group(2)) for m in TYPE_DECL.finditer(text)]
            gates = gated_ranges(text)
            for match in FUNCTION.finditer(text):
                type_name = None
                for start, name in type_starts:
                    if start < match.start():
                        type_name = name
                if type_name is None:
                    continue
                ret, body = return_type_and_body(text, match.end())
                if body is None:
                    continue
                natives = sorted(set(NATIVE_CALL.findall(body)))
                args = re.sub(r"\s+", " ", match.group("args").strip())
                if not natives:
                    indirect.append((package, type_name, match, args, ret, body))
                    continue
                if match.group("static"):
                    static_natives[(type_name, match.group("name"))] = natives
                # Internal types still resolve the hop for the public
                # methods that call them, but never appear themselves
                if type_name in INTERNAL_TYPES:
                    continue
                entry = {
                    "type": f"{package}.{type_name}",
                    "name": match.group("name"),
                    "static": bool(match.group("static")),
                    "signature": f"{match.group('name')}({args}):{ret}",
                    "doc": first_sentence(match.group("doc")),
                    "gated": any(a <= match.start() < b for a, b in gates),
                }
                for native in natives:
                    wrappers.setdefault(native, []).append(entry)
    for package, type_name, match, args, ret, body in indirect:
        if type_name in INTERNAL_TYPES:
            continue
        natives = set()
        for callee_type, callee in re.findall(r"\b([A-Z]\w*)\.(\w+)\s*\(", body):
            natives |= set(static_natives.get((callee_type, callee), []))
        if not natives:
            continue
        entry = {
            "type": f"{package}.{type_name}",
            "name": match.group("name"),
            "static": bool(match.group("static")),
            "signature": f"{match.group('name')}({args}):{ret}",
            "doc": first_sentence(match.group("doc")),
        }
        for native in sorted(natives):
            wrappers.setdefault(native, []).append(entry)
    return wrappers


# --- table ---------------------------------------------------------------

def page_key(fmod_name):
    return fmod_name[len("FMOD_"):].lower()


def build_table():
    shim = shim_functions()
    wrappers = haxe_methods()
    limited = html5_limited()

    entries = {}
    for native, fmod_names in shim.items():
        methods = wrappers.get(native, [])
        for fmod_name in fmod_names:
            entry = entries.setdefault(fmod_name, {"fmod": fmod_name, "natives": set(), "haxe": [], "html5": False})
            entry["natives"].add(native)
            # Only a native dedicated to this one FMOD function marks it.
            # A helper that reaches several functions (programmer sound
            # assignment touches SetCallback) says nothing about them.
            if native in limited and len(fmod_names) == 1:
                entry["html5"] = True
            for method in methods:
                if method not in entry["haxe"]:
                    entry["haxe"].append(method)

    table = {}
    for fmod_name, entry in sorted(entries.items()):
        # A wrapper named like the FMOD function is the direct binding.
        # Helpers that reach the same function (a 2D convenience, a
        # facade method) follow it, and the typed layer precedes the
        # facade and runtime.
        method_name = fmod_name.split("_")[-1].lower()
        entry["haxe"].sort(key=lambda m: (
            0 if m["name"].lower() == method_name else 1,
            0 if m["type"].startswith(("haxefmod.studio.", "haxefmod.core.")) else 1,
            m["type"], m["name"]))
        for m in entry["haxe"]:
            m["direct"] = m["name"].lower() == method_name
        record = {
            "fmod": fmod_name,
            "haxe": entry["haxe"],
            "html5": entry["html5"],
            "gated": any(m.get("gated") for m in entry["haxe"]),
        }
        table[page_key(fmod_name)] = record
        # Channel and ChannelGroup share the ChannelControl reference page
        for prefix in ("FMOD_Channel_", "FMOD_ChannelGroup_"):
            if fmod_name.startswith(prefix):
                alias = "channelcontrol_" + fmod_name[len(prefix):].lower()
                merged = table.setdefault(alias, {"fmod": [], "haxe": [], "html5": False, "gated": False})
                if isinstance(merged["fmod"], list):
                    merged["fmod"].append(fmod_name)
                    for method in entry["haxe"]:
                        if method not in merged["haxe"]:
                            merged["haxe"].append(method)
                    merged["html5"] = merged["html5"] or entry["html5"]
                    merged["gated"] = merged["gated"] or any(m.get("gated") for m in entry["haxe"])
    for record in table.values():
        if isinstance(record["fmod"], list):
            record["fmod"] = ", ".join(record["fmod"])
    return table


def function_notes():
    """Hand-written sections from extension/functions.md, keyed by id."""
    if not os.path.exists(FUNCTIONS_MD):
        return {}
    import importlib.util
    spec = importlib.util.spec_from_file_location(
        "haxe_catalog", os.path.join(ROOT, "ci", "haxe-catalog.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    sections = module.parse_sections(read(FUNCTIONS_MD))
    # a category verdict is shown as its text and reason, ahead of the notes
    for section in sections.values():
        verdict = section.get("verdict")
        if verdict in module.CATEGORY_TEXT:
            section["notes"] = [module.CATEGORY_TEXT[verdict] + " " + section["reason"]] + section["notes"]
    return sections


def merge_notes(table):
    for key, section in function_notes().items():
        record = table.setdefault(key, {"fmod": "", "haxe": [], "html5": False})
        record["notes"] = section["notes"]
        record["heading"] = section["heading"]
        if section["code"] is not None:
            record["code"] = section["code"]
    return table


# --- artifacts -----------------------------------------------------------

def render_data_js(table):
    payload = {
        "haxefmod": haxelib_version(),
        "fmod": fmod_version(),
        "entries": table,
    }
    body = json.dumps(payload, indent=1, sort_keys=True)
    return ("// Generated by ci/haxe-bindings.py from the native shim and the\n"
            "// Haxe wrappers. Do not edit by hand.\n"
            f"const HAXEFMOD_BINDINGS = {body};\n")


def render_userscript(table):
    header = "\n".join([
        "// ==UserScript==",
        "// @name         haxefmod for FMOD docs",
        "// @namespace    https://github.com/Tanz0rz/haxe-fmod",
        f"// @version      {haxelib_version()}",
        "// @description  Adds a Haxe tab to the FMOD API reference showing the haxefmod method for every function.",
        "// @match        https://www.fmod.com/docs/*",
        "// @match        https://fmod.com/docs/*",
        "// @grant        none",
        "// @run-at       document-idle",
        "// ==/UserScript==",
        "",
    ])
    css = read(os.path.join(ROOT, "extension", "content.css"))
    style = ("(function () {\n    var style = document.createElement(\"style\");\n"
             "    style.textContent = " + json.dumps(css) + ";\n"
             "    document.documentElement.appendChild(style);\n})();\n")
    examples_path = os.path.join(ROOT, "extension", "examples-data.js")
    examples = read(examples_path) if os.path.exists(examples_path) else ""
    keys = read(os.path.join(ROOT, "extension", "keys.js"))
    return header + "\n" + keys + "\n" + render_data_js(table) + "\n" + examples + "\n" + style + "\n" + read(CONTENT_JS)


def render_coverage_md(table):
    groups = {}
    for key, record in table.items():
        if key.startswith("channelcontrol_") or not record["fmod"]:
            continue
        fmod_name = record["fmod"]
        parts = fmod_name.split("_")
        owner = "Studio::" + parts[2] if parts[1] == "Studio" else parts[1]
        groups.setdefault(owner, []).append(record)

    lines = [
        "# Coverage",
        "",
        f"Every FMOD function the native layer calls, with the haxefmod methods that reach it. Generated from the sources by `ci/haxe-bindings.py` for haxefmod {haxelib_version()} against FMOD {fmod_version()}. Functions absent from this list are not exposed, see [Limitations](limitations.md).",
        "",
        "The same table powers the browser extension that adds a Haxe tab to the [fmod.com API reference](https://www.fmod.com/docs/2.03/api/welcome.html). In the HTML5 column, \"compile error\" marks a call a js build refuses unless the project sets `-D haxefmod_html5_allow_unsupported`, after which it returns `FMOD_ERR_UNSUPPORTED` at runtime, and \"limited\" marks a call the web build only partly supports.",
        "",
    ]
    total = 0
    for owner in sorted(groups):
        records = sorted(groups[owner], key=lambda r: r["fmod"])
        total += len(records)
        lines += [f"## {owner}", "", "| FMOD | haxefmod | HTML5 |", "|---|---|---|"]
        for record in records:
            methods = record["haxe"]
            if methods:
                cell = "<br>".join(
                    f"`{m['type'].split('.')[-1]}.{m['name']}`" for m in methods)
            else:
                cell = "internal"
            html5 = "compile error" if record.get("gated") else ("limited" if record["html5"] else "")
            lines.append(f"| `{record['fmod']}` | {cell} | {html5} |")
        lines.append("")
    lines.insert(4, f"{total} FMOD functions are reached.")
    lines.insert(5, "")
    return "\n".join(lines) + "\n"


def owner_of(key, heading):
    """The FMOD object a function belongs to, from its heading
    (Studio::EventInstance::start gives Studio::EventInstance)."""
    if heading and "::" in heading:
        return heading.rsplit("::", 1)[0]
    return "Global functions"


def render_unsupported_md(table):
    """Functions with neither a binding nor an equivalent call, grouped by
    FMOD object, each with the note that says why."""
    groups = {}
    for key, record in table.items():
        if record["haxe"] or record.get("code") is not None:
            continue
        groups.setdefault(owner_of(key, record.get("heading")), []).append((key, record))
    total = sum(len(g) for g in groups.values())
    lines = [
        "# Unsupported functions",
        "",
        f"The {total} functions of the FMOD API that haxefmod {haxelib_version()} cannot bind, with the reason for each. Nearly all of them hand FMOD a callback to run on its own threads, which no Haxe target can host, and the rest belong to platforms the library does not ship for or return raw pointers. Generated from `extension/functions.md` by `ci/haxe-bindings.py`, so this page and the Haxe tab of the browser extension always agree. [Coverage](coverage.md) lists everything that is bound.",
        "",
        "If one of these blocks a real use case, open an issue describing it. A workaround at the library level is sometimes possible even when the function itself is not.",
        "",
    ]
    for owner in sorted(groups, key=str.lower):
        lines += [f"## {owner}", "", "| Function | Why |", "|---|---|"]
        for key, record in sorted(groups[owner]):
            name = record.get("heading") or key
            note = " ".join(record.get("notes") or []).replace("|", "\\|")
            if note.startswith("Not exposed."):
                note = note[len("Not exposed."):].strip()
            lines.append(f"| `{name}` | {note} |")
        lines.append("")
    return "\n".join(lines) + "\n"


def main():
    check = "--check" in sys.argv[1:]
    table = merge_notes(build_table())
    outputs = {
        DATA_JS: render_data_js(table),
        USERSCRIPT: render_userscript(table),
        COVERAGE_MD: render_coverage_md(table),
        UNSUPPORTED_MD: render_unsupported_md(table),
    }
    stale = []
    for path, content in outputs.items():
        current = read(path) if os.path.exists(path) else None
        if current == content:
            continue
        if check:
            stale.append(os.path.relpath(path, ROOT))
        else:
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(content)
            print(f"wrote {os.path.relpath(path, ROOT)}")
    bound = sum(1 for k, r in table.items() if r["haxe"] and not k.startswith("channelcontrol_"))
    total = sum(1 for k, r in table.items() if r["fmod"] and not k.startswith("channelcontrol_"))
    noted = sum(1 for r in table.values() if not r["fmod"])
    print(f"haxe-bindings: {total} FMOD functions, {bound} reachable from a public Haxe method, {noted} more covered by notes")
    if stale:
        print("haxe-bindings: out of date: " + ", ".join(stale) + " (run python3 ci/haxe-bindings.py)")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
