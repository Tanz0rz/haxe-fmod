# glossary

## 22.33 Reading Sound Data
verdict: bound
Native only (unsupported in HTML5).
getLength takes the time unit as its parameter, PCMBYTES for the byte count the page reads.
```haxe
import haxefmod.core.Sound;
import haxefmod.studio.Types;

var sound:Sound;
var length:Int;
var buffer:haxe.io.Bytes;

sound = Sound.create("drumloop.wav", false, true); // openOnly is FMOD_OPENONLY
length = sound.getLength(FmodTimeUnit.PCMBYTES);

buffer = haxe.io.Bytes.alloc(4096);
var read = sound.readData(buffer, buffer.length);
while (read > 0) {
    read = sound.readData(buffer, buffer.length);
}

sound.release();
```

## 22.49 User Data
verdict: bound
The value is any Haxe value. It stays on the Haxe side keyed by the handle and is dropped when the handle is released.
```haxe
import haxefmod.core.Sound;

var sound = Sound.create("drumloop.wav");
{
    var userData = "Hello User Data!";
    sound.setUserData(userData);
}
{
    var userData:String = sound.getUserData();
}
```
