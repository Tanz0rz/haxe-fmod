#!/usr/bin/env python3
"""Structural invariants for .github/workflows/audio-test.yml.

The release-path gating lives in workflow expressions that nothing
compiles or type-checks, so regressions there are silent until a tag or
compat run goes wrong. This asserts the properties everything else
leans on:

  1. Every [skip-build]-gated job condition carries the tag override, so
     a release tag on an hdll auto-commit still runs the full suite.
  2. update-hdlls runs only on branch refs (a tag checkout is a detached
     HEAD with no branch to push to, and Windows hdll builds are not
     byte-reproducible, so the push would always be attempted and fail).
  3. Every job has a timeout.
  4. The compat jobs assert the mismatched build FAILS (not just that a
     banner appeared in a zero-exit build), with pipefail set explicitly
     because only the Windows jobs' shell declaration implies it.
  5. linux-html5-chromium asserts a build against a doctored (wrong-version) web
     SDK FAILS with the mismatch banner, with pipefail, since html5 pins
     the web SDK version instead of translating DSP types.
  6. Every job still contains its required test steps by name. Renaming
     or deleting a probe step means updating the list here in the same
     commit.
  7. Every Node harness in tests/js/ is invoked somewhere in the
     workflow.

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

# 5. linux-html5-chromium requires a FAILING build against a doctored web SDK,
# with pipefail, and verifies the version-mismatch banner (paired to the
# job so a copy of the block elsewhere cannot mask its removal here)
html5_job = jobs.get("linux-html5-chromium-build", "")
web_gate = re.search(
    r'set -o pipefail[\s\S]*?'
    r'if FMOD_SDK_WEB="\$DOCTORED" haxelib run lime build html5 2>&1 \| tee [^\n]*; then\n'
    r'\s*echo "FAIL: build succeeded[^\n]*\n\s*exit 1\n\s*fi', html5_job)
if not web_gate:
    fail("linux-html5-chromium-build lost the web-SDK mismatch build-must-fail gate (with pipefail)")
else:
    ok("linux-html5-chromium-build requires the doctored web-SDK build to fail, with pipefail")
if 'grep -q "FMOD web SDK version mismatch"' not in html5_job:
    fail("linux-html5-chromium-build no longer greps for the web mismatch banner")
else:
    ok("linux-html5-chromium-build verifies the web mismatch banner text")

# 6. Required test steps per job. Names must match the workflow's
# `- name:` lines exactly. When a step is renamed on purpose, rename it
# here in the same commit.
NATIVE_SUITE = ["Run api-probe state", "Run synth-test state", "Run cb-test state",
                "Run ps-test state", "Run bank-test state", "Run pan-test state",
                "Validate audio", "Validate volume/mute", "Validate synth audio",
                "Validate build output"]
REQUIRED_STEPS = {
    "unit-tests": [
        "Run unit tests",
        "Verify native shims match the FFI manifest",
        "Check binding coverage against the manifest",
        "Check workflow gating invariants",
        "Test native handle table (C99 and C++ modes)",
        "Test native callback queue (C99 and C++ modes)",
        "Test native GUID helpers (C99 and C++ modes)",
        "Test native PCM ring buffer (C99 and C++ modes)",
        "Negative-test the synth frequency gate",
        "Constants generator parity (CLI vs FMOD Studio script)",
        "Todo scanner end to end",
        "Run native tests under AddressSanitizer and UBSan",
        "Run threaded native tests under ThreadSanitizer",
        "Test define-driven settings (haxefmod_* and -debug)",
        "Check FMOD version literal lockstep",
        "Check hxcpp depend lockstep",
        "Compile the README examples",
    ],
    "linux-cpp-build": ["Build C++ target", "Verify FMOD libraries have no executable stack", "Validate build output", "Build the test DSP plugin next to the game"],
    "linux-cpp-build-manual": ["Build manual-update variant", "Validate build output", "Build the test DSP plugin next to the game"],
    "linux-cpp": ["Record audio", "Validate audio", "Validate game log", "Record volume test", "Validate volume/mute", "Run api-probe state", "Run synth-test state", "Validate synth audio", "Run cb-test state", "Run ps-test state", "Run bank-test state", "Run pan-test state", "Run api-probe state (manual update variant)"],
    "linux-hl-build": ["Build HashLink target (pre-built hdll)", "Build custom hdll via build-hdll", "Rebuild HashLink target (custom hdll)", "Upload compiled hdll", "Verify FMOD libraries have no executable stack", "Debug bin directory contents", "Validate build output", "Stage FMOD runtime into a plain directory", "Build the test DSP plugin next to the game", "lime test end to end"],
    "linux-hl": ["Record audio", "Validate audio", "Validate game log", "Record volume test", "Validate volume/mute", "Run api-probe state", "Run synth-test state", "Validate synth audio", "Run cb-test state", "Run ps-test state", "Run bank-test state", "Run pan-test state", "Run stress-test state (smoke)"],
    "mac-cpp-build": ["Build C++ target", "Validate build output", "Test native headers with Apple clang (sanitizers)"],
    "mac-cpp": ["Record audio via FMOD wavwriter", "Validate audio", "Validate game log", "Record volume test", "Validate volume/mute", "Run api-probe state", "Run synth-test state", "Validate synth audio", "Run cb-test state", "Run ps-test state", "Run bank-test state", "Run pan-test state"],
    "mac-hl-build": ["Build HashLink target (pre-built hdll)", "Build custom hdll via build-hdll", "Rebuild HashLink target (custom hdll)", "Upload compiled hdll", "Validate build output"],
    "mac-hl": ["Record audio via FMOD wavwriter", "Validate audio", "Validate game log", "Record volume test", "Validate volume/mute", "Run api-probe state", "Run synth-test state", "Validate synth audio", "Run cb-test state", "Run ps-test state", "Run bank-test state", "Run pan-test state"],
    "windows-cpp-build": ["Build C++ target", "Validate build output", "Test native headers with MSVC (C and C++ modes)"],
    "windows-cpp": ["Record audio via FMOD wavwriter", "Fix WAV header", "Validate audio", "Validate game log", "Record volume test", "Fix volume test WAV header", "Validate volume/mute", "Run api-probe state", "Run synth-test state", "Validate synth audio", "Run cb-test state", "Run ps-test state", "Run bank-test state", "Run pan-test state"],
    "windows-hl-build": ["Build HashLink target (pre-built hdll)", "Build custom hdll via build-hdll", "Verify custom hdll created", "Rebuild HashLink target (custom hdll)", "Upload compiled hdll", "Validate build output"],
    "windows-hl": ["Record audio via FMOD wavwriter", "Fix WAV header", "Validate audio", "Validate game log", "Record volume test", "Fix volume test WAV header", "Validate volume/mute", "Run api-probe state", "Run synth-test state", "Validate synth audio", "Run cb-test state", "Run ps-test state", "Run bank-test state", "Run pan-test state"],
    "linux-html5-chromium-build": ["Build HTML5 target", "Validate FMOD files replaced placeholders", "Stage FMOD web files into a plain directory", "Typecheck the flixel no-sound-system variant", "Verify mismatched web SDK fails the build"],
    "linux-html5-chromium": ["Record audio", "Validate audio", "Record volume test", "Validate volume/mute", "Run API probe (JS binding coverage)", "Run synth test (generated PCM reaches the output)", "Validate synth audio", "Run callback test (JS payload delivery)", "Run ps-test state (browser)", "Run bank-test state (browser)", "Run pan-test state (browser)"],
    "heaps-hl-build": ["Build test variant", "Validate build output"],
    "heaps-hl": ["Record audio", "Record volume test", "Run state", "Validate synth audio", "Run stress-test state (smoke)"],
    "heaps-html5-build": ["Build test variant", "Validate build output"],
    "heaps-html5": ["Record audio", "Record volume test", "Run state", "Validate synth audio"],
    "kha-linux-build": ["Build test variant", "Validate build output"],
    "kha-linux-build-manual": ["Build test variant", "Validate build output"],
    "kha-linux": ["Record audio", "Record volume test", "Run state", "Validate synth audio", "Run stress-test state (smoke)"],
    "kha-hl-build": ["Build test variant", "Validate build output"],
    "kha-hl": ["Record audio", "Record volume test", "Run state", "Validate synth audio", "Run stress-test state (smoke)"],
    "kha-html5-build": ["Build test variant", "Validate build output"],
    "kha-html5": ["Record audio", "Record volume test", "Run state", "Validate synth audio"],
    "heaps-mac-hl-build": ["Build test variant", "Validate build output"],
    "heaps-mac-hl": ["Record audio", "Record volume test", "Run state", "Validate synth audio", "Run stress-test state (smoke)"],
    "heaps-windows-hl-build": ["Build test variant", "Validate build output"],
    "heaps-windows-hl": ["Record audio", "Record volume test", "Run state", "Validate synth audio", "Run stress-test state (smoke)"],
    "kha-mac-build": ["Build test variant", "Validate build output"],
    "kha-mac": ["Record audio", "Record volume test", "Run state", "Validate synth audio", "Run stress-test state (smoke)"],
    "kha-mac-hl-build": ["Build test variant", "Validate build output"],
    "kha-mac-hl": ["Record audio", "Record volume test", "Run state", "Validate synth audio", "Run stress-test state (smoke)"],
    "kha-windows-build": ["Build test variant", "Validate build output"],
    "kha-windows": ["Record audio", "Record volume test", "Run state", "Validate synth audio", "Run stress-test state (smoke)"],
    "kha-windows-hl-build": ["Build test variant", "Validate build output"],
    "kha-windows-hl": ["Record audio", "Record volume test", "Run state", "Validate synth audio", "Run stress-test state (smoke)"],
    "linux-html5-firefox": [
        "Build HTML5 target",
        "Start display and audio",
        "Install Playwright Firefox",
        "Run api-probe state (firefox)", "Run cb-test state (firefox)",
        "Run ps-test state (firefox)", "Run bank-test state (firefox)",
        "Run pan-test state (firefox)",
    ],
    "linux-hl-compat": [
        "Use compat fixture banks",
        "Verify FMOD libraries have no executable stack",
        "Build HashLink target (expect version mismatch failure)",
        "Test DSP type translation against the 2.02.33 headers",
        "Rebuild HashLink target (custom hdll)",
        "Run api-probe state", "Validate audio", "Validate game log",
    ],
    "mac-hl-compat": [
        "Use compat fixture banks",
        "Build HashLink target (expect version mismatch failure)",
        "Rebuild HashLink target (custom hdll)",
        "Validate audio", "Validate game log",
    ],
    "windows-hl-compat": [
        "Use compat fixture banks",
        "Build HashLink target (expect version mismatch failure)",
        "Rebuild HashLink target (custom hdll)",
        "Validate audio", "Validate game log",
    ],
    "js-harness": [
        "Run jaxe harnesses against the real wasm",
        "Run Core dynamic-audio prototype against the real wasm",
    ],
    "env-doctor": [
        "Doctor passes in a configured environment",
        "Doctor rejects a missing FMOD_SDK (negative test)",
        "Build blocks without FMOD_SDK (hl)",
        "Build blocks without FMOD_SDK_WEB (html5)",
        "Build blocks with a bogus FMOD_SDK (hl)",
        "Postbuild rejects a bogus FMOD_SDK",
        "Postbuild rejects an SDK missing platform libraries",
    ],
    "package-check": [
        "Test DSP type translation against this SDK's headers",
        "Refuse to package without the pre-built hdlls",
        "Build the haxelib package",
        "Reconcile the package against the tracked tree",
        "Build HashLink target from the installed package",
        "Build HTML5 target from the installed package",
        "Run CLI commands from the installed package",
    ],
    "package-check-cpp": [
        "Build the haxelib package",
        "Install libraries with haxefmod from the package",
        "Build C++ target from the installed package",
    ],
}
missing_steps = []
for job_name, required in REQUIRED_STEPS.items():
    body = jobs.get(job_name, "")
    if not body:
        missing_steps.append(f"{job_name}: job not found")
        continue
    step_names = set(re.findall(r"^      - name: (.*)$", body, re.M))
    for step in required:
        if step not in step_names:
            missing_steps.append(f"{job_name}: missing step '{step}'")
if missing_steps:
    for item in missing_steps:
        fail(f"required step check: {item}")
else:
    total = sum(len(v) for v in REQUIRED_STEPS.values())
    ok(f"all {total} required test steps present across {len(REQUIRED_STEPS)} jobs")

# 7. Every Node harness in tests/js/ is wired into the workflow
import os
script_dir = os.path.dirname(os.path.abspath(__file__))
js_dir = os.path.join(script_dir, "..", "tests", "js")
unwired = []
harnesses = sorted(f for f in os.listdir(js_dir) if f.endswith(".js"))
for harness in harnesses:
    if f"tests/js/{harness}" not in text:
        unwired.append(harness)
if unwired:
    fail(f"harnesses in tests/js/ not invoked by the workflow: {unwired}")
else:
    ok(f"all {len(harnesses)} tests/js harnesses are wired into the workflow")

print()
if failures:
    print(f"workflow-invariants: {len(failures)} FAILURE(S)")
    sys.exit(1)
print("workflow-invariants: all assertions passed")
