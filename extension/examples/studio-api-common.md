# studio-api-common

## 0
<!-- FMOD_STUDIO_LOADING_STATE -->
FmodLoadingState carries the same values. Bank.getLoadingState, Bank.getSampleLoadingState, and EventDescription.getSampleLoadingState return it directly.
```haxe
import haxefmod.studio.Types;

var bank = StudioSystem.loadBankFile("assets/fmod/Desktop/SFX.bank", NONBLOCKING);
switch (bank.getLoadingState()) {
    case LOADED: trace("bank ready");
    case LOADING, UNLOADING: trace("still working");
    case UNLOADED: trace("not loaded");
    case ERROR: trace('bank failed: ${StudioSystem.lastResult()}');
}
```

## 1
<!-- FMOD_STUDIO_MEMORY_USAGE -->
FmodMemoryUsage has the same three fields in bytes. StudioSystem.getMemoryUsage, Bus.getMemoryUsage, and EventInstance.getMemoryUsage return it, or null on HTML5 where FMOD does not report memory.
```haxe
var usage = StudioSystem.getMemoryUsage();
if (usage != null) {
    trace('exclusive ${usage.exclusive} inclusive ${usage.inclusive} sample data ${usage.sampledata}');
}
```

## 2
<!-- FMOD_STUDIO_PARAMETER_DESCRIPTION -->
FmodParameterDescription is the Haxe form. The GUID field is not carried, look it up by path with StudioSystem.lookupID when you need it.
```haxe
var description = StudioSystem.getEvent("event:/SFX/Engine");
var rpm = description.getParameterDescriptionByName("RPM");
if (rpm != null) {
    trace('${rpm.name}: ${rpm.minimum} to ${rpm.maximum}, default ${rpm.defaultValue}');
    var id = rpm.id;
    instance.setParameterByID(id, rpm.maximum * 0.5);
}
```

## 3
<!-- FMOD_STUDIO_PARAMETER_FLAGS -->
FmodParameterFlags holds the same bits. The flags field of a description is an Int, so mask it with the flag you care about.
```haxe
import haxefmod.studio.Types;

var description = StudioSystem.getEvent("event:/SFX/Engine");
for (i in 0...description.getParameterDescriptionCount()) {
    var parameter = description.getParameterDescriptionByIndex(i);
    if (parameter == null) continue;
    var labeled = (parameter.flags & FmodParameterFlags.LABELED) != 0;
    var readOnly = (parameter.flags & FmodParameterFlags.READONLY) != 0;
    if (labeled && !readOnly) {
        trace('${parameter.name} first label: ${description.getParameterLabel(parameter.name, 0)}');
    }
}
```

## 4
<!-- FMOD_STUDIO_PARAMETER_ID -->
FmodParameterId is a {data1, data2} structure taken from a parameter description. Keep it when you set the same parameter every frame, since the by-ID calls skip the name lookup.
```haxe
var rpm = StudioSystem.getEvent("event:/SFX/Engine").getParameterDescriptionByName("RPM");
var rpmId = rpm.id;
instance.setParameterByID(rpmId, 3200);
trace(instance.getParameterByID(rpmId));
```

## 5
<!-- FMOD_STUDIO_PARAMETER_TYPE -->
FmodParameterType carries the same values and is the type field of FmodParameterDescription.
```haxe
import haxefmod.studio.Types;

var description = StudioSystem.getEvent("event:/SFX/Engine");
for (i in 0...description.getParameterDescriptionCount()) {
    var parameter = description.getParameterDescriptionByIndex(i);
    if (parameter == null) continue;
    switch (parameter.type) {
        case GAME_CONTROLLED: trace('${parameter.name} is set by the game');
        case AUTOMATIC_DISTANCE, AUTOMATIC_DISTANCE_NORMALIZED: trace('${parameter.name} follows distance');
        default: trace('${parameter.name} is driven by FMOD');
    }
}
```

## 7
<!-- FMOD_STUDIO_PLAYBACK_STATE -->
FmodPlaybackState carries the same values and is returned by EventInstance.getPlaybackState.
```haxe
switch (instance.getPlaybackState()) {
    case PLAYING, STARTING, SUSTAINING: trace("audible");
    case STOPPING: trace("fading out");
    case STOPPED: instance.release();
}
```
