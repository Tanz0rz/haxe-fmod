# core-api-channelcontrol

## ChannelControl::addFadePoint
verdict: bound
getDspClock returns both clocks in one struct, or null on failure. Clock values are Floats, exact to 2^53 samples.
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
getDspClock returns both clocks in one struct, or null on failure. Clock values are Floats, exact to 2^53 samples.
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
Raw channel callbacks run on FMOD's threads and cannot reach Haxe. Channel.setCallback and ChannelGroup.setCallback deliver ChannelEvent values on the game thread during FmodManager.Update(). A group only ever sees Occlusion, the other three are channel events.
```haxe
import haxefmod.core.ChannelEvent;

channel.setCallback(function(event:ChannelEvent) {
    switch (event) {
        case End: trace("channel finished");
        case SyncPoint(index): trace('sync point $index');
        case VirtualVoice(isVirtual): trace('virtual $isVirtual');
        case Occlusion(direct, reverb): trace('occluded $direct $reverb');
    }
});
```

## FMOD_CHANNELCONTROL_CALLBACK_TYPE
verdict: bound
Type: haxefmod.studio.Types.FmodChannelControlCallbackType
Channel.setCallback delivers all four as ChannelEvent values (End, SyncPoint, VirtualVoice, Occlusion). ChannelGroup.setCallback delivers Occlusion, the only one FMOD raises on a group.

## FMOD_CHANNELCONTROL_DSP_INDEX
verdict: bound
Type: haxefmod.studio.Types.ChannelControlDspIndex
addDsp, getDsp, and setDspIndex on Channel and ChannelGroup accept these values as the index. Channel.DSP_HEAD, DSP_FADER, and DSP_TAIL hold the same values as plain Int constants.

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
