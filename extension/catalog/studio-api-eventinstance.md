# studio-api-eventinstance

## studio_eventinstance_get3dattributes
kind: function
index: 0

### C++
```cpp
FMOD_RESULT Studio::EventInstance::get3DAttributes(
  FMOD_3D_ATTRIBUTES *attributes
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventInstance_Get3DAttributes(
  FMOD_STUDIO_EVENTINSTANCE *eventinstance,
  FMOD_3D_ATTRIBUTES *attributes
);
```

### C#
```csharp
RESULT Studio.EventInstance.get3DAttributes(
  out _3D_ATTRIBUTES attributes
);
```

### JavaScript
```javascript
Studio.EventInstance.get3DAttributes(
  attributes
);
```

## studio_eventinstance_getchannelgroup
kind: function
index: 1

### C++
```cpp
FMOD_RESULT Studio::EventInstance::getChannelGroup(
  ChannelGroup **group
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventInstance_GetChannelGroup(
  FMOD_STUDIO_EVENTINSTANCE *eventinstance,
  FMOD_CHANNELGROUP **group
);
```

### C#
```csharp
RESULT Studio.EventInstance.getChannelGroup(
  out FMOD.ChannelGroup group
);
```

### JavaScript
```javascript
Studio.EventInstance.getChannelGroup(
  group
);
```

## studio_eventinstance_getcpuusage
kind: function
index: 2

### C++
```cpp
FMOD_RESULT Studio::EventInstance::getCPUUsage(
  unsigned int *exclusive,
  unsigned int *inclusive
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventInstance_GetCPUUsage(
  FMOD_STUDIO_EVENTINSTANCE *eventinstance,
  unsigned int *exclusive,
  unsigned int *inclusive
);
```

### C#
```csharp
RESULT Studio.EventInstance.getCPUUsage(
  out uint exclusive,
  out uint inclusive
);
```

### JavaScript
```javascript
Studio.EventInstance.getCPUUsage(
  exclusive,
  inclusive
);
```

## studio_eventinstance_getdescription
kind: function
index: 3

### C++
```cpp
FMOD_RESULT Studio::EventInstance::getDescription(
  Studio::EventDescription **description
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventInstance_GetDescription(
  FMOD_STUDIO_EVENTINSTANCE *eventinstance,
  FMOD_STUDIO_EVENTDESCRIPTION **description
);
```

### C#
```csharp
RESULT Studio.EventInstance.getDescription(
  out EventDescription description
);
```

### JavaScript
```javascript
Studio.EventInstance.getDescription(
  description
);
```

## studio_eventinstance_getlistenermask
kind: function
index: 4

### C++
```cpp
FMOD_RESULT Studio::EventInstance::getListenerMask(
  unsigned int *mask
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventInstance_GetListenerMask(
  FMOD_STUDIO_EVENTINSTANCE *eventinstance,
  unsigned int *mask
);
```

### C#
```csharp
RESULT Studio.EventInstance.getListenerMask(
  out uint mask
);
```

### JavaScript
```javascript
Studio.EventInstance.getListenerMask(
  mask
);
```

## studio_eventinstance_getmemoryusage
kind: function
index: 5

### C++
```cpp
FMOD_RESULT Studio::EventInstance::getMemoryUsage(
  FMOD_STUDIO_MEMORY_USAGE *memoryusage
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventInstance_GetMemoryUsage(
  FMOD_STUDIO_EVENTINSTANCE *eventinstance,
  FMOD_STUDIO_MEMORY_USAGE *memoryusage
);
```

### C#
```csharp
RESULT Studio.EventInstance.getMemoryUsage(
  out MEMORY_USAGE memoryusage
);
```

## studio_eventinstance_getminmaxdistance
kind: function
index: 6

### C++
```cpp
FMOD_RESULT Studio::EventInstance::getMinMaxDistance(
  float *min,
  float *max
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventInstance_GetMinMaxDistance(
  FMOD_STUDIO_EVENTINSTANCE *eventinstance,
  float *min,
  float *max
);
```

### C#
```csharp
RESULT Studio.EventInstance.getMinMaxDistance(
  out float min,
  out float max
);
```

### JavaScript
```javascript
Studio.EventInstance.getMinMaxDistance(
  min,
  max
);
```

## studio_eventinstance_getparameterbyid
kind: function
index: 7

### C++
```cpp
FMOD_RESULT Studio::EventInstance::getParameterByID(
  FMOD_STUDIO_PARAMETER_ID id,
  float *value,
  float *finalvalue = nullptr
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventInstance_GetParameterByID(
  FMOD_STUDIO_EVENTINSTANCE *eventinstance,
  FMOD_STUDIO_PARAMETER_ID id,
  float *value,
  float *finalvalue
);
```

### C#
```csharp
RESULT Studio.EventInstance.getParameterByID(
  PARAMETER_ID id,
  out float value
);
RESULT Studio.EventInstance.getParameterByID(
  PARAMETER_ID id,
  out float value,
  out float finalvalue
);
```

### JavaScript
```javascript
Studio.EventInstance.getParameterByID(
  id,
  value,
  finalvalue
);
```

## studio_eventinstance_getparameterbyname
kind: function
index: 8

### C++
```cpp
FMOD_RESULT Studio::EventInstance::getParameterByName(
  const char *name,
  float *value,
  float *finalvalue = nullptr
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventInstance_GetParameterByName(
  FMOD_STUDIO_EVENTINSTANCE *eventinstance,
  const char *name,
  float *value,
  float *finalvalue
);
```

### C#
```csharp
RESULT Studio.EventInstance.getParameterByName(
  string name,
  out float value
);
RESULT Studio.EventInstance.getParameterByName(
  string name,
  out float value,
  out float finalvalue
);
```

### JavaScript
```javascript
Studio.EventInstance.getParameterByName(
  name,
  value,
  finalvalue
);
```

## studio_eventinstance_getpaused
kind: function
index: 9

### C++
```cpp
FMOD_RESULT Studio::EventInstance::getPaused(
  bool *paused
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventInstance_GetPaused(
  FMOD_STUDIO_EVENTINSTANCE *eventinstance,
  FMOD_BOOL *paused
);
```

### C#
```csharp
RESULT Studio.EventInstance.getPaused(
  out bool paused
);
```

### JavaScript
```javascript
Studio.EventInstance.getPaused(
  paused
);
```

## studio_eventinstance_getpitch
kind: function
index: 10

### C++
```cpp
FMOD_RESULT Studio::EventInstance::getPitch(
  float *pitch,
  float *finalpitch = nullptr
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventInstance_GetPitch(
  FMOD_STUDIO_EVENTINSTANCE *eventinstance,
  float *pitch,
  float *finalpitch
);
```

### C#
```csharp
RESULT Studio.EventInstance.getPitch(
  out float pitch
);
RESULT Studio.EventInstance.getPitch(
  out float pitch,
  out float finalpitch
);
```

### JavaScript
```javascript
Studio.EventInstance.getPitch(
  pitch,
  finalpitch
);
```

## studio_eventinstance_getplaybackstate
kind: function
index: 11

### C++
```cpp
FMOD_RESULT Studio::EventInstance::getPlaybackState(
  FMOD_STUDIO_PLAYBACK_STATE *state
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventInstance_GetPlaybackState(
  FMOD_STUDIO_EVENTINSTANCE *eventinstance,
  FMOD_STUDIO_PLAYBACK_STATE *state
);
```

### C#
```csharp
RESULT Studio.EventInstance.getPlaybackState(
  out PLAYBACK_STATE state
);
```

### JavaScript
```javascript
Studio.EventInstance.getPlaybackState(
  state
);
```

## studio_eventinstance_getproperty
kind: function
index: 12

### C++
```cpp
FMOD_RESULT Studio::EventInstance::getProperty(
  FMOD_STUDIO_EVENT_PROPERTY index,
  float *value
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventInstance_GetProperty(
  FMOD_STUDIO_EVENTINSTANCE *eventinstance,
  FMOD_STUDIO_EVENT_PROPERTY index,
  float *value
);
```

### C#
```csharp
RESULT Studio.EventInstance.getProperty(
  EVENT_PROPERTY index,
  out float value
);
```

### JavaScript
```javascript
Studio.EventInstance.getProperty(
  index,
  value
);
```

## studio_eventinstance_getreverblevel
kind: function
index: 13

### C++
```cpp
FMOD_RESULT Studio::EventInstance::getReverbLevel(
  int index,
  float *level
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventInstance_GetReverbLevel(
  FMOD_STUDIO_EVENTINSTANCE *eventinstance,
  int index,
  float *level
);
```

### C#
```csharp
RESULT Studio.EventInstance.getReverbLevel(
  int index,
  out float level
);
```

### JavaScript
```javascript
Studio.EventInstance.getReverbLevel(
  index,
  level
);
```

## studio_eventinstance_getsystem
kind: function
index: 14

### C++
```cpp
FMOD_RESULT Studio::EventInstance::getSystem(
  Studio::System **system
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventInstance_GetSystem(
  FMOD_STUDIO_EVENTINSTANCE *eventinstance,
  FMOD_STUDIO_SYSTEM **system
);
```

### C#
```csharp
RESULT Studio.EventInstance.getSystem(
  out System system
);
```

### JavaScript
```javascript
Studio.EventInstance.getSystem(
  system
);
```

## studio_eventinstance_gettimelineposition
kind: function
index: 15

### C++
```cpp
FMOD_RESULT Studio::EventInstance::getTimelinePosition(
  int *position
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventInstance_GetTimelinePosition(
  FMOD_STUDIO_EVENTINSTANCE *eventinstance,
  int *position
);
```

### C#
```csharp
RESULT Studio.EventInstance.getTimelinePosition(
  out int position
);
```

### JavaScript
```javascript
Studio.EventInstance.getTimelinePosition(
  position
);
```

## studio_eventinstance_getuserdata
kind: function
index: 16

### C++
```cpp
FMOD_RESULT Studio::EventInstance::getUserData(
  void **userdata
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventInstance_GetUserData(
  FMOD_STUDIO_EVENTINSTANCE *eventinstance,
  void **userdata
);
```

### C#
```csharp
RESULT Studio.EventInstance.getUserData(
  out IntPtr userdata
);
```

### JavaScript
```javascript
Studio.EventInstance.getUserData(
  userdata
);
```

## studio_eventinstance_getvolume
kind: function
index: 17

### C++
```cpp
FMOD_RESULT Studio::EventInstance::getVolume(
  float *volume,
  float *finalvolume = nullptr
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventInstance_GetVolume(
  FMOD_STUDIO_EVENTINSTANCE *eventinstance,
  float *volume,
  float *finalvolume
);
```

### C#
```csharp
RESULT Studio.EventInstance.getVolume(
  out float volume
);
RESULT Studio.EventInstance.getVolume(
  out float volume,
  out float finalvolume
);
```

### JavaScript
```javascript
Studio.EventInstance.getVolume(
  volume,
  finalvolume
);
```

## studio_eventinstance_isvalid
kind: function
index: 18

### C++
```cpp
bool Studio::EventInstance::isValid()
```

### C
```c
bool FMOD_Studio_EventInstance_IsValid(FMOD_STUDIO_EVENTINSTANCE *eventinstance)
```

### C#
```csharp
bool Studio.EventInstance.isValid()
```

### JavaScript
```javascript
Studio.EventInstance.isValid()
```

## studio_eventinstance_isvirtual
kind: function
index: 19

### C++
```cpp
FMOD_RESULT Studio::EventInstance::isVirtual(
  bool *virtualstate
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventInstance_IsVirtual(
  FMOD_STUDIO_EVENTINSTANCE *eventinstance,
  FMOD_BOOL *virtualstate
);
```

### C#
```csharp
RESULT Studio.EventInstance.isVirtual(
  out bool virtualstate
);
```

### JavaScript
```javascript
Studio.EventInstance.isVirtual(
  virtualstate
);
```

## studio_eventinstance_keyoff
kind: function
index: 20

### C++
```cpp
FMOD_RESULT Studio::EventInstance::keyOff();
```

### C
```c
FMOD_RESULT FMOD_Studio_EventInstance_KeyOff(FMOD_STUDIO_EVENTINSTANCE *eventinstance);
```

### C#
```csharp
RESULT Studio.EventInstance.keyOff();
```

### JavaScript
```javascript
Studio.EventInstance.keyOff();
```

## studio_eventinstance_release
kind: function
index: 21

### C++
```cpp
FMOD_RESULT Studio::EventInstance::release();
```

### C
```c
FMOD_RESULT FMOD_Studio_EventInstance_Release(FMOD_STUDIO_EVENTINSTANCE *eventinstance);
```

### C#
```csharp
RESULT Studio.EventInstance.release();
```

### JavaScript
```javascript
Studio.EventInstance.release();
```

## studio_eventinstance_set3dattributes
kind: function
index: 22

### C++
```cpp
FMOD_RESULT Studio::EventInstance::set3DAttributes(
  const FMOD_3D_ATTRIBUTES *attributes
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventInstance_Set3DAttributes(
  FMOD_STUDIO_EVENTINSTANCE *eventinstance,
  FMOD_3D_ATTRIBUTES *attributes
);
```

### C#
```csharp
RESULT Studio.EventInstance.set3DAttributes(
  _3D_ATTRIBUTES attributes
);
```

### JavaScript
```javascript
Studio.EventInstance.set3DAttributes(
  attributes
);
```

## studio_eventinstance_setcallback
kind: function
index: 23

### C++
```cpp
FMOD_RESULT Studio::EventInstance::setCallback(
  FMOD_STUDIO_EVENT_CALLBACK callback,
  FMOD_STUDIO_EVENT_CALLBACK_TYPE callbackmask = FMOD_STUDIO_EVENT_CALLBACK_ALL
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventInstance_SetCallback(
  FMOD_STUDIO_EVENTINSTANCE *eventinstance,
  FMOD_STUDIO_EVENT_CALLBACK callback,
  FMOD_STUDIO_EVENT_CALLBACK_TYPE callbackmask
);
```

### C#
```csharp
RESULT Studio.EventInstance.setCallback(
  EVENT_CALLBACK callback,
  EVENT_CALLBACK_TYPE callbackmask = EVENT_CALLBACK_TYPE.ALL
);
```

### JavaScript
```javascript
Studio.EventInstance.setCallback(
  callback,
  callbackmask
);
```

## studio_eventinstance_setlistenermask
kind: function
index: 24

### C++
```cpp
FMOD_RESULT Studio::EventInstance::setListenerMask(
  unsigned int mask
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventInstance_SetListenerMask(
  FMOD_STUDIO_EVENTINSTANCE *eventinstance,
  unsigned int mask
);
```

### C#
```csharp
RESULT Studio.EventInstance.setListenerMask(
  uint mask
);
```

### JavaScript
```javascript
Studio.EventInstance.setListenerMask(
  mask
);
```

## studio_eventinstance_setparameterbyid
kind: function
index: 25

### C++
```cpp
FMOD_RESULT Studio::EventInstance::setParameterByID(
  FMOD_STUDIO_PARAMETER_ID id,
  float value,
  bool ignoreseekspeed = false
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventInstance_SetParameterByID(
  FMOD_STUDIO_EVENTINSTANCE *eventinstance,
  FMOD_STUDIO_PARAMETER_ID id,
  float value,
  FMOD_BOOL ignoreseekspeed
);
```

### C#
```csharp
RESULT Studio.EventInstance.setParameterByID(
  PARAMETER_ID id,
  float value,
  bool ignoreseekspeed = false
);
```

### JavaScript
```javascript
Studio.EventInstance.setParameterByID(
  id,
  value,
  ignoreseekspeed
);
```

## studio_eventinstance_setparameterbyidwithlabel
kind: function
index: 26

### C++
```cpp
FMOD_RESULT Studio::EventInstance::setParameterByIDWithLabel(
  FMOD_STUDIO_PARAMETER_ID id,
  const char *label,
  bool ignoreseekspeed = false
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventInstance_SetParameterByIDWithLabel(
  FMOD_STUDIO_EVENTINSTANCE *eventinstance,
  FMOD_STUDIO_PARAMETER_ID id,
  const char *label,
  FMOD_BOOL ignoreseekspeed
);
```

### C#
```csharp
RESULT Studio.EventInstance.setParameterByIDWithLabel(
  PARAMETER_ID id,
  string label,
  bool ignoreseekspeed = false
);
```

### JavaScript
```javascript
Studio.EventInstance.setParameterByIDWithLabel(
  id,
  label,
  ignoreseekspeed
);
```

## studio_eventinstance_setparameterbyname
kind: function
index: 27

### C++
```cpp
FMOD_RESULT Studio::EventInstance::setParameterByName(
  const char *name,
  float value,
  bool ignoreseekspeed = false
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventInstance_SetParameterByName(
  FMOD_STUDIO_EVENTINSTANCE *eventinstance,
  const char *name,
  float value,
  FMOD_BOOL ignoreseekspeed
);
```

### C#
```csharp
RESULT Studio.EventInstance.setParameterByName(
  string name,
  float value,
  bool ignoreseekspeed = false
);
```

### JavaScript
```javascript
Studio.EventInstance.setParameterByName(
  name,
  value,
  ignoreseekspeed
);
```

## studio_eventinstance_setparameterbynamewithlabel
kind: function
index: 28

### C++
```cpp
FMOD_RESULT Studio::EventInstance::setParameterByNameWithLabel(
  const char *name,
  const char *label,
  bool ignoreseekspeed = false
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventInstance_SetParameterByNameWithLabel(
  FMOD_STUDIO_EVENTINSTANCE *eventinstance,
  const char *name,
  const char *label,
  FMOD_BOOL ignoreseekspeed
);
```

### C#
```csharp
RESULT Studio.EventInstance.setParameterByNameWithLabel(
  string name,
  string label,
  bool ignoreseekspeed = false
);
```

### JavaScript
```javascript
Studio.EventInstance.setParameterByNameWithLabel(
  name,
  label,
  ignoreseekspeed
);
```

## studio_eventinstance_setparametersbyids
kind: function
index: 29

### C++
```cpp
FMOD_RESULT Studio::EventInstance::setParametersByIDs(
  const FMOD_STUDIO_PARAMETER_ID *ids,
  float *values,
  int count,
  bool ignoreseekspeed = false
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventInstance_SetParametersByIDs(
  FMOD_STUDIO_EVENTINSTANCE *eventinstance,
  const FMOD_STUDIO_PARAMETER_ID *ids,
  float *values,
  int count,
  FMOD_BOOL ignoreseekspeed
);
```

### C#
```csharp
RESULT Studio.EventInstance.setParametersByIDs(
  PARAMETER_ID[] ids,
  float[] values,
  int count,
  bool ignoreseekspeed = false
);
```

### JavaScript
```javascript
Studio.EventInstance.setParametersByIDs(
  ids,
  values,
  count,
  ignoreseekspeed
);
```

## studio_eventinstance_setpaused
kind: function
index: 30

### C++
```cpp
FMOD_RESULT Studio::EventInstance::setPaused(
  bool paused
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventInstance_SetPaused(
  FMOD_STUDIO_EVENTINSTANCE *eventinstance,
  FMOD_BOOL paused
);
```

### C#
```csharp
RESULT Studio.EventInstance.setPaused(
  bool paused
);
```

### JavaScript
```javascript
Studio.EventInstance.setPaused(
  paused
);
```

## studio_eventinstance_setpitch
kind: function
index: 31

### C++
```cpp
FMOD_RESULT Studio::EventInstance::setPitch(
  float pitch
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventInstance_SetPitch(
  FMOD_STUDIO_EVENTINSTANCE *eventinstance,
  float pitch
);
```

### C#
```csharp
RESULT Studio.EventInstance.setPitch(
  float pitch
);
```

### JavaScript
```javascript
Studio.EventInstance.setPitch(
  pitch
);
```

## studio_eventinstance_setproperty
kind: function
index: 32

### C++
```cpp
FMOD_RESULT Studio::EventInstance::setProperty(
  FMOD_STUDIO_EVENT_PROPERTY index,
  float value
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventInstance_SetProperty(
  FMOD_STUDIO_EVENTINSTANCE *eventinstance,
  FMOD_STUDIO_EVENT_PROPERTY index,
  float value
);
```

### C#
```csharp
RESULT Studio.EventInstance.setProperty(
  EVENT_PROPERTY index,
  float value
);
```

### JavaScript
```javascript
Studio.EventInstance.setProperty(
  index,
  value
);
```

## studio_eventinstance_setreverblevel
kind: function
index: 33

### C++
```cpp
FMOD_RESULT Studio::EventInstance::setReverbLevel(
  int index,
  float level
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventInstance_SetReverbLevel(
  FMOD_STUDIO_EVENTINSTANCE *eventinstance,
  int index,
  float level
);
```

### C#
```csharp
RESULT Studio.EventInstance.setReverbLevel(
  int index,
  float level
);
```

### JavaScript
```javascript
Studio.EventInstance.setReverbLevel(
  index,
  level
);
```

## studio_eventinstance_settimelineposition
kind: function
index: 34

### C++
```cpp
FMOD_RESULT Studio::EventInstance::setTimelinePosition(
  int position
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventInstance_SetTimelinePosition(
  FMOD_STUDIO_EVENTINSTANCE *eventinstance,
  int position
);
```

### C#
```csharp
RESULT Studio.EventInstance.setTimelinePosition(
  int position
);
```

### JavaScript
```javascript
Studio.EventInstance.setTimelinePosition(
  position
);
```

## studio_eventinstance_setuserdata
kind: function
index: 35

### C++
```cpp
FMOD_RESULT Studio::EventInstance::setUserData(
  void *userdata
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventInstance_SetUserData(
  FMOD_STUDIO_EVENTINSTANCE *eventinstance,
  void *userdata
);
```

### C#
```csharp
RESULT Studio.EventInstance.setUserData(
  IntPtr userdata
);
```

### JavaScript
```javascript
Studio.EventInstance.setUserData(
  userdata
);
```

## studio_eventinstance_setvolume
kind: function
index: 36

### C++
```cpp
FMOD_RESULT Studio::EventInstance::setVolume(
  float volume
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventInstance_SetVolume(
  FMOD_STUDIO_EVENTINSTANCE *eventinstance,
  float volume
);
```

### C#
```csharp
RESULT Studio.EventInstance.setVolume(
  float volume
);
```

### JavaScript
```javascript
Studio.EventInstance.setVolume(
  volume
);
```

## studio_eventinstance_start
kind: function
index: 37

### C++
```cpp
FMOD_RESULT Studio::EventInstance::start();
```

### C
```c
FMOD_RESULT FMOD_Studio_EventInstance_Start(FMOD_STUDIO_EVENTINSTANCE *eventinstance);
```

### C#
```csharp
RESULT Studio.EventInstance.start();
```

### JavaScript
```javascript
Studio.EventInstance.start();
```

## studio_eventinstance_stop
kind: function
index: 38

### C++
```cpp
FMOD_RESULT Studio::EventInstance::stop(
  FMOD_STUDIO_STOP_MODE mode
);
```

### C
```c
FMOD_RESULT FMOD_Studio_EventInstance_Stop(
  FMOD_STUDIO_EVENTINSTANCE *eventinstance,
  FMOD_STUDIO_STOP_MODE mode
);
```

### C#
```csharp
RESULT Studio.EventInstance.stop(
  STOP_MODE mode
);
```

### JavaScript
```javascript
Studio.EventInstance.stop(
  mode
);
```

## FMOD_STUDIO_EVENT_CALLBACK
kind: example
index: 39
heading: FMOD_STUDIO_EVENT_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_STUDIO_EVENT_CALLBACK(
  FMOD_STUDIO_EVENT_CALLBACK_TYPE type,
  FMOD_STUDIO_EVENTINSTANCE *event,
  void *parameters
);
```

### C#
```csharp
delegate RESULT Studio.EVENT_CALLBACK(
  EVENT_CALLBACK_TYPE type,
  IntPtr event,
  IntPtr parameters
);
```

### JavaScript
```javascript
function FMOD_STUDIO_EVENT_CALLBACK(
  type,
  event,
  parameters
)
```

## FMOD_STUDIO_EVENT_CALLBACK_TYPE
kind: example
index: 40
heading: FMOD_STUDIO_EVENT_CALLBACK_TYPE
tabbed: yes

### C/C++
```cpp
#define FMOD_STUDIO_EVENT_CALLBACK_CREATED                  0x00000001
#define FMOD_STUDIO_EVENT_CALLBACK_DESTROYED                0x00000002
#define FMOD_STUDIO_EVENT_CALLBACK_STARTING                 0x00000004
#define FMOD_STUDIO_EVENT_CALLBACK_STARTED                  0x00000008
#define FMOD_STUDIO_EVENT_CALLBACK_RESTARTED                0x00000010
#define FMOD_STUDIO_EVENT_CALLBACK_STOPPED                  0x00000020
#define FMOD_STUDIO_EVENT_CALLBACK_START_FAILED             0x00000040
#define FMOD_STUDIO_EVENT_CALLBACK_CREATE_PROGRAMMER_SOUND  0x00000080
#define FMOD_STUDIO_EVENT_CALLBACK_DESTROY_PROGRAMMER_SOUND 0x00000100
#define FMOD_STUDIO_EVENT_CALLBACK_PLUGIN_CREATED           0x00000200
#define FMOD_STUDIO_EVENT_CALLBACK_PLUGIN_DESTROYED         0x00000400
#define FMOD_STUDIO_EVENT_CALLBACK_TIMELINE_MARKER          0x00000800
#define FMOD_STUDIO_EVENT_CALLBACK_TIMELINE_BEAT            0x00001000
#define FMOD_STUDIO_EVENT_CALLBACK_SOUND_PLAYED             0x00002000
#define FMOD_STUDIO_EVENT_CALLBACK_SOUND_STOPPED            0x00004000
#define FMOD_STUDIO_EVENT_CALLBACK_REAL_TO_VIRTUAL          0x00008000
#define FMOD_STUDIO_EVENT_CALLBACK_VIRTUAL_TO_REAL          0x00010000
#define FMOD_STUDIO_EVENT_CALLBACK_START_EVENT_COMMAND      0x00020000
#define FMOD_STUDIO_EVENT_CALLBACK_NESTED_TIMELINE_BEAT     0x00040000
#define FMOD_STUDIO_EVENT_CALLBACK_ALL                      0xFFFFFFFF
```

### C#
```csharp
enum Studio.EVENT_CALLBACK_TYPE : uint
{
  CREATED                  = 0x00000001,
  DESTROYED                = 0x00000002,
  STARTING                 = 0x00000004,
  STARTED                  = 0x00000008,
  RESTARTED                = 0x00000010,
  STOPPED                  = 0x00000020,
  START_FAILED             = 0x00000040,
  CREATE_PROGRAMMER_SOUND  = 0x00000080,
  DESTROY_PROGRAMMER_SOUND = 0x00000100,
  PLUGIN_CREATED           = 0x00000200,
  PLUGIN_DESTROYED         = 0x00000400,
  TIMELINE_MARKER          = 0x00000800,
  TIMELINE_BEAT            = 0x00001000,
  SOUND_PLAYED             = 0x00002000,
  SOUND_STOPPED            = 0x00004000,
  REAL_TO_VIRTUAL          = 0x00008000,
  VIRTUAL_TO_REAL          = 0x00010000,
  START_EVENT_COMMAND      = 0x00020000,
  NESTED_TIMELINE_BEAT     = 0x00040000,
  ALL                      = 0xFFFFFFFF,
}
```

### JavaScript
```javascript
STUDIO_EVENT_CALLBACK_CREATED                  0x00000001
STUDIO_EVENT_CALLBACK_DESTROYED                0x00000002
STUDIO_EVENT_CALLBACK_STARTING                 0x00000004
STUDIO_EVENT_CALLBACK_STARTED                  0x00000008
STUDIO_EVENT_CALLBACK_RESTARTED                0x00000010
STUDIO_EVENT_CALLBACK_STOPPED                  0x00000020
STUDIO_EVENT_CALLBACK_START_FAILED             0x00000040
STUDIO_EVENT_CALLBACK_CREATE_PROGRAMMER_SOUND  0x00000080
STUDIO_EVENT_CALLBACK_DESTROY_PROGRAMMER_SOUND 0x00000100
STUDIO_EVENT_CALLBACK_PLUGIN_CREATED           0x00000200
STUDIO_EVENT_CALLBACK_PLUGIN_DESTROYED         0x00000400
STUDIO_EVENT_CALLBACK_TIMELINE_MARKER          0x00000800
STUDIO_EVENT_CALLBACK_TIMELINE_BEAT            0x00001000
STUDIO_EVENT_CALLBACK_SOUND_PLAYED             0x00002000
STUDIO_EVENT_CALLBACK_SOUND_STOPPED            0x00004000
STUDIO_EVENT_CALLBACK_REAL_TO_VIRTUAL          0x00008000
STUDIO_EVENT_CALLBACK_VIRTUAL_TO_REAL          0x00010000
STUDIO_EVENT_CALLBACK_START_EVENT_COMMAND      0x00020000
STUDIO_EVENT_CALLBACK_NESTED_TIMELINE_BEAT     0x00040000
STUDIO_EVENT_CALLBACK_ALL                      0xFFFFFFFF
```

## FMOD_STUDIO_EVENT_PROPERTY
kind: example
index: 41
heading: FMOD_STUDIO_EVENT_PROPERTY
tabbed: yes

### C/C++
```cpp
typedef enum FMOD_STUDIO_EVENT_PROPERTY {
  FMOD_STUDIO_EVENT_PROPERTY_CHANNELPRIORITY,
  FMOD_STUDIO_EVENT_PROPERTY_SCHEDULE_DELAY,
  FMOD_STUDIO_EVENT_PROPERTY_SCHEDULE_LOOKAHEAD,
  FMOD_STUDIO_EVENT_PROPERTY_MINIMUM_DISTANCE,
  FMOD_STUDIO_EVENT_PROPERTY_MAXIMUM_DISTANCE,
  FMOD_STUDIO_EVENT_PROPERTY_COOLDOWN,
  FMOD_STUDIO_EVENT_PROPERTY_MAX
} FMOD_STUDIO_EVENT_PROPERTY;
```

### C#
```csharp
enum Studio.EVENT_PROPERTY
{
    CHANNELPRIORITY,
    SCHEDULE_DELAY,
    SCHEDULE_LOOKAHEAD,
    MINIMUM_DISTANCE,
    MAXIMUM_DISTANCE,
    COOLDOWN,
    MAX
};
```

### JavaScript
```javascript
STUDIO_EVENT_PROPERTY_CHANNELPRIORITY
STUDIO_EVENT_PROPERTY_SCHEDULE_DELAY
STUDIO_EVENT_PROPERTY_SCHEDULE_LOOKAHEAD
STUDIO_EVENT_PROPERTY_MINIMUM_DISTANCE
STUDIO_EVENT_PROPERTY_MAXIMUM_DISTANCE
STUDIO_EVENT_PROPERTY_COOLDOWN
STUDIO_EVENT_PROPERTY_MAX
```

## FMOD_STUDIO_PLUGIN_INSTANCE_PROPERTIES
kind: example
index: 42
heading: FMOD_STUDIO_PLUGIN_INSTANCE_PROPERTIES
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_STUDIO_PLUGIN_INSTANCE_PROPERTIES {
  const char   *name;
  FMOD_DSP    *dsp;
} FMOD_STUDIO_PLUGIN_INSTANCE_PROPERTIES;
```

### C#
```csharp
struct Studio.PLUGIN_INSTANCE_PROPERTIES
{
    IntPtr name;
    IntPtr dsp;
}
```

### JavaScript
```javascript
FMOD_STUDIO_PLUGIN_INSTANCE_PROPERTIES
{
  name,
};
```

## FMOD_STUDIO_PROGRAMMER_SOUND_PROPERTIES
kind: example
index: 43
heading: FMOD_STUDIO_PROGRAMMER_SOUND_PROPERTIES
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_STUDIO_PROGRAMMER_SOUND_PROPERTIES {
  const char   *name;
  FMOD_SOUND   *sound;
  int          subsoundIndex;
} FMOD_STUDIO_PROGRAMMER_SOUND_PROPERTIES;
```

### C#
```csharp
struct Studio.PROGRAMMER_SOUND_PROPERTIES
{
    StringWrapper name;
    IntPtr sound;
    int subsoundIndex;
}
```

### JavaScript
```javascript
FMOD_STUDIO_PROGRAMMER_SOUND_PROPERTIES
{
  name,
  sound,
  subsoundIndex,
};
```

## FMOD_STUDIO_STOP_MODE
kind: example
index: 44
heading: FMOD_STUDIO_STOP_MODE
tabbed: yes

### C/C++
```cpp
typedef enum FMOD_STUDIO_STOP_MODE {
  FMOD_STUDIO_STOP_ALLOWFADEOUT,
  FMOD_STUDIO_STOP_IMMEDIATE
} FMOD_STUDIO_STOP_MODE;
```

### C#
```csharp
enum Studio.STOP_MODE
{
    ALLOWFADEOUT,
    IMMEDIATE,
}
```

### JavaScript
```javascript
STUDIO_STOP_ALLOWFADEOUT
STUDIO_STOP_IMMEDIATE
```

## FMOD_STUDIO_TIMELINE_BEAT_PROPERTIES
kind: example
index: 45
heading: FMOD_STUDIO_TIMELINE_BEAT_PROPERTIES
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_STUDIO_TIMELINE_BEAT_PROPERTIES {
  int     bar;
  int     beat;
  int     position;
  float   tempo;
  int     timesignatureupper;
  int     timesignaturelower;
} FMOD_STUDIO_TIMELINE_BEAT_PROPERTIES;
```

### C#
```csharp
struct Studio.TIMELINE_BEAT_PROPERTIES
{
  int bar;
  int beat;
  int position;
  float tempo;
  int timesignatureupper;
  int timesignaturelower;
}
```

### JavaScript
```javascript
FMOD_STUDIO_TIMELINE_BEAT_PROPERTIES
{
  bar,
  beat,
  position,
  tempo,
  timesignatureupper,
  timesignaturelower,
};
```

## FMOD_STUDIO_TIMELINE_MARKER_PROPERTIES
kind: example
index: 46
heading: FMOD_STUDIO_TIMELINE_MARKER_PROPERTIES
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_STUDIO_TIMELINE_MARKER_PROPERTIES {
  const char   *name;
  int          position;
} FMOD_STUDIO_TIMELINE_MARKER_PROPERTIES;
```

### C#
```csharp
struct Studio.TIMELINE_MARKER_PROPERTIES
{
  IntPtr name;
  int position;
}
```

### JavaScript
```javascript
FMOD_STUDIO_TIMELINE_MARKER_PROPERTIES
{
  name,
  position,
};
```

## FMOD_STUDIO_TIMELINE_NESTED_BEAT_PROPERTIES
kind: example
index: 47
heading: FMOD_STUDIO_TIMELINE_NESTED_BEAT_PROPERTIES
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_STUDIO_TIMELINE_NESTED_BEAT_PROPERTIES {
  FMOD_GUID                             eventid;
  FMOD_STUDIO_TIMELINE_BEAT_PROPERTIES  properties;
} FMOD_STUDIO_TIMELINE_NESTED_BEAT_PROPERTIES;
```

### C#
```csharp
struct Studio.TIMELINE_NESTED_BEAT_PROPERTIES
{
  Guid                      eventid;
  TIMELINE_BEAT_PROPERTIES  properties;
}
```

### JavaScript
```javascript
FMOD_STUDIO_TIMELINE_NESTED_BEAT_PROPERTIES
{
  eventid,
  properties,
};
```

