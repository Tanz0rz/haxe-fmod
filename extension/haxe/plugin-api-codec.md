# plugin-api-codec

## FMOD_CODEC_ALLOC_FUNC
verdict: review note only, decide bound or a category
A codec plug-in decodes file data into PCM from callbacks that FMOD invokes on its own streaming and mixer threads. Haxe cannot supply those callbacks, so haxefmod exposes no codec registration.
The formats FMOD decodes on its own (WAV, OGG, MP3, FLAC, FSB and more) load through Sound.create, and audio your game decodes itself can be fed to FMOD as PCM through haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_CODEC_CLOSE_CALLBACK
verdict: review note only, decide bound or a category
A codec plug-in decodes file data into PCM from callbacks that FMOD invokes on its own streaming and mixer threads. Haxe cannot supply those callbacks, so haxefmod exposes no codec registration.
The formats FMOD decodes on its own (WAV, OGG, MP3, FLAC, FSB and more) load through Sound.create, and audio your game decodes itself can be fed to FMOD as PCM through haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_CODEC_DESCRIPTION
verdict: cannot codec plugins are written in C, Sound.create loads every format FMOD decodes and PcmStream feeds decoded audio

## FMOD_CODEC_FILE_READ_FUNC
verdict: review note only, decide bound or a category
A codec plug-in decodes file data into PCM from callbacks that FMOD invokes on its own streaming and mixer threads. Haxe cannot supply those callbacks, so haxefmod exposes no codec registration.
The formats FMOD decodes on its own (WAV, OGG, MP3, FLAC, FSB and more) load through Sound.create, and audio your game decodes itself can be fed to FMOD as PCM through haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_CODEC_FILE_SEEK_FUNC
verdict: review note only, decide bound or a category
A codec plug-in decodes file data into PCM from callbacks that FMOD invokes on its own streaming and mixer threads. Haxe cannot supply those callbacks, so haxefmod exposes no codec registration.
The formats FMOD decodes on its own (WAV, OGG, MP3, FLAC, FSB and more) load through Sound.create, and audio your game decodes itself can be fed to FMOD as PCM through haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_CODEC_FILE_SIZE_FUNC
verdict: review note only, decide bound or a category
A codec plug-in decodes file data into PCM from callbacks that FMOD invokes on its own streaming and mixer threads. Haxe cannot supply those callbacks, so haxefmod exposes no codec registration.
The formats FMOD decodes on its own (WAV, OGG, MP3, FLAC, FSB and more) load through Sound.create, and audio your game decodes itself can be fed to FMOD as PCM through haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_CODEC_FILE_TELL_FUNC
verdict: review note only, decide bound or a category
A codec plug-in decodes file data into PCM from callbacks that FMOD invokes on its own streaming and mixer threads. Haxe cannot supply those callbacks, so haxefmod exposes no codec registration.
The formats FMOD decodes on its own (WAV, OGG, MP3, FLAC, FSB and more) load through Sound.create, and audio your game decodes itself can be fed to FMOD as PCM through haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_CODEC_FREE_FUNC
verdict: review note only, decide bound or a category
A codec plug-in decodes file data into PCM from callbacks that FMOD invokes on its own streaming and mixer threads. Haxe cannot supply those callbacks, so haxefmod exposes no codec registration.
The formats FMOD decodes on its own (WAV, OGG, MP3, FLAC, FSB and more) load through Sound.create, and audio your game decodes itself can be fed to FMOD as PCM through haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_CODEC_GETLENGTH_CALLBACK
verdict: review note only, decide bound or a category
A codec plug-in decodes file data into PCM from callbacks that FMOD invokes on its own streaming and mixer threads. Haxe cannot supply those callbacks, so haxefmod exposes no codec registration.
The formats FMOD decodes on its own (WAV, OGG, MP3, FLAC, FSB and more) load through Sound.create, and audio your game decodes itself can be fed to FMOD as PCM through haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_CODEC_GETPOSITION_CALLBACK
verdict: review note only, decide bound or a category
A codec plug-in decodes file data into PCM from callbacks that FMOD invokes on its own streaming and mixer threads. Haxe cannot supply those callbacks, so haxefmod exposes no codec registration.
The formats FMOD decodes on its own (WAV, OGG, MP3, FLAC, FSB and more) load through Sound.create, and audio your game decodes itself can be fed to FMOD as PCM through haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_CODEC_GETWAVEFORMAT_CALLBACK
verdict: review note only, decide bound or a category
A codec plug-in decodes file data into PCM from callbacks that FMOD invokes on its own streaming and mixer threads. Haxe cannot supply those callbacks, so haxefmod exposes no codec registration.
The formats FMOD decodes on its own (WAV, OGG, MP3, FLAC, FSB and more) load through Sound.create, and audio your game decodes itself can be fed to FMOD as PCM through haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_CODEC_LOG_FUNC
verdict: review note only, decide bound or a category
A codec plug-in decodes file data into PCM from callbacks that FMOD invokes on its own streaming and mixer threads. Haxe cannot supply those callbacks, so haxefmod exposes no codec registration.
The formats FMOD decodes on its own (WAV, OGG, MP3, FLAC, FSB and more) load through Sound.create, and audio your game decodes itself can be fed to FMOD as PCM through haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_CODEC_METADATA_FUNC
verdict: review note only, decide bound or a category
A codec plug-in decodes file data into PCM from callbacks that FMOD invokes on its own streaming and mixer threads. Haxe cannot supply those callbacks, so haxefmod exposes no codec registration.
The formats FMOD decodes on its own (WAV, OGG, MP3, FLAC, FSB and more) load through Sound.create, and audio your game decodes itself can be fed to FMOD as PCM through haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_CODEC_OPEN_CALLBACK
verdict: review note only, decide bound or a category
A codec plug-in decodes file data into PCM from callbacks that FMOD invokes on its own streaming and mixer threads. Haxe cannot supply those callbacks, so haxefmod exposes no codec registration.
The formats FMOD decodes on its own (WAV, OGG, MP3, FLAC, FSB and more) load through Sound.create, and audio your game decodes itself can be fed to FMOD as PCM through haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_CODEC_PLUGIN_VERSION
verdict: review note only, decide bound or a category
A codec plug-in decodes file data into PCM from callbacks that FMOD invokes on its own streaming and mixer threads. Haxe cannot supply those callbacks, so haxefmod exposes no codec registration.
The formats FMOD decodes on its own (WAV, OGG, MP3, FLAC, FSB and more) load through Sound.create, and audio your game decodes itself can be fed to FMOD as PCM through haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_CODEC_READ_CALLBACK
verdict: review note only, decide bound or a category
A codec plug-in decodes file data into PCM from callbacks that FMOD invokes on its own streaming and mixer threads. Haxe cannot supply those callbacks, so haxefmod exposes no codec registration.
The formats FMOD decodes on its own (WAV, OGG, MP3, FLAC, FSB and more) load through Sound.create, and audio your game decodes itself can be fed to FMOD as PCM through haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_CODEC_SEEK_METHOD
verdict: review note only, decide bound or a category
A codec plug-in decodes file data into PCM from callbacks that FMOD invokes on its own streaming and mixer threads. Haxe cannot supply those callbacks, so haxefmod exposes no codec registration.
The formats FMOD decodes on its own (WAV, OGG, MP3, FLAC, FSB and more) load through Sound.create, and audio your game decodes itself can be fed to FMOD as PCM through haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_CODEC_SETPOSITION_CALLBACK
verdict: review note only, decide bound or a category
A codec plug-in decodes file data into PCM from callbacks that FMOD invokes on its own streaming and mixer threads. Haxe cannot supply those callbacks, so haxefmod exposes no codec registration.
The formats FMOD decodes on its own (WAV, OGG, MP3, FLAC, FSB and more) load through Sound.create, and audio your game decodes itself can be fed to FMOD as PCM through haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_CODEC_SOUNDCREATE_CALLBACK
verdict: review note only, decide bound or a category
A codec plug-in decodes file data into PCM from callbacks that FMOD invokes on its own streaming and mixer threads. Haxe cannot supply those callbacks, so haxefmod exposes no codec registration.
The formats FMOD decodes on its own (WAV, OGG, MP3, FLAC, FSB and more) load through Sound.create, and audio your game decodes itself can be fed to FMOD as PCM through haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_CODEC_STATE
verdict: review note only, decide bound or a category
A codec plug-in decodes file data into PCM from callbacks that FMOD invokes on its own streaming and mixer threads. Haxe cannot supply those callbacks, so haxefmod exposes no codec registration.
The formats FMOD decodes on its own (WAV, OGG, MP3, FLAC, FSB and more) load through Sound.create, and audio your game decodes itself can be fed to FMOD as PCM through haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_CODEC_STATE_FUNCTIONS
verdict: cannot codec plugins are written in C, Sound.create loads every format FMOD decodes and PcmStream feeds decoded audio

## FMOD_CODEC_WAVEFORMAT
verdict: review note only, decide bound or a category
A codec plug-in decodes file data into PCM from callbacks that FMOD invokes on its own streaming and mixer threads. Haxe cannot supply those callbacks, so haxefmod exposes no codec registration.
The formats FMOD decodes on its own (WAV, OGG, MP3, FLAC, FSB and more) load through Sound.create, and audio your game decodes itself can be fed to FMOD as PCM through haxefmod.core.PcmStream. See docs/guides/core-api.md.
