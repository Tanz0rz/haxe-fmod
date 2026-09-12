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
import haxefmod.studio.Types;

var bgm = ChannelGroup.create("BGM");
CoreSystem.attachChannelGroupToPort(FmodPortType.MUSIC, FmodPortIndex.NONE, bgm);

var channel = music.play(false, bgm);
```

## Pass Through
verdict: bound
```haxe
import haxefmod.core.ChannelGroup;
import haxefmod.core.CoreSystem;
import haxefmod.studio.Types;

var passthrough = ChannelGroup.create("PASSTHROUGH");
CoreSystem.attachChannelGroupToPort(FmodPortType.PASSTHROUGH, FmodPortIndex.NONE, passthrough);

var channel = your_non_diegetic_sound.play(false, passthrough);
```

