# glossary

## 22.33 Reading Sound Data
verdict: bound
```haxe
import haxefmod.core.Sound;
import haxefmod.studio.Types;

var sound = Sound.create("drumloop.wav", false, true); // openOnly, like FMOD_OPENONLY
var length = sound.getLength(FmodTimeUnit.RAWBYTES);

var buffer = haxe.io.Bytes.alloc(length);
var read = sound.readData(buffer);
```

## 22.49 User Data
verdict: bound
```haxe
import haxefmod.core.Sound;

{
    var userData = "Hello User Data!";
    sound.setUserData(userData);
}
{
    var userData:String = sound.getUserData();
}
```

