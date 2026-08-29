# studio-api-eventinstance

## FMOD_STUDIO_EVENT_CALLBACK
verdict: bound
Type: haxefmod.studio.Callbacks.EventCallback
The handler is an EventCallback, a Haxe function that receives an EventCallbackData value. Without a mask it receives EventCallbackType.PLAYBACK_ALL, the lifecycle, timeline, sound, and virtual types, so programmer sound, plugin, and command types need an explicit mask. DESTROYED is always added so the registration cleans itself up.
FMOD raises the callback on its own thread. haxefmod queues it and delivers it on the game thread from FmodManager.Update, so the handler may touch game state.
No return value and no userdata. The handle itself identifies the instance, and the payload is the FMOD struct of the callback type as the constructor's argument.
```haxe
import haxefmod.studio.Callbacks;

instance.setCallback(function(data:EventCallbackData) {
    switch (data) {
        case Started: trace("started");
        case Stopped: trace("stopped");
        case TimelineMarker(marker): trace("marker " + marker.name + " at " + marker.position);
        case TimelineBeat(beat): trace("beat " + beat.bar + ":" + beat.beat);
        default:
    }
}, EventCallbackType.STARTED | EventCallbackType.STOPPED | EventCallbackType.TIMELINE_MARKER | EventCallbackType.TIMELINE_BEAT);
instance.start();
```

## FMOD_STUDIO_EVENT_CALLBACK_TYPE
verdict: bound
Type: haxefmod.studio.Callbacks.EventCallbackType

## FMOD_STUDIO_EVENT_PROPERTY
verdict: bound
Type: haxefmod.studio.Types.FmodEventProperty

## FMOD_STUDIO_PLUGIN_INSTANCE_PROPERTIES
verdict: bound
Type: haxefmod.studio.Types.FmodPluginInstanceProperties

## FMOD_STUDIO_PROGRAMMER_SOUND_PROPERTIES
verdict: bound
Type: haxefmod.studio.Types.FmodProgrammerSoundProperties

## FMOD_STUDIO_STOP_MODE
verdict: bound
Type: haxefmod.studio.Types.FmodStopMode

## FMOD_STUDIO_TIMELINE_BEAT_PROPERTIES
verdict: bound
Type: haxefmod.studio.Types.FmodTimelineBeatProperties

## FMOD_STUDIO_TIMELINE_MARKER_PROPERTIES
verdict: bound
Type: haxefmod.studio.Types.FmodTimelineMarkerProperties

## FMOD_STUDIO_TIMELINE_NESTED_BEAT_PROPERTIES
verdict: bound
Type: haxefmod.studio.Types.FmodTimelineNestedBeatProperties
