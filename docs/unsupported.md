# Unsupported functions

The 40 functions of the FMOD API that haxefmod 2.0.0 cannot bind, with the reason for each. Nearly all of them hand FMOD a callback to run on its own threads, which no Haxe target can host, and the rest belong to platforms the library does not ship for or return raw pointers. Generated from `extension/functions.md` by `ci/haxe-bindings.py`, so this page and the Haxe tab of the browser extension always agree. [Coverage](coverage.md) lists everything that is bound.

If one of these blocks a real use case, open an issue describing it. A workaround at the library level is sometimes possible even when the function itself is not.

## DSP

| Function | Why |
|---|---|
| `DSP::setCallback` | Cannot be bound. FMOD runs the callback on its mixer thread, and no Haxe target can execute code there. Poll the unit from the game loop with Dsp.getMetering() or Dsp.getFftSpectrum() instead. |
| `DSP::showConfigDialog` | Cannot be bound. It takes a raw operating system window handle, which has no meaning in Haxe. Plugin and built-in DSP parameters are set through Dsp.setParameter. |

## Global functions

| Function | Why |
|---|---|
| `file_close` | Cannot be bound. FMOD runs file callbacks on its streaming and loading threads, and no Haxe target can execute code there. StudioSystem.loadBankFile, loadBankMemory, Sound.create, and Sound.fromPcm are the loading paths. |
| `File_GetDiskBusy` | Cannot be bound. The disk busy flag belongs to the custom file system callbacks, which FMOD runs on its streaming thread, and no Haxe target can execute code there. |
| `file_open` | Cannot be bound. FMOD runs file callbacks on its streaming and loading threads, and no Haxe target can execute code there. StudioSystem.loadBankFile, loadBankMemory, Sound.create, and Sound.fromPcm are the loading paths. |
| `file_read` | Cannot be bound. FMOD runs file callbacks on its streaming and loading threads, and no Haxe target can execute code there. StudioSystem.loadBankFile, loadBankMemory, Sound.create, and Sound.fromPcm are the loading paths. |
| `file_seek` | Cannot be bound. FMOD runs file callbacks on its streaming and loading threads, and no Haxe target can execute code there. StudioSystem.loadBankFile, loadBankMemory, Sound.create, and Sound.fromPcm are the loading paths. |
| `file_seek` | Cannot be bound. FMOD runs file callbacks on its streaming and loading threads, and no Haxe target can execute code there. StudioSystem.loadBankFile, loadBankMemory, Sound.create, and Sound.fromPcm are the loading paths. |
| `File_SetDiskBusy` | Cannot be bound. The disk busy flag belongs to the custom file system callbacks, which FMOD runs on its streaming thread, and no Haxe target can execute code there. |
| `FMOD_Android_JNI_Close` | Cannot be bound. This is an Android JNI entry point and haxefmod targets desktop and web only. |
| `FMOD_Android_JNI_Init` | Cannot be bound. This is an Android JNI entry point and haxefmod targets desktop and web only. |
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

## Studio::Bus

| Function | Why |
|---|---|
| `Studio::Bus::getPortIndex` | Cannot be bound. This is a console port API and haxefmod targets desktop and web only. Route audio through ChannelGroup and Bus instead. |
| `Studio::Bus::setPortIndex` | Cannot be bound. This is a console port API and haxefmod targets desktop and web only. Route audio through ChannelGroup and Bus instead. |

## Studio::CommandReplay

| Function | Why |
|---|---|
| `Studio::CommandReplay::setCreateInstanceCallback` | Cannot be bound. FMOD runs the callback on its update thread while the replay plays, and no Haxe target can execute code there. CommandReplay.getCommandInfo, getCommandString, and getCommandAtTime read the same commands from the game thread. |
| `Studio::CommandReplay::setFrameCallback` | Cannot be bound. FMOD runs the callback on its update thread while the replay plays, and no Haxe target can execute code there. CommandReplay.getCommandInfo, getCommandString, and getCommandAtTime read the same commands from the game thread. |
| `Studio::CommandReplay::setLoadBankCallback` | Cannot be bound. FMOD runs the callback on its update thread while the replay plays, and no Haxe target can execute code there. CommandReplay.getCommandInfo, getCommandString, and getCommandAtTime read the same commands from the game thread. |

## Studio::System

| Function | Why |
|---|---|
| `Studio::System::loadBankCustom` | Cannot be bound. A custom file system is a set of callbacks that FMOD runs on its streaming and loading threads, and no Haxe target can execute code there. StudioSystem.loadBankFile and loadBankMemory are the bank paths, and Sound.create and Sound.fromPcm are the sound paths. |
| `Studio::System::registerPlugin` | Cannot be bound. It takes a DSP description struct whose callbacks FMOD runs on its mixer thread, and no Haxe target can execute code there. A prebuilt plugin binary loads with StudioSystem.loadPlugin, which makes its effects available to Studio events. |
| `Studio::System::unregisterPlugin` | Cannot be bound. It names a plugin registered from a description struct, and that registration cannot be bound because its callbacks would run on FMOD's mixer thread. A plugin loaded with StudioSystem.loadPlugin is unloaded with StudioSystem.unloadPlugin. |

## System

| Function | Why |
|---|---|
| `System::attachFileSystem` | Cannot be bound. A custom file system is a set of callbacks that FMOD runs on its streaming and loading threads, and no Haxe target can execute code there. StudioSystem.loadBankFile and loadBankMemory are the bank paths, and Sound.create and Sound.fromPcm are the sound paths. |
| `System::createDSP` | Cannot be bound. A DSP description is a struct of callbacks that FMOD runs on its mixer thread, and no Haxe target can execute code there. All 33 built-in DSP types are created with Dsp.create(type), and a unit from a loaded plugin with Dsp.createByPlugin(handle). |
| `System::getOutputHandle` | Cannot be bound. It returns a raw operating system pointer, which has no meaning in Haxe. Output device selection goes through CoreSystem.getDriverCount, getDriverName, and setDriver. |
| `System::registerCodec` | Cannot be bound. A plugin description is a struct of callbacks that FMOD runs on its mixer and streaming threads, and no Haxe target can execute code there. A prebuilt plugin binary loads with StudioSystem.loadPlugin, and the built-in DSP types are created with Dsp.create. |
| `System::registerDSP` | Cannot be bound. A plugin description is a struct of callbacks that FMOD runs on its mixer and streaming threads, and no Haxe target can execute code there. A prebuilt plugin binary loads with StudioSystem.loadPlugin, and the built-in DSP types are created with Dsp.create. |
| `System::registerOutput` | Cannot be bound. A plugin description is a struct of callbacks that FMOD runs on its mixer and streaming threads, and no Haxe target can execute code there. A prebuilt plugin binary loads with StudioSystem.loadPlugin, and the built-in DSP types are created with Dsp.create. |
| `System::set3DRolloffCallback` | Cannot be bound. FMOD runs the callback on its mixer thread, and no Haxe target can execute code there. Channel.set3DCustomRolloff takes a curve of points instead, and the built-in rolloff modes are set through Channel.setMode and ChannelGroup.setMode. |
| `System::setFileSystem` | Cannot be bound. A custom file system is a set of callbacks that FMOD runs on its streaming and loading threads, and no Haxe target can execute code there. StudioSystem.loadBankFile and loadBankMemory are the bank paths, and Sound.create and Sound.fromPcm are the sound paths. |

