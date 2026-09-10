#!/usr/bin/env python3
"""Proves every deprecated alias still compiles and warns.

Each entry names an old type or field kept for one release and the
message its @:deprecated metadata carries. A snippet using the old name
must compile for interp and print that warning, so a rename cannot
silently drop the alias or its message before the release that removes
it.

Run: python3 ci/check-deprecations.py
"""

import glob
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

DEPRECATED = [
    ("haxefmod.studio.CoreSound",
     "var s:haxefmod.studio.CoreSound = haxefmod.studio.CoreSound.create(\"x.wav\"); trace(s.isNull());",
     "haxefmod.studio.CoreSound moved to haxefmod.core.Sound, import that instead"),
    ("haxefmod.studio.CommandReplay.seekToTimeMs",
     "var r:haxefmod.studio.CommandReplay = haxefmod.studio.CommandReplay.NULL; trace(r.seekToTimeMs(0));",
     "CommandReplay.seekToTimeMs is now seekToTime, which takes seconds"),
    ("haxefmod.core.Sound.getSyncPointName",
     "var s:haxefmod.core.Sound = haxefmod.core.Sound.NULL; trace(s.getSyncPointName(0));",
     "Sound.getSyncPointName is now getSyncPointInfo(point).name"),
    ("haxefmod.core.Sound.getSyncPointOffset",
     "var s:haxefmod.core.Sound = haxefmod.core.Sound.NULL; trace(s.getSyncPointOffset(0));",
     "Sound.getSyncPointOffset is now getSyncPointInfo(point, offsetType).offset"),
    ("haxefmod.FmodManager.GetEventParameterOnSong",
     "trace(haxefmod.FmodManager.GetEventParameterOnSong(\"x\"));",
     "FmodManager.GetEventParameterOnSong is now GetSongParameter"),
    ("haxefmod.FmodManager.SetEventParameterOnSong",
     "haxefmod.FmodManager.SetEventParameterOnSong(\"x\", 1);",
     "FmodManager.SetEventParameterOnSong is now SetSongParameter"),
    ("haxefmod.FmodManager.GetBusMute",
     "trace(haxefmod.FmodManager.GetBusMute(\"bus:/\"));",
     "FmodManager.GetBusMute is now IsBusMuted"),
    ("haxefmod.FmodManager.SetBusVolumeMaster",
     "haxefmod.FmodManager.SetBusVolumeMaster(1);",
     "FmodManager.SetBusVolumeMaster is now SetMasterVolume"),
    ("haxefmod.FmodManager.GetBusVolumeMaster",
     "trace(haxefmod.FmodManager.GetBusVolumeMaster());",
     "FmodManager.GetBusVolumeMaster is now GetMasterVolume"),
    ("haxefmod.FmodManager.SetBusMuteMaster",
     "haxefmod.FmodManager.SetBusMuteMaster(false);",
     "FmodManager.SetBusMuteMaster is now SetMasterMute"),
    ("haxefmod.FmodManager.GetBusMuteMaster",
     "trace(haxefmod.FmodManager.GetBusMuteMaster());",
     "FmodManager.GetBusMuteMaster is now IsMasterMuted"),
    ("haxefmod.FmodSound",
     "var e:haxefmod.FmodSound = haxefmod.FmodEvent.NULL; trace(e.isNull());",
     "FmodSound is now FmodEvent"),
    ("haxefmod.FmodManager.PlaySound",
     "trace(haxefmod.FmodManager.PlaySound(\"event:/x\").isNull());",
     "FmodManager.PlaySound is now PlayEvent"),
    ("haxefmod.FmodManager.CreateSound",
     "trace(haxefmod.FmodManager.CreateSound(\"event:/x\").isNull());",
     "FmodManager.CreateSound is now CreateEvent"),
    ("haxefmod.FmodManager.PlaySoundOneShot",
     "haxefmod.FmodManager.PlaySoundOneShot(\"event:/x\");",
     "FmodManager.PlaySoundOneShot is now PlayOneShot"),
    ("haxefmod.FmodManager.PlaySoundOneShotAt",
     "haxefmod.FmodManager.PlaySoundOneShotAt(\"event:/x\", 0, 0);",
     "FmodManager.PlaySoundOneShotAt is now PlayOneShotAt"),
    ("haxefmod.FmodManager.PlaySoundOneShotAttached",
     "haxefmod.FmodManager.PlaySoundOneShotAttached(\"event:/x\", null);",
     "FmodManager.PlaySoundOneShotAttached is now PlayOneShotAttached"),
    ("haxefmod.FmodManager.StopAllSounds",
     "haxefmod.FmodManager.StopAllSounds();",
     "FmodManager.StopAllSounds is now StopAllEvents"),
    ("haxefmod.FmodManager.PauseAllSounds",
     "haxefmod.FmodManager.PauseAllSounds();",
     "FmodManager.PauseAllSounds is now PauseAllEvents"),
    ("haxefmod.FmodManager.UnpauseAllSounds",
     "haxefmod.FmodManager.UnpauseAllSounds();",
     "FmodManager.UnpauseAllSounds is now UnpauseAllEvents"),
]

# Aliases in the engine packages compile against that engine. Flixel comes
# from haxelib. The Heaps and Kha packages are new in 3.0.0 and carry none.
ENGINE_DEPRECATED = [
    ("haxefmod.flixel.FmodFlxUtilities.PlaySoundOneShotAttached",
     "haxefmod.flixel.FmodFlxUtilities.PlaySoundOneShotAttached(\"event:/x\", null);",
     "FmodFlxUtilities.PlaySoundOneShotAttached is now PlayOneShotAttached",
     ["-lib", "flixel", "-lib", "openfl", "-lib", "lime", "-D", "FLX_STANDARD_ASSETS_DIRECTORY", "-D", "openfl-html5", "-D", "html5", "-js", "/dev/null"]),
]


def main():
    failures = 0
    with tempfile.TemporaryDirectory(prefix="deprecations-") as workdir:
        stubs = os.path.join(workdir, "kha-stubs")
        subprocess.run([sys.executable, os.path.join(ROOT, "ci", "check-readme-snippets.py"), "--kha-stubs", stubs],
                       capture_output=True, text=True, check=True)
        entries = [(name, body, message, ["--interp"]) for name, body, message in DEPRECATED]
        entries += [(name, body, message, [stubs if a == "KHA_STUBS" else a for a in args]) for name, body, message, args in ENGINE_DEPRECATED]
        for index, (name, body, message, args) in enumerate(entries):
            path = os.path.join(workdir, f"Dep{index}.hx")
            with open(path, "w", encoding="utf-8") as out:
                out.write(f"class Dep{index} {{ static function main() {{ {body} }} }}\n")
            extra = ["-cp", stubs] if stubs in args else []
            args = [a for a in args if a != stubs]
            result = subprocess.run(
                ["haxe", "-cp", ROOT, "-cp", workdir, "--no-output", "-main", f"Dep{index}"] + extra + args,
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
    # Every @:deprecated member in the library must have a row, so a new
    # alias without a compile proof fails here
    listed = {row[0] for row in DEPRECATED + ENGINE_DEPRECATED}
    in_source = 0
    for path in sorted(glob.glob(os.path.join(ROOT, "haxefmod", "**", "*.hx"), recursive=True)):
        with open(path, encoding="utf-8") as fh:
            in_source += fh.read().count("@:deprecated(")
    if in_source != len(listed):
        print(f"FAIL: {in_source} @:deprecated members in haxefmod/, {len(listed)} listed here")
        failures += 1
    print(f"check-deprecations: {len(DEPRECATED) + len(ENGINE_DEPRECATED)} alias(es), {failures} failure(s)")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
