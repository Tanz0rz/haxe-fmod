# platforms-win

## ASIO and C#
verdict: bound
```haxe
import haxefmod.studio.Types;

FmodManager.Initialize({output: FmodOutputType.ASIO, numChannels: 32});
```

## Background Music
verdict: bound
```haxe
import haxefmod.core.ChannelGroup;
import haxefmod.core.CoreSystem;
import haxefmod.core.Sound;
import haxefmod.studio.Types;

var music = ChannelGroup.create("music");
CoreSystem.attachChannelGroupToPort(FmodPortType.MUSIC, FmodPortIndex.NONE, music);
var bgm = Sound.create("assets/music/theme.ogg");
var channel = bgm.play(false, music);
```

## Pass Through
verdict: bound
```haxe
import haxefmod.core.ChannelGroup;
import haxefmod.core.CoreSystem;
import haxefmod.core.Sound;
import haxefmod.studio.Types;

var raw = ChannelGroup.create("passthrough");
CoreSystem.attachChannelGroupToPort(FmodPortType.PASSTHROUGH, FmodPortIndex.NONE, raw);
var voice = Sound.create("assets/voice/line.wav");
var channel = voice.play(false, raw);
```

