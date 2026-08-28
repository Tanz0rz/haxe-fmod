# core-api-dsp

## 2
<!-- FMOD_DSP_CALLBACK -->
DSP callbacks are not exposed since Haxe code cannot run on FMOD's mixer thread. setParameterData copies the bytes, so nothing needs releasing afterwards.

## 3
<!-- FMOD_DSP_CALLBACK_TYPE -->
DSP callbacks are not exposed since Haxe code cannot run on FMOD's mixer thread. setParameterData copies the bytes, so nothing needs releasing afterwards.

## 4
<!-- FMOD_DSP_DATA_PARAMETER_INFO -->
Data parameters are set from Bytes by index. The binding copies the buffer, so the game can drop its reference right after the call.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var reverb = Dsp.create(DspType.CONVOLUTIONREVERB);
var impulse = haxe.io.Bytes.alloc(48000 * 2);
reverb.setParameterData(0, impulse);
```
