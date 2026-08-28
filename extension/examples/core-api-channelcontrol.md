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
Channel.setCallback delivers END and SYNCPOINT as ChannelEvent values. Virtual voice and occlusion callbacks are not delivered, Channel.isVirtual reports the voice state on demand.

## 6
<!-- FMOD_CHANNELCONTROL_DSP_INDEX -->
ChannelGroup.DSP_HEAD, DSP_FADER, and DSP_TAIL are the same values, accepted by addDsp and getDsp on channels and groups.

## 42
<!-- ChannelControl::set3DCustomRolloff -->
Custom rolloff curves are native only (unsupported in HTML5), where the call returns FMOD_ERR_UNSUPPORTED. Each point is an FmodVector with x as the distance and y as the volume, and the copy FMOD needs lives with the channel until it is released.
```haxe
import haxefmod.core.ChannelMode;

channel.setMode(ChannelMode.MODE_3D);
channel.set3DCustomRolloff([{x: 1, y: 1, z: 0}, {x: 10, y: 0.5, z: 0}, {x: 50, y: 0, z: 0}]);
var points = channel.get3DCustomRolloff();
```

## 67
<!-- FMOD_CHANNELCONTROL_TYPE -->
Channel and ChannelGroup are separate handle types, so a callback handler already knows which one it was registered on.
