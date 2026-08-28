# core-api-dsp

## dsp_addinput
kind: function
index: 0

### C++
```cpp
FMOD_RESULT DSP::addInput(
  DSP *input,
  DSPConnection **connection = nullptr,
  FMOD_DSPCONNECTION_TYPE type = FMOD_DSPCONNECTION_TYPE_STANDARD
);
```

### C
```c
FMOD_RESULT FMOD_DSP_AddInput(
  FMOD_DSP *dsp,
  FMOD_DSP *input,
  FMOD_DSPCONNECTION **connection,
  FMOD_DSPCONNECTION_TYPE type
);
```

### C#
```csharp
RESULT DSP.addInput(
  DSP input
);
RESULT DSP.addInput(
  DSP input,
  out DSPConnection connection,
  DSPCONNECTION_TYPE type = DSPCONNECTION_TYPE.STANDARD
);
```

### JavaScript
```javascript
DSP.addInput(
  input,
  connection,
  type
);
```

## dsp_addinputpreallocated
kind: function
index: 1

### C++
```cpp
FMOD_RESULT DSP::addInputPreallocated(
  DSP *input,
  DSPConnection **connection = nullptr
);
```

### C
```c
FMOD_RESULT FMOD_DSP_AddInputPreallocated(
  FMOD_DSP *dsp,
  FMOD_DSP *input,
  FMOD_DSPCONNECTION **connection
);
```

### C#
```csharp
RESULT DSP.addInputPreallocated(
  DSP input,
  DSPConnection connection = null
);
```

## FMOD_DSP_CALLBACK
kind: example
index: 2
heading: FMOD_DSP_CALLBACK

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_DSP_CALLBACK(
  FMOD_DSP *dsp,
  FMOD_DSP_CALLBACK_TYPE type,
  void *data
);
```

### C#
```csharp
delegate RESULT DSP_CALLBACK(
  IntPtr dsp,
  DSP_CALLBACK_TYPE type,
  IntPtr data
);
```

### JavaScript
```javascript
function FMOD_DSP_CALLBACK(
  dsp,
  type,
  data
)
```

## FMOD_DSP_CALLBACK_TYPE
kind: example
index: 3
heading: FMOD_DSP_CALLBACK_TYPE

### C/C++
```cpp
typedef enum FMOD_DSP_CALLBACK_TYPE {
  FMOD_DSP_CALLBACK_DATAPARAMETERRELEASE,
  FMOD_DSP_CALLBACK_MAX
} FMOD_DSP_CALLBACK_TYPE;
```

### C#
```csharp
enum DSP_CALLBACK_TYPE : int
{
  DATAPARAMETERRELEASE,
  MAX,
}
```

### JavaScript
```javascript
DSP_CALLBACK_DATAPARAMETERRELEASE
DSP_CALLBACK_MAX
```

## FMOD_DSP_DATA_PARAMETER_INFO
kind: example
index: 4
heading: FMOD_DSP_DATA_PARAMETER_INFO

### C/C++
```cpp
typedef struct FMOD_DSP_DATA_PARAMETER_INFO {
  void          *data;
  unsigned int  length;
  int           index;
} FMOD_DSP_DATA_PARAMETER_INFO;
```

### C#
```csharp
struct DSP_DATA_PARAMETER_INFO
{
    IntPtr          data;
    uint            length;
    int             index;
}
```

### JavaScript
```javascript
FMOD_DSP_DATA_PARAMETER_INFO
{
  data,
  length,
  index,
};
```

## dsp_disconnectall
kind: function
index: 5

### C++
```cpp
FMOD_RESULT DSP::disconnectAll(
  bool inputs,
  bool outputs
);
```

### C
```c
FMOD_RESULT FMOD_DSP_DisconnectAll(
  FMOD_DSP *dsp,
  FMOD_BOOL inputs,
  FMOD_BOOL outputs
);
```

### C#
```csharp
RESULT DSP.disconnectAll(
  bool inputs,
  bool outputs
);
```

### JavaScript
```javascript
DSP.disconnectAll(
  inputs,
  outputs
);
```

## dsp_disconnectfrom
kind: function
index: 6

### C++
```cpp
FMOD_RESULT DSP::disconnectFrom(
  DSP *target,
  DSPConnection *connection = nullptr
);
```

### C
```c
FMOD_RESULT FMOD_DSP_DisconnectFrom(
  FMOD_DSP *dsp,
  FMOD_DSP *target,
  FMOD_DSPCONNECTION *connection
);
```

### C#
```csharp
RESULT DSP.disconnectFrom(
  DSP target,
  DSPConnection connection = null
);
```

### JavaScript
```javascript
DSP.disconnectFrom(
  target,
  connection
);
```

## dsp_getactive
kind: function
index: 7

### C++
```cpp
FMOD_RESULT DSP::getActive(
  bool *active
);
```

### C
```c
FMOD_RESULT FMOD_DSP_GetActive(
  FMOD_DSP *dsp,
  FMOD_BOOL *active
);
```

### C#
```csharp
RESULT DSP.getActive(
  out bool active
);
```

### JavaScript
```javascript
DSP.getActive(
  active
);
```

## dsp_getbypass
kind: function
index: 8

### C++
```cpp
FMOD_RESULT DSP::getBypass(
  bool *bypass
);
```

### C
```c
FMOD_RESULT FMOD_DSP_GetBypass(
  FMOD_DSP *dsp,
  FMOD_BOOL *bypass
);
```

### C#
```csharp
RESULT DSP.getBypass(
  out bool bypass
);
```

### JavaScript
```javascript
DSP.getBypass(
  bypass
);
```

## dsp_getchannelformat
kind: function
index: 9

### C++
```cpp
FMOD_RESULT DSP::getChannelFormat(
  FMOD_CHANNELMASK *channelmask,
  int *numchannels,
  FMOD_SPEAKERMODE *source_speakermode
);
```

### C
```c
FMOD_RESULT FMOD_DSP_GetChannelFormat(
  FMOD_DSP *dsp,
  FMOD_CHANNELMASK *channelmask,
  int *numchannels,
  FMOD_SPEAKERMODE *source_speakermode
);
```

### C#
```csharp
RESULT DSP.getChannelFormat(
  out CHANNELMASK channelmask,
  out int numchannels,
  out SPEAKERMODE source_speakermode
);
```

### JavaScript
```javascript
DSP.getChannelFormat(
  channelmask,
  numchannels,
  source_speakermode
);
```

## dsp_getcpuusage
kind: function
index: 10

### C++
```cpp
FMOD_RESULT DSP::getCPUUsage(
  unsigned int *exclusive,
  unsigned int *inclusive
);
```

### C
```c
FMOD_RESULT FMOD_DSP_GetCPUUsage(
  FMOD_DSP *dsp,
  unsigned int *exclusive,
  unsigned int *inclusive
);
```

### C#
```csharp
RESULT DSP.getCPUUsage(
  out uint exclusive,
  out uint inclusive
);
```

### JavaScript
```javascript
DSP.getCPUUsage(
  exclusive,
  inclusive
);
```

## dsp_getdataparameterindex
kind: function
index: 11

### C++
```cpp
FMOD_RESULT DSP::getDataParameterIndex(
  int datatype,
  int *index
);
```

### C
```c
FMOD_RESULT FMOD_DSP_GetDataParameterIndex(
  FMOD_DSP *dsp,
  int datatype,
  int *index
);
```

### C#
```csharp
RESULT DSP.getDataParameterIndex(
  int datatype,
  out int index
);
```

### JavaScript
```javascript
DSP.getDataParameterIndex(
  datatype,
  index
);
```

## dsp_getidle
kind: function
index: 12

### C++
```cpp
FMOD_RESULT DSP::getIdle(
  bool *idle
);
```

### C
```c
FMOD_RESULT FMOD_DSP_GetIdle(
  FMOD_DSP *dsp,
  FMOD_BOOL *idle
);
```

### C#
```csharp
RESULT DSP.getIdle(
  out bool idle
);
```

### JavaScript
```javascript
DSP.getIdle(
  idle
);
```

## dsp_getinfo
kind: function
index: 13

### C++
```cpp
FMOD_RESULT DSP::getInfo(
  char *name,
  unsigned int *version,
  int *channels,
  int *configwidth,
  int *configheight
);
```

### C
```c
FMOD_RESULT FMOD_DSP_GetInfo(
  FMOD_DSP *dsp,
  char *name,
  unsigned int *version,
  int *channels,
  int *configwidth,
  int *configheight
);
```

### C#
```csharp
RESULT DSP.getInfo(
  out string name,
  out uint version,
  out int channels,
  out int configwidth,
  out int configheight
);
```

### JavaScript
```javascript
DSP.getInfo(
  name,
  version,
  channels,
  configwidth,
  configheight
);
```

## dsp_getinput
kind: function
index: 14

### C++
```cpp
FMOD_RESULT DSP::getInput(
  int index,
  DSP **input,
  DSPConnection **inputconnection
);
```

### C
```c
FMOD_RESULT FMOD_DSP_GetInput(
  FMOD_DSP *dsp,
  int index,
  FMOD_DSP **input,
  FMOD_DSPCONNECTION **inputconnection
);
```

### C#
```csharp
RESULT DSP.getInput(
  int index,
  out DSP input,
  out DSPConnection inputconnection
);
```

### JavaScript
```javascript
DSP.getInput(
  index,
  input,
  inputconnection
);
```

## dsp_getmeteringenabled
kind: function
index: 15

### C++
```cpp
FMOD_RESULT DSP::getMeteringEnabled(
  bool *inputEnabled,
  bool *outputEnabled
);
```

### C
```c
FMOD_RESULT FMOD_DSP_GetMeteringEnabled(
  FMOD_DSP *dsp,
  FMOD_BOOL *inputEnabled,
  FMOD_BOOL *outputEnabled
);
```

### C#
```csharp
RESULT DSP.getMeteringEnabled(
  out bool inputEnabled,
  out bool outputEnabled
);
```

### JavaScript
```javascript
DSP.getMeteringEnabled(
  inputEnabled,
  outputEnabled
);
```

## dsp_getmeteringinfo
kind: function
index: 16

### C++
```cpp
FMOD_RESULT DSP::getMeteringInfo(
  FMOD_DSP_METERING_INFO *inputInfo,
  FMOD_DSP_METERING_INFO *outputInfo
);
```

### C
```c
FMOD_RESULT FMOD_DSP_GetMeteringInfo(
  FMOD_DSP *dsp,
  FMOD_DSP_METERING_INFO *inputInfo,
  FMOD_DSP_METERING_INFO *outputInfo
);
```

### C#
```csharp
RESULT DSP.getMeteringInfo(
  IntPtr zero,
  DSP_METERING_INFO outputInfo
);
RESULT DSP.getMeteringInfo(
  DSP_METERING_INFO inputInfo,
  IntPtr zero
);
RESULT DSP.getMeteringInfo(
  DSP_METERING_INFO inputInfo,
  DSP_METERING_INFO outputInfo
);
```

### JavaScript
```javascript
DSP.getMeteringInfo(
  inputInfo,
  outputInfo
);
```

## dsp_getnuminputs
kind: function
index: 17

### C++
```cpp
FMOD_RESULT DSP::getNumInputs(
  int *numinputs
);
```

### C
```c
FMOD_RESULT FMOD_DSP_GetNumInputs(
  FMOD_DSP *dsp,
  int *numinputs
);
```

### C#
```csharp
RESULT DSP.getNumInputs(
  out int numinputs
);
```

### JavaScript
```javascript
DSP.getNumInputs(
  numinputs
);
```

## dsp_getnumoutputs
kind: function
index: 18

### C++
```cpp
FMOD_RESULT DSP::getNumOutputs(
  int *numoutputs
);
```

### C
```c
FMOD_RESULT FMOD_DSP_GetNumOutputs(
  FMOD_DSP *dsp,
  int *numoutputs
);
```

### C#
```csharp
RESULT DSP.getNumOutputs(
  out int numoutputs
);
```

### JavaScript
```javascript
DSP.getNumOutputs(
  numoutputs
);
```

## dsp_getnumparameters
kind: function
index: 19

### C++
```cpp
FMOD_RESULT DSP::getNumParameters(
  int *numparams
);
```

### C
```c
FMOD_RESULT FMOD_DSP_GetNumParameters(
  FMOD_DSP *dsp,
  int *numparams
);
```

### C#
```csharp
RESULT DSP.getNumParameters(
  out int numparams
);
```

### JavaScript
```javascript
DSP.getNumParameters(
  numparams
);
```

## dsp_getoutput
kind: function
index: 20

### C++
```cpp
FMOD_RESULT DSP::getOutput(
  int index,
  DSP **output,
  DSPConnection **outputconnection
);
```

### C
```c
FMOD_RESULT FMOD_DSP_GetOutput(
  FMOD_DSP *dsp,
  int index,
  FMOD_DSP **output,
  FMOD_DSPCONNECTION **outputconnection
);
```

### C#
```csharp
RESULT DSP.getOutput(
  int index,
  out DSP output,
  out DSPConnection outputconnection
);
```

### JavaScript
```javascript
DSP.getOutput(
  index,
  output,
  outputconnection
);
```

## dsp_getoutputchannelformat
kind: function
index: 21

### C++
```cpp
FMOD_RESULT DSP::getOutputChannelFormat(
  FMOD_CHANNELMASK inmask,
  int inchannels,
  FMOD_SPEAKERMODE inspeakermode,
  FMOD_CHANNELMASK *outmask,
  int *outchannels,
  FMOD_SPEAKERMODE *outspeakermode
);
```

### C
```c
FMOD_RESULT FMOD_DSP_GetOutputChannelFormat(
  FMOD_DSP *dsp,
  FMOD_CHANNELMASK inmask,
  int inchannels,
  FMOD_SPEAKERMODE inspeakermode,
  FMOD_CHANNELMASK *outmask,
  int *outchannels,
  FMOD_SPEAKERMODE *outspeakermode
);
```

### C#
```csharp
RESULT DSP.getOutputChannelFormat(
  CHANNELMASK inmask,
  int inchannels,
  SPEAKERMODE inspeakermode,
  out CHANNELMASK outmask,
  out int outchannels,
  out SPEAKERMODE outspeakermode
);
```

### JavaScript
```javascript
DSP.getOutputChannelFormat(
  inmask,
  inchannels,
  inspeakermode,
  outmask,
  outchannels,
  outspeakermode
);
```

## dsp_getparameterbool
kind: function
index: 22

### C++
```cpp
FMOD_RESULT DSP::getParameterBool(
  int index,
  bool *value,
  char *valuestr,
  int valuestrlen
);
```

### C
```c
FMOD_RESULT FMOD_DSP_GetParameterBool(
  FMOD_DSP *dsp,
  int index,
  FMOD_BOOL *value,
  char *valuestr,
  int valuestrlen
);
```

### C#
```csharp
RESULT DSP.getParameterBool(
  int index,
  out bool value
);
```

### JavaScript
```javascript
DSP.getParameterBool(
  index,
  value,
  valuestr
);
```

## dsp_getparameterdata
kind: function
index: 23

### C++
```cpp
FMOD_RESULT DSP::getParameterData(
  int index,
  void **data,
  unsigned int *length,
  char *valuestr,
  int valuestrlen
);
```

### C
```c
FMOD_RESULT FMOD_DSP_GetParameterData(
  FMOD_DSP *dsp,
  int index,
  void **data,
  unsigned int *length,
  char *valuestr,
  int valuestrlen
);
```

### C#
```csharp
RESULT DSP.getParameterData(
  int index,
  out IntPtr data,
  out uint length
);
```

### JavaScript
```javascript
DSP.getParameterData(
  index,
  data,
  length,
  valuestr
);
```

## dsp_getparameterfloat
kind: function
index: 24

### C++
```cpp
FMOD_RESULT DSP::getParameterFloat(
  int index,
  float *value,
  char *valuestr,
  int valuestrlen
);
```

### C
```c
FMOD_RESULT FMOD_DSP_GetParameterFloat(
  FMOD_DSP *dsp,
  int index,
  float *value,
  char *valuestr,
  int valuestrlen
);
```

### C#
```csharp
RESULT DSP.getParameterFloat(
  int index,
  out float value
);
```

### JavaScript
```javascript
DSP.getParameterFloat(
  index,
  value,
  valuestr
);
```

## dsp_getparameterinfo
kind: function
index: 25

### C++
```cpp
FMOD_RESULT DSP::getParameterInfo(
  int index,
  FMOD_DSP_PARAMETER_DESC **desc
);
```

### C
```c
FMOD_RESULT FMOD_DSP_GetParameterInfo(
  FMOD_DSP *dsp,
  int index,
  FMOD_DSP_PARAMETER_DESC **desc
);
```

### C#
```csharp
RESULT DSP.getParameterInfo(
  int index,
  out DSP_PARAMETER_DESC desc
);
```

### JavaScript
```javascript
DSP.getParameterInfo(
  index,
  desc
);
```

## dsp_getparameterint
kind: function
index: 26

### C++
```cpp
FMOD_RESULT DSP::getParameterInt(
  int index,
  int *value,
  char *valuestr,
  int valuestrlen
);
```

### C
```c
FMOD_RESULT FMOD_DSP_GetParameterInt(
  FMOD_DSP *dsp,
  int index,
  int *value,
  char *valuestr,
  int valuestrlen
);
```

### C#
```csharp
RESULT DSP.getParameterInt(
  int index,
  out int value
);
```

### JavaScript
```javascript
DSP.getParameterInt(
  index,
  value,
  valuestr
);
```

## dsp_getsystemobject
kind: function
index: 27

### C++
```cpp
FMOD_RESULT DSP::getSystemObject(
  System **system
);
```

### C
```c
FMOD_RESULT FMOD_DSP_GetSystemObject(
  FMOD_DSP *dsp,
  FMOD_SYSTEM **system
);
```

### C#
```csharp
RESULT DSP.getSystemObject(
  out System system
);
```

### JavaScript
```javascript
DSP.getSystemObject(
  system
);
```

## dsp_gettype
kind: function
index: 28

### C++
```cpp
FMOD_RESULT DSP::getType(
  FMOD_DSP_TYPE *type
);
```

### C
```c
FMOD_RESULT FMOD_DSP_GetType(
  FMOD_DSP *dsp,
  FMOD_DSP_TYPE *type
);
```

### C#
```csharp
RESULT DSP.getType(
  out DSP_TYPE type
);
```

### JavaScript
```javascript
DSP.getType(
  type
);
```

## dsp_getuserdata
kind: function
index: 29

### C++
```cpp
FMOD_RESULT DSP::getUserData(
  void **userdata
);
```

### C
```c
FMOD_RESULT FMOD_DSP_GetUserData(
  FMOD_DSP *dsp,
  void **userdata
);
```

### C#
```csharp
RESULT DSP.getUserData(
  out IntPtr userdata
);
```

### JavaScript
```javascript
DSP.getUserData(
  userdata
);
```

## dsp_getwetdrymix
kind: function
index: 30

### C++
```cpp
FMOD_RESULT DSP::getWetDryMix(
  float *prewet,
  float *postwet,
  float *dry
);
```

### C
```c
FMOD_RESULT FMOD_DSP_GetWetDryMix(
  FMOD_DSP *dsp,
  float *prewet,
  float *postwet,
  float *dry
);
```

### C#
```csharp
RESULT DSP.getWetDryMix(
  out float prewet,
  out float postwet,
  out float dry
);
```

### JavaScript
```javascript
DSP.getWetDryMix(
  prewet,
  postwet,
  dry
);
```

## dsp_release
kind: function
index: 31

### C++
```cpp
FMOD_RESULT DSP::release();
```

### C
```c
FMOD_RESULT FMOD_DSP_Release(FMOD_DSP *dsp);
```

### C#
```csharp
RESULT DSP.release();
```

### JavaScript
```javascript
DSP.release();
```

## dsp_reset
kind: function
index: 32

### C++
```cpp
FMOD_RESULT DSP::reset();
```

### C
```c
FMOD_RESULT FMOD_DSP_Reset(FMOD_DSP *dsp);
```

### C#
```csharp
RESULT DSP.reset();
```

### JavaScript
```javascript
DSP.reset();
```

## dsp_setactive
kind: function
index: 33

### C++
```cpp
FMOD_RESULT DSP::setActive(
  bool active
);
```

### C
```c
FMOD_RESULT FMOD_DSP_SetActive(
  FMOD_DSP *dsp,
  FMOD_BOOL active
);
```

### C#
```csharp
RESULT DSP.setActive(
  bool active
);
```

### JavaScript
```javascript
DSP.setActive(
  active
);
```

## dsp_setbypass
kind: function
index: 34

### C++
```cpp
FMOD_RESULT DSP::setBypass(
  bool bypass
);
```

### C
```c
FMOD_RESULT FMOD_DSP_SetBypass(
  FMOD_DSP *dsp,
  FMOD_BOOL bypass
);
```

### C#
```csharp
RESULT DSP.setBypass(
  bool bypass
);
```

### JavaScript
```javascript
DSP.setBypass(
  bypass
);
```

## dsp_setcallback
kind: function
index: 35

### C++
```cpp
FMOD_RESULT DSP::setCallback(
  FMOD_DSP_CALLBACK callback
);
```

### C
```c
FMOD_RESULT FMOD_DSP_SetCallback(
  FMOD_DSP *dsp,
  FMOD_DSP_CALLBACK callback
);
```

### C#
```csharp
RESULT DSP.setCallback(
  DSP_CALLBACK callback
);
```

### JavaScript
```javascript
DSP.setCallback(
  callback
);
```

## dsp_setchannelformat
kind: function
index: 36

### C++
```cpp
FMOD_RESULT DSP::setChannelFormat(
  FMOD_CHANNELMASK channelmask,
  int numchannels,
  FMOD_SPEAKERMODE source_speakermode
);
```

### C
```c
FMOD_RESULT FMOD_DSP_SetChannelFormat(
  FMOD_DSP *dsp,
  FMOD_CHANNELMASK channelmask,
  int numchannels,
  FMOD_SPEAKERMODE source_speakermode
);
```

### C#
```csharp
RESULT DSP.setChannelFormat(
  CHANNELMASK channelmask,
  int numchannels,
  SPEAKERMODE source_speakermode
);
```

### JavaScript
```javascript
DSP.setChannelFormat(
  channelmask,
  numchannels,
  source_speakermode
);
```

## dsp_setmeteringenabled
kind: function
index: 37

### C++
```cpp
FMOD_RESULT DSP::setMeteringEnabled(
  bool inputEnabled,
  bool outputEnabled
);
```

### C
```c
FMOD_RESULT FMOD_DSP_SetMeteringEnabled(
  FMOD_DSP *dsp,
  FMOD_BOOL inputEnabled,
  FMOD_BOOL outputEnabled
);
```

### C#
```csharp
RESULT DSP.setMeteringEnabled(
  bool inputEnabled,
  bool outputEnabled
);
```

### JavaScript
```javascript
DSP.setMeteringEnabled(
  inputEnabled,
  outputEnabled
);
```

## dsp_setparameterbool
kind: function
index: 38

### C++
```cpp
FMOD_RESULT DSP::setParameterBool(
  int index,
  bool value
);
```

### C
```c
FMOD_RESULT FMOD_DSP_SetParameterBool(
  FMOD_DSP *dsp,
  int index,
  FMOD_BOOL value
);
```

### C#
```csharp
RESULT DSP.setParameterBool(
  int index,
  bool value
);
```

### JavaScript
```javascript
DSP.setParameterBool(
  index,
  value
);
```

## dsp_setparameterdata
kind: function
index: 39

### C++
```cpp
FMOD_RESULT DSP::setParameterData(
  int index,
  void *data,
  unsigned int length
);
```

### C
```c
FMOD_RESULT FMOD_DSP_SetParameterData(
  FMOD_DSP *dsp,
  int index,
  void *data,
  unsigned int length
);
```

### C#
```csharp
RESULT DSP.setParameterData(
  int index,
  byte[] data
);
```

### JavaScript
```javascript
DSP.setParameterData(
  index,
  data,
  length
);
```

## dsp_setparameterfloat
kind: function
index: 40

### C++
```cpp
FMOD_RESULT DSP::setParameterFloat(
  int index,
  float value
);
```

### C
```c
FMOD_RESULT FMOD_DSP_SetParameterFloat(
  FMOD_DSP *dsp,
  int index,
  float value
);
```

### C#
```csharp
RESULT DSP.setParameterFloat(
  int index,
  float value
);
```

### JavaScript
```javascript
DSP.setParameterFloat(
  index,
  value
);
```

## dsp_setparameterint
kind: function
index: 41

### C++
```cpp
FMOD_RESULT DSP::setParameterInt(
  int index,
  int value
);
```

### C
```c
FMOD_RESULT FMOD_DSP_SetParameterInt(
  FMOD_DSP *dsp,
  int index,
  int value
);
```

### C#
```csharp
RESULT DSP.setParameterInt(
  int index,
  int value
);
```

### JavaScript
```javascript
DSP.setParameterInt(
  index,
  value
);
```

## dsp_setuserdata
kind: function
index: 42

### C++
```cpp
FMOD_RESULT DSP::setUserData(
  void *userdata
);
```

### C
```c
FMOD_RESULT FMOD_DSP_SetUserData(
  FMOD_DSP *dsp,
  void *userdata
);
```

### C#
```csharp
RESULT DSP.setUserData(
  IntPtr userdata
);
```

### JavaScript
```javascript
DSP.setUserData(
  userdata
);
```

## dsp_setwetdrymix
kind: function
index: 43

### C++
```cpp
FMOD_RESULT DSP::setWetDryMix(
  float prewet,
  float postwet,
  float dry
);
```

### C
```c
FMOD_RESULT FMOD_DSP_SetWetDryMix(
  FMOD_DSP *dsp,
  float prewet,
  float postwet,
  float dry
);
```

### C#
```csharp
RESULT DSP.setWetDryMix(
  float prewet,
  float postwet,
  float dry
);
```

### JavaScript
```javascript
DSP.setWetDryMix(
  prewet,
  postwet,
  dry
);
```

## dsp_showconfigdialog
kind: function
index: 44

### C++
```cpp
FMOD_RESULT DSP::showConfigDialog(
  void *hwnd,
  bool show
);
```

### C
```c
FMOD_RESULT FMOD_DSP_ShowConfigDialog(
  FMOD_DSP *dsp,
  void *hwnd,
  FMOD_BOOL show
);
```

### C#
```csharp
RESULT DSP.showConfigDialog(
  IntPtr hwnd,
  bool show
);
```

### JavaScript
```javascript
DSP.showConfigDialog(
  hwnd,
  show
);
```

