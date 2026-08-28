# platforms-win

## ASIO and C#
kind: example
index: 0
heading: ASIO and C#

### C#
```csharp
[STAThread]
static void Main(string[] args)
{
    Factory.System_Create(out FMOD.System system);
    system.setOutput(OUTPUTTYPE.ASIO);
    system.init(32, INITFLAGS.NORMAL, IntPtr.Zero);
}
```

## Background Music
kind: example
index: 1
heading: Background Music

### C++
```cpp
FMOD::ChannelGroup *bgm;
system->createChannelGroup("BGM", &bgm);
system->attachChannelGroupToPort(FMOD_PORT_TYPE_MUSIC, FMOD_PORT_INDEX_NONE, bgm);

FMOD::Channel* channel;
system->playSound(music, bgm, false, &channel);
```

## Pass Through
kind: example
index: 2
heading: Pass Through

### C++
```cpp
FMOD::ChannelGroup *passthrough;
system->createChannelGroup("PASSTHROUGH", &passthrough);
system->attachChannelGroupToPort(FMOD_PORT_TYPE_PASSTHROUGH, FMOD_PORT_INDEX_NONE, passthrough);

FMOD::Channel *channel;
system->playSound(your_non_diegetic_sound, passthrough, false, &channel);
```

