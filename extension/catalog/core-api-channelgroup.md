# core-api-channelgroup

## channelgroup_addgroup
kind: function
index: 0

### C++
```cpp
FMOD_RESULT ChannelGroup::addGroup(
  ChannelGroup *group,
  bool propagatedspclock = true,
  DSPConnection **connection = nullptr
);
```

### C
```c
FMOD_RESULT FMOD_ChannelGroup_AddGroup(
  FMOD_CHANNELGROUP *channelgroup,
  FMOD_CHANNELGROUP *group,
  FMOD_BOOL propagatedspclock,
  FMOD_DSPCONNECTION **connection
);
```

### C#
```csharp
RESULT ChannelGroup.addGroup(
  ChannelGroup group,
  bool propagatedspclock = true
);
RESULT ChannelGroup.addGroup(
  ChannelGroup group,
  bool propagatedspclock,
  out DSPConnection connection
);
```

### JavaScript
```javascript
ChannelGroup.addGroup(
  group,
  propagatedspclock,
  connection
);
```

## channelgroup_getchannel
kind: function
index: 1

### C++
```cpp
FMOD_RESULT ChannelGroup::getChannel(
  int index,
  Channel **channel
);
```

### C
```c
FMOD_RESULT FMOD_ChannelGroup_GetChannel(
  FMOD_CHANNELGROUP *channelgroup,
  int index,
  FMOD_CHANNEL **channel
);
```

### C#
```csharp
RESULT ChannelGroup.getChannel(
  int index,
  out Channel channel
);
```

### JavaScript
```javascript
ChannelGroup.getChannel(
  index,
  channel
);
```

## channelgroup_getgroup
kind: function
index: 2

### C++
```cpp
FMOD_RESULT ChannelGroup::getGroup(
  int index,
  ChannelGroup **group
);
```

### C
```c
FMOD_RESULT FMOD_ChannelGroup_GetGroup(
  FMOD_CHANNELGROUP *channelgroup,
  int index,
  FMOD_CHANNELGROUP **group
);
```

### C#
```csharp
RESULT ChannelGroup.getGroup(
  int index,
  out ChannelGroup group
);
```

### JavaScript
```javascript
ChannelGroup.getGroup(
  index,
  group
);
```

## channelgroup_getname
kind: function
index: 3

### C++
```cpp
FMOD_RESULT ChannelGroup::getName(
  char *name,
  int namelen
);
```

### C
```c
FMOD_RESULT FMOD_ChannelGroup_GetName(
  FMOD_CHANNELGROUP *channelgroup,
  char *name,
  int namelen
);
```

### C#
```csharp
RESULT ChannelGroup.getName(
  out string name,
  int namelen
);
```

### JavaScript
```javascript
ChannelGroup.getName(
  name
);
```

## channelgroup_getnumchannels
kind: function
index: 4

### C++
```cpp
FMOD_RESULT ChannelGroup::getNumChannels(
  int *numchannels
);
```

### C
```c
FMOD_RESULT FMOD_ChannelGroup_GetNumChannels(
  FMOD_CHANNELGROUP *channelgroup,
  int *numchannels
);
```

### C#
```csharp
RESULT ChannelGroup.getNumChannels(
  out int numchannels
);
```

### JavaScript
```javascript
ChannelGroup.getNumChannels(
  numchannels
);
```

## channelgroup_getnumgroups
kind: function
index: 5

### C++
```cpp
FMOD_RESULT ChannelGroup::getNumGroups(
  int *numgroups
);
```

### C
```c
FMOD_RESULT FMOD_ChannelGroup_GetNumGroups(
  FMOD_CHANNELGROUP *channelgroup,
  int *numgroups
);
```

### C#
```csharp
RESULT ChannelGroup.getNumGroups(
  out int numgroups
);
```

### JavaScript
```javascript
ChannelGroup.getNumGroups(
  numgroups
);
```

## channelgroup_getparentgroup
kind: function
index: 6

### C++
```cpp
FMOD_RESULT ChannelGroup::getParentGroup(
  ChannelGroup **group
);
```

### C
```c
FMOD_RESULT FMOD_ChannelGroup_GetParentGroup(
  FMOD_CHANNELGROUP *channelgroup,
  FMOD_CHANNELGROUP **group
);
```

### C#
```csharp
RESULT ChannelGroup.getParentGroup(
  out ChannelGroup group
);
```

### JavaScript
```javascript
ChannelGroup.getParentGroup(
  group
);
```

## channelgroup_release
kind: function
index: 7

### C++
```cpp
FMOD_RESULT ChannelGroup::release();
```

### C
```c
FMOD_RESULT FMOD_ChannelGroup_Release(FMOD_CHANNELGROUP *channelgroup);
```

### C#
```csharp
RESULT ChannelGroup.release();
```

### JavaScript
```javascript
ChannelGroup.release();
```

