# dsp-plugin-api-guide

## *
<!-- page default -->
This guide walks through writing, building, and loading a DSP plug-in library. haxefmod does not bind loadPlugin, registerDSP, or setPluginPath, because the plug-in itself would have to run on FMOD's mixer thread and Haxe code cannot do that on any target.
The built-in effects cover most game needs and are all available through haxefmod.core.Dsp, with the parameter indices listed in FMOD's effects reference. Sounds your code synthesizes can be played through haxefmod.core.PcmStream. See docs/guides/core-api.md.
