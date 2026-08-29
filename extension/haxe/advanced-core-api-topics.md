# advanced-core-api-topics

## 10.2 Extracting PCM Data from a Sound
verdict: bound
```haxe
import haxefmod.core.Sound;
import haxefmod.studio.Types;

var sound = Sound.create("drumloop.wav", false, true); // openOnly, like FMOD_OPENONLY
var length = sound.getLength(FmodTimeUnit.RAWBYTES);

var buffer = haxe.io.Bytes.alloc(length);
var read = sound.readData(buffer);
```

## Codec Example
verdict: cannot registerCodec takes a description of callbacks that FMOD runs on its own threads, and no Haxe target can run code there. A codec built as a shared library loads with StudioSystem.loadPlugin, shown in the second Codec Example.

## Output Example
verdict: cannot registerOutput takes a description of callbacks that FMOD runs on its own threads, and no Haxe target can run code there. An output plug-in built as a shared library loads with StudioSystem.loadPlugin and CoreSystem.setOutputByPlugin selects it, shown in the second Output Example.

## DSP Example
verdict: cannot registerDSP takes a description of callbacks that FMOD runs on its mixer thread, and no Haxe target can run code there. A DSP plug-in built as a shared library loads with StudioSystem.loadPlugin and Dsp.createByPlugin makes a unit from it, shown in the second DSP Example.

## Codec Example#2
verdict: bound
```haxe
import haxefmod.core.Sound;

var handle = StudioSystem.loadPlugin("example_codec.dll");

// example.xyz is a file encoded with the codec's corresponding encoder
var sound = Sound.create("example.xyz");
```

## Output Example#2
verdict: bound
```haxe
import haxefmod.core.CoreSystem;

var handle = StudioSystem.loadPlugin("example_output.dll");
var result = CoreSystem.setOutputByPlugin(handle);
```

## DSP Example#2
verdict: bound
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.Sound;

var sound = Sound.create("drumloop.wav");

var handle = StudioSystem.loadPlugin("example_dsp.dll");
var channel = sound.play();
var dsp = Dsp.createByPlugin(handle);
var result = channel.addDsp(0, dsp);
```

## 10.7.1 3D Reverbs
verdict: bound
```haxe
import haxefmod.core.Reverb;
import haxefmod.core.Reverb3D;

var reverb = Reverb3D.create();
var prop2 = Reverb.PRESET_CONCERTHALL;
reverb.setProperties(prop2);
```

## 10.7.1 3D Reverbs#2
verdict: bound
```haxe
import haxefmod.core.Reverb3D;

var reverb = Reverb3D.create();
var pos = {x: -10.0, y: 0.0, z: 0.0};
var mindist = 10.0;
var maxdist = 20.0;
reverb.set3DAttributes(pos.x, pos.y, pos.z, mindist, maxdist);
```

## 10.7.1 3D Reverbs#3
verdict: bound
```haxe
var listenerpos = {x: 0.0, y: 0.0, z: -1.0};
StudioSystem.setListenerAttributes(0, {
    position: listenerpos,
    velocity: {x: 0.0, y: 0.0, z: 0.0},
    forward: {x: 0.0, y: 0.0, z: 1.0},
    up: {x: 0.0, y: 1.0, z: 0.0}
});
```

## 10.7.2 Using Multiple Reverbs
verdict: bound
```haxe
import haxefmod.core.Reverb;

var prop1 = Reverb.PRESET_HALLWAY;
var prop2 = Reverb.PRESET_SEWERPIPE;
var prop3 = Reverb.PRESET_PARKINGLOT;
var prop4 = Reverb.PRESET_CONCERTHALL;
```

## 10.7.2 Using Multiple Reverbs#2
verdict: bound
```haxe
import haxefmod.core.Reverb;

var prop1 = Reverb.PRESET_HALLWAY;
var prop2 = Reverb.PRESET_SEWERPIPE;
var prop3 = Reverb.PRESET_PARKINGLOT;
var prop4 = Reverb.PRESET_CONCERTHALL;

var result = Reverb.set(0, prop1);
result = Reverb.set(1, prop2);
result = Reverb.set(2, prop3);
result = Reverb.set(3, prop4);
```

## 10.7.2 Using Multiple Reverbs#3
verdict: bound
```haxe
import haxefmod.core.Reverb;

var prop = Reverb.get(3);
```

## 10.7.2 Using Multiple Reverbs#4
verdict: bound
```haxe
var result = channel.setReverbWet(1, 0.0);
```

## 10.7.2 Using Multiple Reverbs#5
verdict: bound
```haxe
var result = channel.setReverbWet(1, 1.0);
```

## Added new DSP effects
verdict: bound
Type: haxefmod.core.DspType
