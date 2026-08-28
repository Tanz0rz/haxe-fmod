# core-api-common

## 0
<!-- FMOD_3D_ATTRIBUTES -->
Fmod3DAttributes in haxefmod.studio.Types is a typedef with the same four FmodVector fields. Channels take position and velocity as plain floats through set3DAttributes.
```haxe
import haxefmod.studio.Types;

var attributes:Fmod3DAttributes = {
    position: {x: carX, y: carY, z: 0},
    velocity: {x: 0, y: 0, z: 0},
    forward: {x: 0, y: 0, z: 1},
    up: {x: 0, y: 1, z: 0},
};
instance.set3DAttributes(attributes);
StudioSystem.setListenerAttributes(0, attributes);
```

## 1
<!-- FMOD_CHANNELMASK -->
Channel masks are not exposed. Speaker layouts come from the mixer through CoreSystem.getSoftwareFormat, and per-speaker routing goes through Channel.setMixMatrix or ChannelGroup.setMixMatrix.

## 2
<!-- FMOD_CHANNELORDER -->
Channel order is not exposed. Sound.create and Sound.fromPcm use FMOD's default interleaved order.

## 3
<!-- FMOD_CPU_USAGE -->
StudioSystem.getCpuUsage returns a FmodSystemCpuUsage typedef that merges FMOD_CPU_USAGE with the studio update field. Values are percent of one core.
```haxe
var cpu = StudioSystem.getCpuUsage();
if (cpu != null) {
    trace('dsp ${cpu.dsp}% stream ${cpu.stream}% update ${cpu.update}% studio ${cpu.studioUpdate}%');
}
```

## 4
<!-- FMOD_DEBUG_CALLBACK -->
Debug callbacks are not exposed, since they run on FMOD threads. FMOD's log goes to the platform's standard output at the level set by FmodSettings.logLevel.

## 5
<!-- FMOD_DEBUG_FLAGS -->
The library picks the debug flags at init. Choose the level with FmodSettings.logLevel (0 none, 1 error, 2 warning, 3 log) or call FmodManager.EnableDebugMessages to log everything.
```haxe
FmodManager.Initialize({logLevel: 2});
```

## 7
<!-- FMOD_DEBUG_MODE -->
The debug output mode is fixed to FMOD's default. Set the level with FmodSettings.logLevel.

## 10
<!-- FMOD_GUID -->
GUIDs are strings in haxefmod, in the text form FMOD Studio shows and FMOD_Studio_ParseID accepts. StudioSystem.getEventByID and EventDescription.getID work with that string, and the generated FmodEventsGuids class holds one per event.
```haxe
var description = StudioSystem.getEvent("event:/SFX/Coin");
var guid = description.getID();
trace(guid);
```

## 11
<!-- FMOD_MAX_CHANNEL_WIDTH -->
There is no constant for the channel width limit. Mix matrices passed to setMixMatrix are validated by FMOD, so an oversized matrix comes back as FMOD_ERR_INVALID_PARAM.

## 12
<!-- FMOD_MAX_LISTENERS -->
There is no constant for the listener limit. StudioSystem.setNumListeners passes the count through to FMOD, which rejects anything above eight.
```haxe
if (!StudioSystem.setNumListeners(2).isOk()) {
    trace('listener count rejected: ${StudioSystem.lastResult()}');
}
```

## 13
<!-- FMOD_MAX_SYSTEMS -->
haxefmod creates exactly one FMOD system per process, so the system limit never applies.

## 14
<!-- FMOD_MEMORY_ALLOC_CALLBACK -->
Custom allocators are not exposed. FMOD uses its own allocator, and StudioSystem.getMemoryStats reports what it has allocated.
```haxe
var stats = StudioSystem.getMemoryStats();
if (stats != null) {
    trace('current ${stats.current} bytes, peak ${stats.maximum} bytes');
}
```

## 15
<!-- FMOD_MEMORY_FREE_CALLBACK -->
Custom allocators are not exposed. FMOD uses its own allocator.

## 18
<!-- FMOD_MEMORY_REALLOC_CALLBACK -->
Custom allocators are not exposed. FMOD uses its own allocator.

## 19
<!-- FMOD_MEMORY_TYPE -->
Memory type flags belong to the custom allocator hooks, which are not exposed. StudioSystem.getMemoryStats reports the current and peak allocation totals, and StudioSystem.getMemoryUsage breaks down what Studio objects hold on native targets.
```haxe
var memory = StudioSystem.getMemoryUsage();
if (memory != null) {
    trace('inclusive ${memory.inclusive} bytes, sample data ${memory.sampledata} bytes');
}
```

## 20
<!-- FMOD_MODE -->
haxefmod.core.ChannelMode holds the FMOD_MODE bits a game sets at runtime, with the same values. Combine them with bitwise or and pass the int to Sound.setMode or Channel.setMode. Loading flags such as CREATESTREAM and OPENMEMORY are chosen by Sound.create and Sound.fromPcm.
```haxe
import haxefmod.core.ChannelMode;
import haxefmod.core.Sound;

var sound = Sound.create("assets/sfx/engine.wav");
sound.setMode(ChannelMode.MODE_3D | ChannelMode.LOOP_NORMAL | ChannelMode.LINEAR_ROLLOFF_3D);
var channel = sound.play();
if ((channel.getMode() & ChannelMode.LOOP_NORMAL) != 0) {
    trace("looping");
}
```

## 21
<!-- FMOD_RESULT -->
haxefmod.studio.FmodResult is an enum abstract with the same names and values. Setters return one, isOk tests for FMOD_OK, toString gives the name, and StudioSystem.lastResult holds the code behind a failed getter or factory.
```haxe
import haxefmod.studio.FmodResult;

var result = channel.setVolume(0.5);
if (result == FmodResult.FMOD_ERR_INVALID_HANDLE) {
    trace("channel already ended");
} else if (!result.isOk()) {
    trace('setVolume failed: $result');
}
```

## 22
<!-- FMOD_SPEAKER -->
There is no speaker enum. Speaker positions are the row and column indices of a mix matrix in FMOD's speaker order (front left 0, front right 1, center 2, LFE 3, surround left 4, surround right 5, back left 6, back right 7), which Channel.setMixMatrix and ChannelGroup.setMixMatrix take directly.
```haxe
import haxefmod.core.ChannelGroup;

// send a mono input to front left only in a stereo output
ChannelGroup.master().setMixMatrix([1.0, 0.0], 2, 1);
```

## 23
<!-- FMOD_SPEAKERMODE -->
The speaker mode is a plain int with FMOD's values (0 default, 1 raw, 2 mono, 3 stereo, 4 quad, 5 surround, 6 5.1, 7 7.1, 8 7.1.4). Request one at init through FmodSettings.speakerMode and read the active one from CoreSystem.getSoftwareFormat.
```haxe
import haxefmod.core.CoreSystem;

FmodManager.Initialize({speakerMode: 3});
var format = CoreSystem.getSoftwareFormat();
if (format != null && format.speakerMode == 3) {
    trace('stereo at ${format.sampleRate} Hz');
}
```

## 24
<!-- FMOD_SYNCPOINT -->
Sync points are addressed by index on the sound instead of by pointer. Sound.addSyncPoint takes an offset in milliseconds and a name, and the channel reports crossings through Channel.setCallback.
```haxe
import haxefmod.core.ChannelEvent;
import haxefmod.core.Sound;

var sound = Sound.create("assets/music/loop.wav");
sound.addSyncPoint(2000, "drop");
var channel = sound.play();
channel.setCallback(function(event:ChannelEvent) {
    switch (event) {
        case SyncPoint(index): trace('hit ${sound.getSyncPointName(index)}');
        case End: trace("done");
    }
});
```

## 25
<!-- FMOD_THREAD_AFFINITY -->
Thread affinity is not exposed. FMOD chooses its thread placement on every target, and there is no thread to place on HTML5.

## 26
<!-- FMOD_THREAD_PRIORITY -->
Thread priority is not exposed. FMOD uses its default priorities on every target.

## 28
<!-- FMOD_THREAD_STACK_SIZE -->
Thread stack sizes are not exposed. FMOD uses its defaults on every target.

## 29
<!-- FMOD_THREAD_TYPE -->
FMOD thread settings are not exposed, so the thread type enum has no use from Haxe.

## 30
<!-- FMOD_TIMEUNIT -->
Positions and lengths are always milliseconds. Channel.getPosition, Channel.setPosition, Sound.getLength, and Sound.addSyncPoint take and return ms, so there is no time unit argument.
```haxe
import haxefmod.core.Sound;

var sound = Sound.create("assets/music/loop.wav");
var channel = sound.play();
channel.setPosition(1500);
trace('at ${channel.getPosition()} of ${sound.getLength()} ms');
```

## 31
<!-- FMOD_VECTOR -->
FmodVector in haxefmod.studio.Types is a typedef with x, y, and z floats. Any anonymous object with those fields works where one is expected.
```haxe
import haxefmod.studio.Types;

var position:FmodVector = {x: carX, y: carY, z: 0};
StudioSystem.setListenerPosition2D(0, cameraX, cameraY);
instance.set3DAttributes({
    position: position,
    velocity: {x: 0, y: 0, z: 0},
    forward: {x: 0, y: 0, z: 1},
    up: {x: 0, y: 1, z: 0},
});
```

## 32
<!-- FMOD_VERSION -->
haxefmod ships and links one FMOD version per release, and StudioSystem.getVersion reports the version of the library that is running as a string.
```haxe
trace('FMOD ${StudioSystem.getVersion()}');
```
