# Changelog

## 2.0.0

A clean-break rework: the full FMOD Studio API at runtime, typed handles,
payload-carrying callbacks, and a layered architecture with the facade on
top. See `MIGRATION.md` for the complete 1.x to 2.0 mapping.

### Added
- Complete FMOD Studio runtime bindings (`haxefmod.studio`): events, buses,
  VCAs, snapshots, banks, global and labeled parameters, GUID lookups,
  3D/listeners, and profiling, as typed handles safe on stale references.
- Engine-agnostic runtime layer (`haxefmod.runtime.FmodRuntime`): settings-
  driven initialization, refcounted bank loading with real and async unload,
  3D instance attachment, listener helpers.
- `FmodManager.PlaySound(path)` returning a typed `FmodSound` handle with
  `stop`, `pause`, `setVolume`, `setPitch`, `setParameter`, `onEvent`, and
  `release`.
- `PlaySoundOneShotAt(path, x, y)` for positional one-shots.
- `OnSongEvent`/`OnceSongEvent` typed payload callbacks (timeline beats,
  markers, playback lifecycle).
- HaxeFlixel components: `FmodFlxSetup.init()` one-call setup (FMOD init,
  per-frame update plugin, `FlxG.sound` volume and mute routed to the FMOD
  master bus, silenced sound tray beep), `FmodFlxEmitter`, `FmodFlxListener`,
  `FmodFlxBankLoader`, `FmodFlxParameterTrigger`.
- Programmer sounds: `instance.assignProgrammerSound(key)` resolving audio
  table keys (or file paths on native targets) on the FMOD thread.
- Constants generation baked into the export: the FMOD Studio script
  regenerates `FmodEvents`/`FmodBuses`/`FmodVCAs`/`FmodSnapshots`/
  `FmodParameters` on every `Ctrl+B` bank build, plus a `...Guids` class
  per file with the GUID for each constant.
- Event enum generation: the export also emits `FmodEventEnum.hx`
  (a `FmodEventEnum` enum covering every event, named like the
  `FmodEvents` constants, with `path()` and `guid()` mappers) for
  switch statements and enum-importing tools such as LDtk.
- Build-time SDK validation: lime builds fail immediately with setup
  instructions when `FMOD_SDK` (or `FMOD_SDK_WEB` for HTML5) is missing,
  set to a path that is not an FMOD SDK, missing the platform's
  runtime libraries, or (for HL and HTML5) the wrong FMOD version.
- Cross-version DSP effects: `DspType` values translate to the compiled
  SDK's own enum symbolically, so an hdll built with `build-hdll`
  against another FMOD version creates the correct effects (FMOD
  renumbers that enum between releases). Types the SDK lacks report
  `FMOD_ERR_INVALID_PARAM`.
- Bank loading on HTML5 is settings-driven through the same refcounted
  registry as native: `bankFolder` and `autoLoadBanks` (including `[]`)
  apply, a failed fetch surfaces as a bank `ERROR` state instead of
  hanging startup, and `FmodFlxBankLoader` takes an `onError` callback.
- Binding ABI guard: stale pre-built hdlls are refused at build time with
  `build-hdll` instructions instead of crashing at game startup.
- Generated audio (`haxefmod.core`): `PcmStream` streams 16-bit PCM
  produced at runtime into the mixer through a ring buffer, with underrun
  accounting for tuning. `Channel` controls playback: volume, pitch,
  pause, and stop. Works on every supported platform.
- DSP effects (`haxefmod.core.Dsp`): all 33 built-in FMOD effect types
  with typed parameter access, attachable to channels, channel groups,
  and Studio buses. FFT spectrum readback and live peak/RMS metering for
  visualizers. `Dsp.play()` turns source effects like the oscillator into
  sounds.
- Core mixing (`haxefmod.core.ChannelGroup`): the master group and custom
  groups with volume, pitch, mute, pause, and effect chains.
  `Bus.lockChannelGroup`/`getChannelGroup` bridge Studio buses to their
  core groups for effect attach.
- Built-in reverb (`haxefmod.core.Reverb`): typed properties with the
  standard FMOD preset environments, per-channel wet level via
  `Channel.setReverbWet`.
- Channel routing: pan, frequency, loop count, playback position, group
  rerouting, per-channel effects, and 3D position on positional streams
  from `PcmStream.create3d`.
- Custom mixer routing: `Dsp.addInput` builds DSP-to-DSP topologies with
  per-connection mix levels (`DspConnection`), and channel groups nest
  (`ChannelGroup.addGroup`) for group hierarchies.
- Sample-accurate scheduling: DSP clock reads, `setDelay`, and fade points
  on channels and groups (`addFadePoint`, `setFadePointRamp`) for
  click-free, mixer-clock-exact volume automation.
- Positional reverb zones (`Reverb3D`): reverb that follows the listener
  between areas, sharing the `Reverb` presets.
- Spatial channel shaping: sound cones, occlusion, spread, 3D level,
  doppler level, mix matrices, and rolloff selection via `ChannelMode`.
- Memory sounds: `CoreSound.fromPcm` plays raw PCM from memory on every
  platform, with defaults, loop points, mode, and format queries.
- Core system queries: playing channel counts, mixer suspend/resume for
  app backgrounding, and the mixer's output format.
- Channel playback events: `Channel.setCallback` delivers `End` and
  `SyncPoint(index)` through the per-frame callback drain, with sync
  points placed on sounds by offset and name (`CoreSound.addSyncPoint`).
- Sound groups (`haxefmod.core.SoundGroup`): polyphony caps across any
  set of sounds with fail, mute, or steal-lowest behaviors.
- Global 3D scales (`CoreSystem.set3DSettings`), driver enumeration and
  selection, and a matching getter for every core routing and spatial
  setter.
- Banks from memory: `StudioSystem.loadBankMemory` loads embedded or
  downloaded bank bytes into a normal `Bank` handle.
- Per-instance effects: `EventInstance.getChannelGroup` bridges one event
  to its core group for DSP attach.
- Command capture and replay: record API sessions to files for FMOD's
  tools and play them back through `CommandReplay`.
- Channel priority, virtualization and audibility queries, volume ramp
  control, current-sound access, loop points, and DSP chain
  introspection. Sound names and group volume. Convolution impulse
  response upload (`Dsp.setParameterData`), DSP idle and name queries,
  output-side graph traversal, and the full spatial control surface
  mirrored on channel groups.
- Sound TODO markers: `FmodManager.Todo("description")` tags spots that
  need audio later. Release builds compile the call away, debug builds
  trace each site once, and `-D haxefmod_todo_beep` plays a placeholder
  blip so missing sounds are audible during playtesting. List every
  remaining marker with `haxelib run haxefmod todos` (`--json` for
  tooling). The environment check also notes the count.
- Focus-aware muting: the master output is now muted while the game window
  is unfocused, so audio no longer plays to a window nobody is looking at -
  and sounds fired in the background no longer pile up and blast out the
  moment focus returns (FMOD keeps mixing, so they play out in real time).
  The mute uses the core master channel group, independent of your own
  `bus:/` mute. On by default. `FmodFlxSetup` wires Flixel's focus signals
  automatically. Other engines forward focus with
  `FmodManager.SetWindowFocused(isFocused)`. Opt out with the
  `muteWhenUnfocused` setting, `FmodManager.SetMuteWhenUnfocused(false)`, or
  `-D haxefmod_no_mute_when_unfocused`.
- Timeline beat callbacks carry the authored time signature:
  `TimelineBeat(bar, beat, positionMs, tempo, timeSigUpper, timeSigLower)`
  (and the nested variant), so beat-synced logic can react to meter changes.
- Parameter lookups by ID: `getParameterDescriptionByID` and
  `getParameterLabelByID` on `StudioSystem` and `EventDescription`, plus
  `EventDescription.getUserPropertyByName`. `CommandReplay.isValid()`
  matches the other handle types.
- Attached one-shots: `FmodManager.PlaySoundOneShotAttached(path, provider)`
  plays a self-ending event that follows a moving object and releases
  itself when it stops. Flixel games pass a FlxObject through
  `FmodFlxUtilities.PlaySoundOneShotAttached(path, target)`.
- Listener doppler: `FmodFlxListener` pushes the target's velocity (or the
  camera center's movement) along with its position, and
  `StudioSystem.setListenerPosition2D` accepts optional velocity arguments.
  Camera jumps beyond `teleportDistance` (default one camera width) count
  as cuts and push zero velocity, and `resetMotion()` covers cuts the game
  performs itself.
- `maxAttachedVelocity` setting: caps the velocity magnitude FMOD sees from
  attached instances and the flixel listener, taming doppler pitch flutter
  on very fast movers. Default 0 (no cap).
- Distance culling on emitters: `FmodFlxEmitter.stopEventsOutsideMaxDistance`
  stops a looping emitter with a fadeout beyond its max distance
  and restarts it when the listener comes back in range, saving voices.
  One-shot events are exempt (a stopped and restarted one-shot would
  replay long after it finished). Only an instance the emitter itself
  stopped is restarted, `cullCheckInterval` paces the distance checks
  (default every 6 frames), and `cullMaxDistance` overrides the authored
  distance for events without one.

### Changed
- Live Update defaults to on only in debug builds (`-D haxefmod_live_update`
  or `Initialize({liveUpdate: true})` to force).
- `PlaySongTransition` with nothing playing starts the song immediately.
- Switching songs releases the previous song instance.
- Song and sound callbacks fire once per event with typed payloads (1.x
  coalesced to one bitmask poll per frame).
- `haxelib run haxefmod check` exits nonzero when any check fails.
- Generated Linux `run.sh` no longer points at `hlboot.dat` on HashLink
  builds.
- PostBuild clears the executable-stack flag on copied FMOD libraries
  so modern kernels load them.

### Removed
- The single-file `FmodConstants.hx` (`FmodSongs`/`FmodSFX`) output of the
  Studio export script, replaced by the categorized 2.0 constants files.
- String sound IDs (`PlaySoundWithReference`, `PlaySoundAndAssignId`, and
  the per-ID control calls) in favor of `FmodSound` handles.
- Bitmask polling callbacks (`RegisterCallbacksForSong/Sound`,
  `RegisterEventListener`) in favor of typed payload callbacks.
- `Set/GetMasterVolume`, `Set/GetMasterMute` aliases (use the
  `Bus*Master` helpers) and `CheckIfUpdateIsBeingCalled`.

### Known limitations
- HTML5 never delivers `Destroyed` callback events (FMOD JS binding
  limitation). Handler cleanup happens in `release()` on all targets.
- HTML5 ships FSB-only codecs: loose wav/ogg loading and file-path
  programmer sounds are native-only. Audio table keys are the HTML5 route.
- List getters return at most 1024 entries and warn when truncated.
- HTML5 bank loads are always asynchronous (files reach the browser's
  virtual filesystem through a fetch). `IsInitialized()` reports true
  once the system is ready and the `autoLoadBanks` are usable, so games
  that gate on it need no changes.
- HTML5 supports exactly the expected FMOD web SDK version: a
  mismatched `FMOD_SDK_WEB` fails the build with instructions (the JS
  layer's numeric tables are that version's values and the wasm exposes
  no version query to adapt at runtime).
- HTML5 nested timeline beat callbacks report zeroed fields when FMOD's
  JS binding provides no data for them (top-level beats are unaffected).

## 1.1.2-beta and earlier

See the GitHub releases for the 1.x history.
