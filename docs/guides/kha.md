# Kha components

`haxefmod.kha` holds drop-in components for Kha games. Kha has no scene graph, so the components follow any object with `x` and `y` fields, plus `width` and `height` when you want the midpoint tracked instead of the corner. Each component registers itself with the per-frame updater when created, and `dispose()` unregisters it, so keep a reference to anything you need to end before the game does. The package compiles only inside a Kha build, and no other part of the library touches it.

## Setup

Call `FmodKhaSetup.init(?settings)` once from the `System.start` callback. It initializes FMOD with the given [settings](banks-and-settings.md#settings), installs `FmodKhaUpdater` as a `Scheduler` frame task so `FmodManager.Update()` runs every frame, and mutes the master output while the application is paused or in the background, through `System.notifyOnApplicationState` (see [FmodManager](fmod-manager.md#window-focus)).

```haxe
import haxefmod.kha.FmodKhaSetup;

FmodKhaSetup.init({liveUpdate: true});
```

There is no global volume control in Kha itself, so route your settings menu through the FMOD master bus with `FmodManager.SetBusVolumeMaster` and `SetBusMuteMaster`.

A game that prefers its own wiring can call `FmodManager.Initialize()` and `FmodKhaUpdater.init()` separately, or leave the updater out and call `FmodManager.Update()` from its own frame code.

## FmodKhaBankLoader

Loads a set of banks through the refcounted registry and reports when all of them are ready. File names resolve against the configured bank folder.

```haxe
import haxefmod.kha.FmodKhaBankLoader;

var loader = new FmodKhaBankLoader(["Vehicles.bank"], () -> spawnCars(), () -> trace("bank failed"));
```

One `onLoaded` call fires when the last bank finishes, and one `onError` call fires if any bank ends up in an error state, which covers a missing file and a failed fetch in the browser. The `loaded` property tracks the same condition. Pass `async = false` for a synchronous load on native targets. `dispose()` gives the loader's bank references back to the registry, and banks with no remaining holders unload.

## FmodKhaEmitter

Keeps an event instance positioned at a moving body. The instance follows the body's midpoint, with velocity derived from the movement between frames so authored doppler responds to it.

```haxe
import haxefmod.kha.FmodKhaEmitter;

var emitter = FmodKhaEmitter.play(FmodEvents.SFXEngine, car);
emitter.instance.setParameter("RPM", 0.4);
// when the object goes away
emitter.dispose();
```

`FmodKhaEmitter.play(path, target)` creates and starts an instance, and `new FmodKhaEmitter(instance, target)` wraps one you created and started yourself. `dispose()` detaches and releases the instance, which plays out unless you stopped it first. `teleportDistance` (default 500 units) decides when a one-frame jump reads as a cut, reporting zero velocity for that frame rather than a doppler spike.

The emitter also carries the culling controls (`stopEventsOutsideMaxDistance`, `listenerIndex`, `cullCheckInterval`, `cullMaxDistance`), backed by the same runtime tracker every engine's emitter uses. [Flixel components](flixel.md#fmodflxemitter) describes the full culling behavior.

## FmodKhaListener

Positions an FMOD listener every frame. With a body it follows the midpoint, which suits a player character. `setSampler` swaps in a pair of functions instead, so the listener can follow whatever they return, such as the center of the game's camera view.

```haxe
import haxefmod.kha.FmodKhaListener;

var listener = new FmodKhaListener(player);
// or: the camera is the player's ear
var earsOnCamera = new FmodKhaListener();
earsOnCamera.setSampler(() -> cameraX, () -> cameraY);
```

Velocity is derived from movement between frames, and a one-frame jump larger than `teleportDistance` (default 500 units) reads as a cut rather than motion. Call `resetMotion()` before a cut your game performs itself, and `setTarget` to move the listener to another body.

## FmodKhaParameterTrigger

Drives a parameter from a rectangular zone. While the body's midpoint is inside the rectangle the parameter reads `valueInside`, otherwise `valueOutside`, applied on the first frame and then only on edge crossings, so parameter changes you make in between are not fought over.

```haxe
import haxefmod.kha.FmodKhaParameterTrigger;

// Muffle the music while the player is underwater
var trigger = new FmodKhaParameterTrigger(player, 0, 200, 640, 100, "Underwater", 1, 0);
```

The zone is given as x, y, width, and height in world coordinates. Pass an `EventInstance` as the last argument to drive a parameter on that instance, or omit it to drive a global parameter.

## FmodKhaUtilities

`PlaySoundOneShotAttached(path, target)` starts a self-ending event on a moving body and cleans up after it, the pattern from [Callbacks and 3D](callbacks-and-3d.md#positioned-events).

```haxe
import haxefmod.kha.FmodKhaUtilities;

FmodKhaUtilities.PlaySoundOneShotAttached(FmodEvents.SFXCoin, coin);
```
