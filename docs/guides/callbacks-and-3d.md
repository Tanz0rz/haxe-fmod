# Callbacks and 3D

## Typed callbacks

FMOD Studio delivers event callbacks (lifecycle changes, timeline beats, markers) on its own threads. The binding queues them natively and `FmodManager.Update()` or `FmodRuntime.update()` drains the queue on the game thread, decoding each one into an `EventCallbackData` value. Handlers therefore run on the game thread, once per frame, and never touch FMOD's threads.

```haxe
import haxefmod.studio.Callbacks;

var instance = StudioSystem.getEvent("event:/Music/MainLevel").createInstance();
instance.setCallback(data -> switch (data) {
    case TimelineBeat(bar, beat, positionMs, tempo, timeSigUpper, timeSigLower):
        pulseUI(bar, beat);
    case TimelineMarker(name, positionMs):
        trace('$name at $positionMs ms');
    case Stopped:
        trace("stopped");
    default:
});
instance.start();
```

The constructors are `Created`, `Destroyed`, `Starting`, `Started`, `Restarted`, `Stopped`, `StartFailed`, `TimelineMarker(name, positionMs)`, `TimelineBeat(bar, beat, positionMs, tempo, timeSigUpper, timeSigLower)`, `NestedTimelineBeat` with the same payload, `SoundPlayed`, `SoundStopped`, `RealToVirtual`, `VirtualToReal`, and `Other(type)` for callback types without a dedicated constructor. Haxe lets you elide trailing arguments in a pattern, so `case TimelineBeat(bar, beat, _, _)` compiles.

`setCallback(handler, ?mask)` takes an optional mask of `EventCallbackType` bits. Without a mask every playback event is delivered (`EventCallbackType.PLAYBACK_ALL`). A mask limits delivery to the events you care about, which matters for busy events like beat tracking on a fast tempo.

```haxe
import haxefmod.studio.Callbacks;

instance.setCallback(handler, EventCallbackType.TIMELINE_BEAT | EventCallbackType.STOPPED);
```

Each instance has one handler. Registering again replaces it. `release()` removes the handler on every target, so cleanup code that belongs with the instance's end goes there rather than in a `Destroyed` case. HTML5 never delivers `Destroyed` at all, see [Platforms](../platforms.md#html5).

`FmodSound.onEvent` and `FmodManager.OnSongEvent` are the same mechanism on the facade's handles. `FmodManager.ClearAllCallbacks()` removes every handler at once.

### Programmer sounds

`EventInstance.assignProgrammerSound(key)` names the audio a programmer instrument should play. Assign it before `start()`, and the native side resolves it on FMOD's thread when the instrument triggers. The key is either an audio table entry or a `CoreSound` you loaded from a file or PCM. Keys must be under 512 UTF-8 bytes. On HTML5 the call returns `FMOD_ERR_UNSUPPORTED` because of a defect in FMOD's JavaScript runtime, documented in [Limitations](../limitations.md#html5).

## Core channel callbacks

Channels from `CoreSound.play` and `PcmStream.play` support `Channel.setCallback` with `ChannelEvent` values (end of playback, sync points). They ride the same queue and the same per-frame drain.

## Listeners

FMOD positions sound relative to listeners. A 2D game has one listener at the camera or player and moves it every frame.

```haxe
StudioSystem.setListenerPosition2D(0, cameraX, cameraY);
```

`setListenerPosition2D(index, x, y, ?velocityX, ?velocityY)` sets position with unit forward and up vectors. `setListenerAttributes(index, attributes)` takes a full `Fmod3DAttributes` (position, velocity, forward, up) for 3D games. `setNumListeners` enables split-screen setups, and `setListenerWeight` blends between them. `FmodRuntime.setListenerPosition(index, x, y)` is the same 2D call reachable from the runtime layer.

Distance units are whatever your game uses. Authored min and max distances in FMOD Studio are in those same units, so a pixel-based game authors its falloff in pixels. `CoreSystem.set3DSettings(dopplerScale, distanceFactor, rolloffScale)` rescales globally.

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

Parameter names are bare names, for example `"RPM"`. The generated `FmodParameters` constants hold full `parameter:/` paths for the global parameters, which the lookup functions accept as well.
