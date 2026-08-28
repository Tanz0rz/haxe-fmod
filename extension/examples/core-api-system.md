# core-api-system

## 0
<!-- FMOD_3D_ROLLOFF_CALLBACK -->
Rolloff callbacks cannot run on FMOD's threads from Haxe, so they are not exposed. A curve of FmodVector points does the same job without a callback through set3DCustomRolloff on the sound, channel, or group, native only (unsupported in HTML5), where the call returns FMOD_ERR_UNSUPPORTED. The built-in rolloff modes work on every target through the mode flags.
```haxe
import haxefmod.studio.CoreSound;
import haxefmod.core.ChannelMode;

var sound = CoreSound.create("assets/sfx/engine.wav");
sound.setMode(ChannelMode.MODE_3D);
sound.set3DCustomRolloff([{x: 1, y: 1, z: 0}, {x: 10, y: 0.5, z: 0}, {x: 50, y: 0, z: 0}]);
var channel = sound.play();
```

## 1
<!-- FMOD_ADVANCEDSETTINGS -->
Advanced settings are not exposed. The engine settings a game changes live in FmodSettings, passed once at initialization.
```haxe
FmodManager.Initialize({numChannels: 256, sampleRate: 48000, logLevel: 2});
```

## 2
<!-- FMOD_ASYNCREADINFO -->
Custom file systems are not exposed, since user IO callbacks run on FMOD's threads. Load banks with StudioSystem.loadBankFile or loadBankMemory, and core sounds with CoreSound.create or CoreSound.fromPcm.

## 3
<!-- FMOD_CREATESOUNDEXINFO -->
There is no extended-info struct. The file path form takes an optional loop flag, and raw PCM goes through fromPcm with the format described by its arguments.
```haxe
import haxefmod.studio.CoreSound;
var looped = CoreSound.create("assets/music/loop.ogg", true);

var pcm = haxe.io.Bytes.alloc(48000 * 2 * 2);
var sample = CoreSound.fromPcm(pcm, 48000, 2);
if (sample.isNull()) {
    trace('create failed: ${StudioSystem.lastResult()}');
}
```

## 4
<!-- FMOD_DRIVER_STATE -->
Driver state flags are not exposed. The driver list is reachable by index and name, and the current driver by getDriver.
```haxe
import haxefmod.core.CoreSystem;

for (i in 0...CoreSystem.getDriverCount()) {
    var marker = i == CoreSystem.getDriver() ? " (current)" : "";
    trace(CoreSystem.getDriverName(i) + marker);
}
```

## 5
<!-- FMOD_DSP_RESAMPLER -->
The resampler method is an advanced setting and is not exposed. FMOD's default interpolation applies.

## 6
<!-- FMOD_ERRORCALLBACK_INFO -->
System error callbacks are not exposed since Haxe code cannot run on FMOD's threads. Setters return an FmodResult and StudioSystem.lastResult() holds the last getter or factory error.
```haxe
import haxefmod.studio.CoreSound;
var result = StudioSystem.getBus("bus:/SFX").setVolume(0.5);
if (!result.isOk()) {
    trace('setVolume failed: $result');
}
var sound = CoreSound.create("assets/sfx/missing.wav");
if (sound.isNull()) {
    trace('create failed: ${StudioSystem.lastResult()}');
}
```

## 7
<!-- FMOD_ERRORCALLBACK_INSTANCETYPE -->
System error callbacks are not exposed, so there is no instance type to inspect. Check the FmodResult each call returns instead.

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
Init flags are chosen by the library. The settings a game controls at initialization are the fields of FmodSettings.
```haxe
FmodManager.Initialize({liveUpdate: true, numChannels: 256, autoUpdate: true});
```

## 16
<!-- FMOD_OUTPUTTYPE -->
The output type is chosen by FMOD for each platform, and CoreSystem.getOutput reports it as the FMOD_OUTPUTTYPE value. Output device selection within that type goes through the driver calls.
```haxe
import haxefmod.core.CoreSystem;

if (CoreSystem.getDriverCount() > 1) {
    CoreSystem.setDriver(1);
}
```

## 17
<!-- FMOD_PLUGINLIST -->
Plugin authoring stays in C because Haxe code cannot run on FMOD's mixer thread. A prebuilt plugin binary loads with StudioSystem.loadPlugin, native only (unsupported in HTML5), and StudioSystem.getPluginCount, getPluginHandle, and getPluginInfo enumerate what is loaded by FmodPluginType.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.ChannelGroup;

StudioSystem.setPluginPath("plugins");
var plugin = StudioSystem.loadPlugin("fmod_gain.dll");
if (plugin != 0) {
    var gain = Dsp.createByPlugin(plugin);
    ChannelGroup.master().addDsp(ChannelGroup.DSP_HEAD, gain);
}
```

## 18
<!-- FMOD_PLUGINTYPE -->
Plugin authoring stays in C because Haxe code cannot run on FMOD's mixer thread. A prebuilt plugin binary loads with StudioSystem.loadPlugin, native only (unsupported in HTML5), and StudioSystem.getPluginCount, getPluginHandle, and getPluginInfo enumerate what is loaded by FmodPluginType.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.ChannelGroup;

StudioSystem.setPluginPath("plugins");
var plugin = StudioSystem.loadPlugin("fmod_gain.dll");
if (plugin != 0) {
    var gain = Dsp.createByPlugin(plugin);
    ChannelGroup.master().addDsp(ChannelGroup.DSP_HEAD, gain);
}
```

## 19
<!-- FMOD_PORT_INDEX -->
Console port routing is not exposed. Desktop and web targets have no ports.

## 20
<!-- FMOD_PORT_TYPE -->
Console port routing is not exposed. Desktop and web targets have no ports.

## 21
<!-- FMOD_REVERB_MAXINSTANCES -->
The four global reverb instances are addressed by index 0 to 3 on Reverb.
```haxe
import haxefmod.core.Reverb;

Reverb.set(0, Reverb.PRESET_ROOM);
Reverb.set(1, Reverb.PRESET_CAVE);
Reverb.off(1);
```

## 22
<!-- FMOD_REVERB_PRESETS -->
Every preset is a static on Reverb with the same name.
```haxe
import haxefmod.core.Reverb;

Reverb.set(0, Reverb.PRESET_CONCERTHALL);
// later
Reverb.set(0, Reverb.PRESET_OFF);
```

## 23
<!-- FMOD_REVERB_PROPERTIES -->
ReverbProperties in haxefmod.core.Reverb has the same twelve fields in camel case.
```haxe
import haxefmod.core.Reverb;

var custom:ReverbProperties = {
    decayTime: 1500, earlyDelay: 7, lateDelay: 11, hfReference: 5000,
    hfDecayRatio: 50, diffusion: 100, density: 100, lowShelfFrequency: 250,
    lowShelfGain: 0, highCut: 20000, earlyLateMix: 50, wetLevel: -6
};
Reverb.set(0, custom);
```

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
StudioSystem.setSystemCallback takes one handler and delivers the device list changed and device lost events from FmodManager.Update() on the game thread, next to the Studio system events. Engine errors are not among them, set FmodSettings.logLevel to see those in the log.
```haxe
StudioSystem.setSystemCallback(event -> switch (event) {
    case DeviceListChanged: trace("devices changed");
    default:
});
```

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
