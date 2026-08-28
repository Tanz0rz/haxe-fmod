# studio-api-eventinstance

## FMOD_STUDIO_EVENT_CALLBACK
verdict: bound
EventInstance.setCallback(handler, ?mask) takes a Haxe function that receives an EventCallbackData value. Callbacks are queued on FMOD's thread and delivered on the game thread from FmodManager.Update, so the handler can touch game state freely. There is no return value and no userdata, the handle itself identifies the instance.
```haxe
import haxefmod.studio.Callbacks;

instance.setCallback(function(data:EventCallbackData) {
    switch (data) {
        case Started: trace("started");
        case Stopped: trace("stopped");
        case TimelineMarker(name, positionMs): trace('marker $name at $positionMs');
        default:
    }
});
instance.start();
```

## FMOD_STUDIO_EVENT_CALLBACK_TYPE
verdict: bound
Type: haxefmod.studio.Callbacks.EventCallbackType

## FMOD_STUDIO_EVENT_PROPERTY
verdict: bound
Type: haxefmod.studio.Types.FmodEventProperty

## FMOD_STUDIO_PLUGIN_INSTANCE_PROPERTIES
verdict: library the payload of the plugin callbacks, delivered as EventCallbackData.Other(PLUGIN_CREATED) without it since a DSP pointer has no meaning in Haxe

## FMOD_STUDIO_PROGRAMMER_SOUND_PROPERTIES
verdict: library the programmer sound callbacks are handled natively, EventInstance.assignProgrammerSound(key) before start() picks the sound

## FMOD_STUDIO_STOP_MODE
verdict: bound
Type: haxefmod.studio.Types.FmodStopMode

## FMOD_STUDIO_TIMELINE_BEAT_PROPERTIES
verdict: covered the arguments of haxefmod.studio.Callbacks.EventCallbackData.TimelineBeat
The beat properties are the arguments of the TimelineBeat constructor of haxefmod.studio.Callbacks.EventCallbackData.

## FMOD_STUDIO_TIMELINE_MARKER_PROPERTIES
verdict: covered the arguments of haxefmod.studio.Callbacks.EventCallbackData.TimelineMarker
The marker properties are the arguments of the TimelineMarker constructor of haxefmod.studio.Callbacks.EventCallbackData.

## FMOD_STUDIO_TIMELINE_NESTED_BEAT_PROPERTIES
verdict: covered the arguments of haxefmod.studio.Callbacks.EventCallbackData.NestedTimelineBeat, the referenced event's GUID is not carried
The nested beat properties are the arguments of the NestedTimelineBeat constructor of haxefmod.studio.Callbacks.EventCallbackData, the referenced event's GUID is not carried.
