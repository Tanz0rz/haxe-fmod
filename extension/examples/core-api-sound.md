# core-api-sound

## 0
<!-- FMOD_OPENSTATE -->
getOpenState returns the FMOD_OPENSTATE value as an int, 0 once the sound is ready.
```haxe
import haxefmod.studio.CoreSound;
var sound = CoreSound.create("assets/music/intro.ogg");
if (sound.getOpenState() == 0) {
    var channel = sound.play();
}
```

## 3
<!-- FMOD_SOUND_FORMAT -->
Sounds built from raw data are always 16-bit signed PCM. getFormat reports the channel count and bit depth of any loaded sound.
```haxe
import haxefmod.studio.CoreSound;
var sound = CoreSound.create("assets/sfx/hit.wav");
var format = sound.getFormat();
if (format != null) {
    trace('${format.channels} channels, ${format.bits} bits');
}
```

## 28
<!-- Sound::getTag -->
Tag access is not exposed, and netstreams are not part of the supported sound sources. Set the playback rate directly with setFrequency when your game knows it.
```haxe
import haxefmod.studio.CoreSound;
var sound = CoreSound.create("assets/music/track.ogg");
var channel = sound.play();
channel.setFrequency(44100);
```

## 29
<!-- Sound::getTag -->
Tag access is not exposed, and netstreams are not part of the supported sound sources. Set the playback rate directly with setFrequency when your game knows it.
```haxe
import haxefmod.studio.CoreSound;
var sound = CoreSound.create("assets/music/track.ogg");
var channel = sound.play();
channel.setFrequency(44100);
```

## 32
<!-- FMOD_SOUND_NONBLOCK_CALLBACK -->
Sound callbacks are not exposed since Haxe code cannot run on FMOD's threads. Poll getOpenState until it reports 0.

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
import haxefmod.studio.CoreSound;
import haxefmod.core.ChannelMode;

var sound = CoreSound.create("assets/sfx/engine.wav");
sound.setMode(ChannelMode.MODE_3D);
sound.set3DCustomRolloff([{x: 1, y: 1, z: 0}, {x: 10, y: 0.5, z: 0}, {x: 50, y: 0, z: 0}]);
```

## 43
<!-- Sound::setDefaults -->
getDefaults returns both values in one struct.
```haxe
import haxefmod.studio.CoreSound;
var sound = CoreSound.create("assets/sfx/hit.wav");
var defaults = sound.getDefaults();
if (defaults != null) {
    sound.setDefaults(48000, defaults.priority);
}
```

## 44
<!-- Sound::setDefaults -->
getDefaults returns both values in one struct.
```haxe
import haxefmod.studio.CoreSound;
var sound = CoreSound.create("assets/sfx/hit.wav");
var defaults = sound.getDefaults();
if (defaults != null) {
    sound.setDefaults(48000, defaults.priority);
}
```

## 45
<!-- Sound::setDefaults -->
getDefaults returns both values in one struct.
```haxe
import haxefmod.studio.CoreSound;
var sound = CoreSound.create("assets/sfx/hit.wav");
var defaults = sound.getDefaults();
if (defaults != null) {
    sound.setDefaults(48000, defaults.priority);
}
```

## 46
<!-- Sound::setDefaults -->
getDefaults returns both values in one struct.
```haxe
import haxefmod.studio.CoreSound;
var sound = CoreSound.create("assets/sfx/hit.wav");
var defaults = sound.getDefaults();
if (defaults != null) {
    sound.setDefaults(48000, defaults.priority);
}
```

## 54
<!-- FMOD_SOUND_TYPE -->
The sound type is not queryable. CoreSound.create accepts any format FMOD decodes on the target, and on HTML5 only FSB and raw PCM decode, so a loose .wav or .ogg path leaves FMOD_ERR_FORMAT in lastResult.
```haxe
import haxefmod.studio.CoreSound;
var sound = CoreSound.create("assets/sfx/hit.ogg");
if (sound.isNull() && StudioSystem.lastResult() == FMOD_ERR_FORMAT) {
    trace("this target cannot decode loose files");
}
```

## 56
<!-- FMOD_TAG -->
Tag and metadata access is not exposed. Keep track metadata in your game's own data files.

## 57
<!-- FMOD_TAGDATATYPE -->
Tag and metadata access is not exposed. Keep track metadata in your game's own data files.

## 58
<!-- FMOD_TAGTYPE -->
Tag and metadata access is not exposed. Keep track metadata in your game's own data files.
