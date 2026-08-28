# core-api-common-dsp-effects

## FMOD_DSP_CHANNELMIX
verdict: bound
Type: haxefmod.core.DspParameters.DspChannelMix

## FMOD_DSP_CHANNELMIX_OUTPUT
verdict: bound
Type: haxefmod.core.DspEnums.DspChannelMixOutput
Passed through setParameterInt on DspChannelMix.OUTPUTGROUPING.

## FMOD_DSP_CHORUS
verdict: bound
Type: haxefmod.core.DspParameters.DspChorus

## FMOD_DSP_COMPRESSOR
verdict: bound
Type: haxefmod.core.DspParameters.DspCompressor

## FMOD_DSP_CONVOLUTION_REVERB
verdict: bound
Type: haxefmod.core.DspParameters.DspConvolutionReverb
The impulse response is 16-bit PCM handed over through setParameterData on PARAM_IR, with the channel count in the first two bytes as FMOD's format describes.

## FMOD_DSP_DELAY
verdict: bound
Type: haxefmod.core.DspParameters.DspDelay
MAXDELAY is set before the per-channel delays.

## FMOD_DSP_DISTORTION
verdict: bound
Type: haxefmod.core.DspParameters.DspDistortion

## FMOD_DSP_ECHO
verdict: bound
Type: haxefmod.core.DspParameters.DspEcho

## FMOD_DSP_ECHO_DELAYCHANGEMODE_TYPE
verdict: bound
Type: haxefmod.core.DspEnums.DspEchoDelayChangeMode
Passed through setParameterInt on DspEcho.DELAYCHANGEMODE.

## FMOD_DSP_FADER
verdict: bound
Type: haxefmod.core.DspParameters.DspFader

## FMOD_DSP_FFT
verdict: bound
Type: haxefmod.core.DspParameters.DspFft
The SPECTRUMDATA parameter is read through getFftSpectrum instead of getParameterData.

## FMOD_DSP_FFT_DOWNMIX_TYPE
verdict: bound
Type: haxefmod.core.DspEnums.DspFftDownmix
Passed through setParameterInt on DspFft.DOWNMIX.

## FMOD_DSP_FFT_WINDOW_TYPE
verdict: bound
Type: haxefmod.core.DspEnums.DspFftWindow
Passed through setParameterInt on DspFft.WINDOW.

## FMOD_DSP_FLANGE
verdict: bound
Type: haxefmod.core.DspParameters.DspFlange

## FMOD_DSP_HIGHPASS
verdict: bound
Type: haxefmod.core.DspParameters.DspHighpass

## FMOD_DSP_HIGHPASS#2
verdict: bound
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;
import haxefmod.core.DspParameters.DspMultibandEq;
import haxefmod.core.DspEnums.DspMultibandEqFilter;
var multiband = Dsp.create(DspType.MULTIBAND_EQ);
var frequency = 5000.0;
var resonance = 1.0;
// Configure a single band (band A) as a highpass (all other bands default to off).
// 12dB roll-off to approximate the old effect curve.
// Cutoff frequency can be used the same as with the old effect.
// Resonance can be applied by setting the 'Q' value of the new effect.
multiband.setParameterInt(DspMultibandEq.A_FILTER, DspMultibandEqFilter.HIGHPASS_12DB);
multiband.setParameter(DspMultibandEq.A_FREQUENCY, frequency);
multiband.setParameter(DspMultibandEq.A_Q, resonance);
```

## FMOD_DSP_HIGHPASS_SIMPLE
verdict: bound
Type: haxefmod.core.DspParameters.DspHighpassSimple

## FMOD_DSP_HIGHPASS_SIMPLE#2
verdict: bound
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;
import haxefmod.core.DspParameters.DspMultibandEq;
import haxefmod.core.DspEnums.DspMultibandEqFilter;
var multiband = Dsp.create(DspType.MULTIBAND_EQ);
var frequency = 1000.0;
// Configure a single band (band A) as a highpass (all other bands default to off).
// 12dB roll-off to approximate the old effect curve.
// Cutoff frequency can be used the same as with the old effect.
// Resonance / 'Q' should remain at default 0.707.
multiband.setParameterInt(DspMultibandEq.A_FILTER, DspMultibandEqFilter.HIGHPASS_12DB);
multiband.setParameter(DspMultibandEq.A_FREQUENCY, frequency);
```

## FMOD_DSP_ITECHO
verdict: bound
Type: haxefmod.core.DspParameters.DspItEcho

## FMOD_DSP_ITLOWPASS
verdict: bound
Type: haxefmod.core.DspParameters.DspItLowpass

## FMOD_DSP_LIMITER
verdict: bound
Type: haxefmod.core.DspParameters.DspLimiter

## FMOD_DSP_LOUDNESS_METER
verdict: bound
Type: haxefmod.core.DspParameters.DspLoudnessMeter
STATE is set with setParameterInt and WEIGHTING with setParameterData. The INFO readback has no Haxe getter, Dsp.getMetering gives peak and RMS levels on every target.

## FMOD_DSP_LOUDNESS_METER_INFO_TYPE
verdict: library the library has no data parameter getter, so the loudness readback is not exposed and Dsp.getMetering gives peak and RMS levels instead

## FMOD_DSP_LOUDNESS_METER_STATE_TYPE
verdict: bound
Type: haxefmod.core.DspEnums.DspLoudnessMeterState
Passed through setParameterInt on DspLoudnessMeter.STATE, where negative values reset the meter.

## FMOD_DSP_LOUDNESS_METER_WEIGHTING_TYPE
verdict: bound
Shape: usage
The struct is 32 floats, written as bytes through setParameterData on DspLoudnessMeter.WEIGHTING.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;
import haxefmod.core.DspParameters.DspLoudnessMeter;
var meter = Dsp.create(DspType.LOUDNESS_METER);
var weighting = haxe.io.Bytes.alloc(32 * 4);
for (channel in 0...32) {
    weighting.setFloat(channel * 4, 1.0);
}
meter.setParameterData(DspLoudnessMeter.WEIGHTING, weighting);
```

## FMOD_DSP_LOWPASS
verdict: bound
Type: haxefmod.core.DspParameters.DspLowpass

## FMOD_DSP_LOWPASS#2
verdict: bound
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;
import haxefmod.core.DspParameters.DspMultibandEq;
import haxefmod.core.DspEnums.DspMultibandEqFilter;
var multiband = Dsp.create(DspType.MULTIBAND_EQ);
var frequency = 5000.0;
var resonance = 1.0;
// Configure a single band (band A) as a lowpass (all other bands default to off).
// 24dB roll-off to approximate the old effect curve.
// Cutoff frequency can be used the same as with the old effect.
// Resonance can be applied by setting the 'Q' value of the new effect.
multiband.setParameterInt(DspMultibandEq.A_FILTER, DspMultibandEqFilter.LOWPASS_24DB);
multiband.setParameter(DspMultibandEq.A_FREQUENCY, frequency);
multiband.setParameter(DspMultibandEq.A_Q, resonance);
```

## FMOD_DSP_LOWPASS_SIMPLE
verdict: bound
Type: haxefmod.core.DspParameters.DspLowpassSimple

## FMOD_DSP_LOWPASS_SIMPLE#2
verdict: bound
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;
import haxefmod.core.DspParameters.DspMultibandEq;
import haxefmod.core.DspEnums.DspMultibandEqFilter;
var multiband = Dsp.create(DspType.MULTIBAND_EQ);
var frequency = 5000.0;
// Configure a single band (band A) as a lowpass (all other bands default to off).
// 12dB roll-off to approximate the old effect curve.
// Cutoff frequency can be used the same as with the old effect.
// Resonance / 'Q' should remain at default 0.707.
multiband.setParameterInt(DspMultibandEq.A_FILTER, DspMultibandEqFilter.LOWPASS_12DB);
multiband.setParameter(DspMultibandEq.A_FREQUENCY, frequency);
```

## FMOD_DSP_MULTIBAND_DYNAMICS
verdict: bound
Type: haxefmod.core.DspParameters.DspMultibandDynamics
Each band takes eight consecutive indices starting at A_MODE, B_MODE, and C_MODE.

## FMOD_DSP_MULTIBAND_DYNAMICS_MODE_TYPE
verdict: bound
Type: haxefmod.core.DspEnums.DspMultibandDynamicsMode
Passed through setParameterInt on the band's MODE index (DspMultibandDynamics.A_MODE, B_MODE, C_MODE).

## FMOD_DSP_MULTIBAND_EQ
verdict: bound
Type: haxefmod.core.DspParameters.DspMultibandEq
Each band takes four consecutive indices: filter, frequency, Q, gain.

## FMOD_DSP_MULTIBAND_EQ_FILTER_TYPE
verdict: bound
Type: haxefmod.core.DspEnums.DspMultibandEqFilter
Passed through setParameterInt on the band's FILTER index (DspMultibandEq.A_FILTER through E_FILTER).

## FMOD_DSP_NORMALIZE
verdict: bound
Type: haxefmod.core.DspParameters.DspNormalize

## FMOD_DSP_OBJECTPAN
verdict: bound
Type: haxefmod.core.DspParameters.DspObjectPan
The 3D position parameter takes the FMOD_DSP_PARAMETER_3DATTRIBUTES_MULTI struct, which is not exposed, so position an object panner by playing its source through a 3D channel and driving that channel's set3DAttributes instead.

## FMOD_DSP_OSCILLATOR
verdict: bound
Type: haxefmod.core.DspParameters.DspOscillator
A generator unit plays as a sound source through Dsp.play.

## FMOD_DSP_PAN
verdict: bound
Type: haxefmod.core.DspParameters.DspPan
The 3D position parameter takes a struct that is not exposed, so 3D panning goes through a 3D channel's set3DAttributes instead. The 2D parameters work by index.

## FMOD_DSP_PAN#2
verdict: covered this block is prose about how a rotating 3D source is panned, in Haxe the source is positioned through Channel.set3DAttributes and the same panning applies

## FMOD_DSP_PAN_2D_STEREO_MODE_TYPE
verdict: bound
Type: haxefmod.core.DspEnums.DspPan2DStereoModeType
Passed through setParameterInt on DspPan._2D_STEREO_MODE.

## FMOD_DSP_PAN_3D_EXTENT_MODE_TYPE
verdict: bound
Type: haxefmod.core.DspEnums.DspPan3DExtentModeType
Passed through setParameterInt on DspPan._3D_EXTENT_MODE.

## FMOD_DSP_PAN_3D_ROLLOFF_TYPE
verdict: bound
Type: haxefmod.core.DspEnums.DspPan3DRolloffType
Passed through setParameterInt on DspPan._3D_ROLLOFF. A CUSTOM curve goes on the channel through Channel.set3DCustomRolloff (unsupported in HTML5).

## FMOD_DSP_PAN_MODE_TYPE
verdict: bound
Type: haxefmod.core.DspEnums.DspPanModeType
Passed through setParameterInt on DspPan.MODE.

## FMOD_DSP_PARAMEQ
verdict: bound
Type: haxefmod.core.DspParameters.DspParamEq

## FMOD_DSP_PARAMEQ#2
verdict: bound
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;
import haxefmod.core.DspParameters.DspMultibandEq;
import haxefmod.core.DspEnums.DspMultibandEqFilter;
var multiband = Dsp.create(DspType.MULTIBAND_EQ);
var center = 8000.0;
var bandwidth = 1.0;
var gain = 0.0;
// Configure a single band (band A) as a peaking EQ (all other bands default to off).
// Center frequency can be used as with the old effect.
// Bandwidth can be applied by setting the 'Q' value of the new effect.
// Gain at the center frequency can be used the same as with the old effect.
multiband.setParameterInt(DspMultibandEq.A_FILTER, DspMultibandEqFilter.PEAKING);
multiband.setParameter(DspMultibandEq.A_FREQUENCY, center);
multiband.setParameter(DspMultibandEq.A_Q, bandwidth);
multiband.setParameter(DspMultibandEq.A_GAIN, gain);
```

## FMOD_DSP_PITCHSHIFT
verdict: bound
Type: haxefmod.core.DspParameters.DspPitchShift

## FMOD_DSP_RETURN
verdict: bound
Type: haxefmod.core.DspParameters.DspReturn
The return's ID is read with getParameterInt and given to a send's RETURNID.

## FMOD_DSP_SEND
verdict: bound
Type: haxefmod.core.DspParameters.DspSend
RETURNID takes the ID read from a RETURN unit's DspReturn.ID parameter.

## FMOD_DSP_SFXREVERB
verdict: bound
Type: haxefmod.core.DspParameters.DspSfxReverb
The first twelve indices match the fields of ReverbProperties in order. For a global reverb, Reverb.set with a preset is simpler than an SFXREVERB unit.

## FMOD_DSP_THREE_EQ
verdict: bound
Type: haxefmod.core.DspParameters.DspThreeEq

## FMOD_DSP_THREE_EQ_CROSSOVERSLOPE_TYPE
verdict: bound
Type: haxefmod.core.DspEnums.DspThreeEqCrossoverSlope
Passed through setParameterInt on DspThreeEq.CROSSOVERSLOPE.

## FMOD_DSP_TRANSCEIVER
verdict: bound
Type: haxefmod.core.DspParameters.DspTransceiver
One unit transmits on a channel and another receives it anywhere in the graph.

## FMOD_DSP_TRANSCEIVER_SPEAKERMODE
verdict: bound
Type: haxefmod.core.DspEnums.DspTransceiverSpeakerMode
Passed through setParameterInt on DspTransceiver.TRANSMITSPEAKERMODE.

## FMOD_DSP_TREMOLO
verdict: bound
Type: haxefmod.core.DspParameters.DspTremolo

## FMOD_DSP_TYPE
verdict: bound
Type: haxefmod.core.DspType
Third-party plugin units come from StudioSystem.loadPlugin and Dsp.createByPlugin, native only.
