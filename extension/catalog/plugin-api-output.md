# plugin-api-output

## FMOD_OUTPUT_ALLOC_FUNC
kind: example
index: 0
heading: FMOD_OUTPUT_ALLOC_FUNC
tabbed: yes

### C/C++
```cpp
void * F_CALL FMOD_OUTPUT_ALLOC_FUNC(
  unsigned int size,
  unsigned int align,
  const char *file,
  int line
);
```

## FMOD_OUTPUT_CLOSEPORT_CALLBACK
kind: example
index: 1
heading: FMOD_OUTPUT_CLOSEPORT_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_OUTPUT_CLOSEPORT_CALLBACK(
  FMOD_OUTPUT_STATE *output_state,
  int portId
);
```

## FMOD_OUTPUT_CLOSE_CALLBACK
kind: example
index: 2
heading: FMOD_OUTPUT_CLOSE_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_OUTPUT_CLOSE_CALLBACK(
  FMOD_OUTPUT_STATE *output_state
);
```

## FMOD_OUTPUT_COPYPORT_FUNC
kind: example
index: 3
heading: FMOD_OUTPUT_COPYPORT_FUNC
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_OUTPUT_COPYPORT_FUNC(
  FMOD_OUTPUT_STATE *output_state,
  int portId,
  void *buffer,
  unsigned int length
);
```

## FMOD_OUTPUT_DESCRIPTION
kind: example
index: 4
heading: FMOD_OUTPUT_DESCRIPTION
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_OUTPUT_DESCRIPTION {
  unsigned int                           apiversion;
  const char                            *name;
  unsigned int                           version;
  FMOD_OUTPUT_METHOD                     method;
  FMOD_OUTPUT_GETNUMDRIVERS_CALLBACK     getnumdrivers;
  FMOD_OUTPUT_GETDRIVERINFO_CALLBACK     getdriverinfo;
  FMOD_OUTPUT_INIT_CALLBACK              init;
  FMOD_OUTPUT_START_CALLBACK             start;
  FMOD_OUTPUT_STOP_CALLBACK              stop;
  FMOD_OUTPUT_CLOSE_CALLBACK             close;
  FMOD_OUTPUT_UPDATE_CALLBACK            update;
  FMOD_OUTPUT_GETHANDLE_CALLBACK         gethandle;
  FMOD_OUTPUT_MIXER_CALLBACK             mixer;
  FMOD_OUTPUT_OBJECT3DGETINFO_CALLBACK   object3dgetinfo;
  FMOD_OUTPUT_OBJECT3DALLOC_CALLBACK     object3dalloc;
  FMOD_OUTPUT_OBJECT3DFREE_CALLBACK      object3dfree;
  FMOD_OUTPUT_OBJECT3DUPDATE_CALLBACK    object3dupdate;
  FMOD_OUTPUT_OPENPORT_CALLBACK          openport;
  FMOD_OUTPUT_CLOSEPORT_CALLBACK         closeport;
  FMOD_OUTPUT_DEVICELISTCHANGED_CALLBACK devicelistchanged;
} FMOD_OUTPUT_DESCRIPTION;
```

### JavaScript
```javascript
FMOD_OUTPUT_DESCRIPTION
{
  apiversion,
  name,
  version,
  method,
  getnumdrivers,
  getdriverinfo,
  init,
  start,
  stop,
  close,
  update,
  gethandle,
  mixer,
  object3dgetinfo,
  object3dalloc,
  object3dfree,
  object3dupdate,
  openport,
  closeport,
  devicelistchanged
};
```

## FMOD_OUTPUT_DESCRIPTION#2
kind: example
index: 5
heading: FMOD_OUTPUT_DESCRIPTION

### C/C++
```cpp
/*
    Plug-in setup example
*/
extern "C" FMOD_OUTPUT_DESCRIPTION* F_CALL FMODGetOutputDescription()
{
    static FMOD_OUTPUT_DESCRIPTION desc;

    /*
        Fill members of structure
    */

    return &desc;
}
```

## FMOD_OUTPUT_DEVICELISTCHANGED_CALLBACK
kind: example
index: 6
heading: FMOD_OUTPUT_DEVICELISTCHANGED_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_OUTPUT_DEVICELISTCHANGED_CALLBACK(
  FMOD_OUTPUT_STATE *output_state
);
```

## FMOD_OUTPUT_FREE_FUNC
kind: example
index: 7
heading: FMOD_OUTPUT_FREE_FUNC
tabbed: yes

### C/C++
```cpp
void F_CALL FMOD_OUTPUT_FREE_FUNC(
  void *ptr,
  const char *file,
  int line
);
```

## FMOD_OUTPUT_GETDRIVERINFO_CALLBACK
kind: example
index: 8
heading: FMOD_OUTPUT_GETDRIVERINFO_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_OUTPUT_GETDRIVERINFO_CALLBACK(
  FMOD_OUTPUT_STATE *output_state,
  int id,
  char *name,
  int namelen,
  FMOD_GUID *guid,
  int *systemrate,
  FMOD_SPEAKERMODE *speakermode,
  int *speakermodechannels
);
```

## FMOD_OUTPUT_GETHANDLE_CALLBACK
kind: example
index: 9
heading: FMOD_OUTPUT_GETHANDLE_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_OUTPUT_GETHANDLE_CALLBACK(
  FMOD_OUTPUT_STATE *output_state,
  void **handle
);
```

## FMOD_OUTPUT_GETNUMDRIVERS_CALLBACK
kind: example
index: 10
heading: FMOD_OUTPUT_GETNUMDRIVERS_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_OUTPUT_GETNUMDRIVERS_CALLBACK(
  FMOD_OUTPUT_STATE *output_state,
  int *numdrivers
);
```

## FMOD_OUTPUT_INIT_CALLBACK
kind: example
index: 11
heading: FMOD_OUTPUT_INIT_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_OUTPUT_INIT_CALLBACK(
  FMOD_OUTPUT_STATE *output_state,
  int selecteddriver,
  FMOD_INITFLAGS flags,
  int *outputrate,
  FMOD_SPEAKERMODE *speakermode,
  int *speakermodechannels,
  FMOD_SOUND_FORMAT *outputformat,
  int dspbufferlength,
  int *dspnumbuffers,
  int *dspnumadditionalbuffers,
  void *extradriverdata
);
```

## FMOD_OUTPUT_LOG_FUNC
kind: example
index: 12
heading: FMOD_OUTPUT_LOG_FUNC
tabbed: yes

### C/C++
```cpp
void F_CALL FMOD_OUTPUT_LOG_FUNC(
  FMOD_DEBUG_FLAGS level,
  const char *file,
  int line,
  const char *function,
  const char *string,
  ...
);
```

## FMOD_OUTPUT_METHOD
kind: example
index: 13
heading: FMOD_OUTPUT_METHOD
tabbed: yes

### C/C++
```cpp
#define FMOD_OUTPUT_METHOD_MIX_DIRECT    0
#define FMOD_OUTPUT_METHOD_MIX_BUFFERED  2
```

### JavaScript
```javascript
OUTPUT_METHOD_MIX_DIRECT    = 0
OUTPUT_METHOD_MIX_BUFFERED  = 1
```

## FMOD_OUTPUT_MIXER_CALLBACK
kind: example
index: 14
heading: FMOD_OUTPUT_MIXER_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_OUTPUT_MIXER_CALLBACK(
  FMOD_OUTPUT_STATE *output_state
);
```

## FMOD_OUTPUT_OBJECT3DALLOC_CALLBACK
kind: example
index: 15
heading: FMOD_OUTPUT_OBJECT3DALLOC_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_OUTPUT_OBJECT3DALLOC_CALLBACK(
  FMOD_OUTPUT_STATE *output_state,
  void **object3d
);
```

## FMOD_OUTPUT_OBJECT3DFREE_CALLBACK
kind: example
index: 16
heading: FMOD_OUTPUT_OBJECT3DFREE_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_OUTPUT_OBJECT3DFREE_CALLBACK(
  FMOD_OUTPUT_STATE *output_state,
  void *object3d
);
```

## FMOD_OUTPUT_OBJECT3DGETINFO_CALLBACK
kind: example
index: 17
heading: FMOD_OUTPUT_OBJECT3DGETINFO_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_OUTPUT_OBJECT3DGETINFO_CALLBACK(
  FMOD_OUTPUT_STATE *output_state,
  int *maxhardwareobjects
);
```

## FMOD_OUTPUT_OBJECT3DINFO
kind: example
index: 18
heading: FMOD_OUTPUT_OBJECT3DINFO
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_OUTPUT_OBJECT3DINFO {
  float         *buffer;
  unsigned int   bufferlength;
  FMOD_VECTOR    position;
  float          gain;
  float          spread;
  float          priority;
} FMOD_OUTPUT_OBJECT3DINFO;
```

### JavaScript
```javascript
FMOD_OUTPUT_OBJECT3DINFO
{
  buffer,
  bufferlength,
  position,
  gain,
  spread,
  priority,
};
```

## FMOD_OUTPUT_OBJECT3DUPDATE_CALLBACK
kind: example
index: 19
heading: FMOD_OUTPUT_OBJECT3DUPDATE_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_OUTPUT_OBJECT3DUPDATE_CALLBACK(
  FMOD_OUTPUT_STATE *output_state,
  void *object3d,
  const FMOD_OUTPUT_OBJECT3DINFO *info
);
```

## FMOD_OUTPUT_OPENPORT_CALLBACK
kind: example
index: 20
heading: FMOD_OUTPUT_OPENPORT_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_OUTPUT_OPENPORT_CALLBACK(
  FMOD_OUTPUT_STATE *output_state,
  FMOD_PORT_TYPE portType,
  FMOD_PORT_INDEX portIndex,
  int *portId,
  int *portRate,
  int *portChannels,
  FMOD_SOUND_FORMAT *portFormat
);
```

## FMOD_OUTPUT_PLUGIN_VERSION
kind: example
index: 21
heading: FMOD_OUTPUT_PLUGIN_VERSION
tabbed: yes

### C/C++
```cpp
#define FMOD_OUTPUT_PLUGIN_VERSION   5
```

### JavaScript
```javascript
FMOD.OUTPUT_PLUGIN_VERSION
```

## FMOD_OUTPUT_READFROMMIXER_FUNC
kind: example
index: 22
heading: FMOD_OUTPUT_READFROMMIXER_FUNC
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_OUTPUT_READFROMMIXER_FUNC(
  FMOD_OUTPUT_STATE *output_state,
  void *buffer,
  unsigned int length
);
```

## FMOD_OUTPUT_REQUESTRESET_FUNC
kind: example
index: 23
heading: FMOD_OUTPUT_REQUESTRESET_FUNC
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_OUTPUT_REQUESTRESET_FUNC(
  FMOD_OUTPUT_STATE *output_state
);
```

## FMOD_OUTPUT_START_CALLBACK
kind: example
index: 24
heading: FMOD_OUTPUT_START_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_OUTPUT_START_CALLBACK(
  FMOD_OUTPUT_STATE *output_state
);
```

## FMOD_OUTPUT_STATE
kind: example
index: 25
heading: FMOD_OUTPUT_STATE
tabbed: yes

### C/C++
```cpp
typedef struct FMOD_OUTPUT_STATE {
  void                            *plugindata;
  FMOD_OUTPUT_READFROMMIXER_FUNC   readfrommixer;
  FMOD_OUTPUT_ALLOC_FUNC           alloc;
  FMOD_OUTPUT_FREE_FUNC            free;
  FMOD_OUTPUT_LOG_FUNC             log;
  FMOD_OUTPUT_COPYPORT_FUNC        copyport;
  FMOD_OUTPUT_REQUESTRESET_FUNC    requestreset;
} FMOD_OUTPUT_STATE;
```

### JavaScript
```javascript
FMOD_OUTPUT_STATE
{
  plugindata,
};
```

## FMOD_OUTPUT_STOP_CALLBACK
kind: example
index: 26
heading: FMOD_OUTPUT_STOP_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_OUTPUT_STOP_CALLBACK(
  FMOD_OUTPUT_STATE *output_state
);
```

## FMOD_OUTPUT_UPDATE_CALLBACK
kind: example
index: 27
heading: FMOD_OUTPUT_UPDATE_CALLBACK
tabbed: yes

### C/C++
```cpp
FMOD_RESULT F_CALL FMOD_OUTPUT_UPDATE_CALLBACK(
  FMOD_OUTPUT_STATE *output_state
);
```

