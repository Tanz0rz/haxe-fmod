# core-api-sound

## 0
<!-- FMOD_OPENSTATE -->
Returned by Sound.getOpenState, READY once the sound can play.

## 3
<!-- FMOD_SOUND_FORMAT -->
Sound.fromPcm always builds PCM16, and Sound.getFormat reports the channel count and bit depth.

## 28
<!-- Sound::getTag -->
Sound.getTag reads one tag by name as an FmodTag, with a FLOAT payload in floatValue (unsupported in HTML5, returns null there). Netstreams are not part of the supported sound sources, so the tag is read once after the sound opens.
```haxe
import haxefmod.core.Sound;
import haxefmod.studio.Types;

var sound = Sound.create("assets/music/track.ogg");
var channel = sound.play();
var tag = sound.getTag("Sample Rate Change");
if (tag != null && tag.type == FmodTagType.FMOD) {
    var result = channel.setFrequency(tag.floatValue);
    if (!result.isOk()) {
        trace('setFrequency failed: $result');
    }
}
```

## 29
<!-- Sound::getTag -->
Sound.getTag reads one tag by name as an FmodTag, with a FLOAT payload in floatValue (unsupported in HTML5, returns null there). Netstreams are not part of the supported sound sources, so the tag is read once after the sound opens.
```haxe
import haxefmod.core.Sound;
import haxefmod.studio.Types;

var sound = Sound.create("assets/music/track.ogg");
var channel = sound.play();
var tag = sound.getTag("Sample Rate Change");
if (tag != null && tag.type == FmodTagType.FMOD) {
    var result = channel.setFrequency(tag.floatValue);
    if (!result.isOk()) {
        trace('setFrequency failed: $result');
    }
}
```

## 32
<!-- FMOD_SOUND_NONBLOCK_CALLBACK -->
Sound callbacks are not exposed since Haxe code cannot run on FMOD's threads. Poll getOpenState until it reports FmodOpenState.READY.

## 33
<!-- FMOD_SOUND_PCMREAD_CALLBACK -->
PCM read callbacks are not exposed since Haxe code cannot run on FMOD's threads. PcmStream fills the same role from the game thread, the game writes PCM into a ring buffer and the mixer drains it.
```haxe
import haxefmod.core.PcmStream;

var stream = PcmStream.create(48000, 1);
var channel = stream.play();
// each frame
var buffer = haxe.io.Bytes.alloc(stream.space());
for (i in 0...Std.int(buffer.length / 2)) {
    buffer.setUInt16(i * 2, nextSample() & 0xFFFF);
}
stream.write(buffer);
```

## 34
<!-- FMOD_SOUND_PCMSETPOS_CALLBACK -->
PCM position callbacks are not exposed since Haxe code cannot run on FMOD's threads. A PcmStream has no seekable position, so a game that needs to jump restarts what it writes into the ring.

## 40
<!-- Sound::set3DCustomRolloff -->
Custom rolloff curves are native only (unsupported in HTML5), where the call returns FMOD_ERR_UNSUPPORTED. Each point is an FmodVector with x as the distance and y as the volume, and the copy FMOD needs lives with the sound until it is released.
```haxe
import haxefmod.core.Sound;
import haxefmod.core.ChannelMode;

var sound = Sound.create("assets/sfx/engine.wav");
sound.setMode(ChannelMode.MODE_3D);
sound.set3DCustomRolloff([{x: 1, y: 1, z: 0}, {x: 10, y: 0.5, z: 0}, {x: 50, y: 0, z: 0}]);
```

## 43
<!-- Sound::setDefaults -->
getDefaults returns both values in one struct.
```haxe
import haxefmod.core.Sound;
var sound = Sound.create("assets/sfx/hit.wav");
var defaults = sound.getDefaults();
if (defaults != null) {
    sound.setDefaults(48000, defaults.priority);
}
```

## 44
<!-- Sound::setDefaults -->
getDefaults returns both values in one struct.
```haxe
import haxefmod.core.Sound;
var sound = Sound.create("assets/sfx/hit.wav");
var defaults = sound.getDefaults();
if (defaults != null) {
    sound.setDefaults(48000, defaults.priority);
}
```

## 45
<!-- Sound::setDefaults -->
getDefaults returns both values in one struct.
```haxe
import haxefmod.core.Sound;
var sound = Sound.create("assets/sfx/hit.wav");
var defaults = sound.getDefaults();
if (defaults != null) {
    sound.setDefaults(48000, defaults.priority);
}
```

## 46
<!-- Sound::setDefaults -->
getDefaults returns both values in one struct.
```haxe
import haxefmod.core.Sound;
var sound = Sound.create("assets/sfx/hit.wav");
var defaults = sound.getDefaults();
if (defaults != null) {
    sound.setDefaults(48000, defaults.priority);
}
```

## 54
<!-- FMOD_SOUND_TYPE -->
Sound.create accepts any format FMOD decodes on the target, the type of a loaded sound is not queried.

## 56
<!-- FMOD_TAG -->
Returned by Sound.getTag (unsupported in HTML5, null there). The data pointer and datalen are folded into intValue, floatValue, stringValue, and length, and updated is true until the tag has been read once.
