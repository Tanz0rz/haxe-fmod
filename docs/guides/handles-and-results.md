# Handles and results

Every FMOD object in `haxefmod.studio` and `haxefmod.core` is a typed handle: `EventInstance`, `EventDescription`, `Bank`, `Bus`, `Vca`, `CommandReplay`, `Sound`, `Channel`, `ChannelGroup`, `Dsp`, `SoundGroup`, and so on. All of them share these conventions.

## Handles are integers

A handle is an `abstract` over `Int`. The integer indexes a table on the native side that owns the real FMOD pointer. Haxe code never holds a raw pointer, and no Haxe allocation happens on an FMOD thread. Handles compare with `==`, fit in any collection, and cost nothing to copy.

`0` is the null handle. Every handle type has a `NULL` constant and an `isNull()` method.

```haxe
var description = StudioSystem.getEvent("event:/SFX/Missing");
if (description.isNull()) {
    trace("no such event");
}
```

The studio handles (`EventInstance`, `EventDescription`, `Bank`, `Bus`, `Vca`, `CommandReplay`) and `FmodSound` also have `isValid()`. It asks the native side whether the handle still points at a live FMOD object. A released handle is stale, and so is a handle whose object FMOD destroyed on its own. `isNull()` is a local check and `isValid()` is a native call. The core handles have `isNull()` only. A stale core handle returns `FMOD_ERR_INVALID_HANDLE` from its next call.

## Stale handles are safe

Every call on a null or stale handle is a no-op. Getters return a default (`0`, `false`, `""`, `NULL`, or `null` for structs). Setters return `FMOD_ERR_INVALID_HANDLE`. There is no exception path. A sound that failed to play, or a handle kept past its release, never takes the game down.

```haxe
var sound = FmodManager.PlaySound("event:/SFX/Typo");
sound.setVolume(0.5); // returns FMOD_ERR_INVALID_HANDLE, does nothing
sound.release();      // also safe
```

## Lifetimes

FMOD objects have two kinds of lifetime.

**Looked-up handles** (`EventDescription`, `Bus`, `Vca`, `Bank`) refer to objects that live as long as their bank is loaded. `StudioSystem.getBus` caches one handle per path, so repeated bus lookups return the same handle. `getEvent`, `getVCA`, and `getBank` look the object up on each call. The game never releases these handles.

**Created handles** (`EventInstance`, `Sound`, `Dsp`, custom `ChannelGroup`, `SoundGroup`, `CommandReplay`) are yours until you release them. `release()` on an event instance lets FMOD destroy it once it stops. The handle becomes invalid immediately and the library removes any registered callback. The instance plays out unless you stopped it first. Fire-and-forget playback is start followed by release.

```haxe
var description = StudioSystem.getEvent("event:/SFX/Explosion");
var instance = description.createInstance();
instance.start();
instance.release();
```

`Channel` handles end on their own when playback stops. Call `stop()` when you are done with one either way. That always frees the handle slot.

A handle that is never released holds a slot in the native table for the life of the process. `StudioSystem.liveHandleCount()` reports the number of live handles. Tests use it to catch leaks.

## Userdata

Every handle has `setUserData(value)` and `getUserData()`, and so does `StudioSystem`. FMOD's own userdata slot holds a raw pointer, which cannot carry a Haxe value across the binding. The value lives on the Haxe side, keyed by the handle. The library drops the value in three cases:

- when the handle is released through the abstract (`release`, `stop`, `unload`)
- when FMOD destroys an event instance on its own and delivers `Destroyed`
- for every handle at once on `unloadAll`

A recycled native slot gets a new generation and therefore a new handle int. A value left on a dead handle can never be read through the handle that later reuses its slot.

```haxe
var instance = StudioSystem.getEvent("event:/SFX/Engine").createInstance();
instance.setUserData({owner: "car 3"});
var tag = instance.getUserData();
if (tag != null) trace('instance belongs to ${tag.owner}');
instance.release();
trace(instance.getUserData() == null); // true
```

## Results

Setters and commands return `haxefmod.studio.FmodResult`. It is an enum abstract of FMOD's `FMOD_RESULT` codes, pinned to the 2.03.12 header values. `FMOD_OK` is `0`. `isOk()` and `toString()` cover the usual checks.

```haxe
var result = StudioSystem.getBus("bus:/Music").setVolume(0.5);
if (!result.isOk()) {
    trace('volume failed: $result');
}
```

Getters return the value directly. When a getter fails, it returns its default. The failing code is available from `StudioSystem.lastResult()`, which holds the result of the most recent studio binding call. Factory calls follow the same pattern. `createInstance`, `loadBankFile`, `Sound.create`, and their relatives return `NULL` on failure and leave the reason in `lastResult()`.

```haxe
var sound = haxefmod.core.Sound.create("assets/voice/line01.ogg");
if (sound.isNull()) {
    trace('load failed: ${StudioSystem.lastResult()}');
}
```

Numeric arguments pass through to FMOD for validation. An out-of-range index or count comes back as the same error code native FMOD reports.

## Enumerations and struct returns

List getters (`getBankList`, `getEventList`, `getInstanceList`, and the other enumerations) return a Haxe array of handles. The library caps a result at 1024 entries. It truncates a larger result and logs a warning with the real total.

Struct-shaped results (`FmodParameterDescription`, `Fmod3DAttributes`, `FmodCpuUsage`, and the rest of `haxefmod.studio.Types`) are typedefs. A getter that returns one returns `null` on failure.

## Enum abstracts

FMOD's enumerations and flag sets are enum abstracts over `Int` in `haxefmod.studio.Types` and `haxefmod.studio.Callbacks`: `FmodStopMode`, `FmodPlaybackState`, `FmodLoadingState`, `EventCallbackType`, `FmodParameterFlags`, and so on. They accept and produce plain ints. Flags combine with `|` and states compare with `==`. Haxe's short constructor syntax applies wherever the type is known.

```haxe
import haxefmod.studio.Types;

var instance = StudioSystem.getEvent("event:/Music/MainLevel").createInstance();
instance.start();
instance.stop(ALLOWFADEOUT);
if (instance.getPlaybackState() == FmodPlaybackState.STOPPING) {
    trace("fading");
}
instance.release();
```
