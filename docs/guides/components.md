# Engine components

`haxefmod.flixel`, `haxefmod.heaps`, and `haxefmod.kha` hold the same component set for their engine. Each package compiles only when its engine is present. Nothing else in the library depends on them. The set is:

- a one-call setup
- a bank loader
- an emitter that follows a game object
- a listener
- a zone-based parameter trigger
- an attached one-shot helper

=== "HaxeFlixel"

    The components are for HaxeFlixel 5.9.0 or newer. Each one is a `FlxBasic`. Add it to a state, and it updates and destroys with the state like any other flixel object.

=== "Heaps"

    Heaps has no component list to hook, so the components are plain objects and not scene nodes. Each one registers itself with the per-frame updater when created. Call its `dispose()` to unregister it. Keep a reference to any component you must end before the game does.

=== "Kha"

    Kha has no scene graph, so the components follow any object with `x` and `y` fields. Add `width` and `height` fields to have the midpoint tracked instead of the corner. Each component registers itself with the per-frame updater when created. `dispose()` unregisters it. Keep a reference to any component you must end before the game does.

## Setup

=== "HaxeFlixel"

    Call `FmodFlxSetup.init(?settings)` once, in your first state. It initializes FMOD with the given [settings](banks-and-settings.md#settings). It registers `FmodFlxUpdater` as a global plugin, so `FmodManager.Update()` runs every frame in every state. It forwards `FlxG.signals.focusGained` and `focusLost` to `FmodManager.SetWindowFocused` (see [FmodManager](fmod-manager.md#window-focus)).

    It also wires flixel's own audio controls to FMOD. The volume keys and the sound tray drive the FMOD master bus. `FlxG.sound.volume` and `FlxG.sound.muted` map to bus volume and mute. The tray's beep is silenced because FMOD owns the audio now.

    ```haxe
    import haxefmod.flixel.FmodFlxSetup;

    FmodFlxSetup.init({liveUpdate: true});
    ```

    On HTML5 the volume wiring waits for the asynchronous initialization through `FmodRuntime.onceReady`. A call to `init` before FMOD is ready is safe.

    A game that does not want the volume wiring calls `FmodManager.Initialize()` and `FmodFlxUpdater.init()` separately.

=== "Heaps"

    Call `FmodHeapsSetup.init(?settings)` once from your `hxd.App`'s `init()`. It initializes FMOD with the given [settings](banks-and-settings.md#settings). It installs `FmodHeapsUpdater`, so `FmodManager.Update()` runs every frame. It forwards the window's focus events to `FmodManager.SetWindowFocused` (see [FmodManager](fmod-manager.md#window-focus)).

    ```haxe
    import haxefmod.heaps.FmodHeapsSetup;

    FmodHeapsSetup.init({liveUpdate: true});
    ```

    Heaps has no global volume control of its own, so the FMOD master bus is the volume. Wire your settings menu to `FmodManager.SetBusVolumeMaster` and `SetBusMuteMaster`.

    On HashLink the updater rides the main thread's event loop. In the browser it is a `requestAnimationFrame` loop. A game that drives FMOD itself calls `FmodManager.Initialize()` and `FmodHeapsUpdater.init()` separately. It can also skip the updater and call `FmodManager.Update()` from its own loop.

=== "Kha"

    Call `FmodKhaSetup.init(?settings)` once from the `System.start` callback. It initializes FMOD with the given [settings](banks-and-settings.md#settings). It installs `FmodKhaUpdater` as a `Scheduler` frame task, so `FmodManager.Update()` runs every frame. It mutes the master output while the application is paused or in the background, through `System.notifyOnApplicationState` (see [FmodManager](fmod-manager.md#window-focus)).

    ```haxe
    import haxefmod.kha.FmodKhaSetup;

    FmodKhaSetup.init({liveUpdate: true});
    ```

    Kha has no global volume control of its own, so the FMOD master bus is the volume. Route your settings menu through `FmodManager.SetBusVolumeMaster` and `SetBusMuteMaster`.

    A game that prefers its own wiring calls `FmodManager.Initialize()` and `FmodKhaUpdater.init()` separately. It can also leave the updater out and call `FmodManager.Update()` from its own frame code.

## Bank loader

The bank loader loads a set of banks through the refcounted registry and reports when all of them are ready. File names resolve against the configured bank folder. The loader calls `onLoaded` exactly once when every bank is loaded. It calls `onError` exactly once if any bank settles in an error state. A missing file or a failed fetch on HTML5 causes that. The `loaded` property mirrors `onLoaded`. Loading is asynchronous by default, and `async = false` loads synchronously on native targets.

=== "HaxeFlixel"

    ```haxe
    import haxefmod.flixel.FmodFlxBankLoader;

    add(new FmodFlxBankLoader(["Vehicles.bank"], () -> spawnCars(), () -> trace("bank failed")));
    ```

    When the state destroys the loader, the loader releases its bank references. The banks unload unless something else still holds them.

=== "Heaps"

    ```haxe
    import haxefmod.heaps.FmodHeapsBankLoader;

    var loader = new FmodHeapsBankLoader(["Vehicles.bank"], () -> spawnCars(), () -> trace("bank failed"));
    ```

    `dispose()` releases the loader's bank references. The banks unload once nothing else holds them.

=== "Kha"

    ```haxe
    import haxefmod.kha.FmodKhaBankLoader;

    var loader = new FmodKhaBankLoader(["Vehicles.bank"], () -> spawnCars(), () -> trace("bank failed"));
    ```

    `dispose()` gives the loader's bank references back to the registry. Banks with no remaining holders unload.

## Emitter

The emitter keeps an event instance positioned at a moving game object for as long as both are alive.

=== "HaxeFlixel"

    The instance follows a `FlxObject`'s midpoint and velocity. When the state destroys the emitter, the emitter detaches and releases the instance.

    ```haxe
    import haxefmod.flixel.FmodFlxEmitter;

    var emitter = FmodFlxEmitter.play(FmodEvents.SFXEngine, car);
    add(emitter);
    emitter.instance.setParameter("RPM", 0.4);
    ```

    `FmodFlxEmitter.play(path, target)` creates and starts an instance. `new FmodFlxEmitter(instance, target)` wraps an instance you already created. The runtime update pushes the positions, so the emitter has no per-frame work of its own.

=== "Heaps"

    The instance follows the center of an `h2d.Object`'s bounds. Heaps objects carry no velocity, so the emitter derives one from the movement between frames. A jump larger than `teleportDistance` in one frame (default 500 units) counts as a cut. The emitter then pushes zero velocity for that frame and prevents a doppler spike.

    ```haxe
    import haxefmod.heaps.FmodHeapsEmitter;

    var emitter = FmodHeapsEmitter.play(FmodEvents.SFXEngine, car);
    emitter.instance.setParameter("RPM", 0.4);
    // when the object goes away
    emitter.dispose();
    ```

    `FmodHeapsEmitter.play(path, target)` creates and starts an instance. `new FmodHeapsEmitter(instance, target)` wraps an instance you created and started yourself. `dispose()` detaches and releases the instance. The instance plays out unless you stopped it first.

=== "Kha"

    The instance follows a body's midpoint. The emitter derives the velocity from the movement between frames. A one-frame jump larger than `teleportDistance` (default 500 units) counts as a cut. The emitter then pushes zero velocity for that frame and prevents a doppler spike.

    ```haxe
    import haxefmod.kha.FmodKhaEmitter;

    var emitter = FmodKhaEmitter.play(FmodEvents.SFXEngine, car);
    emitter.instance.setParameter("RPM", 0.4);
    // when the object goes away
    emitter.dispose();
    ```

    `FmodKhaEmitter.play(path, target)` creates and starts an instance. `new FmodKhaEmitter(instance, target)` wraps an instance you created and started yourself. `dispose()` detaches and releases the instance. The instance plays out unless you stopped it first.

### Distance culling

Every engine's emitter shares the same culling, backed by one runtime tracker. Culling is opt-in. With `stopEventsOutsideMaxDistance = true`, the emitter stops its event with a fadeout while the event is out of range. The range is the event's authored maximum distance from the listener. The emitter restarts the event when the listener comes back in range. This saves voices on far-away looping emitters. The emitter restarts only an instance it stopped itself, so an instance the game stopped stays stopped.

A restart begins from the event's start with the instance's parameters still applied. `listenerIndex` picks the listener the distance is measured against. `cullCheckInterval` sets how many frames pass between checks (default 6). `cullMaxDistance` overrides the authored distance when set to a positive value. One-shot events are never culled, because a stopped and restarted self-ending event would replay long after it had finished. With the default `cullMaxDistance` only 3D events are culled, and a 2D event is culled only when `cullMaxDistance` is set.

## Listener

The listener positions an FMOD listener every frame. It pushes velocity alongside position, so authored doppler responds to listener movement.

=== "HaxeFlixel"

    With a target, the listener follows the target's midpoint. That suits a player character. Without a target, it follows the center of `FlxG.camera`, for a game where the camera is the player's ear.

    ```haxe
    import haxefmod.flixel.FmodFlxListener;

    add(new FmodFlxListener(player));
    add(new FmodFlxListener()); // or: follow the camera
    ```

    A camera cut would register as a large velocity spike. `teleportDistance` guards against that. A jump larger than it counts as a cut and reports zero velocity for that frame. The default is one camera width. `resetMotion()` does the same explicitly for a cut you know is coming. `setTarget` retargets the listener or drops back to the camera.

=== "Heaps"

    With a target object, the listener follows the center of the object's bounds. With a scene, it follows the center of the scene's camera view.

    ```haxe
    import haxefmod.heaps.FmodHeapsListener;

    var listener = new FmodHeapsListener(player);
    // or: the camera is the player's ear
    var earsOnCamera = new FmodHeapsListener();
    earsOnCamera.setScene(s2d);
    ```

    A one-frame jump larger than `teleportDistance` counts as a cut. Its default of 0 means auto. Auto is one view width in scene-follow mode and 500 units when the listener follows an object. `resetMotion()` does the same explicitly for a camera cut you know is coming. `setTarget` retargets the listener at any time.

=== "Kha"

    With a body, the listener follows the midpoint. `setSampler` swaps in a pair of functions instead. The listener then follows whatever they return, such as the center of the game's camera view.

    ```haxe
    import haxefmod.kha.FmodKhaListener;

    var listener = new FmodKhaListener(player);
    // or: the camera is the player's ear
    var earsOnCamera = new FmodKhaListener();
    earsOnCamera.setSampler(() -> cameraX, () -> cameraY);
    ```

    A one-frame jump larger than `teleportDistance` (default 500 units) counts as a cut. Call `resetMotion()` before a cut your game performs itself. Call `setTarget` to move the listener to another body.

## Parameter trigger

The trigger drives an FMOD parameter from a rectangular zone. While the target is inside the rectangle the parameter reads `valueInside`, otherwise `valueOutside`. The trigger applies the value on the first frame and then only on edge crossings. Parameter changes you make in between are left alone. Pass an `EventInstance` as the last argument to drive a parameter on that instance. Omit it to drive a global parameter.

=== "HaxeFlixel"

    The zone is a `FlxRect`.

    ```haxe
    import haxefmod.flixel.FmodFlxParameterTrigger;
    import flixel.math.FlxRect;

    add(new FmodFlxParameterTrigger(player, FlxRect.get(0, 0, 640, 200), "Indoors", 1, 0));
    ```

=== "Heaps"

    The zone is an `h2d.col.Bounds` in scene coordinates. The trigger tests it against the center of the target's bounds.

    ```haxe
    import haxefmod.heaps.FmodHeapsParameterTrigger;

    // Muffle the music while the player is underwater
    var trigger = new FmodHeapsParameterTrigger(player, waterZone, "Underwater", 1, 0);
    ```

=== "Kha"

    The zone is given as x, y, width, and height in world coordinates. The trigger tests it against the body's midpoint.

    ```haxe
    import haxefmod.kha.FmodKhaParameterTrigger;

    // Muffle the music while the player is underwater
    var trigger = new FmodKhaParameterTrigger(player, 0, 200, 640, 100, "Underwater", 1, 0);
    ```

## Utilities

`PlaySoundOneShotAttached(path, target)` plays a self-ending event that follows a game object until it finishes. [Callbacks and 3D](callbacks-and-3d.md#positioned-events) has the runtime call behind it.

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

Everything the components do goes through public runtime calls: `FmodRuntime.attach` with an `IFmodPositionProvider`, `StudioSystem.setListenerPosition2D`, and `FmodRuntime.banks`. A game on an engine without a component package writes the same few lines against its own object types. The engine-free cores in `haxefmod.runtime` (`EmitterTracker`, `ListenerTracker`, `ZoneTrigger`, `BankLoadTracker`) carry the shared behavior.
