# plugin-api-dsp

## FMOD_COMPLEX
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_ALLOC_FUNC
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_BUFFER_ARRAY
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_BUFFER_ARRAY#2
verdict: bound
Haxe cannot fill a mixer buffer array from inside a DSP callback. To generate a square wave from game code, push samples into a PcmStream and let FMOD's mixer drain the ring buffer.
```haxe
import haxefmod.core.PcmStream;

var stream = PcmStream.create(48000, 1);
var channel = stream.play();

// 440 Hz square wave, 16-bit mono, topped up each frame
var period = Std.int(48000 / 440);
var phase = 0;
var buffer = haxe.io.Bytes.alloc(stream.space());
for (i in 0...Std.int(buffer.length / 2)) {
    var sample = phase < period / 2 ? 16000 : -16000;
    buffer.setUInt16(i * 2, sample & 0xFFFF);
    phase = (phase + 1) % period;
}
stream.write(buffer);
```

## FMOD_DSP_BUFFER_ARRAY#3
verdict: bound
Haxe cannot fill a mixer buffer array from inside a DSP callback. To generate a square wave from game code, push samples into a PcmStream and let FMOD's mixer drain the ring buffer.
```haxe
import haxefmod.core.PcmStream;

var stream = PcmStream.create(48000, 1);
var channel = stream.play();

// 440 Hz square wave, 16-bit mono, topped up each frame
var period = Std.int(48000 / 440);
var phase = 0;
var buffer = haxe.io.Bytes.alloc(stream.space());
for (i in 0...Std.int(buffer.length / 2)) {
    var sample = phase < period / 2 ? 16000 : -16000;
    buffer.setUInt16(i * 2, sample & 0xFFFF);
    phase = (phase + 1) % period;
}
stream.write(buffer);
```

## FMOD_DSP_CREATE_CALLBACK
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_DESCRIPTION
verdict: cannot DSP plugins are written in C, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin

## FMOD_DSP_DESCRIPTION#2
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_DESCRIPTION#3
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_DESCRIPTION#4
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_DFT_FFTREAL_FUNC
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_DFT_IFFTREAL_FUNC
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_FREE_FUNC
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_GETBLOCKSIZE_FUNC
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_GETCLOCK_FUNC
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_GETLISTENERATTRIBUTES_FUNC
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_GETPARAM_BOOL_CALLBACK
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_GETPARAM_DATA_CALLBACK
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_GETPARAM_FLOAT_CALLBACK
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_GETPARAM_INT_CALLBACK
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_GETPARAM_VALUESTR_LENGTH
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_GETSAMPLERATE_FUNC
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_GETSPEAKERMODE_FUNC
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_GETUSERDATA_FUNC
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_LOG_FUNC
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_METERING_INFO
verdict: bound
Shape: usage
The metering struct is filled by FMOD for any unit once metering is enabled. Read it through getMetering, which returns peak and RMS arrays per output channel.
```haxe
import haxefmod.core.ChannelGroup;
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var fader = Dsp.create(DspType.FADER);
ChannelGroup.master().addDsp(ChannelGroup.DSP_TAIL, fader);
fader.setMeteringEnabled(false, true);

// each frame
var meter = fader.getMetering();
if (meter != null) trace('peak L ${meter.peak[0]} rms L ${meter.rms[0]}');
```

## FMOD_DSP_PAN_GETROLLOFFGAIN_FUNC
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_PAN_SUMMONOMATRIX_FUNC
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_PAN_SUMMONOTOSURROUNDMATRIX_FUNC
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_PAN_SUMSTEREOMATRIX_FUNC
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_PAN_SUMSTEREOTOSURROUNDMATRIX_FUNC
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_PAN_SUMSURROUNDMATRIX_FUNC
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_PAN_SURROUND_FLAGS
verdict: bound
Type: haxefmod.studio.Types.FmodDspPanSurroundFlags

## FMOD_DSP_PARAMETER_3DATTRIBUTES
verdict: library the 3D position of a pan unit is not set by parameter, play the source through a 3D channel and call Channel.set3DAttributes

## FMOD_DSP_PARAMETER_3DATTRIBUTES_MULTI
verdict: library the 3D position of a pan unit is not set by parameter, play the source through a 3D channel and call Channel.set3DAttributes

## FMOD_DSP_PARAMETER_ATTENUATION_RANGE
verdict: covered a data parameter format the unit reads, Dsp.setParameterData hands it over as raw bytes and Dsp.getDataParameterIndex finds its index

## FMOD_DSP_PARAMETER_DATA_TYPE
verdict: bound
Type: haxefmod.studio.Types.FmodDspParameterDataType

## FMOD_DSP_PARAMETER_DESC
verdict: bound
Shape: usage
haxefmod does not expose the descriptor struct. getParameterInfo returns its name, type, and range as a plain structure (null in HTML5).
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var eq = Dsp.create(DspType.THREE_EQ);
for (i in 0...eq.getParameterCount()) {
    var info = eq.getParameterInfo(i);
    if (info != null) trace('${info.name} type ${info.type} ${info.min}..${info.max} default ${info.defaultValue}');
}
```

## FMOD_DSP_PARAMETER_DESC_BOOL
verdict: cannot a plugin's parameter descriptor, plugin authoring is C only, Dsp.getParameterInfo reports a parameter's name, type, and range

## FMOD_DSP_PARAMETER_DESC_DATA
verdict: cannot a plugin's parameter descriptor, plugin authoring is C only, Dsp.getParameterInfo reports a parameter's name, type, and range

## FMOD_DSP_PARAMETER_DESC_FLOAT
verdict: cannot a plugin's parameter descriptor, plugin authoring is C only, Dsp.getParameterInfo reports a parameter's name, type, and range

## FMOD_DSP_PARAMETER_DESC_INT
verdict: cannot a plugin's parameter descriptor, plugin authoring is C only, Dsp.getParameterInfo reports a parameter's name, type, and range

## FMOD_DSP_PARAMETER_DYNAMIC_RESPONSE
verdict: covered a data parameter format the unit reads, Dsp.setParameterData hands it over as raw bytes and Dsp.getDataParameterIndex finds its index

## FMOD_DSP_PARAMETER_FFT
verdict: bound
Shape: usage
The FFT data parameter belongs to the built-in FFT unit. Attach one where you want to listen and read the spectrum with getFftSpectrum instead of decoding the struct by hand.
```haxe
import haxefmod.core.ChannelGroup;
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var fft = Dsp.create(DspType.FFT);
ChannelGroup.master().addDsp(ChannelGroup.DSP_TAIL, fft);

// each frame
var spectrum = fft.getFftSpectrum(64);
if (spectrum != null) trace('bass ${spectrum[1]}');
```

## FMOD_DSP_PARAMETER_FINITE_LENGTH
verdict: covered a data parameter format the unit reads, Dsp.setParameterData hands it over as raw bytes and Dsp.getDataParameterIndex finds its index

## FMOD_DSP_PARAMETER_FLOAT_MAPPING
verdict: cannot a plugin's parameter descriptor, plugin authoring is C only, Dsp.getParameterInfo reports a parameter's name, type, and range

## FMOD_DSP_PARAMETER_FLOAT_MAPPING_PIECEWISE_LINEAR
verdict: cannot a plugin's parameter descriptor, plugin authoring is C only, Dsp.getParameterInfo reports a parameter's name, type, and range

## FMOD_DSP_PARAMETER_FLOAT_MAPPING_TYPE
verdict: bound
Type: haxefmod.studio.Types.FmodDspParameterFloatMappingType

## FMOD_DSP_PARAMETER_OVERALLGAIN
verdict: covered a data parameter format the unit reads, Dsp.setParameterData hands it over as raw bytes and Dsp.getDataParameterIndex finds its index

## FMOD_DSP_PARAMETER_SIDECHAIN
verdict: covered a data parameter format the unit reads, Dsp.setParameterData hands it over as raw bytes and Dsp.getDataParameterIndex finds its index

## FMOD_DSP_PARAMETER_TYPE
verdict: bound
Type: haxefmod.studio.Types.FmodDspParameterType
Reported in the type field of Dsp.getParameterInfo. Dsp.PARAMETER_* are the same values.

## FMOD_DSP_PROCESS_CALLBACK
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_PROCESS_CALLBACK#2
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_PROCESS_CALLBACK#3
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_PROCESS_OPERATION
verdict: bound
Type: haxefmod.studio.Types.FmodDspProcessOperation

## FMOD_DSP_READ_CALLBACK
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_READ_CALLBACK#2
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_READ_CALLBACK#3
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_READ_CALLBACK#4
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_REALLOC_FUNC
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_RELEASE_CALLBACK
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_RESET_CALLBACK
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_SETPARAM_BOOL_CALLBACK
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_SETPARAM_DATA_CALLBACK
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_SETPARAM_FLOAT_CALLBACK
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_SETPARAM_INT_CALLBACK
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_SETPOSITION_CALLBACK
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_SHOULDIPROCESS_CALLBACK
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_SHOULDIPROCESS_CALLBACK#2
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_STATE
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_STATE#2
verdict: review note only, decide bound or a category
No Haxe equivalent. This is the C source of a plug-in oscillator, which keeps its phase in plugindata on the mixer thread. FMOD ships the same oscillator as a built-in unit, see the Haxe example under the next tab (Dsp.create(DspType.OSCILLATOR)).

## FMOD_DSP_STATE#3
verdict: bound
A plug-in oscillator keeps its phase in plugindata on the mixer thread, which Haxe cannot do. FMOD ships an oscillator as a built-in unit, so create one and play it as a sound source.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var osc = Dsp.create(DspType.OSCILLATOR);
osc.setParameterInt(0, 0); // waveform: 0 sine, 1 square, 2 saw up, 3 saw down, 4 triangle, 5 noise
osc.setParameter(1, 440); // rate in Hz
var tone = osc.play();
tone.setVolume(0.5);

// later
tone.stop();
osc.release();
```

## FMOD_DSP_STATE#4
verdict: bound
A plug-in oscillator keeps its phase in plugindata on the mixer thread, which Haxe cannot do. FMOD ships an oscillator as a built-in unit, so create one and play it as a sound source.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var osc = Dsp.create(DspType.OSCILLATOR);
osc.setParameterInt(0, 0); // waveform: 0 sine, 1 square, 2 saw up, 3 saw down, 4 triangle, 5 noise
osc.setParameter(1, 440); // rate in Hz
var tone = osc.play();
tone.setVolume(0.5);

// later
tone.stop();
osc.release();
```

## FMOD_DSP_STATE_DFT_FUNCTIONS
verdict: cannot DSP plugins are written in C, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin

## FMOD_DSP_STATE_FUNCTIONS
verdict: cannot DSP plugins are written in C, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin

## FMOD_DSP_STATE_PAN_FUNCTIONS
verdict: cannot DSP plugins are written in C, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin

## FMOD_DSP_SYSTEM_DEREGISTER_CALLBACK
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_SYSTEM_MIX_CALLBACK
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_DSP_SYSTEM_REGISTER_CALLBACK
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.

## FMOD_PLUGIN_SDK_VERSION
verdict: review note only, decide bound or a category
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.
