# Migrating from haxefmod 1.x to 2.0

haxefmod 2.0 is a clean break: the string-based sound IDs and bitmask
polling callbacks are gone, replaced by typed handles and payload-carrying
callbacks, and the full FMOD Studio API is now exposed underneath the
facade. This guide maps every removed 1.x API to its replacement.

## The big picture

2.0 is layered. Use whichever layer fits:

- `FmodManager` - the friendly facade (song slot + sound effects), same
  spirit as 1.x.
- `haxefmod.runtime.FmodRuntime` - engine-agnostic runtime: settings,
  refcounted banks, 3D attachment, listeners.
- `haxefmod.studio.*` - the complete FMOD Studio API (events, buses,
  VCAs, banks, parameters, profiling). Anything the facade does not
  cover is available here.

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

`FmodSound` is a zero-cost typed handle. Cast it to
`haxefmod.studio.EventInstance` for the full instance API (pitch, 3D
attributes, timeline control, labeled parameters, and more).

### Callbacks: bitmask polling -> typed payloads

| 1.x | 2.0 |
|---|---|
| `RegisterCallbacksForSong(cb, mask)` | `OnSongEvent(data -> switch (data) { ... })` |
| `RegisterCallbacksForSound(id, cb, mask)` | `sound.onEvent(data -> ...)` |
| `RegisterEventListener(listener)` | `OnSongEvent` / `sound.onEvent` |
| `FmodCallback` bitmask constants | `haxefmod.studio.Callbacks.EventCallbackType` |

Callbacks now carry payloads:
`TimelineBeat(bar, beat, positionMs, tempo, timeSigUpper, timeSigLower)`,
`TimelineMarker(name, positionMs)`, `Stopped`, and the rest of the
playback lifecycle. Handlers fire once per event (1.x coalesced repeats
into one poll per frame) and replace the previous handler for the same
instance when registered again.

### Coming from flixel-fmod

The separate flixel-fmod library is fully absorbed by 2.0's
`haxefmod.flixel` package. Remove it from your dependencies and map:

| flixel-fmod | 2.0 |
|---|---|
| `FlxFmod.Init()` | `haxefmod.flixel.FmodFlxSetup.init()` |
| `FlxFmod.switchState(state)` | `haxefmod.flixel.FmodFlxUtilities.TransitionToState(state)` |
| `FlxFmod.stopMusicAndSwitchState(state)` | `haxefmod.flixel.FmodFlxUtilities.TransitionToStateAndStopMusic(state)` |
| Hand-rolled sound tray / volume wiring | Covered by `FmodFlxSetup.init()` |

`FmodFlxSetup.init()` covers everything the old `Init()` did (FMOD
initialization, per-frame update plugin, `FlxG.sound` volume routed to
the FMOD master bus, silenced sound tray beep) and also routes mute to
the master bus mute flag, which flixel-fmod never did. It is safe to
combine with an earlier `FmodManager.Initialize()` call (for example in
an html5 preloader): initialization is guarded and the second call is
a no-op.

### Master volume aliases

| 1.x | 2.0 |
|---|---|
| `SetMasterVolume(v)` / `GetMasterVolume()` | `SetBusVolumeMaster(v)` / `GetBusVolumeMaster()` |
| `SetMasterMute(m)` / `GetMasterMute()` | `SetBusMuteMaster(m)` / `GetBusMuteMaster()` |

### Removed without replacement

- `CheckIfUpdateIsBeingCalled()` - internal diagnostic. Call
  `FmodManager.Update()` every frame (or use `FmodFlxSetup.init()` /
  `FmodFlxUpdater` in HaxeFlixel games).

## Behavior changes in kept APIs

- `Initialize(?settings)` now accepts `haxefmod.runtime.FmodSettings`
  (channels, sample rate, bank folder, auto-loaded banks, log level).
- **Live Update is no longer always on.** It defaults to on only in
  `-debug` builds. Force it with `Initialize({liveUpdate: true})` or
  `-D haxefmod_live_update` (this restores the 1.x firewall prompt).
- `PlaySongTransition` with nothing playing now starts the song
  immediately (1.x silently did nothing until a song existed).
- Switching songs with `PlaySong` now releases the previous song
  instance (1.x deliberately leaked it to work around an html5 issue
  that is fixed in 2.0).
- Song/sound callbacks registered through the removed `Register*` APIs
  fired at most once per frame. Typed handlers fire once per event.
- html5: `Destroyed` events are not delivered (an FMOD JS binding
  limitation). Handler cleanup happens in `release()` instead.

## Bank loading

1.x loaded the master banks behind the scenes and `unloadBank` was a
no-op. 2.0 loads them through a refcounted registry with real unload:

```haxe
FmodRuntime.banks.load(FmodRuntime.bankPath("SFX.bank"));
FmodRuntime.banks.unload(FmodRuntime.bankPath("SFX.bank")); // real unload at refcount 0
```

Async loading: `FmodRuntime.banks.loadAsync(path)` then poll
`loadingState(path)`, or use `FmodFlxBankLoader` in HaxeFlixel games.

## Constants generation

The FMOD Studio export script (`fmod-scripts`) remains the recommended
workflow and now emits the 2.0 constants files on every `Ctrl+B` bank
build: `FmodEvents.hx`, `FmodBuses.hx`, `FmodVCAs.hx`,
`FmodSnapshots.hx`, and `FmodParameters.hx`. Each comes with a
`...Guids` class that maps the same constant names to GUIDs.

The old single-file `FmodConstants.hx` output is gone. Rename references
using the mangling rules (`FmodSongs.MainLevel` becomes
`FmodEvents.MusicMainLevel`, `FmodSFX.Jump` becomes
`FmodEvents.SFXJump`), then delete `FmodConstants.hx`. Later 1.x
exports named the songs class `FmodSong`, which maps the same way.

The export also emits `FmodEventEnum.hx`: a `FmodEventEnum` enum
covering every event, with values named like the `FmodEvents`
constants and `path()`/`guid()` mappers back to the strings. It suits
switch statements and LDtk external enums. Ignore the file if you
never need that.

## New in 2.0 (no 1.x equivalent)

- `haxefmod.flixel.FmodFlxSetup.init()`: one-call HaxeFlixel setup that
  initializes FMOD, adds the update plugin, routes `FlxG.sound` volume
  and mute (the volume keys and the sound tray) to the FMOD master bus,
  and silences the sound tray's own beep. Replaces the hand-rolled sound
  tray and volume wiring that flixel-fmod-era projects carried.
  Requires flixel 5.9.0 or newer.
- Full Studio API: `StudioSystem.getEvent/getBus/getVCA/getBank`,
  GUID lookups, global parameters, labeled parameters, profiling.
- 3D: `FmodFlxEmitter`, `FmodFlxListener`, `FmodRuntime.attach`,
  `EventInstance.setPosition2D`, multi-listener support.
- Programmer sounds: `instance.assignProgrammerSound(key)` resolves
  audio-table keys (or file paths on native targets) on the FMOD thread.
- `FmodFlxBankLoader`, `FmodFlxParameterTrigger` components.
