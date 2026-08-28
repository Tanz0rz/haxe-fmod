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
#include "../shared/faxe_dspdata.h"

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
static const volatile char gAbiMarker[] = "hlaxe_fmod_abi=10";

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

static FMOD_CHANNELGROUP* resolve_changroup(int h);

// The channel group a play call routes into. Handle 0 means the master
// group (FMOD's NULL). A stale handle fails the call instead of falling
// back to the master group, so a wrong route is heard about.
static int resolve_play_group(int h, FMOD_CHANNELGROUP** out) {
    *out = NULL;
    if (h == 0) return 1;
    *out = resolve_changroup(h);
    return *out != NULL;
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
            void* gameSound;
            int gameSubsound;
            // A name entry wins over the single key, the game sound wins
            // over both.
            faxe_cbq_lock();
            gameSound = ctx->psGameSound;
            gameSubsound = ctx->psGameSubsound;
            strncpy(key, ctx->psKey, FAXE_PS_KEY_MAX - 1);
            key[FAXE_PS_KEY_MAX - 1] = '\0';
            if (props) faxe_instctx_ps_find_named(ctx, props->name, key);
            faxe_cbq_unlock();
            if (props && props->name) {
                strncpy(ev.str, props->name, FAXE_CBQ_STR_MAX - 1);
            }
            if (props && gameSound) {
                props->sound = (FMOD_SOUND*)gameSound;
                props->subsoundIndex = gameSubsound;
                ctx->psSound = NULL;
            } else if (props && key[0] != '\0' && gCoreSystem && gStudioSystem) {
                // NONBLOCKING moves the decode off the Studio thread. FMOD
                // waits for the sound to become ready before the instrument
                // plays it, the same as FMOD's own example.
                if (FMOD_Studio_System_GetSoundInfo(gStudioSystem, key, &info) == FMOD_OK) {
                    // Audio table entry
                    if (FMOD_System_CreateSound(gCoreSystem, info.name_or_data,
                            FMOD_LOOP_NORMAL | FMOD_CREATECOMPRESSEDSAMPLE | FMOD_NONBLOCKING | info.mode,
                            &info.exinfo, &sound) == FMOD_OK) {
                        props->sound = sound;
                        props->subsoundIndex = info.subsoundindex;
                    }
                } else if (FMOD_System_CreateSound(gCoreSystem, key, FMOD_DEFAULT | FMOD_NONBLOCKING, NULL, &sound) == FMOD_OK) {
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
            if (props && props->name) {
                strncpy(ev.str, props->name, FAXE_CBQ_STR_MAX - 1);
            }
            // Only a sound this shim created is released. A game-owned one
            // stays with the game.
            if (props && props->sound && props->sound == (FMOD_SOUND*)ctx->psSound) {
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
                faxe_guid_format(&props->eventid, ev.str, FAXE_CBQ_STR_MAX);
            }
            break;
        }
        case FMOD_STUDIO_EVENT_CALLBACK_PLUGIN_CREATED:
        case FMOD_STUDIO_EVENT_CALLBACK_PLUGIN_DESTROYED: {
            const FMOD_STUDIO_PLUGIN_INSTANCE_PROPERTIES* props =
                (const FMOD_STUDIO_PLUGIN_INSTANCE_PROPERTIES*)parameters;
            if (props) {
                if (props->name) {
                    strncpy(ev.str, props->name, FAXE_CBQ_STR_MAX - 1);
                }
                ev.ptr = props->dsp;
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
// DESTROYED (context cleanup) plus the programmer-sound bits when any
// programmer sound assignment is present.
static FMOD_STUDIO_EVENT_CALLBACK_TYPE effective_callback_mask(FaxeInstCtx* ctx) {
    unsigned int mask = ctx->cbMask | FMOD_STUDIO_EVENT_CALLBACK_DESTROYED;
    faxe_cbq_lock();
    if (faxe_instctx_ps_armed(ctx)) {
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

// Hands a game-owned sound to the programmer instrument. The sound is
// resolved here on the Haxe thread, the callback only reads the pointer.
// The game keeps the sound alive until the instrument has destroyed it.
HL_PRIM int HL_NAME(ps_assign_sound)(int h, int soundHandle, int subsoundIndex) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    FMOD_SOUND* sound;
    FaxeInstCtx* ctx;
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    ctx = instance_ctx(instance);
    if (!ctx) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    sound = (FMOD_SOUND*)faxe_handle_resolve(soundHandle, FAXE_TYPE_SOUND);
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    if (subsoundIndex < -1) { gLastResult = FMOD_ERR_INVALID_PARAM; return (int)gLastResult; }
    faxe_cbq_lock();
    ctx->psGameSound = sound;
    ctx->psGameSubsound = subsoundIndex;
    faxe_cbq_unlock();
    gLastResult = FMOD_Studio_EventInstance_SetCallback(instance, eventCallback,
        effective_callback_mask(ctx));
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, ps_assign_sound, _I32 _I32 _I32);

// Maps one programmer instrument name to a key or path. The name is the
// instrument's name in FMOD Studio, matched when the create callback runs.
HL_PRIM int HL_NAME(ps_assign_named)(int h, vbyte* name, vbyte* key) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    FaxeInstCtx* ctx;
    int stored;
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    ctx = instance_ctx(instance);
    if (!ctx) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    if (!name || !key) { gLastResult = FMOD_ERR_INVALID_PARAM; return (int)gLastResult; }
    faxe_cbq_lock();
    stored = faxe_instctx_ps_set_named(ctx, (const char*)name, (const char*)key);
    faxe_cbq_unlock();
    if (stored < 0) { gLastResult = FMOD_ERR_INVALID_PARAM; return (int)gLastResult; }
    if (stored == 0) { gLastResult = FMOD_ERR_MEMORY; return (int)gLastResult; }
    gLastResult = FMOD_Studio_EventInstance_SetCallback(instance, eventCallback,
        effective_callback_mask(ctx));
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, ps_assign_named, _I32 _BYTES _BYTES);

HL_PRIM int HL_NAME(ps_clear)(int h) {
    FMOD_STUDIO_EVENTINSTANCE* instance = resolve_instance(h);
    FaxeInstCtx* ctx;
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    ctx = instance_ctx(instance);
    if (!ctx) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    faxe_cbq_lock();
    faxe_instctx_ps_clear(ctx);
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

// mode is a full FMOD_MODE. initialSubsound >= 0 goes into
// exinfo.initialsubsound for FSB streams, -1 leaves the default.
HL_PRIM int HL_NAME(core_create_sound)(vbyte* path, int mode, int initialSubsound) {
    FMOD_SOUND* sound = NULL;
    FMOD_CREATESOUNDEXINFO exinfo;
    FMOD_CREATESOUNDEXINFO* exinfoPtr = NULL;
    int handle;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    if (initialSubsound >= 0) {
        memset(&exinfo, 0, sizeof(exinfo));
        exinfo.cbsize = sizeof(exinfo);
        exinfo.initialsubsound = initialSubsound;
        exinfoPtr = &exinfo;
    }
    gLastResult = FMOD_System_CreateSound(gCoreSystem, (const char*)path, (FMOD_MODE)mode, exinfoPtr, &sound);
    if (gLastResult != FMOD_OK || !sound) return 0;
    handle = faxe_handle_alloc(sound, FAXE_TYPE_SOUND);
    if (handle == 0) {
        gLastResult = FMOD_ERR_MEMORY; /* handle table exhausted */
        FMOD_Sound_Release(sound);
        return 0;
    }
    return handle;
}
DEFINE_PRIM(_I32, core_create_sound, _BYTES _I32 _I32);

// An encoded file image (wav, ogg, mp3, fsb) already in memory. FMOD
// copies the bytes, so the buffer is free once this returns.
HL_PRIM int HL_NAME(core_create_sound_memory)(vbyte* data, int len, int mode) {
    FMOD_CREATESOUNDEXINFO exinfo;
    FMOD_SOUND* sound = NULL;
    int handle;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    if (!data || len <= 0) { gLastResult = FMOD_ERR_INVALID_PARAM; return 0; }
    memset(&exinfo, 0, sizeof(exinfo));
    exinfo.cbsize = sizeof(exinfo);
    exinfo.length = (unsigned int)len;
    gLastResult = FMOD_System_CreateSound(gCoreSystem, (const char*)data,
        ((FMOD_MODE)mode & ~(FMOD_MODE)FMOD_OPENMEMORY_POINT) | FMOD_OPENMEMORY, &exinfo, &sound);
    if (gLastResult != FMOD_OK || !sound) return 0;
    handle = faxe_handle_alloc(sound, FAXE_TYPE_SOUND);
    if (handle == 0) {
        gLastResult = FMOD_ERR_MEMORY; /* handle table exhausted */
        FMOD_Sound_Release(sound);
        return 0;
    }
    return handle;
}
DEFINE_PRIM(_I32, core_create_sound_memory, _BYTES _I32 _I32);

// Releasing a parent sound destroys its subsounds, so every sound handle
// whose FMOD parent is this sound is dropped first. Otherwise those slots
// would keep pointing at freed memory.
static void release_subsound_handles(FMOD_SOUND* parent) {
    int i;
    for (i = 0; i < gFaxeSlotCap; i++) {
        FMOD_SOUND* owner = NULL;
        if (!gFaxeSlots[i].alive || gFaxeSlots[i].type != FAXE_TYPE_SOUND) continue;
        if (gFaxeSlots[i].ptr == (void*)parent) continue;
        if (FMOD_Sound_GetSubSoundParent((FMOD_SOUND*)gFaxeSlots[i].ptr, &owner) != FMOD_OK) continue;
        if (owner == parent) faxe_handle_free(((int)gFaxeSlots[i].gen << 16) | i);
    }
}

HL_PRIM int HL_NAME(core_release_sound)(int h) {
    FMOD_SOUND* sound = resolve_sound(h);
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    release_subsound_handles(sound);
    gLastResult = FMOD_Sound_Release(sound);
    if (gLastResult == FMOD_OK) faxe_handle_free(h);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, core_release_sound, _I32);

// unit is an FMOD_TIMEUNIT value, the length comes back in that unit
HL_PRIM int HL_NAME(core_get_sound_length)(int h, int unit) {
    FMOD_SOUND* sound = resolve_sound(h);
    unsigned int length = 0;
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return -1; }
    gLastResult = FMOD_Sound_GetLength(sound, &length, (FMOD_TIMEUNIT)unit);
    if (gLastResult != FMOD_OK) return -1;
    return (int)length;
}
DEFINE_PRIM(_I32, core_get_sound_length, _I32 _I32);

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

HL_PRIM int HL_NAME(core_pcm_play)(int h, int group, bool paused) {
    HlaxePcmStream* ps = resolve_pcm(h);
    FMOD_CHANNEL* channel = NULL;
    FMOD_CHANNELGROUP* cg;
    int handle;
    if (!ps) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    if (!resolve_play_group(group, &cg)) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_System_PlaySound(gCoreSystem, ps->sound, cg, paused ? 1 : 0, &channel);
    if (gLastResult != FMOD_OK || !channel) return 0;
    handle = faxe_handle_alloc(channel, FAXE_TYPE_CHAN);
    if (handle == 0) {
        gLastResult = FMOD_ERR_MEMORY; /* handle table exhausted */
        FMOD_Channel_Stop(channel);
        return 0;
    }
    return handle;
}
DEFINE_PRIM(_I32, core_pcm_play, _I32 _I32 _BOOL);

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

HL_PRIM int HL_NAME(chan_get_position)(int h, int unit) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    unsigned int position = 0;
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return -1; }
    gLastResult = FMOD_Channel_GetPosition(channel, &position, (FMOD_TIMEUNIT)unit);
    return gLastResult == FMOD_OK ? (int)position : -1;
}
DEFINE_PRIM(_I32, chan_get_position, _I32 _I32);

HL_PRIM int HL_NAME(chan_set_position)(int h, int position, int unit) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Channel_SetPosition(channel, (unsigned int)position, (FMOD_TIMEUNIT)unit);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_set_position, _I32 _I32 _I32);

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

HL_PRIM int HL_NAME(sys_play_dsp)(int dspHandle, int group, bool startPaused) {
    FMOD_DSP* dsp = resolve_dsp(dspHandle);
    FMOD_CHANNEL* channel = NULL;
    FMOD_CHANNELGROUP* cg;
    int handle;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    if (!resolve_play_group(group, &cg)) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_System_PlayDSP(gCoreSystem, dsp, cg, startPaused ? 1 : 0, &channel);
    if (gLastResult != FMOD_OK || !channel) return 0;
    handle = faxe_handle_alloc(channel, FAXE_TYPE_CHAN);
    if (handle == 0) {
        gLastResult = FMOD_ERR_MEMORY; /* handle table exhausted */
        FMOD_Channel_Stop(channel);
        return 0;
    }
    return handle;
}
DEFINE_PRIM(_I32, sys_play_dsp, _I32 _I32 _BOOL);

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

// connHandle 0 means any connection between the two units
HL_PRIM int HL_NAME(dsp_disconnect_from)(int h, int inputHandle, int connHandle) {
    FMOD_DSP* dsp = resolve_dsp(h);
    FMOD_DSP* input = resolve_dsp(inputHandle);
    FMOD_DSPCONNECTION* conn = NULL;
    if (!dsp || !input) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    if (connHandle != 0) {
        conn = resolve_dspconn(connHandle);
        if (!conn) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    }
    gLastResult = FMOD_DSP_DisconnectFrom(dsp, input, conn);
    // Graph changes invalidate connection objects on the mixer's schedule,
    // so every connection handle is dropped deterministically here
    if (gLastResult == FMOD_OK) faxe_handles_free_type(FAXE_TYPE_DSPCONN);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, dsp_disconnect_from, _I32 _I32 _I32);

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

// Returns the connection handle, 0 on failure with the reason in gLastResult
HL_PRIM int HL_NAME(cg_add_group)(int h, int childHandle, bool propagateDspClock) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    FMOD_CHANNELGROUP* child = resolve_changroup(childHandle);
    FMOD_DSPCONNECTION* conn = NULL;
    if (!group || !child) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_ChannelGroup_AddGroup(group, child, propagateDspClock ? 1 : 0, &conn);
    if (gLastResult != FMOD_OK || !conn) return 0;
    return faxe_handle_find_or_alloc(conn, FAXE_TYPE_DSPCONN);
}
DEFINE_PRIM(_I32, cg_add_group, _I32 _I32 _BOOL);

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
// Rows of outChannels by inChannels gains, laid out with inChannelHop
// floats per row (0 = packed). Everything stays inside the 32x32 buffer.
static int matrix_args_ok(int outChannels, int inChannels, int inChannelHop) {
    int stride = inChannelHop > 0 ? inChannelHop : inChannels;
    if (outChannels < 1 || inChannels < 1 || outChannels > 32 || inChannels > 32
            || inChannelHop < 0 || inChannelHop > 32 || stride < inChannels) {
        gLastResult = FMOD_ERR_INVALID_PARAM;
        return 0;
    }
    return 1;
}

HL_PRIM int HL_NAME(chan_set_mix_matrix)(int h, vbyte* in, int outChannels, int inChannels, int inChannelHop) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    double* inFloats = (double*)in;
    float matrix[32 * 32];
    int i;
    int total;
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    if (!matrix_args_ok(outChannels, inChannels, inChannelHop)) return (int)gLastResult;
    total = outChannels * (inChannelHop > 0 ? inChannelHop : inChannels);
    for (i = 0; i < total; i++) matrix[i] = (float)inFloats[i];
    gLastResult = FMOD_Channel_SetMixMatrix(channel, matrix, outChannels, inChannels, inChannelHop);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_set_mix_matrix, _I32 _BYTES _I32 _I32 _I32);

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

HL_PRIM int HL_NAME(core_play_sound)(int h, int group, bool startPaused) {
    FMOD_SOUND* sound = resolve_core_sound(h);
    FMOD_CHANNEL* channel = NULL;
    FMOD_CHANNELGROUP* cg;
    int handle;
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    if (!resolve_play_group(group, &cg)) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_System_PlaySound(gCoreSystem, sound, cg, startPaused ? 1 : 0, &channel);
    if (gLastResult != FMOD_OK || !channel) return 0;
    handle = faxe_handle_alloc(channel, FAXE_TYPE_CHAN);
    if (handle == 0) {
        gLastResult = FMOD_ERR_MEMORY; /* handle table exhausted */
        FMOD_Channel_Stop(channel);
        return 0;
    }
    return handle;
}
DEFINE_PRIM(_I32, core_play_sound, _I32 _I32 _BOOL);

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

// Both points share one FMOD_TIMEUNIT
HL_PRIM int HL_NAME(sound_set_loop_points)(int h, int start, int end, int unit) {
    FMOD_SOUND* sound = resolve_core_sound(h);
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Sound_SetLoopPoints(sound, (unsigned int)start, (FMOD_TIMEUNIT)unit,
        (unsigned int)end, (FMOD_TIMEUNIT)unit);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sound_set_loop_points, _I32 _I32 _I32 _I32);

// out = int[2]: loop start, loop end, both in the given unit
HL_PRIM int HL_NAME(sound_get_loop_points)(int h, int unit, vbyte* out) {
    FMOD_SOUND* sound = resolve_core_sound(h);
    unsigned int start = 0;
    unsigned int end = 0;
    int* outInts = (int*)out;
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Sound_GetLoopPoints(sound, &start, (FMOD_TIMEUNIT)unit, &end, (FMOD_TIMEUNIT)unit);
    outInts[0] = (int)start;
    outInts[1] = (int)end;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sound_get_loop_points, _I32 _I32 _BYTES);

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

// out = int[4]: sound type, sample format, channels, bits
HL_PRIM int HL_NAME(sound_get_format)(int h, vbyte* out) {
    FMOD_SOUND* sound = resolve_core_sound(h);
    FMOD_SOUND_TYPE type = FMOD_SOUND_TYPE_UNKNOWN;
    FMOD_SOUND_FORMAT format = FMOD_SOUND_FORMAT_NONE;
    int channels = 0;
    int bits = 0;
    int* outInts = (int*)out;
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Sound_GetFormat(sound, &type, &format, &channels, &bits);
    outInts[0] = (int)type;
    outInts[1] = (int)format;
    outInts[2] = channels;
    outInts[3] = bits;
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

// out = int[4]: open state, percent buffered, starving, disk busy
HL_PRIM int HL_NAME(sound_get_open_state_info)(int h, vbyte* out) {
    FMOD_SOUND* sound = resolve_core_sound(h);
    FMOD_OPENSTATE state = FMOD_OPENSTATE_READY;
    unsigned int buffered = 0;
    FMOD_BOOL starving = 0;
    FMOD_BOOL diskBusy = 0;
    int* outInts = (int*)out;
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Sound_GetOpenState(sound, &state, &buffered, &starving, &diskBusy);
    outInts[0] = (int)state;
    outInts[1] = (int)buffered;
    outInts[2] = starving ? 1 : 0;
    outInts[3] = diskBusy ? 1 : 0;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sound_get_open_state_info, _I32 _BYTES);

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
#define FAXE_CB_CHAN_VIRTUALVOICE 0x40000003u
#define FAXE_CB_CHAN_OCCLUSION 0x40000004u

// Runs on whichever thread pumps System::update. Pure C: reads the handle
// from the channel or group user data and enqueues, never touching the
// runtime. Occlusion carries two floats, the second rides in i1 as raw bits.
static FMOD_RESULT F_CALLBACK hlaxe_channel_callback(FMOD_CHANNELCONTROL* channelcontrol,
        FMOD_CHANNELCONTROL_TYPE controltype, FMOD_CHANNELCONTROL_CALLBACK_TYPE callbacktype,
        void* commanddata1, void* commanddata2) {
    void* userData = NULL;
    int handle;
    FaxeCbEvent event;
    if (controltype == FMOD_CHANNELCONTROL_CHANNEL) {
        FMOD_Channel_GetUserData((FMOD_CHANNEL*)channelcontrol, &userData);
    } else if (controltype == FMOD_CHANNELCONTROL_CHANNELGROUP) {
        FMOD_ChannelGroup_GetUserData((FMOD_CHANNELGROUP*)channelcontrol, &userData);
    } else {
        return FMOD_OK;
    }
    handle = (int)(intptr_t)userData;
    if (!handle) return FMOD_OK;
    memset(&event, 0, sizeof(event));
    event.handle = handle;
    if (callbacktype == FMOD_CHANNELCONTROL_CALLBACK_END) {
        event.type = FAXE_CB_CHAN_END;
    } else if (callbacktype == FMOD_CHANNELCONTROL_CALLBACK_SYNCPOINT) {
        event.type = FAXE_CB_CHAN_SYNCPOINT;
        event.i1 = (int)(intptr_t)commanddata1;
    } else if (callbacktype == FMOD_CHANNELCONTROL_CALLBACK_VIRTUALVOICE) {
        event.type = FAXE_CB_CHAN_VIRTUALVOICE;
        event.i1 = (int)(intptr_t)commanddata1;
    } else if (callbacktype == FMOD_CHANNELCONTROL_CALLBACK_OCCLUSION) {
        event.type = FAXE_CB_CHAN_OCCLUSION;
        if (commanddata1) event.f1 = *(float*)commanddata1;
        if (commanddata2) memcpy(&event.i1, commanddata2, sizeof(int32_t));
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

HL_PRIM int HL_NAME(cg_set_callback)(int h, bool enabled) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    if (enabled) {
        FMOD_ChannelGroup_SetUserData(group, (void*)(intptr_t)h);
        gLastResult = FMOD_ChannelGroup_SetCallback(group, hlaxe_channel_callback);
    } else {
        gLastResult = FMOD_ChannelGroup_SetCallback(group, NULL);
        FMOD_ChannelGroup_SetUserData(group, NULL);
    }
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, cg_set_callback, _I32 _BOOL);

//// System callbacks (core and studio)

// System events ride the queue with handle 0 under the 0x20000000
// namespace. Core types sit at 0x20000000 | type, studio types at
// 0x20000100 | type so the two sets cannot collide.
#define FAXE_CB_SYS_NAMESPACE 0x20000000u
#define FAXE_CB_SYS_STUDIO_BIT 0x00000100u

// The studio mask in force. Zero means no stash work on the unload paths.
static unsigned int gSystemCallbackMask = 0;

// Runs on whichever FMOD thread raised the event. Plain C only.
static FMOD_RESULT F_CALLBACK hlaxe_system_callback(FMOD_SYSTEM* system,
        FMOD_SYSTEM_CALLBACK_TYPE type, void* commanddata1, void* commanddata2, void* userdata) {
    FaxeCbEvent event;
    (void)system; (void)commanddata1; (void)commanddata2; (void)userdata;
    memset(&event, 0, sizeof(event));
    event.type = FAXE_CB_SYS_NAMESPACE | (uint32_t)type;
    faxe_cbq_push(&event);
    return FMOD_OK;
}

// Runs on the Studio thread. BANK_UNLOAD carries the bank as commanddata.
// FMOD answers reads on that bank with NOTREADY here (verified on
// 2.03.12), so the path comes from the stash the unload paths filled.
static FMOD_RESULT F_CALLBACK hlaxe_studio_system_callback(FMOD_STUDIO_SYSTEM* system,
        FMOD_STUDIO_SYSTEM_CALLBACK_TYPE type, void* commanddata, void* userdata) {
    FaxeCbEvent event;
    (void)system; (void)userdata;
    memset(&event, 0, sizeof(event));
    event.type = FAXE_CB_SYS_NAMESPACE | FAXE_CB_SYS_STUDIO_BIT | (uint32_t)type;
    if (type == FMOD_STUDIO_SYSTEM_CALLBACK_BANK_UNLOAD && commanddata) {
        faxe_bankpath_take(commanddata, event.str);
    }
    faxe_cbq_push(&event);
    return FMOD_OK;
}

// Reads a bank's path while the bank can still answer and stashes it for
// the BANK_UNLOAD record. Haxe thread only.
static void hlaxe_stash_bank_path(FMOD_STUDIO_BANK* bank) {
    char path[FAXE_CBQ_STR_MAX];
    int retrieved = 0;
    if (!gSystemCallbackMask) return;
    if (FMOD_Studio_Bank_GetPath(bank, path, FAXE_CBQ_STR_MAX, &retrieved) == FMOD_OK) {
        faxe_bankpath_put(bank, path);
    }
}

static void hlaxe_stash_all_bank_paths(void) {
    FMOD_STUDIO_BANK* banks[FAXE_BANKPATH_CAPACITY];
    int count = 0;
    int i;
    if (!gSystemCallbackMask || !gStudioSystem) return;
    if (FMOD_Studio_System_GetBankList(gStudioSystem, banks, FAXE_BANKPATH_CAPACITY, &count) != FMOD_OK) return;
    for (i = 0; i < count; i++) hlaxe_stash_bank_path(banks[i]);
}

HL_PRIM int HL_NAME(sys_set_callback_mask)(int mask) {
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    if (mask == 0) {
        gLastResult = FMOD_System_SetCallback(gCoreSystem, NULL, 0);
    } else {
        gLastResult = FMOD_System_SetCallback(gCoreSystem, hlaxe_system_callback,
            (FMOD_SYSTEM_CALLBACK_TYPE)mask);
    }
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_set_callback_mask, _I32);

HL_PRIM int HL_NAME(sys_set_studio_callback_mask)(int mask) {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    if (mask == 0) {
        gLastResult = FMOD_Studio_System_SetCallback(gStudioSystem, NULL, 0);
        faxe_bankpath_clear();
    } else {
        gLastResult = FMOD_Studio_System_SetCallback(gStudioSystem, hlaxe_studio_system_callback,
            (FMOD_STUDIO_SYSTEM_CALLBACK_TYPE)mask);
    }
    gSystemCallbackMask = (gLastResult == FMOD_OK) ? (unsigned int)mask : 0u;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_set_studio_callback_mask, _I32);

HL_PRIM int HL_NAME(sound_add_sync_point)(int h, int offset, int unit, vbyte* name) {
    FMOD_SOUND* sound = resolve_core_sound(h);
    FMOD_SYNCPOINT* point = NULL;
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Sound_AddSyncPoint(sound, (unsigned int)offset, (FMOD_TIMEUNIT)unit,
        (const char*)name, &point);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sound_add_sync_point, _I32 _I32 _I32 _BYTES);

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

HL_PRIM int HL_NAME(sound_get_sync_point_offset)(int h, int index, int unit) {
    FMOD_SOUND* sound = resolve_core_sound(h);
    FMOD_SYNCPOINT* point = NULL;
    unsigned int offset = 0;
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return -1; }
    gLastResult = FMOD_Sound_GetSyncPoint(sound, index, &point);
    if (gLastResult != FMOD_OK) return -1;
    gLastResult = FMOD_Sound_GetSyncPointInfo(sound, point, NULL, 0, &offset, (FMOD_TIMEUNIT)unit);
    return gLastResult == FMOD_OK ? (int)offset : -1;
}
DEFINE_PRIM(_I32, sound_get_sync_point_offset, _I32 _I32 _I32);

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

HL_PRIM int HL_NAME(sys_load_bank_memory)(vbyte* data, int len, int flags) {
    FMOD_STUDIO_BANK* bank = NULL;
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    if (!data || len <= 0) { gLastResult = FMOD_ERR_INVALID_PARAM; return 0; }
    gLastResult = FMOD_Studio_System_LoadBankMemory(gStudioSystem, (const char*)data, len,
        FMOD_STUDIO_LOAD_MEMORY, (FMOD_STUDIO_LOAD_BANK_FLAGS)flags, &bank);
    if (gLastResult != FMOD_OK || !bank) return 0;
    return faxe_handle_find_or_alloc(bank, FAXE_TYPE_BANK);
}
DEFINE_PRIM(_I32, sys_load_bank_memory, _BYTES _I32 _I32);

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

HL_PRIM int HL_NAME(sys_start_command_capture)(vbyte* path, int flags) {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = FMOD_Studio_System_StartCommandCapture(gStudioSystem, (const char*)path,
        (FMOD_STUDIO_COMMANDCAPTURE_FLAGS)flags);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_start_command_capture, _BYTES _I32);

HL_PRIM int HL_NAME(sys_stop_command_capture)() {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = FMOD_Studio_System_StopCommandCapture(gStudioSystem);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_stop_command_capture, _NO_ARG);

HL_PRIM int HL_NAME(sys_load_command_replay)(vbyte* path, int flags) {
    FMOD_STUDIO_COMMANDREPLAY* replay = NULL;
    int handle;
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    gLastResult = FMOD_Studio_System_LoadCommandReplay(gStudioSystem, (const char*)path,
        (FMOD_STUDIO_COMMANDREPLAY_FLAGS)flags, &replay);
    if (gLastResult != FMOD_OK || !replay) return 0;
    handle = faxe_handle_alloc(replay, FAXE_TYPE_REPLAY);
    if (handle == 0) {
        gLastResult = FMOD_ERR_MEMORY; /* handle table exhausted */
        FMOD_Studio_CommandReplay_Release(replay);
        return 0;
    }
    return handle;
}
DEFINE_PRIM(_I32, sys_load_command_replay, _BYTES _I32);

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

HL_PRIM int HL_NAME(replay_seek_to_time)(int h, double seconds) {
    FMOD_STUDIO_COMMANDREPLAY* replay = resolve_replay(h);
    if (!replay) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Studio_CommandReplay_SeekToTime(replay, (float)seconds);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, replay_seek_to_time, _I32 _F64);

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

HL_PRIM int HL_NAME(chan_set_loop_points)(int h, int start, int end, int unit) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Channel_SetLoopPoints(channel, (unsigned int)start, (FMOD_TIMEUNIT)unit,
        (unsigned int)end, (FMOD_TIMEUNIT)unit);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_set_loop_points, _I32 _I32 _I32 _I32);

// out = int[2]: loop start, loop end, both in the given unit
HL_PRIM int HL_NAME(chan_get_loop_points)(int h, int unit, vbyte* out) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    unsigned int start = 0;
    unsigned int end = 0;
    int* outInts = (int*)out;
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Channel_GetLoopPoints(channel, &start, (FMOD_TIMEUNIT)unit, &end, (FMOD_TIMEUNIT)unit);
    outInts[0] = (int)start;
    outInts[1] = (int)end;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_get_loop_points, _I32 _I32 _BYTES);

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

HL_PRIM int HL_NAME(cg_get_3d_occlusion)(int h, vbyte* out) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    float direct = 0.0f;
    float reverb = 0.0f;
    double* outFloats = (double*)out;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_ChannelGroup_Get3DOcclusion(group, &direct, &reverb);
    outFloats[0] = (double)direct;
    outFloats[1] = (double)reverb;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, cg_get_3d_occlusion, _I32 _BYTES);

HL_PRIM int HL_NAME(cg_get_delay)(int h, vbyte* out) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    unsigned long long startClock = 0;
    unsigned long long endClock = 0;
    FMOD_BOOL stopChannels = 0;
    double* outFloats = (double*)out;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_ChannelGroup_GetDelay(group, &startClock, &endClock, &stopChannels);
    outFloats[0] = (double)startClock;
    outFloats[1] = (double)endClock;
    outFloats[2] = stopChannels ? 1.0 : 0.0;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, cg_get_delay, _I32 _BYTES);

HL_PRIM double HL_NAME(cg_get_low_pass_gain)(int h) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    float gain = 0.0f;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    gLastResult = FMOD_ChannelGroup_GetLowPassGain(group, &gain);
    return (double)gain;
}
DEFINE_PRIM(_F64, cg_get_low_pass_gain, _I32);

HL_PRIM bool HL_NAME(cg_is_playing)(int h) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    FMOD_BOOL playing = 0;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    gLastResult = FMOD_ChannelGroup_IsPlaying(group, &playing);
    if (gLastResult != FMOD_OK) return false;
    return playing != 0;
}
DEFINE_PRIM(_BOOL, cg_is_playing, _I32);

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
HL_PRIM int HL_NAME(cg_set_mix_matrix)(int h, vbyte* in, int outChannels, int inChannels, int inChannelHop) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    double* inFloats = (double*)in;
    float matrix[32 * 32];
    int i;
    int total;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    if (!matrix_args_ok(outChannels, inChannels, inChannelHop)) return (int)gLastResult;
    total = outChannels * (inChannelHop > 0 ? inChannelHop : inChannels);
    for (i = 0; i < total; i++) matrix[i] = (float)inFloats[i];
    gLastResult = FMOD_ChannelGroup_SetMixMatrix(group, matrix, outChannels, inChannels, inChannelHop);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, cg_set_mix_matrix, _I32 _BYTES _I32 _I32 _I32);

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

// Drain protocol: cb_next pops the oldest queued event into a static slot
// and the accessors read fields from it. Haxe thread only.
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
    /* Plugin records carry the DSP address. Turn it into a handle here on
     * the Haxe thread, in i1. A destroyed plugin's slot is freed right
     * away, the handle value still reaches the handler for identity. */
    if (gCbCurrent.type == FMOD_STUDIO_EVENT_CALLBACK_PLUGIN_CREATED) {
        gCbCurrent.i1 = faxe_handle_find_or_alloc(gCbCurrent.ptr, FAXE_TYPE_DSP);
    } else if (gCbCurrent.type == FMOD_STUDIO_EVENT_CALLBACK_PLUGIN_DESTROYED) {
        gCbCurrent.i1 = faxe_handle_find(gCbCurrent.ptr, FAXE_TYPE_DSP);
        if (gCbCurrent.i1) faxe_handle_free(gCbCurrent.i1);
    }
    gCbCurrent.ptr = NULL;
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

// GUID of the parameter description read last, in FMOD's text form.
static char gParamGuidBuf[40] = "";

// Copies a parameter description into the scratch buffers: name -> gStringBuf,
// fbuf [0]=min [1]=max [2]=default, ibuf [0]=type [1]=flags [2]=id1 [3]=id2,
// guid -> gParamGuidBuf (read back with sys_last_parameter_guid).
static void write_param_desc(const FMOD_STUDIO_PARAMETER_DESCRIPTION* desc, vbyte* fbuf, vbyte* ibuf) {
    double* outFloats = (double*)fbuf;
    int* outInts = (int*)ibuf;
    snprintf(gStringBuf, sizeof(gStringBuf), "%s", desc->name ? desc->name : "");
    faxe_guid_format(&desc->guid, gParamGuidBuf, sizeof(gParamGuidBuf));
    outFloats[0] = (double)desc->minimum;
    outFloats[1] = (double)desc->maximum;
    outFloats[2] = (double)desc->defaultvalue;
    outInts[0] = (int)desc->type;
    outInts[1] = (int)desc->flags;
    outInts[2] = (int)desc->id.data1;
    outInts[3] = (int)desc->id.data2;
}

HL_PRIM vbyte* HL_NAME(sys_last_parameter_guid)() {
    return (vbyte*)gParamGuidBuf;
}
DEFINE_PRIM(_BYTES, sys_last_parameter_guid, _NO_ARG);

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
// dspBufferLength/dspNumBuffers, softwareChannels, and streamBufferSize
// (bytes) are applied before initialize when nonzero. initFlags bit0 turns
// on FMOD_INIT_PROFILE_ENABLE, bit1 FMOD_INIT_CHANNEL_DISTANCEFILTER.
// The arguments after initFlags are the advanced settings. Zero (or an
// empty key) keeps FMOD's default for that field. Both structs are read
// back first so untouched fields keep whatever FMOD put there.
HL_PRIM int HL_NAME(sys_init_ex)(int numChannels, int sampleRate, int speakerMode, int studioFlags,
    int dspBufferLength, int dspNumBuffers, int softwareChannels, int streamBufferSize, int initFlags,
    int maxMPEGCodecs, int maxVorbisCodecs, int maxFADPCMCodecs, double vol0VirtualVol,
    int defaultDecodeBufferSize, int profilePort, int geometryMaxFadeTime, double distanceFilterCenterFreq,
    int randomSeed, int commandQueueSize, int handleInitialSize, int studioUpdatePeriod,
    int idleSampleDataPoolSize, int streamingScheduleDelay, vbyte* encryptionKey) {
    FMOD_ADVANCEDSETTINGS adv;
    FMOD_STUDIO_ADVANCEDSETTINGS sadv;
    const char* wavWriterPath;
    void* extradriverdata = NULL;
    FMOD_STUDIO_INITFLAGS studioInitFlags;
    FMOD_INITFLAGS coreInitFlags = FMOD_INIT_NORMAL;

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

    if (dspBufferLength > 0 || softwareChannels > 0 || streamBufferSize > 0) {
        FMOD_Studio_System_GetCoreSystem(gStudioSystem, &gCoreSystem);
        if (dspBufferLength > 0) {
            FMOD_System_SetDSPBufferSize(gCoreSystem, (unsigned int)dspBufferLength,
                dspNumBuffers > 0 ? dspNumBuffers : 2);
        }
        if (softwareChannels > 0) FMOD_System_SetSoftwareChannels(gCoreSystem, softwareChannels);
        if (streamBufferSize > 0) {
            FMOD_System_SetStreamBufferSize(gCoreSystem, (unsigned int)streamBufferSize, FMOD_TIMEUNIT_RAWBYTES);
        }
    }
    if (initFlags & 1) coreInitFlags |= FMOD_INIT_PROFILE_ENABLE;
    if (initFlags & 2) coreInitFlags |= FMOD_INIT_CHANNEL_DISTANCEFILTER;

    if (maxMPEGCodecs > 0 || maxVorbisCodecs > 0 || maxFADPCMCodecs > 0 || vol0VirtualVol > 0
        || defaultDecodeBufferSize > 0 || profilePort > 0 || geometryMaxFadeTime > 0
        || distanceFilterCenterFreq > 0 || randomSeed != 0) {
        FMOD_Studio_System_GetCoreSystem(gStudioSystem, &gCoreSystem);
        memset(&adv, 0, sizeof(adv));
        adv.cbSize = sizeof(adv);
        FMOD_System_GetAdvancedSettings(gCoreSystem, &adv);
        adv.cbSize = sizeof(adv);
        if (maxMPEGCodecs > 0) adv.maxMPEGCodecs = maxMPEGCodecs;
        if (maxVorbisCodecs > 0) adv.maxVorbisCodecs = maxVorbisCodecs;
        if (maxFADPCMCodecs > 0) adv.maxFADPCMCodecs = maxFADPCMCodecs;
        if (vol0VirtualVol > 0) adv.vol0virtualvol = (float)vol0VirtualVol;
        if (defaultDecodeBufferSize > 0) adv.defaultDecodeBufferSize = (unsigned int)defaultDecodeBufferSize;
        if (profilePort > 0) adv.profilePort = (unsigned short)profilePort;
        if (geometryMaxFadeTime > 0) adv.geometryMaxFadeTime = (unsigned int)geometryMaxFadeTime;
        if (distanceFilterCenterFreq > 0) adv.distanceFilterCenterFreq = (float)distanceFilterCenterFreq;
        if (randomSeed != 0) adv.randomSeed = (unsigned int)randomSeed;
        FMOD_System_SetAdvancedSettings(gCoreSystem, &adv);
    }
    if (commandQueueSize > 0 || handleInitialSize > 0 || studioUpdatePeriod > 0
        || idleSampleDataPoolSize > 0 || streamingScheduleDelay > 0
        || (encryptionKey != NULL && encryptionKey[0] != '\0')) {
        memset(&sadv, 0, sizeof(sadv));
        sadv.cbsize = sizeof(sadv);
        FMOD_Studio_System_GetAdvancedSettings(gStudioSystem, &sadv);
        sadv.cbsize = sizeof(sadv);
        if (commandQueueSize > 0) sadv.commandqueuesize = (unsigned int)commandQueueSize;
        if (handleInitialSize > 0) sadv.handleinitialsize = (unsigned int)handleInitialSize;
        if (studioUpdatePeriod > 0) sadv.studioupdateperiod = studioUpdatePeriod;
        if (idleSampleDataPoolSize > 0) sadv.idlesampledatapoolsize = idleSampleDataPoolSize;
        if (streamingScheduleDelay > 0) sadv.streamingscheduledelay = (unsigned int)streamingScheduleDelay;
        if (encryptionKey != NULL && encryptionKey[0] != '\0') sadv.encryptionkey = (const char*)encryptionKey;
        FMOD_Studio_System_SetAdvancedSettings(gStudioSystem, &sadv);
    }

    studioInitFlags = (studioFlags & 1) ? FMOD_STUDIO_INIT_LIVEUPDATE : FMOD_STUDIO_INIT_NORMAL;
    gLastResult = FMOD_Studio_System_Initialize(gStudioSystem, numChannels,
        studioInitFlags, coreInitFlags, extradriverdata);
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
DEFINE_PRIM(_I32, sys_init_ex, _I32 _I32 _I32 _I32 _I32 _I32 _I32 _I32 _I32 _I32 _I32 _I32 _F64 _I32 _I32 _I32 _F64 _I32 _I32 _I32 _I32 _I32 _I32 _BYTES);

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

// out = double[15]: position xyz, velocity xyz, forward xyz, up xyz,
// attenuation position xyz
HL_PRIM int HL_NAME(sys_get_listener_attributes)(int index, vbyte* out) {
    FMOD_3D_ATTRIBUTES attrs;
    FMOD_VECTOR attenuation;
    double* d = (double*)out;
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    memset(&attrs, 0, sizeof(attrs));
    memset(&attenuation, 0, sizeof(attenuation));
    gLastResult = FMOD_Studio_System_GetListenerAttributes(gStudioSystem, index, &attrs, &attenuation);
    unpack_3d_attributes(&attrs, d);
    d[12] = (double)attenuation.x;
    d[13] = (double)attenuation.y;
    d[14] = (double)attenuation.z;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_get_listener_attributes, _I32 _BYTES);

// f = double[15] laid out like the getter. With hasAttenuation false FMOD
// attenuates from the listener position and f[12..14] are ignored.
HL_PRIM int HL_NAME(sys_set_listener_attributes)(int index, vbyte* f, bool hasAttenuation) {
    FMOD_3D_ATTRIBUTES attrs;
    FMOD_VECTOR attenuation;
    double* d = (double*)f;
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    pack_3d_attributes(&attrs, d[0], d[1], d[2], d[3], d[4], d[5], d[6], d[7], d[8], d[9], d[10], d[11]);
    attenuation.x = (float)d[12];
    attenuation.y = (float)d[13];
    attenuation.z = (float)d[14];
    gLastResult = FMOD_Studio_System_SetListenerAttributes(gStudioSystem, index, &attrs,
        hasAttenuation ? &attenuation : NULL);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_set_listener_attributes, _I32 _BYTES _BOOL);

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
    hlaxe_stash_all_bank_paths();
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
    hlaxe_stash_bank_path(bank);
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

//// Distance filter, version, sound data, and recording

HL_PRIM int HL_NAME(chan_set_3d_distance_filter)(int h, bool custom, double customLevel, double centerFreq) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Channel_Set3DDistanceFilter(channel, custom ? 1 : 0, (float)customLevel, (float)centerFreq);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_set_3d_distance_filter, _I32 _BOOL _F64 _F64);

// out = double[3]: custom (1 or 0), custom level, center frequency
HL_PRIM int HL_NAME(chan_get_3d_distance_filter)(int h, vbyte* out) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    FMOD_BOOL custom = 0;
    float customLevel = 0.0f;
    float centerFreq = 0.0f;
    double* outFloats = (double*)out;
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Channel_Get3DDistanceFilter(channel, &custom, &customLevel, &centerFreq);
    outFloats[0] = custom ? 1.0 : 0.0;
    outFloats[1] = (double)customLevel;
    outFloats[2] = (double)centerFreq;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_get_3d_distance_filter, _I32 _BYTES);

HL_PRIM int HL_NAME(cg_set_3d_distance_filter)(int h, bool custom, double customLevel, double centerFreq) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_ChannelGroup_Set3DDistanceFilter(group, custom ? 1 : 0, (float)customLevel, (float)centerFreq);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, cg_set_3d_distance_filter, _I32 _BOOL _F64 _F64);

HL_PRIM int HL_NAME(cg_get_3d_distance_filter)(int h, vbyte* out) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    FMOD_BOOL custom = 0;
    float customLevel = 0.0f;
    float centerFreq = 0.0f;
    double* outFloats = (double*)out;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_ChannelGroup_Get3DDistanceFilter(group, &custom, &customLevel, &centerFreq);
    outFloats[0] = custom ? 1.0 : 0.0;
    outFloats[1] = (double)customLevel;
    outFloats[2] = (double)centerFreq;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, cg_get_3d_distance_filter, _I32 _BYTES);

// The version is BCD, so the fields print as hex: 0x00020312 is "2.03.12".
HL_PRIM vbyte* HL_NAME(sys_get_version)() {
    unsigned int version = 0;
    unsigned int build = 0;
    gStringBuf[0] = '\0';
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (vbyte*)gStringBuf; }
    gLastResult = FMOD_System_GetVersion(gCoreSystem, &version, &build);
    if (gLastResult != FMOD_OK) return (vbyte*)gStringBuf;
    snprintf(gStringBuf, sizeof(gStringBuf), "%x.%02x.%02x",
        version >> 16, (version >> 8) & 0xFF, version & 0xFF);
    return (vbyte*)gStringBuf;
}
DEFINE_PRIM(_BYTES, sys_get_version, _NO_ARG);

// Returns the bytes read, or the negated FMOD error. A short read at the
// end of the file still returns the count and leaves FMOD_ERR_FILE_EOF in
// gLastResult. The buffer length is trusted, the Haxe wrapper clamps it.
HL_PRIM int HL_NAME(core_sound_read_data)(int h, vbyte* data, int len) {
    FMOD_SOUND* sound = resolve_core_sound(h);
    unsigned int read = 0;
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return -(int)gLastResult; }
    if (!data || len <= 0) { gLastResult = FMOD_ERR_INVALID_PARAM; return -(int)gLastResult; }
    gLastResult = FMOD_Sound_ReadData(sound, data, (unsigned int)len, &read);
    if (gLastResult != FMOD_OK && gLastResult != FMOD_ERR_FILE_EOF) return -(int)gLastResult;
    return (int)read;
}
DEFINE_PRIM(_I32, core_sound_read_data, _I32 _BYTES _I32);

HL_PRIM int HL_NAME(core_sound_seek_data)(int h, int pcm) {
    FMOD_SOUND* sound = resolve_core_sound(h);
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    if (pcm < 0) { gLastResult = FMOD_ERR_INVALID_PARAM; return (int)gLastResult; }
    gLastResult = FMOD_Sound_SeekData(sound, (unsigned int)pcm);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, core_sound_seek_data, _I32 _I32);

// out = int[1]: connected drivers. Returns the total, -1 on failure.
HL_PRIM int HL_NAME(sys_get_record_num_drivers)(vbyte* out) {
    int total = 0;
    int connected = 0;
    int* outInts = (int*)out;
    outInts[0] = 0;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return -1; }
    gLastResult = FMOD_System_GetRecordNumDrivers(gCoreSystem, &total, &connected);
    if (gLastResult != FMOD_OK) return -1;
    outInts[0] = connected;
    return total;
}
DEFINE_PRIM(_I32, sys_get_record_num_drivers, _BYTES);

// out = int[4]: system rate, speaker mode, channels, driver state
HL_PRIM vbyte* HL_NAME(sys_get_record_driver_info)(int id, vbyte* out) {
    int rate = 0;
    FMOD_SPEAKERMODE mode = FMOD_SPEAKERMODE_DEFAULT;
    int channels = 0;
    FMOD_DRIVER_STATE state = 0;
    int* outInts = (int*)out;
    gStringBuf[0] = '\0';
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (vbyte*)gStringBuf; }
    gLastResult = FMOD_System_GetRecordDriverInfo(gCoreSystem, id, gStringBuf, sizeof(gStringBuf),
        NULL, &rate, &mode, &channels, &state);
    if (gLastResult != FMOD_OK) gStringBuf[0] = '\0';
    outInts[0] = rate;
    outInts[1] = (int)mode;
    outInts[2] = channels;
    outInts[3] = (int)state;
    return (vbyte*)gStringBuf;
}
DEFINE_PRIM(_BYTES, sys_get_record_driver_info, _I32 _BYTES);

// An empty OPENUSER PCM16 sound of the given length for RecordStart to
// fill. No callbacks, FMOD writes straight into the sample buffer.
HL_PRIM int HL_NAME(core_create_record_sound)(int sampleRate, int channels, int seconds) {
    FMOD_CREATESOUNDEXINFO exinfo;
    FMOD_SOUND* sound = NULL;
    int handle;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    if (sampleRate <= 0 || channels < 1 || channels > 2 || seconds <= 0) {
        gLastResult = FMOD_ERR_INVALID_PARAM;
        return 0;
    }
    memset(&exinfo, 0, sizeof(exinfo));
    exinfo.cbsize = sizeof(exinfo);
    exinfo.numchannels = channels;
    exinfo.defaultfrequency = sampleRate;
    exinfo.format = FMOD_SOUND_FORMAT_PCM16;
    exinfo.length = (unsigned int)sampleRate * (unsigned int)channels * 2u * (unsigned int)seconds;
    gLastResult = FMOD_System_CreateSound(gCoreSystem, NULL, FMOD_OPENUSER | FMOD_LOOP_NORMAL, &exinfo, &sound);
    if (gLastResult != FMOD_OK || !sound) return 0;
    handle = faxe_handle_alloc(sound, FAXE_TYPE_SOUND);
    if (handle == 0) {
        gLastResult = FMOD_ERR_MEMORY; /* handle table exhausted */
        FMOD_Sound_Release(sound);
        return 0;
    }
    return handle;
}
DEFINE_PRIM(_I32, core_create_record_sound, _I32 _I32 _I32);

HL_PRIM int HL_NAME(sys_record_start)(int id, int soundHandle, bool loop) {
    FMOD_SOUND* sound = resolve_core_sound(soundHandle);
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_System_RecordStart(gCoreSystem, id, sound, loop ? 1 : 0);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_record_start, _I32 _I32 _BOOL);

HL_PRIM int HL_NAME(sys_record_stop)(int id) {
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = FMOD_System_RecordStop(gCoreSystem, id);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_record_stop, _I32);

HL_PRIM bool HL_NAME(sys_is_recording)(int id) {
    FMOD_BOOL recording = 0;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return false; }
    gLastResult = FMOD_System_IsRecording(gCoreSystem, id, &recording);
    return recording != 0;
}
DEFINE_PRIM(_BOOL, sys_is_recording, _I32);

HL_PRIM int HL_NAME(sys_get_record_position)(int id) {
    unsigned int position = 0;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return -1; }
    gLastResult = FMOD_System_GetRecordPosition(gCoreSystem, id, &position);
    if (gLastResult != FMOD_OK) return -1;
    return (int)position;
}
DEFINE_PRIM(_I32, sys_get_record_position, _I32);

//// Custom 3D rolloff

// Copies packed float32 xyz triples into a malloc'd FMOD_VECTOR array the
// slot owns until the handle dies. NULL with count 0 means clear.
static FMOD_VECTOR* rolloff_copy(vbyte* data, int count) {
    FMOD_VECTOR* points;
    const float* f = (const float*)data;
    int i;
    if (!data || count <= 0) return NULL;
    points = (FMOD_VECTOR*)malloc(sizeof(FMOD_VECTOR) * (size_t)count);
    if (!points) return NULL;
    for (i = 0; i < count; i++) {
        points[i].x = f[i * 3];
        points[i].y = f[i * 3 + 1];
        points[i].z = f[i * 3 + 2];
    }
    return points;
}

// out = double[count*3], capped at FAXE_LIST_MAX doubles. Returns the count.
static int rolloff_unpack(FMOD_VECTOR* points, int count, double* out) {
    int i;
    if (!points || count < 0) count = 0;
    if (count > FAXE_LIST_MAX / 3) count = FAXE_LIST_MAX / 3;
    for (i = 0; i < count; i++) {
        out[i * 3] = (double)points[i].x;
        out[i * 3 + 1] = (double)points[i].y;
        out[i * 3 + 2] = (double)points[i].z;
    }
    return count;
}

HL_PRIM int HL_NAME(chan_set_3d_custom_rolloff)(int h, vbyte* data, int count) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    FMOD_VECTOR* points;
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    if (count < 0) { gLastResult = FMOD_ERR_INVALID_PARAM; return (int)gLastResult; }
    points = rolloff_copy(data, count);
    if (count > 0 && !points) { gLastResult = FMOD_ERR_MEMORY; return (int)gLastResult; }
    gLastResult = FMOD_Channel_Set3DCustomRolloff(channel, points, points ? count : 0);
    if (gLastResult != FMOD_OK) { free(points); return (int)gLastResult; }
    faxe_handle_set_aux(h, points);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_set_3d_custom_rolloff, _I32 _BYTES _I32);

HL_PRIM int HL_NAME(chan_get_3d_custom_rolloff)(int h, vbyte* out) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    FMOD_VECTOR* points = NULL;
    int count = 0;
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return -1; }
    gLastResult = FMOD_Channel_Get3DCustomRolloff(channel, &points, &count);
    if (gLastResult != FMOD_OK) return -1;
    return rolloff_unpack(points, count, (double*)out);
}
DEFINE_PRIM(_I32, chan_get_3d_custom_rolloff, _I32 _BYTES);

HL_PRIM int HL_NAME(cg_set_3d_custom_rolloff)(int h, vbyte* data, int count) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    FMOD_VECTOR* points;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    if (count < 0) { gLastResult = FMOD_ERR_INVALID_PARAM; return (int)gLastResult; }
    points = rolloff_copy(data, count);
    if (count > 0 && !points) { gLastResult = FMOD_ERR_MEMORY; return (int)gLastResult; }
    gLastResult = FMOD_ChannelGroup_Set3DCustomRolloff(group, points, points ? count : 0);
    if (gLastResult != FMOD_OK) { free(points); return (int)gLastResult; }
    faxe_handle_set_aux(h, points);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, cg_set_3d_custom_rolloff, _I32 _BYTES _I32);

HL_PRIM int HL_NAME(cg_get_3d_custom_rolloff)(int h, vbyte* out) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    FMOD_VECTOR* points = NULL;
    int count = 0;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return -1; }
    gLastResult = FMOD_ChannelGroup_Get3DCustomRolloff(group, &points, &count);
    if (gLastResult != FMOD_OK) return -1;
    return rolloff_unpack(points, count, (double*)out);
}
DEFINE_PRIM(_I32, cg_get_3d_custom_rolloff, _I32 _BYTES);

HL_PRIM int HL_NAME(core_sound_set_3d_custom_rolloff)(int h, vbyte* data, int count) {
    FMOD_SOUND* sound = resolve_core_sound(h);
    FMOD_VECTOR* points;
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    if (count < 0) { gLastResult = FMOD_ERR_INVALID_PARAM; return (int)gLastResult; }
    points = rolloff_copy(data, count);
    if (count > 0 && !points) { gLastResult = FMOD_ERR_MEMORY; return (int)gLastResult; }
    gLastResult = FMOD_Sound_Set3DCustomRolloff(sound, points, points ? count : 0);
    if (gLastResult != FMOD_OK) { free(points); return (int)gLastResult; }
    faxe_handle_set_aux(h, points);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, core_sound_set_3d_custom_rolloff, _I32 _BYTES _I32);

HL_PRIM int HL_NAME(core_sound_get_3d_custom_rolloff)(int h, vbyte* out) {
    FMOD_SOUND* sound = resolve_core_sound(h);
    FMOD_VECTOR* points = NULL;
    int count = 0;
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return -1; }
    gLastResult = FMOD_Sound_Get3DCustomRolloff(sound, &points, &count);
    if (gLastResult != FMOD_OK) return -1;
    return rolloff_unpack(points, count, (double*)out);
}
DEFINE_PRIM(_I32, core_sound_get_3d_custom_rolloff, _I32 _BYTES);

//// Geometry

static FMOD_GEOMETRY* resolve_geometry(int h) {
    return (FMOD_GEOMETRY*)faxe_handle_resolve(h, FAXE_TYPE_GEOMETRY);
}

static int geometry_handle(FMOD_GEOMETRY* geometry) {
    int handle = faxe_handle_alloc(geometry, FAXE_TYPE_GEOMETRY);
    if (handle == 0) {
        gLastResult = FMOD_ERR_MEMORY; /* handle table exhausted */
        FMOD_Geometry_Release(geometry);
    }
    return handle;
}

HL_PRIM int HL_NAME(sys_create_geometry)(int maxPolygons, int maxVertices) {
    FMOD_GEOMETRY* geometry = NULL;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    gLastResult = FMOD_System_CreateGeometry(gCoreSystem, maxPolygons, maxVertices, &geometry);
    if (gLastResult != FMOD_OK || !geometry) return 0;
    return geometry_handle(geometry);
}
DEFINE_PRIM(_I32, sys_create_geometry, _I32 _I32);

HL_PRIM int HL_NAME(sys_set_geometry_settings)(double maxWorldSize) {
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = FMOD_System_SetGeometrySettings(gCoreSystem, (float)maxWorldSize);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_set_geometry_settings, _F64);

HL_PRIM double HL_NAME(sys_get_geometry_settings)() {
    float maxWorldSize = 0.0f;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0.0; }
    gLastResult = FMOD_System_GetGeometrySettings(gCoreSystem, &maxWorldSize);
    if (gLastResult != FMOD_OK) return 0.0;
    return (double)maxWorldSize;
}
DEFINE_PRIM(_F64, sys_get_geometry_settings, _NO_ARG);

// out = double[2]: direct, reverb
HL_PRIM int HL_NAME(sys_get_geometry_occlusion)(double lx, double ly, double lz,
        double sx, double sy, double sz, vbyte* out) {
    FMOD_VECTOR listener;
    FMOD_VECTOR source;
    float direct = 0.0f;
    float reverb = 0.0f;
    double* outFloats = (double*)out;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    listener.x = (float)lx; listener.y = (float)ly; listener.z = (float)lz;
    source.x = (float)sx; source.y = (float)sy; source.z = (float)sz;
    gLastResult = FMOD_System_GetGeometryOcclusion(gCoreSystem, &listener, &source, &direct, &reverb);
    outFloats[0] = (double)direct;
    outFloats[1] = (double)reverb;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_get_geometry_occlusion, _F64 _F64 _F64 _F64 _F64 _F64 _BYTES);

HL_PRIM int HL_NAME(sys_load_geometry)(vbyte* data, int len) {
    FMOD_GEOMETRY* geometry = NULL;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    if (!data || len <= 0) { gLastResult = FMOD_ERR_INVALID_PARAM; return 0; }
    gLastResult = FMOD_System_LoadGeometry(gCoreSystem, data, len, &geometry);
    if (gLastResult != FMOD_OK || !geometry) return 0;
    return geometry_handle(geometry);
}
DEFINE_PRIM(_I32, sys_load_geometry, _BYTES _I32);

HL_PRIM int HL_NAME(geo_release)(int h) {
    FMOD_GEOMETRY* geometry = resolve_geometry(h);
    if (!geometry) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Geometry_Release(geometry);
    if (gLastResult == FMOD_OK) faxe_handle_free(h);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, geo_release, _I32);

// vertices = packed float32 xyz triples. Returns the polygon index, -1 on failure.
HL_PRIM int HL_NAME(geo_add_polygon)(int h, double direct, double reverb, bool doubleSided,
        vbyte* vertices, int count) {
    FMOD_GEOMETRY* geometry = resolve_geometry(h);
    FMOD_VECTOR* points;
    int index = -1;
    if (!geometry) { gLastResult = FMOD_ERR_INVALID_HANDLE; return -1; }
    if (!vertices || count < 3) { gLastResult = FMOD_ERR_INVALID_PARAM; return -1; }
    points = rolloff_copy(vertices, count);
    if (!points) { gLastResult = FMOD_ERR_MEMORY; return -1; }
    gLastResult = FMOD_Geometry_AddPolygon(geometry, (float)direct, (float)reverb,
        doubleSided ? 1 : 0, count, points, &index);
    free(points);
    if (gLastResult != FMOD_OK) return -1;
    return index;
}
DEFINE_PRIM(_I32, geo_add_polygon, _I32 _F64 _F64 _BOOL _BYTES _I32);

HL_PRIM int HL_NAME(geo_get_num_polygons)(int h) {
    FMOD_GEOMETRY* geometry = resolve_geometry(h);
    int count = 0;
    if (!geometry) { gLastResult = FMOD_ERR_INVALID_HANDLE; return -1; }
    gLastResult = FMOD_Geometry_GetNumPolygons(geometry, &count);
    if (gLastResult != FMOD_OK) return -1;
    return count;
}
DEFINE_PRIM(_I32, geo_get_num_polygons, _I32);

// out = int[2]: max polygons, max vertices
HL_PRIM int HL_NAME(geo_get_max_polygons)(int h, vbyte* out) {
    FMOD_GEOMETRY* geometry = resolve_geometry(h);
    int maxPolygons = 0;
    int maxVertices = 0;
    int* outInts = (int*)out;
    if (!geometry) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Geometry_GetMaxPolygons(geometry, &maxPolygons, &maxVertices);
    outInts[0] = maxPolygons;
    outInts[1] = maxVertices;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, geo_get_max_polygons, _I32 _BYTES);

HL_PRIM int HL_NAME(geo_get_polygon_num_vertices)(int h, int index) {
    FMOD_GEOMETRY* geometry = resolve_geometry(h);
    int count = 0;
    if (!geometry) { gLastResult = FMOD_ERR_INVALID_HANDLE; return -1; }
    gLastResult = FMOD_Geometry_GetPolygonNumVertices(geometry, index, &count);
    if (gLastResult != FMOD_OK) return -1;
    return count;
}
DEFINE_PRIM(_I32, geo_get_polygon_num_vertices, _I32 _I32);

HL_PRIM int HL_NAME(geo_set_polygon_vertex)(int h, int index, int vertexIndex, double x, double y, double z) {
    FMOD_GEOMETRY* geometry = resolve_geometry(h);
    FMOD_VECTOR vertex;
    if (!geometry) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    vertex.x = (float)x; vertex.y = (float)y; vertex.z = (float)z;
    gLastResult = FMOD_Geometry_SetPolygonVertex(geometry, index, vertexIndex, &vertex);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, geo_set_polygon_vertex, _I32 _I32 _I32 _F64 _F64 _F64);

// out = double[3]: x, y, z
HL_PRIM int HL_NAME(geo_get_polygon_vertex)(int h, int index, int vertexIndex, vbyte* out) {
    FMOD_GEOMETRY* geometry = resolve_geometry(h);
    FMOD_VECTOR vertex;
    double* outFloats = (double*)out;
    if (!geometry) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    memset(&vertex, 0, sizeof(vertex));
    gLastResult = FMOD_Geometry_GetPolygonVertex(geometry, index, vertexIndex, &vertex);
    outFloats[0] = (double)vertex.x;
    outFloats[1] = (double)vertex.y;
    outFloats[2] = (double)vertex.z;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, geo_get_polygon_vertex, _I32 _I32 _I32 _BYTES);

HL_PRIM int HL_NAME(geo_set_polygon_attributes)(int h, int index, double direct, double reverb, bool doubleSided) {
    FMOD_GEOMETRY* geometry = resolve_geometry(h);
    if (!geometry) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Geometry_SetPolygonAttributes(geometry, index, (float)direct, (float)reverb,
        doubleSided ? 1 : 0);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, geo_set_polygon_attributes, _I32 _I32 _F64 _F64 _BOOL);

// out = double[3]: direct, reverb, doubleSided (1.0 or 0.0)
HL_PRIM int HL_NAME(geo_get_polygon_attributes)(int h, int index, vbyte* out) {
    FMOD_GEOMETRY* geometry = resolve_geometry(h);
    float direct = 0.0f;
    float reverb = 0.0f;
    FMOD_BOOL doubleSided = 0;
    double* outFloats = (double*)out;
    if (!geometry) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Geometry_GetPolygonAttributes(geometry, index, &direct, &reverb, &doubleSided);
    outFloats[0] = (double)direct;
    outFloats[1] = (double)reverb;
    outFloats[2] = doubleSided ? 1.0 : 0.0;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, geo_get_polygon_attributes, _I32 _I32 _BYTES);

HL_PRIM int HL_NAME(geo_set_active)(int h, bool active) {
    FMOD_GEOMETRY* geometry = resolve_geometry(h);
    if (!geometry) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Geometry_SetActive(geometry, active ? 1 : 0);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, geo_set_active, _I32 _BOOL);

HL_PRIM bool HL_NAME(geo_get_active)(int h) {
    FMOD_GEOMETRY* geometry = resolve_geometry(h);
    FMOD_BOOL active = 0;
    if (!geometry) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    gLastResult = FMOD_Geometry_GetActive(geometry, &active);
    return active != 0;
}
DEFINE_PRIM(_BOOL, geo_get_active, _I32);

HL_PRIM int HL_NAME(geo_set_rotation)(int h, double fx, double fy, double fz, double ux, double uy, double uz) {
    FMOD_GEOMETRY* geometry = resolve_geometry(h);
    FMOD_VECTOR forward;
    FMOD_VECTOR up;
    if (!geometry) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    forward.x = (float)fx; forward.y = (float)fy; forward.z = (float)fz;
    up.x = (float)ux; up.y = (float)uy; up.z = (float)uz;
    gLastResult = FMOD_Geometry_SetRotation(geometry, &forward, &up);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, geo_set_rotation, _I32 _F64 _F64 _F64 _F64 _F64 _F64);

// out = double[6]: forward xyz, up xyz
HL_PRIM int HL_NAME(geo_get_rotation)(int h, vbyte* out) {
    FMOD_GEOMETRY* geometry = resolve_geometry(h);
    FMOD_VECTOR forward;
    FMOD_VECTOR up;
    double* outFloats = (double*)out;
    if (!geometry) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    memset(&forward, 0, sizeof(forward));
    memset(&up, 0, sizeof(up));
    gLastResult = FMOD_Geometry_GetRotation(geometry, &forward, &up);
    outFloats[0] = (double)forward.x; outFloats[1] = (double)forward.y; outFloats[2] = (double)forward.z;
    outFloats[3] = (double)up.x; outFloats[4] = (double)up.y; outFloats[5] = (double)up.z;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, geo_get_rotation, _I32 _BYTES);

HL_PRIM int HL_NAME(geo_set_position)(int h, double x, double y, double z) {
    FMOD_GEOMETRY* geometry = resolve_geometry(h);
    FMOD_VECTOR position;
    if (!geometry) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    position.x = (float)x; position.y = (float)y; position.z = (float)z;
    gLastResult = FMOD_Geometry_SetPosition(geometry, &position);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, geo_set_position, _I32 _F64 _F64 _F64);

// out = double[3]: x, y, z
HL_PRIM int HL_NAME(geo_get_position)(int h, vbyte* out) {
    FMOD_GEOMETRY* geometry = resolve_geometry(h);
    FMOD_VECTOR position;
    double* outFloats = (double*)out;
    if (!geometry) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    memset(&position, 0, sizeof(position));
    gLastResult = FMOD_Geometry_GetPosition(geometry, &position);
    outFloats[0] = (double)position.x;
    outFloats[1] = (double)position.y;
    outFloats[2] = (double)position.z;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, geo_get_position, _I32 _BYTES);

HL_PRIM int HL_NAME(geo_set_scale)(int h, double x, double y, double z) {
    FMOD_GEOMETRY* geometry = resolve_geometry(h);
    FMOD_VECTOR scale;
    if (!geometry) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    scale.x = (float)x; scale.y = (float)y; scale.z = (float)z;
    gLastResult = FMOD_Geometry_SetScale(geometry, &scale);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, geo_set_scale, _I32 _F64 _F64 _F64);

// out = double[3]: x, y, z
HL_PRIM int HL_NAME(geo_get_scale)(int h, vbyte* out) {
    FMOD_GEOMETRY* geometry = resolve_geometry(h);
    FMOD_VECTOR scale;
    double* outFloats = (double*)out;
    if (!geometry) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    memset(&scale, 0, sizeof(scale));
    gLastResult = FMOD_Geometry_GetScale(geometry, &scale);
    outFloats[0] = (double)scale.x;
    outFloats[1] = (double)scale.y;
    outFloats[2] = (double)scale.z;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, geo_get_scale, _I32 _BYTES);

// Returns the serialized size. A null buffer (or len 0) only sizes, so the
// Haxe wrapper calls twice. A buffer shorter than the size is rejected
// before FMOD writes anything. The buffer length is trusted, the wrapper
// allocates it to the size it was just told.
HL_PRIM int HL_NAME(geo_save)(int h, vbyte* data, int len) {
    FMOD_GEOMETRY* geometry = resolve_geometry(h);
    int size = 0;
    if (!geometry) { gLastResult = FMOD_ERR_INVALID_HANDLE; return -1; }
    gLastResult = FMOD_Geometry_Save(geometry, NULL, &size);
    if (gLastResult != FMOD_OK) return -1;
    if (!data || len <= 0) return size;
    if (len < size) { gLastResult = FMOD_ERR_INVALID_PARAM; return -1; }
    gLastResult = FMOD_Geometry_Save(geometry, data, &size);
    if (gLastResult != FMOD_OK) return -1;
    return size;
}
DEFINE_PRIM(_I32, geo_save, _I32 _BYTES _I32);

//// Completeness tail: getters and setters on objects the library already wraps

HL_PRIM int HL_NAME(core_sound_set_3d_cone_settings)(int h, double inside, double outside, double outsideVolume) {
    FMOD_SOUND* sound = resolve_core_sound(h);
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Sound_Set3DConeSettings(sound, (float)inside, (float)outside, (float)outsideVolume);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, core_sound_set_3d_cone_settings, _I32 _F64 _F64 _F64);

// out = double[3]: inside angle, outside angle, outside volume
HL_PRIM int HL_NAME(core_sound_get_3d_cone_settings)(int h, vbyte* out) {
    FMOD_SOUND* sound = resolve_core_sound(h);
    float inside = 0.0f;
    float outside = 0.0f;
    float outsideVolume = 0.0f;
    double* outFloats = (double*)out;
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Sound_Get3DConeSettings(sound, &inside, &outside, &outsideVolume);
    outFloats[0] = (double)inside;
    outFloats[1] = (double)outside;
    outFloats[2] = (double)outsideVolume;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, core_sound_get_3d_cone_settings, _I32 _BYTES);

HL_PRIM int HL_NAME(core_sound_set_3d_min_max)(int h, double minDistance, double maxDistance) {
    FMOD_SOUND* sound = resolve_core_sound(h);
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Sound_Set3DMinMaxDistance(sound, (float)minDistance, (float)maxDistance);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, core_sound_set_3d_min_max, _I32 _F64 _F64);

// out = double[2]: min, max
HL_PRIM int HL_NAME(core_sound_get_3d_min_max)(int h, vbyte* out) {
    FMOD_SOUND* sound = resolve_core_sound(h);
    float minDistance = 0.0f;
    float maxDistance = 0.0f;
    double* outFloats = (double*)out;
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Sound_Get3DMinMaxDistance(sound, &minDistance, &maxDistance);
    outFloats[0] = (double)minDistance;
    outFloats[1] = (double)maxDistance;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, core_sound_get_3d_min_max, _I32 _BYTES);

HL_PRIM int HL_NAME(chan_set_dsp_index)(int h, int dspHandle, int index) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    FMOD_DSP* dsp = resolve_dsp(dspHandle);
    if (!channel || !dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Channel_SetDSPIndex(channel, dsp, index);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_set_dsp_index, _I32 _I32 _I32);

HL_PRIM int HL_NAME(chan_get_dsp_index)(int h, int dspHandle) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    FMOD_DSP* dsp = resolve_dsp(dspHandle);
    int index = -1;
    if (!channel || !dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return -1; }
    gLastResult = FMOD_Channel_GetDSPIndex(channel, dsp, &index);
    return gLastResult == FMOD_OK ? index : -1;
}
DEFINE_PRIM(_I32, chan_get_dsp_index, _I32 _I32);

// Fade points cross as (clock, volume) pairs. The scratch buffer holds
// FAXE_LIST_MAX doubles, so at most FAXE_LIST_MAX/2 points come back.
#define FAXE_FADE_POINT_MAX (FAXE_LIST_MAX / 2)
static unsigned long long gFadeClocks[FAXE_FADE_POINT_MAX];
static float gFadeVolumes[FAXE_FADE_POINT_MAX];

static int write_fade_points(unsigned int count, vbyte* out) {
    double* outFloats = (double*)out;
    unsigned int i;
    if (count > FAXE_FADE_POINT_MAX) count = FAXE_FADE_POINT_MAX;
    for (i = 0; i < count; i++) {
        outFloats[i * 2] = (double)gFadeClocks[i];
        outFloats[i * 2 + 1] = (double)gFadeVolumes[i];
    }
    return (int)count;
}

// out = double[2*count]: clock, volume per point. Returns the count.
HL_PRIM int HL_NAME(chan_get_fade_points)(int h, vbyte* out) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    unsigned int count = FAXE_FADE_POINT_MAX;
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_Channel_GetFadePoints(channel, &count, gFadeClocks, gFadeVolumes);
    if (gLastResult != FMOD_OK) return 0;
    return write_fade_points(count, out);
}
DEFINE_PRIM(_I32, chan_get_fade_points, _I32 _BYTES);

// Shared by the three mix matrix getters. The caller names the region it
// wants (outChannels rows of inChannels gains) and gets that region back
// row-major in fout, with the object's real counts in iout[0] and iout[1].
// Callers make the FMOD call before this one, since the counts are only
// valid after it returns.
static float gMatrixBuf[32 * 32];

// Copies outActual rows of stride floats (the hop, or inActual when the
// hop is 0) out of gMatrixBuf and returns that count, 0 on failure.
static int write_mix_matrix(FMOD_RESULT result, int outActual, int inActual, int inChannelHop, vbyte* fout, vbyte* iout) {
    double* outFloats = (double*)fout;
    int* outInts = (int*)iout;
    int stride = inChannelHop > 0 ? inChannelHop : inActual;
    int total = outActual * stride;
    int i;
    gLastResult = result;
    if (result != FMOD_OK) return 0;
    if (total < 0 || total > 32 * 32) { gLastResult = FMOD_ERR_INVALID_PARAM; return 0; }
    for (i = 0; i < total; i++) outFloats[i] = (double)gMatrixBuf[i];
    outInts[0] = outActual;
    outInts[1] = inActual;
    return total;
}

// A read hop of 0 means packed rows. 32 is the widest matrix FMOD mixes.
static int matrix_hop_ok(int inChannelHop) {
    if (inChannelHop < 0 || inChannelHop > 32) {
        gLastResult = FMOD_ERR_INVALID_PARAM;
        return 0;
    }
    return 1;
}

HL_PRIM int HL_NAME(chan_get_mix_matrix)(int h, vbyte* fout, vbyte* iout, int inChannelHop) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    int outActual = 0;
    int inActual = 0;
    FMOD_RESULT result;
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    if (!matrix_hop_ok(inChannelHop)) return 0;
    result = FMOD_Channel_GetMixMatrix(channel, gMatrixBuf, &outActual, &inActual, inChannelHop);
    return write_mix_matrix(result, outActual, inActual, inChannelHop, fout, iout);
}
DEFINE_PRIM(_I32, chan_get_mix_matrix, _I32 _BYTES _BYTES _I32);

HL_PRIM int HL_NAME(chan_get_channel_group)(int h) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    FMOD_CHANNELGROUP* group = NULL;
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_Channel_GetChannelGroup(channel, &group);
    if (gLastResult != FMOD_OK || !group) return 0;
    return faxe_handle_find_or_alloc(group, FAXE_TYPE_CHANGROUP);
}
DEFINE_PRIM(_I32, chan_get_channel_group, _I32);

HL_PRIM int HL_NAME(cg_set_dsp_index)(int h, int dspHandle, int index) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    FMOD_DSP* dsp = resolve_dsp(dspHandle);
    if (!group || !dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_ChannelGroup_SetDSPIndex(group, dsp, index);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, cg_set_dsp_index, _I32 _I32 _I32);

HL_PRIM int HL_NAME(cg_get_dsp_index)(int h, int dspHandle) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    FMOD_DSP* dsp = resolve_dsp(dspHandle);
    int index = -1;
    if (!group || !dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return -1; }
    gLastResult = FMOD_ChannelGroup_GetDSPIndex(group, dsp, &index);
    return gLastResult == FMOD_OK ? index : -1;
}
DEFINE_PRIM(_I32, cg_get_dsp_index, _I32 _I32);

HL_PRIM int HL_NAME(cg_get_fade_points)(int h, vbyte* out) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    unsigned int count = FAXE_FADE_POINT_MAX;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_ChannelGroup_GetFadePoints(group, &count, gFadeClocks, gFadeVolumes);
    if (gLastResult != FMOD_OK) return 0;
    return write_fade_points(count, out);
}
DEFINE_PRIM(_I32, cg_get_fade_points, _I32 _BYTES);

HL_PRIM int HL_NAME(cg_get_mix_matrix)(int h, vbyte* fout, vbyte* iout, int inChannelHop) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    int outActual = 0;
    int inActual = 0;
    FMOD_RESULT result;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    if (!matrix_hop_ok(inChannelHop)) return 0;
    result = FMOD_ChannelGroup_GetMixMatrix(group, gMatrixBuf, &outActual, &inActual, inChannelHop);
    return write_mix_matrix(result, outActual, inActual, inChannelHop, fout, iout);
}
DEFINE_PRIM(_I32, cg_get_mix_matrix, _I32 _BYTES _BYTES _I32);

HL_PRIM vbyte* HL_NAME(sg_get_name)(int h) {
    FMOD_SOUNDGROUP* group = resolve_soundgroup(h);
    gStringBuf[0] = '\0';
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (vbyte*)gStringBuf; }
    gLastResult = FMOD_SoundGroup_GetName(group, gStringBuf, sizeof(gStringBuf));
    if (gLastResult != FMOD_OK) gStringBuf[0] = '\0';
    return (vbyte*)gStringBuf;
}
DEFINE_PRIM(_BYTES, sg_get_name, _I32);

// Borrowed reference, the group does not own the sound
HL_PRIM int HL_NAME(sg_get_sound)(int h, int index) {
    FMOD_SOUNDGROUP* group = resolve_soundgroup(h);
    FMOD_SOUND* sound = NULL;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_SoundGroup_GetSound(group, index, &sound);
    if (gLastResult != FMOD_OK || !sound) return 0;
    return faxe_handle_find_or_alloc(sound, FAXE_TYPE_SOUND);
}
DEFINE_PRIM(_I32, sg_get_sound, _I32 _I32);

// The pool channel at this index. It may be idle, in which case every call
// on the handle reports FMOD_ERR_INVALID_HANDLE until FMOD reuses it.
HL_PRIM int HL_NAME(sys_get_channel)(int index) {
    FMOD_CHANNEL* channel = NULL;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    gLastResult = FMOD_System_GetChannel(gCoreSystem, index, &channel);
    if (gLastResult != FMOD_OK || !channel) return 0;
    return faxe_handle_find_or_alloc(channel, FAXE_TYPE_CHAN);
}
DEFINE_PRIM(_I32, sys_get_channel, _I32);

HL_PRIM int HL_NAME(sys_get_output)() {
    FMOD_OUTPUTTYPE output = FMOD_OUTPUTTYPE_AUTODETECT;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return -1; }
    gLastResult = FMOD_System_GetOutput(gCoreSystem, &output);
    return gLastResult == FMOD_OK ? (int)output : -1;
}
DEFINE_PRIM(_I32, sys_get_output, _NO_ARG);

HL_PRIM int HL_NAME(sys_get_speaker_mode_channels)(int mode) {
    int channels = 0;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    gLastResult = FMOD_System_GetSpeakerModeChannels(gCoreSystem, (FMOD_SPEAKERMODE)mode, &channels);
    return gLastResult == FMOD_OK ? channels : 0;
}
DEFINE_PRIM(_I32, sys_get_speaker_mode_channels, _I32);

// out = double[target channels * hop]. hop 0 means the source channel count.
HL_PRIM int HL_NAME(sys_get_default_mix_matrix)(int sourceMode, int targetMode, int hop, vbyte* out) {
    double* outFloats = (double*)out;
    int sourceChannels = 0;
    int targetChannels = 0;
    int total;
    int i;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    gLastResult = FMOD_System_GetSpeakerModeChannels(gCoreSystem, (FMOD_SPEAKERMODE)sourceMode, &sourceChannels);
    if (gLastResult != FMOD_OK) return 0;
    gLastResult = FMOD_System_GetSpeakerModeChannels(gCoreSystem, (FMOD_SPEAKERMODE)targetMode, &targetChannels);
    if (gLastResult != FMOD_OK) return 0;
    if (hop <= 0) hop = sourceChannels;
    total = targetChannels * hop;
    if (hop < sourceChannels || total < 1 || total > 32 * 32) { gLastResult = FMOD_ERR_INVALID_PARAM; return 0; }
    for (i = 0; i < total; i++) gMatrixBuf[i] = 0.0f;
    gLastResult = FMOD_System_GetDefaultMixMatrix(gCoreSystem, (FMOD_SPEAKERMODE)sourceMode, (FMOD_SPEAKERMODE)targetMode, gMatrixBuf, hop);
    if (gLastResult != FMOD_OK) return 0;
    for (i = 0; i < total; i++) outFloats[i] = (double)gMatrixBuf[i];
    return total;
}
DEFINE_PRIM(_I32, sys_get_default_mix_matrix, _I32 _I32 _I32 _BYTES);

// Layout in faxe_dspdata.h: fbuf min, max, default and the mapping
// points, ibuf type, mapping type, goes-to-infinity, data type, point
// count. Returns the name.
HL_PRIM vbyte* HL_NAME(dsp_get_parameter_info)(int h, int index, vbyte* fout, vbyte* iout) {
    FMOD_DSP* dsp = resolve_dsp(h);
    FMOD_DSP_PARAMETER_DESC* desc = NULL;
    double* outFloats = (double*)fout;
    int* outInts = (int*)iout;
    gStringBuf[0] = '\0';
    faxe_dspdata_clear_desc(outFloats, outInts);
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (vbyte*)gStringBuf; }
    gLastResult = FMOD_DSP_GetParameterInfo(dsp, index, &desc);
    if (gLastResult != FMOD_OK || !desc) return (vbyte*)gStringBuf;
    memcpy(gStringBuf, desc->name, sizeof(desc->name));
    gStringBuf[sizeof(desc->name)] = '\0';
    faxe_dspdata_unpack_desc(desc, outFloats, outInts);
    return (vbyte*)gStringBuf;
}
DEFINE_PRIM(_BYTES, dsp_get_parameter_info, _I32 _I32 _BYTES _BYTES);

HL_PRIM int HL_NAME(dsp_get_data_parameter_index)(int h, int dataType) {
    FMOD_DSP* dsp = resolve_dsp(h);
    int index = -1;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return -1; }
    gLastResult = FMOD_DSP_GetDataParameterIndex(dsp, dataType, &index);
    return gLastResult == FMOD_OK ? index : -1;
}
DEFINE_PRIM(_I32, dsp_get_data_parameter_index, _I32 _I32);

HL_PRIM int HL_NAME(dsp_set_channel_format)(int h, int mask, int channels, int speakerMode) {
    FMOD_DSP* dsp = resolve_dsp(h);
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_DSP_SetChannelFormat(dsp, (FMOD_CHANNELMASK)mask, channels, (FMOD_SPEAKERMODE)speakerMode);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, dsp_set_channel_format, _I32 _I32 _I32 _I32);

// out = int[3]: mask, channels, speaker mode
HL_PRIM int HL_NAME(dsp_get_channel_format)(int h, vbyte* out) {
    FMOD_DSP* dsp = resolve_dsp(h);
    FMOD_CHANNELMASK mask = 0;
    int channels = 0;
    FMOD_SPEAKERMODE mode = FMOD_SPEAKERMODE_DEFAULT;
    int* outInts = (int*)out;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_DSP_GetChannelFormat(dsp, &mask, &channels, &mode);
    outInts[0] = (int)mask;
    outInts[1] = channels;
    outInts[2] = (int)mode;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, dsp_get_channel_format, _I32 _BYTES);

// out = int[3]: mask, channels, speaker mode the unit would emit for this input
HL_PRIM int HL_NAME(dsp_get_output_channel_format)(int h, int inMask, int inChannels, int inMode, vbyte* out) {
    FMOD_DSP* dsp = resolve_dsp(h);
    FMOD_CHANNELMASK mask = 0;
    int channels = 0;
    FMOD_SPEAKERMODE mode = FMOD_SPEAKERMODE_DEFAULT;
    int* outInts = (int*)out;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_DSP_GetOutputChannelFormat(dsp, (FMOD_CHANNELMASK)inMask, inChannels, (FMOD_SPEAKERMODE)inMode, &mask, &channels, &mode);
    outInts[0] = (int)mask;
    outInts[1] = channels;
    outInts[2] = (int)mode;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, dsp_get_output_channel_format, _I32 _I32 _I32 _I32 _BYTES);

// in = double[outChannels*inChannels] row-major gains
HL_PRIM int HL_NAME(conn_set_mix_matrix)(int h, vbyte* in, int outChannels, int inChannels, int inChannelHop) {
    FMOD_DSPCONNECTION* conn = resolve_dspconn(h);
    double* inFloats = (double*)in;
    int total;
    int i;
    if (!conn) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    if (!matrix_args_ok(outChannels, inChannels, inChannelHop)) return (int)gLastResult;
    total = outChannels * (inChannelHop > 0 ? inChannelHop : inChannels);
    for (i = 0; i < total; i++) gMatrixBuf[i] = (float)inFloats[i];
    gLastResult = FMOD_DSPConnection_SetMixMatrix(conn, gMatrixBuf, outChannels, inChannels, inChannelHop);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, conn_set_mix_matrix, _I32 _BYTES _I32 _I32 _I32);

HL_PRIM int HL_NAME(conn_get_mix_matrix)(int h, vbyte* fout, vbyte* iout, int inChannelHop) {
    FMOD_DSPCONNECTION* conn = resolve_dspconn(h);
    int outActual = 0;
    int inActual = 0;
    FMOD_RESULT result;
    if (!conn) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    if (!matrix_hop_ok(inChannelHop)) return 0;
    result = FMOD_DSPConnection_GetMixMatrix(conn, gMatrixBuf, &outActual, &inActual, inChannelHop);
    return write_mix_matrix(result, outActual, inActual, inChannelHop, fout, iout);
}
DEFINE_PRIM(_I32, conn_get_mix_matrix, _I32 _BYTES _BYTES _I32);

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
//// System extras (replay inspection, DSP lock, sound info, memory and file stats, network, speaker positions)

/* Command strings can run past gStringBuf, so they get the 1024 bytes FMOD's own example uses. */
static char gCommandBuf[1024];

HL_PRIM int HL_NAME(replay_get_command_count)(int h) {
    FMOD_STUDIO_COMMANDREPLAY* replay = resolve_replay(h);
    int count = 0;
    if (!replay) { gLastResult = FMOD_ERR_INVALID_HANDLE; return -1; }
    gLastResult = FMOD_Studio_CommandReplay_GetCommandCount(replay, &count);
    return gLastResult == FMOD_OK ? count : -1;
}
DEFINE_PRIM(_I32, replay_get_command_count, _I32);

HL_PRIM vbyte* HL_NAME(replay_get_command_info)(int h, int index, vbyte* ibuf, vbyte* fbuf) {
    FMOD_STUDIO_COMMANDREPLAY* replay = resolve_replay(h);
    FMOD_STUDIO_COMMAND_INFO info;
    int* outInts = (int*)ibuf;
    double* outFloats = (double*)fbuf;
    gStringBuf[0] = '\0';
    if (!replay) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (vbyte*)gStringBuf; }
    memset(&info, 0, sizeof(info));
    gLastResult = FMOD_Studio_CommandReplay_GetCommandInfo(replay, index, &info);
    if (gLastResult != FMOD_OK) return (vbyte*)gStringBuf;
    outInts[0] = (int)info.instancetype;
    outInts[1] = (int)info.outputtype;
    outInts[2] = (int)info.instancehandle;
    outInts[3] = (int)info.outputhandle;
    outInts[4] = info.framenumber;
    outInts[5] = info.parentcommandindex;
    outFloats[0] = (double)info.frametime;
    /* The name points into the replay's own memory, so it is copied out while the handle is still live. */
    if (info.commandname) {
        strncpy(gStringBuf, info.commandname, sizeof(gStringBuf) - 1);
        gStringBuf[sizeof(gStringBuf) - 1] = '\0';
    }
    return (vbyte*)gStringBuf;
}
DEFINE_PRIM(_BYTES, replay_get_command_info, _I32 _I32 _BYTES _BYTES);

HL_PRIM vbyte* HL_NAME(replay_get_command_string)(int h, int index) {
    FMOD_STUDIO_COMMANDREPLAY* replay = resolve_replay(h);
    gCommandBuf[0] = '\0';
    if (!replay) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (vbyte*)gCommandBuf; }
    gLastResult = FMOD_Studio_CommandReplay_GetCommandString(replay, index, gCommandBuf, (int)sizeof(gCommandBuf));
    if (gLastResult != FMOD_OK) gCommandBuf[0] = '\0';
    return (vbyte*)gCommandBuf;
}
DEFINE_PRIM(_BYTES, replay_get_command_string, _I32 _I32);

HL_PRIM int HL_NAME(replay_get_command_at_time)(int h, double seconds) {
    FMOD_STUDIO_COMMANDREPLAY* replay = resolve_replay(h);
    int index = -1;
    if (!replay) { gLastResult = FMOD_ERR_INVALID_HANDLE; return -1; }
    gLastResult = FMOD_Studio_CommandReplay_GetCommandAtTime(replay, (float)seconds, &index);
    return gLastResult == FMOD_OK ? index : -1;
}
DEFINE_PRIM(_I32, replay_get_command_at_time, _I32 _F64);

HL_PRIM int HL_NAME(replay_seek_to_command)(int h, int index) {
    FMOD_STUDIO_COMMANDREPLAY* replay = resolve_replay(h);
    if (!replay) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Studio_CommandReplay_SeekToCommand(replay, index);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, replay_seek_to_command, _I32 _I32);

HL_PRIM int HL_NAME(replay_get_playback_state)(int h) {
    FMOD_STUDIO_COMMANDREPLAY* replay = resolve_replay(h);
    FMOD_STUDIO_PLAYBACK_STATE state = FMOD_STUDIO_PLAYBACK_STOPPED;
    if (!replay) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)FMOD_STUDIO_PLAYBACK_STOPPED; }
    gLastResult = FMOD_Studio_CommandReplay_GetPlaybackState(replay, &state);
    return gLastResult == FMOD_OK ? (int)state : (int)FMOD_STUDIO_PLAYBACK_STOPPED;
}
DEFINE_PRIM(_I32, replay_get_playback_state, _I32);

HL_PRIM int HL_NAME(replay_set_bank_path)(int h, vbyte* path) {
    FMOD_STUDIO_COMMANDREPLAY* replay = resolve_replay(h);
    if (!replay) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Studio_CommandReplay_SetBankPath(replay, (const char*)path);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, replay_set_bank_path, _I32 _BYTES);

HL_PRIM int HL_NAME(sys_lock_dsp)() {
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = FMOD_System_LockDSP(gCoreSystem);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_lock_dsp, _NO_ARG);

HL_PRIM int HL_NAME(sys_unlock_dsp)() {
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = FMOD_System_UnlockDSP(gCoreSystem);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_unlock_dsp, _NO_ARG);

// ibuf out: [0]=subsound index [1]=mode [2]=exinfo length [3]=exinfo file
// offset [4]=exinfo initial subsound [5]=exinfo subsound count
HL_PRIM vbyte* HL_NAME(sys_get_sound_info)(vbyte* key, vbyte* ibuf) {
    FMOD_STUDIO_SOUND_INFO info;
    int* outInts = (int*)ibuf;
    gStringBuf[0] = '\0';
    outInts[0] = -1;
    outInts[1] = 0;
    outInts[2] = 0;
    outInts[3] = 0;
    outInts[4] = 0;
    outInts[5] = 0;
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (vbyte*)gStringBuf; }
    memset(&info, 0, sizeof(info));
    gLastResult = FMOD_Studio_System_GetSoundInfo(gStudioSystem, (const char*)key, &info);
    if (gLastResult != FMOD_OK) return (vbyte*)gStringBuf;
    outInts[0] = info.subsoundindex;
    outInts[1] = (int)info.mode;
    outInts[2] = (int)info.exinfo.length;
    outInts[3] = (int)info.exinfo.fileoffset;
    outInts[4] = info.exinfo.initialsubsound;
    outInts[5] = info.exinfo.numsubsounds;
    /* For a bank loaded from memory name_or_data is the sample bytes themselves, which are no string. */
    if (info.name_or_data && !(info.mode & (FMOD_OPENMEMORY | FMOD_OPENMEMORY_POINT))) {
        strncpy(gStringBuf, info.name_or_data, sizeof(gStringBuf) - 1);
        gStringBuf[sizeof(gStringBuf) - 1] = '\0';
    }
    return (vbyte*)gStringBuf;
}
DEFINE_PRIM(_BYTES, sys_get_sound_info, _BYTES _BYTES);

HL_PRIM int HL_NAME(sys_get_memory_stats)(bool blocking, vbyte* ibuf) {
    int current = 0;
    int maximum = 0;
    int* outInts = (int*)ibuf;
    gLastResult = FMOD_Memory_GetStats(&current, &maximum, blocking ? 1 : 0);
    outInts[0] = current;
    outInts[1] = maximum;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_get_memory_stats, _BOOL _BYTES);

HL_PRIM int HL_NAME(sys_get_file_usage)(vbyte* fbuf) {
    long long sample = 0;
    long long stream = 0;
    long long other = 0;
    double* outFloats = (double*)fbuf;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = FMOD_System_GetFileUsage(gCoreSystem, &sample, &stream, &other);
    outFloats[0] = (double)sample;
    outFloats[1] = (double)stream;
    outFloats[2] = (double)other;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_get_file_usage, _BYTES);

HL_PRIM int HL_NAME(sys_set_network_proxy)(vbyte* proxy) {
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = FMOD_System_SetNetworkProxy(gCoreSystem, (const char*)proxy);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_set_network_proxy, _BYTES);

HL_PRIM vbyte* HL_NAME(sys_get_network_proxy)() {
    gStringBuf[0] = '\0';
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (vbyte*)gStringBuf; }
    gLastResult = FMOD_System_GetNetworkProxy(gCoreSystem, gStringBuf, (int)sizeof(gStringBuf));
    if (gLastResult != FMOD_OK) gStringBuf[0] = '\0';
    return (vbyte*)gStringBuf;
}
DEFINE_PRIM(_BYTES, sys_get_network_proxy, _NO_ARG);

HL_PRIM int HL_NAME(sys_set_network_timeout)(int timeoutMs) {
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = FMOD_System_SetNetworkTimeout(gCoreSystem, timeoutMs);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_set_network_timeout, _I32);

HL_PRIM int HL_NAME(sys_get_network_timeout)() {
    int timeoutMs = -1;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return -1; }
    gLastResult = FMOD_System_GetNetworkTimeout(gCoreSystem, &timeoutMs);
    return gLastResult == FMOD_OK ? timeoutMs : -1;
}
DEFINE_PRIM(_I32, sys_get_network_timeout, _NO_ARG);

HL_PRIM int HL_NAME(sys_set_speaker_position)(int speaker, double x, double y, bool active) {
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = FMOD_System_SetSpeakerPosition(gCoreSystem, (FMOD_SPEAKER)speaker, (float)x, (float)y, active ? 1 : 0);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_set_speaker_position, _I32 _F64 _F64 _BOOL);

HL_PRIM int HL_NAME(sys_get_speaker_position)(int speaker, vbyte* fbuf) {
    float x = 0.0f;
    float y = 0.0f;
    FMOD_BOOL active = 0;
    double* outFloats = (double*)fbuf;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = FMOD_System_GetSpeakerPosition(gCoreSystem, (FMOD_SPEAKER)speaker, &x, &y, &active);
    outFloats[0] = (double)x;
    outFloats[1] = (double)y;
    outFloats[2] = active ? 1.0 : 0.0;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_get_speaker_position, _I32 _BYTES);

//// Plugins

// Plugin handles are FMOD's own unsigned ids. They never enter the handle
// table, so a stale one comes back from FMOD as FMOD_ERR_INVALID_HANDLE.

HL_PRIM int HL_NAME(sys_set_plugin_path)(vbyte* path) {
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = FMOD_System_SetPluginPath(gCoreSystem, (const char*)path);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_set_plugin_path, _BYTES);

HL_PRIM int HL_NAME(sys_load_plugin)(vbyte* path, int priority) {
    unsigned int handle = 0;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    gLastResult = FMOD_System_LoadPlugin(gCoreSystem, (const char*)path, &handle, (unsigned int)priority);
    if (gLastResult != FMOD_OK) return 0;
    return (int)handle;
}
DEFINE_PRIM(_I32, sys_load_plugin, _BYTES _I32);

HL_PRIM int HL_NAME(sys_unload_plugin)(int handle) {
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = FMOD_System_UnloadPlugin(gCoreSystem, (unsigned int)handle);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_unload_plugin, _I32);

HL_PRIM int HL_NAME(sys_get_num_plugins)(int type) {
    int count = 0;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return -1; }
    if (type < 0 || type >= (int)FMOD_PLUGINTYPE_MAX) { gLastResult = FMOD_ERR_INVALID_PARAM; return -1; }
    gLastResult = FMOD_System_GetNumPlugins(gCoreSystem, (FMOD_PLUGINTYPE)type, &count);
    if (gLastResult != FMOD_OK) return -1;
    return count;
}
DEFINE_PRIM(_I32, sys_get_num_plugins, _I32);

HL_PRIM int HL_NAME(sys_get_plugin_handle)(int type, int index) {
    unsigned int handle = 0;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    if (type < 0 || type >= (int)FMOD_PLUGINTYPE_MAX) { gLastResult = FMOD_ERR_INVALID_PARAM; return 0; }
    gLastResult = FMOD_System_GetPluginHandle(gCoreSystem, (FMOD_PLUGINTYPE)type, index, &handle);
    if (gLastResult != FMOD_OK) return 0;
    return (int)handle;
}
DEFINE_PRIM(_I32, sys_get_plugin_handle, _I32 _I32);

// out = int[2]: plugin type, version
HL_PRIM vbyte* HL_NAME(sys_get_plugin_info)(int handle, vbyte* out) {
    FMOD_PLUGINTYPE type = FMOD_PLUGINTYPE_OUTPUT;
    unsigned int version = 0;
    int* outInts = (int*)out;
    gStringBuf[0] = '\0';
    outInts[0] = 0;
    outInts[1] = 0;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (vbyte*)gStringBuf; }
    gLastResult = FMOD_System_GetPluginInfo(gCoreSystem, (unsigned int)handle, &type, gStringBuf, sizeof(gStringBuf), &version);
    if (gLastResult != FMOD_OK) { gStringBuf[0] = '\0'; return (vbyte*)gStringBuf; }
    outInts[0] = (int)type;
    outInts[1] = (int)version;
    return (vbyte*)gStringBuf;
}
DEFINE_PRIM(_BYTES, sys_get_plugin_info, _I32 _BYTES);

HL_PRIM int HL_NAME(sys_get_num_nested_plugins)(int handle) {
    int count = 0;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return -1; }
    gLastResult = FMOD_System_GetNumNestedPlugins(gCoreSystem, (unsigned int)handle, &count);
    if (gLastResult != FMOD_OK) return -1;
    return count;
}
DEFINE_PRIM(_I32, sys_get_num_nested_plugins, _I32);

HL_PRIM int HL_NAME(sys_get_nested_plugin)(int handle, int index) {
    unsigned int nested = 0;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    gLastResult = FMOD_System_GetNestedPlugin(gCoreSystem, (unsigned int)handle, index, &nested);
    if (gLastResult != FMOD_OK) return 0;
    return (int)nested;
}
DEFINE_PRIM(_I32, sys_get_nested_plugin, _I32 _I32);

HL_PRIM int HL_NAME(dsp_create_by_plugin)(int pluginHandle) {
    FMOD_DSP* dsp = NULL;
    int handle;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    gLastResult = FMOD_System_CreateDSPByPlugin(gCoreSystem, (unsigned int)pluginHandle, &dsp);
    if (gLastResult != FMOD_OK || !dsp) return 0;
    handle = faxe_handle_alloc(dsp, FAXE_TYPE_DSP);
    if (handle == 0) {
        gLastResult = FMOD_ERR_MEMORY; /* handle table exhausted */
        FMOD_DSP_Release(dsp);
        return 0;
    }
    return handle;
}
DEFINE_PRIM(_I32, dsp_create_by_plugin, _I32);

// out = int[4]: version, input buffers, output buffers, parameter count
HL_PRIM vbyte* HL_NAME(dsp_get_info_by_plugin)(int handle, vbyte* out) {
    const FMOD_DSP_DESCRIPTION* desc = NULL;
    int* outInts = (int*)out;
    size_t i;
    gStringBuf[0] = '\0';
    for (i = 0; i < 4; i++) outInts[i] = 0;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (vbyte*)gStringBuf; }
    gLastResult = FMOD_System_GetDSPInfoByPlugin(gCoreSystem, (unsigned int)handle, &desc);
    if (gLastResult == FMOD_OK && !desc) gLastResult = FMOD_ERR_PLUGIN;
    if (gLastResult != FMOD_OK) return (vbyte*)gStringBuf;
    /* The description name is a fixed 32 byte field with no terminator guarantee */
    for (i = 0; i < sizeof(desc->name) && desc->name[i] != '\0'; i++) gStringBuf[i] = desc->name[i];
    gStringBuf[i] = '\0';
    outInts[0] = (int)desc->version;
    outInts[1] = desc->numinputbuffers;
    outInts[2] = desc->numoutputbuffers;
    outInts[3] = desc->numparameters;
    return (vbyte*)gStringBuf;
}
DEFINE_PRIM(_BYTES, dsp_get_info_by_plugin, _I32 _BYTES);

//// Sound extras: tracker music, subsounds, tags, and advanced settings readback

HL_PRIM int HL_NAME(core_sound_get_music_num_channels)(int h) {
    FMOD_SOUND* sound = resolve_core_sound(h);
    int count = 0;
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return -1; }
    gLastResult = FMOD_Sound_GetMusicNumChannels(sound, &count);
    return gLastResult == FMOD_OK ? count : -1;
}
DEFINE_PRIM(_I32, core_sound_get_music_num_channels, _I32);

HL_PRIM int HL_NAME(core_sound_set_music_channel_volume)(int h, int channel, double volume) {
    FMOD_SOUND* sound = resolve_core_sound(h);
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Sound_SetMusicChannelVolume(sound, channel, (float)volume);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, core_sound_set_music_channel_volume, _I32 _I32 _F64);

HL_PRIM double HL_NAME(core_sound_get_music_channel_volume)(int h, int channel) {
    FMOD_SOUND* sound = resolve_core_sound(h);
    float volume = 0.0f;
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    gLastResult = FMOD_Sound_GetMusicChannelVolume(sound, channel, &volume);
    return gLastResult == FMOD_OK ? (double)volume : 0.0;
}
DEFINE_PRIM(_F64, core_sound_get_music_channel_volume, _I32 _I32);

HL_PRIM int HL_NAME(core_sound_set_music_speed)(int h, double speed) {
    FMOD_SOUND* sound = resolve_core_sound(h);
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Sound_SetMusicSpeed(sound, (float)speed);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, core_sound_set_music_speed, _I32 _F64);

HL_PRIM double HL_NAME(core_sound_get_music_speed)(int h) {
    FMOD_SOUND* sound = resolve_core_sound(h);
    float speed = 0.0f;
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    gLastResult = FMOD_Sound_GetMusicSpeed(sound, &speed);
    return gLastResult == FMOD_OK ? (double)speed : 0.0;
}
DEFINE_PRIM(_F64, core_sound_get_music_speed, _I32);

HL_PRIM int HL_NAME(core_sound_get_num_sub_sounds)(int h) {
    FMOD_SOUND* sound = resolve_core_sound(h);
    int count = 0;
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return -1; }
    gLastResult = FMOD_Sound_GetNumSubSounds(sound, &count);
    return gLastResult == FMOD_OK ? count : -1;
}
DEFINE_PRIM(_I32, core_sound_get_num_sub_sounds, _I32);

// The subsound stays owned by its parent. The handle is looked up or
// allocated, never released from Haxe (see release_subsound_handles).
HL_PRIM int HL_NAME(core_sound_get_sub_sound)(int h, int index) {
    FMOD_SOUND* sound = resolve_core_sound(h);
    FMOD_SOUND* sub = NULL;
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_Sound_GetSubSound(sound, index, &sub);
    if (gLastResult != FMOD_OK || !sub) return 0;
    return faxe_handle_find_or_alloc(sub, FAXE_TYPE_SOUND);
}
DEFINE_PRIM(_I32, core_sound_get_sub_sound, _I32 _I32);

HL_PRIM int HL_NAME(core_sound_get_sub_sound_parent)(int h) {
    FMOD_SOUND* sound = resolve_core_sound(h);
    FMOD_SOUND* parent = NULL;
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_Sound_GetSubSoundParent(sound, &parent);
    if (gLastResult != FMOD_OK || !parent) return 0;
    return faxe_handle_find_or_alloc(parent, FAXE_TYPE_SOUND);
}
DEFINE_PRIM(_I32, core_sound_get_sub_sound_parent, _I32);

HL_PRIM int HL_NAME(core_sound_get_num_tags)(int h, vbyte* ibuf) {
    FMOD_SOUND* sound = resolve_core_sound(h);
    int* outInts = (int*)ibuf;
    int count = 0;
    int updated = 0;
    outInts[0] = 0;
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return -1; }
    gLastResult = FMOD_Sound_GetNumTags(sound, &count, &updated);
    if (gLastResult != FMOD_OK) return -1;
    outInts[0] = updated;
    return count;
}
DEFINE_PRIM(_I32, core_sound_get_num_tags, _I32 _BYTES);

// An empty name means any tag, which is FMOD's NULL name. The int and
// float payloads are copied when they are exactly four bytes wide.
HL_PRIM vbyte* HL_NAME(core_sound_get_tag)(int h, vbyte* name, int index, vbyte* ibuf, vbyte* fbuf) {
    FMOD_SOUND* sound = resolve_core_sound(h);
    int* outInts = (int*)ibuf;
    double* outFloats = (double*)fbuf;
    FMOD_TAG tag;
    outInts[0] = 0; outInts[1] = 0; outInts[2] = 0; outInts[3] = 0; outInts[4] = 0;
    outFloats[0] = 0.0;
    gStringBuf[0] = '\0';
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (vbyte*)gStringBuf; }
    memset(&tag, 0, sizeof(tag));
    gLastResult = FMOD_Sound_GetTag(sound, (name && name[0] != '\0') ? (const char*)name : NULL, index, &tag);
    if (gLastResult != FMOD_OK) return (vbyte*)gStringBuf;
    outInts[0] = (int)tag.type;
    outInts[1] = (int)tag.datatype;
    outInts[2] = tag.updated ? 1 : 0;
    outInts[3] = (int)tag.datalen;
    if (tag.datatype == FMOD_TAGDATATYPE_INT && tag.datalen == 4 && tag.data) outInts[4] = *(int*)tag.data;
    if (tag.datatype == FMOD_TAGDATATYPE_FLOAT && tag.datalen == 4 && tag.data) outFloats[0] = (double)(*(float*)tag.data);
    if (tag.name) {
        strncpy(gStringBuf, tag.name, sizeof(gStringBuf) - 1);
        gStringBuf[sizeof(gStringBuf) - 1] = '\0';
    }
    return (vbyte*)gStringBuf;
}
DEFINE_PRIM(_BYTES, core_sound_get_tag, _I32 _BYTES _I32 _BYTES _BYTES);

HL_PRIM vbyte* HL_NAME(core_sound_get_tag_string)(int h, vbyte* name, int index) {
    FMOD_SOUND* sound = resolve_core_sound(h);
    FMOD_TAG tag;
    size_t len;
    gStringBuf[0] = '\0';
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (vbyte*)gStringBuf; }
    memset(&tag, 0, sizeof(tag));
    gLastResult = FMOD_Sound_GetTag(sound, (name && name[0] != '\0') ? (const char*)name : NULL, index, &tag);
    if (gLastResult != FMOD_OK) return (vbyte*)gStringBuf;
    if ((tag.datatype == FMOD_TAGDATATYPE_STRING || tag.datatype == FMOD_TAGDATATYPE_STRING_UTF8) && tag.data) {
        /* datalen usually counts the terminator, and the copy is capped so
         * a payload that lies about its size cannot run past the buffer */
        len = tag.datalen < sizeof(gStringBuf) - 1 ? tag.datalen : sizeof(gStringBuf) - 1;
        memcpy(gStringBuf, tag.data, len);
        gStringBuf[len] = '\0';
    }
    return (vbyte*)gStringBuf;
}
DEFINE_PRIM(_BYTES, core_sound_get_tag_string, _I32 _BYTES _I32);

HL_PRIM int HL_NAME(sys_get_advanced_settings)(vbyte* ibuf, vbyte* fbuf) {
    int* outInts = (int*)ibuf;
    double* outFloats = (double*)fbuf;
    FMOD_ADVANCEDSETTINGS adv;
    int i;
    for (i = 0; i < 7; i++) outInts[i] = 0;
    outFloats[0] = 0.0; outFloats[1] = 0.0;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    memset(&adv, 0, sizeof(adv));
    adv.cbSize = sizeof(adv);
    gLastResult = FMOD_System_GetAdvancedSettings(gCoreSystem, &adv);
    if (gLastResult != FMOD_OK) return (int)gLastResult;
    outInts[0] = adv.maxMPEGCodecs;
    outInts[1] = adv.maxVorbisCodecs;
    outInts[2] = adv.maxFADPCMCodecs;
    outInts[3] = (int)adv.defaultDecodeBufferSize;
    outInts[4] = (int)adv.profilePort;
    outInts[5] = (int)adv.geometryMaxFadeTime;
    outInts[6] = (int)adv.randomSeed;
    outFloats[0] = (double)adv.vol0virtualvol;
    outFloats[1] = (double)adv.distanceFilterCenterFreq;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_get_advanced_settings, _BYTES _BYTES);

HL_PRIM int HL_NAME(sys_get_studio_advanced_settings)(vbyte* ibuf) {
    int* outInts = (int*)ibuf;
    FMOD_STUDIO_ADVANCEDSETTINGS sadv;
    int i;
    for (i = 0; i < 5; i++) outInts[i] = 0;
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    memset(&sadv, 0, sizeof(sadv));
    sadv.cbsize = sizeof(sadv);
    gLastResult = FMOD_Studio_System_GetAdvancedSettings(gStudioSystem, &sadv);
    if (gLastResult != FMOD_OK) return (int)gLastResult;
    outInts[0] = (int)sadv.commandqueuesize;
    outInts[1] = (int)sadv.handleinitialsize;
    outInts[2] = sadv.studioupdateperiod;
    outInts[3] = sadv.idlesampledatapoolsize;
    outInts[4] = (int)sadv.streamingscheduledelay;
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_get_studio_advanced_settings, _BYTES);

//// Last seven: preallocated DSP input, mix levels, DSP info by type, output plugin, replay cursor

/* FMOD dereferences the connection, so a null one never reaches it */
HL_PRIM int HL_NAME(dsp_add_input_preallocated)(int h, int inputHandle, int connHandle) {
    FMOD_DSP* dsp = resolve_dsp(h);
    FMOD_DSP* input = resolve_dsp(inputHandle);
    FMOD_DSPCONNECTION* conn = resolve_dspconn(connHandle);
    if (!dsp || !input || !conn) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_DSP_AddInputPreallocated(dsp, input, &conn);
    if (gLastResult != FMOD_OK || !conn) return 0;
    return faxe_handle_find_or_alloc(conn, FAXE_TYPE_DSPCONN);
}
DEFINE_PRIM(_I32, dsp_add_input_preallocated, _I32 _I32 _I32);

/* in = double[count], one gain per input channel */
HL_PRIM int HL_NAME(chan_set_mix_levels_input)(int h, vbyte* in, int count) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    double* inFloats = (double*)in;
    float levels[32];
    int i;
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    if (count < 0 || count > 32) { gLastResult = FMOD_ERR_INVALID_PARAM; return (int)gLastResult; }
    for (i = 0; i < count; i++) levels[i] = (float)inFloats[i];
    gLastResult = FMOD_Channel_SetMixLevelsInput(channel, levels, count);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_set_mix_levels_input, _I32 _BYTES _I32);

HL_PRIM int HL_NAME(chan_set_mix_levels_output)(int h, double fl, double fr, double c, double lfe, double sl, double sr, double bl, double br) {
    FMOD_CHANNEL* channel = resolve_channel(h);
    if (!channel) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_Channel_SetMixLevelsOutput(channel, (float)fl, (float)fr, (float)c, (float)lfe, (float)sl, (float)sr, (float)bl, (float)br);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, chan_set_mix_levels_output, _I32 _F64 _F64 _F64 _F64 _F64 _F64 _F64 _F64);

HL_PRIM int HL_NAME(cg_set_mix_levels_input)(int h, vbyte* in, int count) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    double* inFloats = (double*)in;
    float levels[32];
    int i;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    if (count < 0 || count > 32) { gLastResult = FMOD_ERR_INVALID_PARAM; return (int)gLastResult; }
    for (i = 0; i < count; i++) levels[i] = (float)inFloats[i];
    gLastResult = FMOD_ChannelGroup_SetMixLevelsInput(group, levels, count);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, cg_set_mix_levels_input, _I32 _BYTES _I32);

HL_PRIM int HL_NAME(cg_set_mix_levels_output)(int h, double fl, double fr, double c, double lfe, double sl, double sr, double bl, double br) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = FMOD_ChannelGroup_SetMixLevelsOutput(group, (float)fl, (float)fr, (float)c, (float)lfe, (float)sl, (float)sr, (float)bl, (float)br);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, cg_set_mix_levels_output, _I32 _F64 _F64 _F64 _F64 _F64 _F64 _F64 _F64);

/* out = int[4]: version, input buffers, output buffers, parameter count */
HL_PRIM vbyte* HL_NAME(sys_get_dsp_info_by_type)(int type, vbyte* out) {
    const FMOD_DSP_DESCRIPTION* desc = NULL;
    int* outInts = (int*)out;
    size_t i;
    gStringBuf[0] = '\0';
    for (i = 0; i < 4; i++) outInts[i] = 0;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (vbyte*)gStringBuf; }
    gLastResult = FMOD_System_GetDSPInfoByType(gCoreSystem, (FMOD_DSP_TYPE)type, &desc);
    if (gLastResult == FMOD_OK && !desc) gLastResult = FMOD_ERR_INVALID_PARAM;
    if (gLastResult != FMOD_OK) return (vbyte*)gStringBuf;
    /* The description name is a fixed 32 byte field with no terminator guarantee */
    for (i = 0; i < sizeof(desc->name) && desc->name[i] != '\0'; i++) gStringBuf[i] = desc->name[i];
    gStringBuf[i] = '\0';
    outInts[0] = (int)desc->version;
    outInts[1] = desc->numinputbuffers;
    outInts[2] = desc->numoutputbuffers;
    outInts[3] = desc->numparameters;
    return (vbyte*)gStringBuf;
}
DEFINE_PRIM(_BYTES, sys_get_dsp_info_by_type, _I32 _BYTES);

HL_PRIM int HL_NAME(sys_get_output_by_plugin)() {
    unsigned int handle = 0;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    gLastResult = FMOD_System_GetOutputByPlugin(gCoreSystem, &handle);
    return gLastResult == FMOD_OK ? (int)handle : 0;
}
DEFINE_PRIM(_I32, sys_get_output_by_plugin, _NO_ARG);

HL_PRIM int HL_NAME(sys_set_output_by_plugin)(int handle) {
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = FMOD_System_SetOutputByPlugin(gCoreSystem, (unsigned int)handle);
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, sys_set_output_by_plugin, _I32);

/* out = double[1]: current time in seconds */
HL_PRIM int HL_NAME(replay_get_current_command)(int h, vbyte* out) {
    FMOD_STUDIO_COMMANDREPLAY* replay = resolve_replay(h);
    double* outFloats = (double*)out;
    int index = -1;
    float time = 0.0f;
    outFloats[0] = 0.0;
    if (!replay) { gLastResult = FMOD_ERR_INVALID_HANDLE; return -1; }
    gLastResult = FMOD_Studio_CommandReplay_GetCurrentCommand(replay, &index, &time);
    if (gLastResult != FMOD_OK) return -1;
    outFloats[0] = (double)time;
    return index;
}
DEFINE_PRIM(_I32, replay_get_current_command, _I32 _BYTES);

//// Channel group DSP chain walk

HL_PRIM int HL_NAME(cg_get_num_dsps)(int h) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    int count = 0;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_ChannelGroup_GetNumDSPs(group, &count);
    return count;
}
DEFINE_PRIM(_I32, cg_get_num_dsps, _I32);

HL_PRIM int HL_NAME(cg_get_dsp)(int h, int index) {
    FMOD_CHANNELGROUP* group = resolve_changroup(h);
    FMOD_DSP* dsp = NULL;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_ChannelGroup_GetDSP(group, index, &dsp);
    if (gLastResult != FMOD_OK || !dsp) return 0;
    return faxe_handle_find_or_alloc(dsp, FAXE_TYPE_DSP);
}
DEFINE_PRIM(_I32, cg_get_dsp, _I32 _I32);

//// DSP data parameters and unit info

// ibuf[0] version, [1] channels, [2] config width, [3] config height. Returns the name.
HL_PRIM vbyte* HL_NAME(dsp_get_info)(int h, vbyte* iout) {
    FMOD_DSP* dsp = resolve_dsp(h);
    int* outInts = (int*)iout;
    unsigned int version = 0;
    int channels = 0, width = 0, height = 0;
    gStringBuf[0] = '\0';
    outInts[0] = 0; outInts[1] = 0; outInts[2] = 0; outInts[3] = 0;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (vbyte*)gStringBuf; }
    gLastResult = FMOD_DSP_GetInfo(dsp, gStringBuf, &version, &channels, &width, &height);
    if (gLastResult != FMOD_OK) { gStringBuf[0] = '\0'; return (vbyte*)gStringBuf; }
    outInts[0] = (int)version;
    outInts[1] = channels;
    outInts[2] = width;
    outInts[3] = height;
    return (vbyte*)gStringBuf;
}
DEFINE_PRIM(_BYTES, dsp_get_info, _I32 _BYTES);

// Copies up to cap bytes of the data block into out (out may be NULL to
// ask for the size only). Returns the block length FMOD reports, -1 on
// failure.
HL_PRIM int HL_NAME(dsp_get_param_data)(int h, int index, vbyte* out, int cap) {
    FMOD_DSP* dsp = resolve_dsp(h);
    void* data = NULL;
    unsigned int len = 0;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return -1; }
    gLastResult = FMOD_DSP_GetParameterData(dsp, index, &data, &len, NULL, 0);
    if (gLastResult != FMOD_OK) return -1;
    if (out && data && cap > 0) memcpy(out, data, (unsigned int)cap < len ? (unsigned int)cap : len);
    return (int)len;
}
DEFINE_PRIM(_I32, dsp_get_param_data, _I32 _I32 _BYTES _I32);

// fbuf = 24 doubles, relative then absolute attributes (faxe_dspdata.h).
HL_PRIM int HL_NAME(dsp_set_param_3d_attributes)(int h, int index, vbyte* f) {
    FMOD_DSP* dsp = resolve_dsp(h);
    FMOD_DSP_PARAMETER_3DATTRIBUTES attrs;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    faxe_dspdata_pack_3d(&attrs, (const double*)f);
    gLastResult = FMOD_DSP_SetParameterData(dsp, index, &attrs, sizeof(attrs));
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, dsp_set_param_3d_attributes, _I32 _I32 _BYTES);

// fbuf = 116 doubles: relative[8], weight[8], absolute (faxe_dspdata.h).
HL_PRIM int HL_NAME(dsp_set_param_3d_attributes_multi)(int h, int index, int numListeners, vbyte* f) {
    FMOD_DSP* dsp = resolve_dsp(h);
    FMOD_DSP_PARAMETER_3DATTRIBUTES_MULTI attrs;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    if (!faxe_dspdata_pack_3d_multi(&attrs, numListeners, (const double*)f)) {
        gLastResult = FMOD_ERR_INVALID_PARAM;
        return (int)gLastResult;
    }
    gLastResult = FMOD_DSP_SetParameterData(dsp, index, &attrs, sizeof(attrs));
    return (int)gLastResult;
}
DEFINE_PRIM(_I32, dsp_set_param_3d_attributes_multi, _I32 _I32 _I32 _BYTES);

// One side of the meter: input when input is true, output otherwise.
// fbuf peak then rms per channel, ibuf[0] numsamples, ibuf[1] numchannels.
// Returns the channel count.
HL_PRIM int HL_NAME(dsp_get_metering_info)(int h, bool input, vbyte* fout, vbyte* iout) {
    FMOD_DSP* dsp = resolve_dsp(h);
    FMOD_DSP_METERING_INFO info;
    int* outInts = (int*)iout;
    outInts[0] = 0;
    outInts[1] = 0;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    memset(&info, 0, sizeof(info));
    gLastResult = input ? FMOD_DSP_GetMeteringInfo(dsp, &info, NULL) : FMOD_DSP_GetMeteringInfo(dsp, NULL, &info);
    if (gLastResult != FMOD_OK) return 0;
    return faxe_dspdata_unpack_metering(&info, (double*)fout, outInts);
}
DEFINE_PRIM(_I32, dsp_get_metering_info, _I32 _BOOL _BYTES _BYTES);

// fbuf = the spectrum of one channel capped at maxBins, ibuf[0] the
// channel count, ibuf[1] the bin count. Returns the bins written.
HL_PRIM int HL_NAME(dsp_fft_get_spectrum_channel)(int h, int channel, vbyte* fout, int maxBins, vbyte* iout) {
    FMOD_DSP* dsp = resolve_dsp(h);
    FMOD_DSP_PARAMETER_FFT* fft = NULL;
    unsigned int len = 0;
    double* outFloats = (double*)fout;
    int* outInts = (int*)iout;
    int count, i;
    outInts[0] = 0;
    outInts[1] = 0;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = FMOD_DSP_GetParameterData(dsp, FMOD_DSP_FFT_SPECTRUMDATA, (void**)&fft, &len, NULL, 0);
    if (gLastResult != FMOD_OK || !fft) return 0;
    outInts[0] = fft->numchannels;
    outInts[1] = fft->length;
    if (channel < 0 || channel >= fft->numchannels || channel >= 32 || !fft->spectrum[channel]) return 0;
    count = fft->length < maxBins ? fft->length : maxBins;
    if (count > FAXE_LIST_MAX) count = FAXE_LIST_MAX;
    for (i = 0; i < count; i++) outFloats[i] = (double)fft->spectrum[channel][i];
    return count;
}
DEFINE_PRIM(_I32, dsp_fft_get_spectrum_channel, _I32 _I32 _BYTES _I32 _BYTES);

// kind 0 = label, 1 = description, 2 + n = value name n (faxe_dspdata.h).
// Empty when the descriptor has no such text.
HL_PRIM vbyte* HL_NAME(dsp_get_parameter_text)(int h, int index, int kind) {
    FMOD_DSP* dsp = resolve_dsp(h);
    FMOD_DSP_PARAMETER_DESC* desc = NULL;
    gStringBuf[0] = '\0';
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (vbyte*)gStringBuf; }
    gLastResult = FMOD_DSP_GetParameterInfo(dsp, index, &desc);
    if (gLastResult != FMOD_OK || !desc) return (vbyte*)gStringBuf;
    faxe_dspdata_desc_text(desc, kind, gStringBuf, sizeof(gStringBuf));
    return (vbyte*)gStringBuf;
}
DEFINE_PRIM(_BYTES, dsp_get_parameter_text, _I32 _I32 _I32);
