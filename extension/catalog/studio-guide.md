# studio-guide

## 13.9.1 Scripting Example
kind: example
index: 0
heading: 13.9.1 Scripting Example

### C++
```cpp
struct ProgrammerSoundContext
{
    FMOD::System* coreSystem;
    FMOD::Studio::System* system;
    const char* dialogueString;
};

ProgrammerSoundContext programmerSoundContext;
programmerSoundContext.system = system;
programmerSoundContext.coreSystem = coreSystem;
```

## 13.9.1 Scripting Example#2
kind: example
index: 1
heading: 13.9.1 Scripting Example

### C++
```cpp
eventInstance->setUserData(&programmerSoundContext);
eventInstance->setCallback(programmerSoundCallback, FMOD_STUDIO_EVENT_CALLBACK_CREATE_PROGRAMMER_SOUND | FMOD_STUDIO_EVENT_CALLBACK_DESTROY_PROGRAMMER_SOUND);
```

## 13.9.1 Scripting Example#3
kind: example
index: 2
heading: 13.9.1 Scripting Example

### C++
```cpp
// Available banks
// "Dialogue_EN.bank", "Dialogue_JP.bank", "Dialogue_CN.bank"
FMOD::Studio::Bank* localizedBank = NULL;
system->loadBankFile(Common_MediaPath("Dialogue_JP.bank"), FMOD_STUDIO_LOAD_BANK_NORMAL, &localizedBank);
programmerSoundContext.dialogueString = "welcome";
eventInstance->start();
```

## 13.9.1 Scripting Example#4
kind: example
index: 3
heading: 13.9.1 Scripting Example

### C++
```cpp
FMOD_RESULT F_CALL programmerSoundCallback(FMOD_STUDIO_EVENT_CALLBACK_TYPE type, FMOD_STUDIO_EVENTINSTANCE* event, void* parameters)
```

## 13.9.1 Scripting Example#5
kind: example
index: 4
heading: 13.9.1 Scripting Example

### C++
```cpp
{
    FMOD::Studio::EventInstance* eventInstance = (FMOD::Studio::EventInstance*)event;

    if (type == FMOD_STUDIO_EVENT_CALLBACK_CREATE_PROGRAMMER_SOUND)
    {
        // Get our context from the event instance user data
        ProgrammerSoundContext* context = NULL;
        eventInstance->getUserData((void**)&context);

        // Find the audio file in the audio table with the key
        FMOD_STUDIO_SOUND_INFO info;
        context->system->getSoundInfo(context->dialogueString, &info);

        FMOD::Sound* sound = NULL;
        context->coreSystem->createSound(info.name_or_data, FMOD_LOOP_NORMAL | FMOD_CREATECOMPRESSEDSAMPLE | FMOD_NONBLOCKING | info.mode, &info.exinfo, &sound);

        FMOD_STUDIO_PROGRAMMER_SOUND_PROPERTIES* props = (FMOD_STUDIO_PROGRAMMER_SOUND_PROPERTIES*)parameters;

        // Pass the sound to FMOD
        props->sound = (FMOD_SOUND*)sound;
        props->subsoundIndex = info.subsoundindex;
    }
```

## 13.9.1 Scripting Example#6
kind: example
index: 5
heading: 13.9.1 Scripting Example

### C++
```cpp
    else if (type == FMOD_STUDIO_EVENT_CALLBACK_DESTROY_PROGRAMMER_SOUND)
    {
        FMOD_STUDIO_PROGRAMMER_SOUND_PROPERTIES* props = (FMOD_STUDIO_PROGRAMMER_SOUND_PROPERTIES*)parameters;

        // Obtain the sound
        FMOD::Sound* sound = (FMOD::Sound*)props->sound;

        // Release the sound
        sound->release();
    }
}
```

