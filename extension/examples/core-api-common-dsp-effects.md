# core-api-common-dsp-effects

## 0
<!-- FMOD_DSP_CHANNELMIX -->
Parameters are set by index, and the index is the position of the value in this enum.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var mix = Dsp.create(DspType.CHANNELMIX);
mix.setParameterInt(0, 2); // OUTPUTGROUPING, 2 = ALLSTEREO
mix.setParameter(1, -6.0); // GAIN_CH0 in dB
mix.setParameter(2, -6.0); // GAIN_CH1 in dB
```

## 1
<!-- FMOD_DSP_CHANNELMIX_OUTPUT -->
The output grouping is an int with these enum values, set through setParameterInt on index 0.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var mix = Dsp.create(DspType.CHANNELMIX);
mix.setParameterInt(0, 1); // OUTPUTGROUPING = ALLMONO
```

## 2
<!-- FMOD_DSP_CHORUS -->
Parameters are set by index, and the index is the position of the value in this enum.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var chorus = Dsp.create(DspType.CHORUS);
chorus.setParameter(0, 50); // MIX percent
chorus.setParameter(1, 0.8); // RATE in Hz
chorus.setParameter(2, 3); // DEPTH percent
```

## 3
<!-- FMOD_DSP_COMPRESSOR -->
Parameters are set by index, and the index is the position of the value in this enum.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var compressor = Dsp.create(DspType.COMPRESSOR);
compressor.setParameter(0, -12); // THRESHOLD in dB
compressor.setParameter(1, 4); // RATIO
compressor.setParameter(2, 20); // ATTACK in ms
compressor.setParameter(3, 100); // RELEASE in ms
compressor.setParameterBool(5, false); // USESIDECHAIN
```

## 4
<!-- FMOD_DSP_CONVOLUTION_REVERB -->
Parameters are set by index, and the index is the position of the value in this enum. The impulse response is 16-bit PCM handed over through setParameterData, with the channel count in the first two bytes as FMOD's format describes.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var reverb = Dsp.create(DspType.CONVOLUTIONREVERB);
var impulse = haxe.io.Bytes.alloc(2 + 48000 * 2);
impulse.setUInt16(0, 1); // one channel, then the samples
reverb.setParameterData(0, impulse); // IR
reverb.setParameter(1, -6); // WET in dB
reverb.setParameter(2, 0); // DRY in dB
```

## 5
<!-- FMOD_DSP_DELAY -->
Parameters are set by index, and the index is the position of the value in this enum. CH0 through CH15 are indices 0 to 15 and MAXDELAY is 16.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var delay = Dsp.create(DspType.DELAY);
delay.setParameter(16, 500); // MAXDELAY in ms, set before the per-channel delays
delay.setParameter(0, 120); // CH0 delay in ms
delay.setParameter(1, 240); // CH1 delay in ms
```

## 6
<!-- FMOD_DSP_DISTORTION -->
Parameters are set by index, and the index is the position of the value in this enum.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var distortion = Dsp.create(DspType.DISTORTION);
distortion.setParameter(0, 0.7); // LEVEL
```

## 7
<!-- FMOD_DSP_ECHO -->
Parameters are set by index, and the index is the position of the value in this enum.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var echo = Dsp.create(DspType.ECHO);
echo.setParameter(0, 350); // DELAY in ms
echo.setParameter(1, 40); // FEEDBACK percent
echo.setParameter(3, -3); // WETLEVEL in dB
```

## 8
<!-- FMOD_DSP_ECHO_DELAYCHANGEMODE_TYPE -->
The delay change mode is an int with these enum values, set through setParameterInt on index 4 (DELAYCHANGEMODE).
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var echo = Dsp.create(DspType.ECHO);
echo.setParameterInt(4, 1); // DELAYCHANGEMODE = LERP
```

## 9
<!-- FMOD_DSP_FADER -->
Parameters are set by index, and the index is the position of the value in this enum.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var fader = Dsp.create(DspType.FADER);
fader.setParameter(0, -6); // GAIN in dB
```

## 10
<!-- FMOD_DSP_FFT -->
Parameters are set by index, and the index is the position of the value in this enum. The SPECTRUMDATA parameter is read through getFftSpectrum instead of getParameterData.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var fft = Dsp.create(DspType.FFT);
fft.setParameterInt(0, 1024); // WINDOWSIZE
fft.setParameterInt(1, 3); // WINDOW = HANNING
var spectrum = fft.getFftSpectrum(64); // SPECTRUMDATA, averaged across channels
if (spectrum != null) trace('bin 1: ${spectrum[1]}');
```

## 11
<!-- FMOD_DSP_FFT_DOWNMIX_TYPE -->
The downmix type is an int with these enum values, set through setParameterInt on index 8 (DOWNMIX).
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var fft = Dsp.create(DspType.FFT);
fft.setParameterInt(8, 1); // DOWNMIX = MONO
```

## 12
<!-- FMOD_DSP_FFT_WINDOW_TYPE -->
The window type is an int with these enum values, set through setParameterInt on index 1 (WINDOW).
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var fft = Dsp.create(DspType.FFT);
fft.setParameterInt(1, 5); // WINDOW = BLACKMANHARRIS
```

## 13
<!-- FMOD_DSP_FLANGE -->
Parameters are set by index, and the index is the position of the value in this enum.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var flange = Dsp.create(DspType.FLANGE);
flange.setParameter(0, 50); // MIX percent
flange.setParameter(1, 1); // DEPTH
flange.setParameter(2, 0.1); // RATE in Hz
```

## 14
<!-- FMOD_DSP_HIGHPASS -->
Parameters are set by index, and the index is the position of the value in this enum.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var highpass = Dsp.create(DspType.HIGHPASS);
highpass.setParameter(0, 500); // CUTOFF in Hz
highpass.setParameter(1, 1); // RESONANCE
```

## 15
<!-- FMOD_DSP_HIGHPASS -->
The same emulation on a MULTIBAND_EQ unit. Band A's filter is index 0, its frequency index 1, and its Q index 2. Filter types follow FMOD_DSP_MULTIBAND_EQ_FILTER_TYPE, where HIGHPASS_12DB is 4.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var frequency = 500.0;
var resonance = 1.0;
var multiband = Dsp.create(DspType.MULTIBAND_EQ);
multiband.setParameterInt(0, 4); // A_FILTER = HIGHPASS_12DB
multiband.setParameter(1, frequency); // A_FREQUENCY
multiband.setParameter(2, resonance); // A_Q
```

## 16
<!-- FMOD_DSP_HIGHPASS_SIMPLE -->
Parameters are set by index, and the index is the position of the value in this enum.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var highpass = Dsp.create(DspType.HIGHPASS_SIMPLE);
highpass.setParameter(0, 500); // CUTOFF in Hz
```

## 17
<!-- FMOD_DSP_HIGHPASS_SIMPLE -->
The same emulation on a MULTIBAND_EQ unit. Band A's filter is index 0 and its frequency index 1. HIGHPASS_12DB is 4 in FMOD_DSP_MULTIBAND_EQ_FILTER_TYPE, and Q stays at its default.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var frequency = 500.0;
var multiband = Dsp.create(DspType.MULTIBAND_EQ);
multiband.setParameterInt(0, 4); // A_FILTER = HIGHPASS_12DB
multiband.setParameter(1, frequency); // A_FREQUENCY
```

## 18
<!-- FMOD_DSP_ITECHO -->
Parameters are set by index, and the index is the position of the value in this enum.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var echo = Dsp.create(DspType.ITECHO);
echo.setParameter(0, 50); // WETDRYMIX percent
echo.setParameter(1, 50); // FEEDBACK percent
echo.setParameter(2, 300); // LEFTDELAY in ms
echo.setParameter(3, 300); // RIGHTDELAY in ms
```

## 19
<!-- FMOD_DSP_ITLOWPASS -->
Parameters are set by index, and the index is the position of the value in this enum.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var lowpass = Dsp.create(DspType.ITLOWPASS);
lowpass.setParameter(0, 2000); // CUTOFF in Hz
lowpass.setParameter(1, 1); // RESONANCE
```

## 20
<!-- FMOD_DSP_LIMITER -->
Parameters are set by index, and the index is the position of the value in this enum.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var limiter = Dsp.create(DspType.LIMITER);
limiter.setParameter(0, 10); // RELEASETIME in ms
limiter.setParameter(1, -1); // CEILING in dB
limiter.setParameter(2, 0); // MAXIMIZERGAIN in dB
limiter.setParameterBool(3, false); // MODE, true links channels
```

## 21
<!-- FMOD_DSP_LOUDNESS_METER -->
Parameters are set by index, and the index is the position of the value in this enum. The meter runs on every target, but the INFO readback is not exposed because the HTML5 build returns zeroes from it. Use Dsp.getMetering for peak and RMS levels that work everywhere.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var meter = Dsp.create(DspType.LOUDNESS_METER);
meter.setParameterInt(0, 1); // STATE = ANALYZING
meter.setMeteringEnabled(false, true);
var levels = meter.getMetering();
if (levels != null) trace('rms ${levels.rms[0]}');
```

## 22
<!-- FMOD_DSP_LOUDNESS_METER_INFO_TYPE -->
Loudness readback (LUFS values and the histogram) is not exposed, because the HTML5 build returns zeroes from a working meter. Dsp.getMetering gives peak and RMS per output channel on every target.

## 23
<!-- FMOD_DSP_LOUDNESS_METER_STATE_TYPE -->
The state is an int with these enum values, set through setParameterInt on index 0 (STATE). Negative values reset the meter.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var meter = Dsp.create(DspType.LOUDNESS_METER);
meter.setParameterInt(0, -1); // STATE = RESET_ALL
meter.setParameterInt(0, 1); // STATE = ANALYZING
```

## 24
<!-- FMOD_DSP_LOUDNESS_METER_WEIGHTING_TYPE -->
Channel weighting is a data parameter of the loudness meter, whose readback is not exposed. The meter keeps FMOD's default weighting.

## 25
<!-- FMOD_DSP_LOWPASS -->
Parameters are set by index, and the index is the position of the value in this enum.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var lowpass = Dsp.create(DspType.LOWPASS);
lowpass.setParameter(0, 800); // CUTOFF in Hz
lowpass.setParameter(1, 1); // RESONANCE
```

## 26
<!-- FMOD_DSP_LOWPASS -->
The same emulation on a MULTIBAND_EQ unit. Band A's filter is index 0, its frequency index 1, and its Q index 2. LOWPASS_24DB is 2 in FMOD_DSP_MULTIBAND_EQ_FILTER_TYPE.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var frequency = 800.0;
var resonance = 1.0;
var multiband = Dsp.create(DspType.MULTIBAND_EQ);
multiband.setParameterInt(0, 2); // A_FILTER = LOWPASS_24DB
multiband.setParameter(1, frequency); // A_FREQUENCY
multiband.setParameter(2, resonance); // A_Q
```

## 27
<!-- FMOD_DSP_LOWPASS_SIMPLE -->
Parameters are set by index, and the index is the position of the value in this enum.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var lowpass = Dsp.create(DspType.LOWPASS_SIMPLE);
lowpass.setParameter(0, 800); // CUTOFF in Hz
```

## 28
<!-- FMOD_DSP_LOWPASS_SIMPLE -->
The same emulation on a MULTIBAND_EQ unit. Band A's filter is index 0 and its frequency index 1. LOWPASS_12DB is 1 in FMOD_DSP_MULTIBAND_EQ_FILTER_TYPE, and Q stays at its default.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var frequency = 800.0;
var multiband = Dsp.create(DspType.MULTIBAND_EQ);
multiband.setParameterInt(0, 1); // A_FILTER = LOWPASS_12DB
multiband.setParameter(1, frequency); // A_FREQUENCY
```

## 29
<!-- FMOD_DSP_MULTIBAND_DYNAMICS -->
Parameters are set by index, and the index is the position of the value in this enum. Each band takes eight consecutive indices starting at 4 for A, 12 for B, and 20 for C.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var dynamics = Dsp.create(DspType.MULTIBAND_DYNAMICS);
dynamics.setParameter(0, 200); // LOWER_FREQUENCY in Hz
dynamics.setParameter(1, 4000); // UPPER_FREQUENCY in Hz
dynamics.setParameterInt(4, 2); // A_MODE = COMPRESS_DOWN
dynamics.setParameter(6, -18); // A_THRESHOLD in dB
dynamics.setParameter(7, 3); // A_RATIO
```

## 30
<!-- FMOD_DSP_MULTIBAND_DYNAMICS_MODE_TYPE -->
The band mode is an int with these enum values, set through setParameterInt on the band's MODE index (4 for A, 12 for B, 20 for C).
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var dynamics = Dsp.create(DspType.MULTIBAND_DYNAMICS);
dynamics.setParameterInt(12, 4); // B_MODE = EXPAND_DOWN
```

## 31
<!-- FMOD_DSP_MULTIBAND_EQ -->
Parameters are set by index, and the index is the position of the value in this enum. Each band takes four consecutive indices: filter, frequency, Q, gain.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var eq = Dsp.create(DspType.MULTIBAND_EQ);
eq.setParameterInt(0, 7); // A_FILTER = LOWSHELF
eq.setParameter(1, 120); // A_FREQUENCY in Hz
eq.setParameter(3, 3); // A_GAIN in dB
eq.setParameterInt(4, 9); // B_FILTER = PEAKING
eq.setParameter(5, 2500); // B_FREQUENCY in Hz
eq.setParameter(6, 1.5); // B_Q
eq.setParameter(7, -4); // B_GAIN in dB
```

## 32
<!-- FMOD_DSP_MULTIBAND_EQ_FILTER_TYPE -->
The filter type is an int with these enum values, set through setParameterInt on the band's FILTER index (0, 4, 8, 12, 16).
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var eq = Dsp.create(DspType.MULTIBAND_EQ);
eq.setParameterInt(0, 11); // A_FILTER = NOTCH
eq.setParameterInt(4, 0); // B_FILTER = DISABLED
```

## 33
<!-- FMOD_DSP_NORMALIZE -->
Parameters are set by index, and the index is the position of the value in this enum.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var normalize = Dsp.create(DspType.NORMALIZE);
normalize.setParameter(0, 5000); // FADETIME in ms
normalize.setParameter(1, 0.1); // THRESHOLD
normalize.setParameter(2, 20); // MAXAMP
```

## 34
<!-- FMOD_DSP_OBJECTPAN -->
Parameters are set by index, and the index is the position of the value in this enum. The 3D position parameter takes the FMOD_DSP_PARAMETER_3DATTRIBUTES_MULTI struct, which is not exposed, so position an object panner by playing its source through a 3D channel and driving that channel's set3DAttributes instead.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var panner = Dsp.create(DspType.OBJECTPAN);
panner.setParameterInt(1, 2); // _3D_ROLLOFF = INVERSE
panner.setParameter(2, 1); // _3D_MIN_DISTANCE
panner.setParameter(3, 50); // _3D_MAX_DISTANCE
panner.setParameter(7, -3); // OVERALL_GAIN in dB
```

## 35
<!-- FMOD_DSP_OSCILLATOR -->
Parameters are set by index, and the index is the position of the value in this enum. A generator unit plays as a sound source through Dsp.play.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var oscillator = Dsp.create(DspType.OSCILLATOR);
oscillator.setParameterInt(0, 0); // TYPE, 0 = sine
oscillator.setParameter(1, 440); // RATE in Hz
var channel = oscillator.play();
channel.setVolume(0.2);
```

## 36
<!-- FMOD_DSP_PAN -->
Parameters are set by index, and the index is the position of the value in this enum. The 3D position parameter takes a struct that is not exposed, so 3D panning goes through a 3D channel's set3DAttributes instead. The 2D parameters work by index.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var pan = Dsp.create(DspType.PAN);
pan.setParameterInt(0, 1); // MODE = STEREO
pan.setParameter(1, -50); // _2D_STEREO_POSITION, percent left to right
pan.setParameter(3, 90); // _2D_EXTENT in degrees
```

## 37
<!-- FMOD_DSP_PAN -->
FMOD_DSP_PARAMETER_3DATTRIBUTES_MULTI is not exposed, so a pan unit cannot be positioned by parameter from Haxe. Play the source through a 3D channel and call Channel.set3DAttributes, which feeds the same panner with the Studio listeners.

## 38
<!-- FMOD_DSP_PAN_2D_STEREO_MODE_TYPE -->
The stereo mode is an int with these enum values, set through setParameterInt on index 6 (_2D_STEREO_MODE).
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var pan = Dsp.create(DspType.PAN);
pan.setParameterInt(6, 1); // _2D_STEREO_MODE = DISCRETE
```

## 39
<!-- FMOD_DSP_PAN_3D_EXTENT_MODE_TYPE -->
The extent mode is an int with these enum values, set through setParameterInt on index 14 (_3D_EXTENT_MODE).
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var pan = Dsp.create(DspType.PAN);
pan.setParameterInt(14, 1); // _3D_EXTENT_MODE = USER
pan.setParameter(15, 2); // _3D_SOUND_SIZE
```

## 40
<!-- FMOD_DSP_PAN_3D_ROLLOFF_TYPE -->
The rolloff is an int with these enum values, set through setParameterInt on index 11 (_3D_ROLLOFF). CUSTOM needs a curve handed to the pan unit through a data parameter, which is not exposed, so a custom curve goes on the channel instead with Channel.set3DCustomRolloff (unsupported in HTML5), where the call returns FMOD_ERR_UNSUPPORTED.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var pan = Dsp.create(DspType.PAN);
pan.setParameterInt(11, 1); // _3D_ROLLOFF = LINEAR
```

## 41
<!-- FMOD_DSP_PAN_MODE_TYPE -->
The pan mode is an int with these enum values, set through setParameterInt on index 0 (MODE).
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var pan = Dsp.create(DspType.PAN);
pan.setParameterInt(0, 2); // MODE = SURROUND
```

## 42
<!-- FMOD_DSP_PARAMEQ -->
Parameters are set by index, and the index is the position of the value in this enum.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var eq = Dsp.create(DspType.PARAMEQ);
eq.setParameter(0, 1000); // CENTER in Hz
eq.setParameter(1, 1); // BANDWIDTH in octaves
eq.setParameter(2, -6); // GAIN in dB
```

## 43
<!-- FMOD_DSP_PARAMEQ -->
The same emulation on a MULTIBAND_EQ unit. Band A's filter is index 0, frequency 1, Q 2, and gain 3. PEAKING is 9 in FMOD_DSP_MULTIBAND_EQ_FILTER_TYPE.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var center = 1000.0;
var bandwidth = 1.0;
var gain = -6.0;
var multiband = Dsp.create(DspType.MULTIBAND_EQ);
multiband.setParameterInt(0, 9); // A_FILTER = PEAKING
multiband.setParameter(1, center); // A_FREQUENCY
multiband.setParameter(2, bandwidth); // A_Q
multiband.setParameter(3, gain); // A_GAIN
```

## 44
<!-- FMOD_DSP_PITCHSHIFT -->
Parameters are set by index, and the index is the position of the value in this enum.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var pitch = Dsp.create(DspType.PITCHSHIFT);
pitch.setParameter(0, 0.5); // PITCH, 0.5 is one octave down
pitch.setParameter(1, 1024); // FFTSIZE
```

## 45
<!-- FMOD_DSP_RETURN -->
Parameters are set by index, and the index is the position of the value in this enum. The return's ID (index 0) is read with getParameterInt and given to a send's RETURNID.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

import haxefmod.core.ChannelGroup;

var ret = Dsp.create(DspType.RETURN);
ChannelGroup.master().addDsp(ChannelGroup.DSP_TAIL, ret);
var returnId = ret.getParameterInt(0); // ID
ret.setParameterInt(1, 3); // INPUT_SPEAKER_MODE = FMOD_SPEAKERMODE_STEREO
trace('return id $returnId');
```

## 46
<!-- FMOD_DSP_SEND -->
Parameters are set by index, and the index is the position of the value in this enum.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

import haxefmod.core.ChannelGroup;

var ret = Dsp.create(DspType.RETURN);
ChannelGroup.master().addDsp(ChannelGroup.DSP_TAIL, ret);
var send = Dsp.create(DspType.SEND);
send.setParameterInt(0, ret.getParameterInt(0)); // RETURNID
send.setParameter(1, -6); // LEVEL in dB
StudioSystem.getBus("bus:/SFX").getChannelGroup().addDsp(ChannelGroup.DSP_HEAD, send);
```

## 47
<!-- FMOD_DSP_SFXREVERB -->
Parameters are set by index, and the index is the position of the value in this enum. The first twelve indices match the fields of ReverbProperties in order. For a global reverb, Reverb.set with a preset is simpler than an SFXREVERB unit.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var reverb = Dsp.create(DspType.SFXREVERB);
reverb.setParameter(0, 2900); // DECAYTIME in ms
reverb.setParameter(9, 20000); // HIGHCUT in Hz
reverb.setParameter(11, -11.3); // WETLEVEL in dB
reverb.setParameter(12, 0); // DRYLEVEL in dB
```

## 48
<!-- FMOD_DSP_THREE_EQ -->
Parameters are set by index, and the index is the position of the value in this enum.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var eq = Dsp.create(DspType.THREE_EQ);
eq.setParameter(0, 3); // LOWGAIN in dB
eq.setParameter(1, 0); // MIDGAIN in dB
eq.setParameter(2, -2); // HIGHGAIN in dB
eq.setParameter(3, 400); // LOWCROSSOVER in Hz
eq.setParameter(4, 4000); // HIGHCROSSOVER in Hz
```

## 49
<!-- FMOD_DSP_THREE_EQ_CROSSOVERSLOPE_TYPE -->
The crossover slope is an int with these enum values, set through setParameterInt on index 5 (CROSSOVERSLOPE).
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var eq = Dsp.create(DspType.THREE_EQ);
eq.setParameterInt(5, 1); // CROSSOVERSLOPE = 24DB
```

## 50
<!-- FMOD_DSP_TRANSCEIVER -->
Parameters are set by index, and the index is the position of the value in this enum. One unit transmits on a channel and another receives it anywhere in the graph.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

import haxefmod.core.ChannelGroup;

var transmitter = Dsp.create(DspType.TRANSCEIVER);
transmitter.setParameterBool(0, true); // TRANSMIT
transmitter.setParameterInt(2, 3); // CHANNEL
StudioSystem.getBus("bus:/Music").getChannelGroup().addDsp(ChannelGroup.DSP_TAIL, transmitter);

var receiver = Dsp.create(DspType.TRANSCEIVER);
receiver.setParameterBool(0, false); // TRANSMIT off, so it receives
receiver.setParameterInt(2, 3); // CHANNEL
receiver.setParameter(1, -6); // GAIN in dB
ChannelGroup.master().addDsp(ChannelGroup.DSP_TAIL, receiver);
```

## 51
<!-- FMOD_DSP_TRANSCEIVER_SPEAKERMODE -->
The transmit speaker mode is an int with these enum values, set through setParameterInt on index 3 (TRANSMITSPEAKERMODE).
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var transmitter = Dsp.create(DspType.TRANSCEIVER);
transmitter.setParameterInt(3, 1); // TRANSMITSPEAKERMODE = STEREO
```

## 52
<!-- FMOD_DSP_TREMOLO -->
Parameters are set by index, and the index is the position of the value in this enum.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var tremolo = Dsp.create(DspType.TREMOLO);
tremolo.setParameter(0, 5); // FREQUENCY in Hz
tremolo.setParameter(1, 1); // DEPTH
tremolo.setParameter(2, 0.5); // SHAPE
tremolo.setParameter(7, 0.3); // SPREAD
```

## 53
<!-- FMOD_DSP_TYPE -->
haxefmod.core.DspType is an enum abstract with the same names and values, minus MAX. Every built-in type is available on every target. Third-party and custom plugin types are not.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

import haxefmod.core.ChannelGroup;

var lowpass = Dsp.create(DspType.LOWPASS);
if (lowpass.isNull()) {
    trace('create failed: ${StudioSystem.lastResult()}');
}
ChannelGroup.master().addDsp(ChannelGroup.DSP_HEAD, lowpass);
lowpass.setParameter(0, 800); // CUTOFF in Hz
```
