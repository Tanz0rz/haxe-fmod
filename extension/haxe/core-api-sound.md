# core-api-sound

## FMOD_OPENSTATE
verdict: bound
Type: haxefmod.studio.Types.FmodOpenState

## FMOD_SOUND_FORMAT
verdict: bound
Type: haxefmod.studio.Types.FmodSoundFormat

## Sound::getTag
verdict: bound
Native only (unsupported in HTML5).
A null name with index -1 walks the tags updated since the last pass, and a FLOAT payload is read from floatValue.
```haxe
import haxefmod.core.Sound;
import haxefmod.studio.Types;

var sound = Sound.create("assets/music/track.mp3");
var channel = sound.play();
var tag = sound.getTag(null, -1);
while (tag != null) {
    if (tag.type == FmodTagType.FMOD) {
        /* When a song changes, the sample rate may also change, so compensate here. */
        if (tag.name == "Sample Rate Change" && !channel.isNull()) {
            var frequency = tag.floatValue;

            var result = channel.setFrequency(frequency);
            if (!result.isOk()) {
                trace('setFrequency failed: $result');
            }
        }
    }
    tag = sound.getTag(null, -1);
}
```

## Sound::getTag#2
verdict: bound
Native only (unsupported in HTML5).
A null name with index -1 walks the tags updated since the last pass, and a FLOAT payload is read from floatValue.
```haxe
import haxefmod.core.Sound;
import haxefmod.studio.Types;

var sound = Sound.create("assets/music/track.mp3");
var channel = sound.play();
var tag = sound.getTag(null, -1);
while (tag != null) {
    if (tag.type == FmodTagType.FMOD) {
        /* When a song changes, the sample rate may also change, so compensate here. */
        if (tag.name == "Sample Rate Change" && !channel.isNull()) {
            var frequency = tag.floatValue;

            var result = channel.setFrequency(frequency);
            if (!result.isOk()) {
                trace('setFrequency failed: $result');
            }
        }
    }
    tag = sound.getTag(null, -1);
}
```

## FMOD_SOUND_NONBLOCK_CALLBACK
verdict: cannot It runs on FMOD's file thread, where no Haxe code can run. Sound.create with ChannelMode.NONBLOCKING starts the load and Sound.getOpenState reports READY or ERROR when it finishes.

## FMOD_SOUND_PCMREAD_CALLBACK
verdict: bound
Type: haxefmod.core.PcmStream.PcmReadCallback

## FMOD_SOUND_PCMSETPOS_CALLBACK
verdict: cannot It runs on FMOD's mixer thread, where no Haxe code can run. A PcmStream has no seekable position, so a game that needs to jump changes what it writes into the ring.

## Sound::set3DCustomRolloff
verdict: bound
```haxe
import haxefmod.studio.Types.FmodVector;

// Defining a custom array of points
var curve:Array<FmodVector> = [
    {x: 0.0, y: 1.0, z: 0.0},
    {x: 2.0, y: 0.2, z: 0.0},
    {x: 20.0, y: 0.0, z: 0.0}
];
```

## Sound::setDefaults
verdict: bound
getDefaults returns both values in one struct, null on failure.
```haxe
import haxefmod.core.Sound;

var sound = Sound.create("assets/sfx/hit.wav");
var defaults = sound.getDefaults();
if (defaults != null) {
    var priority = defaults.priority;
    sound.setDefaults(48000, priority);
}
```

## Sound::setDefaults#2
verdict: bound
getDefaults returns both values in one struct, null on failure.
```haxe
import haxefmod.core.Sound;

var sound = Sound.create("assets/sfx/hit.wav");
var defaults = sound.getDefaults();
if (defaults != null) {
    var priority = defaults.priority;
    sound.setDefaults(48000, priority);
}
```

## Sound::setDefaults#3
verdict: bound
getDefaults returns both values in one struct, null on failure.
```haxe
import haxefmod.core.Sound;

var sound = Sound.create("assets/sfx/hit.wav");
var defaults = sound.getDefaults();
if (defaults != null) {
    var priority = defaults.priority;
    sound.setDefaults(48000, priority);
}
```

## Sound::setDefaults#4
verdict: bound
getDefaults returns both values in one struct, null on failure.
```haxe
import haxefmod.core.Sound;

var sound = Sound.create("assets/sfx/hit.wav");
var defaults = sound.getDefaults();
if (defaults != null) {
    var priority = defaults.priority;
    sound.setDefaults(48000, priority);
}
```

## FMOD_SOUND_TYPE
verdict: bound
Type: haxefmod.studio.Types.FmodSoundType

## FMOD_TAG
verdict: bound
Type: haxefmod.studio.Types.FmodTag

## FMOD_TAGDATATYPE
verdict: bound
Type: haxefmod.studio.Types.FmodTagDataType

## FMOD_TAGTYPE
verdict: bound
Type: haxefmod.studio.Types.FmodTagType
