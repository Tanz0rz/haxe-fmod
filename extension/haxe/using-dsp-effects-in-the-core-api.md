# using-dsp-effects-in-the-core-api

## Add a DSP effect to a Channel
verdict: bound
```haxe
import haxefmod.core.Sound;
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var sound = Sound.create("assets/drumloop.wav");
var channel = sound.play();
var echo = Dsp.create(DspType.ECHO);
var result = channel.addDsp(0, echo);
if (!result.isOk()) {
    trace('addDsp failed: $result');
}
```

## Add a DSP effect to a Channel#2
verdict: bound
Channel.setDspIndex moves a unit that is already in the chain, and getDspIndex reads its position.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var echo = Dsp.create(DspType.ECHO);
channel.addDsp(0, echo);

// move it to position 1
channel.setDspIndex(echo, 1);
```

## Add a DSP effect to a Channel#3
verdict: bound
```haxe
import haxefmod.core.ChannelGroup;

var group = ChannelGroup.create("my channelgroup");
var result = channel.setChannelGroup(group);
if (!result.isOk()) {
    trace('setChannelGroup failed: $result');
}
```

## Add an effect to the ChannelGroup
verdict: bound
```haxe
import haxefmod.core.ChannelGroup;
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var group = ChannelGroup.create("my channelgroup");
var lowpass = Dsp.create(DspType.LOWPASS);
var result = group.addDsp(1, lowpass);
if (!result.isOk()) {
    trace('addDsp failed: $result');
}
```

## Creating an effect and making all Channels send to it.
verdict: bound
```haxe
import haxefmod.core.ChannelGroup;
import haxefmod.core.Dsp;
import haxefmod.core.DspType;
import haxefmod.studio.StudioSystem;

var reverb = Dsp.create(DspType.SFXREVERB);
var master = ChannelGroup.master();

// the fader is always the tail unit of a group, so every channel routed
// through the master group reaches this one
var masterFader = master.getDsp(ChannelGroup.DSP_TAIL);
var connection = reverb.addInput(masterFader);
if (connection.isNull()) {
    trace('addInput failed: ${StudioSystem.lastResult()}');
}
```

## Creating an effect and making all Channels send to it.#2
verdict: bound
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var reverb = Dsp.create(DspType.SFXREVERB);
var result = reverb.setActive(true);
if (!result.isOk()) {
    trace('setActive failed: $result');
}
```

## Creating an effect and making all Channels send to it.#3
verdict: bound
```haxe
import haxefmod.core.Sound;
import haxefmod.core.ChannelGroup;
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var reverb = Dsp.create(DspType.SFXREVERB);
var group = ChannelGroup.create("my channelgroup");
var sound = Sound.create("assets/drumloop.wav");

// play paused so nothing is heard before the connection exists
var channel = sound.play(true);
channel.setChannelGroup(group);
var head = channel.getDsp(ChannelGroup.DSP_HEAD);
var connection = reverb.addInput(head);
if (connection.isNull()) {
    trace('addInput failed: ${StudioSystem.lastResult()}');
}
channel.setPaused(false);
```

## Controlling mix level and pan matrices for DSPConnections
verdict: bound
addInput returns the DspConnection handle directly.
```haxe
import haxefmod.core.Sound;
import haxefmod.core.ChannelGroup;
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var reverb = Dsp.create(DspType.SFXREVERB);
var group = ChannelGroup.create("my channelgroup");
var sound = Sound.create("assets/drumloop.wav");

var channel = sound.play(true);
channel.setChannelGroup(group);
var head = channel.getDsp(ChannelGroup.DSP_HEAD);
var connection = reverb.addInput(head);
channel.setPaused(false);
```

## Controlling mix level and pan matrices for DSPConnections#2
verdict: bound
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var reverb = Dsp.create(DspType.SFXREVERB);
var connection = reverb.addInput(channel.getDsp(0));
var result = connection.setMix(0.0);
if (!result.isOk()) {
    trace('setMix failed: $result');
}
```

## Set the output format of a DSP unit, and control the pan matrix for its output signal
verdict: bound
Dsp.setChannelFormat sets the format a unit outputs, and getChannelFormat reads it back. The channel mask, channel count, and speaker mode take FMOD's numeric values.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var reverb = Dsp.create(DspType.SFXREVERB);
reverb.setChannelFormat(0, 2, 2); // FMOD_SPEAKERMODE_STEREO
```

## Set the output format of a DSP unit, and control the pan matrix for its output signal#2
verdict: bound
Dsp.getOutputConnection returns the connection on an output slot, and DspConnection.setMixMatrix sets the matrix on it. The matrix is one flat array, rows are output channels and columns are input channels.
```haxe
import haxefmod.core.ChannelGroup;
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var reverb = Dsp.create(DspType.SFXREVERB);
ChannelGroup.master().addDsp(ChannelGroup.DSP_HEAD, reverb);
var connection = reverb.getOutputConnection(0);
var matrix:Array<Float> = [
    // FL FR SL SR  <- input signal (columns)
    0, 0, 0, 0, // front left out
    0, 0, 0, 0, // front right out
    1, 0, 0, 0, // surround left out
    0, 1, 0, 0 // surround right out
];
if (!connection.isNull()) {
    var result = connection.setMixMatrix(matrix, 4, 4);
    if (!result.isOk()) {
        trace('setMixMatrix failed: $result');
    }
}
```

## Bypass an effect / disable it.
verdict: bound
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var reverb = Dsp.create(DspType.SFXREVERB);
var result = reverb.setBypass(true);
if (!result.isOk()) {
    trace('setBypass failed: $result');
}
```

## 7.2 Plug-in DSP Effects
verdict: review carried over from the page default
Plug-in DSP authoring stays in C, because Haxe code cannot run on FMOD's mixer thread on any target. A prebuilt plug-in binary loads with StudioSystem.loadPlugin, and Dsp.createByPlugin creates a unit from it, native only (unsupported in HTML5) because the web build has no plug-in host. All 33 built-in effect types are available through Dsp.create on every target.
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

## 7.2 Plug-in DSP Effects#2
verdict: review carried over from the page default
Plug-in DSP authoring stays in C, because Haxe code cannot run on FMOD's mixer thread on any target. A prebuilt plug-in binary loads with StudioSystem.loadPlugin, and Dsp.createByPlugin creates a unit from it, native only (unsupported in HTML5) because the web build has no plug-in host. All 33 built-in effect types are available through Dsp.create on every target.
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

## 7.2 Plug-in DSP Effects#3
verdict: review carried over from the page default
Plug-in DSP authoring stays in C, because Haxe code cannot run on FMOD's mixer thread on any target. A prebuilt plug-in binary loads with StudioSystem.loadPlugin, and Dsp.createByPlugin creates a unit from it, native only (unsupported in HTML5) because the web build has no plug-in host. All 33 built-in effect types are available through Dsp.create on every target.
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

## 7.2 Plug-in DSP Effects#4
verdict: bound
A plug-in built from a description loads with StudioSystem.loadPlugin after StudioSystem.setPluginPath names its folder, native only (unsupported in HTML5). Release every unit created from it before StudioSystem.unloadPlugin, which answers FMOD_ERR_DSP_INUSE until the mixer has freed them and succeeds when retried a few frames later.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.ChannelGroup;

StudioSystem.setPluginPath("plugins");
var plugin = StudioSystem.loadPlugin("fmod_gain.dll");
var gain = Dsp.createByPlugin(plugin);
ChannelGroup.master().addDsp(ChannelGroup.DSP_HEAD, gain);

// at shutdown
ChannelGroup.master().removeDsp(gain);
gain.release();
var result = StudioSystem.unloadPlugin(plugin);
if (!result.isOk()) {
    trace('unloadPlugin failed: $result');
}
```

## 7.2.1 The Plug-in Descriptor
verdict: review carried over from the page default
Plug-in DSP authoring stays in C, because Haxe code cannot run on FMOD's mixer thread on any target. A prebuilt plug-in binary loads with StudioSystem.loadPlugin, and Dsp.createByPlugin creates a unit from it, native only (unsupported in HTML5) because the web build has no plug-in host. All 33 built-in effect types are available through Dsp.create on every target.
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

## 7.2.4 Multiple plug-ins within one file
verdict: review carried over from the page default
Plug-in DSP authoring stays in C, because Haxe code cannot run on FMOD's mixer thread on any target. A prebuilt plug-in binary loads with StudioSystem.loadPlugin, and Dsp.createByPlugin creates a unit from it, native only (unsupported in HTML5) because the web build has no plug-in host. All 33 built-in effect types are available through Dsp.create on every target.
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

## 7.2.4 Multiple plug-ins within one file#2
verdict: bound
A file that exports a plug-in list loads as one handle. StudioSystem.getNestedPluginCount counts the plug-ins inside it, getNestedPlugin returns each one's handle, and getPluginInfo reports its name, type, and version, native only (unsupported in HTML5).
```haxe
StudioSystem.setPluginPath("plugins");
var plugin = StudioSystem.loadPlugin("fmod_effects.dll");
var count = StudioSystem.getNestedPluginCount(plugin);
for (i in 0...count) {
    var nestedPlugin = StudioSystem.getNestedPlugin(plugin, i);
    var info = StudioSystem.getPluginInfo(nestedPlugin);
    if (info != null) {
        trace(info.name + " type " + info.type + " version " + info.version);
    }
}
```
