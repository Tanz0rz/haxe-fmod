# FmodManager

`haxefmod.FmodManager` is the facade most games talk to. It owns one background song slot, plays sound effects either fire-and-forget or through a handle, and exposes the master and bus controls a settings menu needs. It is built entirely on the public layers underneath, so anything it does not cover is reachable through `haxefmod.runtime.FmodRuntime` and `haxefmod.studio.*` with no hidden state to work around.

Nothing on this page depends on an engine. Every call behaves the same on HaxeFlixel, Heaps, and Kha, and the [engine setup calls](components.md#setup) only keep `Update()` running and wire focus and volume.

## Initialization and update

`FmodManager.Initialize(?settings)` starts FMOD. Every other facade call initializes with defaults on first use, so calling it is optional. Call it yourself when you want to pass [settings](banks-and-settings.md#settings) or control when the engine starts. The first initialization wins. Settings passed to a later call are ignored.

```haxe
FmodManager.Initialize({liveUpdate: true, numChannels: 256});
```

Call `FmodManager.Update()` once per frame. It delivers callbacks, pushes positions for attached instances, and drives song transitions. Audio keeps playing without it, because a background thread (native) or timer (HTML5) services the FMOD mixer on its own, but typed callbacks only arrive from `Update()`. `SetAutoUpdate(false)` turns the background servicing off for games that want to drive FMOD purely from their loop.

`IsInitialized()` reports true once the engine and the default banks are usable. Native targets initialize synchronously, so it is true immediately. HTML5 initializes asynchronously and games gate their first scene on it.

`EnableDebugMessages()` turns on FMOD's own logging at its most verbose level and traces every facade operation. Debug builds enable it automatically.

## Music

The facade has a single song slot. Songs are FMOD events like any other, and the slot makes the common case of one background track at a time trivial.

```haxe
FmodManager.PlaySong(FmodEvents.MusicMainLevel);
```

`PlaySong` replaces the current song immediately with no fade. Calling it again with the song that is already playing does nothing, and if that song stopped or is fading out it restarts. `PlaySongTransition` fades the current song out as authored in FMOD Studio and starts the new one when the fade completes, which needs `Update()` running every frame. A second transition during the fade cuts straight to the newest song rather than crossfading.

```haxe
FmodManager.PlaySongTransition(FmodEvents.MusicTitle);
```

`StopSong` fades out, `StopSongImmediately` cuts, and both cancel any pending transition. `PauseSong` and `UnpauseSong` freeze and resume the timeline. `IsSongPlaying` counts starting, playing, sustaining, and fading as playing, since FMOD starts sounds asynchronously and the PLAYING state alone would misreport the first frames.

Parameters on the song use `SetEventParameterOnSong(name, value)` and `GetEventParameterOnSong(name)`. `GetSongTimelinePosition()` returns the timeline position in milliseconds, and `GetCurrentSongPath()` returns the event path that was passed to `PlaySong`.

### Song callbacks

`OnSongEvent` registers a typed callback on the current song. Beats, markers, and lifecycle events arrive as [`EventCallbackData`](callbacks-and-3d.md#typed-callbacks) values.

```haxe
FmodManager.OnSongEvent(data -> switch (data) {
    case TimelineBeat(beat): pulseUI(beat.bar, beat.beat);
    case TimelineMarker(marker): trace('marker ${marker.name}');
    default:
});
```

The song has one callback slot. Registering replaces any previous handler, and that includes the handler a pending `PlaySongTransition` uses to hand off, so registering during a fade cancels the transition. `OnceSongEvent` fires for the first delivered event and then removes itself. Both take an optional mask of `EventCallbackType` bits to limit which events are delivered.

## Sound effects

`PlaySoundOneShot(path)` starts an event and releases it straight away. FMOD destroys it when it finishes. `PlaySoundOneShotAt(path, x, y)` does the same at a 2D position relative to listener 0, and `PlaySoundOneShotAttached(path, provider)` follows a moving object until the event ends. Attached playback is for one-shot events only. A looping event never ends, so it would never release.

```haxe
FmodManager.PlaySoundOneShot(FmodEvents.SFXCoin);
FmodManager.PlaySoundOneShotAt(FmodEvents.SFXCoin, 320, 240);
```

`PlaySound(path)` returns an `FmodSound` for sounds you control over time.

```haxe
var engine = FmodManager.PlaySound(FmodEvents.SFXEngine);
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

`FmodSound` wraps an `EventInstance` handle with the everyday operations: `stop` (with the authored fadeout), `stopImmediately`, `pause`, `unpause`, `getVolume` and `setVolume`, `getPitch` and `setPitch`, `getParameter` and `setParameter`, `onEvent`, `isPlaying`, and `release`. Call `release()` when you are done with the handle. The sound keeps playing to completion unless you stopped it first, and the handle becomes invalid immediately.

The full event instance API is one cast away, since `FmodSound` is an abstract over `EventInstance`.

```haxe
var sound = FmodManager.PlaySound(FmodEvents.SFXEngine);
var instance:haxefmod.studio.EventInstance = sound;
instance.setPosition2D(100, 50);
instance.setParameterWithLabel("Surface", "Grass");
```

`PlaySound` returns `FmodSound.NULL` when the event could not be created, and logs a warning naming the path. Every method on a null handle is a safe no-op, so a mistyped path degrades to silence rather than a crash. See [Handles and results](handles-and-results.md).

## Global controls

| Call | Effect |
|---|---|
| `StopAllSounds()` | Stops every event routed through the master bus immediately. |
| `PauseAllSounds()` / `UnpauseAllSounds()` | Pauses the master bus, freezing every sound at its position. Events started while paused queue up and play on unpause. |
| `SetBusVolume(path, volume)` / `GetBusVolume(path)` | Linear bus volume, 0.0 silent to 1.0 full. |
| `SetBusMute(path, mute)` / `GetBusMute(path)` | Bus mute flag. Volume survives a mute and unmute round trip. |
| `SetBusVolumeMaster`, `GetBusVolumeMaster`, `SetBusMuteMaster`, `GetBusMuteMaster` | The same for `bus:/`. |
| `ClearAllCallbacks()` | Removes every registered callback: song and sound handlers, event description handlers, core channel and group handlers, the system callback, and PCM stream read callbacks. Userdata is left alone. |

Bus paths come from FMOD Studio, for example `bus:/SFX`, and the generated `FmodBuses` class holds them as constants.

## Window focus

By default the master output is muted while the game window is unfocused, so audio does not play to a window nobody is looking at. FMOD keeps mixing, which means sounds finish on schedule instead of piling up and bursting out when focus returns. Report focus changes from wherever your framework observes them.

```haxe
FmodManager.SetWindowFocused(false);
```

`SetMuteWhenUnfocused(false)` keeps audio playing in the background, as does the `muteWhenUnfocused` setting or the `haxefmod_no_mute_when_unfocused` define. The focus mute is applied to the core master channel group, a separate node from the Studio master bus, so it never disturbs a mute your game set on `bus:/`. Games that never lose focus can ignore all of this.

## Sound TODO markers

`FmodManager.Todo("description")` marks a spot in game code that still needs a sound. Release builds compile the call away. Debug builds trace each call site once, and building with `-D haxefmod_todo_beep` also plays a short placeholder blip so missing sounds are audible during playtesting.

```haxe
FmodManager.Todo("door creak when the cellar opens");
```

`haxelib run haxefmod todos` lists every remaining marker in the project. See [Tools CLI](tools-cli.md#todos).
