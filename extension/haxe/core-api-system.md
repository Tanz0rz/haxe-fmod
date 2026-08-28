# core-api-system

## FMOD_3D_ROLLOFF_CALLBACK
verdict: bound
Rolloff callbacks cannot run on FMOD's threads from Haxe, so they are not exposed. A curve of FmodVector points does the same job without a callback through set3DCustomRolloff on the sound, channel, or group, native only (unsupported in HTML5), where the call returns FMOD_ERR_UNSUPPORTED. The built-in rolloff modes work on every target through the mode flags.
```haxe
import haxefmod.core.Sound;
import haxefmod.core.ChannelMode;

var sound = Sound.create("assets/sfx/engine.wav");
sound.setMode(ChannelMode.MODE_3D);
sound.set3DCustomRolloff([{x: 1, y: 1, z: 0}, {x: 10, y: 0.5, z: 0}, {x: 50, y: 0, z: 0}]);
var channel = sound.play();
```

## FMOD_ADVANCEDSETTINGS
verdict: bound
Type: haxefmod.studio.Types.FmodAdvancedSettings
Set through the FmodSettings fields of the same names at init, read back with StudioSystem.getAdvancedSettings. The fields that stay at FMOD's defaults are not carried.

## FMOD_ASYNCREADINFO
verdict: review note only, decide bound or a category
No Haxe equivalent. Custom file systems are not exposed, since user IO callbacks run on FMOD's threads.

## FMOD_CREATESOUNDEXINFO
verdict: library Sound.create and Sound.fromPcm take its fields as arguments

## FMOD_DRIVER_STATE
verdict: bound
Type: haxefmod.studio.Types.FmodDriverState
Returned in the state field of StudioSystem.getRecordDriverInfo. Output drivers are listed through CoreSystem.getDriverCount, getDriverName, and getDriver without a state.

## FMOD_DSP_RESAMPLER
verdict: bound
Type: haxefmod.studio.Types.FmodDspResampler
The resampler method is not exposed, DEFAULT applies.

## FMOD_ERRORCALLBACK_INFO
verdict: library error callbacks are not exposed, every call returns its FmodResult and StudioSystem.lastResult() keeps the last getter error

## FMOD_ERRORCALLBACK_INSTANCETYPE
verdict: bound
Type: haxefmod.studio.Types.FmodErrorCallbackInstanceType
Error callbacks are not exposed, check the FmodResult each call returns instead.

## FMOD_FILE_ASYNCCANCEL_CALLBACK
verdict: review note only, decide bound or a category
File callbacks are not exposed since Haxe code cannot run on FMOD's threads. Load banks with StudioSystem.loadBankFile or loadBankMemory.

## FMOD_FILE_ASYNCDONE_FUNC
verdict: review note only, decide bound or a category
File callbacks are not exposed since Haxe code cannot run on FMOD's threads. Load banks with StudioSystem.loadBankFile or loadBankMemory.

## FMOD_FILE_ASYNCREAD_CALLBACK
verdict: review note only, decide bound or a category
File callbacks are not exposed since Haxe code cannot run on FMOD's threads. Load banks with StudioSystem.loadBankFile or loadBankMemory.

## FMOD_FILE_CLOSE_CALLBACK
verdict: review note only, decide bound or a category
File callbacks are not exposed since Haxe code cannot run on FMOD's threads. Load banks with StudioSystem.loadBankFile or loadBankMemory.

## FMOD_FILE_OPEN_CALLBACK
verdict: review note only, decide bound or a category
File callbacks are not exposed since Haxe code cannot run on FMOD's threads. Load banks with StudioSystem.loadBankFile or loadBankMemory.

## FMOD_FILE_READ_CALLBACK
verdict: review note only, decide bound or a category
File callbacks are not exposed since Haxe code cannot run on FMOD's threads. Load banks with StudioSystem.loadBankFile or loadBankMemory.

## FMOD_FILE_SEEK_CALLBACK
verdict: review note only, decide bound or a category
File callbacks are not exposed since Haxe code cannot run on FMOD's threads. Load banks with StudioSystem.loadBankFile or loadBankMemory.

## FMOD_INITFLAGS
verdict: bound
Type: haxefmod.studio.Types.FmodInitFlags
The library composes the flags from FmodSettings at init. The liveUpdate, profiling, and distanceFilter fields control the ones a game can change.

## FMOD_OUTPUTTYPE
verdict: bound
Type: haxefmod.studio.Types.FmodOutputType
Returned by CoreSystem.getOutput.

## FMOD_PLUGINLIST
verdict: library static plugin lists are C, a compiled plugin loads with StudioSystem.loadPlugin

## FMOD_PLUGINTYPE
verdict: bound
Type: haxefmod.studio.Types.FmodPluginType

## FMOD_PORT_INDEX
verdict: review note only, decide bound or a category
No Haxe equivalent. Console port routing is not exposed, desktop and web targets have no ports.

## FMOD_PORT_TYPE
verdict: bound
Type: haxefmod.studio.Types.FmodPortType
Console port routing is not exposed, desktop and web targets have no ports.

## FMOD_REVERB_MAXINSTANCES
verdict: review note only, decide bound or a category
No Haxe equivalent. The four global reverb instances are addressed by index 0 to 3 on Reverb.set and Reverb.off.

## FMOD_REVERB_PRESETS
verdict: review note only, decide bound or a category
No Haxe equivalent. Every preset is a ReverbProperties static on Reverb with the same name, for example Reverb.PRESET_CAVE.

## FMOD_REVERB_PROPERTIES
verdict: bound
Type: haxefmod.core.Reverb.ReverbProperties

## FMOD_SYSTEM_CALLBACK
verdict: bound
StudioSystem.setSystemCallback takes one handler and delivers the device list changed and device lost events from FmodManager.Update() on the game thread, next to the Studio system events. Engine errors are not among them, set FmodSettings.logLevel to see those in the log.
```haxe
StudioSystem.setSystemCallback(event -> switch (event) {
    case DeviceListChanged: trace("devices changed");
    default:
});
```

## FMOD_SYSTEM_CALLBACK_TYPE
verdict: bound
Type: haxefmod.studio.Types.FmodSystemCallbackType
The mask bits are also the CORE_* Int constants on SystemCallbacks. StudioSystem.setSystemCallback delivers DEVICELISTCHANGED and DEVICELOST as SystemEvent.

## System::setDSPBufferSize
verdict: bound
FMOD only accepts the mixer buffer before init, so it is set through the dspBufferSize and dspNumBuffers fields of FmodSettings, native only (unsupported in HTML5). The mixer sample rate is readable from getSoftwareFormat.
```haxe
import haxefmod.core.CoreSystem;

var format = CoreSystem.getSoftwareFormat();
if (format != null) {
    trace('Mixer sample rate = ${format.sampleRate} Hz');
}
```

## System::setSpeakerPosition
verdict: bound
CoreSystem.setSpeakerPosition places one speaker of the mode chosen at initialization, and getSpeakerPosition reads it back.
```haxe
import haxefmod.core.CoreSystem;

FmodManager.Initialize({speakerMode: 2}); // FMOD_SPEAKERMODE_STEREO
CoreSystem.setSpeakerPosition(0, -1, 0, true); // FMOD_SPEAKER_FRONT_LEFT
CoreSystem.setSpeakerPosition(1, 1, 0, true); // FMOD_SPEAKER_FRONT_RIGHT
```

## System::setSpeakerPosition#2
verdict: bound
CoreSystem.setSpeakerPosition places one speaker of the mode chosen at initialization, and getSpeakerPosition reads it back.
```haxe
import haxefmod.core.CoreSystem;

FmodManager.Initialize({speakerMode: 2}); // FMOD_SPEAKERMODE_STEREO
CoreSystem.setSpeakerPosition(0, -1, 0, true); // FMOD_SPEAKER_FRONT_LEFT
CoreSystem.setSpeakerPosition(1, 1, 0, true); // FMOD_SPEAKER_FRONT_RIGHT
```

## System::setSpeakerPosition#3
verdict: bound
CoreSystem.setSpeakerPosition places one speaker of the mode chosen at initialization, and a speaker set inactive is left out of the mix.
```haxe
import haxefmod.core.CoreSystem;

FmodManager.Initialize({speakerMode: 6}); // FMOD_SPEAKERMODE_7POINT1
CoreSystem.setSpeakerPosition(2, 0, 0, false); // FMOD_SPEAKER_FRONT_CENTER off
```

## System::setSpeakerPosition#4
verdict: bound
CoreSystem.setSpeakerPosition places one speaker of the mode chosen at initialization, and a speaker set inactive is left out of the mix.
```haxe
import haxefmod.core.CoreSystem;

FmodManager.Initialize({speakerMode: 6}); // FMOD_SPEAKERMODE_7POINT1
CoreSystem.setSpeakerPosition(2, 0, 0, false); // FMOD_SPEAKER_FRONT_CENTER off
```
