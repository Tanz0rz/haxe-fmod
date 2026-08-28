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
EventCallbackType holds the same bits. Combine them with | for the mask argument of setCallback. EventCallbackType.PLAYBACK_ALL covers every lifecycle and timeline type. Leaving the mask out subscribes to all of them.
```haxe
import haxefmod.studio.Callbacks;

instance.setCallback(handler, EventCallbackType.TIMELINE_BEAT | EventCallbackType.TIMELINE_MARKER);
```

## 41
<!-- FMOD_STUDIO_EVENT_PROPERTY -->
FmodEventProperty carries the same values for EventInstance.setProperty and getProperty.
```haxe
import haxefmod.studio.Types;

instance.setProperty(FmodEventProperty.MAXIMUM_DISTANCE, 800);
instance.setProperty(FmodEventProperty.CHANNELPRIORITY, 64);
trace(instance.getProperty(FmodEventProperty.COOLDOWN));
```

## 42
<!-- FMOD_STUDIO_PLUGIN_INSTANCE_PROPERTIES -->
The plugin created and destroyed callbacks arrive as EventCallbackData.Other(PLUGIN_CREATED) and Other(PLUGIN_DESTROYED) if subscribed, without the properties payload, because the DSP pointer it carries has no meaning in Haxe. A plugin effect used by an event loads with StudioSystem.loadPlugin before the bank, native only (unsupported in HTML5).

## 43
<!-- FMOD_STUDIO_PROGRAMMER_SOUND_PROPERTIES -->
The create and destroy programmer sound callbacks are handled natively. Call EventInstance.assignProgrammerSound(key) before start(), and the native side creates the sound from the audio table entry or file path when the instrument triggers and releases it when the instrument ends. Programmer sounds are native only (unsupported in HTML5), where the call returns FMOD_ERR_UNSUPPORTED because of a defect in FMOD's JavaScript runtime.
```haxe
var instance = StudioSystem.getEvent("event:/Dialogue/Line").createInstance();
if (instance.assignProgrammerSound("welcome").isOk()) {
    instance.start();
}
```

## 44
<!-- FMOD_STUDIO_STOP_MODE -->
FmodStopMode carries the same values. EventInstance.stop defaults to ALLOWFADEOUT.
```haxe
import haxefmod.studio.Types;

instance.stop();
instance.stop(FmodStopMode.IMMEDIATE);
```

## 45
<!-- FMOD_STUDIO_TIMELINE_BEAT_PROPERTIES -->
Beat properties arrive as the arguments of EventCallbackData.TimelineBeat.
```haxe
import haxefmod.studio.Callbacks;

instance.setCallback(function(data:EventCallbackData) {
    switch (data) {
        case TimelineBeat(bar, beat, positionMs, tempo, timeSigUpper, timeSigLower):
            pulseUI(bar, beat);
            trace('$tempo bpm in $timeSigUpper/$timeSigLower at $positionMs ms');
        default:
    }
}, EventCallbackType.TIMELINE_BEAT);
```

## 46
<!-- FMOD_STUDIO_TIMELINE_MARKER_PROPERTIES -->
Marker properties arrive as the arguments of EventCallbackData.TimelineMarker.
```haxe
import haxefmod.studio.Callbacks;

instance.setCallback(function(data:EventCallbackData) {
    switch (data) {
        case TimelineMarker(name, positionMs):
            if (name == "Chorus") trace('chorus starts at $positionMs ms');
        default:
    }
}, EventCallbackType.TIMELINE_MARKER);
```

## 47
<!-- FMOD_STUDIO_TIMELINE_NESTED_BEAT_PROPERTIES -->
Nested beats arrive as EventCallbackData.NestedTimelineBeat with the same arguments as TimelineBeat. The referenced event's GUID is not carried. Firefox never delivers nested beats, see the limitations page.
```haxe
import haxefmod.studio.Callbacks;

instance.setCallback(function(data:EventCallbackData) {
    switch (data) {
        case NestedTimelineBeat(bar, beat, positionMs, tempo, timeSigUpper, timeSigLower):
            pulseUI(bar, beat);
        default:
    }
}, EventCallbackType.NESTED_TIMELINE_BEAT);
```
