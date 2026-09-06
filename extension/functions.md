# functions

## channelcontrol_getsystemobject
<!-- ChannelControl::getSystemObject -->
verdict: covered haxefmod has one core system, and haxefmod.core.CoreSystem reaches it directly, so no object needs to hand it back.

## dsp_getsystemobject
<!-- DSP::getSystemObject -->
verdict: covered haxefmod has one core system, and haxefmod.core.CoreSystem reaches it directly, so no object needs to hand it back.

## dsp_setcallback
<!-- DSP::setCallback -->
verdict: cannot FMOD runs the callback on its mixer thread, and no Haxe target can execute code there. Poll the unit from the game loop with Dsp.getMetering(), Dsp.getFftSpectrumInfo(), or Dsp.getParameterData() instead.

## dsp_showconfigdialog
<!-- DSP::showConfigDialog -->
verdict: cannot It takes a raw operating system window handle, which has no meaning in Haxe. Plugin and built-in DSP parameters are set through Dsp.setParameter.

## fmod_android_jni_close
<!-- FMOD_Android_JNI_Close -->
verdict: cannot This is an Android JNI entry point and haxefmod targets desktop and web only.

## fmod_android_jni_init
<!-- FMOD_Android_JNI_Init -->
verdict: cannot This is an Android JNI entry point and haxefmod targets desktop and web only.

## fs_createpreloadedfile
<!-- FS_createPreloadedFile -->
verdict: covered haxefmod does this for you on HTML5.

## readfile
<!-- ReadFile -->
verdict: cannot It returns a raw wasm heap address, which has no meaning in Haxe. StudioSystem.loadBankMemory() loads a bank from bytes you already hold, and Sound.fromPcm() plays raw PCM you already hold.

## memory_free
<!-- Memory_Free -->
verdict: cannot It frees a raw pointer from FMOD's heap, which has no meaning in Haxe, and Haxe code never receives one. Release handles with the release() method of the object that created them.

## file_open
<!-- file_open -->
verdict: cannot FMOD runs file callbacks on its streaming and loading threads, and no Haxe target can execute code there. StudioSystem.loadBankFile, loadBankMemory, Sound.create, and Sound.fromPcm are the loading paths.

## file_close
<!-- file_close -->
verdict: cannot FMOD runs file callbacks on its streaming and loading threads, and no Haxe target can execute code there. StudioSystem.loadBankFile, loadBankMemory, Sound.create, and Sound.fromPcm are the loading paths.

## file_read
<!-- file_read -->
verdict: cannot FMOD runs file callbacks on its streaming and loading threads, and no Haxe target can execute code there. StudioSystem.loadBankFile, loadBankMemory, Sound.create, and Sound.fromPcm are the loading paths.

## file_seek
<!-- file_seek -->
verdict: cannot FMOD runs file callbacks on its streaming and loading threads, and no Haxe target can execute code there. StudioSystem.loadBankFile, loadBankMemory, Sound.create, and Sound.fromPcm are the loading paths.

## setvalue
<!-- setValue -->
verdict: cannot This reads and writes the wasm heap through a raw address, which has no meaning in Haxe. Values cross into FMOD through the typed haxefmod methods, and getters return values directly.

## getvalue
<!-- getValue -->
verdict: cannot This reads and writes the wasm heap through a raw address, which has no meaning in Haxe. Values cross into FMOD through the typed haxefmod methods, and getters return values directly.

## file_seek_1
<!-- file_seek -->
verdict: cannot FMOD runs file callbacks on its streaming and loading threads, and no Haxe target can execute code there. StudioSystem.loadBankFile, loadBankMemory, Sound.create, and Sound.fromPcm are the loading paths.

## sound_getsystemobject
<!-- Sound::getSystemObject -->
verdict: covered haxefmod has one core system, and haxefmod.core.CoreSystem reaches it directly, so no object needs to hand it back.

## soundgroup_getsystemobject
<!-- SoundGroup::getSystemObject -->
verdict: covered haxefmod has one core system, and haxefmod.core.CoreSystem reaches it directly, so no object needs to hand it back.

## system_attachfilesystem
<!-- System::attachFileSystem -->
verdict: cannot A custom file system is a set of callbacks that FMOD runs on its streaming and loading threads, and no Haxe target can execute code there. StudioSystem.loadBankFile and loadBankMemory are the bank paths, and Sound.create and Sound.fromPcm are the sound paths.

## system_close
<!-- System::close -->
verdict: covered haxefmod owns this.

## system_create
<!-- System_Create -->
verdict: covered haxefmod calls this for you.

## system_createdsp
<!-- System::createDSP -->
verdict: cannot A DSP description is a struct of callbacks that FMOD runs on its mixer thread, and no Haxe target can execute code there. All 33 built-in DSP types are created with Dsp.create(type), and a unit from a loaded plugin with Dsp.createByPlugin(handle).

## system_createdspconnection
<!-- System::createDSPConnection -->
verdict: covered haxefmod covers this with Dsp.addInput(), which connects two units and returns the DspConnection for the link.

## system_createstream
<!-- System::createStream -->
verdict: covered Sound.create with the ChannelMode.CREATESTREAM mode streams from a file, and PcmStream.create streams sample data the game writes.

## system_get3dlistenerattributes
<!-- System::get3DListenerAttributes -->
verdict: covered haxefmod covers this with StudioSystem.getListenerAttributes().

## system_get3dnumlisteners
<!-- System::get3DNumListeners -->
verdict: covered haxefmod covers this with StudioSystem.getNumListeners().

## system_getcpuusage
<!-- System::getCPUUsage -->
verdict: covered haxefmod covers this with StudioSystem.getCpuUsage(), which returns the core mixer, stream, geometry, update, and convolution figures next to the Studio update time.

## system_getoutputhandle
<!-- System::getOutputHandle -->
verdict: cannot It returns a raw operating system pointer, which has no meaning in Haxe. Output device selection goes through CoreSystem.getDriverCount, getDriverName, and setDriver.

## system_init
<!-- System::init -->
verdict: covered haxefmod calls this for you.

## system_registercodec
<!-- System::registerCodec -->
verdict: cannot A plugin description is a struct of callbacks that FMOD runs on its mixer and streaming threads, and no Haxe target can execute code there. A prebuilt plugin binary loads with StudioSystem.loadPlugin, and the built-in DSP types are created with Dsp.create.

## system_registerdsp
<!-- System::registerDSP -->
verdict: cannot A plugin description is a struct of callbacks that FMOD runs on its mixer and streaming threads, and no Haxe target can execute code there. A prebuilt plugin binary loads with StudioSystem.loadPlugin, and the built-in DSP types are created with Dsp.create.

## system_registeroutput
<!-- System::registerOutput -->
verdict: cannot A plugin description is a struct of callbacks that FMOD runs on its mixer and streaming threads, and no Haxe target can execute code there. A prebuilt plugin binary loads with StudioSystem.loadPlugin, and the built-in DSP types are created with Dsp.create.

## system_release
<!-- System::release -->
verdict: covered haxefmod owns this.

## system_set3dlistenerattributes
<!-- System::set3DListenerAttributes -->
verdict: covered haxefmod covers this with StudioSystem.setListenerPosition2D() for 2D games and StudioSystem.setListenerAttributes() for the full struct.

## system_set3dnumlisteners
<!-- System::set3DNumListeners -->
verdict: covered haxefmod covers this with StudioSystem.setNumListeners().

## system_set3drolloffcallback
<!-- System::set3DRolloffCallback -->
verdict: cannot FMOD runs the callback on its mixer thread, and no Haxe target can execute code there. Channel.set3DCustomRolloff takes a curve of points instead, and the built-in rolloff modes are set through Channel.setMode and ChannelGroup.setMode.

## system_setfilesystem
<!-- System::setFileSystem -->
verdict: cannot A custom file system is a set of callbacks that FMOD runs on its streaming and loading threads, and no Haxe target can execute code there. StudioSystem.loadBankFile and loadBankMemory are the bank paths, and Sound.create and Sound.fromPcm are the sound paths.

## system_update
<!-- System::update -->
verdict: covered haxefmod calls this for you.

## studio_commandreplay_getsystem
<!-- Studio::CommandReplay::getSystem -->
verdict: covered haxefmod has one Studio system, and StudioSystem reaches it directly, so a replay never needs to hand it back.

## studio_commandreplay_setcreateinstancecallback
<!-- Studio::CommandReplay::setCreateInstanceCallback -->
verdict: cannot FMOD runs the callback on its update thread while the replay plays, and no Haxe target can execute code there. CommandReplay.getCommandInfo, getCommandString, and getCommandAtTime read the same commands from the game thread.

## studio_commandreplay_setframecallback
<!-- Studio::CommandReplay::setFrameCallback -->
verdict: cannot FMOD runs the callback on its update thread while the replay plays, and no Haxe target can execute code there. CommandReplay.getCommandInfo, getCommandString, and getCommandAtTime read the same commands from the game thread.

## studio_commandreplay_setloadbankcallback
<!-- Studio::CommandReplay::setLoadBankCallback -->
verdict: cannot FMOD runs the callback on its update thread while the replay plays, and no Haxe target can execute code there. CommandReplay.getCommandInfo, getCommandString, and getCommandAtTime read the same commands from the game thread.

## studio_parseid
<!-- Studio::parseID -->
verdict: covered FmodGuid.fromString parses the braced text into a FmodGuid, and a plain String converts on its own.

## studio_eventdescription_getparameterdescriptionbyid
<!-- Studio::EventDescription::getParameterDescriptionByID -->
verdict: covered haxefmod covers this with EventDescription.getParameterDescriptionByID().

## studio_eventdescription_getparameterlabelbyid
<!-- Studio::EventDescription::getParameterLabelByID -->
verdict: covered haxefmod covers this with EventDescription.getParameterLabelByID().

## studio_eventdescription_getuserproperty
<!-- Studio::EventDescription::getUserProperty -->
verdict: covered EventDescription.getUserProperty(name) walks the properties FMOD reports by index and returns the one with that name, so the same FmodUserProperty comes back as from FMOD's lookup by name.

## studio_eventdescription_setcallback
<!-- Studio::EventDescription::setCallback -->
verdict: covered haxefmod covers this with EventDescription.setCallback(handler, ?mask), which remembers a handler that createInstance installs on every instance made from the description from then on.

## studio_eventinstance_getsystem
<!-- Studio::EventInstance::getSystem -->
verdict: covered haxefmod has one Studio system, and StudioSystem reaches it directly, so an instance never needs to hand it back.

## studio_system_getparameterdescriptionbyid
<!-- Studio::System::getParameterDescriptionByID -->
verdict: covered haxefmod covers this with StudioSystem.getParameterDescriptionByID().

## studio_system_getparameterlabelbyid
<!-- Studio::System::getParameterLabelByID -->
verdict: covered haxefmod covers this with StudioSystem.getParameterLabelByID().

## studio_system_isvalid
<!-- Studio::System::isValid -->
verdict: covered haxefmod covers this with FmodManager.IsInitialized(), which reports true once the Studio system and the default banks are usable.

## studio_system_loadbankcustom
<!-- Studio::System::loadBankCustom -->
verdict: cannot FMOD_STUDIO_BANK_INFO is declared as haxefmod.studio.Types.FmodStudioBankInfo (size, userData, userDataLength), but the load itself needs the four file callbacks the struct carries, and FMOD runs those on its streaming and loading threads, where no Haxe target can execute code. StudioSystem.loadBankFile and loadBankMemory are the bank paths, and Sound.create and Sound.fromPcm are the sound paths.

## studio_system_registerplugin
<!-- Studio::System::registerPlugin -->
verdict: cannot It takes a DSP description struct whose callbacks FMOD runs on its mixer thread, and no Haxe target can execute code there. A prebuilt plugin binary loads with StudioSystem.loadPlugin, which makes its effects available to Studio events.

## studio_system_unregisterplugin
<!-- Studio::System::unregisterPlugin -->
verdict: cannot It names a plugin registered from a description struct, and that registration cannot be bound because its callbacks would run on FMOD's mixer thread. A plugin loaded with StudioSystem.loadPlugin is unloaded with StudioSystem.unloadPlugin.

## fsbank_init
<!-- FSBank_Init -->
verdict: cannot FSBank is FMOD's offline bank encoder, shipped as a separate tool library outside the runtime SDK. haxefmod links the runtime only, and banks are built with FMOD Studio.

## fsbank_build
<!-- FSBank_Build -->
verdict: cannot FSBank is FMOD's offline bank encoder, shipped as a separate tool library outside the runtime SDK. haxefmod links the runtime only, and banks are built with FMOD Studio.

## fsbank_buildcancel
<!-- FSBank_BuildCancel -->
verdict: cannot FSBank is FMOD's offline bank encoder, shipped as a separate tool library outside the runtime SDK. haxefmod links the runtime only, and banks are built with FMOD Studio.

## fsbank_release
<!-- FSBank_Release -->
verdict: cannot FSBank is FMOD's offline bank encoder, shipped as a separate tool library outside the runtime SDK. haxefmod links the runtime only, and banks are built with FMOD Studio.

## fsbank_releaseprogressitem
<!-- FSBank_ReleaseProgressItem -->
verdict: cannot FSBank is FMOD's offline bank encoder, shipped as a separate tool library outside the runtime SDK. haxefmod links the runtime only, and banks are built with FMOD Studio.

## fsbank_memorygetstats
<!-- FSBank_MemoryGetStats -->
verdict: cannot FSBank is FMOD's offline bank encoder, shipped as a separate tool library outside the runtime SDK. haxefmod links the runtime only, and banks are built with FMOD Studio.

## fsbank_memoryinit
<!-- FSBank_MemoryInit -->
verdict: cannot FSBank is FMOD's offline bank encoder, shipped as a separate tool library outside the runtime SDK. haxefmod links the runtime only, and banks are built with FMOD Studio.

## fsbank_fetchfsbmemory
<!-- FSBank_FetchFSBMemory -->
verdict: cannot FSBank is FMOD's offline bank encoder, shipped as a separate tool library outside the runtime SDK. haxefmod links the runtime only, and banks are built with FMOD Studio.

## fsbank_fetchnextprogressitem
<!-- FSBank_FetchNextProgressItem -->
verdict: cannot FSBank is FMOD's offline bank encoder, shipped as a separate tool library outside the runtime SDK. haxefmod links the runtime only, and banks are built with FMOD Studio.

## studio_system_release
<!-- Studio::System::release -->
verdict: library There is no shutdown call. FmodManager.Initialize() creates the system once and FMOD is released when the process exits, so banks, instances, and handles need no teardown order at quit.

## studio_system_initialize
<!-- Studio::System::initialize -->
verdict: library FmodManager.Initialize(settings) makes this call. maxchannels is FmodSettings.numChannels, studioflags come from liveUpdate and memoryTracking, flags come from the core fields (for example rightHanded3D and profiling), and extradriverdata is never passed.
