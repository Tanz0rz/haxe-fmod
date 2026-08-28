# dsp-plugin-api-guide

## *
<!-- page default -->
This guide walks through writing, building, and loading a DSP plug-in library. haxefmod does not bind registerDSP, because a description carries callbacks that would run on FMOD's mixer thread and Haxe code cannot do that on any target. loadPlugin and setPluginPath only load a prebuilt binary with no Haxe involved, so they are deferred until CI has a plug-in binary to test against, and Studio projects that use plug-in effects cannot load them from haxefmod yet.
The built-in effects cover most game needs and are all available through haxefmod.core.Dsp, with the parameter indices listed in FMOD's effects reference. Sounds your code synthesizes can be played through haxefmod.core.PcmStream. See docs/guides/core-api.md.
