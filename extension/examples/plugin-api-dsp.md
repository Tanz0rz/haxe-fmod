# plugin-api-dsp

## 3
<!-- FMOD_DSP_BUFFER_ARRAY -->
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

## 4
<!-- FMOD_DSP_BUFFER_ARRAY -->
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

## 25
<!-- FMOD_DSP_METERING_INFO -->
The metering struct is filled by FMOD for any unit once metering is enabled. Read it through getMetering, which returns peak and RMS arrays per output channel.
Shape: usage
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

## 43
<!-- FMOD_DSP_PARAMETER_FFT -->
The FFT data parameter belongs to the built-in FFT unit. Attach one where you want to listen and read the spectrum with getFftSpectrum instead of decoding the struct by hand.
Shape: usage
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

## 37
<!-- FMOD_DSP_PARAMETER_DESC -->
haxefmod does not expose the descriptor struct. getParameterInfo returns its name, type, and range as a plain structure (null in HTML5).
Shape: usage
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var eq = Dsp.create(DspType.THREE_EQ);
for (i in 0...eq.getParameterCount()) {
    var info = eq.getParameterInfo(i);
    if (info != null) trace('${info.name} type ${info.type} ${info.min}..${info.max} default ${info.defaultValue}');
}
```

## 50
<!-- FMOD_DSP_PARAMETER_TYPE -->
The parameter type comes back as an Int from getParameterInfo and matches the Dsp.PARAMETER_* constants.
Shape: usage
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var eq = Dsp.create(DspType.THREE_EQ);
var info = eq.getParameterInfo(0);
if (info != null) switch (info.type) {
    case Dsp.PARAMETER_FLOAT: eq.setParameter(0, info.defaultValue);
    case Dsp.PARAMETER_INT: eq.setParameterInt(0, Std.int(info.defaultValue));
    case Dsp.PARAMETER_BOOL: eq.setParameterBool(0, info.defaultValue != 0);
    case Dsp.PARAMETER_DATA: trace('data parameter');
}
```

## 70
<!-- FMOD_DSP_STATE -->
No Haxe equivalent. This is the C source of a plug-in oscillator, which keeps its phase in plugindata on the mixer thread. FMOD ships the same oscillator as a built-in unit, see the Haxe example under the next tab (Dsp.create(DspType.OSCILLATOR)).

## 71
<!-- FMOD_DSP_STATE -->
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

## 72
<!-- FMOD_DSP_STATE -->
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

## *
<!-- page default -->
This page describes the C structures and callbacks a DSP plug-in implements, and every one of them runs on FMOD's mixer thread inside the FMOD process. Haxe code cannot run there on any target, so custom DSP units stay in C or C++.
From Haxe, use the 33 built-in effects through haxefmod.core.Dsp (create, setParameter, addDsp, getMetering, getFftSpectrum) or generate audio yourself with haxefmod.core.PcmStream. See docs/guides/core-api.md.
