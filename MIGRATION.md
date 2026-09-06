# Migrating from haxefmod 2.0 to 3.0

3.0 brings the library to parity with FMOD's own API. The C# integration is the reference for shape. Most of the release is additive and CHANGELOG.md lists it. The changes below need an edit in a 2.0 game.

## Event callbacks deliver FMOD's structs

Each callback delivers the FMOD struct of its type as one constructor argument. The loose values are gone:

```text
// 2.0
case TimelineBeat(bar, beat, positionMs, tempo, timeSigUpper, timeSigLower):
case TimelineMarker(name, positionMs):
case NestedTimelineBeat(bar, beat, positionMs, tempo, upper, lower):

// 3.0
case TimelineBeat(beat):           // FmodTimelineBeatProperties: bar, beat, position, tempo, timeSignatureUpper, timeSignatureLower
case TimelineMarker(marker):       // FmodTimelineMarkerProperties: name, position
case NestedTimelineBeat(nested):   // FmodTimelineNestedBeatProperties: eventId, properties
```

`PluginCreated(properties)` and `PluginDestroyed(properties)` carry `FmodPluginInstanceProperties` with `name` and `dsp`. `ProgrammerSoundCreated(properties)` and `ProgrammerSoundDestroyed(properties)` carry `FmodProgrammerSoundProperties` with `name`, `sound`, and `subsoundIndex`. These four replace the `Other(type)` fallback for their types. `ChannelEvent` gained `VirtualVoice(isVirtual)` and `Occlusion(direct, reverb)`. An exhaustive `switch` on it must have those cases or a `default`.

## The default callback mask is every type

`setCallback(handler)` without a mask now delivers every callback type. FMOD and its C# integration use the same default. `EventCallbackType.PLAYBACK_ALL` is gone. Pass the types a handler switches on as the mask. The mask also keeps a busy event from queuing more callbacks than the handler uses. Beat tracking at a fast tempo is one example:

```haxe
import haxefmod.studio.Callbacks;

instance.setCallback(handler, EventCallbackType.STARTED | EventCallbackType.TIMELINE_BEAT);
```

## Defaults that now match FMOD

- `Channel.setDelay` and `ChannelGroup.setDelay` default `stopChannels` to `true`. Pass `false` for the earlier pause-at-end behavior.
- `StudioSystem.getMemoryStats` defaults `blocking` to `true`. Pass `false` for the earlier non-flushing read.
- The programmer sound callback creates its sound with `NONBLOCKING`, so the file decodes off the Studio thread.

## Calls whose shape changed

- `Sound.addSyncPoint` returns the new `FmodSyncPoint`. On failure it returns `FmodSyncPoint.NULL` with the result in `StudioSystem.lastResult()`. `getSyncPoint(index)`, `getSyncPointInfo(point)`, and `deleteSyncPoint(point)` take the handle. `getSyncPointName` and `getSyncPointOffset` are deprecated aliases.
- `setLoopPoints` and `getLoopPoints` on `Sound` and `Channel` take a time unit per point, `loopStartType` and `loopEndType`. The result fields are `loopStart` and `loopEnd`.
- `CommandReplay.seekToTime` and `getCommandAtTime` take seconds as a `Float`. The millisecond forms remain as deprecated `seekToTimeMs` and `getCommandAtTimeMs`.
- `EventDescription.getUserProperty` takes the property name. The index form is `getUserPropertyByIndex(index)`.
- `Dsp.getMetering` and `getInputMetering` return `FmodDspMeteringInfo` with `numSamples`, `peakLevel`, `rmsLevel`, and `numChannels`. The `{peak, rms}` form is gone.
- `Dsp.getParameterInfo` returns `FmodDspParameterDesc`, laid out like `FMOD_DSP_PARAMETER_DESC`. Only the member that matches `type` is set, one of `floatDesc`, `intDesc`, `boolDesc`, or `dataDesc`.
- `Sound.getFormat` returns `type` and `format` next to `channels` and `bits`.
- GUIDs are `FmodGuid`, an abstract over the braced text form. It converts to and from `String`, so string call sites keep compiling.
- `haxefmod.studio.CoreSound` is deprecated. Use `haxefmod.core.Sound`.

## HTML5 builds

A call to a method FMOD's web build cannot make is now a compile error in a js build. The error names the method and the reason. `-D haxefmod_html5_allow_unsupported` compiles it with a one-time warning, and the call returns `FMOD_ERR_UNSUPPORTED` at runtime. Every such method carries "(unsupported in HTML5)" in its documentation.

## HashLink

The binding ABI is 11. The build refuses a prebuilt `hlaxe_fmod.hdll` from 2.0 and prints instructions. Run `haxelib run haxefmod build-hdll` once, or use the hdlls shipped in the 3.0 package.

# Migrating from haxefmod 1.x to 2.0

haxefmod 2.0 is a clean break. The string-based sound IDs and bitmask polling callbacks are gone. Typed handles and payload-carrying callbacks replace them. The full FMOD Studio API is now exposed underneath the facade.

## The big picture

2.0 is layered. Use the layer that fits:

- `FmodManager` is the friendly facade with the song slot and sound effects, in the same spirit as 1.x.
- `haxefmod.runtime.FmodRuntime` is the engine-agnostic runtime with settings, refcounted banks, 3D attachment, and listeners.
- `haxefmod.studio.*` is the complete FMOD Studio API with events, buses, VCAs, banks, parameters, and profiling. Anything the facade does not cover is available here.

## Removed APIs and their replacements

### Sound effects: string IDs -> FmodSound handles

| 1.x | 2.0 |
|---|---|
| `PlaySoundWithReference(path):String` | `PlaySound(path):FmodSound` |
| `PlaySoundAndAssignId(path, id):String` | `PlaySound(path):FmodSound` (keep the handle instead of an ID) |
| `StopSound(id)` | `sound.stop()` |
| `StopSoundImmediately(id)` | `sound.stopImmediately()` |
| `PauseSound(id)` / `UnpauseSound(id)` | `sound.pause()` / `sound.unpause()` |
| `IsSoundPlaying(id)` | `sound.isPlaying()` |
| `IsSoundLoaded(id)` | `!sound.isNull()` |
| `GetEventParameterOnSound(id, name)` | `sound.getParameter(name)` |
| `SetEventParameterOnSound(id, name, v)` | `sound.setParameter(name, v)` |
| `ReleaseSound(id)` | `sound.release()` |

`FmodSound` is a zero-cost typed handle. Cast it to `haxefmod.studio.EventInstance` for the full instance API, which includes pitch, 3D attributes, timeline control, and labeled parameters.

### Callbacks: bitmask polling -> typed payloads

| 1.x | 2.0 |
|---|---|
| `RegisterCallbacksForSong(cb, mask)` | `OnSongEvent(data -> switch (data) { ... })` |
| `RegisterCallbacksForSound(id, cb, mask)` | `sound.onEvent(data -> ...)` |
| `RegisterEventListener(listener)` | `OnSongEvent` / `sound.onEvent` |
| `FmodCallback` bitmask constants | `haxefmod.studio.Callbacks.EventCallbackType` |

Callbacks now carry payloads. `TimelineBeat(properties)` carries an `FmodTimelineBeatProperties` with `bar`, `beat`, `position`, `tempo`, `timeSignatureUpper`, and `timeSignatureLower`. `TimelineMarker(properties)` carries an `FmodTimelineMarkerProperties` with `name` and `position`. `Stopped` and the rest of the playback lifecycle have their own constructors.

Handlers fire once per event. 1.x coalesced repeats into one poll per frame. A handler registered again replaces the previous handler for the same instance.

### Coming from flixel-fmod

The `haxefmod.flixel` package in 2.0 fully absorbs the separate flixel-fmod library. Remove it from your dependencies and map:

| flixel-fmod | 2.0 |
|---|---|
| `FlxFmod.Init()` | `haxefmod.flixel.FmodFlxSetup.init()` |
| `FlxFmod.switchState(state)` | `haxefmod.flixel.FmodFlxUtilities.TransitionToState(state)` |
| `FlxFmod.stopMusicAndSwitchState(state)` | `haxefmod.flixel.FmodFlxUtilities.TransitionToStateAndStopMusic(state)` |
| Hand-rolled sound tray / volume wiring | Covered by `FmodFlxSetup.init()` |

`FmodFlxSetup.init()` does everything the old `Init()` did. It initializes FMOD, installs the per-frame update plugin, routes `FlxG.sound` volume to the FMOD master bus, and silences the sound tray beep. It also routes mute to the master bus mute flag, which flixel-fmod never did. It requires flixel 5.9.0 or newer. It is safe to combine with an earlier `FmodManager.Initialize()` call, for example in an html5 preloader. Initialization is guarded and the second call is a no-op.

### Master volume aliases

| 1.x | 2.0 |
|---|---|
| `SetMasterVolume(v)` / `GetMasterVolume()` | `SetBusVolumeMaster(v)` / `GetBusVolumeMaster()` |
| `SetMasterMute(m)` / `GetMasterMute()` | `SetBusMuteMaster(m)` / `GetBusMuteMaster()` |

### Removed without replacement

- `CheckIfUpdateIsBeingCalled()` was an internal diagnostic. Call `FmodManager.Update()` every frame, or use `FmodFlxSetup.init()` or `FmodFlxUpdater` in HaxeFlixel games.

## Behavior changes in kept APIs

- `Initialize(?settings)` now accepts `haxefmod.runtime.FmodSettings` with channels, sample rate, bank folder, auto-loaded banks, and log level.
- **Live Update is no longer always on.** It defaults to on only in `-debug` builds. Force it with `Initialize({liveUpdate: true})` or `-D haxefmod_live_update`. This restores the 1.x firewall prompt.
- `PlaySongTransition` with nothing playing now starts the song immediately. 1.x did nothing until a song existed.
- `PlaySong` now releases the previous song instance when it switches songs. 1.x leaked it on purpose to work around an html5 issue, and 2.0 fixes that issue.
- Song and sound callbacks registered through the removed `Register*` APIs fired at most once per frame. Typed handlers fire once per event.
- html5 does not deliver `Destroyed` events. This is an FMOD JS binding limitation. Handler cleanup happens in `release()` instead.

## Bank loading

1.x loaded the master banks behind the scenes, and `unloadBank` was a no-op. 2.0 loads them through a refcounted registry with a real unload:

```haxe
import haxefmod.runtime.FmodRuntime;

FmodRuntime.banks.load(FmodRuntime.bankPath("SFX.bank"));
FmodRuntime.banks.unload(FmodRuntime.bankPath("SFX.bank")); // real unload at refcount 0
```

For async loading, call `FmodRuntime.banks.loadAsync(path)` and then poll `loadingState(path)`. HaxeFlixel games can use `FmodFlxBankLoader` instead.

## Constants generation

The FMOD Studio export script in `fmod-scripts` remains the recommended workflow. It now emits the 2.0 constants files on every `Ctrl+B` bank build. The files are `FmodEvents.hx`, `FmodBuses.hx`, `FmodVCAs.hx`, `FmodSnapshots.hx`, and `FmodParameters.hx`. Each comes with a `...Guids` class that maps the same constant names to GUIDs.

The old single-file `FmodConstants.hx` output is gone. Rename references with the mangling rules, then delete `FmodConstants.hx`. `FmodSongs.MainLevel` becomes `FmodEvents.MusicMainLevel`, and `FmodSFX.Jump` becomes `FmodEvents.SFXJump`. Later 1.x exports named the songs class `FmodSong`, which maps the same way.

The export also emits `FmodEventEnum.hx`. It holds a `FmodEventEnum` enum that covers every event, with values named like the `FmodEvents` constants. The `path()` and `guid()` mappers return the strings. It suits switch statements and LDtk external enums. Ignore the file if you never need that.
