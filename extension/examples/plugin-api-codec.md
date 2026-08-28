# plugin-api-codec

## *
<!-- page default -->
A codec plug-in decodes file data into PCM from callbacks that FMOD invokes on its own streaming and mixer threads. Haxe cannot supply those callbacks, so haxefmod exposes no codec registration.
The formats FMOD decodes on its own (WAV, OGG, MP3, FLAC, FSB and more) load through CoreSound.create, and audio your game decodes itself can be fed to FMOD as PCM through haxefmod.core.PcmStream. See docs/guides/core-api.md.
