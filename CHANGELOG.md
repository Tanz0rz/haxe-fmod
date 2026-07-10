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
  `release`; `PlaySoundOneShotAt(path, x, y)` for positional one-shots;
  `OnSongEvent`/`OnceSongEvent` typed payload callbacks (timeline beats,
  markers, playback lifecycle).
- HaxeFlixel components: `FmodFlxSetup.init()` one-call setup (FMOD init,
  per-frame update plugin, `FlxG.sound` volume and mute routed to the FMOD
  master bus, silenced sound tray beep), `FmodFlxEmitter`, `FmodFlxListener`,
  `FmodFlxBankLoader`, `FmodFlxParameterTrigger`.
- Programmer sounds: `instance.assignProgrammerSound(key)` resolving audio
  table keys (or file paths on native targets) on the FMOD thread.
- Two lockstep constants generators: the FMOD Studio export script
  regenerates `FmodEvents`/`FmodBuses`/`FmodVCAs`/`FmodSnapshots`/
  `FmodParameters` (with GUID companions) on every `Ctrl+B` bank build,
  and `haxelib run haxefmod generate` emits identical files from a built
  `Master.strings.bank`; a CI parity test keeps them byte-identical.
- Optional event enum generation: `Ctrl+Shift+B` in FMOD Studio or
  `haxelib run haxefmod generate --enums` also emits `FmodEventEnum.hx`
  (`FmodSong`/`FmodSFX` plain enums with `FmodEvent.event()` path
  mappers) for switch statements and enum-importing tools such as LDtk.
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
  builds; PostBuild clears the executable-stack flag on copied FMOD
  libraries so modern kernels load them.

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
  limitation); handler cleanup happens in `release()` on all targets.
- HTML5 ships FSB-only codecs: loose wav/ogg loading and file-path
  programmer sounds are native-only; audio table keys are the HTML5 route.
- List getters return at most 1024 entries and warn when truncated.

## 1.1.2-beta and earlier

See the GitHub releases for the 1.x history.
