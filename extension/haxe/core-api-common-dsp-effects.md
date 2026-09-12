# core-api-common-dsp-effects

## FMOD_DSP_CHANNELMIX
verdict: bound
Type: haxefmod.core.DspParameters.DspChannelMix

## FMOD_DSP_CHANNELMIX_OUTPUT
verdict: bound
Type: haxefmod.core.DspEnums.DspChannelMixOutput

## FMOD_DSP_CHORUS
verdict: bound
Type: haxefmod.core.DspParameters.DspChorus

## FMOD_DSP_COMPRESSOR
verdict: bound
Type: haxefmod.core.DspParameters.DspCompressor

## FMOD_DSP_CONVOLUTION_REVERB
verdict: bound
Type: haxefmod.core.DspParameters.DspConvolutionReverb

## FMOD_DSP_DELAY
verdict: bound
Type: haxefmod.core.DspParameters.DspDelay

## FMOD_DSP_DISTORTION
verdict: bound
Type: haxefmod.core.DspParameters.DspDistortion

## FMOD_DSP_ECHO
verdict: bound
Type: haxefmod.core.DspParameters.DspEcho

## FMOD_DSP_ECHO_DELAYCHANGEMODE_TYPE
verdict: bound
Type: haxefmod.core.DspEnums.DspEchoDelayChangeMode

## FMOD_DSP_FADER
verdict: bound
Type: haxefmod.core.DspParameters.DspFader

## FMOD_DSP_FFT
verdict: bound
Type: haxefmod.core.DspParameters.DspFft

## FMOD_DSP_FFT_DOWNMIX_TYPE
verdict: bound
Type: haxefmod.core.DspEnums.DspFftDownmix

## FMOD_DSP_FFT_WINDOW_TYPE
verdict: bound
Type: haxefmod.core.DspEnums.DspFftWindow

## FMOD_DSP_FLANGE
verdict: bound
Type: haxefmod.core.DspParameters.DspFlange

## FMOD_DSP_HIGHPASS
verdict: bound
Type: haxefmod.core.DspParameters.DspHighpass

## FMOD_DSP_HIGHPASS#2
verdict: bound
```haxe
import haxefmod.core.DspParameters.DspMultibandEq;
import haxefmod.core.DspEnums.DspMultibandEqFilter;
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
import haxefmod.core.DspParameters.DspMultibandEq;
import haxefmod.core.DspEnums.DspMultibandEqFilter;
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

## FMOD_DSP_LOUDNESS_METER_INFO_TYPE
verdict: bound
Type: haxefmod.studio.Types.FmodDspLoudnessMeterInfo

## FMOD_DSP_LOUDNESS_METER_STATE_TYPE
verdict: bound
Type: haxefmod.core.DspEnums.DspLoudnessMeterState

## FMOD_DSP_LOUDNESS_METER_WEIGHTING_TYPE
verdict: bound
Type: haxefmod.studio.Types.FmodDspLoudnessMeterWeightingType

## FMOD_DSP_LOWPASS
verdict: bound
Type: haxefmod.core.DspParameters.DspLowpass

## FMOD_DSP_LOWPASS#2
verdict: bound
```haxe
import haxefmod.core.DspParameters.DspMultibandEq;
import haxefmod.core.DspEnums.DspMultibandEqFilter;
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
import haxefmod.core.DspParameters.DspMultibandEq;
import haxefmod.core.DspEnums.DspMultibandEqFilter;
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

## FMOD_DSP_MULTIBAND_DYNAMICS_MODE_TYPE
verdict: bound
Type: haxefmod.core.DspEnums.DspMultibandDynamicsMode

## FMOD_DSP_MULTIBAND_EQ
verdict: bound
Type: haxefmod.core.DspParameters.DspMultibandEq

## FMOD_DSP_MULTIBAND_EQ_FILTER_TYPE
verdict: bound
Type: haxefmod.core.DspEnums.DspMultibandEqFilter

## FMOD_DSP_NORMALIZE
verdict: bound
Type: haxefmod.core.DspParameters.DspNormalize

## FMOD_DSP_OBJECTPAN
verdict: bound
Type: haxefmod.core.DspParameters.DspObjectPan

## FMOD_DSP_OSCILLATOR
verdict: bound
Type: haxefmod.core.DspParameters.DspOscillator

## FMOD_DSP_PAN
verdict: bound
Type: haxefmod.core.DspParameters.DspPan

## FMOD_DSP_PAN#2
verdict: covered this block is prose about how a rotating 3D source is panned, in Haxe the source is positioned through Channel.set3DAttributes and the same panning applies

## FMOD_DSP_PAN_2D_STEREO_MODE_TYPE
verdict: bound
Type: haxefmod.core.DspEnums.DspPan2DStereoModeType

## FMOD_DSP_PAN_3D_EXTENT_MODE_TYPE
verdict: bound
Type: haxefmod.core.DspEnums.DspPan3DExtentModeType

## FMOD_DSP_PAN_3D_ROLLOFF_TYPE
verdict: bound
Type: haxefmod.core.DspEnums.DspPan3DRolloffType

## FMOD_DSP_PAN_MODE_TYPE
verdict: bound
Type: haxefmod.core.DspEnums.DspPanModeType

## FMOD_DSP_PARAMEQ
verdict: bound
Type: haxefmod.core.DspParameters.DspParamEq

## FMOD_DSP_PARAMEQ#2
verdict: bound
```haxe
import haxefmod.core.DspParameters.DspMultibandEq;
import haxefmod.core.DspEnums.DspMultibandEqFilter;
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

## FMOD_DSP_SEND
verdict: bound
Type: haxefmod.core.DspParameters.DspSend

## FMOD_DSP_SFXREVERB
verdict: bound
Type: haxefmod.core.DspParameters.DspSfxReverb

## FMOD_DSP_THREE_EQ
verdict: bound
Type: haxefmod.core.DspParameters.DspThreeEq

## FMOD_DSP_THREE_EQ_CROSSOVERSLOPE_TYPE
verdict: bound
Type: haxefmod.core.DspEnums.DspThreeEqCrossoverSlope

## FMOD_DSP_TRANSCEIVER
verdict: bound
Type: haxefmod.core.DspParameters.DspTransceiver

## FMOD_DSP_TRANSCEIVER_SPEAKERMODE
verdict: bound
Type: haxefmod.core.DspEnums.DspTransceiverSpeakerMode

## FMOD_DSP_TREMOLO
verdict: bound
Type: haxefmod.core.DspParameters.DspTremolo

## FMOD_DSP_TYPE
verdict: bound
Type: haxefmod.core.DspType

