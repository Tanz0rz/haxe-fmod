# core-api-sound

## FMOD_OPENSTATE
verdict: bound
Type: haxefmod.studio.Types.FmodOpenState
Returned by Sound.getOpenState, READY once the sound can play.

## FMOD_SOUND_FORMAT
verdict: bound
Type: haxefmod.studio.Types.FmodSoundFormat
Sound.fromPcm always builds PCM16, and Sound.getFormat reports the channel count and bit depth.

## Sound::getTag
verdict: bound
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

## Sound::getTag#2
verdict: bound
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

## FMOD_SOUND_NONBLOCK_CALLBACK
verdict: review note only, decide bound or a category
Sound callbacks are not exposed since Haxe code cannot run on FMOD's threads. Poll getOpenState until it reports FmodOpenState.READY.

## FMOD_SOUND_PCMREAD_CALLBACK
verdict: bound
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

## FMOD_SOUND_PCMSETPOS_CALLBACK
verdict: review note only, decide bound or a category
PCM position callbacks are not exposed since Haxe code cannot run on FMOD's threads. A PcmStream has no seekable position, so a game that needs to jump restarts what it writes into the ring.

## Sound::set3DCustomRolloff
verdict: bound
Custom rolloff curves are native only (unsupported in HTML5), where the call returns FMOD_ERR_UNSUPPORTED. Each point is an FmodVector with x as the distance and y as the volume, and the copy FMOD needs lives with the sound until it is released.
```haxe
import haxefmod.core.Sound;
import haxefmod.core.ChannelMode;

var sound = Sound.create("assets/sfx/engine.wav");
sound.setMode(ChannelMode.MODE_3D);
sound.set3DCustomRolloff([{x: 1, y: 1, z: 0}, {x: 10, y: 0.5, z: 0}, {x: 50, y: 0, z: 0}]);
```

## Sound::setDefaults
verdict: bound
getDefaults returns both values in one struct.
```haxe
import haxefmod.core.Sound;
var sound = Sound.create("assets/sfx/hit.wav");
var defaults = sound.getDefaults();
if (defaults != null) {
    sound.setDefaults(48000, defaults.priority);
}
```

## Sound::setDefaults#2
verdict: bound
getDefaults returns both values in one struct.
```haxe
import haxefmod.core.Sound;
var sound = Sound.create("assets/sfx/hit.wav");
var defaults = sound.getDefaults();
if (defaults != null) {
    sound.setDefaults(48000, defaults.priority);
}
```

## Sound::setDefaults#3
verdict: bound
getDefaults returns both values in one struct.
```haxe
import haxefmod.core.Sound;
var sound = Sound.create("assets/sfx/hit.wav");
var defaults = sound.getDefaults();
if (defaults != null) {
    sound.setDefaults(48000, defaults.priority);
}
```

## Sound::setDefaults#4
verdict: bound
getDefaults returns both values in one struct.
```haxe
import haxefmod.core.Sound;
var sound = Sound.create("assets/sfx/hit.wav");
var defaults = sound.getDefaults();
if (defaults != null) {
    sound.setDefaults(48000, defaults.priority);
}
```

## FMOD_SOUND_TYPE
verdict: bound
Type: haxefmod.studio.Types.FmodSoundType
Sound.create accepts any format FMOD decodes on the target, the type of a loaded sound is not queried.

## FMOD_TAG
verdict: bound
Type: haxefmod.studio.Types.FmodTag
Returned by Sound.getTag (unsupported in HTML5, null there). The data pointer and datalen are folded into intValue, floatValue, stringValue, and length, and updated is true until the tag has been read once.

## FMOD_TAGDATATYPE
verdict: bound
Type: haxefmod.studio.Types.FmodTagDataType

## FMOD_TAGTYPE
verdict: bound
Type: haxefmod.studio.Types.FmodTagType
