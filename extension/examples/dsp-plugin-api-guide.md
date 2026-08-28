# dsp-plugin-api-guide

## 5
<!-- 18.2.2 Loading the Plug-in in the Game -->
A plug-in built from a description loads with StudioSystem.loadPlugin after StudioSystem.setPluginPath names its folder, native only (unsupported in HTML5). Release every unit created from it before StudioSystem.unloadPlugin, which answers FMOD_ERR_DSP_INUSE until the mixer has freed them and succeeds when retried a few frames later.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.ChannelGroup;

StudioSystem.setPluginPath("plugins");
var plugin = StudioSystem.loadPlugin("fmod_gain.dll");
var gain = Dsp.createByPlugin(plugin);
ChannelGroup.master().addDsp(ChannelGroup.DSP_HEAD, gain);

// at shutdown
ChannelGroup.master().removeDsp(gain);
gain.release();
var result = StudioSystem.unloadPlugin(plugin);
if (!result.isOk()) {
    trace('unloadPlugin failed: $result');
}
```

## 8
<!-- 18.7 Multiple Plug-ins Within One File -->
A file that exports a plug-in list loads as one handle. StudioSystem.getNestedPluginCount counts the plug-ins inside it, getNestedPlugin returns each one's handle, and getPluginInfo reports its name, type, and version, native only (unsupported in HTML5).
```haxe
StudioSystem.setPluginPath("plugins");
var plugin = StudioSystem.loadPlugin("fmod_effects.dll");
var count = StudioSystem.getNestedPluginCount(plugin);
for (i in 0...count) {
    var nestedPlugin = StudioSystem.getNestedPlugin(plugin, i);
    var info = StudioSystem.getPluginInfo(nestedPlugin);
    if (info != null) {
        trace(info.name + " type " + info.type + " version " + info.version);
    }
}
```

## *
<!-- page default -->
This guide walks through writing, building, and loading a DSP plug-in library. haxefmod does not bind registerDSP, because a description carries callbacks that would run on FMOD's mixer thread and Haxe code cannot do that on any target. The built library loads with StudioSystem.loadPlugin after StudioSystem.setPluginPath names its folder, native only (unsupported in HTML5), and a Studio project that uses the effect finds it once the plug-in is loaded before its banks.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.ChannelGroup;

StudioSystem.setPluginPath("plugins");
var plugin = StudioSystem.loadPlugin("fmod_gain.dll");
if (plugin != 0) {
    var gain = Dsp.createByPlugin(plugin);
    ChannelGroup.master().addDsp(ChannelGroup.DSP_HEAD, gain);
}
```
The built-in effects cover most game needs and are all available through haxefmod.core.Dsp, with the parameter indices listed in FMOD's effects reference. Sounds your code synthesizes can be played through haxefmod.core.PcmStream. See docs/guides/core-api.md.
