# core-api-system

## 0
<!-- FMOD_3D_ROLLOFF_CALLBACK -->
Rolloff callbacks cannot run on FMOD's threads from Haxe, so they are not exposed. A curve of FmodVector points does the same job without a callback through set3DCustomRolloff on the sound, channel, or group, native only (unsupported in HTML5), where the call returns FMOD_ERR_UNSUPPORTED. The built-in rolloff modes work on every target through the mode flags.
```haxe
import haxefmod.core.Sound;
import haxefmod.core.ChannelMode;

var sound = Sound.create("assets/sfx/engine.wav");
sound.setMode(ChannelMode.MODE_3D);
sound.set3DCustomRolloff([{x: 1, y: 1, z: 0}, {x: 10, y: 0.5, z: 0}, {x: 50, y: 0, z: 0}]);
var channel = sound.play();
```

## 1
<!-- FMOD_ADVANCEDSETTINGS -->
Set through the FmodSettings fields of the same names at init, read back with StudioSystem.getAdvancedSettings. The fields that stay at FMOD's defaults are not carried.

## 2
<!-- FMOD_ASYNCREADINFO -->
No Haxe equivalent. Custom file systems are not exposed, since user IO callbacks run on FMOD's threads.

## 4
<!-- FMOD_DRIVER_STATE -->
Returned in the state field of StudioSystem.getRecordDriverInfo. Output drivers are listed through CoreSystem.getDriverCount, getDriverName, and getDriver without a state.

## 5
<!-- FMOD_DSP_RESAMPLER -->
The resampler method is not exposed, DEFAULT applies.

## 7
<!-- FMOD_ERRORCALLBACK_INSTANCETYPE -->
Error callbacks are not exposed, check the FmodResult each call returns instead.

## 8
<!-- FMOD_FILE_ASYNCCANCEL_CALLBACK -->
File callbacks are not exposed since Haxe code cannot run on FMOD's threads. Load banks with StudioSystem.loadBankFile or loadBankMemory.

## 9
<!-- FMOD_FILE_ASYNCDONE_FUNC -->
File callbacks are not exposed since Haxe code cannot run on FMOD's threads. Load banks with StudioSystem.loadBankFile or loadBankMemory.

## 10
<!-- FMOD_FILE_ASYNCREAD_CALLBACK -->
File callbacks are not exposed since Haxe code cannot run on FMOD's threads. Load banks with StudioSystem.loadBankFile or loadBankMemory.

## 11
<!-- FMOD_FILE_CLOSE_CALLBACK -->
File callbacks are not exposed since Haxe code cannot run on FMOD's threads. Load banks with StudioSystem.loadBankFile or loadBankMemory.

## 12
<!-- FMOD_FILE_OPEN_CALLBACK -->
File callbacks are not exposed since Haxe code cannot run on FMOD's threads. Load banks with StudioSystem.loadBankFile or loadBankMemory.

## 13
<!-- FMOD_FILE_READ_CALLBACK -->
File callbacks are not exposed since Haxe code cannot run on FMOD's threads. Load banks with StudioSystem.loadBankFile or loadBankMemory.

## 14
<!-- FMOD_FILE_SEEK_CALLBACK -->
File callbacks are not exposed since Haxe code cannot run on FMOD's threads. Load banks with StudioSystem.loadBankFile or loadBankMemory.

## 15
<!-- FMOD_INITFLAGS -->
The library composes the flags from FmodSettings at init. The liveUpdate, profiling, and distanceFilter fields control the ones a game can change.

## 16
<!-- FMOD_OUTPUTTYPE -->
Returned by CoreSystem.getOutput.

## 19
<!-- FMOD_PORT_INDEX -->
No Haxe equivalent. Console port routing is not exposed, desktop and web targets have no ports.

## 20
<!-- FMOD_PORT_TYPE -->
Console port routing is not exposed, desktop and web targets have no ports.

## 21
<!-- FMOD_REVERB_MAXINSTANCES -->
No Haxe equivalent. The four global reverb instances are addressed by index 0 to 3 on Reverb.set and Reverb.off.

## 22
<!-- FMOD_REVERB_PRESETS -->
No Haxe equivalent. Every preset is a ReverbProperties static on Reverb with the same name, for example Reverb.PRESET_CAVE.

## 26
<!-- FMOD_SYSTEM_CALLBACK -->
StudioSystem.setSystemCallback takes one handler and delivers the device list changed and device lost events from FmodManager.Update() on the game thread, next to the Studio system events. Engine errors are not among them, set FmodSettings.logLevel to see those in the log.
```haxe
StudioSystem.setSystemCallback(event -> switch (event) {
    case DeviceListChanged: trace("devices changed");
    default:
});
```

## 27
<!-- FMOD_SYSTEM_CALLBACK_TYPE -->
The mask bits are also the CORE_* Int constants on SystemCallbacks. StudioSystem.setSystemCallback delivers DEVICELISTCHANGED and DEVICELOST as SystemEvent.

## 104
<!-- System::setDSPBufferSize -->
FMOD only accepts the mixer buffer before init, so it is set through the dspBufferSize and dspNumBuffers fields of FmodSettings, native only (unsupported in HTML5). The mixer sample rate is readable from getSoftwareFormat.
```haxe
import haxefmod.core.CoreSystem;

var format = CoreSystem.getSoftwareFormat();
if (format != null) {
    trace('Mixer sample rate = ${format.sampleRate} Hz');
}
```

## 116
<!-- System::setSpeakerPosition -->
CoreSystem.setSpeakerPosition places one speaker of the mode chosen at initialization, and getSpeakerPosition reads it back.
```haxe
import haxefmod.core.CoreSystem;

FmodManager.Initialize({speakerMode: 2}); // FMOD_SPEAKERMODE_STEREO
CoreSystem.setSpeakerPosition(0, -1, 0, true); // FMOD_SPEAKER_FRONT_LEFT
CoreSystem.setSpeakerPosition(1, 1, 0, true); // FMOD_SPEAKER_FRONT_RIGHT
```

## 117
<!-- System::setSpeakerPosition -->
CoreSystem.setSpeakerPosition places one speaker of the mode chosen at initialization, and getSpeakerPosition reads it back.
```haxe
import haxefmod.core.CoreSystem;

FmodManager.Initialize({speakerMode: 2}); // FMOD_SPEAKERMODE_STEREO
CoreSystem.setSpeakerPosition(0, -1, 0, true); // FMOD_SPEAKER_FRONT_LEFT
CoreSystem.setSpeakerPosition(1, 1, 0, true); // FMOD_SPEAKER_FRONT_RIGHT
```

## 118
<!-- System::setSpeakerPosition -->
CoreSystem.setSpeakerPosition places one speaker of the mode chosen at initialization, and a speaker set inactive is left out of the mix.
```haxe
import haxefmod.core.CoreSystem;

FmodManager.Initialize({speakerMode: 6}); // FMOD_SPEAKERMODE_7POINT1
CoreSystem.setSpeakerPosition(2, 0, 0, false); // FMOD_SPEAKER_FRONT_CENTER off
```

## 119
<!-- System::setSpeakerPosition -->
CoreSystem.setSpeakerPosition places one speaker of the mode chosen at initialization, and a speaker set inactive is left out of the mix.
```haxe
import haxefmod.core.CoreSystem;

FmodManager.Initialize({speakerMode: 6}); // FMOD_SPEAKERMODE_7POINT1
CoreSystem.setSpeakerPosition(2, 0, 0, false); // FMOD_SPEAKER_FRONT_CENTER off
```
