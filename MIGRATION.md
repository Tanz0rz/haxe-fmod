# Migrating from haxefmod 2.0 to 3.0

3.0 brings the library to parity with FMOD's own API, with the C# integration as the reference for shape. Most of the release is additive (see CHANGELOG.md), and the changes below are the ones that need an edit in a 2.0 game.

## Event callbacks deliver FMOD's structs

Every callback payload is the FMOD struct of its type, as one constructor argument, in place of loose values:

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

`PluginCreated(properties)` and `PluginDestroyed(properties)` carry `FmodPluginInstanceProperties` (name, dsp), and `ProgrammerSoundCreated(properties)` and `ProgrammerSoundDestroyed(properties)` carry `FmodProgrammerSoundProperties` (name, sound, subsoundIndex). Those four replace the `Other(type)` fallback for their types. `ChannelEvent` gained `VirtualVoice(isVirtual)` and `Occlusion(direct, reverb)`, so an exhaustive `switch` on it needs those cases or a `default`.

## The default callback mask is every type

`setCallback(handler)` without a mask now delivers every callback type, the default FMOD and its C# integration use. `EventCallbackType.PLAYBACK_ALL` is gone. A handler that only switches on a few types should pass them as the mask, which also keeps busy events (beat tracking at a fast tempo) from queuing more than needed:

```haxe
import haxefmod.studio.Callbacks;

instance.setCallback(handler, EventCallbackType.STARTED | EventCallbackType.TIMELINE_BEAT);
```

## Defaults that now match FMOD

- `Channel.setDelay` and `ChannelGroup.setDelay` default `stopChannels` to `true`. Pass `false` for the earlier pause-at-end behaviour.
- `StudioSystem.getMemoryStats` defaults `blocking` to `true`. Pass `false` for the earlier non-flushing read.
- The programmer sound callback creates its sound with `NONBLOCKING`, so the file decodes off the Studio thread.

## Calls whose shape changed

- `Sound.addSyncPoint` returns the new `FmodSyncPoint` (`FmodSyncPoint.NULL` on failure, result in `StudioSystem.lastResult()`). `getSyncPoint(index)`, `getSyncPointInfo(point)`, and `deleteSyncPoint(point)` take the handle. `getSyncPointName` and `getSyncPointOffset` are deprecated aliases.
- `setLoopPoints` and `getLoopPoints` on `Sound` and `Channel` take a time unit per point (`loopStartType`, `loopEndType`), and the result fields are `loopStart` and `loopEnd`.
- `CommandReplay.seekToTime` and `getCommandAtTime` take seconds as a `Float`. The millisecond forms remain as deprecated `seekToTimeMs` and `getCommandAtTimeMs`.
- `EventDescription.getUserProperty` takes the property name. The index form is `getUserPropertyByIndex(index)`.
- `Dsp.getMetering` and `getInputMetering` return `FmodDspMeteringInfo` (`numSamples`, `peakLevel`, `rmsLevel`, `numChannels`) in place of `{peak, rms}`.
- `Dsp.getParameterInfo` returns `FmodDspParameterDesc`, laid out like `FMOD_DSP_PARAMETER_DESC`: only the member matching `type` (`floatDesc`, `intDesc`, `boolDesc`, `dataDesc`) is set.
- `Sound.getFormat` returns `type` and `format` next to `channels` and `bits`.
- GUIDs are `FmodGuid`, an abstract over the braced text form that converts to and from `String`, so string call sites keep compiling.
- `haxefmod.studio.CoreSound` is deprecated in favour of `haxefmod.core.Sound`.

## HTML5 builds

Calling a method FMOD's web build cannot make is now a compile error in a js build, naming the method and the reason. `-D haxefmod_html5_allow_unsupported` compiles it anyway with a one-time warning, and the call returns `FMOD_ERR_UNSUPPORTED` at runtime. Every such method carries "(unsupported in HTML5)" in its documentation.

## HashLink

The binding ABI is 11. A prebuilt `hlaxe_fmod.hdll` from 2.0 is refused at build time with instructions: run `haxelib run haxefmod build-hdll` once, or use the hdlls shipped in the 3.0 package.

# Migrating from haxefmod 1.x to 2.0

haxefmod 2.0 is a clean break: the string-based sound IDs and bitmask polling callbacks are gone, replaced by typed handles and payload-carrying callbacks, and the full FMOD Studio API is now exposed underneath the facade. This guide maps every removed 1.x API to its replacement.

## The big picture

2.0 is layered. Use whichever layer fits:

- `FmodManager` - the friendly facade (song slot + sound effects), same spirit as 1.x.
- `haxefmod.runtime.FmodRuntime` - engine-agnostic runtime: settings, refcounted banks, 3D attachment, listeners.
- `haxefmod.studio.*` - the complete FMOD Studio API (events, buses, VCAs, banks, parameters, profiling). Anything the facade does not cover is available here.

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

`FmodSound` is a zero-cost typed handle. Cast it to `haxefmod.studio.EventInstance` for the full instance API (pitch, 3D attributes, timeline control, labeled parameters, and more).

### Callbacks: bitmask polling -> typed payloads

| 1.x | 2.0 |
|---|---|
| `RegisterCallbacksForSong(cb, mask)` | `OnSongEvent(data -> switch (data) { ... })` |
| `RegisterCallbacksForSound(id, cb, mask)` | `sound.onEvent(data -> ...)` |
| `RegisterEventListener(listener)` | `OnSongEvent` / `sound.onEvent` |
| `FmodCallback` bitmask constants | `haxefmod.studio.Callbacks.EventCallbackType` |

Callbacks now carry payloads: `TimelineBeat(properties)` with an `FmodTimelineBeatProperties` (`bar`, `beat`, `position`, `tempo`, `timeSignatureUpper`, `timeSignatureLower`), `TimelineMarker(properties)` with an `FmodTimelineMarkerProperties` (`name`, `position`), `Stopped`, and the rest of the playback lifecycle. Handlers fire once per event (1.x coalesced repeats into one poll per frame) and replace the previous handler for the same instance when registered again.

### Coming from flixel-fmod

The separate flixel-fmod library is fully absorbed by 2.0's `haxefmod.flixel` package. Remove it from your dependencies and map:

| flixel-fmod | 2.0 |
|---|---|
| `FlxFmod.Init()` | `haxefmod.flixel.FmodFlxSetup.init()` |
| `FlxFmod.switchState(state)` | `haxefmod.flixel.FmodFlxUtilities.TransitionToState(state)` |
| `FlxFmod.stopMusicAndSwitchState(state)` | `haxefmod.flixel.FmodFlxUtilities.TransitionToStateAndStopMusic(state)` |
| Hand-rolled sound tray / volume wiring | Covered by `FmodFlxSetup.init()` |

`FmodFlxSetup.init()` covers everything the old `Init()` did (FMOD initialization, per-frame update plugin, `FlxG.sound` volume routed to the FMOD master bus, silenced sound tray beep) and also routes mute to the master bus mute flag, which flixel-fmod never did. It requires flixel 5.9.0 or newer. It is safe to combine with an earlier `FmodManager.Initialize()` call (for example in an html5 preloader): initialization is guarded and the second call is a no-op.

### Master volume aliases

| 1.x | 2.0 |
|---|---|
| `SetMasterVolume(v)` / `GetMasterVolume()` | `SetBusVolumeMaster(v)` / `GetBusVolumeMaster()` |
| `SetMasterMute(m)` / `GetMasterMute()` | `SetBusMuteMaster(m)` / `GetBusMuteMaster()` |

### Removed without replacement

- `CheckIfUpdateIsBeingCalled()` - internal diagnostic. Call `FmodManager.Update()` every frame (or use `FmodFlxSetup.init()` / `FmodFlxUpdater` in HaxeFlixel games).

## Behavior changes in kept APIs

- `Initialize(?settings)` now accepts `haxefmod.runtime.FmodSettings` (channels, sample rate, bank folder, auto-loaded banks, log level).
- **Live Update is no longer always on.** It defaults to on only in `-debug` builds. Force it with `Initialize({liveUpdate: true})` or `-D haxefmod_live_update` (this restores the 1.x firewall prompt).
- `PlaySongTransition` with nothing playing now starts the song immediately (1.x silently did nothing until a song existed).
- Switching songs with `PlaySong` now releases the previous song instance (1.x deliberately leaked it to work around an html5 issue that is fixed in 2.0).
- Song/sound callbacks registered through the removed `Register*` APIs fired at most once per frame. Typed handlers fire once per event.
- html5: `Destroyed` events are not delivered (an FMOD JS binding limitation). Handler cleanup happens in `release()` instead.

## Bank loading

1.x loaded the master banks behind the scenes and `unloadBank` was a no-op. 2.0 loads them through a refcounted registry with real unload:

```haxe
import haxefmod.runtime.FmodRuntime;

FmodRuntime.banks.load(FmodRuntime.bankPath("SFX.bank"));
FmodRuntime.banks.unload(FmodRuntime.bankPath("SFX.bank")); // real unload at refcount 0
```

Async loading: `FmodRuntime.banks.loadAsync(path)` then poll `loadingState(path)`, or use `FmodFlxBankLoader` in HaxeFlixel games.

## Constants generation

The FMOD Studio export script (`fmod-scripts`) remains the recommended workflow and now emits the 2.0 constants files on every `Ctrl+B` bank build: `FmodEvents.hx`, `FmodBuses.hx`, `FmodVCAs.hx`, `FmodSnapshots.hx`, and `FmodParameters.hx`. Each comes with a `...Guids` class that maps the same constant names to GUIDs.

The old single-file `FmodConstants.hx` output is gone. Rename references using the mangling rules (`FmodSongs.MainLevel` becomes `FmodEvents.MusicMainLevel`, `FmodSFX.Jump` becomes `FmodEvents.SFXJump`), then delete `FmodConstants.hx`. Later 1.x exports named the songs class `FmodSong`, which maps the same way.

The export also emits `FmodEventEnum.hx`: a `FmodEventEnum` enum covering every event, with values named like the `FmodEvents` constants and `path()`/`guid()` mappers back to the strings. It suits switch statements and LDtk external enums. Ignore the file if you never need that.
