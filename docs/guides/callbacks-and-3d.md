# Callbacks and 3D

## Typed callbacks

FMOD Studio delivers event callbacks (lifecycle changes, timeline beats, markers) on its own threads. The binding queues them natively and `FmodManager.Update()` or `FmodRuntime.update()` drains the queue on the game thread, decoding each one into an `EventCallbackData` value. Handlers therefore run on the game thread, once per frame, and never touch FMOD's threads.

```haxe
import haxefmod.studio.Callbacks;

var instance = StudioSystem.getEvent("event:/Music/MainLevel").createInstance();
instance.setCallback(data -> switch (data) {
    case TimelineBeat(beat):
        pulseUI(beat.bar, beat.beat);
    case TimelineMarker(marker):
        trace('${marker.name} at ${marker.position} ms');
    case Stopped:
        trace("stopped");
    default:
});
instance.start();
```

The constructors are `Created`, `Destroyed`, `Starting`, `Started`, `Restarted`, `Stopped`, `StartFailed`, `TimelineMarker(properties)`, `TimelineBeat(properties)`, `NestedTimelineBeat(properties)`, `SoundPlayed`, `SoundStopped`, `RealToVirtual`, `VirtualToReal`, `PluginCreated(properties)`, `PluginDestroyed(properties)`, `ProgrammerSoundCreated(properties)`, `ProgrammerSoundDestroyed(properties)`, and `Other(type)` for the callback types without a dedicated constructor. Each payload is the FMOD struct of that callback as a typedef in `haxefmod.studio.Types`, with FMOD's field names. Two fields carry haxefmod handles: `FmodPluginInstanceProperties.dsp` is a `haxefmod.core.Dsp` live until the destroyed callback, and `FmodProgrammerSoundProperties.sound` is the `Sound` the instrument plays (see below). `NestedTimelineBeat` arrives with an empty `eventId` on HTML5, where FMOD's JavaScript runtime hands the beat over without it.

`setCallback(handler, ?mask)` takes an optional mask of `EventCallbackType` bits. Without a mask every type is delivered, the same default as FMOD's own API, and `DESTROYED` is always included so the registration cleans itself up. Pass a mask to receive only the types the handler switches on.

```haxe
import haxefmod.studio.Callbacks;

instance.setCallback(handler, EventCallbackType.TIMELINE_BEAT | EventCallbackType.STOPPED);
```

Each instance has one handler. Registering again replaces it. `release()` removes the handler on every target, so cleanup code that belongs with the instance's end goes there rather than in a `Destroyed` case. HTML5 never delivers `Destroyed` at all, see [Limitations](../limitations.md#html5).

`EventDescription.setCallback(handler, ?mask)` remembers a handler that `createInstance` installs on every instance made from that description from then on. Instances created before the call keep whatever handler they already had, and an instance's own `setCallback` still replaces the inherited one. `clearCallback()` forgets the description's handler, again without touching existing instances.

```haxe
import haxefmod.studio.Callbacks;

var description = StudioSystem.getEvent("event:/SFX/Footstep");
description.setCallback(data -> switch (data) {
    case Stopped: trace("a footstep ended");
    default:
}, EventCallbackType.STOPPED);
var step = description.createInstance(); // carries the handler
step.start();
step.release();
```

`FmodSound.onEvent` and `FmodManager.OnSongEvent` are the same mechanism on the facade's handles. `FmodManager.ClearAllCallbacks()` removes every handler at once.

### Programmer sounds

FMOD feeds a programmer instrument from its create callback, which runs on FMOD's thread. The library implements that callback natively, and the game names the audio ahead of time instead. `EventInstance.assignProgrammerSound(key)` takes an audio table entry or a file path. Assign it before `start()`, and the native side resolves it when the instrument triggers. The sound is created with `FMOD_NONBLOCKING`, so the decode runs off the Studio thread and FMOD waits for it before the instrument plays. `StudioSystem.getSoundInfo(key)` reports what FMOD would load for an audio table key, the file name or path and the subsound index inside it, and returns `null` for a key that is in no loaded audio table. Programmer sounds fail inside FMOD's JavaScript runtime, so every `assignProgrammerSound` variant is a compile error in a js build, see [Limitations](../limitations.md#html5).

`assignProgrammerSoundFrom(sound, ?subsoundIndex)` hands the instrument a `Sound` the game created itself, from a file, from memory, or from PCM, with an optional subsound of an FSB. The instrument plays it and never releases it. Keep the sound alive until the instrument is done with it and release it yourself afterwards. A sound still loading with `NONBLOCKING` is fine, FMOD waits for it.

An event with several programmer instruments tells them apart by name. `assignProgrammerSoundForName(name, key)` maps one instrument name to a key or path, and `assignProgrammerSounds(map)` sets several at once, stopping at the first entry that fails. A name with no entry falls back to the single key. The handler passed to `setCallback` receives `ProgrammerSoundCreated(properties)` when an instrument received its sound and `ProgrammerSoundDestroyed(properties)` when it is done. `properties` is an `FmodProgrammerSoundProperties`: `name` is the instrument's name in FMOD Studio, `sound` the `Sound` it plays (the one the game handed to `assignProgrammerSoundFrom`, or the one the library created for the key, which stops resolving after the destroyed callback), and `subsoundIndex` the subsound inside it, `-1` for the whole sound. `sound` is `Sound.NULL` when no assignment matched. `clearProgrammerSound()` drops every assignment.

```haxe
var line = StudioSystem.getEvent("event:/Dialogue/Conversation").createInstance();
line.assignProgrammerSounds(["Question" => "npc_question_03", "Answer" => "player_answer_03"]);
line.setCallback(data -> switch (data) {
    case ProgrammerSoundCreated(properties): trace('${properties.name} plays subsound ${properties.subsoundIndex} of ${properties.sound.getLength()} ms');
    case ProgrammerSoundDestroyed(properties): trace('${properties.name} finished');
    default:
});
line.start();
```

### System events

`StudioSystem.setSystemCallback(handler, ?coreMask, ?studioMask)` installs one `SystemCallback` for events the systems themselves raise, delivered as `SystemEvent` values through the same per-frame drain. `DeviceListChanged` and `DeviceLost` come from the core system when the audio device list changes or the active device goes away. `Error(info)` comes from the core system when an FMOD call fails, once `SystemCallbacks.CORE_ERROR` is in the core mask, with the result, the object kind and handle, the function name, and its parameters in a `FmodErrorCallbackInfo`. `BankUnload(path)`, `LiveUpdateConnected`, and `LiveUpdateDisconnected` come from Studio. Registering again replaces the handler, and `clearSystemCallback()` removes it.

```haxe
import haxefmod.studio.SystemCallbacks;

StudioSystem.setSystemCallback(event -> switch (event) {
    case DeviceListChanged:
        trace("audio devices changed");
    case BankUnload(path):
        trace('unloaded $path');
    case LiveUpdateConnected:
        trace("FMOD Studio connected");
    case Error(info):
        trace('${info.functionName} failed with ${info.result.toString()}');
    default:
}, SystemCallbacks.DEFAULT_CORE_MASK | SystemCallbacks.CORE_ERROR);
```

The default masks deliver the device and Studio events above. `PreUpdate` and `PostUpdate` fire on every update, so they are opt-in through the studio mask, for example `SystemCallbacks.DEFAULT_STUDIO_MASK | SystemCallbacks.STUDIO_PREUPDATE`. `BankUnload` carries the bank path only for banks the game unloads through `Bank.unload` or `unloadAll`, since FMOD refuses reads on the bank inside the callback and the binding reads the path ahead of the unload. A bank FMOD drops on its own arrives with an empty path. On HTML5 the core device events never fire under the browser output and the error callback is never raised.

### Core channel callbacks

`Channel.setCallback` takes a `ChannelCallback` and delivers `ChannelEvent` values (`End`, `SyncPoint(index)`, `VirtualVoice(isVirtual)`, `Occlusion(direct, reverb)`), and `ChannelGroup.setCallback` delivers the occlusion event for 3D groups. They ride the same queue and the same per-frame drain. The sync point index is the point's position in offset order, the same handle `Sound.addSyncPoint` returns.

## Listeners

FMOD positions sound relative to listeners, and `StudioSystem.setListenerAttributes` takes FMOD's full attributes struct. A 2D game has one listener at the camera or player and moves it every frame with `setListenerPosition2D(index, x, y, ?velocityX, ?velocityY)`, which sets the position with unit forward and up vectors. `FmodRuntime.setListenerPosition(index, x, y)` is the same call from the runtime layer, and the [engine listeners](components.md#listener) make it every frame for you.

```haxe
StudioSystem.setListenerPosition2D(0, cameraX, cameraY);
```

Distance units are whatever your game uses. Authored min and max distances in FMOD Studio are in those same units, so a pixel-based game authors its falloff in pixels.

## Positioned events

Any instance of a 3D event takes a position through `setPosition2D(x, y, ?velocityX, ?velocityY)`, the 2D form of `set3DAttributes`. Events authored without a spatializer ignore it.

```haxe
var instance = StudioSystem.getEvent("event:/SFX/Engine").createInstance();
instance.setPosition2D(carX, carY);
instance.start();
```

For objects that move, attach the instance and let the runtime push its position every update.

```haxe
import haxefmod.runtime.FmodRuntime;

FmodRuntime.attach(instance, carPositionProvider);
// when the object goes away
FmodRuntime.detach(instance);
instance.release();
```

`IFmodPositionProvider` is a four-method interface: `fmodX`, `fmodY`, `fmodVelocityX`, `fmodVelocityY`. The [engine components](components.md) adapt their objects to it (`FlxObject` and `FlxCamera`, `h2d.Object`, any Kha body with `x` and `y`), and a game can implement it directly. Instances that die (released, or stopped and destroyed by FMOD) are pruned from the attachment list automatically, and `FmodRuntime.attachedCount()` reports how many are live.

`FmodRuntime.playOneShotAttached(path, provider)` and `FmodManager.PlaySoundOneShotAttached` combine create, attach, start, and a release that fires when the event reports `STOPPED`. They suit self-ending events only. A looping event never stops on its own, so it would never release, and for those you keep the instance and use attach and detach yourself.

## Doppler and velocity

Attached instances and the [engine listeners](components.md#listener) push velocity alongside position, so an event authored with doppler responds to relative motion. Very fast movers and camera cuts can produce audible pitch flutter. The `maxAttachedVelocity` setting caps the velocity magnitude FMOD sees, preserving direction and leaving the position untouched. `0`, the default, applies no cap.

```haxe
FmodManager.Initialize({maxAttachedVelocity: 600});
```

## Parameters

`setParameter(name, value, ?ignoreSeekSpeed)`, `setParameterWithLabel(name, label, ?ignoreSeekSpeed)`, `getParameter(name)`, and `getParameterFinal(name)` are short names for FMOD's `...ByName` calls, on `EventInstance` for event parameters and on `StudioSystem` for global ones.

```haxe
instance.setParameter("RPM", 0.7);
instance.setParameterWithLabel("Surface", "Gravel");
StudioSystem.setParameter("TimeOfDay", 0.25);
```

Parameter names are bare names, for example `"RPM"`. The generated `FmodParameters` constants hold full `parameter:/` paths for the global parameters, which the description lookups accept as well.
