# studio-api-eventinstance

## FMOD_STUDIO_EVENT_CALLBACK
verdict: bound
Shape: usage
The handler is a Haxe function that receives an EventCallbackData value. The mask defaults to ALL.
FMOD raises the callback on its own thread. haxefmod queues it and delivers it on the game thread from FmodManager.Update, so the handler may touch game state.
No return value and no userdata. The handle itself identifies the instance, and the payload comes as constructor arguments.
```haxe
import haxefmod.studio.Callbacks;

instance.setCallback(function(data:EventCallbackData) {
    switch (data) {
        case Started: trace("started");
        case Stopped: trace("stopped");
        case TimelineMarker(name, positionMs): trace("marker " + name + " at " + positionMs);
        case TimelineBeat(bar, beat, positionMs, tempo, timeSigUpper, timeSigLower): trace("beat " + bar + ":" + beat);
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
verdict: covered the arguments of haxefmod.studio.Callbacks.EventCallbackData.PluginCreated(name, dsp) and PluginDestroyed(name, dsp). dsp is a haxefmod.core.Dsp handle, live until the destroyed callback delivers it again for matching

## FMOD_STUDIO_PROGRAMMER_SOUND_PROPERTIES
verdict: library the programmer sound callbacks are handled natively, EventInstance.assignProgrammerSound(key) before start() picks the sound

## FMOD_STUDIO_STOP_MODE
verdict: bound
Type: haxefmod.studio.Types.FmodStopMode

## FMOD_STUDIO_TIMELINE_BEAT_PROPERTIES
verdict: covered the arguments of haxefmod.studio.Callbacks.EventCallbackData.TimelineBeat(bar, beat, positionMs, tempo, timeSigUpper, timeSigLower)

## FMOD_STUDIO_TIMELINE_MARKER_PROPERTIES
verdict: covered the arguments of haxefmod.studio.Callbacks.EventCallbackData.TimelineMarker(name, positionMs)

## FMOD_STUDIO_TIMELINE_NESTED_BEAT_PROPERTIES
verdict: covered the arguments of haxefmod.studio.Callbacks.EventCallbackData.NestedTimelineBeat(bar, beat, positionMs, tempo, timeSigUpper, timeSigLower, eventId), eventId is the GUID FMOD reports for the referenced timeline, in FMOD's text form (empty in HTML5, the web runtime hands the beat over without it)
