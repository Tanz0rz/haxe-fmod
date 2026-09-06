# Callbacks and 3D

## Typed callbacks

FMOD Studio delivers event callbacks (lifecycle changes, timeline beats, markers) on its own threads. The binding queues them natively. `FmodManager.Update()` or `FmodRuntime.update()` drains the queue on the game thread and decodes each callback into an `EventCallbackData` value. Handlers run on the game thread, once per frame, and never touch FMOD's threads.

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

The constructors are `Created`, `Destroyed`, `Starting`, `Started`, `Restarted`, `Stopped`, `StartFailed`, `TimelineMarker(properties)`, `TimelineBeat(properties)`, `NestedTimelineBeat(properties)`, `SoundPlayed`, `SoundStopped`, `RealToVirtual`, `VirtualToReal`, `PluginCreated(properties)`, `PluginDestroyed(properties)`, `ProgrammerSoundCreated(properties)`, `ProgrammerSoundDestroyed(properties)`, and `Other(type)` for the callback types without a dedicated constructor. Each payload is the FMOD struct of that callback, as a typedef in `haxefmod.studio.Types` with FMOD's field names. Two fields carry haxefmod handles. `FmodPluginInstanceProperties.dsp` is a `haxefmod.core.Dsp` that stays live until the destroyed callback. `FmodProgrammerSoundProperties.sound` is the `Sound` the instrument plays (see below). On HTML5 `NestedTimelineBeat` arrives with an empty `eventId`, because FMOD's JavaScript runtime hands the beat over without it.

`setCallback(handler, ?mask)` takes an optional mask of `EventCallbackType` bits. Without a mask the binding delivers every type, the same default as FMOD's own API. `DESTROYED` is always in the mask, so the registration cleans itself up. Pass a mask to receive only the types the handler switches on.

```haxe
import haxefmod.studio.Callbacks;

instance.setCallback(handler, EventCallbackType.TIMELINE_BEAT | EventCallbackType.STOPPED);
```

Each instance has one handler. A second registration replaces the first. `release()` removes the handler on every target. Put cleanup code there. A `Destroyed` case never runs on HTML5. See [Limitations](../limitations.md#html5).

`EventDescription.setCallback(handler, ?mask)` stores a handler. From then on `createInstance` installs it on every new instance of that description. Instances created before the call keep their handler. An instance's own `setCallback` replaces the inherited handler. `clearCallback()` removes the description's handler and leaves existing instances unchanged.

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

`FmodSound.onEvent` and `FmodManager.OnSongEvent` are the same mechanism on the handles of the helper class. `FmodManager.ClearAllCallbacks()` removes every handler at once.

### Programmer sounds

FMOD feeds a programmer instrument from its create callback, which runs on FMOD's thread. The library implements that callback natively. The game names the audio ahead of time. `EventInstance.assignProgrammerSound(key)` takes an audio table entry or a file path. Assign the key before `start()`. The native side resolves it when the instrument triggers.

The library creates the sound with `FMOD_NONBLOCKING`. The decode runs off the Studio thread, and FMOD waits for it before the instrument plays. `StudioSystem.getSoundInfo(key)` reports what FMOD loads for an audio table key. That is the file name or path and the subsound index inside it. It returns `null` for a key that is in no loaded audio table. Programmer sounds fail inside FMOD's JavaScript runtime, so every `assignProgrammerSound` variant is a compile error in a js build. See [Limitations](../limitations.md#html5).

`assignProgrammerSoundFrom(sound, ?subsoundIndex)` hands the instrument a `Sound` the game created from a file, from memory, or from PCM. The optional argument picks a subsound of an FSB. The instrument plays the sound and never releases it. Keep the sound alive until the instrument is done with it, then release it yourself. A sound still loading with `NONBLOCKING` is accepted. FMOD waits for it.

An event with several programmer instruments tells them apart by name. `assignProgrammerSoundForName(name, key)` maps one instrument name to a key or path. `assignProgrammerSounds(map)` sets several at once and stops at the first entry that fails. A name with no entry falls back to the single key.

The handler passed to `setCallback` receives `ProgrammerSoundCreated(properties)` when an instrument receives its sound, and `ProgrammerSoundDestroyed(properties)` when it is done. `properties` is an `FmodProgrammerSoundProperties`. `name` is the instrument's name in FMOD Studio. `sound` is the `Sound` the instrument plays. That is the one the game handed to `assignProgrammerSoundFrom`, or the one the library created for the key. A library-created sound stops resolving after the destroyed callback. `subsoundIndex` is the subsound inside it, `-1` for the whole sound.

`sound` is `Sound.NULL` when no assignment matched. `clearProgrammerSound()` drops every assignment.

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

`StudioSystem.setSystemCallback(handler, ?coreMask, ?studioMask)` installs one `SystemCallback` for events the systems themselves raise. The binding delivers them as `SystemEvent` values through the same per-frame drain. `DeviceListChanged` and `DeviceLost` come from the core system when the audio device list changes or the active device goes away. `Error(info)` comes from the core system when an FMOD call fails, once `SystemCallbacks.CORE_ERROR` is in the core mask. Its `FmodErrorCallbackInfo` holds the result, the object kind and handle, the function name, and the parameters. `BankUnload(path)`, `LiveUpdateConnected`, and `LiveUpdateDisconnected` come from Studio.

A second registration replaces the handler. `clearSystemCallback()` removes it.

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

The default masks deliver the device and Studio events above. `PreUpdate` and `PostUpdate` fire on every update, so they are opt-in through the studio mask, for example `SystemCallbacks.DEFAULT_STUDIO_MASK | SystemCallbacks.STUDIO_PREUPDATE`. `BankUnload` carries the bank path only for banks the game unloads through `Bank.unload` or `unloadAll`. FMOD refuses reads on the bank inside the callback, so the binding reads the path before the unload. A bank FMOD drops on its own arrives with an empty path. On HTML5 the core device events never fire under the browser output, and FMOD never raises the error callback.

### Core channel callbacks

`Channel.setCallback` takes a `ChannelCallback` and delivers `ChannelEvent` values: `End`, `SyncPoint(index)`, `VirtualVoice(isVirtual)`, and `Occlusion(direct, reverb)`. `ChannelGroup.setCallback` delivers the occlusion event for 3D groups. Both ride the same queue and the same per-frame drain. The sync point index is the point's position in offset order, the same handle `Sound.addSyncPoint` returns.

## Listeners

FMOD positions sound relative to listeners. `StudioSystem.setListenerAttributes` takes FMOD's full attributes struct. A 2D game has one listener at the camera or player and moves it every frame with `setListenerPosition2D(index, x, y, ?velocityX, ?velocityY)`. That call sets the position with unit forward and up vectors. `FmodRuntime.setListenerPosition(index, x, y)` is the same call from the runtime layer. The [engine listeners](components.md#listener) make the call every frame for you.

```haxe
StudioSystem.setListenerPosition2D(0, cameraX, cameraY);
```

Distance units are the units your game uses. Authored min and max distances in FMOD Studio use the same units. A pixel-based game authors its falloff in pixels.

## Positioned events

Any instance of a 3D event takes a position through `setPosition2D(x, y, ?velocityX, ?velocityY)`, the 2D form of `set3DAttributes`. Events authored without a spatializer ignore it.

```haxe
var instance = StudioSystem.getEvent("event:/SFX/Engine").createInstance();
instance.setPosition2D(carX, carY);
instance.start();
```

For objects that move, attach the instance. The runtime then pushes its position every update.

```haxe
import haxefmod.runtime.FmodRuntime;

FmodRuntime.attach(instance, carPositionProvider);
// when the object goes away
FmodRuntime.detach(instance);
instance.release();
```

`IFmodPositionProvider` is a four-method interface: `fmodX`, `fmodY`, `fmodVelocityX`, `fmodVelocityY`. The [engine components](components.md) adapt their objects to it (`FlxObject` and `FlxCamera`, `h2d.Object`, any Kha body with `x` and `y`). A game can also implement it directly. The runtime prunes dead instances (released, or stopped and destroyed by FMOD) from the attachment list. `FmodRuntime.attachedCount()` reports how many are live.

`FmodRuntime.playOneShotAttached(path, provider)` and `FmodManager.PlaySoundOneShotAttached` combine create, attach, start, and a release that fires when the event reports `STOPPED`. They suit self-ending events only. A looping event never stops on its own, so it never releases. For a looping event, keep the instance and call attach and detach yourself.

## Doppler and velocity

Attached instances and the [engine listeners](components.md#listener) push velocity with position, so an event authored with doppler responds to relative motion. Very fast movers and camera cuts can cause audible pitch flutter. The `maxAttachedVelocity` setting caps the velocity magnitude FMOD sees. It keeps the direction and leaves the position unchanged. `0`, the default, applies no cap.

```haxe
FmodManager.Initialize({maxAttachedVelocity: 600});
```

## Parameters

`setParameter(name, value, ?ignoreSeekSpeed)`, `setParameterWithLabel(name, label, ?ignoreSeekSpeed)`, `getParameter(name)`, and `getParameterFinal(name)` are short names for FMOD's `...ByName` calls. They exist on `EventInstance` for event parameters and on `StudioSystem` for global parameters.

```haxe
instance.setParameter("RPM", 0.7);
instance.setParameterWithLabel("Surface", "Gravel");
StudioSystem.setParameter("TimeOfDay", 0.25);
```

Parameter names are bare names, for example `"RPM"`. The generated `FmodParameters` constants hold full `parameter:/` paths for the global parameters. The description lookups accept those paths as well.
