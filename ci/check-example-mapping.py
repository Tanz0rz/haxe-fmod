#!/usr/bin/env python3
"""Compares every Haxe example against the FMOD snippet it stands beside.

The site snapshot records, for each code example on fmod.com, the facts
of the FMOD snippet: for a type definition the members it declares, for
a procedural example the API calls it makes. This check holds the Haxe
side to those facts:

  - a type definition's Haxe declaration must carry every member the
    FMOD snippet lists (compared after prefixes are stripped and case
    and underscores are ignored), unless the types table files the
    type under a category with a reason or lists the member after
    `skip:`,
  - a procedural example's Haxe fence must use, for every FMOD call in
    the snippet that haxefmod binds, one of the Haxe methods the
    bindings table maps that call to, unless the section is note-only
    with a reason. A call haxefmod does not bind is skipped, and a call
    the library makes on the game's behalf (create, init, update,
    release of the systems) is skipped too.

The failures name the page, the example index and heading, and the
missing member or call, so a wrong translation is found by position
rather than by reading the site.

Run: python3 ci/check-example-mapping.py
"""

import importlib.util
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SNAPSHOT = os.path.join(ROOT, "extension", "test", "site-snapshot.json")
BINDINGS = os.path.join(ROOT, "extension", "bindings-data.js")
TYPES_TABLE = os.path.join(ROOT, "native", "manifest", "types.txt")

# Calls the library makes itself, which a translation has no reason to show
LIBRARY_CALLS = {"create", "init", "initialize", "update", "release", "close", "getCoreSystem",
                 "setSoftwareFormat", "setDSPBufferSize", "setOutput", "setCallback", "setUserData",
                 "getUserData", "setFileSystem", "setAdvancedSettings", "getVersion"}


def load(name):
    spec = importlib.util.spec_from_file_location(name, os.path.join(ROOT, "ci", name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def normalize(text):
    return re.sub(r"[^a-z0-9]", "", text.lower())


def declaration_members(code):
    """Names declared in a Haxe declaration: enum values, inline vars,
    typedef fields, class fields."""
    body = re.sub(r"/\*.*?\*/", "", code, flags=re.S)
    body = re.sub(r"//[^\n]*", "", body)
    return set(re.findall(r"^\s*(?:public\s+)?(?:static\s+)?(?:inline\s+)?(?:@:optional\s+)?var\s+(\w+)", body, re.M))


def table_skips():
    """FMOD type name -> normalized member names its table line skips."""
    skips = {}
    if not os.path.exists(TYPES_TABLE):
        return skips
    for raw in open(TYPES_TABLE, encoding="utf-8"):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        match = re.search(r"skip:\s*([\w,]+)", line)
        if match:
            skips[line.split()[0]] = {normalize(s) for s in match.group(1).split(",")}
    return skips


def bindings_by_method():
    """lowercased FMOD method name -> set of Haxe method names that reach it."""
    source = open(BINDINGS, encoding="utf-8").read()
    data = json.loads(source[source.index("{"):source.rindex("}") + 1])
    table = {}
    for key, entry in data["entries"].items():
        fmod_names = entry["fmod"].split(", ") if entry["fmod"] else []
        for fmod_name in fmod_names:
            method = fmod_name.split("_")[-1].lower()
            table.setdefault(method, set()).update(m["name"] for m in entry["haxe"])
    return table


def main():
    examples_module = load("haxe-examples")
    pages = examples_module.build()
    with open(SNAPSHOT, encoding="utf-8") as fh:
        snapshot = json.load(fh)
    methods = bindings_by_method()
    skips = table_skips()
    problems = []
    checked_types = 0
    checked_calls = 0
    for page, data in sorted(snapshot.items()):
        sections = pages.get(page, {})
        default = sections.get("*")
        for example in data.get("examples", []):
            key = str(example["index"])
            section = sections.get(key) or default
            if section is None:
                continue
            label = f"{page}: example {key} ({example['heading']})"
            if example.get("decl"):
                if section.get("category") or section.get("code") is None:
                    continue
                if section.get("shape"):
                    continue
                checked_types += 1
                have = {normalize(m) for m in declaration_members(section["code"])}
                # header prefix of the members, e.g. FMOD_SPEAKER_
                members = example.get("members") or []
                if not members:
                    continue
                type_name = re.search(r"\b((?:FMOD|FSBANK)_[A-Z0-9_]+)\b", example.get("heading", ""))
                own = type_name.group(1) if type_name else ""
                values = [m for m in members if m != own]
                # the type's own name is the prefix when every value starts
                # with it, the common prefix otherwise
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
                    if normalize(member) in skipped:
                        continue
                    short = normalize(member[len(prefix):] if member.startswith(prefix) else member)
                    # MODE_2D stands for FMOD_2D: a Haxe name may carry a
                    # leading word where the header value starts with a digit
                    if short in have or normalize(member) in have:
                        continue
                    if any(h.endswith(short) and short[0].isdigit() for h in have):
                        continue
                    # a lone member on a page keeps its full name, so the Haxe
                    # name is its tail
                    if not prefix and any(normalize(member).endswith(h) for h in have):
                        continue
                    problems.append(f"{label}: Haxe declaration lacks {member}")
            else:
                if section.get("code") is None:
                    continue
                calls = example.get("calls") or []
                if not calls:
                    continue
                fence = section["code"].lower()
                for call in calls:
                    if call in LIBRARY_CALLS:
                        continue
                    haxe_names = methods.get(call.lower())
                    if not haxe_names:
                        continue
                    checked_calls += 1
                    if not any(name.lower() in fence for name in haxe_names) and call.lower() not in fence:
                        problems.append(f"{label}: FMOD calls {call}() but the Haxe example uses none of {sorted(haxe_names)}")
    for problem in problems:
        print("FAIL: " + problem)
    print(f"check-example-mapping: {checked_types} declarations and {checked_calls} calls compared, {len(problems)} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
