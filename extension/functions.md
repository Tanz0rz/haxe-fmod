# functions

## channelcontrol_getsystemobject
<!-- ChannelControl::getSystemObject -->
verdict: bound
haxefmod has one core system, and haxefmod.core.CoreSystem reaches it directly, so no object needs to hand it back.
```haxe
import haxefmod.core.CoreSystem;

var format = CoreSystem.getSoftwareFormat();
```

## channelcontrol_getmixmatrix
<!-- ChannelControl::getMixMatrix -->
verdict: bound
The matrix comes back as a struct instead of three out parameters: one flat row-major Array<Float> with inChannelHop floats per row (0 = packed to the input count), and the output and input channel counts FMOD reports. Every argument is optional. outChannels and inChannels above 0 keep only that many rows and columns. Native only, the web glue binds the matrix as a single float.
```haxe
var read = channel.getMixMatrix();
if (read != null) {
    var gains = read.matrix; // read.outChannels rows of read.inChannels floats
}
var hopped = channel.getMixMatrix(0, 0, 8); // rows padded to 8 floats
```

## channelcontrol_setmixmatrix
<!-- ChannelControl::setMixMatrix -->
verdict: bound
The matrix is one flat row-major Array<Float>, one row per output channel, with inChannelHop floats per row (0 = packed to inChannels). FMOD mixes at most 32 channels, so a shape outside 32 by 32 or a hop below inChannels is refused with FMOD_ERR_INVALID_PARAM before the call reaches FMOD.
```haxe
var result = channel.setMixMatrix([1, 0, 0, 1], 2, 2);
var padded = channel.setMixMatrix([1, 0, 0, 0, 0, 1, 0, 0], 2, 2, 4);
```

## dspconnection_getmixmatrix
<!-- DSPConnection::getMixMatrix -->
verdict: bound
The matrix comes back as a struct instead of three out parameters: one flat row-major Array<Float> with inChannelHop floats per row (0 = packed to the input count), and the output and input channel counts FMOD reports. Every argument is optional. Native only, the web glue binds the matrix as a single float.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var fft = Dsp.create(DspType.FFT);
var connection = fft.addInput(Dsp.create(DspType.OSCILLATOR));
var read = connection.getMixMatrix();
if (read != null) {
    var gains = read.matrix; // read.outChannels rows of read.inChannels floats
}
```

## dspconnection_setmixmatrix
<!-- DSPConnection::setMixMatrix -->
verdict: bound
The matrix is one flat row-major Array<Float>, one row per output channel, with inChannelHop floats per row (0 = packed to inChannels). FMOD mixes at most 32 channels, so a shape outside 32 by 32 or a hop below inChannels is refused with FMOD_ERR_INVALID_PARAM before the call reaches FMOD.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var fft = Dsp.create(DspType.FFT);
var connection = fft.addInput(Dsp.create(DspType.OSCILLATOR));
var result = connection.setMixMatrix([0.5, 0, 0, 0.5], 2, 2);
```

## file_getdiskbusy
<!-- File_GetDiskBusy -->
verdict: cannot The disk busy flag belongs to the custom file system callbacks, which FMOD runs on its streaming thread, and no Haxe target can execute code there.

## file_setdiskbusy
<!-- File_SetDiskBusy -->
verdict: cannot The disk busy flag belongs to the custom file system callbacks, which FMOD runs on its streaming thread, and no Haxe target can execute code there.

## memory_initialize
<!-- Memory_Initialize -->
verdict: bound
Covered by FmodSettings. The fixed pool form runs through memoryPoolSize, a byte count the library allocates and hands to FMOD before the system is created. The pool never grows, so an exhausted pool fails later calls with FMOD_ERR_MEMORY. The callback arguments are not exposed, an allocator would run on every FMOD thread. Native only, the web build allocates from the wasm heap.
```haxe
FmodManager.Initialize({memoryPoolSize: 64 * 1024 * 1024});
```

## thread_setattributes
<!-- Thread_SetAttributes -->
verdict: bound
Covered by FmodSettings. Each threadAttributes entry names a thread type with the priority, stack size, and core affinity to give it, applied before the system is created. An unset field keeps FMOD's default. affinity is a 32-bit core mask, FMOD's 64-bit group values stay as they are. Native only, the web build has no threads to place.
```haxe
import haxefmod.studio.Types;

FmodManager.Initialize({threadAttributes: [
    {type: FmodThreadType.MIXER, affinity: FmodThreadAffinity.CORE_5},
    {type: FmodThreadType.STREAM, priority: FmodThreadPriority.HIGH, stackSize: FmodThreadStackSize.STREAM},
]});
```

## debug_initialize
<!-- Debug_Initialize -->
verdict: bound
Covered by FmodSettings. logLevel picks the level bits and goes to the console on every target. logFile sends the log to a file instead, and logFlags adds the TYPE_ and DISPLAY_ bits (memory, file, codec, trace, and virtual voice lines, timestamps, line numbers, thread ids). The callback mode is not exposed, FMOD would call it from whichever thread logs. logFile and logFlags are native only. The logging-stripped FMOD libraries write nothing anywhere.
```haxe
import haxefmod.studio.Types;

FmodManager.Initialize({logLevel: 3, logFile: "fmod.log", logFlags: FmodDebugFlags.TYPE_FILE | FmodDebugFlags.DISPLAY_TIMESTAMPS});
```

## system_setoutput
<!-- System::setOutput -->
verdict: bound
Covered by FmodSettings. FMOD only takes the output type before init, so pass output to FmodManager.Initialize(). NOSOUND and NOSOUND_NRT mix without a device, WAVWRITER writes the mix to a file, and the platform values pick a driver on the platform that has it. The FMOD_WAVWRITER environment variable still wins when set. On HTML5 only WEBAUDIO, AUDIOWORKLET, NOSOUND, and NOSOUND_NRT exist and any other value fails init with FMOD_ERR_UNSUPPORTED. CoreSystem.getOutput reports the type in use.
```haxe
import haxefmod.studio.Types;

FmodManager.Initialize({output: FmodOutputType.NOSOUND_NRT});
```

## dsp_getinfo
<!-- DSP::getInfo -->
verdict: bound
Dsp.getInfo() returns the name, version, channels, configwidth, and configheight fields together. Dsp.getName() returns the name alone.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var unit = Dsp.create(DspType.COMPRESSOR);
var info = unit.getInfo();
if (info != null) {
    trace('${info.name} ${info.version} ${info.channels}');
}
```

## dsp_getmeteringinfo
<!-- DSP::getMeteringInfo -->
verdict: bound
One side per call. Dsp.getMetering() reads the output side, getMetering(true) or getInputMetering() the input side. The result carries peak, rms, numChannels, and numSamples.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var unit = Dsp.create(DspType.FADER);
unit.setMeteringEnabled(true, true);
var output = unit.getMetering();
var input = unit.getInputMetering();
```

## dsp_getparameterdata
<!-- DSP::getParameterData -->
verdict: bound
Dsp.getParameterData(index) returns a copy of the block as bytes in the effect's C layout, and the typed readers decode the common formats: getFftSpectrumInfo() for FMOD_DSP_PARAMETER_FFT, getOverallGain() for FMOD_DSP_PARAMETER_OVERALLGAIN, getLoudnessMeterInfo() for FMOD_DSP_LOUDNESS_METER_INFO_TYPE. On HTML5 the web glue types the block instead of exposing its bytes, so only the overall gain, FFT, dynamic response, and attenuation range payloads come back and getLoudnessMeterInfo is a compile error.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;
import haxefmod.studio.Types;

var fader = Dsp.create(DspType.FADER);
var gain = fader.getOverallGain();
var index = fader.getDataParameterIndex(FmodDspParameterDataType.OVERALLGAIN);
var raw = fader.getParameterData(index);
if (raw != null) {
    var linearGain = raw.getFloat(0);
}
```

## dsp_getsystemobject
<!-- DSP::getSystemObject -->
verdict: bound
haxefmod has one core system, and haxefmod.core.CoreSystem reaches it directly, so no object needs to hand it back.
```haxe
import haxefmod.core.CoreSystem;

var format = CoreSystem.getSoftwareFormat();
```

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
verdict: bound
haxefmod does this for you on HTML5. The banks named in FmodSettings.autoLoadBanks are fetched during init, and StudioSystem.loadBankFile() fetches any other bank and places it in the wasm file system before loading it.
```haxe
import haxefmod.studio.Bank;

var bank:Bank = StudioSystem.loadBankFile("assets/fmod/Desktop/Level1.bank");
```

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
verdict: bound
haxefmod has one core system, and haxefmod.core.CoreSystem reaches it directly, so no object needs to hand it back.
```haxe
import haxefmod.core.CoreSystem;

var format = CoreSystem.getSoftwareFormat();
```

## sound_lock
<!-- Sound::lock -->
verdict: cannot It returns a raw pointer into the sample buffer, which has no meaning in Haxe. Sound.readData covers reading, it copies decoded PCM out of a sound opened with the openOnly flag of Sound.create, and seekData moves the read cursor. Both are native only (unsupported in HTML5), where the call returns FMOD_ERR_UNSUPPORTED.
```haxe
import haxefmod.core.Sound;

var sound = Sound.create("assets/sfx/engine.wav", false, true);
var buffer = haxe.io.Bytes.alloc(4096);
var read = sound.readData(buffer);
while (read > 0) {
    // the first read bytes of buffer hold decoded PCM
    read = sound.readData(buffer);
}
sound.release();
```

## sound_unlock
<!-- Sound::unlock -->
verdict: cannot It returns a raw pointer into the sample buffer, which has no meaning in Haxe. Sound.readData covers reading, it copies decoded PCM out of a sound opened with the openOnly flag of Sound.create, and seekData moves the read cursor. Both are native only (unsupported in HTML5), where the call returns FMOD_ERR_UNSUPPORTED.
```haxe
import haxefmod.core.Sound;

var sound = Sound.create("assets/sfx/engine.wav", false, true);
var buffer = haxe.io.Bytes.alloc(4096);
var read = sound.readData(buffer);
while (read > 0) {
    // the first read bytes of buffer hold decoded PCM
    read = sound.readData(buffer);
}
sound.release();
```

## soundgroup_getsystemobject
<!-- SoundGroup::getSystemObject -->
verdict: bound
haxefmod has one core system, and haxefmod.core.CoreSystem reaches it directly, so no object needs to hand it back.
```haxe
import haxefmod.core.CoreSystem;

var format = CoreSystem.getSoftwareFormat();
```

## system_attachchannelgrouptoport
<!-- System::attachChannelGroupToPort -->
verdict: bound
Bound for builds against a console SDK. Desktop outputs have no ports and FMOD reports that in the result. Unsupported in HTML5, where the call returns FMOD_ERR_UNSUPPORTED.
```haxe
import haxefmod.core.ChannelGroup;
import haxefmod.core.CoreSystem;
import haxefmod.studio.Types;

var music = ChannelGroup.create("music");
var attached = CoreSystem.attachChannelGroupToPort(FmodPortType.MUSIC, FmodPortIndex.NONE, music, true);
```

## system_attachfilesystem
<!-- System::attachFileSystem -->
verdict: cannot A custom file system is a set of callbacks that FMOD runs on its streaming and loading threads, and no Haxe target can execute code there. StudioSystem.loadBankFile and loadBankMemory are the bank paths, and Sound.create and Sound.fromPcm are the sound paths.

## system_close
<!-- System::close -->
verdict: bound
haxefmod owns this. The system is never closed, FMOD initializes once in FmodManager.Initialize() and lives until the process exits. Use FmodManager.PauseAllSounds() or CoreSystem.mixerSuspend() when the game goes to the background.
```haxe
import haxefmod.core.CoreSystem;

CoreSystem.mixerSuspend();
// later
CoreSystem.mixerResume();
```

## system_create
<!-- System_Create -->
verdict: bound
haxefmod calls this for you. FmodManager.Initialize() (or FmodRuntime.init()) creates and initializes the Studio system and its core system in one step, and the engine lives until the process exits. Init-time options come from FmodSettings.
```haxe
FmodManager.Initialize({numChannels: 256, sampleRate: 48000});
```

## system_createdsp
<!-- System::createDSP -->
verdict: cannot A DSP description is a struct of callbacks that FMOD runs on its mixer thread, and no Haxe target can execute code there. All 33 built-in DSP types are created with Dsp.create(type), and a unit from a loaded plugin with Dsp.createByPlugin(handle).

## system_createdspconnection
<!-- System::createDSPConnection -->
verdict: bound
haxefmod covers this with Dsp.addInput(), which connects two units and returns the DspConnection for the link.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var reverb = Dsp.create(DspType.SFXREVERB);
var fft = Dsp.create(DspType.FFT);
var connection = fft.addInput(reverb);
connection.setMix(0.5);
```

## system_createstream
<!-- System::createStream -->
verdict: bound
haxefmod covers streams two ways. Sound.create() with ChannelMode.CREATESTREAM opens a file as a stream, and PcmStream.create() opens a stream that Haxe code feeds with raw PCM, which is the one path that works on HTML5 as well.
```haxe
import haxefmod.core.ChannelMode;
import haxefmod.core.PcmStream;
import haxefmod.core.Sound;

var music = Sound.create("assets/music/level1.ogg", true, false, ChannelMode.CREATESTREAM);
var stream = PcmStream.create(44100, 2);
var channel = stream.play();
```

## system_detachchannelgroupfromport
<!-- System::detachChannelGroupFromPort -->
verdict: bound
Bound for builds against a console SDK. Unsupported in HTML5, where the call returns FMOD_ERR_UNSUPPORTED.
```haxe
import haxefmod.core.ChannelGroup;
import haxefmod.core.CoreSystem;

var music = ChannelGroup.create("music");
var detached = CoreSystem.detachChannelGroupFromPort(music);
```

## system_get3dlistenerattributes
<!-- System::get3DListenerAttributes -->
verdict: bound
haxefmod covers this with StudioSystem.getListenerAttributes(). Studio drives the core listeners, so the Studio listener is the core listener.
```haxe
var listener = StudioSystem.getListenerAttributes(0);
if (listener != null) {
    trace('listener at ${listener.position.x}, ${listener.position.y}');
}
```

## system_get3dnumlisteners
<!-- System::get3DNumListeners -->
verdict: bound
haxefmod covers this with StudioSystem.getNumListeners(). Studio drives the core listeners, so the Studio count is the core count.
```haxe
var listeners = StudioSystem.getNumListeners();
```

## system_getcpuusage
<!-- System::getCPUUsage -->
verdict: bound
haxefmod covers this with StudioSystem.getCpuUsage(), which returns the core mixer, stream, geometry, update, and convolution figures next to the Studio update time.
```haxe
var usage = StudioSystem.getCpuUsage();
if (usage != null) {
    trace('dsp ${usage.dsp}% update ${usage.update}%');
}
```

## system_getdspbuffersize
<!-- System::getDSPBufferSize -->
verdict: bound
Covered by FmodSettings. The mixer buffer is set once at init through dspBufferSize and dspNumBuffers, and FmodRuntime.settings() reports the values the engine started with, 0 when FMOD's default was kept. Both are native only (unsupported in HTML5), where the web build fixes the mixer at 2048 samples by 2 buffers.
```haxe
import haxefmod.runtime.FmodRuntime;

FmodManager.Initialize({dspBufferSize: 512, dspNumBuffers: 4});
var settings = FmodRuntime.settings();
trace('mixer ${settings.dspBufferSize} x ${settings.dspNumBuffers}');
```

## system_getoutputhandle
<!-- System::getOutputHandle -->
verdict: cannot It returns a raw operating system pointer, which has no meaning in Haxe. Output device selection goes through CoreSystem.getDriverCount, getDriverName, and setDriver.

## system_getsoftwarechannels
<!-- System::getSoftwareChannels -->
verdict: bound
Covered by FmodSettings. The audible voice cap is set once at init through softwareChannels, and FmodRuntime.settings().softwareChannels reports the value the engine started with, 0 when FMOD's default of 64 was kept.
```haxe
import haxefmod.runtime.FmodRuntime;

FmodManager.Initialize({softwareChannels: 128});
var voices = FmodRuntime.settings().softwareChannels;
```

## system_getstreambuffersize
<!-- System::getStreamBufferSize -->
verdict: bound
Covered by FmodSettings. The file stream buffer is set once at init through streamBufferSize, and FmodRuntime.settings().streamBufferSize reports the value the engine started with, 0 when FMOD's default of 16384 bytes was kept. PcmStream.space() reports how much room a stream you feed yourself has left.
```haxe
import haxefmod.runtime.FmodRuntime;

FmodManager.Initialize({streamBufferSize: 65536});
var bytes = FmodRuntime.settings().streamBufferSize;
```

## system_init
<!-- System::init -->
verdict: bound
haxefmod calls this for you. FmodManager.Initialize() (or FmodRuntime.init()) creates and initializes the Studio system and its core system in one step, and the engine lives until the process exits. Init-time options come from FmodSettings.
```haxe
FmodManager.Initialize({numChannels: 256, sampleRate: 48000});
```

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
verdict: bound
haxefmod owns this. There is no shutdown or re-init, FMOD initializes once in FmodManager.Initialize() and lives until the process exits, so no use-after-shutdown bug can occur. Stop or release your own objects instead of closing the system.
```haxe
FmodManager.StopAllSounds();
```

## system_set3dlistenerattributes
<!-- System::set3DListenerAttributes -->
verdict: bound
haxefmod covers this with StudioSystem.setListenerPosition2D() for 2D games and StudioSystem.setListenerAttributes() for the full struct. Studio drives the core listeners, so setting the Studio listener sets the core one.
```haxe
StudioSystem.setListenerPosition2D(0, cameraX, cameraY);
```

## system_set3dnumlisteners
<!-- System::set3DNumListeners -->
verdict: bound
haxefmod covers this with StudioSystem.setNumListeners(). Studio drives the core listeners, so the count is set once on the Studio system and the core system follows.
```haxe
StudioSystem.setNumListeners(2);
```

## system_set3drolloffcallback
<!-- System::set3DRolloffCallback -->
verdict: cannot FMOD runs the callback on its mixer thread, and no Haxe target can execute code there. Channel.set3DCustomRolloff takes a curve of points instead, and the built-in rolloff modes are set through Channel.setMode and ChannelGroup.setMode.

## system_setadvancedsettings
<!-- System::setAdvancedSettings -->
verdict: bound
haxefmod applies these before init from FmodSettings, which carries maxMPEGCodecs, maxVorbisCodecs, maxFADPCMCodecs, vol0VirtualVol, defaultDecodeBufferSize, profilePort, geometryMaxFadeTime, distanceFilterCenterFreq, and randomSeed. Zero or null keeps FMOD's default for a field. Read them back with StudioSystem.getAdvancedSettings() (unsupported in HTML5, returns null there).
```haxe
FmodManager.Initialize({vol0VirtualVol: 0.001, randomSeed: 42});
```

## system_setdspbuffersize
<!-- System::setDSPBufferSize -->
verdict: bound
Covered by FmodSettings. FMOD only accepts the mixer buffer before init, so pass dspBufferSize (samples) and dspNumBuffers to FmodManager.Initialize(). Both apply on every target, the web build's default is 2048 samples by 2 buffers.
```haxe
FmodManager.Initialize({dspBufferSize: 512, dspNumBuffers: 4});
```

## system_setfilesystem
<!-- System::setFileSystem -->
verdict: cannot A custom file system is a set of callbacks that FMOD runs on its streaming and loading threads, and no Haxe target can execute code there. StudioSystem.loadBankFile and loadBankMemory are the bank paths, and Sound.create and Sound.fromPcm are the sound paths.

## system_setsoftwarechannels
<!-- System::setSoftwareChannels -->
verdict: bound
Covered by FmodSettings. FMOD only accepts the audible voice cap before init, so pass softwareChannels to FmodManager.Initialize(). It is separate from numChannels, which is the virtual voice count Studio initializes with.
```haxe
FmodManager.Initialize({numChannels: 256, softwareChannels: 128});
```

## system_setstreambuffersize
<!-- System::setStreamBufferSize -->
verdict: bound
Covered by FmodSettings. FMOD only accepts the file stream buffer before init, so pass streamBufferSize (bytes) to FmodManager.Initialize(). The ringBytes argument of PcmStream.create sizes the buffer of a stream you feed yourself.
```haxe
FmodManager.Initialize({streamBufferSize: 65536});
```

## system_update
<!-- System::update -->
verdict: bound
haxefmod calls this for you. FmodManager.Update() (or FmodRuntime.update()) services the Studio system once per frame, which updates the core system as well, and a background thread keeps audio running between frames.
```haxe
FmodManager.Update();
```

## studio_bus_getportindex
<!-- Studio::Bus::getPortIndex -->
verdict: cannot This is a console port API and haxefmod targets desktop and web only. Route audio through ChannelGroup and Bus instead.

## studio_bus_setportindex
<!-- Studio::Bus::setPortIndex -->
verdict: cannot This is a console port API and haxefmod targets desktop and web only. Route audio through ChannelGroup and Bus instead.

## studio_commandreplay_getsystem
<!-- Studio::CommandReplay::getSystem -->
verdict: bound
haxefmod has one Studio system, and StudioSystem reaches it directly, so a replay never needs to hand it back.
```haxe
var replay = StudioSystem.loadCommandReplay("capture.cmd.txt");
replay.start();
```

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
verdict: bound
haxefmod passes GUIDs as strings, so there is nothing to parse. StudioSystem.getEventByID, getBusByID, getVCAByID, and getBankByID accept the braced string, and StudioSystem.lookupID converts a path to one.
```haxe
var guid = StudioSystem.lookupID(FmodEvents.MusicMainLevel);
var description = StudioSystem.getEventByID(guid);
```

## studio_eventdescription_getparameterdescriptionbyid
<!-- Studio::EventDescription::getParameterDescriptionByID -->
verdict: bound
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
verdict: bound
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
verdict: bound
haxefmod covers this with EventDescription.getParameterDescriptionByIndex() followed by getParameterLabel() with the parameter's name, or getParameterLabelByID() with its id.
```haxe
var description = StudioSystem.getEvent(FmodEvents.SFXEngine);
var parameter = description.getParameterDescriptionByIndex(0);
if (parameter != null) {
    var label = description.getParameterLabel(parameter.name, 0);
}
```

## studio_eventdescription_getuserproperty
<!-- Studio::EventDescription::getUserProperty -->
verdict: bound
haxefmod covers this with EventDescription.getUserPropertyByName(). Numeric typed properties are native only (unsupported in HTML5), where the call returns FMOD_ERR_UNSUPPORTED because of a defect in FMOD's JS runtime, and string typed properties read on every target.
```haxe
var description = StudioSystem.getEvent(FmodEvents.MusicMainLevel);
var property = description.getUserPropertyByName("Author");
if (property != null) {
    trace(property.name);
}
```

## studio_eventdescription_setcallback
<!-- Studio::EventDescription::setCallback -->
verdict: bound
haxefmod covers this with EventDescription.setCallback(handler, ?mask), which remembers a handler that createInstance installs on every instance made from the description from then on. The events are queued on FMOD's thread and delivered as typed EventCallbackData from FmodManager.Update() on the game thread.
```haxe
var description = StudioSystem.getEvent(FmodEvents.SFXEngine);
description.setCallback(data -> switch (data) {
    case Stopped: trace("engine stopped");
    default:
});
var instance = description.createInstance();
```

## studio_eventinstance_getsystem
<!-- Studio::EventInstance::getSystem -->
verdict: bound
haxefmod has one Studio system, and StudioSystem reaches it directly, so an instance never needs to hand it back.
```haxe
var bus = StudioSystem.getBus(FmodBuses.Music);
```

## studio_eventinstance_setparametersbyids
<!-- Studio::EventInstance::setParametersByIDs -->
verdict: bound
haxefmod covers this with one EventInstance.setParameterByID() call per parameter. The call is cheap, and FMOD applies the values on the next update either way.
```haxe
import haxefmod.studio.Types;

var ids:Array<FmodParameterId> = [{data1: 0, data2: 0}];
var values = [0.5];
for (i in 0...ids.length) {
    instance.setParameterByID(ids[i], values[i]);
}
```

## studio_system_getparameterdescriptionbyid
<!-- Studio::System::getParameterDescriptionByID -->
verdict: bound
haxefmod covers this with StudioSystem.getParameterDescriptionByID().
```haxe
var intensity = StudioSystem.getParameterDescriptionByName("Intensity");
if (intensity != null) {
    var again = StudioSystem.getParameterDescriptionByID(intensity.id);
}
```

## studio_system_getparameterlabelbyid
<!-- Studio::System::getParameterLabelByID -->
verdict: bound
haxefmod covers this with StudioSystem.getParameterLabelByID().
```haxe
var weather = StudioSystem.getParameterDescriptionByName("Weather");
if (weather != null) {
    var label = StudioSystem.getParameterLabelByID(weather.id, 0);
}
```

## studio_system_isvalid
<!-- Studio::System::isValid -->
verdict: bound
haxefmod covers this with FmodManager.IsInitialized(), which reports true once the Studio system and the default banks are usable. On HTML5 initialization is asynchronous, so games gate their first scene on it.
```haxe
if (FmodManager.IsInitialized()) {
    startGame();
}
```

## studio_system_loadbankcustom
<!-- Studio::System::loadBankCustom -->
verdict: cannot A custom file system is a set of callbacks that FMOD runs on its streaming and loading threads, and no Haxe target can execute code there. StudioSystem.loadBankFile and loadBankMemory are the bank paths, and Sound.create and Sound.fromPcm are the sound paths.

## studio_system_registerplugin
<!-- Studio::System::registerPlugin -->
verdict: cannot It takes a DSP description struct whose callbacks FMOD runs on its mixer thread, and no Haxe target can execute code there. A prebuilt plugin binary loads with StudioSystem.loadPlugin, which makes its effects available to Studio events.

## studio_system_setadvancedsettings
<!-- Studio::System::setAdvancedSettings -->
verdict: bound
haxefmod applies these before init from FmodSettings, which carries commandQueueSize, handleInitialSize, studioUpdatePeriod, idleSampleDataPoolSize, streamingScheduleDelay, and encryptionKey. Zero or null keeps FMOD's default for a field. Read them back with StudioSystem.getStudioAdvancedSettings() (unsupported in HTML5, returns null there).
```haxe
FmodManager.Initialize({commandQueueSize: 65536});
```

## studio_system_setparametersbyids
<!-- Studio::System::setParametersByIDs -->
verdict: bound
haxefmod covers this with one StudioSystem.setParameterByID() call per global parameter. The call is cheap, and FMOD applies the values on the next update either way.
```haxe
import haxefmod.studio.Types;

var ids:Array<FmodParameterId> = [{data1: 0, data2: 0}];
var values = [0.5];
for (i in 0...ids.length) {
    StudioSystem.setParameterByID(ids[i], values[i]);
}
```

## studio_system_unregisterplugin
<!-- Studio::System::unregisterPlugin -->
verdict: cannot It names a plugin registered from a description struct, and that registration cannot be bound because its callbacks would run on FMOD's mixer thread. A plugin loaded with StudioSystem.loadPlugin is unloaded with StudioSystem.unloadPlugin.

## fsbank_init
<!-- FSBANK_RESULT -->
verdict: cannot FSBank is FMOD's offline bank encoder, shipped as a separate tool library outside the runtime SDK. haxefmod links the runtime only, and banks are built with FMOD Studio.

## fsbank_build
<!-- FSBANK_RESULT -->
verdict: cannot FSBank is FMOD's offline bank encoder, shipped as a separate tool library outside the runtime SDK. haxefmod links the runtime only, and banks are built with FMOD Studio.

## fsbank_buildcancel
<!-- FSBANK_RESULT -->
verdict: cannot FSBank is FMOD's offline bank encoder, shipped as a separate tool library outside the runtime SDK. haxefmod links the runtime only, and banks are built with FMOD Studio.

## fsbank_release
<!-- FSBANK_RESULT -->
verdict: cannot FSBank is FMOD's offline bank encoder, shipped as a separate tool library outside the runtime SDK. haxefmod links the runtime only, and banks are built with FMOD Studio.

## fsbank_releaseprogressitem
<!-- FSBANK_RESULT -->
verdict: cannot FSBank is FMOD's offline bank encoder, shipped as a separate tool library outside the runtime SDK. haxefmod links the runtime only, and banks are built with FMOD Studio.

## fsbank_memorygetstats
<!-- FSBANK_RESULT -->
verdict: cannot FSBank is FMOD's offline bank encoder, shipped as a separate tool library outside the runtime SDK. haxefmod links the runtime only, and banks are built with FMOD Studio.

## fsbank_memoryinit
<!-- FSBANK_RESULT -->
verdict: cannot FSBank is FMOD's offline bank encoder, shipped as a separate tool library outside the runtime SDK. haxefmod links the runtime only, and banks are built with FMOD Studio.

## fsbank_fetchfsbmemory
<!-- FSBANK_RESULT -->
verdict: cannot FSBank is FMOD's offline bank encoder, shipped as a separate tool library outside the runtime SDK. haxefmod links the runtime only, and banks are built with FMOD Studio.

## fsbank_fetchnextprogressitem
<!-- FSBANK_RESULT -->
verdict: cannot FSBank is FMOD's offline bank encoder, shipped as a separate tool library outside the runtime SDK. haxefmod links the runtime only, and banks are built with FMOD Studio.

## sound_addsyncpoint
<!-- Sound::addSyncPoint -->
verdict: bound
The offset is read in the unit given as the last parameter, milliseconds when left out. FMOD's FMOD_SYNCPOINT handle is not returned. Points are addressed by their index in offset order in the other sync point calls and in ChannelEvent.SyncPoint.
```haxe
import haxefmod.core.Sound;
import haxefmod.studio.Types;

var sound = Sound.create("assets/music/track.wav");
sound.addSyncPoint(500, "drop");
sound.addSyncPoint(48000, "verse", FmodTimeUnit.PCM);
```

## sound_deletesyncpoint
<!-- Sound::deleteSyncPoint -->
verdict: bound
Takes the point's index in offset order instead of an FMOD_SYNCPOINT handle. The indices of later points shift down by one.
```haxe
import haxefmod.core.Sound;

var sound = Sound.create("assets/music/track.wav");
sound.deleteSyncPoint(0);
```

## sound_getsyncpoint
<!-- Sound::getSyncPoint -->
verdict: bound
There is no FMOD_SYNCPOINT handle on the Haxe side. The index in offset order is the address of a point, passed straight to getSyncPointName, getSyncPointOffset, and deleteSyncPoint.
```haxe
import haxefmod.core.Sound;

var sound = Sound.create("assets/music/track.wav");
for (i in 0...sound.getSyncPointCount()) {
    trace(sound.getSyncPointName(i));
}
```

## sound_getsyncpointinfo
<!-- Sound::getSyncPointInfo -->
verdict: bound
Split into getSyncPointName and getSyncPointOffset, both taking the index in offset order. The offset comes back in the unit given as the last parameter, milliseconds when left out.
```haxe
import haxefmod.core.Sound;
import haxefmod.studio.Types;

var sound = Sound.create("assets/music/track.wav");
var name = sound.getSyncPointName(0);
var ms = sound.getSyncPointOffset(0);
var samples = sound.getSyncPointOffset(0, FmodTimeUnit.PCM);
```
