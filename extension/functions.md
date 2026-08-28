# functions

## channel_getchannelgroup
<!-- Channel::getChannelGroup -->
Not exposed. The group a channel plays in is the one you passed to Channel.setChannelGroup, or the master group by default, so keep that reference on the game side.

## channelcontrol_get3dcustomrolloff
<!-- ChannelControl::get3DCustomRolloff -->
Not exposed. Custom 3D rolloff curves are left out because FMOD needs the point array to stay allocated for the object's lifetime, which a marshaled copy cannot guarantee. The built-in rolloff modes are selected through setMode on the channel or group.

## channelcontrol_get3ddistancefilter
<!-- ChannelControl::get3DDistanceFilter -->
Not exposed. The distance filter is left out with the other 3D curve overrides. Channel.getLowPassGain reads the filter gain you applied directly.

## channelcontrol_getdspindex
<!-- ChannelControl::getDSPIndex -->
Not exposed. Channel.getDspCount() and Channel.getDsp(index) walk the chain in order, so the index of a unit is the position where getDsp returns it.

## channelcontrol_getfadepoints
<!-- ChannelControl::getFadePoints -->
Not exposed. Fade point readback is left out. Channel.addFadePoint, setFadePointRamp, and removeFadePoints are bound, and the game keeps its own list of the points it added.

## channelcontrol_getmixmatrix
<!-- ChannelControl::getMixMatrix -->
Not exposed. Mix matrix readback is left out. Channel.setMixMatrix and ChannelGroup.setMixMatrix are bound, and the game keeps the matrix it set.

## channelcontrol_getsystemobject
<!-- ChannelControl::getSystemObject -->
haxefmod has one core system, and haxefmod.core.CoreSystem reaches it directly, so no object needs to hand it back.
```haxe
import haxefmod.core.CoreSystem;

var format = CoreSystem.getSoftwareFormat();
```

## channelcontrol_getuserdata
<!-- ChannelControl::getUserData -->
Not exposed. Userdata on FMOD objects is left out because the binding's handle table already carries object identity. Keep your own map from the handle to your data, handles are ints and work as keys.

## channelcontrol_set3dcustomrolloff
<!-- ChannelControl::set3DCustomRolloff -->
Not exposed. Custom 3D rolloff curves are left out because FMOD needs the point array to stay allocated for the object's lifetime, which a marshaled copy cannot guarantee. The built-in rolloff modes are selected through setMode on the channel or group.

## channelcontrol_set3ddistancefilter
<!-- ChannelControl::set3DDistanceFilter -->
Not exposed. The distance filter is left out with the other 3D curve overrides. Channel.setLowPassGain and ChannelGroup.setLowPassGain apply a filter directly, and Studio events can author distance-driven filters.

## channelcontrol_setdspindex
<!-- ChannelControl::setDSPIndex -->
Not exposed. Reordering the chain after the fact is left out. Channel.addDsp(index, dsp) and ChannelGroup.addDsp(index, dsp) take the position when the unit is inserted, and removeDsp followed by addDsp moves it.

## channelcontrol_setmixlevelsinput
<!-- ChannelControl::setMixLevelsInput -->
Not exposed. Per-speaker input mix levels are left out with the speaker geometry APIs. Channel.setMixMatrix and ChannelGroup.setMixMatrix accept an explicit matrix, and setPan covers the common case.

## channelcontrol_setmixlevelsoutput
<!-- ChannelControl::setMixLevelsOutput -->
Not exposed. Per-speaker output mix levels are left out with the speaker geometry APIs. Channel.setMixMatrix and ChannelGroup.setMixMatrix accept an explicit matrix, and setPan covers the common case.

## file_getdiskbusy
<!-- File_GetDiskBusy -->
Not exposed. Disk busy flags belong to the custom file system integration, which is left out because IO callbacks would run on FMOD threads.

## file_setdiskbusy
<!-- File_SetDiskBusy -->
Not exposed. Disk busy flags belong to the custom file system integration, which is left out because IO callbacks would run on FMOD threads.

## memory_getstats
<!-- Memory_GetStats -->
Not exposed. Global allocator statistics are left out with the custom allocator hooks. StudioSystem.getMemoryUsage() reports the memory held by Studio objects.

## memory_initialize
<!-- Memory_Initialize -->
Not exposed. Custom allocators would be called from FMOD threads, which no Haxe target can do safely, and the library owns init. FMOD uses its default allocator on every target.

## thread_setattributes
<!-- Thread_SetAttributes -->
Not exposed. Thread affinity and priority are init-time engine settings the library keeps at FMOD's defaults, and the web build has no threads to configure.

## dsp_addinputpreallocated
<!-- DSP::addInputPreallocated -->
Not exposed. Preallocated connections are left out. Dsp.addInput() connects two units and returns the DspConnection, and FMOD allocates it on its own thread.

## dsp_getchannelformat
<!-- DSP::getChannelFormat -->
Not exposed. Channel format control on individual units is left out, and every unit runs in the mixer's format from FmodSettings.speakerMode.

## dsp_getdataparameterindex
<!-- DSP::getDataParameterIndex -->
Not exposed. Data parameter lookup is left out with the DSP parameter metadata. Dsp.getFftSpectrum() reads the FFT unit's spectrum data directly, and Dsp.setParameterData(index, bytes) writes a data parameter by index.

## dsp_getoutputchannelformat
<!-- DSP::getOutputChannelFormat -->
Not exposed. Channel format control on individual units is left out, and every unit runs in the mixer's format from FmodSettings.speakerMode.

## dsp_getparameterinfo
<!-- DSP::getParameterInfo -->
Not exposed. The web build has no binding for the parameter description struct, so DSP parameter metadata is left out. Parameter values round-trip by index through Dsp.getParameter, setParameter, and their Int and Bool variants on every target.

## dsp_getsystemobject
<!-- DSP::getSystemObject -->
haxefmod has one core system, and haxefmod.core.CoreSystem reaches it directly, so no object needs to hand it back.
```haxe
import haxefmod.core.CoreSystem;

var format = CoreSystem.getSoftwareFormat();
```

## dsp_getuserdata
<!-- DSP::getUserData -->
Not exposed. Userdata on FMOD objects is left out because the binding's handle table already carries object identity. Keep your own map from the handle to your data, handles are ints and work as keys.

## dsp_setcallback
<!-- DSP::setCallback -->
Not exposed. Haxe code cannot run on FMOD's mixer thread, so DSP callbacks cannot be delivered. Poll the unit from the game loop with Dsp.getMetering() or Dsp.getFftSpectrum() instead.

## dsp_setchannelformat
<!-- DSP::setChannelFormat -->
Not exposed. Channel format control on individual units is left out, and every unit runs in the mixer's format from FmodSettings.speakerMode.

## dsp_setuserdata
<!-- DSP::setUserData -->
Not exposed. Userdata on FMOD objects is left out because the binding's handle table already carries object identity. Keep your own map from the handle to your data, handles are ints and work as keys.

## dsp_showconfigdialog
<!-- DSP::showConfigDialog -->
Not exposed. Plugin configuration dialogs belong to third-party plugins, which haxefmod does not load. Built-in DSP parameters are set through Dsp.setParameter.

## dspconnection_getmixmatrix
<!-- DSPConnection::getMixMatrix -->
Not exposed. Per-connection mix matrices are left out. DspConnection.getMix reads the connection volume.

## dspconnection_getuserdata
<!-- DSPConnection::getUserData -->
Not exposed. Userdata on FMOD objects is left out because the binding's handle table already carries object identity. Keep your own map from the handle to your data, handles are ints and work as keys.

## dspconnection_setmixmatrix
<!-- DSPConnection::setMixMatrix -->
Not exposed. Per-connection mix matrices are left out. DspConnection.setMix sets the connection volume, and Channel.setMixMatrix or ChannelGroup.setMixMatrix shape the speaker mix.

## dspconnection_setuserdata
<!-- DSPConnection::setUserData -->
Not exposed. Userdata on FMOD objects is left out because the binding's handle table already carries object identity. Keep your own map from the handle to your data, handles are ints and work as keys.

## geometry_addpolygon
<!-- Geometry::addPolygon -->
Not exposed. Geometry-based occlusion is left out because the web build reports it unsupported. Drive an event parameter from a game-side raycast instead, or set manual occlusion with Channel.set3DOcclusion and ChannelGroup.set3DOcclusion.

## geometry_getactive
<!-- Geometry::getActive -->
Not exposed. Geometry-based occlusion is left out because the web build reports it unsupported. Drive an event parameter from a game-side raycast instead, or set manual occlusion with Channel.set3DOcclusion and ChannelGroup.set3DOcclusion.

## geometry_getmaxpolygons
<!-- Geometry::getMaxPolygons -->
Not exposed. Geometry-based occlusion is left out because the web build reports it unsupported. Drive an event parameter from a game-side raycast instead, or set manual occlusion with Channel.set3DOcclusion and ChannelGroup.set3DOcclusion.

## geometry_getnumpolygons
<!-- Geometry::getNumPolygons -->
Not exposed. Geometry-based occlusion is left out because the web build reports it unsupported. Drive an event parameter from a game-side raycast instead, or set manual occlusion with Channel.set3DOcclusion and ChannelGroup.set3DOcclusion.

## geometry_getpolygonattributes
<!-- Geometry::getPolygonAttributes -->
Not exposed. Geometry-based occlusion is left out because the web build reports it unsupported. Drive an event parameter from a game-side raycast instead, or set manual occlusion with Channel.set3DOcclusion and ChannelGroup.set3DOcclusion.

## geometry_getpolygonnumvertices
<!-- Geometry::getPolygonNumVertices -->
Not exposed. Geometry-based occlusion is left out because the web build reports it unsupported. Drive an event parameter from a game-side raycast instead, or set manual occlusion with Channel.set3DOcclusion and ChannelGroup.set3DOcclusion.

## geometry_getpolygonvertex
<!-- Geometry::getPolygonVertex -->
Not exposed. Geometry-based occlusion is left out because the web build reports it unsupported. Drive an event parameter from a game-side raycast instead, or set manual occlusion with Channel.set3DOcclusion and ChannelGroup.set3DOcclusion.

## geometry_getposition
<!-- Geometry::getPosition -->
Not exposed. Geometry-based occlusion is left out because the web build reports it unsupported. Drive an event parameter from a game-side raycast instead, or set manual occlusion with Channel.set3DOcclusion and ChannelGroup.set3DOcclusion.

## geometry_getrotation
<!-- Geometry::getRotation -->
Not exposed. Geometry-based occlusion is left out because the web build reports it unsupported. Drive an event parameter from a game-side raycast instead, or set manual occlusion with Channel.set3DOcclusion and ChannelGroup.set3DOcclusion.

## geometry_getscale
<!-- Geometry::getScale -->
Not exposed. Geometry-based occlusion is left out because the web build reports it unsupported. Drive an event parameter from a game-side raycast instead, or set manual occlusion with Channel.set3DOcclusion and ChannelGroup.set3DOcclusion.

## geometry_getuserdata
<!-- Geometry::getUserData -->
Not exposed. Userdata on FMOD objects is left out because the binding's handle table already carries object identity. Keep your own map from the handle to your data, handles are ints and work as keys.

## geometry_release
<!-- Geometry::release -->
Not exposed. Geometry-based occlusion is left out because the web build reports it unsupported. Drive an event parameter from a game-side raycast instead, or set manual occlusion with Channel.set3DOcclusion and ChannelGroup.set3DOcclusion.

## geometry_save
<!-- Geometry::save -->
Not exposed. Geometry-based occlusion is left out because the web build reports it unsupported. Drive an event parameter from a game-side raycast instead, or set manual occlusion with Channel.set3DOcclusion and ChannelGroup.set3DOcclusion.

## geometry_setactive
<!-- Geometry::setActive -->
Not exposed. Geometry-based occlusion is left out because the web build reports it unsupported. Drive an event parameter from a game-side raycast instead, or set manual occlusion with Channel.set3DOcclusion and ChannelGroup.set3DOcclusion.

## geometry_setpolygonattributes
<!-- Geometry::setPolygonAttributes -->
Not exposed. Geometry-based occlusion is left out because the web build reports it unsupported. Drive an event parameter from a game-side raycast instead, or set manual occlusion with Channel.set3DOcclusion and ChannelGroup.set3DOcclusion.

## geometry_setpolygonvertex
<!-- Geometry::setPolygonVertex -->
Not exposed. Geometry-based occlusion is left out because the web build reports it unsupported. Drive an event parameter from a game-side raycast instead, or set manual occlusion with Channel.set3DOcclusion and ChannelGroup.set3DOcclusion.

## geometry_setposition
<!-- Geometry::setPosition -->
Not exposed. Geometry-based occlusion is left out because the web build reports it unsupported. Drive an event parameter from a game-side raycast instead, or set manual occlusion with Channel.set3DOcclusion and ChannelGroup.set3DOcclusion.

## geometry_setrotation
<!-- Geometry::setRotation -->
Not exposed. Geometry-based occlusion is left out because the web build reports it unsupported. Drive an event parameter from a game-side raycast instead, or set manual occlusion with Channel.set3DOcclusion and ChannelGroup.set3DOcclusion.

## geometry_setscale
<!-- Geometry::setScale -->
Not exposed. Geometry-based occlusion is left out because the web build reports it unsupported. Drive an event parameter from a game-side raycast instead, or set manual occlusion with Channel.set3DOcclusion and ChannelGroup.set3DOcclusion.

## geometry_setuserdata
<!-- Geometry::setUserData -->
Not exposed. Userdata on FMOD objects is left out because the binding's handle table already carries object identity. Keep your own map from the handle to your data, handles are ints and work as keys.

## fmod_android_jni_close
<!-- FMOD_Android_JNI_Close -->
Not exposed. Android is not a supported platform, haxefmod targets desktop and web only.

## fmod_android_jni_init
<!-- FMOD_Android_JNI_Init -->
Not exposed. Android is not a supported platform, haxefmod targets desktop and web only.

## fs_createpreloadedfile
<!-- FS_createPreloadedFile -->
haxefmod does this for you on HTML5. The banks named in FmodSettings.autoLoadBanks are fetched during init, and StudioSystem.loadBankFile() fetches any other bank and places it in the wasm file system before loading it.
```haxe
import haxefmod.studio.Bank;

var bank:Bank = StudioSystem.loadBankFile("assets/fmod/Desktop/Level1.bank");
```

## readfile
<!-- ReadFile -->
Not exposed. Reading files from the wasm file system is left out with the custom file system integration. StudioSystem.loadBankMemory() loads a bank from bytes you already hold, and CoreSound.fromPcm() plays raw PCM you already hold.

## memory_free
<!-- Memory_Free -->
Not exposed. Haxe code never allocates on the FMOD heap, so there is nothing to free. Release handles with the release() method of the object that created them.

## file_open
<!-- file_open -->
Not exposed. File callbacks belong to the custom file system integration, which is left out because they would run on FMOD threads. StudioSystem.loadBankFile, loadBankMemory, CoreSound.create, and CoreSound.fromPcm are the supported loading paths.

## file_close
<!-- file_close -->
Not exposed. File callbacks belong to the custom file system integration, which is left out because they would run on FMOD threads. StudioSystem.loadBankFile, loadBankMemory, CoreSound.create, and CoreSound.fromPcm are the supported loading paths.

## file_read
<!-- file_read -->
Not exposed. File callbacks belong to the custom file system integration, which is left out because they would run on FMOD threads. StudioSystem.loadBankFile, loadBankMemory, CoreSound.create, and CoreSound.fromPcm are the supported loading paths.

## file_seek
<!-- file_seek -->
Not exposed. File callbacks belong to the custom file system integration, which is left out because they would run on FMOD threads. StudioSystem.loadBankFile, loadBankMemory, CoreSound.create, and CoreSound.fromPcm are the supported loading paths.

## setvalue
<!-- setValue -->
Not exposed. Direct wasm heap access belongs to hand-written JS glue, which the haxefmod web runtime keeps inside the binding. Values cross into FMOD through the typed haxefmod methods.

## getvalue
<!-- getValue -->
Not exposed. Direct wasm heap access belongs to hand-written JS glue, which the haxefmod web runtime keeps inside the binding. Getters return values directly, and struct getters return typedefs.

## file_seek_1
<!-- file_seek -->
Not exposed. File callbacks belong to the custom file system integration, which is left out because they would run on FMOD threads. StudioSystem.loadBankFile, loadBankMemory, CoreSound.create, and CoreSound.fromPcm are the supported loading paths.

## reverb3d_getuserdata
<!-- Reverb3D::getUserData -->
Not exposed. Userdata on FMOD objects is left out because the binding's handle table already carries object identity. Keep your own map from the handle to your data, handles are ints and work as keys.

## reverb3d_setuserdata
<!-- Reverb3D::setUserData -->
Not exposed. Userdata on FMOD objects is left out because the binding's handle table already carries object identity. Keep your own map from the handle to your data, handles are ints and work as keys.

## sound_get3dconesettings
<!-- Sound::get3DConeSettings -->
Not exposed on the sound. Cone settings are bound on the channel and the group, so read them with Channel.get3DConeSettings or ChannelGroup.get3DConeSettings.

## sound_get3dcustomrolloff
<!-- Sound::get3DCustomRolloff -->
Not exposed. Custom 3D rolloff curves are left out because FMOD needs the point array to stay allocated for the object's lifetime, which a marshaled copy cannot guarantee. The built-in rolloff modes are selected through setMode on the channel or group.

## sound_get3dminmaxdistance
<!-- Sound::get3DMinMaxDistance -->
Not exposed on the sound. Min and max distance are bound on the channel and the group, so read them with Channel.get3DMinMaxDistance or ChannelGroup.get3DMinMaxDistance.

## sound_getmusicchannelvolume
<!-- Sound::getMusicChannelVolume -->
Not exposed. Tracker music channel control (MOD, S3M, XM per-channel access) is left out. Volume and pitch of the whole sound are set on its Channel.

## sound_getmusicnumchannels
<!-- Sound::getMusicNumChannels -->
Not exposed. Tracker music channel control (MOD, S3M, XM per-channel access) is left out. Volume and pitch of the whole sound are set on its Channel.

## sound_getmusicspeed
<!-- Sound::getMusicSpeed -->
Not exposed. Tracker music channel control (MOD, S3M, XM per-channel access) is left out. Volume and pitch of the whole sound are set on its Channel.

## sound_getnumsubsounds
<!-- Sound::getNumSubSounds -->
Not exposed. Subsound and tag access are container internals with no cross-platform story. Load each file as its own CoreSound, or play authored content from banks.

## sound_getnumtags
<!-- Sound::getNumTags -->
Not exposed. Subsound and tag access are container internals with no cross-platform story. Load each file as its own CoreSound, or play authored content from banks.

## sound_getsubsound
<!-- Sound::getSubSound -->
Not exposed. Subsound and tag access are container internals with no cross-platform story. Load each file as its own CoreSound, or play authored content from banks.

## sound_getsubsoundparent
<!-- Sound::getSubSoundParent -->
Not exposed. Subsound and tag access are container internals with no cross-platform story. Load each file as its own CoreSound, or play authored content from banks.

## sound_getsystemobject
<!-- Sound::getSystemObject -->
haxefmod has one core system, and haxefmod.core.CoreSystem reaches it directly, so no object needs to hand it back.
```haxe
import haxefmod.core.CoreSystem;

var format = CoreSystem.getSoftwareFormat();
```

## sound_gettag
<!-- Sound::getTag -->
Not exposed. Subsound and tag access are container internals with no cross-platform story. Load each file as its own CoreSound, or play authored content from banks.

## sound_getuserdata
<!-- Sound::getUserData -->
Not exposed. Userdata on FMOD objects is left out because the binding's handle table already carries object identity. Keep your own map from the handle to your data, handles are ints and work as keys.

## sound_lock
<!-- Sound::lock -->
Not exposed. Sample readback is unsupported on the web build, so lock, unlock, readData, and seekData are left out. Games that need waveform data keep their own copy of the PCM they feed through PcmStream or CoreSound.fromPcm.

## sound_readdata
<!-- Sound::readData -->
Not exposed. Sample readback is unsupported on the web build, so lock, unlock, readData, and seekData are left out. Games that need waveform data keep their own copy of the PCM they feed through PcmStream or CoreSound.fromPcm.

## sound_seekdata
<!-- Sound::seekData -->
Not exposed. Sample readback is unsupported on the web build, so lock, unlock, readData, and seekData are left out. Games that need waveform data keep their own copy of the PCM they feed through PcmStream or CoreSound.fromPcm.

## sound_set3dconesettings
<!-- Sound::set3DConeSettings -->
Not exposed on the sound. Cone settings are bound on the channel and the group, so set them with Channel.set3DConeSettings after play or with ChannelGroup.set3DConeSettings for a whole group.

## sound_set3dcustomrolloff
<!-- Sound::set3DCustomRolloff -->
Not exposed. Custom 3D rolloff curves are left out because FMOD needs the point array to stay allocated for the object's lifetime, which a marshaled copy cannot guarantee. The built-in rolloff modes are selected through setMode on the channel or group.

## sound_set3dminmaxdistance
<!-- Sound::set3DMinMaxDistance -->
Not exposed on the sound. Min and max distance are bound on the channel and the group, so set them with Channel.set3DMinMaxDistance after play or with ChannelGroup.set3DMinMaxDistance for a whole group.

## sound_setmusicchannelvolume
<!-- Sound::setMusicChannelVolume -->
Not exposed. Tracker music channel control (MOD, S3M, XM per-channel access) is left out. Volume and pitch of the whole sound are set on its Channel.

## sound_setmusicspeed
<!-- Sound::setMusicSpeed -->
Not exposed. Tracker music channel control (MOD, S3M, XM per-channel access) is left out. Volume and pitch of the whole sound are set on its Channel.

## sound_unlock
<!-- Sound::unlock -->
Not exposed. Sample readback is unsupported on the web build, so lock, unlock, readData, and seekData are left out. Games that need waveform data keep their own copy of the PCM they feed through PcmStream or CoreSound.fromPcm.

## soundgroup_getname
<!-- SoundGroup::getName -->
Not exposed. The name is the one you passed to SoundGroup.create, so keep it on the game side. SoundGroup.master() is the default group.

## soundgroup_getsound
<!-- SoundGroup::getSound -->
Not exposed. Enumerating a group's sounds is left out. SoundGroup.getSoundCount() and getPlayingCount() report the totals, and the game keeps the CoreSound handles it assigned with CoreSound.setSoundGroup.

## soundgroup_getsystemobject
<!-- SoundGroup::getSystemObject -->
haxefmod has one core system, and haxefmod.core.CoreSystem reaches it directly, so no object needs to hand it back.
```haxe
import haxefmod.core.CoreSystem;

var format = CoreSystem.getSoftwareFormat();
```

## soundgroup_getuserdata
<!-- SoundGroup::getUserData -->
Not exposed. Userdata on FMOD objects is left out because the binding's handle table already carries object identity. Keep your own map from the handle to your data, handles are ints and work as keys.

## soundgroup_setuserdata
<!-- SoundGroup::setUserData -->
Not exposed. Userdata on FMOD objects is left out because the binding's handle table already carries object identity. Keep your own map from the handle to your data, handles are ints and work as keys.

## system_attachchannelgrouptoport
<!-- System::attachChannelGroupToPort -->
Not exposed. Console port APIs are left out because haxefmod supports desktop and web only. Route audio through ChannelGroup and Bus instead.

## system_attachfilesystem
<!-- System::attachFileSystem -->
Not exposed. Custom file systems need IO callbacks that run on FMOD threads, which no Haxe target can do safely. StudioSystem.loadBankFile and loadBankMemory are the supported bank paths, and CoreSound.create and CoreSound.fromPcm are the sound paths.

## system_close
<!-- System::close -->
haxefmod owns this. The system is never closed, FMOD initializes once in FmodManager.Initialize() and lives until the process exits. Use FmodManager.PauseAllSounds() or CoreSystem.mixerSuspend() when the game goes to the background.
```haxe
import haxefmod.core.CoreSystem;

CoreSystem.mixerSuspend();
// later
CoreSystem.mixerResume();
```

## system_create
<!-- System_Create -->
haxefmod calls this for you. FmodManager.Initialize() (or FmodRuntime.init()) creates and initializes the Studio system and its core system in one step, and the engine lives until the process exits. Init-time options come from FmodSettings.
```haxe
FmodManager.Initialize({numChannels: 256, sampleRate: 48000});
```

## system_createdsp
<!-- System::createDSP -->
Not exposed. A DSP description carries callbacks that would run on FMOD's mixer thread, which no Haxe target can do. All 33 built-in DSP types are created with Dsp.create(type).

## system_createdspbyplugin
<!-- System::createDSPByPlugin -->
Not exposed. Third-party plugins and custom codecs, DSPs, and outputs run code on FMOD threads, which no Haxe target can do, and the web build has no plugin host at all. The 33 built-in DSP types are bound through Dsp.create.

## system_createdspconnection
<!-- System::createDSPConnection -->
haxefmod covers this with Dsp.addInput(), which connects two units and returns the DspConnection for the link.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var reverb = Dsp.create(DspType.SFXREVERB);
var fft = Dsp.create(DspType.FFT);
var connection = fft.addInput(reverb);
connection.setMix(0.5);
```

## system_creategeometry
<!-- System::createGeometry -->
Not exposed. Geometry-based occlusion is left out because the web build reports it unsupported. Drive an event parameter from a game-side raycast instead, or set manual occlusion with Channel.set3DOcclusion and ChannelGroup.set3DOcclusion.

## system_createstream
<!-- System::createStream -->
haxefmod covers streams two ways. CoreSound.create() opens a file for playback, and PcmStream.create() opens a stream that Haxe code feeds with raw PCM, which is the one path that works on HTML5 as well.
```haxe
import haxefmod.core.PcmStream;

var stream = PcmStream.create(44100, 2);
var channel = stream.play();
```

## system_detachchannelgroupfromport
<!-- System::detachChannelGroupFromPort -->
Not exposed. Console port APIs are left out because haxefmod supports desktop and web only. Route audio through ChannelGroup and Bus instead.

## system_get3dlistenerattributes
<!-- System::get3DListenerAttributes -->
haxefmod covers this with StudioSystem.getListenerAttributes(). Studio drives the core listeners, so the Studio listener is the core listener.
```haxe
var listener = StudioSystem.getListenerAttributes(0);
if (listener != null) {
    trace('listener at ${listener.position.x}, ${listener.position.y}');
}
```

## system_get3dnumlisteners
<!-- System::get3DNumListeners -->
haxefmod covers this with StudioSystem.getNumListeners(). Studio drives the core listeners, so the Studio count is the core count.
```haxe
var listeners = StudioSystem.getNumListeners();
```

## system_getadvancedsettings
<!-- System::getAdvancedSettings -->
Not exposed. FMOD_ADVANCEDSETTINGS is left at its defaults on every target. FmodRuntime.settings() returns the resolved FmodSettings the engine started with.

## system_getchannel
<!-- System::getChannel -->
Not exposed. Channels are reached through the handle returned by CoreSound.play, PcmStream.play, or Dsp.play rather than by pool index, and ChannelGroup.getChannel(index) enumerates the channels in a group.

## system_getcpuusage
<!-- System::getCPUUsage -->
haxefmod covers this with StudioSystem.getCpuUsage(), which returns the core mixer, stream, geometry, update, and convolution figures next to the Studio update time.
```haxe
var usage = StudioSystem.getCpuUsage();
if (usage != null) {
    trace('dsp ${usage.dsp}% update ${usage.update}%');
}
```

## system_getdefaultmixmatrix
<!-- System::getDefaultMixMatrix -->
Not exposed. Speaker geometry and mix matrix readback are left out. Channel.setMixMatrix and ChannelGroup.setMixMatrix accept the matrix you build yourself.

## system_getdspbuffersize
<!-- System::getDSPBufferSize -->
Not exposed. The library owns init, and the mixer buffer stays at FMOD's default on native targets and 2048 samples by 2 buffers on HTML5.

## system_getdspinfobyplugin
<!-- System::getDSPInfoByPlugin -->
Not exposed. Third-party plugins and custom codecs, DSPs, and outputs run code on FMOD threads, which no Haxe target can do, and the web build has no plugin host at all. The 33 built-in DSP types are bound through Dsp.create.

## system_getdspinfobytype
<!-- System::getDSPInfoByType -->
Not exposed. DSP metadata lookup is left out with the plugin APIs. Dsp.getName() and Dsp.getType() report what a created unit is, and Dsp.getParameterCount() reports how many parameters it has.

## system_getfileusage
<!-- System::getFileUsage -->
Not exposed. File IO statistics are a tooling diagnostic with no cross-platform story, and the web build has no file system to count. StudioSystem.getBufferUsage() reports the Studio command and handle buffer usage.

## system_getgeometryocclusion
<!-- System::getGeometryOcclusion -->
Not exposed. Geometry-based occlusion is left out because the web build reports it unsupported. Drive an event parameter from a game-side raycast instead, or set manual occlusion with Channel.set3DOcclusion and ChannelGroup.set3DOcclusion.

## system_getgeometrysettings
<!-- System::getGeometrySettings -->
Not exposed. Geometry-based occlusion is left out because the web build reports it unsupported. Drive an event parameter from a game-side raycast instead, or set manual occlusion with Channel.set3DOcclusion and ChannelGroup.set3DOcclusion.

## system_getnestedplugin
<!-- System::getNestedPlugin -->
Not exposed. Third-party plugins and custom codecs, DSPs, and outputs run code on FMOD threads, which no Haxe target can do, and the web build has no plugin host at all. The 33 built-in DSP types are bound through Dsp.create.

## system_getnetworkproxy
<!-- System::getNetworkProxy -->
Not exposed. Network streaming is left out, the library keeps FMOD's default network settings, and CoreSound.create opens local files only.

## system_getnetworktimeout
<!-- System::getNetworkTimeout -->
Not exposed. Network streaming is left out, the library keeps FMOD's default network settings, and CoreSound.create opens local files only.

## system_getnumnestedplugins
<!-- System::getNumNestedPlugins -->
Not exposed. Third-party plugins and custom codecs, DSPs, and outputs run code on FMOD threads, which no Haxe target can do, and the web build has no plugin host at all. The 33 built-in DSP types are bound through Dsp.create.

## system_getnumplugins
<!-- System::getNumPlugins -->
Not exposed. Third-party plugins and custom codecs, DSPs, and outputs run code on FMOD threads, which no Haxe target can do, and the web build has no plugin host at all. The 33 built-in DSP types are bound through Dsp.create.

## system_getoutput
<!-- System::getOutput -->
Not exposed. The library owns init and keeps FMOD's default output type for the platform. Output device selection is bound through CoreSystem.getDriverCount, getDriverName, and setDriver.

## system_getoutputbyplugin
<!-- System::getOutputByPlugin -->
Not exposed. Output plugins are not loadable from haxefmod, and the library keeps FMOD's default output type for the platform.

## system_getoutputhandle
<!-- System::getOutputHandle -->
Not exposed. Haxe code never holds a raw pointer, and the library keeps FMOD's default output type, so there is no platform handle to hand back.

## system_getpluginhandle
<!-- System::getPluginHandle -->
Not exposed. Third-party plugins and custom codecs, DSPs, and outputs run code on FMOD threads, which no Haxe target can do, and the web build has no plugin host at all. The 33 built-in DSP types are bound through Dsp.create.

## system_getplugininfo
<!-- System::getPluginInfo -->
Not exposed. Third-party plugins and custom codecs, DSPs, and outputs run code on FMOD threads, which no Haxe target can do, and the web build has no plugin host at all. The 33 built-in DSP types are bound through Dsp.create.

## system_getrecorddriverinfo
<!-- System::getRecordDriverInfo -->
Not exposed. Microphone recording is left out because browser permission flows make its behavior environment-dependent and untestable in CI. Feed captured audio you obtain elsewhere through PcmStream or CoreSound.fromPcm.

## system_getrecordnumdrivers
<!-- System::getRecordNumDrivers -->
Not exposed. Microphone recording is left out because browser permission flows make its behavior environment-dependent and untestable in CI. Feed captured audio you obtain elsewhere through PcmStream or CoreSound.fromPcm.

## system_getrecordposition
<!-- System::getRecordPosition -->
Not exposed. Microphone recording is left out because browser permission flows make its behavior environment-dependent and untestable in CI. Feed captured audio you obtain elsewhere through PcmStream or CoreSound.fromPcm.

## system_getsoftwarechannels
<!-- System::getSoftwareChannels -->
Not exposed. The library owns init, and the software channel count stays at FMOD's default. FmodRuntime.settings().numChannels reports the virtual voice count the engine started with.

## system_getspeakermodechannels
<!-- System::getSpeakerModeChannels -->
Not exposed. Speaker geometry APIs are left out. CoreSystem.getSoftwareFormat() reports the speaker mode and raw speaker count the mixer runs with.

## system_getspeakerposition
<!-- System::getSpeakerPosition -->
Not exposed. Speaker geometry APIs are left out, and the mixer runs with FMOD's default speaker positions for the speaker mode in FmodSettings.speakerMode.

## system_getstreambuffersize
<!-- System::getStreamBufferSize -->
Not exposed. The library owns init and keeps FMOD's default file stream buffer. PcmStream.space() reports how much room a stream you feed yourself has left.

## system_getuserdata
<!-- System::getUserData -->
Not exposed. Userdata on FMOD objects is left out because the binding's handle table already carries object identity. Keep your own map from the handle to your data, handles are ints and work as keys.

## system_getversion
<!-- System::getVersion -->
Not exposed. haxefmod ships against one FMOD version (2.03.12 for this release) and the native binding checks its own ABI at init, so there is nothing to query at runtime. docs/coverage.md names the FMOD version each release is built against.

## system_init
<!-- System::init -->
haxefmod calls this for you. FmodManager.Initialize() (or FmodRuntime.init()) creates and initializes the Studio system and its core system in one step, and the engine lives until the process exits. Init-time options come from FmodSettings.
```haxe
FmodManager.Initialize({numChannels: 256, sampleRate: 48000});
```

## system_isrecording
<!-- System::isRecording -->
Not exposed. Microphone recording is left out because browser permission flows make its behavior environment-dependent and untestable in CI. Feed captured audio you obtain elsewhere through PcmStream or CoreSound.fromPcm.

## system_loadgeometry
<!-- System::loadGeometry -->
Not exposed. Geometry-based occlusion is left out because the web build reports it unsupported. Drive an event parameter from a game-side raycast instead, or set manual occlusion with Channel.set3DOcclusion and ChannelGroup.set3DOcclusion.

## system_loadplugin
<!-- System::loadPlugin -->
Not exposed. Third-party plugins and custom codecs, DSPs, and outputs run code on FMOD threads, which no Haxe target can do, and the web build has no plugin host at all. The 33 built-in DSP types are bound through Dsp.create.

## system_lockdsp
<!-- System::lockDSP -->
Not exposed. Haxe code cannot run on FMOD's mixer thread, so there is nothing to lock the DSP graph against. Effects are added and removed with Dsp, Channel.addDsp, and ChannelGroup.addDsp without locking.

## system_recordstart
<!-- System::recordStart -->
Not exposed. Microphone recording is left out because browser permission flows make its behavior environment-dependent and untestable in CI. Feed captured audio you obtain elsewhere through PcmStream or CoreSound.fromPcm.

## system_recordstop
<!-- System::recordStop -->
Not exposed. Microphone recording is left out because browser permission flows make its behavior environment-dependent and untestable in CI. Feed captured audio you obtain elsewhere through PcmStream or CoreSound.fromPcm.

## system_registercodec
<!-- System::registerCodec -->
Not exposed. Third-party plugins and custom codecs, DSPs, and outputs run code on FMOD threads, which no Haxe target can do, and the web build has no plugin host at all. The 33 built-in DSP types are bound through Dsp.create.

## system_registerdsp
<!-- System::registerDSP -->
Not exposed. Third-party plugins and custom codecs, DSPs, and outputs run code on FMOD threads, which no Haxe target can do, and the web build has no plugin host at all. The 33 built-in DSP types are bound through Dsp.create.

## system_registeroutput
<!-- System::registerOutput -->
Not exposed. Third-party plugins and custom codecs, DSPs, and outputs run code on FMOD threads, which no Haxe target can do, and the web build has no plugin host at all. The 33 built-in DSP types are bound through Dsp.create.

## system_release
<!-- System::release -->
haxefmod owns this. There is no shutdown or re-init, FMOD initializes once in FmodManager.Initialize() and lives until the process exits, so no use-after-shutdown bug can occur. Stop or release your own objects instead of closing the system.
```haxe
FmodManager.StopAllSounds();
```

## system_set3dlistenerattributes
<!-- System::set3DListenerAttributes -->
haxefmod covers this with StudioSystem.setListenerPosition2D() for 2D games and StudioSystem.setListenerAttributes() for the full struct. Studio drives the core listeners, so setting the Studio listener sets the core one.
```haxe
StudioSystem.setListenerPosition2D(0, cameraX, cameraY);
```

## system_set3dnumlisteners
<!-- System::set3DNumListeners -->
haxefmod covers this with StudioSystem.setNumListeners(). Studio drives the core listeners, so the count is set once on the Studio system and the core system follows.
```haxe
StudioSystem.setNumListeners(2);
```

## system_set3drolloffcallback
<!-- System::set3DRolloffCallback -->
Not exposed. Haxe code cannot run on FMOD's mixer thread, so a rolloff callback cannot be delivered. The built-in rolloff modes are set through Channel.setMode and ChannelGroup.setMode.

## system_setadvancedsettings
<!-- System::setAdvancedSettings -->
Not exposed. The library owns init, and FMOD_ADVANCEDSETTINGS is left at its defaults on every target. The init-time options haxefmod supports are the FmodSettings fields and the haxefmod_* compile-time defines.

## system_setcallback
<!-- System::setCallback -->
Not exposed. System diagnostic callbacks are FMOD tooling hooks that would run on FMOD threads, which no Haxe target can do safely. Set FmodSettings.logLevel or call FmodManager.EnableDebugMessages() to see engine errors in the log.

## system_setdspbuffersize
<!-- System::setDSPBufferSize -->
Not exposed. The library owns init, and the mixer buffer stays at FMOD's default on native targets and 2048 samples by 2 buffers on HTML5.

## system_setfilesystem
<!-- System::setFileSystem -->
Not exposed. Custom file systems need IO callbacks that run on FMOD threads, which no Haxe target can do safely. StudioSystem.loadBankFile and loadBankMemory are the supported bank paths, and CoreSound.create and CoreSound.fromPcm are the sound paths.

## system_setgeometrysettings
<!-- System::setGeometrySettings -->
Not exposed. Geometry-based occlusion is left out because the web build reports it unsupported. Drive an event parameter from a game-side raycast instead, or set manual occlusion with Channel.set3DOcclusion and ChannelGroup.set3DOcclusion.

## system_setnetworkproxy
<!-- System::setNetworkProxy -->
Not exposed. Network streaming is left out, the library keeps FMOD's default network settings, and CoreSound.create opens local files only.

## system_setnetworktimeout
<!-- System::setNetworkTimeout -->
Not exposed. Network streaming is left out, the library keeps FMOD's default network settings, and CoreSound.create opens local files only.

## system_setoutputbyplugin
<!-- System::setOutputByPlugin -->
Not exposed. Output plugins are third-party code that would run on FMOD threads, which no Haxe target can do safely. The library keeps FMOD's default output type for the platform.

## system_setpluginpath
<!-- System::setPluginPath -->
Not exposed. Third-party plugins and custom codecs, DSPs, and outputs run code on FMOD threads, which no Haxe target can do, and the web build has no plugin host at all. The 33 built-in DSP types are bound through Dsp.create.

## system_setsoftwarechannels
<!-- System::setSoftwareChannels -->
Not exposed. The library owns init, and the software channel count stays at FMOD's default. FmodSettings.numChannels sets the virtual voice count that Studio initializes with.

## system_setspeakerposition
<!-- System::setSpeakerPosition -->
Not exposed. Speaker geometry APIs are left out, and the mixer runs with FMOD's default speaker positions for the speaker mode in FmodSettings.speakerMode.

## system_setstreambuffersize
<!-- System::setStreamBufferSize -->
Not exposed. The library owns init and keeps FMOD's default file stream buffer. The ringBytes argument of PcmStream.create sizes the buffer of a stream you feed yourself.

## system_setuserdata
<!-- System::setUserData -->
Not exposed. Userdata on FMOD objects is left out because the binding's handle table already carries object identity. Keep your own map from the handle to your data, handles are ints and work as keys.

## system_unloadplugin
<!-- System::unloadPlugin -->
Not exposed. Third-party plugins and custom codecs, DSPs, and outputs run code on FMOD threads, which no Haxe target can do, and the web build has no plugin host at all. The 33 built-in DSP types are bound through Dsp.create.

## system_unlockdsp
<!-- System::unlockDSP -->
Not exposed. Haxe code cannot run on FMOD's mixer thread, so the DSP graph is never locked from Haxe. Effects are added and removed with Dsp, Channel.addDsp, and ChannelGroup.addDsp without locking.

## system_update
<!-- System::update -->
haxefmod calls this for you. FmodManager.Update() (or FmodRuntime.update()) services the Studio system once per frame, which updates the core system as well, and a background thread keeps audio running between frames.
```haxe
FmodManager.Update();
```

## studio_bank_getuserdata
<!-- Studio::Bank::getUserData -->
Not exposed. Userdata on FMOD objects is left out because the binding's handle table already carries object identity. Keep your own map from the handle to your data, handles are ints and work as keys.

## studio_bank_setuserdata
<!-- Studio::Bank::setUserData -->
Not exposed. Userdata on FMOD objects is left out because the binding's handle table already carries object identity. Keep your own map from the handle to your data, handles are ints and work as keys.

## studio_bus_getportindex
<!-- Studio::Bus::getPortIndex -->
Not exposed. Console port APIs are left out because haxefmod supports desktop and web only. Route audio through ChannelGroup and Bus instead.

## studio_bus_setportindex
<!-- Studio::Bus::setPortIndex -->
Not exposed. Console port APIs are left out because haxefmod supports desktop and web only. Route audio through ChannelGroup and Bus instead.

## studio_commandreplay_getcommandattime
<!-- Studio::CommandReplay::getCommandAtTime -->
Not exposed. Command replay inspection and tool hooks are FMOD tooling integration points. Command capture and basic playback are bound through StudioSystem.startCommandCapture, stopCommandCapture, loadCommandReplay, and CommandReplay.start, stop, setPaused, seekToTime, and getLength.

## studio_commandreplay_getcommandcount
<!-- Studio::CommandReplay::getCommandCount -->
Not exposed. Command replay inspection and tool hooks are FMOD tooling integration points. Command capture and basic playback are bound through StudioSystem.startCommandCapture, stopCommandCapture, loadCommandReplay, and CommandReplay.start, stop, setPaused, seekToTime, and getLength.

## studio_commandreplay_getcommandinfo
<!-- Studio::CommandReplay::getCommandInfo -->
Not exposed. Command replay inspection and tool hooks are FMOD tooling integration points. Command capture and basic playback are bound through StudioSystem.startCommandCapture, stopCommandCapture, loadCommandReplay, and CommandReplay.start, stop, setPaused, seekToTime, and getLength.

## studio_commandreplay_getcommandstring
<!-- Studio::CommandReplay::getCommandString -->
Not exposed. Command replay inspection and tool hooks are FMOD tooling integration points. Command capture and basic playback are bound through StudioSystem.startCommandCapture, stopCommandCapture, loadCommandReplay, and CommandReplay.start, stop, setPaused, seekToTime, and getLength.

## studio_commandreplay_getcurrentcommand
<!-- Studio::CommandReplay::getCurrentCommand -->
Not exposed. Command replay inspection and tool hooks are FMOD tooling integration points. Command capture and basic playback are bound through StudioSystem.startCommandCapture, stopCommandCapture, loadCommandReplay, and CommandReplay.start, stop, setPaused, seekToTime, and getLength.

## studio_commandreplay_getplaybackstate
<!-- Studio::CommandReplay::getPlaybackState -->
Not exposed. Command replay inspection and tool hooks are FMOD tooling integration points. Command capture and basic playback are bound through StudioSystem.startCommandCapture, stopCommandCapture, loadCommandReplay, and CommandReplay.start, stop, setPaused, seekToTime, and getLength.

## studio_commandreplay_getsystem
<!-- Studio::CommandReplay::getSystem -->
haxefmod has one Studio system, and StudioSystem reaches it directly, so a replay never needs to hand it back.
```haxe
var replay = StudioSystem.loadCommandReplay("capture.cmd.txt");
replay.start();
```

## studio_commandreplay_getuserdata
<!-- Studio::CommandReplay::getUserData -->
Not exposed. Userdata on FMOD objects is left out because the binding's handle table already carries object identity. Keep your own map from the handle to your data, handles are ints and work as keys.

## studio_commandreplay_seektocommand
<!-- Studio::CommandReplay::seekToCommand -->
Not exposed. Command replay inspection and tool hooks are FMOD tooling integration points. Command capture and basic playback are bound through StudioSystem.startCommandCapture, stopCommandCapture, loadCommandReplay, and CommandReplay.start, stop, setPaused, seekToTime, and getLength.

## studio_commandreplay_setbankpath
<!-- Studio::CommandReplay::setBankPath -->
Not exposed. Command replay inspection and tool hooks are FMOD tooling integration points. Command capture and basic playback are bound through StudioSystem.startCommandCapture, stopCommandCapture, loadCommandReplay, and CommandReplay.start, stop, setPaused, seekToTime, and getLength.

## studio_commandreplay_setcreateinstancecallback
<!-- Studio::CommandReplay::setCreateInstanceCallback -->
Not exposed. Command replay inspection and tool hooks are FMOD tooling integration points. Command capture and basic playback are bound through StudioSystem.startCommandCapture, stopCommandCapture, loadCommandReplay, and CommandReplay.start, stop, setPaused, seekToTime, and getLength.

## studio_commandreplay_setframecallback
<!-- Studio::CommandReplay::setFrameCallback -->
Not exposed. Command replay inspection and tool hooks are FMOD tooling integration points. Command capture and basic playback are bound through StudioSystem.startCommandCapture, stopCommandCapture, loadCommandReplay, and CommandReplay.start, stop, setPaused, seekToTime, and getLength.

## studio_commandreplay_setloadbankcallback
<!-- Studio::CommandReplay::setLoadBankCallback -->
Not exposed. Command replay inspection and tool hooks are FMOD tooling integration points. Command capture and basic playback are bound through StudioSystem.startCommandCapture, stopCommandCapture, loadCommandReplay, and CommandReplay.start, stop, setPaused, seekToTime, and getLength.

## studio_commandreplay_setuserdata
<!-- Studio::CommandReplay::setUserData -->
Not exposed. Userdata on FMOD objects is left out because the binding's handle table already carries object identity. Keep your own map from the handle to your data, handles are ints and work as keys.

## studio_parseid
<!-- Studio::parseID -->
haxefmod passes GUIDs as strings, so there is nothing to parse. StudioSystem.getEventByID, getBusByID, getVCAByID, and getBankByID accept the braced string, and StudioSystem.lookupID converts a path to one.
```haxe
var guid = StudioSystem.lookupID(FmodEvents.MusicMainLevel);
var description = StudioSystem.getEventByID(guid);
```

## studio_eventdescription_getparameterdescriptionbyid
<!-- Studio::EventDescription::getParameterDescriptionByID -->
haxefmod covers this with EventDescription.getParameterDescriptionByID().
```haxe
var description = StudioSystem.getEvent(FmodEvents.SFXEngine);
var rpm = description.getParameterDescriptionByName("RPM");
if (rpm != null) {
    var again = description.getParameterDescriptionByID(rpm.id);
}
```

## studio_eventdescription_getparameterlabelbyid
<!-- Studio::EventDescription::getParameterLabelByID -->
haxefmod covers this with EventDescription.getParameterLabelByID().
```haxe
var description = StudioSystem.getEvent(FmodEvents.SFXEngine);
var surface = description.getParameterDescriptionByName("Surface");
if (surface != null) {
    var label = description.getParameterLabelByID(surface.id, 0);
}
```

## studio_eventdescription_getparameterlabelbyindex
<!-- Studio::EventDescription::getParameterLabelByIndex -->
haxefmod covers this with EventDescription.getParameterDescriptionByIndex() followed by getParameterLabel() with the parameter's name, or getParameterLabelByID() with its id.
```haxe
var description = StudioSystem.getEvent(FmodEvents.SFXEngine);
var parameter = description.getParameterDescriptionByIndex(0);
if (parameter != null) {
    var label = description.getParameterLabel(parameter.name, 0);
}
```

## studio_eventdescription_getuserdata
<!-- Studio::EventDescription::getUserData -->
Not exposed. Userdata on FMOD objects is left out because the binding's handle table already carries object identity. Keep your own map from the handle to your data, handles are ints and work as keys.

## studio_eventdescription_getuserproperty
<!-- Studio::EventDescription::getUserProperty -->
haxefmod covers this with EventDescription.getUserPropertyByName(). On HTML5 only string typed properties are readable, numeric ones report FMOD_ERR_UNSUPPORTED because of a defect in FMOD's JS runtime.
```haxe
var description = StudioSystem.getEvent(FmodEvents.MusicMainLevel);
var property = description.getUserPropertyByName("Author");
if (property != null) {
    trace(property.name);
}
```

## studio_eventdescription_setcallback
<!-- Studio::EventDescription::setCallback -->
Not exposed on the description. Callbacks are registered per instance with EventInstance.setCallback (or FmodSound.onEvent), which delivers typed EventCallbackData from FmodManager.Update() instead of from an FMOD thread.

## studio_eventdescription_setuserdata
<!-- Studio::EventDescription::setUserData -->
Not exposed. Userdata on FMOD objects is left out because the binding's handle table already carries object identity. Keep your own map from the handle to your data, handles are ints and work as keys.

## studio_eventinstance_getsystem
<!-- Studio::EventInstance::getSystem -->
haxefmod has one Studio system, and StudioSystem reaches it directly, so an instance never needs to hand it back.
```haxe
var bus = StudioSystem.getBus(FmodBuses.Music);
```

## studio_eventinstance_setparametersbyids
<!-- Studio::EventInstance::setParametersByIDs -->
haxefmod covers this with one EventInstance.setParameterByID() call per parameter. The call is cheap, and FMOD applies the values on the next update either way.
```haxe
import haxefmod.studio.Types;

var ids:Array<FmodParameterId> = [{data1: 0, data2: 0}];
var values = [0.5];
for (i in 0...ids.length) {
    instance.setParameterByID(ids[i], values[i]);
}
```

## studio_system_getadvancedsettings
<!-- Studio::System::getAdvancedSettings -->
Not exposed. FMOD_STUDIO_ADVANCEDSETTINGS is left at its defaults on every target. FmodRuntime.settings() returns the resolved FmodSettings the engine started with.

## studio_system_getparameterdescriptionbyid
<!-- Studio::System::getParameterDescriptionByID -->
haxefmod covers this with StudioSystem.getParameterDescriptionByID().
```haxe
var intensity = StudioSystem.getParameterDescriptionByName("Intensity");
if (intensity != null) {
    var again = StudioSystem.getParameterDescriptionByID(intensity.id);
}
```

## studio_system_getparameterlabelbyid
<!-- Studio::System::getParameterLabelByID -->
haxefmod covers this with StudioSystem.getParameterLabelByID().
```haxe
var weather = StudioSystem.getParameterDescriptionByName("Weather");
if (weather != null) {
    var label = StudioSystem.getParameterLabelByID(weather.id, 0);
}
```

## studio_system_getsoundinfo
<!-- Studio::System::getSoundInfo -->
Not exposed. Audio table lookup is left out because the programmer sound flow hands the key to FMOD instead. EventInstance.assignProgrammerSound(key) names the audio table entry or file to play, and the binding resolves it. Unsupported on HTML5, where assignProgrammerSound returns FMOD_ERR_UNSUPPORTED.

## studio_system_getuserdata
<!-- Studio::System::getUserData -->
Not exposed. Userdata on FMOD objects is left out because the binding's handle table already carries object identity. Keep your own map from the handle to your data, handles are ints and work as keys.

## studio_system_isvalid
<!-- Studio::System::isValid -->
haxefmod covers this with FmodManager.IsInitialized(), which reports true once the Studio system and the default banks are usable. On HTML5 initialization is asynchronous, so games gate their first scene on it.
```haxe
if (FmodManager.IsInitialized()) {
    startGame();
}
```

## studio_system_loadbankcustom
<!-- Studio::System::loadBankCustom -->
Not exposed. Custom file systems need IO callbacks that run on FMOD threads, which no Haxe target can do safely. StudioSystem.loadBankFile and loadBankMemory are the supported bank paths, and CoreSound.create and CoreSound.fromPcm are the sound paths.

## studio_system_registerplugin
<!-- Studio::System::registerPlugin -->
Not exposed. Third-party plugins and custom codecs, DSPs, and outputs run code on FMOD threads, which no Haxe target can do, and the web build has no plugin host at all. The 33 built-in DSP types are bound through Dsp.create.

## studio_system_setadvancedsettings
<!-- Studio::System::setAdvancedSettings -->
Not exposed. The library owns init, and FMOD_STUDIO_ADVANCEDSETTINGS is left at its defaults on every target. The init-time options haxefmod supports are the FmodSettings fields and the haxefmod_* compile-time defines.

## studio_system_setcallback
<!-- Studio::System::setCallback -->
Not exposed. Studio system callbacks would run on FMOD threads, which no Haxe target can do safely. Bank loading is synchronous through StudioSystem.loadBankFile, and Bank.getLoadingState reports the state.

## studio_system_setparametersbyids
<!-- Studio::System::setParametersByIDs -->
haxefmod covers this with one StudioSystem.setParameterByID() call per global parameter. The call is cheap, and FMOD applies the values on the next update either way.
```haxe
import haxefmod.studio.Types;

var ids:Array<FmodParameterId> = [{data1: 0, data2: 0}];
var values = [0.5];
for (i in 0...ids.length) {
    StudioSystem.setParameterByID(ids[i], values[i]);
}
```

## studio_system_setuserdata
<!-- Studio::System::setUserData -->
Not exposed. Userdata on FMOD objects is left out because the binding's handle table already carries object identity. Keep your own map from the handle to your data, handles are ints and work as keys.

## studio_system_unregisterplugin
<!-- Studio::System::unregisterPlugin -->
Not exposed. Third-party plugins and custom codecs, DSPs, and outputs run code on FMOD threads, which no Haxe target can do, and the web build has no plugin host at all. The 33 built-in DSP types are bound through Dsp.create.
