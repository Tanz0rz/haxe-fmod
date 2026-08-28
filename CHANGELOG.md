# Changelog

## Unreleased

### Added
- Init settings for the engine knobs FMOD only accepts before initialization: `FmodSettings.dspBufferSize` and `dspNumBuffers` (mixer latency, native only, the web build fixes its buffer), `softwareChannels` (the audible voice cap, separate from the virtual count in `numChannels`), `streamBufferSize`, `profiling` (turns on FMOD profiling so `Bus`, `EventInstance`, and `Dsp` `getCpuUsage()` report values), and `distanceFilter`. Defines `haxefmod_dsp_buffer_size` and `haxefmod_software_channels` set the first two from `Project.xml`.
- `Channel.set3DDistanceFilter` and `ChannelGroup.set3DDistanceFilter` with their getters, FMOD's built-in muffling with distance. They need the `distanceFilter` setting on at init.
- `StudioSystem.getVersion()` reports the FMOD engine the running build loaded, formatted like `2.03.12`, for diagnostics and bug reports.
- `Sound.readData(buffer, ?length)` and `seekData(pcm)` read decoded PCM out of a sound, for waveform displays and offline analysis. `Sound.create` gained an `openOnly` flag that keeps the file open for reading. Unsupported in HTML5, where they report `FMOD_ERR_UNSUPPORTED`.
- Microphone recording on native targets: `StudioSystem.getRecordDriverCount()`, `getRecordDriverInfo(id)`, `recordStart(id, sound, loop)`, `recordStop(id)`, `isRecording(id)`, and `getRecordPosition(id)`, recording into a buffer from `Sound.createRecordBuffer(sampleRate, channels, seconds)`. Unsupported in HTML5.
- Custom 3D rolloff curves: `set3DCustomRolloff(points)` and `get3DCustomRolloff()` on `Channel`, `ChannelGroup`, and `Sound`, taking `FmodVector` points where x is the distance and y the volume. Unsupported in HTML5.
- Geometry occlusion (`haxefmod.core.Geometry`): create or load a mesh, add polygons with per-face occlusion, place and rotate it, query occlusion between two points, and save it. Unsupported in HTML5.
- System callbacks: `StudioSystem.setSystemCallback(handler, ?coreMask, ?studioMask)` delivers `SystemEvent` values on the game thread from the callback queue: `DeviceListChanged`, `DeviceLost`, `BankUnload(path)`, `LiveUpdateConnected`, `LiveUpdateDisconnected`, and on request `PreUpdate` and `PostUpdate`. Works on every target. `ClearAllCallbacks` clears it too.
- Plugin loading on native targets: `StudioSystem.loadPlugin(path)`, `unloadPlugin`, `setPluginPath`, `getPluginCount(type)`, `getPluginHandle`, `getPluginInfo`, `getNestedPluginCount`, `getNestedPlugin`, and `Dsp.createByPlugin(handle)` with `Dsp.getPluginInfo`, so a Studio project that uses plugin effects can load them at runtime. Unsupported in HTML5. CI compiles a small gain plugin and loads it in the probe.
- Command replay inspection: `CommandReplay.getCommandCount`, `getCommandInfo`, `getCommandString`, `getCommandAtTime`, `seekToCommand`, `getPlaybackState`, and `setBankPath`.
- `StudioSystem.lockDsp()` and `unlockDsp()` to batch graph edits into one mixer update, `getSoundInfo(key)` for audio table lookups, `getMemoryStats()`, and `getFileUsage()`.
- `CoreSystem` network proxy and timeout settings, and speaker position get and set.
- The remaining plain getters and setters: sound-level 3D cone and min/max distance defaults, DSP chain index moves and readback, fade point and mix matrix readback, `Channel.getChannelGroup`, `SoundGroup.getName` and `getSound`, `CoreSystem.getChannel`, `getOutput`, `getSpeakerModeChannels`, and `getDefaultMixMatrix`, `Dsp.getParameterInfo`, `getDataParameterIndex`, and channel formats, and `DspConnection` mix matrices. The matrix, fade point, and parameter description readers are unsupported in HTML5.
- Userdata on every handle: `setUserData(value)` and `getUserData()` on each studio and core handle type and on `StudioSystem`. The value lives on the Haxe side keyed by the handle and is dropped when the handle is released or destroyed.
- `EventDescription.setCallback(handler, ?mask)` registers a handler on every instance created from the description from then on, matching FMOD's description-level callback.
- Tracker music control on `Sound`: `getMusicNumChannels`, `setMusicChannelVolume`, `getMusicChannelVolume`, `setMusicSpeed`, and `getMusicSpeed` for MOD, S3M, XM, and IT files. Unsupported in HTML5, where loose files cannot load.
- Subsounds and tags on `Sound`: `getNumSubSounds`, `getSubSound`, `getSubSoundParent`, `getNumTags`, and `getTag(name, index)` returning an `FmodTag`. Tag payloads are unsupported in HTML5.
- Advanced settings as init-time `FmodSettings` fields: `maxMPEGCodecs`, `maxVorbisCodecs`, `maxFADPCMCodecs`, `vol0VirtualVol`, `defaultDecodeBufferSize`, `profilePort`, `geometryMaxFadeTime`, `distanceFilterCenterFreq`, `randomSeed`, `commandQueueSize`, `handleInitialSize`, `studioUpdatePeriod`, `idleSampleDataPoolSize`, `streamingScheduleDelay`, and `encryptionKey`, with `StudioSystem.getAdvancedSettings()` and `getStudioAdvancedSettings()` to read them back (the readers are unsupported in HTML5).
- Every FMOD type the headers declare now has a Haxe declaration or a documented reason it cannot: value enums for speakers, speaker modes, output types, driver states, channel masks, time units, open states, sound types and formats, connection types, sound group behaviors, DSP chain positions, and the rest, one enum abstract per DSP effect's parameter list (`haxefmod.core.DspParameters`, so `dsp.setParameter(DspLowpass.CUTOFF, 800)` replaces a magic index), and the DSP value enums (`haxefmod.core.DspEnums`). `ChannelMode` carries all 29 `FMOD_MODE` flags. `native/manifest/types.txt` maps every header type and CI checks each declaration's names and values against the SDK headers.
- `ChannelGroup.getDspCount()` and `getDsp(index)` walk a group's effect chain like `Channel` does.
- Time units: `Sound.getLength`, `getLoopPoints`, `setLoopPoints`, `addSyncPoint`, and `getSyncPointOffset`, and `Channel.getPosition`, `setPosition`, `getLoopPoints`, and `setLoopPoints` take an `FmodTimeUnit` as an optional last parameter, so lengths, positions, and loop points can be read and written in samples, bytes, or tracker rows. Without it they stay in milliseconds.
- `Sound.getOpenStateInfo()` returns the open state together with `percentBuffered`, `starving`, and `diskBusy`.
- DSP data parameters and unit info: `Dsp.getInfo()` (name, version, channels, config size), `getParameterData(index)` returning the raw bytes of a data parameter, `getOverallGain()`, `getLoudnessMeterInfo()` (unsupported in HTML5), `getFftSpectrumInfo(maxBins)` with every channel and the bin and channel counts, `getMetering(input)` and `getInputMetering()` with `numChannels` and `numSamples`, `setParameter3DAttributes(index, absolute, ?relative)` and `setParameter3DAttributesMulti(index, absolute, relative, ?weights)` packed by the shim, and `getParameterInfo` now reporting the label, description, float mapping, int and bool value names, and data type. `FmodDspParameter3DAttributes`, `FmodDspParameter3DAttributesMulti`, `FmodDspParameterOverallGain`, `FmodDspLoudnessMeterInfo`, and `FmodDspParameterFft` declare the payloads.
- HTML5 compile gate: calling a native-only method in a js build is a compile error at the call site naming the method and the reason. `-D haxefmod_html5_allow_unsupported` compiles the call anyway, prints one warning per build, and the call returns `FMOD_ERR_UNSUPPORTED` at runtime in the browser. Applies to sample readback, recording, custom rolloff, geometry, programmer sounds, and memory usage queries.

### Changed
- `Sound.getFormat()` now returns the container `type` (`FmodSoundType`) and sample `format` (`FmodSoundFormat`) next to `channels` and `bits`.
- `Sound.create(path, ?loop, ?openOnly, ?mode, ?initialSubsound)` takes any `ChannelMode` flags at load time (`MODE_3D`, `CREATESTREAM`, `CREATESAMPLE`, `CREATECOMPRESSEDSAMPLE`, `LOOP_BIDI`, `NONBLOCKING`, and the rest) and the subsound an FSB stream starts on. A `NONBLOCKING` load returns at once and `getOpenState()` reports when it is `READY`. HTML5 loads synchronously and drops the flag.
- `Sound.fromMemory(bytes, ?mode, ?length)` creates a sound from an encoded file image in memory (wav, ogg, mp3, fsb). `fromPcm` stays for raw samples. HTML5 decodes FSB images only.
- `Sound.play`, `Dsp.play`, and `PcmStream.play` take an optional `ChannelGroup` so the channel starts inside the group instead of moving there after `setChannelGroup`.
- `Channel.DSP_HEAD`, `DSP_FADER`, and `DSP_TAIL`, the same chain positions `ChannelGroup` declares.
- Programmer sounds: `EventInstance.assignProgrammerSoundFrom(sound, ?subsoundIndex)` hands a `Sound` the game owns to the instrument and never releases it, `assignProgrammerSoundForName(name, key)` and `assignProgrammerSounds(map)` map programmer instrument names to keys for events with several instruments, and the callbacks deliver `ProgrammerSoundCreated(name)` and `ProgrammerSoundDestroyed(name)` with the instrument's name. Unsupported in HTML5 like `assignProgrammerSound`.
- HTML5 compile gate: calling a native-only method in a js build is a compile error at the call site naming the method and the reason. `-D haxefmod_html5_allow_unsupported` compiles the call anyway, prints one warning per build, and the call returns `FMOD_ERR_UNSUPPORTED` at runtime in the browser. Applies to sample readback, recording, custom rolloff, geometry, programmer sounds, and memory usage queries.

### Changed
- The native programmer sound callback creates its sound with `FMOD_NONBLOCKING`, the same as FMOD's own example, so audio table entries and files decode off the Studio thread. FMOD waits for the sound before the instrument plays it.
- `EventInstance.setCallback` handlers receive `ProgrammerSoundCreated(name)` and `ProgrammerSoundDestroyed(name)` for the programmer sound callback types instead of `Other(type)`.

### Deprecated
- `haxefmod.studio.CoreSound` is now `haxefmod.core.Sound`, the core `Sound` object next to `Channel`, `ChannelGroup`, `Dsp`, and `SoundGroup`. The old name remains as a deprecated alias for this release and the compiler warns at every use.

### Fixed
- Pointing `FMOD_SDK` at the HTML5 FMOD Engine package (or `FMOD_SDK_WEB` at a desktop one) now fails the build with a message naming the swapped packages. Previously a native build got as far as copying libraries and died with an uncaught exception on macOS and Windows. Both packages ship the same `api/core/inc` headers, so the check is the platform's own core library rather than a header.
- A desktop FMOD SDK missing the libraries for the platform being built now reports the missing file with setup instructions instead of an uncaught exception. Linux already did this; macOS and Windows now match.

## 2.0.0 (2026-08-27)

A clean-break rework: the full FMOD Studio API at runtime, typed handles, payload-carrying callbacks, and a layered architecture with the facade on top. See `MIGRATION.md` for the complete 1.x to 2.0 mapping.

### Added
- Complete FMOD Studio runtime bindings (`haxefmod.studio`): events, buses, VCAs, snapshots, banks, global and labeled parameters, GUID lookups, 3D/listeners, and profiling, as typed handles safe on stale references.
- Engine-agnostic runtime layer (`haxefmod.runtime.FmodRuntime`): settings-driven initialization, refcounted bank loading with real and async unload, 3D instance attachment, listener helpers.
- `FmodManager.PlaySound(path)` returning a typed `FmodSound` handle with `stop`, `pause`, `setVolume`, `setPitch`, `setParameter`, `onEvent`, and `release`.
- `PlaySoundOneShotAt(path, x, y)` for positional one-shots.
- `OnSongEvent`/`OnceSongEvent` typed payload callbacks (timeline beats, markers, playback lifecycle).
- HaxeFlixel components: `FmodFlxSetup.init()` one-call setup (FMOD init, per-frame update plugin, `FlxG.sound` volume and mute routed to the FMOD master bus, silenced sound tray beep), `FmodFlxEmitter`, `FmodFlxListener`, `FmodFlxBankLoader`, `FmodFlxParameterTrigger`.
- Programmer sounds on native targets: `instance.assignProgrammerSound(key)` resolving audio table keys or file paths on the FMOD thread (HTML5 reports `FMOD_ERR_UNSUPPORTED`, see `LIMITATIONS.md`).
- Constants generation baked into the export: the FMOD Studio script regenerates `FmodEvents`/`FmodBuses`/`FmodVCAs`/`FmodSnapshots`/`FmodParameters` on every `Ctrl+B` bank build, plus a `...Guids` class per file with the GUID for each constant.
- Event enum generation: the export also emits `FmodEventEnum.hx` (a `FmodEventEnum` enum covering every event, named like the `FmodEvents` constants, with `path()` and `guid()` mappers) for switch statements and enum-importing tools such as LDtk.
- Standalone constants generation: `haxelib run haxefmod generate` parses a compiled `Master.strings.bank` directly (default `assets/fmod/Desktop/Master.strings.bank`, with `--strings`, `--out`, and `--package` overrides) and writes the same constants files and `FmodEventEnum.hx` as the Studio export script, for CI and for teammates who never open FMOD Studio.
- Build-time SDK validation: lime builds fail immediately with setup instructions when `FMOD_SDK` (or `FMOD_SDK_WEB` for HTML5) is missing, set to a path that is not an FMOD SDK, or (for HL and HTML5) the wrong FMOD version.
- Cross-version DSP effects: `DspType` values translate to the compiled SDK's own enum symbolically, so an hdll built with `build-hdll` against another FMOD version creates the correct effects (FMOD renumbers that enum between releases). Types the SDK lacks report `FMOD_ERR_INVALID_PARAM`.
- Bank loading on HTML5 is settings-driven through the same refcounted registry as native: `bankFolder` and `autoLoadBanks` (including `[]`) apply, a failed fetch surfaces as a bank `ERROR` state with a traced warning (a failed `autoLoadBanks` fetch still holds `IsInitialized()` false, since the game's own banks are unusable), and `FmodFlxBankLoader` takes an `onError` callback.
- Binding ABI guard: stale pre-built hdlls are refused at build time with `build-hdll` instructions instead of crashing at game startup.
- Generated audio (`haxefmod.core`): `PcmStream` streams 16-bit PCM produced at runtime into the mixer through a ring buffer, with underrun accounting for tuning. `Channel` controls playback: volume, pitch, pause, and stop. Works on every supported platform.
- DSP effects (`haxefmod.core.Dsp`): all 33 built-in FMOD effect types with typed parameter access, attachable to channels, channel groups, and Studio buses. FFT spectrum readback and live peak/RMS metering for visualizers. `Dsp.play()` turns source effects like the oscillator into sounds.
- Core mixing (`haxefmod.core.ChannelGroup`): the master group and custom groups with volume, pitch, mute, pause, and effect chains. `Bus.lockChannelGroup`/`getChannelGroup` bridge Studio buses to their core groups for effect attach.
- Built-in reverb (`haxefmod.core.Reverb`): typed properties with the standard FMOD preset environments, per-channel wet level via `Channel.setReverbWet`.
- Channel routing: pan, frequency, loop count, playback position, group rerouting, per-channel effects, and 3D position on positional streams from `PcmStream.create3d`.
- Custom mixer routing: `Dsp.addInput` builds DSP-to-DSP topologies with per-connection mix levels (`DspConnection`), and channel groups nest (`ChannelGroup.addGroup`) for group hierarchies.
- Sample-accurate scheduling: DSP clock reads, `setDelay`, and fade points on channels and groups (`addFadePoint`, `setFadePointRamp`) for click-free, mixer-clock-exact volume automation.
- Positional reverb zones (`Reverb3D`): reverb that follows the listener between areas, sharing the `Reverb` presets.
- Spatial channel shaping: sound cones, occlusion, spread, 3D level, doppler level, mix matrices, and rolloff selection via `ChannelMode`.
- Memory sounds: `Sound.fromPcm` plays raw PCM from memory on every platform, with defaults, loop points, mode, and format queries.
- Core system queries: playing channel counts, mixer suspend/resume for app backgrounding, and the mixer's output format.
- Channel playback events: `Channel.setCallback` delivers `End` and `SyncPoint(index)` through the per-frame callback drain, with sync points placed on sounds by offset and name (`Sound.addSyncPoint`).
- Sound groups (`haxefmod.core.SoundGroup`): polyphony caps across any set of sounds with fail, mute, or steal-lowest behaviors.
- Global 3D scales (`CoreSystem.set3DSettings`), driver enumeration and selection, and a matching getter for every core routing and spatial setter.
- Banks from memory: `StudioSystem.loadBankMemory` loads embedded or downloaded bank bytes into a normal `Bank` handle.
- Per-instance effects: `EventInstance.getChannelGroup` bridges one event to its core group for DSP attach.
- Command capture and replay: record API sessions to files for FMOD's tools and play them back through `CommandReplay`.
- Channel priority, virtualization and audibility queries, volume ramp control, current-sound access, loop points, and DSP chain introspection. Sound names and group volume. Convolution impulse response upload (`Dsp.setParameterData`), DSP idle and name queries, output-side graph traversal, and the full spatial control surface mirrored on channel groups.
- Sound TODO markers: `FmodManager.Todo("description")` tags spots that need audio later. Release builds compile the call away, debug builds trace each site once, and `-D haxefmod_todo_beep` plays a placeholder blip so missing sounds are audible during playtesting. List every remaining marker with `haxelib run haxefmod todos` (`--json` for tooling). The environment check also notes the count.
- Focus-aware muting: the master output is now muted while the game window is unfocused, so audio no longer plays to a window nobody is looking at - and sounds fired in the background no longer pile up and blast out the moment focus returns (FMOD keeps mixing, so they play out in real time). The mute uses the core master channel group, independent of your own `bus:/` mute. On by default. `FmodFlxSetup` wires Flixel's focus signals automatically. Other engines forward focus with `FmodManager.SetWindowFocused(isFocused)`. Opt out with the `muteWhenUnfocused` setting, `FmodManager.SetMuteWhenUnfocused(false)`, or `-D haxefmod_no_mute_when_unfocused`.
- Timeline beat callbacks carry the authored time signature: `TimelineBeat(bar, beat, positionMs, tempo, timeSigUpper, timeSigLower)` (and the nested variant), so beat-synced logic can react to meter changes.
- Parameter lookups by ID: `getParameterDescriptionByID` and `getParameterLabelByID` on `StudioSystem` and `EventDescription`, plus `EventDescription.getUserPropertyByName`. `CommandReplay.isValid()` matches the other handle types.
- Attached one-shots: `FmodManager.PlaySoundOneShotAttached(path, provider)` plays a self-ending event that follows a moving object and releases itself when it stops. Flixel games pass a FlxObject through `FmodFlxUtilities.PlaySoundOneShotAttached(path, target)`.
- Listener doppler: `FmodFlxListener` pushes the target's velocity (or the camera center's movement) along with its position, and `StudioSystem.setListenerPosition2D` accepts optional velocity arguments. Camera jumps larger than one camera width count as cuts and push zero velocity (`teleportDistance` overrides the threshold), and `resetMotion()` covers cuts the game performs itself.
- `maxAttachedVelocity` setting: caps the velocity magnitude FMOD sees from attached instances and the flixel listener, taming doppler pitch flutter on very fast movers. Default 0 (no cap).
- Distance culling on emitters: `FmodFlxEmitter.stopEventsOutsideMaxDistance` stops a looping emitter with a fadeout beyond its max distance and restarts it when the listener comes back in range, saving voices. One-shot events are exempt (a stopped and restarted one-shot would replay long after it finished). Only an instance the emitter itself stopped is restarted, `cullCheckInterval` paces the distance checks (default every 6 frames), and `cullMaxDistance` overrides the authored distance. Authored distances apply to 3D events only, so a 2D event is culled only when `cullMaxDistance` is set explicitly.

### Changed
- Live Update defaults to on only in debug builds (`-D haxefmod_live_update` or `Initialize({liveUpdate: true})` to force).
- `PlaySongTransition` with nothing playing starts the song immediately.
- Switching songs releases the previous song instance.
- Song and sound callbacks fire once per event with typed payloads (1.x coalesced to one bitmask poll per frame).
- `haxelib run haxefmod check` exits nonzero when any check fails.
- Generated Linux `run.sh` no longer points at `hlboot.dat` on HashLink builds.
- PostBuild clears the executable-stack flag on copied FMOD libraries so modern kernels load them, with no external tools needed.

### Removed
- The single-file `FmodConstants.hx` (`FmodSongs`/`FmodSFX`) output of the Studio export script, replaced by the categorized 2.0 constants files.
- String sound IDs (`PlaySoundWithReference`, `PlaySoundAndAssignId`, and the per-ID control calls) in favor of `FmodSound` handles.
- Bitmask polling callbacks (`RegisterCallbacksForSong/Sound`, `RegisterEventListener`) in favor of typed payload callbacks.
- `Set/GetMasterVolume`, `Set/GetMasterMute` aliases (use the `Bus*Master` helpers) and `CheckIfUpdateIsBeingCalled`.

## 1.1.2-beta and earlier

See the GitHub releases for the 1.x history.
