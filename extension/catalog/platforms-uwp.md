# platforms-uwp

## Background Music
kind: example
index: 0
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
index: 1
heading: Pass Through

### C++
```cpp
FMOD::ChannelGroup *passthrough;
system->createChannelGroup("PASSTHROUGH", &passthrough);
system->attachChannelGroupToPort(FMOD_PORT_TYPE_PASSTHROUGH, FMOD_PORT_INDEX_NONE, passthrough);

FMOD::Channel *channel;
system->playSound(your_non_diegetic_sound, passthrough, false, &channel);
```

