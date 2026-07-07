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
#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>
#include "../shared/faxe_handles.h"
#include "../shared/faxe_cbqueue.h"

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

// Result of the most recent studio binding call made from the Haxe thread.
static FMOD_RESULT gLastResult = FMOD_OK;
// Static buffer for string out-params. Contents are only valid until the
// next binding call; the Haxe wrappers copy immediately.
static char gStringBuf[512];

// Auto-update thread state
static volatile int gAutoUpdateRunning = 0;
#ifdef _WIN32
static HANDLE gUpdateThread = NULL;
#else
static pthread_t gUpdateThread;
static int gThreadCreated = 0;
#endif

// Resolve an event instance handle to its FMOD pointer (NULL if stale/invalid)
static FMOD_STUDIO_EVENTINSTANCE* resolve_instance(int h) {
    return (FMOD_STUDIO_EVENTINSTANCE*)faxe_handle_resolve(h, FAXE_TYPE_EVI);
}

// Callback - runs on an FMOD thread, NOT an HL thread. Must not touch the
// handle table or any HL values; it reads the instance handle back from FMOD
// userdata, copies payloads into a plain C record, and pushes it onto the
// shared queue. The Haxe thread drains the queue during update().
static FMOD_RESULT F_CALLBACK eventCallback(FMOD_STUDIO_EVENT_CALLBACK_TYPE type,
    FMOD_STUDIO_EVENTINSTANCE* event, void* parameters) {
    void* userData = NULL;
    int handle;
    FaxeCbEvent ev;

    FMOD_Studio_EventInstance_GetUserData(event, &userData);
    handle = (int)(intptr_t)userData;
    if (handle <= 0) return FMOD_OK;

    memset(&ev, 0, sizeof(ev));
    ev.handle = handle;
    ev.type = (uint32_t)type;

    switch (type) {
        case FMOD_STUDIO_EVENT_CALLBACK_TIMELINE_MARKER: {
            const FMOD_STUDIO_TIMELINE_MARKER_PROPERTIES* props =
                (const FMOD_STUDIO_TIMELINE_MARKER_PROPERTIES*)parameters;
            if (props) {
                if (props->name) {
                    strncpy(ev.str, props->name, FAXE_CBQ_STR_MAX - 1);
                }
                ev.i1 = props->position;
            }
            break;
        }
        case FMOD_STUDIO_EVENT_CALLBACK_TIMELINE_BEAT: {
            const FMOD_STUDIO_TIMELINE_BEAT_PROPERTIES* props =
                (const FMOD_STUDIO_TIMELINE_BEAT_PROPERTIES*)parameters;
            if (props) {
                ev.i1 = props->bar;
                ev.i2 = props->beat;
                ev.i3 = props->position;
                ev.f1 = props->tempo;
            }
            break;
        }
        case FMOD_STUDIO_EVENT_CALLBACK_NESTED_TIMELINE_BEAT: {
            const FMOD_STUDIO_TIMELINE_NESTED_BEAT_PROPERTIES* props =
                (const FMOD_STUDIO_TIMELINE_NESTED_BEAT_PROPERTIES*)parameters;
            if (props) {
                ev.i1 = props->properties.bar;
                ev.i2 = props->properties.beat;
                ev.i3 = props->properties.position;
                ev.f1 = props->properties.tempo;
            }
            break;
        }
        default:
            break;
    }

    faxe_cbq_push(&ev);
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

    // FMOD_WAVWRITER env var: write mixed audio to WAV file (for CI recording)
    const char* wavWriterPath = getenv("FMOD_WAVWRITER");
    void* extradriverdata = NULL;
    if (wavWriterPath && wavWriterPath[0] != '\0') {
        FMOD_Studio_System_GetCoreSystem(gStudioSystem, &gCoreSystem);
        FMOD_System_SetOutput(gCoreSystem, FMOD_OUTPUTTYPE_WAVWRITER);
        // Explicit stereo format so WAV header has correct channel count (Windows needs this)
        FMOD_System_SetSoftwareFormat(gCoreSystem, 48000, FMOD_SPEAKERMODE_STEREO, 0);
        extradriverdata = (void*)wavWriterPath;
    }

    result = FMOD_Studio_System_Initialize(gStudioSystem, numChannels,
        FMOD_STUDIO_INIT_LIVEUPDATE, FMOD_INIT_NORMAL, extradriverdata);
    if (result != FMOD_OK) {
        FMOD_Studio_System_Release(gStudioSystem);
        gStudioSystem = NULL;
        return result;
    }

    FMOD_Studio_System_GetCoreSystem(gStudioSystem, &gCoreSystem);
    faxe_cbq_init();
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

HL_PRIM void HL_NAME(unload_bank)(vbyte* path) {
    // Note: Would need bank tracking to implement properly.
    // No-op matching the C++ backend behavior (real unload lands in M5).
}
DEFINE_PRIM(_VOID, unload_bank, _BYTES);

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

    FMOD_STUDIO_EVENTDESCRIPTION* desc;
    if (FMOD_Studio_System_GetEvent(gStudioSystem, (const char*)eventPath, &desc) != FMOD_OK) return -1;

    FMOD_STUDIO_EVENTINSTANCE* instance;
    if (FMOD_Studio_EventDescription_CreateInstance(desc, &instance) != FMOD_OK) return -1;

    int handle = faxe_handle_alloc(instance, FAXE_TYPE_EVI);
    if (handle == 0) {
        FMOD_Studio_EventInstance_Release(instance);
        return -1;
    }

    // Store the handle in userdata so FMOD-thread callbacks can find it
    // without touching the handle table.
    FMOD_Studio_EventInstance_SetUserData(instance, (void*)(intptr_t)handle);
    return handle;
}
DEFINE_PRIM(_I32, create_instance, _BYTES);

HL_PRIM void HL_NAME(start)(int h) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    if (instance) FMOD_Studio_EventInstance_Start(instance);
}
DEFINE_PRIM(_VOID, start, _I32);

HL_PRIM void HL_NAME(stop)(int h, int immediate) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    if (instance)
        FMOD_Studio_EventInstance_Stop(instance,
            immediate ? FMOD_STUDIO_STOP_IMMEDIATE : FMOD_STUDIO_STOP_ALLOWFADEOUT);
}
DEFINE_PRIM(_VOID, stop, _I32 _I32);

HL_PRIM void HL_NAME(release)(int h) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    if (instance) {
        FMOD_Studio_EventInstance_Stop(instance, FMOD_STUDIO_STOP_IMMEDIATE);
        FMOD_Studio_EventInstance_Release(instance);
        faxe_handle_free(h);
    }
}
DEFINE_PRIM(_VOID, release, _I32);

HL_PRIM void HL_NAME(set_paused)(int h, bool paused) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    if (instance) FMOD_Studio_EventInstance_SetPaused(instance, paused);
}
DEFINE_PRIM(_VOID, set_paused, _I32 _BOOL);

HL_PRIM int HL_NAME(get_playback_state)(int h) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    if (!instance) return FMOD_STUDIO_PLAYBACK_STOPPED;
    FMOD_STUDIO_PLAYBACK_STATE state;
    FMOD_Studio_EventInstance_GetPlaybackState(instance, &state);
    return (int)state;
}
DEFINE_PRIM(_I32, get_playback_state, _I32);

HL_PRIM int HL_NAME(get_timeline_position)(int h) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    if (!instance) return 0;
    int position = 0;
    FMOD_Studio_EventInstance_GetTimelinePosition(instance, &position);
    return position;
}
DEFINE_PRIM(_I32, get_timeline_position, _I32);

//// Parameters

HL_PRIM double HL_NAME(get_param)(int h, vbyte* name) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    if (!instance) return 0.0;
    float value = 0.0f;
    FMOD_Studio_EventInstance_GetParameterByName(instance, (const char*)name, &value, NULL);
    return (double)value;
}
DEFINE_PRIM(_F64, get_param, _I32 _BYTES);

HL_PRIM void HL_NAME(set_param)(int h, vbyte* name, double value) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    if (instance)
        FMOD_Studio_EventInstance_SetParameterByName(instance, (const char*)name, (float)value, false);
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

HL_PRIM void HL_NAME(set_bus_volume)(vbyte* path, double volume) {
    if (!gStudioSystem) return;
    FMOD_STUDIO_BUS* bus;
    if (FMOD_Studio_System_GetBus(gStudioSystem, (const char*)path, &bus) == FMOD_OK)
        FMOD_Studio_Bus_SetVolume(bus, (float)volume);
}
DEFINE_PRIM(_VOID, set_bus_volume, _BYTES _F64);

HL_PRIM double HL_NAME(get_bus_volume)(vbyte* path) {
    if (!gStudioSystem) return 0.0;
    FMOD_STUDIO_BUS* bus;
    if (FMOD_Studio_System_GetBus(gStudioSystem, (const char*)path, &bus) == FMOD_OK) {
        float volume = 0.0f;
        FMOD_Studio_Bus_GetVolume(bus, &volume, NULL);
        return (double)volume;
    }
    return 0.0;
}
DEFINE_PRIM(_F64, get_bus_volume, _BYTES);

HL_PRIM void HL_NAME(set_bus_mute)(vbyte* path, bool mute) {
    if (!gStudioSystem) return;
    FMOD_STUDIO_BUS* bus;
    if (FMOD_Studio_System_GetBus(gStudioSystem, (const char*)path, &bus) == FMOD_OK)
        FMOD_Studio_Bus_SetMute(bus, mute);
}
DEFINE_PRIM(_VOID, set_bus_mute, _BYTES _BOOL);

HL_PRIM bool HL_NAME(get_bus_mute)(vbyte* path) {
    if (!gStudioSystem) return false;
    FMOD_STUDIO_BUS* bus;
    if (FMOD_Studio_System_GetBus(gStudioSystem, (const char*)path, &bus) == FMOD_OK) {
        FMOD_BOOL mute = 0;
        FMOD_Studio_Bus_GetMute(bus, &mute);
        return mute != 0;
    }
    return false;
}
DEFINE_PRIM(_BOOL, get_bus_mute, _BYTES);

//// Callbacks

HL_PRIM int HL_NAME(evi_set_callback_mask)(int h, int mask) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Studio_EventInstance_SetCallback(instance, eventCallback,
        (FMOD_STUDIO_EVENT_CALLBACK_TYPE)(unsigned int)mask);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, evi_set_callback_mask, _I32 _I32);

// Drain protocol: cb_next pops the oldest queued event into a static slot;
// the accessors read fields from that slot. Haxe thread only.
static FaxeCbEvent gCbCurrent;

HL_PRIM bool HL_NAME(cb_next)() {
    return faxe_cbq_pop(&gCbCurrent) == 1;
}
DEFINE_PRIM(_BOOL, cb_next, _NO_ARG);

HL_PRIM int HL_NAME(cb_handle)() {
    return gCbCurrent.handle;
}
DEFINE_PRIM(_I32, cb_handle, _NO_ARG);

HL_PRIM int HL_NAME(cb_type)() {
    return (int)gCbCurrent.type;
}
DEFINE_PRIM(_I32, cb_type, _NO_ARG);

HL_PRIM int HL_NAME(cb_int)(int index) {
    return index == 0 ? gCbCurrent.i1 : (index == 1 ? gCbCurrent.i2 : gCbCurrent.i3);
}
DEFINE_PRIM(_I32, cb_int, _I32);

HL_PRIM double HL_NAME(cb_float)() {
    return (double)gCbCurrent.f1;
}
DEFINE_PRIM(_F64, cb_float, _NO_ARG);

HL_PRIM vbyte* HL_NAME(cb_string)() {
    return (vbyte*)gCbCurrent.str;
}
DEFINE_PRIM(_BYTES, cb_string, _NO_ARG);

HL_PRIM bool HL_NAME(cb_take_overflow)() {
    return faxe_cbq_take_overflow() == 1;
}
DEFINE_PRIM(_BOOL, cb_take_overflow, _NO_ARG);

//// Studio System (2.0 bindings)

HL_PRIM int HL_NAME(sys_last_result)() {
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_last_result, _NO_ARG);

HL_PRIM int HL_NAME(sys_get_bus)(vbyte* path) {
    FMOD_STUDIO_BUS* bus = NULL;
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    gLastResult = FMOD_Studio_System_GetBus(gStudioSystem, (const char*)path, &bus);
    if (gLastResult != FMOD_OK || !bus) return 0;
    return faxe_handle_alloc(bus, FAXE_TYPE_BUS);
}
DEFINE_PRIM(_I32, sys_get_bus, _BYTES);

//// Bus (2.0 bindings)

static FMOD_STUDIO_BUS* resolve_bus(int h) {
    return (FMOD_STUDIO_BUS*)faxe_handle_resolve(h, FAXE_TYPE_BUS);
}

HL_PRIM bool HL_NAME(bus_is_valid)(int h) {
    FMOD_STUDIO_BUS* bus = resolve_bus(h);
    return bus != NULL && FMOD_Studio_Bus_IsValid(bus);
}
DEFINE_PRIM(_BOOL, bus_is_valid, _I32);

HL_PRIM vbyte* HL_NAME(bus_get_id)(int h) {
    FMOD_STUDIO_BUS* bus = resolve_bus(h);
    FMOD_GUID id;
    gStringBuf[0] = '\0';
    if (!bus) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (vbyte*)gStringBuf; }
    gLastResult = FMOD_Studio_Bus_GetID(bus, &id);
    if (gLastResult == FMOD_OK) {
        snprintf(gStringBuf, sizeof(gStringBuf),
            "{%08x-%04x-%04x-%02x%02x-%02x%02x%02x%02x%02x%02x}",
            id.Data1, id.Data2, id.Data3,
            id.Data4[0], id.Data4[1], id.Data4[2], id.Data4[3],
            id.Data4[4], id.Data4[5], id.Data4[6], id.Data4[7]);
    }
    return (vbyte*)gStringBuf;
}
DEFINE_PRIM(_BYTES, bus_get_id, _I32);

HL_PRIM vbyte* HL_NAME(bus_get_path)(int h) {
    FMOD_STUDIO_BUS* bus = resolve_bus(h);
    int retrieved = 0;
    gStringBuf[0] = '\0';
    if (!bus) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (vbyte*)gStringBuf; }
    gLastResult = FMOD_Studio_Bus_GetPath(bus, gStringBuf, sizeof(gStringBuf), &retrieved);
    if (gLastResult != FMOD_OK) gStringBuf[0] = '\0';
    return (vbyte*)gStringBuf;
}
DEFINE_PRIM(_BYTES, bus_get_path, _I32);

HL_PRIM double HL_NAME(bus_get_volume)(int h) {
    FMOD_STUDIO_BUS* bus = resolve_bus(h);
    float volume = 0.0f;
    if (!bus) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    gLastResult = FMOD_Studio_Bus_GetVolume(bus, &volume, NULL);
    return (double)volume;
}
DEFINE_PRIM(_F64, bus_get_volume, _I32);

HL_PRIM double HL_NAME(bus_get_final_volume)(int h) {
    FMOD_STUDIO_BUS* bus = resolve_bus(h);
    float volume = 0.0f;
    float finalVolume = 0.0f;
    if (!bus) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    gLastResult = FMOD_Studio_Bus_GetVolume(bus, &volume, &finalVolume);
    return (double)finalVolume;
}
DEFINE_PRIM(_F64, bus_get_final_volume, _I32);

HL_PRIM int HL_NAME(bus_set_volume)(int h, double volume) {
    FMOD_STUDIO_BUS* bus = resolve_bus(h);
    if (!bus) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Studio_Bus_SetVolume(bus, (float)volume);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, bus_set_volume, _I32 _F64);

HL_PRIM bool HL_NAME(bus_get_paused)(int h) {
    FMOD_STUDIO_BUS* bus = resolve_bus(h);
    FMOD_BOOL paused = 0;
    if (!bus) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    gLastResult = FMOD_Studio_Bus_GetPaused(bus, &paused);
    return paused != 0;
}
DEFINE_PRIM(_BOOL, bus_get_paused, _I32);

HL_PRIM int HL_NAME(bus_set_paused)(int h, bool paused) {
    FMOD_STUDIO_BUS* bus = resolve_bus(h);
    if (!bus) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Studio_Bus_SetPaused(bus, paused);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, bus_set_paused, _I32 _BOOL);

HL_PRIM bool HL_NAME(bus_get_mute)(int h) {
    FMOD_STUDIO_BUS* bus = resolve_bus(h);
    FMOD_BOOL mute = 0;
    if (!bus) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    gLastResult = FMOD_Studio_Bus_GetMute(bus, &mute);
    return mute != 0;
}
DEFINE_PRIM(_BOOL, bus_get_mute, _I32);

HL_PRIM int HL_NAME(bus_set_mute)(int h, bool mute) {
    FMOD_STUDIO_BUS* bus = resolve_bus(h);
    if (!bus) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Studio_Bus_SetMute(bus, mute);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, bus_set_mute, _I32 _BOOL);

HL_PRIM int HL_NAME(bus_stop_all_events)(int h, int stopMode) {
    FMOD_STUDIO_BUS* bus = resolve_bus(h);
    if (!bus) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Studio_Bus_StopAllEvents(bus,
        stopMode == 1 ? FMOD_STUDIO_STOP_IMMEDIATE : FMOD_STUDIO_STOP_ALLOWFADEOUT);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, bus_stop_all_events, _I32 _I32);

// out = int[2]: exclusive, inclusive (microseconds)
HL_PRIM int HL_NAME(bus_get_cpu_usage)(int h, vbyte* out) {
    FMOD_STUDIO_BUS* bus = resolve_bus(h);
    unsigned int exclusive = 0;
    unsigned int inclusive = 0;
    int* outInts = (int*)out;
    if (!bus) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Studio_Bus_GetCPUUsage(bus, &exclusive, &inclusive);
    outInts[0] = (int)exclusive;
    outInts[1] = (int)inclusive;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, bus_get_cpu_usage, _I32 _BYTES);

// out = int[3]: exclusive, inclusive, sampledata (bytes)
HL_PRIM int HL_NAME(bus_get_memory_usage)(int h, vbyte* out) {
    FMOD_STUDIO_BUS* bus = resolve_bus(h);
    FMOD_STUDIO_MEMORY_USAGE usage;
    int* outInts = (int*)out;
    usage.exclusive = 0; usage.inclusive = 0; usage.sampledata = 0;
    if (!bus) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Studio_Bus_GetMemoryUsage(bus, &usage);
    outInts[0] = usage.exclusive;
    outInts[1] = usage.inclusive;
    outInts[2] = usage.sampledata;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, bus_get_memory_usage, _I32 _BYTES);

//// Debug

HL_PRIM int HL_NAME(debug_live_handle_count)() {
    return faxe_live_handle_count();
}
DEFINE_PRIM(_I32, debug_live_handle_count, _NO_ARG);
