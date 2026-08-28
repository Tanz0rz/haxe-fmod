# plugin-api-dsp

## FMOD_COMPLEX
verdict: cannot the sample type of the plugin DFT helpers, received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host

## FMOD_DSP_ALLOC_FUNC
verdict: cannot received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin

## FMOD_DSP_BUFFER_ARRAY
verdict: cannot the mixer buffers received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units

## FMOD_DSP_BUFFER_ARRAY#2
verdict: bound
A plugin process callback cannot run in Haxe, the built-in oscillator unit plays the same square wave from game code.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspParameters.DspOscillator;
import haxefmod.core.DspType;

var osc = Dsp.create(DspType.OSCILLATOR);
osc.setParameterInt(DspOscillator.TYPE, 1); // square
osc.setParameter(DspOscillator.RATE, 750.0); // one flip every 32 samples at 48 kHz
var tone = osc.play();
```

## FMOD_DSP_BUFFER_ARRAY#3
verdict: bound
A plugin process callback cannot run in Haxe, the built-in oscillator unit plays the same square wave from game code.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspParameters.DspOscillator;
import haxefmod.core.DspType;

var osc = Dsp.create(DspType.OSCILLATOR);
osc.setParameterInt(DspOscillator.TYPE, 1); // square
osc.setParameter(DspOscillator.RATE, 750.0); // one flip every 32 samples at 48 kHz
var tone = osc.play();
```

## FMOD_DSP_CREATE_CALLBACK
verdict: cannot received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin

## FMOD_DSP_DESCRIPTION
verdict: cannot received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin

## FMOD_DSP_DESCRIPTION#2
verdict: cannot a plugin names itself in its description, received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.getName reads the name of a created unit

## FMOD_DSP_DESCRIPTION#3
verdict: cannot a plugin names itself in its description, received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.getName reads the name of a created unit

## FMOD_DSP_DESCRIPTION#4
verdict: cannot a plugin names itself in its description, received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.getName reads the name of a created unit

## FMOD_DSP_DFT_FFTREAL_FUNC
verdict: cannot received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin

## FMOD_DSP_DFT_IFFTREAL_FUNC
verdict: cannot received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin

## FMOD_DSP_FREE_FUNC
verdict: cannot received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin

## FMOD_DSP_GETBLOCKSIZE_FUNC
verdict: cannot received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin

## FMOD_DSP_GETCLOCK_FUNC
verdict: cannot received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin

## FMOD_DSP_GETLISTENERATTRIBUTES_FUNC
verdict: cannot received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin

## FMOD_DSP_GETPARAM_BOOL_CALLBACK
verdict: cannot received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin

## FMOD_DSP_GETPARAM_DATA_CALLBACK
verdict: cannot received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin

## FMOD_DSP_GETPARAM_FLOAT_CALLBACK
verdict: cannot received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin

## FMOD_DSP_GETPARAM_INT_CALLBACK
verdict: cannot received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin

## FMOD_DSP_GETPARAM_VALUESTR_LENGTH
verdict: cannot the size of the value string received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host

## FMOD_DSP_GETSAMPLERATE_FUNC
verdict: cannot received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin

## FMOD_DSP_GETSPEAKERMODE_FUNC
verdict: cannot received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin

## FMOD_DSP_GETUSERDATA_FUNC
verdict: cannot received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin

## FMOD_DSP_LOG_FUNC
verdict: cannot received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin

## FMOD_DSP_METERING_INFO
verdict: bound
Type: haxefmod.studio.Types.FmodDspMeteringInfo
Dsp.getMetering() returns the output side, getMetering(true) or getInputMetering() the input side, once setMeteringEnabled is on.

## FMOD_DSP_PAN_GETROLLOFFGAIN_FUNC
verdict: cannot received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin

## FMOD_DSP_PAN_SUMMONOMATRIX_FUNC
verdict: cannot received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin

## FMOD_DSP_PAN_SUMMONOTOSURROUNDMATRIX_FUNC
verdict: cannot received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin

## FMOD_DSP_PAN_SUMSTEREOMATRIX_FUNC
verdict: cannot received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin

## FMOD_DSP_PAN_SUMSTEREOTOSURROUNDMATRIX_FUNC
verdict: cannot received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin

## FMOD_DSP_PAN_SUMSURROUNDMATRIX_FUNC
verdict: cannot received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin

## FMOD_DSP_PAN_SURROUND_FLAGS
verdict: bound
Type: haxefmod.studio.Types.FmodDspPanSurroundFlags

## FMOD_DSP_PARAMETER_3DATTRIBUTES
verdict: bound
Type: haxefmod.studio.Types.FmodDspParameter3DAttributes
Set with Dsp.setParameter3DAttributes(index, absolute, ?relative), the shim packs the struct.

## FMOD_DSP_PARAMETER_3DATTRIBUTES_MULTI
verdict: bound
Type: haxefmod.studio.Types.FmodDspParameter3DAttributesMulti
Set with Dsp.setParameter3DAttributesMulti(index, absolute, relative, ?weights), one relative entry per listener, the shim packs the struct.

## FMOD_DSP_PARAMETER_ATTENUATION_RANGE
verdict: bound
Type: haxefmod.studio.Types.FmodDspParameterAttenuationRange
Set with Dsp.setParameterAttenuationRange(index, props) and read with getParameterAttenuationRange(index), the shim packs the struct. Dsp.getDataParameterIndex(ATTENUATION_RANGE) finds the index.

## FMOD_DSP_PARAMETER_DATA_TYPE
verdict: bound
Type: haxefmod.studio.Types.FmodDspParameterDataType

## FMOD_DSP_PARAMETER_DESC
verdict: bound
Type: haxefmod.studio.Types.FmodDspParameterDesc
Dsp.getParameterInfo(index) returns it, native only (unsupported in HTML5). The union member matching type is set (floatDesc, intDesc, boolDesc, or dataDesc), the other three are null.

## FMOD_DSP_PARAMETER_DESC_BOOL
verdict: bound
Type: haxefmod.studio.Types.FmodDspParameterDescBool
The boolDesc member of FmodDspParameterDesc.

## FMOD_DSP_PARAMETER_DESC_DATA
verdict: bound
Type: haxefmod.studio.Types.FmodDspParameterDescData
The dataDesc member of FmodDspParameterDesc.

## FMOD_DSP_PARAMETER_DESC_FLOAT
verdict: bound
Type: haxefmod.studio.Types.FmodDspParameterDescFloat
The floatDesc member of FmodDspParameterDesc.

## FMOD_DSP_PARAMETER_DESC_INT
verdict: bound
Type: haxefmod.studio.Types.FmodDspParameterDescInt
The intDesc member of FmodDspParameterDesc.

## FMOD_DSP_PARAMETER_DYNAMIC_RESPONSE
verdict: bound
Type: haxefmod.studio.Types.FmodDspParameterDynamicResponse
Read with Dsp.getParameterDynamicResponse(index), the shim unpacks the struct. Dsp.getDataParameterIndex(DYNAMIC_RESPONSE) finds the index.

## FMOD_DSP_PARAMETER_FFT
verdict: bound
Type: haxefmod.studio.Types.FmodDspParameterFft
Read with Dsp.getFftSpectrumInfo(maxBins) on an FFT unit, or getFftSpectrum(maxBins) for the first channel alone.

## FMOD_DSP_PARAMETER_FINITE_LENGTH
verdict: bound
Type: haxefmod.studio.Types.FmodDspParameterFiniteLength
Set with Dsp.setParameterFiniteLength(index, props) and read with getParameterFiniteLength(index), the shim packs the struct.

## FMOD_DSP_PARAMETER_FLOAT_MAPPING
verdict: bound
Type: haxefmod.studio.Types.FmodDspParameterFloatMapping
The mapping field of FmodDspParameterDescFloat.

## FMOD_DSP_PARAMETER_FLOAT_MAPPING_PIECEWISE_LINEAR
verdict: bound
Type: haxefmod.studio.Types.FmodDspParameterFloatMappingPiecewiseLinear
The piecewiseLinearMapping field of FmodDspParameterFloatMapping, empty unless the mapping type is PIECEWISE_LINEAR.

## FMOD_DSP_PARAMETER_FLOAT_MAPPING_TYPE
verdict: bound
Type: haxefmod.studio.Types.FmodDspParameterFloatMappingType

## FMOD_DSP_PARAMETER_OVERALLGAIN
verdict: bound
Type: haxefmod.studio.Types.FmodDspParameterOverallGain
Read with Dsp.getOverallGain(), which finds the unit's overall gain parameter, or getOverallGain(index).

## FMOD_DSP_PARAMETER_SIDECHAIN
verdict: bound
Type: haxefmod.studio.Types.FmodDspParameterSidechain
Set with Dsp.setParameterSidechain(index, props) and read with getParameterSidechain(index), the shim packs the struct. DspCompressor.USESIDECHAIN is one such parameter.

## FMOD_DSP_PARAMETER_TYPE
verdict: bound
Type: haxefmod.studio.Types.FmodDspParameterType
Reported in the type field of Dsp.getParameterInfo.

## FMOD_DSP_PROCESS_CALLBACK
verdict: cannot received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin

## FMOD_DSP_PROCESS_CALLBACK#2
verdict: bound
A plugin process callback cannot run in Haxe, the built-in fader unit halves the signal in the same place of the chain.
```haxe
import haxefmod.core.ChannelGroup;
import haxefmod.core.Dsp;
import haxefmod.core.DspParameters.DspFader;
import haxefmod.core.DspType;

var fader = Dsp.create(DspType.FADER);
fader.setParameter(DspFader.GAIN, -6.02); // dB, half amplitude
ChannelGroup.master().addDsp(ChannelGroup.DSP_TAIL, fader);
```

## FMOD_DSP_PROCESS_CALLBACK#3
verdict: bound
A plugin process callback cannot run in Haxe, the built-in fader unit halves the signal in the same place of the chain.
```haxe
import haxefmod.core.ChannelGroup;
import haxefmod.core.Dsp;
import haxefmod.core.DspParameters.DspFader;
import haxefmod.core.DspType;

var fader = Dsp.create(DspType.FADER);
fader.setParameter(DspFader.GAIN, -6.02); // dB, half amplitude
ChannelGroup.master().addDsp(ChannelGroup.DSP_TAIL, fader);
```

## FMOD_DSP_PROCESS_OPERATION
verdict: bound
Type: haxefmod.studio.Types.FmodDspProcessOperation

## FMOD_DSP_READ_CALLBACK
verdict: cannot received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin

## FMOD_DSP_READ_CALLBACK#2
verdict: bound
A plugin read callback cannot run in Haxe, the built-in fader unit halves the signal in the same place of the chain.
```haxe
import haxefmod.core.ChannelGroup;
import haxefmod.core.Dsp;
import haxefmod.core.DspParameters.DspFader;
import haxefmod.core.DspType;

var fader = Dsp.create(DspType.FADER);
fader.setParameter(DspFader.GAIN, -6.02); // dB, half amplitude
ChannelGroup.master().addDsp(ChannelGroup.DSP_TAIL, fader);
```

## FMOD_DSP_READ_CALLBACK#3
verdict: bound
A plugin read callback cannot run in Haxe, the built-in fader unit halves the signal in the same place of the chain.
```haxe
import haxefmod.core.ChannelGroup;
import haxefmod.core.Dsp;
import haxefmod.core.DspParameters.DspFader;
import haxefmod.core.DspType;

var fader = Dsp.create(DspType.FADER);
fader.setParameter(DspFader.GAIN, -6.02); // dB, half amplitude
ChannelGroup.master().addDsp(ChannelGroup.DSP_TAIL, fader);
```

## FMOD_DSP_READ_CALLBACK#4
verdict: bound
A plugin read callback cannot run in Haxe, the built-in fader unit halves the signal in the same place of the chain.
```haxe
import haxefmod.core.ChannelGroup;
import haxefmod.core.Dsp;
import haxefmod.core.DspParameters.DspFader;
import haxefmod.core.DspType;

var fader = Dsp.create(DspType.FADER);
fader.setParameter(DspFader.GAIN, -6.02); // dB, half amplitude
ChannelGroup.master().addDsp(ChannelGroup.DSP_TAIL, fader);
```

## FMOD_DSP_REALLOC_FUNC
verdict: cannot received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin

## FMOD_DSP_RELEASE_CALLBACK
verdict: cannot received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin

## FMOD_DSP_RESET_CALLBACK
verdict: cannot received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin

## FMOD_DSP_SETPARAM_BOOL_CALLBACK
verdict: cannot received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin

## FMOD_DSP_SETPARAM_DATA_CALLBACK
verdict: cannot received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin

## FMOD_DSP_SETPARAM_FLOAT_CALLBACK
verdict: cannot received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin

## FMOD_DSP_SETPARAM_INT_CALLBACK
verdict: cannot received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin

## FMOD_DSP_SETPOSITION_CALLBACK
verdict: cannot received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin

## FMOD_DSP_SHOULDIPROCESS_CALLBACK
verdict: cannot received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin

## FMOD_DSP_SHOULDIPROCESS_CALLBACK#2
verdict: cannot the question is received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.isIdle reports from game code whether a unit's inputs went idle

## FMOD_DSP_STATE
verdict: cannot the per instance state received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units

## FMOD_DSP_STATE#2
verdict: cannot a plugin read callback keeping its phase in plugindata, received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, the built-in oscillator unit (Dsp.create(DspType.OSCILLATOR)) plays the same tone from game code

## FMOD_DSP_STATE#3
verdict: bound
A plugin oscillator keeps its phase in plugindata on the mixer thread, the built-in oscillator unit plays the same 440 Hz sine from game code.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspParameters.DspOscillator;
import haxefmod.core.DspType;

var osc = Dsp.create(DspType.OSCILLATOR);
osc.setParameterInt(DspOscillator.TYPE, 0); // 0 sine, 1 square, 2 saw up, 3 saw down, 4 triangle, 5 noise
osc.setParameter(DspOscillator.RATE, 440.0);
var tone = osc.play();
if (tone.isNull()) trace("play failed");

// later
tone.stop();
var result = osc.release();
if (!result.isOk()) trace(result.toString());
```

## FMOD_DSP_STATE#4
verdict: bound
A plugin oscillator keeps its phase in plugindata on the mixer thread, the built-in oscillator unit plays the same 440 Hz sine from game code.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspParameters.DspOscillator;
import haxefmod.core.DspType;

var osc = Dsp.create(DspType.OSCILLATOR);
osc.setParameterInt(DspOscillator.TYPE, 0); // 0 sine, 1 square, 2 saw up, 3 saw down, 4 triangle, 5 noise
osc.setParameter(DspOscillator.RATE, 440.0);
var tone = osc.play();
if (tone.isNull()) trace("play failed");

// later
tone.stop();
var result = osc.release();
if (!result.isOk()) trace(result.toString());
```

## FMOD_DSP_STATE_DFT_FUNCTIONS
verdict: cannot received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin

## FMOD_DSP_STATE_FUNCTIONS
verdict: cannot received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin

## FMOD_DSP_STATE_PAN_FUNCTIONS
verdict: cannot received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin

## FMOD_DSP_SYSTEM_DEREGISTER_CALLBACK
verdict: cannot received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin

## FMOD_DSP_SYSTEM_MIX_CALLBACK
verdict: cannot received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin

## FMOD_DSP_SYSTEM_REGISTER_CALLBACK
verdict: cannot received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, Dsp.create gives the built-in units and StudioSystem.loadPlugin loads a compiled plugin

## FMOD_PLUGIN_SDK_VERSION
verdict: cannot the SDK version a compiled plugin is built against, received only by a plugin callback on FMOD's mixer thread, which Haxe code cannot host, StudioSystem.getPluginInfo reports a loaded plugin's version
