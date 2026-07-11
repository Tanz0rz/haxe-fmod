# Changelog

## 2.1.0

### Added
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
  set to a path that is not an FMOD SDK, or missing the platform's
  runtime libraries.
- Binding ABI guard: stale pre-built hdlls are refused at build time with
  `build-hdll` instructions instead of crashing at game startup.

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

## 1.1.2-beta and earlier

See the GitHub releases for the 1.x history.
