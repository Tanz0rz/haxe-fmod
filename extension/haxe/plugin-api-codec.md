# plugin-api-codec

## FMOD_CODEC_ALLOC_FUNC
verdict: cannot runs on FMOD's threads inside a codec plugin, plugin authoring is C only

## FMOD_CODEC_CLOSE_CALLBACK
verdict: cannot runs on FMOD's threads inside a codec plugin, plugin authoring is C only

## FMOD_CODEC_DESCRIPTION
verdict: cannot codec plugins are written in C, Sound.create loads every format FMOD decodes and PcmStream feeds decoded audio

## FMOD_CODEC_FILE_READ_FUNC
verdict: cannot runs on FMOD's threads inside a codec plugin, plugin authoring is C only

## FMOD_CODEC_FILE_SEEK_FUNC
verdict: cannot runs on FMOD's threads inside a codec plugin, plugin authoring is C only

## FMOD_CODEC_FILE_SIZE_FUNC
verdict: cannot runs on FMOD's threads inside a codec plugin, plugin authoring is C only

## FMOD_CODEC_FILE_TELL_FUNC
verdict: cannot runs on FMOD's threads inside a codec plugin, plugin authoring is C only

## FMOD_CODEC_FREE_FUNC
verdict: cannot runs on FMOD's threads inside a codec plugin, plugin authoring is C only

## FMOD_CODEC_GETLENGTH_CALLBACK
verdict: cannot runs on FMOD's threads inside a codec plugin, plugin authoring is C only

## FMOD_CODEC_GETPOSITION_CALLBACK
verdict: cannot runs on FMOD's threads inside a codec plugin, plugin authoring is C only

## FMOD_CODEC_GETWAVEFORMAT_CALLBACK
verdict: cannot runs on FMOD's threads inside a codec plugin, plugin authoring is C only

## FMOD_CODEC_LOG_FUNC
verdict: cannot runs on FMOD's threads inside a codec plugin, plugin authoring is C only

## FMOD_CODEC_METADATA_FUNC
verdict: cannot runs on FMOD's threads inside a codec plugin, plugin authoring is C only

## FMOD_CODEC_OPEN_CALLBACK
verdict: cannot runs on FMOD's threads inside a codec plugin, plugin authoring is C only

## FMOD_CODEC_PLUGIN_VERSION
verdict: cannot a codec plugin is built in C against this version, a prebuilt codec plugin binary loads with StudioSystem.loadPlugin

## FMOD_CODEC_READ_CALLBACK
verdict: cannot runs on FMOD's threads inside a codec plugin, plugin authoring is C only

## FMOD_CODEC_SEEK_METHOD
verdict: cannot only a codec plugin's seek function receives it, plugin authoring is C only

## FMOD_CODEC_SETPOSITION_CALLBACK
verdict: cannot runs on FMOD's threads inside a codec plugin, plugin authoring is C only

## FMOD_CODEC_SOUNDCREATE_CALLBACK
verdict: cannot runs on FMOD's threads inside a codec plugin, plugin authoring is C only

## FMOD_CODEC_STATE
verdict: cannot FMOD hands it to codec plugin callbacks on its own threads, plugin authoring is C only

## FMOD_CODEC_STATE_FUNCTIONS
verdict: cannot codec plugins are written in C, Sound.create loads every format FMOD decodes and PcmStream feeds decoded audio

## FMOD_CODEC_WAVEFORMAT
verdict: cannot a codec plugin fills it in C, game code reads a loaded sound's format through Sound.getFormat
