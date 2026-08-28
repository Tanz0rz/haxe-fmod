# core-api-dsp

## FMOD_DSP_CALLBACK
verdict: review note only, decide bound or a category
DSP callbacks are not exposed since Haxe code cannot run on FMOD's mixer thread. setParameterData copies the bytes, so nothing needs releasing afterwards.

## FMOD_DSP_CALLBACK_TYPE
verdict: bound
Type: haxefmod.studio.Types.FmodDspCallbackType
DSP callbacks are not exposed since Haxe code cannot run on FMOD's mixer thread. setParameterData copies the bytes, so nothing needs releasing.

## FMOD_DSP_DATA_PARAMETER_INFO
verdict: cannot the payload of a DSP callback, which runs on the mixer thread, Dsp.setParameterData copies its bytes so nothing needs releasing
