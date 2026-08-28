"""Reads the FMOD SDK headers into a table of declared types.

Used by ci/check-type-parity.py (every Haxe declaration mapped to an FMOD
type must carry the same names and values) and by ci/haxe-examples.py
(type definitions on fmod.com resolve through the mapping to the Haxe
declaration). Four kinds of declaration are read:

  enum      typedef enum FMOD_X { A, B = 3, ... } FMOD_X;
  flags     typedef unsigned int FMOD_X; followed by its #define block
  struct    typedef struct FMOD_X { type field; ... } FMOD_X;
  callback  typedef RET (F_CALL *FMOD_X)(...);

The SDK root comes from FMOD_SDK, falling back to the private cache
checkout next to the repo.
"""

import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

HEADERS = [
    "api/core/inc/fmod_common.h",
    "api/core/inc/fmod_dsp.h",
    "api/core/inc/fmod_dsp_effects.h",
    "api/core/inc/fmod_codec.h",
    "api/core/inc/fmod_output.h",
    "api/studio/inc/fmod_studio_common.h",
    "api/fsbank/inc/fsbank.h",
]


def sdk_root():
    root = os.environ.get("FMOD_SDK")
    if root and os.path.isdir(root):
        return root
    cache = os.path.join(os.path.dirname(ROOT), "fmod-sdk-cache", "sdk", "2.03.12", "linux")
    if os.path.isdir(cache):
        return cache
    raise SystemExit("fmod_headers: set FMOD_SDK to an FMOD Engine SDK root")


def strip_comments(text):
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    return re.sub(r"//[^\n]*", "", text)


def parse_value(expr, known):
    expr = expr.strip()
    if expr in known:
        return known[expr]
    try:
        return int(eval(expr, {"__builtins__": {}}, dict(known)))  # header expressions are shifts, ors, hex
    except Exception:
        return None


ENUM = re.compile(r"typedef\s+enum\s*(\w*)\s*\{(.*?)\}\s*(\w+)\s*;", re.S)
STRUCT = re.compile(r"typedef\s+struct\s+(\w+)\s*\{(.*?)\}\s*(\w+)\s*;", re.S)
CALLBACK = re.compile(r"typedef\s+[\w\s\*]+\(\s*F_CALL\s*\*\s*(\w+)\s*\)\s*\(", re.S)
FLAG_TYPE = re.compile(r"typedef\s+unsigned\s+int\s+(\w+)\s*;")
DEFINE = re.compile(r"^\s*#define\s+(\w+)\s+(.+?)\s*$", re.M)


def read_types():
    """name -> {kind, values: [(name, number)], fields: [(type, name)], header}"""
    types = {}
    known = {}
    root = sdk_root()
    for relative in HEADERS:
        path = os.path.join(root, relative)
        if not os.path.exists(path):
            continue
        with open(path, encoding="utf-8", errors="replace") as fh:
            raw = fh.read()
        text = strip_comments(raw)
        for match in ENUM.finditer(text):
            name = match.group(3)
            values = []
            current = -1
            for item in match.group(2).split(","):
                item = item.strip()
                if not item or item.startswith("#"):
                    continue
                if "=" in item:
                    value_name, expr = item.split("=", 1)
                    number = parse_value(expr, known)
                    if number is None:
                        continue
                    current = number
                else:
                    value_name = item
                    current += 1
                value_name = value_name.strip()
                if not re.match(r"^\w+$", value_name):
                    continue
                known[value_name] = current
                # FORCEINT pads the enum to 32 bits and is not a value
                if value_name.endswith("_FORCEINT"):
                    continue
                values.append((value_name, current))
            types[name] = {"kind": "enum", "values": values, "fields": [], "header": relative}
        for match in STRUCT.finditer(text):
            name = match.group(3)
            fields = []
            for line in match.group(2).split(";"):
                line = line.strip()
                if not line:
                    continue
                parts = line.replace("*", " * ").split()
                if len(parts) < 2:
                    continue
                field = parts[-1]
                array = ""
                if "[" in field:
                    field, array = field.split("[", 1)
                    array = "[" + array
                fields.append((" ".join(parts[:-1]), field))
            types[name] = {"kind": "struct", "values": [], "fields": fields, "header": relative}
        for match in CALLBACK.finditer(text):
            types[match.group(1)] = {"kind": "callback", "values": [], "fields": [], "header": relative}
        # flag families: the #define block that follows the typedef
        lines = text.splitlines()
        for index, line in enumerate(lines):
            flag = FLAG_TYPE.match(line.strip())
            if not flag:
                continue
            name = flag.group(1)
            values = []
            j = index + 1
            while j < len(lines) and (DEFINE.match(lines[j]) or lines[j].strip() == ""):
                define = DEFINE.match(lines[j])
                if define:
                    number = parse_value(define.group(2), known)
                    if number is not None:
                        known[define.group(1)] = number
                        values.append((define.group(1), number))
                j += 1
            types[name] = {"kind": "flags", "values": values, "fields": [], "header": relative}
    return types


if __name__ == "__main__":
    table = read_types()
    kinds = {}
    for entry in table.values():
        kinds[entry["kind"]] = kinds.get(entry["kind"], 0) + 1
    print(f"fmod_headers: {len(table)} types {kinds}")
