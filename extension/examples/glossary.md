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
Every handle has setUserData and getUserData. The value is any Haxe value, it lives on the Haxe side keyed by the handle, and the entry is dropped when the handle is released.
```haxe
import haxefmod.studio.CoreSound;

var sound = CoreSound.create("drumloop.wav");
sound.setUserData("Hello User Data!");

trace(sound.getUserData());
```
