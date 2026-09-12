# advanced-core-api-topics

## 10.2 Extracting PCM Data from a Sound
kind: example
index: 0
heading: 10.2 Extracting PCM Data from a Sound
tabbed: yes

### C++
```cpp
FMOD::Sound *sound;
unsigned int length;
char *buffer;

system->createSound("drumloop.wav", FMOD_OPENONLY, nullptr, &sound);
sound->getLength(&length, FMOD_TIMEUNIT_RAWBYTES);

buffer = new char[length];
sound->readData(buffer, length, nullptr);

delete[] buffer;
```

### C
```c
FMOD_SOUND *sound;
unsigned int length;
char *buffer;

FMOD_System_CreateSound(system, "drumloop.wav", FMOD_OPENONLY, 0, &sound);
FMOD_Sound_GetLength(sound, &length, FMOD_TIMEUNIT_RAWBYTES);

buffer = (char *)malloc(length);
FMOD_Sound_ReadData(sound, (void *)buffer, length, 0);

free(buffer);
```

### C#
```csharp
FMOD.Sound sound;
uint length;
byte[] buffer;

system.createSound("drumloop.wav", FMOD.MODE.OPENONLY, out sound);
sound.getLength(out length, FMOD.TIMEUNIT.RAWBYTES);

buffer = new byte[(int)length];
sound.readData(buffer);
```

### JavaScript
```javascript
var sound = {};
var length = {};
var buffer = {};

system.createSound("drumloop.wav", FMOD.OPENONLY, null, sound);
sound = sound.val;

sound.getLength(length, FMOD.TIMEUNIT_RAWBYTES);
length = length.val;

sound.readData(buffer, length, null);
buffer = buffer.val;
```

## Codec Example
kind: example
index: 1
heading: Codec Example
tabbed: yes

### C++
```cpp
FMOD_RESULT result;
unsigned int handle;
FMOD::Sound* sound;

result = system->registerCodec(FMOD_Example_GetCodecDescription(), &handle);

// example.xyz is a file encoded with the codec's corresponding encoder
result = system->createSound("example.xyz", FMOD_DEFAULT, 0, &sound);
```

### C
```c
FMOD_RESULT result;
unsigned int handle;
FMOD_SOUND* sound;

result = FMOD_System_RegisterCodec(system, FMOD_Example_GetCodecDescription(), &handle, 0);

// example.xyz is a file encoded with the codec's corresponding encoder
result = FMOD_System_CreateSound(system, "example.xyz", FMOD_DEFAULT, 0, &sound);
```

### JavaScript
```javascript
var result = {};
var handle = {};
var sound = {};
var outval = {};

result = system.registerCodec(FMOD_Example_GetCodecDescription(), outval, 0);
handle = outval.val;

// example.xyz is a file encoded with the codec's corresponding encoder
result = system.createSound("example.xyz", FMOD.DEFAULT, 0, outval);
sound = outval.val;
```

## Output Example
kind: example
index: 2
heading: Output Example
tabbed: yes

### C++
```cpp
FMOD_RESULT result;
unsigned int handle;

result = system->registerOutput(FMOD_Example_GetOutputDescription(), &handle);
result = system->setOutputByPlugin(handle);
```

### C
```c
FMOD_RESULT result;
unsigned int handle;

result = FMOD_System_RegisterOutput(system, FMOD_Example_GetCodecDescription(), &handle);
result = FMOD_System_SetOutputByPlugin(system, handle);
```

### JavaScript
```javascript
var result = {};
var handle = {};
var outval = {};

result = system.registerOutput(FMOD_Example_GetOutputDescription(), outval, 0);
handle = outval.val;
result = system.setOutputByPlugin(handle);
```

## DSP Example
kind: example
index: 3
heading: DSP Example
tabbed: yes

### C++
```cpp
FMOD::Channel* channel;
FMOD::DSP* dsp;
FMOD_RESULT result;
unsigned int handle;

result = system->registerDSP(FMOD_Example_GetDSPDescription(), &handle);
result = system->playSound(sound, 0, false, &channel);
result = system->createDSPByPlugin(handle, &dsp);
result = channel->addDSP(0, dsp);
```

### C
```c
FMOD_CHANNEL* channel;
FMOD_DSP* dsp;
FMOD_RESULT result;
unsigned int handle;

result = FMOD_System_RegisterDSP(system, FMOD_Example_GetDSPDescription(), &handle);
result = FMOD_System_PlaySound(system, sound, 0, false, &channel);
result = FMOD_System_CreateDSPByPlugin(system, handle, &dsp);
result = FMOD_Channel_AddDSP(channel, 0, dsp);
```

### JavaScript
```javascript
var result = {};
var handle = {};
var dsp = {};
var channel = {};
var outval = {};

result = system.registerDSP(FMOD_Example_GetDSPDescription(), outval);
handle = outval.val;
result = system.playSound(sound, 0, false, outval);
channel = outval.val;
result = system.createDSPByPlugin(handle, outval);
dsp = outval.val;
result = channel.addDSP(0, dsp);
```

## Codec Example#2
kind: example
index: 4
heading: Codec Example
tabbed: yes

### C++
```cpp
FMOD_RESULT result;
unsigned int handle;
FMOD::Sound* sound;

result = system->loadPlugin("example_codec.dll", &handle);

// example.xyz is a file encoded with the codec's corresponding encoder
result = system->createSound("example.xyz", FMOD_DEFAULT, 0, &sound);
```

### C
```c
FMOD_RESULT result;
unsigned int handle;
FMOD_SOUND* sound;

result = FMOD_System_LoadPlugin(system, "example_codec.dll", &handle, 0);

// example.xyz is a file encoded with the codec's corresponding encoder
result = FMOD_System_CreateSound(system, "example.xyz", FMOD_DEFAULT, 0, &sound);
```

### C#
```csharp
FMOD.Result result;
uint handle;
FMOD.Sound sound;

result = system.loadPlugin("example_codec.dll", out handle);

// example.xyz is a file encoded with the codec's corresponding encoder
result = system.createSound("example.xyz", FMOD.MODE.DEFAULT, 0, out sound);
```

## Output Example#2
kind: example
index: 5
heading: Output Example
tabbed: yes

### C++
```cpp
FMOD_RESULT result;
unsigned int handle;

result = system->loadPlugin("example_output.dll", &handle);
result = system->setOutputByPlugin(handle);
```

### C
```c
FMOD_RESULT result;
unsigned int handle;

result = FMOD_System_LoadPlugin(system, "example_output.dll", &handle, 0);
result = FMOD_System_SetOutputByPlugin(system, handle);
```

### C#
```csharp
FMOD.Result result;
uint handle;

result = system.loadPlugin("example_output.dll", out handle);
result = system.setOutputByPlugin(handle);
```

## DSP Example#2
kind: example
index: 6
heading: DSP Example
tabbed: yes

### C++
```cpp
FMOD::Channel* channel;
FMOD::DSP* dsp;
FMOD_RESULT result;
unsigned int handle;

result = system->loadPlugin("example_dsp.dll", &handle);
result = system->playSound(sound, 0, false, &channel);
result = system->createDSPByPlugin(handle, &dsp);
result = channel->addDSP(0, dsp);
```

### C
```c
FMOD_CHANNEL* channel;
FMOD_DSP* dsp;
FMOD_RESULT result;
unsigned int handle;

result = FMOD_System_LoadPlugin(system, "example_dsp.dll", &handle, 0);
result = FMOD_System_PlaySound(system, sound, 0, false, &channel);
result = FMOD_System_CreateDSPByPlugin(system, handle, &dsp);
result = FMOD_Channel_AddDSP(channel, 0, dsp);
```

### C#
```csharp
FMOD.Channel channel;
FMOD.DSP dsp;
FMOD_RESULT result;
uint handle;

result = system.loadPlugin("example_dsp.dll", out handle);
result = system.playSound(sound, 0, false, out channel);
result = system.createDSPByPlugin(handle, out dsp);
result = channel.addDSP(0, dsp);
```

## 10.7.1 3D Reverbs
kind: example
index: 7
heading: 10.7.1 3D Reverbs

### text
```text
FMOD::Reverb *reverb;
result = system->createReverb3D(&reverb);
FMOD_REVERB_PROPERTIES prop2 = FMOD_PRESET_CONCERTHALL;
reverb->setProperties(&prop2);
```

## 10.7.1 3D Reverbs#2
kind: example
index: 8
heading: 10.7.1 3D Reverbs

### text
```text
FMOD_VECTOR pos = { -10.0f, 0.0f, 0.0f };
float mindist = 10.0f; 
float maxdist = 20.0f;
reverb->set3DAttributes(&pos, mindist, maxdist);
```

## 10.7.1 3D Reverbs#3
kind: example
index: 9
heading: 10.7.1 3D Reverbs

### text
```text
FMOD_VECTOR  listenerpos  = { 0.0f, 0.0f, -1.0f };
system->set3DListenerAttributes(0, &listenerpos, 0, 0, 0);
```

## 10.7.2 Using Multiple Reverbs
kind: example
index: 10
heading: 10.7.2 Using Multiple Reverbs

### text
```text
FMOD_REVERB_PROPERTIES prop1 = FMOD_PRESET_HALLWAY;
FMOD_REVERB_PROPERTIES prop2 = FMOD_PRESET_SEWERPIPE;
FMOD_REVERB_PROPERTIES prop3 = FMOD_PRESET_PARKINGLOT;
FMOD_REVERB_PROPERTIES prop4 = FMOD_PRESET_CONCERTHALL;
```

## 10.7.2 Using Multiple Reverbs#2
kind: example
index: 11
heading: 10.7.2 Using Multiple Reverbs

### text
```text
result = system->setReverbProperties(0, &prop1);
result = system->setReverbProperties(1, &prop2);
result = system->setReverbProperties(2, &prop3);
result = system->setReverbProperties(3, &prop4);
```

## 10.7.2 Using Multiple Reverbs#3
kind: example
index: 12
heading: 10.7.2 Using Multiple Reverbs

### text
```text
FMOD_REVERB_PROPERTIES prop = { 0 };
result = system->getReverbProperties(3, &prop);
```

## 10.7.2 Using Multiple Reverbs#4
kind: example
index: 13
heading: 10.7.2 Using Multiple Reverbs

### text
```text
result = channel->setReverbProperties(1, 0.0f);
```

## 10.7.2 Using Multiple Reverbs#5
kind: example
index: 14
heading: 10.7.2 Using Multiple Reverbs

### text
```text
result = channel->setReverbProperties(1, 1.0f);
```

## Added new DSP effects
kind: example
index: 15
heading: Added new DSP effects

### C++
```cpp
FMOD_DSP_TYPE_SEND,               /* This unit sends a copy of the signal to a return DSP anywhere in the DSP tree. */
FMOD_DSP_TYPE_RETURN,             /* This unit receives signals from a number of send DSPs. */
FMOD_DSP_TYPE_HIGHPASS_SIMPLE,    /* This unit filters sound using a simple highpass with no resonance, but has flexible cutoff and is fast. Deprecated and will be removed in a future release (see FMOD_DSP_HIGHPASS_SIMPLE remarks for alternatives). */
FMOD_DSP_TYPE_PAN,                /* This unit pans the signal, possibly upmixing or downmixing as well. */
FMOD_DSP_TYPE_THREE_EQ,           /* This unit is a three-band equalizer. */
FMOD_DSP_TYPE_FFT,                /* This unit simply analyzes the signal and provides spectrum information back through getParameter. */
FMOD_DSP_TYPE_LOUDNESS_METER,     /* This unit analyzes the loudness and true peak of the signal. */
FMOD_DSP_TYPE_ENVELOPEFOLLOWER,   /* This unit tracks the envelope of the input/sidechain signal. Format to be publicly disclosed soon. */
FMOD_DSP_TYPE_CONVOLUTIONREVERB,  /* This unit implements convolution reverb. */
FMOD_DSP_TYPE_CHANNELMIX,         /* This unit provides per signal channel gain, and output channel mapping to allow 1 multi-channel signal made up of many groups of signals to map to a single output signal. */
FMOD_DSP_TYPE_TRANSCEIVER,        /* This unit 'sends' and 'receives' from a selection of up to 32 different slots.  It is like a send/return but it uses global slots rather than returns as the destination.  It also has other features.  Multiple transceivers can receive from a single channel, or multiple transceivers can send to a single channel, or a combination of both. */
FMOD_DSP_TYPE_OBJECTPAN,          /* This unit sends the signal to a 3d object encoder like Dolby Atmos.   Supports a subset of the FMOD_DSP_TYPE_PAN parameters. */
FMOD_DSP_TYPE_MULTIBAND_EQ,       /* This unit is a flexible five band parametric equalizer. */
```

