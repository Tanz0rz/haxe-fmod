# using-dsp-effects-in-the-core-api

## 0
<!-- Add a DSP effect to a Channel -->
```haxe
import haxefmod.studio.CoreSound;
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var sound = CoreSound.create("assets/drumloop.wav");
var channel = sound.play();
var echo = Dsp.create(DspType.ECHO);
var result = channel.addDsp(0, echo);
if (!result.isOk()) {
    trace('addDsp failed: $result');
}
```

## 1
<!-- Add a DSP effect to a Channel -->
Reordering a unit in place is not exposed. Remove the effect and add it back at the wanted index.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var echo = Dsp.create(DspType.ECHO);
channel.addDsp(0, echo);

// move it to position 1
channel.removeDsp(echo);
channel.addDsp(1, echo);
```

## 2
<!-- Add a DSP effect to a Channel -->
```haxe
import haxefmod.core.ChannelGroup;

var group = ChannelGroup.create("my channelgroup");
var result = channel.setChannelGroup(group);
if (!result.isOk()) {
    trace('setChannelGroup failed: $result');
}
```

## 3
<!-- Add an effect to the ChannelGroup -->
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

## 4
<!-- Creating an effect and making all Channels send to it. -->
The tail unit of a group is not handed out directly. Adding the reverb at ChannelGroup.DSP_TAIL connects it as an input of the master group's last unit.
```haxe
import haxefmod.core.ChannelGroup;
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var reverb = Dsp.create(DspType.SFXREVERB);
var result = ChannelGroup.master().addDsp(ChannelGroup.DSP_TAIL, reverb);
if (!result.isOk()) {
    trace('addDsp failed: $result');
}
```

## 5
<!-- Creating an effect and making all Channels send to it. -->
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var reverb = Dsp.create(DspType.SFXREVERB);
var result = reverb.setActive(true);
if (!result.isOk()) {
    trace('setActive failed: $result');
}
```

## 6
<!-- Creating an effect and making all Channels send to it. -->
```haxe
import haxefmod.studio.CoreSound;
import haxefmod.core.ChannelGroup;
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var reverb = Dsp.create(DspType.SFXREVERB);
var group = ChannelGroup.create("my channelgroup");
var sound = CoreSound.create("assets/drumloop.wav");

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

## 7
<!-- Controlling mix level and pan matrices for DSPConnections -->
addInput returns the DspConnection handle directly.
```haxe
import haxefmod.studio.CoreSound;
import haxefmod.core.ChannelGroup;
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var reverb = Dsp.create(DspType.SFXREVERB);
var group = ChannelGroup.create("my channelgroup");
var sound = CoreSound.create("assets/drumloop.wav");

var channel = sound.play(true);
channel.setChannelGroup(group);
var head = channel.getDsp(ChannelGroup.DSP_HEAD);
var connection = reverb.addInput(head);
channel.setPaused(false);
```

## 8
<!-- Controlling mix level and pan matrices for DSPConnections -->
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

## 9
<!-- Set the output format of a DSP unit, and control the pan matrix for its output signal -->
DSP::setChannelFormat is not exposed. The mixer runs at the speaker mode chosen in FmodSettings, and a channel's output layout is shaped with Channel.setMixMatrix instead.

## 10
<!-- Set the output format of a DSP unit, and control the pan matrix for its output signal -->
Mix matrices are set on channels and channel groups rather than on a connection. The matrix is one flat array, rows are output channels and columns are input channels.
```haxe
var matrix:Array<Float> = [
    // FL FR SL SR  <- input signal (columns)
    0, 0, 0, 0, // front left out
    0, 0, 0, 0, // front right out
    1, 0, 0, 0, // surround left out
    0, 1, 0, 0 // surround right out
];
var result = channel.setMixMatrix(matrix, 4, 4);
if (!result.isOk()) {
    trace('setMixMatrix failed: $result');
}
```

## 11
<!-- Bypass an effect / disable it. -->
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var reverb = Dsp.create(DspType.SFXREVERB);
var result = reverb.setBypass(true);
if (!result.isOk()) {
    trace('setBypass failed: $result');
}
```

## *
<!-- page default -->
Plug-in DSP effects are not exposed. Haxe code cannot run on FMOD's mixer thread on any target and the web build has no plug-in host, so plug-in authoring and loading stay in C. All 33 built-in effect types are available through Dsp.create.
