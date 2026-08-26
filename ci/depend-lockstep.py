#!/usr/bin/env python3
"""hxcpp compile-cache depend lockstep.

The cpp CI jobs cache compiled objects (HXCPP_COMPILE_CACHE), and the
cache key hashes source contents plus declared <depend> files ONLY. A
header linc_faxe.cpp includes without a matching <depend> in
linc_faxe.xml reopens a stale-object hole: header-only edits reuse
outdated cached objects and ship silently wrong binaries. This has
happened before - now it fails the build instead.

Run: python3 ci/depend-lockstep.py
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CPP = os.path.join(ROOT, "native", "faxe", "linc_faxe.cpp")
XML = os.path.join(ROOT, "native", "faxe", "linc_faxe.xml")

with open(CPP, encoding="utf-8") as fh:
    includes = re.findall(r'#include "([^"]+)"', fh.read())
with open(XML, encoding="utf-8") as fh:
    depends = re.findall(r'<depend name="\$\{LINC_FAXE_PATH\}/([^"]+)"', fh.read())

failures = []
checked = 0
for include in includes:
    # Includes are relative to native/faxe/; depends to the library root
    normalized = os.path.normpath(os.path.join("native", "faxe", include))
    normalized = normalized.replace(os.sep, "/")
    checked += 1
    if normalized not in depends:
        failures.append(f"{include} (expected <depend> for {normalized})")

stale = [d for d in depends
         if not os.path.exists(os.path.join(ROOT, d))]

print(f"depend-lockstep: {checked} includes in linc_faxe.cpp, {len(depends)} depends declared")
if failures:
    for failure in failures:
        print(f"FAIL: linc_faxe.cpp includes a header with no <depend>: {failure}")
if stale:
    for entry in stale:
        print(f"FAIL: linc_faxe.xml declares a <depend> for a missing file: {entry}")
if failures or stale:
    print(f"\ndepend-lockstep: {len(failures) + len(stale)} FAILURE(S)")
    sys.exit(1)
print("depend-lockstep: every included header is a declared depend")
