# core-api-channelcontrol

## ChannelControl::addFadePoint
verdict: bound
getDspClock returns both clocks in one struct, or null when the handle is invalid. Clock values are Floats, which hold sample counts exactly.
```haxe
// Example. Ramp from full volume to half volume over the next 4096 samples
var clocks = channel.getDspClock();
if (clocks != null) {
    var parentclock = clocks.parent;
    channel.addFadePoint(parentclock,        1.0);
    channel.addFadePoint(parentclock + 4096, 0.5);
}
```

## ChannelControl::addFadePoint#2
verdict: bound
getDspClock returns both clocks in one struct, or null when the handle is invalid. Clock values are Floats, which hold sample counts exactly.
```haxe
// Example. Ramp from full volume to half volume over the next 4096 samples
var clocks = channel.getDspClock();
if (clocks != null) {
    var parentclock = clocks.parent;
    channel.addFadePoint(parentclock,        1.0);
    channel.addFadePoint(parentclock + 4096, 0.5);
}
```

## FMOD_CHANNELCONTROL_CALLBACK
verdict: bound
Shape: usage
Raw channel callbacks run on FMOD's threads and cannot reach Haxe. Channel.setCallback delivers End and SyncPoint as ChannelEvent values on the game thread during FmodManager.Update().
```haxe
import haxefmod.core.ChannelEvent;

channel.setCallback(function(event:ChannelEvent) {
    switch (event) {
        case End: trace("channel finished");
        case SyncPoint(index): trace('sync point $index');
    }
});
```

## FMOD_CHANNELCONTROL_CALLBACK_TYPE
verdict: bound
Type: haxefmod.studio.Types.FmodChannelControlCallbackType
Channel.setCallback delivers END and SYNCPOINT as ChannelEvent values. VIRTUALVOICE and OCCLUSION are not delivered, Channel.isVirtual reports the voice state on demand.

## FMOD_CHANNELCONTROL_DSP_INDEX
verdict: bound
Type: haxefmod.studio.Types.ChannelControlDspIndex
addDsp, getDsp, and setDspIndex on Channel and ChannelGroup accept these values as the index.

## ChannelControl::set3DCustomRolloff
verdict: bound
Native only (unsupported in HTML5).
Each point is an FmodVector with x as the distance and y as the volume. The binding keeps its own copy of the points for the channel's lifetime.
```haxe
import haxefmod.studio.Types.FmodVector;

// Defining a custom array of points
var curve:Array<FmodVector> = [
    {x: 0.0,  y: 1.0, z: 0.0},
    {x: 2.0,  y: 0.2, z: 0.0},
    {x: 20.0, y: 0.0, z: 0.0}
];
channel.set3DCustomRolloff(curve);
```

## FMOD_CHANNELCONTROL_TYPE
verdict: bound
Type: haxefmod.studio.Types.FmodChannelControlType
Channel and ChannelGroup are separate handle types, so no Haxe call takes this value.
