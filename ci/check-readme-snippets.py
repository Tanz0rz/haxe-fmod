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
for the docs/ check. A fence that mentions heaps compiles against an
installed heaps. Kha fences compile against small kha stubs written
here, since Kha only exists as a checkout and only the adapter-facing
surface matters to the examples.

Run: python3 ci/check-readme-snippets.py [file.md | directory ...]
With no argument README.md and MIGRATION.md are checked. A directory is
searched for *.md files recursively.
"""

import concurrent.futures
import os
import re
import subprocess
import sys
import tempfile
import textwrap

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_DOCS = [os.path.join(ROOT, "README.md"), os.path.join(ROOT, "MIGRATION.md")]

SCAFFOLD = """{imports}
import haxefmod.FmodManager;
import haxefmod.FmodSound;
import haxefmod.studio.StudioSystem;

class Snippet{index} {{
    static var engineSound:haxefmod.FmodSound;
    static var channel:haxefmod.core.Channel;
    static var sound:haxefmod.core.Sound;
    static var dsp:haxefmod.core.Dsp;
    static var multiband:haxefmod.core.Dsp;
    static var dsp_echo:haxefmod.core.Dsp;
    static var dsp_reverb:haxefmod.core.Dsp;
    static var channel_dsp_head:haxefmod.core.Dsp;
    static var dsp_connection:haxefmod.core.DspConnection;
    static var group:haxefmod.core.ChannelGroup;
    static var channelgroup:haxefmod.core.ChannelGroup;
    static var filename:String;
    static var path:String;
    static var handle:Int;
    static var key:String;
    static var eventInstance:haxefmod.studio.EventInstance;
    static var reverb:haxefmod.core.Reverb3D;
    static var music:haxefmod.core.Sound;
    static var your_non_diegetic_sound:haxefmod.core.Sound;
    static var stackSizeStream:Int;
    static var stackSizeNonBlocking:Int;
    static var stackSizeMixer:Int;
    static var chars:haxe.io.Bytes;
    static var prop1:haxefmod.core.Reverb.ReverbProperties;
    static var prop2:haxefmod.core.Reverb.ReverbProperties;
    static var prop3:haxefmod.core.Reverb.ReverbProperties;
    static var prop4:haxefmod.core.Reverb.ReverbProperties;
    static var frequency:Float;
    static var resonance:Float;
    static var center:Float;
    static var bandwidth:Float;
    static var gain:Float;
    static var posx:Float;
    static var posy:Float;
    static var posz:Float;
    static var lastposx:Float;
    static var lastposy:Float;
    static var lastposz:Float;
    static var timedelta:Float;
    static var gameRunning:Bool;
    static var listenerPos:haxefmod.studio.Types.FmodVector;
    static var listenerVel:haxefmod.studio.Types.FmodVector;
    static var listenerForward:haxefmod.studio.Types.FmodVector;
    static var listenerUp:haxefmod.studio.Types.FmodVector;
    static function updateGame():Void {{}}
    static function handleError(result:haxefmod.studio.FmodResult):Void {{}}
    static function degtorad(degrees:Float):Float return degrees * Math.PI / 180;
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
{engine_members}
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

HEAPS_MEMBERS = """    static var car:h2d.Object;
    static var player:h2d.Object;
    static var coin:h2d.Object;
    static var s2d:h2d.Scene;
    static var waterZone:h2d.col.Bounds;
"""

KHA_MEMBERS = """    static var car:haxefmod.kha.FmodKhaEmitter.KhaBody;
    static var player:haxefmod.kha.FmodKhaEmitter.KhaBody;
    static var coin:haxefmod.kha.FmodKhaEmitter.KhaBody;
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

# The pieces of Kha the adapter package and the doc examples touch. Kept
# to the exact members haxefmod.kha calls, so a Kha API change the
# adapters depend on still surfaces through the real engine builds in CI.
KHA_STUB_MODULES = {
    os.path.join("kha", "System.hx"): """package kha;

typedef SystemOptions = {
    var title:String;
    var width:Int;
    var height:Int;
}

class System {
    public static function start(options:SystemOptions, callback:Dynamic->Void):Void {}
    public static function notifyOnApplicationState(foreground:Void->Void, resume:Void->Void,
        pause:Void->Void, background:Void->Void, shutdown:Void->Void):Void {}
}
""",
    os.path.join("kha", "Scheduler.hx"): """package kha;

class Scheduler {
    public static function addFrameTask(task:Void->Void, priority:Int):Int return 0;
    public static function realTime():Float return 0;
}
""",
}


def extract_fences(text):
    # Fences inside content tabs are indented four spaces, and the type
    # detection below expects declarations at column zero
    return [textwrap.dedent(f) for f in re.findall(r"```haxe\n(.*?)```", text, re.S)]


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
        kha_dir = os.path.join(workdir, "kha-stubs")
        for name, content in KHA_STUB_MODULES.items():
            path = os.path.join(kha_dir, name)
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w", encoding="utf-8") as out:
                out.write(content)
        commands = []
        for index, (doc_name, doc_index, fence) in enumerate(fences):
            header, members, statements, types = split_snippet(fence.strip())
            uses_flixel = "flixel" in fence
            uses_heaps = "heaps" in fence
            uses_kha = "kha." in fence
            engine_members = ""
            if uses_flixel:
                engine_members = FLIXEL_MEMBERS
            elif uses_heaps:
                engine_members = HEAPS_MEMBERS
            elif uses_kha:
                engine_members = KHA_MEMBERS
            # Duplicate scaffold imports are legal in Haxe, keep them all
            source = SCAFFOLD.format(
                index=index,
                imports="\n".join(header),
                engine_members=engine_members,
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
            elif uses_heaps:
                command += ["-lib", "heaps", "-js", os.path.join(workdir, "out.js")]
            elif uses_kha:
                command += ["-cp", kha_dir, "-js", os.path.join(workdir, "out.js")]
            command.append(f"Snippet{index}")
            commands.append(command)
        # The compiles are independent (--no-output writes nothing, each
        # fence is its own module), so they fan out across the cores.
        # Results come back in fence order, so failures print exactly as
        # the serial loop printed them.
        def compile_fence(command):
            return subprocess.run(command, capture_output=True, text=True)
        with concurrent.futures.ThreadPoolExecutor(max_workers=os.cpu_count()) as pool:
            results = pool.map(compile_fence, commands)
            for (doc_name, doc_index, fence), result in zip(fences, results):
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
