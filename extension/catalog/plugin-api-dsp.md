# plugin-api-dsp

## FMOD_COMPLEX
kind: example
index: 0
heading: FMOD_COMPLEX
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_COMPLEX {
  float   real;
  float   imag;
} FMOD_COMPLEX;
```

### C#
```csharp
struct COMPLEX
{
  float real;
  float imag;
}
```

### JavaScript
```javascript
FMOD_COMPLEX
{
  real,
  imag,
};
```

## FMOD_DSP_ALLOC_FUNC
kind: example
index: 1
heading: FMOD_DSP_ALLOC_FUNC
tabbed: yes

### C/C++
```cpp
void * F_CALL FMOD_DSP_ALLOC_FUNC(
    unsigned int size,
    FMOD_MEMORY_TYPE type,
    const char *sourcestr
);
```

### C#
```csharp
delegate IntPtr DSP_ALLOC_FUNC(
    uint size,
    MEMORY_TYPE type,
    IntPtr sourcestr
);
```

## FMOD_DSP_BUFFER_ARRAY
kind: example
index: 2
heading: FMOD_DSP_BUFFER_ARRAY
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_DSP_BUFFER_ARRAY {
  int                numbuffers;
  int               *buffernumchannels;
  FMOD_CHANNELMASK   *bufferchannelmask;
  float            **buffers;
  FMOD_SPEAKERMODE   speakermode;
} FMOD_DSP_BUFFER_ARRAY;
```

### C#
```csharp
struct DSP_BUFFER_ARRAY
{
  int           numbuffers;
  int[]         buffernumchannels;
  CHANNELMASK[] bufferchannelmask;
  IntPtr[]      buffers;
  SPEAKERMODE   speakermode;
  int           numchannels;
  IntPtr        buffer;
}
```

## FMOD_DSP_BUFFER_ARRAY#2
kind: example
index: 3
heading: FMOD_DSP_BUFFER_ARRAY

### C/C++
```cpp
int numchannels = outbufferarray[0].buffernumchannels[0];
float *output = outbufferarray[0].buffers[0];

bool pos = false;
int step = 0;
for (unsigned int sample = 0; sample < length; sample++)
{
    for (int channel = 0; channel < numchannels; channel++)
    {
        output[sample * numchannels + channel] = pos ? 1.0f : -1.0f;
    }
    if (step++ % 32 == 0)
    {
        pos = !pos;
    }
}
```

## FMOD_DSP_BUFFER_ARRAY#3
kind: example
index: 4
heading: FMOD_DSP_BUFFER_ARRAY

### C#
```csharp
int numchannels = outbufferarray.numchannels;
float[] output = new float[length * numchannels];

bool pos = false;
int step = 0;
for (int sample = 0; sample < length; sample++)
{
    for (int channel = 0; channel < numchannels; channel++)
    {
        output[sample * numchannels + channel] = pos ? 1.0f : -1.0f;
    }
    if (step++ % 32 == 0)
    {
        pos = !pos;
    }
}

Marshal.Copy(output, 0, outbufferarray.buffer, (int)length * numchannels);
```

## FMOD_DSP_CREATE_CALLBACK
kind: example
index: 5
heading: FMOD_DSP_CREATE_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_DSP_CREATE_CALLBACK(
  FMOD_DSP_STATE *dsp_state
);
```

### C#
```csharp
delegate RESULT DSP_CREATE_CALLBACK(
    ref DSP_STATE dsp_state
);
```

### JavaScript
```javascript
function FMOD_DSP_CREATE_CALLBACK(
    dsp_state
)
```

## FMOD_DSP_DESCRIPTION
kind: example
index: 6
heading: FMOD_DSP_DESCRIPTION
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_DSP_DESCRIPTION {
  unsigned int                          pluginsdkversion;
  char                                  name[32];
  unsigned int                          version;
  int                                   numinputbuffers;
  int                                   numoutputbuffers;
  FMOD_DSP_CREATE_CALLBACK              create;
  FMOD_DSP_RELEASE_CALLBACK             release;
  FMOD_DSP_RESET_CALLBACK               reset;
  FMOD_DSP_READ_CALLBACK                read;
  FMOD_DSP_PROCESS_CALLBACK             process;
  FMOD_DSP_SETPOSITION_CALLBACK         setposition;
  int                                   numparameters;
  FMOD_DSP_PARAMETER_DESC             **paramdesc;
  FMOD_DSP_SETPARAM_FLOAT_CALLBACK      setparameterfloat;
  FMOD_DSP_SETPARAM_INT_CALLBACK        setparameterint;
  FMOD_DSP_SETPARAM_BOOL_CALLBACK       setparameterbool;
  FMOD_DSP_SETPARAM_DATA_CALLBACK       setparameterdata;
  FMOD_DSP_GETPARAM_FLOAT_CALLBACK      getparameterfloat;
  FMOD_DSP_GETPARAM_INT_CALLBACK        getparameterint;
  FMOD_DSP_GETPARAM_BOOL_CALLBACK       getparameterbool;
  FMOD_DSP_GETPARAM_DATA_CALLBACK       getparameterdata;
  FMOD_DSP_SHOULDIPROCESS_CALLBACK      shouldiprocess;
  void                                 *userdata;
  FMOD_DSP_SYSTEM_REGISTER_CALLBACK     sys_register;
  FMOD_DSP_SYSTEM_DEREGISTER_CALLBACK   sys_deregister;
  FMOD_DSP_SYSTEM_MIX_CALLBACK          sys_mix;
} FMOD_DSP_DESCRIPTION;
```

### C#
```csharp
struct DSP_DESCRIPTION
{
  uint                           pluginsdkversion;
  char[]                         name;
  uint                           version;
  int                            numinputbuffers;
  int                            numoutputbuffers;
  DSP_CREATE_CALLBACK            create;
  DSP_RELEASE_CALLBACK           release;
  DSP_RESET_CALLBACK             reset;
  DSP_READ_CALLBACK              read;
  DSP_PROCESS_CALLBACK           process;
  DSP_SETPOSITION_CALLBACK       setposition;
  int                            numparameters;
  IntPtr                         paramdesc;
  DSP_SETPARAM_FLOAT_CALLBACK    setparameterfloat;
  DSP_SETPARAM_INT_CALLBACK      setparameterint;
  DSP_SETPARAM_BOOL_CALLBACK     setparameterbool;
  DSP_SETPARAM_DATA_CALLBACK     setparameterdata;
  DSP_GETPARAM_FLOAT_CALLBACK    getparameterfloat;
  DSP_GETPARAM_INT_CALLBACK      getparameterint;
  DSP_GETPARAM_BOOL_CALLBACK     getparameterbool;
  DSP_GETPARAM_DATA_CALLBACK     getparameterdata;
  DSP_SHOULDIPROCESS_CALLBACK    shouldiprocess;
  IntPtr                         userdata;
  DSP_SYSTEM_REGISTER_CALLBACK   sys_register;
  DSP_SYSTEM_DEREGISTER_CALLBACK sys_deregister;
  DSP_SYSTEM_MIX_CALLBACK        sys_mix;
}
```

### JavaScript
```javascript
FMOD_DSP_DESCRIPTION
{
  pluginsdkversion,
  name,
  version,
  numinputbuffers,
  numoutputbuffers,
  create,
  release,
  reset,
  read,
  process,
  setposition,
  numparameters,
  paramdesc,
  setparameterfloat,
  setparameterint,
  setparameterbool,
  setparameterdata,
  getparameterfloat,
  getparameterint,
  getparameterbool,
  getparameterdata,
  shouldiprocess,
  userdata,
  sys_register,
  sys_deregister,
  sys_mix,
};
```

## FMOD_DSP_DESCRIPTION#2
kind: example
index: 7
heading: FMOD_DSP_DESCRIPTION

### C/C++
```cpp
FMOD_DSP_DESCRIPTION desc = {};
strncpy(desc.name, "My DSP", sizeof(desc.name));
```

## FMOD_DSP_DESCRIPTION#3
kind: example
index: 8
heading: FMOD_DSP_DESCRIPTION

### C#
```csharp
FMOD.DSP_DESCRIPTION desc = new FMOD.DSP_DESCRIPTION();
desc.name = System.Text.Encoding.UTF8.GetBytes("My DSP");
```

## FMOD_DSP_DESCRIPTION#4
kind: example
index: 9
heading: FMOD_DSP_DESCRIPTION

### javaScript
```text
var desc = FMOD.DSP_DESCRIPTION();
desc.name = "My DSP";
```

## FMOD_DSP_DFT_FFTREAL_FUNC
kind: example
index: 10
heading: FMOD_DSP_DFT_FFTREAL_FUNC
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_DSP_DFT_FFTREAL_FUNC(
    FMOD_DSP_STATE *dsp_state,
    int size,
    const float *signal,
    FMOD_COMPLEX* dft,
    const float *window,
    int signalhop
);
```

### C#
```csharp
delegate RESULT DSP_DFT_FFTREAL_FUNC(
    ref DSP_STATE dsp_state,
    int size,
    IntPtr signal,
    IntPtr dft,
    IntPtr window,
    int signalhop
);
```

## FMOD_DSP_DFT_IFFTREAL_FUNC
kind: example
index: 11
heading: FMOD_DSP_DFT_IFFTREAL_FUNC
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_DSP_DFT_IFFTREAL_FUNC(
    FMOD_DSP_STATE *dsp_state,
    int size,
    const FMOD_COMPLEX *dft,
    float* signal,
    const float *window,
    int signalhop
);
```

### C#
```csharp
delegate RESULT DSP_DFT_IFFTREAL_FUNC(
    ref DSP_STATE dsp_state,
    int size,
    IntPtr dft,
    IntPtr signal,
    IntPtr window,
    int signalhop
);
```

## FMOD_DSP_FREE_FUNC
kind: example
index: 12
heading: FMOD_DSP_FREE_FUNC
tabbed: yes

### C/C++
```cpp
void F_CALL FMOD_DSP_FREE_FUNC(
    void *ptr,
    FMOD_MEMORY_TYPE type,
    const char *sourcestr
);
```

### C#
```csharp
delegate IntPtr DSP_FREE_FUNC(
    IntPtr ptr,
    MEMORY_TYPE type,
    IntPtr sourcestr
);
```

## FMOD_DSP_GETBLOCKSIZE_FUNC
kind: example
index: 13
heading: FMOD_DSP_GETBLOCKSIZE_FUNC
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_DSP_GETBLOCKSIZE_FUNC(
    FMOD_DSP_STATE *dsp_state,
    unsigned int *blocksize
);
```

### C#
```csharp
delegate RESULT DSP_GETBLOCKSIZE_FUNC(
    ref DSP_STATE dsp_state,
    ref uint blocksize
);
```

### JavaScript
```javascript
FMOD_DSP_GETBLOCKSIZE_FUNC(
    dsp_state,
    blocksize
)
```

## FMOD_DSP_GETCLOCK_FUNC
kind: example
index: 14
heading: FMOD_DSP_GETCLOCK_FUNC
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_DSP_GETCLOCK_FUNC(
    FMOD_DSP_STATE *dsp_state,
    unsigned long long *clock,
    unsigned int *offset,
    unsigned int *length
);
```

### C#
```csharp
delegate RESULT DSP_GETCLOCK_FUNC(
    ref DSP_STATE dsp_state,
    out ulong clock,
    out uint offset,
    out uint length
);
```

## FMOD_DSP_GETLISTENERATTRIBUTES_FUNC
kind: example
index: 15
heading: FMOD_DSP_GETLISTENERATTRIBUTES_FUNC
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_DSP_GETLISTENERATTRIBUTES_FUNC(
    FMOD_DSP_STATE *dsp_state,
    int *numlisteners,
    FMOD_3D_ATTRIBUTES *attributes
);
```

### C#
```csharp
delegate RESULT DSP_GETLISTENERATTRIBUTES_FUNC(
    ref DSP_STATE dsp_state,
    ref int numlisteners,
    IntPtr attributes
);
```

## FMOD_DSP_GETPARAM_BOOL_CALLBACK
kind: example
index: 16
heading: FMOD_DSP_GETPARAM_BOOL_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_DSP_GETPARAM_BOOL_CALLBACK(
  FMOD_DSP_STATE *dsp_state,
  int index,
  FMOD_BOOL *value,
  char *valuestr
);
```

### C#
```csharp
delegate RESULT DSP_GETPARAM_BOOL_CALLBACK
(
  ref DSP_STATE dsp_state,
  int index,
  ref bool value,
  IntPtr valuestr
);
```

### JavaScript
```javascript
function FMOD_DSP_GETPARAM_BOOL_CALLBACK(
    dsp_state,
    index,
    value,
    valuestr
)
```

## FMOD_DSP_GETPARAM_DATA_CALLBACK
kind: example
index: 17
heading: FMOD_DSP_GETPARAM_DATA_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_DSP_GETPARAM_DATA_CALLBACK(
  FMOD_DSP_STATE *dsp_state,
  int index,
  void **data,
  unsigned int *length,
  char *valuestr
);
```

### C#
```csharp
delegate RESULT DSP_GETPARAM_DATA_CALLBACK
(
  ref DSP_STATE dsp_state,
  int index,
  IntPtr data,
  ref uint length,
  IntPtr valuestr
);
```

### JavaScript
```javascript
function FMOD_DSP_GETPARAM_DATA_CALLBACK(
    dsp_state,
    index,
    data,
    length,
    valuestr
)
```

## FMOD_DSP_GETPARAM_FLOAT_CALLBACK
kind: example
index: 18
heading: FMOD_DSP_GETPARAM_FLOAT_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_DSP_GETPARAM_FLOAT_CALLBACK(
  FMOD_DSP_STATE *dsp_state,
  int index,
  float *value,
  char *valuestr
);
```

### C#
```csharp
delegate RESULT DSP_GETPARAM_FLOAT_CALLBACK
(
  ref DSP_STATE dsp_state,
  int index,
  ref float value,
  IntPtr valuestr
);
```

### JavaScript
```javascript
function FMOD_DSP_GETPARAM_FLOAT_CALLBACK(
    dsp_state,
    index,
    value,
    valuestr
)
```

## FMOD_DSP_GETPARAM_INT_CALLBACK
kind: example
index: 19
heading: FMOD_DSP_GETPARAM_INT_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_DSP_GETPARAM_INT_CALLBACK(
  FMOD_DSP_STATE *dsp_state,
  int index,
  int *value,
  char *valuestr
);
```

### C#
```csharp
delegate RESULT DSP_GETPARAM_INT_CALLBACK
(
  ref DSP_STATE dsp_state,
  int index,
  ref int value,
  IntPtr valuestr
);
```

### JavaScript
```javascript
function FMOD_DSP_GETPARAM_INT_CALLBACK(
    dsp_state,
    index,
    value,
    valuestr
)
```

## FMOD_DSP_GETPARAM_VALUESTR_LENGTH
kind: example
index: 20
heading: FMOD_DSP_GETPARAM_VALUESTR_LENGTH
tabbed: yes

### C/C++
```cpp
#define FMOD_DSP_GETPARAM_VALUESTR_LENGTH   32
```

### JavaScript
```javascript
FMOD.DSP_GETPARAM_VALUESTR_LENGTH = 32
```

## FMOD_DSP_GETSAMPLERATE_FUNC
kind: example
index: 21
heading: FMOD_DSP_GETSAMPLERATE_FUNC
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_DSP_GETSAMPLERATE_FUNC(
    FMOD_DSP_STATE *dsp_state,
    int *rate
);
```

### C#
```csharp
delegate RESULT DSP_GETSAMPLERATE_FUNC(
    ref DSP_STATE dsp_state,
    ref int rate
);
```

### JavaScript
```javascript
FMOD_DSP_GETSAMPLERATE_FUNC(
    dsp_state,
    rate
)
```

## FMOD_DSP_GETSPEAKERMODE_FUNC
kind: example
index: 22
heading: FMOD_DSP_GETSPEAKERMODE_FUNC
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_DSP_GETSPEAKERMODE_FUNC(
    FMOD_DSP_STATE *dsp_state,
    FMOD_SPEAKERMODE *speakermode_mixer,
    FMOD_SPEAKERMODE *speakermode_output
);
```

### C#
```csharp
delegate RESULT DSP_GETSPEAKERMODE_FUNC(
    ref DSP_STATE dsp_state,
    ref int speakermode_mixer,
    ref int speakermode_output
);
```

### JavaScript
```javascript
FMOD_DSP_GETSPEAKERMODE_FUNC(
    dsp_state,
    speakermode_mixer,
    speakermode_output
)
```

## FMOD_DSP_GETUSERDATA_FUNC
kind: example
index: 23
heading: FMOD_DSP_GETUSERDATA_FUNC
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_DSP_GETUSERDATA_FUNC(
    FMOD_DSP_STATE *dsp_state,
    void **userdata
);
```

### C#
```csharp
delegate RESULT DSP_GETUSERDATA_FUNC(
    ref DSP_STATE dsp_state,
    out IntPtr userdata
);
```

## FMOD_DSP_LOG_FUNC
kind: example
index: 24
heading: FMOD_DSP_LOG_FUNC
tabbed: yes

### C/C++
```cpp
void F_CALL FMOD_DSP_LOG_FUNC(
    FMOD_DEBUG_FLAGS level,
    const char *file,
    int line,
    const char *function,
    const char *str,
    ...
);
```

### C#
```csharp
delegate void DSP_LOG_FUNC(
    DEBUG_FLAGS level,
    IntPtr file,
    int line,
    IntPtr function,
    IntPtr str
);
```

## FMOD_DSP_METERING_INFO
kind: example
index: 25
heading: FMOD_DSP_METERING_INFO
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_DSP_METERING_INFO {
  int     numsamples;
  float   peaklevel[32];
  float   rmslevel[32];
  short   numchannels;
} FMOD_DSP_METERING_INFO;
```

### C#
```csharp
struct DSP_METERING_INFO
{
  int     numsamples;
  float[] peaklevel;
  float[] rmslevel;
  short   numchannels;
}
```

### JavaScript
```javascript
FMOD_DSP_METERING_INFO
{
  numsamples,
  peaklevel,
  rmslevel,
  numchannels,
};
```

## FMOD_DSP_PAN_GETROLLOFFGAIN_FUNC
kind: example
index: 26
heading: FMOD_DSP_PAN_GETROLLOFFGAIN_FUNC
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_DSP_PAN_GETROLLOFFGAIN_FUNC(
    FMOD_DSP_STATE *dsp_state,
    FMOD_DSP_PAN_3D_ROLLOFF_TYPE rolloff,
    float distance,
    float mindistance,
    float maxdistance,
    float *gain
);
```

### C#
```csharp
delegate RESULT DSP_PAN_GETROLLOFFGAIN_FUNC(
    ref DSP_STATE dsp_state,
    DSP_PAN_3D_ROLLOFF_TYPE rolloff,
    float distance,
    float mindistance,
    float maxdistance,
    out float gain
);
```

## FMOD_DSP_PAN_SUMMONOMATRIX_FUNC
kind: example
index: 27
heading: FMOD_DSP_PAN_SUMMONOMATRIX_FUNC
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_DSP_PAN_SUMMONOMATRIX_FUNC(
    FMOD_DSP_STATE *dsp_state,
    FMOD_SPEAKERMODE sourceSpeakerMode,
    float lowFrequencyGain,
    float overallGain,
    float *matrix
);
```

### C#
```csharp
delegate RESULT DSP_PAN_SUMMONOMATRIX_FUNC(
    ref DSP_STATE dsp_state,
    int sourceSpeakerMode,
    float lowFrequencyGain,
    float overallGain,
    IntPtr matrix
);
```

## FMOD_DSP_PAN_SUMMONOTOSURROUNDMATRIX_FUNC
kind: example
index: 28
heading: FMOD_DSP_PAN_SUMMONOTOSURROUNDMATRIX_FUNC
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_DSP_PAN_SUMMONOTOSURROUNDMATRIX_FUNC(
    FMOD_DSP_STATE *dsp_state,
    FMOD_SPEAKERMODE targetSpeakerMode,
    float direction,
    float extent,
    float lowFrequencyGain,
    float overallGain,
    int matrixHop,
    float *matrix
);
```

### C#
```csharp
delegate RESULT DSP_PAN_SUMMONOTOSURROUNDMATRIX_FUNC(
    ref DSP_STATE dsp_state,
    int targetSpeakerMode,
    float direction,
    float extent,
    float lowFrequencyGain,
    float overallGain,
    int matrixHop,
    IntPtr matrix
);
```

## FMOD_DSP_PAN_SUMSTEREOMATRIX_FUNC
kind: example
index: 29
heading: FMOD_DSP_PAN_SUMSTEREOMATRIX_FUNC
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_DSP_PAN_SUMSTEREOMATRIX_FUNC(
    FMOD_DSP_STATE *dsp_state,
    FMOD_SPEAKERMODE sourceSpeakerMode,
    float pan,
    float lowFrequencyGain,
    float overallGain,
    int matrixHop,
    float *matrix
);
```

### C#
```csharp
delegate RESULT DSP_PAN_SUMSTEREOMATRIX_FUNC(
    ref DSP_STATE dsp_state,
    int sourceSpeakerMode,
    float pan,
    float lowFrequencyGain,
    float overallGain,
    int matrixHop,
    IntPtr matrix
);
```

## FMOD_DSP_PAN_SUMSTEREOTOSURROUNDMATRIX_FUNC
kind: example
index: 30
heading: FMOD_DSP_PAN_SUMSTEREOTOSURROUNDMATRIX_FUNC
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_DSP_PAN_SUMSTEREOTOSURROUNDMATRIX_FUNC(
    FMOD_DSP_STATE *dsp_state,
     FMOD_SPEAKERMODE targetSpeakerMode,
     float direction,
     float extent,
     float rotation,
     float lowFrequencyGain,
     float overallGain,
     int matrixHop,
     float *matrix
);
```

### C#
```csharp
delegate RESULT DSP_PAN_SUMSTEREOTOSURROUNDMATRIX_FUNC(
    ref DSP_STATE dsp_state,
    int targetSpeakerMode,
    float direction,
    float extent,
    float rotation,
    float lowFrequencyGain,
    float overallGain,
    int matrixHop,
    IntPtr matrix
);
```

## FMOD_DSP_PAN_SUMSURROUNDMATRIX_FUNC
kind: example
index: 31
heading: FMOD_DSP_PAN_SUMSURROUNDMATRIX_FUNC
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_DSP_PAN_SUMSURROUNDMATRIX_FUNC(
    FMOD_DSP_STATE *dsp_state,
    FMOD_SPEAKERMODE sourceSpeakerMode,
    FMOD_SPEAKERMODE targetSpeakerMode,
    float direction,
    float extent,
    float rotation,
    float lowFrequencyGain,
    float overallGain,
    int matrixHop,
    float *matrix,
    FMOD_DSP_PAN_SURROUND_FLAGS flags
);
```

### C#
```csharp
delegate RESULT DSP_PAN_SUMSURROUNDMATRIX_FUNC(
    ref DSP_STATE dsp_state,
    int sourceSpeakerMode,
    int targetSpeakerMode,
    float direction,
    float extent,
    float rotation,
    float lowFrequencyGain,
    float overallGain,
    int matrixHop,
    IntPtr matrix,
    DSP_PAN_SURROUND_FLAGS flags
);
```

## FMOD_DSP_PAN_SURROUND_FLAGS
kind: example
index: 32
heading: FMOD_DSP_PAN_SURROUND_FLAGS
tabbed: yes

### C/C++
```cpp
typedef enum FMOD_DSP_PAN_SURROUND_FLAGS {
  FMOD_DSP_PAN_SURROUND_DEFAULT,
  FMOD_DSP_PAN_SURROUND_ROTATION_NOT_BIASED
} FMOD_DSP_PAN_SURROUND_FLAGS;
```

### C#
```csharp
enum DSP_PAN_SURROUND_FLAGS
{
  DEFAULT,
  ROTATION_NOT_BIASED,
}
```

### JavaScript
```javascript
DSP_PAN_SURROUND_DEFAULT
DSP_PAN_SURROUND_ROTATION_NOT_BIASED
```

## FMOD_DSP_PARAMETER_3DATTRIBUTES
kind: example
index: 33
heading: FMOD_DSP_PARAMETER_3DATTRIBUTES
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_DSP_PARAMETER_3DATTRIBUTES {
  FMOD_3D_ATTRIBUTES   relative;
  FMOD_3D_ATTRIBUTES   absolute;
} FMOD_DSP_PARAMETER_3DATTRIBUTES;
```

### C#
```csharp
struct DSP_PARAMETER_3DATTRIBUTES
{
  _3D_ATTRIBUTES relative;
  _3D_ATTRIBUTES absolute;
}
```

### JavaScript
```javascript
FMOD_DSP_PARAMETER_3DATTRIBUTES
{
  relative,
  absolute,
}
```

## FMOD_DSP_PARAMETER_3DATTRIBUTES_MULTI
kind: example
index: 34
heading: FMOD_DSP_PARAMETER_3DATTRIBUTES_MULTI
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_DSP_PARAMETER_3DATTRIBUTES_MULTI {
  int                  numlisteners;
  FMOD_3D_ATTRIBUTES   relative[FMOD_MAX_LISTENERS];
  float                weight[FMOD_MAX_LISTENERS];
  FMOD_3D_ATTRIBUTES   absolute;
} FMOD_DSP_PARAMETER_3DATTRIBUTES_MULTI;
```

### C#
```csharp
struct DSP_PARAMETER_3DATTRIBUTES_MULTI
{
  int               numlisteners;
  _3D_ATTRIBUTES[]  relative;
  float[]           weight;
  _3D_ATTRIBUTES    absolute;
}
```

### JavaScript
```javascript
FMOD_DSP_PARAMETER_3DATTRIBUTES_MULTI
{
  numlisteners,
};
```

## FMOD_DSP_PARAMETER_ATTENUATION_RANGE
kind: example
index: 35
heading: FMOD_DSP_PARAMETER_ATTENUATION_RANGE
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_DSP_PARAMETER_ATTENUATION_RANGE {
  float   min;
  float   max;
} FMOD_DSP_PARAMETER_ATTENUATION_RANGE;
```

### C#
```csharp
struct DSP_PARAMETER_ATTENUATION_RANGE
{
  float min;
  float max;
}
```

### JavaScript
```javascript
FMOD_DSP_PARAMETER_ATTENUATION_RANGE
{
  min,
  max,
};
```

## FMOD_DSP_PARAMETER_DATA_TYPE
kind: example
index: 36
heading: FMOD_DSP_PARAMETER_DATA_TYPE
tabbed: yes

### C/C++
```cpp
typedef enum FMOD_DSP_PARAMETER_DATA_TYPE {
  FMOD_DSP_PARAMETER_DATA_TYPE_USER = 0,
  FMOD_DSP_PARAMETER_DATA_TYPE_OVERALLGAIN = -1,
  FMOD_DSP_PARAMETER_DATA_TYPE_3DATTRIBUTES = -2,
  FMOD_DSP_PARAMETER_DATA_TYPE_SIDECHAIN = -3,
  FMOD_DSP_PARAMETER_DATA_TYPE_FFT = -4,
  FMOD_DSP_PARAMETER_DATA_TYPE_3DATTRIBUTES_MULTI = -5,
  FMOD_DSP_PARAMETER_DATA_TYPE_ATTENUATION_RANGE = -6,
  FMOD_DSP_PARAMETER_DATA_TYPE_DYNAMIC_RESPONSE = -7,
  FMOD_DSP_PARAMETER_DATA_TYPE_FINITE_LENGTH = -8
} FMOD_DSP_PARAMETER_DATA_TYPE;
```

### C#
```csharp
enum DSP_PARAMETER_DATA_TYPE
{
  DSP_PARAMETER_DATA_TYPE_USER = 0,
  DSP_PARAMETER_DATA_TYPE_OVERALLGAIN = -1,
  DSP_PARAMETER_DATA_TYPE_3DATTRIBUTES = -2,
  DSP_PARAMETER_DATA_TYPE_SIDECHAIN = -3,
  DSP_PARAMETER_DATA_TYPE_FFT = -4,
  DSP_PARAMETER_DATA_TYPE_3DATTRIBUTES_MULTI = -5,
  DSP_PARAMETER_DATA_TYPE_ATTENUATION_RANGE = -6,
  DSP_PARAMETER_DATA_TYPE_DYNAMIC_RESPONSE = -7,
  DSP_PARAMETER_DATA_TYPE_FINITE_LENGTH = -8
}
```

### JavaScript
```javascript
FMOD.DSP_PARAMETER_DATA_TYPE_USER = 0
FMOD.DSP_PARAMETER_DATA_TYPE_OVERALLGAIN = -1
FMOD.DSP_PARAMETER_DATA_TYPE_3DATTRIBUTES = -2
FMOD.DSP_PARAMETER_DATA_TYPE_SIDECHAIN = -3
FMOD.DSP_PARAMETER_DATA_TYPE_FFT = -4
FMOD.DSP_PARAMETER_DATA_TYPE_3DATTRIBUTES_MULTI = -5
FMOD.DSP_PARAMETER_DATA_TYPE_ATTENUATION_RANGE = -6,
FMOD.DSP_PARAMETER_DATA_TYPE_DYNAMIC_RESPONSE = -7
FMOD.DSP_PARAMETER_DATA_TYPE_FINITE_LENGTH = -8
```

## FMOD_DSP_PARAMETER_DESC
kind: example
index: 37
heading: FMOD_DSP_PARAMETER_DESC
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_DSP_PARAMETER_DESC {
  FMOD_DSP_PARAMETER_TYPE         type;
  char                            name[16];
  char                            label[16];
  const char                     *description;
  union
  {
      FMOD_DSP_PARAMETER_DESC_FLOAT   floatdesc;
      FMOD_DSP_PARAMETER_DESC_INT     intdesc;
      FMOD_DSP_PARAMETER_DESC_BOOL    booldesc;
      FMOD_DSP_PARAMETER_DESC_DATA    datadesc;
  }
} FMOD_DSP_PARAMETER_DESC;
```

### C#
```csharp
struct DSP_PARAMETER_DESC
{
  DSP_PARAMETER_TYPE         type;
  char[]                     name;
  char[]                     label;
  string                     description;
  DSP_PARAMETER_DESC_UNION   desc;
}
```

### JavaScript
```javascript
FMOD_DSP_PARAMETER_DESC
{
  type,
  name,
  label,
  description,
};
```

## FMOD_DSP_PARAMETER_DESC_BOOL
kind: example
index: 38
heading: FMOD_DSP_PARAMETER_DESC_BOOL
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_DSP_PARAMETER_DESC_BOOL {
  FMOD_BOOL            defaultval;
  const char* const*   valuenames;
} FMOD_DSP_PARAMETER_DESC_BOOL;
```

### C#
```csharp
struct DSP_PARAMETER_DESC_BOOL
{
  bool      defaultval;
  IntPtr    valuenames;
}
```

### JavaScript
```javascript
FMOD_DSP_PARAMETER_DESC_BOOL
{
  defaultval,
};
```

## FMOD_DSP_PARAMETER_DESC_DATA
kind: example
index: 39
heading: FMOD_DSP_PARAMETER_DESC_DATA
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_DSP_PARAMETER_DESC_DATA {
  int   datatype;
} FMOD_DSP_PARAMETER_DESC_DATA;
```

### C#
```csharp
struct DSP_PARAMETER_DESC_DATA
{
  int   datatype;
}
```

### JavaScript
```javascript
FMOD_DSP_PARAMETER_DESC_DATA
{
  datatype,
};
```

## FMOD_DSP_PARAMETER_DESC_FLOAT
kind: example
index: 40
heading: FMOD_DSP_PARAMETER_DESC_FLOAT
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_DSP_PARAMETER_DESC_FLOAT {
  float                              min;
  float                              max;
  float                              defaultval;
  FMOD_DSP_PARAMETER_FLOAT_MAPPING   mapping;
} FMOD_DSP_PARAMETER_DESC_FLOAT;
```

### C#
```csharp
struct DSP_PARAMETER_DESC_FLOAT
{
  float                       min;
  float                       max;
  float                       defaultval;
  DSP_PARAMETER_FLOAT_MAPPING mapping;
}
```

### JavaScript
```javascript
FMOD_DSP_PARAMETER_DESC_FLOAT
{
  min,
  max,
  defaultval,
};
```

## FMOD_DSP_PARAMETER_DESC_INT
kind: example
index: 41
heading: FMOD_DSP_PARAMETER_DESC_INT
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_DSP_PARAMETER_DESC_INT {
  int                  min;
  int                  max;
  int                  defaultval;
  FMOD_BOOL            goestoinf;
  const char* const*   valuenames;
} FMOD_DSP_PARAMETER_DESC_INT;
```

### C#
```csharp
struct DSP_PARAMETER_DESC_INT
{
  int    min;
  int    max;
  int    defaultval;
  bool   goestoinf;
  IntPtr valuenames;
}
```

### JavaScript
```javascript
FMOD_DSP_PARAMETER_DESC_INT
{
  min,
  max,
  defaultval,
  goestoinf,
};
```

## FMOD_DSP_PARAMETER_DYNAMIC_RESPONSE
kind: example
index: 42
heading: FMOD_DSP_PARAMETER_DYNAMIC_RESPONSE
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_DSP_PARAMETER_DYNAMIC_RESPONSE {
  int     numchannels;
  float   rms[32];
} FMOD_DSP_PARAMETER_DYNAMIC_RESPONSE;
```

### C#
```csharp
struct DSP_PARAMETER_DYNAMIC_RESPONSE
{
  int numchannels;
  float[] rms;
}
```

### JavaScript
```javascript
DSP_PARAMETER_DYNAMIC_RESPONSE
{
  numchannels,
  rms,
}
```

## FMOD_DSP_PARAMETER_FFT
kind: example
index: 43
heading: FMOD_DSP_PARAMETER_FFT
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_DSP_PARAMETER_FFT {
  int     length;
  int     numchannels;
  float   *spectrum[32];
} FMOD_DSP_PARAMETER_FFT;
```

### C#
```csharp
struct DSP_PARAMETER_FFT
{
  int       length;
  int       numchannels;
  float[][] spectrum;
  void getSpectrum(ref float[][] buffer);
  void getSpectrum(int channel, ref float[] buffer);
}
```

### JavaScript
```javascript
FMOD_DSP_PARAMETER_FFT
{
  length,
  numchannels,
  spectrum
};
```

## FMOD_DSP_PARAMETER_FINITE_LENGTH
kind: example
index: 44
heading: FMOD_DSP_PARAMETER_FINITE_LENGTH
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_DSP_PARAMETER_FINITE_LENGTH
{
  FMOD_BOOL finite;
} FMOD_DSP_PARAMETER_FINITE_LENGTH;
```

### C#
```csharp
struct DSP_PARAMETER_FINITE_LENGTH
{
  int finite;
}
```

### JavaScript
```javascript
DSP_PARAMETER_FINITE_LENGTH
{
  finite,
}
```

## FMOD_DSP_PARAMETER_FLOAT_MAPPING
kind: example
index: 45
heading: FMOD_DSP_PARAMETER_FLOAT_MAPPING
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_DSP_PARAMETER_FLOAT_MAPPING {
  FMOD_DSP_PARAMETER_FLOAT_MAPPING_TYPE               type;
  FMOD_DSP_PARAMETER_FLOAT_MAPPING_PIECEWISE_LINEAR   piecewiselinearmapping;
} FMOD_DSP_PARAMETER_FLOAT_MAPPING;
```

### C#
```csharp
struct DSP_PARAMETER_FLOAT_MAPPING
{
  DSP_PARAMETER_FLOAT_MAPPING_TYPE type;
  DSP_PARAMETER_FLOAT_MAPPING_PIECEWISE_LINEAR piecewiselinearmapping;
}
```

### JavaScript
```javascript
FMOD_DSP_PARAMETER_FLOAT_MAPPING
{
  type,
  piecewiselinearmapping
};
```

## FMOD_DSP_PARAMETER_FLOAT_MAPPING_PIECEWISE_LINEAR
kind: example
index: 46
heading: FMOD_DSP_PARAMETER_FLOAT_MAPPING_PIECEWISE_LINEAR
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_DSP_PARAMETER_FLOAT_MAPPING_PIECEWISE_LINEAR {
  int     numpoints;
  float   *pointparamvalues;
  float   *pointpositions;
} FMOD_DSP_PARAMETER_FLOAT_MAPPING_PIECEWISE_LINEAR;
```

### C#
```csharp
struct DSP_PARAMETER_FLOAT_MAPPING_PIECEWISE_LINEAR
{
  int numpoints;
  IntPtr pointparamvalues;
  IntPtr pointpositions;
}
```

### JavaScript
```javascript
FMOD_DSP_PARAMETER_FLOAT_MAPPING_PIECEWISE_LINEAR
{
  numpoints,
};
```

## FMOD_DSP_PARAMETER_FLOAT_MAPPING_TYPE
kind: example
index: 47
heading: FMOD_DSP_PARAMETER_FLOAT_MAPPING_TYPE
tabbed: yes

### C/C++
```cpp
typedef enum FMOD_DSP_PARAMETER_FLOAT_MAPPING_TYPE {
  FMOD_DSP_PARAMETER_FLOAT_MAPPING_TYPE_LINEAR,
  FMOD_DSP_PARAMETER_FLOAT_MAPPING_TYPE_AUTO,
  FMOD_DSP_PARAMETER_FLOAT_MAPPING_TYPE_PIECEWISE_LINEAR
} FMOD_DSP_PARAMETER_FLOAT_MAPPING_TYPE;
```

### C#
```csharp
enum DSP_PARAMETER_FLOAT_MAPPING_TYPE
{
  DSP_PARAMETER_FLOAT_MAPPING_TYPE_LINEAR = 0,
  DSP_PARAMETER_FLOAT_MAPPING_TYPE_AUTO,
  DSP_PARAMETER_FLOAT_MAPPING_TYPE_PIECEWISE_LINEAR,
}
```

### JavaScript
```javascript
FMOD.DSP_PARAMETER_FLOAT_MAPPING_TYPE_LINEAR
FMOD.DSP_PARAMETER_FLOAT_MAPPING_TYPE_AUTO
FMOD.DSP_PARAMETER_FLOAT_MAPPING_TYPE_PIECEWISE_LINEAR
```

## FMOD_DSP_PARAMETER_OVERALLGAIN
kind: example
index: 48
heading: FMOD_DSP_PARAMETER_OVERALLGAIN
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_DSP_PARAMETER_OVERALLGAIN {
  float   linear_gain;
  float   linear_gain_additive;
} FMOD_DSP_PARAMETER_OVERALLGAIN;
```

### C#
```csharp
struct DSP_PARAMETER_OVERALLGAIN
{
  float linear_gain;
  float linear_gain_additive;
}
```

### JavaScript
```javascript
FMOD_DSP_PARAMETER_OVERALLGAIN
{
  linear_gain,
  linear_gain_additive,
};
```

## FMOD_DSP_PARAMETER_SIDECHAIN
kind: example
index: 49
heading: FMOD_DSP_PARAMETER_SIDECHAIN
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_DSP_PARAMETER_SIDECHAIN {
  FMOD_BOOL   sidechainenable;
} FMOD_DSP_PARAMETER_SIDECHAIN;
```

### C#
```csharp
struct DSP_PARAMETER_SIDECHAIN
{
  int sidechainenable;
}
```

### JavaScript
```javascript
FMOD_DSP_PARAMETER_SIDECHAIN
{
  sidechainenable,
};
```

## FMOD_DSP_PARAMETER_TYPE
kind: example
index: 50
heading: FMOD_DSP_PARAMETER_TYPE
tabbed: yes

### C/C++
```cpp
typedef enum FMOD_DSP_PARAMETER_TYPE {
  FMOD_DSP_PARAMETER_TYPE_FLOAT,
  FMOD_DSP_PARAMETER_TYPE_INT,
  FMOD_DSP_PARAMETER_TYPE_BOOL,
  FMOD_DSP_PARAMETER_TYPE_DATA,
  FMOD_DSP_PARAMETER_TYPE_MAX
} FMOD_DSP_PARAMETER_TYPE;
```

### C#
```csharp
enum DSP_PARAMETER_TYPE
{
  FLOAT = 0,
  INT,
  BOOL,
  DATA,
  MAX
}
```

### JavaScript
```javascript
FMOD.DSP_PARAMETER_TYPE_FLOAT
FMOD.DSP_PARAMETER_TYPE_INT
FMOD.DSP_PARAMETER_TYPE_BOOL
FMOD.DSP_PARAMETER_TYPE_DATA
FMOD.DSP_PARAMETER_TYPE_MAX
```

## FMOD_DSP_PROCESS_CALLBACK
kind: example
index: 51
heading: FMOD_DSP_PROCESS_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_DSP_PROCESS_CALLBACK(
  FMOD_DSP_STATE *dsp_state,
  unsigned int length,
  const FMOD_DSP_BUFFER_ARRAY *inbufferarray,
  FMOD_DSP_BUFFER_ARRAY *outbufferarray,
  FMOD_BOOL inputsidle,
  FMOD_DSP_PROCESS_OPERATION op
);
```

### C#
```csharp
delegate RESULT DSP_PROCESS_CALLBACK
(
  ref DSP_STATE dsp_state,
  uint length,
  ref DSP_BUFFER_ARRAY inbufferarray,
  ref DSP_BUFFER_ARRAY outbufferarray,
  bool inputsidle,
  DSP_PROCESS_OPERATION op
);
```

## FMOD_DSP_PROCESS_CALLBACK#2
kind: example
index: 52
heading: FMOD_DSP_PROCESS_CALLBACK

### C/C++
```cpp
FMOD_RESULT F_CALL Process(FMOD_DSP_STATE *dsp_state, unsigned int length, const FMOD_DSP_BUFFER_ARRAY *inbufferarray, FMOD_DSP_BUFFER_ARRAY *outbufferarray, FMOD_BOOL inputsidle, FMOD_DSP_PROCESS_OPERATION op)
{
    if (op == FMOD_DSP_PROCESS_QUERY)
    {
        if (outbufferarray && inbufferarray)
        {
            if (outbufferarray[0].buffernumchannels[0] != inbufferarray[0].buffernumchannels[0])
            {
                FMOD_ERR_DSP_SILENCE;
            }
        }
        if (inputsidle)
        {
            return FMOD_ERR_DSP_DONTPROCESS;
        }
    }
    else
    {
        int numchannels = outbufferarray[0].buffernumchannels[0];
        float *input = inbufferarray[0].buffers[0];
        float *output = outbufferarray[0].buffers[0];

        for (unsigned int sample = 0; sample < length; sample++)
        {
            for (int channel = 0; channel < numchannels; channel++)
            {
                output[sample * numchannels + channel] = input[sample * numchannels + channel] * 0.5f;
            }
        }
    }

    return FMOD_OK;
}
```

## FMOD_DSP_PROCESS_CALLBACK#3
kind: example
index: 53
heading: FMOD_DSP_PROCESS_CALLBACK

### C#
```csharp
[AOT.MonoPInvokeCallback(typeof(FMOD.DSP_PROCESS_CALLBACK))]
static RESULT Process(ref DSP_STATE dsp_state, uint length, ref DSP_BUFFER_ARRAY inbufferarray, ref DSP_BUFFER_ARRAY outbufferarray, bool inputsidle, DSP_PROCESS_OPERATION op)
{
    if (op == DSP_PROCESS_OPERATION.PROCESS_QUERY)
    {
        if (inbufferarray.numchannels != outbufferarray.numchannels)
        {
            return RESULT.ERR_DSP_SILENCE;
        }
        if (inputsidle)
        {
            return RESULT.ERR_DSP_DONTPROCESS;
        }
    }
    else if (op == DSP_PROCESS_OPERATION.PROCESS_PERFORM)
    {
        int numchannels = outbufferarray.numchannels;
        float[] input = new float[length * numchannels];
        float[] output = new float[length * numchannels];

        Marshal.Copy(inbufferarray.buffer, input, 0, (int)length * numchannels);

        for (int sample = 0; sample < length; sample++)
        {
            for (int channel = 0; channel < numchannels; channel++)
            {
                output[sample * numchannels + channel] = input[sample * numchannels + channel] * 0.5f;
            }
        }

        Marshal.Copy(output, 0, outbufferarray.buffer, (int)length * numchannels);
    }

    return RESULT.OK;
}
```

## FMOD_DSP_PROCESS_OPERATION
kind: example
index: 54
heading: FMOD_DSP_PROCESS_OPERATION
tabbed: yes

### C/C++
```cpp
typedef enum FMOD_DSP_PROCESS_OPERATION {
  FMOD_DSP_PROCESS_PERFORM,
  FMOD_DSP_PROCESS_QUERY
} FMOD_DSP_PROCESS_OPERATION;
```

### C#
```csharp
enum DSP_PROCESS_OPERATION
{
  PROCESS_PERFORM = 0,
  PROCESS_QUERY
}
```

## FMOD_DSP_READ_CALLBACK
kind: example
index: 55
heading: FMOD_DSP_READ_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_DSP_READ_CALLBACK(
  FMOD_DSP_STATE *dsp_state,
  float *inbuffer,
  float *outbuffer,
  unsigned int length,
  int inchannels,
  int *outchannels
);
```

### C#
```csharp
delegate RESULT DSP_READ_CALLBACK
(
  ref DSP_STATE dsp_state,
  IntPtr inbuffer,
  IntPtr outbuffer,
  uint length,
  int inchannels,
  ref int outchannels
);
```

### JavaScript
```javascript
function FMOD_DSP_READ_CALLBACK(
    dsp_state,
    inbuffer,
    outbuffer,
    length,
    inchannels,
    outchannels
)
```

## FMOD_DSP_READ_CALLBACK#2
kind: example
index: 56
heading: FMOD_DSP_READ_CALLBACK

### C/C++
```cpp
FMOD_RESULT F_CALL Read(FMOD_DSP_STATE *dsp_state, float *inbuffer, float *outbuffer, unsigned int length, int inchannels, int *outchannels)
{
    for (unsigned int sample = 0; sample < length; sample++)
    {
        for (int channel = 0; channel < inchannels; channel++)
        {
            outbuffer[sample * *outchannels + channel] = inbuffer[sample * inchannels + channel] * 0.5f;
        }
    }

    return FMOD_OK;
}
```

## FMOD_DSP_READ_CALLBACK#3
kind: example
index: 57
heading: FMOD_DSP_READ_CALLBACK

### C#
```csharp
[AOT.MonoPInvokeCallback(typeof(FMOD.DSP_READ_CALLBACK))]
static RESULT Read(ref DSP_STATE dsp_state, IntPtr inbuffer, IntPtr outbuffer, uint length, int inchannels, ref int outchannels)
{
    float[] input = new float[length * inchannels];
    float[] output = new float[length * outchannels];

    Marshal.Copy(inbuffer, input, 0, (int)length * inchannels);

    for (int sample = 0; sample < length; sample++)
    {
        for (int channel = 0; channel < outchannels; channel++)
        {
            output[sample * outchannels + channel] = input[sample * outchannels + channel] * 0.5f;
        }
    }

    Marshal.Copy(output, 0, outbuffer, (int)length * outchannels);

    return RESULT.OK;
}
```

## FMOD_DSP_READ_CALLBACK#4
kind: example
index: 58
heading: FMOD_DSP_READ_CALLBACK

### JavaScript
```javascript
function Read(dsp_state, inbuffer, outbuffer, length, inchannels, outchannels)
{
    for (var sample = 0; sample < length; sample++)
    {
        for (var channel = 0; channel < outchannels; channel++)
        {
            let val = FMOD.getValue(inbuffer + (((sample * inchannels) + channel) * 4), 'float') * 0.5;

            FMOD.setValue(outbuffer + (((sample * outchannels) + channel) * 4), val, 'float');
            dsp_state.plugindata.buffer[(sample * outchannels) + channel] = val;
        }
    }

    return FMOD.OK;
}
```

## FMOD_DSP_REALLOC_FUNC
kind: example
index: 59
heading: FMOD_DSP_REALLOC_FUNC
tabbed: yes

### C/C++
```cpp
void * F_CALL FMOD_DSP_REALLOC_FUNC(
    void *ptr,
    unsigned int size,
    FMOD_MEMORY_TYPE type,
    const char *sourcestr
);
```

### C#
```csharp
delegate IntPtr DSP_REALLOC_FUNC(
    IntPtr ptr,
    uint size,
    MEMORY_TYPE type,
    IntPtr sourcestr
);
```

## FMOD_DSP_RELEASE_CALLBACK
kind: example
index: 60
heading: FMOD_DSP_RELEASE_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_DSP_RELEASE_CALLBACK(
  FMOD_DSP_STATE *dsp_state
);
```

### C#
```csharp
delegate RESULT DSP_RELEASE_CALLBACK
(
  ref DSP_STATE dsp_state
);
```

### JavaScript
```javascript
function FMOD_DSP_RELEASE_CALLBACK(
    dsp_state,
)
```

## FMOD_DSP_RESET_CALLBACK
kind: example
index: 61
heading: FMOD_DSP_RESET_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_DSP_RESET_CALLBACK(
  FMOD_DSP_STATE *dsp_state
);
```

### C#
```csharp
delegate RESULT DSP_RESET_CALLBACK
(
  ref DSP_STATE dsp_state
)
```

### JavaScript
```javascript
function FMOD_DSP_RESET_CALLBACK(
    dsp_state,
)
```

## FMOD_DSP_SETPARAM_BOOL_CALLBACK
kind: example
index: 62
heading: FMOD_DSP_SETPARAM_BOOL_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_DSP_SETPARAM_BOOL_CALLBACK(
  FMOD_DSP_STATE *dsp_state,
  int index,
  FMOD_BOOL value
);
```

### C#
```csharp
delegate RESULT DSP_SETPARAM_BOOL_CALLBACK
(
  ref DSP_STATE dsp_state,
  int index,
  bool value
);
```

### JavaScript
```javascript
function FMOD_DSP_SETPARAM_BOOL_CALLBACK(
    dsp_state,
    index,
    value
)
```

## FMOD_DSP_SETPARAM_DATA_CALLBACK
kind: example
index: 63
heading: FMOD_DSP_SETPARAM_DATA_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_DSP_SETPARAM_DATA_CALLBACK(
  FMOD_DSP_STATE *dsp_state,
  int index,
  void *data,
  unsigned int length
);
```

### C#
```csharp
delegate RESULT DSP_SETPARAM_DATA_CALLBACK
(
  ref DSP_STATE dsp_state,
  int index,
  IntPtr data,
  uint length
);
```

### JavaScript
```javascript
function FMOD_DSP_SETPARAM_DATA_CALLBACK(
    dsp_state,
    index,
    data,
    length
)
```

## FMOD_DSP_SETPARAM_FLOAT_CALLBACK
kind: example
index: 64
heading: FMOD_DSP_SETPARAM_FLOAT_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_DSP_SETPARAM_FLOAT_CALLBACK(
  FMOD_DSP_STATE *dsp_state,
  int index,
  float value
);
```

### C#
```csharp
delegate RESULT DSP_SETPARAM_FLOAT_CALLBACK
(
  ref DSP_STATE dsp_state,
  int index,
  ref float value
);
```

### JavaScript
```javascript
function FMOD_DSP_SETPARAM_FLOAT_CALLBACK(
    dsp_state,
    index,
    value
)
```

## FMOD_DSP_SETPARAM_INT_CALLBACK
kind: example
index: 65
heading: FMOD_DSP_SETPARAM_INT_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_DSP_SETPARAM_INT_CALLBACK(
  FMOD_DSP_STATE *dsp_state,
  int index,
  int value
);
```

### C#
```csharp
delegate RESULT DSP_SETPARAM_INT_CALLBACK
(
  ref DSP_STATE dsp_state,
  int index,
  int value
);
```

### JavaScript
```javascript
function FMOD_DSP_SETPARAM_INT_CALLBACK(
    dsp_state,
    index,
    value
)
```

## FMOD_DSP_SETPOSITION_CALLBACK
kind: example
index: 66
heading: FMOD_DSP_SETPOSITION_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_DSP_SETPOSITION_CALLBACK(
  FMOD_DSP_STATE *dsp_state,
  unsigned int pos
);
```

### C#
```csharp
delegate RESULT DSP_SETPOSITION_CALLBACK
(
  ref DSP_STATE dsp_state,
  uint pos
);
```

### JavaScript
```javascript
function FMOD_DSP_SETPOSITION_CALLBACK(
    dsp_state,
    pos
)
```

## FMOD_DSP_SHOULDIPROCESS_CALLBACK
kind: example
index: 67
heading: FMOD_DSP_SHOULDIPROCESS_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_DSP_SHOULDIPROCESS_CALLBACK(
  FMOD_DSP_STATE *dsp_state,
  FMOD_BOOL inputsidle,
  unsigned int length,
  FMOD_CHANNELMASK inmask,
  int inchannels,
  FMOD_SPEAKERMODE speakermode
);
```

### C#
```csharp
delegate RESULT DSP_SHOULDIPROCESS_CALLBACK
(
  ref DSP_STATE dsp_state,
  bool inputsidle,
  uint length,
  CHANNELMASK inmask,
  int inchannels,
  SPEAKERMODE speakermode
);
```

### JavaScript
```javascript
function FMOD_DSP_SHOULDIPROCESS_CALLBACK(
    dsp_state,
    inputsidle,
    length,
    inmask,
    inchannels,
    speakermode
)
```

## FMOD_DSP_SHOULDIPROCESS_CALLBACK#2
kind: example
index: 68
heading: FMOD_DSP_SHOULDIPROCESS_CALLBACK

### C
```c
static FMOD_RESULT F_CALL shouldIProcess(FMOD_DSP_STATE *dsp_state, bool inputsidle, unsigned int length, FMOD_CHANNELMASK inmask, int inchannels, FMOD_SPEAKERMODE speakermode)
{
    if (inputsidle)
    {
        return FMOD_ERR_DSP_SILENCE;
    }
    return FMOD_OK;
}
```

## FMOD_DSP_STATE
kind: example
index: 69
heading: FMOD_DSP_STATE
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_DSP_STATE {
  void                      *instance;
  void                      *plugindata;
  FMOD_CHANNELMASK           channelmask;
  FMOD_SPEAKERMODE           source_speakermode;
  float                     *sidechaindata;
  int                        sidechainchannels;
  FMOD_DSP_STATE_FUNCTIONS   *functions;
  int                        systemobject;
} FMOD_DSP_STATE;
```

### C#
```csharp
struct DSP_STATE
{
  IntPtr     instance;
  IntPtr     plugindata;
  uint       channelmask;
  int        source_speakermode;
  IntPtr     sidechaindata;
  int        sidechainchannels;
  IntPtr     functions;
  int        systemobject;
}
```

### JavaScript
```javascript
FMOD_DSP_STATE
{
  instance,
  plugindata,
  channelmask,
  source_speakermode,
  sidechaindata,
  sidechainchannels,
  functions,
  systemobject,
};
```

## FMOD_DSP_STATE#2
kind: example
index: 70
heading: FMOD_DSP_STATE

### C/C++
```cpp
#define TWO_PI (2.0f * 3.14159265358979323846f)

typedef struct
{
    unsigned int step[16];
} dsp_data;

FMOD_RESULT F_CALL Read(FMOD_DSP_STATE *dsp_state, float *inbuffer, float *outbuffer, unsigned int length, int inchannels, int *outchannels)
{
    dsp_data *data = (dsp_data *)dsp_state->plugindata;
    int samplerate;
    dsp_state->functions->getsamplerate(dsp_state, &samplerate);

    for (unsigned int sample = 0; sample < length; sample++)
    {
        for (int channel = 0; channel < inchannels; channel++)
        {
            outbuffer[sample * *outchannels + channel] = sinf((440.0f * TWO_PI * data->step[channel]++) / (float)samplerate);
        }
    }

    return FMOD_OK;
}

FMOD_RESULT F_CALL Create(FMOD_DSP_STATE *dsp_state)
{
    dsp_data *data = (dsp_data *)calloc(sizeof(dsp_data), 1);
    if (!data)
    {
        return FMOD_ERR_MEMORY;
    }
    memset(data, 0, sizeof(data));
    dsp_state->plugindata = data;

    return FMOD_OK;
}

FMOD_RESULT F_CALL Release(FMOD_DSP_STATE *dsp_state)
{
    if (dsp_state->plugindata)
    {
        dsp_data *data = (dsp_data *)dsp_state->plugindata;
        free(data);
    }

    return FMOD_OK;
}
```

## FMOD_DSP_STATE#3
kind: example
index: 71
heading: FMOD_DSP_STATE

### C#
```csharp
class dsp_data
{
    public uint[] step;
}

[AOT.MonoPInvokeCallback(typeof(FMOD.DSP_READ_CALLBACK))]
static RESULT CaptureDSPReadCallback(ref FMOD.DSP_STATE dsp_state, IntPtr inbuffer, IntPtr outbuffer, uint length, int inchannels, ref int outchannels)
{
    float[] input = new float[length * inchannels];
    float[] output = new float[length * outchannels];

    GCHandle dataHandle = GCHandle.FromIntPtr(dsp_state.plugindata);
    dsp_data data = dataHandle.Target as dsp_data;

    int samplerate = 0;
    dsp_state.functions.getsamplerate(ref dsp_state, ref samplerate);

    for (int sample = 0; sample < length; sample++)
    {
        for (int channel = 0; channel < outchannels; channel++)
        {
            output[sample * outchannels + channel] = MathF.Sin((440.0f * MathF.PI * 2 * data.step[channel]++) / (float)samplerate);
        }
    }

    Marshal.Copy(output, 0, outbuffer, (int)length * outchannels);

    return RESULT.OK;
}

[AOT.MonoPInvokeCallback(typeof(FMOD.DSP_CREATE_CALLBACK))]
static RESULT CaptureDSPCreateCallback(ref FMOD.DSP_STATE dsp_state)
{
    dsp_data data = new dsp_data();
    data.step = new uint[16];
    dsp_state.plugindata = GCHandle.ToIntPtr(GCHandle.Alloc(data));

    return RESULT.OK;
}

[AOT.MonoPInvokeCallback(typeof(FMOD.DSP_RELEASE_CALLBACK))]
static RESULT CaptureDSPReleaseCallback(ref FMOD.DSP_STATE dsp_state)
{
    GCHandle.FromIntPtr(dsp_state.plugindata).Free();

    return RESULT.OK;
}
```

## FMOD_DSP_STATE#4
kind: example
index: 72
heading: FMOD_DSP_STATE

### JavaScript
```javascript
function Read(dsp_state, inbuffer, outbuffer, length, inchannels, outchannels)
{
    let outval = {};
    result = dsp_state.functions.getsamplerate(dsp_state, outval);
    CHECK_RESULT(result);

    for (var sample = 0; sample < length; sample++)
    {
        for (var channel = 0; channel < outchannels; channel++)
        {
            let val = Math.sin((440.0 * 2 * Math.PI * dsp_state.plugindata.step[channel]++) / outval.val);
            FMOD.setValue(outbuffer + (((sample * outchannels) + channel) * 4), val, 'float');
        }
    }

    return FMOD.OK;
}

function Create(dsp_state)
{
    dsp_state.plugindata =
    {
        step: []
    };
    for(let i = 0; i < 16; i++)
    {
        dsp_state.plugindata.step[i] = 0;
    }

    return FMOD.OK;
}

function Release(dsp_state)
{
    // No need to clean up memory in js
    return FMOD.OK;
}
```

## FMOD_DSP_STATE_DFT_FUNCTIONS
kind: example
index: 73
heading: FMOD_DSP_STATE_DFT_FUNCTIONS
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_DSP_STATE_DFT_FUNCTIONS {
  FMOD_DSP_DFT_FFTREAL_FUNC    fftreal;
  FMOD_DSP_DFT_IFFTREAL_FUNC   inversefftreal;
} FMOD_DSP_STATE_DFT_FUNCTIONS;
```

### C#
```csharp
struct DSP_STATE_DFT_FUNCTIONS
{
  DSP_DFT_FFTREAL_FUNC  fftreal;
  DSP_DFT_IFFTREAL_FUNC inversefftreal;
}
```

## FMOD_DSP_STATE_FUNCTIONS
kind: example
index: 74
heading: FMOD_DSP_STATE_FUNCTIONS
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_DSP_STATE_FUNCTIONS {
  FMOD_DSP_ALLOC_FUNC                   alloc;
  FMOD_DSP_REALLOC_FUNC                 realloc;
  FMOD_DSP_FREE_FUNC                    free;
  FMOD_DSP_GETSAMPLERATE_FUNC           getsamplerate;
  FMOD_DSP_GETBLOCKSIZE_FUNC            getblocksize;
  FMOD_DSP_STATE_DFT_FUNCTIONS         *dft;
  FMOD_DSP_STATE_PAN_FUNCTIONS         *pan;
  FMOD_DSP_GETSPEAKERMODE_FUNC          getspeakermode;
  FMOD_DSP_GETCLOCK_FUNC                getclock;
  FMOD_DSP_GETLISTENERATTRIBUTES_FUNC   getlistenerattributes;
  FMOD_DSP_LOG_FUNC                     log;
  FMOD_DSP_GETUSERDATA_FUNC             getuserdata;
} FMOD_DSP_STATE_FUNCTIONS;
```

### C#
```csharp
struct DSP_STATE_FUNCTIONS
{
  DSP_ALLOC_FUNC                  alloc;
  DSP_REALLOC_FUNC                realloc;
  DSP_FREE_FUNC                   free;
  DSP_GETSAMPLERATE_FUNC          getsamplerate;
  DSP_GETBLOCKSIZE_FUNC           getblocksize;
  IntPtr                          dft;
  IntPtr                          pan;
  DSP_GETSPEAKERMODE_FUNC         getspeakermode;
  DSP_GETCLOCK_FUNC               getclock;
  DSP_GETLISTENERATTRIBUTES_FUNC  getlistenerattributes;
  DSP_LOG_FUNC                    log;
  DSP_GETUSERDATA_FUNC            getuserdata;
}
```

### JavaScript
```javascript
DSP_STATE_FUNCTIONS
{
  getsamplerate,
  getblocksize,
  getspeakermode
}
```

## FMOD_DSP_STATE_PAN_FUNCTIONS
kind: example
index: 75
heading: FMOD_DSP_STATE_PAN_FUNCTIONS
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_DSP_STATE_PAN_FUNCTIONS {
  FMOD_DSP_PAN_SUMMONOMATRIX_FUNC               summonomatrix;
  FMOD_DSP_PAN_SUMSTEREOMATRIX_FUNC             sumstereomatrix;
  FMOD_DSP_PAN_SUMSURROUNDMATRIX_FUNC           sumsurroundmatrix;
  FMOD_DSP_PAN_SUMMONOTOSURROUNDMATRIX_FUNC     summonotosurroundmatrix;
  FMOD_DSP_PAN_SUMSTEREOTOSURROUNDMATRIX_FUNC   sumstereotosurroundmatrix;
  FMOD_DSP_PAN_GETROLLOFFGAIN_FUNC              getrolloffgain;
} FMOD_DSP_STATE_PAN_FUNCTIONS;
```

### C#
```csharp
struct DSP_STATE_PAN_FUNCTIONS
{
  DSP_PAN_SUMMONOMATRIX_FUNC             summonomatrix;
  DSP_PAN_SUMSTEREOMATRIX_FUNC           sumstereomatrix;
  DSP_PAN_SUMSURROUNDMATRIX_FUNC         sumsurroundmatrix;
  DSP_PAN_SUMMONOTOSURROUNDMATRIX_FUNC   summonotosurroundmatrix;
  DSP_PAN_SUMSTEREOTOSURROUNDMATRIX_FUNC sumstereotosurroundmatrix;
  DSP_PAN_GETROLLOFFGAIN_FUNC            getrolloffgain;
}
```

## FMOD_DSP_SYSTEM_DEREGISTER_CALLBACK
kind: example
index: 76
heading: FMOD_DSP_SYSTEM_DEREGISTER_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_DSP_SYSTEM_DEREGISTER_CALLBACK(
  FMOD_DSP_STATE *dsp_state
);
```

### C#
```csharp
delegate RESULT DSP_SYSTEM_DEREGISTER_CALLBACK
(
  ref DSP_STATE dsp_state
);
```

### JavaScript
```javascript
function FMOD_DSP_SYSTEM_DEREGISTER_CALLBACK(
    dsp_state
)
```

## FMOD_DSP_SYSTEM_MIX_CALLBACK
kind: example
index: 77
heading: FMOD_DSP_SYSTEM_MIX_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_DSP_SYSTEM_MIX_CALLBACK(
  FMOD_DSP_STATE *dsp_state,
  int stage
);
```

### C#
```csharp
delegate RESULT DSP_SYSTEM_MIX_CALLBACK
(
  ref DSP_STATE dsp_state,
  int stage
);
```

### JavaScript
```javascript
function FMOD_DSP_SYSTEM_MIX_CALLBACK(
    dsp_state,
    stage
)
```

## FMOD_DSP_SYSTEM_REGISTER_CALLBACK
kind: example
index: 78
heading: FMOD_DSP_SYSTEM_REGISTER_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_DSP_SYSTEM_REGISTER_CALLBACK(
  FMOD_DSP_STATE *dsp_state
);
```

### C#
```csharp
delegate RESULT DSP_SYSTEM_REGISTER_CALLBACK
(
  ref DSP_STATE dsp_state
);
```

### JavaScript
```javascript
function FMOD_DSP_SYSTEM_REGISTER_CALLBACK(
    dsp_state
)
```

## FMOD_PLUGIN_SDK_VERSION
kind: example
index: 79
heading: FMOD_PLUGIN_SDK_VERSION
tabbed: yes

### C/C++
```cpp
#define FMOD_PLUGIN_SDK_VERSION   110
```

### JavaScript
```javascript
FMOD.PLUGIN_SDK_VERSION = 110
```

