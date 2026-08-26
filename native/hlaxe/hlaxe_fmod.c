/**
 * HashLink FMOD bindings - Minimal FFI layer
 *
 * Raw FMOD calls only, mirrored line for line from linc_faxe.cpp. Typed
 * wrappers live in haxefmod/studio and haxefmod/core. Numeric arguments
 * pass through for FMOD to validate (it owns the rules and reports the
 * result code). The shim itself guards only memory safety: buffer sizes,
 * handle resolution, and byte counts a bare pointer cannot carry.
 */

#define HL_NAME(n) hlaxe_fmod_##n
#include <hl.h>
#include <fmod_studio.h>
#include <fmod.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>
#include "../shared/faxe_handles.h"
#include "../shared/faxe_pcmring.h"
#include "../shared/faxe_dsptype.h"
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
// next binding call. The Haxe wrappers copy immediately.
static char gStringBuf[512];

/* Shared list buffer for the list getters (Haxe thread only, like gStringBuf) */
static void* gListBuf[FAXE_LIST_MAX];

// Binding ABI marker. PostBuild.hx scans compiled hdlls for this string to
// reject stale pre-built hdlls before they become loader fatals. Keep the
// number in lockstep with the manifest header "# abi-version:".
// volatile: clang -O2 constant-folds a plain atoi(marker) and then strips
// the unreferenced string from the binary, erasing the marker the scan
// depends on. Volatile reads cannot be folded, so the string survives any
// optimization level.
static const volatile char gAbiMarker[] = "hlaxe_fmod_abi=8";

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
// handle table or any HL values. It reads the per-instance context back from
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
    if (!ctx) return FMOD_OK;
    /* handle can be rewritten from the game thread when a released instance
     * is re-acquired through evd_get_instance_list, so read it under the lock */
    faxe_cbq_lock();
    handle = ctx->handle;
    faxe_cbq_unlock();
    if (handle <= 0) return FMOD_OK;

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
                ev.i4 = props->timesignatureupper;
                ev.i5 = props->timesignaturelower;
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
                ev.i4 = props->properties.timesignatureupper;
                ev.i5 = props->properties.timesignaturelower;
                ev.f1 = props->properties.tempo;
            }
            break;
        }
        default:
            break;
    }

    // The context's lifetime ends with the instance. DESTROYED is always in
    // the installed mask (see attach_instance_ctx), so hand-off is guaranteed.
    // The context rides the queue as the event's payload and the game-thread
    // drain frees it: freeing here would race a game-thread caller that read
    // the context pointer from userdata just before this callback ran.
    if (type == FMOD_STUDIO_EVENT_CALLBACK_DESTROYED) {
        FMOD_Studio_EventInstance_SetUserData(event, NULL);
        ev.opaque = ctx;
    }

    faxe_cbq_push(&ev);
    return FMOD_OK;
}

// Attaches the per-instance context and installs the shim callback with at
// least the DESTROYED bit so the context is always reclaimed. Called from
// every managed-instance creation path (Haxe thread).
static int attach_instance_ctx(FMOD_STUDIO_EVENTINSTANCE* instance, int handle) {
    FaxeInstCtx* ctx = faxe_instctx_create(handle);
    if (!ctx) return 0;
    FMOD_Studio_EventInstance_SetUserData(instance, ctx);
    /* Without the callback the DESTROYED hand-off never happens and the
     * context would leak with the instance, so a failed install aborts */
    if (FMOD_Studio_EventInstance_SetCallback(instance, eventCallback,
            FMOD_STUDIO_EVENT_CALLBACK_DESTROYED) != FMOD_OK) {
        FMOD_Studio_EventInstance_SetUserData(instance, NULL);
        faxe_instctx_destroy(ctx);
        return 0;
    }
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

HL_PRIM bool HL_NAME(sys_is_initialized)() {
    return gStudioSystem != NULL;
}
DEFINE_PRIM(_BOOL, sys_is_initialized, _NO_ARG);

HL_PRIM void HL_NAME(sys_update)() {
    if (gStudioSystem) FMOD_Studio_System_Update(gStudioSystem);
}
DEFINE_PRIM(_VOID, sys_update, _NO_ARG);

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

HL_PRIM void HL_NAME(sys_set_auto_update)(bool enabled) {
    if (enabled && !gAutoUpdateRunning) {
        gAutoUpdateRunning = 1;
#ifdef _WIN32
        gUpdateThread = CreateThread(NULL, 0, autoUpdateLoop, NULL, 0, NULL);
#else
        if (pthread_create(&gUpdateThread, NULL, autoUpdateLoop, NULL) == 0) {
            gThreadCreated = 1;
        } else {
            /* No thread is running, and gUpdateThread is indeterminate:
             * joining it later would be undefined behavior */
            gAutoUpdateRunning = 0;
        }
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
DEFINE_PRIM(_VOID, sys_set_auto_update, _BOOL);

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
    /* The shim consumes this string itself (everywhere else strings go
     * to FMOD, whose own validation rejects NULL). A null vbyte would
     * crash the strncpy, and a key at or past the buffer size would
     * silently truncate - possibly mid-UTF-8 - and resolve the wrong
     * sound, so both are rejected. */
    if (!key || strlen((const char*)key) >= FAXE_PS_KEY_MAX) {
        gLastResult = FMOD_ERR_INVALID_PARAM;
        return (int)gLastResult;
    }
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
        gLastResult = FMOD_ERR_MEMORY; /* handle table exhausted */
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

//// Core PCM streams (user-generated audio)

// An OPENUSER looping stream paired with the ring the game thread feeds
typedef struct {
    FMOD_SOUND* sound;
    FaxePcmRing* ring;
} HlaxePcmStream;

// Mixer thread: plain C, drains the ring (silence-padded on underrun)
static FMOD_RESULT F_CALLBACK hlaxe_pcmread(FMOD_SOUND* sound, void* data, unsigned int datalen) {
    void* ud = NULL;
    FMOD_Sound_GetUserData(sound, &ud);
    if (ud) {
        faxe_pcmring_read((FaxePcmRing*)ud, data, (int)datalen);
    } else {
        memset(data, 0, datalen);
    }
    return FMOD_OK;
}

static HlaxePcmStream* resolve_pcm(int h) {
    return (HlaxePcmStream*)faxe_handle_resolve(h, FAXE_TYPE_PCM);
}

static FMOD_CHANNEL* resolve_channel(int h) {
    return (FMOD_CHANNEL*)faxe_handle_resolve(h, FAXE_TYPE_CHAN);
}

HL_PRIM int HL_NAME(core_pcm_create)(int sampleRate, int channels, int ringBytes) {
    FMOD_CREATESOUNDEXINFO exinfo;
    HlaxePcmStream* ps;
    int handle;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    if (sampleRate <= 0 || channels < 1 || channels > 2 || ringBytes <= 0) {
        gLastResult = FMOD_ERR_INVALID_PARAM;
        return 0;
    }
    ps = (HlaxePcmStream*)malloc(sizeof(HlaxePcmStream));
    if (!ps) { gLastResult = FMOD_ERR_MEMORY; return 0; }
    ps->ring = faxe_pcmring_create(ringBytes);
    if (!ps->ring) { free(ps); gLastResult = FMOD_ERR_MEMORY; return 0; }

    memset(&exinfo, 0, sizeof(exinfo));
    exinfo.cbsize = sizeof(FMOD_CREATESOUNDEXINFO);
    exinfo.numchannels = channels;
    exinfo.defaultfrequency = sampleRate;
    exinfo.format = FMOD_SOUND_FORMAT_PCM16;
    exinfo.decodebuffersize = 4096;
    exinfo.length = (unsigned int)(sampleRate * channels * 2); /* a one second window */
    exinfo.pcmreadcallback = hlaxe_pcmread;
    exinfo.userdata = ps->ring;

    gLastResult = FMOD_System_CreateSound(gCoreSystem, NULL,
        FMOD_OPENUSER | FMOD_LOOP_NORMAL | FMOD_CREATESTREAM, &exinfo, &ps->sound);
    if (gLastResult != FMOD_OK || !ps->sound) {
        faxe_pcmring_destroy(ps->ring);
        free(ps);
        return 0;
    }
    handle = faxe_handle_alloc(ps, FAXE_TYPE_PCM);
    if (handle == 0) {
        gLastResult = FMOD_ERR_MEMORY; /* handle table exhausted */
        FMOD_Sound_Release(ps->sound);
        faxe_pcmring_destroy(ps->ring);
        free(ps);
        return 0;
    }
    return handle;
}
DEFINE_PRIM(_I32, core_pcm_create, _I32 _I32 _I32);

HL_PRIM int HL_NAME(core_pcm_create_3d)(int sampleRate, int channels, int ringBytes) {
    FMOD_CREATESOUNDEXINFO exinfo;
    HlaxePcmStream* ps;
    int handle;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    if (sampleRate <= 0 || channels < 1 || channels > 2 || ringBytes <= 0) {
        gLastResult = FMOD_ERR_INVALID_PARAM;
        return 0;
    }
    ps = (HlaxePcmStream*)malloc(sizeof(HlaxePcmStream));
    if (!ps) { gLastResult = FMOD_ERR_MEMORY; return 0; }
    ps->ring = faxe_pcmring_create(ringBytes);
    if (!ps->ring) { free(ps); gLastResult = FMOD_ERR_MEMORY; return 0; }

    memset(&exinfo, 0, sizeof(exinfo));
    exinfo.cbsize = sizeof(FMOD_CREATESOUNDEXINFO);
    exinfo.numchannels = channels;
    exinfo.defaultfrequency = sampleRate;
    exinfo.format = FMOD_SOUND_FORMAT_PCM16;
    exinfo.decodebuffersize = 4096;
    exinfo.length = (unsigned int)(sampleRate * channels * 2); /* a one second window */
    exinfo.pcmreadcallback = hlaxe_pcmread;
    exinfo.userdata = ps->ring;

    gLastResult = FMOD_System_CreateSound(gCoreSystem, NULL,
        FMOD_OPENUSER | FMOD_LOOP_NORMAL | FMOD_CREATESTREAM | FMOD_3D, &exinfo, &ps->sound);
    if (gLastResult != FMOD_OK || !ps->sound) {
        faxe_pcmring_destroy(ps->ring);
        free(ps);
        return 0;
    }
    handle = faxe_handle_alloc(ps, FAXE_TYPE_PCM);
    if (handle == 0) {
        gLastResult = FMOD_ERR_MEMORY; /* handle table exhausted */
        FMOD_Sound_Release(ps->sound);
        faxe_pcmring_destroy(ps->ring);
        free(ps);
        return 0;
    }
    return handle;
}
DEFINE_PRIM(_I32, core_pcm_create_3d, _I32 _I32 _I32);

HL_PRIM int HL_NAME(core_pcm_write)(int h, vbyte* data, int len) {
    HlaxePcmStream* ps = resolve_pcm(h);
    if (!ps) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    /* A bare byte pointer carries no length, so a bad count cannot be
     * clamped here - reject it. The Haxe wrapper clamps against the real
     * buffer size before the call. */
    if (!data || len <= 0) { gLastResult = FMOD_ERR_INVALID_PARAM; return 0; }
    gLastResult = FMOD_OK;
    return faxe_pcmring_write(ps->ring, data, len);
}
DEFINE_PRIM(_I32, core_pcm_write, _I32 _BYTES _I32);

HL_PRIM int HL_NAME(core_pcm_space)(int h) {
    HlaxePcmStream* ps = resolve_pcm(h);
    if (!ps) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    return faxe_pcmring_space(ps->ring);
}
DEFINE_PRIM(_I32, core_pcm_space, _I32);

HL_PRIM int HL_NAME(core_pcm_underruns)(int h) {
    HlaxePcmStream* ps = resolve_pcm(h);
    if (!ps) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    return faxe_pcmring_take_underruns(ps->ring);
}
DEFINE_PRIM(_I32, core_pcm_underruns, _I32);

HL_PRIM int HL_NAME(core_pcm_play)(int h, bool paused) {
    HlaxePcmStream* ps = resolve_pcm(h);
    FMOD_CHANNEL* channel = NULL;
    int handle;
    if (!ps) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_System_PlaySound(gCoreSystem, ps->sound, NULL, paused ? 1 : 0, &channel);
    if (gLastResult != FMOD_OK || !channel) return 0;
    handle = faxe_handle_alloc(channel, FAXE_TYPE_CHAN);
    if (handle == 0) {
        gLastResult = FMOD_ERR_MEMORY; /* handle table exhausted */
        FMOD_Channel_Stop(channel);
        return 0;
    }
    return handle;
}
DEFINE_PRIM(_I32, core_pcm_play, _I32 _BOOL);

HL_PRIM int HL_NAME(core_pcm_release)(int h) {
    HlaxePcmStream* ps = resolve_pcm(h);
    if (!ps) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    /* Releasing a stream blocks until the mixer is done with it, so the
     * ring is safe to destroy afterward. Channels playing it stop with
     * the release and their handles go stale, which resolves safely.
     * Clearing the user data first makes any straggling pcmread fall to
     * its silence path instead of touching the ring. */
    FMOD_Sound_SetUserData(ps->sound, NULL);
    gLastResult = FMOD_Sound_Release(ps->sound);
    if (gLastResult != FMOD_OK) return (int)gLastResult;
    faxe_pcmring_destroy(ps->ring);
    free(ps);
    faxe_handle_free(h);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, core_pcm_release, _I32);

//// Core channels

HL_PRIM int HL_NAME(chan_set_volume)(int h, double volume) {
    FMOD_CHANNEL* ch = resolve_channel(h);
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Channel_SetVolume(ch, (float)volume);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_set_volume, _I32 _F64);

HL_PRIM double HL_NAME(chan_get_volume)(int h) {
    FMOD_CHANNEL* ch = resolve_channel(h);
    float volume = 0.0f;
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    gLastResult = FMOD_Channel_GetVolume(ch, &volume);
    return (double)volume;
}
DEFINE_PRIM(_F64, chan_get_volume, _I32);

HL_PRIM int HL_NAME(chan_set_pitch)(int h, double pitch) {
    FMOD_CHANNEL* ch = resolve_channel(h);
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Channel_SetPitch(ch, (float)pitch);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_set_pitch, _I32 _F64);

HL_PRIM double HL_NAME(chan_get_pitch)(int h) {
    FMOD_CHANNEL* ch = resolve_channel(h);
    float pitch = 0.0f;
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    gLastResult = FMOD_Channel_GetPitch(ch, &pitch);
    return (double)pitch;
}
DEFINE_PRIM(_F64, chan_get_pitch, _I32);

HL_PRIM int HL_NAME(chan_set_paused)(int h, bool paused) {
    FMOD_CHANNEL* ch = resolve_channel(h);
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Channel_SetPaused(ch, paused ? 1 : 0);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_set_paused, _I32 _BOOL);

HL_PRIM bool HL_NAME(chan_get_paused)(int h) {
    FMOD_CHANNEL* ch = resolve_channel(h);
    FMOD_BOOL paused = 0;
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    gLastResult = FMOD_Channel_GetPaused(ch, &paused);
    return paused != 0;
}
DEFINE_PRIM(_BOOL, chan_get_paused, _I32);

HL_PRIM bool HL_NAME(chan_is_playing)(int h) {
    FMOD_CHANNEL* ch = resolve_channel(h);
    FMOD_BOOL playing = 0;
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    gLastResult = FMOD_Channel_IsPlaying(ch, &playing);
    if (gLastResult != FMOD_OK) return false;
    return playing != 0;
}
DEFINE_PRIM(_BOOL, chan_is_playing, _I32);

HL_PRIM int HL_NAME(chan_stop)(int h) {
    FMOD_CHANNEL* ch = resolve_channel(h);
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    /* The channel is finished either way, so the slot is freed even when
     * FMOD reports the channel already gone */
    gLastResult = FMOD_Channel_Stop(ch);
    faxe_handle_free(h);
    /* Stopping tears down the channel's DSP chain, which destroys its
     * connection objects */
    faxe_handles_free_type(FAXE_TYPE_DSPCONN);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_stop, _I32);

//// Core DSP effects

static void hlaxe_reclaim_dead_lookups(void);

static FMOD_DSP* resolve_dsp(int h) {
    return (FMOD_DSP*)faxe_handle_resolve(h, FAXE_TYPE_DSP);
}

static FMOD_CHANNELGROUP* resolve_changroup(int h) {
    return (FMOD_CHANNELGROUP*)faxe_handle_resolve(h, FAXE_TYPE_CHANGROUP);
}

HL_PRIM int HL_NAME(dsp_create_by_type)(int type) {
    FMOD_DSP* dsp = NULL;
    int handle;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    /* Symbolic translation: FMOD renumbers this enum between releases,
     * so a raw cast creates the wrong effect on any other SDK version */
    FMOD_DSP_TYPE dspType = faxe_dsp_type_from_binding(type);
    if (dspType == FAXE_DSP_TYPE_UNSUPPORTED) { gLastResult = FMOD_ERR_INVALID_PARAM; return 0; }
    gLastResult = FMOD_System_CreateDSPByType(gCoreSystem, dspType, &dsp);
    if (gLastResult != FMOD_OK || !dsp) return 0;
    handle = faxe_handle_alloc(dsp, FAXE_TYPE_DSP);
    if (handle == 0) {
        gLastResult = FMOD_ERR_MEMORY; /* handle table exhausted */
        FMOD_DSP_Release(dsp);
        return 0;
    }
    return handle;
}
DEFINE_PRIM(_I32, dsp_create_by_type, _I32);

HL_PRIM int HL_NAME(dsp_release)(int h) {
    FMOD_DSP* dsp = resolve_dsp(h);
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_DSP_Release(dsp);
    if (gLastResult == FMOD_OK) {
        faxe_handle_free(h);
        // Releasing a DSP tears down its connections
        faxe_handles_free_type(FAXE_TYPE_DSPCONN);
    }
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, dsp_release, _I32);

HL_PRIM int HL_NAME(dsp_set_param_float)(int h, int index, double value) {
    FMOD_DSP* dsp = resolve_dsp(h);
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_DSP_SetParameterFloat(dsp, index, (float)value);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, dsp_set_param_float, _I32 _I32 _F64);

HL_PRIM double HL_NAME(dsp_get_param_float)(int h, int index) {
    FMOD_DSP* dsp = resolve_dsp(h);
    float value = 0.0f;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    gLastResult = FMOD_DSP_GetParameterFloat(dsp, index, &value, NULL, 0);
    return (double)value;
}
DEFINE_PRIM(_F64, dsp_get_param_float, _I32 _I32);

HL_PRIM int HL_NAME(dsp_set_param_int)(int h, int index, int value) {
    FMOD_DSP* dsp = resolve_dsp(h);
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_DSP_SetParameterInt(dsp, index, value);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, dsp_set_param_int, _I32 _I32 _I32);

HL_PRIM int HL_NAME(dsp_get_param_int)(int h, int index) {
    FMOD_DSP* dsp = resolve_dsp(h);
    int value = 0;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_DSP_GetParameterInt(dsp, index, &value, NULL, 0);
    return value;
}
DEFINE_PRIM(_I32, dsp_get_param_int, _I32 _I32);

HL_PRIM int HL_NAME(dsp_set_param_bool)(int h, int index, bool value) {
    FMOD_DSP* dsp = resolve_dsp(h);
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_DSP_SetParameterBool(dsp, index, value ? 1 : 0);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, dsp_set_param_bool, _I32 _I32 _BOOL);

HL_PRIM bool HL_NAME(dsp_get_param_bool)(int h, int index) {
    FMOD_DSP* dsp = resolve_dsp(h);
    FMOD_BOOL value = 0;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    gLastResult = FMOD_DSP_GetParameterBool(dsp, index, &value, NULL, 0);
    return value ? true : false;
}
DEFINE_PRIM(_BOOL, dsp_get_param_bool, _I32 _I32);

HL_PRIM int HL_NAME(dsp_get_num_params)(int h) {
    FMOD_DSP* dsp = resolve_dsp(h);
    int count = 0;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_DSP_GetNumParameters(dsp, &count);
    return count;
}
DEFINE_PRIM(_I32, dsp_get_num_params, _I32);

HL_PRIM int HL_NAME(dsp_get_type)(int h) {
    FMOD_DSP* dsp = resolve_dsp(h);
    FMOD_DSP_TYPE type = FMOD_DSP_TYPE_UNKNOWN;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_DSP_GetType(dsp, &type);
    return faxe_dsp_type_to_binding(type);
}
DEFINE_PRIM(_I32, dsp_get_type, _I32);

HL_PRIM int HL_NAME(dsp_set_bypass)(int h, bool bypass) {
    FMOD_DSP* dsp = resolve_dsp(h);
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_DSP_SetBypass(dsp, bypass ? 1 : 0);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, dsp_set_bypass, _I32 _BOOL);

HL_PRIM bool HL_NAME(dsp_get_bypass)(int h) {
    FMOD_DSP* dsp = resolve_dsp(h);
    FMOD_BOOL bypass = 0;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    gLastResult = FMOD_DSP_GetBypass(dsp, &bypass);
    return bypass ? true : false;
}
DEFINE_PRIM(_BOOL, dsp_get_bypass, _I32);

HL_PRIM int HL_NAME(dsp_set_wet_dry_mix)(int h, double prewet, double postwet, double dry) {
    FMOD_DSP* dsp = resolve_dsp(h);
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_DSP_SetWetDryMix(dsp, (float)prewet, (float)postwet, (float)dry);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, dsp_set_wet_dry_mix, _I32 _F64 _F64 _F64);

HL_PRIM int HL_NAME(dsp_set_active)(int h, bool active) {
    FMOD_DSP* dsp = resolve_dsp(h);
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_DSP_SetActive(dsp, active ? 1 : 0);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, dsp_set_active, _I32 _BOOL);

HL_PRIM int HL_NAME(dsp_reset)(int h) {
    FMOD_DSP* dsp = resolve_dsp(h);
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_DSP_Reset(dsp);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, dsp_reset, _I32);

HL_PRIM int HL_NAME(dsp_set_metering_enabled)(int h, bool input, bool output) {
    FMOD_DSP* dsp = resolve_dsp(h);
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_DSP_SetMeteringEnabled(dsp, input ? 1 : 0, output ? 1 : 0);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, dsp_set_metering_enabled, _I32 _BOOL _BOOL);

// out = double[2*ch]: [0..ch-1] output peak, [ch..2ch-1] output rms.
// Returns the channel count.
HL_PRIM int HL_NAME(dsp_get_metering)(int h, vbyte* out) {
    FMOD_DSP* dsp = resolve_dsp(h);
    FMOD_DSP_METERING_INFO info;
    double* outFloats = (double*)out;
    int i;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    memset(&info, 0, sizeof(info));
    gLastResult = FMOD_DSP_GetMeteringInfo(dsp, NULL, &info);
    if (gLastResult != FMOD_OK) return 0;
    for (i = 0; i < info.numchannels && i < 32; i++) {
        outFloats[i] = (double)info.peaklevel[i];
        outFloats[info.numchannels + i] = (double)info.rmslevel[i];
    }
    return (int)info.numchannels;
}
DEFINE_PRIM(_I32, dsp_get_metering, _I32 _BYTES);

// out = double[maxBins]: channel-0 spectrum magnitudes. Returns bins written.
HL_PRIM int HL_NAME(dsp_fft_get_spectrum)(int h, vbyte* out, int maxBins) {
    FMOD_DSP* dsp = resolve_dsp(h);
    FMOD_DSP_PARAMETER_FFT* fft = NULL;
    unsigned int len = 0;
    double* outFloats = (double*)out;
    int count, i;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_DSP_GetParameterData(dsp, FMOD_DSP_FFT_SPECTRUMDATA,
        (void**)&fft, &len, NULL, 0);
    if (gLastResult != FMOD_OK || !fft || fft->numchannels < 1) return 0;
    count = fft->length < maxBins ? fft->length : maxBins;
    for (i = 0; i < count; i++) outFloats[i] = (double)fft->spectrum[0][i];
    return count;
}
DEFINE_PRIM(_I32, dsp_fft_get_spectrum, _I32 _BYTES _I32);

//// Core channel groups

HL_PRIM int HL_NAME(cg_get_master)() {
    FMOD_CHANNELGROUP* group = NULL;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    gLastResult = FMOD_System_GetMasterChannelGroup(gCoreSystem, &group);
    if (gLastResult != FMOD_OK || !group) return 0;
    return faxe_handle_find_or_alloc(group, FAXE_TYPE_CHANGROUP);
}
DEFINE_PRIM(_I32, cg_get_master, _NO_ARG);

HL_PRIM int HL_NAME(cg_create)(vbyte* name) {
    FMOD_CHANNELGROUP* group = NULL;
    int handle;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    gLastResult = FMOD_System_CreateChannelGroup(gCoreSystem, (const char*)name, &group);
    if (gLastResult != FMOD_OK || !group) return 0;
    handle = faxe_handle_alloc(group, FAXE_TYPE_CHANGROUP);
    if (handle == 0) {
        gLastResult = FMOD_ERR_MEMORY; /* handle table exhausted */
        FMOD_ChannelGroup_Release(group);
        return 0;
    }
    return handle;
}
DEFINE_PRIM(_I32, cg_create, _BYTES);

HL_PRIM int HL_NAME(cg_release)(int h) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_ChannelGroup_Release(group);
    if (gLastResult == FMOD_OK) {
        faxe_handle_free(h);
        /* Releasing the group destroys the connections of every DSP in it */
        faxe_handles_free_type(FAXE_TYPE_DSPCONN);
    }
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, cg_release, _I32);

HL_PRIM int HL_NAME(cg_set_volume)(int h, double volume) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_ChannelGroup_SetVolume(group, (float)volume);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, cg_set_volume, _I32 _F64);

HL_PRIM double HL_NAME(cg_get_volume)(int h) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    float volume = 0.0f;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    gLastResult = FMOD_ChannelGroup_GetVolume(group, &volume);
    return (double)volume;
}
DEFINE_PRIM(_F64, cg_get_volume, _I32);

HL_PRIM int HL_NAME(cg_set_pitch)(int h, double pitch) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_ChannelGroup_SetPitch(group, (float)pitch);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, cg_set_pitch, _I32 _F64);

HL_PRIM double HL_NAME(cg_get_pitch)(int h) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    float pitch = 0.0f;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    gLastResult = FMOD_ChannelGroup_GetPitch(group, &pitch);
    return (double)pitch;
}
DEFINE_PRIM(_F64, cg_get_pitch, _I32);

HL_PRIM int HL_NAME(cg_set_mute)(int h, bool mute) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_ChannelGroup_SetMute(group, mute ? 1 : 0);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, cg_set_mute, _I32 _BOOL);

HL_PRIM bool HL_NAME(cg_get_mute)(int h) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    FMOD_BOOL mute = 0;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    gLastResult = FMOD_ChannelGroup_GetMute(group, &mute);
    return mute ? true : false;
}
DEFINE_PRIM(_BOOL, cg_get_mute, _I32);

HL_PRIM int HL_NAME(cg_set_paused)(int h, bool paused) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_ChannelGroup_SetPaused(group, paused ? 1 : 0);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, cg_set_paused, _I32 _BOOL);

HL_PRIM bool HL_NAME(cg_get_paused)(int h) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    FMOD_BOOL paused = 0;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    gLastResult = FMOD_ChannelGroup_GetPaused(group, &paused);
    return paused ? true : false;
}
DEFINE_PRIM(_BOOL, cg_get_paused, _I32);

HL_PRIM int HL_NAME(cg_add_dsp)(int h, int index, int dspHandle) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    FMOD_DSP* dsp = resolve_dsp(dspHandle);
    if (!group || !dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_ChannelGroup_AddDSP(group, index, dsp);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, cg_add_dsp, _I32 _I32 _I32);

HL_PRIM int HL_NAME(cg_remove_dsp)(int h, int dspHandle) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    FMOD_DSP* dsp = resolve_dsp(dspHandle);
    if (!group || !dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_ChannelGroup_RemoveDSP(group, dsp);
    /* Removing a DSP rebuilds that part of the graph and destroys the
     * affected connection objects */
    if (gLastResult == FMOD_OK) faxe_handles_free_type(FAXE_TYPE_DSPCONN);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, cg_remove_dsp, _I32 _I32);

HL_PRIM int HL_NAME(cg_stop)(int h) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_ChannelGroup_Stop(group);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, cg_stop, _I32);

//// Core channel routing and effects

HL_PRIM int HL_NAME(chan_set_pan)(int h, double pan) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Channel_SetPan(channel, (float)pan);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_set_pan, _I32 _F64);

HL_PRIM int HL_NAME(chan_set_frequency)(int h, double frequency) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Channel_SetFrequency(channel, (float)frequency);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_set_frequency, _I32 _F64);

HL_PRIM double HL_NAME(chan_get_frequency)(int h) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    float frequency = 0.0f;
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    gLastResult = FMOD_Channel_GetFrequency(channel, &frequency);
    return (double)frequency;
}
DEFINE_PRIM(_F64, chan_get_frequency, _I32);

HL_PRIM int HL_NAME(chan_set_loop_count)(int h, int loopCount) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Channel_SetLoopCount(channel, loopCount);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_set_loop_count, _I32 _I32);

HL_PRIM int HL_NAME(chan_get_position)(int h) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    unsigned int position = 0;
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return -1; }
    gLastResult = FMOD_Channel_GetPosition(channel, &position, FMOD_TIMEUNIT_MS);
    return gLastResult == FMOD_OK ? (int)position : -1;
}
DEFINE_PRIM(_I32, chan_get_position, _I32);

HL_PRIM int HL_NAME(chan_set_position)(int h, int positionMs) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Channel_SetPosition(channel, (unsigned int)positionMs, FMOD_TIMEUNIT_MS);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_set_position, _I32 _I32);

HL_PRIM int HL_NAME(chan_set_channel_group)(int h, int groupHandle) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    FMOD_CHANNELGROUP* group = resolve_changroup(groupHandle);
    if (!channel || !group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Channel_SetChannelGroup(channel, group);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_set_channel_group, _I32 _I32);

HL_PRIM int HL_NAME(chan_add_dsp)(int h, int index, int dspHandle) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    FMOD_DSP* dsp = resolve_dsp(dspHandle);
    if (!channel || !dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Channel_AddDSP(channel, index, dsp);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_add_dsp, _I32 _I32 _I32);

HL_PRIM int HL_NAME(chan_remove_dsp)(int h, int dspHandle) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    FMOD_DSP* dsp = resolve_dsp(dspHandle);
    if (!channel || !dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Channel_RemoveDSP(channel, dsp);
    /* Removing a DSP rebuilds that part of the graph and destroys the
     * affected connection objects */
    if (gLastResult == FMOD_OK) faxe_handles_free_type(FAXE_TYPE_DSPCONN);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_remove_dsp, _I32 _I32);

HL_PRIM int HL_NAME(chan_set_3d_attributes)(int h, double posX, double posY, double posZ,
        double velX, double velY, double velZ) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    FMOD_VECTOR position;
    FMOD_VECTOR velocity;
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    position.x = (float)posX; position.y = (float)posY; position.z = (float)posZ;
    velocity.x = (float)velX; velocity.y = (float)velY; velocity.z = (float)velZ;
    gLastResult = FMOD_Channel_Set3DAttributes(channel, &position, &velocity);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_set_3d_attributes, _I32 _F64 _F64 _F64 _F64 _F64 _F64);

HL_PRIM int HL_NAME(chan_set_3d_min_max)(int h, double minDist, double maxDist) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Channel_Set3DMinMaxDistance(channel, (float)minDist, (float)maxDist);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_set_3d_min_max, _I32 _F64 _F64);

HL_PRIM int HL_NAME(chan_set_reverb_wet)(int h, int instance, double wet) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Channel_SetReverbProperties(channel, instance, (float)wet);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_set_reverb_wet, _I32 _I32 _F64);

//// Studio bus to core group bridge

HL_PRIM int HL_NAME(bus_lock_channel_group)(int h) {
    FMOD_STUDIO_BUS* bus = (FMOD_STUDIO_BUS*)faxe_handle_resolve(h, FAXE_TYPE_BUS);
    if (!bus) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Studio_Bus_LockChannelGroup(bus);
    // The group is created on the async command queue. Flushing makes it
    // resolvable before the matching bus_get_channel_group call.
    if (gLastResult == FMOD_OK && gStudioSystem) {
        FMOD_Studio_System_FlushCommands(gStudioSystem);
    }
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, bus_lock_channel_group, _I32);

HL_PRIM int HL_NAME(bus_unlock_channel_group)(int h) {
    FMOD_STUDIO_BUS* bus = (FMOD_STUDIO_BUS*)faxe_handle_resolve(h, FAXE_TYPE_BUS);
    if (!bus) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Studio_Bus_UnlockChannelGroup(bus);
    // The group may be destroyed once unlocked: reclaim its cached handle
    // before a recycled address can alias it
    if (gLastResult == FMOD_OK) hlaxe_reclaim_dead_lookups();
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, bus_unlock_channel_group, _I32);

HL_PRIM int HL_NAME(bus_get_channel_group)(int h) {
    FMOD_STUDIO_BUS* bus = (FMOD_STUDIO_BUS*)faxe_handle_resolve(h, FAXE_TYPE_BUS);
    FMOD_CHANNELGROUP* group = NULL;
    if (!bus) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_Studio_Bus_GetChannelGroup(bus, &group);
    if (gLastResult != FMOD_OK || !group) return 0;
    return faxe_handle_find_or_alloc(group, FAXE_TYPE_CHANGROUP);
}
DEFINE_PRIM(_I32, bus_get_channel_group, _I32);

//// Core system extras

HL_PRIM int HL_NAME(sys_play_dsp)(int dspHandle, bool startPaused) {
    FMOD_DSP* dsp = resolve_dsp(dspHandle);
    FMOD_CHANNEL* channel = NULL;
    int handle;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    gLastResult = FMOD_System_PlayDSP(gCoreSystem, dsp, NULL, startPaused ? 1 : 0, &channel);
    if (gLastResult != FMOD_OK || !channel) return 0;
    handle = faxe_handle_alloc(channel, FAXE_TYPE_CHAN);
    if (handle == 0) {
        gLastResult = FMOD_ERR_MEMORY; /* handle table exhausted */
        FMOD_Channel_Stop(channel);
        return 0;
    }
    return handle;
}
DEFINE_PRIM(_I32, sys_play_dsp, _I32 _BOOL);

// fbuf = double[12]: reverb properties in fmod_common.h field order
// (DecayTime, EarlyDelay, LateDelay, HFReference, HFDecayRatio, Diffusion,
// Density, LowShelfFrequency, LowShelfGain, HighCut, EarlyLateMix, WetLevel)
HL_PRIM int HL_NAME(sys_set_reverb_properties)(int instance, vbyte* fbuf) {
    FMOD_REVERB_PROPERTIES props;
    double* inFloats = (double*)fbuf;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    props.DecayTime = (float)inFloats[0];
    props.EarlyDelay = (float)inFloats[1];
    props.LateDelay = (float)inFloats[2];
    props.HFReference = (float)inFloats[3];
    props.HFDecayRatio = (float)inFloats[4];
    props.Diffusion = (float)inFloats[5];
    props.Density = (float)inFloats[6];
    props.LowShelfFrequency = (float)inFloats[7];
    props.LowShelfGain = (float)inFloats[8];
    props.HighCut = (float)inFloats[9];
    props.EarlyLateMix = (float)inFloats[10];
    props.WetLevel = (float)inFloats[11];
    gLastResult = FMOD_System_SetReverbProperties(gCoreSystem, instance, &props);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_set_reverb_properties, _I32 _BYTES);

HL_PRIM int HL_NAME(sys_get_reverb_properties)(int instance, vbyte* fbuf) {
    FMOD_REVERB_PROPERTIES props;
    double* outFloats = (double*)fbuf;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    memset(&props, 0, sizeof(props));
    gLastResult = FMOD_System_GetReverbProperties(gCoreSystem, instance, &props);
    if (gLastResult != FMOD_OK) return (int)gLastResult;
    outFloats[0] = (double)props.DecayTime;
    outFloats[1] = (double)props.EarlyDelay;
    outFloats[2] = (double)props.LateDelay;
    outFloats[3] = (double)props.HFReference;
    outFloats[4] = (double)props.HFDecayRatio;
    outFloats[5] = (double)props.Diffusion;
    outFloats[6] = (double)props.Density;
    outFloats[7] = (double)props.LowShelfFrequency;
    outFloats[8] = (double)props.LowShelfGain;
    outFloats[9] = (double)props.HighCut;
    outFloats[10] = (double)props.EarlyLateMix;
    outFloats[11] = (double)props.WetLevel;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_get_reverb_properties, _I32 _BYTES);

//// Core DSP connection graph

static FMOD_DSPCONNECTION* resolve_dspconn(int h) {
    return (FMOD_DSPCONNECTION*)faxe_handle_resolve(h, FAXE_TYPE_DSPCONN);
}

HL_PRIM int HL_NAME(dsp_add_input)(int h, int inputHandle, int type) {
    FMOD_DSP* dsp = resolve_dsp(h);
    FMOD_DSP* input = resolve_dsp(inputHandle);
    FMOD_DSPCONNECTION* conn = NULL;
    if (!dsp || !input) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_DSP_AddInput(dsp, input, &conn, (FMOD_DSPCONNECTION_TYPE)type);
    if (gLastResult != FMOD_OK || !conn) return 0;
    return faxe_handle_find_or_alloc(conn, FAXE_TYPE_DSPCONN);
}
DEFINE_PRIM(_I32, dsp_add_input, _I32 _I32 _I32);

HL_PRIM int HL_NAME(dsp_disconnect_from)(int h, int inputHandle) {
    FMOD_DSP* dsp = resolve_dsp(h);
    FMOD_DSP* input = resolve_dsp(inputHandle);
    if (!dsp || !input) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_DSP_DisconnectFrom(dsp, input, NULL);
    // Graph changes invalidate connection objects on the mixer's schedule,
    // so every connection handle is dropped deterministically here
    if (gLastResult == FMOD_OK) faxe_handles_free_type(FAXE_TYPE_DSPCONN);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, dsp_disconnect_from, _I32 _I32);

HL_PRIM int HL_NAME(dsp_disconnect_all)(int h, bool inputs, bool outputs) {
    FMOD_DSP* dsp = resolve_dsp(h);
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_DSP_DisconnectAll(dsp, inputs ? 1 : 0, outputs ? 1 : 0);
    if (gLastResult == FMOD_OK) faxe_handles_free_type(FAXE_TYPE_DSPCONN);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, dsp_disconnect_all, _I32 _BOOL _BOOL);

HL_PRIM int HL_NAME(dsp_get_num_inputs)(int h) {
    FMOD_DSP* dsp = resolve_dsp(h);
    int count = 0;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_DSP_GetNumInputs(dsp, &count);
    return count;
}
DEFINE_PRIM(_I32, dsp_get_num_inputs, _I32);

HL_PRIM int HL_NAME(dsp_get_num_outputs)(int h) {
    FMOD_DSP* dsp = resolve_dsp(h);
    int count = 0;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_DSP_GetNumOutputs(dsp, &count);
    return count;
}
DEFINE_PRIM(_I32, dsp_get_num_outputs, _I32);

HL_PRIM int HL_NAME(dsp_get_input_dsp)(int h, int index) {
    FMOD_DSP* dsp = resolve_dsp(h);
    FMOD_DSP* input = NULL;
    FMOD_DSPCONNECTION* conn = NULL;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_DSP_GetInput(dsp, index, &input, &conn);
    if (gLastResult != FMOD_OK || !input) return 0;
    return faxe_handle_find_or_alloc(input, FAXE_TYPE_DSP);
}
DEFINE_PRIM(_I32, dsp_get_input_dsp, _I32 _I32);

HL_PRIM int HL_NAME(dsp_get_input_connection)(int h, int index) {
    FMOD_DSP* dsp = resolve_dsp(h);
    FMOD_DSP* input = NULL;
    FMOD_DSPCONNECTION* conn = NULL;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_DSP_GetInput(dsp, index, &input, &conn);
    if (gLastResult != FMOD_OK || !conn) return 0;
    return faxe_handle_find_or_alloc(conn, FAXE_TYPE_DSPCONN);
}
DEFINE_PRIM(_I32, dsp_get_input_connection, _I32 _I32);

HL_PRIM int HL_NAME(dspconn_set_mix)(int h, double mix) {
    FMOD_DSPCONNECTION* conn = resolve_dspconn(h);
    if (!conn) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_DSPConnection_SetMix(conn, (float)mix);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, dspconn_set_mix, _I32 _F64);

HL_PRIM double HL_NAME(dspconn_get_mix)(int h) {
    FMOD_DSPCONNECTION* conn = resolve_dspconn(h);
    float mix = 0.0f;
    if (!conn) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    gLastResult = FMOD_DSPConnection_GetMix(conn, &mix);
    return (double)mix;
}
DEFINE_PRIM(_F64, dspconn_get_mix, _I32);

HL_PRIM int HL_NAME(dspconn_get_type)(int h) {
    FMOD_DSPCONNECTION* conn = resolve_dspconn(h);
    FMOD_DSPCONNECTION_TYPE type = FMOD_DSPCONNECTION_TYPE_STANDARD;
    if (!conn) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_DSPConnection_GetType(conn, &type);
    return (int)type;
}
DEFINE_PRIM(_I32, dspconn_get_type, _I32);

//// Core channel group nesting

HL_PRIM int HL_NAME(cg_add_group)(int h, int childHandle) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    FMOD_CHANNELGROUP* child = resolve_changroup(childHandle);
    if (!group || !child) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_ChannelGroup_AddGroup(group, child, 1, NULL);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, cg_add_group, _I32 _I32);

HL_PRIM int HL_NAME(cg_get_num_groups)(int h) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    int count = 0;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_ChannelGroup_GetNumGroups(group, &count);
    return count;
}
DEFINE_PRIM(_I32, cg_get_num_groups, _I32);

HL_PRIM int HL_NAME(cg_get_group)(int h, int index) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    FMOD_CHANNELGROUP* child = NULL;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_ChannelGroup_GetGroup(group, index, &child);
    if (gLastResult != FMOD_OK || !child) return 0;
    return faxe_handle_find_or_alloc(child, FAXE_TYPE_CHANGROUP);
}
DEFINE_PRIM(_I32, cg_get_group, _I32 _I32);

HL_PRIM int HL_NAME(cg_get_parent_group)(int h) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    FMOD_CHANNELGROUP* parent = NULL;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_ChannelGroup_GetParentGroup(group, &parent);
    if (gLastResult != FMOD_OK || !parent) return 0;
    return faxe_handle_find_or_alloc(parent, FAXE_TYPE_CHANGROUP);
}
DEFINE_PRIM(_I32, cg_get_parent_group, _I32);

//// Core channel spatial and control extras

HL_PRIM int HL_NAME(chan_set_mute)(int h, bool mute) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Channel_SetMute(channel, mute ? 1 : 0);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_set_mute, _I32 _BOOL);

HL_PRIM bool HL_NAME(chan_get_mute)(int h) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    FMOD_BOOL mute = 0;
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    gLastResult = FMOD_Channel_GetMute(channel, &mute);
    return mute ? true : false;
}
DEFINE_PRIM(_BOOL, chan_get_mute, _I32);

HL_PRIM int HL_NAME(chan_set_low_pass_gain)(int h, double gain) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Channel_SetLowPassGain(channel, (float)gain);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_set_low_pass_gain, _I32 _F64);

HL_PRIM int HL_NAME(chan_set_mode)(int h, int mode) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Channel_SetMode(channel, (FMOD_MODE)mode);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_set_mode, _I32 _I32);

HL_PRIM int HL_NAME(chan_set_3d_cone_settings)(int h, double insideAngle, double outsideAngle, double outsideVolume) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Channel_Set3DConeSettings(channel, (float)insideAngle,
        (float)outsideAngle, (float)outsideVolume);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_set_3d_cone_settings, _I32 _F64 _F64 _F64);

HL_PRIM int HL_NAME(chan_set_3d_cone_orientation)(int h, double x, double y, double z) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    FMOD_VECTOR direction;
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    direction.x = (float)x; direction.y = (float)y; direction.z = (float)z;
    gLastResult = FMOD_Channel_Set3DConeOrientation(channel, &direction);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_set_3d_cone_orientation, _I32 _F64 _F64 _F64);

HL_PRIM int HL_NAME(chan_set_3d_occlusion)(int h, double direct, double reverb) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Channel_Set3DOcclusion(channel, (float)direct, (float)reverb);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_set_3d_occlusion, _I32 _F64 _F64);

// out = double[2]: direct, reverb
HL_PRIM int HL_NAME(chan_get_3d_occlusion)(int h, vbyte* out) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    float direct = 0.0f;
    float reverb = 0.0f;
    double* outFloats = (double*)out;
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Channel_Get3DOcclusion(channel, &direct, &reverb);
    outFloats[0] = (double)direct;
    outFloats[1] = (double)reverb;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_get_3d_occlusion, _I32 _BYTES);

HL_PRIM int HL_NAME(chan_set_3d_spread)(int h, double angle) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Channel_Set3DSpread(channel, (float)angle);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_set_3d_spread, _I32 _F64);

HL_PRIM int HL_NAME(chan_set_3d_level)(int h, double level) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Channel_Set3DLevel(channel, (float)level);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_set_3d_level, _I32 _F64);

HL_PRIM int HL_NAME(chan_set_3d_doppler_level)(int h, double level) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Channel_Set3DDopplerLevel(channel, (float)level);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_set_3d_doppler_level, _I32 _F64);

// in = double[outChannels*inChannels] row-major gains
HL_PRIM int HL_NAME(chan_set_mix_matrix)(int h, vbyte* in, int outChannels, int inChannels) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    double* inFloats = (double*)in;
    float matrix[32 * 32];
    int i;
    int total = outChannels * inChannels;
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    if (total < 0 || total > 32 * 32) { gLastResult = FMOD_ERR_INVALID_PARAM; return (int)gLastResult; }
    for (i = 0; i < total; i++) matrix[i] = (float)inFloats[i];
    gLastResult = FMOD_Channel_SetMixMatrix(channel, matrix, outChannels, inChannels, 0);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_set_mix_matrix, _I32 _BYTES _I32 _I32);

//// Core scheduling (DSP clocks cross as doubles: exact to 2^53 samples)

// out = double[2]: channel clock, parent group clock
HL_PRIM int HL_NAME(chan_get_dsp_clock)(int h, vbyte* out) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    unsigned long long clock = 0;
    unsigned long long parent = 0;
    double* outFloats = (double*)out;
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Channel_GetDSPClock(channel, &clock, &parent);
    outFloats[0] = (double)clock;
    outFloats[1] = (double)parent;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_get_dsp_clock, _I32 _BYTES);

HL_PRIM int HL_NAME(chan_set_delay)(int h, double startClock, double endClock, bool stopChannels) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Channel_SetDelay(channel, (unsigned long long)startClock,
        (unsigned long long)endClock, stopChannels ? 1 : 0);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_set_delay, _I32 _F64 _F64 _BOOL);

HL_PRIM int HL_NAME(chan_add_fade_point)(int h, double clock, double volume) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Channel_AddFadePoint(channel, (unsigned long long)clock, (float)volume);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_add_fade_point, _I32 _F64 _F64);

HL_PRIM int HL_NAME(chan_set_fade_point_ramp)(int h, double clock, double volume) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Channel_SetFadePointRamp(channel, (unsigned long long)clock, (float)volume);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_set_fade_point_ramp, _I32 _F64 _F64);

HL_PRIM int HL_NAME(chan_remove_fade_points)(int h, double startClock, double endClock) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Channel_RemoveFadePoints(channel, (unsigned long long)startClock,
        (unsigned long long)endClock);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_remove_fade_points, _I32 _F64 _F64);

HL_PRIM int HL_NAME(cg_get_dsp_clock)(int h, vbyte* out) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    unsigned long long clock = 0;
    unsigned long long parent = 0;
    double* outFloats = (double*)out;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_ChannelGroup_GetDSPClock(group, &clock, &parent);
    outFloats[0] = (double)clock;
    outFloats[1] = (double)parent;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, cg_get_dsp_clock, _I32 _BYTES);

HL_PRIM int HL_NAME(cg_set_delay)(int h, double startClock, double endClock, bool stopChannels) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_ChannelGroup_SetDelay(group, (unsigned long long)startClock,
        (unsigned long long)endClock, stopChannels ? 1 : 0);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, cg_set_delay, _I32 _F64 _F64 _BOOL);

HL_PRIM int HL_NAME(cg_add_fade_point)(int h, double clock, double volume) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_ChannelGroup_AddFadePoint(group, (unsigned long long)clock, (float)volume);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, cg_add_fade_point, _I32 _F64 _F64);

HL_PRIM int HL_NAME(cg_set_fade_point_ramp)(int h, double clock, double volume) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_ChannelGroup_SetFadePointRamp(group, (unsigned long long)clock, (float)volume);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, cg_set_fade_point_ramp, _I32 _F64 _F64);

HL_PRIM int HL_NAME(cg_remove_fade_points)(int h, double startClock, double endClock) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_ChannelGroup_RemoveFadePoints(group, (unsigned long long)startClock,
        (unsigned long long)endClock);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, cg_remove_fade_points, _I32 _F64 _F64);

//// Core reverb zones

static FMOD_REVERB3D* resolve_reverb3d(int h) {
    return (FMOD_REVERB3D*)faxe_handle_resolve(h, FAXE_TYPE_REVERB3D);
}

HL_PRIM int HL_NAME(sys_create_reverb3d)() {
    FMOD_REVERB3D* reverb = NULL;
    int handle;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    gLastResult = FMOD_System_CreateReverb3D(gCoreSystem, &reverb);
    if (gLastResult != FMOD_OK || !reverb) return 0;
    handle = faxe_handle_alloc(reverb, FAXE_TYPE_REVERB3D);
    if (handle == 0) {
        gLastResult = FMOD_ERR_MEMORY; /* handle table exhausted */
        FMOD_Reverb3D_Release(reverb);
        return 0;
    }
    return handle;
}
DEFINE_PRIM(_I32, sys_create_reverb3d, _NO_ARG);

HL_PRIM int HL_NAME(r3d_release)(int h) {
    FMOD_REVERB3D* reverb = resolve_reverb3d(h);
    if (!reverb) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Reverb3D_Release(reverb);
    if (gLastResult == FMOD_OK) faxe_handle_free(h);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, r3d_release, _I32);

HL_PRIM int HL_NAME(r3d_set_3d_attributes)(int h, double x, double y, double z,
        double minDist, double maxDist) {
    FMOD_REVERB3D* reverb = resolve_reverb3d(h);
    FMOD_VECTOR position;
    if (!reverb) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    position.x = (float)x; position.y = (float)y; position.z = (float)z;
    gLastResult = FMOD_Reverb3D_Set3DAttributes(reverb, &position, (float)minDist, (float)maxDist);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, r3d_set_3d_attributes, _I32 _F64 _F64 _F64 _F64 _F64);

HL_PRIM int HL_NAME(r3d_set_properties)(int h, vbyte* fbuf) {
    FMOD_REVERB3D* reverb = resolve_reverb3d(h);
    FMOD_REVERB_PROPERTIES props;
    double* inFloats = (double*)fbuf;
    if (!reverb) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    props.DecayTime = (float)inFloats[0];
    props.EarlyDelay = (float)inFloats[1];
    props.LateDelay = (float)inFloats[2];
    props.HFReference = (float)inFloats[3];
    props.HFDecayRatio = (float)inFloats[4];
    props.Diffusion = (float)inFloats[5];
    props.Density = (float)inFloats[6];
    props.LowShelfFrequency = (float)inFloats[7];
    props.LowShelfGain = (float)inFloats[8];
    props.HighCut = (float)inFloats[9];
    props.EarlyLateMix = (float)inFloats[10];
    props.WetLevel = (float)inFloats[11];
    gLastResult = FMOD_Reverb3D_SetProperties(reverb, &props);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, r3d_set_properties, _I32 _BYTES);

HL_PRIM int HL_NAME(r3d_get_properties)(int h, vbyte* fbuf) {
    FMOD_REVERB3D* reverb = resolve_reverb3d(h);
    FMOD_REVERB_PROPERTIES props;
    double* outFloats = (double*)fbuf;
    if (!reverb) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    memset(&props, 0, sizeof(props));
    gLastResult = FMOD_Reverb3D_GetProperties(reverb, &props);
    if (gLastResult != FMOD_OK) return (int)gLastResult;
    outFloats[0] = (double)props.DecayTime;
    outFloats[1] = (double)props.EarlyDelay;
    outFloats[2] = (double)props.LateDelay;
    outFloats[3] = (double)props.HFReference;
    outFloats[4] = (double)props.HFDecayRatio;
    outFloats[5] = (double)props.Diffusion;
    outFloats[6] = (double)props.Density;
    outFloats[7] = (double)props.LowShelfFrequency;
    outFloats[8] = (double)props.LowShelfGain;
    outFloats[9] = (double)props.HighCut;
    outFloats[10] = (double)props.EarlyLateMix;
    outFloats[11] = (double)props.WetLevel;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, r3d_get_properties, _I32 _BYTES);

HL_PRIM int HL_NAME(r3d_set_active)(int h, bool active) {
    FMOD_REVERB3D* reverb = resolve_reverb3d(h);
    if (!reverb) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Reverb3D_SetActive(reverb, active ? 1 : 0);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, r3d_set_active, _I32 _BOOL);

//// Core sound surface

static FMOD_SOUND* resolve_core_sound(int h) {
    return (FMOD_SOUND*)faxe_handle_resolve(h, FAXE_TYPE_SOUND);
}

HL_PRIM int HL_NAME(core_create_sound_pcm)(vbyte* data, int len, int sampleRate, int channels) {
    FMOD_CREATESOUNDEXINFO exinfo;
    FMOD_SOUND* sound = NULL;
    int handle;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    if (!data || len <= 0 || sampleRate <= 0 || channels < 1 || channels > 2) {
        gLastResult = FMOD_ERR_INVALID_PARAM;
        return 0;
    }
    memset(&exinfo, 0, sizeof(exinfo));
    exinfo.cbsize = sizeof(exinfo);
    exinfo.length = (unsigned int)len;
    exinfo.numchannels = channels;
    exinfo.defaultfrequency = sampleRate;
    exinfo.format = FMOD_SOUND_FORMAT_PCM16;
    gLastResult = FMOD_System_CreateSound(gCoreSystem, (const char*)data,
        FMOD_OPENMEMORY | FMOD_OPENRAW, &exinfo, &sound);
    if (gLastResult != FMOD_OK || !sound) return 0;
    handle = faxe_handle_alloc(sound, FAXE_TYPE_SOUND);
    if (handle == 0) {
        gLastResult = FMOD_ERR_MEMORY; /* handle table exhausted */
        FMOD_Sound_Release(sound);
        return 0;
    }
    return handle;
}
DEFINE_PRIM(_I32, core_create_sound_pcm, _BYTES _I32 _I32 _I32);

HL_PRIM int HL_NAME(core_play_sound)(int h, bool startPaused) {
    FMOD_SOUND* sound = resolve_core_sound(h);
    FMOD_CHANNEL* channel = NULL;
    int handle;
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    gLastResult = FMOD_System_PlaySound(gCoreSystem, sound, NULL, startPaused ? 1 : 0, &channel);
    if (gLastResult != FMOD_OK || !channel) return 0;
    handle = faxe_handle_alloc(channel, FAXE_TYPE_CHAN);
    if (handle == 0) {
        gLastResult = FMOD_ERR_MEMORY; /* handle table exhausted */
        FMOD_Channel_Stop(channel);
        return 0;
    }
    return handle;
}
DEFINE_PRIM(_I32, core_play_sound, _I32 _BOOL);

HL_PRIM int HL_NAME(sound_set_defaults)(int h, double frequency, int priority) {
    FMOD_SOUND* sound = resolve_core_sound(h);
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Sound_SetDefaults(sound, (float)frequency, priority);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sound_set_defaults, _I32 _F64 _I32);

// out = double[2]: frequency, priority
HL_PRIM int HL_NAME(sound_get_defaults)(int h, vbyte* out) {
    FMOD_SOUND* sound = resolve_core_sound(h);
    float frequency = 0.0f;
    int priority = 0;
    double* outFloats = (double*)out;
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Sound_GetDefaults(sound, &frequency, &priority);
    outFloats[0] = (double)frequency;
    outFloats[1] = (double)priority;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sound_get_defaults, _I32 _BYTES);

HL_PRIM int HL_NAME(sound_set_loop_points)(int h, int startMs, int endMs) {
    FMOD_SOUND* sound = resolve_core_sound(h);
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Sound_SetLoopPoints(sound, (unsigned int)startMs, FMOD_TIMEUNIT_MS,
        (unsigned int)endMs, FMOD_TIMEUNIT_MS);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sound_set_loop_points, _I32 _I32 _I32);

// out = int[2]: loop start ms, loop end ms
HL_PRIM int HL_NAME(sound_get_loop_points)(int h, vbyte* out) {
    FMOD_SOUND* sound = resolve_core_sound(h);
    unsigned int start = 0;
    unsigned int end = 0;
    int* outInts = (int*)out;
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Sound_GetLoopPoints(sound, &start, FMOD_TIMEUNIT_MS, &end, FMOD_TIMEUNIT_MS);
    outInts[0] = (int)start;
    outInts[1] = (int)end;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sound_get_loop_points, _I32 _BYTES);

HL_PRIM int HL_NAME(sound_set_mode)(int h, int mode) {
    FMOD_SOUND* sound = resolve_core_sound(h);
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Sound_SetMode(sound, (FMOD_MODE)mode);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sound_set_mode, _I32 _I32);

HL_PRIM int HL_NAME(sound_get_mode)(int h) {
    FMOD_SOUND* sound = resolve_core_sound(h);
    FMOD_MODE mode = 0;
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_Sound_GetMode(sound, &mode);
    return (int)mode;
}
DEFINE_PRIM(_I32, sound_get_mode, _I32);

// out = int[2]: channels, bits
HL_PRIM int HL_NAME(sound_get_format)(int h, vbyte* out) {
    FMOD_SOUND* sound = resolve_core_sound(h);
    FMOD_SOUND_TYPE type = FMOD_SOUND_TYPE_UNKNOWN;
    FMOD_SOUND_FORMAT format = FMOD_SOUND_FORMAT_NONE;
    int channels = 0;
    int bits = 0;
    int* outInts = (int*)out;
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Sound_GetFormat(sound, &type, &format, &channels, &bits);
    outInts[0] = channels;
    outInts[1] = bits;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sound_get_format, _I32 _BYTES);

HL_PRIM int HL_NAME(sound_get_open_state)(int h) {
    FMOD_SOUND* sound = resolve_core_sound(h);
    FMOD_OPENSTATE state = FMOD_OPENSTATE_READY;
    unsigned int buffered = 0;
    FMOD_BOOL starving = 0;
    FMOD_BOOL diskBusy = 0;
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return -1; }
    gLastResult = FMOD_Sound_GetOpenState(sound, &state, &buffered, &starving, &diskBusy);
    return gLastResult == FMOD_OK ? (int)state : -1;
}
DEFINE_PRIM(_I32, sound_get_open_state, _I32);

//// Core system extras (slice 3)

// out = int[2]: all channels, real (audible) channels
HL_PRIM int HL_NAME(sys_get_channels_playing)(vbyte* out) {
    int all = 0;
    int real = 0;
    int* outInts = (int*)out;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = FMOD_System_GetChannelsPlaying(gCoreSystem, &all, &real);
    outInts[0] = all;
    outInts[1] = real;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_get_channels_playing, _BYTES);

HL_PRIM int HL_NAME(sys_mixer_suspend)() {
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = FMOD_System_MixerSuspend(gCoreSystem);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_mixer_suspend, _NO_ARG);

HL_PRIM int HL_NAME(sys_mixer_resume)() {
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = FMOD_System_MixerResume(gCoreSystem);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_mixer_resume, _NO_ARG);

// out = int[3]: sample rate, speaker mode, raw speaker count
HL_PRIM int HL_NAME(sys_get_software_format)(vbyte* out) {
    int rate = 0;
    FMOD_SPEAKERMODE mode = FMOD_SPEAKERMODE_DEFAULT;
    int raw = 0;
    int* outInts = (int*)out;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = FMOD_System_GetSoftwareFormat(gCoreSystem, &rate, &mode, &raw);
    outInts[0] = rate;
    outInts[1] = (int)mode;
    outInts[2] = raw;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_get_software_format, _BYTES);

// out = int[2]: exclusive us, inclusive us (needs profiling enabled)
HL_PRIM int HL_NAME(dsp_get_cpu_usage)(int h, vbyte* out) {
    FMOD_DSP* dsp = resolve_dsp(h);
    unsigned int exclusive = 0;
    unsigned int inclusive = 0;
    int* outInts = (int*)out;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_DSP_GetCPUUsage(dsp, &exclusive, &inclusive);
    outInts[0] = (int)exclusive;
    outInts[1] = (int)inclusive;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, dsp_get_cpu_usage, _I32 _BYTES);

//// Channel callbacks and sync points

#define FAXE_CB_CHAN_END 0x40000001u
#define FAXE_CB_CHAN_SYNCPOINT 0x40000002u

// Runs on whichever thread pumps System::update. Pure C: reads the handle
// from the channel's user data and enqueues, never touching the runtime.
static FMOD_RESULT F_CALLBACK hlaxe_channel_callback(FMOD_CHANNELCONTROL* channelcontrol,
        FMOD_CHANNELCONTROL_TYPE controltype, FMOD_CHANNELCONTROL_CALLBACK_TYPE callbacktype,
        void* commanddata1, void* commanddata2) {
    void* userData = NULL;
    int handle;
    FaxeCbEvent event;
    (void)commanddata2;
    if (controltype != FMOD_CHANNELCONTROL_CHANNEL) return FMOD_OK;
    FMOD_Channel_GetUserData((FMOD_CHANNEL*)channelcontrol, &userData);
    handle = (int)(intptr_t)userData;
    if (!handle) return FMOD_OK;
    memset(&event, 0, sizeof(event));
    event.handle = handle;
    if (callbacktype == FMOD_CHANNELCONTROL_CALLBACK_END) {
        event.type = FAXE_CB_CHAN_END;
    } else if (callbacktype == FMOD_CHANNELCONTROL_CALLBACK_SYNCPOINT) {
        event.type = FAXE_CB_CHAN_SYNCPOINT;
        event.i1 = (int)(intptr_t)commanddata1;
    } else {
        return FMOD_OK;
    }
    faxe_cbq_push(&event);
    return FMOD_OK;
}

HL_PRIM int HL_NAME(chan_set_callback)(int h, bool enabled) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    if (enabled) {
        FMOD_Channel_SetUserData(channel, (void*)(intptr_t)h);
        gLastResult = FMOD_Channel_SetCallback(channel, hlaxe_channel_callback);
    } else {
        gLastResult = FMOD_Channel_SetCallback(channel, NULL);
        FMOD_Channel_SetUserData(channel, NULL);
    }
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_set_callback, _I32 _BOOL);

HL_PRIM int HL_NAME(sound_add_sync_point)(int h, int offsetMs, vbyte* name) {
    FMOD_SOUND* sound = resolve_core_sound(h);
    FMOD_SYNCPOINT* point = NULL;
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Sound_AddSyncPoint(sound, (unsigned int)offsetMs, FMOD_TIMEUNIT_MS,
        (const char*)name, &point);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sound_add_sync_point, _I32 _I32 _BYTES);

HL_PRIM int HL_NAME(sound_delete_sync_point)(int h, int index) {
    FMOD_SOUND* sound = resolve_core_sound(h);
    FMOD_SYNCPOINT* point = NULL;
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Sound_GetSyncPoint(sound, index, &point);
    if (gLastResult != FMOD_OK) return (int)gLastResult;
    gLastResult = FMOD_Sound_DeleteSyncPoint(sound, point);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sound_delete_sync_point, _I32 _I32);

HL_PRIM int HL_NAME(sound_get_num_sync_points)(int h) {
    FMOD_SOUND* sound = resolve_core_sound(h);
    int count = 0;
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_Sound_GetNumSyncPoints(sound, &count);
    return count;
}
DEFINE_PRIM(_I32, sound_get_num_sync_points, _I32);

HL_PRIM vbyte* HL_NAME(sound_get_sync_point_name)(int h, int index) {
    FMOD_SOUND* sound = resolve_core_sound(h);
    FMOD_SYNCPOINT* point = NULL;
    unsigned int offset = 0;
    gStringBuf[0] = '\0';
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (vbyte*)gStringBuf; }
    gLastResult = FMOD_Sound_GetSyncPoint(sound, index, &point);
    if (gLastResult != FMOD_OK) return (vbyte*)gStringBuf;
    gLastResult = FMOD_Sound_GetSyncPointInfo(sound, point, gStringBuf, sizeof(gStringBuf),
        &offset, FMOD_TIMEUNIT_MS);
    if (gLastResult != FMOD_OK) gStringBuf[0] = '\0';
    return (vbyte*)gStringBuf;
}
DEFINE_PRIM(_BYTES, sound_get_sync_point_name, _I32 _I32);

HL_PRIM int HL_NAME(sound_get_sync_point_offset)(int h, int index) {
    FMOD_SOUND* sound = resolve_core_sound(h);
    FMOD_SYNCPOINT* point = NULL;
    unsigned int offset = 0;
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return -1; }
    gLastResult = FMOD_Sound_GetSyncPoint(sound, index, &point);
    if (gLastResult != FMOD_OK) return -1;
    gLastResult = FMOD_Sound_GetSyncPointInfo(sound, point, NULL, 0, &offset, FMOD_TIMEUNIT_MS);
    return gLastResult == FMOD_OK ? (int)offset : -1;
}
DEFINE_PRIM(_I32, sound_get_sync_point_offset, _I32 _I32);

//// Sound groups

static FMOD_SOUNDGROUP* resolve_soundgroup(int h) {
    return (FMOD_SOUNDGROUP*)faxe_handle_resolve(h, FAXE_TYPE_SOUNDGROUP);
}

HL_PRIM int HL_NAME(sys_create_sound_group)(vbyte* name) {
    FMOD_SOUNDGROUP* group = NULL;
    int handle;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    gLastResult = FMOD_System_CreateSoundGroup(gCoreSystem, (const char*)name, &group);
    if (gLastResult != FMOD_OK || !group) return 0;
    handle = faxe_handle_alloc(group, FAXE_TYPE_SOUNDGROUP);
    if (handle == 0) {
        gLastResult = FMOD_ERR_MEMORY; /* handle table exhausted */
        FMOD_SoundGroup_Release(group);
        return 0;
    }
    return handle;
}
DEFINE_PRIM(_I32, sys_create_sound_group, _BYTES);

HL_PRIM int HL_NAME(sys_get_master_sound_group)() {
    FMOD_SOUNDGROUP* group = NULL;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    gLastResult = FMOD_System_GetMasterSoundGroup(gCoreSystem, &group);
    if (gLastResult != FMOD_OK || !group) return 0;
    return faxe_handle_find_or_alloc(group, FAXE_TYPE_SOUNDGROUP);
}
DEFINE_PRIM(_I32, sys_get_master_sound_group, _NO_ARG);

HL_PRIM int HL_NAME(sg_release)(int h) {
    FMOD_SOUNDGROUP* group = resolve_soundgroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_SoundGroup_Release(group);
    if (gLastResult == FMOD_OK) faxe_handle_free(h);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sg_release, _I32);

HL_PRIM int HL_NAME(sg_set_max_audible)(int h, int maxAudible) {
    FMOD_SOUNDGROUP* group = resolve_soundgroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_SoundGroup_SetMaxAudible(group, maxAudible);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sg_set_max_audible, _I32 _I32);

HL_PRIM int HL_NAME(sg_get_max_audible)(int h) {
    FMOD_SOUNDGROUP* group = resolve_soundgroup(h);
    int maxAudible = 0;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_SoundGroup_GetMaxAudible(group, &maxAudible);
    return maxAudible;
}
DEFINE_PRIM(_I32, sg_get_max_audible, _I32);

HL_PRIM int HL_NAME(sg_set_max_audible_behavior)(int h, int behavior) {
    FMOD_SOUNDGROUP* group = resolve_soundgroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_SoundGroup_SetMaxAudibleBehavior(group, (FMOD_SOUNDGROUP_BEHAVIOR)behavior);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sg_set_max_audible_behavior, _I32 _I32);

HL_PRIM int HL_NAME(sg_get_max_audible_behavior)(int h) {
    FMOD_SOUNDGROUP* group = resolve_soundgroup(h);
    FMOD_SOUNDGROUP_BEHAVIOR behavior = FMOD_SOUNDGROUP_BEHAVIOR_FAIL;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_SoundGroup_GetMaxAudibleBehavior(group, &behavior);
    return (int)behavior;
}
DEFINE_PRIM(_I32, sg_get_max_audible_behavior, _I32);

HL_PRIM int HL_NAME(sg_set_mute_fade_speed)(int h, double speed) {
    FMOD_SOUNDGROUP* group = resolve_soundgroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_SoundGroup_SetMuteFadeSpeed(group, (float)speed);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sg_set_mute_fade_speed, _I32 _F64);

HL_PRIM int HL_NAME(sg_get_num_sounds)(int h) {
    FMOD_SOUNDGROUP* group = resolve_soundgroup(h);
    int count = 0;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_SoundGroup_GetNumSounds(group, &count);
    return count;
}
DEFINE_PRIM(_I32, sg_get_num_sounds, _I32);

HL_PRIM int HL_NAME(sg_stop)(int h) {
    FMOD_SOUNDGROUP* group = resolve_soundgroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_SoundGroup_Stop(group);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sg_stop, _I32);

HL_PRIM int HL_NAME(sound_set_sound_group)(int h, int groupHandle) {
    FMOD_SOUND* sound = resolve_core_sound(h);
    FMOD_SOUNDGROUP* group = resolve_soundgroup(groupHandle);
    if (!sound || !group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Sound_SetSoundGroup(sound, group);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sound_set_sound_group, _I32 _I32);

//// System 3D settings and drivers

HL_PRIM int HL_NAME(sys_set_3d_settings)(double doppler, double distanceFactor, double rolloffScale) {
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = FMOD_System_Set3DSettings(gCoreSystem, (float)doppler,
        (float)distanceFactor, (float)rolloffScale);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_set_3d_settings, _F64 _F64 _F64);

// out = double[3]: doppler, distance factor, rolloff scale
HL_PRIM int HL_NAME(sys_get_3d_settings)(vbyte* out) {
    float doppler = 0.0f;
    float distanceFactor = 0.0f;
    float rolloffScale = 0.0f;
    double* outFloats = (double*)out;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = FMOD_System_Get3DSettings(gCoreSystem, &doppler, &distanceFactor, &rolloffScale);
    outFloats[0] = (double)doppler;
    outFloats[1] = (double)distanceFactor;
    outFloats[2] = (double)rolloffScale;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_get_3d_settings, _BYTES);

HL_PRIM int HL_NAME(sys_get_num_drivers)() {
    int count = 0;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    gLastResult = FMOD_System_GetNumDrivers(gCoreSystem, &count);
    return count;
}
DEFINE_PRIM(_I32, sys_get_num_drivers, _NO_ARG);

HL_PRIM vbyte* HL_NAME(sys_get_driver_name)(int id) {
    gStringBuf[0] = '\0';
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (vbyte*)gStringBuf; }
    gLastResult = FMOD_System_GetDriverInfo(gCoreSystem, id, gStringBuf, sizeof(gStringBuf),
        NULL, NULL, NULL, NULL);
    if (gLastResult != FMOD_OK) gStringBuf[0] = '\0';
    return (vbyte*)gStringBuf;
}
DEFINE_PRIM(_BYTES, sys_get_driver_name, _I32);

//// Getter symmetry for the routing and spatial setters

HL_PRIM int HL_NAME(chan_get_loop_count)(int h) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    int loopCount = 0;
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_Channel_GetLoopCount(channel, &loopCount);
    return loopCount;
}
DEFINE_PRIM(_I32, chan_get_loop_count, _I32);

HL_PRIM double HL_NAME(chan_get_low_pass_gain)(int h) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    float gain = 0.0f;
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    gLastResult = FMOD_Channel_GetLowPassGain(channel, &gain);
    return (double)gain;
}
DEFINE_PRIM(_F64, chan_get_low_pass_gain, _I32);

HL_PRIM int HL_NAME(chan_get_mode)(int h) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    FMOD_MODE mode = 0;
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_Channel_GetMode(channel, &mode);
    return (int)mode;
}
DEFINE_PRIM(_I32, chan_get_mode, _I32);

// out = double[3]: inside angle, outside angle, outside volume
HL_PRIM int HL_NAME(chan_get_3d_cone_settings)(int h, vbyte* out) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    float inside = 0.0f;
    float outside = 0.0f;
    float volume = 0.0f;
    double* outFloats = (double*)out;
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Channel_Get3DConeSettings(channel, &inside, &outside, &volume);
    outFloats[0] = (double)inside;
    outFloats[1] = (double)outside;
    outFloats[2] = (double)volume;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_get_3d_cone_settings, _I32 _BYTES);

HL_PRIM double HL_NAME(chan_get_3d_spread)(int h) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    float angle = 0.0f;
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    gLastResult = FMOD_Channel_Get3DSpread(channel, &angle);
    return (double)angle;
}
DEFINE_PRIM(_F64, chan_get_3d_spread, _I32);

HL_PRIM double HL_NAME(chan_get_3d_level)(int h) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    float level = 0.0f;
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    gLastResult = FMOD_Channel_Get3DLevel(channel, &level);
    return (double)level;
}
DEFINE_PRIM(_F64, chan_get_3d_level, _I32);

HL_PRIM double HL_NAME(chan_get_3d_doppler_level)(int h) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    float level = 0.0f;
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    gLastResult = FMOD_Channel_Get3DDopplerLevel(channel, &level);
    return (double)level;
}
DEFINE_PRIM(_F64, chan_get_3d_doppler_level, _I32);

// out = double[2]: min, max
HL_PRIM int HL_NAME(chan_get_3d_min_max)(int h, vbyte* out) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    float minDist = 0.0f;
    float maxDist = 0.0f;
    double* outFloats = (double*)out;
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Channel_Get3DMinMaxDistance(channel, &minDist, &maxDist);
    outFloats[0] = (double)minDist;
    outFloats[1] = (double)maxDist;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_get_3d_min_max, _I32 _BYTES);

// out = double[6]: position xyz, velocity xyz
HL_PRIM int HL_NAME(chan_get_3d_attributes)(int h, vbyte* out) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    FMOD_VECTOR position;
    FMOD_VECTOR velocity;
    double* outFloats = (double*)out;
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    memset(&position, 0, sizeof(position));
    memset(&velocity, 0, sizeof(velocity));
    gLastResult = FMOD_Channel_Get3DAttributes(channel, &position, &velocity);
    outFloats[0] = (double)position.x;
    outFloats[1] = (double)position.y;
    outFloats[2] = (double)position.z;
    outFloats[3] = (double)velocity.x;
    outFloats[4] = (double)velocity.y;
    outFloats[5] = (double)velocity.z;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_get_3d_attributes, _I32 _BYTES);

// out = double[3]: start clock, end clock, stop channels (0/1)
HL_PRIM int HL_NAME(chan_get_delay)(int h, vbyte* out) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    unsigned long long startClock = 0;
    unsigned long long endClock = 0;
    FMOD_BOOL stopChannels = 0;
    double* outFloats = (double*)out;
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Channel_GetDelay(channel, &startClock, &endClock, &stopChannels);
    outFloats[0] = (double)startClock;
    outFloats[1] = (double)endClock;
    outFloats[2] = stopChannels ? 1.0 : 0.0;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_get_delay, _I32 _BYTES);

// out = double[3]: prewet, postwet, dry
HL_PRIM int HL_NAME(dsp_get_wet_dry_mix)(int h, vbyte* out) {
    FMOD_DSP* dsp = resolve_dsp(h);
    float prewet = 0.0f;
    float postwet = 0.0f;
    float dry = 0.0f;
    double* outFloats = (double*)out;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_DSP_GetWetDryMix(dsp, &prewet, &postwet, &dry);
    outFloats[0] = (double)prewet;
    outFloats[1] = (double)postwet;
    outFloats[2] = (double)dry;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, dsp_get_wet_dry_mix, _I32 _BYTES);

HL_PRIM bool HL_NAME(dsp_get_active)(int h) {
    FMOD_DSP* dsp = resolve_dsp(h);
    FMOD_BOOL active = 0;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    gLastResult = FMOD_DSP_GetActive(dsp, &active);
    return active ? true : false;
}
DEFINE_PRIM(_BOOL, dsp_get_active, _I32);

// out = int[2]: input enabled, output enabled
HL_PRIM int HL_NAME(dsp_get_metering_enabled)(int h, vbyte* out) {
    FMOD_DSP* dsp = resolve_dsp(h);
    FMOD_BOOL inputEnabled = 0;
    FMOD_BOOL outputEnabled = 0;
    int* outInts = (int*)out;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_DSP_GetMeteringEnabled(dsp, &inputEnabled, &outputEnabled);
    outInts[0] = inputEnabled ? 1 : 0;
    outInts[1] = outputEnabled ? 1 : 0;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, dsp_get_metering_enabled, _I32 _BYTES);

//// Bank loading from memory

HL_PRIM int HL_NAME(sys_load_bank_memory)(vbyte* data, int len) {
    FMOD_STUDIO_BANK* bank = NULL;
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    if (!data || len <= 0) { gLastResult = FMOD_ERR_INVALID_PARAM; return 0; }
    gLastResult = FMOD_Studio_System_LoadBankMemory(gStudioSystem, (const char*)data, len,
        FMOD_STUDIO_LOAD_MEMORY, FMOD_STUDIO_LOAD_BANK_NORMAL, &bank);
    if (gLastResult != FMOD_OK || !bank) return 0;
    return faxe_handle_find_or_alloc(bank, FAXE_TYPE_BANK);
}
DEFINE_PRIM(_I32, sys_load_bank_memory, _BYTES _I32);

//// Event instance core bridge

HL_PRIM int HL_NAME(evi_get_channel_group)(int h) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    FMOD_CHANNELGROUP* group = NULL;
    FaxeInstCtx* ctx;
    int cgHandle;
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_Studio_EventInstance_GetChannelGroup(instance, &group);
    if (gLastResult != FMOD_OK || !group) return 0;
    cgHandle = faxe_handle_find_or_alloc(group, FAXE_TYPE_CHANGROUP);
    /* The group dies with the instance, outside every sweep trigger. Record
     * the handle on the context so the DESTROYED drain reclaims the slot
     * before a recycled group address can alias it. A restarted instance
     * gets a new group, so a differing previous handle is dead: reclaim it
     * here for the same reason. */
    ctx = instance_ctx(instance);
    if (ctx) {
        if (ctx->cgHandle != 0 && ctx->cgHandle != cgHandle) {
            faxe_handle_free(ctx->cgHandle);
        }
        ctx->cgHandle = cgHandle;
    }
    return cgHandle;
}
DEFINE_PRIM(_I32, evi_get_channel_group, _I32);

//// Command capture and replay

static FMOD_STUDIO_COMMANDREPLAY* resolve_replay(int h) {
    return (FMOD_STUDIO_COMMANDREPLAY*)faxe_handle_resolve(h, FAXE_TYPE_REPLAY);
}

HL_PRIM int HL_NAME(sys_start_command_capture)(vbyte* path) {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = FMOD_Studio_System_StartCommandCapture(gStudioSystem, (const char*)path,
        FMOD_STUDIO_COMMANDCAPTURE_NORMAL);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_start_command_capture, _BYTES);

HL_PRIM int HL_NAME(sys_stop_command_capture)() {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = FMOD_Studio_System_StopCommandCapture(gStudioSystem);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_stop_command_capture, _NO_ARG);

HL_PRIM int HL_NAME(sys_load_command_replay)(vbyte* path) {
    FMOD_STUDIO_COMMANDREPLAY* replay = NULL;
    int handle;
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    gLastResult = FMOD_Studio_System_LoadCommandReplay(gStudioSystem, (const char*)path,
        FMOD_STUDIO_COMMANDREPLAY_NORMAL, &replay);
    if (gLastResult != FMOD_OK || !replay) return 0;
    handle = faxe_handle_alloc(replay, FAXE_TYPE_REPLAY);
    if (handle == 0) {
        gLastResult = FMOD_ERR_MEMORY; /* handle table exhausted */
        FMOD_Studio_CommandReplay_Release(replay);
        return 0;
    }
    return handle;
}
DEFINE_PRIM(_I32, sys_load_command_replay, _BYTES);

HL_PRIM int HL_NAME(replay_release)(int h) {
    FMOD_STUDIO_COMMANDREPLAY* replay = resolve_replay(h);
    if (!replay) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Studio_CommandReplay_Release(replay);
    if (gLastResult == FMOD_OK) faxe_handle_free(h);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, replay_release, _I32);

HL_PRIM bool HL_NAME(replay_is_valid)(int h) {
    FMOD_STUDIO_COMMANDREPLAY* replay = resolve_replay(h);
    return replay != NULL && FMOD_Studio_CommandReplay_IsValid(replay);
}
DEFINE_PRIM(_BOOL, replay_is_valid, _I32);

HL_PRIM int HL_NAME(replay_start)(int h) {
    FMOD_STUDIO_COMMANDREPLAY* replay = resolve_replay(h);
    if (!replay) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Studio_CommandReplay_Start(replay);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, replay_start, _I32);

HL_PRIM int HL_NAME(replay_stop)(int h) {
    FMOD_STUDIO_COMMANDREPLAY* replay = resolve_replay(h);
    if (!replay) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Studio_CommandReplay_Stop(replay);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, replay_stop, _I32);

HL_PRIM int HL_NAME(replay_set_paused)(int h, bool paused) {
    FMOD_STUDIO_COMMANDREPLAY* replay = resolve_replay(h);
    if (!replay) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Studio_CommandReplay_SetPaused(replay, paused ? 1 : 0);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, replay_set_paused, _I32 _BOOL);

HL_PRIM bool HL_NAME(replay_get_paused)(int h) {
    FMOD_STUDIO_COMMANDREPLAY* replay = resolve_replay(h);
    FMOD_BOOL paused = 0;
    if (!replay) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    gLastResult = FMOD_Studio_CommandReplay_GetPaused(replay, &paused);
    return paused ? true : false;
}
DEFINE_PRIM(_BOOL, replay_get_paused, _I32);

HL_PRIM int HL_NAME(replay_seek_to_time)(int h, int timeMs) {
    FMOD_STUDIO_COMMANDREPLAY* replay = resolve_replay(h);
    if (!replay) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Studio_CommandReplay_SeekToTime(replay, (float)timeMs / 1000.0f);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, replay_seek_to_time, _I32 _I32);

HL_PRIM double HL_NAME(replay_get_length)(int h) {
    FMOD_STUDIO_COMMANDREPLAY* replay = resolve_replay(h);
    float length = 0.0f;
    if (!replay) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    gLastResult = FMOD_Studio_CommandReplay_GetLength(replay, &length);
    return (double)length;
}
DEFINE_PRIM(_F64, replay_get_length, _I32);

//// Channel priority, virtualization, and remaining getters

HL_PRIM int HL_NAME(chan_set_priority)(int h, int priority) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Channel_SetPriority(channel, priority);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_set_priority, _I32 _I32);

HL_PRIM int HL_NAME(chan_get_priority)(int h) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    int priority = 0;
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_Channel_GetPriority(channel, &priority);
    return priority;
}
DEFINE_PRIM(_I32, chan_get_priority, _I32);

HL_PRIM bool HL_NAME(chan_is_virtual)(int h) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    FMOD_BOOL isVirtual = 0;
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    gLastResult = FMOD_Channel_IsVirtual(channel, &isVirtual);
    return isVirtual ? true : false;
}
DEFINE_PRIM(_BOOL, chan_is_virtual, _I32);

HL_PRIM double HL_NAME(chan_get_audibility)(int h) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    float audibility = 0.0f;
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    gLastResult = FMOD_Channel_GetAudibility(channel, &audibility);
    return (double)audibility;
}
DEFINE_PRIM(_F64, chan_get_audibility, _I32);

HL_PRIM int HL_NAME(chan_set_volume_ramp)(int h, bool ramp) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Channel_SetVolumeRamp(channel, ramp ? 1 : 0);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_set_volume_ramp, _I32 _BOOL);

HL_PRIM bool HL_NAME(chan_get_volume_ramp)(int h) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    FMOD_BOOL ramp = 0;
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    gLastResult = FMOD_Channel_GetVolumeRamp(channel, &ramp);
    return ramp ? true : false;
}
DEFINE_PRIM(_BOOL, chan_get_volume_ramp, _I32);

// The returned handle is a borrowed reference: do not release a sound
// obtained this way
HL_PRIM int HL_NAME(chan_get_current_sound)(int h) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    FMOD_SOUND* sound = NULL;
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_Channel_GetCurrentSound(channel, &sound);
    if (gLastResult != FMOD_OK || !sound) return 0;
    return faxe_handle_find_or_alloc(sound, FAXE_TYPE_SOUND);
}
DEFINE_PRIM(_I32, chan_get_current_sound, _I32);

HL_PRIM int HL_NAME(chan_set_loop_points)(int h, int startMs, int endMs) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Channel_SetLoopPoints(channel, (unsigned int)startMs, FMOD_TIMEUNIT_MS,
        (unsigned int)endMs, FMOD_TIMEUNIT_MS);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_set_loop_points, _I32 _I32 _I32);

// out = int[2]: loop start ms, loop end ms
HL_PRIM int HL_NAME(chan_get_loop_points)(int h, vbyte* out) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    unsigned int start = 0;
    unsigned int end = 0;
    int* outInts = (int*)out;
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Channel_GetLoopPoints(channel, &start, FMOD_TIMEUNIT_MS, &end, FMOD_TIMEUNIT_MS);
    outInts[0] = (int)start;
    outInts[1] = (int)end;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_get_loop_points, _I32 _BYTES);

HL_PRIM double HL_NAME(chan_get_reverb_wet)(int h, int instance) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    float wet = 0.0f;
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    gLastResult = FMOD_Channel_GetReverbProperties(channel, instance, &wet);
    return (double)wet;
}
DEFINE_PRIM(_F64, chan_get_reverb_wet, _I32 _I32);

HL_PRIM int HL_NAME(chan_get_index)(int h) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    int index = -1;
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return -1; }
    gLastResult = FMOD_Channel_GetIndex(channel, &index);
    return gLastResult == FMOD_OK ? index : -1;
}
DEFINE_PRIM(_I32, chan_get_index, _I32);

// out = double[3]: direction xyz
HL_PRIM int HL_NAME(chan_get_3d_cone_orientation)(int h, vbyte* out) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    FMOD_VECTOR direction;
    double* outFloats = (double*)out;
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    memset(&direction, 0, sizeof(direction));
    gLastResult = FMOD_Channel_Get3DConeOrientation(channel, &direction);
    outFloats[0] = (double)direction.x;
    outFloats[1] = (double)direction.y;
    outFloats[2] = (double)direction.z;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_get_3d_cone_orientation, _I32 _BYTES);

HL_PRIM int HL_NAME(chan_get_num_dsps)(int h) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    int count = 0;
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_Channel_GetNumDSPs(channel, &count);
    return count;
}
DEFINE_PRIM(_I32, chan_get_num_dsps, _I32);

HL_PRIM int HL_NAME(chan_get_dsp)(int h, int index) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    FMOD_DSP* dsp = NULL;
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_Channel_GetDSP(channel, index, &dsp);
    if (gLastResult != FMOD_OK || !dsp) return 0;
    return faxe_handle_find_or_alloc(dsp, FAXE_TYPE_DSP);
}
DEFINE_PRIM(_I32, chan_get_dsp, _I32 _I32);

//// Sound name, group getter, and loop count

HL_PRIM vbyte* HL_NAME(sound_get_name)(int h) {
    FMOD_SOUND* sound = resolve_core_sound(h);
    gStringBuf[0] = '\0';
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (vbyte*)gStringBuf; }
    gLastResult = FMOD_Sound_GetName(sound, gStringBuf, sizeof(gStringBuf));
    if (gLastResult != FMOD_OK) gStringBuf[0] = '\0';
    return (vbyte*)gStringBuf;
}
DEFINE_PRIM(_BYTES, sound_get_name, _I32);

HL_PRIM int HL_NAME(sound_get_sound_group)(int h) {
    FMOD_SOUND* sound = resolve_core_sound(h);
    FMOD_SOUNDGROUP* group = NULL;
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_Sound_GetSoundGroup(sound, &group);
    if (gLastResult != FMOD_OK || !group) return 0;
    return faxe_handle_find_or_alloc(group, FAXE_TYPE_SOUNDGROUP);
}
DEFINE_PRIM(_I32, sound_get_sound_group, _I32);

HL_PRIM int HL_NAME(sound_get_loop_count)(int h) {
    FMOD_SOUND* sound = resolve_core_sound(h);
    int loopCount = 0;
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_Sound_GetLoopCount(sound, &loopCount);
    return loopCount;
}
DEFINE_PRIM(_I32, sound_get_loop_count, _I32);

HL_PRIM int HL_NAME(sound_set_loop_count)(int h, int loopCount) {
    FMOD_SOUND* sound = resolve_core_sound(h);
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Sound_SetLoopCount(sound, loopCount);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sound_set_loop_count, _I32 _I32);

//// Sound group volume and counters

HL_PRIM int HL_NAME(sg_set_volume)(int h, double volume) {
    FMOD_SOUNDGROUP* group = resolve_soundgroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_SoundGroup_SetVolume(group, (float)volume);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sg_set_volume, _I32 _F64);

HL_PRIM double HL_NAME(sg_get_volume)(int h) {
    FMOD_SOUNDGROUP* group = resolve_soundgroup(h);
    float volume = 0.0f;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    gLastResult = FMOD_SoundGroup_GetVolume(group, &volume);
    return (double)volume;
}
DEFINE_PRIM(_F64, sg_get_volume, _I32);

HL_PRIM int HL_NAME(sg_get_num_playing)(int h) {
    FMOD_SOUNDGROUP* group = resolve_soundgroup(h);
    int count = 0;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_SoundGroup_GetNumPlaying(group, &count);
    return count;
}
DEFINE_PRIM(_I32, sg_get_num_playing, _I32);

HL_PRIM double HL_NAME(sg_get_mute_fade_speed)(int h) {
    FMOD_SOUNDGROUP* group = resolve_soundgroup(h);
    float speed = 0.0f;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    gLastResult = FMOD_SoundGroup_GetMuteFadeSpeed(group, &speed);
    return (double)speed;
}
DEFINE_PRIM(_F64, sg_get_mute_fade_speed, _I32);

//// Output device selection

HL_PRIM int HL_NAME(sys_set_driver)(int driver) {
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = FMOD_System_SetDriver(gCoreSystem, driver);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_set_driver, _I32);

HL_PRIM int HL_NAME(sys_get_driver)() {
    int driver = 0;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    gLastResult = FMOD_System_GetDriver(gCoreSystem, &driver);
    return driver;
}
DEFINE_PRIM(_I32, sys_get_driver, _NO_ARG);

//// DSP data params, info, and output traversal

HL_PRIM int HL_NAME(dsp_set_param_data)(int h, int index, vbyte* data, int len) {
    FMOD_DSP* dsp = resolve_dsp(h);
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    if (!data || len <= 0) { gLastResult = FMOD_ERR_INVALID_PARAM; return (int)gLastResult; }
    gLastResult = FMOD_DSP_SetParameterData(dsp, index, data, (unsigned int)len);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, dsp_set_param_data, _I32 _I32 _BYTES _I32);

HL_PRIM bool HL_NAME(dsp_get_idle)(int h) {
    FMOD_DSP* dsp = resolve_dsp(h);
    FMOD_BOOL idle = 0;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    gLastResult = FMOD_DSP_GetIdle(dsp, &idle);
    return idle ? true : false;
}
DEFINE_PRIM(_BOOL, dsp_get_idle, _I32);

HL_PRIM vbyte* HL_NAME(dsp_get_info_name)(int h) {
    FMOD_DSP* dsp = resolve_dsp(h);
    gStringBuf[0] = '\0';
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (vbyte*)gStringBuf; }
    gLastResult = FMOD_DSP_GetInfo(dsp, gStringBuf, NULL, NULL, NULL, NULL);
    if (gLastResult != FMOD_OK) gStringBuf[0] = '\0';
    return (vbyte*)gStringBuf;
}
DEFINE_PRIM(_BYTES, dsp_get_info_name, _I32);

HL_PRIM int HL_NAME(dsp_get_output_dsp)(int h, int index) {
    FMOD_DSP* dsp = resolve_dsp(h);
    FMOD_DSP* output = NULL;
    FMOD_DSPCONNECTION* conn = NULL;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_DSP_GetOutput(dsp, index, &output, &conn);
    if (gLastResult != FMOD_OK || !output) return 0;
    return faxe_handle_find_or_alloc(output, FAXE_TYPE_DSP);
}
DEFINE_PRIM(_I32, dsp_get_output_dsp, _I32 _I32);

HL_PRIM int HL_NAME(dsp_get_output_connection)(int h, int index) {
    FMOD_DSP* dsp = resolve_dsp(h);
    FMOD_DSP* output = NULL;
    FMOD_DSPCONNECTION* conn = NULL;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_DSP_GetOutput(dsp, index, &output, &conn);
    if (gLastResult != FMOD_OK || !conn) return 0;
    return faxe_handle_find_or_alloc(conn, FAXE_TYPE_DSPCONN);
}
DEFINE_PRIM(_I32, dsp_get_output_connection, _I32 _I32);

HL_PRIM int HL_NAME(dspconn_get_input_dsp)(int h) {
    FMOD_DSPCONNECTION* conn = resolve_dspconn(h);
    FMOD_DSP* dsp = NULL;
    if (!conn) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_DSPConnection_GetInput(conn, &dsp);
    if (gLastResult != FMOD_OK || !dsp) return 0;
    return faxe_handle_find_or_alloc(dsp, FAXE_TYPE_DSP);
}
DEFINE_PRIM(_I32, dspconn_get_input_dsp, _I32);

HL_PRIM int HL_NAME(dspconn_get_output_dsp)(int h) {
    FMOD_DSPCONNECTION* conn = resolve_dspconn(h);
    FMOD_DSP* dsp = NULL;
    if (!conn) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_DSPConnection_GetOutput(conn, &dsp);
    if (gLastResult != FMOD_OK || !dsp) return 0;
    return faxe_handle_find_or_alloc(dsp, FAXE_TYPE_DSP);
}
DEFINE_PRIM(_I32, dspconn_get_output_dsp, _I32);

//// Reverb3D getters

HL_PRIM bool HL_NAME(r3d_get_active)(int h) {
    FMOD_REVERB3D* reverb = resolve_reverb3d(h);
    FMOD_BOOL active = 0;
    if (!reverb) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    gLastResult = FMOD_Reverb3D_GetActive(reverb, &active);
    return active ? true : false;
}
DEFINE_PRIM(_BOOL, r3d_get_active, _I32);

// out = double[5]: position xyz, min distance, max distance
HL_PRIM int HL_NAME(r3d_get_3d_attributes)(int h, vbyte* out) {
    FMOD_REVERB3D* reverb = resolve_reverb3d(h);
    FMOD_VECTOR position;
    float minDist = 0.0f;
    float maxDist = 0.0f;
    double* outFloats = (double*)out;
    if (!reverb) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    memset(&position, 0, sizeof(position));
    gLastResult = FMOD_Reverb3D_Get3DAttributes(reverb, &position, &minDist, &maxDist);
    outFloats[0] = (double)position.x;
    outFloats[1] = (double)position.y;
    outFloats[2] = (double)position.z;
    outFloats[3] = (double)minDist;
    outFloats[4] = (double)maxDist;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, r3d_get_3d_attributes, _I32 _BYTES);

//// Channel group spatial mirror and remaining control surface

HL_PRIM int HL_NAME(cg_set_pan)(int h, double pan) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_ChannelGroup_SetPan(group, (float)pan);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, cg_set_pan, _I32 _F64);

HL_PRIM int HL_NAME(cg_set_low_pass_gain)(int h, double gain) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_ChannelGroup_SetLowPassGain(group, (float)gain);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, cg_set_low_pass_gain, _I32 _F64);

HL_PRIM int HL_NAME(cg_set_mode)(int h, int mode) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_ChannelGroup_SetMode(group, (FMOD_MODE)mode);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, cg_set_mode, _I32 _I32);

HL_PRIM int HL_NAME(cg_get_mode)(int h) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    FMOD_MODE mode = 0;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_ChannelGroup_GetMode(group, &mode);
    return (int)mode;
}
DEFINE_PRIM(_I32, cg_get_mode, _I32);

HL_PRIM int HL_NAME(cg_set_3d_attributes)(int h, double posX, double posY, double posZ, double velX, double velY, double velZ) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    FMOD_VECTOR position;
    FMOD_VECTOR velocity;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    position.x = (float)posX; position.y = (float)posY; position.z = (float)posZ;
    velocity.x = (float)velX; velocity.y = (float)velY; velocity.z = (float)velZ;
    gLastResult = FMOD_ChannelGroup_Set3DAttributes(group, &position, &velocity);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, cg_set_3d_attributes, _I32 _F64 _F64 _F64 _F64 _F64 _F64);

// out = double[6]: position xyz, velocity xyz
HL_PRIM int HL_NAME(cg_get_3d_attributes)(int h, vbyte* out) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    FMOD_VECTOR position;
    FMOD_VECTOR velocity;
    double* outFloats = (double*)out;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    memset(&position, 0, sizeof(position));
    memset(&velocity, 0, sizeof(velocity));
    gLastResult = FMOD_ChannelGroup_Get3DAttributes(group, &position, &velocity);
    outFloats[0] = (double)position.x;
    outFloats[1] = (double)position.y;
    outFloats[2] = (double)position.z;
    outFloats[3] = (double)velocity.x;
    outFloats[4] = (double)velocity.y;
    outFloats[5] = (double)velocity.z;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, cg_get_3d_attributes, _I32 _BYTES);

HL_PRIM int HL_NAME(cg_set_3d_min_max)(int h, double minDist, double maxDist) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_ChannelGroup_Set3DMinMaxDistance(group, (float)minDist, (float)maxDist);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, cg_set_3d_min_max, _I32 _F64 _F64);

// out = double[2]: min, max
HL_PRIM int HL_NAME(cg_get_3d_min_max)(int h, vbyte* out) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    float minDist = 0.0f;
    float maxDist = 0.0f;
    double* outFloats = (double*)out;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_ChannelGroup_Get3DMinMaxDistance(group, &minDist, &maxDist);
    outFloats[0] = (double)minDist;
    outFloats[1] = (double)maxDist;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, cg_get_3d_min_max, _I32 _BYTES);

HL_PRIM int HL_NAME(cg_set_3d_occlusion)(int h, double direct, double reverb) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_ChannelGroup_Set3DOcclusion(group, (float)direct, (float)reverb);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, cg_set_3d_occlusion, _I32 _F64 _F64);

HL_PRIM int HL_NAME(cg_set_3d_level)(int h, double level) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_ChannelGroup_Set3DLevel(group, (float)level);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, cg_set_3d_level, _I32 _F64);

HL_PRIM double HL_NAME(cg_get_3d_level)(int h) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    float level = 0.0f;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    gLastResult = FMOD_ChannelGroup_Get3DLevel(group, &level);
    return (double)level;
}
DEFINE_PRIM(_F64, cg_get_3d_level, _I32);

HL_PRIM int HL_NAME(cg_set_3d_spread)(int h, double angle) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_ChannelGroup_Set3DSpread(group, (float)angle);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, cg_set_3d_spread, _I32 _F64);

HL_PRIM double HL_NAME(cg_get_3d_spread)(int h) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    float angle = 0.0f;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    gLastResult = FMOD_ChannelGroup_Get3DSpread(group, &angle);
    return (double)angle;
}
DEFINE_PRIM(_F64, cg_get_3d_spread, _I32);

HL_PRIM int HL_NAME(cg_set_3d_doppler_level)(int h, double level) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_ChannelGroup_Set3DDopplerLevel(group, (float)level);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, cg_set_3d_doppler_level, _I32 _F64);

HL_PRIM double HL_NAME(cg_get_3d_doppler_level)(int h) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    float level = 0.0f;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    gLastResult = FMOD_ChannelGroup_Get3DDopplerLevel(group, &level);
    return (double)level;
}
DEFINE_PRIM(_F64, cg_get_3d_doppler_level, _I32);

HL_PRIM int HL_NAME(cg_set_3d_cone_settings)(int h, double insideAngle, double outsideAngle, double outsideVolume) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_ChannelGroup_Set3DConeSettings(group, (float)insideAngle,
        (float)outsideAngle, (float)outsideVolume);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, cg_set_3d_cone_settings, _I32 _F64 _F64 _F64);

// out = double[3]: inside angle, outside angle, outside volume
HL_PRIM int HL_NAME(cg_get_3d_cone_settings)(int h, vbyte* out) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    float inside = 0.0f;
    float outside = 0.0f;
    float volume = 0.0f;
    double* outFloats = (double*)out;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_ChannelGroup_Get3DConeSettings(group, &inside, &outside, &volume);
    outFloats[0] = (double)inside;
    outFloats[1] = (double)outside;
    outFloats[2] = (double)volume;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, cg_get_3d_cone_settings, _I32 _BYTES);

HL_PRIM int HL_NAME(cg_set_3d_cone_orientation)(int h, double x, double y, double z) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    FMOD_VECTOR direction;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    direction.x = (float)x; direction.y = (float)y; direction.z = (float)z;
    gLastResult = FMOD_ChannelGroup_Set3DConeOrientation(group, &direction);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, cg_set_3d_cone_orientation, _I32 _F64 _F64 _F64);

// out = double[3]: direction xyz
HL_PRIM int HL_NAME(cg_get_3d_cone_orientation)(int h, vbyte* out) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    FMOD_VECTOR direction;
    double* outFloats = (double*)out;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    memset(&direction, 0, sizeof(direction));
    gLastResult = FMOD_ChannelGroup_Get3DConeOrientation(group, &direction);
    outFloats[0] = (double)direction.x;
    outFloats[1] = (double)direction.y;
    outFloats[2] = (double)direction.z;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, cg_get_3d_cone_orientation, _I32 _BYTES);

HL_PRIM int HL_NAME(cg_set_reverb_wet)(int h, int instance, double wet) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_ChannelGroup_SetReverbProperties(group, instance, (float)wet);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, cg_set_reverb_wet, _I32 _I32 _F64);

HL_PRIM double HL_NAME(cg_get_reverb_wet)(int h, int instance) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    float wet = 0.0f;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    gLastResult = FMOD_ChannelGroup_GetReverbProperties(group, instance, &wet);
    return (double)wet;
}
DEFINE_PRIM(_F64, cg_get_reverb_wet, _I32 _I32);

// in = double[outChannels*inChannels] row-major gains
HL_PRIM int HL_NAME(cg_set_mix_matrix)(int h, vbyte* in, int outChannels, int inChannels) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    double* inFloats = (double*)in;
    float matrix[32 * 32];
    int i;
    int total = outChannels * inChannels;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    if (total < 0 || total > 32 * 32) { gLastResult = FMOD_ERR_INVALID_PARAM; return (int)gLastResult; }
    for (i = 0; i < total; i++) matrix[i] = (float)inFloats[i];
    gLastResult = FMOD_ChannelGroup_SetMixMatrix(group, matrix, outChannels, inChannels, 0);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, cg_set_mix_matrix, _I32 _BYTES _I32 _I32);

HL_PRIM int HL_NAME(cg_set_volume_ramp)(int h, bool ramp) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_ChannelGroup_SetVolumeRamp(group, ramp ? 1 : 0);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, cg_set_volume_ramp, _I32 _BOOL);

HL_PRIM bool HL_NAME(cg_get_volume_ramp)(int h) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    FMOD_BOOL ramp = 0;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    gLastResult = FMOD_ChannelGroup_GetVolumeRamp(group, &ramp);
    return ramp ? true : false;
}
DEFINE_PRIM(_BOOL, cg_get_volume_ramp, _I32);

HL_PRIM double HL_NAME(cg_get_audibility)(int h) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    float audibility = 0.0f;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    gLastResult = FMOD_ChannelGroup_GetAudibility(group, &audibility);
    return (double)audibility;
}
DEFINE_PRIM(_F64, cg_get_audibility, _I32);

HL_PRIM vbyte* HL_NAME(cg_get_name)(int h) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    gStringBuf[0] = '\0';
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (vbyte*)gStringBuf; }
    gLastResult = FMOD_ChannelGroup_GetName(group, gStringBuf, sizeof(gStringBuf));
    if (gLastResult != FMOD_OK) gStringBuf[0] = '\0';
    return (vbyte*)gStringBuf;
}
DEFINE_PRIM(_BYTES, cg_get_name, _I32);

HL_PRIM int HL_NAME(cg_get_num_channels)(int h) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    int count = 0;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_ChannelGroup_GetNumChannels(group, &count);
    return count;
}
DEFINE_PRIM(_I32, cg_get_num_channels, _I32);

HL_PRIM int HL_NAME(cg_get_channel)(int h, int index) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    FMOD_CHANNEL* channel = NULL;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_ChannelGroup_GetChannel(group, index, &channel);
    if (gLastResult != FMOD_OK || !channel) return 0;
    return faxe_handle_find_or_alloc(channel, FAXE_TYPE_CHAN);
}
DEFINE_PRIM(_I32, cg_get_channel, _I32 _I32);

// Drain protocol: cb_next pops the oldest queued event into a static slot;
// the accessors read fields from that slot. Haxe thread only.
static FaxeCbEvent gCbCurrent;

// Final cleanup for a destroyed instance, on the game thread: the handle
// slot, the channel-group handle minted for it, and the context itself.
// Both frees are generation-checked, so slots already reclaimed elsewhere
// (release, or a recycled slot) are left alone.
static void free_destroyed_ctx(FaxeInstCtx* ctx) {
    if (ctx->cgHandle != 0) faxe_handle_free(ctx->cgHandle);
    if (ctx->handle > 0) faxe_handle_free(ctx->handle);
    faxe_instctx_destroy(ctx);
}

HL_PRIM bool HL_NAME(cb_next)() {
    if (faxe_cbq_pop(&gCbCurrent) != 1) {
        /* Drain end: dispose of contexts whose DESTROYED events were
         * dropped by the ring's overflow policy. */
        FaxeInstCtx* orphan = (FaxeInstCtx*)faxe_cbq_take_orphans();
        while (orphan) {
            FaxeInstCtx* next = (FaxeInstCtx*)orphan->qnext;
            free_destroyed_ctx(orphan);
            orphan = next;
        }
        return false;
    }
    if (gCbCurrent.opaque) {
        free_destroyed_ctx((FaxeInstCtx*)gCbCurrent.opaque);
        gCbCurrent.opaque = NULL;
    }
    return true;
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
    switch (index) {
        case 0: return gCbCurrent.i1;
        case 1: return gCbCurrent.i2;
        case 2: return gCbCurrent.i3;
        case 3: return gCbCurrent.i4;
        case 4: return gCbCurrent.i5;
        default: return 0;
    }
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

//// Studio System

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

// Settings-driven init: numChannels <= 0 falls back to 128. sampleRate 0 =
// FMOD default. speakerMode 0 = default speaker mode. studioFlags bit0 =
// live update. Keeps the FMOD_WAVWRITER env branch (CI recording), which
// forces 48000/stereo and wins over the requested format. Idempotent:
// returns FMOD_OK when already initialized.
HL_PRIM int HL_NAME(sys_init_ex)(int numChannels, int sampleRate, int speakerMode, int studioFlags) {
    const char* wavWriterPath;
    void* extradriverdata = NULL;
    FMOD_STUDIO_INITFLAGS studioInitFlags;

    if (gStudioSystem != NULL) { gLastResult = FMOD_OK; return (int)gLastResult; }
    if (numChannels <= 0) numChannels = 128;

    gLastResult = FMOD_Studio_System_Create(&gStudioSystem, FMOD_VERSION);
    if (gLastResult != FMOD_OK) return (int)gLastResult;

    // FMOD_WAVWRITER env var: write mixed audio to WAV file (for CI recording)
    wavWriterPath = getenv("FMOD_WAVWRITER");
    if (wavWriterPath && wavWriterPath[0] != '\0') {
        FMOD_Studio_System_GetCoreSystem(gStudioSystem, &gCoreSystem);
        FMOD_System_SetOutput(gCoreSystem, FMOD_OUTPUTTYPE_WAVWRITER);
        // Explicit stereo format so WAV header has correct channel count (Windows needs this)
        FMOD_System_SetSoftwareFormat(gCoreSystem, 48000, FMOD_SPEAKERMODE_STEREO, 0);
        extradriverdata = (void*)wavWriterPath;
    } else if (sampleRate > 0 || speakerMode > 0) {
        FMOD_Studio_System_GetCoreSystem(gStudioSystem, &gCoreSystem);
        FMOD_System_SetSoftwareFormat(gCoreSystem, sampleRate, (FMOD_SPEAKERMODE)speakerMode, 0);
    }

    studioInitFlags = (studioFlags & 1) ? FMOD_STUDIO_INIT_LIVEUPDATE : FMOD_STUDIO_INIT_NORMAL;
    gLastResult = FMOD_Studio_System_Initialize(gStudioSystem, numChannels,
        studioInitFlags, FMOD_INIT_NORMAL, extradriverdata);
    if (gLastResult != FMOD_OK) {
        FMOD_Studio_System_Release(gStudioSystem);
        gStudioSystem = NULL;
        /* The wavwriter and format branches above may have cached the core
         * system, which the release just destroyed */
        gCoreSystem = NULL;
        return (int)gLastResult;
    }

    FMOD_Studio_System_GetCoreSystem(gStudioSystem, &gCoreSystem);
    faxe_cbq_init();
    gLastResult = FMOD_OK;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_init_ex, _I32 _I32 _I32 _I32);

// FMOD_Debug_Initialize level mapping (0=none 1=error 2=warning 3=log),
// TTY mode, no file logging. The logging-stripped FMOD libs report
// FMOD_ERR_UNSUPPORTED. That result is passed through.
HL_PRIM int HL_NAME(sys_set_debug_level)(int level) {
    FMOD_DEBUG_FLAGS flags = FMOD_DEBUG_LEVEL_NONE;
    if (level == 1) flags = FMOD_DEBUG_LEVEL_ERROR;
    else if (level == 2) flags = FMOD_DEBUG_LEVEL_WARNING;
    else if (level >= 3) flags = FMOD_DEBUG_LEVEL_LOG;
    gLastResult = FMOD_Debug_Initialize(flags, FMOD_DEBUG_MODE_TTY, NULL, NULL);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_set_debug_level, _I32);

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

// out = int[FAXE_LIST_MAX]: bank handles. Returns the count written
HL_PRIM int HL_NAME(sys_get_bank_list)(vbyte* out) {
    FMOD_STUDIO_BANK** banks = (FMOD_STUDIO_BANK**)gListBuf;
    int count = 0;
    int i;
    int* outInts = (int*)out;
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    gLastResult = FMOD_Studio_System_GetBankList(gStudioSystem, banks, FAXE_LIST_MAX, &count);
    if (gLastResult != FMOD_OK) return 0;
    if (count > FAXE_LIST_MAX) count = FAXE_LIST_MAX;
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
// so fetch through the list. index must stay below the list cap (FAXE_LIST_MAX).
HL_PRIM vbyte* HL_NAME(sys_get_parameter_description_by_index)(int index, vbyte* fbuf, vbyte* ibuf) {
    FMOD_STUDIO_PARAMETER_DESCRIPTION* list;
    int count = 0;
    gStringBuf[0] = '\0';
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (vbyte*)gStringBuf; }
    if (index < 0 || index >= FAXE_LIST_MAX) { gLastResult = FMOD_ERR_INVALID_PARAM; return (vbyte*)gStringBuf; }
    list = (FMOD_STUDIO_PARAMETER_DESCRIPTION*)malloc((size_t)(index + 1) * sizeof(FMOD_STUDIO_PARAMETER_DESCRIPTION));
    if (!list) { gLastResult = FMOD_ERR_MEMORY; return (vbyte*)gStringBuf; }
    gLastResult = FMOD_Studio_System_GetParameterDescriptionList(gStudioSystem, list, index + 1, &count);
    if (gLastResult == FMOD_OK && index < count) {
        write_param_desc(&list[index], fbuf, ibuf);
    } else if (gLastResult == FMOD_OK) {
        gLastResult = FMOD_ERR_INVALID_PARAM;
    }
    free(list);
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

// flags: bit0 = nonblocking. Returns a bank handle or 0 on failure
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

// Async bank load: always FMOD_STUDIO_LOAD_BANK_NONBLOCKING. poll
// bank_get_loading_state. Returns a bank handle or 0.
HL_PRIM int HL_NAME(sys_load_bank_async)(vbyte* path) {
    FMOD_STUDIO_BANK* bank = NULL;
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    gLastResult = FMOD_Studio_System_LoadBankFile(gStudioSystem, (const char*)path,
        FMOD_STUDIO_LOAD_BANK_NONBLOCKING, &bank);
    if (gLastResult != FMOD_OK || !bank) return 0;
    return faxe_handle_find_or_alloc(bank, FAXE_TYPE_BANK);
}
DEFINE_PRIM(_I32, sys_load_bank_async, _BYTES);

// Frees the cached lookup handles whose objects an unload just destroyed,
// so a reload cannot alias a recycled address under a stale handle.
static int hlaxe_lookup_slot_valid(void* ptr, unsigned char type) {
    switch (type) {
        case FAXE_TYPE_BUS: return FMOD_Studio_Bus_IsValid((FMOD_STUDIO_BUS*)ptr) ? 1 : 0;
        case FAXE_TYPE_VCA: return FMOD_Studio_VCA_IsValid((FMOD_STUDIO_VCA*)ptr) ? 1 : 0;
        case FAXE_TYPE_EVD: return FMOD_Studio_EventDescription_IsValid((FMOD_STUDIO_EVENTDESCRIPTION*)ptr) ? 1 : 0;
        case FAXE_TYPE_CHANGROUP: {
            // Core objects are handle-validated inside FMOD: a call on a
            // destroyed group reports FMOD_ERR_INVALID_HANDLE safely
            float volume = 0.0f;
            return FMOD_ChannelGroup_GetVolume((FMOD_CHANNELGROUP*)ptr, &volume)
                != FMOD_ERR_INVALID_HANDLE ? 1 : 0;
        }
        default: return 1;
    }
}

static void hlaxe_reclaim_dead_lookups(void) {
    // Unload runs on FMOD's async command queue. Flushing makes the dead
    // objects observable to IsValid before the sweep.
    if (gStudioSystem) FMOD_Studio_System_FlushCommands(gStudioSystem);
    faxe_handles_sweep_lookups(hlaxe_lookup_slot_valid);
}

HL_PRIM int HL_NAME(sys_unload_all)() {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = FMOD_Studio_System_UnloadAll(gStudioSystem);
    if (gLastResult == FMOD_OK) hlaxe_reclaim_dead_lookups();
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

//// Bus

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

//// VCA

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

//// Bank

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

// Real unload. Frees the bank handle on success so stale copies stop resolving
HL_PRIM int HL_NAME(bank_unload)(int h) {
    FMOD_STUDIO_BANK* bank = resolve_bank(h);
    if (!bank) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Studio_Bank_Unload(bank);
    if (gLastResult == FMOD_OK) {
        faxe_handle_free(h);
        hlaxe_reclaim_dead_lookups();
    }
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

// out = int[FAXE_LIST_MAX]: event description handles. Returns the count written
HL_PRIM int HL_NAME(bank_get_event_list)(int h, vbyte* out) {
    FMOD_STUDIO_BANK* bank = resolve_bank(h);
    FMOD_STUDIO_EVENTDESCRIPTION** list = (FMOD_STUDIO_EVENTDESCRIPTION**)gListBuf;
    int count = 0;
    int i;
    int* outInts = (int*)out;
    if (!bank) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_Studio_Bank_GetEventList(bank, list, FAXE_LIST_MAX, &count);
    if (gLastResult != FMOD_OK) return 0;
    if (count > FAXE_LIST_MAX) count = FAXE_LIST_MAX;
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

// out = int[FAXE_LIST_MAX]: bus handles. Returns the count written
HL_PRIM int HL_NAME(bank_get_bus_list)(int h, vbyte* out) {
    FMOD_STUDIO_BANK* bank = resolve_bank(h);
    FMOD_STUDIO_BUS** list = (FMOD_STUDIO_BUS**)gListBuf;
    int count = 0;
    int i;
    int* outInts = (int*)out;
    if (!bank) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_Studio_Bank_GetBusList(bank, list, FAXE_LIST_MAX, &count);
    if (gLastResult != FMOD_OK) return 0;
    if (count > FAXE_LIST_MAX) count = FAXE_LIST_MAX;
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

// out = int[FAXE_LIST_MAX]: VCA handles. Returns the count written
HL_PRIM int HL_NAME(bank_get_vca_list)(int h, vbyte* out) {
    FMOD_STUDIO_BANK* bank = resolve_bank(h);
    FMOD_STUDIO_VCA** list = (FMOD_STUDIO_VCA**)gListBuf;
    int count = 0;
    int i;
    int* outInts = (int*)out;
    if (!bank) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_Studio_Bank_GetVCAList(bank, list, FAXE_LIST_MAX, &count);
    if (gLastResult != FMOD_OK) return 0;
    if (count > FAXE_LIST_MAX) count = FAXE_LIST_MAX;
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

//// EventDescription

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
        gLastResult = FMOD_ERR_MEMORY; /* handle table exhausted */
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

// out = int[FAXE_LIST_MAX]: instance handles. Returns the count written. Instances FMOD
// returns that we have not seen before get fresh handles.
HL_PRIM int HL_NAME(evd_get_instance_list)(int h, vbyte* out) {
    FMOD_STUDIO_EVENTDESCRIPTION* desc = resolve_evd(h);
    FMOD_STUDIO_EVENTINSTANCE** list = (FMOD_STUDIO_EVENTINSTANCE**)gListBuf;
    int count = 0;
    int i;
    int* outInts = (int*)out;
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_Studio_EventDescription_GetInstanceList(desc, list, FAXE_LIST_MAX, &count);
    if (gLastResult != FMOD_OK) return 0;
    if (count > FAXE_LIST_MAX) count = FAXE_LIST_MAX;
    for (i = 0; i < count; i++) {
        /* The instance's own context is the identity authority. Pointer
         * dedup would be wrong here: a dead instance's slot keeps its
         * dangling pointer until the DESTROYED drain, and FMOD can hand a
         * new instance the same address inside that window. */
        FaxeInstCtx* ctx = instance_ctx(list[i]);
        int handle;
        if (ctx && faxe_handle_resolve(ctx->handle, FAXE_TYPE_EVI) == (void*)list[i]) {
            handle = ctx->handle;
        } else {
            /* Released-but-still-playing (context holds a freed handle) or
             * never managed: mint a fresh slot and point the context at it,
             * or queued callbacks carry a dead handle and get dropped. */
            handle = faxe_handle_alloc(list[i], FAXE_TYPE_EVI);
            if (handle != 0) {
                if (ctx) {
                    faxe_cbq_lock();
                    ctx->handle = handle;
                    faxe_cbq_unlock();
                } else if (!attach_instance_ctx(list[i], handle)) {
                    /* No context means no DESTROYED hand-off would ever
                     * reclaim the slot */
                    faxe_handle_free(handle);
                    handle = 0;
                    gLastResult = FMOD_ERR_INVALID_HANDLE;
                }
            } else {
                gLastResult = FMOD_ERR_MEMORY;
            }
        }
        outInts[i] = handle;
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

//// EventInstance

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
    /* INVALID_HANDLE means FMOD already destroyed the instance (bank unload,
     * releaseAllInstances). The slot must still be reclaimed or it leaks for
     * the rest of the process. */
    if (gLastResult == FMOD_OK || gLastResult == FMOD_ERR_INVALID_HANDLE) {
        faxe_handle_free(h);
    }
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

// Reads the version out of the marker so the string is always retained in
// the compiled hdll and the prim can never disagree with it. The digits are
// copied through volatile reads before atoi (see the marker declaration).
HL_PRIM int HL_NAME(binding_abi_version)() {
    char digits[8];
    int i = 0;
    while (i < 7 && gAbiMarker[15 + i] != '\0') {
        digits[i] = gAbiMarker[15 + i];
        i++;
    }
    digits[i] = '\0';
    return atoi(digits);
}
DEFINE_PRIM(_I32, binding_abi_version, _NO_ARG);
