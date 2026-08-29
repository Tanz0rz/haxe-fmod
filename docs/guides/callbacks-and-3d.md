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

The constructors are `Created`, `Destroyed`, `Starting`, `Started`, `Restarted`, `Stopped`, `StartFailed`, `TimelineMarker(properties)`, `TimelineBeat(properties)`, `NestedTimelineBeat(properties)`, `SoundPlayed`, `SoundStopped`, `RealToVirtual`, `VirtualToReal`, `PluginCreated(properties)` and `PluginDestroyed(properties)` for the plugin effects on the instance, `ProgrammerSoundCreated(properties)` and `ProgrammerSoundDestroyed(properties)` for programmer instruments, and `Other(type)` for the callback types without a dedicated constructor. Each payload is the FMOD struct of the callback as a typedef in `haxefmod.studio.Types`, with FMOD's field names: `FmodTimelineMarkerProperties` (`name`, `position` in milliseconds), `FmodTimelineBeatProperties` (`bar`, `beat`, `position`, `tempo`, `timeSignatureUpper`, `timeSignatureLower`), `FmodTimelineNestedBeatProperties` (`eventId`, the GUID FMOD reports for the referenced timeline the beat comes from, empty in HTML5 where FMOD's JavaScript runtime hands the beat over without it, and `properties`, the beat), `FmodPluginInstanceProperties` (`name` and `dsp`, a `haxefmod.core.Dsp` handle live until the destroyed callback), and `FmodProgrammerSoundProperties` (see below).

`setCallback(handler, ?mask)` takes an optional mask of `EventCallbackType` bits. Without a mask every playback event is delivered (`EventCallbackType.PLAYBACK_ALL`). A mask limits delivery to the events you care about, which matters for busy events like beat tracking on a fast tempo.

```haxe
import haxefmod.studio.Callbacks;

instance.setCallback(handler, EventCallbackType.TIMELINE_BEAT | EventCallbackType.STOPPED);
```

Each instance has one handler. Registering again replaces it. `release()` removes the handler on every target, so cleanup code that belongs with the instance's end goes there rather than in a `Destroyed` case. HTML5 never delivers `Destroyed` at all, see [Platforms](../platforms.md#html5).

`EventDescription.setCallback(handler, ?mask)` remembers a handler that `createInstance` installs on every instance made from that description from then on, the way `Studio::EventDescription::setCallback` does. Instances created before the call keep whatever handler they already had, and an instance's own `setCallback` still replaces the inherited one. `clearCallback()` forgets the description's handler, again without touching existing instances.

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

`EventInstance.assignProgrammerSound(key)` names the audio a programmer instrument should play. Assign it before `start()`, and the native side resolves it on FMOD's thread when the instrument triggers. The key is either an audio table entry or a file path. Keys must be under 512 UTF-8 bytes. The sound is created with `FMOD_NONBLOCKING`, so the decode runs off the Studio thread and FMOD waits for it before the instrument plays. On HTML5 the call returns `FMOD_ERR_UNSUPPORTED` because of a defect in FMOD's JavaScript runtime, documented in [Limitations](../limitations.md#html5). `StudioSystem.getSoundInfo(key)` reports what FMOD would load for an audio table key, the file name or path and the subsound index inside it, and returns `null` for a key that is in no loaded audio table.

`assignProgrammerSoundFrom(sound, ?subsoundIndex)` hands the instrument a `Sound` the game created itself, from a file, from memory, or from PCM, with an optional subsound of an FSB. The instrument plays it and never releases it. Keep the sound alive until the instrument is done with it and release it yourself afterwards. A sound still loading with `NONBLOCKING` is fine, FMOD waits for it.

An event with several programmer instruments tells them apart by name. `assignProgrammerSoundForName(name, key)` maps one instrument name to a key or path, and `assignProgrammerSounds(map)` sets several at once, up to eight per instance. A name with no entry falls back to the single key. The handler passed to `setCallback` receives `ProgrammerSoundCreated(properties)` when an instrument received its sound and `ProgrammerSoundDestroyed(properties)` when it is done. `properties` is an `FmodProgrammerSoundProperties`: `name` is the instrument's name in FMOD Studio, `sound` the `Sound` it plays (the one the game handed to `assignProgrammerSoundFrom`, or the one the library created for the key, which stops resolving after the destroyed callback), and `subsoundIndex` the subsound inside it, `-1` for the whole sound. `sound` is null when no assignment matched. `clearProgrammerSound()` drops every assignment.

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

## Core channel callbacks

Channels from `Sound.play` and `PcmStream.play` support `Channel.setCallback` with `ChannelEvent` values (end of playback, sync points, virtual voice changes, occlusion), and `ChannelGroup.setCallback` delivers the occlusion event for 3D groups. They ride the same queue and the same per-frame drain.

## Listeners

FMOD positions sound relative to listeners. A 2D game has one listener at the camera or player and moves it every frame.

```haxe
StudioSystem.setListenerPosition2D(0, cameraX, cameraY);
```

`setListenerPosition2D(index, x, y, ?velocityX, ?velocityY)` sets position with unit forward and up vectors. `setListenerAttributes(index, attributes, ?attenuationPosition)` takes a full `Fmod3DAttributes` (position, velocity, forward, up) for 3D games, and the optional `attenuationPosition` is the point distance attenuation is measured from when it differs from the listener, a third-person camera that hears from the character. `getListenerAttributes(index)` returns both, as an `FmodListenerAttributes`. `setNumListeners` enables split-screen setups, and `setListenerWeight` blends between them. `FmodRuntime.setListenerPosition(index, x, y)` is the same 2D call reachable from the runtime layer.

Distance units are whatever your game uses. Authored min and max distances in FMOD Studio are in those same units, so a pixel-based game authors its falloff in pixels. `CoreSystem.set3DSettings(dopplerScale, distanceFactor, rolloffScale)` rescales globally.

Studio events attenuate by the curve authored on their spatializer. Core channels attenuate by their 3D mode, and `set3DCustomRolloff(points)` on a `Channel`, `ChannelGroup`, or `Sound` replaces that with a curve of `FmodVector` points, `x` the distance and `y` the volume (unsupported in HTML5). It returns `FMOD_ERR_UNSUPPORTED` there. With `distanceFilter` on in the settings, 3D core channels also pass through a lowpass that closes with distance, and `Channel.set3DDistanceFilter` overrides it per channel. Both are described in [Core API](core-api.md#channels), and polygon occlusion between listener and source is in [Geometry occlusion](core-api.md#geometry-occlusion).

## Positioned events

Any instance of a 3D event takes a position through `setPosition2D(x, y, ?velocityX, ?velocityY)` or `set3DAttributes`. Events authored without a spatializer ignore it. `EventDescription.is3D()` tells you which kind you have.

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

`IFmodPositionProvider` is a four-method interface: `fmodX`, `fmodY`, `fmodVelocityX`, `fmodVelocityY`. The flixel components adapt `FlxObject` and `FlxCamera` to it, and any engine can implement it directly. Instances that die (released, or stopped and destroyed by FMOD) are pruned from the attachment list automatically, and `FmodRuntime.attachedCount()` reports how many are live.

`FmodRuntime.playOneShotAttached(path, provider)` and `FmodManager.PlaySoundOneShotAttached` combine create, attach, start, and a release that fires when the event reports `STOPPED`. They suit self-ending events only. A looping event never stops on its own, so it would never release, and for those you keep the instance and use attach and detach yourself.

## Doppler and velocity

Attached instances and the flixel listener push velocity alongside position, so an event authored with doppler responds to relative motion. Very fast movers and camera cuts can produce audible pitch flutter. The `maxAttachedVelocity` setting caps the velocity magnitude FMOD sees, preserving direction and leaving the position untouched. `0`, the default, applies no cap.

```haxe
FmodManager.Initialize({maxAttachedVelocity: 600});
```

`EventDescription.isDopplerEnabled()` reports whether an event was authored with doppler at all.

## Global and event parameters

Parameters are FMOD Studio's way of letting game state drive the mix. Event-local parameters are set on the instance, global parameters on `StudioSystem`.

```haxe
instance.setParameter("RPM", 0.7);
instance.setParameterWithLabel("Surface", "Gravel");
StudioSystem.setParameter("TimeOfDay", 0.25);
```

`setParameter(name, value, ?ignoreSeekSpeed)` and `setParameterWithLabel(name, label, ?ignoreSeekSpeed)` exist on both, alongside `getParameter` and `getParameterFinal` (the value after seek speed and automation). `getParameterDescriptionByName`, `getParameterDescriptionByIndex`, `getParameterDescriptionByID`, and `getParameterLabel` expose the authored range, default, type, and flags for building settings UIs or validating values. The `...ByID` variants take the `FmodParameterId` from a description and skip the name lookup.

FMOD's own names work too: `setParameterByName`, `getParameterByName`, `getParameterByNameFinal`, `setParameterByNameWithLabel`, and `getParameterLabelByName` are the same calls. `setParametersByIDs(ids, values, ?ignoreSeekSpeed)` sets a batch of parameters in one call on either, `StudioSystem.getParameterDescriptionList()` returns every global parameter description, and `EventDescription.getParameterLabelByIndex(index, labelIndex)` reads a label without the name.

Parameter names are bare names, for example `"RPM"`. The generated `FmodParameters` constants hold full `parameter:/` paths for the global parameters, which the lookup functions accept as well.
