# Unsupported functions

The 129 functions of the FMOD API that haxefmod 2.0.0 does not expose, with the reason for each. Generated from `extension/functions.md` by `ci/haxe-bindings.py`, so this page and the Haxe tab of the browser extension always agree. [Limitations](limitations.md) explains the categories, and [Coverage](coverage.md) lists what is bound.

Every function here is a candidate for a future binding. An issue naming one, with the use case, is the way to ask.

## Channel

| Function | Why |
|---|---|
| `Channel::getChannelGroup` | The group a channel plays in is the one you passed to Channel.setChannelGroup, or the master group by default, so keep that reference on the game side. |

## ChannelControl

| Function | Why |
|---|---|
| `ChannelControl::getDSPIndex` | Channel.getDspCount() and Channel.getDsp(index) walk the chain in order, so the index of a unit is the position where getDsp returns it. |
| `ChannelControl::getFadePoints` | Fade point readback is left out. Channel.addFadePoint, setFadePointRamp, and removeFadePoints are bound, and the game keeps its own list of the points it added. |
| `ChannelControl::getMixMatrix` | Mix matrix readback is left out. Channel.setMixMatrix and ChannelGroup.setMixMatrix are bound, and the game keeps the matrix it set. |
| `ChannelControl::getUserData` | Userdata on FMOD objects is left out because the binding's handle table already carries object identity. Keep your own map from the handle to your data, handles are ints and work as keys. |
| `ChannelControl::setDSPIndex` | Reordering the chain after the fact is left out. Channel.addDsp(index, dsp) and ChannelGroup.addDsp(index, dsp) take the position when the unit is inserted, and removeDsp followed by addDsp moves it. |
| `ChannelControl::setMixLevelsInput` | Per-speaker input mix levels are left out with the speaker geometry APIs. Channel.setMixMatrix and ChannelGroup.setMixMatrix accept an explicit matrix, and setPan covers the common case. |
| `ChannelControl::setMixLevelsOutput` | Per-speaker output mix levels are left out with the speaker geometry APIs. Channel.setMixMatrix and ChannelGroup.setMixMatrix accept an explicit matrix, and setPan covers the common case. |

## DSP

| Function | Why |
|---|---|
| `DSP::addInputPreallocated` | Preallocated connections are left out. Dsp.addInput() connects two units and returns the DspConnection, and FMOD allocates it on its own thread. |
| `DSP::getChannelFormat` | Channel format control on individual units is left out, and every unit runs in the mixer's format from FmodSettings.speakerMode. |
| `DSP::getDataParameterIndex` | Data parameter lookup is left out with the DSP parameter metadata. Dsp.getFftSpectrum() reads the FFT unit's spectrum data directly, and Dsp.setParameterData(index, bytes) writes a data parameter by index. |
| `DSP::getOutputChannelFormat` | Channel format control on individual units is left out, and every unit runs in the mixer's format from FmodSettings.speakerMode. |
| `DSP::getParameterInfo` | The web build has no binding for the parameter description struct, so DSP parameter metadata is left out. Parameter values round-trip by index through Dsp.getParameter, setParameter, and their Int and Bool variants on every target. |
| `DSP::getUserData` | Userdata on FMOD objects is left out because the binding's handle table already carries object identity. Keep your own map from the handle to your data, handles are ints and work as keys. |
| `DSP::setCallback` | Haxe code cannot run on FMOD's mixer thread, so DSP callbacks cannot be delivered. Poll the unit from the game loop with Dsp.getMetering() or Dsp.getFftSpectrum() instead. |
| `DSP::setChannelFormat` | Channel format control on individual units is left out, and every unit runs in the mixer's format from FmodSettings.speakerMode. |
| `DSP::setUserData` | Userdata on FMOD objects is left out because the binding's handle table already carries object identity. Keep your own map from the handle to your data, handles are ints and work as keys. |
| `DSP::showConfigDialog` | Plugin configuration dialogs belong to third-party plugins, which haxefmod does not load. Built-in DSP parameters are set through Dsp.setParameter. |

## DSPConnection

| Function | Why |
|---|---|
| `DSPConnection::getMixMatrix` | Per-connection mix matrices are left out. DspConnection.getMix reads the connection volume. |
| `DSPConnection::getUserData` | Userdata on FMOD objects is left out because the binding's handle table already carries object identity. Keep your own map from the handle to your data, handles are ints and work as keys. |
| `DSPConnection::setMixMatrix` | Per-connection mix matrices are left out. DspConnection.setMix sets the connection volume, and Channel.setMixMatrix or ChannelGroup.setMixMatrix shape the speaker mix. |
| `DSPConnection::setUserData` | Userdata on FMOD objects is left out because the binding's handle table already carries object identity. Keep your own map from the handle to your data, handles are ints and work as keys. |

## Geometry

| Function | Why |
|---|---|
| `Geometry::getUserData` | Userdata on FMOD objects is left out because the binding's handle table already carries object identity. Keep your own map from the handle to your data, handles are ints and work as keys. |
| `Geometry::setUserData` | Userdata on FMOD objects is left out because the binding's handle table already carries object identity. Keep your own map from the handle to your data, handles are ints and work as keys. |

## Global functions

| Function | Why |
|---|---|
| `file_close` | File callbacks belong to the custom file system integration, which is left out because they would run on FMOD threads. StudioSystem.loadBankFile, loadBankMemory, CoreSound.create, and CoreSound.fromPcm are the supported loading paths. |
| `File_GetDiskBusy` | Disk busy flags belong to the custom file system integration, which is left out because IO callbacks would run on FMOD threads. |
| `file_open` | File callbacks belong to the custom file system integration, which is left out because they would run on FMOD threads. StudioSystem.loadBankFile, loadBankMemory, CoreSound.create, and CoreSound.fromPcm are the supported loading paths. |
| `file_read` | File callbacks belong to the custom file system integration, which is left out because they would run on FMOD threads. StudioSystem.loadBankFile, loadBankMemory, CoreSound.create, and CoreSound.fromPcm are the supported loading paths. |
| `file_seek` | File callbacks belong to the custom file system integration, which is left out because they would run on FMOD threads. StudioSystem.loadBankFile, loadBankMemory, CoreSound.create, and CoreSound.fromPcm are the supported loading paths. |
| `file_seek` | File callbacks belong to the custom file system integration, which is left out because they would run on FMOD threads. StudioSystem.loadBankFile, loadBankMemory, CoreSound.create, and CoreSound.fromPcm are the supported loading paths. |
| `File_SetDiskBusy` | Disk busy flags belong to the custom file system integration, which is left out because IO callbacks would run on FMOD threads. |
| `FMOD_Android_JNI_Close` | Android is not a supported platform, haxefmod targets desktop and web only. |
| `FMOD_Android_JNI_Init` | Android is not a supported platform, haxefmod targets desktop and web only. |
| `getValue` | Direct wasm heap access belongs to hand-written JS glue, which the haxefmod web runtime keeps inside the binding. Getters return values directly, and struct getters return typedefs. |
| `Memory_Free` | Haxe code never allocates on the FMOD heap, so there is nothing to free. Release handles with the release() method of the object that created them. |
| `Memory_GetStats` | Global allocator statistics are left out with the custom allocator hooks. StudioSystem.getMemoryUsage() reports the memory held by Studio objects. |
| `Memory_Initialize` | Custom allocators would be called from FMOD threads, which no Haxe target can do safely, and the library owns init. FMOD uses its default allocator on every target. |
| `ReadFile` | Reading files from the wasm file system is left out with the custom file system integration. StudioSystem.loadBankMemory() loads a bank from bytes you already hold, and CoreSound.fromPcm() plays raw PCM you already hold. |
| `setValue` | Direct wasm heap access belongs to hand-written JS glue, which the haxefmod web runtime keeps inside the binding. Values cross into FMOD through the typed haxefmod methods. |
| `Thread_SetAttributes` | Thread affinity and priority are init-time engine settings the library keeps at FMOD's defaults, and the web build has no threads to configure. |

## Reverb3D

| Function | Why |
|---|---|
| `Reverb3D::getUserData` | Userdata on FMOD objects is left out because the binding's handle table already carries object identity. Keep your own map from the handle to your data, handles are ints and work as keys. |
| `Reverb3D::setUserData` | Userdata on FMOD objects is left out because the binding's handle table already carries object identity. Keep your own map from the handle to your data, handles are ints and work as keys. |

## Sound

| Function | Why |
|---|---|
| `Sound::get3DConeSettings` | Not exposed on the sound. Cone settings are bound on the channel and the group, so read them with Channel.get3DConeSettings or ChannelGroup.get3DConeSettings. |
| `Sound::get3DMinMaxDistance` | Not exposed on the sound. Min and max distance are bound on the channel and the group, so read them with Channel.get3DMinMaxDistance or ChannelGroup.get3DMinMaxDistance. |
| `Sound::getMusicChannelVolume` | Tracker music channel control (MOD, S3M, XM per-channel access) is left out. Volume and pitch of the whole sound are set on its Channel. |
| `Sound::getMusicNumChannels` | Tracker music channel control (MOD, S3M, XM per-channel access) is left out. Volume and pitch of the whole sound are set on its Channel. |
| `Sound::getMusicSpeed` | Tracker music channel control (MOD, S3M, XM per-channel access) is left out. Volume and pitch of the whole sound are set on its Channel. |
| `Sound::getNumSubSounds` | Subsound and tag access are container internals with no cross-platform story. Load each file as its own CoreSound, or play authored content from banks. |
| `Sound::getNumTags` | Subsound and tag access are container internals with no cross-platform story. Load each file as its own CoreSound, or play authored content from banks. |
| `Sound::getSubSound` | Subsound and tag access are container internals with no cross-platform story. Load each file as its own CoreSound, or play authored content from banks. |
| `Sound::getSubSoundParent` | Subsound and tag access are container internals with no cross-platform story. Load each file as its own CoreSound, or play authored content from banks. |
| `Sound::getTag` | Subsound and tag access are container internals with no cross-platform story. Load each file as its own CoreSound, or play authored content from banks. |
| `Sound::getUserData` | Userdata on FMOD objects is left out because the binding's handle table already carries object identity. Keep your own map from the handle to your data, handles are ints and work as keys. |
| `Sound::set3DConeSettings` | Not exposed on the sound. Cone settings are bound on the channel and the group, so set them with Channel.set3DConeSettings after play or with ChannelGroup.set3DConeSettings for a whole group. |
| `Sound::set3DMinMaxDistance` | Not exposed on the sound. Min and max distance are bound on the channel and the group, so set them with Channel.set3DMinMaxDistance after play or with ChannelGroup.set3DMinMaxDistance for a whole group. |
| `Sound::setMusicChannelVolume` | Tracker music channel control (MOD, S3M, XM per-channel access) is left out. Volume and pitch of the whole sound are set on its Channel. |
| `Sound::setMusicSpeed` | Tracker music channel control (MOD, S3M, XM per-channel access) is left out. Volume and pitch of the whole sound are set on its Channel. |

## SoundGroup

| Function | Why |
|---|---|
| `SoundGroup::getName` | The name is the one you passed to SoundGroup.create, so keep it on the game side. SoundGroup.master() is the default group. |
| `SoundGroup::getSound` | Enumerating a group's sounds is left out. SoundGroup.getSoundCount() and getPlayingCount() report the totals, and the game keeps the CoreSound handles it assigned with CoreSound.setSoundGroup. |
| `SoundGroup::getUserData` | Userdata on FMOD objects is left out because the binding's handle table already carries object identity. Keep your own map from the handle to your data, handles are ints and work as keys. |
| `SoundGroup::setUserData` | Userdata on FMOD objects is left out because the binding's handle table already carries object identity. Keep your own map from the handle to your data, handles are ints and work as keys. |

## Studio::Bank

| Function | Why |
|---|---|
| `Studio::Bank::getUserData` | Userdata on FMOD objects is left out because the binding's handle table already carries object identity. Keep your own map from the handle to your data, handles are ints and work as keys. |
| `Studio::Bank::setUserData` | Userdata on FMOD objects is left out because the binding's handle table already carries object identity. Keep your own map from the handle to your data, handles are ints and work as keys. |

## Studio::Bus

| Function | Why |
|---|---|
| `Studio::Bus::getPortIndex` | Console port APIs are left out because haxefmod supports desktop and web only. Route audio through ChannelGroup and Bus instead. |
| `Studio::Bus::setPortIndex` | Console port APIs are left out because haxefmod supports desktop and web only. Route audio through ChannelGroup and Bus instead. |

## Studio::CommandReplay

| Function | Why |
|---|---|
| `Studio::CommandReplay::getCommandAtTime` | Command replay inspection and tool hooks are FMOD tooling integration points. Command capture and basic playback are bound through StudioSystem.startCommandCapture, stopCommandCapture, loadCommandReplay, and CommandReplay.start, stop, setPaused, seekToTime, and getLength. |
| `Studio::CommandReplay::getCommandCount` | Command replay inspection and tool hooks are FMOD tooling integration points. Command capture and basic playback are bound through StudioSystem.startCommandCapture, stopCommandCapture, loadCommandReplay, and CommandReplay.start, stop, setPaused, seekToTime, and getLength. |
| `Studio::CommandReplay::getCommandInfo` | Command replay inspection and tool hooks are FMOD tooling integration points. Command capture and basic playback are bound through StudioSystem.startCommandCapture, stopCommandCapture, loadCommandReplay, and CommandReplay.start, stop, setPaused, seekToTime, and getLength. |
| `Studio::CommandReplay::getCommandString` | Command replay inspection and tool hooks are FMOD tooling integration points. Command capture and basic playback are bound through StudioSystem.startCommandCapture, stopCommandCapture, loadCommandReplay, and CommandReplay.start, stop, setPaused, seekToTime, and getLength. |
| `Studio::CommandReplay::getCurrentCommand` | Command replay inspection and tool hooks are FMOD tooling integration points. Command capture and basic playback are bound through StudioSystem.startCommandCapture, stopCommandCapture, loadCommandReplay, and CommandReplay.start, stop, setPaused, seekToTime, and getLength. |
| `Studio::CommandReplay::getPlaybackState` | Command replay inspection and tool hooks are FMOD tooling integration points. Command capture and basic playback are bound through StudioSystem.startCommandCapture, stopCommandCapture, loadCommandReplay, and CommandReplay.start, stop, setPaused, seekToTime, and getLength. |
| `Studio::CommandReplay::getUserData` | Userdata on FMOD objects is left out because the binding's handle table already carries object identity. Keep your own map from the handle to your data, handles are ints and work as keys. |
| `Studio::CommandReplay::seekToCommand` | Command replay inspection and tool hooks are FMOD tooling integration points. Command capture and basic playback are bound through StudioSystem.startCommandCapture, stopCommandCapture, loadCommandReplay, and CommandReplay.start, stop, setPaused, seekToTime, and getLength. |
| `Studio::CommandReplay::setBankPath` | Command replay inspection and tool hooks are FMOD tooling integration points. Command capture and basic playback are bound through StudioSystem.startCommandCapture, stopCommandCapture, loadCommandReplay, and CommandReplay.start, stop, setPaused, seekToTime, and getLength. |
| `Studio::CommandReplay::setCreateInstanceCallback` | Command replay inspection and tool hooks are FMOD tooling integration points. Command capture and basic playback are bound through StudioSystem.startCommandCapture, stopCommandCapture, loadCommandReplay, and CommandReplay.start, stop, setPaused, seekToTime, and getLength. |
| `Studio::CommandReplay::setFrameCallback` | Command replay inspection and tool hooks are FMOD tooling integration points. Command capture and basic playback are bound through StudioSystem.startCommandCapture, stopCommandCapture, loadCommandReplay, and CommandReplay.start, stop, setPaused, seekToTime, and getLength. |
| `Studio::CommandReplay::setLoadBankCallback` | Command replay inspection and tool hooks are FMOD tooling integration points. Command capture and basic playback are bound through StudioSystem.startCommandCapture, stopCommandCapture, loadCommandReplay, and CommandReplay.start, stop, setPaused, seekToTime, and getLength. |
| `Studio::CommandReplay::setUserData` | Userdata on FMOD objects is left out because the binding's handle table already carries object identity. Keep your own map from the handle to your data, handles are ints and work as keys. |

## Studio::EventDescription

| Function | Why |
|---|---|
| `Studio::EventDescription::getUserData` | Userdata on FMOD objects is left out because the binding's handle table already carries object identity. Keep your own map from the handle to your data, handles are ints and work as keys. |
| `Studio::EventDescription::setCallback` | Not exposed on the description. Callbacks are registered per instance with EventInstance.setCallback (or FmodSound.onEvent), which delivers typed EventCallbackData from FmodManager.Update() instead of from an FMOD thread. |
| `Studio::EventDescription::setUserData` | Userdata on FMOD objects is left out because the binding's handle table already carries object identity. Keep your own map from the handle to your data, handles are ints and work as keys. |

## Studio::System

| Function | Why |
|---|---|
| `Studio::System::getAdvancedSettings` | FMOD_STUDIO_ADVANCEDSETTINGS is left at its defaults on every target. FmodRuntime.settings() returns the resolved FmodSettings the engine started with. |
| `Studio::System::getSoundInfo` | Audio table lookup is left out because the programmer sound flow hands the key to FMOD instead. EventInstance.assignProgrammerSound(key) names the audio table entry or file to play, and the binding resolves it. Programmer sounds are native only (unsupported in HTML5), where assignProgrammerSound returns FMOD_ERR_UNSUPPORTED. |
| `Studio::System::getUserData` | Userdata on FMOD objects is left out because the binding's handle table already carries object identity. Keep your own map from the handle to your data, handles are ints and work as keys. |
| `Studio::System::loadBankCustom` | Custom file systems need IO callbacks that run on FMOD threads, which no Haxe target can do safely. StudioSystem.loadBankFile and loadBankMemory are the supported bank paths, and CoreSound.create and CoreSound.fromPcm are the sound paths. |
| `Studio::System::registerPlugin` | Not bound yet. Loading a prebuilt plugin binary runs the plugin's own code on FMOD's threads with no Haxe involved, so nothing rules it out, it is deferred until CI has a plugin binary to test against. Until then a Studio project that uses plugin effects cannot load them from haxefmod. The 33 built-in DSP types are bound through Dsp.create. HTML5 has no plugin host (unsupported in HTML5), so the call will return FMOD_ERR_UNSUPPORTED there once it lands. |
| `Studio::System::setAdvancedSettings` | The library owns init, and FMOD_STUDIO_ADVANCEDSETTINGS is left at its defaults on every target. The init-time options haxefmod supports are the FmodSettings fields and the haxefmod_* compile-time defines. |
| `Studio::System::setUserData` | Userdata on FMOD objects is left out because the binding's handle table already carries object identity. Keep your own map from the handle to your data, handles are ints and work as keys. |
| `Studio::System::unregisterPlugin` | Not bound yet. Loading a prebuilt plugin binary runs the plugin's own code on FMOD's threads with no Haxe involved, so nothing rules it out, it is deferred until CI has a plugin binary to test against. Until then a Studio project that uses plugin effects cannot load them from haxefmod. The 33 built-in DSP types are bound through Dsp.create. HTML5 has no plugin host (unsupported in HTML5), so the call will return FMOD_ERR_UNSUPPORTED there once it lands. |

## System

| Function | Why |
|---|---|
| `System::attachChannelGroupToPort` | Console port APIs are left out because haxefmod supports desktop and web only. Route audio through ChannelGroup and Bus instead. |
| `System::attachFileSystem` | Custom file systems need IO callbacks that run on FMOD threads, which no Haxe target can do safely. StudioSystem.loadBankFile and loadBankMemory are the supported bank paths, and CoreSound.create and CoreSound.fromPcm are the sound paths. |
| `System::createDSP` | A DSP description carries callbacks that would run on FMOD's mixer thread, which no Haxe target can do, so creating a unit from a description stays out for good. All 33 built-in DSP types are created with Dsp.create(type). |
| `System::createDSPByPlugin` | Not bound yet. Loading a prebuilt plugin binary runs the plugin's own code on FMOD's threads with no Haxe involved, so nothing rules it out, it is deferred until CI has a plugin binary to test against. Until then a Studio project that uses plugin effects cannot load them from haxefmod. The 33 built-in DSP types are bound through Dsp.create. HTML5 has no plugin host (unsupported in HTML5), so the call will return FMOD_ERR_UNSUPPORTED there once it lands. |
| `System::detachChannelGroupFromPort` | Console port APIs are left out because haxefmod supports desktop and web only. Route audio through ChannelGroup and Bus instead. |
| `System::getAdvancedSettings` | FMOD_ADVANCEDSETTINGS is left at its defaults on every target. FmodRuntime.settings() returns the resolved FmodSettings the engine started with. |
| `System::getChannel` | Channels are reached through the handle returned by CoreSound.play, PcmStream.play, or Dsp.play rather than by pool index, and ChannelGroup.getChannel(index) enumerates the channels in a group. |
| `System::getDefaultMixMatrix` | Speaker geometry and mix matrix readback are left out. Channel.setMixMatrix and ChannelGroup.setMixMatrix accept the matrix you build yourself. |
| `System::getDSPInfoByPlugin` | Not bound yet. Loading a prebuilt plugin binary runs the plugin's own code on FMOD's threads with no Haxe involved, so nothing rules it out, it is deferred until CI has a plugin binary to test against. Until then a Studio project that uses plugin effects cannot load them from haxefmod. The 33 built-in DSP types are bound through Dsp.create. HTML5 has no plugin host (unsupported in HTML5), so the call will return FMOD_ERR_UNSUPPORTED there once it lands. |
| `System::getDSPInfoByType` | DSP metadata lookup is left out with the plugin APIs. Dsp.getName() and Dsp.getType() report what a created unit is, and Dsp.getParameterCount() reports how many parameters it has. |
| `System::getFileUsage` | File IO statistics are a tooling diagnostic with no cross-platform story, and the web build has no file system to count. StudioSystem.getBufferUsage() reports the Studio command and handle buffer usage. |
| `System::getNestedPlugin` | Not bound yet. Loading a prebuilt plugin binary runs the plugin's own code on FMOD's threads with no Haxe involved, so nothing rules it out, it is deferred until CI has a plugin binary to test against. Until then a Studio project that uses plugin effects cannot load them from haxefmod. The 33 built-in DSP types are bound through Dsp.create. HTML5 has no plugin host (unsupported in HTML5), so the call will return FMOD_ERR_UNSUPPORTED there once it lands. |
| `System::getNetworkProxy` | Network streaming is left out, the library keeps FMOD's default network settings, and CoreSound.create opens local files only. |
| `System::getNetworkTimeout` | Network streaming is left out, the library keeps FMOD's default network settings, and CoreSound.create opens local files only. |
| `System::getNumNestedPlugins` | Not bound yet. Loading a prebuilt plugin binary runs the plugin's own code on FMOD's threads with no Haxe involved, so nothing rules it out, it is deferred until CI has a plugin binary to test against. Until then a Studio project that uses plugin effects cannot load them from haxefmod. The 33 built-in DSP types are bound through Dsp.create. HTML5 has no plugin host (unsupported in HTML5), so the call will return FMOD_ERR_UNSUPPORTED there once it lands. |
| `System::getNumPlugins` | Not bound yet. Loading a prebuilt plugin binary runs the plugin's own code on FMOD's threads with no Haxe involved, so nothing rules it out, it is deferred until CI has a plugin binary to test against. Until then a Studio project that uses plugin effects cannot load them from haxefmod. The 33 built-in DSP types are bound through Dsp.create. HTML5 has no plugin host (unsupported in HTML5), so the call will return FMOD_ERR_UNSUPPORTED there once it lands. |
| `System::getOutput` | The library owns init and keeps FMOD's default output type for the platform. Output device selection is bound through CoreSystem.getDriverCount, getDriverName, and setDriver. |
| `System::getOutputByPlugin` | Output plugins are not loadable from haxefmod, and the library keeps FMOD's default output type for the platform. |
| `System::getOutputHandle` | Haxe code never holds a raw pointer, and the library keeps FMOD's default output type, so there is no platform handle to hand back. |
| `System::getPluginHandle` | Not bound yet. Loading a prebuilt plugin binary runs the plugin's own code on FMOD's threads with no Haxe involved, so nothing rules it out, it is deferred until CI has a plugin binary to test against. Until then a Studio project that uses plugin effects cannot load them from haxefmod. The 33 built-in DSP types are bound through Dsp.create. HTML5 has no plugin host (unsupported in HTML5), so the call will return FMOD_ERR_UNSUPPORTED there once it lands. |
| `System::getPluginInfo` | Not bound yet. Loading a prebuilt plugin binary runs the plugin's own code on FMOD's threads with no Haxe involved, so nothing rules it out, it is deferred until CI has a plugin binary to test against. Until then a Studio project that uses plugin effects cannot load them from haxefmod. The 33 built-in DSP types are bound through Dsp.create. HTML5 has no plugin host (unsupported in HTML5), so the call will return FMOD_ERR_UNSUPPORTED there once it lands. |
| `System::getSpeakerModeChannels` | Speaker geometry APIs are left out. CoreSystem.getSoftwareFormat() reports the speaker mode and raw speaker count the mixer runs with. |
| `System::getSpeakerPosition` | Speaker geometry APIs are left out, and the mixer runs with FMOD's default speaker positions for the speaker mode in FmodSettings.speakerMode. |
| `System::getUserData` | Userdata on FMOD objects is left out because the binding's handle table already carries object identity. Keep your own map from the handle to your data, handles are ints and work as keys. |
| `System::loadPlugin` | Not bound yet. Loading a prebuilt plugin binary runs the plugin's own code on FMOD's threads with no Haxe involved, so nothing rules it out, it is deferred until CI has a plugin binary to test against. Until then a Studio project that uses plugin effects cannot load them from haxefmod. The 33 built-in DSP types are bound through Dsp.create. HTML5 has no plugin host (unsupported in HTML5), so the call will return FMOD_ERR_UNSUPPORTED there once it lands. |
| `System::lockDSP` | Haxe code cannot run on FMOD's mixer thread, so there is nothing to lock the DSP graph against. Effects are added and removed with Dsp, Channel.addDsp, and ChannelGroup.addDsp without locking. |
| `System::registerCodec` | Registering a plugin from a description hands FMOD callbacks that would run on its mixer and streaming threads, which no Haxe target can do, so this stays out for good. Loading a prebuilt plugin binary with System::loadPlugin is a separate case that is deferred rather than impossible. The 33 built-in DSP types are bound through Dsp.create. |
| `System::registerDSP` | Registering a plugin from a description hands FMOD callbacks that would run on its mixer and streaming threads, which no Haxe target can do, so this stays out for good. Loading a prebuilt plugin binary with System::loadPlugin is a separate case that is deferred rather than impossible. The 33 built-in DSP types are bound through Dsp.create. |
| `System::registerOutput` | Registering a plugin from a description hands FMOD callbacks that would run on its mixer and streaming threads, which no Haxe target can do, so this stays out for good. Loading a prebuilt plugin binary with System::loadPlugin is a separate case that is deferred rather than impossible. The 33 built-in DSP types are bound through Dsp.create. |
| `System::set3DRolloffCallback` | Haxe code cannot run on FMOD's mixer thread, so a rolloff callback cannot be delivered. The built-in rolloff modes are set through Channel.setMode and ChannelGroup.setMode. |
| `System::setAdvancedSettings` | The library owns init, and FMOD_ADVANCEDSETTINGS is left at its defaults on every target. The init-time options haxefmod supports are the FmodSettings fields and the haxefmod_* compile-time defines. |
| `System::setFileSystem` | Custom file systems need IO callbacks that run on FMOD threads, which no Haxe target can do safely. StudioSystem.loadBankFile and loadBankMemory are the supported bank paths, and CoreSound.create and CoreSound.fromPcm are the sound paths. |
| `System::setNetworkProxy` | Network streaming is left out, the library keeps FMOD's default network settings, and CoreSound.create opens local files only. |
| `System::setNetworkTimeout` | Network streaming is left out, the library keeps FMOD's default network settings, and CoreSound.create opens local files only. |
| `System::setOutputByPlugin` | Output plugins are third-party code that would run on FMOD threads, which no Haxe target can do safely. The library keeps FMOD's default output type for the platform. |
| `System::setPluginPath` | Not bound yet. Loading a prebuilt plugin binary runs the plugin's own code on FMOD's threads with no Haxe involved, so nothing rules it out, it is deferred until CI has a plugin binary to test against. Until then a Studio project that uses plugin effects cannot load them from haxefmod. The 33 built-in DSP types are bound through Dsp.create. HTML5 has no plugin host (unsupported in HTML5), so the call will return FMOD_ERR_UNSUPPORTED there once it lands. |
| `System::setSpeakerPosition` | Speaker geometry APIs are left out, and the mixer runs with FMOD's default speaker positions for the speaker mode in FmodSettings.speakerMode. |
| `System::setUserData` | Userdata on FMOD objects is left out because the binding's handle table already carries object identity. Keep your own map from the handle to your data, handles are ints and work as keys. |
| `System::unloadPlugin` | Not bound yet. Loading a prebuilt plugin binary runs the plugin's own code on FMOD's threads with no Haxe involved, so nothing rules it out, it is deferred until CI has a plugin binary to test against. Until then a Studio project that uses plugin effects cannot load them from haxefmod. The 33 built-in DSP types are bound through Dsp.create. HTML5 has no plugin host (unsupported in HTML5), so the call will return FMOD_ERR_UNSUPPORTED there once it lands. |
| `System::unlockDSP` | Haxe code cannot run on FMOD's mixer thread, so the DSP graph is never locked from Haxe. Effects are added and removed with Dsp, Channel.addDsp, and ChannelGroup.addDsp without locking. |

