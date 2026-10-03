# studio-api-commandreplay

## FMOD_STUDIO_COMMANDREPLAY_CREATE_INSTANCE_CALLBACK
kind: example
index: 0
heading: FMOD_STUDIO_COMMANDREPLAY_CREATE_INSTANCE_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_STUDIO_COMMANDREPLAY_CREATE_INSTANCE_CALLBACK(
  FMOD_STUDIO_COMMANDREPLAY *replay,
  int commandindex,
  FMOD_STUDIO_EVENTDESCRIPTION *eventdescription,
  FMOD_STUDIO_EVENTINSTANCE **instance,
  void *userdata
);
```

### C#
```csharp
delegate RESULT Studio.COMMANDREPLAY_CREATE_INSTANCE_CALLBACK(
  IntPtr replay,
  int commandindex,
  IntPtr eventdescription,
  out IntPtr instance,
  IntPtr userdata
);
```

## FMOD_STUDIO_COMMANDREPLAY_FRAME_CALLBACK
kind: example
index: 1
heading: FMOD_STUDIO_COMMANDREPLAY_FRAME_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_STUDIO_COMMANDREPLAY_FRAME_CALLBACK(
  FMOD_STUDIO_COMMANDREPLAY *replay,
  int commandindex,
  float currenttime,
  void *userdata
);
```

### C#
```csharp
delegate RESULT Studio.COMMANDREPLAY_FRAME_CALLBACK(
  IntPtr replay,
  int commandindex,
  float currenttime,
  IntPtr userdata
);
```

## studio_commandreplay_getcommandattime
kind: function
index: 2

### C++
```cpp
FMOD_RESULT Studio::CommandReplay::getCommandAtTime(
  float time,
  int *commandindex
);
```

### C
```c
FMOD_RESULT FMOD_Studio_CommandReplay_GetCommandAtTime(
  FMOD_STUDIO_COMMANDREPLAY *commandreplay,
  float time,
  int *commandindex
);
```

### C#
```csharp
RESULT Studio.CommandReplay.getCommandAtTime(
  float time,
  out int commandindex
);
```

### JavaScript
```javascript
Studio.CommandReplay.getCommandAtTime(
  time,
  commandindex
);
```

## studio_commandreplay_getcommandcount
kind: function
index: 3

### C++
```cpp
FMOD_RESULT Studio::CommandReplay::getCommandCount(
  int *count
);
```

### C
```c
FMOD_RESULT FMOD_Studio_CommandReplay_GetCommandCount(
  FMOD_STUDIO_COMMANDREPLAY *commandreplay,
  int *count
);
```

### C#
```csharp
RESULT Studio.CommandReplay.getCommandCount(
  out int count
);
```

### JavaScript
```javascript
Studio.CommandReplay.getCommandCount(
  count
);
```

## studio_commandreplay_getcommandinfo
kind: function
index: 4

### C++
```cpp
FMOD_RESULT Studio::CommandReplay::getCommandInfo(
  int commandindex,
  FMOD_STUDIO_COMMAND_INFO *info
);
```

### C
```c
FMOD_RESULT FMOD_Studio_CommandReplay_GetCommandInfo(
  FMOD_STUDIO_COMMANDREPLAY *commandreplay,
  int commandindex,
  FMOD_STUDIO_COMMAND_INFO *info
);
```

### C#
```csharp
RESULT Studio.CommandReplay.getCommandInfo(
  int commandindex,
  out COMMAND_INFO info
);
```

### JavaScript
```javascript
Studio.CommandReplay.getCommandInfo(
  commandindex,
  info
);
```

## studio_commandreplay_getcommandstring
kind: function
index: 5

### C++
```cpp
FMOD_RESULT Studio::CommandReplay::getCommandString(
  int commandindex,
  char *buffer,
  int length
);
```

### C
```c
FMOD_RESULT FMOD_Studio_CommandReplay_GetCommandString(
  FMOD_STUDIO_COMMANDREPLAY *commandreplay,
  int commandindex,
  char *buffer,
  int length
);
```

### C#
```csharp
RESULT Studio.CommandReplay.getCommandString(
  int commandindex,
  out string buffer
);
```

### JavaScript
```javascript
Studio.CommandReplay.getCommandString(
  commandindex,
  buffer
);
```

## studio_commandreplay_getcurrentcommand
kind: function
index: 6

### C++
```cpp
FMOD_RESULT Studio::CommandReplay::getCurrentCommand(
  int *commandindex,
  float *currenttime
);
```

### C
```c
FMOD_RESULT FMOD_Studio_CommandReplay_GetCurrentCommand(
  FMOD_STUDIO_COMMANDREPLAY *commandreplay,
  int *commandindex,
  float *currenttime
);
```

### C#
```csharp
RESULT Studio.CommandReplay.getCurrentCommand(
  out int commandindex,
  out float currenttime
);
```

### JavaScript
```javascript
Studio.CommandReplay.getCurrentCommand(
  commandindex,
  currenttime
);
```

## studio_commandreplay_getlength
kind: function
index: 7

### C++
```cpp
FMOD_RESULT Studio::CommandReplay::getLength(
  float *length
);
```

### C
```c
FMOD_RESULT FMOD_Studio_CommandReplay_GetLength(
  FMOD_STUDIO_COMMANDREPLAY *commandreplay,
  float *length
);
```

### C#
```csharp
RESULT Studio.CommandReplay.getLength(
  out float length
);
```

### JavaScript
```javascript
Studio.CommandReplay.getLength(
  length
);
```

## studio_commandreplay_getpaused
kind: function
index: 8

### C++
```cpp
FMOD_RESULT Studio::CommandReplay::getPaused(
  bool *paused
);
```

### C
```c
FMOD_RESULT FMOD_Studio_CommandReplay_GetPaused(
  FMOD_STUDIO_COMMANDREPLAY *commandreplay,
  FMOD_BOOL *paused
);
```

### C#
```csharp
RESULT Studio.CommandReplay.getPaused(
  out bool paused
);
```

### JavaScript
```javascript
Studio.CommandReplay.getPaused(
  paused
);
```

## studio_commandreplay_getplaybackstate
kind: function
index: 9

### C++
```cpp
FMOD_RESULT Studio::CommandReplay::getPlaybackState(
  FMOD_STUDIO_PLAYBACK_STATE *state
);
```

### C
```c
FMOD_RESULT FMOD_Studio_CommandReplay_GetPlaybackState(
  FMOD_STUDIO_COMMANDREPLAY *commandreplay,
  FMOD_STUDIO_PLAYBACK_STATE *state
);
```

### C#
```csharp
RESULT Studio.CommandReplay.getPlaybackState(
  out PLAYBACK_STATE state
);
```

### JavaScript
```javascript
Studio.CommandReplay.getPlaybackState(
  state
);
```

## studio_commandreplay_getsystem
kind: function
index: 10

### C++
```cpp
FMOD_RESULT Studio::CommandReplay::getSystem(
  Studio::System **system
);
```

### C
```c
FMOD_RESULT FMOD_Studio_CommandReplay_GetSystem(
  FMOD_STUDIO_COMMANDREPLAY *commandreplay,
  FMOD_STUDIO_SYSTEM **system
);
```

### C#
```csharp
RESULT Studio.CommandReplay.getSystem(
  out System system
);
```

### JavaScript
```javascript
Studio.CommandReplay.getSystem(
  system
);
```

## studio_commandreplay_getuserdata
kind: function
index: 11

### C++
```cpp
FMOD_RESULT Studio::CommandReplay::getUserData(
  void **userdata
);
```

### C
```c
FMOD_RESULT FMOD_Studio_CommandReplay_GetUserData(
  FMOD_STUDIO_COMMANDREPLAY *commandreplay,
  void **userdata
);
```

### C#
```csharp
RESULT Studio.CommandReplay.getUserData(
  out IntPtr userdata
);
```

### JavaScript
```javascript
Studio.CommandReplay.getUserData(
  userdata
);
```

## studio_commandreplay_isvalid
kind: function
index: 12

### C++
```cpp
bool Studio::CommandReplay::isValid()
```

### C
```c
bool FMOD_Studio_CommandReplay_IsValid(FMOD_STUDIO_COMMANDREPLAY *commandreplay)
```

### C#
```csharp
bool Studio.CommandReplay.isValid()
```

### JavaScript
```javascript
Studio.CommandReplay.isValid()
```

## FMOD_STUDIO_COMMANDREPLAY_LOAD_BANK_CALLBACK
kind: example
index: 13
heading: FMOD_STUDIO_COMMANDREPLAY_LOAD_BANK_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_STUDIO_COMMANDREPLAY_LOAD_BANK_CALLBACK(
  FMOD_STUDIO_COMMANDREPLAY *replay,
  int commandindex,
  const FMOD_GUID *bankguid,
  const char *bankfilename,
  FMOD_STUDIO_LOAD_BANK_FLAGS flags,
  FMOD_STUDIO_BANK **bank,
  void *userdata
);
```

### C#
```csharp
delegate RESULT Studio.COMMANDREPLAY_LOAD_BANK_CALLBACK(
  IntPtr replay,
  int commandindex,
  ref Guid bankguid,
  IntPtr bankfilename,
  LOAD_BANK_FLAGS flags,
  out IntPtr bank,
  IntPtr userdata
);
```

## studio_commandreplay_release
kind: function
index: 14

### C++
```cpp
FMOD_RESULT Studio::CommandReplay::release();
```

### C
```c
FMOD_RESULT FMOD_Studio_CommandReplay_Release(FMOD_STUDIO_COMMANDREPLAY *commandreplay);
```

### C#
```csharp
RESULT Studio.CommandReplay.release();
```

### JavaScript
```javascript
Studio.CommandReplay.release();
```

## studio_commandreplay_seektocommand
kind: function
index: 15

### C++
```cpp
FMOD_RESULT Studio::CommandReplay::seekToCommand(
  int commandindex
);
```

### C
```c
FMOD_RESULT FMOD_Studio_CommandReplay_SeekToCommand(
  FMOD_STUDIO_COMMANDREPLAY *commandreplay,
  int commandindex
);
```

### C#
```csharp
RESULT Studio.CommandReplay.seekToCommand(
  int commandindex
);
```

### JavaScript
```javascript
Studio.CommandReplay.seekToCommand(
  commandindex
);
```

## studio_commandreplay_seektotime
kind: function
index: 16

### C++
```cpp
FMOD_RESULT Studio::CommandReplay::seekToTime(
  float time
);
```

### C
```c
FMOD_RESULT FMOD_Studio_CommandReplay_SeekToTime(
  FMOD_STUDIO_COMMANDREPLAY *commandreplay,
  float time
);
```

### C#
```csharp
RESULT Studio.CommandReplay.seekToTime(
  float time
);
```

### JavaScript
```javascript
Studio.CommandReplay.seekToTime(
  time
);
```

## studio_commandreplay_setbankpath
kind: function
index: 17

### C++
```cpp
FMOD_RESULT Studio::CommandReplay::setBankPath(
  const char *bankPath
);
```

### C
```c
FMOD_RESULT FMOD_Studio_CommandReplay_SetBankPath(
  FMOD_STUDIO_COMMANDREPLAY *commandreplay,
  const char *bankPath
);
```

### C#
```csharp
RESULT Studio.CommandReplay.setBankPath(
  string bankPath
);
```

### JavaScript
```javascript
Studio.CommandReplay.setBankPath(
  bankPath
);
```

## studio_commandreplay_setcreateinstancecallback
kind: function
index: 18

### C++
```cpp
FMOD_RESULT Studio::CommandReplay::setCreateInstanceCallback(
  FMOD_STUDIO_COMMANDREPLAY_CREATE_INSTANCE_CALLBACK callback
);
```

### C
```c
FMOD_RESULT FMOD_Studio_CommandReplay_SetCreateInstanceCallback(
  FMOD_STUDIO_COMMANDREPLAY *commandreplay,
  FMOD_STUDIO_COMMANDREPLAY_CREATE_INSTANCE_CALLBACK callback
);
```

### C#
```csharp
RESULT Studio.CommandReplay.setCreateInstanceCallback(
  COMMANDREPLAY_CREATE_INSTANCE_CALLBACK callback
);
```

## studio_commandreplay_setframecallback
kind: function
index: 19

### C++
```cpp
FMOD_RESULT Studio::CommandReplay::setFrameCallback(
  FMOD_STUDIO_COMMANDREPLAY_FRAME_CALLBACK callback
);
```

### C
```c
FMOD_RESULT FMOD_Studio_CommandReplay_SetFrameCallback(
  FMOD_STUDIO_COMMANDREPLAY *commandreplay,
  FMOD_STUDIO_COMMANDREPLAY_FRAME_CALLBACK callback
);
```

### C#
```csharp
RESULT Studio.CommandReplay.setFrameCallback(
  COMMANDREPLAY_FRAME_CALLBACK callback
);
```

## studio_commandreplay_setloadbankcallback
kind: function
index: 20

### C++
```cpp
FMOD_RESULT Studio::CommandReplay::setLoadBankCallback(
  FMOD_STUDIO_COMMANDREPLAY_LOAD_BANK_CALLBACK callback
);
```

### C
```c
FMOD_RESULT FMOD_Studio_CommandReplay_SetLoadBankCallback(
  FMOD_STUDIO_COMMANDREPLAY *commandreplay,
  FMOD_STUDIO_COMMANDREPLAY_LOAD_BANK_CALLBACK callback
);
```

### C#
```csharp
RESULT Studio.CommandReplay.setLoadBankCallback(
  COMMANDREPLAY_LOAD_BANK_CALLBACK callback
);
```

## studio_commandreplay_setpaused
kind: function
index: 21

### C++
```cpp
FMOD_RESULT Studio::CommandReplay::setPaused(
  bool paused
);
```

### C
```c
FMOD_RESULT FMOD_Studio_CommandReplay_SetPaused(
  FMOD_STUDIO_COMMANDREPLAY *commandreplay,
  FMOD_BOOL paused
);
```

### C#
```csharp
RESULT Studio.CommandReplay.setPaused(
  bool paused
);
```

### JavaScript
```javascript
Studio.CommandReplay.setPaused(
  paused
);
```

## studio_commandreplay_setuserdata
kind: function
index: 22

### C++
```cpp
FMOD_RESULT Studio::CommandReplay::setUserData(
  void *userdata
);
```

### C
```c
FMOD_RESULT FMOD_Studio_CommandReplay_SetUserData(
  FMOD_STUDIO_COMMANDREPLAY *commandreplay,
  void *userdata
);
```

### C#
```csharp
RESULT Studio.CommandReplay.setUserData(
  IntPtr userdata
);
```

### JavaScript
```javascript
Studio.CommandReplay.setUserData(
  userdata
);
```

## studio_commandreplay_start
kind: function
index: 23

### C++
```cpp
FMOD_RESULT Studio::CommandReplay::start();
```

### C
```c
FMOD_RESULT FMOD_Studio_CommandReplay_Start(FMOD_STUDIO_COMMANDREPLAY *commandreplay);
```

### C#
```csharp
RESULT Studio.CommandReplay.start();
```

### JavaScript
```javascript
Studio.CommandReplay.start();
```

## studio_commandreplay_stop
kind: function
index: 24

### C++
```cpp
FMOD_RESULT Studio::CommandReplay::stop();
```

### C
```c
FMOD_RESULT FMOD_Studio_CommandReplay_Stop(FMOD_STUDIO_COMMANDREPLAY *commandreplay);
```

### C#
```csharp
RESULT Studio.CommandReplay.stop();
```

### JavaScript
```javascript
Studio.CommandReplay.stop();
```

## FMOD_STUDIO_COMMAND_INFO
kind: example
index: 25
heading: FMOD_STUDIO_COMMAND_INFO
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_STUDIO_COMMAND_INFO {
  const char                *commandname;
  int                        parentcommandindex;
  int                        framenumber;
  float                      frametime;
  FMOD_STUDIO_INSTANCETYPE   instancetype;
  FMOD_STUDIO_INSTANCETYPE   outputtype;
  unsigned int               instancehandle;
  unsigned int               outputhandle;
} FMOD_STUDIO_COMMAND_INFO;
```

### C#
```csharp
struct Studio.COMMAND_INFO
{
    StringWrapper commandname;
    int parentcommandindex;
    int framenumber;
    float frametime;
    INSTANCETYPE instancetype;
    INSTANCETYPE outputtype;
    UInt32 instancehandle;
    UInt32 outputhandle;
}
```

### JavaScript
```javascript
FMOD_STUDIO_COMMAND_INFO
{
  commandname,
  parentcommandindex,
  framenumber,
  frametime,
  instancetype,
  outputtype,
  instancehandle,
  outputhandle,
};
```

## FMOD_STUDIO_INSTANCETYPE
kind: example
index: 26
heading: FMOD_STUDIO_INSTANCETYPE
tabbed: yes

### C/C++
```cpp
typedef enum FMOD_STUDIO_INSTANCETYPE {
  FMOD_STUDIO_INSTANCETYPE_NONE,
  FMOD_STUDIO_INSTANCETYPE_SYSTEM,
  FMOD_STUDIO_INSTANCETYPE_EVENTDESCRIPTION,
  FMOD_STUDIO_INSTANCETYPE_EVENTINSTANCE,
  FMOD_STUDIO_INSTANCETYPE_PARAMETERINSTANCE,
  FMOD_STUDIO_INSTANCETYPE_BUS,
  FMOD_STUDIO_INSTANCETYPE_VCA,
  FMOD_STUDIO_INSTANCETYPE_BANK,
  FMOD_STUDIO_INSTANCETYPE_COMMANDREPLAY
} FMOD_STUDIO_INSTANCETYPE;
```

### C#
```csharp
enum Studio.INSTANCETYPE
{
    NONE,
    SYSTEM,
    EVENTDESCRIPTION,
    EVENTINSTANCE,
    PARAMETERINSTANCE,
    BUS,
    VCA,
    BANK,
    COMMANDREPLAY,
}
```

### JavaScript
```javascript
STUDIO_INSTANCETYPE_NONE
STUDIO_INSTANCETYPE_SYSTEM
STUDIO_INSTANCETYPE_EVENTDESCRIPTION
STUDIO_INSTANCETYPE_EVENTINSTANCE
STUDIO_INSTANCETYPE_PARAMETERINSTANCE
STUDIO_INSTANCETYPE_BUS
STUDIO_INSTANCETYPE_VCA
STUDIO_INSTANCETYPE_BANK
STUDIO_INSTANCETYPE_COMMANDREPLAY
```

