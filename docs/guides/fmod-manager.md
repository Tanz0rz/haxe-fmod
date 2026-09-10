# FmodManager

`haxefmod.FmodManager` is the helper class most games talk to. It owns six areas. Those are lifecycle with banks, one background song slot, events, the mixer (buses, VCAs, and snapshots), global parameters, and game policy. Every call takes an FMOD Studio path or name and holds no handle. The song slot is its one piece of state. `PlayEvent` and `CreateEvent` return an `FmodEvent`, the one handle with a lifetime. `GetBus`, `GetVCA`, and `GetEventDescription` return FMOD's own objects for anything beyond the path calls. It is built entirely on the public layers underneath. Anything it does not cover is reachable through `haxefmod.runtime.FmodRuntime` and `haxefmod.studio.*`, with no hidden state. See [Beyond the helper class](#beyond-the-helper-class).

Every call behaves the same on HaxeFlixel, Heaps, and Kha. The [engine setup calls](components.md#setup) only keep `Update()` running and wire focus and volume.

## Initialization and update

`FmodManager.Initialize(?settings)` starts FMOD. Every other `FmodManager` call initializes with defaults on first use, so the call is optional. Call it yourself to pass [settings](settings.md#settings) or to control when the engine starts. The first initialization wins. The library ignores settings passed to a later call.

```haxe
FmodManager.Initialize({liveUpdate: true, numChannels: 256});
```

Call `FmodManager.Update()` once per frame. It delivers callbacks, pushes positions for attached instances, and drives song transitions. Audio continues without it, because a background thread (native) or timer (HTML5) services the FMOD mixer. Typed callbacks only arrive from `Update()`. `SetAutoUpdate(false)` turns the background servicing off for games that drive FMOD from their own loop. `IsAutoUpdate()` reports the state.

`IsInitialized()` reports true once the engine and the default banks are usable. Native targets initialize synchronously, so it is true immediately. HTML5 initializes asynchronously, and games gate their first scene on it. `InitializeFailed()` reports that a default bank failed to load, so initialization cannot complete. A loading scene shows a message instead of waiting forever.

`EnableDebugMessages()` turns on FMOD's own logging at its most verbose level and traces every `FmodManager` operation. Debug builds enable it automatically.

### Banks

`Initialize` loads the banks named in the `autoLoadBanks` setting, `Master.bank` and `Master.strings.bank` by default. A game with more banks loads them when it needs them. `LoadBank(name)` takes a file name and resolves it against the bank folder setting, or takes a full path. `UnloadBank(name)` releases it, and `IsBankLoaded(name)` reports when its events are usable.

```haxe
FmodManager.LoadBank("Level1.bank");
// on leaving the level
FmodManager.UnloadBank("Level1.bank");
```

Loads are counted. A bank loaded twice unloads on the second `UnloadBank`. A level never pulls away a bank another level still holds. Native targets load synchronously. HTML5 loads asynchronously, so poll `IsBankLoaded` before the first event from the bank. `IsAnyBankLoading()` reports whether any bank is still loading, and `AnyBankFailed()` reports a load that ended in error. `WaitForBanks()` blocks until every pending load completes on native targets. HTML5 cannot block, so it returns at once there. The [engine components](components.md) load a bank for a state's lifetime without any of these calls. [Bank loading](bank-loading.md) covers the registry underneath.

## Music

The helper class has a single song slot. Songs are FMOD events like any other. The slot makes the common case of one background track at a time trivial.

```haxe
FmodManager.PlaySong(FmodEvents.MusicMainLevel);
```

`PlaySong` replaces the current song immediately with no fade. A second call with the song that is already playing does nothing. If that song stopped or is fading out, the call restarts it. `PlaySongTransition` fades the current song out as authored in FMOD Studio and starts the new one when the fade completes. It needs `Update()` running every frame. A second transition during the fade cuts straight to the newest song.

```haxe
FmodManager.PlaySongTransition(FmodEvents.MusicTitle);
```

`StopSong` fades out and `StopSongImmediately` cuts. Both cancel any pending transition. `PauseSong` and `UnpauseSong` freeze and resume the timeline. `IsSongPlaying` counts starting, playing, sustaining, and fading as playing. FMOD starts sounds asynchronously, and the PLAYING state alone would misreport the first frames.

Parameters on the song use `SetSongParameter(name, value)` and `GetSongParameter(name)`. A labeled parameter takes its label text through `SetSongParameterWithLabel(name, label)`. `GetSongTimelinePosition()` returns the timeline position in milliseconds, and `SetSongTimelinePosition(ms)` moves it. `GetCurrentSongPath()` returns the event path that was passed to `PlaySong`.

```haxe
FmodManager.SetSongParameter("Tension", 0.8);
FmodManager.SetSongParameterWithLabel("Section", "Chorus");
```

### Song callbacks

`OnSongEvent` registers a typed callback on the current song. Beats, markers, and lifecycle events arrive as [`EventCallbackData`](callbacks.md) values.

```haxe
FmodManager.OnSongEvent(data -> switch (data) {
    case TimelineBeat(beat): pulseUI(beat.bar, beat.beat);
    case TimelineMarker(marker): trace('marker ${marker.name}');
    default:
});
```

The song has one callback slot. A new registration replaces any previous handler. That includes the handler a pending `PlaySongTransition` uses to hand off, so a registration during a fade cancels the transition. `OnceSongEvent` fires for the first delivered event and then removes itself. Both take an optional mask of `EventCallbackType` bits to limit which events are delivered.

## Events

`PlayOneShot(path)` starts an event and releases it straight away. FMOD destroys it when it finishes. `PlayOneShotAt(path, x, y)` does the same at a 2D position relative to listener 0. `PlayOneShotAttached(path, provider)` follows a moving object until the event ends. Attached playback is for one-shot events only. A looping event never ends, so it would never release.

```haxe
FmodManager.PlayOneShot(FmodEvents.SFXCoin);
FmodManager.PlayOneShotAt(FmodEvents.SFXCoin, 320, 240);
```

`PlayEvent(path)` returns an `FmodEvent` for events you control over time. `CreateEvent(path)` returns the same handle without starting it. Parameters and a position land before the first frame, and `start()` plays it.

```haxe
var engine = FmodManager.PlayEvent(FmodEvents.SFXEngine);
engine.setParameter("RPM", 0.5);
engine.setVolume(0.8);
engine.onEvent(data -> switch (data) {
    case Stopped: trace("engine stopped");
    default:
});
// later
engine.stop();
engine.release();
```

```haxe
var footstep = FmodManager.CreateEvent(FmodEvents.SFXFootstep);
footstep.setParameterWithLabel("Surface", "Grass");
footstep.start();
```

`FmodEvent` wraps an `EventInstance` handle with the everyday operations. Validity: `isNull` and `isValid`. Playback: `start`, `stop` (with the authored fadeout), `stopImmediately`, `pause`, `unpause`, `isPlaying`, and `isPaused`. Timeline: `getTimelinePosition` and `setTimelinePosition(ms)`. Mix: `getVolume`, `setVolume`, `getPitch`, `setPitch`, and `setPosition2D(x, y, velocityX = 0, velocityY = 0)`. Parameters: `getParameter`, `setParameter`, and `setParameterWithLabel`. Lifecycle: `onEvent`, `onceEvent`, and `release`. `onceEvent` fires for the first delivered event and then removes itself. Call `release()` when you are done with the handle. The handle becomes invalid immediately. The event plays to completion unless you stopped it first.

The full event instance API is one cast away. `FmodEvent` is an abstract over `EventInstance`.

```haxe
var event = FmodManager.PlayEvent(FmodEvents.SFXEngine);
var instance:haxefmod.studio.EventInstance = event;
instance.setPosition2D(100, 50);
instance.setTimelinePosition(2000);
```

Snapshots are events to FMOD, so these calls accept them too. The [Snapshots](#snapshots) section covers the calls made for them.

`PlayEvent` returns `FmodEvent.NULL` when FMOD cannot create the event, and logs a warning that names the path. Every method on a null handle is a safe no-op, so a mistyped path degrades to silence. See [Handles and results](handles-and-results.md).

## Global controls

| Call | Effect |
|---|---|
| `StopAllEvents()` | Stops every event routed through the master bus immediately, the song included. |
| `PauseAllEvents()` / `UnpauseAllEvents()` | Pauses the master bus and freezes every event at its position. Events started while paused queue up and play on unpause. |
| `SetBusVolume(path, volume)` / `GetBusVolume(path)` | Linear bus volume, 0.0 silent to 1.0 full. |
| `SetBusMute(path, mute)` / `IsBusMuted(path)` | Bus mute flag. Volume survives a mute and unmute round trip. |
| `SetBusPaused(path, paused)` / `IsBusPaused(path)` | Pauses one bus. Every event through it freezes at its position and resumes from there. A pause menu pauses `bus:/SFX` and keeps the music bus running. |
| `SetMasterVolume(volume)`, `GetMasterVolume()`, `SetMasterMute(mute)`, `IsMasterMuted()` | The same for the master bus, `bus:/`. |
| `SetVCAVolume(path, volume)` / `GetVCAVolume(path)` | Linear VCA volume, 0.0 to 1.0. A VCA scales every bus assigned to it. |
| `ClearAllCallbacks()` | Removes every registered callback: song and event handlers, event description handlers, core channel and group handlers, the system callback, and PCM stream read callbacks. Userdata stays. |

Bus and VCA paths come from FMOD Studio, for example `bus:/SFX` and `vca:/Music`. The generated `FmodBuses` and `FmodVCAs` classes hold them as constants. A project that authors its Master, Music, and SFX sliders as VCAs uses the VCA calls. A project that authors them as buses uses the bus calls.

```haxe
FmodManager.SetBusVolume(FmodBuses.SFX, 0.5);
FmodManager.SetVCAVolume(FmodVCAs.Music, 0.8);
```

## Global parameters

A global parameter is shared by every event in the project. `SetGlobalParameter(name, value)` sets one and `GetGlobalParameter(name)` reads it back. A labeled parameter takes its label text through `SetGlobalParameterWithLabel(name, label)`. The names and labels come from FMOD Studio. The generated `FmodParameters` constants hold `parameter:/Name` paths. Every parameter call in this class takes either form, and so does `setParameter`, `getParameter`, and `setParameterWithLabel` on `FmodEvent`.

```haxe
FmodManager.SetGlobalParameter(FmodParameters.Intensity, 0.75);
FmodManager.SetGlobalParameterWithLabel(FmodParameters.Weather, "Rain");
```

A parameter local to one event is set on that event. The song takes `SetSongParameter`, and an event from `PlayEvent` takes `setParameter` on its handle. FMOD reports a value of 0 for a name it does not know.

## Snapshots

A snapshot is a mixer state the sound designer authored in FMOD Studio. It carries bus volumes, effect settings, sends, and a blend curve. Underwater, paused, and low health are typical snapshots. The game applies one and removes it, and FMOD blends the mixer toward the authored state and back. Several snapshots can be active together.

```haxe
FmodManager.StartSnapshot(FmodSnapshots.Paused);
// later
FmodManager.StopSnapshot(FmodSnapshots.Paused);
```

`StartSnapshot(path)` applies a snapshot until `StopSnapshot(path)` removes it with its authored fade. `StopSnapshotImmediately(path)` cuts. A second `StartSnapshot` for a snapshot that is already applied does nothing. During the fade out it restarts the snapshot. `IsSnapshotActive(path)` reports whether it is applied, and stays true through the fade out. The generated `FmodSnapshots` class holds the paths as constants.

A snapshot's intensity is authored in FMOD Studio and is not a parameter the API can set. To vary it at runtime, the sound designer automates the intensity on a parameter. The game then drives that parameter with `SetGlobalParameter`.

The calls hold no handle. FMOD keeps a started snapshot alive until it stops, and the calls find it again by its path. A snapshot with a timeline that ends on its own can also be fired through `PlayOneShot`.

## Window focus

By default the library mutes the master output while the game window is unfocused. FMOD keeps mixing, so sounds finish on schedule and do not burst out when focus returns. The [engine setup calls](components.md#setup) report focus changes for you. A game without one reports them to the runtime layer from wherever its framework observes them.

```haxe
import haxefmod.runtime.FmodRuntime;

FmodRuntime.setWindowFocused(false);
```

`SetMuteWhenUnfocused(false)` keeps audio playing in the background, and `IsMuteWhenUnfocused()` reports the choice. The `muteWhenUnfocused` setting and the `haxefmod_no_mute_when_unfocused` define do the same. The focus mute applies to the core master channel group, a separate node from the Studio master bus. It never disturbs a mute your game set on `bus:/`. Games that never lose focus can ignore all of this.

## Sound TODO markers

`FmodManager.Todo("description")` marks a spot in game code that still needs a sound. Release builds compile the call away. Debug builds trace each call site once. A build with `-D haxefmod_todo_beep` also plays a short placeholder blip, so missing sounds are audible during playtesting.

```haxe
FmodManager.Todo("door creak when the cellar opens");
```

`haxelib run haxefmod todos` lists every remaining marker in the project. See [Tools CLI](tools-cli.md#todos).

## Beyond the helper class

`FmodManager` covers what a game needs before its first settings menu and its first dynamic music moment. Every call is one action on one FMOD Studio path or name. The layers underneath cover the rest, and mixing them with the helper class is safe. The helper class holds no state FMOD does not hold, apart from the song slot.

| Need | Layer | Guide |
|---|---|---|
| The listener, attached instances, focus, settings after init, the bank registry's states and counts | `haxefmod.runtime.FmodRuntime` | [Runtime and settings](settings.md), [Bank loading](bank-loading.md), [3D and listeners](3d.md) |
| Every FMOD Studio object by handle: events, buses, VCAs, snapshots, banks, command replay | `haxefmod.studio` | [Handles and results](handles-and-results.md), [Callbacks](callbacks.md), the Haxe tab on fmod.com |
| The FMOD Core API: sounds, channels, groups, DSP, geometry | `haxefmod.core` | [Core API helpers](core-api.md) |

`PlayEvent` and `CreateEvent` return the one handle with a lifetime. The cast above reaches the full `EventInstance` API from it. For FMOD's other objects the helper class hands out the object itself. `GetBus(path)`, `GetVCA(path)`, and `GetEventDescription(path)` return the same handles `haxefmod.studio` serves. They belong to FMOD and need no release. A bad path returns a null handle whose every call is a safe no-op. Use them for what the path calls do not cover. Examples are a bus's final volume after VCAs and snapshots, and the channel group under a bus for effects. An event's length, distances, parameters, labels, and sample data preloading come from its description.

```haxe
var shown = FmodManager.GetBus(FmodBuses.Music).getFinalVolume();
FmodManager.GetEventDescription(FmodEvents.MusicMainLevel).loadSampleData();
```
