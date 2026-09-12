# plugin-api-codec

## FMOD_CODEC_ALLOC_FUNC
kind: example
index: 0
heading: FMOD_CODEC_ALLOC_FUNC
tabbed: yes

### C/C++
```cpp
void * F_CALL FMOD_CODEC_ALLOC_FUNC(
  unsigned int size,
  unsigned int align,
  const char *file,
  int line
);
```

## FMOD_CODEC_CLOSE_CALLBACK
kind: example
index: 1
heading: FMOD_CODEC_CLOSE_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_CODEC_CLOSE_CALLBACK(
  FMOD_CODEC_STATE *codec_state
);
```

## FMOD_CODEC_DESCRIPTION
kind: example
index: 2
heading: FMOD_CODEC_DESCRIPTION
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_CODEC_DESCRIPTION {
  unsigned int                        apiversion;
  const char                         *name;
  unsigned int                        version;
  int                                 defaultasstream;
  FMOD_TIMEUNIT                       timeunits;
  FMOD_CODEC_OPEN_CALLBACK            open;
  FMOD_CODEC_CLOSE_CALLBACK           close;
  FMOD_CODEC_READ_CALLBACK            read;
  FMOD_CODEC_GETLENGTH_CALLBACK       getlength;
  FMOD_CODEC_SETPOSITION_CALLBACK     setposition;
  FMOD_CODEC_GETPOSITION_CALLBACK     getposition;
  FMOD_CODEC_SOUNDCREATE_CALLBACK     soundcreate;
  FMOD_CODEC_GETWAVEFORMAT_CALLBACK   getwaveformat;
} FMOD_CODEC_DESCRIPTION;
```

### JavaScript
```javascript
FMOD_CODEC_DESCRIPTION
{
  apiversion,
  name,
  version,
  defaultasstream,
  timeunits,
  open,
  close,
  read,
  getlength,
  setposition,
  getposition,
  soundcreate,
  getwaveformat,
};
```

## FMOD_CODEC_FILE_READ_FUNC
kind: example
index: 3
heading: FMOD_CODEC_FILE_READ_FUNC
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_CODEC_FILE_READ_FUNC(
  FMOD_CODEC_STATE *codec_state,
  void *buffer,
  unsigned int sizebytes,
  unsigned int *bytesread
);
```

## FMOD_CODEC_FILE_SEEK_FUNC
kind: example
index: 4
heading: FMOD_CODEC_FILE_SEEK_FUNC
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_CODEC_FILE_SEEK_FUNC(
  FMOD_CODEC_STATE *codec_state,
  unsigned int pos,
  FMOD_CODEC_SEEK_METHOD method
);
```

## FMOD_CODEC_FILE_SIZE_FUNC
kind: example
index: 5
heading: FMOD_CODEC_FILE_SIZE_FUNC
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_CODEC_FILE_SIZE_FUNC(
  FMOD_CODEC_STATE *codec_state,
  unsigned int *size
);
```

## FMOD_CODEC_FILE_TELL_FUNC
kind: example
index: 6
heading: FMOD_CODEC_FILE_TELL_FUNC
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_CODEC_FILE_TELL_FUNC(
  FMOD_CODEC_STATE *codec_state,
  unsigned int *pos
);
```

## FMOD_CODEC_FREE_FUNC
kind: example
index: 7
heading: FMOD_CODEC_FREE_FUNC
tabbed: yes

### C/C++
```cpp
void F_CALL FMOD_CODEC_FREE_FUNC(
  void *ptr,
  const char *file,
  int line
);
```

## FMOD_CODEC_GETLENGTH_CALLBACK
kind: example
index: 8
heading: FMOD_CODEC_GETLENGTH_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_CODEC_GETLENGTH_CALLBACK(
  FMOD_CODEC_STATE *codec_state,
  unsigned int *length,
  FMOD_TIMEUNIT lengthtype
);
```

## FMOD_CODEC_GETPOSITION_CALLBACK
kind: example
index: 9
heading: FMOD_CODEC_GETPOSITION_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_CODEC_GETPOSITION_CALLBACK(
  FMOD_CODEC_STATE *codec_state,
  unsigned int *position,
  FMOD_TIMEUNIT postype
);
```

## FMOD_CODEC_GETWAVEFORMAT_CALLBACK
kind: example
index: 10
heading: FMOD_CODEC_GETWAVEFORMAT_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_CODEC_GETWAVEFORMAT_CALLBACK(
  FMOD_CODEC_STATE *codec_state,
  int index,
  FMOD_CODEC_WAVEFORMAT *waveformat
);
```

## FMOD_CODEC_LOG_FUNC
kind: example
index: 11
heading: FMOD_CODEC_LOG_FUNC
tabbed: yes

### C/C++
```cpp
void F_CALL FMOD_CODEC_LOG_FUNC(
  FMOD_DEBUG_FLAGS level,
  const char *file,
  int line,
  const char *function,
  const char *string,
  ...
);
```

## FMOD_CODEC_METADATA_FUNC
kind: example
index: 12
heading: FMOD_CODEC_METADATA_FUNC
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_CODEC_METADATA_FUNC(
  FMOD_CODEC_STATE *codec_state,
  FMOD_TAGTYPE tagtype,
  char *name,
  void *data,
  unsigned int datalen,
  FMOD_TAGDATATYPE datatype,
  int unique
);
```

## FMOD_CODEC_OPEN_CALLBACK
kind: example
index: 13
heading: FMOD_CODEC_OPEN_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_CODEC_OPEN_CALLBACK(
  FMOD_CODEC_STATE *codec_state,
  FMOD_MODE usermode,
  FMOD_CREATESOUNDEXINFO *userexinfo
);
```

## FMOD_CODEC_PLUGIN_VERSION
kind: example
index: 14
heading: FMOD_CODEC_PLUGIN_VERSION
tabbed: yes

### C/C++
```cpp
#define FMOD_CODEC_PLUGIN_VERSION   1
```

### JavaScript
```javascript
FMOD.CODEC_PLUGIN_VERSION
```

## FMOD_CODEC_READ_CALLBACK
kind: example
index: 15
heading: FMOD_CODEC_READ_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_CODEC_READ_CALLBACK(
  FMOD_CODEC_STATE *codec_state,
  void *buffer,
  unsigned int samples_in,
  unsigned int *samples_out
);
```

## FMOD_CODEC_SEEK_METHOD
kind: example
index: 16
heading: FMOD_CODEC_SEEK_METHOD
tabbed: yes

### C/C++
```cpp
#define FMOD_CODEC_SEEK_METHOD_SET     0
#define FMOD_CODEC_SEEK_METHOD_CURRENT 1
#define FMOD_CODEC_SEEK_METHOD_END     2
```

## FMOD_CODEC_SETPOSITION_CALLBACK
kind: example
index: 17
heading: FMOD_CODEC_SETPOSITION_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_CODEC_SETPOSITION_CALLBACK(
  FMOD_CODEC_STATE *codec_state,
  int subsound,
  unsigned int position,
  FMOD_TIMEUNIT postype
);
```

## FMOD_CODEC_SOUNDCREATE_CALLBACK
kind: example
index: 18
heading: FMOD_CODEC_SOUNDCREATE_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_CODEC_SOUNDCREATE_CALLBACK(
  FMOD_CODEC_STATE *codec_state,
  int subsound,
  FMOD_SOUND *sound
);
```

## FMOD_CODEC_STATE
kind: example
index: 19
heading: FMOD_CODEC_STATE
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_CODEC_STATE {
  void                          *plugindata;
  FMOD_CODEC_WAVEFORMAT         *waveformat;
  FMOD_CODEC_STATE_FUNCTIONS    *functions;
  int                            numsubsounds;
} FMOD_CODEC_STATE;
```

### JavaScript
```javascript
FMOD_CODEC_STATE
{
  plugindata;
  waveformat;
  functions;
  numsubsounds,
};
```

## FMOD_CODEC_STATE_FUNCTIONS
kind: example
index: 20
heading: FMOD_CODEC_STATE_FUNCTIONS
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_CODEC_STATE_FUNCTIONS {
    FMOD_CODEC_METADATA_FUNC     metadata;
    FMOD_CODEC_ALLOC_FUNC        alloc;
    FMOD_CODEC_FREE_FUNC         free;
    FMOD_CODEC_LOG_FUNC          log;
    FMOD_CODEC_FILE_READ_FUNC    read;
    FMOD_CODEC_FILE_SEEK_FUNC    seek;
    FMOD_CODEC_FILE_TELL_FUNC    tell;
    FMOD_CODEC_FILE_SIZE_FUNC    size;
} FMOD_CODEC_STATE_FUNCTIONS;
```

## FMOD_CODEC_WAVEFORMAT
kind: example
index: 21
heading: FMOD_CODEC_WAVEFORMAT
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_CODEC_WAVEFORMAT {
  const char*         name;
  FMOD_SOUND_FORMAT   format;
  int                 channels;
  int                 frequency;
  unsigned int        lengthbytes;
  unsigned int        lengthpcm;
  unsigned int        pcmblocksize;
  int                 loopstart;
  int                 loopend;
  FMOD_MODE           mode;
  FMOD_CHANNELMASK    channelmask;
  FMOD_CHANNELORDER   channelorder;
  float               peakvolume;
} FMOD_CODEC_WAVEFORMAT;
```

### JavaScript
```javascript
FMOD_CODEC_WAVEFORMAT
{
  name,
  format,
  channels,
  frequency,
  lengthbytes,
  lengthpcm,
  pcmblocksize,
  loopstart,
  loopend,
  mode,
  channelmask,
  channelorder,
  peakvolume,
};
```

