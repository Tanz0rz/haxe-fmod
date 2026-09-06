#!/usr/bin/env python3
"""Keeps the docs and the compiler in agreement about HTML5 support.

A method FMOD's web build cannot run carries two things in the Haxe
source: the phrase "(unsupported in HTML5)" in its doc comment, and the
compile gate (the macro branch under
`#if (macro || (js && !haxefmod_html5_allow_unsupported))`, see
haxefmod/studio/native/Html5Gate.hx). ci/check-html5-gate.py proves each
gate carries the phrase. This check proves the reverse: every method
whose doc comment carries the phrase sits inside a gate, so a doc
comment cannot promise an error the compiler does not raise.

Doc comments on fields (settings, constants) may use the phrase without
a gate, since there is nothing to gate on a field.

Run: python3 ci/check-html5-phrase.py
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "haxefmod")
PHRASE = "(unsupported in HTML5)"
GATE_OPEN = "#if (macro || (js && !haxefmod_html5_allow_unsupported))"

FUNCTION = re.compile(r"^\s*(?:public|private|static|inline|override|macro|\s)*function\s+(\w+)")
FIELD = re.compile(r"^\s*(?:@:optional\s+)?(?:public|private|static|\s)*var\s+(\w+)")


def check_file(path):
    problems = []
    with open(path, encoding="utf-8") as fh:
        lines = fh.read().splitlines()
    # gate depth tracks the #if/#else/#end nesting of the gate block only
    gate_state = "none"
    depth = 0
    gate_depth = -1
    pending_phrase_line = None
    for number, line in enumerate(lines, 1):
        stripped = line.strip()
        if stripped.startswith("#if"):
            depth += 1
            if stripped == GATE_OPEN:
                gate_state = "macro"
                gate_depth = depth
        elif stripped.startswith("#else") and depth == gate_depth:
            gate_state = "real"
        elif stripped.startswith("#end"):
            if depth == gate_depth:
                gate_state = "none"
                gate_depth = -1
            depth -= 1
        if PHRASE in line and pending_phrase_line is None:
            pending_phrase_line = number
        if pending_phrase_line is not None:
            if FUNCTION.match(line):
                if gate_state == "none":
                    problems.append(f"{os.path.relpath(path, ROOT)}:{number}: {FUNCTION.match(line).group(1)} documents "
                                    f"'{PHRASE}' but has no compile gate")
                pending_phrase_line = None
            elif FIELD.match(line):
                pending_phrase_line = None
    return problems


def main():
    problems = []
    checked = 0
    for dirpath, _dirnames, filenames in os.walk(SOURCE):
        for name in sorted(filenames):
            if name.endswith(".hx"):
                checked += 1
                problems += check_file(os.path.join(dirpath, name))
    for problem in problems:
        print("FAIL: " + problem)
    print(f"check-html5-phrase: {checked} files, {len(problems)} ungated phrase(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
