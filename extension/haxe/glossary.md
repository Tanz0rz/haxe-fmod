# glossary

## 22.33 Reading Sound Data
verdict: bound
```haxe
import haxefmod.core.Sound;
import haxefmod.studio.Types;

var sound:Sound;
var length:Int;
var buffer:haxe.io.Bytes;

sound = Sound.create("drumloop.wav", false, true); // openOnly is FMOD_OPENONLY
length = sound.getLength(FmodTimeUnit.RAWBYTES);

buffer = haxe.io.Bytes.alloc(length);
var read = sound.readData(buffer, length);

buffer = null;
```

## 22.49 User Data
verdict: bound
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

