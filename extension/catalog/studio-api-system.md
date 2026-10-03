# studio-api-system

## FMOD_STUDIO_ADVANCEDSETTINGS
kind: example
index: 0
heading: FMOD_STUDIO_ADVANCEDSETTINGS
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_STUDIO_ADVANCEDSETTINGS {
  int            cbsize;
  unsigned int   commandqueuesize;
  unsigned int   handleinitialsize;
  int            studioupdateperiod;
  int            idlesampledatapoolsize;
  unsigned int   streamingscheduledelay;
  const char*    encryptionkey;
} FMOD_STUDIO_ADVANCEDSETTINGS;
```

### C#
```csharp
struct Studio.ADVANCEDSETTINGS
{
  int cbsize;
  int commandqueuesize;
  int handleinitialsize;
  int studioupdateperiod;
  int idlesampledatapoolsize;
  int streamingscheduledelay;
  StringWrapper encryptionkey;
}
```

### JavaScript
```javascript
FMOD_STUDIO_ADVANCEDSETTINGS
{
  commandqueuesize,
  handleinitialsize,
  studioupdateperiod,
  idlesampledatapoolsize,
  streamingscheduledelay;
};
```

## FMOD_STUDIO_BANK_INFO
kind: example
index: 1
heading: FMOD_STUDIO_BANK_INFO
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_STUDIO_BANK_INFO {
  int                        size;
  void                      *userdata;
  int                        userdatalength;
  FMOD_FILE_OPEN_CALLBACK    opencallback;
  FMOD_FILE_CLOSE_CALLBACK   closecallback;
  FMOD_FILE_READ_CALLBACK    readcallback;
  FMOD_FILE_SEEK_CALLBACK    seekcallback;
} FMOD_STUDIO_BANK_INFO;
```

### C#
```csharp
struct Studio.BANK_INFO
{
  int size;
  IntPtr userdata;
  int userdatalength;
  FILE_OPENCALLBACK opencallback;
  FILE_CLOSECALLBACK closecallback;
  FILE_READCALLBACK readcallback;
  FILE_SEEKCALLBACK seekcallback;
}
```

### JavaScript
```javascript
FMOD_STUDIO_BANK_INFO
{
  userdata,
  userdatalength,
  opencallback,
  closecallback,
  readcallback,
  seekcallback,
};
```

## FMOD_STUDIO_BUFFER_INFO
kind: example
index: 2
heading: FMOD_STUDIO_BUFFER_INFO
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_STUDIO_BUFFER_INFO {
  int     currentusage;
  int     peakusage;
  int     capacity;
  int     stallcount;
  float   stalltime;
} FMOD_STUDIO_BUFFER_INFO;
```

### C#
```csharp
struct Studio.BUFFER_INFO
{
    int currentusage;
    int peakusage;
    int capacity;
    int stallcount;
    float stalltime;
}
```

### JavaScript
```javascript
FMOD_STUDIO_BUFFER_INFO
{
  currentusage,
  peakusage,
  capacity,
  stallcount,
  stalltime,
};
```

## FMOD_STUDIO_BUFFER_USAGE
kind: example
index: 3
heading: FMOD_STUDIO_BUFFER_USAGE
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_STUDIO_BUFFER_USAGE {
  FMOD_STUDIO_BUFFER_INFO   studiocommandqueue;
  FMOD_STUDIO_BUFFER_INFO   studiohandle;
} FMOD_STUDIO_BUFFER_USAGE;
```

### C#
```csharp
struct Studio.BUFFER_USAGE
{
  BUFFER_INFO studiocommandqueue;
  BUFFER_INFO studiohandle;
}
```

### JavaScript
```javascript
FMOD_STUDIO_BUFFER_USAGE
{
  studiocommandqueue,
  studiohandle,
};
```

## FMOD_STUDIO_COMMANDCAPTURE_FLAGS
kind: example
index: 4
heading: FMOD_STUDIO_COMMANDCAPTURE_FLAGS
tabbed: yes

### C/C++
```cpp
#define FMOD_STUDIO_COMMANDCAPTURE_NORMAL             0x00000000
#define FMOD_STUDIO_COMMANDCAPTURE_FILEFLUSH          0x00000001
#define FMOD_STUDIO_COMMANDCAPTURE_SKIP_INITIAL_STATE 0x00000002
```

### C#
```csharp
enum Studio.COMMANDCAPTURE_FLAGS : uint
{
    NORMAL             = 0x00000000,
    FILEFLUSH          = 0x00000001,
    SKIP_INITIAL_STATE = 0x00000002,
}
```

### JavaScript
```javascript
STUDIO_COMMANDCAPTURE_NORMAL             0x00000000
STUDIO_COMMANDCAPTURE_FILEFLUSH          0x00000001
STUDIO_COMMANDCAPTURE_SKIP_INITIAL_STATE 0x00000002
```

## FMOD_STUDIO_COMMANDREPLAY_FLAGS
kind: example
index: 5
heading: FMOD_STUDIO_COMMANDREPLAY_FLAGS
tabbed: yes

### C/C++
```cpp
#define FMOD_STUDIO_COMMANDREPLAY_NORMAL         0x00000000
#define FMOD_STUDIO_COMMANDREPLAY_SKIP_CLEANUP   0x00000001
#define FMOD_STUDIO_COMMANDREPLAY_FAST_FORWARD   0x00000002
#define FMOD_STUDIO_COMMANDREPLAY_SKIP_BANK_LOAD 0x00000004
```

### C#
```csharp
enum Studio.COMMANDREPLAY_FLAGS : uint
{
  NORMAL         = 0x00000000,
  SKIP_CLEANUP   = 0x00000001,
  FAST_FORWARD   = 0x00000002,
  SKIP_BANK_LOAD = 0x00000004,
}
```

### JavaScript
```javascript
STUDIO_COMMANDREPLAY_NORMAL         0x00000000
STUDIO_COMMANDREPLAY_SKIP_CLEANUP   0x00000001
STUDIO_COMMANDREPLAY_FAST_FORWARD   0x00000002
STUDIO_COMMANDREPLAY_SKIP_BANK_LOAD 0x00000004
```

## FMOD_STUDIO_CPU_USAGE
kind: example
index: 6
heading: FMOD_STUDIO_CPU_USAGE
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_STUDIO_CPU_USAGE {
  float   update;
} FMOD_STUDIO_CPU_USAGE;
```

### C#
```csharp
struct Studio.CPU_USAGE
{
    float update;
}
```

### JavaScript
```javascript
FMOD_STUDIO_CPU_USAGE
{
  update
};
```

## FMOD_STUDIO_INITFLAGS
kind: example
index: 7
heading: FMOD_STUDIO_INITFLAGS
tabbed: yes

### C/C++
```cpp
#define FMOD_STUDIO_INIT_NORMAL                0x00000000
#define FMOD_STUDIO_INIT_LIVEUPDATE            0x00000001
#define FMOD_STUDIO_INIT_ALLOW_MISSING_PLUGINS 0x00000002
#define FMOD_STUDIO_INIT_SYNCHRONOUS_UPDATE    0x00000004
#define FMOD_STUDIO_INIT_DEFERRED_CALLBACKS    0x00000008
#define FMOD_STUDIO_INIT_LOAD_FROM_UPDATE      0x00000010
#define FMOD_STUDIO_INIT_MEMORY_TRACKING       0x00000020
```

### C#
```csharp
enum Studio.INITFLAGS : uint
{
    NORMAL                = 0x00000000
    LIVEUPDATE            = 0x00000001
    ALLOW_MISSING_PLUGINS = 0x00000002
    SYNCHRONOUS_UPDATE    = 0x00000004
    DEFERRED_CALLBACKS    = 0x00000008
    LOAD_FROM_UPDATE      = 0x00000010
    MEMORY_TRACKING       = 0x00000020
}
```

### JavaScript
```javascript
STUDIO_INIT_NORMAL                0x00000000
STUDIO_INIT_LIVEUPDATE            0x00000001
STUDIO_INIT_ALLOW_MISSING_PLUGINS 0x00000002
STUDIO_INIT_SYNCHRONOUS_UPDATE    0x00000004
STUDIO_INIT_DEFERRED_CALLBACKS    0x00000008
STUDIO_INIT_LOAD_FROM_UPDATE      0x00000010
STUDIO_INIT_MEMORY_TRACKING       0x00000020
```

## FMOD_STUDIO_LOAD_BANK_FLAGS
kind: example
index: 8
heading: FMOD_STUDIO_LOAD_BANK_FLAGS
tabbed: yes

### C/C++
```cpp
#define FMOD_STUDIO_LOAD_BANK_NORMAL             0x00000000
#define FMOD_STUDIO_LOAD_BANK_NONBLOCKING        0x00000001
#define FMOD_STUDIO_LOAD_BANK_DECOMPRESS_SAMPLES 0x00000002
#define FMOD_STUDIO_LOAD_BANK_UNENCRYPTED        0x00000004
```

### C#
```csharp
enum Studio.LOAD_BANK_FLAGS : uint
{
    NORMAL             = 0x00000000,
    NONBLOCKING        = 0x00000001,
    DECOMPRESS_SAMPLES = 0x00000002,
    UNENCRYPTED        = 0x00000004,
}
```

### JavaScript
```javascript
STUDIO_LOAD_BANK_NORMAL             0x00000000
STUDIO_LOAD_BANK_NONBLOCKING        0x00000001
STUDIO_LOAD_BANK_DECOMPRESS_SAMPLES 0x00000002
STUDIO_LOAD_BANK_UNENCRYPTED        0x00000004
```

## FMOD_STUDIO_LOAD_MEMORY_ALIGNMENT
kind: example
index: 9
heading: FMOD_STUDIO_LOAD_MEMORY_ALIGNMENT
tabbed: yes

### C/C++
```cpp
#define FMOD_STUDIO_LOAD_MEMORY_ALIGNMENT   32
```

## FMOD_STUDIO_LOAD_MEMORY_MODE
kind: example
index: 10
heading: FMOD_STUDIO_LOAD_MEMORY_MODE
tabbed: yes

### C/C++
```cpp
typedef enum FMOD_STUDIO_LOAD_MEMORY_MODE {
  FMOD_STUDIO_LOAD_MEMORY,
  FMOD_STUDIO_LOAD_MEMORY_POINT
} FMOD_STUDIO_LOAD_MEMORY_MODE;
```

## FMOD_STUDIO_LOAD_MEMORY_MODE#2
kind: example
index: 11
heading: FMOD_STUDIO_LOAD_MEMORY_MODE

### JavaScript
```javascript
STUDIO_LOAD_MEMORY       0
STUDIO_LOAD_MEMORY_POINT 1
```

## FMOD_STUDIO_SOUND_INFO
kind: example
index: 12
heading: FMOD_STUDIO_SOUND_INFO
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_STUDIO_SOUND_INFO {
  const char              *name_or_data;
  FMOD_MODE                mode;
  FMOD_CREATESOUNDEXINFO   exinfo;
  int                      subsoundindex;
} FMOD_STUDIO_SOUND_INFO;
```

### C#
```csharp
class Studio.SOUND_INFO
{
  byte[] name_or_data;
  MODE mode;
  CREATESOUNDEXINFO exinfo;
  int subsoundindex;
  string name { get; }
}
```

### JavaScript
```javascript
FMOD_STUDIO_SOUND_INFO
{
  name_or_data,
  mode,
  exinfo,
  subsoundindex,
};
```

## FMOD_STUDIO_SYSTEM_CALLBACK
kind: example
index: 13
heading: FMOD_STUDIO_SYSTEM_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_STUDIO_SYSTEM_CALLBACK(
  FMOD_STUDIO_SYSTEM *system,
  FMOD_STUDIO_SYSTEM_CALLBACK_TYPE type,
  void *commanddata,
  void *userdata
);
```

### C#
```csharp
delegate RESULT Studio.SYSTEM_CALLBACK(
  IntPtr system,
  SYSTEM_CALLBACK_TYPE type,
  IntPtr commanddata,
  IntPtr userdata
);
```

### JavaScript
```javascript
function FMOD_STUDIO_SYSTEM_CALLBACK(
  system,
  type,
  commanddata,
  userdata
)
```

## FMOD_STUDIO_SYSTEM_CALLBACK_TYPE
kind: example
index: 14
heading: FMOD_STUDIO_SYSTEM_CALLBACK_TYPE
tabbed: yes

### C/C++
```cpp
#define FMOD_STUDIO_SYSTEM_CALLBACK_PREUPDATE               0x00000001
#define FMOD_STUDIO_SYSTEM_CALLBACK_POSTUPDATE              0x00000002
#define FMOD_STUDIO_SYSTEM_CALLBACK_BANK_UNLOAD             0x00000004
#define FMOD_STUDIO_SYSTEM_CALLBACK_LIVEUPDATE_CONNECTED    0x00000008
#define FMOD_STUDIO_SYSTEM_CALLBACK_LIVEUPDATE_DISCONNECTED 0x00000010
#define FMOD_STUDIO_SYSTEM_CALLBACK_ALL                     0xFFFFFFFF
```

### C#
```csharp
enum Studio.SYSTEM_CALLBACK_TYPE : uint
{
    PREUPDATE               = 0x00000001,
    POSTUPDATE              = 0x00000002,
    BANK_UNLOAD             = 0x00000004,
    LIVEUPDATE_CONNECTED    = 0x00000008,
    LIVEUPDATE_DISCONNECTED = 0x00000010,
    ALL                     = 0xFFFFFFFF,
}
```

### JavaScript
```javascript
STUDIO_SYSTEM_CALLBACK_PREUPDATE                0x00000001
STUDIO_SYSTEM_CALLBACK_POSTUPDATE               0x00000002
STUDIO_SYSTEM_CALLBACK_BANK_UNLOAD              0x00000004
STUDIO_SYSTEM_CALLBACK_LIVEUPDATE_CONNECTED     0x00000008
STUDIO_SYSTEM_CALLBACK_LIVEUPDATE_DISCONNECTED  0x00000010
STUDIO_SYSTEM_CALLBACK_ALL                      0xFFFFFFFF
```

## studio_system_create
kind: function
index: 15

### C++
```cpp
static FMOD_RESULT Studio::System::create(
  Studio::System **system,
  unsigned int headerversion = FMOD_VERSION
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_Create(
  FMOD_STUDIO_SYSTEM **system,
  unsigned int headerversion
);
```

### C#
```csharp
static RESULT Studio.System.create(
  out System system
);
```

### JavaScript
```javascript
static Studio_System_Create(
  system
);
```

## studio_system_flushcommands
kind: function
index: 16

### C++
```cpp
FMOD_RESULT Studio::System::flushCommands();
```

### C
```c
FMOD_RESULT FMOD_Studio_System_FlushCommands(FMOD_STUDIO_SYSTEM *system);
```

### C#
```csharp
RESULT Studio.System.flushCommands();
```

### JavaScript
```javascript
Studio.System.flushCommands();
```

## studio_system_flushsampleloading
kind: function
index: 17

### C++
```cpp
FMOD_RESULT Studio::System::flushSampleLoading();
```

### C
```c
FMOD_RESULT FMOD_Studio_System_FlushSampleLoading(FMOD_STUDIO_SYSTEM *system);
```

### C#
```csharp
RESULT Studio.System.flushSampleLoading();
```

### JavaScript
```javascript
Studio.System.flushSampleLoading();
```

## studio_system_getadvancedsettings
kind: function
index: 18

### C++
```cpp
FMOD_RESULT Studio::System::getAdvancedSettings(
  FMOD_STUDIO_ADVANCEDSETTINGS *settings
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_GetAdvancedSettings(
  FMOD_STUDIO_SYSTEM *system,
  FMOD_STUDIO_ADVANCEDSETTINGS *settings
);
```

### C#
```csharp
RESULT Studio.System.getAdvancedSettings(
  out ADVANCEDSETTINGS settings
);
```

### JavaScript
```javascript
Studio.System.getAdvancedSettings(
  settings
);
```

## studio_system_getbank
kind: function
index: 19

### C++
```cpp
FMOD_RESULT Studio::System::getBank(
  const char *path,
  Studio::Bank **bank
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_GetBank(
  FMOD_STUDIO_SYSTEM *system,
  const char *path,
  FMOD_STUDIO_BANK **bank
);
```

### C#
```csharp
RESULT Studio.System.getBank(
  string path,
  out Bank bank
);
```

### JavaScript
```javascript
Studio.System.getBank(
  path,
  bank
);
```

## studio_system_getbankbyid
kind: function
index: 20

### C++
```cpp
FMOD_RESULT Studio::System::getBankByID(
  const FMOD_GUID *id,
  Studio::Bank **bank
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_GetBankByID(
  FMOD_STUDIO_SYSTEM *system,
  const FMOD_GUID *id,
  FMOD_STUDIO_BANK **bank
);
```

### C#
```csharp
RESULT Studio.System.getBankByID(
  Guid id,
  out Bank bank
);
```

### JavaScript
```javascript
Studio.System.getBankByID(
  id,
  bank
);
```

## studio_system_getbankcount
kind: function
index: 21

### C++
```cpp
FMOD_RESULT Studio::System::getBankCount(
  int *count
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_GetBankCount(
  FMOD_STUDIO_SYSTEM *system,
  int *count
);
```

### C#
```csharp
RESULT Studio.System.getBankCount(
  out int count
);
```

### JavaScript
```javascript
Studio.System.getBankCount(
  count
);
```

## studio_system_getbanklist
kind: function
index: 22

### C++
```cpp
FMOD_RESULT Studio::System::getBankList(
  Studio::Bank **array,
  int capacity,
  int *count
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_GetBankList(
  FMOD_STUDIO_SYSTEM *system,
  FMOD_STUDIO_BANK **array,
  int capacity,
  int *count
);
```

### C#
```csharp
RESULT Studio.System.getBankList(
  out Bank[] array
);
```

### JavaScript
```javascript
Studio.System.getBankList(
  array,
  capacity,
  count
);
```

## studio_system_getbufferusage
kind: function
index: 23

### C++
```cpp
FMOD_RESULT Studio::System::getBufferUsage(
  FMOD_STUDIO_BUFFER_USAGE *usage
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_GetBufferUsage(
  FMOD_STUDIO_SYSTEM *system,
  FMOD_STUDIO_BUFFER_USAGE *usage
);
```

### C#
```csharp
RESULT Studio.System.getBufferUsage(
  out BUFFER_USAGE usage
);
```

### JavaScript
```javascript
Studio.System.getBufferUsage(
  usage
);
```

## studio_system_getbus
kind: function
index: 24

### C++
```cpp
FMOD_RESULT Studio::System::getBus(
  const char *path,
  Studio::Bus **bus
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_GetBus(
  FMOD_STUDIO_SYSTEM *system,
  const char *path,
  FMOD_STUDIO_BUS **bus
);
```

### C#
```csharp
RESULT Studio.System.getBus(
  string path,
  out Bus bus
);
```

### JavaScript
```javascript
Studio.System.getBus(
  path,
  bus
);
```

## studio_system_getbusbyid
kind: function
index: 25

### C++
```cpp
FMOD_RESULT Studio::System::getBusByID(
  const FMOD_GUID *id,
  Studio::Bus **bus
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_GetBusByID(
  FMOD_STUDIO_SYSTEM *system,
  const FMOD_GUID *id,
  FMOD_STUDIO_BUS **bus
);
```

### C#
```csharp
RESULT Studio.System.getBusByID(
  Guid id,
  out Bus bus
);
```

### JavaScript
```javascript
Studio.System.getBusByID(
  id,
  bus
);
```

## studio_system_getcoresystem
kind: function
index: 26

### C++
```cpp
FMOD_RESULT Studio::System::getCoreSystem(
  System **system
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_GetCoreSystem(
  FMOD_STUDIO_SYSTEM *system,
  FMOD_SYSTEM **system
);
```

### C#
```csharp
RESULT Studio.System.getCoreSystem(
  out FMOD.System system
);
```

### JavaScript
```javascript
Studio.System.getCoreSystem(
  system
);
```

## studio_system_getcpuusage
kind: function
index: 27

### C++
```cpp
FMOD_RESULT Studio::System::getCPUUsage(
  FMOD_STUDIO_CPU_USAGE *usage,
  FMOD_CPU_USAGE *usage_core
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_GetCPUUsage(
  FMOD_STUDIO_SYSTEM *system,
  FMOD_STUDIO_CPU_USAGE *usage,
  FMOD_CPU_USAGE *usage_core
);
```

### C#
```csharp
RESULT Studio.System.getCPUUsage(
  out CPU_USAGE usage,
  out FMOD.CPU_USAGE usage_core
);
```

### JavaScript
```javascript
Studio.System.getCPUUsage(
  usage,
  usage_core
);
```

## studio_system_getevent
kind: function
index: 28

### C++
```cpp
FMOD_RESULT Studio::System::getEvent(
  const char *path,
  Studio::EventDescription **event
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_GetEvent(
  FMOD_STUDIO_SYSTEM *system,
  const char *path,
  FMOD_STUDIO_EVENTDESCRIPTION **event
);
```

### C#
```csharp
RESULT Studio.System.getEvent(
  string path,
  out EventDescription _event
);
```

### JavaScript
```javascript
Studio.System.getEvent(
  path,
  event
);
```

## studio_system_geteventbyid
kind: function
index: 29

### C++
```cpp
FMOD_RESULT Studio::System::getEventByID(
  const FMOD_GUID *id,
  Studio::EventDescription **event
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_GetEventByID(
  FMOD_STUDIO_SYSTEM *system,
  const FMOD_GUID *id,
  FMOD_STUDIO_EVENTDESCRIPTION **event
);
```

### C#
```csharp
RESULT Studio.System.getEventByID(
  Guid id,
  out EventDescription _event
);
```

### JavaScript
```javascript
Studio.System.getEventByID(
  id,
  event
);
```

## studio_system_getlistenerattributes
kind: function
index: 30

### C++
```cpp
FMOD_RESULT Studio::System::getListenerAttributes(
  int listener,
  FMOD_3D_ATTRIBUTES *attributes,
  FMOD_VECTOR *attenuationposition = nullptr
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_GetListenerAttributes(
  FMOD_STUDIO_SYSTEM *system,
  int listener,
  FMOD_3D_ATTRIBUTES *attributes,
  FMOD_VECTOR *attenuationposition
);
```

### C#
```csharp
RESULT Studio.System.getListenerAttributes(
  int listener,
  out _3D_ATTRIBUTES attributes
);
RESULT Studio.System.getListenerAttributes(
  int listener,
  out _3D_ATTRIBUTES attributes,
  out VECTOR attenuationposition
);
```

### JavaScript
```javascript
Studio.System.getListenerAttributes(
  listener,
  attributes,
  attenuationposition
);
```

## studio_system_getlistenerweight
kind: function
index: 31

### C++
```cpp
FMOD_RESULT Studio::System::getListenerWeight(
  int listener,
  float *weight
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_GetListenerWeight(
  FMOD_STUDIO_SYSTEM *system,
  int listener,
  float *weight
);
```

### C#
```csharp
RESULT Studio.System.getListenerWeight(
  int listener,
  out float weight
);
```

### JavaScript
```javascript
Studio.System.getListenerWeight(
  listener,
  weight
);
```

## studio_system_getmemoryusage
kind: function
index: 32

### C++
```cpp
FMOD_RESULT Studio::System::getMemoryUsage(
  FMOD_STUDIO_MEMORY_USAGE *memoryusage
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_GetMemoryUsage(
  FMOD_STUDIO_SYSTEM *system,
  FMOD_STUDIO_MEMORY_USAGE *memoryusage
);
```

### C#
```csharp
RESULT Studio.System.getMemoryUsage(
  out MEMORY_USAGE memoryusage
);
```

## studio_system_getnumlisteners
kind: function
index: 33

### C++
```cpp
FMOD_RESULT Studio::System::getNumListeners(
  int *numlisteners
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_GetNumListeners(
  FMOD_STUDIO_SYSTEM *system,
  int *numlisteners
);
```

### C#
```csharp
RESULT Studio.System.getNumListeners(
  out int numlisteners
);
```

### JavaScript
```javascript
Studio.System.getNumListeners(
  numlisteners
);
```

## studio_system_getparameterbyid
kind: function
index: 34

### C++
```cpp
FMOD_RESULT Studio::System::getParameterByID(
  FMOD_STUDIO_PARAMETER_ID id,
  float *value,
  float *finalvalue = nullptr
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_GetParameterByID(
  FMOD_STUDIO_SYSTEM *system,
  FMOD_STUDIO_PARAMETER_ID id,
  float *value,
  float *finalvalue
);
```

### C#
```csharp
RESULT Studio.System.getParameterByID(
  PARAMETER_ID id,
  out float value
);
RESULT Studio.System.getParameterByID(
  PARAMETER_ID id,
  out float value,
  out float finalvalue
);
```

### JavaScript
```javascript
Studio.System.getParameterByID(
  id,
  value,
  finalvalue
);
```

## studio_system_getparameterbyname
kind: function
index: 35

### C++
```cpp
FMOD_RESULT Studio::System::getParameterByName(
  const char *name,
  float *value,
  float *finalvalue = nullptr
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_GetParameterByName(
  FMOD_STUDIO_SYSTEM *system,
  const char *name,
  float *value,
  float *finalvalue
);
```

### C#
```csharp
RESULT Studio.System.getParameterByName(
  string name,
  out float value
);
RESULT Studio.System.getParameterByName(
  string name,
  out float value,
  out float finalvalue
);
```

### JavaScript
```javascript
Studio.System.getParameterByName(
  name,
  value,
  finalvalue
);
```

## studio_system_getparameterdescriptionbyid
kind: function
index: 36

### C++
```cpp
FMOD_RESULT Studio::System::getParameterDescriptionByID(
  FMOD_STUDIO_PARAMETER_ID id,
  FMOD_STUDIO_PARAMETER_DESCRIPTION *parameter
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_GetParameterDescriptionByID(
  FMOD_STUDIO_SYSTEM *system,
  FMOD_STUDIO_PARAMETER_ID id,
  FMOD_STUDIO_PARAMETER_DESCRIPTION *parameter
);
```

### C#
```csharp
RESULT Studio.System.getParameterDescriptionByID(
  PARAMETER_ID id,
  out PARAMETER_DESCRIPTION parameter
);
```

### JavaScript
```javascript
Studio.System.getParameterDescriptionByID(
  id,
  parameter
);
```

## studio_system_getparameterdescriptionbyname
kind: function
index: 37

### C++
```cpp
FMOD_RESULT Studio::System::getParameterDescriptionByName(
  const char *name,
  FMOD_STUDIO_PARAMETER_DESCRIPTION *parameter
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_GetParameterDescriptionByName(
  FMOD_STUDIO_SYSTEM *system,
  const char *name,
  FMOD_STUDIO_PARAMETER_DESCRIPTION *parameter
);
```

### C#
```csharp
RESULT Studio.System.getParameterDescriptionByName(
  string name,
  out PARAMETER_DESCRIPTION parameter
);
```

### JavaScript
```javascript
Studio.System.getParameterDescriptionByName(
  name,
  parameter
);
```

## studio_system_getparameterdescriptioncount
kind: function
index: 38

### C++
```cpp
FMOD_RESULT Studio::System::getParameterDescriptionCount(
  int *count
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_GetParameterDescriptionCount(
  FMOD_STUDIO_SYSTEM *system,
  int *count
);
```

### C#
```csharp
RESULT Studio.System.getParameterDescriptionCount(
  out int count
);
```

### JavaScript
```javascript
Studio.System.getParameterDescriptionCount(
  count
);
```

## studio_system_getparameterdescriptionlist
kind: function
index: 39

### C++
```cpp
FMOD_RESULT Studio::System::getParameterDescriptionList(
  FMOD_STUDIO_PARAMETER_DESCRIPTION *array,
  int capacity,
  int *count
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_GetParameterDescriptionList(
  FMOD_STUDIO_SYSTEM *system,
  FMOD_STUDIO_PARAMETER_DESCRIPTION *array,
  int capacity,
  int *count
);
```

### C#
```csharp
RESULT Studio.System.getParameterDescriptionList(
  out PARAMETER_DESCRIPTION[] array
);
```

### JavaScript
```javascript
Studio.System.getParameterDescriptionList(
  array,
  capacity,
  count
);
```

## studio_system_getparameterlabelbyid
kind: function
index: 40

### C++
```cpp
FMOD_RESULT Studio::System::getParameterLabelByID(
  FMOD_STUDIO_PARAMETER_ID id,
  int labelindex,
  char *label,
  int size,
  int *retrieved
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_GetParameterLabelByID(
  FMOD_STUDIO_SYSTEM *system,
  FMOD_STUDIO_PARAMETER_ID id,
  int labelindex,
  char *label,
  int size,
  int *retrieved
);
```

### C#
```csharp
RESULT Studio.System.getParameterLabelByID(
  PARAMETER_ID id,
  int labelindex,
  out string label
);
```

### JavaScript
```javascript
Studio.System.getParameterLabelByID(
  id,
  labelindex,
  label,
  size,
  retrieved
);
```

## studio_system_getparameterlabelbyname
kind: function
index: 41

### C++
```cpp
FMOD_RESULT Studio::System::getParameterLabelByName(
  const char *name,
  int labelindex,
  char *label,
  int size,
  int *retrieved
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_GetParameterLabelByName(
  FMOD_STUDIO_SYSTEM *system,
  const char *name,
  int labelindex,
  char *label,
  int size,
  int *retrieved
);
```

### C#
```csharp
RESULT Studio.System.getParameterLabelByName(
  string name,
  int labelindex,
  out string label
);
```

### JavaScript
```javascript
Studio.System.getParameterLabelByName(
  name,
  labelindex,
  label,
  size,
  retrieved
);
```

## studio_system_getsoundinfo
kind: function
index: 42

### C++
```cpp
FMOD_RESULT Studio::System::getSoundInfo(
  const char *key,
  FMOD_STUDIO_SOUND_INFO *info
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_GetSoundInfo(
  FMOD_STUDIO_SYSTEM *system,
  const char *key,
  FMOD_STUDIO_SOUND_INFO *info
);
```

### C#
```csharp
RESULT Studio.System.getSoundInfo(
  string key,
  out SOUND_INFO info
);
```

### JavaScript
```javascript
Studio.System.getSoundInfo(
  key,
  info
);
```

## studio_system_getuserdata
kind: function
index: 43

### C++
```cpp
FMOD_RESULT Studio::System::getUserData(
  void **userdata
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_GetUserData(
  FMOD_STUDIO_SYSTEM *system,
  void **userdata
);
```

### C#
```csharp
RESULT Studio.System.getUserData(
  out IntPtr userdata
);
```

### JavaScript
```javascript
Studio.System.getUserData(
  userdata
);
```

## studio_system_getvca
kind: function
index: 44

### C++
```cpp
FMOD_RESULT Studio::System::getVCA(
  const char *path,
  Studio::VCA **vca
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_GetVCA(
  FMOD_STUDIO_SYSTEM *system,
  const char *path,
  FMOD_STUDIO_VCA **vca
);
```

### C#
```csharp
RESULT Studio.System.getVCA(
  string path,
  out VCA vca
);
```

### JavaScript
```javascript
Studio.System.getVCA(
  path,
  vca
);
```

## studio_system_getvcabyid
kind: function
index: 45

### C++
```cpp
FMOD_RESULT Studio::System::getVCAByID(
  const FMOD_GUID *id,
  Studio::VCA **vca
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_GetVCAByID(
  FMOD_STUDIO_SYSTEM *system,
  const FMOD_GUID *id,
  FMOD_STUDIO_VCA **vca
);
```

### C#
```csharp
RESULT Studio.System.getVCAByID(
  Guid id,
  out VCA vca
);
```

### JavaScript
```javascript
Studio.System.getVCAByID(
  id,
  vca
);
```

## studio_system_initialize
kind: function
index: 46

### C++
```cpp
FMOD_RESULT Studio::System::initialize(
  int maxchannels,
  FMOD_STUDIO_INITFLAGS studioflags,
  FMOD_INITFLAGS flags,
  void *extradriverdata
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_Initialize(
  FMOD_STUDIO_SYSTEM *system,
  int maxchannels,
  FMOD_STUDIO_INITFLAGS studioflags,
  FMOD_INITFLAGS flags,
  void *extradriverdata
);
```

### C#
```csharp
RESULT Studio.System.initialize(
  int maxchannels,
  INITFLAGS studioflags,
  FMOD.INITFLAGS flags,
  IntPtr extradriverdata
);
```

### JavaScript
```javascript
Studio.System.initialize(
  maxchannels,
  studioflags,
  flags,
  extradriverdata
);
```

## studio_system_isvalid
kind: function
index: 47

### C++
```cpp
bool Studio::System::isValid()
```

### C
```c
bool FMOD_Studio_System_IsValid(FMOD_STUDIO_SYSTEM *system)
```

### C#
```csharp
bool Studio.System.isValid()
```

### JavaScript
```javascript
Studio.System.isValid()
```

## studio_system_loadbankcustom
kind: function
index: 48

### C++
```cpp
FMOD_RESULT Studio::System::loadBankCustom(
  const FMOD_STUDIO_BANK_INFO *info,
  FMOD_STUDIO_LOAD_BANK_FLAGS flags,
  Studio::Bank **bank
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_LoadBankCustom(
  FMOD_STUDIO_SYSTEM *system,
  const FMOD_STUDIO_BANK_INFO *info,
  FMOD_STUDIO_LOAD_BANK_FLAGS flags,
  FMOD_STUDIO_BANK **bank
);
```

### C#
```csharp
RESULT Studio.System.loadBankCustom(
  BANK_INFO info,
  LOAD_BANK_FLAGS flags,
  out Bank bank
);
```

### JavaScript
```javascript
Studio.System.loadBankCustom(
  info,
  flags,
  bank
);
```

## studio_system_loadbankfile
kind: function
index: 49

### C++
```cpp
FMOD_RESULT Studio::System::loadBankFile(
  const char *filename,
  FMOD_STUDIO_LOAD_BANK_FLAGS flags,
  Studio::Bank **bank
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_LoadBankFile(
  FMOD_STUDIO_SYSTEM *system,
  const char *filename,
  FMOD_STUDIO_LOAD_BANK_FLAGS flags,
  FMOD_STUDIO_BANK **bank
);
```

### C#
```csharp
RESULT Studio.System.loadBankFile(
  string filename,
  LOAD_BANK_FLAGS flags,
  out Bank bank
);
```

### JavaScript
```javascript
Studio.System.loadBankFile(
  filename,
  flags,
  bank
);
```

## studio_system_loadbankmemory
kind: function
index: 50

### C++
```cpp
FMOD_RESULT Studio::System::loadBankMemory(
  const char *buffer,
  int length,
  FMOD_STUDIO_LOAD_MEMORY_MODE mode,
  FMOD_STUDIO_LOAD_BANK_FLAGS flags,
  Studio::Bank **bank
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_LoadBankMemory(
  FMOD_STUDIO_SYSTEM *system,
  const char *buffer,
  int length,
  FMOD_STUDIO_LOAD_MEMORY_MODE mode,
  FMOD_STUDIO_LOAD_BANK_FLAGS flags,
  FMOD_STUDIO_BANK **bank
);
```

### C#
```csharp
RESULT Studio.System.loadBankMemory(
  byte[] buffer,
  LOAD_BANK_FLAGS flags,
  out Bank bank
);
```

### JavaScript
```javascript
Studio.System.loadBankMemory(
  buffer,
  length,
  mode,
  flags,
  bank
);
```

## studio_system_loadcommandreplay
kind: function
index: 51

### C++
```cpp
FMOD_RESULT Studio::System::loadCommandReplay(
  const char *filename,
  FMOD_STUDIO_COMMANDREPLAY_FLAGS flags,
  Studio::CommandReplay **replay
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_LoadCommandReplay(
  FMOD_STUDIO_SYSTEM *system,
  const char *filename,
  FMOD_STUDIO_COMMANDREPLAY_FLAGS flags,
  FMOD_STUDIO_COMMANDREPLAY **replay
);
```

### C#
```csharp
RESULT Studio.System.loadCommandReplay(
  string filename,
  COMMANDREPLAY_FLAGS flags,
  out Studio.CommandReplay replay
);
```

### JavaScript
```javascript
Studio.System.loadCommandReplay(
  filename,
  flags,
  replay
);
```

## studio_system_lookupid
kind: function
index: 52

### C++
```cpp
FMOD_RESULT Studio::System::lookupID(
  const char *path,
  FMOD_GUID *id
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_LookupID(
  FMOD_STUDIO_SYSTEM *system,
  const char *path,
  FMOD_GUID *id
);
```

### C#
```csharp
RESULT Studio.System.lookupID(
  string path,
  out Guid id
);
```

### JavaScript
```javascript
Studio.System.lookupID(
  path,
  id
);
```

## studio_system_lookuppath
kind: function
index: 53

### C++
```cpp
FMOD_RESULT Studio::System::lookupPath(
  const FMOD_GUID *id,
  char *path,
  int size,
  int *retrieved
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_LookupPath(
  FMOD_STUDIO_SYSTEM *system,
  const FMOD_GUID *id,
  char *path,
  int size,
  int *retrieved
);
```

### C#
```csharp
RESULT Studio.System.lookupPath(
  Guid id,
  out string path
);
```

### JavaScript
```javascript
Studio.System.lookupPath(
  id,
  path,
  size,
  retrieved
);
```

## studio_system_registerplugin
kind: function
index: 54

### C++
```cpp
FMOD_RESULT Studio::System::registerPlugin(
  const FMOD_DSP_DESCRIPTION *description
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_RegisterPlugin(
  FMOD_STUDIO_SYSTEM *system,
  const FMOD_DSP_DESCRIPTION *description
);
```

### JavaScript
```javascript
Studio.System.registerPlugin(
  description
);
```

## studio_system_release
kind: function
index: 55

### C++
```cpp
FMOD_RESULT Studio::System::release();
```

### C
```c
FMOD_RESULT FMOD_Studio_System_Release(FMOD_STUDIO_SYSTEM *system);
```

### C#
```csharp
RESULT Studio.System.release();
```

### JavaScript
```javascript
Studio.System.release();
```

## studio_system_resetbufferusage
kind: function
index: 56

### C++
```cpp
FMOD_RESULT Studio::System::resetBufferUsage();
```

### C
```c
FMOD_RESULT FMOD_Studio_System_ResetBufferUsage(FMOD_STUDIO_SYSTEM *system);
```

### C#
```csharp
RESULT Studio.System.resetBufferUsage();
```

### JavaScript
```javascript
Studio.System.resetBufferUsage();
```

## studio_system_setadvancedsettings
kind: function
index: 57

### C++
```cpp
FMOD_RESULT Studio::System::setAdvancedSettings(
  FMOD_STUDIO_ADVANCEDSETTINGS *settings
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_SetAdvancedSettings(
  FMOD_STUDIO_SYSTEM *system,
  FMOD_STUDIO_ADVANCEDSETTINGS *settings
);
```

### C#
```csharp
RESULT Studio.System.setAdvancedSettings(
  ADVANCEDSETTINGS settings
);

RESULT Studio.System.setAdvancedSettings(
  ADVANCEDSETTINGS settings,
  String encryptionkey
);
```

### JavaScript
```javascript
Studio.System.setAdvancedSettings(
  settings
);
```

## studio_system_setcallback
kind: function
index: 58

### C++
```cpp
FMOD_RESULT Studio::System::setCallback(
  FMOD_STUDIO_SYSTEM_CALLBACK callback,
  FMOD_STUDIO_SYSTEM_CALLBACK_TYPE callbackmask = FMOD_STUDIO_SYSTEM_CALLBACK_ALL
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_SetCallback(
  FMOD_STUDIO_SYSTEM *system,
  FMOD_STUDIO_SYSTEM_CALLBACK callback,
  FMOD_STUDIO_SYSTEM_CALLBACK_TYPE callbackmask
);
```

### C#
```csharp
RESULT Studio.System.setCallback(
  SYSTEM_CALLBACK callback,
  SYSTEM_CALLBACK_TYPE callbackmask = SYSTEM_CALLBACK_TYPE.ALL
);
```

### JavaScript
```javascript
Studio.System.setCallback(
  callback,
  callbackmask
);
```

## studio_system_setlistenerattributes
kind: function
index: 59

### C++
```cpp
FMOD_RESULT Studio::System::setListenerAttributes(
  int listener,
  const FMOD_3D_ATTRIBUTES *attributes,
  const FMOD_VECTOR *attenuationposition = nullptr
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_SetListenerAttributes(
  FMOD_STUDIO_SYSTEM *system,
  int listener,
  const FMOD_3D_ATTRIBUTES *attributes,
  const FMOD_VECTOR *attenuationposition
);
```

### C#
```csharp
RESULT Studio.System.setListenerAttributes(
  int listener,
  _3D_ATTRIBUTES attributes
);
RESULT Studio.System.setListenerAttributes(
  int listener,
  _3D_ATTRIBUTES attributes,
  VECTOR attenuationposition
);
```

### JavaScript
```javascript
Studio.System.setListenerAttributes(
  listener,
  attributes,
  attenuationposition
);
```

## studio_system_setlistenerweight
kind: function
index: 60

### C++
```cpp
FMOD_RESULT Studio::System::setListenerWeight(
  int listener,
  float weight
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_SetListenerWeight(
  FMOD_STUDIO_SYSTEM *system,
  int listener,
  float weight
);
```

### C#
```csharp
RESULT Studio.System.setListenerWeight(
  int listener,
  float weight
);
```

### JavaScript
```javascript
Studio.System.setListenerWeight(
  listener,
  weight
);
```

## studio_system_setnumlisteners
kind: function
index: 61

### C++
```cpp
FMOD_RESULT Studio::System::setNumListeners(
  int numlisteners
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_SetNumListeners(
  FMOD_STUDIO_SYSTEM *system,
  int numlisteners
);
```

### C#
```csharp
RESULT Studio.System.setNumListeners(
  int numlisteners
);
```

### JavaScript
```javascript
Studio.System.setNumListeners(
  numlisteners
);
```

## studio_system_setparameterbyid
kind: function
index: 62

### C++
```cpp
FMOD_RESULT Studio::System::setParameterByID(
  FMOD_STUDIO_PARAMETER_ID id,
  float value,
  bool ignoreseekspeed = false
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_SetParameterByID(
  FMOD_STUDIO_SYSTEM *system,
  FMOD_STUDIO_PARAMETER_ID id,
  float value,
  FMOD_BOOL ignoreseekspeed
);
```

### C#
```csharp
RESULT Studio.System.setParameterByID(
  PARAMETER_ID id,
  float value,
  bool ignoreseekspeed = false
);
```

### JavaScript
```javascript
Studio.System.setParameterByID(
  id,
  value,
  ignoreseekspeed
);
```

## studio_system_setparameterbyidwithlabel
kind: function
index: 63

### C++
```cpp
FMOD_RESULT Studio::System::setParameterByIDWithLabel(
  FMOD_STUDIO_PARAMETER_ID id,
  const char *label,
  bool ignoreseekspeed = false
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_SetParameterByIDWithLabel(
  FMOD_STUDIO_SYSTEM *system,
  FMOD_STUDIO_PARAMETER_ID id,
  const char *label,
  FMOD_BOOL ignoreseekspeed
);
```

### C#
```csharp
RESULT Studio.System.setParameterByIDWithLabel(
  PARAMETER_ID id,
  string label,
  bool ignoreseekspeed = false
);
```

### JavaScript
```javascript
Studio.System.setParameterByIDWithLabel(
  id,
  label,
  ignoreseekspeed
);
```

## studio_system_setparameterbyname
kind: function
index: 64

### C++
```cpp
FMOD_RESULT Studio::System::setParameterByName(
  const char *name,
  float value,
  bool ignoreseekspeed = false
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_SetParameterByName(
  FMOD_STUDIO_SYSTEM *system,
  const char *name,
  float value,
  FMOD_BOOL ignoreseekspeed
);
```

### C#
```csharp
RESULT Studio.System.setParameterByName(
  string name,
  float value,
  bool ignoreseekspeed = false
);
```

### JavaScript
```javascript
Studio.System.setParameterByName(
  name,
  value,
  ignoreseekspeed
);
```

## studio_system_setparameterbynamewithlabel
kind: function
index: 65

### C++
```cpp
FMOD_RESULT Studio::System::setParameterByNameWithLabel(
  const char *name,
  const char *label,
  bool ignoreseekspeed = false
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_SetParameterByNameWithLabel(
  FMOD_STUDIO_SYSTEM *system,
  const char *name,
  const char *label,
  FMOD_BOOL ignoreseekspeed
);
```

### C#
```csharp
RESULT Studio.System.setParameterByNameWithLabel(
  string name,
  string label,
  bool ignoreseekspeed = false
);
```

### JavaScript
```javascript
Studio.System.setParameterByNameWithLabel(
  name,
  label,
  ignoreseekspeed
);
```

## studio_system_setparametersbyids
kind: function
index: 66

### C++
```cpp
FMOD_RESULT Studio::System::setParametersByIDs(
  const FMOD_STUDIO_PARAMETER_ID *ids,
  float *values,
  int count,
  bool ignoreseekspeed = false
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_SetParametersByIDs(
  FMOD_STUDIO_SYSTEM *system,
  const FMOD_STUDIO_PARAMETER_ID *ids,
  float *values,
  int count,
  FMOD_BOOL ignoreseekspeed
);
```

### C#
```csharp
RESULT Studio.System.setParametersByIDs(
  PARAMETER_ID[] ids,
  float[] values,
  int count,
  bool ignoreseekspeed = false
);
```

### JavaScript
```javascript
Studio.System.setParametersByIDs(
  ids,
  values,
  count,
  ignoreseekspeed
);
```

## studio_system_setuserdata
kind: function
index: 67

### C++
```cpp
FMOD_RESULT Studio::System::setUserData(
  void *userdata
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_SetUserData(
  FMOD_STUDIO_SYSTEM *system,
  void *userdata
);
```

### C#
```csharp
RESULT Studio.System.setUserData(
  IntPtr userdata
);
```

### JavaScript
```javascript
Studio.System.setUserData(
  userdata
);
```

## studio_system_startcommandcapture
kind: function
index: 68

### C++
```cpp
FMOD_RESULT Studio::System::startCommandCapture(
  const char *filename,
  FMOD_STUDIO_COMMANDCAPTURE_FLAGS flags
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_StartCommandCapture(
  FMOD_STUDIO_SYSTEM *system,
  const char *filename,
  FMOD_STUDIO_COMMANDCAPTURE_FLAGS flags
);
```

### C#
```csharp
RESULT Studio.System.startCommandCapture(
  string filename,
  COMMANDCAPTURE_FLAGS flags
);
```

### JavaScript
```javascript
Studio.System.startCommandCapture(
  filename,
  flags
);
```

## studio_system_stopcommandcapture
kind: function
index: 69

### C++
```cpp
FMOD_RESULT Studio::System::stopCommandCapture();
```

### C
```c
FMOD_RESULT FMOD_Studio_System_StopCommandCapture(FMOD_STUDIO_SYSTEM *system);
```

### C#
```csharp
RESULT Studio.System.stopCommandCapture();
```

### JavaScript
```javascript
Studio.System.stopCommandCapture();
```

## studio_system_unloadall
kind: function
index: 70

### C++
```cpp
FMOD_RESULT Studio::System::unloadAll();
```

### C
```c
FMOD_RESULT FMOD_Studio_System_UnloadAll(FMOD_STUDIO_SYSTEM *system);
```

### C#
```csharp
RESULT Studio.System.unloadAll();
```

### JavaScript
```javascript
Studio.System.unloadAll();
```

## studio_system_unregisterplugin
kind: function
index: 71

### C++
```cpp
FMOD_RESULT Studio::System::unregisterPlugin(
  const char *name
);
```

### C
```c
FMOD_RESULT FMOD_Studio_System_UnregisterPlugin(
  FMOD_STUDIO_SYSTEM *system,
  const char *name
);
```

### JavaScript
```javascript
Studio.System.unregisterPlugin(
  name
);
```

## studio_system_update
kind: function
index: 72

### C++
```cpp
FMOD_RESULT Studio::System::update();
```

### C
```c
FMOD_RESULT FMOD_Studio_System_Update(FMOD_STUDIO_SYSTEM *system);
```

### C#
```csharp
RESULT Studio.System.update();
```

### JavaScript
```javascript
Studio.System.update();
```

