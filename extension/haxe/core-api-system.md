# core-api-system

## FMOD_3D_ROLLOFF_CALLBACK
verdict: cannot The callback runs on FMOD's mixer thread and no Haxe target can execute code there. A curve of points passed to set3DCustomRolloff on Sound, Channel, or ChannelGroup shapes the rolloff instead, and the rolloff flags of ChannelMode select the built-in curves.

## FMOD_ADVANCEDSETTINGS
verdict: bound
Type: haxefmod.studio.Types.FmodAdvancedSettings

## FMOD_ASYNCREADINFO
verdict: cannot The struct is handed to the async file callbacks, which run on FMOD's file threads, and custom file systems are not exposed. Sound.create reads the platform file system and StudioSystem.loadBankMemory takes bytes.

## FMOD_CREATESOUNDEXINFO
verdict: bound
Type: haxefmod.studio.Types.FmodCreateSoundExInfo

## FMOD_DRIVER_STATE
verdict: bound
Type: haxefmod.studio.Types.FmodDriverState

## FMOD_DSP_RESAMPLER
verdict: bound
Type: haxefmod.studio.Types.FmodDspResampler

## FMOD_ERRORCALLBACK_INFO
verdict: bound
Type: haxefmod.studio.Types.FmodErrorCallbackInfo

## FMOD_ERRORCALLBACK_INSTANCETYPE
verdict: bound
Type: haxefmod.studio.Types.FmodErrorCallbackInstanceType

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

## FMOD_OUTPUTTYPE
verdict: bound
Type: haxefmod.studio.Types.FmodOutputType

## FMOD_PLUGINLIST
verdict: bound
Type: haxefmod.studio.Types.FmodPluginList

## FMOD_PLUGINTYPE
verdict: bound
Type: haxefmod.studio.Types.FmodPluginType

## FMOD_PORT_INDEX
verdict: bound
Type: haxefmod.studio.Types.FmodPortIndex

## FMOD_PORT_TYPE
verdict: bound
Type: haxefmod.studio.Types.FmodPortType

## FMOD_REVERB_MAXINSTANCES
verdict: bound
Type: haxefmod.studio.Types.FmodLimits

## FMOD_REVERB_PRESETS
verdict: bound
Type: haxefmod.core.Reverb.ReverbPresets

## FMOD_REVERB_PROPERTIES
verdict: bound
Type: haxefmod.core.Reverb.ReverbProperties

## FMOD_SYSTEM_CALLBACK
verdict: bound
Type: haxefmod.studio.SystemCallbacks.SystemCallback

## FMOD_SYSTEM_CALLBACK_TYPE
verdict: bound
Type: haxefmod.studio.Types.FmodSystemCallbackType

## System::setDSPBufferSize
verdict: bound
```haxe
import haxefmod.core.CoreSystem;

var mixer = CoreSystem.getDSPBufferSize();
var blocksize = mixer.bufferLength;
var numblocks = mixer.numBuffers;
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
