#!/usr/bin/env python3
"""Checks the HTML5 compile-time gate on every native-only method.

Each row of GATED names a public method that FMOD's web build cannot
serve. haxefmod declares those methods twice (see
haxefmod/studio/native/Html5Gate.hx): a macro that stops compilation at
the call site on a js build, and the real body everywhere else. For each
row this script compiles a one-call fixture four ways and expects:

  js                                   fails, naming the method and
                                       "is unsupported in HTML5"
  js -D haxefmod_html5_allow_unsupported   compiles
  hl                                   compiles
  interp                               compiles

A gate that is removed, renamed, or loses its message fails the check.
The script also checks that the doc comment above each gated method
still carries the phrase "unsupported in HTML5".

Run: python3 ci/check-html5-gate.py
"""

import os
import re
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFINE = "haxefmod_html5_allow_unsupported"

# (type, method, source file, statements that call the method)
V = "{x: 0.0, y: 0.0, z: 0.0}"
GATED = [
    ("StudioSystem", "getMemoryUsage", "haxefmod/studio/StudioSystem.hx",
     "var r = StudioSystem.getMemoryUsage();"),
    ("StudioSystem", "getRecordDriverCount", "haxefmod/studio/StudioSystem.hx",
     "var r = StudioSystem.getRecordDriverCount();"),
    ("StudioSystem", "getRecordDriverInfo", "haxefmod/studio/StudioSystem.hx",
     "var r = StudioSystem.getRecordDriverInfo(0);"),
    ("StudioSystem", "recordStart", "haxefmod/studio/StudioSystem.hx",
     "var s:Sound = cast 1; var r = StudioSystem.recordStart(0, s, true);"),
    ("StudioSystem", "recordStop", "haxefmod/studio/StudioSystem.hx",
     "var r = StudioSystem.recordStop(0);"),
    ("StudioSystem", "isRecording", "haxefmod/studio/StudioSystem.hx",
     "var r = StudioSystem.isRecording(0);"),
    ("StudioSystem", "getRecordPosition", "haxefmod/studio/StudioSystem.hx",
     "var r = StudioSystem.getRecordPosition(0);"),
    ("Bus", "getCpuUsage", "haxefmod/studio/Bus.hx",
     "var b:Bus = cast 1; var r = b.getCpuUsage();"),
    ("EventInstance", "getCpuUsage", "haxefmod/studio/EventInstance.hx",
     "var e:EventInstance = cast 1; var r = e.getCpuUsage();"),
    ("Sound", "createRecordBuffer", "haxefmod/core/Sound.hx",
     "var r = Sound.createRecordBuffer(48000, 1, 1);"),
    ("Sound", "readData", "haxefmod/core/Sound.hx",
     "var s:Sound = cast 1; var r = s.readData(haxe.io.Bytes.alloc(16));"),
    ("Sound", "seekData", "haxefmod/core/Sound.hx",
     "var s:Sound = cast 1; var r = s.seekData(0);"),
    ("Sound", "set3DCustomRolloff", "haxefmod/core/Sound.hx",
     "var s:Sound = cast 1; var r = s.set3DCustomRolloff([" + V + "]);"),
    ("Sound", "get3DCustomRolloff", "haxefmod/core/Sound.hx",
     "var s:Sound = cast 1; var r = s.get3DCustomRolloff();"),
    ("Channel", "set3DCustomRolloff", "haxefmod/core/Channel.hx",
     "var c:Channel = cast 1; var r = c.set3DCustomRolloff([" + V + "]);"),
    ("Channel", "get3DCustomRolloff", "haxefmod/core/Channel.hx",
     "var c:Channel = cast 1; var r = c.get3DCustomRolloff();"),
    ("ChannelGroup", "set3DCustomRolloff", "haxefmod/core/ChannelGroup.hx",
     "var g:ChannelGroup = cast 1; var r = g.set3DCustomRolloff([" + V + "]);"),
    ("ChannelGroup", "get3DCustomRolloff", "haxefmod/core/ChannelGroup.hx",
     "var g:ChannelGroup = cast 1; var r = g.get3DCustomRolloff();"),
    ("EventInstance", "assignProgrammerSound", "haxefmod/studio/EventInstance.hx",
     "var e:EventInstance = cast 1; var r = e.assignProgrammerSound(\"key\");"),
    ("EventInstance", "clearProgrammerSound", "haxefmod/studio/EventInstance.hx",
     "var e:EventInstance = cast 1; var r = e.clearProgrammerSound();"),
    ("EventInstance", "assignProgrammerSoundFrom", "haxefmod/studio/EventInstance.hx",
     "var e:EventInstance = cast 1; var r = e.assignProgrammerSoundFrom(cast 2, 0);"),
    ("EventInstance", "assignProgrammerSoundForName", "haxefmod/studio/EventInstance.hx",
     "var e:EventInstance = cast 1; var r = e.assignProgrammerSoundForName(\"Line\", \"key\");"),
    ("EventInstance", "assignProgrammerSounds", "haxefmod/studio/EventInstance.hx",
     "var e:EventInstance = cast 1; var r = e.assignProgrammerSounds([\"Line\" => \"key\"]);"),
    ("EventInstance", "getMemoryUsage", "haxefmod/studio/EventInstance.hx",
     "var e:EventInstance = cast 1; var r = e.getMemoryUsage();"),
    ("Bus", "getMemoryUsage", "haxefmod/studio/Bus.hx",
     "var b:Bus = cast 1; var r = b.getMemoryUsage();"),
    ("Geometry", "create", "haxefmod/core/Geometry.hx",
     "var r = Geometry.create(8, 32);"),
    ("Geometry", "load", "haxefmod/core/Geometry.hx",
     "var r = Geometry.load(haxe.io.Bytes.alloc(16));"),
    ("Geometry", "setWorldSize", "haxefmod/core/Geometry.hx",
     "var r = Geometry.setWorldSize(1000);"),
    ("Geometry", "getWorldSize", "haxefmod/core/Geometry.hx",
     "var r = Geometry.getWorldSize();"),
    ("Geometry", "getOcclusion", "haxefmod/core/Geometry.hx",
     "var r = Geometry.getOcclusion(" + V + ", " + V + ");"),
    ("Geometry", "release", "haxefmod/core/Geometry.hx",
     "var g:Geometry = cast 1; var r = g.release();"),
    ("Geometry", "addPolygon", "haxefmod/core/Geometry.hx",
     "var g:Geometry = cast 1; var r = g.addPolygon(1, 1, false, [" + V + ", " + V + ", " + V + "]);"),
    ("Geometry", "getNumPolygons", "haxefmod/core/Geometry.hx",
     "var g:Geometry = cast 1; var r = g.getNumPolygons();"),
    ("Geometry", "getMaxPolygons", "haxefmod/core/Geometry.hx",
     "var g:Geometry = cast 1; var r = g.getMaxPolygons();"),
    ("Geometry", "getPolygonNumVertices", "haxefmod/core/Geometry.hx",
     "var g:Geometry = cast 1; var r = g.getPolygonNumVertices(0);"),
    ("Geometry", "setPolygonVertex", "haxefmod/core/Geometry.hx",
     "var g:Geometry = cast 1; var r = g.setPolygonVertex(0, 0, " + V + ");"),
    ("Geometry", "getPolygonVertex", "haxefmod/core/Geometry.hx",
     "var g:Geometry = cast 1; var r = g.getPolygonVertex(0, 0);"),
    ("Geometry", "setPolygonAttributes", "haxefmod/core/Geometry.hx",
     "var g:Geometry = cast 1; var r = g.setPolygonAttributes(0, 1, 1, false);"),
    ("Geometry", "getPolygonAttributes", "haxefmod/core/Geometry.hx",
     "var g:Geometry = cast 1; var r = g.getPolygonAttributes(0);"),
    ("Geometry", "setActive", "haxefmod/core/Geometry.hx",
     "var g:Geometry = cast 1; var r = g.setActive(true);"),
    ("Geometry", "getActive", "haxefmod/core/Geometry.hx",
     "var g:Geometry = cast 1; var r = g.getActive();"),
    ("Geometry", "setRotation", "haxefmod/core/Geometry.hx",
     "var g:Geometry = cast 1; var r = g.setRotation(" + V + ", " + V + ");"),
    ("Geometry", "getRotation", "haxefmod/core/Geometry.hx",
     "var g:Geometry = cast 1; var r = g.getRotation();"),
    ("Geometry", "setPosition", "haxefmod/core/Geometry.hx",
     "var g:Geometry = cast 1; var r = g.setPosition(" + V + ");"),
    ("Geometry", "getPosition", "haxefmod/core/Geometry.hx",
     "var g:Geometry = cast 1; var r = g.getPosition();"),
    ("Geometry", "setScale", "haxefmod/core/Geometry.hx",
     "var g:Geometry = cast 1; var r = g.setScale(" + V + ");"),
    ("Geometry", "getScale", "haxefmod/core/Geometry.hx",
     "var g:Geometry = cast 1; var r = g.getScale();"),
    ("Geometry", "save", "haxefmod/core/Geometry.hx",
     "var g:Geometry = cast 1; var r = g.save();"),
    ("Channel", "getFadePoints", "haxefmod/core/Channel.hx",
     "var c:Channel = cast 1; var r = c.getFadePoints();"),
    ("Channel", "getMixMatrix", "haxefmod/core/Channel.hx",
     "var c:Channel = cast 1; var r = c.getMixMatrix(2, 2);"),
    ("ChannelGroup", "getFadePoints", "haxefmod/core/ChannelGroup.hx",
     "var g:ChannelGroup = cast 1; var r = g.getFadePoints();"),
    ("ChannelGroup", "getMixMatrix", "haxefmod/core/ChannelGroup.hx",
     "var g:ChannelGroup = cast 1; var r = g.getMixMatrix(2, 2);"),
    ("DspConnection", "getMixMatrix", "haxefmod/core/DspConnection.hx",
     "var c:DspConnection = cast 1; var r = c.getMixMatrix(2, 2);"),
    ("CoreSystem", "getDefaultMixMatrix", "haxefmod/core/CoreSystem.hx",
     "var r = CoreSystem.getDefaultMixMatrix(3, 3);"),
    ("Dsp", "getParameterInfo", "haxefmod/core/Dsp.hx",
     "var d:Dsp = cast 1; var r = d.getParameterInfo(0);"),
    ("StudioSystem", "setPluginPath", "haxefmod/studio/StudioSystem.hx",
     "var r = StudioSystem.setPluginPath(\"plugins\");"),
    ("StudioSystem", "loadPlugin", "haxefmod/studio/StudioSystem.hx",
     "var r = StudioSystem.loadPlugin(\"gain.so\");"),
    ("StudioSystem", "unloadPlugin", "haxefmod/studio/StudioSystem.hx",
     "var r = StudioSystem.unloadPlugin(1);"),
    ("StudioSystem", "getPluginCount", "haxefmod/studio/StudioSystem.hx",
     "var r = StudioSystem.getPluginCount(FmodPluginType.DSP);"),
    ("StudioSystem", "getPluginHandle", "haxefmod/studio/StudioSystem.hx",
     "var r = StudioSystem.getPluginHandle(FmodPluginType.DSP, 0);"),
    ("StudioSystem", "getPluginInfo", "haxefmod/studio/StudioSystem.hx",
     "var r = StudioSystem.getPluginInfo(1);"),
    ("StudioSystem", "getNestedPluginCount", "haxefmod/studio/StudioSystem.hx",
     "var r = StudioSystem.getNestedPluginCount(1);"),
    ("StudioSystem", "getNestedPlugin", "haxefmod/studio/StudioSystem.hx",
     "var r = StudioSystem.getNestedPlugin(1, 0);"),
    ("Dsp", "createByPlugin", "haxefmod/core/Dsp.hx",
     "var r = Dsp.createByPlugin(1);"),
    ("Dsp", "getPluginInfo", "haxefmod/core/Dsp.hx",
     "var r = Dsp.getPluginInfo(1);"),
    ("StudioSystem", "getAdvancedSettings", "haxefmod/studio/StudioSystem.hx",
     "var r = StudioSystem.getAdvancedSettings();"),
    ("StudioSystem", "getStudioAdvancedSettings", "haxefmod/studio/StudioSystem.hx",
     "var r = StudioSystem.getStudioAdvancedSettings();"),
    ("Sound", "getMusicNumChannels", "haxefmod/core/Sound.hx",
     "var s:Sound = cast 1; var r = s.getMusicNumChannels();"),
    ("Sound", "setMusicChannelVolume", "haxefmod/core/Sound.hx",
     "var s:Sound = cast 1; var r = s.setMusicChannelVolume(0, 0.5);"),
    ("Sound", "getMusicChannelVolume", "haxefmod/core/Sound.hx",
     "var s:Sound = cast 1; var r = s.getMusicChannelVolume(0);"),
    ("Sound", "setMusicSpeed", "haxefmod/core/Sound.hx",
     "var s:Sound = cast 1; var r = s.setMusicSpeed(1.5);"),
    ("Sound", "getMusicSpeed", "haxefmod/core/Sound.hx",
     "var s:Sound = cast 1; var r = s.getMusicSpeed();"),
    ("Sound", "getTag", "haxefmod/core/Sound.hx",
     "var s:Sound = cast 1; var r = s.getTag(null, 0);"),
    ("Dsp", "addInputPreallocated", "haxefmod/core/Dsp.hx",
     "var d:Dsp = cast 1; var c:DspConnection = cast 1; var r = d.addInputPreallocated(d, c);"),
    ("CoreSystem", "getDspInfoByType", "haxefmod/core/CoreSystem.hx",
     "var r = CoreSystem.getDspInfoByType(DspType.FADER);"),
]

IMPORTS = "\n".join([
    "import haxefmod.studio.StudioSystem;",
    "import haxefmod.core.Sound;",
    "import haxefmod.studio.EventInstance;",
    "import haxefmod.studio.Bus;",
    "import haxefmod.core.Channel;",
    "import haxefmod.core.ChannelGroup;",
    "import haxefmod.core.Geometry;",
    "import haxefmod.core.CoreSystem;",
    "import haxefmod.core.Dsp;",
    "import haxefmod.core.DspConnection;",
    "import haxefmod.core.DspType;",
    "import haxefmod.core.Dsp;",
    "import haxefmod.studio.Types;",
])

# (label, extra haxe args, must compile)
MODES = [
    ("js", ["-js", "/dev/null"], False),
    ("js+define", ["-js", "/dev/null", "-D", DEFINE], True),
    ("hl", ["-hl", "/dev/null"], True),
    ("interp", ["--interp"], True),
]


def compile_fixture(fixture_dir, main, extra):
    cmd = ["haxe", "-cp", ROOT, "-cp", fixture_dir, "-main", main, "--no-output"] + extra
    proc = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    return proc.returncode, proc.stdout + proc.stderr


def check_row(fixture_dir, index, row):
    type_name, method, _source, statements = row
    main = "Gate%02d" % index
    with open(os.path.join(fixture_dir, main + ".hx"), "w", encoding="utf-8") as fh:
        fh.write(IMPORTS + "\nclass " + main + " {\n    static function main() {\n        "
                 + statements + "\n    }\n}\n")
    label = type_name + "." + method
    failures = []
    for mode, extra, must_compile in MODES:
        code, output = compile_fixture(fixture_dir, main, extra)
        if must_compile:
            if code != 0:
                failures.append("%s [%s] should compile:\n%s" % (label, mode, output.strip()))
        else:
            if code == 0:
                failures.append("%s [%s] compiled, the gate is missing" % (label, mode))
            elif label + " is unsupported in HTML5" not in output:
                failures.append("%s [%s] failed without the gate message:\n%s" % (label, mode, output.strip()))
    return label, failures


def check_doc(row):
    """The doc comment right above the gated method must say unsupported in HTML5."""
    type_name, method, source, _statements = row
    text = open(os.path.join(ROOT, source), encoding="utf-8").read()
    pattern = re.compile(r"/\*\*(?P<doc>(?:(?!\*/).)*)\*/\s*public\s+(?:static\s+)?macro\s+function\s+" + method + r"\(", re.S)
    match = pattern.search(text)
    if not match:
        return "%s.%s: no macro declaration with a doc comment in %s" % (type_name, method, source)
    doc = re.sub(r"\s*\n\s*\*\s*", " ", match.group("doc"))
    if "unsupported in HTML5" not in doc:
        return "%s.%s: doc comment lacks the phrase unsupported in HTML5" % (type_name, method)
    return None


def main():
    failures = []
    for row in GATED:
        problem = check_doc(row)
        if problem:
            failures.append(problem)
    with tempfile.TemporaryDirectory() as fixture_dir:
        with ThreadPoolExecutor(max_workers=max(1, os.cpu_count() or 1)) as pool:
            results = list(pool.map(lambda pair: check_row(fixture_dir, pair[0], pair[1]), enumerate(GATED)))
    for _label, row_failures in results:
        failures.extend(row_failures)
    for failure in failures:
        print("FAIL " + failure)
    print("check-html5-gate: %d gated methods, %d compiles, %d failures"
          % (len(GATED), len(GATED) * len(MODES), len(failures)))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
