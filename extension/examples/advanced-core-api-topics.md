# advanced-core-api-topics

## 0
<!-- 10.2 Extracting PCM Data from a Sound -->
Sound.readData reads decoded PCM out of a sound opened with the openOnly flag of Sound.create, and seekData moves the read cursor. Sound.getLength reports milliseconds rather than a byte count, so the buffer is read in fixed chunks until readData returns 0. Both are native only (unsupported in HTML5), where the call returns FMOD_ERR_UNSUPPORTED, so a web build keeps its own copy of the PCM it feeds through Sound.fromPcm or PcmStream.
```haxe
import haxefmod.core.Sound;

var sound = Sound.create("assets/sfx/engine.wav", false, true);
var lengthMs = sound.getLength(); // milliseconds, the PCM byte count is not reported
var buffer = haxe.io.Bytes.alloc(4096);
var read = sound.readData(buffer);
while (read > 0) {
    // the first read bytes of buffer hold decoded PCM
    read = sound.readData(buffer);
}
sound.release();
```

## 7
<!-- 10.7.1 3D Reverbs -->
```haxe
import haxefmod.core.Reverb;
import haxefmod.core.Reverb3D;

var reverb = Reverb3D.create();
if (reverb.isNull()) {
    trace('create failed: ${StudioSystem.lastResult()}');
}
reverb.setProperties(Reverb.PRESET_CONCERTHALL);
```

## 8
<!-- 10.7.1 3D Reverbs -->
```haxe
import haxefmod.core.Reverb3D;

var reverb = Reverb3D.create();
var minDist = 10.0;
var maxDist = 20.0;
reverb.set3DAttributes(-10.0, 0.0, 0.0, minDist, maxDist);
```

## 9
<!-- 10.7.1 3D Reverbs -->
```haxe
import haxefmod.studio.Types;

StudioSystem.setListenerAttributes(0, {
    position: {x: 0, y: 0, z: -1},
    velocity: {x: 0, y: 0, z: 0},
    forward: {x: 0, y: 0, z: 1},
    up: {x: 0, y: 1, z: 0}
});
```

## 10
<!-- 10.7.2 Using Multiple Reverbs -->
```haxe
import haxefmod.core.Reverb;

var prop1 = Reverb.PRESET_HALLWAY;
var prop2 = Reverb.PRESET_SEWERPIPE;
var prop3 = Reverb.PRESET_PARKINGLOT;
var prop4 = Reverb.PRESET_CONCERTHALL;
```

## 11
<!-- 10.7.2 Using Multiple Reverbs -->
```haxe
import haxefmod.core.Reverb;

Reverb.set(0, Reverb.PRESET_HALLWAY);
Reverb.set(1, Reverb.PRESET_SEWERPIPE);
Reverb.set(2, Reverb.PRESET_PARKINGLOT);
Reverb.set(3, Reverb.PRESET_CONCERTHALL);
```

## 12
<!-- 10.7.2 Using Multiple Reverbs -->
```haxe
import haxefmod.core.Reverb;

var prop = Reverb.get(3);
if (prop == null) {
    trace('get failed: ${StudioSystem.lastResult()}');
}
```

## 13
<!-- 10.7.2 Using Multiple Reverbs -->
```haxe
var result = channel.setReverbWet(1, 0.0);
if (!result.isOk()) {
    trace('setReverbWet failed: $result');
}
```

## 14
<!-- 10.7.2 Using Multiple Reverbs -->
```haxe
var result = channel.setReverbWet(1, 1.0);
if (!result.isOk()) {
    trace('setReverbWet failed: $result');
}
```

## 15
<!-- Added new DSP effects -->
Every built-in effect type is a DspType value with the same name as its FMOD_DSP_TYPE constant.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var send = Dsp.create(DspType.SEND);
var ret = Dsp.create(DspType.RETURN);
var pan = Dsp.create(DspType.PAN);
var threeEq = Dsp.create(DspType.THREE_EQ);
var fft = Dsp.create(DspType.FFT);
var loudness = Dsp.create(DspType.LOUDNESS_METER);
var convolution = Dsp.create(DspType.CONVOLUTIONREVERB);
var channelMix = Dsp.create(DspType.CHANNELMIX);
var transceiver = Dsp.create(DspType.TRANSCEIVER);
var objectPan = Dsp.create(DspType.OBJECTPAN);
var multibandEq = Dsp.create(DspType.MULTIBAND_EQ);
```

## 2
<!-- Output Example -->
registerOutput takes a description of callbacks that run on FMOD's threads, so an output plug-in is written in C and built as a shared library. The built library loads with StudioSystem.loadPlugin and CoreSystem.setOutputByPlugin selects it, native only (unsupported in HTML5). The library owns initialization, so on a running native system the call re-selects the output device on the spot.
```haxe
import haxefmod.core.CoreSystem;

StudioSystem.setPluginPath("plugins");
var plugin = StudioSystem.loadPlugin("example_output.dll");
if (plugin != 0) {
    var result = CoreSystem.setOutputByPlugin(plugin);
    if (!result.isOk()) {
        trace('setOutputByPlugin failed: $result');
    }
}
```

## 3
<!-- DSP Example -->
registerDSP takes a description of callbacks that run on FMOD's mixer thread, so a DSP plug-in is written in C and built as a shared library. The built library loads with StudioSystem.loadPlugin, Dsp.createByPlugin makes a unit from it, and the unit goes on a channel like any built-in effect, native only (unsupported in HTML5).
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.Sound;

StudioSystem.setPluginPath("plugins");
var plugin = StudioSystem.loadPlugin("example_dsp.dll");
var sound = Sound.create("assets/sfx/engine.wav");
var channel = sound.play();
if (plugin != 0) {
    var dsp = Dsp.createByPlugin(plugin);
    channel.addDsp(0, dsp);
}
```

## 5
<!-- Output Example -->
StudioSystem.loadPlugin loads the built output plug-in and CoreSystem.setOutputByPlugin selects it, native only (unsupported in HTML5). The library owns initialization, so on a running native system the call re-selects the output device on the spot.
```haxe
import haxefmod.core.CoreSystem;

StudioSystem.setPluginPath("plugins");
var plugin = StudioSystem.loadPlugin("example_output.dll");
if (plugin != 0) {
    var result = CoreSystem.setOutputByPlugin(plugin);
    if (!result.isOk()) {
        trace('setOutputByPlugin failed: $result');
    }
}
```

## 6
<!-- DSP Example -->
StudioSystem.loadPlugin loads the built DSP plug-in, Dsp.createByPlugin makes a unit from it, and the unit goes on a channel like any built-in effect, native only (unsupported in HTML5).
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.Sound;

StudioSystem.setPluginPath("plugins");
var plugin = StudioSystem.loadPlugin("example_dsp.dll");
var sound = Sound.create("assets/sfx/engine.wav");
var channel = sound.play();
if (plugin != 0) {
    var dsp = Dsp.createByPlugin(plugin);
    channel.addDsp(0, dsp);
}
```

## *
<!-- page default -->
Codec, output, and DSP plug-in authoring stays in C, because Haxe code cannot run on FMOD's mixer thread on any target. A prebuilt plug-in binary loads with StudioSystem.loadPlugin, and Dsp.createByPlugin creates a unit from it, native only (unsupported in HTML5) because the web build has no plug-in host. Built-in codecs, outputs, and all 33 built-in effect types are available on every target.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.ChannelGroup;

StudioSystem.setPluginPath("plugins");
var plugin = StudioSystem.loadPlugin("fmod_gain.dll");
if (plugin != 0) {
    var gain = Dsp.createByPlugin(plugin);
    ChannelGroup.master().addDsp(ChannelGroup.DSP_HEAD, gain);
}
```
