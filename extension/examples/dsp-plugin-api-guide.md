# dsp-plugin-api-guide

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
