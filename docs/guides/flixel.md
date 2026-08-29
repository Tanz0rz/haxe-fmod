# Flixel components

`haxefmod.flixel` holds drop-in components for HaxeFlixel 5.9.0 or newer. Each one is a `FlxBasic` you add to a state, so it updates and destroys with the state like any other flixel object. The package only compiles when flixel is present, and nothing else in the library depends on it.

## Setup

Call `FmodFlxSetup.init(?settings)` once, in your first state. It initializes FMOD with the given [settings](banks-and-settings.md#settings), registers `FmodFlxUpdater` as a global plugin so `FmodManager.Update()` runs every frame in every state, forwards `FlxG.signals.focusGained` and `focusLost` to `FmodManager.SetWindowFocused` (see [FmodManager](fmod-manager.md#window-focus)), and wires flixel's own audio controls to FMOD. The volume keys and sound tray drive the FMOD master bus, `FlxG.sound.volume` and `FlxG.sound.muted` map to bus volume and mute, and the tray's beep is silenced because FMOD owns the audio now.

```haxe
import haxefmod.flixel.FmodFlxSetup;

FmodFlxSetup.init({liveUpdate: true});
```

On HTML5 the volume wiring waits for the asynchronous initialization through `FmodRuntime.onceReady`, so calling `init` before FMOD is ready is fine.

Games that do not want the volume wiring call `FmodManager.Initialize()` and `FmodFlxUpdater.init()` separately.

## FmodFlxBankLoader

Loads a set of banks through the refcounted registry and reports when all of them are ready. File names resolve against the configured bank folder.

```haxe
import haxefmod.flixel.FmodFlxBankLoader;

add(new FmodFlxBankLoader(["Vehicles.bank"], () -> spawnCars(), () -> trace("bank failed")));
```

`onLoaded` is called exactly once when every bank is loaded, and `onError` exactly once if any bank settles in an error state (a missing file, or a failed fetch on HTML5). The `loaded` property mirrors the first. Loading is asynchronous by default, and `async = false` loads synchronously on native targets. Destroying the loader releases its bank references, so banks unload when the state ends unless something else still holds them.

## FmodFlxEmitter

Keeps an event instance positioned at a moving `FlxObject`. The instance follows the object's midpoint and velocity for as long as both are alive, and destroying the emitter detaches and releases the instance.

```haxe
import haxefmod.flixel.FmodFlxEmitter;

var emitter = FmodFlxEmitter.play(FmodEvents.SFXEngine, car);
add(emitter);
emitter.instance.setParameter("RPM", 0.4);
```

`FmodFlxEmitter.play(path, target)` creates and starts an instance, and `new FmodFlxEmitter(instance, target)` wraps one you already created. Positions are pushed by the runtime update, so the emitter has no per-frame work of its own.

Distance culling is opt-in. With `stopEventsOutsideMaxDistance = true`, the emitter stops its event with a fadeout while it is beyond the event's authored maximum distance from the listener, and restarts it when the listener comes back in range. This saves voices on far-away looping emitters. Only an instance the emitter itself stopped is restarted, so an instance the game stopped stays stopped, and a restart begins from the event's start with the instance's parameters still applied. `listenerIndex` picks which listener the distance is measured against, `cullCheckInterval` sets how many frames pass between checks (default 6), and `cullMaxDistance` overrides the authored distance when set to a positive value. One-shot events are never culled, since stopping and restarting a self-ending event would replay it long after it would have finished. With the default `cullMaxDistance` only 3D events are culled. A 2D event is culled only when `cullMaxDistance` is set.

## FmodFlxListener

Positions an FMOD listener every frame. With a target it follows the target's midpoint, which suits a player character. Without one it follows the center of `FlxG.camera`, for games where the camera is the player's ear.

```haxe
import haxefmod.flixel.FmodFlxListener;

add(new FmodFlxListener(player));
add(new FmodFlxListener()); // or: follow the camera
```

Listener velocity is pushed along with position (the target's velocity, or the camera center's movement per second), so authored doppler responds to listener movement. Camera cuts would otherwise register as a huge velocity spike. `teleportDistance` guards against that: a jump larger than it is treated as a cut and reports zero velocity for that frame. The default is one camera width. `resetMotion()` does the same explicitly for a cut you know is coming, and `setTarget` retargets the listener or drops back to the camera.

## FmodFlxParameterTrigger

Sets a parameter when a target enters or leaves a rectangular zone.

```haxe
import haxefmod.flixel.FmodFlxParameterTrigger;
import flixel.math.FlxRect;

add(new FmodFlxParameterTrigger(player, FlxRect.get(0, 0, 640, 200), "Indoors", 1, 0));
```

The parameter is applied once on each transition. Pass an `EventInstance` as the last argument to drive a parameter on that instance, or omit it to drive a global parameter.

## FmodFlxUtilities

`TransitionToStateAndStopMusic(state)` stops the current song with its authored fadeout, waits for it to report stopped, and then switches state. `TransitionToState(state)` switches immediately, and `PlaySoundOneShotAttached(path, flxObject)` plays a self-ending event that follows a flixel object, see [Callbacks and 3D](callbacks-and-3d.md#positioned-events).

```haxe
import haxefmod.flixel.FmodFlxUtilities;

FmodFlxUtilities.TransitionToStateAndStopMusic(MenuState.new);
FmodFlxUtilities.PlaySoundOneShotAttached(FmodEvents.SFXCoin, coin);
```

## Custom engines

Everything the flixel components do goes through public runtime calls: `FmodRuntime.attach` with an `IFmodPositionProvider`, `StudioSystem.setListenerPosition2D`, and `FmodRuntime.banks`. A game on another engine writes the same few lines against its own object types.
