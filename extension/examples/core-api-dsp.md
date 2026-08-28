# core-api-dsp

## 2
<!-- FMOD_DSP_CALLBACK -->
DSP callbacks are not exposed since Haxe code cannot run on FMOD's mixer thread. setParameterData copies the bytes, so nothing needs releasing afterwards.

## 3
<!-- FMOD_DSP_CALLBACK_TYPE -->
No Haxe equivalent. DSP callbacks are not exposed since Haxe code cannot run on FMOD's mixer thread, setParameterData copies the bytes so nothing needs releasing.

## 4
<!-- FMOD_DSP_DATA_PARAMETER_INFO -->
No Haxe equivalent. Dsp.setParameterData(index, bytes) copies the buffer, so the game can drop its reference right after the call.
