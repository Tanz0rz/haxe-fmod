# core-api-sound

## FMOD_OPENSTATE
kind: example
index: 0
heading: FMOD_OPENSTATE
tabbed: yes

### C/C++
```cpp
typedef enum FMOD_OPENSTATE {
  FMOD_OPENSTATE_READY,
  FMOD_OPENSTATE_LOADING,
  FMOD_OPENSTATE_ERROR,
  FMOD_OPENSTATE_CONNECTING,
  FMOD_OPENSTATE_BUFFERING,
  FMOD_OPENSTATE_SEEKING,
  FMOD_OPENSTATE_PLAYING,
  FMOD_OPENSTATE_SETPOSITION,
  FMOD_OPENSTATE_MAX
} FMOD_OPENSTATE;
```

### C#
```csharp
enum OPENSTATE : int
{
  READY,
  LOADING,
  ERROR,
  CONNECTING,
  BUFFERING,
  SEEKING,
  PLAYING,
  SETPOSITION,
  MAX
}
```

### JavaScript
```javascript
FMOD.OPENSTATE_READY
FMOD.OPENSTATE_LOADING
FMOD.OPENSTATE_ERROR
FMOD.OPENSTATE_CONNECTING
FMOD.OPENSTATE_BUFFERING
FMOD.OPENSTATE_SEEKING
FMOD.OPENSTATE_PLAYING
FMOD.OPENSTATE_SETPOSITION
FMOD.OPENSTATE_MAX
```

## sound_addsyncpoint
kind: function
index: 1

### C++
```cpp
FMOD_RESULT Sound::addSyncPoint(
  unsigned int offset,
  FMOD_TIMEUNIT offsettype,
  const char *name,
  FMOD_SYNCPOINT **point
);
```

### C
```c
FMOD_RESULT FMOD_Sound_AddSyncPoint(
  FMOD_SOUND *sound,
  unsigned int offset,
  FMOD_TIMEUNIT offsettype,
  const char *name,
  FMOD_SYNCPOINT **point
);
```

### C#
```csharp
RESULT Sound.addSyncPoint(
  uint offset,
  TIMEUNIT offsettype,
  string name,
  out IntPtr point
);
```

### JavaScript
```javascript
Sound.addSyncPoint(
  offset,
  offsettype,
  name,
  point
);
```

## sound_deletesyncpoint
kind: function
index: 2

### C++
```cpp
FMOD_RESULT Sound::deleteSyncPoint(
  FMOD_SYNCPOINT *point
);
```

### C
```c
FMOD_RESULT FMOD_Sound_DeleteSyncPoint(
  FMOD_SOUND *sound,
  FMOD_SYNCPOINT *point
);
```

### C#
```csharp
RESULT Sound.deleteSyncPoint(
  IntPtr point
);
```

### JavaScript
```javascript
Sound.deleteSyncPoint(
  point
);
```

## FMOD_SOUND_FORMAT
kind: example
index: 3
heading: FMOD_SOUND_FORMAT
tabbed: yes

### C/C++
```cpp
typedef enum FMOD_SOUND_FORMAT {
  FMOD_SOUND_FORMAT_NONE,
  FMOD_SOUND_FORMAT_PCM8,
  FMOD_SOUND_FORMAT_PCM16,
  FMOD_SOUND_FORMAT_PCM24,
  FMOD_SOUND_FORMAT_PCM32,
  FMOD_SOUND_FORMAT_PCMFLOAT,
  FMOD_SOUND_FORMAT_BITSTREAM,
  FMOD_SOUND_FORMAT_MAX
} FMOD_SOUND_FORMAT;
```

### C#
```csharp
enum SOUND_FORMAT
{
  NONE,
  PCM8,
  PCM16,
  PCM24,
  PCM32,
  PCMFLOAT,
  BITSTREAM,
  MAX
}
```

### JavaScript
```javascript
FMOD.SOUND_FORMAT_NONE
FMOD.SOUND_FORMAT_PCM8
FMOD.SOUND_FORMAT_PCM16
FMOD.SOUND_FORMAT_PCM24
FMOD.SOUND_FORMAT_PCM32
FMOD.SOUND_FORMAT_PCMFLOAT
FMOD.SOUND_FORMAT_BITSTREAM
FMOD.SOUND_FORMAT_MAX
```

## sound_get3dconesettings
kind: function
index: 4

### C++
```cpp
FMOD_RESULT Sound::get3DConeSettings(
  float *insideconeangle,
  float *outsideconeangle,
  float *outsidevolume
);
```

### C
```c
FMOD_RESULT FMOD_Sound_Get3DConeSettings(
  FMOD_SOUND *sound,
  float *insideconeangle,
  float *outsideconeangle,
  float *outsidevolume
);
```

### C#
```csharp
RESULT Sound.get3DConeSettings(
  out float insideconeangle,
  out float outsideconeangle,
  out float outsidevolume
);
```

### JavaScript
```javascript
Sound.get3DConeSettings(
  insideconeangle,
  outsideconeangle,
  outsidevolume
);
```

## sound_get3dcustomrolloff
kind: function
index: 5

### C++
```cpp
FMOD_RESULT Sound::get3DCustomRolloff(
  FMOD_VECTOR **points,
  int *numpoints
);
```

### C
```c
FMOD_RESULT FMOD_Sound_Get3DCustomRolloff(
  FMOD_SOUND *sound,
  FMOD_VECTOR **points,
  int *numpoints
);
```

### C#
```csharp
RESULT Sound.get3DCustomRolloff(
  out IntPtr points,
  out int numpoints
);
```

### JavaScript
```javascript
Sound.get3DCustomRolloff(
  points,
  numpoints
);
```

## sound_get3dminmaxdistance
kind: function
index: 6

### C++
```cpp
FMOD_RESULT Sound::get3DMinMaxDistance(
  float *min,
  float *max
);
```

### C
```c
FMOD_RESULT FMOD_Sound_Get3DMinMaxDistance(
  FMOD_SOUND *sound,
  float *min,
  float *max
);
```

### C#
```csharp
RESULT Sound.get3DMinMaxDistance(
  out float min,
  out float max
);
```

### JavaScript
```javascript
Sound.get3DMinMaxDistance(
  min,
  max
);
```

## sound_getdefaults
kind: function
index: 7

### C++
```cpp
FMOD_RESULT Sound::getDefaults(
  float *frequency,
  int *priority
);
```

### C
```c
FMOD_RESULT FMOD_Sound_GetDefaults(
  FMOD_SOUND *sound,
  float *frequency,
  int *priority
);
```

### C#
```csharp
RESULT Sound.getDefaults(
  out float frequency,
  out int priority
);
```

### JavaScript
```javascript
Sound.getDefaults(
  frequency,
  priority
);
```

## sound_getformat
kind: function
index: 8

### C++
```cpp
FMOD_RESULT Sound::getFormat(
  FMOD_SOUND_TYPE *type,
  FMOD_SOUND_FORMAT *format,
  int *channels,
  int *bits
);
```

### C
```c
FMOD_RESULT FMOD_Sound_GetFormat(
  FMOD_SOUND *sound,
  FMOD_SOUND_TYPE *type,
  FMOD_SOUND_FORMAT *format,
  int *channels,
  int *bits
);
```

### C#
```csharp
RESULT Sound.getFormat(
  out SOUND_TYPE type,
  out SOUND_FORMAT format,
  out int channels,
  out int bits
);
```

### JavaScript
```javascript
Sound.getFormat(
  type,
  format,
  channels,
  bits
);
```

## sound_getlength
kind: function
index: 9

### C++
```cpp
FMOD_RESULT Sound::getLength(
  unsigned int *length,
  FMOD_TIMEUNIT lengthtype
);
```

### C
```c
FMOD_RESULT FMOD_Sound_GetLength(
  FMOD_SOUND *sound,
  unsigned int *length,
  FMOD_TIMEUNIT lengthtype
);
```

### C#
```csharp
RESULT Sound.getLength(
  out uint length,
  TIMEUNIT lengthtype
);
```

### JavaScript
```javascript
Sound.getLength(
  length,
  lengthtype
);
```

## sound_getloopcount
kind: function
index: 10

### C++
```cpp
FMOD_RESULT Sound::getLoopCount(
  int *loopcount
);
```

### C
```c
FMOD_RESULT FMOD_Sound_GetLoopCount(
  FMOD_SOUND *sound,
  int *loopcount
);
```

### C#
```csharp
RESULT Sound.getLoopCount(
  out int loopcount
);
```

### JavaScript
```javascript
Sound.getLoopCount(
  loopcount
);
```

## sound_getlooppoints
kind: function
index: 11

### C++
```cpp
FMOD_RESULT Sound::getLoopPoints(
  unsigned int *loopstart,
  FMOD_TIMEUNIT loopstarttype,
  unsigned int *loopend,
  FMOD_TIMEUNIT loopendtype
);
```

### C
```c
FMOD_RESULT FMOD_Sound_GetLoopPoints(
  FMOD_SOUND *sound,
  unsigned int *loopstart,
  FMOD_TIMEUNIT loopstarttype,
  unsigned int *loopend,
  FMOD_TIMEUNIT loopendtype
);
```

### C#
```csharp
RESULT Sound.getLoopPoints(
  out uint loopstart,
  TIMEUNIT loopstarttype,
  out uint loopend,
  TIMEUNIT loopendtype
);
```

### JavaScript
```javascript
Sound.getLoopPoints(
  loopstart,
  loopstarttype,
  loopend,
  loopendtype
);
```

## sound_getmode
kind: function
index: 12

### C++
```cpp
FMOD_RESULT Sound::getMode(
  FMOD_MODE *mode
);
```

### C
```c
FMOD_RESULT FMOD_Sound_GetMode(
  FMOD_SOUND *sound,
  FMOD_MODE *mode
);
```

### C#
```csharp
RESULT Sound.getMode(
  out MODE mode
);
```

### JavaScript
```javascript
Sound.getMode(
  mode
);
```

## sound_getmusicchannelvolume
kind: function
index: 13

### C++
```cpp
FMOD_RESULT Sound::getMusicChannelVolume(
  int channel,
  float *volume
);
```

### C
```c
FMOD_RESULT FMOD_Sound_GetMusicChannelVolume(
  FMOD_SOUND *sound,
  int channel,
  float *volume
);
```

### C#
```csharp
RESULT Sound.getMusicChannelVolume(
  int channel,
  out float volume
);
```

### JavaScript
```javascript
Sound.getMusicChannelVolume(
  channel,
  volume
);
```

## sound_getmusicnumchannels
kind: function
index: 14

### C++
```cpp
FMOD_RESULT Sound::getMusicNumChannels(
  int *numchannels
);
```

### C
```c
FMOD_RESULT FMOD_Sound_GetMusicNumChannels(
  FMOD_SOUND *sound,
  int *numchannels
);
```

### C#
```csharp
RESULT Sound.getMusicNumChannels(
  out int numchannels
);
```

### JavaScript
```javascript
Sound.getMusicNumChannels(
  numchannels
);
```

## sound_getmusicspeed
kind: function
index: 15

### C++
```cpp
FMOD_RESULT Sound::getMusicSpeed(
  float *speed
);
```

### C
```c
FMOD_RESULT FMOD_Sound_GetMusicSpeed(
  FMOD_SOUND *sound,
  float *speed
);
```

### C#
```csharp
RESULT Sound.getMusicSpeed(
  out float speed
);
```

### JavaScript
```javascript
Sound.getMusicSpeed(
  speed
);
```

## sound_getname
kind: function
index: 16

### C++
```cpp
FMOD_RESULT Sound::getName(
  char *name,
  int namelen
);
```

### C
```c
FMOD_RESULT FMOD_Sound_GetName(
  FMOD_SOUND *sound,
  char *name,
  int namelen
);
```

### C#
```csharp
RESULT Sound.getName(
  out string name,
  int namelen
);
```

### JavaScript
```javascript
Sound.getName(
  name
);
```

## sound_getnumsubsounds
kind: function
index: 17

### C++
```cpp
FMOD_RESULT Sound::getNumSubSounds(
  int *numsubsounds
);
```

### C
```c
FMOD_RESULT FMOD_Sound_GetNumSubSounds(
  FMOD_SOUND *sound,
  int *numsubsounds
);
```

### C#
```csharp
RESULT Sound.getNumSubSounds(
  out int numsubsounds
);
```

### JavaScript
```javascript
Sound.getNumSubSounds(
  numsubsounds
);
```

## sound_getnumsyncpoints
kind: function
index: 18

### C++
```cpp
FMOD_RESULT Sound::getNumSyncPoints(
  int *numsyncpoints
);
```

### C
```c
FMOD_RESULT FMOD_Sound_GetNumSyncPoints(
  FMOD_SOUND *sound,
  int *numsyncpoints
);
```

### C#
```csharp
RESULT Sound.getNumSyncPoints(
  out int numsyncpoints
);
```

### JavaScript
```javascript
Sound.getNumSyncPoints(
  numsyncpoints
);
```

## sound_getnumtags
kind: function
index: 19

### C++
```cpp
FMOD_RESULT Sound::getNumTags(
  int *numtags,
  int *numtagsupdated
);
```

### C
```c
FMOD_RESULT FMOD_Sound_GetNumTags(
  FMOD_SOUND *sound,
  int *numtags,
  int *numtagsupdated
);
```

### C#
```csharp
RESULT Sound.getNumTags(
  out int numtags,
  out int numtagsupdated
);
```

### JavaScript
```javascript
Sound.getNumTags(
  numtags,
  numtagsupdated
);
```

## sound_getopenstate
kind: function
index: 20

### C++
```cpp
FMOD_RESULT Sound::getOpenState(
  FMOD_OPENSTATE *openstate,
  unsigned int *percentbuffered,
  bool *starving,
  bool *diskbusy
);
```

### C
```c
FMOD_RESULT FMOD_Sound_GetOpenState(
  FMOD_SOUND *sound,
  FMOD_OPENSTATE *openstate,
  unsigned int *percentbuffered,
  FMOD_BOOL *starving,
  FMOD_BOOL *diskbusy
);
```

### C#
```csharp
RESULT Sound.getOpenState(
  out OPENSTATE openstate,
  out uint percentbuffered,
  out bool starving,
  out bool diskbusy
);
```

### JavaScript
```javascript
Sound.getOpenState(
  openstate,
  percentbuffered,
  starving,
  diskbusy
);
```

## sound_getsoundgroup
kind: function
index: 21

### C++
```cpp
FMOD_RESULT Sound::getSoundGroup(
  SoundGroup **soundgroup
);
```

### C
```c
FMOD_RESULT FMOD_Sound_GetSoundGroup(
  FMOD_SOUND *sound,
  FMOD_SOUNDGROUP **soundgroup
);
```

### C#
```csharp
RESULT Sound.getSoundGroup(
  out SoundGroup soundgroup
);
```

### JavaScript
```javascript
Sound.getSoundGroup(
  soundgroup
);
```

## sound_getsubsound
kind: function
index: 22

### C++
```cpp
FMOD_RESULT Sound::getSubSound(
  int index,
  Sound **subsound
);
```

### C
```c
FMOD_RESULT FMOD_Sound_GetSubSound(
  FMOD_SOUND *sound,
  int index,
  FMOD_SOUND **subsound
);
```

### C#
```csharp
RESULT Sound.getSubSound(
  int index,
  out Sound subsound
);
```

### JavaScript
```javascript
Sound.getSubSound(
  index,
  subsound
);
```

## sound_getsubsoundparent
kind: function
index: 23

### C++
```cpp
FMOD_RESULT Sound::getSubSoundParent(
  Sound **parentsound
);
```

### C
```c
FMOD_RESULT FMOD_Sound_GetSubSoundParent(
  FMOD_SOUND *sound,
  FMOD_SOUND **parentsound
);
```

### C#
```csharp
RESULT Sound.getSubSoundParent(
  out Sound parentsound
);
```

### JavaScript
```javascript
Sound.getSubSoundParent(
  parentsound
);
```

## sound_getsyncpoint
kind: function
index: 24

### C++
```cpp
FMOD_RESULT Sound::getSyncPoint(
  int index,
  FMOD_SYNCPOINT **point
);
```

### C
```c
FMOD_RESULT FMOD_Sound_GetSyncPoint(
  FMOD_SOUND *sound,
  int index,
  FMOD_SYNCPOINT **point
);
```

### C#
```csharp
RESULT Sound.getSyncPoint(
  int index,
  out IntPtr point
);
```

### JavaScript
```javascript
Sound.getSyncPoint(
  index,
  point
);
```

## sound_getsyncpointinfo
kind: function
index: 25

### C++
```cpp
FMOD_RESULT Sound::getSyncPointInfo(
  FMOD_SYNCPOINT *point,
  char *name,
  int namelen,
  unsigned int *offset,
  FMOD_TIMEUNIT offsettype
);
```

### C
```c
FMOD_RESULT FMOD_Sound_GetSyncPointInfo(
  FMOD_SOUND *sound,
  FMOD_SYNCPOINT *point,
  char *name,
  int namelen,
  unsigned int *offset,
  FMOD_TIMEUNIT offsettype
);
```

### C#
```csharp
RESULT Sound.getSyncPointInfo(
  IntPtr point,
  out string name,
  int namelen,
  out uint offset,
  TIMEUNIT offsettype
);
```

### JavaScript
```javascript
Sound.getSyncPointInfo(
  point,
  name,
  namelen,
  offset,
  offsettype
);
```

## sound_getsystemobject
kind: function
index: 26

### C++
```cpp
FMOD_RESULT Sound::getSystemObject(
  System **system
);
```

### C
```c
FMOD_RESULT FMOD_Sound_GetSystemObject(
  FMOD_SOUND *sound,
  FMOD_SYSTEM **system
);
```

### C#
```csharp
RESULT Sound.getSystemObject(
  out System system
);
```

### JavaScript
```javascript
Sound.getSystemObject(
  system
);
```

## sound_gettag
kind: function
index: 27

### C++
```cpp
FMOD_RESULT Sound::getTag(
  const char *name,
  int index,
  FMOD_TAG *tag
);
```

### C
```c
FMOD_RESULT FMOD_Sound_GetTag(
  FMOD_SOUND *sound,
  const char *name,
  int index,
  FMOD_TAG *tag
);
```

### C#
```csharp
RESULT Sound.getTag(
  string name,
  int index,
  out TAG tag
);
```

### JavaScript
```javascript
Sound.getTag(
  name,
  index,
  tag
);
```

## Sound::getTag
kind: example
index: 28
heading: Sound::getTag

### C
```c
  FMOD_TAG tag;
  while (FMOD_Sound_GetTag(sound, 0, -1, &tag) == FMOD_OK)
  {
    if (tag.type == FMOD_TAGTYPE_FMOD)
    {
        /* When a song changes, the sample rate may also change, so compensate here. */
        if (!strcmp(tag.name, "Sample Rate Change") && channel)
        {
            float frequency = *((float *)tag.data);

            result = FMOD_Channel_SetFrequency(channel, frequency);
            ERRCHECK(result);
        }
    }
  }
```

## Sound::getTag#2
kind: example
index: 29
heading: Sound::getTag

### C++
```cpp
  FMOD_TAG tag;
  while (sound->getTag(0, -1, &tag) == FMOD_OK)
  {
    if (tag.type == FMOD_TAGTYPE_FMOD)
    {
        /* When a song changes, the sample rate may also change, so compensate here. */
        if (!strcmp(tag.name, "Sample Rate Change") && channel)
        {
            float frequency = *((float *)tag.data);

            result = channel->setFrequency(frequency);
            ERRCHECK(result);
        }
    }
  }
```

## sound_getuserdata
kind: function
index: 30

### C++
```cpp
FMOD_RESULT Sound::getUserData(
  void **userdata
);
```

### C
```c
FMOD_RESULT FMOD_Sound_GetUserData(
  FMOD_SOUND *sound,
  void **userdata
);
```

### C#
```csharp
RESULT Sound.getUserData(
  out IntPtr userdata
);
```

### JavaScript
```javascript
Sound.getUserData(
  userdata
);
```

## sound_lock
kind: function
index: 31

### C++
```cpp
FMOD_RESULT Sound::lock(
  unsigned int offset,
  unsigned int length,
  void **ptr1,
  void **ptr2,
  unsigned int *len1,
  unsigned int *len2
);
```

### C
```c
FMOD_RESULT FMOD_Sound_Lock(
  FMOD_SOUND *sound,
  unsigned int offset,
  unsigned int length,
  void **ptr1,
  void **ptr2,
  unsigned int *len1,
  unsigned int *len2
);
```

### C#
```csharp
RESULT Sound.lock(
  uint offset,
  uint length,
  out IntPtr ptr1,
  out IntPtr ptr2,
  out uint len1,
  out uint len2
);
```

### JavaScript
```javascript
Sound.lock(
  offset,
  length,
  ptr1,
  ptr2,
  len1,
  len2
);
```

## FMOD_SOUND_NONBLOCK_CALLBACK
kind: example
index: 32
heading: FMOD_SOUND_NONBLOCK_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_SOUND_NONBLOCK_CALLBACK(
  FMOD_SOUND *sound,
  FMOD_RESULT result
);
```

### C#
```csharp
delegate RESULT SOUND_NONBLOCKCALLBACK(
  IntPtr sound,
  RESULT result
);
```

## FMOD_SOUND_PCMREAD_CALLBACK
kind: example
index: 33
heading: FMOD_SOUND_PCMREAD_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_SOUND_PCMREAD_CALLBACK(
  FMOD_SOUND *sound,
  void *data,
  unsigned int datalen
);
```

### C#
```csharp
delegate RESULT SOUND_PCMREADCALLBACK(
  IntPtr sound,
  IntPtr data,
  uint datalen
);
```

### JavaScript
```javascript
function FMOD_SOUND_PCMREAD_CALLBACK(
  sound,
  data,
  datalen
)
```

## FMOD_SOUND_PCMSETPOS_CALLBACK
kind: example
index: 34
heading: FMOD_SOUND_PCMSETPOS_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_SOUND_PCMSETPOS_CALLBACK(
  FMOD_SOUND *sound,
  int subsound,
  unsigned int position,
  FMOD_TIMEUNIT postype
);
```

### C#
```csharp
delegate RESULT SOUND_PCMSETPOSCALLBACK(
  IntPtr sound,
  int subsound,
  uint position,
  TIMEUNIT postype
);
```

### JavaScript
```javascript
function FMOD_SOUND_PCMSETPOS_CALLBACK(
  sound,
  subsound,
  position,
  postype
)
```

## sound_readdata
kind: function
index: 35

### C++
```cpp
FMOD_RESULT Sound::readData(
  void *buffer,
  unsigned int length,
  unsigned int *read
);
```

### C
```c
FMOD_RESULT FMOD_Sound_ReadData(
  FMOD_SOUND *sound,
  void *buffer,
  unsigned int length,
  unsigned int *read
);
```

### C#
```csharp
RESULT Sound.readData(
  byte[] buffer
);
RESULT Sound.readData(
  byte[] buffer,
  out uint read
);
```

### JavaScript
```javascript
Sound.readData(
  buffer,
  length,
  read
);
```

## sound_release
kind: function
index: 36

### C++
```cpp
FMOD_RESULT Sound::release();
```

### C
```c
FMOD_RESULT FMOD_Sound_Release(FMOD_SOUND *sound);
```

### C#
```csharp
RESULT Sound.release();
```

### JavaScript
```javascript
Sound.release();
```

## sound_seekdata
kind: function
index: 37

### C++
```cpp
FMOD_RESULT Sound::seekData(
  unsigned int pcm
);
```

### C
```c
FMOD_RESULT FMOD_Sound_SeekData(
  FMOD_SOUND *sound,
  unsigned int pcm
);
```

### C#
```csharp
RESULT Sound.seekData(
  uint pcm
);
```

### JavaScript
```javascript
Sound.seekData(
  pcm
);
```

## sound_set3dconesettings
kind: function
index: 38

### C++
```cpp
FMOD_RESULT Sound::set3DConeSettings(
  float insideconeangle,
  float outsideconeangle,
  float outsidevolume
);
```

### C
```c
FMOD_RESULT FMOD_Sound_Set3DConeSettings(
  FMOD_SOUND *sound,
  float insideconeangle,
  float outsideconeangle,
  float outsidevolume
);
```

### C#
```csharp
RESULT Sound.set3DConeSettings(
  float insideconeangle,
  float outsideconeangle,
  float outsidevolume
);
```

### JavaScript
```javascript
Sound.set3DConeSettings(
  insideconeangle,
  outsideconeangle,
  outsidevolume
);
```

## sound_set3dcustomrolloff
kind: function
index: 39

### C++
```cpp
FMOD_RESULT Sound::set3DCustomRolloff(
  FMOD_VECTOR *points,
  int numpoints
);
```

### C
```c
FMOD_RESULT FMOD_Sound_Set3DCustomRolloff(
  FMOD_SOUND *sound,
  FMOD_VECTOR *points,
  int numpoints
);
```

### C#
```csharp
RESULT Sound.set3DCustomRolloff(
  ref VECTOR points,
  int numpoints
);
```

### JavaScript
```javascript
Sound.set3DCustomRolloff(
  points,
  numpoints
);
```

## Sound::set3DCustomRolloff
kind: example
index: 40
heading: Sound::set3DCustomRolloff

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

## sound_set3dminmaxdistance
kind: function
index: 41

### C++
```cpp
FMOD_RESULT Sound::set3DMinMaxDistance(
  float min,
  float max
);
```

### C
```c
FMOD_RESULT FMOD_Sound_Set3DMinMaxDistance(
  FMOD_SOUND *sound,
  float min,
  float max
);
```

### C#
```csharp
RESULT Sound.set3DMinMaxDistance(
  float min,
  float max
);
```

### JavaScript
```javascript
Sound.set3DMinMaxDistance(
  min,
  max
);
```

## sound_setdefaults
kind: function
index: 42

### C++
```cpp
FMOD_RESULT Sound::setDefaults(
  float frequency,
  int priority
);
```

### C
```c
FMOD_RESULT FMOD_Sound_SetDefaults(
  FMOD_SOUND *sound,
  float frequency,
  int priority
);
```

### C#
```csharp
RESULT Sound.setDefaults(
  float frequency,
  int priority
);
```

### JavaScript
```javascript
Sound.setDefaults(
  frequency,
  priority
);
```

## Sound::setDefaults
kind: example
index: 43
heading: Sound::setDefaults

### C++
```cpp
int priority;
sound->getDefaults(nullptr, &priority);
sound->setDefaults(48000, priority);
```

## Sound::setDefaults#2
kind: example
index: 44
heading: Sound::setDefaults

### C
```c
int priority;
FMOD_Sound_GetDefaults(sound, NULL, &priority);
FMOD_Sound_SetDefaults(48000, priority);
```

## Sound::setDefaults#3
kind: example
index: 45
heading: Sound::setDefaults

### C#
```csharp
int priority;
sound.getDefaults(out _, out priority);
sound.setDefaults(48000, priority);
```

## Sound::setDefaults#4
kind: example
index: 46
heading: Sound::setDefaults

### JavaScript
```javascript
sound.getDefaults(null, outval);
sound.setDefaults(48000, outval.val);
```

## sound_setloopcount
kind: function
index: 47

### C++
```cpp
FMOD_RESULT Sound::setLoopCount(
  int loopcount
);
```

### C
```c
FMOD_RESULT FMOD_Sound_SetLoopCount(
  FMOD_SOUND *sound,
  int loopcount
);
```

### C#
```csharp
RESULT Sound.setLoopCount(
  int loopcount
);
```

### JavaScript
```javascript
Sound.setLoopCount(
  loopcount
);
```

## sound_setlooppoints
kind: function
index: 48

### C++
```cpp
FMOD_RESULT Sound::setLoopPoints(
  unsigned int loopstart,
  FMOD_TIMEUNIT loopstarttype,
  unsigned int loopend,
  FMOD_TIMEUNIT loopendtype
);
```

### C
```c
FMOD_RESULT FMOD_Sound_SetLoopPoints(
  FMOD_SOUND *sound,
  unsigned int loopstart,
  FMOD_TIMEUNIT loopstarttype,
  unsigned int loopend,
  FMOD_TIMEUNIT loopendtype
);
```

### C#
```csharp
RESULT Sound.setLoopPoints(
  uint loopstart,
  TIMEUNIT loopstarttype,
  uint loopend,
  TIMEUNIT loopendtype
);
```

### JavaScript
```javascript
Sound.setLoopPoints(
  loopstart,
  loopstarttype,
  loopend,
  loopendtype
);
```

## sound_setmode
kind: function
index: 49

### C++
```cpp
FMOD_RESULT Sound::setMode(
  FMOD_MODE mode
);
```

### C
```c
FMOD_RESULT FMOD_Sound_SetMode(
  FMOD_SOUND *sound,
  FMOD_MODE mode
);
```

### C#
```csharp
RESULT Sound.setMode(
  MODE mode
);
```

### JavaScript
```javascript
Sound.setMode(
  mode
);
```

## sound_setmusicchannelvolume
kind: function
index: 50

### C++
```cpp
FMOD_RESULT Sound::setMusicChannelVolume(
  int channel,
  float volume
);
```

### C
```c
FMOD_RESULT FMOD_Sound_SetMusicChannelVolume(
  FMOD_SOUND *sound,
  int channel,
  float volume
);
```

### C#
```csharp
RESULT Sound.setMusicChannelVolume(
  int channel,
  float volume
);
```

### JavaScript
```javascript
Sound.setMusicChannelVolume(
  channel,
  volume
);
```

## sound_setmusicspeed
kind: function
index: 51

### C++
```cpp
FMOD_RESULT Sound::setMusicSpeed(
  float speed
);
```

### C
```c
FMOD_RESULT FMOD_Sound_SetMusicSpeed(
  FMOD_SOUND *sound,
  float speed
);
```

### C#
```csharp
RESULT Sound.setMusicSpeed(
  float speed
);
```

### JavaScript
```javascript
Sound.setMusicSpeed(
  speed
);
```

## sound_setsoundgroup
kind: function
index: 52

### C++
```cpp
FMOD_RESULT Sound::setSoundGroup(
  SoundGroup *soundgroup
);
```

### C
```c
FMOD_RESULT FMOD_Sound_SetSoundGroup(
  FMOD_SOUND *sound,
  FMOD_SOUNDGROUP *soundgroup
);
```

### C#
```csharp
RESULT Sound.setSoundGroup(
  SoundGroup soundgroup
);
```

### JavaScript
```javascript
Sound.setSoundGroup(
  soundgroup
);
```

## sound_setuserdata
kind: function
index: 53

### C++
```cpp
FMOD_RESULT Sound::setUserData(
  void *userdata
);
```

### C
```c
FMOD_RESULT FMOD_Sound_SetUserData(
  FMOD_SOUND *sound,
  void *userdata
);
```

### C#
```csharp
RESULT Sound.setUserData(
  IntPtr userdata
);
```

### JavaScript
```javascript
Sound.setUserData(
  userdata
);
```

## FMOD_SOUND_TYPE
kind: example
index: 54
heading: FMOD_SOUND_TYPE
tabbed: yes

### C/C++
```cpp
typedef enum FMOD_SOUND_TYPE {
  FMOD_SOUND_TYPE_UNKNOWN,
  FMOD_SOUND_TYPE_AIFF,
  FMOD_SOUND_TYPE_ASF,
  FMOD_SOUND_TYPE_DLS,
  FMOD_SOUND_TYPE_FLAC,
  FMOD_SOUND_TYPE_FSB,
  FMOD_SOUND_TYPE_IT,
  FMOD_SOUND_TYPE_MIDI,
  FMOD_SOUND_TYPE_MOD,
  FMOD_SOUND_TYPE_MPEG,
  FMOD_SOUND_TYPE_OGGVORBIS,
  FMOD_SOUND_TYPE_PLAYLIST,
  FMOD_SOUND_TYPE_RAW,
  FMOD_SOUND_TYPE_S3M,
  FMOD_SOUND_TYPE_USER,
  FMOD_SOUND_TYPE_WAV,
  FMOD_SOUND_TYPE_XM,
  FMOD_SOUND_TYPE_XMA,
  FMOD_SOUND_TYPE_AUDIOQUEUE,
  FMOD_SOUND_TYPE_AT9,
  FMOD_SOUND_TYPE_VORBIS,
  FMOD_SOUND_TYPE_MEDIA_FOUNDATION,
  FMOD_SOUND_TYPE_MEDIACODEC,
  FMOD_SOUND_TYPE_FADPCM,
  FMOD_SOUND_TYPE_OPUS,
  FMOD_SOUND_TYPE_MAX
} FMOD_SOUND_TYPE;
```

### C#
```csharp
enum SOUND_TYPE
{
  UNKNOWN,
  AIFF,
  ASF,
  DLS,
  FLAC,
  FSB,
  IT,
  MIDI,
  MOD,
  MPEG,
  OGGVORBIS,
  PLAYLIST,
  RAW,
  S3M,
  USER,
  WAV,
  XM,
  XMA,
  AUDIOQUEUE,
  AT9,
  VORBIS,
  MEDIA_FOUNDATION,
  MEDIACODEC,
  FADPCM,
  OPUS,
  MAX,
}
```

### JavaScript
```javascript
FMOD.SOUND_TYPE_UNKNOWN
FMOD.SOUND_TYPE_AIFF
FMOD.SOUND_TYPE_ASF
FMOD.SOUND_TYPE_DLS
FMOD.SOUND_TYPE_FLAC
FMOD.SOUND_TYPE_FSB
FMOD.SOUND_TYPE_IT
FMOD.SOUND_TYPE_MIDI
FMOD.SOUND_TYPE_MOD
FMOD.SOUND_TYPE_MPEG
FMOD.SOUND_TYPE_OGGVORBIS
FMOD.SOUND_TYPE_PLAYLIST
FMOD.SOUND_TYPE_RAW
FMOD.SOUND_TYPE_S3M
FMOD.SOUND_TYPE_USER
FMOD.SOUND_TYPE_WAV
FMOD.SOUND_TYPE_XM
FMOD.SOUND_TYPE_XMA
FMOD.SOUND_TYPE_AUDIOQUEUE
FMOD.SOUND_TYPE_AT9
FMOD.SOUND_TYPE_VORBIS
FMOD.SOUND_TYPE_MEDIA_FOUNDATION
FMOD.SOUND_TYPE_MEDIACODEC
FMOD.SOUND_TYPE_FADPCM
FMOD.SOUND_TYPE_OPUS
FMOD.SOUND_TYPE_MAX
```

## sound_unlock
kind: function
index: 55

### C++
```cpp
FMOD_RESULT Sound::unlock(
  void *ptr1,
  void *ptr2,
  unsigned int len1,
  unsigned int len2
);
```

### C
```c
FMOD_RESULT FMOD_Sound_Unlock(
  FMOD_SOUND *sound,
  void *ptr1,
  void *ptr2,
  unsigned int len1,
  unsigned int len2
);
```

### C#
```csharp
RESULT Sound.unlock(
  IntPtr ptr1,
  IntPtr ptr2,
  uint len1,
  uint len2
);
```

### JavaScript
```javascript
Sound.unlock(
  ptr1,
  ptr2,
  len1,
  len2
);
```

## FMOD_TAG
kind: example
index: 56
heading: FMOD_TAG
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_TAG {
  FMOD_TAGTYPE       type;
  FMOD_TAGDATATYPE   datatype;
  char              *name;
  void              *data;
  unsigned int       datalen;
  FMOD_BOOL          updated;
} FMOD_TAG;
```

### C#
```csharp
struct TAG
{
  TAGTYPE           type;
  TAGDATATYPE       datatype;
  StringWrapper     name;
  IntPtr            data;
  uint              datalen;
  bool              updated;
}
```

### JavaScript
```javascript
FMOD_TAG
{
  type,
  datatype,
  data,
  datalen,
  updated,
};
```

## FMOD_TAGDATATYPE
kind: example
index: 57
heading: FMOD_TAGDATATYPE
tabbed: yes

### C/C++
```cpp
typedef enum FMOD_TAGDATATYPE {
  FMOD_TAGDATATYPE_BINARY,
  FMOD_TAGDATATYPE_INT,
  FMOD_TAGDATATYPE_FLOAT,
  FMOD_TAGDATATYPE_STRING,
  FMOD_TAGDATATYPE_STRING_UTF16,
  FMOD_TAGDATATYPE_STRING_UTF16BE,
  FMOD_TAGDATATYPE_STRING_UTF8,
  FMOD_TAGDATATYPE_MAX
} FMOD_TAGDATATYPE;
```

### C#
```csharp
enum TAGDATATYPE : int
{
  BINARY,
  INT,
  FLOAT,
  STRING,
  STRING_UTF16,
  STRING_UTF16BE,
  STRING_UTF8,
  MAX
}
```

### JavaScript
```javascript
FMOD.TAGDATATYPE_BINARY
FMOD.TAGDATATYPE_INT
FMOD.TAGDATATYPE_FLOAT
FMOD.TAGDATATYPE_STRING
FMOD.TAGDATATYPE_STRING_UTF16
FMOD.TAGDATATYPE_STRING_UTF16BE
FMOD.TAGDATATYPE_STRING_UTF8
FMOD.TAGDATATYPE_MAX
```

## FMOD_TAGTYPE
kind: example
index: 58
heading: FMOD_TAGTYPE
tabbed: yes

### C/C++
```cpp
typedef enum FMOD_TAGTYPE {
  FMOD_TAGTYPE_UNKNOWN,
  FMOD_TAGTYPE_ID3V1,
  FMOD_TAGTYPE_ID3V2,
  FMOD_TAGTYPE_VORBISCOMMENT,
  FMOD_TAGTYPE_SHOUTCAST,
  FMOD_TAGTYPE_ICECAST,
  FMOD_TAGTYPE_ASF,
  FMOD_TAGTYPE_MIDI,
  FMOD_TAGTYPE_PLAYLIST,
  FMOD_TAGTYPE_FMOD,
  FMOD_TAGTYPE_USER,
  FMOD_TAGTYPE_MAX
} FMOD_TAGTYPE;
```

### C#
```csharp
enum TAGTYPE
{
  UNKNOWN,
  ID3V1,
  ID3V2,
  VORBISCOMMENT,
  SHOUTCAST,
  ICECAST,
  ASF,
  MIDI,
  PLAYLIST,
  FMOD,
  USER,
  MAX
}
```

### JavaScript
```javascript
FMOD.TAGTYPE_UNKNOWN
FMOD.TAGTYPE_ID3V1
FMOD.TAGTYPE_ID3V2
FMOD.TAGTYPE_VORBISCOMMENT
FMOD.TAGTYPE_SHOUTCAST
FMOD.TAGTYPE_ICECAST
FMOD.TAGTYPE_ASF
FMOD.TAGTYPE_MIDI
FMOD.TAGTYPE_PLAYLIST
FMOD.TAGTYPE_FMOD
FMOD.TAGTYPE_USER
FMOD.TAGTYPE_MAX
```

