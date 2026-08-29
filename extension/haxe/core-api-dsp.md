# core-api-dsp

## FMOD_DSP_CALLBACK
verdict: cannot FMOD calls it on its mixer thread, no Haxe target can run code there. Dsp.setParameterData copies its bytes, so no release callback is needed.

## FMOD_DSP_CALLBACK_TYPE
verdict: bound
Type: haxefmod.studio.Types.FmodDspCallbackType

## FMOD_DSP_DATA_PARAMETER_INFO
verdict: cannot the payload of a DSP callback, which runs on the mixer thread. Dsp.setParameterData copies its bytes so nothing needs releasing.
