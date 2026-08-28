# glossary

## 22.33 Reading Sound Data
verdict: bound
Sound.readData reads decoded PCM out of a sound opened with the openOnly flag of Sound.create, and seekData moves the read cursor. Sound.getLength reports milliseconds rather than a byte count, so the buffer is read in fixed chunks until readData returns 0. Both are native only (unsupported in HTML5), where the call returns FMOD_ERR_UNSUPPORTED, so a web build keeps its own copy of the PCM it feeds through Sound.fromPcm or PcmStream.
```haxe
import haxefmod.core.Sound;

var sound = Sound.create("assets/sfx/engine.wav", false, true);
var lengthMs = sound.getLength(); // milliseconds, the PCM byte count is not reported
var buffer = haxe.io.Bytes.alloc(4096);
var read = sound.readData(buffer);
while (read > 0) {
    // the first read bytes of buffer hold decoded PCM
    read = sound.readData(buffer);
}
sound.release();
```

## 22.49 User Data
verdict: bound
Every handle has setUserData and getUserData. The value is any Haxe value, it lives on the Haxe side keyed by the handle, and the entry is dropped when the handle is released.
```haxe
import haxefmod.core.Sound;

var sound = Sound.create("drumloop.wav");
sound.setUserData("Hello User Data!");

trace(sound.getUserData());
```
