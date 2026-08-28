# core-api-channelcontrol

## channelcontrol_adddsp
kind: function
index: 0

### C++
```cpp
FMOD_RESULT ChannelControl::addDSP(
  int index,
  DSP *dsp
);
```

### C
```c
FMOD_RESULT FMOD_Channel_AddDSP(
  FMOD_CHANNEL *channel,
  int index,
  FMOD_DSP *dsp
);
FMOD_RESULT FMOD_ChannelGroup_AddDSP(
  FMOD_CHANNELGROUP *channelgroup,
  int index,
  FMOD_DSP *dsp
);
```

### C#
```csharp
RESULT ChannelControl.addDSP(
  int index,
  DSP dsp
);
```

### JavaScript
```javascript
Channel.addDSP(
  index,
  dsp
);
ChannelGroup.addDSP(
  index,
  dsp
);
```

## channelcontrol_addfadepoint
kind: function
index: 1

### C++
```cpp
FMOD_RESULT ChannelControl::addFadePoint(
  unsigned long long dspclock,
  float volume
);
```

### C
```c
FMOD_RESULT FMOD_Channel_AddFadePoint(
  FMOD_CHANNEL *channel,
  unsigned long long dspclock,
  float volume
);
FMOD_RESULT FMOD_ChannelGroup_AddFadePoint(
  FMOD_CHANNELGROUP *channelgroup,
  unsigned long long dspclock,
  float volume
);
```

### C#
```csharp
RESULT ChannelControl.addFadePoint(
  ulong dspclock,
  float volume
);
```

### JavaScript
```javascript
Channel.addFadePoint(
  dspclock,
  volume
);
ChannelGroup.addFadePoint(
  dspclock,
  volume
);
```

## ChannelControl::addFadePoint
kind: example
index: 2
heading: ChannelControl::addFadePoint

### C
```c
/* Example. Ramp from full volume to half volume over the next 4096 samples */
unsigned long long parentclock;
FMOD_ChannelControl_GetDSPClock(target, NULL, &parentclock);
FMOD_ChannelControl_AddFadePoint(target, parentclock,        1.0f);
FMOD_ChannelControl_AddFadePoint(target, parentclock + 4096, 0.5f);
```

## ChannelControl::addFadePoint#2
kind: example
index: 3
heading: ChannelControl::addFadePoint

### C++
```cpp
// Example. Ramp from full volume to half volume over the next 4096 samples
unsigned long long parentclock;
target->getDSPClock(nullptr, &parentclock);
target->addFadePoint(parentclock,        1.0f);
target->addFadePoint(parentclock + 4096, 0.5f);
```

## FMOD_CHANNELCONTROL_CALLBACK
kind: example
index: 4
heading: FMOD_CHANNELCONTROL_CALLBACK

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_CHANNELCONTROL_CALLBACK(
  FMOD_CHANNELCONTROL *channelcontrol,
  FMOD_CHANNELCONTROL_TYPE controltype,
  FMOD_CHANNELCONTROL_CALLBACK_TYPE callbacktype,
  void *commanddata1,
  void *commanddata2
);
```

### C#
```csharp
delegate RESULT CHANNELCONTROL_CALLBACK(
  IntPtr channelcontrol,
  CHANNELCONTROL_TYPE controltype,
  CHANNELCONTROL_CALLBACK_TYPE callbacktype,
  IntPtr commanddata1,
  IntPtr commanddata2
);
```

### JavaScript
```javascript
function FMOD_CHANNELCONTROL_CALLBACK(
  channelcontrol,
  controltype,
  callbacktype,
  commanddata1,
  commanddata2
)
```

## FMOD_CHANNELCONTROL_CALLBACK_TYPE
kind: example
index: 5
heading: FMOD_CHANNELCONTROL_CALLBACK_TYPE

### C/C++
```cpp
typedef enum FMOD_CHANNELCONTROL_CALLBACK_TYPE {
  FMOD_CHANNELCONTROL_CALLBACK_END,
  FMOD_CHANNELCONTROL_CALLBACK_VIRTUALVOICE,
  FMOD_CHANNELCONTROL_CALLBACK_SYNCPOINT,
  FMOD_CHANNELCONTROL_CALLBACK_OCCLUSION,
  FMOD_CHANNELCONTROL_CALLBACK_MAX
} FMOD_CHANNELCONTROL_CALLBACK_TYPE;
```

### C#
```csharp
enum CHANNELCONTROL_CALLBACK_TYPE : int
{
  END,
  VIRTUALVOICE,
  SYNCPOINT,
  OCCLUSION,
  MAX,
}
```

### JavaScript
```javascript
CHANNELCONTROL_CALLBACK_END
CHANNELCONTROL_CALLBACK_VIRTUALVOICE
CHANNELCONTROL_CALLBACK_SYNCPOINT
CHANNELCONTROL_CALLBACK_OCCLUSION
CHANNELCONTROL_CALLBACK_MAX
```

## FMOD_CHANNELCONTROL_DSP_INDEX
kind: example
index: 6
heading: FMOD_CHANNELCONTROL_DSP_INDEX

### C/C++
```cpp
typedef enum FMOD_CHANNELCONTROL_DSP_INDEX {
  FMOD_CHANNELCONTROL_DSP_HEAD  = -1,
  FMOD_CHANNELCONTROL_DSP_FADER = -2,
  FMOD_CHANNELCONTROL_DSP_TAIL  = -3
} FMOD_CHANNELCONTROL_DSP_INDEX;
```

### C#
```csharp
struct CHANNELCONTROL_DSP_INDEX
{
  const int HEAD  = -1;
  const int FADER = -2;
  const int TAIL  = -3;
}
```

### JavaScript
```javascript
CHANNELCONTROL_DSP_HEAD     = -1
CHANNELCONTROL_DSP_FADER    = -2
CHANNELCONTROL_DSP_TAIL     = -3
```

## channelcontrol_get3dattributes
kind: function
index: 7

### C++
```cpp
FMOD_RESULT ChannelControl::get3DAttributes(
  FMOD_VECTOR *pos,
  FMOD_VECTOR *vel
);
```

### C
```c
FMOD_RESULT FMOD_Channel_Get3DAttributes(
  FMOD_CHANNEL *channel,
  FMOD_VECTOR *pos,
  FMOD_VECTOR *vel
);
FMOD_RESULT FMOD_ChannelGroup_Get3DAttributes(
  FMOD_CHANNELGROUP *channelgroup,
  FMOD_VECTOR *pos,
  FMOD_VECTOR *vel
);
```

### C#
```csharp
RESULT ChannelControl.get3DAttributes(
  out VECTOR pos,
  out VECTOR vel
);
```

### JavaScript
```javascript
Channel.get3DAttributes(
  pos,
  vel
);
ChannelGroup.get3DAttributes(
  pos,
  vel
);
```

## channelcontrol_get3dconeorientation
kind: function
index: 8

### C++
```cpp
FMOD_RESULT ChannelControl::get3DConeOrientation(
  FMOD_VECTOR *orientation
);
```

### C
```c
FMOD_RESULT FMOD_Channel_Get3DConeOrientation(
  FMOD_CHANNEL *channel,
  FMOD_VECTOR *orientation
);
FMOD_RESULT FMOD_ChannelGroup_Get3DConeOrientation(
  FMOD_CHANNELGROUP *channelgroup,
  FMOD_VECTOR *orientation
);
```

### C#
```csharp
RESULT ChannelControl.get3DConeOrientation(
  out VECTOR orientation
);
```

### JavaScript
```javascript
Channel.get3DConeOrientation(
  orientation
);
ChannelGroup.get3DConeOrientation(
  orientation
);
```

## channelcontrol_get3dconesettings
kind: function
index: 9

### C++
```cpp
FMOD_RESULT ChannelControl::get3DConeSettings(
  float *insideconeangle,
  float *outsideconeangle,
  float *outsidevolume
);
```

### C
```c
FMOD_RESULT FMOD_Channel_Get3DConeSettings(
  FMOD_CHANNEL *channel,
  float *insideconeangle,
  float *outsideconeangle,
  float *outsidevolume
);
FMOD_RESULT FMOD_ChannelGroup_Get3DConeSettings(
  FMOD_CHANNELGROUP *channelgroup,
  float *insideconeangle,
  float *outsideconeangle,
  float *outsidevolume
);
```

### C#
```csharp
RESULT ChannelControl.get3DConeSettings(
  out float insideconeangle,
  out float outsideconeangle,
  out float outsidevolume
);
```

### JavaScript
```javascript
Channel.get3DConeSettings(
  insideconeangle,
  outsideconeangle,
  outsidevolume
);
ChannelGroup.get3DConeSettings(
  insideconeangle,
  outsideconeangle,
  outsidevolume
);
```

## channelcontrol_get3dcustomrolloff
kind: function
index: 10

### C++
```cpp
FMOD_RESULT ChannelControl::get3DCustomRolloff(
  FMOD_VECTOR **points,
  int *numpoints
);
```

### C
```c
FMOD_RESULT FMOD_Channel_Get3DCustomRolloff(
  FMOD_CHANNEL *channel,
  FMOD_VECTOR **points,
  int *numpoints
);
FMOD_RESULT FMOD_ChannelGroup_Get3DCustomRolloff(
  FMOD_CHANNELGROUP *channelgroup,
  FMOD_VECTOR **points,
  int *numpoints
);
```

### C#
```csharp
RESULT ChannelControl.get3DCustomRolloff(
  out IntPtr points,
  out int numpoints
);
```

### JavaScript
```javascript
Channel.get3DCustomRolloff(
  points,
  numpoints
);
ChannelGroup.get3DCustomRolloff(
  points,
  numpoints
);
```

## channelcontrol_get3ddistancefilter
kind: function
index: 11

### C++
```cpp
FMOD_RESULT ChannelControl::get3DDistanceFilter(
  bool *custom,
  float *customLevel,
  float *centerFreq
);
```

### C
```c
FMOD_RESULT FMOD_Channel_Get3DDistanceFilter(
  FMOD_CHANNEL *channel,
  FMOD_BOOL *custom,
  float *customLevel,
  float *centerFreq
);
FMOD_RESULT FMOD_ChannelGroup_Get3DDistanceFilter(
  FMOD_CHANNELGROUP *channelgroup,
  FMOD_BOOL *custom,
  float *customLevel,
  float *centerFreq
);
```

### C#
```csharp
RESULT ChannelControl.get3DDistanceFilter(
  out bool custom,
  out float customLevel,
  out float centerFreq
);
```

### JavaScript
```javascript
Channel.get3DDistanceFilter(
  custom,
  customLevel,
  centerFreq
);
ChannelGroup.get3DDistanceFilter(
  custom,
  customLevel,
  centerFreq
);
```

## channelcontrol_get3ddopplerlevel
kind: function
index: 12

### C++
```cpp
FMOD_RESULT ChannelControl::get3DDopplerLevel(
  float *level
);
```

### C
```c
FMOD_RESULT FMOD_Channel_Get3DDopplerLevel(
  FMOD_CHANNEL *channel,
  float *level
);
FMOD_RESULT FMOD_ChannelGroup_Get3DDopplerLevel(
  FMOD_CHANNELGROUP *channelgroup,
  float *level
);
```

### C#
```csharp
RESULT ChannelControl.get3DDopplerLevel(
  out float level
);
```

### JavaScript
```javascript
Channel.get3DDopplerLevel(
  level
);
ChannelGroup.get3DDopplerLevel(
  level
);
```

## channelcontrol_get3dlevel
kind: function
index: 13

### C++
```cpp
FMOD_RESULT ChannelControl::get3DLevel(
  float *level
);
```

### C
```c
FMOD_RESULT FMOD_Channel_Get3DLevel(
  FMOD_CHANNEL *channel,
  float *level
);
FMOD_RESULT FMOD_ChannelGroup_Get3DLevel(
  FMOD_CHANNELGROUP *channelgroup,
  float *level
);
```

### C#
```csharp
RESULT ChannelControl.get3DLevel(
  out float level
);
```

### JavaScript
```javascript
Channel.get3DLevel(
  level
);
ChannelGroup.get3DLevel(
  level
);
```

## channelcontrol_get3dminmaxdistance
kind: function
index: 14

### C++
```cpp
FMOD_RESULT ChannelControl::get3DMinMaxDistance(
  float *mindistance,
  float *maxdistance
);
```

### C
```c
FMOD_RESULT FMOD_Channel_Get3DMinMaxDistance(
  FMOD_CHANNEL *channel,
  float *mindistance,
  float *maxdistance
);
FMOD_RESULT FMOD_ChannelGroup_Get3DMinMaxDistance(
  FMOD_CHANNELGROUP *channelgroup,
  float *mindistance,
  float *maxdistance
);
```

### C#
```csharp
RESULT ChannelControl.get3DMinMaxDistance(
  out float mindistance,
  out float maxdistance
);
```

### JavaScript
```javascript
Channel.get3DMinMaxDistance(
  mindistance,
  maxdistance
);
ChannelGroup.get3DMinMaxDistance(
  mindistance,
  maxdistance
);
```

## channelcontrol_get3docclusion
kind: function
index: 15

### C++
```cpp
FMOD_RESULT ChannelControl::get3DOcclusion(
  float *directocclusion,
  float *reverbocclusion
);
```

### C
```c
FMOD_RESULT FMOD_Channel_Get3DOcclusion(
  FMOD_CHANNEL *channel,
  float *directocclusion,
  float *reverbocclusion
);
FMOD_RESULT FMOD_ChannelGroup_Get3DOcclusion(
  FMOD_CHANNELGROUP *channelgroup,
  float *directocclusion,
  float *reverbocclusion
);
```

### C#
```csharp
RESULT ChannelControl.get3DOcclusion(
  out float directocclusion,
  out float reverbocclusion
);
```

### JavaScript
```javascript
Channel.get3DOcclusion(
  directocclusion,
  reverbocclusion
);
ChannelGroup.get3DOcclusion(
  directocclusion,
  reverbocclusion
);
```

## channelcontrol_get3dspread
kind: function
index: 16

### C++
```cpp
FMOD_RESULT ChannelControl::get3DSpread(
  float *angle
);
```

### C
```c
FMOD_RESULT FMOD_Channel_Get3DSpread(
  FMOD_CHANNEL *channel,
  float *angle
);
FMOD_RESULT FMOD_ChannelGroup_Get3DSpread(
  FMOD_CHANNELGROUP *channelgroup,
  float *angle
);
```

### C#
```csharp
RESULT ChannelControl.get3DSpread(
  out float angle
);
```

### JavaScript
```javascript
Channel.get3DSpread(
  angle
);
ChannelGroup.get3DSpread(
  angle
);
```

## channelcontrol_getaudibility
kind: function
index: 17

### C++
```cpp
FMOD_RESULT ChannelControl::getAudibility(
  float *audibility
);
```

### C
```c
FMOD_RESULT FMOD_Channel_GetAudibility(
  FMOD_CHANNEL *channel,
  float *audibility
);
FMOD_RESULT FMOD_ChannelGroup_GetAudibility(
  FMOD_CHANNELGROUP *channelgroup,
  float *audibility
);
```

### C#
```csharp
RESULT ChannelControl.getAudibility(
  out float audibility
);
```

### JavaScript
```javascript
Channel.getAudibility(
  audibility
);
ChannelGroup.getAudibility(
  audibility
);
```

## channelcontrol_getdelay
kind: function
index: 18

### C++
```cpp
FMOD_RESULT ChannelControl::getDelay(
  unsigned long long *dspclock_start,
  unsigned long long *dspclock_end,
  bool *stopchannels = nullptr
);
```

### C
```c
FMOD_RESULT FMOD_Channel_GetDelay(
  FMOD_CHANNEL *channel,
  unsigned long long *dspclock_start,
  unsigned long long *dspclock_end,
  FMOD_BOOL *stopchannels
);
FMOD_RESULT FMOD_ChannelGroup_GetDelay(
  FMOD_CHANNELGROUP *channelgroup,
  unsigned long long *dspclock_start,
  unsigned long long *dspclock_end,
  FMOD_BOOL *stopchannels
);
```

### C#
```csharp
RESULT ChannelControl.getDelay(
  out ulong dspclock_start,
  out ulong dspclock_end
);
RESULT ChannelControl.getDelay(
  out ulong dspclock_start,
  out ulong dspclock_end,
  out bool stopchannels
);
```

### JavaScript
```javascript
Channel.getDelay(
  dspclock_start,
  dspclock_end,
  stopchannels
);
ChannelGroup.getDelay(
  dspclock_start,
  dspclock_end,
  stopchannels
);
```

## channelcontrol_getdsp
kind: function
index: 19

### C++
```cpp
FMOD_RESULT ChannelControl::getDSP(
  int index,
  DSP **dsp
);
```

### C
```c
FMOD_RESULT FMOD_Channel_GetDSP(
  FMOD_CHANNEL *channel,
  int index,
  FMOD_DSP **dsp
);
FMOD_RESULT FMOD_ChannelGroup_GetDSP(
  FMOD_CHANNELGROUP *channelgroup,
  int index,
  FMOD_DSP **dsp
);
```

### C#
```csharp
RESULT ChannelControl.getDSP(
  int index,
  out DSP dsp
);
```

### JavaScript
```javascript
Channel.getDSP(
  index,
  dsp
);
ChannelGroup.getDSP(
  index,
  dsp
);
```

## channelcontrol_getdspclock
kind: function
index: 20

### C++
```cpp
FMOD_RESULT ChannelControl::getDSPClock(
  unsigned long long *dspclock,
  unsigned long long *parentclock
);
```

### C
```c
FMOD_RESULT FMOD_Channel_GetDSPClock(
  FMOD_CHANNEL *channel,
  unsigned long long *dspclock,
  unsigned long long *parentclock
);
FMOD_RESULT FMOD_ChannelGroup_GetDSPClock(
  FMOD_CHANNELGROUP *channelgroup,
  unsigned long long *dspclock,
  unsigned long long *parentclock
);
```

### C#
```csharp
RESULT ChannelControl.getDSPClock(
  out ulong dspclock,
  out ulong parentclock
);
```

### JavaScript
```javascript
Channel.getDSPClock(
  dspclock,
  parentclock
);
ChannelGroup.getDSPClock(
  dspclock,
  parentclock
);
```

## channelcontrol_getdspindex
kind: function
index: 21

### C++
```cpp
FMOD_RESULT ChannelControl::getDSPIndex(
  DSP *dsp,
  int *index
);
```

### C
```c
FMOD_RESULT FMOD_Channel_GetDSPIndex(
  FMOD_CHANNEL *channel,
  FMOD_DSP *dsp,
  int *index
);
FMOD_RESULT FMOD_ChannelGroup_GetDSPIndex(
  FMOD_CHANNELGROUP *channelgroup,
  FMOD_DSP *dsp,
  int *index
);
```

### C#
```csharp
RESULT ChannelControl.getDSPIndex(
  DSP dsp,
  out int index
);
```

### JavaScript
```javascript
Channel.getDSPIndex(
  dsp,
  index
);
ChannelGroup.getDSPIndex(
  dsp,
  index
);
```

## channelcontrol_getfadepoints
kind: function
index: 22

### C++
```cpp
FMOD_RESULT ChannelControl::getFadePoints(
  unsigned int *numpoints,
  unsigned long long *point_dspclock,
  float *point_volume
);
```

### C
```c
FMOD_RESULT FMOD_Channel_GetFadePoints(
  FMOD_CHANNEL *channel,
  unsigned int *numpoints,
  unsigned long long *point_dspclock,
  float *point_volume
);
FMOD_RESULT FMOD_ChannelGroup_GetFadePoints(
  FMOD_CHANNELGROUP *channelgroup,
  unsigned int *numpoints,
  unsigned long long *point_dspclock,
  float *point_volume
);
```

### C#
```csharp
RESULT ChannelControl.getFadePoints(
  ref uint numpoints,
  ulong[] point_dspclock,
  float[] point_volume
);
```

### JavaScript
```javascript
Channel.getFadePoints(
  numpoints,
  point_dspclock,
  point_volume
);
ChannelGroup.getFadePoints(
  numpoints,
  point_dspclock,
  point_volume
);
```

## channelcontrol_getlowpassgain
kind: function
index: 23

### C++
```cpp
FMOD_RESULT ChannelControl::getLowPassGain(
  float *gain
);
```

### C
```c
FMOD_RESULT FMOD_Channel_GetLowPassGain(
  FMOD_CHANNEL *channel,
  float *gain
);
FMOD_RESULT FMOD_ChannelGroup_GetLowPassGain(
  FMOD_CHANNELGROUP *channelgroup,
  float *gain
);
```

### C#
```csharp
RESULT ChannelControl.getLowPassGain(
  out float gain
);
```

### JavaScript
```javascript
Channel.getLowPassGain(
  gain
);
ChannelGroup.getLowPassGain(
  gain
);
```

## channelcontrol_getmixmatrix
kind: function
index: 24

### C++
```cpp
FMOD_RESULT ChannelControl::getMixMatrix(
  float *matrix,
  int *outchannels,
  int *inchannels,
  int inchannel_hop = 0
);
```

### C
```c
FMOD_RESULT FMOD_Channel_GetMixMatrix(
  FMOD_CHANNEL *channel,
  float *matrix,
  int *outchannels,
  int *inchannels,
  int inchannel_hop
);
FMOD_RESULT FMOD_ChannelGroup_GetMixMatrix(
  FMOD_CHANNELGROUP *channelgroup,
  float *matrix,
  int *outchannels,
  int *inchannels,
  int inchannel_hop
);
```

### C#
```csharp
RESULT ChannelControl.getMixMatrix(
  float[] matrix,
  out int outchannels,
  out int inchannels,
  int inchannel_hop = 0
);
```

### JavaScript
```javascript
Channel.getMixMatrix(
  matrix,
  outchannels,
  inchannels,
  inchannel_hop
);
ChannelGroup.getMixMatrix(
  matrix,
  outchannels,
  inchannels,
  inchannel_hop
);
```

## channelcontrol_getmode
kind: function
index: 25

### C++
```cpp
FMOD_RESULT ChannelControl::getMode(
  FMOD_MODE *mode
);
```

### C
```c
FMOD_RESULT FMOD_Channel_GetMode(
  FMOD_CHANNEL *channel,
  FMOD_MODE *mode
);
FMOD_RESULT FMOD_ChannelGroup_GetMode(
  FMOD_CHANNELGROUP *channelgroup,
  FMOD_MODE *mode
);
```

### C#
```csharp
RESULT ChannelControl.getMode(
  out MODE mode
);
```

### JavaScript
```javascript
Channel.getMode(
  mode
);
ChannelGroup.getMode(
  mode
);
```

## channelcontrol_getmute
kind: function
index: 26

### C++
```cpp
FMOD_RESULT ChannelControl::getMute(
  bool *mute
);
```

### C
```c
FMOD_RESULT FMOD_Channel_GetMute(
  FMOD_CHANNEL *channel,
  FMOD_BOOL *mute
);
FMOD_RESULT FMOD_ChannelGroup_GetMute(
  FMOD_CHANNELGROUP *channelgroup,
  FMOD_BOOL *mute
);
```

### C#
```csharp
RESULT ChannelControl.getMute(
  out bool mute
);
```

### JavaScript
```javascript
Channel.getMute(
  mute
);
ChannelGroup.getMute(
  mute
);
```

## channelcontrol_getnumdsps
kind: function
index: 27

### C++
```cpp
FMOD_RESULT ChannelControl::getNumDSPs(
  int *numdsps
);
```

### C
```c
FMOD_RESULT FMOD_Channel_GetNumDSPs(
  FMOD_CHANNEL *channel,
  int *numdsps
);
FMOD_RESULT FMOD_ChannelGroup_GetNumDSPs(
  FMOD_CHANNELGROUP *channelgroup,
  int *numdsps
);
```

### C#
```csharp
RESULT ChannelControl.getNumDSPs(
  out int numdsps
);
```

### JavaScript
```javascript
Channel.getNumDSPs(
  numdsps
);
ChannelGroup.getNumDSPs(
  numdsps
);
```

## channelcontrol_getpaused
kind: function
index: 28

### C++
```cpp
FMOD_RESULT ChannelControl::getPaused(
  bool *paused
);
```

### C
```c
FMOD_RESULT FMOD_Channel_GetPaused(
  FMOD_CHANNEL *channel,
  FMOD_BOOL *paused
);
FMOD_RESULT FMOD_ChannelGroup_GetPaused(
  FMOD_CHANNELGROUP *channelgroup,
  FMOD_BOOL *paused
);
```

### C#
```csharp
RESULT ChannelControl.getPaused(
  out bool paused
);
```

### JavaScript
```javascript
Channel.getPaused(
  paused
);
ChannelGroup.getPaused(
  paused
);
```

## channelcontrol_getpitch
kind: function
index: 29

### C++
```cpp
FMOD_RESULT ChannelControl::getPitch(
  float *pitch
);
```

### C
```c
FMOD_RESULT FMOD_Channel_GetPitch(
  FMOD_CHANNEL *channel,
  float *pitch
);
FMOD_RESULT FMOD_ChannelGroup_GetPitch(
  FMOD_CHANNELGROUP *channelgroup,
  float *pitch
);
```

### C#
```csharp
RESULT ChannelControl.getPitch(
  out float pitch
);
```

### JavaScript
```javascript
Channel.getPitch(
  pitch
);
ChannelGroup.getPitch(
  pitch
);
```

## channelcontrol_getreverbproperties
kind: function
index: 30

### C++
```cpp
FMOD_RESULT ChannelControl::getReverbProperties(
  int instance,
  float *wet
);
```

### C
```c
FMOD_RESULT FMOD_Channel_GetReverbProperties(
  FMOD_CHANNEL *channel,
  int instance,
  float *wet
);
FMOD_RESULT FMOD_ChannelGroup_GetReverbProperties(
  FMOD_CHANNELGROUP *channelgroup,
  int instance,
  float *wet
);
```

### C#
```csharp
RESULT ChannelControl.getReverbProperties(
  int instance,
  out float wet
);
```

### JavaScript
```javascript
Channel.getReverbProperties(
  instance,
  wet
);
ChannelGroup.getReverbProperties(
  instance,
  wet
);
```

## channelcontrol_getsystemobject
kind: function
index: 31

### C++
```cpp
FMOD_RESULT ChannelControl::getSystemObject(
  System **system
);
```

### C
```c
FMOD_RESULT FMOD_Channel_GetSystemObject(
  FMOD_CHANNEL *channel,
  FMOD_SYSTEM **system
);
FMOD_RESULT FMOD_ChannelGroup_GetSystemObject(
  FMOD_CHANNELGROUP *channelgroup,
  FMOD_SYSTEM **system
);
```

### C#
```csharp
RESULT ChannelControl.getSystemObject(
  out System system
);
```

### JavaScript
```javascript
Channel.getSystemObject(
  system
);
ChannelGroup.getSystemObject(
  system
);
```

## channelcontrol_getuserdata
kind: function
index: 32

### C++
```cpp
FMOD_RESULT ChannelControl::getUserData(
  void **userdata
);
```

### C
```c
FMOD_RESULT FMOD_Channel_GetUserData(
  FMOD_CHANNEL *channel,
  void **userdata
);
FMOD_RESULT FMOD_ChannelGroup_GetUserData(
  FMOD_CHANNELGROUP *channelgroup,
  void **userdata
);
```

### C#
```csharp
RESULT ChannelControl.getUserData(
  out IntPtr userdata
);
```

### JavaScript
```javascript
Channel.getUserData(
  userdata
);
ChannelGroup.getUserData(
  userdata
);
```

## channelcontrol_getvolume
kind: function
index: 33

### C++
```cpp
FMOD_RESULT ChannelControl::getVolume(
  float *volume
);
```

### C
```c
FMOD_RESULT FMOD_Channel_GetVolume(
  FMOD_CHANNEL *channel,
  float *volume
);
FMOD_RESULT FMOD_ChannelGroup_GetVolume(
  FMOD_CHANNELGROUP *channelgroup,
  float *volume
);
```

### C#
```csharp
RESULT ChannelControl.getVolume(
  out float volume
);
```

### JavaScript
```javascript
Channel.getVolume(
  volume
);
ChannelGroup.getVolume(
  volume
);
```

## channelcontrol_getvolumeramp
kind: function
index: 34

### C++
```cpp
FMOD_RESULT ChannelControl::getVolumeRamp(
  bool *ramp
);
```

### C
```c
FMOD_RESULT FMOD_Channel_GetVolumeRamp(
  FMOD_CHANNEL *channel,
  FMOD_BOOL *ramp
);
FMOD_RESULT FMOD_ChannelGroup_GetVolumeRamp(
  FMOD_CHANNELGROUP *channelgroup,
  FMOD_BOOL *ramp
);
```

### C#
```csharp
RESULT ChannelControl.getVolumeRamp(
  out bool ramp
);
```

### JavaScript
```javascript
Channel.getVolumeRamp(
  ramp
);
ChannelGroup.getVolumeRamp(
  ramp
);
```

## channelcontrol_isplaying
kind: function
index: 35

### C++
```cpp
FMOD_RESULT ChannelControl::isPlaying(
  bool *isplaying
);
```

### C
```c
FMOD_RESULT FMOD_Channel_IsPlaying(
  FMOD_CHANNEL *channel,
  FMOD_BOOL *isplaying
);
FMOD_RESULT FMOD_ChannelGroup_IsPlaying(
  FMOD_CHANNELGROUP *channelgroup,
  FMOD_BOOL *isplaying
);
```

### C#
```csharp
RESULT ChannelControl.isPlaying(
  out bool isplaying
);
```

### JavaScript
```javascript
Channel.isPlaying(
  isplaying
);
ChannelGroup.isPlaying(
  isplaying
);
```

## channelcontrol_removedsp
kind: function
index: 36

### C++
```cpp
FMOD_RESULT ChannelControl::removeDSP(
  DSP *dsp
);
```

### C
```c
FMOD_RESULT FMOD_Channel_RemoveDSP(
  FMOD_CHANNEL *channel,
  FMOD_DSP *dsp
);
FMOD_RESULT FMOD_ChannelGroup_RemoveDSP(
  FMOD_CHANNELGROUP *channelgroup,
  FMOD_DSP *dsp
);
```

### C#
```csharp
RESULT ChannelControl.removeDSP(
  DSP dsp
);
```

### JavaScript
```javascript
Channel.removeDSP(
  dsp
);
ChannelGroup.removeDSP(
  dsp
);
```

## channelcontrol_removefadepoints
kind: function
index: 37

### C++
```cpp
FMOD_RESULT ChannelControl::removeFadePoints(
  unsigned long long dspclock_start,
  unsigned long long dspclock_end
);
```

### C
```c
FMOD_RESULT FMOD_Channel_RemoveFadePoints(
  FMOD_CHANNEL *channel,
  unsigned long long dspclock_start,
  unsigned long long dspclock_end
);
FMOD_RESULT FMOD_ChannelGroup_RemoveFadePoints(
  FMOD_CHANNELGROUP *channelgroup,
  unsigned long long dspclock_start,
  unsigned long long dspclock_end
);
```

### C#
```csharp
RESULT ChannelControl.removeFadePoints(
  ulong dspclock_start,
  ulong dspclock_end
);
```

### JavaScript
```javascript
Channel.removeFadePoints(
  dspclock_start,
  dspclock_end
);
ChannelGroup.removeFadePoints(
  dspclock_start,
  dspclock_end
);
```

## channelcontrol_set3dattributes
kind: function
index: 38

### C++
```cpp
FMOD_RESULT ChannelControl::set3DAttributes(
  const FMOD_VECTOR *pos,
  const FMOD_VECTOR *vel
);
```

### C
```c
FMOD_RESULT FMOD_Channel_Set3DAttributes(
  FMOD_CHANNEL *channel,
  const FMOD_VECTOR *pos,
  const FMOD_VECTOR *vel
);
FMOD_RESULT FMOD_ChannelGroup_Set3DAttributes(
  FMOD_CHANNELGROUP *channelgroup,
  const FMOD_VECTOR *pos,
  const FMOD_VECTOR *vel
);
```

### C#
```csharp
RESULT ChannelControl.set3DAttributes(
  ref VECTOR pos,
  ref VECTOR vel
);
RESULT ChannelControl.set3DAttributes(
  ref VECTOR pos,
  ref VECTOR vel
);
```

### JavaScript
```javascript
Channel.set3DAttributes(
  pos,
  vel
);
ChannelGroup.set3DAttributes(
  pos,
  vel
);
```

## channelcontrol_set3dconeorientation
kind: function
index: 39

### C++
```cpp
FMOD_RESULT ChannelControl::set3DConeOrientation(
  FMOD_VECTOR *orientation
);
```

### C
```c
FMOD_RESULT FMOD_Channel_Set3DConeOrientation(
  FMOD_CHANNEL *channel,
  FMOD_VECTOR *orientation
);
FMOD_RESULT FMOD_ChannelGroup_Set3DConeOrientation(
  FMOD_CHANNELGROUP *channelgroup,
  FMOD_VECTOR *orientation
);
```

### C#
```csharp
RESULT ChannelControl.set3DConeOrientation(
  ref VECTOR orientation
);
```

### JavaScript
```javascript
Channel.set3DConeOrientation(
  orientation
);
ChannelGroup.set3DConeOrientation(
  orientation
);
```

## channelcontrol_set3dconesettings
kind: function
index: 40

### C++
```cpp
FMOD_RESULT ChannelControl::set3DConeSettings(
  float insideconeangle,
  float outsideconeangle,
  float outsidevolume
);
```

### C
```c
FMOD_RESULT FMOD_Channel_Set3DConeSettings(
  FMOD_CHANNEL *channel,
  float insideconeangle,
  float outsideconeangle,
  float outsidevolume
);
FMOD_RESULT FMOD_ChannelGroup_Set3DConeSettings(
  FMOD_CHANNELGROUP *channelgroup,
  float insideconeangle,
  float outsideconeangle,
  float outsidevolume
);
```

### C#
```csharp
RESULT ChannelControl.set3DConeSettings(
  float insideconeangle,
  float outsideconeangle,
  float outsidevolume
);
```

### JavaScript
```javascript
Channel.set3DConeSettings(
  insideconeangle,
  outsideconeangle,
  outsidevolume
);
ChannelGroup.set3DConeSettings(
  insideconeangle,
  outsideconeangle,
  outsidevolume
);
```

## channelcontrol_set3dcustomrolloff
kind: function
index: 41

### C++
```cpp
FMOD_RESULT ChannelControl::set3DCustomRolloff(
  FMOD_VECTOR *points,
  int numpoints
);
```

### C
```c
FMOD_RESULT FMOD_Channel_Set3DCustomRolloff(
  FMOD_CHANNEL *channel,
  FMOD_VECTOR *points,
  int numpoints
);
FMOD_RESULT FMOD_ChannelGroup_Set3DCustomRolloff(
  FMOD_CHANNELGROUP *channelgroup,
  FMOD_VECTOR *points,
  int numpoints
);
```

### C#
```csharp
RESULT ChannelControl.set3DCustomRolloff(
  ref VECTOR points,
  int numpoints
);
```

### JavaScript
```javascript
Channel.set3DCustomRolloff(
  points,
  numpoints
);
ChannelGroup.set3DCustomRolloff(
  points,
  numpoints
);
```

## ChannelControl::set3DCustomRolloff
kind: example
index: 42
heading: ChannelControl::set3DCustomRolloff

### C/C++
```cpp
// Defining a custom array of points
FMOD_VECTOR curve[3] =
{
    { 0.0f,  1.0f, 0.0f },
    { 2.0f,  0.2f, 0.0f },
    { 20.0f, 0.0f, 0.0f }
};
```

## channelcontrol_set3ddistancefilter
kind: function
index: 43

### C++
```cpp
FMOD_RESULT ChannelControl::set3DDistanceFilter(
  bool custom,
  float customLevel,
  float centerFreq
);
```

### C
```c
FMOD_RESULT FMOD_Channel_Set3DDistanceFilter(
  FMOD_CHANNEL *channel,
  FMOD_BOOL custom,
  float customLevel,
  float centerFreq
);
FMOD_RESULT FMOD_ChannelGroup_Set3DDistanceFilter(
  FMOD_CHANNELGROUP *channelgroup,
  FMOD_BOOL custom,
  float customLevel,
  float centerFreq
);
```

### C#
```csharp
RESULT ChannelControl.set3DDistanceFilter(
  bool custom,
  float customLevel,
  float centerFreq
);
```

### JavaScript
```javascript
Channel.set3DDistanceFilter(
  custom,
  customLevel,
  centerFreq
);
ChannelGroup.set3DDistanceFilter(
  custom,
  customLevel,
  centerFreq
);
```

## channelcontrol_set3ddopplerlevel
kind: function
index: 44

### C++
```cpp
FMOD_RESULT ChannelControl::set3DDopplerLevel(
  float level
);
```

### C
```c
FMOD_RESULT FMOD_Channel_Set3DDopplerLevel(
  FMOD_CHANNEL *channel,
  float level
);
FMOD_RESULT FMOD_ChannelGroup_Set3DDopplerLevel(
  FMOD_CHANNELGROUP *channelgroup,
  float level
);
```

### C#
```csharp
RESULT ChannelControl.set3DDopplerLevel(
  float level
);
```

### JavaScript
```javascript
Channel.set3DDopplerLevel(
  level
);
ChannelGroup.set3DDopplerLevel(
  level
);
```

## channelcontrol_set3dlevel
kind: function
index: 45

### C++
```cpp
FMOD_RESULT ChannelControl::set3DLevel(
  float level
);
```

### C
```c
FMOD_RESULT FMOD_Channel_Set3DLevel(
  FMOD_CHANNEL *channel,
  float level
);
FMOD_RESULT FMOD_ChannelGroup_Set3DLevel(
  FMOD_CHANNELGROUP *channelgroup,
  float level
);
```

### C#
```csharp
RESULT ChannelControl.set3DLevel(
  float level
);
```

### JavaScript
```javascript
Channel.set3DLevel(
  level
);
ChannelGroup.set3DLevel(
  level
);
```

## channelcontrol_set3dminmaxdistance
kind: function
index: 46

### C++
```cpp
FMOD_RESULT ChannelControl::set3DMinMaxDistance(
  float mindistance,
  float maxdistance
);
```

### C
```c
FMOD_RESULT FMOD_Channel_Set3DMinMaxDistance(
  FMOD_CHANNEL *channel,
  float mindistance,
  float maxdistance
);
FMOD_RESULT FMOD_ChannelGroup_Set3DMinMaxDistance(
  FMOD_CHANNELGROUP *channelgroup,
  float mindistance,
  float maxdistance
);
```

### C#
```csharp
RESULT ChannelControl.set3DMinMaxDistance(
  float mindistance,
  float maxdistance
);
```

### JavaScript
```javascript
Channel.set3DMinMaxDistance(
  mindistance,
  maxdistance
);
ChannelGroup.set3DMinMaxDistance(
  mindistance,
  maxdistance
);
```

## channelcontrol_set3docclusion
kind: function
index: 47

### C++
```cpp
FMOD_RESULT ChannelControl::set3DOcclusion(
  float directocclusion,
  float reverbocclusion
);
```

### C
```c
FMOD_RESULT FMOD_Channel_Set3DOcclusion(
  FMOD_CHANNEL *channel,
  float directocclusion,
  float reverbocclusion
);
FMOD_RESULT FMOD_ChannelGroup_Set3DOcclusion(
  FMOD_CHANNELGROUP *channelgroup,
  float directocclusion,
  float reverbocclusion
);
```

### C#
```csharp
RESULT ChannelControl.set3DOcclusion(
  float directocclusion,
  float reverbocclusion
);
```

### JavaScript
```javascript
Channel.set3DOcclusion(
  directocclusion,
  reverbocclusion
);
ChannelGroup.set3DOcclusion(
  directocclusion,
  reverbocclusion
);
```

## channelcontrol_set3dspread
kind: function
index: 48

### C++
```cpp
FMOD_RESULT ChannelControl::set3DSpread(
  float angle
);
```

### C
```c
FMOD_RESULT FMOD_Channel_Set3DSpread(
  FMOD_CHANNEL *channel,
  float angle
);
FMOD_RESULT FMOD_ChannelGroup_Set3DSpread(
  FMOD_CHANNELGROUP *channelgroup,
  float angle
);
```

### C#
```csharp
RESULT ChannelControl.set3DSpread(
  float angle
);
```

### JavaScript
```javascript
Channel.set3DSpread(
  angle
);
ChannelGroup.set3DSpread(
  angle
);
```

## channelcontrol_setcallback
kind: function
index: 49

### C++
```cpp
FMOD_RESULT ChannelControl::setCallback(
  FMOD_CHANNELCONTROL_CALLBACK callback
);
```

### C
```c
FMOD_RESULT FMOD_Channel_SetCallback(
  FMOD_CHANNEL *channel,
  FMOD_CHANNELCONTROL_CALLBACK callback
);
FMOD_RESULT FMOD_ChannelGroup_SetCallback(
  FMOD_CHANNELGROUP *channelgroup,
  FMOD_CHANNELCONTROL_CALLBACK callback
);
```

### C#
```csharp
RESULT ChannelControl.setCallback(
  CHANNEL_CALLBACK callback
);
```

### JavaScript
```javascript
Channel.setCallback(
  callback
);
ChannelGroup.setCallback(
  callback
);
```

## channelcontrol_setdelay
kind: function
index: 50

### C++
```cpp
FMOD_RESULT ChannelControl::setDelay(
  unsigned long long dspclock_start,
  unsigned long long dspclock_end,
  bool stopchannels = true
);
```

### C
```c
FMOD_RESULT FMOD_Channel_SetDelay(
  FMOD_CHANNEL *channel,
  unsigned long long dspclock_start,
  unsigned long long dspclock_end,
  FMOD_BOOL stopchannels
);
FMOD_RESULT FMOD_ChannelGroup_SetDelay(
  FMOD_CHANNELGROUP *channelgroup,
  unsigned long long dspclock_start,
  unsigned long long dspclock_end,
  FMOD_BOOL stopchannels
);
```

### C#
```csharp
RESULT ChannelControl.setDelay(
  ulong dspclock_start,
  ulong dspclock_end,
  bool stopchannels = true
);
```

### JavaScript
```javascript
Channel.setDelay(
  dspclock_start,
  dspclock_end,
  stopchannels
);
ChannelGroup.setDelay(
  dspclock_start,
  dspclock_end,
  stopchannels
);
```

## channelcontrol_setdspindex
kind: function
index: 51

### C++
```cpp
FMOD_RESULT ChannelControl::setDSPIndex(
  DSP *dsp,
  int index
);
```

### C
```c
FMOD_RESULT FMOD_Channel_SetDSPIndex(
  FMOD_CHANNEL *channel,
  FMOD_DSP *dsp,
  int index
);
FMOD_RESULT FMOD_ChannelGroup_SetDSPIndex(
  FMOD_CHANNELGROUP *channelgroup,
  FMOD_DSP *dsp,
  int index
);
```

### C#
```csharp
RESULT ChannelControl.setDSPIndex(
  DSP dsp,
  int index
);
```

### JavaScript
```javascript
Channel.setDSPIndex(
  dsp,
  index
);
ChannelGroup.setDSPIndex(
  dsp,
  index
);
```

## channelcontrol_setfadepointramp
kind: function
index: 52

### C++
```cpp
FMOD_RESULT ChannelControl::setFadePointRamp(
  unsigned long long dspclock,
  float volume
);
```

### C
```c
FMOD_RESULT FMOD_Channel_SetFadePointRamp(
  FMOD_CHANNEL *channel,
  unsigned long long dspclock,
  float volume
);
FMOD_RESULT FMOD_ChannelGroup_SetFadePointRamp(
  FMOD_CHANNELGROUP *channelgroup,
  unsigned long long dspclock,
  float volume
);
```

### C#
```csharp
RESULT ChannelControl.setFadePointRamp(
  ulong dspclock,
  float volume
);
```

### JavaScript
```javascript
Channel.setFadePointRamp(
  dspclock,
  volume
);
ChannelGroup.setFadePointRamp(
  dspclock,
  volume
);
```

## channelcontrol_setlowpassgain
kind: function
index: 53

### C++
```cpp
FMOD_RESULT ChannelControl::setLowPassGain(
  float gain
);
```

### C
```c
FMOD_RESULT FMOD_Channel_SetLowPassGain(
  FMOD_CHANNEL *channel,
  float gain
);
FMOD_RESULT FMOD_ChannelGroup_SetLowPassGain(
  FMOD_CHANNELGROUP *channelgroup,
  float gain
);
```

### C#
```csharp
RESULT ChannelControl.setLowPassGain(
  float gain
);
```

### JavaScript
```javascript
Channel.setLowPassGain(
  gain
);
ChannelGroup.setLowPassGain(
  gain
);
```

## channelcontrol_setmixlevelsinput
kind: function
index: 54

### C++
```cpp
FMOD_RESULT ChannelControl::setMixLevelsInput(
  float *levels,
  int numlevels
);
```

### C
```c
FMOD_RESULT FMOD_Channel_SetMixLevelsInput(
  FMOD_CHANNEL *channel,
  float *levels,
  int numlevels
);
FMOD_RESULT FMOD_ChannelGroup_SetMixLevelsInput(
  FMOD_CHANNELGROUP *channelgroup,
  float *levels,
  int numlevels
);
```

### C#
```csharp
RESULT ChannelControl.setMixLevelsInput(
  float[] levels,
  int numlevels
);
```

### JavaScript
```javascript
Channel.setMixLevelsInput(
  levels,
  numlevels
);
ChannelGroup.setMixLevelsInput(
  levels,
  numlevels
);
```

## channelcontrol_setmixlevelsoutput
kind: function
index: 55

### C++
```cpp
FMOD_RESULT ChannelControl::setMixLevelsOutput(
  float frontleft,
  float frontright,
  float center,
  float lfe,
  float surroundleft,
  float surroundright,
  float backleft,
  float backright
);
```

### C
```c
FMOD_RESULT FMOD_Channel_SetMixLevelsOutput(
  FMOD_CHANNEL *channel,
  float frontleft,
  float frontright,
  float center,
  float lfe,
  float surroundleft,
  float surroundright,
  float backleft,
  float backright
);
FMOD_RESULT FMOD_ChannelGroup_SetMixLevelsOutput(
  FMOD_CHANNELGROUP *channelgroup,
  float frontleft,
  float frontright,
  float center,
  float lfe,
  float surroundleft,
  float surroundright,
  float backleft,
  float backright
);
```

### C#
```csharp
RESULT ChannelControl.setMixLevelsOutput(
  float frontleft,
  float frontright,
  float center,
  float lfe,
  float surroundleft,
  float surroundright,
  float backleft,
  float backright
);
```

### JavaScript
```javascript
Channel.setMixLevelsOutput(
  frontleft,
  frontright,
  center,
  lfe,
  surroundleft,
  surroundright,
  backleft,
  backright
);
ChannelGroup.setMixLevelsOutput(
  frontleft,
  frontright,
  center,
  lfe,
  surroundleft,
  surroundright,
  backleft,
  backright
);
```

## channelcontrol_setmixmatrix
kind: function
index: 56

### C++
```cpp
FMOD_RESULT ChannelControl::setMixMatrix(
  float *matrix,
  int outchannels,
  int inchannels,
  int inchannel_hop = 0
);
```

### C
```c
FMOD_RESULT FMOD_Channel_SetMixMatrix(
  FMOD_CHANNEL *channel,
  float *matrix,
  int outchannels,
  int inchannels,
  int inchannel_hop
);
FMOD_RESULT FMOD_ChannelGroup_SetMixMatrix(
  FMOD_CHANNELGROUP *channelgroup,
  float *matrix,
  int outchannels,
  int inchannels,
  int inchannel_hop
);
```

### C#
```csharp
RESULT ChannelControl.setMixMatrix(
  float[] matrix,
  int outchannels,
  int inchannels,
  int inchannel_hop = 0
);
```

### JavaScript
```javascript
Channel.setMixMatrix(
  matrix,
  outchannels,
  inchannels,
  inchannel_hop
);
ChannelGroup.setMixMatrix(
  matrix,
  outchannels,
  inchannels,
  inchannel_hop
);
```

## channelcontrol_setmode
kind: function
index: 57

### C++
```cpp
FMOD_RESULT ChannelControl::setMode(
  FMOD_MODE mode
);
```

### C
```c
FMOD_RESULT FMOD_Channel_SetMode(
  FMOD_CHANNEL *channel,
  FMOD_MODE mode
);
FMOD_RESULT FMOD_ChannelGroup_SetMode(
  FMOD_CHANNELGROUP *channelgroup,
  FMOD_MODE mode
);
```

### C#
```csharp
RESULT ChannelControl.setMode(
  MODE mode
);
```

### JavaScript
```javascript
Channel.setMode(
  mode
);
ChannelGroup.setMode(
  mode
);
```

## channelcontrol_setmute
kind: function
index: 58

### C++
```cpp
FMOD_RESULT ChannelControl::setMute(
  bool mute
);
```

### C
```c
FMOD_RESULT FMOD_Channel_SetMute(
  FMOD_CHANNEL *channel,
  FMOD_BOOL mute
);
FMOD_RESULT FMOD_ChannelGroup_SetMute(
  FMOD_CHANNELGROUP *channelgroup,
  FMOD_BOOL mute
);
```

### C#
```csharp
RESULT ChannelControl.setMute(
  bool mute
);
```

### JavaScript
```javascript
Channel.setMute(
  mute
);
ChannelGroup.setMute(
  mute
);
```

## channelcontrol_setpan
kind: function
index: 59

### C++
```cpp
FMOD_RESULT ChannelControl::setPan(
  float pan
);
```

### C
```c
FMOD_RESULT FMOD_Channel_SetPan(
  FMOD_CHANNEL *channel,
  float pan
);
FMOD_RESULT FMOD_ChannelGroup_SetPan(
  FMOD_CHANNELGROUP *channelgroup,
  float pan
);
```

### C#
```csharp
RESULT ChannelControl.setPan(
  float pan
);
```

### JavaScript
```javascript
Channel.setPan(
  pan
);
ChannelGroup.setPan(
  pan
);
```

## channelcontrol_setpaused
kind: function
index: 60

### C++
```cpp
FMOD_RESULT ChannelControl::setPaused(
  bool paused
);
```

### C
```c
FMOD_RESULT FMOD_Channel_SetPaused(
  FMOD_CHANNEL *channel,
  FMOD_BOOL paused
);
FMOD_RESULT FMOD_ChannelGroup_SetPaused(
  FMOD_CHANNELGROUP *channelgroup,
  FMOD_BOOL paused
);
```

### C#
```csharp
RESULT ChannelControl.setPaused(
  bool paused
);
```

### JavaScript
```javascript
Channel.setPaused(
  paused
);
ChannelGroup.setPaused(
  paused
);
```

## channelcontrol_setpitch
kind: function
index: 61

### C++
```cpp
FMOD_RESULT ChannelControl::setPitch(
  float pitch
);
```

### C
```c
FMOD_RESULT FMOD_Channel_SetPitch(
  FMOD_CHANNEL *channel,
  float pitch
);
FMOD_RESULT FMOD_ChannelGroup_SetPitch(
  FMOD_CHANNELGROUP *channelgroup,
  float pitch
);
```

### C#
```csharp
RESULT ChannelControl.setPitch(
  float pitch
);
```

### JavaScript
```javascript
Channel.setPitch(
  pitch
);
ChannelGroup.setPitch(
  pitch
);
```

## channelcontrol_setreverbproperties
kind: function
index: 62

### C++
```cpp
FMOD_RESULT ChannelControl::setReverbProperties(
  int instance,
  float wet
);
```

### C
```c
FMOD_RESULT FMOD_Channel_SetReverbProperties(
  FMOD_CHANNEL *channel,
  int instance,
  float wet
);
FMOD_RESULT FMOD_ChannelGroup_SetReverbProperties(
  FMOD_CHANNELGROUP *channelgroup,
  int instance,
  float wet
);
```

### C#
```csharp
RESULT ChannelControl.setReverbProperties(
  int instance,
  float wet
);
```

### JavaScript
```javascript
Channel.setReverbProperties(
  instance,
  wet
);
ChannelGroup.setReverbProperties(
  instance,
  wet
);
```

## channelcontrol_setuserdata
kind: function
index: 63

### C++
```cpp
FMOD_RESULT ChannelControl::setUserData(
  void *userdata
);
```

### C
```c
FMOD_RESULT FMOD_Channel_SetUserData(
  FMOD_CHANNEL *channel,
  void *userdata
);
FMOD_RESULT FMOD_ChannelGroup_SetUserData(
  FMOD_CHANNELGROUP *channelgroup,
  void *userdata
);
```

### C#
```csharp
RESULT ChannelControl.setUserData(
  IntPtr userdata
);
```

### JavaScript
```javascript
Channel.setUserData(
  userdata
);
ChannelGroup.setUserData(
  userdata
);
```

## channelcontrol_setvolume
kind: function
index: 64

### C++
```cpp
FMOD_RESULT ChannelControl::setVolume(
  float volume
);
```

### C
```c
FMOD_RESULT FMOD_Channel_SetVolume(
  FMOD_CHANNEL *channel,
  float volume
);
FMOD_RESULT FMOD_ChannelGroup_SetVolume(
  FMOD_CHANNELGROUP *channelgroup,
  float volume
);
```

### C#
```csharp
RESULT ChannelControl.setVolume(
  float volume
);
```

### JavaScript
```javascript
Channel.setVolume(
  volume
);
ChannelGroup.setVolume(
  volume
);
```

## channelcontrol_setvolumeramp
kind: function
index: 65

### C++
```cpp
FMOD_RESULT ChannelControl::setVolumeRamp(
  bool ramp
);
```

### C
```c
FMOD_RESULT FMOD_Channel_SetVolumeRamp(
  FMOD_CHANNEL *channel,
  FMOD_BOOL ramp
);
FMOD_RESULT FMOD_ChannelGroup_SetVolumeRamp(
  FMOD_CHANNELGROUP *channelgroup,
  FMOD_BOOL ramp
);
```

### C#
```csharp
RESULT ChannelControl.setVolumeRamp(
  bool ramp
);
```

### JavaScript
```javascript
Channel.setVolumeRamp(
  ramp
);
ChannelGroup.setVolumeRamp(
  ramp
);
```

## channelcontrol_stop
kind: function
index: 66

### C++
```cpp
FMOD_RESULT ChannelControl::stop();
```

### C
```c
FMOD_RESULT FMOD_Channel_Stop(FMOD_CHANNEL *channel);
FMOD_RESULT FMOD_ChannelGroup_Stop(FMOD_CHANNELGROUP *channelgroup);
```

### C#
```csharp
RESULT ChannelControl.stop();
```

### JavaScript
```javascript
Channel.stop();
ChannelGroup.stop();
```

## FMOD_CHANNELCONTROL_TYPE
kind: example
index: 67
heading: FMOD_CHANNELCONTROL_TYPE

### C/C++
```cpp
typedef enum FMOD_CHANNELCONTROL_TYPE {
  FMOD_CHANNELCONTROL_CHANNEL,
  FMOD_CHANNELCONTROL_CHANNELGROUP,
  FMOD_CHANNELCONTROL_MAX,
} FMOD_CHANNELCONTROL_TYPE;
```

### C#
```csharp
enum CHANNELCONTROL_TYPE : int
{
    CHANNEL,
    CHANNELGROUP,
    MAX
}
```

### JavaScript
```javascript
CHANNELCONTROL_CHANNEL
CHANNELCONTROL_CHANNELGROUP
CHANNELCONTROL_MAX
```

