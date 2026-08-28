# core-api-system

## FMOD_3D_ROLLOFF_CALLBACK
verdict: cannot The callback runs on FMOD's mixer thread and no Haxe target can execute code there. A curve of points passed to set3DCustomRolloff on Sound, Channel, or ChannelGroup shapes the rolloff instead, and the rolloff flags of ChannelMode select the built-in curves.

## FMOD_ADVANCEDSETTINGS
verdict: bound
Type: haxefmod.studio.Types.FmodAdvancedSettings
Set at init through the FmodSettings fields of the same names and read back with StudioSystem.getAdvancedSettings. The fields not listed here keep FMOD's defaults.

## FMOD_ASYNCREADINFO
verdict: cannot The struct is handed to the async file callbacks, which run on FMOD's file threads, and custom file systems are not exposed. Sound.create reads the platform file system and StudioSystem.loadBankMemory takes bytes.

## FMOD_CREATESOUNDEXINFO
verdict: library Sound.create, Sound.fromMemory, and Sound.fromPcm take its fields as arguments: the length of a memory image, the initial subsound of an FSB, and the format, rate, and channel count of raw PCM.

## FMOD_DRIVER_STATE
verdict: bound
Type: haxefmod.studio.Types.FmodDriverState
The state field of StudioSystem.getRecordDriverInfo. Output drivers are listed by CoreSystem.getDriverCount and getDriverName without a state.

## FMOD_DSP_RESAMPLER
verdict: bound
Type: haxefmod.studio.Types.FmodDspResampler
The resampler method is not among the FmodSettings fields, DEFAULT applies.

## FMOD_ERRORCALLBACK_INFO
verdict: library Error callbacks are not exposed. Every call returns its FmodResult and StudioSystem.lastResult() keeps the result of the last getter.

## FMOD_ERRORCALLBACK_INSTANCETYPE
verdict: bound
Type: haxefmod.studio.Types.FmodErrorCallbackInstanceType
Error callbacks are not exposed, check the FmodResult each call returns instead.

## FMOD_FILE_ASYNCCANCEL_CALLBACK
verdict: cannot The callback runs on FMOD's file threads and no Haxe target can execute code there. Sound.create reads the platform file system and StudioSystem.loadBankMemory takes bytes.

## FMOD_FILE_ASYNCDONE_FUNC
verdict: cannot The function is called from FMOD's file threads and no Haxe target can execute code there. Sound.create reads the platform file system and StudioSystem.loadBankMemory takes bytes.

## FMOD_FILE_ASYNCREAD_CALLBACK
verdict: cannot The callback runs on FMOD's file threads and no Haxe target can execute code there. Sound.create reads the platform file system and StudioSystem.loadBankMemory takes bytes.

## FMOD_FILE_CLOSE_CALLBACK
verdict: cannot The callback runs on FMOD's file threads and no Haxe target can execute code there. Sound.create reads the platform file system and StudioSystem.loadBankMemory takes bytes.

## FMOD_FILE_OPEN_CALLBACK
verdict: cannot The callback runs on FMOD's file threads and no Haxe target can execute code there. Sound.create reads the platform file system and StudioSystem.loadBankMemory takes bytes.

## FMOD_FILE_READ_CALLBACK
verdict: cannot The callback runs on FMOD's file threads and no Haxe target can execute code there. Sound.create reads the platform file system and StudioSystem.loadBankMemory takes bytes.

## FMOD_FILE_SEEK_CALLBACK
verdict: cannot The callback runs on FMOD's file threads and no Haxe target can execute code there. Sound.create reads the platform file system and StudioSystem.loadBankMemory takes bytes.

## FMOD_INITFLAGS
verdict: bound
Type: haxefmod.studio.Types.FmodInitFlags
The library composes the flags at init. FmodSettings.profiling sets PROFILE_ENABLE and FmodSettings.distanceFilter sets CHANNEL_DISTANCEFILTER, the other bits stay clear.

## FMOD_OUTPUTTYPE
verdict: bound
Type: haxefmod.studio.Types.FmodOutputType
Read with CoreSystem.getOutput. The library picks AUTODETECT at init.

## FMOD_PLUGINLIST
verdict: cannot A static plugin list holds pointers to plugin descriptions written in C. A compiled plugin loads with StudioSystem.loadPlugin.

## FMOD_PLUGINTYPE
verdict: bound
Type: haxefmod.studio.Types.FmodPluginType

## FMOD_PORT_INDEX
verdict: cannot Console port routing is not exposed. Desktop and web targets have no ports.

## FMOD_PORT_TYPE
verdict: bound
Type: haxefmod.studio.Types.FmodPortType
Console port routing is not exposed. Desktop and web targets have no ports.

## FMOD_REVERB_MAXINSTANCES
verdict: covered The four reverb instances are addressed by index 0 to 3 on Reverb.set, Reverb.get, and Reverb.off.

## FMOD_REVERB_PRESETS
verdict: covered Every preset is a ReverbProperties static on Reverb with the same name, Reverb.PRESET_OFF through Reverb.PRESET_UNDERWATER, for Reverb.set.

## FMOD_REVERB_PROPERTIES
verdict: bound
Type: haxefmod.core.Reverb.ReverbProperties

## FMOD_SYSTEM_CALLBACK
verdict: bound
Shape: usage
The native callback runs on FMOD's threads, so it is not exposed. StudioSystem.setSystemCallback takes one handler and delivers DeviceListChanged and DeviceLost from FmodManager.Update() on the game thread as SystemEvent, next to the Studio system events.
The command data and user data pointers have no Haxe side. On HTML5 the device events never fire under the browser output.
```haxe
StudioSystem.setSystemCallback(event -> switch (event) {
    case DeviceListChanged: trace("device list changed");
    case DeviceLost: trace("device lost");
    default:
});
```

## FMOD_SYSTEM_CALLBACK_TYPE
verdict: bound
Type: haxefmod.studio.Types.FmodSystemCallbackType
StudioSystem.setSystemCallback delivers DEVICELISTCHANGED and DEVICELOST, its coreMask takes the CORE_* constants of SystemCallbacks. The other types are not delivered.

## System::setDSPBufferSize
verdict: bound
Native only (unsupported in HTML5).
FmodRuntime.settings() reports the values init ran with, 0 for a buffer left at FMOD's default.
```haxe
import haxefmod.core.CoreSystem;
import haxefmod.runtime.FmodRuntime;

var blocksize = FmodRuntime.settings().dspBufferSize;
var numblocks = FmodRuntime.settings().dspNumBuffers;
var frequency = CoreSystem.getSoftwareFormat().sampleRate;

var ms = blocksize * 1000.0 / frequency;

trace('Mixer blocksize        = $ms ms');
trace('Mixer Total buffersize = ${ms * numblocks} ms');
trace('Mixer Average Latency  = ${ms * (numblocks - 1.5)} ms');
```

## System::setSpeakerPosition
verdict: bound
```haxe
import haxefmod.core.CoreSystem;
import haxefmod.studio.Types.FmodSpeaker;

CoreSystem.setSpeakerPosition(FmodSpeaker.FRONT_LEFT, -1.0, 0.0, true);
CoreSystem.setSpeakerPosition(FmodSpeaker.FRONT_RIGHT, 1.0, 0.0, true);
```

## System::setSpeakerPosition#2
verdict: bound
```haxe
import haxefmod.core.CoreSystem;
import haxefmod.studio.Types.FmodSpeaker;

CoreSystem.setSpeakerPosition(FmodSpeaker.FRONT_LEFT, -1.0, 0.0, true);
CoreSystem.setSpeakerPosition(FmodSpeaker.FRONT_RIGHT, 1.0, 0.0, true);
```

## System::setSpeakerPosition#3
verdict: bound
```haxe
import haxefmod.core.CoreSystem;
import haxefmod.studio.Types.FmodSpeaker;

var degtorad = (degrees:Float) -> degrees * Math.PI / 180;

CoreSystem.setSpeakerPosition(FmodSpeaker.FRONT_LEFT, Math.sin(degtorad(-30)), Math.cos(degtorad(-30)), true);
CoreSystem.setSpeakerPosition(FmodSpeaker.FRONT_RIGHT, Math.sin(degtorad(30)), Math.cos(degtorad(30)), true);
CoreSystem.setSpeakerPosition(FmodSpeaker.FRONT_CENTER, Math.sin(degtorad(0)), Math.cos(degtorad(0)), true);
CoreSystem.setSpeakerPosition(FmodSpeaker.LOW_FREQUENCY, Math.sin(degtorad(0)), Math.cos(degtorad(0)), true);
CoreSystem.setSpeakerPosition(FmodSpeaker.SURROUND_LEFT, Math.sin(degtorad(-90)), Math.cos(degtorad(-90)), true);
CoreSystem.setSpeakerPosition(FmodSpeaker.SURROUND_RIGHT, Math.sin(degtorad(90)), Math.cos(degtorad(90)), true);
CoreSystem.setSpeakerPosition(FmodSpeaker.BACK_LEFT, Math.sin(degtorad(-150)), Math.cos(degtorad(-150)), true);
CoreSystem.setSpeakerPosition(FmodSpeaker.BACK_RIGHT, Math.sin(degtorad(150)), Math.cos(degtorad(150)), true);
```

## System::setSpeakerPosition#4
verdict: bound
```haxe
import haxefmod.core.CoreSystem;
import haxefmod.studio.Types.FmodSpeaker;

var degtorad = (degrees:Float) -> degrees * Math.PI / 180;

CoreSystem.setSpeakerPosition(FmodSpeaker.FRONT_LEFT, Math.sin(degtorad(-30)), Math.cos(degtorad(-30)), true);
CoreSystem.setSpeakerPosition(FmodSpeaker.FRONT_RIGHT, Math.sin(degtorad(30)), Math.cos(degtorad(30)), true);
CoreSystem.setSpeakerPosition(FmodSpeaker.FRONT_CENTER, Math.sin(degtorad(0)), Math.cos(degtorad(0)), true);
CoreSystem.setSpeakerPosition(FmodSpeaker.LOW_FREQUENCY, Math.sin(degtorad(0)), Math.cos(degtorad(0)), true);
CoreSystem.setSpeakerPosition(FmodSpeaker.SURROUND_LEFT, Math.sin(degtorad(-90)), Math.cos(degtorad(-90)), true);
CoreSystem.setSpeakerPosition(FmodSpeaker.SURROUND_RIGHT, Math.sin(degtorad(90)), Math.cos(degtorad(90)), true);
CoreSystem.setSpeakerPosition(FmodSpeaker.BACK_LEFT, Math.sin(degtorad(-150)), Math.cos(degtorad(-150)), true);
CoreSystem.setSpeakerPosition(FmodSpeaker.BACK_RIGHT, Math.sin(degtorad(150)), Math.cos(degtorad(150)), true);
```
