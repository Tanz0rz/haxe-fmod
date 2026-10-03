# core-api-system

## FMOD_3D_ROLLOFF_CALLBACK
kind: example
index: 0
heading: FMOD_3D_ROLLOFF_CALLBACK
tabbed: yes

### C/C++
```cpp
float F_CALL FMOD_3D_ROLLOFF_CALLBACK(
  FMOD_CHANNELCONTROL *channelcontrol,
  float distance
);
```

### C#
```csharp
delegate float CB_3D_ROLLOFFCALLBACK(
  IntPtr channelcontrol,
  float distance
);
```

## FMOD_ADVANCEDSETTINGS
kind: example
index: 1
heading: FMOD_ADVANCEDSETTINGS
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_ADVANCEDSETTINGS {
  int                  cbSize;
  int                  maxMPEGCodecs;
  int                  maxADPCMCodecs;
  int                  maxXMACodecs;
  int                  maxVorbisCodecs;
  int                  maxAT9Codecs;
  int                  maxFADPCMCodecs;
  int                  maxOpusCodecs;
  int                  ASIONumChannels;
  char               **ASIOChannelList;
  FMOD_SPEAKER        *ASIOSpeakerList;
  float                vol0virtualvol;
  unsigned int         defaultDecodeBufferSize;
  unsigned short       profilePort;
  unsigned int         geometryMaxFadeTime;
  float                distanceFilterCenterFreq;
  int                  reverb3Dinstance;
  int                  DSPBufferPoolSize;
  FMOD_DSP_RESAMPLER   resamplerMethod;
  unsigned int         randomSeed;
  int                  maxConvolutionThreads;
  int                  maxSpatialObjects;
} FMOD_ADVANCEDSETTINGS;
```

### C#
```csharp
struct ADVANCEDSETTINGS
{
  int           cbSize;
  int           maxMPEGCodecs;
  int           maxADPCMCodecs;
  int           maxXMACodecs;
  int           maxVorbisCodecs;
  int           maxAT9Codecs;
  int           maxFADPCMCodecs;
  int           maxOpusCodecs;
  int           ASIONumChannels;
  IntPtr        ASIOChannelList;
  IntPtr        ASIOSpeakerList;
  float         vol0virtualvol;
  uint          defaultDecodeBufferSize;
  ushort        profilePort;
  uint          geometryMaxFadeTime;
  float         distanceFilterCenterFreq;
  int           reverb3Dinstance;
  int           DSPBufferPoolSize;
  DSP_RESAMPLER resamplerMethod;
  uint          randomSeed;
  int           maxConvolutionThreads;
  int           maxSpatialObjects;
}
```

### JavaScript
```javascript
ADVANCEDSETTINGS
{
  maxMPEGCodecs,
  maxADPCMCodecs,
  maxXMACodecs,
  maxVorbisCodecs,
  maxAT9Codecs,
  maxFADPCMCodecs,
  maxOpusCodecs,
  ASIONumChannels,
  vol0virtualvol,
  defaultDecodeBufferSize,
  profilePort,
  geometryMaxFadeTime,
  distanceFilterCenterFreq,
  reverb3Dinstance,
  DSPBufferPoolSize,
  resamplerMethod,
  randomSeed,
  maxConvolutionThreads,
  maxSpatialObjects,
};
```

## FMOD_ASYNCREADINFO
kind: example
index: 2
heading: FMOD_ASYNCREADINFO
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_ASYNCREADINFO {
  void                      *handle;
  unsigned int               offset;
  unsigned int               sizebytes;
  int                        priority;
  void                      *userdata;
  void                      *buffer;
  unsigned int               bytesread;
  FMOD_FILE_ASYNCDONE_FUNC   done;
} FMOD_ASYNCREADINFO;
```

### C#
```csharp
struct ASYNCREADINFO
{
  IntPtr                      handle;
  uint                        offset;
  uint                        sizebytes;
  int                         priority;
  IntPtr                      userdata;
  IntPtr                      buffer;
  uint                        bytesread;
  FILE_ASYNCDONE_FUNC         done;
}
```

## FMOD_CREATESOUNDEXINFO
kind: example
index: 3
heading: FMOD_CREATESOUNDEXINFO
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_CREATESOUNDEXINFO {
  int                              cbsize;
  unsigned int                     length;
  unsigned int                     fileoffset;
  int                              numchannels;
  int                              defaultfrequency;
  FMOD_SOUND_FORMAT                format;
  unsigned int                     decodebuffersize;
  int                              initialsubsound;
  int                              numsubsounds;
  int                             *inclusionlist;
  int                              inclusionlistnum;
  FMOD_SOUND_PCMREAD_CALLBACK      pcmreadcallback;
  FMOD_SOUND_PCMSETPOS_CALLBACK    pcmsetposcallback;
  FMOD_SOUND_NONBLOCK_CALLBACK     nonblockcallback;
  const char                      *dlsname;
  const char                      *encryptionkey;
  int                              maxpolyphony;
  void                            *userdata;
  FMOD_SOUND_TYPE                  suggestedsoundtype;
  FMOD_FILE_OPEN_CALLBACK          fileuseropen;
  FMOD_FILE_CLOSE_CALLBACK         fileuserclose;
  FMOD_FILE_READ_CALLBACK          fileuserread;
  FMOD_FILE_SEEK_CALLBACK          fileuserseek;
  FMOD_FILE_ASYNCREAD_CALLBACK     fileuserasyncread;
  FMOD_FILE_ASYNCCANCEL_CALLBACK   fileuserasynccancel;
  void                            *fileuserdata;
  int                              filebuffersize;
  FMOD_CHANNELORDER                channelorder;
  FMOD_SOUNDGROUP                 *initialsoundgroup;
  unsigned int                     initialseekposition;
  FMOD_TIMEUNIT                    initialseekpostype;
  int                              ignoresetfilesystem;
  unsigned int                     audioqueuepolicy;
  unsigned int                     minmidigranularity;
  int                              nonblockthreadid;
  FMOD_GUID                       *fsbguid;
} FMOD_CREATESOUNDEXINFO;
```

### C#
```csharp
struct CREATESOUNDEXINFO
{
  int                      cbsize;
  uint                     length;
  uint                     fileoffset;
  int                      numchannels;
  int                      defaultfrequency;
  SOUND_FORMAT             format;
  uint                     decodebuffersize;
  int                      initialsubsound;
  int                      numsubsounds;
  IntPtr                   inclusionlist;
  int                      inclusionlistnum;
  SOUND_PCMREADCALLBACK    pcmreadcallback;
  SOUND_PCMSETPOSCALLBACK  pcmsetposcallback;
  SOUND_NONBLOCKCALLBACK   nonblockcallback;
  IntPtr                   dlsname;
  IntPtr                   encryptionkey;
  int                      maxpolyphony;
  IntPtr                   userdata;
  SOUND_TYPE               suggestedsoundtype;
  FILE_OPENCALLBACK        fileuseropen;
  FILE_CLOSECALLBACK       fileuserclose;
  FILE_READCALLBACK        fileuserread;
  FILE_SEEKCALLBACK        fileuserseek;
  FILE_ASYNCREADCALLBACK   fileuserasyncread;
  FILE_ASYNCCANCELCALLBACK fileuserasynccancel;
  IntPtr                   fileuserdata;
  int                      filebuffersize;
  CHANNELORDER             channelorder;
  IntPtr                   initialsoundgroup;
  uint                     initialseekposition;
  TIMEUNIT                 initialseekpostype;
  int                      ignoresetfilesystem;
  uint                     audioqueuepolicy;
  uint                     minmidigranularity;
  int                      nonblockthreadid;
  IntPtr                   fsbguid;
}
```

### JavaScript
```javascript
CREATESOUNDEXINFO
{
  length,
  fileoffset,
  numchannels,
  defaultfrequency,
  format,
  decodebuffersize,
  initialsubsound,
  numsubsounds,
  inclusionlist,
  inclusionlistnum,
  pcmreadcallback,
  pcmsetposcallback,
  nonblockcallback,
  dlsname,
  encryptionkey,
  maxpolyphony,
  userdata,
  suggestedsoundtype,
  fileuseropen,
  fileuserclose,
  fileuserread,
  fileuserseek,
  fileuserasyncread,
  fileuserasynccancel,
  fileuserdata,
  filebuffersize,
  channelorder,
  initialsoundgroup,
  initialseekposition,
  initialseekpostype,
  ignoresetfilesystem,
  audioqueuepolicy,
  minmidigranularity,
  nonblockthreadid,
};
```

## FMOD_DRIVER_STATE
kind: example
index: 4
heading: FMOD_DRIVER_STATE
tabbed: yes

### C/C++
```cpp
#define FMOD_DRIVER_STATE_CONNECTED   0x00000001
#define FMOD_DRIVER_STATE_DEFAULT     0x00000002
```

### C#
```csharp
[Flags]
enum DRIVER_STATE : uint
{
  CONNECTED = 0x00000001,
  DEFAULT   = 0x00000002,
}
```

### JavaScript
```javascript
DRIVER_STATE_CONNECTED = 0x00000001
DRIVER_STATE_DEFAULT   = 0x00000002
```

## FMOD_DSP_RESAMPLER
kind: example
index: 5
heading: FMOD_DSP_RESAMPLER
tabbed: yes

### C/C++
```cpp
typedef enum FMOD_DSP_RESAMPLER {
  FMOD_DSP_RESAMPLER_DEFAULT,
  FMOD_DSP_RESAMPLER_NOINTERP,
  FMOD_DSP_RESAMPLER_LINEAR,
  FMOD_DSP_RESAMPLER_CUBIC,
  FMOD_DSP_RESAMPLER_SPLINE,
  FMOD_DSP_RESAMPLER_MAX
} FMOD_DSP_RESAMPLER;
```

### C#
```csharp
enum DSP_RESAMPLER : int
{
  DEFAULT,
  NOINTERP,
  LINEAR,
  CUBIC,
  SPLINE,
  MAX
}
```

### JavaScript
```javascript
DSP_RESAMPLER_DEFAULT
DSP_RESAMPLER_NOINTERP
DSP_RESAMPLER_LINEAR
DSP_RESAMPLER_CUBIC
DSP_RESAMPLER_SPLINE
DSP_RESAMPLER_MAX
```

## FMOD_ERRORCALLBACK_INFO
kind: example
index: 6
heading: FMOD_ERRORCALLBACK_INFO
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_ERRORCALLBACK_INFO {
  FMOD_RESULT                       result;
  FMOD_ERRORCALLBACK_INSTANCETYPE   instancetype;
  void                             *instance;
  const char                       *functionname;
  const char                       *functionparams;
} FMOD_ERRORCALLBACK_INFO;
```

### C#
```csharp
struct ERRORCALLBACK_INFO
{
  RESULT                      result;
  ERRORCALLBACK_INSTANCETYPE  instancetype;
  IntPtr                      instance;
  StringWrapper               functionname;
  StringWrapper               functionparams;
}
```

### JavaScript
```javascript
ERRORCALLBACK_INFO
{
  result,
  instancetype,
  instance,
  functionname,
  functionparams,
};
```

## FMOD_ERRORCALLBACK_INSTANCETYPE
kind: example
index: 7
heading: FMOD_ERRORCALLBACK_INSTANCETYPE
tabbed: yes

### C/C++
```cpp
typedef enum FMOD_ERRORCALLBACK_INSTANCETYPE {
  FMOD_ERRORCALLBACK_INSTANCETYPE_NONE,
  FMOD_ERRORCALLBACK_INSTANCETYPE_SYSTEM,
  FMOD_ERRORCALLBACK_INSTANCETYPE_CHANNEL,
  FMOD_ERRORCALLBACK_INSTANCETYPE_CHANNELGROUP,
  FMOD_ERRORCALLBACK_INSTANCETYPE_CHANNELCONTROL,
  FMOD_ERRORCALLBACK_INSTANCETYPE_SOUND,
  FMOD_ERRORCALLBACK_INSTANCETYPE_SOUNDGROUP,
  FMOD_ERRORCALLBACK_INSTANCETYPE_DSP,
  FMOD_ERRORCALLBACK_INSTANCETYPE_DSPCONNECTION,
  FMOD_ERRORCALLBACK_INSTANCETYPE_GEOMETRY,
  FMOD_ERRORCALLBACK_INSTANCETYPE_REVERB3D,
  FMOD_ERRORCALLBACK_INSTANCETYPE_STUDIO_SYSTEM,
  FMOD_ERRORCALLBACK_INSTANCETYPE_STUDIO_EVENTDESCRIPTION,
  FMOD_ERRORCALLBACK_INSTANCETYPE_STUDIO_EVENTINSTANCE,
  FMOD_ERRORCALLBACK_INSTANCETYPE_STUDIO_PARAMETERINSTANCE,
  FMOD_ERRORCALLBACK_INSTANCETYPE_STUDIO_BUS,
  FMOD_ERRORCALLBACK_INSTANCETYPE_STUDIO_VCA,
  FMOD_ERRORCALLBACK_INSTANCETYPE_STUDIO_BANK,
  FMOD_ERRORCALLBACK_INSTANCETYPE_STUDIO_COMMANDREPLAY
} FMOD_ERRORCALLBACK_INSTANCETYPE;
```

### C#
```csharp
enum ERRORCALLBACK_INSTANCETYPE
{
  NONE,
  SYSTEM,
  CHANNEL,
  CHANNELGROUP,
  CHANNELCONTROL,
  SOUND,
  SOUNDGROUP,
  DSP,
  DSPCONNECTION,
  GEOMETRY,
  REVERB3D,
  STUDIO_SYSTEM,
  STUDIO_EVENTDESCRIPTION,
  STUDIO_EVENTINSTANCE,
  STUDIO_PARAMETERINSTANCE,
  STUDIO_BUS,
  STUDIO_VCA,
  STUDIO_BANK,
  STUDIO_COMMANDREPLAY
}
```

### JavaScript
```javascript
ERRORCALLBACK_INSTANCETYPE_NONE
ERRORCALLBACK_INSTANCETYPE_SYSTEM
ERRORCALLBACK_INSTANCETYPE_CHANNEL
ERRORCALLBACK_INSTANCETYPE_CHANNELGROUP
ERRORCALLBACK_INSTANCETYPE_CHANNELCONTROL
ERRORCALLBACK_INSTANCETYPE_SOUND
ERRORCALLBACK_INSTANCETYPE_SOUNDGROUP
ERRORCALLBACK_INSTANCETYPE_DSP
ERRORCALLBACK_INSTANCETYPE_DSPCONNECTION
ERRORCALLBACK_INSTANCETYPE_GEOMETRY
ERRORCALLBACK_INSTANCETYPE_REVERB3D
ERRORCALLBACK_INSTANCETYPE_STUDIO_SYSTEM
ERRORCALLBACK_INSTANCETYPE_STUDIO_EVENTDESCRIPTION
ERRORCALLBACK_INSTANCETYPE_STUDIO_EVENTINSTANCE
ERRORCALLBACK_INSTANCETYPE_STUDIO_PARAMETERINSTANCE
ERRORCALLBACK_INSTANCETYPE_STUDIO_BUS
ERRORCALLBACK_INSTANCETYPE_STUDIO_VCA
ERRORCALLBACK_INSTANCETYPE_STUDIO_BANK
ERRORCALLBACK_INSTANCETYPE_STUDIO_COMMANDREPLAY
```

## FMOD_FILE_ASYNCCANCEL_CALLBACK
kind: example
index: 8
heading: FMOD_FILE_ASYNCCANCEL_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_FILE_ASYNCCANCEL_CALLBACK(
  FMOD_ASYNCREADINFO *info,
  void *userdata
);
```

### C#
```csharp
delegate RESULT FILE_ASYNCCANCELCALLBACK(
  IntPtr info,
  IntPtr userdata
);
```

## FMOD_FILE_ASYNCDONE_FUNC
kind: example
index: 9
heading: FMOD_FILE_ASYNCDONE_FUNC
tabbed: yes

### C/C++
```cpp
void F_CALL FMOD_FILE_ASYNCDONE_FUNC(
  FMOD_ASYNCREADINFO *info,
  FMOD_RESULT result
);
```

### C#
```csharp
delegate void FILE_ASYNCDONE_FUNC(
  IntPtr info,
  RESULT result
);
```

## FMOD_FILE_ASYNCREAD_CALLBACK
kind: example
index: 10
heading: FMOD_FILE_ASYNCREAD_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_FILE_ASYNCREAD_CALLBACK(
  FMOD_ASYNCREADINFO *info,
  void *userdata
);
```

### C#
```csharp
delegate RESULT FILE_ASYNCREADCALLBACK(
  IntPtr info,
  IntPtr userdata
);
```

## FMOD_FILE_CLOSE_CALLBACK
kind: example
index: 11
heading: FMOD_FILE_CLOSE_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_FILE_CLOSE_CALLBACK(
  void *handle,
  void *userdata
);
```

### C#
```csharp
delegate RESULT FILE_CLOSECALLBACK(
  IntPtr handle,
  IntPtr userdata
);
```

### JavaScript
```javascript
function FMOD_FILE_CLOSE_CALLBACK(
  handle,
  userdata
)
```

## FMOD_FILE_OPEN_CALLBACK
kind: example
index: 12
heading: FMOD_FILE_OPEN_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_FILE_OPEN_CALLBACK(
  const char *name,
  unsigned int *filesize,
  void **handle,
  void *userdata
);
```

### C#
```csharp
delegate RESULT FILE_OPENCALLBACK(
  IntPtr name,
  ref uint filesize,
  ref IntPtr handle,
  IntPtr userdata
);
```

### JavaScript
```javascript
function FMOD_FILE_OPEN_CALLBACK(
  name,
  filesize,
  handle,
  userdata
)
```

## FMOD_FILE_READ_CALLBACK
kind: example
index: 13
heading: FMOD_FILE_READ_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_FILE_READ_CALLBACK(
  void *handle,
  void *buffer,
  unsigned int sizebytes,
  unsigned int *bytesread,
  void *userdata
);
```

### C#
```csharp
delegate RESULT FILE_READCALLBACK(
  IntPtr handle,
  IntPtr buffer,
  uint sizebytes,
  ref uint bytesread,
  IntPtr userdata
);
```

### JavaScript
```javascript
function FMOD_FILE_READ_CALLBACK(
  handle,
  buffer,
  sizebytes,
  bytesread,
  userdata
)
```

## FMOD_FILE_SEEK_CALLBACK
kind: example
index: 14
heading: FMOD_FILE_SEEK_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_FILE_SEEK_CALLBACK(
  void *handle,
  unsigned int pos,
  void *userdata
);
```

### C#
```csharp
delegate RESULT FILE_SEEKCALLBACK(
  IntPtr handle,
  uint pos,
  IntPtr userdata
);
```

### JavaScript
```javascript
function FMOD_FILE_SEEK_CALLBACK(
  handle,
  pos,
  userdata
)
```

## FMOD_INITFLAGS
kind: example
index: 15
heading: FMOD_INITFLAGS
tabbed: yes

### C/C++
```cpp
#define FMOD_INIT_NORMAL                     0x00000000
#define FMOD_INIT_STREAM_FROM_UPDATE         0x00000001
#define FMOD_INIT_MIX_FROM_UPDATE            0x00000002
#define FMOD_INIT_3D_RIGHTHANDED             0x00000004
#define FMOD_INIT_CLIP_OUTPUT                0x00000008
#define FMOD_INIT_CHANNEL_LOWPASS            0x00000100
#define FMOD_INIT_CHANNEL_DISTANCEFILTER     0x00000200
#define FMOD_INIT_PROFILE_ENABLE             0x00010000
#define FMOD_INIT_VOL0_BECOMES_VIRTUAL       0x00020000
#define FMOD_INIT_GEOMETRY_USECLOSEST        0x00040000
#define FMOD_INIT_PREFER_DOLBY_DOWNMIX       0x00080000
#define FMOD_INIT_THREAD_UNSAFE              0x00100000
#define FMOD_INIT_PROFILE_METER_ALL          0x00200000
#define FMOD_INIT_MEMORY_TRACKING            0x00400000
```

### C#
```csharp
[Flags]
enum INITFLAGS : uint
{
  NORMAL                     = 0x00000000,
  STREAM_FROM_UPDATE         = 0x00000001,
  MIX_FROM_UPDATE            = 0x00000002,
  _3D_RIGHTHANDED            = 0x00000004,
  CLIP_OUTPUT                = 0x00000008,
  CHANNEL_LOWPASS            = 0x00000100,
  CHANNEL_DISTANCEFILTER     = 0x00000200,
  PROFILE_ENABLE             = 0x00010000,
  VOL0_BECOMES_VIRTUAL       = 0x00020000,
  GEOMETRY_USECLOSEST        = 0x00040000,
  PREFER_DOLBY_DOWNMIX       = 0x00080000,
  THREAD_UNSAFE              = 0x00100000,
  PROFILE_METER_ALL          = 0x00200000,
  MEMORY_TRACKING            = 0x00400000,
}
```

### JavaScript
```javascript
INIT_NORMAL                 = 0x00000000
INIT_STREAM_FROM_UPDATE     = 0x00000001
INIT_MIX_FROM_UPDATE        = 0x00000002
INIT_3D_RIGHTHANDED         = 0x00000004
INIT_CLIP_OUTPUT            = 0x00000008
INIT_CHANNEL_LOWPASS        = 0x00000100
INIT_CHANNEL_DISTANCEFILTER = 0x00000200
INIT_PROFILE_ENABLE         = 0x00010000
INIT_VOL0_BECOMES_VIRTUAL   = 0x00020000
INIT_GEOMETRY_USECLOSEST    = 0x00040000
INIT_PREFER_DOLBY_DOWNMIX   = 0x00080000
INIT_THREAD_UNSAFE          = 0x00100000
INIT_PROFILE_METER_ALL      = 0x00200000
INIT_MEMORY_TRACKING        = 0x00400000
```

## FMOD_OUTPUTTYPE
kind: example
index: 16
heading: FMOD_OUTPUTTYPE
tabbed: yes

### C/C++
```cpp
typedef enum FMOD_OUTPUTTYPE {
  FMOD_OUTPUTTYPE_AUTODETECT,
  FMOD_OUTPUTTYPE_UNKNOWN,
  FMOD_OUTPUTTYPE_NOSOUND,
  FMOD_OUTPUTTYPE_WAVWRITER,
  FMOD_OUTPUTTYPE_NOSOUND_NRT,
  FMOD_OUTPUTTYPE_WAVWRITER_NRT,
  FMOD_OUTPUTTYPE_WASAPI,
  FMOD_OUTPUTTYPE_ASIO,
  FMOD_OUTPUTTYPE_PULSEAUDIO,
  FMOD_OUTPUTTYPE_ALSA,
  FMOD_OUTPUTTYPE_COREAUDIO,
  FMOD_OUTPUTTYPE_AUDIOTRACK,
  FMOD_OUTPUTTYPE_OPENSL,
  FMOD_OUTPUTTYPE_AUDIOOUT,
  FMOD_OUTPUTTYPE_AUDIO3D,
  FMOD_OUTPUTTYPE_WEBAUDIO,
  FMOD_OUTPUTTYPE_NNAUDIO,
  FMOD_OUTPUTTYPE_WINSONIC,
  FMOD_OUTPUTTYPE_AAUDIO,
  FMOD_OUTPUTTYPE_AUDIOWORKLET,
  FMOD_OUTPUTTYPE_PHASE,
  FMOD_OUTPUTTYPE_OHAUDIO,
  FMOD_OUTPUTTYPE_MAX
} FMOD_OUTPUTTYPE;
```

### C#
```csharp
enum OUTPUTTYPE : int
{
  AUTODETECT,
  UNKNOWN,
  NOSOUND,
  WAVWRITER,
  NOSOUND_NRT,
  WAVWRITER_NRT,
  WASAPI,
  ASIO,
  PULSEAUDIO,
  ALSA,
  COREAUDIO,
  AUDIOTRACK,
  OPENSL,
  AUDIOOUT,
  AUDIO3D,
  WEBAUDIO,
  NNAUDIO,
  WINSONIC,
  AAUDIO,
  AUDIOWORKLET,
  PHASE,
  OHAUDIO,
  MAX,
}
```

### JavaScript
```javascript
OUTPUTTYPE_AUTODETECT
OUTPUTTYPE_UNKNOWN
OUTPUTTYPE_NOSOUND
OUTPUTTYPE_WAVWRITER
OUTPUTTYPE_NOSOUND_NRT
OUTPUTTYPE_WAVWRITER_NRT
OUTPUTTYPE_WASAPI
OUTPUTTYPE_ASIO
OUTPUTTYPE_PULSEAUDIO
OUTPUTTYPE_ALSA
OUTPUTTYPE_COREAUDIO
OUTPUTTYPE_AUDIOTRACK
OUTPUTTYPE_OPENSL
OUTPUTTYPE_AUDIOOUT
OUTPUTTYPE_AUDIO3D
OUTPUTTYPE_WEBAUDIO
OUTPUTTYPE_NNAUDIO
OUTPUTTYPE_WINSONIC
OUTPUTTYPE_AAUDIO
OUTPUTTYPE_AUDIOWORKLET
OUTPUTTYPE_PHASE
OUTPUTTYPE_OHAUDIO
OUTPUTTYPE_MAX
```

## FMOD_PLUGINLIST
kind: example
index: 17
heading: FMOD_PLUGINLIST
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_PLUGINLIST {
  FMOD_PLUGINTYPE  type;
  void            *description;
} FMOD_PLUGINLIST;
```

## FMOD_PLUGINTYPE
kind: example
index: 18
heading: FMOD_PLUGINTYPE
tabbed: yes

### C/C++
```cpp
typedef enum FMOD_PLUGINTYPE {
  FMOD_PLUGINTYPE_OUTPUT,
  FMOD_PLUGINTYPE_CODEC,
  FMOD_PLUGINTYPE_DSP,
  FMOD_PLUGINTYPE_MAX
} FMOD_PLUGINTYPE;
```

### C#
```csharp
enum PLUGINTYPE : int
{
  OUTPUT,
  CODEC,
  DSP,
  MAX
}
```

### JavaScript
```javascript
PLUGINTYPE_OUTPUT
PLUGINTYPE_CODEC
PLUGINTYPE_DSP
PLUGINTYPE_MAX
```

## FMOD_PORT_INDEX
kind: example
index: 19
heading: FMOD_PORT_INDEX
tabbed: yes

### C/C++
```cpp
#define FMOD_PORT_INDEX_NONE 0xFFFFFFFFFFFFFFFF
```

### C#
```csharp
struct PORT_INDEX
{
  const ulong NONE = 0xFFFFFFFFFFFFFFFF;
}
```

### JavaScript
```javascript
PORT_INDEX_NONE = 0xFFFFFFFFFFFFFFFF
```

## FMOD_PORT_TYPE
kind: example
index: 20
heading: FMOD_PORT_TYPE
tabbed: yes

### C/C++
```cpp
typedef enum FMOD_PORT_TYPE
{
    FMOD_PORT_TYPE_MUSIC,
    FMOD_PORT_TYPE_COPYRIGHT_MUSIC,
    FMOD_PORT_TYPE_VOICE,
    FMOD_PORT_TYPE_CONTROLLER,
    FMOD_PORT_TYPE_PERSONAL,
    FMOD_PORT_TYPE_VIBRATION,
    FMOD_PORT_TYPE_AUX,
    FMOD_PORT_TYPE_PASSTHROUGH,
    FMOD_PORT_TYPE_VR_VIBRATION,
    FMOD_PORT_TYPE_MAX
} FMOD_PORT_TYPE;
```

### C#
```csharp
enum PORT_TYPE : int
{
    MUSIC,
    COPYRIGHT_MUSIC,
    VOICE,
    CONTROLLER,
    PERSONAL,
    VIBRATION,
    AUX,
    PASSTHROUGH,
    VR_VIBRATION,
    MAX
}
```

### JavaScript
```javascript
PORT_TYPE_MUSIC
PORT_TYPE_COPYRIGHT_MUSIC
PORT_TYPE_VOICE
PORT_TYPE_CONTROLLER
PORT_TYPE_PERSONAL
PORT_TYPE_VIBRATION
PORT_TYPE_AUX
PORT_TYPE_PASSTHROUGH
PORT_TYPE_VR_VIBRATION
PORT_TYPE_MAX
```

## FMOD_REVERB_MAXINSTANCES
kind: example
index: 21
heading: FMOD_REVERB_MAXINSTANCES
tabbed: yes

### C/C++
```cpp
#define FMOD_REVERB_MAXINSTANCES 4
```

### C#
```csharp
class CONSTANTS
{
  const int REVERB_MAXINSTANCES = 4;
}
```

### JavaScript
```javascript
REVERB_MAXINSTANCES = 4
```

## FMOD_REVERB_PRESETS
kind: example
index: 22
heading: FMOD_REVERB_PRESETS
tabbed: yes

### C/C++
```cpp
#define FMOD_PRESET_OFF                {  1000,    7,  11, 5000, 100, 100, 100, 250, 0,    20,  96, -80.0f }
#define FMOD_PRESET_GENERIC            {  1500,    7,  11, 5000,  83, 100, 100, 250, 0, 14500,  96,  -8.0f }
#define FMOD_PRESET_PADDEDCELL         {   170,    1,   2, 5000,  10, 100, 100, 250, 0,   160,  84,  -7.8f }
#define FMOD_PRESET_ROOM               {   400,    2,   3, 5000,  83, 100, 100, 250, 0,  6050,  88,  -9.4f }
#define FMOD_PRESET_BATHROOM           {  1500,    7,  11, 5000,  54, 100,  60, 250, 0,  2900,  83,   0.5f }
#define FMOD_PRESET_LIVINGROOM         {   500,    3,   4, 5000,  10, 100, 100, 250, 0,   160,  58, -19.0f }
#define FMOD_PRESET_STONEROOM          {  2300,   12,  17, 5000,  64, 100, 100, 250, 0,  7800,  71,  -8.5f }
#define FMOD_PRESET_AUDITORIUM         {  4300,   20,  30, 5000,  59, 100, 100, 250, 0,  5850,  64, -11.7f }
#define FMOD_PRESET_CONCERTHALL        {  3900,   20,  29, 5000,  70, 100, 100, 250, 0,  5650,  80,  -9.8f }
#define FMOD_PRESET_CAVE               {  2900,   15,  22, 5000, 100, 100, 100, 250, 0, 20000,  59, -11.3f }
#define FMOD_PRESET_ARENA              {  7200,   20,  30, 5000,  33, 100, 100, 250, 0,  4500,  80,  -9.6f }
#define FMOD_PRESET_HANGAR             { 10000,   20,  30, 5000,  23, 100, 100, 250, 0,  3400,  72,  -7.4f }
#define FMOD_PRESET_CARPETTEDHALLWAY   {   300,    2,  30, 5000,  10, 100, 100, 250, 0,   500,  56, -24.0f }
#define FMOD_PRESET_HALLWAY            {  1500,    7,  11, 5000,  59, 100, 100, 250, 0,  7800,  87,  -5.5f }
#define FMOD_PRESET_STONECORRIDOR      {   270,   13,  20, 5000,  79, 100, 100, 250, 0,  9000,  86,  -6.0f }
#define FMOD_PRESET_ALLEY              {  1500,    7,  11, 5000,  86, 100, 100, 250, 0,  8300,  80,  -9.8f }
#define FMOD_PRESET_FOREST             {  1500,  162,  88, 5000,  54,  79, 100, 250, 0,   760,  94, -12.3f }
#define FMOD_PRESET_CITY               {  1500,    7,  11, 5000,  67,  50, 100, 250, 0,  4050,  66, -26.0f }
#define FMOD_PRESET_MOUNTAINS          {  1500,  300, 100, 5000,  21,  27, 100, 250, 0,  1220,  82, -24.0f }
#define FMOD_PRESET_QUARRY             {  1500,   61,  25, 5000,  83, 100, 100, 250, 0,  3400, 100,  -5.0f }
#define FMOD_PRESET_PLAIN              {  1500,  179, 100, 5000,  50,  21, 100, 250, 0,  1670,  65, -28.0f }
#define FMOD_PRESET_PARKINGLOT         {  1700,    8,  12, 5000, 100, 100, 100, 250, 0, 20000,  56, -19.5f }
#define FMOD_PRESET_SEWERPIPE          {  2800,   14,  21, 5000,  14,  80,  60, 250, 0,  3400,  66,   1.2f }
#define FMOD_PRESET_UNDERWATER         {  1500,    7,  11, 5000,  10, 100, 100, 250, 0,   500,  92,   7.0f }
```

### C#
```csharp
class PRESET
{
  REVERB_PROPERTIES OFF
  REVERB_PROPERTIES GENERIC
  REVERB_PROPERTIES PADDEDCELL
  REVERB_PROPERTIES ROOM
  REVERB_PROPERTIES BATHROOM
  REVERB_PROPERTIES LIVINGROOM
  REVERB_PROPERTIES STONEROOM
  REVERB_PROPERTIES AUDITORIUM
  REVERB_PROPERTIES CONCERTHALL
  REVERB_PROPERTIES CAVE
  REVERB_PROPERTIES ARENA
  REVERB_PROPERTIES HANGAR
  REVERB_PROPERTIES CARPETTEDHALLWAY
  REVERB_PROPERTIES HALLWAY
  REVERB_PROPERTIES STONECORRIDOR
  REVERB_PROPERTIES ALLEY
  REVERB_PROPERTIES FOREST
  REVERB_PROPERTIES CITY
  REVERB_PROPERTIES MOUNTAINS
  REVERB_PROPERTIES QUARRY
  REVERB_PROPERTIES PLAIN
  REVERB_PROPERTIES PARKINGLOT
  REVERB_PROPERTIES SEWERPIPE
  REVERB_PROPERTIES UNDERWATER
}
```

## FMOD_REVERB_PROPERTIES
kind: example
index: 23
heading: FMOD_REVERB_PROPERTIES
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_REVERB_PROPERTIES {
  float   DecayTime;
  float   EarlyDelay;
  float   LateDelay;
  float   HFReference;
  float   HFDecayRatio;
  float   Diffusion;
  float   Density;
  float   LowShelfFrequency;
  float   LowShelfGain;
  float   HighCut;
  float   EarlyLateMix;
  float   WetLevel;
} FMOD_REVERB_PROPERTIES;
```

### C#
```csharp
struct REVERB_PROPERTIES
{
    float DecayTime;
    float EarlyDelay;
    float LateDelay;
    float HFReference;
    float HFDecayRatio;
    float Diffusion;
    float Density;
    float LowShelfFrequency;
    float LowShelfGain;
    float HighCut;
    float EarlyLateMix;
    float WetLevel;
}
```

### JavaScript
```javascript
REVERB_PROPERTIES
{
  DecayTime,
  EarlyDelay,
  LateDelay,
  HFReference,
  HFDecayRatio,
  Diffusion,
  Density,
  LowShelfFrequency,
  LowShelfGain,
  HighCut,
  EarlyLateMix,
  WetLevel,
};
```

## system_attachchannelgrouptoport
kind: function
index: 24

### C++
```cpp
FMOD_RESULT System::attachChannelGroupToPort(
  FMOD_PORT_TYPE portType,
  FMOD_PORT_INDEX portIndex,
  ChannelGroup *channelgroup,
  bool passThru = false
);
```

### C
```c
FMOD_RESULT FMOD_System_AttachChannelGroupToPort(
  FMOD_SYSTEM *system,
  FMOD_PORT_TYPE portType,
  FMOD_PORT_INDEX portIndex,
  FMOD_CHANNELGROUP *channelgroup,
  FMOD_BOOL passThru
);
```

### C#
```csharp
RESULT System.attachChannelGroupToPort(
  uint portType,
  ulong portIndex,
  ChannelGroup channelgroup,
  bool passThru = false
);
```

### JavaScript
```javascript
System.attachChannelGroupToPort(
  portType,
  portIndex,
  channelgroup,
  passThru
);
```

## system_attachfilesystem
kind: function
index: 25

### C++
```cpp
FMOD_RESULT System::attachFileSystem(
  FMOD_FILE_OPEN_CALLBACK useropen,
  FMOD_FILE_CLOSE_CALLBACK userclose,
  FMOD_FILE_READ_CALLBACK userread,
  FMOD_FILE_SEEK_CALLBACK userseek
);
```

### C
```c
FMOD_RESULT FMOD_System_AttachFileSystem(
  FMOD_SYSTEM *system,
  FMOD_FILE_OPEN_CALLBACK useropen,
  FMOD_FILE_CLOSE_CALLBACK userclose,
  FMOD_FILE_READ_CALLBACK userread,
  FMOD_FILE_SEEK_CALLBACK userseek
);
```

### C#
```csharp
RESULT System.attachFileSystem(
  FILE_OPENCALLBACK useropen,
  FILE_CLOSECALLBACK userclose,
  FILE_READCALLBACK userread,
  FILE_SEEKCALLBACK userseek
);
```

### JavaScript
```javascript
System.attachFileSystem(
  useropen,
  userclose,
  userread,
  userseek
);
```

## FMOD_SYSTEM_CALLBACK
kind: example
index: 26
heading: FMOD_SYSTEM_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_SYSTEM_CALLBACK(
  FMOD_SYSTEM *system,
  FMOD_SYSTEM_CALLBACK_TYPE type,
  void *commanddata1,
  void *commanddata2,
  void *userdata
);
```

### C#
```csharp
delegate RESULT SYSTEM_CALLBACK(
  IntPtr system,
  SYSTEM_CALLBACK_TYPE type,
  IntPtr commanddata1,
  IntPtr commanddata2,
  IntPtr userdata
);
```

### JavaScript
```javascript
function FMOD_SYSTEM_CALLBACK(
  system,
  type,
  commanddata1,
  commanddata2,
  userdata
)
```

## FMOD_SYSTEM_CALLBACK_TYPE
kind: example
index: 27
heading: FMOD_SYSTEM_CALLBACK_TYPE
tabbed: yes

### C/C++
```cpp
#define FMOD_SYSTEM_CALLBACK_DEVICELISTCHANGED        0x00000001
#define FMOD_SYSTEM_CALLBACK_DEVICELOST               0x00000002
#define FMOD_SYSTEM_CALLBACK_MEMORYALLOCATIONFAILED   0x00000004
#define FMOD_SYSTEM_CALLBACK_THREADCREATED            0x00000008
#define FMOD_SYSTEM_CALLBACK_BADDSPCONNECTION         0x00000010
#define FMOD_SYSTEM_CALLBACK_PREMIX                   0x00000020
#define FMOD_SYSTEM_CALLBACK_POSTMIX                  0x00000040
#define FMOD_SYSTEM_CALLBACK_ERROR                    0x00000080
#define FMOD_SYSTEM_CALLBACK_THREADDESTROYED          0x00000100
#define FMOD_SYSTEM_CALLBACK_PREUPDATE                0x00000200
#define FMOD_SYSTEM_CALLBACK_POSTUPDATE               0x00000400
#define FMOD_SYSTEM_CALLBACK_RECORDLISTCHANGED        0x00000800
#define FMOD_SYSTEM_CALLBACK_BUFFEREDNOMIX            0x00001000
#define FMOD_SYSTEM_CALLBACK_DEVICEREINITIALIZE       0x00002000
#define FMOD_SYSTEM_CALLBACK_OUTPUTUNDERRUN           0x00004000
#define FMOD_SYSTEM_CALLBACK_RECORDPOSITIONCHANGED    0x00008000
#define FMOD_SYSTEM_CALLBACK_ALL                      0xFFFFFFFF
```

### C#
```csharp
[Flags]
enum SYSTEM_CALLBACK_TYPE : uint
{
  DEVICELISTCHANGED      = 0x00000001,
  DEVICELOST             = 0x00000002,
  MEMORYALLOCATIONFAILED = 0x00000004,
  THREADCREATED          = 0x00000008,
  BADDSPCONNECTION       = 0x00000010,
  PREMIX                 = 0x00000020,
  POSTMIX                = 0x00000040,
  ERROR                  = 0x00000080,
  THREADDESTROYED        = 0x00000100,
  PREUPDATE              = 0x00000200,
  POSTUPDATE             = 0x00000400,
  RECORDLISTCHANGED      = 0x00000800,
  BUFFEREDNOMIX          = 0x00001000,
  DEVICEREINITIALIZE     = 0x00002000,
  OUTPUTUNDERRUN         = 0x00004000,
  RECORDPOSITIONCHANGED  = 0x00008000,
  ALL                    = 0xFFFFFFFF,
}
```

### JavaScript
```javascript
SYSTEM_CALLBACK_DEVICELISTCHANGED      = 0x00000001
SYSTEM_CALLBACK_DEVICELOST             = 0x00000002
SYSTEM_CALLBACK_MEMORYALLOCATIONFAILED = 0x00000004
SYSTEM_CALLBACK_THREADCREATED          = 0x00000008
SYSTEM_CALLBACK_BADDSPCONNECTION       = 0x00000010
SYSTEM_CALLBACK_PREMIX                 = 0x00000020
SYSTEM_CALLBACK_POSTMIX                = 0x00000040
SYSTEM_CALLBACK_ERROR                  = 0x00000080
SYSTEM_CALLBACK_THREADDESTROYED        = 0x00000100
SYSTEM_CALLBACK_PREUPDATE              = 0x00000200
SYSTEM_CALLBACK_POSTUPDATE             = 0x00000400
SYSTEM_CALLBACK_RECORDLISTCHANGED      = 0x00000800
SYSTEM_CALLBACK_BUFFEREDNOMIX          = 0x00001000
SYSTEM_CALLBACK_DEVICEREINITIALIZE     = 0x00002000
SYSTEM_CALLBACK_OUTPUTUNDERRUN         = 0x00004000
SYSTEM_CALLBACK_RECORDPOSITIONCHANGED  = 0x00008000
SYSTEM_CALLBACK_ALL                    = 0xFFFFFFFF
```

## system_close
kind: function
index: 28

### C++
```cpp
FMOD_RESULT System::close();
```

### C
```c
FMOD_RESULT FMOD_System_Close(FMOD_SYSTEM *system);
```

### C#
```csharp
RESULT System.close();
```

### JavaScript
```javascript
System.close();
```

## system_create
kind: function
index: 29

### C++
```cpp
FMOD_RESULT System_Create(
  System **system,
  unsigned int headerversion = FMOD_VERSION
);
```

### C
```c
FMOD_RESULT FMOD_System_Create(
  FMOD_SYSTEM **system,
  unsigned int headerversion
);
```

### C#
```csharp
static RESULT Factory.System_Create(
  out System system
);
```

### JavaScript
```javascript
System_Create(
  system
);
```

## system_createchannelgroup
kind: function
index: 30

### C++
```cpp
FMOD_RESULT System::createChannelGroup(
  const char *name,
  ChannelGroup **channelgroup
);
```

### C
```c
FMOD_RESULT FMOD_System_CreateChannelGroup(
  FMOD_SYSTEM *system,
  const char *name,
  FMOD_CHANNELGROUP **channelgroup
);
```

### C#
```csharp
RESULT System.createChannelGroup(
  string name,
  out ChannelGroup channelgroup
);
```

### JavaScript
```javascript
System.createChannelGroup(
  name,
  channelgroup
);
```

## system_createdsp
kind: function
index: 31

### C++
```cpp
FMOD_RESULT System::createDSP(
  const FMOD_DSP_DESCRIPTION *description,
  DSP **dsp
);
```

### C
```c
FMOD_RESULT FMOD_System_CreateDSP(
  FMOD_SYSTEM *system,
  const FMOD_DSP_DESCRIPTION *description,
  FMOD_DSP **dsp
);
```

### C#
```csharp
RESULT System.createDSP(
  ref DSP_DESCRIPTION description,
  out DSP dsp
);
```

### JavaScript
```javascript
System.createDSP(
  description,
  dsp
);
```

## system_createdspbyplugin
kind: function
index: 32

### C++
```cpp
FMOD_RESULT System::createDSPByPlugin(
  unsigned int handle,
  DSP **dsp
);
```

### C
```c
FMOD_RESULT FMOD_System_CreateDSPByPlugin(
  FMOD_SYSTEM *system,
  unsigned int handle,
  FMOD_DSP **dsp
);
```

### C#
```csharp
RESULT System.createDSPByPlugin(
  uint handle,
  out DSP dsp
);
```

### JavaScript
```javascript
System.createDSPByPlugin(
  handle,
  dsp
);
```

## system_createdspbytype
kind: function
index: 33

### C++
```cpp
FMOD_RESULT System::createDSPByType(
  FMOD_DSP_TYPE type,
  DSP **dsp
);
```

### C
```c
FMOD_RESULT FMOD_System_CreateDSPByType(
  FMOD_SYSTEM *system,
  FMOD_DSP_TYPE type,
  FMOD_DSP **dsp
);
```

### C#
```csharp
RESULT System.createDSPByType(
  DSP_TYPE type,
  out DSP dsp
);
```

### JavaScript
```javascript
System.createDSPByType(
  type,
  dsp
);
```

## system_createdspconnection
kind: function
index: 34

### C++
```cpp
FMOD_RESULT System::createDSPConnection(
  FMOD_DSPCONNECTION_TYPE type,
  DSPConnection **connection
);
```

### C
```c
FMOD_RESULT FMOD_System_CreateDSPConnection(
  FMOD_SYSTEM *system,
  FMOD_DSPCONNECTION_TYPE type,
  FMOD_DSP **connection
);
```

### C#
```csharp
RESULT System.createDSPConnection(
  DSPCONNECTION_TYPE type,
  out DSPConnection connection
);
```

### JavaScript
```javascript
System.createDSPConnection(
  type,
  connection
);
```

## system_creategeometry
kind: function
index: 35

### C++
```cpp
FMOD_RESULT System::createGeometry(
  int maxpolygons,
  int maxvertices,
  Geometry **geometry
);
```

### C
```c
FMOD_RESULT FMOD_System_CreateGeometry(
  FMOD_SYSTEM *system,
  int maxpolygons,
  int maxvertices,
  FMOD_GEOMETRY **geometry
);
```

### C#
```csharp
RESULT System.createGeometry(
  int maxpolygons,
  int maxvertices,
  out Geometry geometry
);
```

### JavaScript
```javascript
System.createGeometry(
  maxpolygons,
  maxvertices,
  geometry
);
```

## system_createreverb3d
kind: function
index: 36

### C++
```cpp
FMOD_RESULT System::createReverb3D(
  Reverb3D **reverb
);
```

### C
```c
FMOD_RESULT FMOD_System_CreateReverb3D(
  FMOD_SYSTEM *system,
  FMOD_REVERB3D **reverb
);
```

### C#
```csharp
RESULT System.createReverb3D(
  out Reverb3D reverb
);
```

### JavaScript
```javascript
System.createReverb3D(
  reverb
);
```

## system_createsound
kind: function
index: 37

### C++
```cpp
FMOD_RESULT System::createSound(
  const char *name_or_data,
  FMOD_MODE mode,
  FMOD_CREATESOUNDEXINFO *exinfo,
  Sound **sound
);
```

### C
```c
FMOD_RESULT FMOD_System_CreateSound(
  FMOD_SYSTEM *system,
  const char *name_or_data,
  FMOD_MODE mode,
  FMOD_CREATESOUNDEXINFO *exinfo,
  FMOD_SOUND **sound
);
```

### C#
```csharp
RESULT System.createSound(
  string name,
  MODE mode,
  out Sound sound
);
RESULT System.createSound(
  byte[] data,
  MODE mode,
  out Sound sound
);
RESULT System.createSound(
  string name,
  MODE mode,
  ref CREATESOUNDEXINFO exinfo,
  out Sound sound
);
RESULT System.createSound(
  IntPtr name_or_data,
  MODE mode,
  ref CREATESOUNDEXINFO exinfo,
  out Sound sound
);
```

### JavaScript
```javascript
System.createSound(
  name_or_data,
  mode,
  exinfo,
  sound
);
```

## system_createsoundgroup
kind: function
index: 38

### C++
```cpp
FMOD_RESULT System::createSoundGroup(
  const char *name,
  SoundGroup **soundgroup
);
```

### C
```c
FMOD_RESULT FMOD_System_CreateSoundGroup(
  FMOD_SYSTEM *system,
  const char *name,
  FMOD_SOUNDGROUP **soundgroup
);
```

### C#
```csharp
RESULT System.createSoundGroup(
  string name,
  out SoundGroup soundgroup
);
```

### JavaScript
```javascript
System.createSoundGroup(
  name,
  soundgroup
);
```

## system_createstream
kind: function
index: 39

### C++
```cpp
FMOD_RESULT System::createStream(
  const char *name_or_data,
  FMOD_MODE mode,
  FMOD_CREATESOUNDEXINFO *exinfo,
  Sound **sound
);
```

### C
```c
FMOD_RESULT FMOD_System_CreateStream(
  FMOD_SYSTEM *system,
  const char *name_or_data,
  FMOD_MODE mode,
  FMOD_CREATESOUNDEXINFO *exinfo,
  FMOD_SOUND **sound
);
```

### C#
```csharp
RESULT System.createStream(
  string name,
  MODE mode,
  out Sound sound
);
RESULT System.createStream(
  string name,
  MODE mode,
  ref CREATESOUNDEXINFO exinfo,
  out Sound sound
);
RESULT System.createStream(
  byte[] data,
  MODE mode,
  ref CREATESOUNDEXINFO exinfo,
  out Sound sound
);
RESULT System.createStream(
  IntPtr name_or_data,
  MODE mode,
  ref CREATESOUNDEXINFO exinfo,
  out Sound sound
);
```

### JavaScript
```javascript
System.createStream(
  name_or_data,
  mode,
  exinfo,
  sound
);
```

## system_detachchannelgroupfromport
kind: function
index: 40

### C++
```cpp
FMOD_RESULT System::detachChannelGroupFromPort(
  ChannelGroup *channelgroup
);
```

### C
```c
FMOD_RESULT FMOD_System_DetachChannelGroupFromPort(
  FMOD_SYSTEM *system,
  FMOD_CHANNELGROUP *channelgroup
);
```

### C#
```csharp
RESULT System.detachChannelGroupFromPort(
  ChannelGroup channelgroup
);
```

### JavaScript
```javascript
System.detachChannelGroupFromPort(
  channelgroup
);
```

## system_get3dlistenerattributes
kind: function
index: 41

### C++
```cpp
FMOD_RESULT System::get3DListenerAttributes(
  int listener,
  FMOD_VECTOR *pos,
  FMOD_VECTOR *vel,
  FMOD_VECTOR *forward,
  FMOD_VECTOR *up
);
```

### C
```c
FMOD_RESULT FMOD_System_Get3DListenerAttributes(
  FMOD_SYSTEM *system,
  int listener,
  FMOD_VECTOR *pos,
  FMOD_VECTOR *vel,
  FMOD_VECTOR *forward,
  FMOD_VECTOR *up
);
```

### C#
```csharp
RESULT System.get3DListenerAttributes(
  int listener,
  out VECTOR pos,
  out VECTOR vel,
  out VECTOR forward,
  out VECTOR up
);
```

### JavaScript
```javascript
System.get3DListenerAttributes(
  listener,
  pos,
  vel,
  forward,
  up
);
```

## system_get3dnumlisteners
kind: function
index: 42

### C++
```cpp
FMOD_RESULT System::get3DNumListeners(
  int *numlisteners
);
```

### C
```c
FMOD_RESULT FMOD_System_Get3DNumListeners(
  FMOD_SYSTEM *system,
  int *numlisteners
);
```

### C#
```csharp
RESULT System.get3DNumListeners(
  out int numlisteners
);
```

### JavaScript
```javascript
System.get3DNumListeners(
  numlisteners
);
```

## system_get3dsettings
kind: function
index: 43

### C++
```cpp
FMOD_RESULT System::get3DSettings(
  float *dopplerscale,
  float *distancefactor,
  float *rolloffscale
);
```

### C
```c
FMOD_RESULT FMOD_System_Get3DSettings(
  FMOD_SYSTEM *system,
  float *dopplerscale,
  float *distancefactor,
  float *rolloffscale
);
```

### C#
```csharp
RESULT System.get3DSettings(
  out float dopplerscale,
  out float distancefactor,
  out float rolloffscale
);
```

### JavaScript
```javascript
System.get3DSettings(
  dopplerscale,
  distancefactor,
  rolloffscale
);
```

## system_getadvancedsettings
kind: function
index: 44

### C++
```cpp
FMOD_RESULT System::getAdvancedSettings(
  FMOD_ADVANCEDSETTINGS *settings
);
```

### C
```c
FMOD_RESULT FMOD_System_GetAdvancedSettings(
  FMOD_SYSTEM *system,
  FMOD_ADVANCEDSETTINGS *settings
);
```

### C#
```csharp
RESULT System.getAdvancedSettings(
  ref ADVANCEDSETTINGS settings
);
```

### JavaScript
```javascript
System.getAdvancedSettings(
  settings
);
```

## system_getchannel
kind: function
index: 45

### C++
```cpp
FMOD_RESULT System::getChannel(
  int channelid,
  Channel **channel
);
```

### C
```c
FMOD_RESULT FMOD_System_GetChannel(
  FMOD_SYSTEM *system,
  int channelid,
  FMOD_CHANNEL **channel
);
```

### C#
```csharp
RESULT System.getChannel(
  int channelid,
  out Channel channel
);
```

### JavaScript
```javascript
System.getChannel(
  channelid,
  channel
);
```

## system_getchannelsplaying
kind: function
index: 46

### C++
```cpp
FMOD_RESULT System::getChannelsPlaying(
  int *channels,
  int *realchannels = nullptr
);
```

### C
```c
FMOD_RESULT FMOD_System_GetChannelsPlaying(
  FMOD_SYSTEM *system,
  int *channels,
  int *realchannels
);
```

### C#
```csharp
RESULT System.getChannelsPlaying(
  out int channels
);
RESULT System.getChannelsPlaying(
  out int channels,
  out int realchannels
);
```

### JavaScript
```javascript
System.getChannelsPlaying(
  channels,
  realchannels
);
```

## system_getcpuusage
kind: function
index: 47

### C++
```cpp
FMOD_RESULT System::getCPUUsage(
  FMOD_CPU_USAGE *usage
);
```

### C
```c
FMOD_RESULT FMOD_System_GetCPUUsage(
  FMOD_SYSTEM *system,
  FMOD_CPU_USAGE *usage
);
```

### C#
```csharp
RESULT System.getCPUUsage(
  out CPU_USAGE usage
);
```

### JavaScript
```javascript
System.getCPUUsage(
  usage
);
```

## system_getdefaultmixmatrix
kind: function
index: 48

### C++
```cpp
FMOD_RESULT System::getDefaultMixMatrix(
  FMOD_SPEAKERMODE sourcespeakermode,
  FMOD_SPEAKERMODE targetspeakermode,
  float *matrix,
  int matrixhop
);
```

### C
```c
FMOD_RESULT FMOD_System_GetDefaultMixMatrix(
  FMOD_SYSTEM *system,
  FMOD_SPEAKERMODE sourcespeakermode,
  FMOD_SPEAKERMODE targetspeakermode,
  float *matrix,
  int matrixhop
);
```

### C#
```csharp
RESULT System.getDefaultMixMatrix(
  SPEAKERMODE sourcespeakermode,
  SPEAKERMODE targetspeakermode,
  float[] matrix,
  int matrixhop
);
```

### JavaScript
```javascript
System.getDefaultMixMatrix(
  sourcespeakermode,
  targetspeakermode,
  matrix,
  matrixhop
);
```

## system_getdriver
kind: function
index: 49

### C++
```cpp
FMOD_RESULT System::getDriver(
  int *driver
);
```

### C
```c
FMOD_RESULT FMOD_System_GetDriver(
  FMOD_SYSTEM *system,
  int *driver
);
```

### C#
```csharp
RESULT System.getDriver(
  out int driver
);
```

### JavaScript
```javascript
System.getDriver(
  driver
);
```

## system_getdriverinfo
kind: function
index: 50

### C++
```cpp
FMOD_RESULT System::getDriverInfo(
  int id,
  char *name,
  int namelen,
  FMOD_GUID *guid,
  int *systemrate,
  FMOD_SPEAKERMODE *speakermode,
  int *speakermodechannels
);
```

### C
```c
FMOD_RESULT FMOD_System_GetDriverInfo(
  FMOD_SYSTEM *system,
  int id,
  char *name,
  int namelen,
  FMOD_GUID *guid,
  int *systemrate,
  FMOD_SPEAKERMODE *speakermode,
  int *speakermodechannels
);
```

### C#
```csharp
RESULT System.getDriverInfo(
  int id,
  out string name,
  int namelen,
  out Guid guid,
  out int systemrate,
  out SPEAKERMODE speakermode,
  out int speakermodechannels
);
```

### JavaScript
```javascript
System.getDriverInfo(
  id,
  name,
  guid,
  systemrate,
  speakermode,
  speakermodechannels
);
```

## system_getdspbuffersize
kind: function
index: 51

### C++
```cpp
FMOD_RESULT System::getDSPBufferSize(
  unsigned int *bufferlength,
  int *numbuffers
);
```

### C
```c
FMOD_RESULT FMOD_System_GetDSPBufferSize(
  FMOD_SYSTEM *system,
  unsigned int *bufferlength,
  int *numbuffers
);
```

### C#
```csharp
RESULT System.getDSPBufferSize(
  out uint bufferlength,
  out int numbuffers
);
```

### JavaScript
```javascript
System.getDSPBufferSize(
  bufferlength,
  numbuffers
);
```

## system_getdspinfobyplugin
kind: function
index: 52

### C++
```cpp
FMOD_RESULT System::getDSPInfoByPlugin(
  unsigned int handle,
  const FMOD_DSP_DESCRIPTION **description
);
```

### C
```c
FMOD_RESULT FMOD_System_GetDSPInfoByPlugin(
  FMOD_SYSTEM *system,
  unsigned int handle,
  const FMOD_DSP_DESCRIPTION **description
);
```

### C#
```csharp
RESULT System.getDSPInfoByPlugin(
  uint handle,
  out IntPtr description
);
```

### JavaScript
```javascript
System.getDSPInfoByPlugin(
  handle,
  description
);
```

## system_getdspinfobytype
kind: function
index: 53

### C++
```cpp
FMOD_RESULT System::getDSPInfoByType(
  FMOD_DSP_TYPE type,
  const FMOD_DSP_DESCRIPTION **description
);
```

### C
```c
FMOD_RESULT FMOD_System_GetDSPInfoByType(
  FMOD_SYSTEM *system,
  FMOD_DSP_TYPE type,
  const FMOD_DSP_DESCRIPTION **description
);
```

### C#
```csharp
RESULT System.getDSPInfoByType(
  DSP_TYPE type,
  out IntPtr description
);
```

### JavaScript
```javascript
System.getDSPInfoByType(
  type,
  description
);
```

## system_getfileusage
kind: function
index: 54

### C++
```cpp
FMOD_RESULT System::getFileUsage(
  long long *sampleBytesRead,
  long long *streamBytesRead,
  long long *otherBytesRead
);
```

### C
```c
FMOD_RESULT FMOD_System_GetFileUsage(
  FMOD_SYSTEM *system,
  long long *sampleBytesRead,
  long long *streamBytesRead,
  long long *otherBytesRead
);
```

### C#
```csharp
RESULT System.getFileUsage(
  out Int64 sampleBytesRead,
  out Int64 streamBytesRead,
  out Int64 otherBytesRead
);
```

### JavaScript
```javascript
System.getFileUsage(
  sampleBytesRead,
  streamBytesRead,
  otherBytesRead
);
```

## system_getgeometryocclusion
kind: function
index: 55

### C++
```cpp
FMOD_RESULT System::getGeometryOcclusion(
  const FMOD_VECTOR *listener,
  const FMOD_VECTOR *source,
  float *direct,
  float *reverb
);
```

### C
```c
FMOD_RESULT FMOD_System_GetGeometryOcclusion(
  FMOD_SYSTEM *system,
  const FMOD_VECTOR *listener,
  const FMOD_VECTOR *source,
  float *direct,
  float *reverb
);
```

### C#
```csharp
RESULT System.getGeometryOcclusion(
  ref VECTOR listener,
  ref VECTOR source,
  out float direct,
  out float reverb
);
```

### JavaScript
```javascript
System.getGeometryOcclusion(
  listener,
  source,
  direct,
  reverb
);
```

## system_getgeometrysettings
kind: function
index: 56

### C++
```cpp
FMOD_RESULT System::getGeometrySettings(
  float *maxworldsize
);
```

### C
```c
FMOD_RESULT FMOD_System_GetGeometrySettings(
  FMOD_SYSTEM *system,
  float *maxworldsize
);
```

### C#
```csharp
RESULT System.getGeometrySettings(
  out float maxworldsize
);
```

### JavaScript
```javascript
System.getGeometrySettings(
  maxworldsize
);
```

## system_getmasterchannelgroup
kind: function
index: 57

### C++
```cpp
FMOD_RESULT System::getMasterChannelGroup(
  ChannelGroup **channelgroup
);
```

### C
```c
FMOD_RESULT FMOD_System_GetMasterChannelGroup(
  FMOD_SYSTEM *system,
  FMOD_CHANNELGROUP **channelgroup
);
```

### C#
```csharp
RESULT System.getMasterChannelGroup(
  out ChannelGroup channelgroup
);
```

### JavaScript
```javascript
System.getMasterChannelGroup(
  channelgroup
);
```

## system_getmastersoundgroup
kind: function
index: 58

### C++
```cpp
FMOD_RESULT System::getMasterSoundGroup(
  SoundGroup **soundgroup
);
```

### C
```c
FMOD_RESULT FMOD_System_GetMasterSoundGroup(
  FMOD_SYSTEM *system,
  FMOD_SOUNDGROUP **soundgroup
);
```

### C#
```csharp
RESULT System.getMasterSoundGroup(
  out SoundGroup soundgroup
);
```

### JavaScript
```javascript
System.getMasterSoundGroup(
  soundgroup
);
```

## system_getnestedplugin
kind: function
index: 59

### C++
```cpp
FMOD_RESULT System::getNestedPlugin(
  unsigned int handle,
  int index,
  unsigned int *nestedhandle
);
```

### C
```c
FMOD_RESULT FMOD_System_GetNestedPlugin(
  FMOD_SYSTEM *system,
  unsigned int handle,
  int index,
  unsigned int *nestedhandle
);
```

### C#
```csharp
RESULT System.getNestedPlugin(
  uint handle,
  int index,
  out uint nestedhandle
);
```

### JavaScript
```javascript
System.getNestedPlugin(
  handle,
  index,
  nestedhandle
);
```

## system_getnetworkproxy
kind: function
index: 60

### C++
```cpp
FMOD_RESULT System::getNetworkProxy(
  char *proxy,
  int proxylen
);
```

### C
```c
FMOD_RESULT FMOD_System_GetNetworkProxy(
  FMOD_SYSTEM *system,
  char *proxy,
  int proxylen
);
```

### C#
```csharp
RESULT System.getNetworkProxy(
  out string proxy,
  int proxylen
);
```

### JavaScript
```javascript
System.getNetworkProxy(
  proxy
);
```

## system_getnetworktimeout
kind: function
index: 61

### C++
```cpp
FMOD_RESULT System::getNetworkTimeout(
  int *timeout
);
```

### C
```c
FMOD_RESULT FMOD_System_GetNetworkTimeout(
  FMOD_SYSTEM *system,
  int *timeout
);
```

### C#
```csharp
RESULT System.getNetworkTimeout(
  out int timeout
);
```

### JavaScript
```javascript
System.getNetworkTimeout(
  timeout
);
```

## system_getnumdrivers
kind: function
index: 62

### C++
```cpp
FMOD_RESULT System::getNumDrivers(
  int *numdrivers
);
```

### C
```c
FMOD_RESULT FMOD_System_GetNumDrivers(
  FMOD_SYSTEM *system,
  int *numdrivers
);
```

### C#
```csharp
RESULT System.getNumDrivers(
  out int numdrivers
);
```

### JavaScript
```javascript
System.getNumDrivers(
  numdrivers
);
```

## system_getnumnestedplugins
kind: function
index: 63

### C++
```cpp
FMOD_RESULT System::getNumNestedPlugins(
  unsigned int handle,
  int *count
);
```

### C
```c
FMOD_RESULT FMOD_System_GetNumNestedPlugins(
  FMOD_SYSTEM *system,
  unsigned int handle,
  int *count
);
```

### C#
```csharp
RESULT System.getNumNestedPlugins(
  uint handle,
  out int count
);
```

### JavaScript
```javascript
System.getNumNestedPlugins(
  handle,
  count
);
```

## system_getnumplugins
kind: function
index: 64

### C++
```cpp
FMOD_RESULT System::getNumPlugins(
  FMOD_PLUGINTYPE plugintype,
  int *numplugins
);
```

### C
```c
FMOD_RESULT FMOD_System_GetNumPlugins(
  FMOD_SYSTEM *system,
  FMOD_PLUGINTYPE plugintype,
  int *numplugins
);
```

### C#
```csharp
RESULT System.getNumPlugins(
  PLUGINTYPE plugintype,
  out int numplugins
);
```

### JavaScript
```javascript
System.getNumPlugins(
  plugintype,
  numplugins
);
```

## system_getoutput
kind: function
index: 65

### C++
```cpp
FMOD_RESULT System::getOutput(
  FMOD_OUTPUTTYPE *output
);
```

### C
```c
FMOD_RESULT FMOD_System_GetOutput(
  FMOD_SYSTEM *system,
  FMOD_OUTPUTTYPE *output
);
```

### C#
```csharp
RESULT System.getOutput(
  out OUTPUTTYPE output
);
```

### JavaScript
```javascript
System.getOutput(
  output
);
```

## system_getoutputbyplugin
kind: function
index: 66

### C++
```cpp
FMOD_RESULT System::getOutputByPlugin(
  unsigned int *handle
);
```

### C
```c
FMOD_RESULT FMOD_System_GetOutputByPlugin(
  FMOD_SYSTEM *system,
  unsigned int *handle
);
```

### C#
```csharp
RESULT System.getOutputByPlugin(
  out uint handle
);
```

### JavaScript
```javascript
System.getOutputByPlugin(
  handle
);
```

## system_getoutputhandle
kind: function
index: 67

### C++
```cpp
FMOD_RESULT System::getOutputHandle(
  void **handle
);
```

### C
```c
FMOD_RESULT FMOD_System_GetOutputHandle(
  FMOD_SYSTEM *system,
  void **handle
);
```

### C#
```csharp
RESULT System.getOutputHandle(
  out IntPtr handle
);
```

### JavaScript
```javascript
System.getOutputHandle(
  handle
);
```

## system_getpluginhandle
kind: function
index: 68

### C++
```cpp
FMOD_RESULT System::getPluginHandle(
  FMOD_PLUGINTYPE plugintype,
  int index,
  unsigned int *handle
);
```

### C
```c
FMOD_RESULT FMOD_System_GetPluginHandle(
  FMOD_SYSTEM *system,
  FMOD_PLUGINTYPE plugintype,
  int index,
  unsigned int *handle
);
```

### C#
```csharp
RESULT System.getPluginHandle(
  PLUGINTYPE plugintype,
  int index,
  out uint handle
);
```

### JavaScript
```javascript
System.getPluginHandle(
  plugintype,
  index,
  handle
);
```

## system_getplugininfo
kind: function
index: 69

### C++
```cpp
FMOD_RESULT System::getPluginInfo(
  unsigned int handle,
  FMOD_PLUGINTYPE *plugintype,
  char *name,
  int namelen,
  unsigned int *version
);
```

### C
```c
FMOD_RESULT FMOD_System_GetPluginInfo(
  FMOD_SYSTEM *system,
  unsigned int handle,
  FMOD_PLUGINTYPE *plugintype,
  char *name,
  int namelen,
  unsigned int *version
);
```

### C#
```csharp
RESULT System.getPluginInfo(
  uint handle,
  out PLUGINTYPE plugintype,
  out string name,
  int namelen,
  out uint version
);
```

### JavaScript
```javascript
System.getPluginInfo(
  handle,
  plugintype,
  name,
  version
);
```

## system_getrecorddriverinfo
kind: function
index: 70

### C++
```cpp
FMOD_RESULT System::getRecordDriverInfo(
  int id,
  char *name,
  int namelen,
  FMOD_GUID *guid,
  int *systemrate,
  FMOD_SPEAKERMODE *speakermode,
  int *speakermodechannels,
  FMOD_DRIVER_STATE *state
);
```

### C
```c
FMOD_RESULT FMOD_System_GetRecordDriverInfo(
  FMOD_SYSTEM *system,
  int id,
  char *name,
  int namelen,
  FMOD_GUID *guid,
  int *systemrate,
  FMOD_SPEAKERMODE *speakermode,
  int *speakermodechannels,
  FMOD_DRIVER_STATE *state
);
```

### C#
```csharp
RESULT System.getRecordDriverInfo(
  int id,
  out string name,
  int namelen,
  out Guid guid,
  out int systemrate,
  out SPEAKERMODE speakermode,
  out int speakermodechannels,
  out DRIVER_STATE state
);
```

### JavaScript
```javascript
System.getRecordDriverInfo(
  id,
  name,
  guid,
  systemrate,
  speakermode,
  speakermodechannels,
  state
);
```

## system_getrecordnumdrivers
kind: function
index: 71

### C++
```cpp
FMOD_RESULT System::getRecordNumDrivers(
  int *numdrivers,
  int *numconnected
);
```

### C
```c
FMOD_RESULT FMOD_System_GetRecordNumDrivers(
  FMOD_SYSTEM *system,
  int *numdrivers,
  int *numconnected
);
```

### C#
```csharp
RESULT System.getRecordNumDrivers(
  out int numdrivers,
  out int numconnected
);
```

### JavaScript
```javascript
System.getRecordNumDrivers(
  numdrivers,
  numconnected
);
```

## system_getrecordposition
kind: function
index: 72

### C++
```cpp
FMOD_RESULT System::getRecordPosition(
  int id,
  unsigned int *position
);
```

### C
```c
FMOD_RESULT FMOD_System_GetRecordPosition(
  FMOD_SYSTEM *system,
  int id,
  unsigned int *position
);
```

### C#
```csharp
RESULT System.getRecordPosition(
  int id,
  out uint position
);
```

### JavaScript
```javascript
System.getRecordPosition(
  id,
  position
);
```

## system_getreverbproperties
kind: function
index: 73

### C++
```cpp
FMOD_RESULT System::getReverbProperties(
  int instance,
  FMOD_REVERB_PROPERTIES *prop
);
```

### C
```c
FMOD_RESULT FMOD_System_GetReverbProperties(
  FMOD_SYSTEM *system,
  int instance,
  FMOD_REVERB_PROPERTIES *prop
);
```

### C#
```csharp
RESULT System.getReverbProperties(
  int instance,
  out REVERB_PROPERTIES prop
);
```

### JavaScript
```javascript
System.getReverbProperties(
  instance,
  prop
);
```

## system_getsoftwarechannels
kind: function
index: 74

### C++
```cpp
FMOD_RESULT System::getSoftwareChannels(
  int *numsoftwarechannels
);
```

### C
```c
FMOD_RESULT FMOD_System_GetSoftwareChannels(
  FMOD_SYSTEM *system,
  int *numsoftwarechannels
);
```

### C#
```csharp
RESULT System.getSoftwareChannels(
  out int numsoftwarechannels
);
```

### JavaScript
```javascript
System.getSoftwareChannels(
  numsoftwarechannels
);
```

## system_getsoftwareformat
kind: function
index: 75

### C++
```cpp
FMOD_RESULT System::getSoftwareFormat(
  int *samplerate,
  FMOD_SPEAKERMODE *speakermode,
  int *numrawspeakers
);
```

### C
```c
FMOD_RESULT FMOD_System_GetSoftwareFormat(
  FMOD_SYSTEM *system,
  int *samplerate,
  FMOD_SPEAKERMODE *speakermode,
  int *numrawspeakers
);
```

### C#
```csharp
RESULT System.getSoftwareFormat(
  out int samplerate,
  out SPEAKERMODE speakermode,
  out int numrawspeakers
);
```

### JavaScript
```javascript
System.getSoftwareFormat(
  samplerate,
  speakermode,
  numrawspeakers
);
```

## system_getspeakermodechannels
kind: function
index: 76

### C++
```cpp
FMOD_RESULT System::getSpeakerModeChannels(
  FMOD_SPEAKERMODE mode,
  int *channels
);
```

### C
```c
FMOD_RESULT FMOD_System_GetSpeakerModeChannels(
  FMOD_SYSTEM *system,
  FMOD_SPEAKERMODE mode,
  int *channels
);
```

### C#
```csharp
RESULT System.getSpeakerModeChannels(
  SPEAKERMODE mode,
  out int channels
);
```

### JavaScript
```javascript
System.getSpeakerModeChannels(
  mode,
  channels
);
```

## system_getspeakerposition
kind: function
index: 77

### C++
```cpp
FMOD_RESULT System::getSpeakerPosition(
  FMOD_SPEAKER speaker,
  float *x,
  float *y,
  bool *active
);
```

### C
```c
FMOD_RESULT FMOD_System_GetSpeakerPosition(
  FMOD_SYSTEM *system,
  FMOD_SPEAKER speaker,
  float *x,
  float *y,
  FMOD_BOOL *active
);
```

### C#
```csharp
RESULT System.getSpeakerPosition(
  SPEAKER speaker,
  out float x,
  out float y,
  out bool active
);
```

### JavaScript
```javascript
System.getSpeakerPosition(
  speaker,
  x,
  y,
  active
);
```

## system_getstreambuffersize
kind: function
index: 78

### C++
```cpp
FMOD_RESULT System::getStreamBufferSize(
  unsigned int *filebuffersize,
  FMOD_TIMEUNIT *filebuffersizetype
);
```

### C
```c
FMOD_RESULT FMOD_System_GetStreamBufferSize(
  FMOD_SYSTEM *system,
  unsigned int *filebuffersize,
  FMOD_TIMEUNIT *filebuffersizetype
);
```

### C#
```csharp
RESULT System.getStreamBufferSize(
  out uint filebuffersize,
  out TIMEUNIT filebuffersizetype
);
```

### JavaScript
```javascript
System.getStreamBufferSize(
  filebuffersize,
  filebuffersizetype
);
```

## system_getuserdata
kind: function
index: 79

### C++
```cpp
FMOD_RESULT System::getUserData(
  void **userdata
);
```

### C
```c
FMOD_RESULT FMOD_System_GetUserData(
  FMOD_SYSTEM *system,
  void **userdata
);
```

### C#
```csharp
RESULT System.getUserData(
  out IntPtr userdata
);
```

### JavaScript
```javascript
System.getUserData(
  userdata
);
```

## system_getversion
kind: function
index: 80

### C++
```cpp
FMOD_RESULT System::getVersion(
  unsigned int *version,
  unsigned int *buildnumber = 0
);
```

### C
```c
FMOD_RESULT FMOD_System_GetVersion(
  FMOD_SYSTEM *system,
  unsigned int *version,
  unsigned int *buildnumber
);
```

### C#
```csharp
RESULT System.getVersion(
  out uint version
);
RESULT System.getVersion(
  out uint version,
  out uint buildnumber
);
```

### JavaScript
```javascript
System.getVersion(
  version,
  buildnumber
);
```

## system_init
kind: function
index: 81

### C++
```cpp
FMOD_RESULT System::init(
  int maxchannels,
  FMOD_INITFLAGS flags,
  void *extradriverdata
);
```

### C
```c
FMOD_RESULT FMOD_System_Init(
  FMOD_SYSTEM *system,
  int maxchannels,
  FMOD_INITFLAGS flags,
  void *extradriverdata
);
```

### C#
```csharp
RESULT System.init(
  int maxchannels,
  INITFLAGS flags,
  IntPtr extradriverdata
);
```

### JavaScript
```javascript
System.init(
  maxchannels,
  flags,
  extradriverdata
);
```

## system_isrecording
kind: function
index: 82

### C++
```cpp
FMOD_RESULT System::isRecording(
  int id,
  bool *recording
);
```

### C
```c
FMOD_RESULT FMOD_System_IsRecording(
  FMOD_SYSTEM *system,
  int id,
  FMOD_BOOL *recording
);
```

### C#
```csharp
RESULT System.isRecording(
  int id,
  out bool recording
);
```

### JavaScript
```javascript
System.isRecording(
  id,
  recording
);
```

## system_loadgeometry
kind: function
index: 83

### C++
```cpp
FMOD_RESULT System::loadGeometry(
  const void *data,
  int datasize,
  Geometry **geometry
);
```

### C
```c
FMOD_RESULT FMOD_System_LoadGeometry(
  FMOD_SYSTEM *system,
  const void *data,
  int datasize,
  FMOD_GEOMETRY **geometry
);
```

### C#
```csharp
RESULT System.loadGeometry(
  IntPtr data,
  int datasize,
  out Geometry geometry
);
```

### JavaScript
```javascript
System.loadGeometry(
  data,
  datasize,
  geometry
);
```

## system_loadplugin
kind: function
index: 84

### C++
```cpp
FMOD_RESULT System::loadPlugin(
  const char *filename,
  unsigned int *handle,
  unsigned int priority = 0
);
```

### C
```c
FMOD_RESULT FMOD_System_LoadPlugin(
  FMOD_SYSTEM *system,
  const char *filename,
  unsigned int *handle,
  unsigned int priority
);
```

### C#
```csharp
RESULT System.loadPlugin(
  string filename,
  out uint handle,
  uint priority = 0
);
```

## system_lockdsp
kind: function
index: 85

### C++
```cpp
FMOD_RESULT System::lockDSP();
```

### C
```c
FMOD_RESULT FMOD_System_LockDSP(FMOD_SYSTEM *system);
```

### C#
```csharp
RESULT System.lockDSP();
```

### JavaScript
```javascript
System.lockDSP();
```

## system_mixerresume
kind: function
index: 86

### C++
```cpp
FMOD_RESULT System::mixerResume();
```

### C
```c
FMOD_RESULT FMOD_System_MixerResume(FMOD_SYSTEM *system);
```

### C#
```csharp
RESULT System.mixerResume();
```

### JavaScript
```javascript
System.mixerResume();
```

## system_mixersuspend
kind: function
index: 87

### C++
```cpp
FMOD_RESULT System::mixerSuspend();
```

### C
```c
FMOD_RESULT FMOD_System_MixerSuspend(FMOD_SYSTEM *system);
```

### C#
```csharp
RESULT System.mixerSuspend();
```

### JavaScript
```javascript
System.mixerSuspend();
```

## system_playdsp
kind: function
index: 88

### C++
```cpp
FMOD_RESULT System::playDSP(
  DSP *dsp,
  ChannelGroup *channelgroup,
  bool paused,
  Channel **channel
);
```

### C
```c
FMOD_RESULT FMOD_System_PlayDSP(
  FMOD_SYSTEM *system,
  FMOD_DSP *dsp,
  FMOD_CHANNELGROUP *channelgroup,
  FMOD_BOOL paused,
  FMOD_CHANNEL **channel
);
```

### C#
```csharp
RESULT System.playDSP(
  DSP dsp,
  ChannelGroup channelgroup,
  bool paused,
  out Channel channel
);
```

### JavaScript
```javascript
System.playDSP(
  dsp,
  channelgroup,
  paused,
  channel
);
```

## system_playsound
kind: function
index: 89

### C++
```cpp
FMOD_RESULT System::playSound(
  Sound *sound,
  ChannelGroup *channelgroup,
  bool paused,
  Channel **channel
);
```

### C
```c
FMOD_RESULT FMOD_System_PlaySound(
  FMOD_SYSTEM *system,
  FMOD_SOUND *sound,
  FMOD_CHANNELGROUP *channelgroup,
  FMOD_BOOL paused,
  FMOD_CHANNEL **channel
);
```

### C#
```csharp
RESULT System.playSound(
  Sound sound,
  ChannelGroup channelgroup,
  bool paused,
  out Channel channel
);
```

### JavaScript
```javascript
System.playSound(
  sound,
  channelgroup,
  paused,
  channel
);
```

## system_recordstart
kind: function
index: 90

### C++
```cpp
FMOD_RESULT System::recordStart(
  int id,
  Sound *sound,
  bool loop
);
```

### C
```c
FMOD_RESULT FMOD_System_RecordStart(
  FMOD_SYSTEM *system,
  int id,
  FMOD_SOUND *sound,
  FMOD_BOOL loop
);
```

### C#
```csharp
RESULT System.recordStart(
  int id,
  Sound sound,
  bool loop
);
```

### JavaScript
```javascript
System.recordStart(
  id,
  sound,
  loop
);
```

## system_recordstop
kind: function
index: 91

### C++
```cpp
FMOD_RESULT System::recordStop(
  int id
);
```

### C
```c
FMOD_RESULT FMOD_System_RecordStop(
  FMOD_SYSTEM *system,
  int id
);
```

### C#
```csharp
RESULT System.recordStop(
  int id
);
```

### JavaScript
```javascript
System.recordStop(
  id
);
```

## system_registercodec
kind: function
index: 92

### C++
```cpp
FMOD_RESULT System::registerCodec(
  FMOD_CODEC_DESCRIPTION *description,
  unsigned int *handle,
  unsigned int priority = 0
);
```

### C
```c
FMOD_RESULT FMOD_System_RegisterCodec(
  FMOD_SYSTEM *system,
  FMOD_CODEC_DESCRIPTION *description,
  unsigned int *handle,
  unsigned int priority
);
```

### JavaScript
```javascript
System.registerCodec(
  description,
  handle,
  priority
);
```

## system_registerdsp
kind: function
index: 93

### C++
```cpp
FMOD_RESULT System::registerDSP(
  const FMOD_DSP_DESCRIPTION *description,
  unsigned int *handle
);
```

### C
```c
FMOD_RESULT FMOD_System_RegisterDSP(
  FMOD_SYSTEM *system,
  const FMOD_DSP_DESCRIPTION *description,
  unsigned int *handle
);
```

### C#
```csharp
RESULT System.registerDSP(
  ref DSP_DESCRIPTION description,
  out uint handle
);
```

### JavaScript
```javascript
System.registerDSP(
  description,
  handle
);
```

## system_registeroutput
kind: function
index: 94

### C++
```cpp
FMOD_RESULT System::registerOutput(
  const FMOD_OUTPUT_DESCRIPTION *description,
  unsigned int *handle
);
```

### C
```c
FMOD_RESULT FMOD_System_RegisterOutput(
  FMOD_SYSTEM *system,
  const FMOD_OUTPUT_DESCRIPTION *description,
  unsigned int *handle
);
```

### JavaScript
```javascript
System.registerOutput(
  description,
  handle
);
```

## system_release
kind: function
index: 95

### C++
```cpp
FMOD_RESULT System::release();
```

### C
```c
FMOD_RESULT FMOD_System_Release(FMOD_SYSTEM *system);
```

### C#
```csharp
RESULT System.release();
```

### JavaScript
```javascript
System.release();
```

## system_set3dlistenerattributes
kind: function
index: 96

### C++
```cpp
FMOD_RESULT System::set3DListenerAttributes(
  int listener,
  const FMOD_VECTOR *pos,
  const FMOD_VECTOR *vel,
  const FMOD_VECTOR *forward,
  const FMOD_VECTOR *up
);
```

### C
```c
FMOD_RESULT FMOD_System_Set3DListenerAttributes(
  FMOD_SYSTEM *system,
  int listener,
  const FMOD_VECTOR *pos,
  const FMOD_VECTOR *vel,
  const FMOD_VECTOR *forward,
  const FMOD_VECTOR *up
);
```

### C#
```csharp
RESULT System.set3DListenerAttributes(
  int listener,
  ref VECTOR pos,
  ref VECTOR vel,
  ref VECTOR forward,
  ref VECTOR up
);
```

### JavaScript
```javascript
System.set3DListenerAttributes(
  listener,
  pos,
  vel,
  forward,
  up
);
```

## system_set3dnumlisteners
kind: function
index: 97

### C++
```cpp
FMOD_RESULT System::set3DNumListeners(
  int numlisteners
);
```

### C
```c
FMOD_RESULT FMOD_System_Set3DNumListeners(
  FMOD_SYSTEM *system,
  int numlisteners
);
```

### C#
```csharp
RESULT System.set3DNumListeners(
  int numlisteners
);
```

### JavaScript
```javascript
System.set3DNumListeners(
  numlisteners
);
```

## system_set3drolloffcallback
kind: function
index: 98

### C++
```cpp
FMOD_RESULT System::set3DRolloffCallback(
  FMOD_3D_ROLLOFF_CALLBACK callback
);
```

### C
```c
FMOD_RESULT FMOD_System_Set3DRolloffCallback(
  FMOD_SYSTEM *system,
  FMOD_3D_ROLLOFF_CALLBACK callback
);
```

### C#
```csharp
RESULT System.set3DRolloffCallback(
  CB_3D_ROLLOFFCALLBACK callback
);
```

## system_set3dsettings
kind: function
index: 99

### C++
```cpp
FMOD_RESULT System::set3DSettings(
  float dopplerscale,
  float distancefactor,
  float rolloffscale
);
```

### C
```c
FMOD_RESULT FMOD_System_Set3DSettings(
  FMOD_SYSTEM *system,
  float dopplerscale,
  float distancefactor,
  float rolloffscale
);
```

### C#
```csharp
RESULT System.set3DSettings(
  float dopplerscale,
  float distancefactor,
  float rolloffscale
);
```

### JavaScript
```javascript
System.set3DSettings(
  dopplerscale,
  distancefactor,
  rolloffscale
);
```

## system_setadvancedsettings
kind: function
index: 100

### C++
```cpp
FMOD_RESULT System::setAdvancedSettings(
  FMOD_ADVANCEDSETTINGS *settings
);
```

### C
```c
FMOD_RESULT FMOD_System_SetAdvancedSettings(
  FMOD_SYSTEM *system,
  FMOD_ADVANCEDSETTINGS *settings
);
```

### C#
```csharp
RESULT System.setAdvancedSettings(
  ref ADVANCEDSETTINGS settings
);
```

### JavaScript
```javascript
System.setAdvancedSettings(
  settings
);
```

## system_setcallback
kind: function
index: 101

### C++
```cpp
FMOD_RESULT System::setCallback(
  FMOD_SYSTEM_CALLBACK callback,
  FMOD_SYSTEM_CALLBACK_TYPE callbackmask = FMOD_SYSTEM_CALLBACK_ALL
);
```

### C
```c
FMOD_RESULT FMOD_System_SetCallback(
  FMOD_SYSTEM *system,
  FMOD_SYSTEM_CALLBACK callback,
  FMOD_SYSTEM_CALLBACK_TYPE callbackmask
);
```

### C#
```csharp
RESULT System.setCallback(
  SYSTEM_CALLBACK callback,
  SYSTEM_CALLBACK_TYPE callbackmask = SYSTEM_CALLBACK_TYPE.ALL
);
```

### JavaScript
```javascript
System.setCallback(
  callback,
  callbackmask
);
```

## system_setdriver
kind: function
index: 102

### C++
```cpp
FMOD_RESULT System::setDriver(
  int driver
);
```

### C
```c
FMOD_RESULT FMOD_System_SetDriver(
  FMOD_SYSTEM *system,
  int driver
);
```

### C#
```csharp
RESULT System.setDriver(
  int driver
);
```

### JavaScript
```javascript
System.setDriver(
  driver
);
```

## system_setdspbuffersize
kind: function
index: 103

### C++
```cpp
FMOD_RESULT System::setDSPBufferSize(
  unsigned int bufferlength,
  int numbuffers
);
```

### C
```c
FMOD_RESULT FMOD_System_SetDSPBufferSize(
  FMOD_SYSTEM *system,
  unsigned int bufferlength,
  int numbuffers
);
```

### C#
```csharp
RESULT System.setDSPBufferSize(
  uint bufferlength,
  int numbuffers
);
```

### JavaScript
```javascript
System.setDSPBufferSize(
  bufferlength,
  numbuffers
);
```

## System::setDSPBufferSize
kind: example
index: 104
heading: System::setDSPBufferSize

### text
```text
FMOD_RESULT result;
unsigned int blocksize;
int numblocks;
float ms;

result = system->getDSPBufferSize(&blocksize, &numblocks);
result = system->getSoftwareFormat(&frequency, 0, 0);

ms = (float)blocksize * 1000.0f / (float)frequency;

printf("Mixer blocksize        = %.02f ms\n", ms);
printf("Mixer Total buffersize = %.02f ms\n", ms * numblocks);
printf("Mixer Average Latency  = %.02f ms\n", ms * ((float)numblocks - 1.5f));
```

## system_setfilesystem
kind: function
index: 105

### C++
```cpp
FMOD_RESULT System::setFileSystem(
  FMOD_FILE_OPEN_CALLBACK useropen,
  FMOD_FILE_CLOSE_CALLBACK userclose,
  FMOD_FILE_READ_CALLBACK userread,
  FMOD_FILE_SEEK_CALLBACK userseek,
  FMOD_FILE_ASYNCREAD_CALLBACK userasyncread,
  FMOD_FILE_ASYNCCANCEL_CALLBACK userasynccancel,
  int blockalign
);
```

### C
```c
FMOD_RESULT FMOD_System_SetFileSystem(
  FMOD_SYSTEM *system,
  FMOD_FILE_OPEN_CALLBACK useropen,
  FMOD_FILE_CLOSE_CALLBACK userclose,
  FMOD_FILE_READ_CALLBACK userread,
  FMOD_FILE_SEEK_CALLBACK userseek,
  FMOD_FILE_ASYNCREAD_CALLBACK userasyncread,
  FMOD_FILE_ASYNCCANCEL_CALLBACK userasynccancel,
  int blockalign
);
```

### C#
```csharp
RESULT System.setFileSystem(
  FILE_OPENCALLBACK useropen,
  FILE_CLOSECALLBACK userclose,
  FILE_READCALLBACK userread,
  FILE_SEEKCALLBACK userseek,
  FILE_ASYNCREADCALLBACK userasyncread,
  FILE_ASYNCCANCELCALLBACK userasynccancel,
  int blockalign
);
```

### JavaScript
```javascript
System.setFileSystem(
  useropen,
  userclose,
  userread,
  userseek,
  userasyncread,
  userasynccancel,
  blockalign
);
```

## system_setgeometrysettings
kind: function
index: 106

### C++
```cpp
FMOD_RESULT System::setGeometrySettings(
  float maxworldsize
);
```

### C
```c
FMOD_RESULT FMOD_System_SetGeometrySettings(
  FMOD_SYSTEM *system,
  float maxworldsize
);
```

### C#
```csharp
RESULT System.setGeometrySettings(
  float maxworldsize
);
```

### JavaScript
```javascript
System.setGeometrySettings(
  maxworldsize
);
```

## system_setnetworkproxy
kind: function
index: 107

### C++
```cpp
FMOD_RESULT System::setNetworkProxy(
  const char *proxy
);
```

### C
```c
FMOD_RESULT FMOD_System_SetNetworkProxy(
  FMOD_SYSTEM *system,
  const char *proxy
);
```

### C#
```csharp
RESULT System.setNetworkProxy(
  string proxy
);
```

### JavaScript
```javascript
System.setNetworkProxy(
  proxy
);
```

## system_setnetworktimeout
kind: function
index: 108

### C++
```cpp
FMOD_RESULT System::setNetworkTimeout(
  int timeout
);
```

### C
```c
FMOD_RESULT FMOD_System_SetNetworkTimeout(
  FMOD_SYSTEM *system,
  int timeout
);
```

### C#
```csharp
RESULT System.setNetworkTimeout(
  int timeout
);
```

### JavaScript
```javascript
System.setNetworkTimeout(
  timeout
);
```

## system_setoutput
kind: function
index: 109

### C++
```cpp
FMOD_RESULT System::setOutput(
  FMOD_OUTPUTTYPE output
);
```

### C
```c
FMOD_RESULT FMOD_System_SetOutput(
  FMOD_SYSTEM *system,
  FMOD_OUTPUTTYPE output
);
```

### C#
```csharp
RESULT System.setOutput(
  OUTPUTTYPE output
);
```

### JavaScript
```javascript
System.setOutput(
  output
);
```

## system_setoutputbyplugin
kind: function
index: 110

### C++
```cpp
FMOD_RESULT System::setOutputByPlugin(
  unsigned int handle
);
```

### C
```c
FMOD_RESULT FMOD_System_SetOutputByPlugin(
  FMOD_SYSTEM *system,
  unsigned int handle
);
```

### C#
```csharp
RESULT System.setOutputByPlugin(
  uint handle
);
```

### JavaScript
```javascript
System.setOutputByPlugin(
  handle
);
```

## system_setpluginpath
kind: function
index: 111

### C++
```cpp
FMOD_RESULT System::setPluginPath(
  const char *path
);
```

### C
```c
FMOD_RESULT FMOD_System_SetPluginPath(
  FMOD_SYSTEM *system,
  const char *path
);
```

### C#
```csharp
RESULT System.setPluginPath(
  string path
);
```

### JavaScript
```javascript
System.setPluginPath(
  path
);
```

## system_setreverbproperties
kind: function
index: 112

### C++
```cpp
FMOD_RESULT System::setReverbProperties(
  int instance,
  const FMOD_REVERB_PROPERTIES *prop
);
```

### C
```c
FMOD_RESULT FMOD_System_SetReverbProperties(
  FMOD_SYSTEM *system,
  int instance,
  const FMOD_REVERB_PROPERTIES *prop
);
```

### C#
```csharp
RESULT System.setReverbProperties(
  int instance,
  ref REVERB_PROPERTIES prop
);
```

### JavaScript
```javascript
System.setReverbProperties(
  instance,
  prop
);
```

## system_setsoftwarechannels
kind: function
index: 113

### C++
```cpp
FMOD_RESULT System::setSoftwareChannels(
  int numsoftwarechannels
);
```

### C
```c
FMOD_RESULT FMOD_System_SetSoftwareChannels(
  FMOD_SYSTEM *system,
  int numsoftwarechannels
);
```

### C#
```csharp
RESULT System.setSoftwareChannels(
  int numsoftwarechannels
);
```

### JavaScript
```javascript
System.setSoftwareChannels(
  numsoftwarechannels
);
```

## system_setsoftwareformat
kind: function
index: 114

### C++
```cpp
FMOD_RESULT System::setSoftwareFormat(
  int samplerate,
  FMOD_SPEAKERMODE speakermode,
  int numrawspeakers
);
```

### C
```c
FMOD_RESULT FMOD_System_SetSoftwareFormat(
  FMOD_SYSTEM *system,
  int samplerate,
  FMOD_SPEAKERMODE speakermode,
  int numrawspeakers
);
```

### C#
```csharp
RESULT System.setSoftwareFormat(
  int samplerate,
  SPEAKERMODE speakermode,
  int numrawspeakers
);
```

### JavaScript
```javascript
System.setSoftwareFormat(
  samplerate,
  speakermode,
  numrawspeakers
);
```

## system_setspeakerposition
kind: function
index: 115

### C++
```cpp
FMOD_RESULT System::setSpeakerPosition(
  FMOD_SPEAKER speaker,
  float x,
  float y,
  bool active
);
```

### C
```c
FMOD_RESULT FMOD_System_SetSpeakerPosition(
  FMOD_SYSTEM *system,
  FMOD_SPEAKER speaker,
  float x,
  float y,
  FMOD_BOOL active
);
```

### C#
```csharp
RESULT System.setSpeakerPosition(
  SPEAKER speaker,
  float x,
  float y,
  bool active
);
```

### JavaScript
```javascript
System.setSpeakerPosition(
  speaker,
  x,
  y,
  active
);
```

## System::setSpeakerPosition
kind: example
index: 116
heading: System::setSpeakerPosition

### C
```c
FMOD_System_SetSpeakerPosition(system, FMOD_SPEAKER_FRONT_LEFT, -1.0f,  0.0f, 1);
FMOD_System_SetSpeakerPosition(system, FMOD_SPEAKER_FRONT_RIGHT, 1.0f,  0.0f, 1);
```

## System::setSpeakerPosition#2
kind: example
index: 117
heading: System::setSpeakerPosition

### C++
```cpp
system->setSpeakerPosition(FMOD_SPEAKER_FRONT_LEFT, -1.0f,  0.0f, true);
system->setSpeakerPosition(FMOD_SPEAKER_FRONT_RIGHT, 1.0f,  0.0f, true);
```

## System::setSpeakerPosition#3
kind: example
index: 118
heading: System::setSpeakerPosition

### C
```c
FMOD_System_SetSpeakerPosition(system, FMOD_SPEAKER_FRONT_LEFT,     sin(degtorad( -30)), cos(degtorad( -30)), 1);
FMOD_System_SetSpeakerPosition(system, FMOD_SPEAKER_FRONT_RIGHT,    sin(degtorad(  30)), cos(degtorad(  30)), 1);
FMOD_System_SetSpeakerPosition(system, FMOD_SPEAKER_FRONT_CENTER,   sin(degtorad(   0)), cos(degtorad(   0)), 1);
FMOD_System_SetSpeakerPosition(system, FMOD_SPEAKER_LOW_FREQUENCY,  sin(degtorad(   0)), cos(degtorad(   0)), 1);
FMOD_System_SetSpeakerPosition(system, FMOD_SPEAKER_SURROUND_LEFT,  sin(degtorad( -90)), cos(degtorad( -90)), 1);
FMOD_System_SetSpeakerPosition(system, FMOD_SPEAKER_SURROUND_RIGHT, sin(degtorad(  90)), cos(degtorad(  90)), 1);
FMOD_System_SetSpeakerPosition(system, FMOD_SPEAKER_BACK_LEFT,      sin(degtorad(-150)), cos(degtorad(-150)), 1);
FMOD_System_SetSpeakerPosition(system, FMOD_SPEAKER_BACK_RIGHT,     sin(degtorad( 150)), cos(degtorad( 150)), 1);
```

## System::setSpeakerPosition#4
kind: example
index: 119
heading: System::setSpeakerPosition

### C++
```cpp
system->setSpeakerPosition(FMOD_SPEAKER_FRONT_LEFT,     sin(degtorad( -30)), cos(degtorad( -30)), true);
system->setSpeakerPosition(FMOD_SPEAKER_FRONT_RIGHT,    sin(degtorad(  30)), cos(degtorad(  30)), true);
system->setSpeakerPosition(FMOD_SPEAKER_FRONT_CENTER,   sin(degtorad(   0)), cos(degtorad(   0)), true);
system->setSpeakerPosition(FMOD_SPEAKER_LOW_FREQUENCY,  sin(degtorad(   0)), cos(degtorad(   0)), true);
system->setSpeakerPosition(FMOD_SPEAKER_SURROUND_LEFT,  sin(degtorad( -90)), cos(degtorad( -90)), true);
system->setSpeakerPosition(FMOD_SPEAKER_SURROUND_RIGHT, sin(degtorad(  90)), cos(degtorad(  90)), true);
system->setSpeakerPosition(FMOD_SPEAKER_BACK_LEFT,      sin(degtorad(-150)), cos(degtorad(-150)), true);
system->setSpeakerPosition(FMOD_SPEAKER_BACK_RIGHT,     sin(degtorad( 150)), cos(degtorad( 150)), true);
```

## system_setstreambuffersize
kind: function
index: 120

### C++
```cpp
FMOD_RESULT System::setStreamBufferSize(
  unsigned int filebuffersize,
  FMOD_TIMEUNIT filebuffersizetype
);
```

### C
```c
FMOD_RESULT FMOD_System_SetStreamBufferSize(
  FMOD_SYSTEM *system,
  unsigned int filebuffersize,
  FMOD_TIMEUNIT filebuffersizetype
);
```

### C#
```csharp
RESULT System.setStreamBufferSize(
  uint filebuffersize,
  TIMEUNIT filebuffersizetype
);
```

### JavaScript
```javascript
System.setStreamBufferSize(
  filebuffersize,
  filebuffersizetype
);
```

## system_setuserdata
kind: function
index: 121

### C++
```cpp
FMOD_RESULT System::setUserData(
  void *userdata
);
```

### C
```c
FMOD_RESULT FMOD_System_SetUserData(
  FMOD_SYSTEM *system,
  void *userdata
);
```

### C#
```csharp
RESULT System.setUserData(
  IntPtr userdata
);
```

### JavaScript
```javascript
System.setUserData(
  userdata
);
```

## system_unloadplugin
kind: function
index: 122

### C++
```cpp
FMOD_RESULT System::unloadPlugin(
  unsigned int handle
);
```

### C
```c
FMOD_RESULT FMOD_System_UnloadPlugin(
  FMOD_SYSTEM *system,
  unsigned int handle
);
```

### C#
```csharp
RESULT System.unloadPlugin(
  uint handle
);
```

### JavaScript
```javascript
System.unloadPlugin(
  handle
);
```

## system_unlockdsp
kind: function
index: 123

### C++
```cpp
FMOD_RESULT System::unlockDSP();
```

### C
```c
FMOD_RESULT FMOD_System_UnlockDSP(FMOD_SYSTEM *system);
```

### C#
```csharp
RESULT System.unlockDSP();
```

### JavaScript
```javascript
System.unlockDSP();
```

## system_update
kind: function
index: 124

### C++
```cpp
FMOD_RESULT System::update();
```

### C
```c
FMOD_RESULT FMOD_System_Update(FMOD_SYSTEM *system);
```

### C#
```csharp
RESULT System.update();
```

### JavaScript
```javascript
System.update();
```

