# Unsupported functions

The 67 functions of the FMOD API that haxefmod 3.0.0 cannot bind, with the reason for each. Nearly all of them hand FMOD a callback to run on its own threads, which no Haxe target can host, and the rest belong to platforms the library does not ship for or return raw pointers. Generated from `extension/functions.md` by `ci/haxe-bindings.py`, so this page and the Haxe tab of the browser extension always agree. [Coverage](coverage.md) lists everything that is bound.

If one of these blocks a real use case, open an issue describing it. A workaround at the library level is sometimes possible even when the function itself is not.

## ChannelControl

| Function | Why |
|---|---|
| `ChannelControl::getSystemObject` | No Haxe declaration, another call plays this role. haxefmod has one core system, and haxefmod.core.CoreSystem reaches it directly, so no object needs to hand it back. |

## DSP

| Function | Why |
|---|---|
| `DSP::getSystemObject` | No Haxe declaration, another call plays this role. haxefmod has one core system, and haxefmod.core.CoreSystem reaches it directly, so no object needs to hand it back. |
| `DSP::setCallback` | Cannot be bound. FMOD runs the callback on its mixer thread, and no Haxe target can execute code there. Poll the unit from the game loop with Dsp.getMetering(), Dsp.getFftSpectrumInfo(), or Dsp.getParameterData() instead. |
| `DSP::showConfigDialog` | Cannot be bound. It takes a raw operating system window handle, which has no meaning in Haxe. Plugin and built-in DSP parameters are set through Dsp.setParameter. |

## Global functions

| Function | Why |
|---|---|
| `file_close` | Cannot be bound. FMOD runs file callbacks on its streaming and loading threads, and no Haxe target can execute code there. StudioSystem.loadBankFile, loadBankMemory, Sound.create, and Sound.fromPcm are the loading paths. |
| `File_GetDiskBusy` | No Haxe declaration, another call plays this role. The global disk busy flag is not bound. Sound.getOpenStateInfo() reports diskBusy per sound, which is the value a game polls while a stream fills. |
| `file_open` | Cannot be bound. FMOD runs file callbacks on its streaming and loading threads, and no Haxe target can execute code there. StudioSystem.loadBankFile, loadBankMemory, Sound.create, and Sound.fromPcm are the loading paths. |
| `file_read` | Cannot be bound. FMOD runs file callbacks on its streaming and loading threads, and no Haxe target can execute code there. StudioSystem.loadBankFile, loadBankMemory, Sound.create, and Sound.fromPcm are the loading paths. |
| `file_seek` | Cannot be bound. FMOD runs file callbacks on its streaming and loading threads, and no Haxe target can execute code there. StudioSystem.loadBankFile, loadBankMemory, Sound.create, and Sound.fromPcm are the loading paths. |
| `file_seek` | Cannot be bound. FMOD runs file callbacks on its streaming and loading threads, and no Haxe target can execute code there. StudioSystem.loadBankFile, loadBankMemory, Sound.create, and Sound.fromPcm are the loading paths. |
| `File_SetDiskBusy` | Cannot be bound. The disk busy flag belongs to the custom file system callbacks, which FMOD runs on its streaming thread, and no Haxe target can execute code there. |
| `FMOD_Android_JNI_Close` | Cannot be bound. This is an Android JNI entry point and haxefmod targets desktop and web only. |
| `FMOD_Android_JNI_Init` | Cannot be bound. This is an Android JNI entry point and haxefmod targets desktop and web only. |
| `FS_createPreloadedFile` | No Haxe declaration, another call plays this role. haxefmod does this for you on HTML5. |
| `FSBANK_RESULT` | Cannot be bound. FSBank is FMOD's offline bank encoder, shipped as a separate tool library outside the runtime SDK. haxefmod links the runtime only, and banks are built with FMOD Studio. |
| `FSBANK_RESULT` | Cannot be bound. FSBank is FMOD's offline bank encoder, shipped as a separate tool library outside the runtime SDK. haxefmod links the runtime only, and banks are built with FMOD Studio. |
| `FSBANK_RESULT` | Cannot be bound. FSBank is FMOD's offline bank encoder, shipped as a separate tool library outside the runtime SDK. haxefmod links the runtime only, and banks are built with FMOD Studio. |
| `FSBANK_RESULT` | Cannot be bound. FSBank is FMOD's offline bank encoder, shipped as a separate tool library outside the runtime SDK. haxefmod links the runtime only, and banks are built with FMOD Studio. |
| `FSBANK_RESULT` | Cannot be bound. FSBank is FMOD's offline bank encoder, shipped as a separate tool library outside the runtime SDK. haxefmod links the runtime only, and banks are built with FMOD Studio. |
| `FSBANK_RESULT` | Cannot be bound. FSBank is FMOD's offline bank encoder, shipped as a separate tool library outside the runtime SDK. haxefmod links the runtime only, and banks are built with FMOD Studio. |
| `FSBANK_RESULT` | Cannot be bound. FSBank is FMOD's offline bank encoder, shipped as a separate tool library outside the runtime SDK. haxefmod links the runtime only, and banks are built with FMOD Studio. |
| `FSBANK_RESULT` | Cannot be bound. FSBank is FMOD's offline bank encoder, shipped as a separate tool library outside the runtime SDK. haxefmod links the runtime only, and banks are built with FMOD Studio. |
| `FSBANK_RESULT` | Cannot be bound. FSBank is FMOD's offline bank encoder, shipped as a separate tool library outside the runtime SDK. haxefmod links the runtime only, and banks are built with FMOD Studio. |
| `getValue` | Cannot be bound. This reads and writes the wasm heap through a raw address, which has no meaning in Haxe. Values cross into FMOD through the typed haxefmod methods, and getters return values directly. |
| `Memory_Free` | Cannot be bound. It frees a raw pointer from FMOD's heap, which has no meaning in Haxe, and Haxe code never receives one. Release handles with the release() method of the object that created them. |
| `ReadFile` | Cannot be bound. It returns a raw wasm heap address, which has no meaning in Haxe. StudioSystem.loadBankMemory() loads a bank from bytes you already hold, and Sound.fromPcm() plays raw PCM you already hold. |
| `setValue` | Cannot be bound. This reads and writes the wasm heap through a raw address, which has no meaning in Haxe. Values cross into FMOD through the typed haxefmod methods, and getters return values directly. |
| `System_Create` | No Haxe declaration, another call plays this role. haxefmod calls this for you. |

## Sound

| Function | Why |
|---|---|
| `Sound::getSystemObject` | No Haxe declaration, another call plays this role. haxefmod has one core system, and haxefmod.core.CoreSystem reaches it directly, so no object needs to hand it back. |
| `Sound::lock` | Cannot be bound. It returns a raw pointer into the sample buffer, which has no meaning in Haxe. Sound.readData covers reading, it copies decoded PCM out of a sound opened with the openOnly flag of Sound.create, and seekData moves the read cursor. Both are native only (unsupported in HTML5), where the call returns FMOD_ERR_UNSUPPORTED. |
| `Sound::unlock` | Cannot be bound. It returns a raw pointer into the sample buffer, which has no meaning in Haxe. Sound.readData covers reading, it copies decoded PCM out of a sound opened with the openOnly flag of Sound.create, and seekData moves the read cursor. Both are native only (unsupported in HTML5), where the call returns FMOD_ERR_UNSUPPORTED. |

## SoundGroup

| Function | Why |
|---|---|
| `SoundGroup::getSystemObject` | No Haxe declaration, another call plays this role. haxefmod has one core system, and haxefmod.core.CoreSystem reaches it directly, so no object needs to hand it back. |

## Studio

| Function | Why |
|---|---|
| `Studio::parseID` | No Haxe declaration, another call plays this role. FmodGuid.fromString parses the braced text into a FmodGuid, and a plain String converts on its own. |

## Studio::CommandReplay

| Function | Why |
|---|---|
| `Studio::CommandReplay::getSystem` | No Haxe declaration, another call plays this role. haxefmod has one Studio system, and StudioSystem reaches it directly, so a replay never needs to hand it back. |
| `Studio::CommandReplay::setCreateInstanceCallback` | Cannot be bound. FMOD runs the callback on its update thread while the replay plays, and no Haxe target can execute code there. CommandReplay.getCommandInfo, getCommandString, and getCommandAtTime read the same commands from the game thread. |
| `Studio::CommandReplay::setFrameCallback` | Cannot be bound. FMOD runs the callback on its update thread while the replay plays, and no Haxe target can execute code there. CommandReplay.getCommandInfo, getCommandString, and getCommandAtTime read the same commands from the game thread. |
| `Studio::CommandReplay::setLoadBankCallback` | Cannot be bound. FMOD runs the callback on its update thread while the replay plays, and no Haxe target can execute code there. CommandReplay.getCommandInfo, getCommandString, and getCommandAtTime read the same commands from the game thread. |

## Studio::EventDescription

| Function | Why |
|---|---|
| `Studio::EventDescription::getParameterDescriptionByID` | No Haxe declaration, another call plays this role. haxefmod covers this with EventDescription.getParameterDescriptionByID(). |
| `Studio::EventDescription::getParameterLabelByID` | No Haxe declaration, another call plays this role. haxefmod covers this with EventDescription.getParameterLabelByID(). |
| `Studio::EventDescription::getUserProperty` | No Haxe declaration, another call plays this role. EventDescription.getUserProperty(name) walks the properties FMOD reports by index and returns the one with that name, so the same FmodUserProperty comes back as from FMOD's lookup by name. |
| `Studio::EventDescription::setCallback` | No Haxe declaration, another call plays this role. haxefmod covers this with EventDescription.setCallback(handler, ?mask), which remembers a handler that createInstance installs on every instance made from the description from then on. |

## Studio::EventInstance

| Function | Why |
|---|---|
| `Studio::EventInstance::getSystem` | No Haxe declaration, another call plays this role. haxefmod has one Studio system, and StudioSystem reaches it directly, so an instance never needs to hand it back. |

## Studio::System

| Function | Why |
|---|---|
| `Studio::System::getParameterDescriptionByID` | No Haxe declaration, another call plays this role. haxefmod covers this with StudioSystem.getParameterDescriptionByID(). |
| `Studio::System::getParameterLabelByID` | No Haxe declaration, another call plays this role. haxefmod covers this with StudioSystem.getParameterLabelByID(). |
| `Studio::System::isValid` | No Haxe declaration, another call plays this role. haxefmod covers this with FmodManager.IsInitialized(), which reports true once the Studio system and the default banks are usable. |
| `Studio::System::loadBankCustom` | Cannot be bound. FMOD_STUDIO_BANK_INFO is declared as haxefmod.studio.Types.FmodStudioBankInfo (size, userData, userDataLength), but the load itself needs the four file callbacks the struct carries, and FMOD runs those on its streaming and loading threads, where no Haxe target can execute code. StudioSystem.loadBankFile and loadBankMemory are the bank paths, and Sound.create and Sound.fromPcm are the sound paths. |
| `Studio::System::registerPlugin` | Cannot be bound. It takes a DSP description struct whose callbacks FMOD runs on its mixer thread, and no Haxe target can execute code there. A prebuilt plugin binary loads with StudioSystem.loadPlugin, which makes its effects available to Studio events. |
| `Studio::System::unregisterPlugin` | Cannot be bound. It names a plugin registered from a description struct, and that registration cannot be bound because its callbacks would run on FMOD's mixer thread. A plugin loaded with StudioSystem.loadPlugin is unloaded with StudioSystem.unloadPlugin. |

## System

| Function | Why |
|---|---|
| `System::attachFileSystem` | Cannot be bound. A custom file system is a set of callbacks that FMOD runs on its streaming and loading threads, and no Haxe target can execute code there. StudioSystem.loadBankFile and loadBankMemory are the bank paths, and Sound.create and Sound.fromPcm are the sound paths. |
| `System::close` | No Haxe declaration, another call plays this role. haxefmod owns this. |
| `System::createDSP` | Cannot be bound. A DSP description is a struct of callbacks that FMOD runs on its mixer thread, and no Haxe target can execute code there. All 33 built-in DSP types are created with Dsp.create(type), and a unit from a loaded plugin with Dsp.createByPlugin(handle). |
| `System::createDSPConnection` | No Haxe declaration, another call plays this role. haxefmod covers this with Dsp.addInput(), which connects two units and returns the DspConnection for the link. |
| `System::createStream` | No Haxe declaration, another call plays this role. haxefmod covers streams two ways. |
| `System::get3DListenerAttributes` | No Haxe declaration, another call plays this role. haxefmod covers this with StudioSystem.getListenerAttributes(). |
| `System::get3DNumListeners` | No Haxe declaration, another call plays this role. haxefmod covers this with StudioSystem.getNumListeners(). |
| `System::getCPUUsage` | No Haxe declaration, another call plays this role. haxefmod covers this with StudioSystem.getCpuUsage(), which returns the core mixer, stream, geometry, update, and convolution figures next to the Studio update time. |
| `System::getOutputHandle` | Cannot be bound. It returns a raw operating system pointer, which has no meaning in Haxe. Output device selection goes through CoreSystem.getDriverCount, getDriverName, and setDriver. |
| `System::init` | No Haxe declaration, another call plays this role. haxefmod calls this for you. |
| `System::registerCodec` | Cannot be bound. A plugin description is a struct of callbacks that FMOD runs on its mixer and streaming threads, and no Haxe target can execute code there. A prebuilt plugin binary loads with StudioSystem.loadPlugin, and the built-in DSP types are created with Dsp.create. |
| `System::registerDSP` | Cannot be bound. A plugin description is a struct of callbacks that FMOD runs on its mixer and streaming threads, and no Haxe target can execute code there. A prebuilt plugin binary loads with StudioSystem.loadPlugin, and the built-in DSP types are created with Dsp.create. |
| `System::registerOutput` | Cannot be bound. A plugin description is a struct of callbacks that FMOD runs on its mixer and streaming threads, and no Haxe target can execute code there. A prebuilt plugin binary loads with StudioSystem.loadPlugin, and the built-in DSP types are created with Dsp.create. |
| `System::release` | No Haxe declaration, another call plays this role. haxefmod owns this. |
| `System::set3DListenerAttributes` | No Haxe declaration, another call plays this role. haxefmod covers this with StudioSystem.setListenerPosition2D() for 2D games and StudioSystem.setListenerAttributes() for the full struct. |
| `System::set3DNumListeners` | No Haxe declaration, another call plays this role. haxefmod covers this with StudioSystem.setNumListeners(). |
| `System::set3DRolloffCallback` | Cannot be bound. FMOD runs the callback on its mixer thread, and no Haxe target can execute code there. Channel.set3DCustomRolloff takes a curve of points instead, and the built-in rolloff modes are set through Channel.setMode and ChannelGroup.setMode. |
| `System::setFileSystem` | Cannot be bound. A custom file system is a set of callbacks that FMOD runs on its streaming and loading threads, and no Haxe target can execute code there. StudioSystem.loadBankFile and loadBankMemory are the bank paths, and Sound.create and Sound.fromPcm are the sound paths. |
| `System::update` | No Haxe declaration, another call plays this role. haxefmod calls this for you. |

