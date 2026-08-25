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
  5. linux-html5 asserts a build against a doctored (wrong-version) web
     SDK FAILS with the mismatch banner, with pipefail, since html5 pins
     the web SDK version instead of translating DSP types.

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

# Per-job slices: everything below pairs assertions with their job
jobs_text = text[text.index("\njobs:"):]
job_matches = list(re.finditer(r"^  ([A-Za-z][\w-]*):\s*$", jobs_text, re.M))
jobs = {}
for i, m in enumerate(job_matches):
    end = job_matches[i + 1].start() if i + 1 < len(job_matches) else len(jobs_text)
    jobs[m.group(1)] = jobs_text[m.start():end]
if len(jobs) < 16:
    fail(f"expected at least 16 jobs, found {len(jobs)}")
else:
    ok(f"{len(jobs)} jobs found")

# 1. Tag override leads every [skip-build]-gated job condition. The
# override must be the leading disjunct of the expression, so a negated
# or buried occurrence of the substring does not satisfy the check.
OVERRIDE_LEAD = re.compile(
    r"if:\s*\$\{\{\s*startsWith\(github\.ref, 'refs/tags/'\)\s*\|\|")
gated_jobs = 0
for name, body in jobs.items():
    if name == "update-hdlls":
        continue
    if "[skip-build]" not in body:
        fail(f"job {name} has no skip-build gate at all")
        continue
    gated_jobs += 1
    gate_lines = [l for l in body.splitlines()
                  if l.lstrip().startswith("if:") and "[skip-build]" in l]
    if not gate_lines:
        fail(f"job {name}: skip-build gate is not a single-line if (unverifiable)")
    elif not all(OVERRIDE_LEAD.search(l) for l in gate_lines):
        fail(f"job {name}: gate does not lead with the tag override")
if gated_jobs >= 15:
    ok(f"{gated_jobs} gated jobs all lead with the tag override")
else:
    fail(f"only {gated_jobs} gated jobs found")

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

# 3. Every job declares a job-level timeout (paired per job, so a
# step-level timeout elsewhere cannot mask a job that lost its own)
untimed = [name for name, body in jobs.items()
           if not re.search(r"^    timeout-minutes:", body, re.M)]
if untimed:
    fail(f"jobs without a job-level timeout: {untimed}")
else:
    ok(f"all {len(jobs)} jobs declare job-level timeouts")

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

# 5. linux-html5 requires a FAILING build against a doctored web SDK,
# with pipefail, and verifies the version-mismatch banner (paired to the
# job so a copy of the block elsewhere cannot mask its removal here)
html5_job = jobs.get("linux-html5", "")
web_gate = re.search(
    r'set -o pipefail[\s\S]*?'
    r'if FMOD_SDK_WEB="\$DOCTORED" haxelib run lime build html5 2>&1 \| tee [^\n]*; then\n'
    r'\s*echo "FAIL: build succeeded[^\n]*\n\s*exit 1\n\s*fi', html5_job)
if not web_gate:
    fail("linux-html5 lost the web-SDK mismatch build-must-fail gate (with pipefail)")
else:
    ok("linux-html5 requires the doctored web-SDK build to fail, with pipefail")
if 'grep -q "FMOD web SDK version mismatch"' not in html5_job:
    fail("linux-html5 no longer greps for the web mismatch banner")
else:
    ok("linux-html5 verifies the web mismatch banner text")

print()
if failures:
    print(f"workflow-invariants: {len(failures)} FAILURE(S)")
    sys.exit(1)
print("workflow-invariants: all assertions passed")
