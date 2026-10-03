# glossary

## 22.33 Reading Sound Data
kind: example
index: 0
heading: 22.33 Reading Sound Data
tabbed: yes

### C++
```cpp
FMOD::Sound *sound;
unsigned int length;
char *buffer;

system->createSound("drumloop.wav", FMOD_DEFAULT | FMOD_OPENONLY, nullptr, &sound);
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

FMOD_System_CreateSound(system, "drumloop.wav", FMOD_DEFAULT | FMOD_OPENONLY, 0, &sound);
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

system.createSound("drumloop.wav", FMOD.MODE.DEFAULT | FMOD.MODE.OPENONLY, out sound);
sound.getLength(out length, FMOD.TIMEUNIT.RAWBYTES);

buffer = new byte[(int)length];
sound.readData(buffer);
```

### JavaScript
```javascript
var sound = {};
var length = {};
var buffer = {};

system.createSound("drumloop.wav", FMOD.DEFAULT | FMOD.OPENONLY, null, sound);
sound = sound.val;

sound.getLength(length, FMOD.TIMEUNIT_RAWBYTES);
length = length.val;

sound.readData(buffer, length, null);
buffer = buffer.val;
```

## 22.49 User Data
kind: example
index: 1
heading: 22.49 User Data
tabbed: yes

### C++
```cpp
{
    const char *userData = "Hello User Data!";
    void *pointer = (void *)userData;
    sound->setUserData(pointer);
}
{
    void *pointer;
    sound->getUserData(&pointer);
    const char *userData = (const char *)pointer;
}
```

### C
```c
{
    const char *userData = "Hello User Data!";
    void *pointer = (void *)userData;
    FMOD_Sound_SetUserData(object, pointer);
}
{
    void *pointer;
    FMOD_Sound_GetUserData(object, &pointer);
    const char *userData = (const char *)pointer;
}
```

### C#
```csharp
{
    string userData = "Hello User Data!";
    GCHandle handle = GCHandle.Alloc(userData);
    IntPtr pointer = GCHandle.ToIntPtr(handle);
    sound.setUserData(pointer);
}
{
    IntPtr pointer;
    sound.getUserData(out pointer);
    GCHandle handle = GCHandle.FromIntPtr(pointer);
    string userData = handle.Target as string;
}
```

### JavaScript
```javascript
{
    var userData = "Hello User Data!";
    sound.setUserData(userData);
}
{
    var outval = {};
    sound.getUserData(outval);
    var userData = outval.val;
}
```

