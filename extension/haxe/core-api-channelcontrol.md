# core-api-channelcontrol

## ChannelControl::addFadePoint
verdict: bound
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
Type: haxefmod.core.ChannelEvent.ChannelCallback

## FMOD_CHANNELCONTROL_CALLBACK_TYPE
verdict: bound
Type: haxefmod.studio.Types.FmodChannelControlCallbackType

## FMOD_CHANNELCONTROL_DSP_INDEX
verdict: bound
Type: haxefmod.studio.Types.ChannelControlDspIndex

## ChannelControl::set3DCustomRolloff
verdict: bound
```haxe
import haxefmod.studio.Types.FmodVector;

// Defining a custom array of points
var curve:Array<FmodVector> = [
    {x: 0.0,  y: 1.0, z: 0.0},
    {x: 2.0,  y: 0.2, z: 0.0},
    {x: 20.0, y: 0.0, z: 0.0}
];
```

## FMOD_CHANNELCONTROL_TYPE
verdict: bound
Type: haxefmod.studio.Types.FmodChannelControlType

