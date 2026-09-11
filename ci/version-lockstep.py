#!/usr/bin/env python3
"""FMOD version literal lockstep.

fmod_expected_version (BCD hex, e.g. 0x00020312 = 2.03.12) is the
machine-read source of truth: PostBuild, BuildCheck, and build-hdll gate
on it. But the doctor, the README, and the workflows carry the same
version as dotted string literals. On an SDK bump those literals go
stale: the doctor would demand the wrong version while builds gate on
the file.

This asserts every FMOD-version-shaped literal in the scanned files is
either the expected version or the declared compat-test version. A bump
then flags every leftover literal until each is updated.

Run: python3 ci/version-lockstep.py
"""

import io
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# The one deliberately different version: the compat jobs and the DSP
# translation test pin FMOD 2.02.33 to prove cross-version behavior.
COMPAT_VERSION = "2.02.33"

# Every tracked text file is scanned. A file that carries another FMOD
# version on purpose is listed here with its reason.
EXEMPT = {
    "tests/TestVersionParsing.hx": "parses version strings of other releases",
}


def tracked_files():
    out = subprocess.run(["git", "ls-files", "-z"], cwd=ROOT, check=True,
                         capture_output=True).stdout
    return [p for p in out.decode("utf-8").split("\0") if p]

# FMOD versions are always major.minor(2).patch(2), e.g. 2.03.12. Other
# dotted triples in the tree (haxe/lime/openfl/flixel versions, SDL)
# do not match the two-digit shape.
FMOD_VERSION = re.compile(r"\b\d\.\d{2}\.\d{2}\b")


def expected_version():
    with open(os.path.join(ROOT, "fmod_expected_version")) as fh:
        hex_version = fh.read().strip()
    match = re.fullmatch(r"0x(\d{4})(\d{2})(\d{2})", hex_version)
    if not match:
        print(f"FAIL: fmod_expected_version is not BCD hex: {hex_version}")
        sys.exit(1)
    product, major, minor = match.groups()
    return f"{int(product)}.{major}.{minor}"


expected = expected_version()
allowed = {expected, COMPAT_VERSION}
failures = []
found_expected = 0

scanned = 0
for rel in tracked_files():
    if rel in EXEMPT:
        continue
    path = os.path.join(ROOT, rel)
    if not os.path.isfile(path):
        continue
    try:
        with open(path, encoding="utf-8") as raw:
            text = raw.read()
    except UnicodeDecodeError:
        continue  # a binary file carries no version literal to keep
    scanned += 1
    with io.StringIO(text) as fh:
        for number, line in enumerate(fh, 1):
            for literal in FMOD_VERSION.findall(line):
                if literal == expected:
                    found_expected += 1
                elif literal not in allowed:
                    failures.append(
                        f"{rel}:{number}: stale FMOD version literal {literal} "
                        f"(expected {expected} or compat {COMPAT_VERSION})")

if found_expected == 0:
    failures.append(
        f"no file states the expected version {expected} at all - "
        "the scan list or the regex is broken")

# The library version reaches three files. The tag gate compares them
# late, this compares them on every push.
import json
lib_version = json.load(open(os.path.join(ROOT, "haxelib.json")))["version"]
manifest_version = json.load(open(os.path.join(ROOT, "extension", "manifest.json")))["version"]
if manifest_version != lib_version:
    failures.append(f"extension/manifest.json version {manifest_version} differs from haxelib.json {lib_version}")
with open(os.path.join(ROOT, "extension", "haxefmod-fmod-docs.user.js")) as fh:
    script_version = re.search(r"^// @version\s+(\S+)", fh.read(), re.M)
script_version = script_version.group(1) if script_version else None
if script_version != lib_version:
    failures.append(f"the userscript @version {script_version} differs from haxelib.json {lib_version}")

print(f"version-lockstep: expected {expected} (from fmod_expected_version), "
      f"compat {COMPAT_VERSION}, {found_expected} expected-version literals in {scanned} files, library {lib_version}")
if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    print(f"\nversion-lockstep: {len(failures)} FAILURE(S)")
    sys.exit(1)
print("version-lockstep: all FMOD version literals are current")
