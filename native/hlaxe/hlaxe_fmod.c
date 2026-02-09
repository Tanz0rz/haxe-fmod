/**
 * HashLink FMOD bindings - Minimal FFI layer
 *
 * DESIGN: This is the thinnest possible wrapper around FMOD.
 * - No logic, no error handling, no debug printing
 * - Just raw FMOD API calls
 * - All logic lives in Haxe (HlBackend.hx)
 */

#define HL_NAME(n) hlaxe_fmod_##n
#include <hl.h>
#include <fmod_studio.h>
#include <fmod.h>

// F_CALLBACK was removed in newer FMOD SDKs
#ifndef F_CALLBACK
#define F_CALLBACK F_CALL
#endif

#ifdef _WIN32
#include <windows.h>
#else
#include <pthread.h>
#include <unistd.h>
#endif

// Global state (must be native - these are C pointers)
static FMOD_STUDIO_SYSTEM* gStudioSystem = NULL;
static FMOD_SYSTEM* gCoreSystem = NULL;

// Auto-update thread state
static volatile int gAutoUpdateRunning = 0;
#ifdef _WIN32
static HANDLE gUpdateThread = NULL;
#else
static pthread_t gUpdateThread;
static int gThreadCreated = 0;
#endif

// Instance storage (must be native - these are C pointers)
#define MAX_INSTANCES 256
static FMOD_STUDIO_EVENTINSTANCE* gInstances[MAX_INSTANCES];
static unsigned int gCallbackFlags[MAX_INSTANCES];
static int gInstanceCount = 0;

// Callback (must be native - FMOD invokes this)
static FMOD_RESULT F_CALLBACK eventCallback(FMOD_STUDIO_EVENT_CALLBACK_TYPE type,
    FMOD_STUDIO_EVENTINSTANCE* event, void* parameters) {
    for (int i = 0; i < gInstanceCount; i++) {
        if (gInstances[i] == event) {
            gCallbackFlags[i] |= type;
            break;
        }
    }
    return FMOD_OK;
}

//// System

HL_PRIM bool HL_NAME(is_initialized)() {
    return gStudioSystem != NULL;
}
DEFINE_PRIM(_BOOL, is_initialized, _NO_ARG);

HL_PRIM int HL_NAME(init)(int numChannels) {
    if (gStudioSystem != NULL) return FMOD_OK;

    FMOD_RESULT result = FMOD_Studio_System_Create(&gStudioSystem, FMOD_VERSION);
    if (result != FMOD_OK) return result;

    result = FMOD_Studio_System_Initialize(gStudioSystem, numChannels,
        FMOD_STUDIO_INIT_LIVEUPDATE, FMOD_INIT_NORMAL, NULL);
    if (result != FMOD_OK) {
        FMOD_Studio_System_Release(gStudioSystem);
        gStudioSystem = NULL;
        return result;
    }

    FMOD_Studio_System_GetCoreSystem(gStudioSystem, &gCoreSystem);
    return FMOD_OK;
}
DEFINE_PRIM(_I32, init, _I32);

HL_PRIM void HL_NAME(update)() {
    if (gStudioSystem) FMOD_Studio_System_Update(gStudioSystem);
}
DEFINE_PRIM(_VOID, update, _NO_ARG);

// Auto-update thread function
#ifdef _WIN32
static DWORD WINAPI autoUpdateLoop(LPVOID param) {
    while (gAutoUpdateRunning) {
        if (gStudioSystem) FMOD_Studio_System_Update(gStudioSystem);
        Sleep(16); // ~60fps
    }
    return 0;
}
#else
static void* autoUpdateLoop(void* param) {
    while (gAutoUpdateRunning) {
        if (gStudioSystem) FMOD_Studio_System_Update(gStudioSystem);
        usleep(16000); // ~60fps (16ms in microseconds)
    }
    return NULL;
}
#endif

HL_PRIM void HL_NAME(set_auto_update)(bool enabled) {
    if (enabled && !gAutoUpdateRunning) {
        gAutoUpdateRunning = 1;
#ifdef _WIN32
        gUpdateThread = CreateThread(NULL, 0, autoUpdateLoop, NULL, 0, NULL);
#else
        pthread_create(&gUpdateThread, NULL, autoUpdateLoop, NULL);
        gThreadCreated = 1;
#endif
    } else if (!enabled && gAutoUpdateRunning) {
        gAutoUpdateRunning = 0;
#ifdef _WIN32
        if (gUpdateThread) {
            WaitForSingleObject(gUpdateThread, INFINITE);
            CloseHandle(gUpdateThread);
            gUpdateThread = NULL;
        }
#else
        if (gThreadCreated) {
            pthread_join(gUpdateThread, NULL);
            gThreadCreated = 0;
        }
#endif
    }
}
DEFINE_PRIM(_VOID, set_auto_update, _BOOL);

//// Banks

HL_PRIM int HL_NAME(load_bank)(vbyte* path) {
    if (!gStudioSystem) return FMOD_ERR_NOTREADY;
    FMOD_STUDIO_BANK* bank;
    return FMOD_Studio_System_LoadBankFile(gStudioSystem, (const char*)path,
        FMOD_STUDIO_LOAD_BANK_NORMAL, &bank);
}
DEFINE_PRIM(_I32, load_bank, _BYTES);

//// Events - One shot

HL_PRIM int HL_NAME(fire_one_shot)(vbyte* eventPath) {
    if (!gStudioSystem) return FMOD_ERR_NOTREADY;

    FMOD_STUDIO_EVENTDESCRIPTION* desc;
    FMOD_RESULT result = FMOD_Studio_System_GetEvent(gStudioSystem, (const char*)eventPath, &desc);
    if (result != FMOD_OK) return result;

    FMOD_STUDIO_EVENTINSTANCE* instance;
    result = FMOD_Studio_EventDescription_CreateInstance(desc, &instance);
    if (result != FMOD_OK) return result;

    FMOD_Studio_EventInstance_Start(instance);
    FMOD_Studio_EventInstance_Release(instance);
    return FMOD_OK;
}
DEFINE_PRIM(_I32, fire_one_shot, _BYTES);

//// Events - Managed instances

HL_PRIM int HL_NAME(create_instance)(vbyte* eventPath) {
    if (!gStudioSystem) return -1;
    if (gInstanceCount >= MAX_INSTANCES) return -1;

    FMOD_STUDIO_EVENTDESCRIPTION* desc;
    if (FMOD_Studio_System_GetEvent(gStudioSystem, (const char*)eventPath, &desc) != FMOD_OK) return -1;

    FMOD_STUDIO_EVENTINSTANCE* instance;
    if (FMOD_Studio_EventDescription_CreateInstance(desc, &instance) != FMOD_OK) return -1;

    int handle = gInstanceCount++;
    gInstances[handle] = instance;
    gCallbackFlags[handle] = 0;
    return handle;
}
DEFINE_PRIM(_I32, create_instance, _BYTES);

HL_PRIM void HL_NAME(start)(int h) {
    if (h >= 0 && h < gInstanceCount && gInstances[h])
        FMOD_Studio_EventInstance_Start(gInstances[h]);
}
DEFINE_PRIM(_VOID, start, _I32);

HL_PRIM void HL_NAME(stop)(int h, int immediate) {
    if (h >= 0 && h < gInstanceCount && gInstances[h])
        FMOD_Studio_EventInstance_Stop(gInstances[h],
            immediate ? FMOD_STUDIO_STOP_IMMEDIATE : FMOD_STUDIO_STOP_ALLOWFADEOUT);
}
DEFINE_PRIM(_VOID, stop, _I32 _I32);

HL_PRIM void HL_NAME(release)(int h) {
    if (h >= 0 && h < gInstanceCount && gInstances[h]) {
        FMOD_Studio_EventInstance_Release(gInstances[h]);
        gInstances[h] = NULL;
        gCallbackFlags[h] = 0;
    }
}
DEFINE_PRIM(_VOID, release, _I32);

HL_PRIM void HL_NAME(set_paused)(int h, bool paused) {
    if (h >= 0 && h < gInstanceCount && gInstances[h])
        FMOD_Studio_EventInstance_SetPaused(gInstances[h], paused);
}
DEFINE_PRIM(_VOID, set_paused, _I32 _BOOL);

HL_PRIM int HL_NAME(get_playback_state)(int h) {
    if (h < 0 || h >= gInstanceCount || !gInstances[h]) return FMOD_STUDIO_PLAYBACK_STOPPED;
    FMOD_STUDIO_PLAYBACK_STATE state;
    FMOD_Studio_EventInstance_GetPlaybackState(gInstances[h], &state);
    return (int)state;
}
DEFINE_PRIM(_I32, get_playback_state, _I32);

//// Parameters

HL_PRIM double HL_NAME(get_param)(int h, vbyte* name) {
    if (h < 0 || h >= gInstanceCount || !gInstances[h]) return 0.0;
    float value = 0.0f;
    FMOD_Studio_EventInstance_GetParameterByName(gInstances[h], (const char*)name, &value, NULL);
    return (double)value;
}
DEFINE_PRIM(_F64, get_param, _I32 _BYTES);

HL_PRIM void HL_NAME(set_param)(int h, vbyte* name, double value) {
    if (h >= 0 && h < gInstanceCount && gInstances[h])
        FMOD_Studio_EventInstance_SetParameterByName(gInstances[h], (const char*)name, (float)value, false);
}
DEFINE_PRIM(_VOID, set_param, _I32 _BYTES _F64);

//// Bus

HL_PRIM void HL_NAME(set_bus_paused)(vbyte* path, bool paused) {
    if (!gStudioSystem) return;
    FMOD_STUDIO_BUS* bus;
    if (FMOD_Studio_System_GetBus(gStudioSystem, (const char*)path, &bus) == FMOD_OK)
        FMOD_Studio_Bus_SetPaused(bus, paused);
}
DEFINE_PRIM(_VOID, set_bus_paused, _BYTES _BOOL);

HL_PRIM void HL_NAME(stop_bus)(vbyte* path) {
    if (!gStudioSystem) return;
    FMOD_STUDIO_BUS* bus;
    if (FMOD_Studio_System_GetBus(gStudioSystem, (const char*)path, &bus) == FMOD_OK)
        FMOD_Studio_Bus_StopAllEvents(bus, FMOD_STUDIO_STOP_ALLOWFADEOUT);
}
DEFINE_PRIM(_VOID, stop_bus, _BYTES);

//// Callbacks

HL_PRIM void HL_NAME(enable_callbacks)(int h) {
    if (h >= 0 && h < gInstanceCount && gInstances[h])
        FMOD_Studio_EventInstance_SetCallback(gInstances[h], eventCallback,
            FMOD_STUDIO_EVENT_CALLBACK_STARTED | FMOD_STUDIO_EVENT_CALLBACK_STOPPED |
            FMOD_STUDIO_EVENT_CALLBACK_SOUND_PLAYED | FMOD_STUDIO_EVENT_CALLBACK_SOUND_STOPPED);
}
DEFINE_PRIM(_VOID, enable_callbacks, _I32);

HL_PRIM bool HL_NAME(poll_callbacks)(int h, int mask) {
    if (h < 0 || h >= gInstanceCount) return false;
    bool fired = (gCallbackFlags[h] & mask) != 0;
    gCallbackFlags[h] &= ~mask;
    return fired;
}
DEFINE_PRIM(_BOOL, poll_callbacks, _I32 _I32);
