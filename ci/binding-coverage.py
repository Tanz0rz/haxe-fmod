#!/usr/bin/env python3
"""Binding-coverage lockstep for native/manifest/studio_api.txt.

verify-native proves every manifest function EXISTS in the three shims.
This proves every manifest function is EXERCISED: called somewhere in the
unit tests, the Node wasm harnesses, or the example project's CI test
states - directly, or through a wrapper method in haxefmod/ that those
tests call. A function with no exercise evidence must carry an entry in
ci/binding-coverage-excused.txt with a reason, so coverage can only be
dropped by writing the removal down.

Evidence sources, in order:
  1. Direct call in a test: `<name>(` in tests/*.hx or the example test
     states, or `fmod_<name>(` in tests/js/*.js. arity-audit.js is
     EXCLUDED - it invokes every jaxe export mechanically to check
     arity, which would make this check vacuous.
  2. Wrapper hop: a haxefmod/ method whose body calls
     `NativeStudio.<name>(` counts as exercised when that method's own
     name is called from a test source. Wrapper names shorter than 4
     characters never count as evidence (too generic to grep for).

Run: python3 ci/binding-coverage.py
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(ROOT, "native", "manifest", "studio_api.txt")
EXCUSED = os.path.join(ROOT, "ci", "binding-coverage-excused.txt")

TEST_SOURCES = []
for base, exts in [
    (os.path.join(ROOT, "tests"), (".hx",)),
    (os.path.join(ROOT, "tests", "js"), (".js",)),
    (os.path.join(ROOT, "example-project", "EZPlatformer", "source"), (".hx",)),
]:
    if not os.path.isdir(base):
        continue
    for entry in sorted(os.listdir(base)):
        path = os.path.join(base, entry)
        if os.path.isfile(path) and entry.endswith(exts):
            if entry == "arity-audit.js":
                continue
            TEST_SOURCES.append(path)

WRAPPER_SOURCES = []
for dirpath, _dirnames, filenames in os.walk(os.path.join(ROOT, "haxefmod")):
    for entry in sorted(filenames):
        if entry.endswith(".hx"):
            WRAPPER_SOURCES.append(os.path.join(dirpath, entry))


def read(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def manifest_functions():
    names = []
    for line in read(MANIFEST).splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "->" not in line:
            continue
        names.append(line.split()[0])
    return names


def excused_functions():
    excused = {}
    if not os.path.exists(EXCUSED):
        return excused
    for line in read(EXCUSED).splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        name, _sep, reason = line.partition(" ")
        excused[name] = reason.strip()
    return excused


test_text = {path: read(path) for path in TEST_SOURCES}
wrapper_text = {path: read(path) for path in WRAPPER_SOURCES}

# Wrapper map: manifest name -> set of haxefmod/ method names whose body
# calls NativeStudio.<name>(. The enclosing method is the nearest
# `function <ident>` above the call site.
FUNC_DECL = re.compile(r"function\s+([A-Za-z_]\w*)\s*\(")


def enclosing_functions(source, needle):
    found = set()
    for match in re.finditer(re.escape(needle), source):
        decls = list(FUNC_DECL.finditer(source, 0, match.start()))
        if decls:
            found.add(decls[-1].group(1))
    return found


def called_in_tests(symbol):
    pattern = re.compile(r"\b" + re.escape(symbol) + r"\s*\(")
    return any(pattern.search(text) for text in test_text.values())


failures = []
covered = 0
excused = excused_functions()
names = manifest_functions()
seen_excuses = set()

for name in names:
    # 1. Direct: the prim name itself (Haxe externs and stub share it) or
    # the jaxe export name in a harness
    if called_in_tests(name) or called_in_tests("fmod_" + name):
        covered += 1
        continue
    # 2. Wrapper hop
    wrappers = set()
    for text in wrapper_text.values():
        wrappers |= enclosing_functions(text, "NativeStudio." + name + "(")
    wrappers = {w for w in wrappers if len(w) >= 4}
    if any(called_in_tests(w) for w in wrappers):
        covered += 1
        continue
    if name in excused:
        seen_excuses.add(name)
        continue
    failures.append(name)

stale = [n for n in excused if n not in seen_excuses]
for name in stale:
    if name not in names:
        failures.append(f"[stale excuse: not in manifest] {name}")
    else:
        failures.append(f"[stale excuse: now covered - remove it] {name}")

print(f"binding-coverage: {len(names)} manifest functions, "
      f"{covered} exercised, {len(seen_excuses)} excused")
if failures:
    print()
    for name in failures:
        print(f"FAIL: no exercise evidence and no excuse: {name}"
              if not name.startswith("[") else f"FAIL: {name}")
    print(f"\nbinding-coverage: {len(failures)} FAILURE(S)")
    print("Add a test that calls the function (directly or through its "
          "wrapper), or an excuse line to ci/binding-coverage-excused.txt.")
    sys.exit(1)
print("binding-coverage: every manifest function is exercised or excused")
