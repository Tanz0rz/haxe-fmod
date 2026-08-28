# glossary

## 0
<!-- 22.33 Reading Sound Data -->
CoreSound.readData reads decoded PCM out of a sound opened with the openOnly flag of CoreSound.create, and seekData moves the read cursor. Both are native only (unsupported in HTML5), where the call returns FMOD_ERR_UNSUPPORTED, so a web build keeps its own copy of the PCM it feeds through CoreSound.fromPcm or PcmStream.
```haxe
import haxefmod.studio.CoreSound;

var sound = CoreSound.create("assets/sfx/engine.wav", false, true);
var buffer = haxe.io.Bytes.alloc(4096);
var read = sound.readData(buffer);
while (read > 0) {
    // the first read bytes of buffer hold decoded PCM
    read = sound.readData(buffer);
}
sound.release();
```

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
