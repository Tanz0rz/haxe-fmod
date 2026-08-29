# core-api-soundgroup

## FMOD_SOUNDGROUP_BEHAVIOR
kind: example
index: 0
heading: FMOD_SOUNDGROUP_BEHAVIOR

### C/C++
```cpp
typedef enum FMOD_SOUNDGROUP_BEHAVIOR {
  FMOD_SOUNDGROUP_BEHAVIOR_FAIL,
  FMOD_SOUNDGROUP_BEHAVIOR_MUTE,
  FMOD_SOUNDGROUP_BEHAVIOR_STEALLOWEST,
  FMOD_SOUNDGROUP_BEHAVIOR_MAX
} FMOD_SOUNDGROUP_BEHAVIOR;
```

### C#
```csharp
enum SOUNDGROUP_BEHAVIOR
{
    BEHAVIOR_FAIL,
    BEHAVIOR_MUTE,
    BEHAVIOR_STEALLOWEST,
    MAX,
}
```

### JavaScript
```javascript
FMOD.SOUNDGROUP_BEHAVIOR_FAIL
FMOD.SOUNDGROUP_BEHAVIOR_MUTE
FMOD.SOUNDGROUP_BEHAVIOR_STEALLOWEST
FMOD.SOUNDGROUP_BEHAVIOR_MAX
```

## soundgroup_getmaxaudible
kind: function
index: 1

### C++
```cpp
FMOD_RESULT SoundGroup::getMaxAudible(
  int *maxaudible
);
```

### C
```c
FMOD_RESULT FMOD_SoundGroup_GetMaxAudible(
  FMOD_SOUNDGROUP *soundgroup,
  int *maxaudible
);
```

### C#
```csharp
RESULT SoundGroup.getMaxAudible(
  out int maxaudible
);
```

### JavaScript
```javascript
SoundGroup.getMaxAudible(
  maxaudible
);
```

## soundgroup_getmaxaudiblebehavior
kind: function
index: 2

### C++
```cpp
FMOD_RESULT SoundGroup::getMaxAudibleBehavior(
  FMOD_SOUNDGROUP_BEHAVIOR *behavior
);
```

### C
```c
FMOD_RESULT FMOD_SoundGroup_GetMaxAudibleBehavior(
  FMOD_SOUNDGROUP *soundgroup,
  FMOD_SOUNDGROUP_BEHAVIOR *behavior
);
```

### C#
```csharp
RESULT SoundGroup.getMaxAudibleBehavior(
  out SOUNDGROUP_BEHAVIOR behavior
);
```

### JavaScript
```javascript
SoundGroup.getMaxAudibleBehavior(
  behavior
);
```

## soundgroup_getmutefadespeed
kind: function
index: 3

### C++
```cpp
FMOD_RESULT SoundGroup::getMuteFadeSpeed(
  float *speed
);
```

### C
```c
FMOD_RESULT FMOD_SoundGroup_GetMuteFadeSpeed(
  FMOD_SOUNDGROUP *soundgroup,
  float *speed
);
```

### C#
```csharp
RESULT SoundGroup.getMuteFadeSpeed(
  out float speed
);
```

### JavaScript
```javascript
SoundGroup.getMuteFadeSpeed(
  speed
);
```

## soundgroup_getname
kind: function
index: 4

### C++
```cpp
FMOD_RESULT SoundGroup::getName(
  char *name,
  int namelen
);
```

### C
```c
FMOD_RESULT FMOD_SoundGroup_GetName(
  FMOD_SOUNDGROUP *soundgroup,
  char *name,
  int namelen
);
```

### C#
```csharp
RESULT SoundGroup.getName(
  out string name,
  int namelen
);
```

### JavaScript
```javascript
SoundGroup.getName(
  name
);
```

## soundgroup_getnumplaying
kind: function
index: 5

### C++
```cpp
FMOD_RESULT SoundGroup::getNumPlaying(
  int *numplaying
);
```

### C
```c
FMOD_RESULT FMOD_SoundGroup_GetNumPlaying(
  FMOD_SOUNDGROUP *soundgroup,
  int *numplaying
);
```

### C#
```csharp
RESULT SoundGroup.getNumPlaying(
  out int numplaying
);
```

### JavaScript
```javascript
SoundGroup.getNumPlaying(
  numplaying
);
```

## soundgroup_getnumsounds
kind: function
index: 6

### C++
```cpp
FMOD_RESULT SoundGroup::getNumSounds(
  int *numsounds
);
```

### C
```c
FMOD_RESULT FMOD_SoundGroup_GetNumSounds(
  FMOD_SOUNDGROUP *soundgroup,
  int *numsounds
);
```

### C#
```csharp
RESULT SoundGroup.getNumSounds(
  out int numsounds
);
```

### JavaScript
```javascript
SoundGroup.getNumSounds(
  numsounds
);
```

## soundgroup_getsound
kind: function
index: 7

### C++
```cpp
FMOD_RESULT SoundGroup::getSound(
  int index,
  Sound **sound
);
```

### C
```c
FMOD_RESULT FMOD_SoundGroup_GetSound(
  FMOD_SOUNDGROUP *soundgroup,
  int index,
  FMOD_SOUND **sound
);
```

### C#
```csharp
RESULT SoundGroup.getSound(
  int index,
  out Sound sound
);
```

### JavaScript
```javascript
SoundGroup.getSound(
  index,
  sound
);
```

## soundgroup_getsystemobject
kind: function
index: 8

### C++
```cpp
FMOD_RESULT SoundGroup::getSystemObject(
  System **system
);
```

### C
```c
FMOD_RESULT FMOD_SoundGroup_GetSystemObject(
  FMOD_SOUNDGROUP *soundgroup,
  FMOD_SYSTEM **system
);
```

### C#
```csharp
RESULT SoundGroup.getSystemObject(
  out System system
);
```

### JavaScript
```javascript
SoundGroup.getSystemObject(
  system
);
```

## soundgroup_getuserdata
kind: function
index: 9

### C++
```cpp
FMOD_RESULT SoundGroup::getUserData(
  void **userdata
);
```

### C
```c
FMOD_RESULT FMOD_SoundGroup_GetUserData(
  FMOD_SOUNDGROUP *soundgroup,
  void **userdata
);
```

### C#
```csharp
RESULT SoundGroup.getUserData(
  out IntPtr userdata
);
```

### JavaScript
```javascript
SoundGroup.getUserData(
  userdata
);
```

## soundgroup_getvolume
kind: function
index: 10

### C++
```cpp
FMOD_RESULT SoundGroup::getVolume(
  float *volume
);
```

### C
```c
FMOD_RESULT FMOD_SoundGroup_GetVolume(
  FMOD_SOUNDGROUP *soundgroup,
  float *volume
);
```

### C#
```csharp
RESULT SoundGroup.getVolume(
  out float volume
);
```

### JavaScript
```javascript
SoundGroup.getVolume(
  volume
);
```

## soundgroup_release
kind: function
index: 11

### C++
```cpp
FMOD_RESULT SoundGroup::release();
```

### C
```c
FMOD_RESULT FMOD_SoundGroup_Release(FMOD_SOUNDGROUP *soundgroup);
```

### C#
```csharp
RESULT SoundGroup.release();
```

### JavaScript
```javascript
SoundGroup.release();
```

## soundgroup_setmaxaudible
kind: function
index: 12

### C++
```cpp
FMOD_RESULT SoundGroup::setMaxAudible(
  int maxaudible
);
```

### C
```c
FMOD_RESULT FMOD_SoundGroup_SetMaxAudible(
  FMOD_SOUNDGROUP *soundgroup,
  int maxaudible
);
```

### C#
```csharp
RESULT SoundGroup.setMaxAudible(
  int maxaudible
);
```

### JavaScript
```javascript
SoundGroup.setMaxAudible(
  maxaudible
);
```

## soundgroup_setmaxaudiblebehavior
kind: function
index: 13

### C++
```cpp
FMOD_RESULT SoundGroup::setMaxAudibleBehavior(
  FMOD_SOUNDGROUP_BEHAVIOR behavior
);
```

### C
```c
FMOD_RESULT FMOD_SoundGroup_SetMaxAudibleBehavior(
  FMOD_SOUNDGROUP *soundgroup,
  FMOD_SOUNDGROUP_BEHAVIOR behavior
);
```

### C#
```csharp
RESULT SoundGroup.setMaxAudibleBehavior(
  SOUNDGROUP_BEHAVIOR behavior
);
```

### JavaScript
```javascript
SoundGroup.setMaxAudibleBehavior(
  behavior
);
```

## soundgroup_setmutefadespeed
kind: function
index: 14

### C++
```cpp
FMOD_RESULT SoundGroup::setMuteFadeSpeed(
  float speed
);
```

### C
```c
FMOD_RESULT FMOD_SoundGroup_SetMuteFadeSpeed(
  FMOD_SOUNDGROUP *soundgroup,
  float speed
);
```

### C#
```csharp
RESULT SoundGroup.setMuteFadeSpeed(
  float speed
);
```

### JavaScript
```javascript
SoundGroup.setMuteFadeSpeed(
  speed
);
```

## soundgroup_setuserdata
kind: function
index: 15

### C++
```cpp
FMOD_RESULT SoundGroup::setUserData(
  void *userdata
);
```

### C
```c
FMOD_RESULT FMOD_SoundGroup_SetUserData(
  FMOD_SOUNDGROUP *soundgroup,
  void *userdata
);
```

### C#
```csharp
RESULT SoundGroup.setUserData(
  IntPtr userdata
);
```

### JavaScript
```javascript
SoundGroup.setUserData(
  userdata
);
```

## soundgroup_setvolume
kind: function
index: 16

### C++
```cpp
FMOD_RESULT SoundGroup::setVolume(
  float volume
);
```

### C
```c
FMOD_RESULT FMOD_SoundGroup_SetVolume(
  FMOD_SOUNDGROUP *soundgroup,
  float volume
);
```

### C#
```csharp
RESULT SoundGroup.setVolume(
  float volume
);
```

### JavaScript
```javascript
SoundGroup.setVolume(
  volume
);
```

## soundgroup_stop
kind: function
index: 17

### C++
```cpp
FMOD_RESULT SoundGroup::stop();
```

### C
```c
FMOD_RESULT FMOD_SoundGroup_Stop(FMOD_SOUNDGROUP *soundgroup);
```

### C#
```csharp
RESULT SoundGroup.stop();
```

### JavaScript
```javascript
SoundGroup.stop();
```

