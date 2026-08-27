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

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# The one deliberately different version: the compat jobs and the DSP
# translation test pin FMOD 2.02.33 to prove cross-version behavior.
COMPAT_VERSION = "2.02.33"

SCANNED = [
    "haxefmod/tools/Run.hx",
    "haxefmod/tools/PostBuild.hx",
    "haxefmod/tools/BuildCheck.hx",
    "haxefmod/tools/BuildHdll.hx",
    "README.md",
    "CHANGELOG.md",
    ".github/workflows/audio-test.yml",
    ".github/workflows/canary.yml",
    ".github/workflows/stress-test.yml",
    ".github/workflows/release-smoke.yml",
]

# FMOD versions are always major.minor(2).patch(2), e.g. 2.03.12. Other
# dotted triples in these files (haxe/lime/openfl/flixel versions, SDL)
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

for rel in SCANNED:
    path = os.path.join(ROOT, rel)
    if not os.path.exists(path):
        failures.append(f"{rel}: scanned file missing")
        continue
    with open(path, encoding="utf-8") as fh:
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

print(f"version-lockstep: expected {expected} (from fmod_expected_version), "
      f"compat {COMPAT_VERSION}, {found_expected} expected-version literals")
if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    print(f"\nversion-lockstep: {len(failures)} FAILURE(S)")
    sys.exit(1)
print("version-lockstep: all FMOD version literals are current")
