#!/usr/bin/env python3
"""Compiles the README's ```haxe fences against the real library.

The README ships in the haxelib package: a snippet that does not compile
is a broken quickstart for every new user. Each fence is wrapped in a
scaffold class with stub identifiers for the game-side names snippets
reference (FmodEvents constants, flixel hooks, helper functions), then
type-checked with `haxe --no-output` against the actual haxefmod source,
so an API change that breaks an example fails CI here.

Run: python3 ci/check-readme-snippets.py
"""

import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
README = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "README.md")

SCAFFOLD = """{imports}
import haxefmod.FmodManager;
import haxefmod.FmodSound;
import haxefmod.studio.StudioSystem;

class Snippet{index} {{
    static var engineSound:haxefmod.FmodSound;
    static var channel:haxefmod.core.Channel;
    static function pulseUI(bar:Int, beat:Int):Void {{}}
    static function nextSample():Int return 0;
{members}
    static function snippet():Void {{
{body}
    }}
}}
"""

# Game-side generated-constants modules README snippets import. Written
# as real files so `import FmodEvents;` resolves like it does in a game.
STUB_MODULES = {
    "FmodEvents.hx": """class FmodEvents {
    public static inline var SFXEngine = "event:/SFX/Engine";
    public static inline var SFXJump = "event:/SFX/Jump";
    public static inline var SFXCoin = "event:/SFX/Coin";
    public static inline var MusicMainLevel = "event:/Music/MainLevel";
    public static inline var MusicTitle = "event:/Music/Title";
}
""",
    "FmodBuses.hx": """class FmodBuses {
    public static inline var SFX = "bus:/SFX";
    public static inline var Music = "bus:/Music";
}
""",
}


def extract_fences(text):
    return re.findall(r"```haxe\n(.*?)```", text, re.S)


def split_snippet(code):
    """The leading run of imports (comments, blanks, and #if guards
    included) moves to the file header. A body that starts with a
    function definition compiles as class members, everything else as
    statements (local functions are legal inside them)."""
    header = []
    rest = []
    in_header = True
    for line in code.splitlines():
        stripped = line.strip()
        header_shaped = (stripped == "" or stripped.startswith("//")
                         or stripped.startswith("import ")
                         or stripped.startswith("#if") or stripped == "#end")
        if in_header and header_shaped:
            if not stripped.startswith("//"):
                header.append(stripped)
        else:
            in_header = False
            rest.append(line)
    body = "\n".join(rest).strip("\n")
    if re.match(r"\s*(public\s+)?function\s", body):
        return header, body, ""
    return header, "", body


def indent(code, depth):
    pad = " " * depth
    return "\n".join(pad + line if line.strip() else line for line in code.splitlines())


def main():
    with open(README, encoding="utf-8") as fh:
        fences = extract_fences(fh.read())
    if not fences:
        print("FAIL: no ```haxe fences found in README.md - extraction broken?")
        return 1

    failures = 0
    with tempfile.TemporaryDirectory(prefix="readme-snippets-") as workdir:
        for name, content in STUB_MODULES.items():
            with open(os.path.join(workdir, name), "w", encoding="utf-8") as out:
                out.write(content)
        for index, fence in enumerate(fences):
            header, members, statements = split_snippet(fence.strip())
            # Duplicate scaffold imports are legal in Haxe, keep them all
            source = SCAFFOLD.format(
                index=index,
                imports="\n".join(header),
                members=indent(members, 4),
                body=indent(statements, 8))
            path = os.path.join(workdir, f"Snippet{index}.hx")
            with open(path, "w", encoding="utf-8") as out:
                out.write(source)
            result = subprocess.run(
                ["haxe", "-cp", ROOT, "-cp", workdir, "--no-output", f"Snippet{index}"],
                capture_output=True, text=True)
            if result.returncode != 0:
                failures += 1
                print(f"FAIL: README snippet {index} does not compile:")
                print("--- snippet ---")
                print(fence.strip())
                print("--- compiler ---")
                print(result.stderr.strip())
                print()
    print(f"readme-snippets: {len(fences)} fences, {failures} failing")
    if failures:
        return 1
    print("readme-snippets: every README example compiles")
    return 0


if __name__ == "__main__":
    sys.exit(main())
