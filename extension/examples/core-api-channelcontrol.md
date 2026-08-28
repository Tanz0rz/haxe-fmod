# core-api-channelcontrol

## 2
<!-- ChannelControl::addFadePoint -->
getDspClock returns both clocks in one struct. Clock values are Floats, which hold sample counts exactly.
```haxe
// Ramp from full volume to half volume over the next 4096 samples
var clocks = channel.getDspClock();
if (clocks != null) {
    channel.addFadePoint(clocks.parent, 1.0);
    channel.addFadePoint(clocks.parent + 4096, 0.5);
}
```

## 3
<!-- ChannelControl::addFadePoint -->
getDspClock returns both clocks in one struct. Clock values are Floats, which hold sample counts exactly.
```haxe
// Ramp from full volume to half volume over the next 4096 samples
var clocks = channel.getDspClock();
if (clocks != null) {
    channel.addFadePoint(clocks.parent, 1.0);
    channel.addFadePoint(clocks.parent + 4096, 0.5);
}
```

## 4
<!-- FMOD_CHANNELCONTROL_CALLBACK -->
Raw channel callbacks cannot run on FMOD's threads from Haxe. Channel.setCallback delivers typed ChannelEvent values on the game thread from FmodManager.Update().
```haxe
import haxefmod.core.ChannelEvent;

channel.setCallback(event -> switch (event) {
    case End: trace("finished");
    case SyncPoint(index): trace('sync point $index');
    default:
});
```

## 5
<!-- FMOD_CHANNELCONTROL_CALLBACK_TYPE -->
ChannelEvent has End and SyncPoint(index) constructors. Virtual voice and occlusion callbacks are not delivered, isVirtual() reports the voice state on demand.
```haxe
import haxefmod.core.ChannelEvent;

channel.setCallback(event -> switch (event) {
    case End: trace("finished");
    case SyncPoint(index): trace('sync point $index');
    default:
});
if (channel.isVirtual()) trace("voice is virtual");
```

## 6
<!-- FMOD_CHANNELCONTROL_DSP_INDEX -->
The three built-in positions are constants on ChannelGroup and work for both channels and groups.
```haxe
import haxefmod.core.ChannelGroup;
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var lowpass = Dsp.create(DspType.LOWPASS);
channel.addDsp(ChannelGroup.DSP_HEAD, lowpass);
var fft = Dsp.create(DspType.FFT);
ChannelGroup.master().addDsp(ChannelGroup.DSP_TAIL, fft);
```

## 42
<!-- ChannelControl::set3DCustomRolloff -->
Custom rolloff curves are not exposed because FMOD needs the point array to outlive the channel. Pick a built-in rolloff mode instead.
```haxe
import haxefmod.core.ChannelMode;

channel.setMode(ChannelMode.MODE_3D | ChannelMode.LINEAR_SQUARE_ROLLOFF_3D);
channel.set3DMinMaxDistance(1, 20);
```

## 67
<!-- FMOD_CHANNELCONTROL_TYPE -->
Channel and ChannelGroup are separate handle types, so a callback handler already knows which one it was registered on.
