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
verdict: review note only, decide bound or a category
The same emulation on a MULTIBAND_EQ unit. Band A's filter is DspMultibandEq.A_FILTER, its frequency A_FREQUENCY, and its Q A_Q, with the filter set to DspMultibandEqFilter.HIGHPASS_12DB.

## FMOD_DSP_HIGHPASS_SIMPLE
verdict: bound
Type: haxefmod.core.DspParameters.DspHighpassSimple

## FMOD_DSP_HIGHPASS_SIMPLE#2
verdict: review note only, decide bound or a category
The same emulation on a MULTIBAND_EQ unit. Band A's filter is DspMultibandEq.A_FILTER and its frequency A_FREQUENCY, with the filter set to DspMultibandEqFilter.HIGHPASS_12DB and Q left at its default.

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
The meter runs on every target, but the INFO readback is not exposed because the HTML5 build returns zeroes from it. Use Dsp.getMetering for peak and RMS levels that work everywhere.

## FMOD_DSP_LOUDNESS_METER_INFO_TYPE
verdict: library the loudness readback is not exposed since the HTML5 build returns zeroes from it, Dsp.getMetering gives peak and RMS on every target

## FMOD_DSP_LOUDNESS_METER_STATE_TYPE
verdict: bound
Type: haxefmod.core.DspEnums.DspLoudnessMeterState
Passed through setParameterInt on DspLoudnessMeter.STATE, where negative values reset the meter.

## FMOD_DSP_LOUDNESS_METER_WEIGHTING_TYPE
verdict: library channel weighting is a data parameter of the loudness meter, whose readback is not exposed, so the meter keeps FMOD's default weighting

## FMOD_DSP_LOWPASS
verdict: bound
Type: haxefmod.core.DspParameters.DspLowpass

## FMOD_DSP_LOWPASS#2
verdict: review note only, decide bound or a category
The same emulation on a MULTIBAND_EQ unit. Band A's filter is DspMultibandEq.A_FILTER, its frequency A_FREQUENCY, and its Q A_Q, with the filter set to DspMultibandEqFilter.LOWPASS_24DB.

## FMOD_DSP_LOWPASS_SIMPLE
verdict: bound
Type: haxefmod.core.DspParameters.DspLowpassSimple

## FMOD_DSP_LOWPASS_SIMPLE#2
verdict: review note only, decide bound or a category
The same emulation on a MULTIBAND_EQ unit. Band A's filter is DspMultibandEq.A_FILTER and its frequency A_FREQUENCY, with the filter set to DspMultibandEqFilter.LOWPASS_12DB and Q left at its default.

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
verdict: review note only, decide bound or a category
FMOD_DSP_PARAMETER_3DATTRIBUTES_MULTI is not exposed, so a pan unit cannot be positioned by parameter from Haxe. Play the source through a 3D channel and call Channel.set3DAttributes, which feeds the same panner with the Studio listeners.

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
verdict: review note only, decide bound or a category
The same emulation on a MULTIBAND_EQ unit. Band A's filter is DspMultibandEq.A_FILTER, frequency A_FREQUENCY, Q A_Q, and gain A_GAIN, with the filter set to DspMultibandEqFilter.PEAKING.

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
