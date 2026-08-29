#!/usr/bin/env python3
"""Compiles the ```haxe fences in the markdown docs against the real library.

README.md and MIGRATION.md ship in the haxelib package, and docs/ is the
published site, so their examples have to keep compiling as the API
moves. Each fence is wrapped in a scaffold class with stub identifiers for
the game-side names snippets reference (FmodEvents constants, flixel
hooks, helper functions), then type-checked with `haxe --no-output`
against the actual haxefmod source, so an API change that breaks an
example fails CI here.

A fence that mentions flixel compiles against flixel, openfl, and lime
with a set of flixel-shaped stubs, so those libraries must be installed
for the docs/ check.

Run: python3 ci/check-readme-snippets.py [file.md | directory ...]
With no argument README.md and MIGRATION.md are checked. A directory is
searched for *.md files recursively.
"""

import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_DOCS = [os.path.join(ROOT, "README.md"), os.path.join(ROOT, "MIGRATION.md")]

SCAFFOLD = """{imports}
import haxefmod.FmodManager;
import haxefmod.FmodSound;
import haxefmod.studio.StudioSystem;

class Snippet{index} {{
    static var engineSound:haxefmod.FmodSound;
    static var channel:haxefmod.core.Channel;
    static var instance:haxefmod.studio.EventInstance;
    static var handler:haxefmod.studio.Callbacks.EventCallbackData->Void;
    static var carPositionProvider:haxefmod.runtime.IFmodPositionProvider;
    static var cameraX:Float;
    static var cameraY:Float;
    static var carX:Float;
    static var carY:Float;
    static function pulseUI(bar:Int, beat:Int):Void {{}}
    static function nextSample():Int return 0;
    static function startGame():Void {{}}
    static function spawnCars():Void {{}}
{flixel_members}
{members}
    static function snippet():Void {{
{body}
    }}
}}
{types}
"""

FLIXEL_MEMBERS = """    static var car:flixel.FlxObject;
    static var player:flixel.FlxObject;
    static var coin:flixel.FlxObject;
    static function add(basic:flixel.FlxBasic):flixel.FlxBasic return basic;
"""

# Game-side generated-constants modules the snippets import. Written as
# real files so `import FmodEvents;` resolves like it does in a game.
STUB_MODULES = {
    "FmodEvents.hx": """class FmodEvents {
    public static inline var SFXEngine = "event:/SFX/Engine";
    public static inline var SFXJump = "event:/SFX/Jump";
    public static inline var SFXCoin = "event:/SFX/Coin";
    public static inline var MusicMainLevel = "event:/Music/MainLevel";
    public static inline var MusicTitle = "event:/Music/Title";
}
""",
    "FmodEventsGuids.hx": """class FmodEventsGuids {
    public static inline var MusicMainLevel = "{e5187c3f-0000-0000-0000-000000000000}";
}
""",
    "FmodBuses.hx": """class FmodBuses {
    public static inline var SFX = "bus:/SFX";
    public static inline var Music = "bus:/Music";
}
""",
}

# Only compiled when a fence needs flixel
FLIXEL_STUB_MODULES = {
    "MenuState.hx": """class MenuState extends flixel.FlxState {}
""",
}


def extract_fences(text):
    return re.findall(r"```haxe\n(.*?)```", text, re.S)


def split_snippet(code):
    """The leading run of imports (comments, blanks, and #if guards
    included) moves to the file header. Class and typedef declarations at
    column zero become extra types of the module. A body that starts with
    a function definition compiles as class members, everything else as
    statements (local functions are legal inside them)."""
    header = []
    rest = []
    types = []
    in_header = True
    in_type = False
    for line in code.splitlines():
        stripped = line.strip()
        header_shaped = (stripped == "" or stripped.startswith("//")
                         or stripped.startswith("import ")
                         or stripped.startswith("#if") or stripped == "#end")
        if in_header and header_shaped:
            if not stripped.startswith("//"):
                header.append(stripped)
            continue
        in_header = False
        if not in_type and re.match(r"(class|typedef|enum|interface)\s", line):
            in_type = True
        if in_type:
            types.append(line)
            # a declaration ends at its closing brace on column zero
            if line == "}" or (line.startswith("typedef") and line.rstrip().endswith(";")):
                in_type = False
        else:
            rest.append(line)
    body = "\n".join(rest).strip("\n")
    types = "\n".join(types)
    if re.match(r"\s*(public\s+|override\s+)*function\s", body):
        return header, body, "", types
    return header, "", body, types


def indent(code, depth):
    pad = " " * depth
    return "\n".join(pad + line if line.strip() else line for line in code.splitlines())


def collect_docs(args):
    if not args:
        return DEFAULT_DOCS
    docs = []
    for arg in args:
        path = arg if os.path.isabs(arg) else os.path.join(ROOT, arg)
        if os.path.isdir(path):
            for folder, _, names in sorted(os.walk(path)):
                docs += [os.path.join(folder, n) for n in sorted(names) if n.endswith(".md")]
        else:
            docs.append(path)
    return docs


def main():
    docs = collect_docs(sys.argv[1:])
    fences = []
    for doc in docs:
        with open(doc, encoding="utf-8") as fh:
            doc_fences = extract_fences(fh.read())
        label = os.path.relpath(doc, ROOT)
        if not doc_fences and doc in DEFAULT_DOCS:
            print(f"FAIL: no ```haxe fences found in {label} - drop it from DEFAULT_DOCS if the doc genuinely has no examples")
            return 1
        fences += [(label, i + 1, fence) for i, fence in enumerate(doc_fences)]

    failures = 0
    with tempfile.TemporaryDirectory(prefix="readme-snippets-") as workdir:
        for name, content in STUB_MODULES.items():
            with open(os.path.join(workdir, name), "w", encoding="utf-8") as out:
                out.write(content)
        flixel_dir = os.path.join(workdir, "flixel-stubs")
        os.mkdir(flixel_dir)
        for name, content in FLIXEL_STUB_MODULES.items():
            with open(os.path.join(flixel_dir, name), "w", encoding="utf-8") as out:
                out.write(content)
        for index, (doc_name, doc_index, fence) in enumerate(fences):
            header, members, statements, types = split_snippet(fence.strip())
            uses_flixel = "flixel" in fence
            # Duplicate scaffold imports are legal in Haxe, keep them all
            source = SCAFFOLD.format(
                index=index,
                imports="\n".join(header),
                flixel_members=FLIXEL_MEMBERS if uses_flixel else "",
                members=indent(members, 4),
                body=indent(statements, 8),
                types=types)
            path = os.path.join(workdir, f"Snippet{index}.hx")
            with open(path, "w", encoding="utf-8") as out:
                out.write(source)
            command = ["haxe", "-cp", ROOT, "-cp", workdir, "--no-output"]
            if uses_flixel:
                # flixel only type-checks against a real target, and the
                # standard-assets define keeps it off the sys package there
                command += ["-cp", flixel_dir, "-lib", "flixel", "-lib", "openfl", "-lib", "lime",
                            "-D", "FLX_STANDARD_ASSETS_DIRECTORY", "-D", "openfl-html5",
                            "-js", os.path.join(workdir, "out.js")]
            command.append(f"Snippet{index}")
            result = subprocess.run(command, capture_output=True, text=True)
            if result.returncode != 0:
                failures += 1
                print(f"FAIL: {doc_name} fence {doc_index} does not compile:")
                print("--- snippet ---")
                print(fence.strip())
                print("--- compiler ---")
                print(result.stderr.strip())
                print()
    print(f"readme-snippets: {len(fences)} fences, {failures} failing")
    if failures:
        return 1
    print("readme-snippets: every doc example compiles")
    return 0


if __name__ == "__main__":
    sys.exit(main())
