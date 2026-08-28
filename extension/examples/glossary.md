# glossary

## 0
<!-- 22.33 Reading Sound Data -->
Sound sample readback (readData, lock) is not exposed, since FMOD's web build does not support it. Keep your own copy of the PCM you feed through PcmStream or CoreSound.fromPcm when the game needs waveform data.

## 1
<!-- 22.49 User Data -->
userdata is not exposed. Handles are plain integers, so keep a Map from the handle to your own data, or a field on the game object that owns the sound.
```haxe
import haxefmod.studio.CoreSound;

var sound = CoreSound.create("drumloop.wav");
var userData = new Map<CoreSound, String>();
userData.set(sound, "Hello User Data!");

trace(userData.get(sound));
```
