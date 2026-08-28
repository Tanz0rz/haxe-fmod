# studio-api-eventinstance

## 39
<!-- FMOD_STUDIO_EVENT_CALLBACK -->
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

## 45
<!-- FMOD_STUDIO_TIMELINE_BEAT_PROPERTIES -->
The beat properties are the arguments of the TimelineBeat constructor of haxefmod.studio.Callbacks.EventCallbackData.

## 46
<!-- FMOD_STUDIO_TIMELINE_MARKER_PROPERTIES -->
The marker properties are the arguments of the TimelineMarker constructor of haxefmod.studio.Callbacks.EventCallbackData.

## 47
<!-- FMOD_STUDIO_TIMELINE_NESTED_BEAT_PROPERTIES -->
The nested beat properties are the arguments of the NestedTimelineBeat constructor of haxefmod.studio.Callbacks.EventCallbackData, the referenced event's GUID is not carried.
