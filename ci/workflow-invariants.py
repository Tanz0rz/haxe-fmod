#!/usr/bin/env python3
"""Structural invariants for .github/workflows/audio-test.yml.

The release-path gating lives in workflow expressions that nothing
compiles or type-checks, so regressions there are silent until a tag or
compat run goes wrong. This asserts the properties everything else
leans on:

  1. Every [skip-build]-gated job condition carries the tag override, so
     a release tag on an hdll auto-commit runs the full suite.
  2. update-hdlls runs only on branch refs. A tag checkout is a detached
     HEAD with no branch to push to. Windows hdll builds are not
     byte-reproducible, so the push would always be attempted and fail.
  3. Every job has a timeout.
  4. The compat jobs assert the mismatched build FAILS, beyond a banner
     appearing in a zero-exit build. pipefail is set explicitly, because
     only the Windows jobs' shell declaration implies it.
  5. linux-html5-chromium asserts a build against a doctored (wrong-version) web
     SDK FAILS with the mismatch banner, with pipefail. html5 pins the
     web SDK version instead of translating DSP types.
  6. Every job contains its required test steps by name. Renaming
     or deleting a probe step means updating the list here in the same
     commit.
  7. Every Node harness in tests/js/ is invoked somewhere in the
     workflow.
  8. The plain portability loops name every native test that needs no
     SDK header, and the sanitizer loops name every native test. Both
     sets are read from tests/native and its includes, in the workflow
     and in ci/local-ci.sh, so a test reaches every pass.
  9. The HashLink commit is named once, in HASHLINK_COMMIT, and every
     checkout and cache key reads it there.
  10. HAXELIB_PINS names every pinned haxelib install and every haxelib
     cache key carries it, so a bump rotates the caches. No install is
     left unpinned outside the canary.
  11. Every other workflow that repeats HASHLINK_COMMIT, HAXELIB_PINS,
     or HAXE_VERSION carries the same value. Every other workflow's
     pinned installs are in the pins, with or without the variable.
  12. The seven manifest ABI parses across the workflows are the same
     line, and a guard that refuses a non-number follows each one.
  13. No workflow uses krdlab/setup-haxe directly, so every such install
     goes through the local action with the retry. The macOS jobs
     install Haxe through Homebrew, which retries on its own.
  14. Every haxelib install, git clone, npm install, playwright install,
     brew install, pip install, and curl health check goes through
     ci/retry.sh. That covers the workflows, the composite actions, and
     the run job generator. Every apt-get carries its retry option.
  15. The steps gated on a stale pre-built hdll are the known few, so a
     new gate cannot hide behind the branch escape hatch unnoticed. The
     three HashLink build gates read both hdll markers.

Run: python3 ci/workflow-invariants.py [workflow-file]
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_WORKFLOW = os.path.join(ROOT, ".github", "workflows", "audio-test.yml")
PATH = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_WORKFLOW
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
    fail("compat jobs do not grep for the mismatch banner")
else:
    ok("compat jobs verify the mismatch banner text")

# 9. The HashLink commit is named once in the workflow environment, and
# every checkout and cache key reads it there
if re.search(r"git checkout [0-9a-f]{40}", text):
    fail("a HashLink checkout names the commit literally instead of HASHLINK_COMMIT")
else:
    ok("every HashLink checkout reads HASHLINK_COMMIT")
hl_keys = re.findall(r"key: hashlink-[^\n]*", text)
if not hl_keys or any("env.HASHLINK_COMMIT" not in k for k in hl_keys):
    fail(f"a HashLink cache key lacks HASHLINK_COMMIT: {hl_keys}")
else:
    ok(f"{len(hl_keys)} HashLink cache keys read HASHLINK_COMMIT")

# 10. Every pinned haxelib install appears in HAXELIB_PINS, and every
# haxelib cache key carries the pins, so a bump rotates the caches
pins_match = re.search(r"HAXELIB_PINS: (\S+)", text)
pins = pins_match.group(1) if pins_match else ""
installs = set(re.findall(r"haxelib install ([a-z]+) ([0-9][0-9.]*)", text))
missing_pins = sorted(f"{lib}{ver}" for lib, ver in installs if f"{lib}{ver}" not in pins.split("-"))
# The library under test is installed at whatever version is published
unpinned = sorted(set(re.findall(r"haxelib install ([a-z]+) --", text)) - {"haxefmod"})
haxelib_keys = re.findall(r"key: haxelib-[^\n]*", text)
if missing_pins or unpinned or not haxelib_keys or any("env.HAXELIB_PINS" not in k for k in haxelib_keys):
    fail(f"HAXELIB_PINS out of step: missing {missing_pins}, unpinned {unpinned}, keys {haxelib_keys}")
else:
    ok(f"HAXELIB_PINS covers {len(installs)} pinned installs across {len(haxelib_keys)} cache keys")

# 11. The other workflows repeat the two values. A bump in one file
# that misses another would build or cache against the old pin there.
for other in sorted(os.listdir(os.path.dirname(PATH))):
    other_path = os.path.join(os.path.dirname(PATH), other)
    if not other.endswith(".yml") or os.path.abspath(other_path) == os.path.abspath(PATH):
        continue
    with open(other_path) as fh:
        other_text = fh.read()
    other_commit = re.search(r"HASHLINK_COMMIT: (\S+)", other_text)
    this_commit = re.search(r"HASHLINK_COMMIT: (\S+)", text)
    if other_commit and (not this_commit or other_commit.group(1) != this_commit.group(1)):
        fail(f"{other} names HashLink commit {other_commit.group(1)}, this workflow names {this_commit.group(1) if this_commit else None}")
    elif other_commit:
        ok(f"{other} names the same HashLink commit")
    if re.search(r"git checkout [0-9a-f]{40}", other_text):
        fail(f"{other} checks a HashLink commit out literally")
    other_haxe = re.search(r"HAXE_VERSION: (\S+)", other_text)
    this_haxe = re.search(r"HAXE_VERSION: (\S+)", text)
    if other_haxe and (not this_haxe or other_haxe.group(1) != this_haxe.group(1)):
        fail(f"{other} names Haxe {other_haxe.group(1)}, this workflow names {this_haxe.group(1) if this_haxe else None}")
    elif other_haxe:
        ok(f"{other} names the same Haxe version")
    # The canary installs the newest versions on purpose, every other
    # sibling pins each install
    other_unpinned = sorted(set(re.findall(r"haxelib install ([a-z]+) --", other_text)) - {"haxefmod"})
    if other_unpinned and other != "canary.yml":
        fail(f"{other} installs without a version: {other_unpinned}")
    other_pins = re.search(r"HAXELIB_PINS: (\S+)", other_text)
    if other_pins and other_pins.group(1) != pins:
        fail(f"{other} carries HAXELIB_PINS {other_pins.group(1)}, this workflow carries {pins}")
    # A workflow without the variable still installs pinned versions,
    # which must be the ones the pins name
    other_installs = set(re.findall(r"haxelib install ([a-z]+) ([0-9][0-9.]*)", other_text))
    other_missing = sorted(f"{lib}{ver}" for lib, ver in other_installs if f"{lib}{ver}" not in pins.split("-"))
    # A haxelib cache key in a sibling needs the pins in it, and the
    # sibling then needs the variable the key reads
    other_keys = re.findall(r"key: haxelib-[^\n]*", other_text)
    if other_missing or (other_keys and not other_pins) or any("env.HAXELIB_PINS" not in k for k in other_keys):
        fail(f"{other} installs out of step with HAXELIB_PINS: missing {other_missing}, keys {other_keys}, pins declared {bool(other_pins)}")
    elif other_installs:
        ok(f"{other} installs {len(other_installs)} pinned versions the pins name")

# 12. The seven ABI parses of the manifest header are one line each, and
# a numeric guard follows each. None of them can fail open again. Every
# workflow is scanned, and the count is held, so an eighth parse under
# another name or in another file is noticed.
ABI_PARSE_COUNT = 7
abi_parse = 'ABI=$(grep "^# abi-version:" native/manifest/studio_api.txt | grep -o "[0-9][0-9]*" | head -1 || true)'
abi_lines = []
for wf in sorted(os.listdir(os.path.dirname(PATH))):
    if not wf.endswith(".yml"):
        continue
    with open(os.path.join(os.path.dirname(PATH), wf)) as fh:
        wf_text = fh.read()
    abi_lines += [(wf, l, nxt) for l, nxt in re.findall(r"\n *([A-Z_]+=\$\(grep \"\^# abi-version:\"[^\n]*)\n *([^\n]*)", wf_text)]
abi_bad = [(wf, l) for wf, l, _ in abi_lines if l != abi_parse]
abi_unguarded = [(wf, l) for wf, l, nxt in abi_lines if not nxt.strip().startswith('case "$ABI" in \'\'|*[!0-9]*)')]
if len(abi_lines) != ABI_PARSE_COUNT or abi_bad or abi_unguarded:
    fail(f"ABI parses out of step: {len(abi_lines)} found of {ABI_PARSE_COUNT}, differing {abi_bad}, unguarded {abi_unguarded}")
else:
    ok(f"{len(abi_lines)} ABI parses match and carry the numeric guard")

# 13. No workflow uses krdlab/setup-haxe directly, so every such install
# goes through the local action with the retry
direct = []
for wf in sorted(os.listdir(os.path.dirname(PATH))):
    if not wf.endswith(".yml"):
        continue
    with open(os.path.join(os.path.dirname(PATH), wf)) as fh:
        if re.search(r"uses: krdlab/setup-haxe", fh.read()):
            direct.append(wf)
if direct:
    fail(f"a workflow uses krdlab/setup-haxe directly instead of the retrying action: {direct}")
else:
    ok("no workflow uses krdlab/setup-haxe directly")

# 14. Every network fetch goes through the retry wrapper, and every
# wrapper path resolves. A relative path after a cd, or a wrong depth
# from an action directory, is exit 127 on the runner. The path check
# is what catches both. Every apt-get carries its retry option, and a
# comment or echo naming one is skipped.
FETCH_RE = re.compile(r"(haxelib install|git clone|npm install|npx playwright install|curl -fsS|brew install|pip\"? install)")
WRAPPER_RE = re.compile(r"bash (\"?)(\$GITHUB_ACTION_PATH|\$GITHUB_WORKSPACE|)(/?(?:\.\./)*)ci/retry\.sh\1")
fetch_files = [os.path.join(os.path.dirname(PATH), wf) for wf in sorted(os.listdir(os.path.dirname(PATH))) if wf.endswith(".yml")]
actions_dir = os.path.join(ROOT, ".github", "actions")
fetch_files += [os.path.join(actions_dir, a, "action.yml") for a in sorted(os.listdir(actions_dir))]
fetch_files.append(os.path.join(ROOT, "ci", "generate-run-jobs.py"))
bare = []
unresolved = []
unretried = []
wrapped = 0
for path in fetch_files:
    with open(path) as fh:
        lines = fh.readlines()
    block_indent = None
    moved = False
    for n, line in enumerate(lines, 1):
        stripped = line.strip()
        indent = len(line) - len(line.lstrip(" "))
        if re.match(r"run: \|", stripped) or re.match(r"return f?" + chr(34) * 3, stripped):
            block_indent = indent
            moved = False
            continue
        if block_indent is not None and stripped and indent <= block_indent:
            block_indent = None
        if stripped.startswith("#") or stripped.startswith("echo "):
            continue
        if re.search(r"\bapt-get\b", line) and not re.search(r"Acquire::Retries=[1-9]", line):
            unretried.append(f"{os.path.relpath(path, ROOT)}:{n}")
        if re.match(r"cd ", stripped) and not stripped.startswith("cd -"):
            moved = True
        if "retry.sh" in line:
            m = WRAPPER_RE.search(line)
            if not m:
                unresolved.append(f"{os.path.relpath(path, ROOT)}:{n} unrecognised wrapper spelling")
            elif m.group(2) == "$GITHUB_ACTION_PATH":
                base = os.path.dirname(path)
                target = os.path.normpath(os.path.join(base, m.group(3).lstrip("/"), "ci", "retry.sh"))
                if not os.path.exists(target):
                    unresolved.append(f"{os.path.relpath(path, ROOT)}:{n} resolves to {os.path.relpath(target, ROOT)}")
            elif m.group(2) == "" and moved:
                unresolved.append(f"{os.path.relpath(path, ROOT)}:{n} relative wrapper after a cd")
            elif m.group(2) != "$GITHUB_ACTION_PATH" and not os.path.exists(os.path.join(ROOT, "ci", "retry.sh")):
                unresolved.append(f"{os.path.relpath(path, ROOT)}:{n} ci/retry.sh is missing")
            if FETCH_RE.search(line):
                wrapped += 1
        elif FETCH_RE.search(line):
            bare.append(f"{os.path.relpath(path, ROOT)}:{n}")
if bare or unresolved or unretried or wrapped < 100:
    fail(f"network fetches outside ci/retry.sh: {bare}, wrapper paths that do not resolve: {unresolved}, apt-get without retries: {unretried} ({wrapped} wrapped)")
else:
    ok(f"{wrapped} network fetches go through ci/retry.sh, none bare, every wrapper path resolves, apt retries")

# 15. The stale-hdll escape hatch gates the known steps only
STALE_GATED = ["Doctor passes in a configured environment", "Build HashLink target from the installed package", "Validate build output"]
STALE_REFERENCES = 5
STALE_INLINE = 3
gated = re.findall(r"- name: ([^\n]+)\n(?:[^\n]*\n){0,3}?[ ]*if: steps\.abi\.outputs\.stale != 'true'", text)
stale_refs = len(re.findall(r"steps\.abi\.outputs\.stale", text))
# The three HashLink build jobs gate inside their run block. Each of
# those blocks reads both markers, so no inline hatch reads the ABI alone.
inline_blocks = re.findall(r"\n[ ]*STALE=0\n(?:[^\n]*\n)*?[ ]*if \[ \"\$STALE\" = \"1\" \]", text)
inline_half = [b for b in inline_blocks if '[ "$SRCMARK" != "$SRC" ]' not in b or '[ "$MARK" != "$ABI" ]' not in b]
if gated != STALE_GATED or stale_refs != STALE_REFERENCES or len(inline_blocks) != STALE_INLINE or inline_half:
    fail(f"stale-hdll gates out of step: steps {gated}, {stale_refs} references of {STALE_REFERENCES}, {len(inline_blocks)} inline gates of {STALE_INLINE}, {len(inline_half)} reading one marker")
else:
    ok(f"the stale-hdll gate covers the {len(gated)} known steps, {stale_refs} references, and {len(inline_blocks)} inline gates on both markers")

# 8. The plain portability loops name every native test that needs no SDK
# header, and the sanitizer loops name every native test
loops = re.findall(r"for (?:%%t|t) in \(?([a-z0-9_ ]+?)\)?(?:;| do\b)", text)
# The ThreadSanitizer loops run the threaded tests only, so they are apart.
# Both groups are pinned to the test files on disk. The plain loops name
# every test that needs no SDK header, and the sanitizer loops name every
# test. A new test file wired into neither group fails here too, and so
# does a local replay loop that drifts from the workflow.
NATIVE_DIR = os.path.join(ROOT, "tests", "native")
NATIVE_TESTS = sorted(f[len("test_faxe_"):-2] for f in os.listdir(NATIVE_DIR)
                      if f.startswith("test_faxe_") and f.endswith(".c"))


def needs_sdk(path, seen=None):
    # A test needs the FMOD headers when it, or a shared header it pulls
    # in, includes one. A test that stubs FMOD_GUID and defines the
    # common header's guard first compiles without them.
    seen = seen or set()
    if path in seen or not os.path.isfile(path):
        return False
    seen.add(path)
    with open(path) as fh:
        text = fh.read()
    if "#define _FMOD_COMMON_H" in text:
        return False
    for inc in re.findall(r'#include\s+[<"]([^>"]+)[>"]', text):
        if os.path.basename(inc).startswith("fmod"):
            return True
        if needs_sdk(os.path.normpath(os.path.join(os.path.dirname(path), inc)), seen):
            return True
    return False


SDK_TESTS = {t for t in NATIVE_TESTS if needs_sdk(os.path.join(NATIVE_DIR, f"test_faxe_{t}.c"))}
PLAIN_TESTS = sorted(set(NATIVE_TESTS) - SDK_TESTS)
if not SDK_TESTS or not PLAIN_TESTS:
    fail(f"the native test split reads wrong: SDK {sorted(SDK_TESTS)}, plain {PLAIN_TESTS}")
# The local replay repeats the loops, so it is held to the same sets
with open(os.path.join(ROOT, "ci", "local-ci.sh")) as fh:
    local_loops = re.findall(r"for (?:%%t|t) in \(?([a-z0-9_ ]+?)\)?(?:;| do\b)", fh.read())
loops = [l for l in loops if "handles" in l]
local_loops = [l for l in local_loops if "handles" in l]
plain = [l for l in loops if not SDK_TESTS & set(l.split())]
sanitized = [l for l in loops if SDK_TESTS & set(l.split())]
local_plain = [l for l in local_loops if not SDK_TESTS & set(l.split())]
local_sanitized = [l for l in local_loops if SDK_TESTS & set(l.split())]
plain_wrong = [l for l in plain + local_plain if sorted(l.split()) != PLAIN_TESTS]
sanitized_wrong = [l for l in sanitized + local_sanitized if sorted(l.split()) != NATIVE_TESTS]
if not plain or len(sanitized) < 2 or not local_plain or not local_sanitized or plain_wrong or sanitized_wrong:
    fail(f"the shared header test loops differ from tests/native: plain {plain + local_plain} (expected {PLAIN_TESTS}), sanitized {sanitized + local_sanitized} (expected {NATIVE_TESTS})")
else:
    ok(f"{len(plain) + len(local_plain)} plain loops name the {len(PLAIN_TESTS)} header tests, {len(sanitized) + len(local_sanitized)} sanitizer loops name all {len(NATIVE_TESTS)}")

# 5. linux-html5-chromium requires a FAILING build against a doctored web SDK,
# with pipefail, and verifies the version-mismatch banner. The check is
# paired to the job, so a copy of the block elsewhere cannot mask its removal.
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
    fail("linux-html5-chromium-build does not grep for the web mismatch banner")
else:
    ok("linux-html5-chromium-build verifies the web mismatch banner text")

# 6. Required test steps per job. Names must match the workflow's
# `- name:` lines exactly. When a step is renamed on purpose, rename it
# here in the same commit.
REQUIRED_STEPS = {
    "unit-tests": [
        "Run unit tests",
        "Verify native shims match the FFI manifest",
        "Check binding coverage against the manifest",
        "Check workflow gating invariants",
        "Check the run jobs match their generator",
        "Check the extension package manifest",
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
        "Test the default bank failure path",
        "Check the generated bindings table and example translations",
        "Check FMOD version literal lockstep",
        "Check hxcpp depend lockstep",
        "Compile the README examples",
        "Test native instance context (C99 and C++ modes)",
        "Check the DSP parameter enums match fmod_dsp_effects.h",
        "Check the HTML5 compile gate",
        "Check the HTML5 phrase matches the gate",
        "Check the deprecated aliases still compile and warn",
        "Check Haxe type declarations against the FMOD headers"
    ],
    "linux-cpp-build": ["Build C++ target", "Verify FMOD libraries have no executable stack", "Validate build output", "Build the test DSP plugin next to the game"],
    "linux-cpp-build-manual": ["Build manual-update variant", "Validate build output", "Build the test DSP plugin next to the game"],
    "linux-cpp": ["Record audio", "Validate audio", "Validate volume/mute", "Validate game log", "Record volume test", "Run state", "Validate synth audio", "Run stress-test state (smoke)", "Run api-probe state (manual update variant)"],
    "linux-hl-build": ["Build HashLink target (pre-built hdll)", "Build custom hdll via build-hdll", "Rebuild HashLink target (custom hdll)", "Upload compiled hdll", "Verify FMOD libraries have no executable stack", "Validate build output", "Stage FMOD runtime into a plain directory", "Build the test DSP plugin next to the game", "lime test end to end"],
    "linux-hl": ["Record audio", "Validate audio", "Validate volume/mute", "Validate game log", "Record volume test", "Run state", "Validate synth audio", "Run stress-test state (smoke)"],
    "mac-cpp-build": ["Build C++ target", "Validate build output", "Test native headers with Apple clang (sanitizers)"],
    "mac-cpp": ["Record audio", "Validate audio", "Validate volume/mute", "Validate game log", "Record volume test", "Run state", "Validate synth audio", "Run stress-test state (smoke)"],
    "mac-hl-build": ["Build HashLink target (pre-built hdll)", "Build custom hdll via build-hdll", "Rebuild HashLink target (custom hdll)", "Upload compiled hdll", "Validate build output"],
    "mac-hl": ["Record audio", "Validate audio", "Validate volume/mute", "Validate game log", "Record volume test", "Run state", "Validate synth audio", "Run stress-test state (smoke)"],
    "windows-cpp-build": ["Build C++ target", "Validate build output", "Test native headers with MSVC (C and C++ modes)"],
    "windows-cpp": ["Record audio", "Validate audio", "Validate volume/mute", "Validate game log", "Record volume test", "Run state", "Validate synth audio", "Run stress-test state (smoke)"],
    "windows-hl-build": ["Build HashLink target (pre-built hdll)", "Build custom hdll via build-hdll", "Verify custom hdll created", "Rebuild HashLink target (custom hdll)", "Upload compiled hdll", "Validate build output"],
    "windows-hl": ["Record audio", "Validate audio", "Validate volume/mute", "Validate game log", "Record volume test", "Run state", "Validate synth audio", "Run stress-test state (smoke)"],
    "linux-html5-chromium-build": ["Build HTML5 target", "Validate FMOD files replaced placeholders", "Stage FMOD web files into a plain directory", "Typecheck the flixel no-sound-system variant", "Verify mismatched web SDK fails the build"],
    "linux-html5-chromium": ["Record audio", "Validate audio", "Validate volume/mute", "Record volume test", "Run state", "Validate synth audio"],
    "heaps-hl-build": ["Build test variant", "Validate build output"],
    "heaps-hl-build-manual": ["Build test variant", "Validate build output"],
    "heaps-hl": ["Record audio", "Validate audio", "Validate volume/mute", "Validate game log", "Record volume test", "Run state", "Validate synth audio", "Run stress-test state (smoke)", "Run api-probe state (manual update variant)"],
    "heaps-html5-build": ["Build test variant", "Validate build output"],
    "heaps-html5": ["Record audio", "Validate audio", "Validate volume/mute", "Record volume test", "Run state", "Validate synth audio"],
    "kha-linux-build": ["Build test variant", "Validate build output", "Check out Kha"],
    "kha-linux-build-manual": ["Build test variant", "Validate build output", "Check out Kha"],
    "kha-linux": ["Record audio", "Validate audio", "Validate volume/mute", "Validate game log", "Record volume test", "Run state", "Validate synth audio", "Run stress-test state (smoke)", "Run api-probe state (manual update variant)"],
    "kha-hl-build": ["Build test variant", "Validate build output", "Check out Kha"],
    "kha-hl": ["Record audio", "Validate audio", "Validate volume/mute", "Validate game log", "Record volume test", "Run state", "Validate synth audio", "Run stress-test state (smoke)"],
    "kha-html5-build": ["Build test variant", "Validate build output", "Check out Kha"],
    "kha-html5": ["Record audio", "Validate audio", "Validate volume/mute", "Record volume test", "Run state", "Validate synth audio"],
    "heaps-mac-hl-build": ["Build test variant", "Validate build output"],
    "heaps-mac-hl": ["Record audio", "Validate audio", "Validate volume/mute", "Validate game log", "Record volume test", "Run state", "Validate synth audio", "Run stress-test state (smoke)"],
    "heaps-windows-hl-build": ["Build test variant", "Validate build output"],
    "heaps-windows-hl": ["Record audio", "Validate audio", "Validate volume/mute", "Validate game log", "Record volume test", "Run state", "Validate synth audio", "Run stress-test state (smoke)"],
    "kha-mac-build": ["Build test variant", "Validate build output", "Check out Kha"],
    "kha-mac": ["Record audio", "Validate audio", "Validate volume/mute", "Validate game log", "Record volume test", "Run state", "Validate synth audio", "Run stress-test state (smoke)"],
    "kha-mac-hl-build": ["Build test variant", "Validate build output", "Check out Kha"],
    "kha-mac-hl": ["Record audio", "Validate audio", "Validate volume/mute", "Validate game log", "Record volume test", "Run state", "Validate synth audio", "Run stress-test state (smoke)"],
    "kha-windows-build": ["Build test variant", "Validate build output", "Check out Kha"],
    "kha-windows": ["Record audio", "Validate audio", "Validate volume/mute", "Validate game log", "Record volume test", "Run state", "Validate synth audio", "Run stress-test state (smoke)"],
    "kha-windows-hl-build": ["Build test variant", "Validate build output", "Check out Kha"],
    "kha-windows-hl": ["Record audio", "Validate audio", "Validate volume/mute", "Validate game log", "Record volume test", "Run state", "Validate synth audio", "Run stress-test state (smoke)"],
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
        "Run api-probe state", "Validate audio", "Validate game log", "Validate build output", "Validate volume/mute"],
    "mac-hl-compat": [
        "Use compat fixture banks",
        "Build HashLink target (expect version mismatch failure)",
        "Rebuild HashLink target (custom hdll)",
        "Validate audio", "Validate game log", "Validate build output", "Validate volume/mute"],
    "windows-hl-compat": [
        "Use compat fixture banks",
        "Build HashLink target (expect version mismatch failure)",
        "Rebuild HashLink target (custom hdll)",
        "Validate audio", "Validate game log", "Validate build output", "Validate volume/mute", "Verify custom hdll created"],
    "js-harness": [
        "Run jaxe harnesses against the real wasm",
        "Run Core dynamic-audio prototype against the real wasm",
    ],
    "env-doctor": [
        "Check the pre-built hdll ABI",
        "Doctor passes in a configured environment",
        "Doctor rejects a missing FMOD_SDK (negative test)",
        "Build blocks without FMOD_SDK (hl)",
        "Build blocks without FMOD_SDK_WEB (html5)",
        "Build blocks with a bogus FMOD_SDK (hl)",
        "Postbuild rejects a bogus FMOD_SDK",
        "Postbuild rejects an SDK missing platform libraries",
    ],
    "package-check": [
        "Check the pre-built hdll ABI",
        "Test DSP type translation against this SDK's headers",
        "Refuse to package without the pre-built hdlls",
        "Build the haxelib package",
        "Reconcile the package against the tracked tree",
        "Build HashLink target from the installed package",
        "Build HTML5 target from the installed package",
        "Run CLI commands from the installed package", "Verify tag matches haxelib.json version", "Test the DSP parameter indices against this SDK's headers", "Validate build output", "Validate FMOD files replaced placeholders"],
    "package-check-cpp": [
        "Build the haxelib package",
        "Install libraries with haxefmod from the package",
        "Build C++ target from the installed package",
    ],
    "api-docs": [
        "Install dox",
        "Generate type XML",
        "Render API docs",
        "Upload API docs",
    ],
    "update-hdlls": [
        "Ensure the run is on a branch",
        "Download compiled hdlls",
        "Update templates directory",
        "Commit updated hdlls",
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

# 6a. The required step table names every job and no other, so a new job
# cannot ship without its probe steps listed
uncovered = sorted(set(jobs) - set(REQUIRED_STEPS))
orphaned = sorted(set(REQUIRED_STEPS) - set(jobs))
if uncovered or orphaned:
    fail(f"REQUIRED_STEPS out of sync: uncovered {uncovered}, orphaned {orphaned}")
else:
    ok("REQUIRED_STEPS names every job")

# 7. Every Node harness in tests/js/ is wired into the workflow
js_dir = os.path.join(ROOT, "tests", "js")
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
