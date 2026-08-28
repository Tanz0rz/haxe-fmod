# plugin-api-output

## *
<!-- page default -->
An output plug-in is the driver that pulls mixed audio out of FMOD and hands it to a device, and its callbacks run on FMOD's mixer thread in C. There is no way to implement one from Haxe, so haxefmod offers no output registration.
haxefmod initializes FMOD with the platform's default output on each target. Effects go through haxefmod.core.Dsp, generated audio through haxefmod.core.PcmStream. See docs/guides/core-api.md and LIMITATIONS.md.
