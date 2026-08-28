# core-api-common-dsp-effects

## 1
<!-- FMOD_DSP_CHANNELMIX_OUTPUT -->
Passed through setParameterInt on DspChannelMix.OUTPUTGROUPING.

## 4
<!-- FMOD_DSP_CONVOLUTION_REVERB -->
The impulse response is 16-bit PCM handed over through setParameterData on PARAM_IR, with the channel count in the first two bytes as FMOD's format describes.

## 5
<!-- FMOD_DSP_DELAY -->
MAXDELAY is set before the per-channel delays.

## 8
<!-- FMOD_DSP_ECHO_DELAYCHANGEMODE_TYPE -->
Passed through setParameterInt on DspEcho.DELAYCHANGEMODE.

## 10
<!-- FMOD_DSP_FFT -->
The SPECTRUMDATA parameter is read through getFftSpectrum instead of getParameterData.

## 11
<!-- FMOD_DSP_FFT_DOWNMIX_TYPE -->
Passed through setParameterInt on DspFft.DOWNMIX.

## 12
<!-- FMOD_DSP_FFT_WINDOW_TYPE -->
Passed through setParameterInt on DspFft.WINDOW.

## 15
<!-- FMOD_DSP_HIGHPASS -->
The same emulation on a MULTIBAND_EQ unit. Band A's filter is DspMultibandEq.A_FILTER, its frequency A_FREQUENCY, and its Q A_Q, with the filter set to DspMultibandEqFilter.HIGHPASS_12DB.

## 17
<!-- FMOD_DSP_HIGHPASS_SIMPLE -->
The same emulation on a MULTIBAND_EQ unit. Band A's filter is DspMultibandEq.A_FILTER and its frequency A_FREQUENCY, with the filter set to DspMultibandEqFilter.HIGHPASS_12DB and Q left at its default.

## 21
<!-- FMOD_DSP_LOUDNESS_METER -->
The meter runs on every target, but the INFO readback is not exposed because the HTML5 build returns zeroes from it. Use Dsp.getMetering for peak and RMS levels that work everywhere.

## 23
<!-- FMOD_DSP_LOUDNESS_METER_STATE_TYPE -->
Passed through setParameterInt on DspLoudnessMeter.STATE, where negative values reset the meter.

## 26
<!-- FMOD_DSP_LOWPASS -->
The same emulation on a MULTIBAND_EQ unit. Band A's filter is DspMultibandEq.A_FILTER, its frequency A_FREQUENCY, and its Q A_Q, with the filter set to DspMultibandEqFilter.LOWPASS_24DB.

## 28
<!-- FMOD_DSP_LOWPASS_SIMPLE -->
The same emulation on a MULTIBAND_EQ unit. Band A's filter is DspMultibandEq.A_FILTER and its frequency A_FREQUENCY, with the filter set to DspMultibandEqFilter.LOWPASS_12DB and Q left at its default.

## 29
<!-- FMOD_DSP_MULTIBAND_DYNAMICS -->
Each band takes eight consecutive indices starting at A_MODE, B_MODE, and C_MODE.

## 30
<!-- FMOD_DSP_MULTIBAND_DYNAMICS_MODE_TYPE -->
Passed through setParameterInt on the band's MODE index (DspMultibandDynamics.A_MODE, B_MODE, C_MODE).

## 31
<!-- FMOD_DSP_MULTIBAND_EQ -->
Each band takes four consecutive indices: filter, frequency, Q, gain.

## 32
<!-- FMOD_DSP_MULTIBAND_EQ_FILTER_TYPE -->
Passed through setParameterInt on the band's FILTER index (DspMultibandEq.A_FILTER through E_FILTER).

## 34
<!-- FMOD_DSP_OBJECTPAN -->
The 3D position parameter takes the FMOD_DSP_PARAMETER_3DATTRIBUTES_MULTI struct, which is not exposed, so position an object panner by playing its source through a 3D channel and driving that channel's set3DAttributes instead.

## 35
<!-- FMOD_DSP_OSCILLATOR -->
A generator unit plays as a sound source through Dsp.play.

## 36
<!-- FMOD_DSP_PAN -->
The 3D position parameter takes a struct that is not exposed, so 3D panning goes through a 3D channel's set3DAttributes instead. The 2D parameters work by index.

## 37
<!-- FMOD_DSP_PAN -->
FMOD_DSP_PARAMETER_3DATTRIBUTES_MULTI is not exposed, so a pan unit cannot be positioned by parameter from Haxe. Play the source through a 3D channel and call Channel.set3DAttributes, which feeds the same panner with the Studio listeners.

## 38
<!-- FMOD_DSP_PAN_2D_STEREO_MODE_TYPE -->
Passed through setParameterInt on DspPan._2D_STEREO_MODE.

## 39
<!-- FMOD_DSP_PAN_3D_EXTENT_MODE_TYPE -->
Passed through setParameterInt on DspPan._3D_EXTENT_MODE.

## 40
<!-- FMOD_DSP_PAN_3D_ROLLOFF_TYPE -->
Passed through setParameterInt on DspPan._3D_ROLLOFF. A CUSTOM curve goes on the channel through Channel.set3DCustomRolloff (unsupported in HTML5).

## 41
<!-- FMOD_DSP_PAN_MODE_TYPE -->
Passed through setParameterInt on DspPan.MODE.

## 43
<!-- FMOD_DSP_PARAMEQ -->
The same emulation on a MULTIBAND_EQ unit. Band A's filter is DspMultibandEq.A_FILTER, frequency A_FREQUENCY, Q A_Q, and gain A_GAIN, with the filter set to DspMultibandEqFilter.PEAKING.

## 45
<!-- FMOD_DSP_RETURN -->
The return's ID is read with getParameterInt and given to a send's RETURNID.

## 46
<!-- FMOD_DSP_SEND -->
RETURNID takes the ID read from a RETURN unit's DspReturn.ID parameter.

## 47
<!-- FMOD_DSP_SFXREVERB -->
The first twelve indices match the fields of ReverbProperties in order. For a global reverb, Reverb.set with a preset is simpler than an SFXREVERB unit.

## 49
<!-- FMOD_DSP_THREE_EQ_CROSSOVERSLOPE_TYPE -->
Passed through setParameterInt on DspThreeEq.CROSSOVERSLOPE.

## 50
<!-- FMOD_DSP_TRANSCEIVER -->
One unit transmits on a channel and another receives it anywhere in the graph.

## 51
<!-- FMOD_DSP_TRANSCEIVER_SPEAKERMODE -->
Passed through setParameterInt on DspTransceiver.TRANSMITSPEAKERMODE.

## 53
<!-- FMOD_DSP_TYPE -->
Third-party plugin units come from StudioSystem.loadPlugin and Dsp.createByPlugin, native only.
