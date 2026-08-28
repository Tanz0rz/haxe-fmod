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

## 40
<!-- FMOD_STUDIO_EVENT_CALLBACK_TYPE -->
Type: haxefmod.studio.Callbacks.EventCallbackType

## 41
<!-- FMOD_STUDIO_EVENT_PROPERTY -->
Type: haxefmod.studio.Types.FmodEventProperty

## 42
<!-- FMOD_STUDIO_PLUGIN_INSTANCE_PROPERTIES -->
No Haxe equivalent. The plugin callbacks arrive as EventCallbackData.Other(PLUGIN_CREATED) and Other(PLUGIN_DESTROYED) without a payload, since the DSP pointer has no meaning in Haxe.

## 43
<!-- FMOD_STUDIO_PROGRAMMER_SOUND_PROPERTIES -->
No Haxe equivalent. The programmer sound callbacks are handled natively, call EventInstance.assignProgrammerSound(key) before start(), native only (unsupported in HTML5).

## 44
<!-- FMOD_STUDIO_STOP_MODE -->
Type: haxefmod.studio.Types.FmodStopMode

## 45
<!-- FMOD_STUDIO_TIMELINE_BEAT_PROPERTIES -->
The beat properties are the arguments of the TimelineBeat constructor.
Type: haxefmod.studio.Callbacks.EventCallbackData

## 46
<!-- FMOD_STUDIO_TIMELINE_MARKER_PROPERTIES -->
The marker properties are the arguments of the TimelineMarker constructor.
Type: haxefmod.studio.Callbacks.EventCallbackData

## 47
<!-- FMOD_STUDIO_TIMELINE_NESTED_BEAT_PROPERTIES -->
The nested beat properties are the arguments of the NestedTimelineBeat constructor, the referenced event's GUID is not carried.
Type: haxefmod.studio.Callbacks.EventCallbackData
