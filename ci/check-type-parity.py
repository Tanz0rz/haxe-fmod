#!/usr/bin/env python3
"""Keeps every Haxe declaration of an FMOD type equal to the SDK header.

native/manifest/types.txt maps each FMOD type name to what haxefmod
declares for it:

    FMOD_SPEAKER            haxefmod.studio.Types.FmodSpeaker
    FMOD_SYSTEM_CALLBACK    cannot    runs on FMOD's threads, delivered through StudioSystem.setSystemCallback instead

A line is the FMOD name and a Haxe type path, or the FMOD name, the
word `cannot`, and the reason the type cannot exist on the Haxe side
(it is only ever touched on FMOD's threads, or it belongs to a platform
the library does not ship for). Every other FMOD type has a Haxe
declaration, the same fields and values under the same names. The examples generator turns a type
definition on fmod.com into the Haxe declaration or a comment with the
reason through this table, so the table is the single place that says
how an FMOD type appears on the Haxe side.

This check reads the SDK headers (ci/fmod_headers.py) and fails when:
  - a type in the headers has no line in the table (nothing is allowed
    to be silently absent),
  - a line names a Haxe type that does not exist,
  - an enum or flag family in Haxe is missing a value the header has,
    carries one the header lacks, or gives one a different number,
  - a struct typedef in Haxe is missing a field the header has (extra
    Haxe fields are fine, they are documented conveniences). A field may
    be a property (var data1(get, never):Int) on an abstract.

Value names compare after the prefix is removed: the type's own name
when every value starts with it (FMOD_DSP_CONVOLUTION_REVERB_PARAM_IR
against PARAM_IR), the common prefix otherwise (FMOD_SPEAKER_FRONT_LEFT
against FRONT_LEFT). A header name that would start with a digit may
carry a leading word in Haxe (FMOD_3D against MODE_3D). Struct field
names compare ignoring case and underscores (DecayTime against
decayTime). Enum values and struct fields Haxe leaves out on purpose
are listed in the table line after `skip:`.

Run: python3 ci/check-type-parity.py
"""

import importlib.util
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TABLE = os.path.join(ROOT, "native", "manifest", "types.txt")
CATEGORIES = ("cannot",)


def load_headers():
    spec = importlib.util.spec_from_file_location("fmod_headers", os.path.join(ROOT, "ci", "fmod_headers.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.read_types()


def read_table():
    """fmod name -> {target, reason, skip}"""
    table = {}
    if not os.path.exists(TABLE):
        return table
    with open(TABLE, encoding="utf-8") as fh:
        for raw in fh:
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split(None, 2)
            name = parts[0]
            target = parts[1] if len(parts) > 1 else ""
            rest = parts[2] if len(parts) > 2 else ""
            skip = set()
            match = re.search(r"skip:\s*([\w,]+)", rest)
            if match:
                skip = set(match.group(1).split(","))
                rest = rest[:match.start()].strip()
            table[name] = {"target": target, "reason": rest.strip(), "skip": skip}
    return table


def haxe_declaration(path):
    """(kind, values{name: number}, fields{name}) for a Haxe type path."""
    parts = path.split(".")
    name = parts[-1]
    candidates = [os.path.join(ROOT, *parts) + ".hx"]
    if len(parts) > 1:
        candidates.append(os.path.join(ROOT, *parts[:-1]) + ".hx")
    for file in candidates:
        if not os.path.exists(file):
            continue
        with open(file, encoding="utf-8") as fh:
            text = fh.read()
        match = re.search(r"^(?:@:\w+(?:\([^)]*\))?\s*)*(enum\s+abstract|abstract|class|typedef|enum|interface)\s+" + re.escape(name) + r"\b[^\n]*", text, re.M)
        if not match:
            continue
        brace = text.find("{", match.end() - len(match.group(0)))
        depth = 0
        end = len(text)
        for i in range(brace, len(text)):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    end = i
                    break
        body = text[brace + 1:end]
        body = re.sub(r"/\*.*?\*/", "", body, flags=re.S)
        body = re.sub(r"//[^\n]*", "", body)
        kind = match.group(1).replace(" ", "_")
        values = {}
        fields = set()
        for value in re.finditer(r"^\s*(?:public\s+)?(?:static\s+)?(?:inline\s+)?var\s+(\w+)\s*(?::\s*[\w<>.]+)?\s*=\s*(-?0x[0-9A-Fa-f]+|-?\d+)\s*;", body, re.M):
            values[value.group(1)] = int(value.group(2), 0)
        for field in re.finditer(r"^\s*(?:public\s+)?(?:@:optional\s+)?var\s+(\w+)\s*(?:\([^)]*\))?\s*:", body, re.M):
            fields.add(field.group(1))
        return kind, values, fields
    return None, {}, set()


def normalize(name):
    return re.sub(r"[^a-z0-9]", "", name.lower())


def common_prefix(names):
    if not names:
        return ""
    prefix = names[0]
    for name in names[1:]:
        while not name.startswith(prefix):
            prefix = prefix[:-1]
    # cut back to an underscore boundary
    if "_" in prefix:
        prefix = prefix[:prefix.rfind("_") + 1]
    return prefix


def value_prefix(fmod_name, names):
    own = fmod_name + "_"
    if all(n.startswith(own) for n in names):
        return own
    return common_prefix(names) if len(names) > 1 else own


def compare_values(fmod_name, header_values, haxe_values, skip):
    problems = []
    names = [n for n, _ in header_values]
    prefix = value_prefix(fmod_name, names)
    stripped = {}
    for value_name, number in header_values:
        short = value_name[len(prefix):] if value_name.startswith(prefix) else value_name
        stripped[short] = number
    def haxe_key(name):
        return normalize(name[len(prefix):] if name.startswith(prefix) else name)
    haxe_by_norm = {haxe_key(k): (k, v) for k, v in haxe_values.items()}
    matched = set()
    for short, number in stripped.items():
        if short in skip:
            continue
        key = normalize(short)
        found = haxe_by_norm.get(key)
        if found is None and short[0].isdigit():
            # a Haxe name may carry a leading word where the header value starts with a digit
            for haxe_key_name, entry in haxe_by_norm.items():
                if haxe_key_name.endswith(key):
                    found = entry
                    break
        if found is None:
            problems.append(f"{fmod_name}: header value {prefix}{short} = {number} is missing in Haxe")
            continue
        matched.add(found[0])
        if found[1] != number:
            problems.append(f"{fmod_name}: {found[0]} is {found[1]} in Haxe but {number} in the header")
    header_by_norm = {normalize(k) for k in stripped}
    for haxe_name in haxe_values:
        if haxe_name not in matched and haxe_key(haxe_name) not in header_by_norm:
            problems.append(f"{fmod_name}: Haxe value {haxe_name} has no counterpart in the header")
    return problems


def main():
    headers = load_headers()
    table = read_table()
    problems = []
    mapped = 0
    for fmod_name, entry in sorted(headers.items()):
        line = table.get(fmod_name)
        if line is None:
            problems.append(f"{fmod_name} ({entry['kind']} in {entry['header']}) has no line in native/manifest/types.txt")
            continue
        target = line["target"]
        if target in CATEGORIES:
            if not line["reason"]:
                problems.append(f"{fmod_name}: category {target} needs a reason")
            continue
        kind, values, fields = haxe_declaration(target)
        if kind is None:
            problems.append(f"{fmod_name}: Haxe type {target} not found")
            continue
        mapped += 1
        if entry["kind"] in ("enum", "flags"):
            if not entry["values"]:
                # a bare typedef alias (FMOD_BOOL) has nothing to compare
                continue
            if not values:
                problems.append(f"{fmod_name}: {target} declares no numeric values to compare")
            else:
                problems += compare_values(fmod_name, entry["values"], values, line["skip"])
        elif entry["kind"] == "struct":
            haxe_norm = {normalize(f) for f in fields}
            for _type, field in entry["fields"]:
                if field in line["skip"]:
                    continue
                if normalize(field) not in haxe_norm:
                    problems.append(f"{fmod_name}: field {field} is missing in {target}")
    for name in table:
        if name not in headers:
            problems.append(f"{name} is in native/manifest/types.txt but not in the headers")
    for problem in problems:
        print("FAIL: " + problem)
    print(f"check-type-parity: {len(headers)} header types, {mapped} Haxe declarations compared, {len(problems)} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
