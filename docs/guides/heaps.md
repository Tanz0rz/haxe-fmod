# Heaps components

`haxefmod.heaps` holds drop-in components for Heaps games. They are plain objects rather than scene nodes, since Heaps has no component list to hook. Each one registers itself with the per-frame updater when created and unregisters when you call its `dispose()`, so keep a reference for anything you need to end before the game does. Without heaps on the classpath the package is simply absent, and no other part of the library uses it.

## Setup

Call `FmodHeapsSetup.init(?settings)` once from your `hxd.App`'s `init()`. It initializes FMOD with the given [settings](banks-and-settings.md#settings), installs `FmodHeapsUpdater` so `FmodManager.Update()` runs every frame, and forwards the window's focus events to `FmodManager.SetWindowFocused` (see [FmodManager](fmod-manager.md#window-focus)).

```haxe
import haxefmod.heaps.FmodHeapsSetup;

FmodHeapsSetup.init({liveUpdate: true});
```

Heaps has no global volume control of its own, so the FMOD master bus is the volume. Wire your settings menu to `FmodManager.SetBusVolumeMaster` and `SetBusMuteMaster`.

On HashLink the updater rides the main thread's event loop, and in the browser it is a `requestAnimationFrame` loop. Games that want to drive FMOD themselves call `FmodManager.Initialize()` and `FmodHeapsUpdater.init()` separately, or skip the updater and call `FmodManager.Update()` from their own loop.

## FmodHeapsBankLoader

Loads a set of banks through the refcounted registry and reports when all of them are ready. File names resolve against the configured bank folder.

```haxe
import haxefmod.heaps.FmodHeapsBankLoader;

var loader = new FmodHeapsBankLoader(["Vehicles.bank"], () -> spawnCars(), () -> trace("bank failed"));
```

`onLoaded` runs exactly once when every bank is loaded, and `onError` exactly once if any bank settles in an error state (a missing file, or a failed fetch in the browser). The `loaded` property mirrors the first. Loading is asynchronous by default, and `async = false` loads synchronously on native targets. `dispose()` releases the loader's bank references, so the banks unload once nothing else holds them.

## FmodHeapsEmitter

Keeps an event instance positioned at a moving `h2d.Object`. The instance follows the center of the object's bounds. Heaps objects carry no velocity, so the emitter derives one from the movement between frames, and authored doppler responds to it.

```haxe
import haxefmod.heaps.FmodHeapsEmitter;

var emitter = FmodHeapsEmitter.play(FmodEvents.SFXEngine, car);
emitter.instance.setParameter("RPM", 0.4);
// when the object goes away
emitter.dispose();
```

`FmodHeapsEmitter.play(path, target)` creates and starts an instance, and `new FmodHeapsEmitter(instance, target)` wraps one you created and started yourself. `dispose()` detaches and releases the instance, which plays out unless you stopped it first. A jump larger than `teleportDistance` in one frame (default 500 units) counts as a cut and pushes zero velocity instead of a doppler spike.

Distance culling works the same way it does on the flixel emitter: `stopEventsOutsideMaxDistance` opts in, `listenerIndex` picks the listener the distance is measured against, `cullCheckInterval` paces the checks, and `cullMaxDistance` overrides the authored maximum distance. See [Flixel components](flixel.md#fmodflxemitter) for the full culling behavior, which is shared through the same runtime tracker.

## FmodHeapsListener

Positions an FMOD listener every frame. With a target object it follows the center of the object's bounds, which suits a player character. With a scene it follows the center of the scene's camera view, for games where the camera is the player's ear.

```haxe
import haxefmod.heaps.FmodHeapsListener;

var listener = new FmodHeapsListener(player);
// or: the camera is the player's ear
var earsOnCamera = new FmodHeapsListener();
earsOnCamera.setScene(s2d);
```

Velocity is derived from movement between frames, so authored doppler responds to listener motion. `teleportDistance` treats a larger one-frame jump as a cut. Its default of 0 means auto: one view width in scene-follow mode, 500 units when following an object. `resetMotion()` does the same explicitly for a camera cut you know is coming, and `setTarget` retargets the listener at any time.

## FmodHeapsParameterTrigger

Drives a parameter from a rectangular zone. While the center of the target's bounds is inside the rectangle the parameter reads `valueInside`, otherwise `valueOutside`, applied on the first frame and then only on edge crossings, so parameter changes you make in between are not fought over.

```haxe
import haxefmod.heaps.FmodHeapsParameterTrigger;

// Muffle the music while the player is underwater
var trigger = new FmodHeapsParameterTrigger(player, waterZone, "Underwater", 1, 0);
```

The zone is an `h2d.col.Bounds` in scene coordinates. Pass an `EventInstance` as the last argument to drive a parameter on that instance, or omit it to drive a global parameter.

## FmodHeapsUtilities

`PlaySoundOneShotAttached(path, target)` plays a self-ending event that follows an `h2d.Object` until it finishes, see [Callbacks and 3D](callbacks-and-3d.md#positioned-events).

```haxe
import haxefmod.heaps.FmodHeapsUtilities;

FmodHeapsUtilities.PlaySoundOneShotAttached(FmodEvents.SFXCoin, coin);
```
