# fsbank-api

## fsbank_init
kind: function
index: 0

### C
```c
FSBANK_RESULT FSBank_Init(
  FSBANK_FSBVERSION version,
  FSBANK_INITFLAGS flags,
  unsigned int numSimultaneousJobs,
  const char *cacheDirectory
);
```

## fsbank_build
kind: function
index: 1

### C
```c
FSBANK_RESULT FSBank_Build(
  const FSBANK_SUBSOUND *subSounds,
  unsigned int numSubSounds,
  FSBANK_FORMAT encodeFormat,
  FSBANK_BUILDFLAGS buildFlags,
  unsigned int quality,
  const char *encryptKey,
  const char *outputFileName
);
```

## fsbank_buildcancel
kind: function
index: 2

### C
```c
FSBANK_RESULT FSBank_BuildCancel();
```

## fsbank_release
kind: function
index: 3

### C
```c
FSBANK_RESULT FSBank_Release();
```

## fsbank_releaseprogressitem
kind: function
index: 4

### C
```c
FSBANK_RESULT FSBank_ReleaseProgressItem(
  const FSBANK_PROGRESSITEM *progressItem
);
```

## fsbank_memorygetstats
kind: function
index: 5

### C
```c
FSBANK_RESULT FSBank_MemoryGetStats(
  unsigned int *currentAllocated,
  unsigned int *maximumAllocated
);
```

## fsbank_memoryinit
kind: function
index: 6

### C
```c
FSBANK_RESULT FSBank_MemoryInit(
  FSBANK_MEMORY_ALLOC_CALLBACK userAlloc,
  FSBANK_MEMORY_REALLOC_CALLBACK userRealloc,
  FSBANK_MEMORY_FREE_CALLBACK userFree
);
```

## fsbank_fetchfsbmemory
kind: function
index: 7

### C
```c
FSBANK_RESULT FSBank_FetchFSBMemory(
  const void **data,
  unsigned int *length
);
```

## fsbank_fetchnextprogressitem
kind: function
index: 8

### C
```c
FSBANK_RESULT FSBank_FetchNextProgressItem(
  const FSBANK_PROGRESSITEM **progressItem
);
```

## 20.10 FSBANK_MEMORY_ALLOC_CALLBACK
kind: example
index: 9
heading: 20.10 FSBANK_MEMORY_ALLOC_CALLBACK
tabbed: yes

### C
```c
void * FSBANK_CALLBACK FSBANK_MEMORY_ALLOC_CALLBACK(
  unsigned int size,
  unsigned int type,
  const char *sourceStr
);
```

## 20.11 FSBANK_MEMORY_FREE_CALLBACK
kind: example
index: 10
heading: 20.11 FSBANK_MEMORY_FREE_CALLBACK
tabbed: yes

### C
```c
void FSBANK_CALLBACK FSBANK_MEMORY_FREE_CALLBACK(
  void *ptr,
  unsigned int type,
  const char *sourceStr
);
```

## 20.12 FSBANK_MEMORY_REALLOC_CALLBACK
kind: example
index: 11
heading: 20.12 FSBANK_MEMORY_REALLOC_CALLBACK
tabbed: yes

### C
```c
void * FSBANK_CALLBACK FSBANK_MEMORY_REALLOC_CALLBACK(
  void *ptr,
  unsigned int size,
  unsigned int type,
  const char *sourceStr
);
```

## 20.13 FSBANK_INITFLAGS
kind: example
index: 12
heading: 20.13 FSBANK_INITFLAGS
tabbed: yes

### C
```c
#define FSBANK_INIT_NORMAL                  0x00000000
#define FSBANK_INIT_IGNOREERRORS            0x00000001
#define FSBANK_INIT_WARNINGSASERRORS        0x00000002
#define FSBANK_INIT_CREATEINCLUDEHEADER     0x00000004
#define FSBANK_INIT_DONTLOADCACHEFILES      0x00000008
#define FSBANK_INIT_GENERATEPROGRESSITEMS   0x00000010
```

## 20.14 FSBANK_BUILDFLAGS
kind: example
index: 13
heading: 20.14 FSBANK_BUILDFLAGS
tabbed: yes

### C
```c
#define FSBANK_BUILD_DEFAULT                 0x00000000
#define FSBANK_BUILD_DISABLESYNCPOINTS       0x00000001
#define FSBANK_BUILD_DONTLOOP                0x00000002
#define FSBANK_BUILD_FILTERHIGHFREQ          0x00000004
#define FSBANK_BUILD_DISABLESEEKING          0x00000008
#define FSBANK_BUILD_OPTIMIZESAMPLERATE      0x00000010
#define FSBANK_BUILD_FSB5_DONTWRITENAMES     0x00000080
#define FSBANK_BUILD_NOGUID                  0x00000100
#define FSBANK_BUILD_WRITEPEAKVOLUME         0x00000200
#define FSBANK_BUILD_ALIGN4K                 0x00000400
#define FSBANK_BUILD_OVERRIDE_MASK           (FSBANK_BUILD_DISABLESYNCPOINTS | FSBANK_BUILD_DONTLOOP | FSBANK_BUILD_FILTERHIGHFREQ | FSBANK_BUILD_DISABLESEEKING | FSBANK_BUILD_OPTIMIZESAMPLERATE | FSBANK_BUILD_WRITEPEAKVOLUME)
#define FSBANK_BUILD_CACHE_VALIDATION_MASK   (FSBANK_BUILD_DONTLOOP | FSBANK_BUILD_FILTERHIGHFREQ | FSBANK_BUILD_OPTIMIZESAMPLERATE)
```

## 20.15 FSBANK_FORMAT
kind: example
index: 14
heading: 20.15 FSBANK_FORMAT
tabbed: yes

### C
```c
typedef enum FSBANK_FORMAT {
  FSBANK_FORMAT_PCM,
  FSBANK_FORMAT_XMA,
  FSBANK_FORMAT_AT9,
  FSBANK_FORMAT_VORBIS,
  FSBANK_FORMAT_FADPCM,
  FSBANK_FORMAT_OPUS,
  FSBANK_FORMAT_MAX
} FSBANK_FORMAT;
```

## 20.16 FSBANK_FSBVERSION
kind: example
index: 15
heading: 20.16 FSBANK_FSBVERSION
tabbed: yes

### C
```c
typedef enum FSBANK_FSBVERSION {
  FSBANK_FSBVERSION_FSB5,
  FSBANK_FSBVERSION_MAX
} FSBANK_FSBVERSION;
```

## 20.17 FSBANK_PROGRESSITEM
kind: example
index: 16
heading: 20.17 FSBANK_PROGRESSITEM
tabbed: yes

### C
```c
typedef struct FSBANK_PROGRESSITEM {
  int            subSoundIndex;
  int            threadIndex;
  FSBANK_STATE   state;
  const void    *stateData;
} FSBANK_PROGRESSITEM;
```

## 20.18 FSBANK_RESULT
kind: example
index: 17
heading: 20.18 FSBANK_RESULT
tabbed: yes

### C
```c
typedef enum FSBANK_RESULT {
  FSBANK_OK,
  FSBANK_ERR_CACHE_CHUNKNOTFOUND,
  FSBANK_ERR_CANCELLED,
  FSBANK_ERR_CANNOT_CONTINUE,
  FSBANK_ERR_ENCODER,
  FSBANK_ERR_ENCODER_INIT,
  FSBANK_ERR_ENCODER_NOTSUPPORTED,
  FSBANK_ERR_FILE_OS,
  FSBANK_ERR_FILE_NOTFOUND,
  FSBANK_ERR_FMOD,
  FSBANK_ERR_INITIALIZED,
  FSBANK_ERR_INVALID_FORMAT,
  FSBANK_ERR_INVALID_PARAM,
  FSBANK_ERR_MEMORY,
  FSBANK_ERR_UNINITIALIZED,
  FSBANK_ERR_WRITER_FORMAT,
  FSBANK_WARN_CANNOTLOOP,
  FSBANK_WARN_IGNORED_FILTERHIGHFREQ,
  FSBANK_WARN_IGNORED_DISABLESEEKING,
  FSBANK_WARN_FORCED_DONTWRITENAMES,
  FSBANK_ERR_ENCODER_FILE_NOTFOUND,
  FSBANK_ERR_ENCODER_FILE_BAD,
  FSBANK_WARN_IGNORED_ALIGN4K,
} FSBANK_RESULT;
```

## 20.19 FSBANK_STATE
kind: example
index: 18
heading: 20.19 FSBANK_STATE
tabbed: yes

### C
```c
typedef enum FSBANK_STATE {
  FSBANK_STATE_DECODING,
  FSBANK_STATE_ANALYSING,
  FSBANK_STATE_PREPROCESSING,
  FSBANK_STATE_ENCODING,
  FSBANK_STATE_WRITING,
  FSBANK_STATE_FINISHED,
  FSBANK_STATE_FAILED,
  FSBANK_STATE_WARNING
} FSBANK_STATE;
```

## 20.20 FSBANK_STATEDATA_FAILED
kind: example
index: 19
heading: 20.20 FSBANK_STATEDATA_FAILED
tabbed: yes

### C
```c
typedef struct FSBANK_STATEDATA_FAILED {
  FSBANK_RESULT   errorCode;
  char            errorString[256];
} FSBANK_STATEDATA_FAILED;
```

## 20.21 FSBANK_STATEDATA_WARNING
kind: example
index: 20
heading: 20.21 FSBANK_STATEDATA_WARNING
tabbed: yes

### C
```c
typedef struct FSBANK_STATEDATA_WARNING {
  FSBANK_RESULT   warnCode;
  char            warningString[256];
} FSBANK_STATEDATA_WARNING;
```

## 20.22 FSBANK_SUBSOUND
kind: example
index: 21
heading: 20.22 FSBANK_SUBSOUND
tabbed: yes

### C
```c
typedef struct FSBANK_SUBSOUND {
  const char* const   *fileNames;
  const void* const   *fileData;
  const unsigned int   *fileDataLengths;
  unsigned int         numFiles;
  FSBANK_BUILDFLAGS    overrideFlags;
  unsigned int         overrideQuality;
  float                desiredSampleRate;
  float                percentOptimizedRate;
} FSBANK_SUBSOUND;
```

