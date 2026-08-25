#!/usr/bin/env python3
"""Structural invariants for .github/workflows/audio-test.yml.

The release-path gating lives in workflow expressions that nothing
compiles or type-checks, so regressions there are silent until a tag or
compat run goes wrong. This asserts the load-bearing properties:

  1. Every [skip-build]-gated job condition carries the tag override, so
     a release tag on an hdll auto-commit still runs the full suite.
  2. update-hdlls runs only on branch refs (a tag checkout is a detached
     HEAD with no branch to push to, and Windows hdll builds are not
     byte-reproducible, so the push would always be attempted and fail).
  3. Every job has a timeout.
  4. The compat jobs assert the mismatched build FAILS (not just that a
     banner appeared in a zero-exit build), with pipefail set explicitly
     because only the Windows jobs' shell declaration implies it.

Run: python3 ci/workflow-invariants.py [workflow-file]
"""

import re
import sys

PATH = sys.argv[1] if len(sys.argv) > 1 else ".github/workflows/audio-test.yml"
TAG_OVERRIDE = "startsWith(github.ref, 'refs/tags/')"
failures = []


def fail(message):
    failures.append(message)
    print(f"FAIL: {message}")


def ok(message):
    print(f"ok: {message}")


with open(PATH) as fh:
    text = fh.read()

# 1. Tag override on every [skip-build]-gated job condition
gated = [
    line for line in text.splitlines()
    if line.lstrip().startswith("if:") and "[skip-build]" in line
]
if len(gated) < 15:
    fail(f"expected at least 15 skip-build gated job conditions, found {len(gated)}")
else:
    ok(f"{len(gated)} skip-build gated job conditions found")
missing = [line.strip()[:80] for line in gated if TAG_OVERRIDE not in line]
if missing:
    fail(f"{len(missing)} gated conditions lack the tag override: {missing[0]}...")
else:
    ok("every gated condition carries the tag override")

# 2. update-hdlls guarded to branch refs
match = re.search(r"update-hdlls:.*?(?=\n  \S|\Z)", text, re.S)
if not match:
    fail("update-hdlls job not found")
else:
    job = match.group(0)
    if "startsWith(github.ref, 'refs/heads/')" not in job:
        fail("update-hdlls does not require a branch ref")
    else:
        ok("update-hdlls requires a branch ref")
    if "timeout-minutes" not in job:
        fail("update-hdlls has no timeout")
    else:
        ok("update-hdlls has a timeout")

# 3. Every job has a timeout (scan only below the jobs: key, so trigger
# names under on: are not counted as jobs)
jobs_section = text[text.index("\njobs:"):]
job_names = re.findall(r"^  ([a-z][a-z0-9-]*):\s*$", jobs_section, re.M)
timeouts = text.count("timeout-minutes:")
if timeouts < len(job_names):
    fail(f"{len(job_names)} jobs but only {timeouts} timeout-minutes declarations")
else:
    ok(f"all {len(job_names)} jobs declare timeouts")

# 4. Compat jobs require a FAILING mismatch build, with pipefail
mismatch_blocks = re.findall(
    r"set -o pipefail\n\s*if haxelib run lime build hl 2>&1 \| tee [^\n]*; then\n"
    r"\s*echo \"ERROR[^\n]*\n\s*exit 1\n\s*fi", text)
if len(mismatch_blocks) != 3:
    fail(f"expected 3 compat build-must-fail gates with pipefail, found {len(mismatch_blocks)}")
else:
    ok("all 3 compat jobs require the mismatched build to fail, with pipefail")
if text.count('grep -q "FMOD SDK version mismatch"') < 3:
    fail("compat jobs no longer grep for the mismatch banner")
else:
    ok("compat jobs still verify the mismatch banner text")

print()
if failures:
    print(f"workflow-invariants: {len(failures)} FAILURE(S)")
    sys.exit(1)
print("workflow-invariants: all assertions passed")
