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
#include "../shared/faxe_guid.h"
#include "../shared/faxe_cbqueue.h"
#include "../shared/faxe_instctx.h"

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
// handle table or any HL values; it reads the per-instance context back from
// FMOD userdata, copies payloads into a plain C record, and pushes it onto
// the shared queue. The Haxe thread drains the queue during update().
// Programmer sounds are resolved right here on the FMOD thread: the key was
// stored in the context by ps_assign (guarded by the queue mutex).
static FMOD_RESULT F_CALLBACK eventCallback(FMOD_STUDIO_EVENT_CALLBACK_TYPE type,
    FMOD_STUDIO_EVENTINSTANCE* event, void* parameters) {
    void* userData = NULL;
    FaxeInstCtx* ctx;
    int handle;
    FaxeCbEvent ev;

    FMOD_Studio_EventInstance_GetUserData(event, &userData);
    ctx = (FaxeInstCtx*)userData;
    if (!ctx || ctx->handle <= 0) return FMOD_OK;
    handle = ctx->handle;

    memset(&ev, 0, sizeof(ev));
    ev.handle = handle;
    ev.type = (uint32_t)type;

    switch (type) {
        case FMOD_STUDIO_EVENT_CALLBACK_CREATE_PROGRAMMER_SOUND: {
            FMOD_STUDIO_PROGRAMMER_SOUND_PROPERTIES* props =
                (FMOD_STUDIO_PROGRAMMER_SOUND_PROPERTIES*)parameters;
            char key[FAXE_PS_KEY_MAX];
            FMOD_STUDIO_SOUND_INFO info;
            FMOD_SOUND* sound = NULL;
            faxe_cbq_lock();
            strncpy(key, ctx->psKey, FAXE_PS_KEY_MAX - 1);
            key[FAXE_PS_KEY_MAX - 1] = '\0';
            faxe_cbq_unlock();
            if (props && key[0] != '\0' && gCoreSystem && gStudioSystem) {
                if (FMOD_Studio_System_GetSoundInfo(gStudioSystem, key, &info) == FMOD_OK) {
                    // Audio table entry
                    if (FMOD_System_CreateSound(gCoreSystem, info.name_or_data,
                            FMOD_LOOP_NORMAL | FMOD_CREATECOMPRESSEDSAMPLE | info.mode,
                            &info.exinfo, &sound) == FMOD_OK) {
                        props->sound = sound;
                        props->subsoundIndex = info.subsoundindex;
                    }
                } else if (FMOD_System_CreateSound(gCoreSystem, key, FMOD_DEFAULT, NULL, &sound) == FMOD_OK) {
                    // Plain file path fallback
                    props->sound = sound;
                    props->subsoundIndex = -1;
                }
                ctx->psSound = sound;
            }
            break;
        }
        case FMOD_STUDIO_EVENT_CALLBACK_DESTROY_PROGRAMMER_SOUND: {
            FMOD_STUDIO_PROGRAMMER_SOUND_PROPERTIES* props =
                (FMOD_STUDIO_PROGRAMMER_SOUND_PROPERTIES*)parameters;
            if (props && props->sound) {
                FMOD_Sound_Release(props->sound);
            }
            ctx->psSound = NULL;
            break;
        }
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

    // The context's lifetime ends with the instance. DESTROYED is always in
    // the installed mask (see attach_instance_ctx), so cleanup is guaranteed.
    if (type == FMOD_STUDIO_EVENT_CALLBACK_DESTROYED) {
        FMOD_Studio_EventInstance_SetUserData(event, NULL);
        faxe_instctx_destroy(ctx);
    }
    return FMOD_OK;
}

// Attaches the per-instance context and installs the shim callback with at
// least the DESTROYED bit so the context is always reclaimed. Called from
// every managed-instance creation path (Haxe thread).
static int attach_instance_ctx(FMOD_STUDIO_EVENTINSTANCE* instance, int handle) {
    FaxeInstCtx* ctx = faxe_instctx_create(handle);
    if (!ctx) return 0;
    FMOD_Studio_EventInstance_SetUserData(instance, ctx);
    FMOD_Studio_EventInstance_SetCallback(instance, eventCallback, FMOD_STUDIO_EVENT_CALLBACK_DESTROYED);
    return 1;
}

// Reads the context back from a live instance (Haxe thread only).
static FaxeInstCtx* instance_ctx(FMOD_STUDIO_EVENTINSTANCE* instance) {
    void* userData = NULL;
    FMOD_Studio_EventInstance_GetUserData(instance, &userData);
    return (FaxeInstCtx*)userData;
}

// Builds the mask actually installed on the instance: the user's mask plus
// DESTROYED (context cleanup) plus the programmer-sound bits when a key is
// assigned.
static FMOD_STUDIO_EVENT_CALLBACK_TYPE effective_callback_mask(FaxeInstCtx* ctx) {
    unsigned int mask = ctx->cbMask | FMOD_STUDIO_EVENT_CALLBACK_DESTROYED;
    faxe_cbq_lock();
    if (ctx->psKey[0] != '\0') {
        mask |= FMOD_STUDIO_EVENT_CALLBACK_CREATE_PROGRAMMER_SOUND
              | FMOD_STUDIO_EVENT_CALLBACK_DESTROY_PROGRAMMER_SOUND;
    }
    faxe_cbq_unlock();
    return (FMOD_STUDIO_EVENT_CALLBACK_TYPE)mask;
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

    // Attach the per-instance context so FMOD-thread callbacks can find the
    // handle (and programmer-sound key) without touching the handle table.
    if (!attach_instance_ctx(instance, handle)) {
        faxe_handle_free(handle);
        FMOD_Studio_EventInstance_Release(instance);
        return -1;
    }
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
    FaxeInstCtx* ctx;
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    ctx = instance_ctx(instance);
    if (!ctx) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    ctx->cbMask = (unsigned int)mask;
    gLastResult = FMOD_Studio_EventInstance_SetCallback(instance, eventCallback,
        effective_callback_mask(ctx));
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, evi_set_callback_mask, _I32 _I32);

//// Programmer sounds

HL_PRIM int HL_NAME(ps_assign)(int h, vbyte* key) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    FaxeInstCtx* ctx;
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    ctx = instance_ctx(instance);
    if (!ctx) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    faxe_cbq_lock();
    strncpy(ctx->psKey, (const char*)key, FAXE_PS_KEY_MAX - 1);
    ctx->psKey[FAXE_PS_KEY_MAX - 1] = '\0';
    faxe_cbq_unlock();
    gLastResult = FMOD_Studio_EventInstance_SetCallback(instance, eventCallback,
        effective_callback_mask(ctx));
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, ps_assign, _I32 _BYTES);

HL_PRIM int HL_NAME(ps_clear)(int h) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    FaxeInstCtx* ctx;
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    ctx = instance_ctx(instance);
    if (!ctx) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    faxe_cbq_lock();
    ctx->psKey[0] = '\0';
    faxe_cbq_unlock();
    gLastResult = FMOD_Studio_EventInstance_SetCallback(instance, eventCallback,
        effective_callback_mask(ctx));
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, ps_clear, _I32);

//// Core API micro subset (programmer sounds only)

static FMOD_SOUND* resolve_sound(int h) {
    return (FMOD_SOUND*)faxe_handle_resolve(h, FAXE_TYPE_SOUND);
}

HL_PRIM int HL_NAME(core_create_sound)(vbyte* path, int mode) {
    FMOD_SOUND* sound = NULL;
    FMOD_MODE fmodMode = FMOD_DEFAULT;
    int handle;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    if (mode & 1) fmodMode |= FMOD_LOOP_NORMAL;
    gLastResult = FMOD_System_CreateSound(gCoreSystem, (const char*)path, fmodMode, NULL, &sound);
    if (gLastResult != FMOD_OK || !sound) return 0;
    handle = faxe_handle_alloc(sound, FAXE_TYPE_SOUND);
    if (handle == 0) {
        FMOD_Sound_Release(sound);
        return 0;
    }
    return handle;
}
DEFINE_PRIM(_I32, core_create_sound, _BYTES _I32);

HL_PRIM int HL_NAME(core_release_sound)(int h) {
    FMOD_SOUND* sound = resolve_sound(h);
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Sound_Release(sound);
    if (gLastResult == FMOD_OK) faxe_handle_free(h);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, core_release_sound, _I32);

HL_PRIM int HL_NAME(core_get_sound_length)(int h) {
    FMOD_SOUND* sound = resolve_sound(h);
    unsigned int length = 0;
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return -1; }
    gLastResult = FMOD_Sound_GetLength(sound, &length, FMOD_TIMEUNIT_MS);
    if (gLastResult != FMOD_OK) return -1;
    return (int)length;
}
DEFINE_PRIM(_I32, core_get_sound_length, _I32);

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

// Copies a parameter description into the scratch buffers: name -> gStringBuf,
// fbuf [0]=min [1]=max [2]=default, ibuf [0]=type [1]=flags [2]=id1 [3]=id2.
static void write_param_desc(const FMOD_STUDIO_PARAMETER_DESCRIPTION* desc, vbyte* fbuf, vbyte* ibuf) {
    double* outFloats = (double*)fbuf;
    int* outInts = (int*)ibuf;
    snprintf(gStringBuf, sizeof(gStringBuf), "%s", desc->name ? desc->name : "");
    outFloats[0] = (double)desc->minimum;
    outFloats[1] = (double)desc->maximum;
    outFloats[2] = (double)desc->defaultvalue;
    outInts[0] = (int)desc->type;
    outInts[1] = (int)desc->flags;
    outInts[2] = (int)desc->id.data1;
    outInts[3] = (int)desc->id.data2;
}

// Narrows 12 flattened doubles (pos, vel, forward, up) into FMOD 3D attributes.
static void pack_3d_attributes(FMOD_3D_ATTRIBUTES* attrs,
    double px, double py, double pz, double vx, double vy, double vz,
    double fx, double fy, double fz, double ux, double uy, double uz) {
    attrs->position.x = (float)px; attrs->position.y = (float)py; attrs->position.z = (float)pz;
    attrs->velocity.x = (float)vx; attrs->velocity.y = (float)vy; attrs->velocity.z = (float)vz;
    attrs->forward.x  = (float)fx; attrs->forward.y  = (float)fy; attrs->forward.z  = (float)fz;
    attrs->up.x       = (float)ux; attrs->up.y       = (float)uy; attrs->up.z       = (float)uz;
}

// Widens FMOD 3D attributes into 12 flattened doubles (pos, vel, forward, up).
static void unpack_3d_attributes(const FMOD_3D_ATTRIBUTES* attrs, double* out) {
    out[0]  = (double)attrs->position.x; out[1]  = (double)attrs->position.y; out[2]  = (double)attrs->position.z;
    out[3]  = (double)attrs->velocity.x; out[4]  = (double)attrs->velocity.y; out[5]  = (double)attrs->velocity.z;
    out[6]  = (double)attrs->forward.x;  out[7]  = (double)attrs->forward.y;  out[8]  = (double)attrs->forward.z;
    out[9]  = (double)attrs->up.x;       out[10] = (double)attrs->up.y;       out[11] = (double)attrs->up.z;
}

HL_PRIM int HL_NAME(sys_last_result)() {
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_last_result, _NO_ARG);

HL_PRIM int HL_NAME(sys_get_bus)(vbyte* path) {
    FMOD_STUDIO_BUS* bus = NULL;
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    gLastResult = FMOD_Studio_System_GetBus(gStudioSystem, (const char*)path, &bus);
    if (gLastResult != FMOD_OK || !bus) return 0;
    return faxe_handle_find_or_alloc(bus, FAXE_TYPE_BUS);
}
DEFINE_PRIM(_I32, sys_get_bus, _BYTES);

HL_PRIM int HL_NAME(sys_get_bus_by_id)(vbyte* guid) {
    FMOD_STUDIO_BUS* bus = NULL;
    FMOD_GUID id;
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    if (!faxe_guid_parse((const char*)guid, &id)) { gLastResult = FMOD_ERR_INVALID_PARAM; return 0; }
    gLastResult = FMOD_Studio_System_GetBusByID(gStudioSystem, &id, &bus);
    if (gLastResult != FMOD_OK || !bus) return 0;
    return faxe_handle_find_or_alloc(bus, FAXE_TYPE_BUS);
}
DEFINE_PRIM(_I32, sys_get_bus_by_id, _BYTES);

HL_PRIM int HL_NAME(sys_get_event)(vbyte* path) {
    FMOD_STUDIO_EVENTDESCRIPTION* desc = NULL;
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    gLastResult = FMOD_Studio_System_GetEvent(gStudioSystem, (const char*)path, &desc);
    if (gLastResult != FMOD_OK || !desc) return 0;
    return faxe_handle_find_or_alloc(desc, FAXE_TYPE_EVD);
}
DEFINE_PRIM(_I32, sys_get_event, _BYTES);

HL_PRIM int HL_NAME(sys_get_event_by_id)(vbyte* guid) {
    FMOD_STUDIO_EVENTDESCRIPTION* desc = NULL;
    FMOD_GUID id;
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    if (!faxe_guid_parse((const char*)guid, &id)) { gLastResult = FMOD_ERR_INVALID_PARAM; return 0; }
    gLastResult = FMOD_Studio_System_GetEventByID(gStudioSystem, &id, &desc);
    if (gLastResult != FMOD_OK || !desc) return 0;
    return faxe_handle_find_or_alloc(desc, FAXE_TYPE_EVD);
}
DEFINE_PRIM(_I32, sys_get_event_by_id, _BYTES);

HL_PRIM int HL_NAME(sys_get_vca)(vbyte* path) {
    FMOD_STUDIO_VCA* vca = NULL;
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    gLastResult = FMOD_Studio_System_GetVCA(gStudioSystem, (const char*)path, &vca);
    if (gLastResult != FMOD_OK || !vca) return 0;
    return faxe_handle_find_or_alloc(vca, FAXE_TYPE_VCA);
}
DEFINE_PRIM(_I32, sys_get_vca, _BYTES);

HL_PRIM int HL_NAME(sys_get_vca_by_id)(vbyte* guid) {
    FMOD_STUDIO_VCA* vca = NULL;
    FMOD_GUID id;
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    if (!faxe_guid_parse((const char*)guid, &id)) { gLastResult = FMOD_ERR_INVALID_PARAM; return 0; }
    gLastResult = FMOD_Studio_System_GetVCAByID(gStudioSystem, &id, &vca);
    if (gLastResult != FMOD_OK || !vca) return 0;
    return faxe_handle_find_or_alloc(vca, FAXE_TYPE_VCA);
}
DEFINE_PRIM(_I32, sys_get_vca_by_id, _BYTES);

HL_PRIM int HL_NAME(sys_get_bank)(vbyte* path) {
    FMOD_STUDIO_BANK* bank = NULL;
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    gLastResult = FMOD_Studio_System_GetBank(gStudioSystem, (const char*)path, &bank);
    if (gLastResult != FMOD_OK || !bank) return 0;
    return faxe_handle_find_or_alloc(bank, FAXE_TYPE_BANK);
}
DEFINE_PRIM(_I32, sys_get_bank, _BYTES);

HL_PRIM int HL_NAME(sys_get_bank_by_id)(vbyte* guid) {
    FMOD_STUDIO_BANK* bank = NULL;
    FMOD_GUID id;
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    if (!faxe_guid_parse((const char*)guid, &id)) { gLastResult = FMOD_ERR_INVALID_PARAM; return 0; }
    gLastResult = FMOD_Studio_System_GetBankByID(gStudioSystem, &id, &bank);
    if (gLastResult != FMOD_OK || !bank) return 0;
    return faxe_handle_find_or_alloc(bank, FAXE_TYPE_BANK);
}
DEFINE_PRIM(_I32, sys_get_bank_by_id, _BYTES);

HL_PRIM int HL_NAME(sys_get_bank_count)() {
    int count = 0;
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    gLastResult = FMOD_Studio_System_GetBankCount(gStudioSystem, &count);
    return count;
}
DEFINE_PRIM(_I32, sys_get_bank_count, _NO_ARG);

// out = int[64]: bank handles; returns the count written
HL_PRIM int HL_NAME(sys_get_bank_list)(vbyte* out) {
    FMOD_STUDIO_BANK* banks[64];
    int count = 0;
    int i;
    int* outInts = (int*)out;
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    gLastResult = FMOD_Studio_System_GetBankList(gStudioSystem, banks, 64, &count);
    if (gLastResult != FMOD_OK) return 0;
    if (count > 64) count = 64;
    for (i = 0; i < count; i++) {
        outInts[i] = faxe_handle_find_or_alloc(banks[i], FAXE_TYPE_BANK);
    }
    return count;
}
DEFINE_PRIM(_I32, sys_get_bank_list, _BYTES);

HL_PRIM vbyte* HL_NAME(sys_lookup_id)(vbyte* path) {
    FMOD_GUID id;
    gStringBuf[0] = '\0';
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (vbyte*)gStringBuf; }
    gLastResult = FMOD_Studio_System_LookupID(gStudioSystem, (const char*)path, &id);
    if (gLastResult == FMOD_OK) faxe_guid_format(&id, gStringBuf, sizeof(gStringBuf));
    return (vbyte*)gStringBuf;
}
DEFINE_PRIM(_BYTES, sys_lookup_id, _BYTES);

HL_PRIM vbyte* HL_NAME(sys_lookup_path)(vbyte* guid) {
    FMOD_GUID id;
    int retrieved = 0;
    gStringBuf[0] = '\0';
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (vbyte*)gStringBuf; }
    if (!faxe_guid_parse((const char*)guid, &id)) { gLastResult = FMOD_ERR_INVALID_PARAM; return (vbyte*)gStringBuf; }
    gLastResult = FMOD_Studio_System_LookupPath(gStudioSystem, &id, gStringBuf, sizeof(gStringBuf), &retrieved);
    if (gLastResult != FMOD_OK) gStringBuf[0] = '\0';
    return (vbyte*)gStringBuf;
}
DEFINE_PRIM(_BYTES, sys_lookup_path, _BYTES);

HL_PRIM double HL_NAME(sys_get_param_by_name)(vbyte* name) {
    float value = 0.0f;
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0.0; }
    gLastResult = FMOD_Studio_System_GetParameterByName(gStudioSystem, (const char*)name, &value, NULL);
    return (double)value;
}
DEFINE_PRIM(_F64, sys_get_param_by_name, _BYTES);

HL_PRIM double HL_NAME(sys_get_param_by_name_final)(vbyte* name) {
    float value = 0.0f;
    float finalValue = 0.0f;
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0.0; }
    gLastResult = FMOD_Studio_System_GetParameterByName(gStudioSystem, (const char*)name, &value, &finalValue);
    return (double)finalValue;
}
DEFINE_PRIM(_F64, sys_get_param_by_name_final, _BYTES);

HL_PRIM int HL_NAME(sys_set_param_by_name)(vbyte* name, double value, bool ignoreSeekSpeed) {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = FMOD_Studio_System_SetParameterByName(gStudioSystem, (const char*)name,
        (float)value, ignoreSeekSpeed);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_set_param_by_name, _BYTES _F64 _BOOL);

HL_PRIM int HL_NAME(sys_set_param_by_name_with_label)(vbyte* name, vbyte* label, bool ignoreSeekSpeed) {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = FMOD_Studio_System_SetParameterByNameWithLabel(gStudioSystem, (const char*)name,
        (const char*)label, ignoreSeekSpeed);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_set_param_by_name_with_label, _BYTES _BYTES _BOOL);

HL_PRIM double HL_NAME(sys_get_param_by_id)(int id1, int id2) {
    FMOD_STUDIO_PARAMETER_ID pid;
    float value = 0.0f;
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0.0; }
    pid.data1 = (unsigned int)id1;
    pid.data2 = (unsigned int)id2;
    gLastResult = FMOD_Studio_System_GetParameterByID(gStudioSystem, pid, &value, NULL);
    return (double)value;
}
DEFINE_PRIM(_F64, sys_get_param_by_id, _I32 _I32);

HL_PRIM double HL_NAME(sys_get_param_by_id_final)(int id1, int id2) {
    FMOD_STUDIO_PARAMETER_ID pid;
    float value = 0.0f;
    float finalValue = 0.0f;
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0.0; }
    pid.data1 = (unsigned int)id1;
    pid.data2 = (unsigned int)id2;
    gLastResult = FMOD_Studio_System_GetParameterByID(gStudioSystem, pid, &value, &finalValue);
    return (double)finalValue;
}
DEFINE_PRIM(_F64, sys_get_param_by_id_final, _I32 _I32);

HL_PRIM int HL_NAME(sys_set_param_by_id)(int id1, int id2, double value, bool ignoreSeekSpeed) {
    FMOD_STUDIO_PARAMETER_ID pid;
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    pid.data1 = (unsigned int)id1;
    pid.data2 = (unsigned int)id2;
    gLastResult = FMOD_Studio_System_SetParameterByID(gStudioSystem, pid, (float)value, ignoreSeekSpeed);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_set_param_by_id, _I32 _I32 _F64 _BOOL);

HL_PRIM int HL_NAME(sys_set_param_by_id_with_label)(int id1, int id2, vbyte* label, bool ignoreSeekSpeed) {
    FMOD_STUDIO_PARAMETER_ID pid;
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    pid.data1 = (unsigned int)id1;
    pid.data2 = (unsigned int)id2;
    gLastResult = FMOD_Studio_System_SetParameterByIDWithLabel(gStudioSystem, pid,
        (const char*)label, ignoreSeekSpeed);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_set_param_by_id_with_label, _I32 _I32 _BYTES _BOOL);

HL_PRIM int HL_NAME(sys_get_parameter_description_count)() {
    int count = 0;
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    gLastResult = FMOD_Studio_System_GetParameterDescriptionCount(gStudioSystem, &count);
    return count;
}
DEFINE_PRIM(_I32, sys_get_parameter_description_count, _NO_ARG);

// FMOD has no by-index getter for global parameters, only the list call,
// so fetch through the list; index must stay below the list cap (64).
HL_PRIM vbyte* HL_NAME(sys_get_parameter_description_by_index)(int index, vbyte* fbuf, vbyte* ibuf) {
    FMOD_STUDIO_PARAMETER_DESCRIPTION list[64];
    int count = 0;
    gStringBuf[0] = '\0';
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (vbyte*)gStringBuf; }
    if (index < 0 || index >= 64) { gLastResult = FMOD_ERR_INVALID_PARAM; return (vbyte*)gStringBuf; }
    gLastResult = FMOD_Studio_System_GetParameterDescriptionList(gStudioSystem, list, index + 1, &count);
    if (gLastResult != FMOD_OK) return (vbyte*)gStringBuf;
    if (index >= count) { gLastResult = FMOD_ERR_INVALID_PARAM; return (vbyte*)gStringBuf; }
    write_param_desc(&list[index], fbuf, ibuf);
    return (vbyte*)gStringBuf;
}
DEFINE_PRIM(_BYTES, sys_get_parameter_description_by_index, _I32 _BYTES _BYTES);

HL_PRIM vbyte* HL_NAME(sys_get_parameter_description_by_name)(vbyte* name, vbyte* fbuf, vbyte* ibuf) {
    FMOD_STUDIO_PARAMETER_DESCRIPTION desc;
    gStringBuf[0] = '\0';
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (vbyte*)gStringBuf; }
    gLastResult = FMOD_Studio_System_GetParameterDescriptionByName(gStudioSystem, (const char*)name, &desc);
    if (gLastResult == FMOD_OK) write_param_desc(&desc, fbuf, ibuf);
    return (vbyte*)gStringBuf;
}
DEFINE_PRIM(_BYTES, sys_get_parameter_description_by_name, _BYTES _BYTES _BYTES);

HL_PRIM vbyte* HL_NAME(sys_get_parameter_label)(vbyte* name, int labelIndex) {
    int retrieved = 0;
    gStringBuf[0] = '\0';
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (vbyte*)gStringBuf; }
    gLastResult = FMOD_Studio_System_GetParameterLabelByName(gStudioSystem, (const char*)name,
        labelIndex, gStringBuf, sizeof(gStringBuf), &retrieved);
    if (gLastResult != FMOD_OK) gStringBuf[0] = '\0';
    return (vbyte*)gStringBuf;
}
DEFINE_PRIM(_BYTES, sys_get_parameter_label, _BYTES _I32);

HL_PRIM int HL_NAME(sys_get_num_listeners)() {
    int num = 0;
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    gLastResult = FMOD_Studio_System_GetNumListeners(gStudioSystem, &num);
    return num;
}
DEFINE_PRIM(_I32, sys_get_num_listeners, _NO_ARG);

HL_PRIM int HL_NAME(sys_set_num_listeners)(int num) {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = FMOD_Studio_System_SetNumListeners(gStudioSystem, num);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_set_num_listeners, _I32);

// out = double[12]: position xyz, velocity xyz, forward xyz, up xyz
HL_PRIM int HL_NAME(sys_get_listener_attributes)(int index, vbyte* out) {
    FMOD_3D_ATTRIBUTES attrs;
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    memset(&attrs, 0, sizeof(attrs));
    gLastResult = FMOD_Studio_System_GetListenerAttributes(gStudioSystem, index, &attrs, NULL);
    unpack_3d_attributes(&attrs, (double*)out);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_get_listener_attributes, _I32 _BYTES);

HL_PRIM int HL_NAME(sys_set_listener_attributes)(int index, vbyte* f) {
    FMOD_3D_ATTRIBUTES attrs;
    double* d = (double*)f;
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    pack_3d_attributes(&attrs, d[0], d[1], d[2], d[3], d[4], d[5], d[6], d[7], d[8], d[9], d[10], d[11]);
    gLastResult = FMOD_Studio_System_SetListenerAttributes(gStudioSystem, index, &attrs, NULL);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_set_listener_attributes, _I32 _BYTES);

HL_PRIM double HL_NAME(sys_get_listener_weight)(int index) {
    float weight = 0.0f;
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0.0; }
    gLastResult = FMOD_Studio_System_GetListenerWeight(gStudioSystem, index, &weight);
    return (double)weight;
}
DEFINE_PRIM(_F64, sys_get_listener_weight, _I32);

HL_PRIM int HL_NAME(sys_set_listener_weight)(int index, double weight) {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = FMOD_Studio_System_SetListenerWeight(gStudioSystem, index, (float)weight);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_set_listener_weight, _I32 _F64);

// flags: bit0 = nonblocking; returns a bank handle or 0 on failure
HL_PRIM int HL_NAME(sys_load_bank_file)(vbyte* path, int flags) {
    FMOD_STUDIO_BANK* bank = NULL;
    FMOD_STUDIO_LOAD_BANK_FLAGS loadFlags;
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    loadFlags = (flags & 1) ? FMOD_STUDIO_LOAD_BANK_NONBLOCKING : FMOD_STUDIO_LOAD_BANK_NORMAL;
    gLastResult = FMOD_Studio_System_LoadBankFile(gStudioSystem, (const char*)path, loadFlags, &bank);
    if (gLastResult != FMOD_OK || !bank) return 0;
    return faxe_handle_find_or_alloc(bank, FAXE_TYPE_BANK);
}
DEFINE_PRIM(_I32, sys_load_bank_file, _BYTES _I32);

HL_PRIM int HL_NAME(sys_unload_all)() {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = FMOD_Studio_System_UnloadAll(gStudioSystem);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_unload_all, _NO_ARG);

HL_PRIM int HL_NAME(sys_flush_commands)() {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = FMOD_Studio_System_FlushCommands(gStudioSystem);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_flush_commands, _NO_ARG);

HL_PRIM int HL_NAME(sys_flush_sample_loading)() {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = FMOD_Studio_System_FlushSampleLoading(gStudioSystem);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_flush_sample_loading, _NO_ARG);

// out = double[7]: studio update, core dsp/stream/geometry/update/conv1/conv2 (percent)
HL_PRIM int HL_NAME(sys_get_cpu_usage)(vbyte* out) {
    FMOD_STUDIO_CPU_USAGE studio;
    FMOD_CPU_USAGE core;
    double* outFloats = (double*)out;
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    memset(&studio, 0, sizeof(studio));
    memset(&core, 0, sizeof(core));
    gLastResult = FMOD_Studio_System_GetCPUUsage(gStudioSystem, &studio, &core);
    outFloats[0] = (double)studio.update;
    outFloats[1] = (double)core.dsp;
    outFloats[2] = (double)core.stream;
    outFloats[3] = (double)core.geometry;
    outFloats[4] = (double)core.update;
    outFloats[5] = (double)core.convolution1;
    outFloats[6] = (double)core.convolution2;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_get_cpu_usage, _BYTES);

// iout = int[8]: cmdqueue cur/peak/cap/stallcount, handle cur/peak/cap/stallcount;
// fout = double[2]: cmdqueue stalltime, handle stalltime (seconds)
HL_PRIM int HL_NAME(sys_get_buffer_usage)(vbyte* iout, vbyte* fout) {
    FMOD_STUDIO_BUFFER_USAGE usage;
    int* outInts = (int*)iout;
    double* outFloats = (double*)fout;
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    memset(&usage, 0, sizeof(usage));
    gLastResult = FMOD_Studio_System_GetBufferUsage(gStudioSystem, &usage);
    outInts[0] = usage.studiocommandqueue.currentusage;
    outInts[1] = usage.studiocommandqueue.peakusage;
    outInts[2] = usage.studiocommandqueue.capacity;
    outInts[3] = usage.studiocommandqueue.stallcount;
    outInts[4] = usage.studiohandle.currentusage;
    outInts[5] = usage.studiohandle.peakusage;
    outInts[6] = usage.studiohandle.capacity;
    outInts[7] = usage.studiohandle.stallcount;
    outFloats[0] = (double)usage.studiocommandqueue.stalltime;
    outFloats[1] = (double)usage.studiohandle.stalltime;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_get_buffer_usage, _BYTES _BYTES);

HL_PRIM int HL_NAME(sys_reset_buffer_usage)() {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = FMOD_Studio_System_ResetBufferUsage(gStudioSystem);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_reset_buffer_usage, _NO_ARG);

// out = int[3]: exclusive, inclusive, sampledata (bytes)
HL_PRIM int HL_NAME(sys_get_memory_usage)(vbyte* out) {
    FMOD_STUDIO_MEMORY_USAGE usage;
    int* outInts = (int*)out;
    usage.exclusive = 0; usage.inclusive = 0; usage.sampledata = 0;
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = FMOD_Studio_System_GetMemoryUsage(gStudioSystem, &usage);
    outInts[0] = usage.exclusive;
    outInts[1] = usage.inclusive;
    outInts[2] = usage.sampledata;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_get_memory_usage, _BYTES);

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

//// VCA (2.0 bindings)

static FMOD_STUDIO_VCA* resolve_vca(int h) {
    return (FMOD_STUDIO_VCA*)faxe_handle_resolve(h, FAXE_TYPE_VCA);
}

HL_PRIM bool HL_NAME(vca_is_valid)(int h) {
    FMOD_STUDIO_VCA* vca = resolve_vca(h);
    return vca != NULL && FMOD_Studio_VCA_IsValid(vca);
}
DEFINE_PRIM(_BOOL, vca_is_valid, _I32);

HL_PRIM vbyte* HL_NAME(vca_get_id)(int h) {
    FMOD_STUDIO_VCA* vca = resolve_vca(h);
    FMOD_GUID id;
    gStringBuf[0] = '\0';
    if (!vca) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (vbyte*)gStringBuf; }
    gLastResult = FMOD_Studio_VCA_GetID(vca, &id);
    if (gLastResult == FMOD_OK) faxe_guid_format(&id, gStringBuf, sizeof(gStringBuf));
    return (vbyte*)gStringBuf;
}
DEFINE_PRIM(_BYTES, vca_get_id, _I32);

HL_PRIM vbyte* HL_NAME(vca_get_path)(int h) {
    FMOD_STUDIO_VCA* vca = resolve_vca(h);
    int retrieved = 0;
    gStringBuf[0] = '\0';
    if (!vca) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (vbyte*)gStringBuf; }
    gLastResult = FMOD_Studio_VCA_GetPath(vca, gStringBuf, sizeof(gStringBuf), &retrieved);
    if (gLastResult != FMOD_OK) gStringBuf[0] = '\0';
    return (vbyte*)gStringBuf;
}
DEFINE_PRIM(_BYTES, vca_get_path, _I32);

HL_PRIM double HL_NAME(vca_get_volume)(int h) {
    FMOD_STUDIO_VCA* vca = resolve_vca(h);
    float volume = 0.0f;
    if (!vca) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    gLastResult = FMOD_Studio_VCA_GetVolume(vca, &volume, NULL);
    return (double)volume;
}
DEFINE_PRIM(_F64, vca_get_volume, _I32);

HL_PRIM double HL_NAME(vca_get_final_volume)(int h) {
    FMOD_STUDIO_VCA* vca = resolve_vca(h);
    float volume = 0.0f;
    float finalVolume = 0.0f;
    if (!vca) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    gLastResult = FMOD_Studio_VCA_GetVolume(vca, &volume, &finalVolume);
    return (double)finalVolume;
}
DEFINE_PRIM(_F64, vca_get_final_volume, _I32);

HL_PRIM int HL_NAME(vca_set_volume)(int h, double volume) {
    FMOD_STUDIO_VCA* vca = resolve_vca(h);
    if (!vca) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Studio_VCA_SetVolume(vca, (float)volume);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, vca_set_volume, _I32 _F64);

//// Bank (2.0 bindings)

static FMOD_STUDIO_BANK* resolve_bank(int h) {
    return (FMOD_STUDIO_BANK*)faxe_handle_resolve(h, FAXE_TYPE_BANK);
}

HL_PRIM bool HL_NAME(bank_is_valid)(int h) {
    FMOD_STUDIO_BANK* bank = resolve_bank(h);
    return bank != NULL && FMOD_Studio_Bank_IsValid(bank);
}
DEFINE_PRIM(_BOOL, bank_is_valid, _I32);

HL_PRIM vbyte* HL_NAME(bank_get_id)(int h) {
    FMOD_STUDIO_BANK* bank = resolve_bank(h);
    FMOD_GUID id;
    gStringBuf[0] = '\0';
    if (!bank) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (vbyte*)gStringBuf; }
    gLastResult = FMOD_Studio_Bank_GetID(bank, &id);
    if (gLastResult == FMOD_OK) faxe_guid_format(&id, gStringBuf, sizeof(gStringBuf));
    return (vbyte*)gStringBuf;
}
DEFINE_PRIM(_BYTES, bank_get_id, _I32);

HL_PRIM vbyte* HL_NAME(bank_get_path)(int h) {
    FMOD_STUDIO_BANK* bank = resolve_bank(h);
    int retrieved = 0;
    gStringBuf[0] = '\0';
    if (!bank) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (vbyte*)gStringBuf; }
    gLastResult = FMOD_Studio_Bank_GetPath(bank, gStringBuf, sizeof(gStringBuf), &retrieved);
    if (gLastResult != FMOD_OK) gStringBuf[0] = '\0';
    return (vbyte*)gStringBuf;
}
DEFINE_PRIM(_BYTES, bank_get_path, _I32);

// Real unload; frees the bank handle on success so stale copies stop resolving
HL_PRIM int HL_NAME(bank_unload)(int h) {
    FMOD_STUDIO_BANK* bank = resolve_bank(h);
    if (!bank) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Studio_Bank_Unload(bank);
    if (gLastResult == FMOD_OK) faxe_handle_free(h);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, bank_unload, _I32);

HL_PRIM int HL_NAME(bank_load_sample_data)(int h) {
    FMOD_STUDIO_BANK* bank = resolve_bank(h);
    if (!bank) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Studio_Bank_LoadSampleData(bank);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, bank_load_sample_data, _I32);

HL_PRIM int HL_NAME(bank_unload_sample_data)(int h) {
    FMOD_STUDIO_BANK* bank = resolve_bank(h);
    if (!bank) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Studio_Bank_UnloadSampleData(bank);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, bank_unload_sample_data, _I32);

HL_PRIM int HL_NAME(bank_get_loading_state)(int h) {
    FMOD_STUDIO_BANK* bank = resolve_bank(h);
    FMOD_STUDIO_LOADING_STATE state = FMOD_STUDIO_LOADING_STATE_UNLOADED;
    if (!bank) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)FMOD_STUDIO_LOADING_STATE_UNLOADED; }
    gLastResult = FMOD_Studio_Bank_GetLoadingState(bank, &state);
    return (int)state;
}
DEFINE_PRIM(_I32, bank_get_loading_state, _I32);

HL_PRIM int HL_NAME(bank_get_sample_loading_state)(int h) {
    FMOD_STUDIO_BANK* bank = resolve_bank(h);
    FMOD_STUDIO_LOADING_STATE state = FMOD_STUDIO_LOADING_STATE_UNLOADED;
    if (!bank) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)FMOD_STUDIO_LOADING_STATE_UNLOADED; }
    gLastResult = FMOD_Studio_Bank_GetSampleLoadingState(bank, &state);
    return (int)state;
}
DEFINE_PRIM(_I32, bank_get_sample_loading_state, _I32);

HL_PRIM int HL_NAME(bank_get_event_count)(int h) {
    FMOD_STUDIO_BANK* bank = resolve_bank(h);
    int count = 0;
    if (!bank) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_Studio_Bank_GetEventCount(bank, &count);
    return count;
}
DEFINE_PRIM(_I32, bank_get_event_count, _I32);

// out = int[64]: event description handles; returns the count written
HL_PRIM int HL_NAME(bank_get_event_list)(int h, vbyte* out) {
    FMOD_STUDIO_BANK* bank = resolve_bank(h);
    FMOD_STUDIO_EVENTDESCRIPTION* list[64];
    int count = 0;
    int i;
    int* outInts = (int*)out;
    if (!bank) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_Studio_Bank_GetEventList(bank, list, 64, &count);
    if (gLastResult != FMOD_OK) return 0;
    if (count > 64) count = 64;
    for (i = 0; i < count; i++) {
        outInts[i] = faxe_handle_find_or_alloc(list[i], FAXE_TYPE_EVD);
    }
    return count;
}
DEFINE_PRIM(_I32, bank_get_event_list, _I32 _BYTES);

HL_PRIM int HL_NAME(bank_get_bus_count)(int h) {
    FMOD_STUDIO_BANK* bank = resolve_bank(h);
    int count = 0;
    if (!bank) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_Studio_Bank_GetBusCount(bank, &count);
    return count;
}
DEFINE_PRIM(_I32, bank_get_bus_count, _I32);

// out = int[64]: bus handles; returns the count written
HL_PRIM int HL_NAME(bank_get_bus_list)(int h, vbyte* out) {
    FMOD_STUDIO_BANK* bank = resolve_bank(h);
    FMOD_STUDIO_BUS* list[64];
    int count = 0;
    int i;
    int* outInts = (int*)out;
    if (!bank) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_Studio_Bank_GetBusList(bank, list, 64, &count);
    if (gLastResult != FMOD_OK) return 0;
    if (count > 64) count = 64;
    for (i = 0; i < count; i++) {
        outInts[i] = faxe_handle_find_or_alloc(list[i], FAXE_TYPE_BUS);
    }
    return count;
}
DEFINE_PRIM(_I32, bank_get_bus_list, _I32 _BYTES);

HL_PRIM int HL_NAME(bank_get_vca_count)(int h) {
    FMOD_STUDIO_BANK* bank = resolve_bank(h);
    int count = 0;
    if (!bank) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_Studio_Bank_GetVCACount(bank, &count);
    return count;
}
DEFINE_PRIM(_I32, bank_get_vca_count, _I32);

// out = int[64]: VCA handles; returns the count written
HL_PRIM int HL_NAME(bank_get_vca_list)(int h, vbyte* out) {
    FMOD_STUDIO_BANK* bank = resolve_bank(h);
    FMOD_STUDIO_VCA* list[64];
    int count = 0;
    int i;
    int* outInts = (int*)out;
    if (!bank) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_Studio_Bank_GetVCAList(bank, list, 64, &count);
    if (gLastResult != FMOD_OK) return 0;
    if (count > 64) count = 64;
    for (i = 0; i < count; i++) {
        outInts[i] = faxe_handle_find_or_alloc(list[i], FAXE_TYPE_VCA);
    }
    return count;
}
DEFINE_PRIM(_I32, bank_get_vca_list, _I32 _BYTES);

HL_PRIM int HL_NAME(bank_get_string_count)(int h) {
    FMOD_STUDIO_BANK* bank = resolve_bank(h);
    int count = 0;
    if (!bank) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_Studio_Bank_GetStringCount(bank, &count);
    return count;
}
DEFINE_PRIM(_I32, bank_get_string_count, _I32);

// string table path by index (strings.bank only)
HL_PRIM vbyte* HL_NAME(bank_get_string_info)(int h, int index) {
    FMOD_STUDIO_BANK* bank = resolve_bank(h);
    FMOD_GUID id;
    int retrieved = 0;
    gStringBuf[0] = '\0';
    if (!bank) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (vbyte*)gStringBuf; }
    gLastResult = FMOD_Studio_Bank_GetStringInfo(bank, index, &id, gStringBuf, sizeof(gStringBuf), &retrieved);
    if (gLastResult != FMOD_OK) gStringBuf[0] = '\0';
    return (vbyte*)gStringBuf;
}
DEFINE_PRIM(_BYTES, bank_get_string_info, _I32 _I32);

// string table GUID by index (strings.bank only)
HL_PRIM vbyte* HL_NAME(bank_get_string_guid)(int h, int index) {
    FMOD_STUDIO_BANK* bank = resolve_bank(h);
    FMOD_GUID id;
    gStringBuf[0] = '\0';
    if (!bank) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (vbyte*)gStringBuf; }
    gLastResult = FMOD_Studio_Bank_GetStringInfo(bank, index, &id, NULL, 0, NULL);
    if (gLastResult == FMOD_OK) faxe_guid_format(&id, gStringBuf, sizeof(gStringBuf));
    return (vbyte*)gStringBuf;
}
DEFINE_PRIM(_BYTES, bank_get_string_guid, _I32 _I32);

//// EventDescription (2.0 bindings)

static FMOD_STUDIO_EVENTDESCRIPTION* resolve_evd(int h) {
    return (FMOD_STUDIO_EVENTDESCRIPTION*)faxe_handle_resolve(h, FAXE_TYPE_EVD);
}

HL_PRIM bool HL_NAME(evd_is_valid)(int h) {
    FMOD_STUDIO_EVENTDESCRIPTION* desc = resolve_evd(h);
    return desc != NULL && FMOD_Studio_EventDescription_IsValid(desc);
}
DEFINE_PRIM(_BOOL, evd_is_valid, _I32);

HL_PRIM vbyte* HL_NAME(evd_get_id)(int h) {
    FMOD_STUDIO_EVENTDESCRIPTION* desc = resolve_evd(h);
    FMOD_GUID id;
    gStringBuf[0] = '\0';
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (vbyte*)gStringBuf; }
    gLastResult = FMOD_Studio_EventDescription_GetID(desc, &id);
    if (gLastResult == FMOD_OK) faxe_guid_format(&id, gStringBuf, sizeof(gStringBuf));
    return (vbyte*)gStringBuf;
}
DEFINE_PRIM(_BYTES, evd_get_id, _I32);

HL_PRIM vbyte* HL_NAME(evd_get_path)(int h) {
    FMOD_STUDIO_EVENTDESCRIPTION* desc = resolve_evd(h);
    int retrieved = 0;
    gStringBuf[0] = '\0';
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (vbyte*)gStringBuf; }
    gLastResult = FMOD_Studio_EventDescription_GetPath(desc, gStringBuf, sizeof(gStringBuf), &retrieved);
    if (gLastResult != FMOD_OK) gStringBuf[0] = '\0';
    return (vbyte*)gStringBuf;
}
DEFINE_PRIM(_BYTES, evd_get_path, _I32);

HL_PRIM int HL_NAME(evd_get_length)(int h) {
    FMOD_STUDIO_EVENTDESCRIPTION* desc = resolve_evd(h);
    int length = 0;
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_Studio_EventDescription_GetLength(desc, &length);
    return length;
}
DEFINE_PRIM(_I32, evd_get_length, _I32);

// out = double[2]: min, max
HL_PRIM int HL_NAME(evd_get_min_max_distance)(int h, vbyte* out) {
    FMOD_STUDIO_EVENTDESCRIPTION* desc = resolve_evd(h);
    float minDist = 0.0f;
    float maxDist = 0.0f;
    double* outFloats = (double*)out;
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Studio_EventDescription_GetMinMaxDistance(desc, &minDist, &maxDist);
    outFloats[0] = (double)minDist;
    outFloats[1] = (double)maxDist;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, evd_get_min_max_distance, _I32 _BYTES);

HL_PRIM double HL_NAME(evd_get_sound_size)(int h) {
    FMOD_STUDIO_EVENTDESCRIPTION* desc = resolve_evd(h);
    float size = 0.0f;
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    gLastResult = FMOD_Studio_EventDescription_GetSoundSize(desc, &size);
    return (double)size;
}
DEFINE_PRIM(_F64, evd_get_sound_size, _I32);

HL_PRIM bool HL_NAME(evd_is_snapshot)(int h) {
    FMOD_STUDIO_EVENTDESCRIPTION* desc = resolve_evd(h);
    FMOD_BOOL value = 0;
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    gLastResult = FMOD_Studio_EventDescription_IsSnapshot(desc, &value);
    return value != 0;
}
DEFINE_PRIM(_BOOL, evd_is_snapshot, _I32);

HL_PRIM bool HL_NAME(evd_is_oneshot)(int h) {
    FMOD_STUDIO_EVENTDESCRIPTION* desc = resolve_evd(h);
    FMOD_BOOL value = 0;
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    gLastResult = FMOD_Studio_EventDescription_IsOneshot(desc, &value);
    return value != 0;
}
DEFINE_PRIM(_BOOL, evd_is_oneshot, _I32);

HL_PRIM bool HL_NAME(evd_is_stream)(int h) {
    FMOD_STUDIO_EVENTDESCRIPTION* desc = resolve_evd(h);
    FMOD_BOOL value = 0;
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    gLastResult = FMOD_Studio_EventDescription_IsStream(desc, &value);
    return value != 0;
}
DEFINE_PRIM(_BOOL, evd_is_stream, _I32);

HL_PRIM bool HL_NAME(evd_is_3d)(int h) {
    FMOD_STUDIO_EVENTDESCRIPTION* desc = resolve_evd(h);
    FMOD_BOOL value = 0;
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    gLastResult = FMOD_Studio_EventDescription_Is3D(desc, &value);
    return value != 0;
}
DEFINE_PRIM(_BOOL, evd_is_3d, _I32);

HL_PRIM bool HL_NAME(evd_is_doppler_enabled)(int h) {
    FMOD_STUDIO_EVENTDESCRIPTION* desc = resolve_evd(h);
    FMOD_BOOL value = 0;
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    gLastResult = FMOD_Studio_EventDescription_IsDopplerEnabled(desc, &value);
    return value != 0;
}
DEFINE_PRIM(_BOOL, evd_is_doppler_enabled, _I32);

HL_PRIM bool HL_NAME(evd_has_sustain_point)(int h) {
    FMOD_STUDIO_EVENTDESCRIPTION* desc = resolve_evd(h);
    FMOD_BOOL value = 0;
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    gLastResult = FMOD_Studio_EventDescription_HasSustainPoint(desc, &value);
    return value != 0;
}
DEFINE_PRIM(_BOOL, evd_has_sustain_point, _I32);

// Returns an instance handle or 0. The handle is stored in FMOD userdata so
// FMOD-thread callbacks can identify the instance without the handle table.
HL_PRIM int HL_NAME(evd_create_instance)(int h) {
    FMOD_STUDIO_EVENTDESCRIPTION* desc = resolve_evd(h);
    FMOD_STUDIO_EVENTINSTANCE* instance = NULL;
    int handle;
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_Studio_EventDescription_CreateInstance(desc, &instance);
    if (gLastResult != FMOD_OK || !instance) return 0;
    handle = faxe_handle_alloc(instance, FAXE_TYPE_EVI);
    if (handle == 0) {
        FMOD_Studio_EventInstance_Release(instance);
        return 0;
    }
    if (!attach_instance_ctx(instance, handle)) {
        faxe_handle_free(handle);
        FMOD_Studio_EventInstance_Release(instance);
        return 0;
    }
    return handle;
}
DEFINE_PRIM(_I32, evd_create_instance, _I32);

HL_PRIM int HL_NAME(evd_get_instance_count)(int h) {
    FMOD_STUDIO_EVENTDESCRIPTION* desc = resolve_evd(h);
    int count = 0;
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_Studio_EventDescription_GetInstanceCount(desc, &count);
    return count;
}
DEFINE_PRIM(_I32, evd_get_instance_count, _I32);

// out = int[64]: instance handles; returns the count written. Instances FMOD
// returns that we have not seen before get fresh handles.
HL_PRIM int HL_NAME(evd_get_instance_list)(int h, vbyte* out) {
    FMOD_STUDIO_EVENTDESCRIPTION* desc = resolve_evd(h);
    FMOD_STUDIO_EVENTINSTANCE* list[64];
    int count = 0;
    int i;
    int* outInts = (int*)out;
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_Studio_EventDescription_GetInstanceList(desc, list, 64, &count);
    if (gLastResult != FMOD_OK) return 0;
    if (count > 64) count = 64;
    for (i = 0; i < count; i++) {
        outInts[i] = faxe_handle_find_or_alloc(list[i], FAXE_TYPE_EVI);
    }
    return count;
}
DEFINE_PRIM(_I32, evd_get_instance_list, _I32 _BYTES);

HL_PRIM int HL_NAME(evd_release_all_instances)(int h) {
    FMOD_STUDIO_EVENTDESCRIPTION* desc = resolve_evd(h);
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Studio_EventDescription_ReleaseAllInstances(desc);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, evd_release_all_instances, _I32);

HL_PRIM int HL_NAME(evd_load_sample_data)(int h) {
    FMOD_STUDIO_EVENTDESCRIPTION* desc = resolve_evd(h);
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Studio_EventDescription_LoadSampleData(desc);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, evd_load_sample_data, _I32);

HL_PRIM int HL_NAME(evd_unload_sample_data)(int h) {
    FMOD_STUDIO_EVENTDESCRIPTION* desc = resolve_evd(h);
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Studio_EventDescription_UnloadSampleData(desc);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, evd_unload_sample_data, _I32);

HL_PRIM int HL_NAME(evd_get_sample_loading_state)(int h) {
    FMOD_STUDIO_EVENTDESCRIPTION* desc = resolve_evd(h);
    FMOD_STUDIO_LOADING_STATE state = FMOD_STUDIO_LOADING_STATE_UNLOADED;
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)FMOD_STUDIO_LOADING_STATE_UNLOADED; }
    gLastResult = FMOD_Studio_EventDescription_GetSampleLoadingState(desc, &state);
    return (int)state;
}
DEFINE_PRIM(_I32, evd_get_sample_loading_state, _I32);

HL_PRIM int HL_NAME(evd_get_parameter_description_count)(int h) {
    FMOD_STUDIO_EVENTDESCRIPTION* desc = resolve_evd(h);
    int count = 0;
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_Studio_EventDescription_GetParameterDescriptionCount(desc, &count);
    return count;
}
DEFINE_PRIM(_I32, evd_get_parameter_description_count, _I32);

HL_PRIM vbyte* HL_NAME(evd_get_parameter_description_by_index)(int h, int index, vbyte* fbuf, vbyte* ibuf) {
    FMOD_STUDIO_EVENTDESCRIPTION* desc = resolve_evd(h);
    FMOD_STUDIO_PARAMETER_DESCRIPTION param;
    gStringBuf[0] = '\0';
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (vbyte*)gStringBuf; }
    gLastResult = FMOD_Studio_EventDescription_GetParameterDescriptionByIndex(desc, index, &param);
    if (gLastResult == FMOD_OK) write_param_desc(&param, fbuf, ibuf);
    return (vbyte*)gStringBuf;
}
DEFINE_PRIM(_BYTES, evd_get_parameter_description_by_index, _I32 _I32 _BYTES _BYTES);

HL_PRIM vbyte* HL_NAME(evd_get_parameter_description_by_name)(int h, vbyte* name, vbyte* fbuf, vbyte* ibuf) {
    FMOD_STUDIO_EVENTDESCRIPTION* desc = resolve_evd(h);
    FMOD_STUDIO_PARAMETER_DESCRIPTION param;
    gStringBuf[0] = '\0';
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (vbyte*)gStringBuf; }
    gLastResult = FMOD_Studio_EventDescription_GetParameterDescriptionByName(desc, (const char*)name, &param);
    if (gLastResult == FMOD_OK) write_param_desc(&param, fbuf, ibuf);
    return (vbyte*)gStringBuf;
}
DEFINE_PRIM(_BYTES, evd_get_parameter_description_by_name, _I32 _BYTES _BYTES _BYTES);

HL_PRIM vbyte* HL_NAME(evd_get_parameter_label)(int h, vbyte* name, int labelIndex) {
    FMOD_STUDIO_EVENTDESCRIPTION* desc = resolve_evd(h);
    int retrieved = 0;
    gStringBuf[0] = '\0';
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (vbyte*)gStringBuf; }
    gLastResult = FMOD_Studio_EventDescription_GetParameterLabelByName(desc, (const char*)name,
        labelIndex, gStringBuf, sizeof(gStringBuf), &retrieved);
    if (gLastResult != FMOD_OK) gStringBuf[0] = '\0';
    return (vbyte*)gStringBuf;
}
DEFINE_PRIM(_BYTES, evd_get_parameter_label, _I32 _BYTES _I32);

HL_PRIM int HL_NAME(evd_get_user_property_count)(int h) {
    FMOD_STUDIO_EVENTDESCRIPTION* desc = resolve_evd(h);
    int count = 0;
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_Studio_EventDescription_GetUserPropertyCount(desc, &count);
    return count;
}
DEFINE_PRIM(_I32, evd_get_user_property_count, _I32);

HL_PRIM vbyte* HL_NAME(evd_get_user_property_name)(int h, int index) {
    FMOD_STUDIO_EVENTDESCRIPTION* desc = resolve_evd(h);
    FMOD_STUDIO_USER_PROPERTY prop;
    gStringBuf[0] = '\0';
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (vbyte*)gStringBuf; }
    gLastResult = FMOD_Studio_EventDescription_GetUserPropertyByIndex(desc, index, &prop);
    if (gLastResult == FMOD_OK && prop.name) {
        snprintf(gStringBuf, sizeof(gStringBuf), "%s", prop.name);
    }
    return (vbyte*)gStringBuf;
}
DEFINE_PRIM(_BYTES, evd_get_user_property_name, _I32 _I32);

// FMOD_STUDIO_USER_PROPERTY_TYPE: 0=int 1=bool 2=float 3=string
HL_PRIM int HL_NAME(evd_get_user_property_type)(int h, int index) {
    FMOD_STUDIO_EVENTDESCRIPTION* desc = resolve_evd(h);
    FMOD_STUDIO_USER_PROPERTY prop;
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_Studio_EventDescription_GetUserPropertyByIndex(desc, index, &prop);
    if (gLastResult != FMOD_OK) return 0;
    return (int)prop.type;
}
DEFINE_PRIM(_I32, evd_get_user_property_type, _I32 _I32);

// int/bool values are coerced to double so one getter covers the numeric types
HL_PRIM double HL_NAME(evd_get_user_property_float)(int h, int index) {
    FMOD_STUDIO_EVENTDESCRIPTION* desc = resolve_evd(h);
    FMOD_STUDIO_USER_PROPERTY prop;
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    gLastResult = FMOD_Studio_EventDescription_GetUserPropertyByIndex(desc, index, &prop);
    if (gLastResult != FMOD_OK) return 0.0;
    switch (prop.type) {
        case FMOD_STUDIO_USER_PROPERTY_TYPE_INTEGER: return (double)prop.intvalue;
        case FMOD_STUDIO_USER_PROPERTY_TYPE_BOOLEAN: return prop.boolvalue ? 1.0 : 0.0;
        case FMOD_STUDIO_USER_PROPERTY_TYPE_FLOAT:   return (double)prop.floatvalue;
        default: break;
    }
    return 0.0;
}
DEFINE_PRIM(_F64, evd_get_user_property_float, _I32 _I32);

HL_PRIM vbyte* HL_NAME(evd_get_user_property_string)(int h, int index) {
    FMOD_STUDIO_EVENTDESCRIPTION* desc = resolve_evd(h);
    FMOD_STUDIO_USER_PROPERTY prop;
    gStringBuf[0] = '\0';
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (vbyte*)gStringBuf; }
    gLastResult = FMOD_Studio_EventDescription_GetUserPropertyByIndex(desc, index, &prop);
    if (gLastResult == FMOD_OK && prop.type == FMOD_STUDIO_USER_PROPERTY_TYPE_STRING && prop.stringvalue) {
        snprintf(gStringBuf, sizeof(gStringBuf), "%s", prop.stringvalue);
    }
    return (vbyte*)gStringBuf;
}
DEFINE_PRIM(_BYTES, evd_get_user_property_string, _I32 _I32);

//// EventInstance (2.0 bindings)

HL_PRIM bool HL_NAME(evi_is_valid)(int h) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    return instance != NULL && FMOD_Studio_EventInstance_IsValid(instance);
}
DEFINE_PRIM(_BOOL, evi_is_valid, _I32);

// Returns the description handle (cached per description, like bus lookups)
HL_PRIM int HL_NAME(evi_get_description)(int h) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    FMOD_STUDIO_EVENTDESCRIPTION* desc = NULL;
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_Studio_EventInstance_GetDescription(instance, &desc);
    if (gLastResult != FMOD_OK || !desc) return 0;
    return faxe_handle_find_or_alloc(desc, FAXE_TYPE_EVD);
}
DEFINE_PRIM(_I32, evi_get_description, _I32);

HL_PRIM int HL_NAME(evi_start)(int h) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Studio_EventInstance_Start(instance);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, evi_start, _I32);

HL_PRIM int HL_NAME(evi_stop)(int h, int stopMode) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Studio_EventInstance_Stop(instance,
        stopMode == 1 ? FMOD_STUDIO_STOP_IMMEDIATE : FMOD_STUDIO_STOP_ALLOWFADEOUT);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, evi_stop, _I32 _I32);

HL_PRIM int HL_NAME(evi_key_off)(int h) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Studio_EventInstance_KeyOff(instance);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, evi_key_off, _I32);

// Releases the instance (it keeps playing until it stops) and frees the handle
HL_PRIM int HL_NAME(evi_release)(int h) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Studio_EventInstance_Release(instance);
    if (gLastResult == FMOD_OK) faxe_handle_free(h);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, evi_release, _I32);

HL_PRIM int HL_NAME(evi_get_playback_state)(int h) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    FMOD_STUDIO_PLAYBACK_STATE state = FMOD_STUDIO_PLAYBACK_STOPPED;
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)FMOD_STUDIO_PLAYBACK_STOPPED; }
    gLastResult = FMOD_Studio_EventInstance_GetPlaybackState(instance, &state);
    return (int)state;
}
DEFINE_PRIM(_I32, evi_get_playback_state, _I32);

HL_PRIM bool HL_NAME(evi_get_paused)(int h) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    FMOD_BOOL paused = 0;
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    gLastResult = FMOD_Studio_EventInstance_GetPaused(instance, &paused);
    return paused != 0;
}
DEFINE_PRIM(_BOOL, evi_get_paused, _I32);

HL_PRIM int HL_NAME(evi_set_paused)(int h, bool paused) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Studio_EventInstance_SetPaused(instance, paused);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, evi_set_paused, _I32 _BOOL);

HL_PRIM double HL_NAME(evi_get_volume)(int h) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    float volume = 0.0f;
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    gLastResult = FMOD_Studio_EventInstance_GetVolume(instance, &volume, NULL);
    return (double)volume;
}
DEFINE_PRIM(_F64, evi_get_volume, _I32);

HL_PRIM double HL_NAME(evi_get_volume_final)(int h) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    float volume = 0.0f;
    float finalVolume = 0.0f;
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    gLastResult = FMOD_Studio_EventInstance_GetVolume(instance, &volume, &finalVolume);
    return (double)finalVolume;
}
DEFINE_PRIM(_F64, evi_get_volume_final, _I32);

HL_PRIM int HL_NAME(evi_set_volume)(int h, double volume) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Studio_EventInstance_SetVolume(instance, (float)volume);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, evi_set_volume, _I32 _F64);

HL_PRIM double HL_NAME(evi_get_pitch)(int h) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    float pitch = 0.0f;
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    gLastResult = FMOD_Studio_EventInstance_GetPitch(instance, &pitch, NULL);
    return (double)pitch;
}
DEFINE_PRIM(_F64, evi_get_pitch, _I32);

HL_PRIM double HL_NAME(evi_get_pitch_final)(int h) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    float pitch = 0.0f;
    float finalPitch = 0.0f;
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    gLastResult = FMOD_Studio_EventInstance_GetPitch(instance, &pitch, &finalPitch);
    return (double)finalPitch;
}
DEFINE_PRIM(_F64, evi_get_pitch_final, _I32);

HL_PRIM int HL_NAME(evi_set_pitch)(int h, double pitch) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Studio_EventInstance_SetPitch(instance, (float)pitch);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, evi_set_pitch, _I32 _F64);

HL_PRIM int HL_NAME(evi_get_timeline_position)(int h) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    int position = 0;
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_Studio_EventInstance_GetTimelinePosition(instance, &position);
    return position;
}
DEFINE_PRIM(_I32, evi_get_timeline_position, _I32);

HL_PRIM int HL_NAME(evi_set_timeline_position)(int h, int position) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Studio_EventInstance_SetTimelinePosition(instance, position);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, evi_set_timeline_position, _I32 _I32);

HL_PRIM bool HL_NAME(evi_is_virtual)(int h) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    FMOD_BOOL virtualState = 0;
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    gLastResult = FMOD_Studio_EventInstance_IsVirtual(instance, &virtualState);
    return virtualState != 0;
}
DEFINE_PRIM(_BOOL, evi_is_virtual, _I32);

// out = double[2]: min, max
HL_PRIM int HL_NAME(evi_get_min_max_distance)(int h, vbyte* out) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    float minDist = 0.0f;
    float maxDist = 0.0f;
    double* outFloats = (double*)out;
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Studio_EventInstance_GetMinMaxDistance(instance, &minDist, &maxDist);
    outFloats[0] = (double)minDist;
    outFloats[1] = (double)maxDist;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, evi_get_min_max_distance, _I32 _BYTES);

// out = double[12]: position xyz, velocity xyz, forward xyz, up xyz
HL_PRIM int HL_NAME(evi_get_3d_attributes)(int h, vbyte* out) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    FMOD_3D_ATTRIBUTES attrs;
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    memset(&attrs, 0, sizeof(attrs));
    gLastResult = FMOD_Studio_EventInstance_Get3DAttributes(instance, &attrs);
    unpack_3d_attributes(&attrs, (double*)out);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, evi_get_3d_attributes, _I32 _BYTES);

HL_PRIM int HL_NAME(evi_set_3d_attributes)(int h, vbyte* f) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    FMOD_3D_ATTRIBUTES attrs;
    double* d = (double*)f;
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    pack_3d_attributes(&attrs, d[0], d[1], d[2], d[3], d[4], d[5], d[6], d[7], d[8], d[9], d[10], d[11]);
    gLastResult = FMOD_Studio_EventInstance_Set3DAttributes(instance, &attrs);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, evi_set_3d_attributes, _I32 _BYTES);

HL_PRIM int HL_NAME(evi_get_listener_mask)(int h) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    unsigned int mask = 0;
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_Studio_EventInstance_GetListenerMask(instance, &mask);
    return (int)mask;
}
DEFINE_PRIM(_I32, evi_get_listener_mask, _I32);

HL_PRIM int HL_NAME(evi_set_listener_mask)(int h, int mask) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Studio_EventInstance_SetListenerMask(instance, (unsigned int)mask);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, evi_set_listener_mask, _I32 _I32);

// propertyIndex = FMOD_STUDIO_EVENT_PROPERTY
HL_PRIM double HL_NAME(evi_get_property)(int h, int propertyIndex) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    float value = 0.0f;
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    gLastResult = FMOD_Studio_EventInstance_GetProperty(instance,
        (FMOD_STUDIO_EVENT_PROPERTY)propertyIndex, &value);
    return (double)value;
}
DEFINE_PRIM(_F64, evi_get_property, _I32 _I32);

HL_PRIM int HL_NAME(evi_set_property)(int h, int propertyIndex, double value) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Studio_EventInstance_SetProperty(instance,
        (FMOD_STUDIO_EVENT_PROPERTY)propertyIndex, (float)value);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, evi_set_property, _I32 _I32 _F64);

HL_PRIM double HL_NAME(evi_get_reverb_level)(int h, int index) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    float level = 0.0f;
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    gLastResult = FMOD_Studio_EventInstance_GetReverbLevel(instance, index, &level);
    return (double)level;
}
DEFINE_PRIM(_F64, evi_get_reverb_level, _I32 _I32);

HL_PRIM int HL_NAME(evi_set_reverb_level)(int h, int index, double level) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Studio_EventInstance_SetReverbLevel(instance, index, (float)level);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, evi_set_reverb_level, _I32 _I32 _F64);

HL_PRIM double HL_NAME(evi_get_param_by_name)(int h, vbyte* name) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    float value = 0.0f;
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    gLastResult = FMOD_Studio_EventInstance_GetParameterByName(instance, (const char*)name, &value, NULL);
    return (double)value;
}
DEFINE_PRIM(_F64, evi_get_param_by_name, _I32 _BYTES);

HL_PRIM double HL_NAME(evi_get_param_by_name_final)(int h, vbyte* name) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    float value = 0.0f;
    float finalValue = 0.0f;
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    gLastResult = FMOD_Studio_EventInstance_GetParameterByName(instance, (const char*)name, &value, &finalValue);
    return (double)finalValue;
}
DEFINE_PRIM(_F64, evi_get_param_by_name_final, _I32 _BYTES);

HL_PRIM int HL_NAME(evi_set_param_by_name)(int h, vbyte* name, double value, bool ignoreSeekSpeed) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Studio_EventInstance_SetParameterByName(instance, (const char*)name,
        (float)value, ignoreSeekSpeed);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, evi_set_param_by_name, _I32 _BYTES _F64 _BOOL);

HL_PRIM int HL_NAME(evi_set_param_by_name_with_label)(int h, vbyte* name, vbyte* label, bool ignoreSeekSpeed) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Studio_EventInstance_SetParameterByNameWithLabel(instance, (const char*)name,
        (const char*)label, ignoreSeekSpeed);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, evi_set_param_by_name_with_label, _I32 _BYTES _BYTES _BOOL);

HL_PRIM double HL_NAME(evi_get_param_by_id)(int h, int id1, int id2) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    FMOD_STUDIO_PARAMETER_ID pid;
    float value = 0.0f;
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    pid.data1 = (unsigned int)id1;
    pid.data2 = (unsigned int)id2;
    gLastResult = FMOD_Studio_EventInstance_GetParameterByID(instance, pid, &value, NULL);
    return (double)value;
}
DEFINE_PRIM(_F64, evi_get_param_by_id, _I32 _I32 _I32);

HL_PRIM double HL_NAME(evi_get_param_by_id_final)(int h, int id1, int id2) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    FMOD_STUDIO_PARAMETER_ID pid;
    float value = 0.0f;
    float finalValue = 0.0f;
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    pid.data1 = (unsigned int)id1;
    pid.data2 = (unsigned int)id2;
    gLastResult = FMOD_Studio_EventInstance_GetParameterByID(instance, pid, &value, &finalValue);
    return (double)finalValue;
}
DEFINE_PRIM(_F64, evi_get_param_by_id_final, _I32 _I32 _I32);

HL_PRIM int HL_NAME(evi_set_param_by_id)(int h, int id1, int id2, double value, bool ignoreSeekSpeed) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    FMOD_STUDIO_PARAMETER_ID pid;
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    pid.data1 = (unsigned int)id1;
    pid.data2 = (unsigned int)id2;
    gLastResult = FMOD_Studio_EventInstance_SetParameterByID(instance, pid, (float)value, ignoreSeekSpeed);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, evi_set_param_by_id, _I32 _I32 _I32 _F64 _BOOL);

HL_PRIM int HL_NAME(evi_set_param_by_id_with_label)(int h, int id1, int id2, vbyte* label, bool ignoreSeekSpeed) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    FMOD_STUDIO_PARAMETER_ID pid;
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    pid.data1 = (unsigned int)id1;
    pid.data2 = (unsigned int)id2;
    gLastResult = FMOD_Studio_EventInstance_SetParameterByIDWithLabel(instance, pid,
        (const char*)label, ignoreSeekSpeed);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, evi_set_param_by_id_with_label, _I32 _I32 _I32 _BYTES _BOOL);

// out = int[2]: exclusive, inclusive (microseconds)
HL_PRIM int HL_NAME(evi_get_cpu_usage)(int h, vbyte* out) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    unsigned int exclusive = 0;
    unsigned int inclusive = 0;
    int* outInts = (int*)out;
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Studio_EventInstance_GetCPUUsage(instance, &exclusive, &inclusive);
    outInts[0] = (int)exclusive;
    outInts[1] = (int)inclusive;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, evi_get_cpu_usage, _I32 _BYTES);

// out = int[3]: exclusive, inclusive, sampledata (bytes)
HL_PRIM int HL_NAME(evi_get_memory_usage)(int h, vbyte* out) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    FMOD_STUDIO_MEMORY_USAGE usage;
    int* outInts = (int*)out;
    usage.exclusive = 0; usage.inclusive = 0; usage.sampledata = 0;
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Studio_EventInstance_GetMemoryUsage(instance, &usage);
    outInts[0] = usage.exclusive;
    outInts[1] = usage.inclusive;
    outInts[2] = usage.sampledata;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, evi_get_memory_usage, _I32 _BYTES);

//// Debug

HL_PRIM int HL_NAME(debug_live_handle_count)() {
    return faxe_live_handle_count();
}
DEFINE_PRIM(_I32, debug_live_handle_count, _NO_ARG);
