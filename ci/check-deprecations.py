#!/usr/bin/env python3
"""Proves every deprecated alias still compiles and warns.

Each entry names an old type or field kept for one release and the
message its @:deprecated metadata carries. A snippet using the old name
must compile for interp and print that warning, so a rename cannot
silently drop the alias or its message before the release that removes
it.

Run: python3 ci/check-deprecations.py
"""

import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

DEPRECATED = [
    ("haxefmod.studio.CoreSound",
     "var s:haxefmod.studio.CoreSound = haxefmod.studio.CoreSound.create(\"x.wav\"); trace(s.isNull());",
     "haxefmod.studio.CoreSound moved to haxefmod.core.Sound"),
    ("haxefmod.studio.CommandReplay.seekToTimeMs",
     "var r:haxefmod.studio.CommandReplay = haxefmod.studio.CommandReplay.NULL; trace(r.seekToTimeMs(0));",
     "CommandReplay.seekToTimeMs is replaced by seekToTime, which takes seconds"),
    ("haxefmod.studio.CommandReplay.getCommandAtTimeMs",
     "var r:haxefmod.studio.CommandReplay = haxefmod.studio.CommandReplay.NULL; trace(r.getCommandAtTimeMs(0));",
     "CommandReplay.getCommandAtTimeMs is replaced by getCommandAtTime, which takes seconds"),
    ("haxefmod.core.Sound.getSyncPointName",
     "var s:haxefmod.core.Sound = haxefmod.core.Sound.NULL; trace(s.getSyncPointName(0));",
     "Sound.getSyncPointName is replaced by getSyncPointInfo(point).name"),
    ("haxefmod.core.Sound.getSyncPointOffset",
     "var s:haxefmod.core.Sound = haxefmod.core.Sound.NULL; trace(s.getSyncPointOffset(0));",
     "Sound.getSyncPointOffset is replaced by getSyncPointInfo(point, offsetType).offset"),
]


def main():
    failures = 0
    with tempfile.TemporaryDirectory(prefix="deprecations-") as workdir:
        for index, (name, body, message) in enumerate(DEPRECATED):
            path = os.path.join(workdir, f"Dep{index}.hx")
            with open(path, "w", encoding="utf-8") as out:
                out.write(f"class Dep{index} {{ static function main() {{ {body} }} }}\n")
            result = subprocess.run(
                ["haxe", "-cp", ROOT, "-cp", workdir, "--no-output", "--interp", "-main", f"Dep{index}"],
                capture_output=True, text=True)
            output = result.stdout + result.stderr
            if result.returncode != 0:
                failures += 1
                print(f"FAIL: {name} no longer compiles:\n{output.strip()}")
            elif message not in output:
                failures += 1
                print(f"FAIL: {name} compiles without the deprecation warning: {message}")
            else:
                print(f"ok: {name} warns")
    print(f"check-deprecations: {len(DEPRECATED)} alias(es), {failures} failure(s)")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
