# loading-and-playing-sounds-in-the-core-api

## 4.1.1 Non-blocking Sound Creation
kind: example
index: 0
heading: 4.1.1 Non-blocking Sound Creation

### text
```text
FMOD::Sound *sound;
result = system->createStream("../media/wave.mp3", FMOD_NONBLOCKING, 0, &sound); // Creates a handle to a stream then commands the FMOD Async loader to open the stream in the background.
ERRCHECK(result);
```

## 4.1.1 Non-blocking Sound Creation#2
kind: example
index: 1
heading: 4.1.1 Non-blocking Sound Creation

### text
```text
FMOD_RESULT F_CALLBACK nonblockcallback(FMOD_SOUND *sound, FMOD_RESULT result)
{
    FMOD::Sound *snd = (FMOD::Sound *)sound;

    printf("Sound loaded! (%d) %s\n", result, FMOD_ErrorString(result)); 

    return FMOD_OK;
}
```

## 4.1.1 Non-blocking Sound Creation#3
kind: example
index: 2
heading: 4.1.1 Non-blocking Sound Creation

### text
```text
FMOD_RESULT result;
FMOD::Sound *sound;
FMOD_CREATESOUNDEXINFO exinfo;

memset(&exinfo, 0, sizeof(FMOD_CREATESOUNDEXINFO));
exinfo.cbsize = sizeof(FMOD_CREATESOUNDEXINFO);
exinfo.nonblockcallback = nonblockcallback;

result = system->createStream("../media/wave.mp3", FMOD_NONBLOCKING, &exinfo, &sound);
ERRCHECK(result);
```

## 4.2 Playing a sound
kind: example
index: 3
heading: 4.2 Playing a sound
tabbed: yes

### C
```c
FMOD_RESULT result;
FMOD_SOUND *sound;
FMOD_CHANNEL *channel;

result = FMOD_System_CreateSound(system, "../media/wave.mp3", FMOD_DEFAULT, 0, &sound);
ERRCHECK(result);

result = FMOD_System_PlaySound(system, sound, 0, 0, &channel);
ERRCHECK(result);
```

### C++
```cpp
FMOD_RESULT result;
FMOD::Sound *sound;
FMOD::Channel *channel;

result = system->createSound("../media/wave.mp3", FMOD_DEFAULT, nullptr, &sound);
ERRCHECK(result);

result = system->playSound(sound, nullptr, false, &channel);
ERRCHECK(result);
```

### C#
```csharp
FMOD.RESULT result;
FMOD.Sound sound;
FMOD.Channel channel;

result = system.createSound("../media/wave.mp3", FMOD.MODE.DEFAULT, out sound);
ERRCHECK(result);

result = system.playSound(sound, null, false, out channel);
ERRCHECK(result);
```

### JavaScript
```javascript
var result;
var sound = {};
var outval = {};
var channel = null;

result = system.createSound("../media/wave.mp3", FMOD.MODE_DEFAULT, 0, outval);
ERRCHECK(result);

sound = outval.val;

result = system.playSound(sound, null, false, channel);
ERRCHECK(result);
```

## 4.3.1 Creating a Sound from memory
kind: example
index: 4
heading: 4.3.1 Creating a Sound from memory
tabbed: yes

### C++
```cpp
FMOD::Sound *sound;
FMOD_CREATESOUNDEXINFO exinfo;
void *buffer = 0;
int length = 0;

//
// Load your audio data to the "buffer" pointer here
//

// Create extended sound info struct
memset(&exinfo, 0, sizeof(FMOD_CREATESOUNDEXINFO));
exinfo.cbsize = sizeof(FMOD_CREATESOUNDEXINFO);     // Size of the struct.
exinfo.length = length;                             // Length of sound - PCM data in bytes

system->createSound((const char *)buffer, FMOD_OPENMEMORY, &exinfo, &sound);
// The audio data pointed to by "buffer" has been duplicated into FMOD's buffers, and can now be freed
// However, if loading as a stream with FMOD_CREATESTREAM or System::createStream, the memory must stay active, so do not free it!
```

### C
```c
FMOD_Sound *sound;
FMOD_CREATESOUNDEXINFO exinfo;
void *buffer = 0;
int length = 0;

//
// Load your audio data to the "buffer" pointer here
//

// Create extended sound info struct
memset(&exinfo, 0, sizeof(FMOD_CREATESOUNDEXINFO));
exinfo.cbsize = sizeof(FMOD_CREATESOUNDEXINFO);     // Size of the struct.
exinfo.length = length;                             // Length of sound - PCM data in bytes

FMOD_System_CreateSound(system, (const char *)buffer, FMOD_OPENMEMORY, &exinfo, &sound);
// The audio data pointed to by "buffer" has been duplicated into FMOD's buffers, and can now be freed
// However, if loading as a stream with FMOD_CREATESTREAM or System::createStream, the memory must stay active, so do not free it!
```

### C#
```csharp
FMOD.Sound sound;
FMOD.CREATESOUNDEXINFO exinfo;
byte[] buffer;

//
// Load your audio data to the "buffer" array here
//

// Create extended sound info struct
exinfo = new FMOD.CREATESOUNDEXINFO();
exinfo.cbsize = Marshal.SizeOf(typeof(FMOD.CREATESOUNDEXINFO));
exinfo.length = (uint)bytes.Length;

system.createSound(buffer, FMOD.MODE.OPENMEMORY, ref exinfo, out sound);
// The audio data stored by the "buffer" array has been duplicated into FMOD's buffers, and can now be freed
// However, if loading as a stream with FMOD_CREATESTREAM or System::createStream, you must pin "buffer" with GCHandle so that it stays active
```

### JavaScript
```javascript
var sound = {};
var outval = {};
var buffer;

//
// Load your audio data to a Uint8Array and assign it to "buffer" var here 
//

// Create extended sound info struct
// No need to define cbsize, the struct already knows its own size in JS
var exinfo = FMOD.CREATESOUNDEXINFO();
exinfo.length = buffer.length;            // Length of sound - PCM data in bytes

system.createSound(buffer.buffer, FMOD.OPENMEMORY, exinfo, outval);
sound = outval.val;
// The audio data stored in the "buffer" var has been duplicated into FMOD's buffers, and can now be freed
// However, if loading as a stream with FMOD_CREATESTREAM or System::createStream, the memory must stay active, so do not free it!
```

## 4.3.1 Creating a Sound from memory#2
kind: example
index: 5
heading: 4.3.1 Creating a Sound from memory
tabbed: yes

### C++
```cpp
FMOD::Sound *sound;
FMOD_CREATESOUNDEXINFO exinfo;
void *buffer = 0;
int length = 0;

//
// Load your audio data to the "buffer" pointer here
//

// Create extended sound info struct
memset(&exinfo, 0, sizeof(FMOD_CREATESOUNDEXINFO));
exinfo.cbsize = sizeof(FMOD_CREATESOUNDEXINFO);     // Size of the struct
exinfo.length = length;                             // Length of sound - PCM data in bytes

system->createSound((const char *)buffer, FMOD_OPENMEMORY_POINT, &exinfo, &sound);
// As FMOD is using the data stored at the buffer pointer as is, without copying it into its own buffers, the memory cannot be freed until after Sound::release is called
```

### C
```c
FMOD_Sound *sound;
FMOD_CREATESOUNDEXINFO exinfo;
void *buffer = 0;
int length = 0;

//
// Load your audio data to the "buffer" pointer here
//

// Create extended sound info struct
memset(&exinfo, 0, sizeof(FMOD_CREATESOUNDEXINFO));
exinfo.cbsize = sizeof(FMOD_CREATESOUNDEXINFO);     // Size of the struct
exinfo.length = length;                             // Length of sound - PCM data in bytes

FMOD_System_CreateSound(system, (const char *)buffer, FMOD_OPENMEMORY_POINT, &exinfo, &sound);
// As FMOD is using the data stored at the buffer pointer as is, without copying it into its own buffers, the memory cannot be freed until after Sound::release is called
```

### C#
```csharp
FMOD.Sound sound
FMOD.CREATESOUNDEXINFO exinfo;
byte[] buffer;
GCHandle gch;

//
// Load your audio data to the "buffer" array here
//

// Pin data in memory so a pointer to it can be passed to FMOD's unmanaged code
gch = GCHandle.Alloc(buffer, GCHandleType.Pinned);

// Create extended sound info struct
exinfo = new FMOD.CREATESOUNDEXINFO();
exinfo.cbsize = Marshal.SizeOf(typeof(FMOD.CREATESOUNDEXINFO)); // Size of the struct
exinfo.length = (uint)bytes.Length;                             // Length of sound - PCM data in bytes

system.createSound(gch.AddrOfPinnedObject(), FMOD.MODE.OPENMEMORY_POINT, ref exinfo, out sound);
// As FMOD is using the data stored at the buffer pointer as is, without copying it into its own buffers, the memory must stay active and pinned
// Unpin memory with gch.Free() after Sound::release has been called
```

## 4.3.2 Creating a Sound from PCM data
kind: example
index: 6
heading: 4.3.2 Creating a Sound from PCM data
tabbed: yes

### C++
```cpp
FMOD::Sound *sound;
FMOD_CREATESOUNDEXINFO exinfo;

// Create extended sound info struct
memset(&exinfo, 0, sizeof(FMOD_CREATESOUNDEXINFO));
exinfo.cbsize           = sizeof(FMOD_CREATESOUNDEXINFO);   // Size of the struct
exinfo.numchannels      = 2;                                // Number of channels in the sound
exinfo.defaultfrequency = 44100;                            // Playback rate of sound
exinfo.format           = FMOD_SOUND_FORMAT_PCM16;          // Data format of sound

system->createSound("./Your/File/Path/Here.raw", FMOD_OPENRAW, &exinfo, &sound);
```

### C
```c
FMOD_Sound *sound;
FMOD_CREATESOUNDEXINFO exinfo;

// Create extended sound info struct
memset(&exinfo, 0, sizeof(FMOD_CREATESOUNDEXINFO));
exinfo.cbsize           = sizeof(FMOD_CREATESOUNDEXINFO);   // Size of the struct
exinfo.numchannels      = 2;                                // Number of channels in the sound
exinfo.defaultfrequency = 44100;                            // Default playback rate of sound
exinfo.format           = FMOD_SOUND_FORMAT_PCM16;          // Data format of sound

FMOD_System_CreateSound(system, "./Your/File/Path/Here.raw", FMOD_OPENRAW, &exinfo, &sound);
```

### C#
```csharp
FMOD.Sound sound
FMOD.CREATESOUNDEXINFO exinfo;

// Create extended sound info struct
exinfo = new FMOD.CREATESOUNDEXINFO();
exinfo.cbsize           = Marshal.SizeOf(typeof(FMOD.CREATESOUNDEXINFO));  // Size of the struct
exinfo.numchannels      = 2;                                // Number of channels in the sound
exinfo.defaultfrequency = 44100;                            // Default playback rate of sound
exinfo.format           = FMOD.SOUND_FORMAT.PCM16;          // Data format of sound

system.createSound("./Your/File/Path/Here.raw", FMOD.MODE.OPENRAW, ref exinfo, out sound);
```

### JavaScript
```javascript
var sound = {};
var outval = {};
var exinfo = FMOD.CREATESOUNDEXINFO();

// Create extended sound info struct
// No need to define cbsize, the struct already knows its own size in JS
exinfo.numchannels      = 2;                                // Number of channels in the sound
exinfo.defaultfrequency = 44100;                            // Default playback rate of sound
exinfo.format           = FMOD.SOUND_FORMAT.PCM16;          // Data format of sound

system.createSound("./Your/File/Path/Here.raw", FMOD.OPENRAW, exinfo, outval);
sound = outval.val;
```

## 4.3.3 Creating a Sound by manually providing sample data
kind: example
index: 7
heading: 4.3.3 Creating a Sound by manually providing sample data
tabbed: yes

### C++
```cpp
FMOD::Sound *sound;
FMOD_CREATESOUNDEXINFO exinfo;

// Create extended sound info struct
memset(&exinfo, 0, sizeof(FMOD_CREATESOUNDEXINFO));
exinfo.cbsize           = sizeof(FMOD_CREATESOUNDEXINFO);   // Size of the struct
exinfo.numchannels      = 2;                                // Number of channels in the sound
exinfo.defaultfrequency = 44100;                            // Default playback rate of sound
exinfo.length           = exinfo.defaultfrequency * exinfo.numchannels * sizeof(signed short) * 5;   // Length of sound - PCM data in bytes. 5 = seconds
exinfo.format           = FMOD_SOUND_FORMAT_PCM16;          // Data format of sound
exinfo.pcmreadcallback  = MyReadCallbackFunction;           // To read sound data, you must specify a read callback using the pcmreadcallback field
// Alternatively, use Sound::lock and Sound::unlock to submit sample data to the sound when playing it back

// As sample data is being loaded via callback or Sound::lock and Sound::unlock, pass null or equivalent as first argument
system->createSound(0, FMOD_OPENUSER, &exinfo, &sound);
```

### C
```c
FMOD_Sound *sound;
FMOD_CREATESOUNDEXINFO exinfo;

// Create extended sound info struct
memset(&exinfo, 0, sizeof(FMOD_CREATESOUNDEXINFO));
exinfo.cbsize           = sizeof(FMOD_CREATESOUNDEXINFO);   // Size of the struct
exinfo.numchannels      = 2;                                // Number of channels in the sound
exinfo.defaultfrequency = 44100;                            // Default playback rate of sound
exinfo.length           = exinfo.defaultfrequency * exinfo.numchannels * sizeof(signed short) * 5;   // Length of sound - PCM data in bytes. 5 = seconds
exinfo.format           = FMOD_SOUND_FORMAT_PCM16;          // Data format of sound
exinfo.pcmreadcallback  = MyReadCallbackFunction;           // To read sound data, you must specify a read callback using the pcmreadcallback field
// Alternatively, use Sound::lock and Sound::unlock to submit sample data to the sound when playing it back

// As sample data is being loaded via callback or Sound::lock and Sound::unlock, pass null or equivalent as second argument
FMOD_System_CreateSound(system, NULL, FMOD_OPENUSER, &exinfo, &sound);
```

### C#
```csharp
FMOD.Sound sound
FMOD.CREATESOUNDEXINFO exinfo;

// Create extended sound info struct
exinfo = new FMOD.CREATESOUNDEXINFO();
exinfo.cbsize           = Marshal.SizeOf(typeof(FMOD.CREATESOUNDEXINFO));  // Size of the struct
exinfo.numchannels      = 2;                                // Number of channels in the sound
exinfo.defaultfrequency = 44100;                            // Default playback rate of sound
exinfo.length           = exinfo.defaultfrequency * exinfo.numchannels * sizeof(short) * 5;   // Length of sound - PCM data in bytes. 5 = seconds
exinfo.format           = FMOD.SOUND_FORMAT.PCM16;          // Data format of sound
exinfo.pcmreadcallback  = MyReadCallbackFunction;           // To read sound data, you must specify a read callback using the pcmreadcallback field
// Alternatively, use Sound::lock and Sound::unlock to submit sample data to the sound when playing it back

// As sample data is being loaded via callback or Sound::lock and Sound::unlock, pass null or equivalent as first argument
system.createSound("", FMOD.MODE.OPENUSER, ref exinfo, out sound);
```

### JavaScript
```javascript
var sound = {};
var outval = {};
var exinfo = FMOD.CREATESOUNDEXINFO();

// Create extended sound info struct
// No need to define cbsize, the struct already knows its own size in JS
exinfo.numchannels      = 2;                                // Number of channels in the sound
exinfo.defaultfrequency = 44100;                            // Default playback rate of sound
exinfo.length           = exinfo.defaultfrequency * exinfo.numchannels * 2 * 5;      // Length of sound - PCM data in bytes. 2 = sizeof(short) and 5 = seconds
exinfo.format           = FMOD.SOUND_FORMAT.PCM16;          // Data format of sound
exinfo.pcmreadcallback  = MyReadCallbackFunction;           // To read sound data, you must specify a read callback using the pcmreadcallback field
// Alternatively, use Sound::lock and Sound::unlock to submit sample data to the sound when playing it back

// As sample data is being loaded via callback or Sound::lock and Sound::unlock, pass null or equivalent as first argument
system.createSound("", FMOD.OPENUSER, exinfo, outval);
sound = outval.val;
```

## 4.3.4 Creating the Sound as a Streamed FSB File
kind: example
index: 8
heading: 4.3.4 Creating the Sound as a Streamed FSB File

### text
```text
FMOD_RESULT result;
FMOD::Sound *sound;
FMOD_CREATESOUNDEXINFO exinfo;

memset(&exinfo, 0, sizeof(FMOD_CREATESOUNDEXINFO));
exinfo.cbsize = sizeof(FMOD_CREATESOUNDEXINFO);
exinfo.initialsubsound = 1;

result = system->createStream("../media/sounds.fsb", FMOD_NONBLOCKING, &exinfo, &sound);
ERRCHECK(result);
```

## 4.5.1 Setup : Override FMOD's file system with callbacks
kind: example
index: 9
heading: 4.5.1 Setup : Override FMOD's file system with callbacks

### text
```text
FMOD_FILE_OPENCALLBACK  useropen
FMOD_FILE_CLOSECALLBACK  userclose
FMOD_FILE_READCALLBACK  userread
FMOD_FILE_SEEKCALLBACK  userseek
```

## 4.5.1 Setup : Override FMOD's file system with callbacks#2
kind: example
index: 10
heading: 4.5.1 Setup : Override FMOD's file system with callbacks

### text
```text
FMOD_FILE_ASYNCREADCALLBACK  userasyncread
FMOD_FILE_ASYNCCANCELCALLBACK  userasynccancel
```

## 4.5.2 Defining the basics - opening and closing the file handle.
kind: example
index: 11
heading: 4.5.2 Defining the basics - opening and closing the file handle.

### text
```text
FMOD_RESULT F_CALLBACK myopen(const char *name, unsigned int *filesize, void **handle, void **userdata)
{
    if (name)
    {
        FILE *fp;

        fp = fopen(name, "rb");
        if (!fp)
        {
            return FMOD_ERR_FILE_NOTFOUND;
        }

        fseek(fp, 0, SEEK_END);
        *filesize = ftell(fp);
        fseek(fp, 0, SEEK_SET);

        *userdata = (void *)0x12345678;
        *handle = fp;
    }

    return FMOD_OK;
}

FMOD_RESULT F_CALLBACK myclose(void *handle, void *userdata)
{
    if (!handle)
    {
        return FMOD_ERR_INVALID_PARAM;
    }

    fclose((FILE *)handle);

    return FMOD_OK;
}
```

## 4.5.3 Defining 'userasyncread'
kind: example
index: 12
heading: 4.5.3 Defining 'userasyncread'

### text
```text
FMOD_RESULT F_CALLBACK myasyncread(FMOD_ASYNCREADINFO *info, void *userdata)
{
    return PutReadRequestOntoQueue(info);
}
```

## 4.5.4 Defining 'userasynccancel'
kind: example
index: 13
heading: 4.5.4 Defining 'userasynccancel'

### text
```text
FMOD_RESULT F_CALLBACK myasynccancel(void *handle, void *userdata)
{
    return SearchQueueForFileHandleAndRemove(info);
}
```

## 4.5.5 Filling out the FMOD_ASYNCREADINFO structure when performing a deferred read
kind: example
index: 14
heading: 4.5.5 Filling out the FMOD_ASYNCREADINFO structure when performing a deferred read

### text
```text
typedef struct {
  void *  handle;
  unsigned int  offset;
  unsigned int  sizebytes;
  int  priority;
  void *  buffer;
  unsigned int  bytesread;
  FMOD_RESULT  result;
  void *  userdata;
} FMOD_ASYNCREADINFO;
```

