# Engine components

`haxefmod.flixel`, `haxefmod.heaps`, and `haxefmod.kha` each hold the same drop-in component set for their engine: a one-call setup, a bank loader, an emitter that follows a game object, a listener, a zone-based parameter trigger, and an attached one-shot helper. Each package only compiles when its engine is present, and nothing else in the library depends on any of them.

=== "HaxeFlixel"

    The components are for HaxeFlixel 5.9.0 or newer. Each one is a `FlxBasic` you add to a state, so it updates and destroys with the state like any other flixel object.

=== "Heaps"

    The components are plain objects rather than scene nodes, since Heaps has no component list to hook. Each one registers itself with the per-frame updater when created and unregisters when you call its `dispose()`, so keep a reference for anything you need to end before the game does.

=== "Kha"

    Kha has no scene graph, so the components follow any object with `x` and `y` fields, plus `width` and `height` when you want the midpoint tracked instead of the corner. Each component registers itself with the per-frame updater when created, and `dispose()` unregisters it, so keep a reference to anything you need to end before the game does.

## Setup

=== "HaxeFlixel"

    Call `FmodFlxSetup.init(?settings)` once, in your first state. It initializes FMOD with the given [settings](banks-and-settings.md#settings), registers `FmodFlxUpdater` as a global plugin so `FmodManager.Update()` runs every frame in every state, forwards `FlxG.signals.focusGained` and `focusLost` to `FmodManager.SetWindowFocused` (see [FmodManager](fmod-manager.md#window-focus)), and wires flixel's own audio controls to FMOD. The volume keys and sound tray drive the FMOD master bus, `FlxG.sound.volume` and `FlxG.sound.muted` map to bus volume and mute, and the tray's beep is silenced because FMOD owns the audio now.

    ```haxe
    import haxefmod.flixel.FmodFlxSetup;

    FmodFlxSetup.init({liveUpdate: true});
    ```

    On HTML5 the volume wiring waits for the asynchronous initialization through `FmodRuntime.onceReady`, so calling `init` before FMOD is ready is fine.

    Games that do not want the volume wiring call `FmodManager.Initialize()` and `FmodFlxUpdater.init()` separately.

=== "Heaps"

    Call `FmodHeapsSetup.init(?settings)` once from your `hxd.App`'s `init()`. It initializes FMOD with the given [settings](banks-and-settings.md#settings), installs `FmodHeapsUpdater` so `FmodManager.Update()` runs every frame, and forwards the window's focus events to `FmodManager.SetWindowFocused` (see [FmodManager](fmod-manager.md#window-focus)).

    ```haxe
    import haxefmod.heaps.FmodHeapsSetup;

    FmodHeapsSetup.init({liveUpdate: true});
    ```

    Heaps has no global volume control of its own, so the FMOD master bus is the volume. Wire your settings menu to `FmodManager.SetBusVolumeMaster` and `SetBusMuteMaster`.

    On HashLink the updater rides the main thread's event loop, and in the browser it is a `requestAnimationFrame` loop. Games that want to drive FMOD themselves call `FmodManager.Initialize()` and `FmodHeapsUpdater.init()` separately, or skip the updater and call `FmodManager.Update()` from their own loop.

=== "Kha"

    Call `FmodKhaSetup.init(?settings)` once from the `System.start` callback. It initializes FMOD with the given [settings](banks-and-settings.md#settings), installs `FmodKhaUpdater` as a `Scheduler` frame task so `FmodManager.Update()` runs every frame, and mutes the master output while the application is paused or in the background, through `System.notifyOnApplicationState` (see [FmodManager](fmod-manager.md#window-focus)).

    ```haxe
    import haxefmod.kha.FmodKhaSetup;

    FmodKhaSetup.init({liveUpdate: true});
    ```

    There is no global volume control in Kha itself, so route your settings menu through the FMOD master bus with `FmodManager.SetBusVolumeMaster` and `SetBusMuteMaster`.

    A game that prefers its own wiring can call `FmodManager.Initialize()` and `FmodKhaUpdater.init()` separately, or leave the updater out and call `FmodManager.Update()` from its own frame code.

## Bank loader

Loads a set of banks through the refcounted registry and reports when all of them are ready. File names resolve against the configured bank folder. `onLoaded` is called exactly once when every bank is loaded, and `onError` exactly once if any bank settles in an error state (a missing file, or a failed fetch on HTML5). The `loaded` property mirrors the first. Loading is asynchronous by default, and `async = false` loads synchronously on native targets.

=== "HaxeFlixel"

    ```haxe
    import haxefmod.flixel.FmodFlxBankLoader;

    add(new FmodFlxBankLoader(["Vehicles.bank"], () -> spawnCars(), () -> trace("bank failed")));
    ```

    Destroying the loader releases its bank references, so banks unload when the state ends unless something else still holds them.

=== "Heaps"

    ```haxe
    import haxefmod.heaps.FmodHeapsBankLoader;

    var loader = new FmodHeapsBankLoader(["Vehicles.bank"], () -> spawnCars(), () -> trace("bank failed"));
    ```

    `dispose()` releases the loader's bank references, so the banks unload once nothing else holds them.

=== "Kha"

    ```haxe
    import haxefmod.kha.FmodKhaBankLoader;

    var loader = new FmodKhaBankLoader(["Vehicles.bank"], () -> spawnCars(), () -> trace("bank failed"));
    ```

    `dispose()` gives the loader's bank references back to the registry, and banks with no remaining holders unload.

## Emitter

Keeps an event instance positioned at a moving game object for as long as both are alive.

=== "HaxeFlixel"

    The instance follows a `FlxObject`'s midpoint and velocity, and destroying the emitter detaches and releases the instance.

    ```haxe
    import haxefmod.flixel.FmodFlxEmitter;

    var emitter = FmodFlxEmitter.play(FmodEvents.SFXEngine, car);
    add(emitter);
    emitter.instance.setParameter("RPM", 0.4);
    ```

    `FmodFlxEmitter.play(path, target)` creates and starts an instance, and `new FmodFlxEmitter(instance, target)` wraps one you already created. Positions are pushed by the runtime update, so the emitter has no per-frame work of its own.

=== "Heaps"

    The instance follows the center of an `h2d.Object`'s bounds. Heaps objects carry no velocity, so the emitter derives one from the movement between frames, and a jump larger than `teleportDistance` in one frame (default 500 units) counts as a cut and pushes zero velocity instead of a doppler spike.

    ```haxe
    import haxefmod.heaps.FmodHeapsEmitter;

    var emitter = FmodHeapsEmitter.play(FmodEvents.SFXEngine, car);
    emitter.instance.setParameter("RPM", 0.4);
    // when the object goes away
    emitter.dispose();
    ```

    `FmodHeapsEmitter.play(path, target)` creates and starts an instance, and `new FmodHeapsEmitter(instance, target)` wraps one you created and started yourself. `dispose()` detaches and releases the instance, which plays out unless you stopped it first.

=== "Kha"

    The instance follows a body's midpoint, with velocity derived from the movement between frames. `teleportDistance` (default 500 units) decides when a one-frame jump reads as a cut, reporting zero velocity for that frame rather than a doppler spike.

    ```haxe
    import haxefmod.kha.FmodKhaEmitter;

    var emitter = FmodKhaEmitter.play(FmodEvents.SFXEngine, car);
    emitter.instance.setParameter("RPM", 0.4);
    // when the object goes away
    emitter.dispose();
    ```

    `FmodKhaEmitter.play(path, target)` creates and starts an instance, and `new FmodKhaEmitter(instance, target)` wraps one you created and started yourself. `dispose()` detaches and releases the instance, which plays out unless you stopped it first.

### Distance culling

Culling is shared behavior on every engine's emitter, backed by one runtime tracker. It is opt-in. With `stopEventsOutsideMaxDistance = true`, the emitter stops its event with a fadeout while it is beyond the event's authored maximum distance from the listener, and restarts it when the listener comes back in range. This saves voices on far-away looping emitters. Only an instance the emitter itself stopped is restarted, so an instance the game stopped stays stopped, and a restart begins from the event's start with the instance's parameters still applied. `listenerIndex` picks which listener the distance is measured against, `cullCheckInterval` sets how many frames pass between checks (default 6), and `cullMaxDistance` overrides the authored distance when set to a positive value. One-shot events are never culled, since stopping and restarting a self-ending event would replay it long after it would have finished. With the default `cullMaxDistance` only 3D events are culled. A 2D event is culled only when `cullMaxDistance` is set.

## Listener

Positions an FMOD listener every frame, with velocity pushed alongside position so authored doppler responds to listener movement.

=== "HaxeFlixel"

    With a target it follows the target's midpoint, which suits a player character. Without one it follows the center of `FlxG.camera`, for games where the camera is the player's ear.

    ```haxe
    import haxefmod.flixel.FmodFlxListener;

    add(new FmodFlxListener(player));
    add(new FmodFlxListener()); // or: follow the camera
    ```

    Camera cuts would otherwise register as a huge velocity spike. `teleportDistance` guards against that: a jump larger than it is treated as a cut and reports zero velocity for that frame. The default is one camera width. `resetMotion()` does the same explicitly for a cut you know is coming, and `setTarget` retargets the listener or drops back to the camera.

=== "Heaps"

    With a target object it follows the center of the object's bounds. With a scene it follows the center of the scene's camera view.

    ```haxe
    import haxefmod.heaps.FmodHeapsListener;

    var listener = new FmodHeapsListener(player);
    // or: the camera is the player's ear
    var earsOnCamera = new FmodHeapsListener();
    earsOnCamera.setScene(s2d);
    ```

    `teleportDistance` treats a larger one-frame jump as a cut. Its default of 0 means auto: one view width in scene-follow mode, 500 units when following an object. `resetMotion()` does the same explicitly for a camera cut you know is coming, and `setTarget` retargets the listener at any time.

=== "Kha"

    With a body it follows the midpoint. `setSampler` swaps in a pair of functions instead, so the listener can follow whatever they return, such as the center of the game's camera view.

    ```haxe
    import haxefmod.kha.FmodKhaListener;

    var listener = new FmodKhaListener(player);
    // or: the camera is the player's ear
    var earsOnCamera = new FmodKhaListener();
    earsOnCamera.setSampler(() -> cameraX, () -> cameraY);
    ```

    A one-frame jump larger than `teleportDistance` (default 500 units) reads as a cut rather than motion. Call `resetMotion()` before a cut your game performs itself, and `setTarget` to move the listener to another body.

## Parameter trigger

Drives an FMOD parameter from a rectangular zone. While the target is inside the rectangle the parameter reads `valueInside`, otherwise `valueOutside`, applied on the first frame and then only on edge crossings, so parameter changes you make in between are not fought over. Pass an `EventInstance` as the last argument to drive a parameter on that instance, or omit it to drive a global parameter.

=== "HaxeFlixel"

    The zone is a `FlxRect`.

    ```haxe
    import haxefmod.flixel.FmodFlxParameterTrigger;
    import flixel.math.FlxRect;

    add(new FmodFlxParameterTrigger(player, FlxRect.get(0, 0, 640, 200), "Indoors", 1, 0));
    ```

=== "Heaps"

    The zone is an `h2d.col.Bounds` in scene coordinates, tested against the center of the target's bounds.

    ```haxe
    import haxefmod.heaps.FmodHeapsParameterTrigger;

    // Muffle the music while the player is underwater
    var trigger = new FmodHeapsParameterTrigger(player, waterZone, "Underwater", 1, 0);
    ```

=== "Kha"

    The zone is given as x, y, width, and height in world coordinates, tested against the body's midpoint.

    ```haxe
    import haxefmod.kha.FmodKhaParameterTrigger;

    // Muffle the music while the player is underwater
    var trigger = new FmodKhaParameterTrigger(player, 0, 200, 640, 100, "Underwater", 1, 0);
    ```

## Utilities

`PlaySoundOneShotAttached(path, target)` plays a self-ending event that follows a game object until it finishes, see [Callbacks and 3D](callbacks-and-3d.md#positioned-events).

=== "HaxeFlixel"

    ```haxe
    import haxefmod.flixel.FmodFlxUtilities;

    FmodFlxUtilities.TransitionToStateAndStopMusic(MenuState.new);
    FmodFlxUtilities.PlaySoundOneShotAttached(FmodEvents.SFXCoin, coin);
    ```

    `TransitionToStateAndStopMusic(state)` stops the current song with its authored fadeout, waits for it to report stopped, and then switches state. `TransitionToState(state)` switches immediately.

=== "Heaps"

    ```haxe
    import haxefmod.heaps.FmodHeapsUtilities;

    FmodHeapsUtilities.PlaySoundOneShotAttached(FmodEvents.SFXCoin, coin);
    ```

=== "Kha"

    ```haxe
    import haxefmod.kha.FmodKhaUtilities;

    FmodKhaUtilities.PlaySoundOneShotAttached(FmodEvents.SFXCoin, coin);
    ```

## Rolling your own

Everything the components do goes through public runtime calls: `FmodRuntime.attach` with an `IFmodPositionProvider`, `StudioSystem.setListenerPosition2D`, and `FmodRuntime.banks`. A game on an engine without a component package writes the same few lines against its own object types, and the engine-free cores in `haxefmod.runtime` (`EmitterTracker`, `ListenerTracker`, `ZoneTrigger`, `BankLoadTracker`) carry the shared behavior.
