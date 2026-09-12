# studio-api-bus

## studio_bus_getchannelgroup
kind: function
index: 0

### C++
```cpp
FMOD_RESULT Studio::Bus::getChannelGroup(
  ChannelGroup **group
);
```

### C
```c
FMOD_RESULT FMOD_Studio_Bus_GetChannelGroup(
  FMOD_STUDIO_BUS *bus,
  FMOD_CHANNELGROUP **group
);
```

### C#
```csharp
RESULT Studio.Bus.getChannelGroup(
  out FMOD.ChannelGroup group
);
```

### JavaScript
```javascript
Bus.getChannelGroup(
  group
);
```

## studio_bus_getcpuusage
kind: function
index: 1

### C++
```cpp
FMOD_RESULT Studio::Bus::getCPUUsage(
  unsigned int *exclusive,
  unsigned int *inclusive
);
```

### C
```c
FMOD_RESULT FMOD_Studio_Bus_GetCPUUsage(
  FMOD_STUDIO_BUS *bus,
  unsigned int *exclusive,
  unsigned int *inclusive
);
```

### C#
```csharp
RESULT Studio.Bus.getCPUUsage(
  out uint exclusive,
  out uint inclusive
);
```

### JavaScript
```javascript
Studio.Bus.getCPUUsage(
    exclusive,
    inclusive
);
```

## studio_bus_getid
kind: function
index: 2

### C++
```cpp
FMOD_RESULT Studio::Bus::getID(
  FMOD_GUID *id
);
```

### C
```c
FMOD_RESULT FMOD_Studio_Bus_GetID(
  FMOD_STUDIO_BUS *bus,
  FMOD_GUID *id
);
```

### C#
```csharp
RESULT Studio.Bus.getID(
  out Guid id
);
```

### JavaScript
```javascript
Bus.getID(
  id
);
```

## studio_bus_getmemoryusage
kind: function
index: 3

### C++
```cpp
FMOD_RESULT Studio::Bus::getMemoryUsage(
  FMOD_STUDIO_MEMORY_USAGE *memoryusage
);
```

### C
```c
FMOD_RESULT FMOD_Studio_Bus_GetMemoryUsage(
  FMOD_STUDIO_BUS *bus,
  FMOD_STUDIO_MEMORY_USAGE *memoryusage
);
```

### C#
```csharp
RESULT Studio.Bus.getMemoryUsage(
  out MEMORY_USAGE memoryusage
);
```

## studio_bus_getmute
kind: function
index: 4

### C++
```cpp
FMOD_RESULT Studio::Bus::getMute(
  bool *mute
);
```

### C
```c
FMOD_RESULT FMOD_Studio_Bus_GetMute(
  FMOD_STUDIO_BUS *bus,
  FMOD_BOOL *mute
);
```

### C#
```csharp
RESULT Studio.Bus.getMute(
  out bool mute
);
```

### JavaScript
```javascript
Bus.getMute(
  mute
);
```

## studio_bus_getpath
kind: function
index: 5

### C++
```cpp
FMOD_RESULT Studio::Bus::getPath(
  char *path,
  int size,
  int *retrieved
);
```

### C
```c
FMOD_RESULT FMOD_Studio_Bus_GetPath(
  FMOD_STUDIO_BUS *bus,
  char *path,
  int size,
  int *retrieved
);
```

### C#
```csharp
RESULT Studio.Bus.getPath(
  out string path
);
```

### JavaScript
```javascript
Bus.getPath(
  path,
  size,
  retrieved
);
```

## studio_bus_getpaused
kind: function
index: 6

### C++
```cpp
FMOD_RESULT Studio::Bus::getPaused(
  bool *paused
);
```

### C
```c
FMOD_RESULT FMOD_Studio_Bus_GetPaused(
  FMOD_STUDIO_BUS *bus,
  FMOD_BOOL *paused
);
```

### C#
```csharp
RESULT Studio.Bus.getPaused(
  out bool paused
);
```

### JavaScript
```javascript
Bus.getPaused(
  paused
);
```

## studio_bus_getportindex
kind: function
index: 7

### C++
```cpp
FMOD_RESULT Studio::Bus::getPortIndex(
  FMOD_PORT_INDEX *index
);
```

### C
```c
FMOD_RESULT FMOD_Studio_Bus_GetPortIndex(
  FMOD_STUDIO_BUS *bus,
  FMOD_PORT_INDEX *index
);
```

### C#
```csharp
RESULT Studio.Bus.getPortIndex(
  out ulong index
);
```

### JavaScript
```javascript
Bus.getPortIndex(
  index
);
```

## studio_bus_getvolume
kind: function
index: 8

### C++
```cpp
FMOD_RESULT Studio::Bus::getVolume(
  float *volume,
  float *finalvolume = nullptr
);
```

### C
```c
FMOD_RESULT FMOD_Studio_Bus_GetVolume(
  FMOD_STUDIO_BUS *bus,
  float *volume,
  float *finalvolume
);
```

### C#
```csharp
RESULT Studio.Bus.getVolume(
  out float volume
);
RESULT Studio.Bus.getVolume(
  out float volume,
  out float finalvolume
);
```

### JavaScript
```javascript
Bus.getVolume(
  volume,
  finalvolume
);
```

## studio_bus_isvalid
kind: function
index: 9

### C++
```cpp
bool Studio::Bus::isValid()
```

### C
```c
bool FMOD_Studio_Bus_IsValid(FMOD_STUDIO_BUS *bus)
```

### C#
```csharp
bool Studio.Bus.isValid()
```

### JavaScript
```javascript
Studio.Bus.isValid()
```

## studio_bus_lockchannelgroup
kind: function
index: 10

### C++
```cpp
FMOD_RESULT Studio::Bus::lockChannelGroup();
```

### C
```c
FMOD_RESULT FMOD_Studio_Bus_LockChannelGroup(FMOD_STUDIO_BUS *bus);
```

### C#
```csharp
RESULT Studio.Bus.lockChannelGroup();
```

### JavaScript
```javascript
Bus.lockChannelGroup();
```

## studio_bus_setmute
kind: function
index: 11

### C++
```cpp
FMOD_RESULT Studio::Bus::setMute(
  bool mute
);
```

### C
```c
FMOD_RESULT FMOD_Studio_Bus_SetMute(
  FMOD_STUDIO_BUS *bus,
  FMOD_BOOL mute
);
```

### C#
```csharp
RESULT Studio.Bus.setMute(
  bool mute
);
```

### JavaScript
```javascript
Bus.setMute(
  mute
);
```

## studio_bus_setpaused
kind: function
index: 12

### C++
```cpp
FMOD_RESULT Studio::Bus::setPaused(
  bool paused
);
```

### C
```c
FMOD_RESULT FMOD_Studio_Bus_SetPaused(
  FMOD_STUDIO_BUS *bus,
  FMOD_BOOL paused
);
```

### C#
```csharp
RESULT Studio.Bus.setPaused(
  bool paused
);
```

### JavaScript
```javascript
Bus.setPaused(
  paused
);
```

## studio_bus_setportindex
kind: function
index: 13

### C++
```cpp
FMOD_RESULT Studio::Bus::setPortIndex(
  FMOD_PORT_INDEX index
);
```

### C
```c
FMOD_RESULT FMOD_Studio_Bus_SetPortIndex(
  FMOD_STUDIO_BUS *bus,
  FMOD_PORT_INDEX index
);
```

### C#
```csharp
RESULT Studio.Bus.setPortIndex(
  ulong index
);
```

### JavaScript
```javascript
Bus.setPortIndex(
  index
);
```

## studio_bus_setvolume
kind: function
index: 14

### C++
```cpp
FMOD_RESULT Studio::Bus::setVolume(
  float volume
);
```

### C
```c
FMOD_RESULT FMOD_Studio_Bus_SetVolume(
  FMOD_STUDIO_BUS *bus,
  float volume
);
```

### C#
```csharp
RESULT Studio.Bus.setVolume(
  float volume
);
```

### JavaScript
```javascript
Bus.setVolume(
  volume
);
```

## studio_bus_stopallevents
kind: function
index: 15

### C++
```cpp
FMOD_RESULT Studio::Bus::stopAllEvents(
  FMOD_STUDIO_STOP_MODE mode
);
```

### C
```c
FMOD_RESULT FMOD_Studio_Bus_StopAllEvents(
  FMOD_STUDIO_BUS *bus,
  FMOD_STUDIO_STOP_MODE mode
);
```

### C#
```csharp
RESULT Studio.Bus.stopAllEvents(
  STOP_MODE mode
);
```

### JavaScript
```javascript
Bus.stopAllEvents(
  mode
);
```

## studio_bus_unlockchannelgroup
kind: function
index: 16

### C++
```cpp
FMOD_RESULT Studio::Bus::unlockChannelGroup();
```

### C
```c
FMOD_RESULT FMOD_Studio_Bus_UnlockChannelGroup(FMOD_STUDIO_BUS *bus);
```

### C#
```csharp
RESULT Studio.Bus.unlockChannelGroup();
```

### JavaScript
```javascript
Bus.unlockChannelGroup();
```

