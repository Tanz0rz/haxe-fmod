/**
 * Faxe - C++ FMOD bindings - Minimal FFI layer
 *
 * Raw FMOD calls only. The wrapper classes in haxefmod/studio and
 * haxefmod/core carry the typed API on top. Argument validation policy:
 * numeric arguments (indexes, counts, positions) pass through to FMOD,
 * which validates them and reports the result code. The shim only guards
 * what FMOD cannot: buffer lengths, handle resolution, and anything that
 * would read or write out of bounds before FMOD sees it.
 *
 * The MIT License (MIT)
 * Copyright (c) 2016 Aaron M. Shea
 * Copyright (c) 2020 Tanner Moore
 */

#include <hxcpp.h>
#include <fmod_studio.hpp>
#include "linc_faxe.h"
#include "../shared/faxe_handles.h"
#include "../shared/faxe_pcmring.h"
#include "../shared/faxe_dsptype.h"
#include "../shared/faxe_cbqueue.h"
#include "../shared/faxe_guid.h"
#include "../shared/faxe_instctx.h"
#include <thread>
#include <atomic>
#include <chrono>
#include <cstdlib>
#include <cstdint>
#include <cstdio>

// F_CALLBACK was removed in newer FMOD SDKs
#ifndef F_CALLBACK
#define F_CALLBACK F_CALL
#endif

namespace linc {
namespace faxe {

// Global state
static FMOD::Studio::System* gStudioSystem = NULL;
static FMOD::System* gCoreSystem = NULL;

// Result of the most recent studio binding call made from the Haxe thread.
static FMOD_RESULT gLastResult = FMOD_OK;
// Static buffer for string out-params. Contents are only valid until the
// next binding call; the Haxe wrappers copy immediately.
static char gStringBuf[512];

// Shared list buffer for the list getters (Haxe thread only, like gStringBuf)
static void* gListBuf[FAXE_LIST_MAX];

// Auto-update thread
static std::thread* gUpdateThread = NULL;
static std::atomic<bool> gAutoUpdateRunning(false);

// Resolve an event instance handle to its FMOD pointer (NULL if stale/invalid)
static inline FMOD::Studio::EventInstance* resolveInstance(int h) {
    return (FMOD::Studio::EventInstance*)faxe_handle_resolve(h, FAXE_TYPE_EVI);
}

// Callback handler - runs on an FMOD thread. Must not touch the handle table
// or any Haxe values; it reads the per-instance context back from FMOD
// userdata, copies payloads into a plain C record, and pushes it onto the
// shared queue. The Haxe thread drains the queue during update().
// Programmer sounds are resolved right here on the FMOD thread: the key was
// stored in the context by fmod_ps_assign (guarded by the queue mutex).
static FMOD_RESULT F_CALLBACK eventCallback(FMOD_STUDIO_EVENT_CALLBACK_TYPE type,
    FMOD_STUDIO_EVENTINSTANCE* event, void* parameters) {
    FMOD::Studio::EventInstance* instance = (FMOD::Studio::EventInstance*)event;
    void* userData = NULL;
    instance->getUserData(&userData);
    FaxeInstCtx* ctx = (FaxeInstCtx*)userData;
    if (!ctx) return FMOD_OK;
    // handle can be rewritten from the game thread when a released instance
    // is re-acquired through evd_get_instance_list, so read it under the lock
    faxe_cbq_lock();
    int handle = ctx->handle;
    faxe_cbq_unlock();
    if (handle <= 0) return FMOD_OK;

    FaxeCbEvent ev;
    memset(&ev, 0, sizeof(ev));
    ev.handle = handle;
    ev.type = (uint32_t)type;

    switch (type) {
        case FMOD_STUDIO_EVENT_CALLBACK_CREATE_PROGRAMMER_SOUND: {
            FMOD_STUDIO_PROGRAMMER_SOUND_PROPERTIES* props =
                (FMOD_STUDIO_PROGRAMMER_SOUND_PROPERTIES*)parameters;
            char key[FAXE_PS_KEY_MAX];
            faxe_cbq_lock();
            strncpy(key, ctx->psKey, FAXE_PS_KEY_MAX - 1);
            key[FAXE_PS_KEY_MAX - 1] = '\0';
            faxe_cbq_unlock();
            if (props && key[0] != '\0' && gCoreSystem && gStudioSystem) {
                FMOD_STUDIO_SOUND_INFO info;
                FMOD::Sound* sound = NULL;
                if (gStudioSystem->getSoundInfo(key, &info) == FMOD_OK) {
                    // Audio table entry
                    if (gCoreSystem->createSound(info.name_or_data,
                            FMOD_LOOP_NORMAL | FMOD_CREATECOMPRESSEDSAMPLE | info.mode,
                            &info.exinfo, &sound) == FMOD_OK) {
                        props->sound = (FMOD_SOUND*)sound;
                        props->subsoundIndex = info.subsoundindex;
                    }
                } else if (gCoreSystem->createSound(key, FMOD_DEFAULT, NULL, &sound) == FMOD_OK) {
                    // Plain file path fallback
                    props->sound = (FMOD_SOUND*)sound;
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
                ((FMOD::Sound*)props->sound)->release();
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
    // the installed mask (see attachInstanceCtx), so hand-off is guaranteed.
    // The context rides the queue as the event's payload and the game-thread
    // drain frees it: freeing here would race a game-thread caller that read
    // the context pointer from userdata just before this callback ran.
    if (type == FMOD_STUDIO_EVENT_CALLBACK_DESTROYED) {
        instance->setUserData(NULL);
        ev.opaque = ctx;
    }

    faxe_cbq_push(&ev);
    return FMOD_OK;
}

// Attaches the per-instance context and installs the shim callback with at
// least the DESTROYED bit so the context is always reclaimed. Called from
// every managed-instance creation path (Haxe thread).
static bool attachInstanceCtx(FMOD::Studio::EventInstance* instance, int handle) {
    FaxeInstCtx* ctx = faxe_instctx_create(handle);
    if (!ctx) return false;
    instance->setUserData(ctx);
    // Without the callback the DESTROYED hand-off never happens and the
    // context would leak with the instance, so a failed install aborts
    if (instance->setCallback(eventCallback, FMOD_STUDIO_EVENT_CALLBACK_DESTROYED) != FMOD_OK) {
        instance->setUserData(NULL);
        faxe_instctx_destroy(ctx);
        return false;
    }
    return true;
}

// Reads the context back from a live instance (Haxe thread only).
static FaxeInstCtx* instanceCtx(FMOD::Studio::EventInstance* instance) {
    void* userData = NULL;
    instance->getUserData(&userData);
    return (FaxeInstCtx*)userData;
}

// Auto-update thread function
static void autoUpdateLoop() {
    while (gAutoUpdateRunning.load()) {
        if (gStudioSystem) {
            gStudioSystem->update();
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(16)); // ~60fps
    }
}

//// System

bool fmod_sys_is_initialized() {
    return gStudioSystem != NULL;
}

void fmod_sys_update() {
    if (gStudioSystem) gStudioSystem->update();
}

void fmod_sys_set_auto_update(bool enabled) {
    if (enabled && !gAutoUpdateRunning.load()) {
        // Start auto-update thread
        gAutoUpdateRunning.store(true);
        gUpdateThread = new std::thread(autoUpdateLoop);
    } else if (!enabled && gAutoUpdateRunning.load()) {
        // Stop auto-update thread
        gAutoUpdateRunning.store(false);
        if (gUpdateThread && gUpdateThread->joinable()) {
            gUpdateThread->join();
            delete gUpdateThread;
            gUpdateThread = NULL;
        }
    }
}

//// Callbacks

// Builds the mask actually installed on the instance: the user's mask plus
// DESTROYED (context cleanup) plus the programmer-sound bits when a key is
// assigned.
static FMOD_STUDIO_EVENT_CALLBACK_TYPE effectiveCallbackMask(FaxeInstCtx* ctx) {
    unsigned int mask = ctx->cbMask | FMOD_STUDIO_EVENT_CALLBACK_DESTROYED;
    faxe_cbq_lock();
    if (ctx->psKey[0] != '\0') {
        mask |= FMOD_STUDIO_EVENT_CALLBACK_CREATE_PROGRAMMER_SOUND
              | FMOD_STUDIO_EVENT_CALLBACK_DESTROY_PROGRAMMER_SOUND;
    }
    faxe_cbq_unlock();
    return (FMOD_STUDIO_EVENT_CALLBACK_TYPE)mask;
}

int fmod_evi_set_callback_mask(int h, int mask) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    FaxeInstCtx* ctx = instanceCtx(instance);
    if (!ctx) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    ctx->cbMask = (unsigned int)mask;
    gLastResult = instance->setCallback(eventCallback, effectiveCallbackMask(ctx));
    return (int)gLastResult;
}

//// Programmer sounds

int fmod_ps_assign(int h, const ::String& key) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    FaxeInstCtx* ctx = instanceCtx(instance);
    if (!ctx) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    faxe_cbq_lock();
    strncpy(ctx->psKey, key.c_str(), FAXE_PS_KEY_MAX - 1);
    ctx->psKey[FAXE_PS_KEY_MAX - 1] = '\0';
    faxe_cbq_unlock();
    gLastResult = instance->setCallback(eventCallback, effectiveCallbackMask(ctx));
    return (int)gLastResult;
}

int fmod_ps_clear(int h) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    FaxeInstCtx* ctx = instanceCtx(instance);
    if (!ctx) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    faxe_cbq_lock();
    ctx->psKey[0] = '\0';
    faxe_cbq_unlock();
    gLastResult = instance->setCallback(eventCallback, effectiveCallbackMask(ctx));
    return (int)gLastResult;
}

//// Core API micro subset (programmer sounds only)

static inline FMOD::Sound* resolveSound(int h) {
    return (FMOD::Sound*)faxe_handle_resolve(h, FAXE_TYPE_SOUND);
}

int fmod_core_create_sound(const ::String& path, int mode) {
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    FMOD::Sound* sound = NULL;
    FMOD_MODE fmodMode = FMOD_DEFAULT;
    if (mode & 1) fmodMode |= FMOD_LOOP_NORMAL;
    gLastResult = gCoreSystem->createSound(path.c_str(), fmodMode, NULL, &sound);
    if (gLastResult != FMOD_OK || !sound) return 0;
    int handle = faxe_handle_alloc(sound, FAXE_TYPE_SOUND);
    if (handle == 0) {
        gLastResult = FMOD_ERR_MEMORY; /* handle table exhausted */
        sound->release();
        return 0;
    }
    return handle;
}

int fmod_core_release_sound(int h) {
    FMOD::Sound* sound = resolveSound(h);
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = sound->release();
    if (gLastResult == FMOD_OK) faxe_handle_free(h);
    return (int)gLastResult;
}

int fmod_core_get_sound_length(int h) {
    FMOD::Sound* sound = resolveSound(h);
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return -1; }
    unsigned int length = 0;
    gLastResult = sound->getLength(&length, FMOD_TIMEUNIT_MS);
    if (gLastResult != FMOD_OK) return -1;
    return (int)length;
}

//// Core PCM streams (user-generated audio)

// An OPENUSER looping stream paired with the ring the game thread feeds
struct LincPcmStream {
    FMOD::Sound* sound;
    FaxePcmRing* ring;
};

// Mixer thread: plain C++, drains the ring (silence-padded on underrun)
static FMOD_RESULT F_CALLBACK lincPcmRead(FMOD_SOUND* sound, void* data, unsigned int datalen) {
    void* ud = NULL;
    ((FMOD::Sound*)sound)->getUserData(&ud);
    if (ud) {
        faxe_pcmring_read((FaxePcmRing*)ud, data, (int)datalen);
    } else {
        memset(data, 0, datalen);
    }
    return FMOD_OK;
}

static inline LincPcmStream* resolvePcm(int h) {
    return (LincPcmStream*)faxe_handle_resolve(h, FAXE_TYPE_PCM);
}

static inline FMOD::Channel* resolveChannel(int h) {
    return (FMOD::Channel*)faxe_handle_resolve(h, FAXE_TYPE_CHAN);
}

int fmod_core_pcm_create(int sampleRate, int channels, int ringBytes) {
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    if (sampleRate <= 0 || channels < 1 || channels > 2 || ringBytes <= 0) {
        gLastResult = FMOD_ERR_INVALID_PARAM;
        return 0;
    }
    LincPcmStream* ps = (LincPcmStream*)malloc(sizeof(LincPcmStream));
    if (!ps) { gLastResult = FMOD_ERR_MEMORY; return 0; }
    ps->ring = faxe_pcmring_create(ringBytes);
    if (!ps->ring) { free(ps); gLastResult = FMOD_ERR_MEMORY; return 0; }

    FMOD_CREATESOUNDEXINFO exinfo;
    memset(&exinfo, 0, sizeof(exinfo));
    exinfo.cbsize = sizeof(FMOD_CREATESOUNDEXINFO);
    exinfo.numchannels = channels;
    exinfo.defaultfrequency = sampleRate;
    exinfo.format = FMOD_SOUND_FORMAT_PCM16;
    exinfo.decodebuffersize = 4096;
    exinfo.length = (unsigned int)(sampleRate * channels * 2); // a one second window
    exinfo.pcmreadcallback = lincPcmRead;
    exinfo.userdata = ps->ring;

    ps->sound = NULL;
    gLastResult = gCoreSystem->createSound(NULL,
        FMOD_OPENUSER | FMOD_LOOP_NORMAL | FMOD_CREATESTREAM, &exinfo, &ps->sound);
    if (gLastResult != FMOD_OK || !ps->sound) {
        faxe_pcmring_destroy(ps->ring);
        free(ps);
        return 0;
    }
    int handle = faxe_handle_alloc(ps, FAXE_TYPE_PCM);
    if (handle == 0) {
        gLastResult = FMOD_ERR_MEMORY; /* handle table exhausted */
        ps->sound->release();
        faxe_pcmring_destroy(ps->ring);
        free(ps);
        return 0;
    }
    return handle;
}

int fmod_core_pcm_create_3d(int sampleRate, int channels, int ringBytes) {
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    if (sampleRate <= 0 || channels < 1 || channels > 2 || ringBytes <= 0) {
        gLastResult = FMOD_ERR_INVALID_PARAM;
        return 0;
    }
    LincPcmStream* ps = (LincPcmStream*)malloc(sizeof(LincPcmStream));
    if (!ps) { gLastResult = FMOD_ERR_MEMORY; return 0; }
    ps->ring = faxe_pcmring_create(ringBytes);
    if (!ps->ring) { free(ps); gLastResult = FMOD_ERR_MEMORY; return 0; }

    FMOD_CREATESOUNDEXINFO exinfo;
    memset(&exinfo, 0, sizeof(exinfo));
    exinfo.cbsize = sizeof(FMOD_CREATESOUNDEXINFO);
    exinfo.numchannels = channels;
    exinfo.defaultfrequency = sampleRate;
    exinfo.format = FMOD_SOUND_FORMAT_PCM16;
    exinfo.decodebuffersize = 4096;
    exinfo.length = (unsigned int)(sampleRate * channels * 2); // a one second window
    exinfo.pcmreadcallback = lincPcmRead;
    exinfo.userdata = ps->ring;

    ps->sound = NULL;
    gLastResult = gCoreSystem->createSound(NULL,
        FMOD_OPENUSER | FMOD_LOOP_NORMAL | FMOD_CREATESTREAM | FMOD_3D, &exinfo, &ps->sound);
    if (gLastResult != FMOD_OK || !ps->sound) {
        faxe_pcmring_destroy(ps->ring);
        free(ps);
        return 0;
    }
    int handle = faxe_handle_alloc(ps, FAXE_TYPE_PCM);
    if (handle == 0) {
        gLastResult = FMOD_ERR_MEMORY; /* handle table exhausted */
        ps->sound->release();
        faxe_pcmring_destroy(ps->ring);
        free(ps);
        return 0;
    }
    return handle;
}

int fmod_core_pcm_write(int h, ::Array<unsigned char> data, int len) {
    LincPcmStream* ps = resolvePcm(h);
    if (!ps) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    if (data == null() || len <= 0) { gLastResult = FMOD_ERR_INVALID_PARAM; return 0; }
    if (len > data->length) len = data->length;
    gLastResult = FMOD_OK;
    return faxe_pcmring_write(ps->ring, &data[0], len);
}

int fmod_core_pcm_space(int h) {
    LincPcmStream* ps = resolvePcm(h);
    if (!ps) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    return faxe_pcmring_space(ps->ring);
}

int fmod_core_pcm_underruns(int h) {
    LincPcmStream* ps = resolvePcm(h);
    if (!ps) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    return faxe_pcmring_take_underruns(ps->ring);
}

int fmod_core_pcm_play(int h, bool paused) {
    LincPcmStream* ps = resolvePcm(h);
    if (!ps) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    FMOD::Channel* channel = NULL;
    gLastResult = gCoreSystem->playSound(ps->sound, NULL, paused, &channel);
    if (gLastResult != FMOD_OK || !channel) return 0;
    int handle = faxe_handle_alloc(channel, FAXE_TYPE_CHAN);
    if (handle == 0) {
        gLastResult = FMOD_ERR_MEMORY; /* handle table exhausted */
        channel->stop();
        return 0;
    }
    return handle;
}

int fmod_core_pcm_release(int h) {
    LincPcmStream* ps = resolvePcm(h);
    if (!ps) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    // Releasing a stream blocks until the mixer is done with it, so the
    // ring is safe to destroy afterward. Channels playing it stop with
    // the release and their handles go stale, which resolves safely.
    // Clearing the user data first makes any straggling pcmread fall to
    // its silence path instead of touching the ring
    ps->sound->setUserData(NULL);
    gLastResult = ps->sound->release();
    if (gLastResult != FMOD_OK) return (int)gLastResult;
    faxe_pcmring_destroy(ps->ring);
    free(ps);
    faxe_handle_free(h);
    return (int)gLastResult;
}

//// Core channels

int fmod_chan_set_volume(int h, float volume) {
    FMOD::Channel* ch = resolveChannel(h);
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = ch->setVolume(volume);
    return (int)gLastResult;
}

float fmod_chan_get_volume(int h) {
    FMOD::Channel* ch = resolveChannel(h);
    float volume = 0.0f;
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0f; }
    gLastResult = ch->getVolume(&volume);
    return volume;
}

int fmod_chan_set_pitch(int h, float pitch) {
    FMOD::Channel* ch = resolveChannel(h);
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = ch->setPitch(pitch);
    return (int)gLastResult;
}

float fmod_chan_get_pitch(int h) {
    FMOD::Channel* ch = resolveChannel(h);
    float pitch = 0.0f;
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0f; }
    gLastResult = ch->getPitch(&pitch);
    return pitch;
}

int fmod_chan_set_paused(int h, bool paused) {
    FMOD::Channel* ch = resolveChannel(h);
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = ch->setPaused(paused);
    return (int)gLastResult;
}

bool fmod_chan_get_paused(int h) {
    FMOD::Channel* ch = resolveChannel(h);
    bool paused = false;
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    gLastResult = ch->getPaused(&paused);
    return paused;
}

bool fmod_chan_is_playing(int h) {
    FMOD::Channel* ch = resolveChannel(h);
    bool playing = false;
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    gLastResult = ch->isPlaying(&playing);
    if (gLastResult != FMOD_OK) return false;
    return playing;
}

int fmod_chan_stop(int h) {
    FMOD::Channel* ch = resolveChannel(h);
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    // The channel is finished either way, so the slot is freed even when
    // FMOD reports the channel already gone
    gLastResult = ch->stop();
    faxe_handle_free(h);
    // Stopping tears down the channel's DSP chain, which destroys its
    // connection objects
    faxe_handles_free_type(FAXE_TYPE_DSPCONN);
    return (int)gLastResult;
}

//// Core DSP effects

static void lincReclaimDeadLookups();

static inline FMOD::DSP* resolveDsp(int h) {
    return (FMOD::DSP*)faxe_handle_resolve(h, FAXE_TYPE_DSP);
}

static inline FMOD::ChannelGroup* resolveChanGroup(int h) {
    return (FMOD::ChannelGroup*)faxe_handle_resolve(h, FAXE_TYPE_CHANGROUP);
}

int fmod_dsp_create_by_type(int type) {
    FMOD::DSP* dsp = NULL;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    // Symbolic translation: FMOD renumbers this enum between releases,
    // so a raw cast creates the wrong effect on any other SDK version
    FMOD_DSP_TYPE dspType = faxe_dsp_type_from_binding(type);
    if (dspType == FAXE_DSP_TYPE_UNSUPPORTED) { gLastResult = FMOD_ERR_INVALID_PARAM; return 0; }
    gLastResult = gCoreSystem->createDSPByType(dspType, &dsp);
    if (gLastResult != FMOD_OK || !dsp) return 0;
    int handle = faxe_handle_alloc(dsp, FAXE_TYPE_DSP);
    if (handle == 0) {
        gLastResult = FMOD_ERR_MEMORY; /* handle table exhausted */
        dsp->release();
        return 0;
    }
    return handle;
}

int fmod_dsp_release(int h) {
    FMOD::DSP* dsp = resolveDsp(h);
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = dsp->release();
    if (gLastResult == FMOD_OK) {
        faxe_handle_free(h);
        // Releasing a DSP tears down its connections
        faxe_handles_free_type(FAXE_TYPE_DSPCONN);
    }
    return (int)gLastResult;
}

int fmod_dsp_set_param_float(int h, int index, float value) {
    FMOD::DSP* dsp = resolveDsp(h);
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = dsp->setParameterFloat(index, value);
    return (int)gLastResult;
}

float fmod_dsp_get_param_float(int h, int index) {
    FMOD::DSP* dsp = resolveDsp(h);
    float value = 0.0f;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0f; }
    gLastResult = dsp->getParameterFloat(index, &value, NULL, 0);
    return value;
}

int fmod_dsp_set_param_int(int h, int index, int value) {
    FMOD::DSP* dsp = resolveDsp(h);
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = dsp->setParameterInt(index, value);
    return (int)gLastResult;
}

int fmod_dsp_get_param_int(int h, int index) {
    FMOD::DSP* dsp = resolveDsp(h);
    int value = 0;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = dsp->getParameterInt(index, &value, NULL, 0);
    return value;
}

int fmod_dsp_set_param_bool(int h, int index, bool value) {
    FMOD::DSP* dsp = resolveDsp(h);
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = dsp->setParameterBool(index, value);
    return (int)gLastResult;
}

bool fmod_dsp_get_param_bool(int h, int index) {
    FMOD::DSP* dsp = resolveDsp(h);
    bool value = false;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    gLastResult = dsp->getParameterBool(index, &value, NULL, 0);
    return value;
}

int fmod_dsp_get_num_params(int h) {
    FMOD::DSP* dsp = resolveDsp(h);
    int count = 0;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = dsp->getNumParameters(&count);
    return count;
}

int fmod_dsp_get_type(int h) {
    FMOD::DSP* dsp = resolveDsp(h);
    FMOD_DSP_TYPE type = FMOD_DSP_TYPE_UNKNOWN;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = dsp->getType(&type);
    return faxe_dsp_type_to_binding(type);
}

int fmod_dsp_set_bypass(int h, bool bypass) {
    FMOD::DSP* dsp = resolveDsp(h);
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = dsp->setBypass(bypass);
    return (int)gLastResult;
}

bool fmod_dsp_get_bypass(int h) {
    FMOD::DSP* dsp = resolveDsp(h);
    bool bypass = false;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    gLastResult = dsp->getBypass(&bypass);
    return bypass;
}

int fmod_dsp_set_wet_dry_mix(int h, float prewet, float postwet, float dry) {
    FMOD::DSP* dsp = resolveDsp(h);
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = dsp->setWetDryMix(prewet, postwet, dry);
    return (int)gLastResult;
}

int fmod_dsp_set_active(int h, bool active) {
    FMOD::DSP* dsp = resolveDsp(h);
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = dsp->setActive(active);
    return (int)gLastResult;
}

int fmod_dsp_reset(int h) {
    FMOD::DSP* dsp = resolveDsp(h);
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = dsp->reset();
    return (int)gLastResult;
}

int fmod_dsp_set_metering_enabled(int h, bool input, bool output) {
    FMOD::DSP* dsp = resolveDsp(h);
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = dsp->setMeteringEnabled(input, output);
    return (int)gLastResult;
}

// fbuf = [0..ch-1] output peak, [ch..2ch-1] output rms. Returns channel count.
int fmod_dsp_get_metering(int h, ::Array<Float> fbuf) {
    FMOD::DSP* dsp = resolveDsp(h);
    FMOD_DSP_METERING_INFO info;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    memset(&info, 0, sizeof(info));
    gLastResult = dsp->getMeteringInfo(NULL, &info);
    if (gLastResult != FMOD_OK) return 0;
    for (int i = 0; i < info.numchannels && i < 32; i++) {
        fbuf[i] = (double)info.peaklevel[i];
        fbuf[info.numchannels + i] = (double)info.rmslevel[i];
    }
    return (int)info.numchannels;
}

// fbuf = channel-0 spectrum magnitudes, capped at maxBins. Returns bins written.
int fmod_dsp_fft_get_spectrum(int h, ::Array<Float> fbuf, int maxBins) {
    FMOD::DSP* dsp = resolveDsp(h);
    FMOD_DSP_PARAMETER_FFT* fft = NULL;
    unsigned int len = 0;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = dsp->getParameterData(FMOD_DSP_FFT_SPECTRUMDATA, (void**)&fft, &len, NULL, 0);
    if (gLastResult != FMOD_OK || !fft || fft->numchannels < 1) return 0;
    int count = fft->length < maxBins ? fft->length : maxBins;
    for (int i = 0; i < count; i++) fbuf[i] = (double)fft->spectrum[0][i];
    return count;
}

//// Core channel groups

int fmod_cg_get_master() {
    FMOD::ChannelGroup* group = NULL;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    gLastResult = gCoreSystem->getMasterChannelGroup(&group);
    if (gLastResult != FMOD_OK || !group) return 0;
    return faxe_handle_find_or_alloc(group, FAXE_TYPE_CHANGROUP);
}

int fmod_cg_create(const ::String& name) {
    FMOD::ChannelGroup* group = NULL;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    gLastResult = gCoreSystem->createChannelGroup(name.c_str(), &group);
    if (gLastResult != FMOD_OK || !group) return 0;
    int handle = faxe_handle_alloc(group, FAXE_TYPE_CHANGROUP);
    if (handle == 0) {
        gLastResult = FMOD_ERR_MEMORY; /* handle table exhausted */
        group->release();
        return 0;
    }
    return handle;
}

int fmod_cg_release(int h) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = group->release();
    if (gLastResult == FMOD_OK) {
        faxe_handle_free(h);
        // Releasing the group destroys the connections of every DSP in it
        faxe_handles_free_type(FAXE_TYPE_DSPCONN);
    }
    return (int)gLastResult;
}

int fmod_cg_set_volume(int h, float volume) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = group->setVolume(volume);
    return (int)gLastResult;
}

float fmod_cg_get_volume(int h) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    float volume = 0.0f;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0f; }
    gLastResult = group->getVolume(&volume);
    return volume;
}

int fmod_cg_set_pitch(int h, float pitch) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = group->setPitch(pitch);
    return (int)gLastResult;
}

float fmod_cg_get_pitch(int h) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    float pitch = 0.0f;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0f; }
    gLastResult = group->getPitch(&pitch);
    return pitch;
}

int fmod_cg_set_mute(int h, bool mute) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = group->setMute(mute);
    return (int)gLastResult;
}

bool fmod_cg_get_mute(int h) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    bool mute = false;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    gLastResult = group->getMute(&mute);
    return mute;
}

int fmod_cg_set_paused(int h, bool paused) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = group->setPaused(paused);
    return (int)gLastResult;
}

bool fmod_cg_get_paused(int h) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    bool paused = false;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    gLastResult = group->getPaused(&paused);
    return paused;
}

int fmod_cg_add_dsp(int h, int index, int dspHandle) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    FMOD::DSP* dsp = resolveDsp(dspHandle);
    if (!group || !dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = group->addDSP(index, dsp);
    return (int)gLastResult;
}

int fmod_cg_remove_dsp(int h, int dspHandle) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    FMOD::DSP* dsp = resolveDsp(dspHandle);
    if (!group || !dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = group->removeDSP(dsp);
    // Removing a DSP rebuilds that part of the graph and destroys the
    // affected connection objects
    if (gLastResult == FMOD_OK) faxe_handles_free_type(FAXE_TYPE_DSPCONN);
    return (int)gLastResult;
}

int fmod_cg_stop(int h) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = group->stop();
    return (int)gLastResult;
}

//// Core channel routing and effects

int fmod_chan_set_pan(int h, float pan) {
    FMOD::Channel* ch = resolveChannel(h);
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = ch->setPan(pan);
    return (int)gLastResult;
}

int fmod_chan_set_frequency(int h, float frequency) {
    FMOD::Channel* ch = resolveChannel(h);
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = ch->setFrequency(frequency);
    return (int)gLastResult;
}

float fmod_chan_get_frequency(int h) {
    FMOD::Channel* ch = resolveChannel(h);
    float frequency = 0.0f;
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0f; }
    gLastResult = ch->getFrequency(&frequency);
    return frequency;
}

int fmod_chan_set_loop_count(int h, int loopCount) {
    FMOD::Channel* ch = resolveChannel(h);
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = ch->setLoopCount(loopCount);
    return (int)gLastResult;
}

int fmod_chan_get_position(int h) {
    FMOD::Channel* ch = resolveChannel(h);
    unsigned int position = 0;
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return -1; }
    gLastResult = ch->getPosition(&position, FMOD_TIMEUNIT_MS);
    return gLastResult == FMOD_OK ? (int)position : -1;
}

int fmod_chan_set_position(int h, int positionMs) {
    FMOD::Channel* ch = resolveChannel(h);
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = ch->setPosition((unsigned int)positionMs, FMOD_TIMEUNIT_MS);
    return (int)gLastResult;
}

int fmod_chan_set_channel_group(int h, int groupHandle) {
    FMOD::Channel* ch = resolveChannel(h);
    FMOD::ChannelGroup* group = resolveChanGroup(groupHandle);
    if (!ch || !group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = ch->setChannelGroup(group);
    return (int)gLastResult;
}

int fmod_chan_add_dsp(int h, int index, int dspHandle) {
    FMOD::Channel* ch = resolveChannel(h);
    FMOD::DSP* dsp = resolveDsp(dspHandle);
    if (!ch || !dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = ch->addDSP(index, dsp);
    return (int)gLastResult;
}

int fmod_chan_remove_dsp(int h, int dspHandle) {
    FMOD::Channel* ch = resolveChannel(h);
    FMOD::DSP* dsp = resolveDsp(dspHandle);
    if (!ch || !dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = ch->removeDSP(dsp);
    // Removing a DSP rebuilds that part of the graph and destroys the
    // affected connection objects
    if (gLastResult == FMOD_OK) faxe_handles_free_type(FAXE_TYPE_DSPCONN);
    return (int)gLastResult;
}

int fmod_chan_set_3d_attributes(int h, float posX, float posY, float posZ, float velX, float velY, float velZ) {
    FMOD::Channel* ch = resolveChannel(h);
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    FMOD_VECTOR position = { posX, posY, posZ };
    FMOD_VECTOR velocity = { velX, velY, velZ };
    gLastResult = ch->set3DAttributes(&position, &velocity);
    return (int)gLastResult;
}

int fmod_chan_set_3d_min_max(int h, float minDist, float maxDist) {
    FMOD::Channel* ch = resolveChannel(h);
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = ch->set3DMinMaxDistance(minDist, maxDist);
    return (int)gLastResult;
}

int fmod_chan_set_reverb_wet(int h, int instance, float wet) {
    FMOD::Channel* ch = resolveChannel(h);
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = ch->setReverbProperties(instance, wet);
    return (int)gLastResult;
}

//// Studio bus to core group bridge

int fmod_bus_lock_channel_group(int h) {
    FMOD::Studio::Bus* bus = (FMOD::Studio::Bus*)faxe_handle_resolve(h, FAXE_TYPE_BUS);
    if (!bus) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = bus->lockChannelGroup();
    // The group is created on the async command queue. Flushing makes it
    // resolvable before the matching bus_get_channel_group call.
    if (gLastResult == FMOD_OK && gStudioSystem) {
        gStudioSystem->flushCommands();
    }
    return (int)gLastResult;
}

int fmod_bus_unlock_channel_group(int h) {
    FMOD::Studio::Bus* bus = (FMOD::Studio::Bus*)faxe_handle_resolve(h, FAXE_TYPE_BUS);
    if (!bus) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = bus->unlockChannelGroup();
    // The group may be destroyed once unlocked: reclaim its cached handle
    // before a recycled address can alias it
    if (gLastResult == FMOD_OK) lincReclaimDeadLookups();
    return (int)gLastResult;
}

int fmod_bus_get_channel_group(int h) {
    FMOD::Studio::Bus* bus = (FMOD::Studio::Bus*)faxe_handle_resolve(h, FAXE_TYPE_BUS);
    FMOD::ChannelGroup* group = NULL;
    if (!bus) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = bus->getChannelGroup(&group);
    if (gLastResult != FMOD_OK || !group) return 0;
    return faxe_handle_find_or_alloc(group, FAXE_TYPE_CHANGROUP);
}

//// Core system extras

int fmod_sys_play_dsp(int dspHandle, bool startPaused) {
    FMOD::DSP* dsp = resolveDsp(dspHandle);
    FMOD::Channel* channel = NULL;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    gLastResult = gCoreSystem->playDSP(dsp, NULL, startPaused, &channel);
    if (gLastResult != FMOD_OK || !channel) return 0;
    int handle = faxe_handle_alloc(channel, FAXE_TYPE_CHAN);
    if (handle == 0) {
        gLastResult = FMOD_ERR_MEMORY; /* handle table exhausted */
        channel->stop();
        return 0;
    }
    return handle;
}

// fbuf = 12 reverb property floats in fmod_common.h field order
// (DecayTime, EarlyDelay, LateDelay, HFReference, HFDecayRatio, Diffusion,
// Density, LowShelfFrequency, LowShelfGain, HighCut, EarlyLateMix, WetLevel)
int fmod_sys_set_reverb_properties(int instance, ::Array<Float> fbuf) {
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    FMOD_REVERB_PROPERTIES props;
    props.DecayTime = (float)fbuf[0];
    props.EarlyDelay = (float)fbuf[1];
    props.LateDelay = (float)fbuf[2];
    props.HFReference = (float)fbuf[3];
    props.HFDecayRatio = (float)fbuf[4];
    props.Diffusion = (float)fbuf[5];
    props.Density = (float)fbuf[6];
    props.LowShelfFrequency = (float)fbuf[7];
    props.LowShelfGain = (float)fbuf[8];
    props.HighCut = (float)fbuf[9];
    props.EarlyLateMix = (float)fbuf[10];
    props.WetLevel = (float)fbuf[11];
    gLastResult = gCoreSystem->setReverbProperties(instance, &props);
    return (int)gLastResult;
}

int fmod_sys_get_reverb_properties(int instance, ::Array<Float> fbuf) {
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    FMOD_REVERB_PROPERTIES props;
    memset(&props, 0, sizeof(props));
    gLastResult = gCoreSystem->getReverbProperties(instance, &props);
    if (gLastResult != FMOD_OK) return (int)gLastResult;
    fbuf[0] = (double)props.DecayTime;
    fbuf[1] = (double)props.EarlyDelay;
    fbuf[2] = (double)props.LateDelay;
    fbuf[3] = (double)props.HFReference;
    fbuf[4] = (double)props.HFDecayRatio;
    fbuf[5] = (double)props.Diffusion;
    fbuf[6] = (double)props.Density;
    fbuf[7] = (double)props.LowShelfFrequency;
    fbuf[8] = (double)props.LowShelfGain;
    fbuf[9] = (double)props.HighCut;
    fbuf[10] = (double)props.EarlyLateMix;
    fbuf[11] = (double)props.WetLevel;
    return (int)gLastResult;
}

//// Core DSP connection graph

static inline FMOD::DSPConnection* resolveDspConn(int h) {
    return (FMOD::DSPConnection*)faxe_handle_resolve(h, FAXE_TYPE_DSPCONN);
}

static inline FMOD::Reverb3D* resolveReverb3d(int h) {
    return (FMOD::Reverb3D*)faxe_handle_resolve(h, FAXE_TYPE_REVERB3D);
}

int fmod_dsp_add_input(int h, int inputHandle, int type) {
    FMOD::DSP* dsp = resolveDsp(h);
    FMOD::DSP* input = resolveDsp(inputHandle);
    FMOD::DSPConnection* conn = NULL;
    if (!dsp || !input) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = dsp->addInput(input, &conn, (FMOD_DSPCONNECTION_TYPE)type);
    if (gLastResult != FMOD_OK || !conn) return 0;
    return faxe_handle_find_or_alloc(conn, FAXE_TYPE_DSPCONN);
}

int fmod_dsp_disconnect_from(int h, int inputHandle) {
    FMOD::DSP* dsp = resolveDsp(h);
    FMOD::DSP* input = resolveDsp(inputHandle);
    if (!dsp || !input) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = dsp->disconnectFrom(input, NULL);
    // The connection object died: reclaim its cached handle before a
    // recycled address can alias it
    // Graph changes invalidate connection objects on the mixer's schedule,
    // so every connection handle is dropped deterministically here
    if (gLastResult == FMOD_OK) faxe_handles_free_type(FAXE_TYPE_DSPCONN);
    return (int)gLastResult;
}

int fmod_dsp_disconnect_all(int h, bool inputs, bool outputs) {
    FMOD::DSP* dsp = resolveDsp(h);
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = dsp->disconnectAll(inputs, outputs);
    if (gLastResult == FMOD_OK) faxe_handles_free_type(FAXE_TYPE_DSPCONN);
    return (int)gLastResult;
}

int fmod_dsp_get_num_inputs(int h) {
    FMOD::DSP* dsp = resolveDsp(h);
    int count = 0;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = dsp->getNumInputs(&count);
    return count;
}

int fmod_dsp_get_num_outputs(int h) {
    FMOD::DSP* dsp = resolveDsp(h);
    int count = 0;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = dsp->getNumOutputs(&count);
    return count;
}

int fmod_dsp_get_input_dsp(int h, int index) {
    FMOD::DSP* dsp = resolveDsp(h);
    FMOD::DSP* input = NULL;
    FMOD::DSPConnection* conn = NULL;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = dsp->getInput(index, &input, &conn);
    if (gLastResult != FMOD_OK || !input) return 0;
    return faxe_handle_find_or_alloc(input, FAXE_TYPE_DSP);
}

int fmod_dsp_get_input_connection(int h, int index) {
    FMOD::DSP* dsp = resolveDsp(h);
    FMOD::DSP* input = NULL;
    FMOD::DSPConnection* conn = NULL;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = dsp->getInput(index, &input, &conn);
    if (gLastResult != FMOD_OK || !conn) return 0;
    return faxe_handle_find_or_alloc(conn, FAXE_TYPE_DSPCONN);
}

int fmod_dspconn_set_mix(int h, float mix) {
    FMOD::DSPConnection* conn = resolveDspConn(h);
    if (!conn) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = conn->setMix(mix);
    return (int)gLastResult;
}

float fmod_dspconn_get_mix(int h) {
    FMOD::DSPConnection* conn = resolveDspConn(h);
    float mix = 0.0f;
    if (!conn) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0f; }
    gLastResult = conn->getMix(&mix);
    return mix;
}

int fmod_dspconn_get_type(int h) {
    FMOD::DSPConnection* conn = resolveDspConn(h);
    FMOD_DSPCONNECTION_TYPE type = FMOD_DSPCONNECTION_TYPE_STANDARD;
    if (!conn) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = conn->getType(&type);
    return (int)type;
}

//// Core channel group nesting

int fmod_cg_add_group(int h, int childHandle) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    FMOD::ChannelGroup* child = resolveChanGroup(childHandle);
    if (!group || !child) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = group->addGroup(child, true, NULL);
    return (int)gLastResult;
}

int fmod_cg_get_num_groups(int h) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    int count = 0;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = group->getNumGroups(&count);
    return count;
}

int fmod_cg_get_group(int h, int index) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    FMOD::ChannelGroup* child = NULL;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = group->getGroup(index, &child);
    if (gLastResult != FMOD_OK || !child) return 0;
    return faxe_handle_find_or_alloc(child, FAXE_TYPE_CHANGROUP);
}

int fmod_cg_get_parent_group(int h) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    FMOD::ChannelGroup* parent = NULL;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = group->getParentGroup(&parent);
    if (gLastResult != FMOD_OK || !parent) return 0;
    return faxe_handle_find_or_alloc(parent, FAXE_TYPE_CHANGROUP);
}

//// Core channel spatial and control extras

int fmod_chan_set_mute(int h, bool mute) {
    FMOD::Channel* ch = resolveChannel(h);
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = ch->setMute(mute);
    return (int)gLastResult;
}

bool fmod_chan_get_mute(int h) {
    FMOD::Channel* ch = resolveChannel(h);
    bool mute = false;
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    gLastResult = ch->getMute(&mute);
    return mute;
}

int fmod_chan_set_low_pass_gain(int h, float gain) {
    FMOD::Channel* ch = resolveChannel(h);
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = ch->setLowPassGain(gain);
    return (int)gLastResult;
}

int fmod_chan_set_mode(int h, int mode) {
    FMOD::Channel* ch = resolveChannel(h);
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = ch->setMode((FMOD_MODE)mode);
    return (int)gLastResult;
}

int fmod_chan_set_3d_cone_settings(int h, float insideAngle, float outsideAngle, float outsideVolume) {
    FMOD::Channel* ch = resolveChannel(h);
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = ch->set3DConeSettings(insideAngle, outsideAngle, outsideVolume);
    return (int)gLastResult;
}

int fmod_chan_set_3d_cone_orientation(int h, float x, float y, float z) {
    FMOD::Channel* ch = resolveChannel(h);
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    FMOD_VECTOR direction = { x, y, z };
    gLastResult = ch->set3DConeOrientation(&direction);
    return (int)gLastResult;
}

int fmod_chan_set_3d_occlusion(int h, float direct, float reverb) {
    FMOD::Channel* ch = resolveChannel(h);
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = ch->set3DOcclusion(direct, reverb);
    return (int)gLastResult;
}

// fbuf out: [0]=direct [1]=reverb
int fmod_chan_get_3d_occlusion(int h, ::Array<Float> fbuf) {
    FMOD::Channel* ch = resolveChannel(h);
    float direct = 0.0f;
    float reverb = 0.0f;
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = ch->get3DOcclusion(&direct, &reverb);
    fbuf[0] = (double)direct;
    fbuf[1] = (double)reverb;
    return (int)gLastResult;
}

int fmod_chan_set_3d_spread(int h, float angle) {
    FMOD::Channel* ch = resolveChannel(h);
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = ch->set3DSpread(angle);
    return (int)gLastResult;
}

int fmod_chan_set_3d_level(int h, float level) {
    FMOD::Channel* ch = resolveChannel(h);
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = ch->set3DLevel(level);
    return (int)gLastResult;
}

int fmod_chan_set_3d_doppler_level(int h, float level) {
    FMOD::Channel* ch = resolveChannel(h);
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = ch->set3DDopplerLevel(level);
    return (int)gLastResult;
}

// fbuf in: out*in gains row-major
int fmod_chan_set_mix_matrix(int h, ::Array<Float> fbuf, int outChannels, int inChannels) {
    FMOD::Channel* ch = resolveChannel(h);
    float matrix[32 * 32];
    int total = outChannels * inChannels;
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    if (total < 0 || total > 32 * 32) { gLastResult = FMOD_ERR_INVALID_PARAM; return (int)gLastResult; }
    for (int i = 0; i < total; i++) matrix[i] = (float)fbuf[i];
    gLastResult = ch->setMixMatrix(matrix, outChannels, inChannels, 0);
    return (int)gLastResult;
}

//// Core scheduling (DSP clocks cross as doubles: exact to 2^53 samples)

// fbuf out: [0]=channel clock [1]=parent group clock
int fmod_chan_get_dsp_clock(int h, ::Array<Float> fbuf) {
    FMOD::Channel* ch = resolveChannel(h);
    unsigned long long clock = 0;
    unsigned long long parent = 0;
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = ch->getDSPClock(&clock, &parent);
    fbuf[0] = (double)clock;
    fbuf[1] = (double)parent;
    return (int)gLastResult;
}

int fmod_chan_set_delay(int h, double startClock, double endClock, bool stopChannels) {
    FMOD::Channel* ch = resolveChannel(h);
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = ch->setDelay((unsigned long long)startClock, (unsigned long long)endClock, stopChannels);
    return (int)gLastResult;
}

int fmod_chan_add_fade_point(int h, double clock, float volume) {
    FMOD::Channel* ch = resolveChannel(h);
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = ch->addFadePoint((unsigned long long)clock, volume);
    return (int)gLastResult;
}

int fmod_chan_set_fade_point_ramp(int h, double clock, float volume) {
    FMOD::Channel* ch = resolveChannel(h);
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = ch->setFadePointRamp((unsigned long long)clock, volume);
    return (int)gLastResult;
}

int fmod_chan_remove_fade_points(int h, double startClock, double endClock) {
    FMOD::Channel* ch = resolveChannel(h);
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = ch->removeFadePoints((unsigned long long)startClock, (unsigned long long)endClock);
    return (int)gLastResult;
}

int fmod_cg_get_dsp_clock(int h, ::Array<Float> fbuf) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    unsigned long long clock = 0;
    unsigned long long parent = 0;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = group->getDSPClock(&clock, &parent);
    fbuf[0] = (double)clock;
    fbuf[1] = (double)parent;
    return (int)gLastResult;
}

int fmod_cg_set_delay(int h, double startClock, double endClock, bool stopChannels) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = group->setDelay((unsigned long long)startClock, (unsigned long long)endClock, stopChannels);
    return (int)gLastResult;
}

int fmod_cg_add_fade_point(int h, double clock, float volume) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = group->addFadePoint((unsigned long long)clock, volume);
    return (int)gLastResult;
}

int fmod_cg_set_fade_point_ramp(int h, double clock, float volume) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = group->setFadePointRamp((unsigned long long)clock, volume);
    return (int)gLastResult;
}

int fmod_cg_remove_fade_points(int h, double startClock, double endClock) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = group->removeFadePoints((unsigned long long)startClock, (unsigned long long)endClock);
    return (int)gLastResult;
}

//// Core reverb zones

int fmod_sys_create_reverb3d() {
    FMOD::Reverb3D* reverb = NULL;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    gLastResult = gCoreSystem->createReverb3D(&reverb);
    if (gLastResult != FMOD_OK || !reverb) return 0;
    int handle = faxe_handle_alloc(reverb, FAXE_TYPE_REVERB3D);
    if (handle == 0) {
        gLastResult = FMOD_ERR_MEMORY; /* handle table exhausted */
        reverb->release();
        return 0;
    }
    return handle;
}

int fmod_r3d_release(int h) {
    FMOD::Reverb3D* reverb = resolveReverb3d(h);
    if (!reverb) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = reverb->release();
    if (gLastResult == FMOD_OK) faxe_handle_free(h);
    return (int)gLastResult;
}

int fmod_r3d_set_3d_attributes(int h, float x, float y, float z, float minDist, float maxDist) {
    FMOD::Reverb3D* reverb = resolveReverb3d(h);
    if (!reverb) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    FMOD_VECTOR position = { x, y, z };
    gLastResult = reverb->set3DAttributes(&position, minDist, maxDist);
    return (int)gLastResult;
}

// fbuf: 12 reverb property floats, DecayTime..WetLevel in header order
int fmod_r3d_set_properties(int h, ::Array<Float> fbuf) {
    FMOD::Reverb3D* reverb = resolveReverb3d(h);
    if (!reverb) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    FMOD_REVERB_PROPERTIES props;
    props.DecayTime = (float)fbuf[0];
    props.EarlyDelay = (float)fbuf[1];
    props.LateDelay = (float)fbuf[2];
    props.HFReference = (float)fbuf[3];
    props.HFDecayRatio = (float)fbuf[4];
    props.Diffusion = (float)fbuf[5];
    props.Density = (float)fbuf[6];
    props.LowShelfFrequency = (float)fbuf[7];
    props.LowShelfGain = (float)fbuf[8];
    props.HighCut = (float)fbuf[9];
    props.EarlyLateMix = (float)fbuf[10];
    props.WetLevel = (float)fbuf[11];
    gLastResult = reverb->setProperties(&props);
    return (int)gLastResult;
}

int fmod_r3d_get_properties(int h, ::Array<Float> fbuf) {
    FMOD::Reverb3D* reverb = resolveReverb3d(h);
    if (!reverb) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    FMOD_REVERB_PROPERTIES props;
    memset(&props, 0, sizeof(props));
    gLastResult = reverb->getProperties(&props);
    if (gLastResult != FMOD_OK) return (int)gLastResult;
    fbuf[0] = (double)props.DecayTime;
    fbuf[1] = (double)props.EarlyDelay;
    fbuf[2] = (double)props.LateDelay;
    fbuf[3] = (double)props.HFReference;
    fbuf[4] = (double)props.HFDecayRatio;
    fbuf[5] = (double)props.Diffusion;
    fbuf[6] = (double)props.Density;
    fbuf[7] = (double)props.LowShelfFrequency;
    fbuf[8] = (double)props.LowShelfGain;
    fbuf[9] = (double)props.HighCut;
    fbuf[10] = (double)props.EarlyLateMix;
    fbuf[11] = (double)props.WetLevel;
    return (int)gLastResult;
}

int fmod_r3d_set_active(int h, bool active) {
    FMOD::Reverb3D* reverb = resolveReverb3d(h);
    if (!reverb) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = reverb->setActive(active);
    return (int)gLastResult;
}

//// Core sound surface

int fmod_core_create_sound_pcm(::Array<unsigned char> data, int len, int sampleRate, int channels) {
    FMOD::Sound* sound = NULL;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    if (data == null() || len <= 0 || len > data->length || sampleRate <= 0 || channels < 1 || channels > 2) {
        gLastResult = FMOD_ERR_INVALID_PARAM;
        return 0;
    }
    FMOD_CREATESOUNDEXINFO exinfo;
    memset(&exinfo, 0, sizeof(exinfo));
    exinfo.cbsize = sizeof(exinfo);
    exinfo.length = (unsigned int)len;
    exinfo.numchannels = channels;
    exinfo.defaultfrequency = sampleRate;
    exinfo.format = FMOD_SOUND_FORMAT_PCM16;
    gLastResult = gCoreSystem->createSound((const char*)&data[0], FMOD_OPENMEMORY | FMOD_OPENRAW, &exinfo, &sound);
    if (gLastResult != FMOD_OK || !sound) return 0;
    int handle = faxe_handle_alloc(sound, FAXE_TYPE_SOUND);
    if (handle == 0) {
        gLastResult = FMOD_ERR_MEMORY; /* handle table exhausted */
        sound->release();
        return 0;
    }
    return handle;
}

int fmod_core_play_sound(int h, bool startPaused) {
    FMOD::Sound* sound = resolveSound(h);
    FMOD::Channel* channel = NULL;
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    gLastResult = gCoreSystem->playSound(sound, NULL, startPaused, &channel);
    if (gLastResult != FMOD_OK || !channel) return 0;
    int handle = faxe_handle_alloc(channel, FAXE_TYPE_CHAN);
    if (handle == 0) {
        gLastResult = FMOD_ERR_MEMORY; /* handle table exhausted */
        channel->stop();
        return 0;
    }
    return handle;
}

int fmod_sound_set_defaults(int h, float frequency, int priority) {
    FMOD::Sound* sound = resolveSound(h);
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = sound->setDefaults(frequency, priority);
    return (int)gLastResult;
}

// fbuf out: [0]=frequency [1]=priority
int fmod_sound_get_defaults(int h, ::Array<Float> fbuf) {
    FMOD::Sound* sound = resolveSound(h);
    float frequency = 0.0f;
    int priority = 0;
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = sound->getDefaults(&frequency, &priority);
    fbuf[0] = (double)frequency;
    fbuf[1] = (double)priority;
    return (int)gLastResult;
}

int fmod_sound_set_loop_points(int h, int startMs, int endMs) {
    FMOD::Sound* sound = resolveSound(h);
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = sound->setLoopPoints((unsigned int)startMs, FMOD_TIMEUNIT_MS, (unsigned int)endMs, FMOD_TIMEUNIT_MS);
    return (int)gLastResult;
}

// ibuf out: [0]=loop start ms [1]=loop end ms
int fmod_sound_get_loop_points(int h, ::Array<int> ibuf) {
    FMOD::Sound* sound = resolveSound(h);
    unsigned int start = 0;
    unsigned int end = 0;
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = sound->getLoopPoints(&start, FMOD_TIMEUNIT_MS, &end, FMOD_TIMEUNIT_MS);
    ibuf[0] = (int)start;
    ibuf[1] = (int)end;
    return (int)gLastResult;
}

int fmod_sound_set_mode(int h, int mode) {
    FMOD::Sound* sound = resolveSound(h);
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = sound->setMode((FMOD_MODE)mode);
    return (int)gLastResult;
}

int fmod_sound_get_mode(int h) {
    FMOD::Sound* sound = resolveSound(h);
    FMOD_MODE mode = 0;
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = sound->getMode(&mode);
    return (int)mode;
}

// ibuf out: [0]=channels [1]=bits
int fmod_sound_get_format(int h, ::Array<int> ibuf) {
    FMOD::Sound* sound = resolveSound(h);
    FMOD_SOUND_TYPE type = FMOD_SOUND_TYPE_UNKNOWN;
    FMOD_SOUND_FORMAT format = FMOD_SOUND_FORMAT_NONE;
    int channels = 0;
    int bits = 0;
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = sound->getFormat(&type, &format, &channels, &bits);
    ibuf[0] = channels;
    ibuf[1] = bits;
    return (int)gLastResult;
}

int fmod_sound_get_open_state(int h) {
    FMOD::Sound* sound = resolveSound(h);
    FMOD_OPENSTATE state = FMOD_OPENSTATE_READY;
    unsigned int buffered = 0;
    bool starving = false;
    bool diskBusy = false;
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return -1; }
    gLastResult = sound->getOpenState(&state, &buffered, &starving, &diskBusy);
    return gLastResult == FMOD_OK ? (int)state : -1;
}

//// Core system extras (slice 3)

// ibuf out: [0]=all channels [1]=real (audible) channels
int fmod_sys_get_channels_playing(::Array<int> ibuf) {
    int all = 0;
    int real = 0;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = gCoreSystem->getChannelsPlaying(&all, &real);
    ibuf[0] = all;
    ibuf[1] = real;
    return (int)gLastResult;
}

int fmod_sys_mixer_suspend() {
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = gCoreSystem->mixerSuspend();
    return (int)gLastResult;
}

int fmod_sys_mixer_resume() {
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = gCoreSystem->mixerResume();
    return (int)gLastResult;
}

// ibuf out: [0]=sample rate [1]=speaker mode [2]=raw speaker count
int fmod_sys_get_software_format(::Array<int> ibuf) {
    int rate = 0;
    FMOD_SPEAKERMODE mode = FMOD_SPEAKERMODE_DEFAULT;
    int raw = 0;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = gCoreSystem->getSoftwareFormat(&rate, &mode, &raw);
    ibuf[0] = rate;
    ibuf[1] = (int)mode;
    ibuf[2] = raw;
    return (int)gLastResult;
}

// ibuf out: [0]=exclusive us [1]=inclusive us (needs profiling enabled)
int fmod_dsp_get_cpu_usage(int h, ::Array<int> ibuf) {
    FMOD::DSP* dsp = resolveDsp(h);
    unsigned int exclusive = 0;
    unsigned int inclusive = 0;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = dsp->getCPUUsage(&exclusive, &inclusive);
    ibuf[0] = (int)exclusive;
    ibuf[1] = (int)inclusive;
    return (int)gLastResult;
}

//// Channel callbacks and sync points

#define FAXE_CB_CHAN_END 0x40000001u
#define FAXE_CB_CHAN_SYNCPOINT 0x40000002u

// Runs on whichever thread pumps System::update. Pure C data handling:
// reads the handle from the channel's user data and enqueues, never
// touching the runtime.
static FMOD_RESULT F_CALLBACK lincChannelCallback(FMOD_CHANNELCONTROL* channelcontrol, FMOD_CHANNELCONTROL_TYPE controltype, FMOD_CHANNELCONTROL_CALLBACK_TYPE callbacktype, void* commanddata1, void* commanddata2) {
    void* userData = NULL;
    int handle;
    FaxeCbEvent event;
    (void)commanddata2;
    if (controltype != FMOD_CHANNELCONTROL_CHANNEL) return FMOD_OK;
    ((FMOD::Channel*)channelcontrol)->getUserData(&userData);
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

int fmod_chan_set_callback(int h, bool enabled) {
    FMOD::Channel* ch = resolveChannel(h);
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    if (enabled) {
        ch->setUserData((void*)(intptr_t)h);
        gLastResult = ch->setCallback(lincChannelCallback);
    } else {
        gLastResult = ch->setCallback(NULL);
        ch->setUserData(NULL);
    }
    return (int)gLastResult;
}

int fmod_sound_add_sync_point(int h, int offsetMs, const ::String& name) {
    FMOD::Sound* sound = resolveSound(h);
    FMOD_SYNCPOINT* point = NULL;
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = sound->addSyncPoint((unsigned int)offsetMs, FMOD_TIMEUNIT_MS, name.c_str(), &point);
    return (int)gLastResult;
}

int fmod_sound_delete_sync_point(int h, int index) {
    FMOD::Sound* sound = resolveSound(h);
    FMOD_SYNCPOINT* point = NULL;
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = sound->getSyncPoint(index, &point);
    if (gLastResult != FMOD_OK) return (int)gLastResult;
    gLastResult = sound->deleteSyncPoint(point);
    return (int)gLastResult;
}

int fmod_sound_get_num_sync_points(int h) {
    FMOD::Sound* sound = resolveSound(h);
    int count = 0;
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = sound->getNumSyncPoints(&count);
    return count;
}

const char* fmod_sound_get_sync_point_name(int h, int index) {
    FMOD::Sound* sound = resolveSound(h);
    FMOD_SYNCPOINT* point = NULL;
    unsigned int offset = 0;
    gStringBuf[0] = '\0';
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return gStringBuf; }
    gLastResult = sound->getSyncPoint(index, &point);
    if (gLastResult != FMOD_OK) return gStringBuf;
    gLastResult = sound->getSyncPointInfo(point, gStringBuf, sizeof(gStringBuf), &offset, FMOD_TIMEUNIT_MS);
    if (gLastResult != FMOD_OK) gStringBuf[0] = '\0';
    return gStringBuf;
}

int fmod_sound_get_sync_point_offset(int h, int index) {
    FMOD::Sound* sound = resolveSound(h);
    FMOD_SYNCPOINT* point = NULL;
    unsigned int offset = 0;
    if (!sound) { gLastResult = FMOD_ERR_INVALID_HANDLE; return -1; }
    gLastResult = sound->getSyncPoint(index, &point);
    if (gLastResult != FMOD_OK) return -1;
    gLastResult = sound->getSyncPointInfo(point, NULL, 0, &offset, FMOD_TIMEUNIT_MS);
    return gLastResult == FMOD_OK ? (int)offset : -1;
}

//// Sound groups

static inline FMOD::SoundGroup* resolveSoundGroup(int h) {
    return (FMOD::SoundGroup*)faxe_handle_resolve(h, FAXE_TYPE_SOUNDGROUP);
}

int fmod_sys_create_sound_group(const ::String& name) {
    FMOD::SoundGroup* group = NULL;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    gLastResult = gCoreSystem->createSoundGroup(name.c_str(), &group);
    if (gLastResult != FMOD_OK || !group) return 0;
    int handle = faxe_handle_alloc(group, FAXE_TYPE_SOUNDGROUP);
    if (handle == 0) {
        gLastResult = FMOD_ERR_MEMORY; /* handle table exhausted */
        group->release();
        return 0;
    }
    return handle;
}

int fmod_sys_get_master_sound_group() {
    FMOD::SoundGroup* group = NULL;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    gLastResult = gCoreSystem->getMasterSoundGroup(&group);
    if (gLastResult != FMOD_OK || !group) return 0;
    return faxe_handle_find_or_alloc(group, FAXE_TYPE_SOUNDGROUP);
}

int fmod_sg_release(int h) {
    FMOD::SoundGroup* group = resolveSoundGroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = group->release();
    if (gLastResult == FMOD_OK) faxe_handle_free(h);
    return (int)gLastResult;
}

int fmod_sg_set_max_audible(int h, int maxAudible) {
    FMOD::SoundGroup* group = resolveSoundGroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = group->setMaxAudible(maxAudible);
    return (int)gLastResult;
}

int fmod_sg_get_max_audible(int h) {
    FMOD::SoundGroup* group = resolveSoundGroup(h);
    int maxAudible = 0;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = group->getMaxAudible(&maxAudible);
    return maxAudible;
}

int fmod_sg_set_max_audible_behavior(int h, int behavior) {
    FMOD::SoundGroup* group = resolveSoundGroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = group->setMaxAudibleBehavior((FMOD_SOUNDGROUP_BEHAVIOR)behavior);
    return (int)gLastResult;
}

int fmod_sg_get_max_audible_behavior(int h) {
    FMOD::SoundGroup* group = resolveSoundGroup(h);
    FMOD_SOUNDGROUP_BEHAVIOR behavior = FMOD_SOUNDGROUP_BEHAVIOR_FAIL;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = group->getMaxAudibleBehavior(&behavior);
    return (int)behavior;
}

int fmod_sg_set_mute_fade_speed(int h, float speed) {
    FMOD::SoundGroup* group = resolveSoundGroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = group->setMuteFadeSpeed(speed);
    return (int)gLastResult;
}

int fmod_sg_get_num_sounds(int h) {
    FMOD::SoundGroup* group = resolveSoundGroup(h);
    int count = 0;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = group->getNumSounds(&count);
    return count;
}

int fmod_sg_stop(int h) {
    FMOD::SoundGroup* group = resolveSoundGroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = group->stop();
    return (int)gLastResult;
}

int fmod_sound_set_sound_group(int h, int groupHandle) {
    FMOD::Sound* sound = resolveSound(h);
    FMOD::SoundGroup* group = resolveSoundGroup(groupHandle);
    if (!sound || !group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = sound->setSoundGroup(group);
    return (int)gLastResult;
}

//// System 3D settings and drivers

int fmod_sys_set_3d_settings(float doppler, float distanceFactor, float rolloffScale) {
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = gCoreSystem->set3DSettings(doppler, distanceFactor, rolloffScale);
    return (int)gLastResult;
}

// fbuf out: [0]=doppler [1]=distance factor [2]=rolloff scale
int fmod_sys_get_3d_settings(::Array<Float> fbuf) {
    float doppler = 0.0f;
    float distanceFactor = 0.0f;
    float rolloffScale = 0.0f;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = gCoreSystem->get3DSettings(&doppler, &distanceFactor, &rolloffScale);
    fbuf[0] = (double)doppler;
    fbuf[1] = (double)distanceFactor;
    fbuf[2] = (double)rolloffScale;
    return (int)gLastResult;
}

int fmod_sys_get_num_drivers() {
    int count = 0;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    gLastResult = gCoreSystem->getNumDrivers(&count);
    return count;
}

const char* fmod_sys_get_driver_name(int id) {
    gStringBuf[0] = '\0';
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return gStringBuf; }
    gLastResult = gCoreSystem->getDriverInfo(id, gStringBuf, sizeof(gStringBuf), NULL, NULL, NULL, NULL);
    if (gLastResult != FMOD_OK) gStringBuf[0] = '\0';
    return gStringBuf;
}

//// Getter symmetry for the routing and spatial setters

int fmod_chan_get_loop_count(int h) {
    FMOD::Channel* ch = resolveChannel(h);
    int loopCount = 0;
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = ch->getLoopCount(&loopCount);
    return loopCount;
}

float fmod_chan_get_low_pass_gain(int h) {
    FMOD::Channel* ch = resolveChannel(h);
    float gain = 0.0f;
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0f; }
    gLastResult = ch->getLowPassGain(&gain);
    return gain;
}

int fmod_chan_get_mode(int h) {
    FMOD::Channel* ch = resolveChannel(h);
    FMOD_MODE mode = 0;
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = ch->getMode(&mode);
    return (int)mode;
}

// fbuf out: [0]=inside angle [1]=outside angle [2]=outside volume
int fmod_chan_get_3d_cone_settings(int h, ::Array<Float> fbuf) {
    FMOD::Channel* ch = resolveChannel(h);
    float inside = 0.0f;
    float outside = 0.0f;
    float volume = 0.0f;
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = ch->get3DConeSettings(&inside, &outside, &volume);
    fbuf[0] = (double)inside;
    fbuf[1] = (double)outside;
    fbuf[2] = (double)volume;
    return (int)gLastResult;
}

float fmod_chan_get_3d_spread(int h) {
    FMOD::Channel* ch = resolveChannel(h);
    float angle = 0.0f;
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0f; }
    gLastResult = ch->get3DSpread(&angle);
    return angle;
}

float fmod_chan_get_3d_level(int h) {
    FMOD::Channel* ch = resolveChannel(h);
    float level = 0.0f;
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0f; }
    gLastResult = ch->get3DLevel(&level);
    return level;
}

float fmod_chan_get_3d_doppler_level(int h) {
    FMOD::Channel* ch = resolveChannel(h);
    float level = 0.0f;
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0f; }
    gLastResult = ch->get3DDopplerLevel(&level);
    return level;
}

// fbuf out: [0]=min [1]=max
int fmod_chan_get_3d_min_max(int h, ::Array<Float> fbuf) {
    FMOD::Channel* ch = resolveChannel(h);
    float minDist = 0.0f;
    float maxDist = 0.0f;
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = ch->get3DMinMaxDistance(&minDist, &maxDist);
    fbuf[0] = (double)minDist;
    fbuf[1] = (double)maxDist;
    return (int)gLastResult;
}

// fbuf out: [0..2]=position [3..5]=velocity
int fmod_chan_get_3d_attributes(int h, ::Array<Float> fbuf) {
    FMOD::Channel* ch = resolveChannel(h);
    FMOD_VECTOR position;
    FMOD_VECTOR velocity;
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    memset(&position, 0, sizeof(position));
    memset(&velocity, 0, sizeof(velocity));
    gLastResult = ch->get3DAttributes(&position, &velocity);
    fbuf[0] = (double)position.x;
    fbuf[1] = (double)position.y;
    fbuf[2] = (double)position.z;
    fbuf[3] = (double)velocity.x;
    fbuf[4] = (double)velocity.y;
    fbuf[5] = (double)velocity.z;
    return (int)gLastResult;
}

// fbuf out: [0]=start clock [1]=end clock [2]=stop channels (0/1)
int fmod_chan_get_delay(int h, ::Array<Float> fbuf) {
    FMOD::Channel* ch = resolveChannel(h);
    unsigned long long startClock = 0;
    unsigned long long endClock = 0;
    bool stopChannels = false;
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = ch->getDelay(&startClock, &endClock, &stopChannels);
    fbuf[0] = (double)startClock;
    fbuf[1] = (double)endClock;
    fbuf[2] = stopChannels ? 1.0 : 0.0;
    return (int)gLastResult;
}

// fbuf out: [0]=prewet [1]=postwet [2]=dry
int fmod_dsp_get_wet_dry_mix(int h, ::Array<Float> fbuf) {
    FMOD::DSP* dsp = resolveDsp(h);
    float prewet = 0.0f;
    float postwet = 0.0f;
    float dry = 0.0f;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = dsp->getWetDryMix(&prewet, &postwet, &dry);
    fbuf[0] = (double)prewet;
    fbuf[1] = (double)postwet;
    fbuf[2] = (double)dry;
    return (int)gLastResult;
}

bool fmod_dsp_get_active(int h) {
    FMOD::DSP* dsp = resolveDsp(h);
    bool active = false;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    gLastResult = dsp->getActive(&active);
    return active;
}

// ibuf out: [0]=input enabled [1]=output enabled
int fmod_dsp_get_metering_enabled(int h, ::Array<int> ibuf) {
    FMOD::DSP* dsp = resolveDsp(h);
    bool inputEnabled = false;
    bool outputEnabled = false;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = dsp->getMeteringEnabled(&inputEnabled, &outputEnabled);
    ibuf[0] = inputEnabled ? 1 : 0;
    ibuf[1] = outputEnabled ? 1 : 0;
    return (int)gLastResult;
}

//// Bank loading from memory

int fmod_sys_load_bank_memory(::Array<unsigned char> data, int len) {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    if (data == null() || len <= 0) { gLastResult = FMOD_ERR_INVALID_PARAM; return 0; }
    if (len > data->length) len = data->length;
    FMOD::Studio::Bank* bank = NULL;
    // FMOD_STUDIO_LOAD_MEMORY copies the buffer, so the caller's bytes are
    // free as soon as this returns
    gLastResult = gStudioSystem->loadBankMemory((const char*)&data[0], len,
        FMOD_STUDIO_LOAD_MEMORY, FMOD_STUDIO_LOAD_BANK_NORMAL, &bank);
    if (gLastResult != FMOD_OK || !bank) return 0;
    return faxe_handle_find_or_alloc(bank, FAXE_TYPE_BANK);
}

//// Event instance core bridge

int fmod_evi_get_channel_group(int h) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    FMOD::ChannelGroup* group = NULL;
    gLastResult = instance->getChannelGroup(&group);
    if (gLastResult != FMOD_OK || !group) return 0;
    int cgHandle = faxe_handle_find_or_alloc(group, FAXE_TYPE_CHANGROUP);
    // The group dies with the instance, outside every sweep trigger. Record
    // the handle on the context so the DESTROYED drain reclaims the slot
    // before a recycled group address can alias it. A restarted instance
    // gets a new group, so a differing previous handle is dead: reclaim it
    // here for the same reason.
    FaxeInstCtx* ctx = instanceCtx(instance);
    if (ctx) {
        if (ctx->cgHandle != 0 && ctx->cgHandle != cgHandle) {
            faxe_handle_free(ctx->cgHandle);
        }
        ctx->cgHandle = cgHandle;
    }
    return cgHandle;
}

//// Command capture and replay

static inline FMOD::Studio::CommandReplay* resolveReplay(int h) {
    return (FMOD::Studio::CommandReplay*)faxe_handle_resolve(h, FAXE_TYPE_REPLAY);
}

int fmod_sys_start_command_capture(const ::String& path) {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = gStudioSystem->startCommandCapture(path.c_str(), FMOD_STUDIO_COMMANDCAPTURE_NORMAL);
    return (int)gLastResult;
}

int fmod_sys_stop_command_capture() {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = gStudioSystem->stopCommandCapture();
    return (int)gLastResult;
}

int fmod_sys_load_command_replay(const ::String& path) {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    FMOD::Studio::CommandReplay* replay = NULL;
    gLastResult = gStudioSystem->loadCommandReplay(path.c_str(), FMOD_STUDIO_COMMANDREPLAY_NORMAL, &replay);
    if (gLastResult != FMOD_OK || !replay) return 0;
    int handle = faxe_handle_alloc(replay, FAXE_TYPE_REPLAY);
    if (handle == 0) {
        gLastResult = FMOD_ERR_MEMORY; /* handle table exhausted */
        replay->release();
        return 0;
    }
    return handle;
}

int fmod_replay_release(int h) {
    FMOD::Studio::CommandReplay* replay = resolveReplay(h);
    if (!replay) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = replay->release();
    if (gLastResult == FMOD_OK) faxe_handle_free(h);
    return (int)gLastResult;
}

bool fmod_replay_is_valid(int h) {
    FMOD::Studio::CommandReplay* replay = resolveReplay(h);
    return replay != NULL && replay->isValid();
}

int fmod_replay_start(int h) {
    FMOD::Studio::CommandReplay* replay = resolveReplay(h);
    if (!replay) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = replay->start();
    return (int)gLastResult;
}

int fmod_replay_stop(int h) {
    FMOD::Studio::CommandReplay* replay = resolveReplay(h);
    if (!replay) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = replay->stop();
    return (int)gLastResult;
}

int fmod_replay_set_paused(int h, bool paused) {
    FMOD::Studio::CommandReplay* replay = resolveReplay(h);
    if (!replay) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = replay->setPaused(paused);
    return (int)gLastResult;
}

bool fmod_replay_get_paused(int h) {
    FMOD::Studio::CommandReplay* replay = resolveReplay(h);
    bool paused = false;
    if (!replay) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    gLastResult = replay->getPaused(&paused);
    return paused;
}

int fmod_replay_seek_to_time(int h, int timeMs) {
    FMOD::Studio::CommandReplay* replay = resolveReplay(h);
    if (!replay) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = replay->seekToTime((float)timeMs / 1000.0f);
    return (int)gLastResult;
}

float fmod_replay_get_length(int h) {
    FMOD::Studio::CommandReplay* replay = resolveReplay(h);
    float seconds = 0.0f;
    if (!replay) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0f; }
    gLastResult = replay->getLength(&seconds);
    return seconds;
}

//// Channel priority, virtualization, and remaining getters

int fmod_chan_set_priority(int h, int priority) {
    FMOD::Channel* ch = resolveChannel(h);
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = ch->setPriority(priority);
    return (int)gLastResult;
}

int fmod_chan_get_priority(int h) {
    FMOD::Channel* ch = resolveChannel(h);
    int priority = 0;
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = ch->getPriority(&priority);
    return priority;
}

bool fmod_chan_is_virtual(int h) {
    FMOD::Channel* ch = resolveChannel(h);
    bool isVirtual = false;
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    gLastResult = ch->isVirtual(&isVirtual);
    return isVirtual;
}

float fmod_chan_get_audibility(int h) {
    FMOD::Channel* ch = resolveChannel(h);
    float audibility = 0.0f;
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0f; }
    gLastResult = ch->getAudibility(&audibility);
    return audibility;
}

int fmod_chan_set_volume_ramp(int h, bool ramp) {
    FMOD::Channel* ch = resolveChannel(h);
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = ch->setVolumeRamp(ramp);
    return (int)gLastResult;
}

bool fmod_chan_get_volume_ramp(int h) {
    FMOD::Channel* ch = resolveChannel(h);
    bool ramp = false;
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    gLastResult = ch->getVolumeRamp(&ramp);
    return ramp;
}

// Borrowed reference: the returned sound belongs to whoever created it, so
// releasing a handle obtained this way is a caller error
int fmod_chan_get_current_sound(int h) {
    FMOD::Channel* ch = resolveChannel(h);
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    FMOD::Sound* sound = NULL;
    gLastResult = ch->getCurrentSound(&sound);
    if (gLastResult != FMOD_OK || !sound) return 0;
    return faxe_handle_find_or_alloc(sound, FAXE_TYPE_SOUND);
}

int fmod_chan_set_loop_points(int h, int startMs, int endMs) {
    FMOD::Channel* ch = resolveChannel(h);
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = ch->setLoopPoints((unsigned int)startMs, FMOD_TIMEUNIT_MS, (unsigned int)endMs, FMOD_TIMEUNIT_MS);
    return (int)gLastResult;
}

int fmod_chan_get_loop_points(int h, ::Array<int> ibuf) {
    FMOD::Channel* ch = resolveChannel(h);
    unsigned int start = 0;
    unsigned int end = 0;
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = ch->getLoopPoints(&start, FMOD_TIMEUNIT_MS, &end, FMOD_TIMEUNIT_MS);
    ibuf[0] = (int)start;
    ibuf[1] = (int)end;
    return (int)gLastResult;
}

float fmod_chan_get_reverb_wet(int h, int instance) {
    FMOD::Channel* ch = resolveChannel(h);
    float wet = 0.0f;
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0f; }
    gLastResult = ch->getReverbProperties(instance, &wet);
    return wet;
}

int fmod_chan_get_index(int h) {
    FMOD::Channel* ch = resolveChannel(h);
    int index = -1;
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return -1; }
    gLastResult = ch->getIndex(&index);
    return gLastResult == FMOD_OK ? index : -1;
}

int fmod_chan_get_3d_cone_orientation(int h, ::Array<Float> fbuf) {
    FMOD::Channel* ch = resolveChannel(h);
    FMOD_VECTOR direction;
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    memset(&direction, 0, sizeof(direction));
    gLastResult = ch->get3DConeOrientation(&direction);
    fbuf[0] = (double)direction.x;
    fbuf[1] = (double)direction.y;
    fbuf[2] = (double)direction.z;
    return (int)gLastResult;
}

int fmod_chan_get_num_dsps(int h) {
    FMOD::Channel* ch = resolveChannel(h);
    int count = 0;
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = ch->getNumDSPs(&count);
    return count;
}

int fmod_chan_get_dsp(int h, int index) {
    FMOD::Channel* ch = resolveChannel(h);
    if (!ch) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    FMOD::DSP* dsp = NULL;
    gLastResult = ch->getDSP(index, &dsp);
    if (gLastResult != FMOD_OK || !dsp) return 0;
    return faxe_handle_find_or_alloc(dsp, FAXE_TYPE_DSP);
}

//// Sound name, group getter, and loop count

const char* fmod_sound_get_name(int h) {
    gStringBuf[0] = '\0';
    FMOD::Sound* snd = resolveSound(h);
    if (!snd) { gLastResult = FMOD_ERR_INVALID_HANDLE; return gStringBuf; }
    gLastResult = snd->getName(gStringBuf, sizeof(gStringBuf));
    if (gLastResult != FMOD_OK) gStringBuf[0] = '\0';
    return gStringBuf;
}

int fmod_sound_get_sound_group(int h) {
    FMOD::Sound* snd = resolveSound(h);
    if (!snd) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    FMOD::SoundGroup* group = NULL;
    gLastResult = snd->getSoundGroup(&group);
    if (gLastResult != FMOD_OK || !group) return 0;
    return faxe_handle_find_or_alloc(group, FAXE_TYPE_SOUNDGROUP);
}

int fmod_sound_get_loop_count(int h) {
    FMOD::Sound* snd = resolveSound(h);
    int loopCount = 0;
    if (!snd) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = snd->getLoopCount(&loopCount);
    return loopCount;
}

int fmod_sound_set_loop_count(int h, int loopCount) {
    FMOD::Sound* snd = resolveSound(h);
    if (!snd) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = snd->setLoopCount(loopCount);
    return (int)gLastResult;
}

//// Sound group volume and counters

int fmod_sg_set_volume(int h, float volume) {
    FMOD::SoundGroup* group = resolveSoundGroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = group->setVolume(volume);
    return (int)gLastResult;
}

float fmod_sg_get_volume(int h) {
    FMOD::SoundGroup* group = resolveSoundGroup(h);
    float volume = 0.0f;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0f; }
    gLastResult = group->getVolume(&volume);
    return volume;
}

int fmod_sg_get_num_playing(int h) {
    FMOD::SoundGroup* group = resolveSoundGroup(h);
    int count = 0;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = group->getNumPlaying(&count);
    return count;
}

float fmod_sg_get_mute_fade_speed(int h) {
    FMOD::SoundGroup* group = resolveSoundGroup(h);
    float speed = 0.0f;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0f; }
    gLastResult = group->getMuteFadeSpeed(&speed);
    return speed;
}

//// Output device selection

int fmod_sys_set_driver(int id) {
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = gCoreSystem->setDriver(id);
    return (int)gLastResult;
}

int fmod_sys_get_driver() {
    int id = 0;
    if (!gCoreSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    gLastResult = gCoreSystem->getDriver(&id);
    return id;
}

//// DSP data params, info, and output traversal

int fmod_dsp_set_param_data(int h, int index, ::Array<unsigned char> data, int len) {
    FMOD::DSP* dsp = resolveDsp(h);
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    if (data == null() || len <= 0) { gLastResult = FMOD_ERR_INVALID_PARAM; return (int)gLastResult; }
    if (len > data->length) len = data->length;
    gLastResult = dsp->setParameterData(index, (void*)&data[0], (unsigned int)len);
    return (int)gLastResult;
}

bool fmod_dsp_get_idle(int h) {
    FMOD::DSP* dsp = resolveDsp(h);
    bool idle = false;
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    gLastResult = dsp->getIdle(&idle);
    return idle;
}

const char* fmod_dsp_get_info_name(int h) {
    gStringBuf[0] = '\0';
    FMOD::DSP* dsp = resolveDsp(h);
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return gStringBuf; }
    gLastResult = dsp->getInfo(gStringBuf, 0, 0, 0, 0);
    if (gLastResult != FMOD_OK) gStringBuf[0] = '\0';
    return gStringBuf;
}

int fmod_dsp_get_output_dsp(int h, int index) {
    FMOD::DSP* dsp = resolveDsp(h);
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    FMOD::DSP* output = NULL;
    FMOD::DSPConnection* conn = NULL;
    gLastResult = dsp->getOutput(index, &output, &conn);
    if (gLastResult != FMOD_OK || !output) return 0;
    return faxe_handle_find_or_alloc(output, FAXE_TYPE_DSP);
}

int fmod_dsp_get_output_connection(int h, int index) {
    FMOD::DSP* dsp = resolveDsp(h);
    if (!dsp) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    FMOD::DSP* output = NULL;
    FMOD::DSPConnection* conn = NULL;
    gLastResult = dsp->getOutput(index, &output, &conn);
    if (gLastResult != FMOD_OK || !conn) return 0;
    return faxe_handle_find_or_alloc(conn, FAXE_TYPE_DSPCONN);
}

int fmod_dspconn_get_input_dsp(int h) {
    FMOD::DSPConnection* conn = resolveDspConn(h);
    if (!conn) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    FMOD::DSP* dsp = NULL;
    gLastResult = conn->getInput(&dsp);
    if (gLastResult != FMOD_OK || !dsp) return 0;
    return faxe_handle_find_or_alloc(dsp, FAXE_TYPE_DSP);
}

int fmod_dspconn_get_output_dsp(int h) {
    FMOD::DSPConnection* conn = resolveDspConn(h);
    if (!conn) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    FMOD::DSP* dsp = NULL;
    gLastResult = conn->getOutput(&dsp);
    if (gLastResult != FMOD_OK || !dsp) return 0;
    return faxe_handle_find_or_alloc(dsp, FAXE_TYPE_DSP);
}

//// Reverb3D getters

bool fmod_r3d_get_active(int h) {
    FMOD::Reverb3D* reverb = resolveReverb3d(h);
    bool active = false;
    if (!reverb) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    gLastResult = reverb->getActive(&active);
    return active;
}

int fmod_r3d_get_3d_attributes(int h, ::Array<Float> fbuf) {
    FMOD::Reverb3D* reverb = resolveReverb3d(h);
    FMOD_VECTOR position;
    float minDist = 0.0f;
    float maxDist = 0.0f;
    if (!reverb) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    memset(&position, 0, sizeof(position));
    gLastResult = reverb->get3DAttributes(&position, &minDist, &maxDist);
    fbuf[0] = (double)position.x;
    fbuf[1] = (double)position.y;
    fbuf[2] = (double)position.z;
    fbuf[3] = (double)minDist;
    fbuf[4] = (double)maxDist;
    return (int)gLastResult;
}

//// Channel group spatial mirror and remaining control surface

int fmod_cg_set_pan(int h, float pan) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = group->setPan(pan);
    return (int)gLastResult;
}

int fmod_cg_set_low_pass_gain(int h, float gain) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = group->setLowPassGain(gain);
    return (int)gLastResult;
}

int fmod_cg_set_mode(int h, int mode) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = group->setMode((FMOD_MODE)mode);
    return (int)gLastResult;
}

int fmod_cg_get_mode(int h) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    FMOD_MODE mode = 0;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = group->getMode(&mode);
    return (int)mode;
}

int fmod_cg_set_3d_attributes(int h, float posX, float posY, float posZ, float velX, float velY, float velZ) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    FMOD_VECTOR position = { posX, posY, posZ };
    FMOD_VECTOR velocity = { velX, velY, velZ };
    gLastResult = group->set3DAttributes(&position, &velocity);
    return (int)gLastResult;
}

int fmod_cg_get_3d_attributes(int h, ::Array<Float> fbuf) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    FMOD_VECTOR position;
    FMOD_VECTOR velocity;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    memset(&position, 0, sizeof(position));
    memset(&velocity, 0, sizeof(velocity));
    gLastResult = group->get3DAttributes(&position, &velocity);
    fbuf[0] = (double)position.x;
    fbuf[1] = (double)position.y;
    fbuf[2] = (double)position.z;
    fbuf[3] = (double)velocity.x;
    fbuf[4] = (double)velocity.y;
    fbuf[5] = (double)velocity.z;
    return (int)gLastResult;
}

int fmod_cg_set_3d_min_max(int h, float minDist, float maxDist) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = group->set3DMinMaxDistance(minDist, maxDist);
    return (int)gLastResult;
}

int fmod_cg_get_3d_min_max(int h, ::Array<Float> fbuf) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    float minDist = 0.0f;
    float maxDist = 0.0f;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = group->get3DMinMaxDistance(&minDist, &maxDist);
    fbuf[0] = (double)minDist;
    fbuf[1] = (double)maxDist;
    return (int)gLastResult;
}

int fmod_cg_set_3d_occlusion(int h, float direct, float reverb) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = group->set3DOcclusion(direct, reverb);
    return (int)gLastResult;
}

int fmod_cg_set_3d_level(int h, float level) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = group->set3DLevel(level);
    return (int)gLastResult;
}

float fmod_cg_get_3d_level(int h) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    float level = 0.0f;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0f; }
    gLastResult = group->get3DLevel(&level);
    return level;
}

int fmod_cg_set_3d_spread(int h, float angle) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = group->set3DSpread(angle);
    return (int)gLastResult;
}

float fmod_cg_get_3d_spread(int h) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    float angle = 0.0f;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0f; }
    gLastResult = group->get3DSpread(&angle);
    return angle;
}

int fmod_cg_set_3d_doppler_level(int h, float level) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = group->set3DDopplerLevel(level);
    return (int)gLastResult;
}

float fmod_cg_get_3d_doppler_level(int h) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    float level = 0.0f;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0f; }
    gLastResult = group->get3DDopplerLevel(&level);
    return level;
}

int fmod_cg_set_3d_cone_settings(int h, float insideAngle, float outsideAngle, float outsideVolume) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = group->set3DConeSettings(insideAngle, outsideAngle, outsideVolume);
    return (int)gLastResult;
}

int fmod_cg_get_3d_cone_settings(int h, ::Array<Float> fbuf) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    float insideAngle = 0.0f;
    float outsideAngle = 0.0f;
    float outsideVolume = 0.0f;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = group->get3DConeSettings(&insideAngle, &outsideAngle, &outsideVolume);
    fbuf[0] = (double)insideAngle;
    fbuf[1] = (double)outsideAngle;
    fbuf[2] = (double)outsideVolume;
    return (int)gLastResult;
}

int fmod_cg_set_3d_cone_orientation(int h, float x, float y, float z) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    FMOD_VECTOR direction;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    direction.x = x; direction.y = y; direction.z = z;
    gLastResult = group->set3DConeOrientation(&direction);
    return (int)gLastResult;
}

int fmod_cg_get_3d_cone_orientation(int h, ::Array<Float> fbuf) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    FMOD_VECTOR direction;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    memset(&direction, 0, sizeof(direction));
    gLastResult = group->get3DConeOrientation(&direction);
    fbuf[0] = (double)direction.x;
    fbuf[1] = (double)direction.y;
    fbuf[2] = (double)direction.z;
    return (int)gLastResult;
}

int fmod_cg_set_reverb_wet(int h, int instance, float wet) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = group->setReverbProperties(instance, wet);
    return (int)gLastResult;
}

float fmod_cg_get_reverb_wet(int h, int instance) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    float wet = 0.0f;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0f; }
    gLastResult = group->getReverbProperties(instance, &wet);
    return wet;
}

int fmod_cg_set_mix_matrix(int h, ::Array<Float> fbuf, int outChannels, int inChannels) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    float matrix[32 * 32];
    int total = outChannels * inChannels;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    if (total < 0 || total > 32 * 32) { gLastResult = FMOD_ERR_INVALID_PARAM; return (int)gLastResult; }
    for (int i = 0; i < total; i++) matrix[i] = (float)fbuf[i];
    gLastResult = group->setMixMatrix(matrix, outChannels, inChannels, 0);
    return (int)gLastResult;
}

int fmod_cg_set_volume_ramp(int h, bool ramp) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = group->setVolumeRamp(ramp);
    return (int)gLastResult;
}

bool fmod_cg_get_volume_ramp(int h) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    bool ramp = false;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    gLastResult = group->getVolumeRamp(&ramp);
    return ramp;
}

float fmod_cg_get_audibility(int h) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    float audibility = 0.0f;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0f; }
    gLastResult = group->getAudibility(&audibility);
    return audibility;
}

const char* fmod_cg_get_name(int h) {
    gStringBuf[0] = '\0';
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return gStringBuf; }
    gLastResult = group->getName(gStringBuf, sizeof(gStringBuf));
    if (gLastResult != FMOD_OK) gStringBuf[0] = '\0';
    return gStringBuf;
}

int fmod_cg_get_num_channels(int h) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    int count = 0;
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    gLastResult = group->getNumChannels(&count);
    return count;
}

int fmod_cg_get_channel(int h, int index) {
    FMOD::ChannelGroup* group = resolveChanGroup(h);
    if (!group) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    FMOD::Channel* ch = NULL;
    gLastResult = group->getChannel(index, &ch);
    if (gLastResult != FMOD_OK || !ch) return 0;
    return faxe_handle_find_or_alloc(ch, FAXE_TYPE_CHAN);
}

// Drain protocol: cb_next pops the oldest queued event into a static slot;
// the accessors read fields from that slot. Haxe thread only.
static FaxeCbEvent gCbCurrent;

// Final cleanup for a destroyed instance, on the game thread: the handle
// slot, the channel-group handle minted for it, and the context itself.
// Both frees are generation-checked, so slots already reclaimed elsewhere
// (release, or a recycled slot) are left alone.
static void freeDestroyedCtx(FaxeInstCtx* ctx) {
    if (ctx->cgHandle != 0) faxe_handle_free(ctx->cgHandle);
    if (ctx->handle > 0) faxe_handle_free(ctx->handle);
    faxe_instctx_destroy(ctx);
}

bool fmod_cb_next() {
    if (faxe_cbq_pop(&gCbCurrent) != 1) {
        // Drain end: dispose of contexts whose DESTROYED events were
        // dropped by the ring's overflow policy.
        FaxeInstCtx* orphan = (FaxeInstCtx*)faxe_cbq_take_orphans();
        while (orphan) {
            FaxeInstCtx* next = (FaxeInstCtx*)orphan->qnext;
            freeDestroyedCtx(orphan);
            orphan = next;
        }
        return false;
    }
    if (gCbCurrent.opaque) {
        freeDestroyedCtx((FaxeInstCtx*)gCbCurrent.opaque);
        gCbCurrent.opaque = NULL;
    }
    return true;
}

int fmod_cb_handle() {
    return gCbCurrent.handle;
}

int fmod_cb_type() {
    return (int)gCbCurrent.type;
}

int fmod_cb_int(int index) {
    switch (index) {
        case 0: return gCbCurrent.i1;
        case 1: return gCbCurrent.i2;
        case 2: return gCbCurrent.i3;
        case 3: return gCbCurrent.i4;
        case 4: return gCbCurrent.i5;
        default: return 0;
    }
}

double fmod_cb_float() {
    return (double)gCbCurrent.f1;
}

const char* fmod_cb_string() {
    return gCbCurrent.str;
}

bool fmod_cb_take_overflow() {
    return faxe_cbq_take_overflow() == 1;
}

//// Studio System

// Shared helpers for the 2.0 bindings.

static inline FMOD_STUDIO_PARAMETER_ID makeParamId(int data1, int data2) {
    FMOD_STUDIO_PARAMETER_ID id;
    id.data1 = (unsigned int)data1;
    id.data2 = (unsigned int)data2;
    return id;
}

// Copies text into gStringBuf ("" for NULL) and returns it.
static const char* copyToStringBuf(const char* text) {
    if (!text) { gStringBuf[0] = '\0'; return gStringBuf; }
    strncpy(gStringBuf, text, sizeof(gStringBuf) - 1);
    gStringBuf[sizeof(gStringBuf) - 1] = '\0';
    return gStringBuf;
}

// fbuf: [0]=min [1]=max [2]=default; ibuf: [0]=type [1]=flags [2]=id1 [3]=id2;
// returns the parameter name (via gStringBuf).
static const char* writeParamDescription(const FMOD_STUDIO_PARAMETER_DESCRIPTION* param, ::Array<Float> fbuf, ::Array<int> ibuf) {
    fbuf[0] = (double)param->minimum;
    fbuf[1] = (double)param->maximum;
    fbuf[2] = (double)param->defaultvalue;
    ibuf[0] = (int)param->type;
    ibuf[1] = (int)param->flags;
    ibuf[2] = (int)param->id.data1;
    ibuf[3] = (int)param->id.data2;
    return copyToStringBuf(param->name);
}

// fbuf[0..11] = position xyz, velocity xyz, forward xyz, up xyz
static void writeAttributes(const FMOD_3D_ATTRIBUTES* a, ::Array<Float> fbuf) {
    fbuf[0] = (double)a->position.x; fbuf[1] = (double)a->position.y; fbuf[2] = (double)a->position.z;
    fbuf[3] = (double)a->velocity.x; fbuf[4] = (double)a->velocity.y; fbuf[5] = (double)a->velocity.z;
    fbuf[6] = (double)a->forward.x; fbuf[7] = (double)a->forward.y; fbuf[8] = (double)a->forward.z;
    fbuf[9] = (double)a->up.x; fbuf[10] = (double)a->up.y; fbuf[11] = (double)a->up.z;
}

static FMOD_3D_ATTRIBUTES makeAttributes(double px, double py, double pz, double vx, double vy, double vz, double fx, double fy, double fz, double ux, double uy, double uz) {
    FMOD_3D_ATTRIBUTES a;
    a.position.x = (float)px; a.position.y = (float)py; a.position.z = (float)pz;
    a.velocity.x = (float)vx; a.velocity.y = (float)vy; a.velocity.z = (float)vz;
    a.forward.x = (float)fx; a.forward.y = (float)fy; a.forward.z = (float)fz;
    a.up.x = (float)ux; a.up.y = (float)uy; a.up.z = (float)uz;
    return a;
}

int fmod_sys_last_result() {
    return (int)gLastResult;
}

// Settings-driven init: numChannels <= 0 falls back to 128; sampleRate 0 =
// FMOD default; speakerMode 0 = default speaker mode; studioFlags bit0 =
// live update. Keeps the FMOD_WAVWRITER env branch (CI recording), which
// forces 48000/stereo and wins over the requested format. Idempotent:
// returns FMOD_OK when already initialized.
int fmod_sys_init_ex(int numChannels, int sampleRate, int speakerMode, int studioFlags) {
    if (gStudioSystem != NULL) { gLastResult = FMOD_OK; return (int)gLastResult; }
    if (numChannels <= 0) numChannels = 128;

    gLastResult = FMOD::Studio::System::create(&gStudioSystem);
    if (gLastResult != FMOD_OK) return (int)gLastResult;

    // FMOD_WAVWRITER env var: write mixed audio to WAV file (for CI recording)
    const char* wavWriterPath = std::getenv("FMOD_WAVWRITER");
    void* extradriverdata = nullptr;
    if (wavWriterPath && wavWriterPath[0] != '\0') {
        gStudioSystem->getCoreSystem(&gCoreSystem);
        gCoreSystem->setOutput(FMOD_OUTPUTTYPE_WAVWRITER);
        // Explicit stereo format so WAV header has correct channel count (Windows needs this)
        gCoreSystem->setSoftwareFormat(48000, FMOD_SPEAKERMODE_STEREO, 0);
        extradriverdata = (void*)wavWriterPath;
    } else if (sampleRate > 0 || speakerMode > 0) {
        gStudioSystem->getCoreSystem(&gCoreSystem);
        gCoreSystem->setSoftwareFormat(sampleRate, (FMOD_SPEAKERMODE)speakerMode, 0);
    }

    FMOD_STUDIO_INITFLAGS studioInitFlags = (studioFlags & 1) ? FMOD_STUDIO_INIT_LIVEUPDATE : FMOD_STUDIO_INIT_NORMAL;
    gLastResult = gStudioSystem->initialize(numChannels, studioInitFlags, FMOD_INIT_NORMAL, extradriverdata);
    if (gLastResult != FMOD_OK) {
        gStudioSystem->release();
        gStudioSystem = NULL;
        // The wavwriter and format branches above may have cached the core
        // system, which the release just destroyed
        gCoreSystem = NULL;
        return (int)gLastResult;
    }

    gStudioSystem->getCoreSystem(&gCoreSystem);
    faxe_cbq_init();
    gLastResult = FMOD_OK;
    return (int)gLastResult;
}

// FMOD_Debug_Initialize level mapping (0=none 1=error 2=warning 3=log),
// TTY mode, no file logging. The logging-stripped FMOD libs report
// FMOD_ERR_UNSUPPORTED; that result is passed through.
int fmod_sys_set_debug_level(int level) {
    FMOD_DEBUG_FLAGS flags = FMOD_DEBUG_LEVEL_NONE;
    if (level == 1) flags = FMOD_DEBUG_LEVEL_ERROR;
    else if (level == 2) flags = FMOD_DEBUG_LEVEL_WARNING;
    else if (level >= 3) flags = FMOD_DEBUG_LEVEL_LOG;
    gLastResult = FMOD::Debug_Initialize(flags, FMOD_DEBUG_MODE_TTY, NULL, NULL);
    return (int)gLastResult;
}

int fmod_sys_get_bus(const ::String& path) {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    FMOD::Studio::Bus* bus = NULL;
    gLastResult = gStudioSystem->getBus(path.c_str(), &bus);
    if (gLastResult != FMOD_OK || !bus) return 0;
    return faxe_handle_find_or_alloc(bus, FAXE_TYPE_BUS);
}

int fmod_sys_get_bus_by_id(const ::String& guid) {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    FMOD_GUID id;
    if (!faxe_guid_parse(guid.c_str(), &id)) { gLastResult = FMOD_ERR_INVALID_PARAM; return 0; }
    FMOD::Studio::Bus* bus = NULL;
    gLastResult = gStudioSystem->getBusByID(&id, &bus);
    if (gLastResult != FMOD_OK || !bus) return 0;
    return faxe_handle_find_or_alloc(bus, FAXE_TYPE_BUS);
}

int fmod_sys_get_event(const ::String& path) {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    FMOD::Studio::EventDescription* desc = NULL;
    gLastResult = gStudioSystem->getEvent(path.c_str(), &desc);
    if (gLastResult != FMOD_OK || !desc) return 0;
    return faxe_handle_find_or_alloc(desc, FAXE_TYPE_EVD);
}

int fmod_sys_get_event_by_id(const ::String& guid) {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    FMOD_GUID id;
    if (!faxe_guid_parse(guid.c_str(), &id)) { gLastResult = FMOD_ERR_INVALID_PARAM; return 0; }
    FMOD::Studio::EventDescription* desc = NULL;
    gLastResult = gStudioSystem->getEventByID(&id, &desc);
    if (gLastResult != FMOD_OK || !desc) return 0;
    return faxe_handle_find_or_alloc(desc, FAXE_TYPE_EVD);
}

int fmod_sys_get_vca(const ::String& path) {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    FMOD::Studio::VCA* vca = NULL;
    gLastResult = gStudioSystem->getVCA(path.c_str(), &vca);
    if (gLastResult != FMOD_OK || !vca) return 0;
    return faxe_handle_find_or_alloc(vca, FAXE_TYPE_VCA);
}

int fmod_sys_get_vca_by_id(const ::String& guid) {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    FMOD_GUID id;
    if (!faxe_guid_parse(guid.c_str(), &id)) { gLastResult = FMOD_ERR_INVALID_PARAM; return 0; }
    FMOD::Studio::VCA* vca = NULL;
    gLastResult = gStudioSystem->getVCAByID(&id, &vca);
    if (gLastResult != FMOD_OK || !vca) return 0;
    return faxe_handle_find_or_alloc(vca, FAXE_TYPE_VCA);
}

int fmod_sys_get_bank(const ::String& path) {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    FMOD::Studio::Bank* bank = NULL;
    gLastResult = gStudioSystem->getBank(path.c_str(), &bank);
    if (gLastResult != FMOD_OK || !bank) return 0;
    return faxe_handle_find_or_alloc(bank, FAXE_TYPE_BANK);
}

int fmod_sys_get_bank_by_id(const ::String& guid) {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    FMOD_GUID id;
    if (!faxe_guid_parse(guid.c_str(), &id)) { gLastResult = FMOD_ERR_INVALID_PARAM; return 0; }
    FMOD::Studio::Bank* bank = NULL;
    gLastResult = gStudioSystem->getBankByID(&id, &bank);
    if (gLastResult != FMOD_OK || !bank) return 0;
    return faxe_handle_find_or_alloc(bank, FAXE_TYPE_BANK);
}

int fmod_sys_get_bank_count() {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    int count = 0;
    gLastResult = gStudioSystem->getBankCount(&count);
    return count;
}

// Fills out with bank handles, returns the count written (capped at FAXE_LIST_MAX).
int fmod_sys_get_bank_list(::Array<int> out) {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    FMOD::Studio::Bank** banks = (FMOD::Studio::Bank**)gListBuf;
    int count = 0;
    gLastResult = gStudioSystem->getBankList(banks, FAXE_LIST_MAX, &count);
    if (gLastResult != FMOD_OK) return 0;
    int written = 0;
    for (int i = 0; i < count; i++) {
        int handle = faxe_handle_find_or_alloc(banks[i], FAXE_TYPE_BANK);
        if (handle != 0) out[written++] = handle;
    }
    return written;
}

// path -> GUID string ("" + lastResult on failure)
const char* fmod_sys_lookup_id(const ::String& path) {
    gStringBuf[0] = '\0';
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return gStringBuf; }
    FMOD_GUID id;
    gLastResult = gStudioSystem->lookupID(path.c_str(), &id);
    if (gLastResult == FMOD_OK) faxe_guid_format(&id, gStringBuf, sizeof(gStringBuf));
    return gStringBuf;
}

// GUID string -> path
const char* fmod_sys_lookup_path(const ::String& guid) {
    gStringBuf[0] = '\0';
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return gStringBuf; }
    FMOD_GUID id;
    if (!faxe_guid_parse(guid.c_str(), &id)) { gLastResult = FMOD_ERR_INVALID_PARAM; return gStringBuf; }
    int retrieved = 0;
    gLastResult = gStudioSystem->lookupPath(&id, gStringBuf, sizeof(gStringBuf), &retrieved);
    if (gLastResult != FMOD_OK) gStringBuf[0] = '\0';
    return gStringBuf;
}

double fmod_sys_get_param_by_name(const ::String& name) {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0.0; }
    float value = 0.0f;
    gLastResult = gStudioSystem->getParameterByName(name.c_str(), &value, NULL);
    return (double)value;
}

double fmod_sys_get_param_by_name_final(const ::String& name) {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0.0; }
    float value = 0.0f;
    float finalValue = 0.0f;
    gLastResult = gStudioSystem->getParameterByName(name.c_str(), &value, &finalValue);
    return (double)finalValue;
}

int fmod_sys_set_param_by_name(const ::String& name, double value, bool ignoreSeekSpeed) {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = gStudioSystem->setParameterByName(name.c_str(), (float)value, ignoreSeekSpeed);
    return (int)gLastResult;
}

int fmod_sys_set_param_by_name_with_label(const ::String& name, const ::String& label, bool ignoreSeekSpeed) {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = gStudioSystem->setParameterByNameWithLabel(name.c_str(), label.c_str(), ignoreSeekSpeed);
    return (int)gLastResult;
}

double fmod_sys_get_param_by_id(int id1, int id2) {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0.0; }
    float value = 0.0f;
    gLastResult = gStudioSystem->getParameterByID(makeParamId(id1, id2), &value, NULL);
    return (double)value;
}

double fmod_sys_get_param_by_id_final(int id1, int id2) {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0.0; }
    float value = 0.0f;
    float finalValue = 0.0f;
    gLastResult = gStudioSystem->getParameterByID(makeParamId(id1, id2), &value, &finalValue);
    return (double)finalValue;
}

int fmod_sys_set_param_by_id(int id1, int id2, double value, bool ignoreSeekSpeed) {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = gStudioSystem->setParameterByID(makeParamId(id1, id2), (float)value, ignoreSeekSpeed);
    return (int)gLastResult;
}

int fmod_sys_set_param_by_id_with_label(int id1, int id2, const ::String& label, bool ignoreSeekSpeed) {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = gStudioSystem->setParameterByIDWithLabel(makeParamId(id1, id2), label.c_str(), ignoreSeekSpeed);
    return (int)gLastResult;
}

int fmod_sys_get_parameter_description_count() {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    int count = 0;
    gLastResult = gStudioSystem->getParameterDescriptionCount(&count);
    return count;
}

// FMOD has no by-index getter for global parameters, so this reads the
// description list up to index+1 entries and picks the requested one.
const char* fmod_sys_get_parameter_description_by_index(int index, ::Array<Float> fbuf, ::Array<int> ibuf) {
    gStringBuf[0] = '\0';
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return gStringBuf; }
    if (index < 0 || index >= FAXE_LIST_MAX) { gLastResult = FMOD_ERR_INVALID_PARAM; return gStringBuf; }
    FMOD_STUDIO_PARAMETER_DESCRIPTION* list =
        (FMOD_STUDIO_PARAMETER_DESCRIPTION*)malloc((size_t)(index + 1) * sizeof(FMOD_STUDIO_PARAMETER_DESCRIPTION));
    if (!list) { gLastResult = FMOD_ERR_MEMORY; return gStringBuf; }
    int count = 0;
    gLastResult = gStudioSystem->getParameterDescriptionList(list, index + 1, &count);
    if (gLastResult == FMOD_OK && index >= count) gLastResult = FMOD_ERR_INVALID_PARAM;
    if (gLastResult == FMOD_OK) writeParamDescription(&list[index], fbuf, ibuf);
    free(list);
    return gStringBuf;
}

const char* fmod_sys_get_parameter_description_by_name(const ::String& name, ::Array<Float> fbuf, ::Array<int> ibuf) {
    gStringBuf[0] = '\0';
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return gStringBuf; }
    FMOD_STUDIO_PARAMETER_DESCRIPTION param;
    gLastResult = gStudioSystem->getParameterDescriptionByName(name.c_str(), &param);
    if (gLastResult != FMOD_OK) return gStringBuf;
    return writeParamDescription(&param, fbuf, ibuf);
}

const char* fmod_sys_get_parameter_label(const ::String& name, int labelIndex) {
    gStringBuf[0] = '\0';
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return gStringBuf; }
    int retrieved = 0;
    gLastResult = gStudioSystem->getParameterLabelByName(name.c_str(), labelIndex, gStringBuf, sizeof(gStringBuf), &retrieved);
    if (gLastResult != FMOD_OK) gStringBuf[0] = '\0';
    return gStringBuf;
}

int fmod_sys_get_num_listeners() {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    int num = 0;
    gLastResult = gStudioSystem->getNumListeners(&num);
    return num;
}

int fmod_sys_set_num_listeners(int num) {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = gStudioSystem->setNumListeners(num);
    return (int)gLastResult;
}

// fbuf[0..11] = 3D attributes of the listener at index
int fmod_sys_get_listener_attributes(int index, ::Array<Float> fbuf) {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    FMOD_3D_ATTRIBUTES attributes;
    memset(&attributes, 0, sizeof(attributes));
    gLastResult = gStudioSystem->getListenerAttributes(index, &attributes, NULL);
    writeAttributes(&attributes, fbuf);
    return (int)gLastResult;
}

int fmod_sys_set_listener_attributes(int index, ::Array<Float> f) {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    FMOD_3D_ATTRIBUTES attrs = makeAttributes(f[0], f[1], f[2], f[3], f[4], f[5], f[6], f[7], f[8], f[9], f[10], f[11]);
    gLastResult = gStudioSystem->setListenerAttributes(index, &attrs, NULL);
    return (int)gLastResult;
}

double fmod_sys_get_listener_weight(int index) {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0.0; }
    float weight = 0.0f;
    gLastResult = gStudioSystem->getListenerWeight(index, &weight);
    return (double)weight;
}

int fmod_sys_set_listener_weight(int index, double weight) {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = gStudioSystem->setListenerWeight(index, (float)weight);
    return (int)gLastResult;
}

// flags bit0 = nonblocking; returns a bank handle or 0
int fmod_sys_load_bank_file(const ::String& path, int flags) {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    FMOD_STUDIO_LOAD_BANK_FLAGS loadFlags = (flags & 1) ? FMOD_STUDIO_LOAD_BANK_NONBLOCKING : FMOD_STUDIO_LOAD_BANK_NORMAL;
    FMOD::Studio::Bank* bank = NULL;
    gLastResult = gStudioSystem->loadBankFile(path.c_str(), loadFlags, &bank);
    if (gLastResult != FMOD_OK || !bank) return 0;
    return faxe_handle_find_or_alloc(bank, FAXE_TYPE_BANK);
}

// Async bank load: always FMOD_STUDIO_LOAD_BANK_NONBLOCKING; poll
// bank_get_loading_state. Returns a bank handle or 0.
int fmod_sys_load_bank_async(const ::String& path) {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    FMOD::Studio::Bank* bank = NULL;
    gLastResult = gStudioSystem->loadBankFile(path.c_str(), FMOD_STUDIO_LOAD_BANK_NONBLOCKING, &bank);
    if (gLastResult != FMOD_OK || !bank) return 0;
    return faxe_handle_find_or_alloc(bank, FAXE_TYPE_BANK);
}

// Frees the cached lookup handles whose objects an unload just destroyed,
// so a reload cannot alias a recycled address under a stale handle.
static int lincLookupSlotValid(void* ptr, unsigned char type) {
    switch (type) {
        case FAXE_TYPE_BUS: return ((FMOD::Studio::Bus*)ptr)->isValid() ? 1 : 0;
        case FAXE_TYPE_VCA: return ((FMOD::Studio::VCA*)ptr)->isValid() ? 1 : 0;
        case FAXE_TYPE_EVD: return ((FMOD::Studio::EventDescription*)ptr)->isValid() ? 1 : 0;
        case FAXE_TYPE_CHANGROUP: {
            // Core objects are handle-validated inside FMOD: a call on a
            // destroyed group reports FMOD_ERR_INVALID_HANDLE safely
            float volume = 0.0f;
            return ((FMOD::ChannelGroup*)ptr)->getVolume(&volume)
                != FMOD_ERR_INVALID_HANDLE ? 1 : 0;
        }
        default: return 1;
    }
}

static void lincReclaimDeadLookups() {
    // Unload runs on FMOD's async command queue. Flushing makes the dead
    // objects observable to isValid before the sweep.
    if (gStudioSystem) gStudioSystem->flushCommands();
    faxe_handles_sweep_lookups(lincLookupSlotValid);
}

int fmod_sys_unload_all() {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = gStudioSystem->unloadAll();
    if (gLastResult == FMOD_OK) lincReclaimDeadLookups();
    return (int)gLastResult;
}

int fmod_sys_flush_commands() {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = gStudioSystem->flushCommands();
    return (int)gLastResult;
}

int fmod_sys_flush_sample_loading() {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = gStudioSystem->flushSampleLoading();
    return (int)gLastResult;
}

// fbuf: [0]=studio update, [1..6]=core dsp/stream/geometry/update/convolution1/convolution2
int fmod_sys_get_cpu_usage(::Array<Float> fbuf) {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    FMOD_STUDIO_CPU_USAGE studio;
    FMOD_CPU_USAGE core;
    memset(&studio, 0, sizeof(studio));
    memset(&core, 0, sizeof(core));
    gLastResult = gStudioSystem->getCPUUsage(&studio, &core);
    fbuf[0] = (double)studio.update;
    fbuf[1] = (double)core.dsp;
    fbuf[2] = (double)core.stream;
    fbuf[3] = (double)core.geometry;
    fbuf[4] = (double)core.update;
    fbuf[5] = (double)core.convolution1;
    fbuf[6] = (double)core.convolution2;
    return (int)gLastResult;
}

// ibuf: [0..3]=commandqueue cur/peak/cap/stall [4..7]=handle same; fbuf: [0]=commandqueue stalltime [1]=handle stalltime
int fmod_sys_get_buffer_usage(::Array<int> ibuf, ::Array<Float> fbuf) {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    FMOD_STUDIO_BUFFER_USAGE usage;
    memset(&usage, 0, sizeof(usage));
    gLastResult = gStudioSystem->getBufferUsage(&usage);
    ibuf[0] = usage.studiocommandqueue.currentusage;
    ibuf[1] = usage.studiocommandqueue.peakusage;
    ibuf[2] = usage.studiocommandqueue.capacity;
    ibuf[3] = usage.studiocommandqueue.stallcount;
    ibuf[4] = usage.studiohandle.currentusage;
    ibuf[5] = usage.studiohandle.peakusage;
    ibuf[6] = usage.studiohandle.capacity;
    ibuf[7] = usage.studiohandle.stallcount;
    fbuf[0] = (double)usage.studiocommandqueue.stalltime;
    fbuf[1] = (double)usage.studiohandle.stalltime;
    return (int)gLastResult;
}

int fmod_sys_reset_buffer_usage() {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = gStudioSystem->resetBufferUsage();
    return (int)gLastResult;
}

// ibuf: [0]=exclusive [1]=inclusive [2]=sampledata (bytes)
int fmod_sys_get_memory_usage(::Array<int> ibuf) {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    FMOD_STUDIO_MEMORY_USAGE usage;
    usage.exclusive = 0; usage.inclusive = 0; usage.sampledata = 0;
    gLastResult = gStudioSystem->getMemoryUsage(&usage);
    ibuf[0] = usage.exclusive;
    ibuf[1] = usage.inclusive;
    ibuf[2] = usage.sampledata;
    return (int)gLastResult;
}

//// Bus

static inline FMOD::Studio::Bus* resolveBus(int h) {
    return (FMOD::Studio::Bus*)faxe_handle_resolve(h, FAXE_TYPE_BUS);
}

bool fmod_bus_is_valid(int h) {
    FMOD::Studio::Bus* bus = resolveBus(h);
    return bus != NULL && bus->isValid();
}

const char* fmod_bus_get_id(int h) {
    gStringBuf[0] = '\0';
    FMOD::Studio::Bus* bus = resolveBus(h);
    if (!bus) { gLastResult = FMOD_ERR_INVALID_HANDLE; return gStringBuf; }
    FMOD_GUID id;
    gLastResult = bus->getID(&id);
    if (gLastResult == FMOD_OK) faxe_guid_format(&id, gStringBuf, sizeof(gStringBuf));
    return gStringBuf;
}

const char* fmod_bus_get_path(int h) {
    gStringBuf[0] = '\0';
    FMOD::Studio::Bus* bus = resolveBus(h);
    if (!bus) { gLastResult = FMOD_ERR_INVALID_HANDLE; return gStringBuf; }
    int retrieved = 0;
    gLastResult = bus->getPath(gStringBuf, sizeof(gStringBuf), &retrieved);
    if (gLastResult != FMOD_OK) gStringBuf[0] = '\0';
    return gStringBuf;
}

double fmod_bus_get_volume(int h) {
    FMOD::Studio::Bus* bus = resolveBus(h);
    if (!bus) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    float volume = 0.0f;
    gLastResult = bus->getVolume(&volume, NULL);
    return (double)volume;
}

double fmod_bus_get_final_volume(int h) {
    FMOD::Studio::Bus* bus = resolveBus(h);
    if (!bus) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    float volume = 0.0f;
    float finalVolume = 0.0f;
    gLastResult = bus->getVolume(&volume, &finalVolume);
    return (double)finalVolume;
}

int fmod_bus_set_volume(int h, double volume) {
    FMOD::Studio::Bus* bus = resolveBus(h);
    if (!bus) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = bus->setVolume((float)volume);
    return (int)gLastResult;
}

bool fmod_bus_get_paused(int h) {
    FMOD::Studio::Bus* bus = resolveBus(h);
    if (!bus) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    bool paused = false;
    gLastResult = bus->getPaused(&paused);
    return paused;
}

int fmod_bus_set_paused(int h, bool paused) {
    FMOD::Studio::Bus* bus = resolveBus(h);
    if (!bus) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = bus->setPaused(paused);
    return (int)gLastResult;
}

bool fmod_bus_get_mute(int h) {
    FMOD::Studio::Bus* bus = resolveBus(h);
    if (!bus) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    bool mute = false;
    gLastResult = bus->getMute(&mute);
    return mute;
}

int fmod_bus_set_mute(int h, bool mute) {
    FMOD::Studio::Bus* bus = resolveBus(h);
    if (!bus) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = bus->setMute(mute);
    return (int)gLastResult;
}

int fmod_bus_stop_all_events(int h, int stopMode) {
    FMOD::Studio::Bus* bus = resolveBus(h);
    if (!bus) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = bus->stopAllEvents(stopMode == 1 ? FMOD_STUDIO_STOP_IMMEDIATE : FMOD_STUDIO_STOP_ALLOWFADEOUT);
    return (int)gLastResult;
}

// out[0] = exclusive, out[1] = inclusive (microseconds)
int fmod_bus_get_cpu_usage(int h, ::Array<int> out) {
    FMOD::Studio::Bus* bus = resolveBus(h);
    if (!bus) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    unsigned int exclusive = 0;
    unsigned int inclusive = 0;
    gLastResult = bus->getCPUUsage(&exclusive, &inclusive);
    out[0] = (int)exclusive;
    out[1] = (int)inclusive;
    return (int)gLastResult;
}

// out[0] = exclusive, out[1] = inclusive, out[2] = sampledata (bytes)
int fmod_bus_get_memory_usage(int h, ::Array<int> out) {
    FMOD::Studio::Bus* bus = resolveBus(h);
    if (!bus) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    FMOD_STUDIO_MEMORY_USAGE usage;
    usage.exclusive = 0; usage.inclusive = 0; usage.sampledata = 0;
    gLastResult = bus->getMemoryUsage(&usage);
    out[0] = usage.exclusive;
    out[1] = usage.inclusive;
    out[2] = usage.sampledata;
    return (int)gLastResult;
}

//// VCA

static inline FMOD::Studio::VCA* resolveVca(int h) {
    return (FMOD::Studio::VCA*)faxe_handle_resolve(h, FAXE_TYPE_VCA);
}

bool fmod_vca_is_valid(int h) {
    FMOD::Studio::VCA* vca = resolveVca(h);
    return vca != NULL && vca->isValid();
}

const char* fmod_vca_get_id(int h) {
    gStringBuf[0] = '\0';
    FMOD::Studio::VCA* vca = resolveVca(h);
    if (!vca) { gLastResult = FMOD_ERR_INVALID_HANDLE; return gStringBuf; }
    FMOD_GUID id;
    gLastResult = vca->getID(&id);
    if (gLastResult == FMOD_OK) faxe_guid_format(&id, gStringBuf, sizeof(gStringBuf));
    return gStringBuf;
}

const char* fmod_vca_get_path(int h) {
    gStringBuf[0] = '\0';
    FMOD::Studio::VCA* vca = resolveVca(h);
    if (!vca) { gLastResult = FMOD_ERR_INVALID_HANDLE; return gStringBuf; }
    int retrieved = 0;
    gLastResult = vca->getPath(gStringBuf, sizeof(gStringBuf), &retrieved);
    if (gLastResult != FMOD_OK) gStringBuf[0] = '\0';
    return gStringBuf;
}

double fmod_vca_get_volume(int h) {
    FMOD::Studio::VCA* vca = resolveVca(h);
    if (!vca) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    float volume = 0.0f;
    gLastResult = vca->getVolume(&volume, NULL);
    return (double)volume;
}

double fmod_vca_get_final_volume(int h) {
    FMOD::Studio::VCA* vca = resolveVca(h);
    if (!vca) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    float volume = 0.0f;
    float finalVolume = 0.0f;
    gLastResult = vca->getVolume(&volume, &finalVolume);
    return (double)finalVolume;
}

int fmod_vca_set_volume(int h, double volume) {
    FMOD::Studio::VCA* vca = resolveVca(h);
    if (!vca) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = vca->setVolume((float)volume);
    return (int)gLastResult;
}

//// Bank

static inline FMOD::Studio::Bank* resolveBank(int h) {
    return (FMOD::Studio::Bank*)faxe_handle_resolve(h, FAXE_TYPE_BANK);
}

bool fmod_bank_is_valid(int h) {
    FMOD::Studio::Bank* bank = resolveBank(h);
    return bank != NULL && bank->isValid();
}

const char* fmod_bank_get_id(int h) {
    gStringBuf[0] = '\0';
    FMOD::Studio::Bank* bank = resolveBank(h);
    if (!bank) { gLastResult = FMOD_ERR_INVALID_HANDLE; return gStringBuf; }
    FMOD_GUID id;
    gLastResult = bank->getID(&id);
    if (gLastResult == FMOD_OK) faxe_guid_format(&id, gStringBuf, sizeof(gStringBuf));
    return gStringBuf;
}

const char* fmod_bank_get_path(int h) {
    gStringBuf[0] = '\0';
    FMOD::Studio::Bank* bank = resolveBank(h);
    if (!bank) { gLastResult = FMOD_ERR_INVALID_HANDLE; return gStringBuf; }
    int retrieved = 0;
    gLastResult = bank->getPath(gStringBuf, sizeof(gStringBuf), &retrieved);
    if (gLastResult != FMOD_OK) gStringBuf[0] = '\0';
    return gStringBuf;
}

// Real unload; frees the bank handle on success.
int fmod_bank_unload(int h) {
    FMOD::Studio::Bank* bank = resolveBank(h);
    if (!bank) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = bank->unload();
    if (gLastResult == FMOD_OK) {
        faxe_handle_free(h);
        lincReclaimDeadLookups();
    }
    return (int)gLastResult;
}

int fmod_bank_load_sample_data(int h) {
    FMOD::Studio::Bank* bank = resolveBank(h);
    if (!bank) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = bank->loadSampleData();
    return (int)gLastResult;
}

int fmod_bank_unload_sample_data(int h) {
    FMOD::Studio::Bank* bank = resolveBank(h);
    if (!bank) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = bank->unloadSampleData();
    return (int)gLastResult;
}

int fmod_bank_get_loading_state(int h) {
    FMOD::Studio::Bank* bank = resolveBank(h);
    if (!bank) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)FMOD_STUDIO_LOADING_STATE_UNLOADED; }
    FMOD_STUDIO_LOADING_STATE state = FMOD_STUDIO_LOADING_STATE_UNLOADED;
    gLastResult = bank->getLoadingState(&state);
    return (int)state;
}

int fmod_bank_get_sample_loading_state(int h) {
    FMOD::Studio::Bank* bank = resolveBank(h);
    if (!bank) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)FMOD_STUDIO_LOADING_STATE_UNLOADED; }
    FMOD_STUDIO_LOADING_STATE state = FMOD_STUDIO_LOADING_STATE_UNLOADED;
    gLastResult = bank->getSampleLoadingState(&state);
    return (int)state;
}

int fmod_bank_get_event_count(int h) {
    FMOD::Studio::Bank* bank = resolveBank(h);
    if (!bank) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    int count = 0;
    gLastResult = bank->getEventCount(&count);
    return count;
}

// Fills out with event description handles, returns the count written (capped at FAXE_LIST_MAX).
int fmod_bank_get_event_list(int h, ::Array<int> out) {
    FMOD::Studio::Bank* bank = resolveBank(h);
    if (!bank) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    FMOD::Studio::EventDescription** descs = (FMOD::Studio::EventDescription**)gListBuf;
    int count = 0;
    gLastResult = bank->getEventList(descs, FAXE_LIST_MAX, &count);
    if (gLastResult != FMOD_OK) return 0;
    int written = 0;
    for (int i = 0; i < count; i++) {
        int handle = faxe_handle_find_or_alloc(descs[i], FAXE_TYPE_EVD);
        if (handle != 0) out[written++] = handle;
    }
    return written;
}

int fmod_bank_get_bus_count(int h) {
    FMOD::Studio::Bank* bank = resolveBank(h);
    if (!bank) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    int count = 0;
    gLastResult = bank->getBusCount(&count);
    return count;
}

int fmod_bank_get_bus_list(int h, ::Array<int> out) {
    FMOD::Studio::Bank* bank = resolveBank(h);
    if (!bank) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    FMOD::Studio::Bus** buses = (FMOD::Studio::Bus**)gListBuf;
    int count = 0;
    gLastResult = bank->getBusList(buses, FAXE_LIST_MAX, &count);
    if (gLastResult != FMOD_OK) return 0;
    int written = 0;
    for (int i = 0; i < count; i++) {
        int handle = faxe_handle_find_or_alloc(buses[i], FAXE_TYPE_BUS);
        if (handle != 0) out[written++] = handle;
    }
    return written;
}

int fmod_bank_get_vca_count(int h) {
    FMOD::Studio::Bank* bank = resolveBank(h);
    if (!bank) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    int count = 0;
    gLastResult = bank->getVCACount(&count);
    return count;
}

int fmod_bank_get_vca_list(int h, ::Array<int> out) {
    FMOD::Studio::Bank* bank = resolveBank(h);
    if (!bank) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    FMOD::Studio::VCA** vcas = (FMOD::Studio::VCA**)gListBuf;
    int count = 0;
    gLastResult = bank->getVCAList(vcas, FAXE_LIST_MAX, &count);
    if (gLastResult != FMOD_OK) return 0;
    int written = 0;
    for (int i = 0; i < count; i++) {
        int handle = faxe_handle_find_or_alloc(vcas[i], FAXE_TYPE_VCA);
        if (handle != 0) out[written++] = handle;
    }
    return written;
}

int fmod_bank_get_string_count(int h) {
    FMOD::Studio::Bank* bank = resolveBank(h);
    if (!bank) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    int count = 0;
    gLastResult = bank->getStringCount(&count);
    return count;
}

// String table path by index
const char* fmod_bank_get_string_info(int h, int index) {
    gStringBuf[0] = '\0';
    FMOD::Studio::Bank* bank = resolveBank(h);
    if (!bank) { gLastResult = FMOD_ERR_INVALID_HANDLE; return gStringBuf; }
    FMOD_GUID id;
    int retrieved = 0;
    gLastResult = bank->getStringInfo(index, &id, gStringBuf, sizeof(gStringBuf), &retrieved);
    if (gLastResult != FMOD_OK) gStringBuf[0] = '\0';
    return gStringBuf;
}

// String table GUID by index (formatted string)
const char* fmod_bank_get_string_guid(int h, int index) {
    gStringBuf[0] = '\0';
    FMOD::Studio::Bank* bank = resolveBank(h);
    if (!bank) { gLastResult = FMOD_ERR_INVALID_HANDLE; return gStringBuf; }
    FMOD_GUID id;
    int retrieved = 0;
    gLastResult = bank->getStringInfo(index, &id, gStringBuf, sizeof(gStringBuf), &retrieved);
    if (gLastResult == FMOD_OK) faxe_guid_format(&id, gStringBuf, sizeof(gStringBuf));
    else gStringBuf[0] = '\0';
    return gStringBuf;
}

//// EventDescription

static inline FMOD::Studio::EventDescription* resolveDescription(int h) {
    return (FMOD::Studio::EventDescription*)faxe_handle_resolve(h, FAXE_TYPE_EVD);
}

bool fmod_evd_is_valid(int h) {
    FMOD::Studio::EventDescription* desc = resolveDescription(h);
    return desc != NULL && desc->isValid();
}

const char* fmod_evd_get_id(int h) {
    gStringBuf[0] = '\0';
    FMOD::Studio::EventDescription* desc = resolveDescription(h);
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return gStringBuf; }
    FMOD_GUID id;
    gLastResult = desc->getID(&id);
    if (gLastResult == FMOD_OK) faxe_guid_format(&id, gStringBuf, sizeof(gStringBuf));
    return gStringBuf;
}

const char* fmod_evd_get_path(int h) {
    gStringBuf[0] = '\0';
    FMOD::Studio::EventDescription* desc = resolveDescription(h);
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return gStringBuf; }
    int retrieved = 0;
    gLastResult = desc->getPath(gStringBuf, sizeof(gStringBuf), &retrieved);
    if (gLastResult != FMOD_OK) gStringBuf[0] = '\0';
    return gStringBuf;
}

int fmod_evd_get_length(int h) {
    FMOD::Studio::EventDescription* desc = resolveDescription(h);
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    int length = 0;
    gLastResult = desc->getLength(&length);
    return length;
}

// fbuf: [0]=min [1]=max
int fmod_evd_get_min_max_distance(int h, ::Array<Float> fbuf) {
    FMOD::Studio::EventDescription* desc = resolveDescription(h);
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    float min = 0.0f;
    float max = 0.0f;
    gLastResult = desc->getMinMaxDistance(&min, &max);
    fbuf[0] = (double)min;
    fbuf[1] = (double)max;
    return (int)gLastResult;
}

double fmod_evd_get_sound_size(int h) {
    FMOD::Studio::EventDescription* desc = resolveDescription(h);
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    float size = 0.0f;
    gLastResult = desc->getSoundSize(&size);
    return (double)size;
}

bool fmod_evd_is_snapshot(int h) {
    FMOD::Studio::EventDescription* desc = resolveDescription(h);
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    bool value = false;
    gLastResult = desc->isSnapshot(&value);
    return value;
}

bool fmod_evd_is_oneshot(int h) {
    FMOD::Studio::EventDescription* desc = resolveDescription(h);
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    bool value = false;
    gLastResult = desc->isOneshot(&value);
    return value;
}

bool fmod_evd_is_stream(int h) {
    FMOD::Studio::EventDescription* desc = resolveDescription(h);
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    bool value = false;
    gLastResult = desc->isStream(&value);
    return value;
}

bool fmod_evd_is_3d(int h) {
    FMOD::Studio::EventDescription* desc = resolveDescription(h);
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    bool value = false;
    gLastResult = desc->is3D(&value);
    return value;
}

bool fmod_evd_is_doppler_enabled(int h) {
    FMOD::Studio::EventDescription* desc = resolveDescription(h);
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    bool value = false;
    gLastResult = desc->isDopplerEnabled(&value);
    return value;
}

bool fmod_evd_has_sustain_point(int h) {
    FMOD::Studio::EventDescription* desc = resolveDescription(h);
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    bool value = false;
    gLastResult = desc->hasSustainPoint(&value);
    return value;
}

int fmod_evd_create_instance(int h) {
    FMOD::Studio::EventDescription* desc = resolveDescription(h);
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    FMOD::Studio::EventInstance* instance = NULL;
    gLastResult = desc->createInstance(&instance);
    if (gLastResult != FMOD_OK || !instance) return 0;
    int handle = faxe_handle_alloc(instance, FAXE_TYPE_EVI);
    if (handle == 0) {
        gLastResult = FMOD_ERR_MEMORY; /* handle table exhausted */
        instance->release();
        return 0;
    }
    // Attach the per-instance context so FMOD-thread callbacks can find the
    // handle (and programmer-sound key) without touching the handle table.
    if (!attachInstanceCtx(instance, handle)) {
        faxe_handle_free(handle);
        instance->release();
        return 0;
    }
    return handle;
}

int fmod_evd_get_instance_count(int h) {
    FMOD::Studio::EventDescription* desc = resolveDescription(h);
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    int count = 0;
    gLastResult = desc->getInstanceCount(&count);
    return count;
}

// Fills out with instance handles, returns the count written (capped at FAXE_LIST_MAX).
// Instances FMOD returns that we have not seen get fresh handles.
int fmod_evd_get_instance_list(int h, ::Array<int> out) {
    FMOD::Studio::EventDescription* desc = resolveDescription(h);
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    FMOD::Studio::EventInstance** instances = (FMOD::Studio::EventInstance**)gListBuf;
    int count = 0;
    gLastResult = desc->getInstanceList(instances, FAXE_LIST_MAX, &count);
    if (gLastResult != FMOD_OK) return 0;
    int written = 0;
    for (int i = 0; i < count; i++) {
        // The instance's own context is the identity authority. Pointer
        // dedup would be wrong here: a dead instance's slot keeps its
        // dangling pointer until the DESTROYED drain, and FMOD can hand a
        // new instance the same address inside that window.
        FaxeInstCtx* ctx = instanceCtx(instances[i]);
        int handle;
        if (ctx && faxe_handle_resolve(ctx->handle, FAXE_TYPE_EVI) == (void*)instances[i]) {
            handle = ctx->handle;
        } else {
            // Released-but-still-playing (context holds a freed handle) or
            // never managed: mint a fresh slot and point the context at it,
            // or queued callbacks carry a dead handle and get dropped.
            handle = faxe_handle_alloc(instances[i], FAXE_TYPE_EVI);
            if (handle != 0) {
                if (ctx) {
                    faxe_cbq_lock();
                    ctx->handle = handle;
                    faxe_cbq_unlock();
                } else if (!attachInstanceCtx(instances[i], handle)) {
                    // No context means no DESTROYED hand-off would ever
                    // reclaim the slot
                    faxe_handle_free(handle);
                    handle = 0;
                    gLastResult = FMOD_ERR_INVALID_HANDLE;
                }
            } else {
                gLastResult = FMOD_ERR_MEMORY;
            }
        }
        if (handle != 0) out[written++] = handle;
    }
    return written;
}

int fmod_evd_release_all_instances(int h) {
    FMOD::Studio::EventDescription* desc = resolveDescription(h);
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = desc->releaseAllInstances();
    return (int)gLastResult;
}

int fmod_evd_load_sample_data(int h) {
    FMOD::Studio::EventDescription* desc = resolveDescription(h);
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = desc->loadSampleData();
    return (int)gLastResult;
}

int fmod_evd_unload_sample_data(int h) {
    FMOD::Studio::EventDescription* desc = resolveDescription(h);
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = desc->unloadSampleData();
    return (int)gLastResult;
}

int fmod_evd_get_sample_loading_state(int h) {
    FMOD::Studio::EventDescription* desc = resolveDescription(h);
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)FMOD_STUDIO_LOADING_STATE_UNLOADED; }
    FMOD_STUDIO_LOADING_STATE state = FMOD_STUDIO_LOADING_STATE_UNLOADED;
    gLastResult = desc->getSampleLoadingState(&state);
    return (int)state;
}

int fmod_evd_get_parameter_description_count(int h) {
    FMOD::Studio::EventDescription* desc = resolveDescription(h);
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    int count = 0;
    gLastResult = desc->getParameterDescriptionCount(&count);
    return count;
}

const char* fmod_evd_get_parameter_description_by_index(int h, int index, ::Array<Float> fbuf, ::Array<int> ibuf) {
    gStringBuf[0] = '\0';
    FMOD::Studio::EventDescription* desc = resolveDescription(h);
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return gStringBuf; }
    FMOD_STUDIO_PARAMETER_DESCRIPTION param;
    gLastResult = desc->getParameterDescriptionByIndex(index, &param);
    if (gLastResult != FMOD_OK) return gStringBuf;
    return writeParamDescription(&param, fbuf, ibuf);
}

const char* fmod_evd_get_parameter_description_by_name(int h, const ::String& name, ::Array<Float> fbuf, ::Array<int> ibuf) {
    gStringBuf[0] = '\0';
    FMOD::Studio::EventDescription* desc = resolveDescription(h);
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return gStringBuf; }
    FMOD_STUDIO_PARAMETER_DESCRIPTION param;
    gLastResult = desc->getParameterDescriptionByName(name.c_str(), &param);
    if (gLastResult != FMOD_OK) return gStringBuf;
    return writeParamDescription(&param, fbuf, ibuf);
}

const char* fmod_evd_get_parameter_label(int h, const ::String& name, int labelIndex) {
    gStringBuf[0] = '\0';
    FMOD::Studio::EventDescription* desc = resolveDescription(h);
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return gStringBuf; }
    int retrieved = 0;
    gLastResult = desc->getParameterLabelByName(name.c_str(), labelIndex, gStringBuf, sizeof(gStringBuf), &retrieved);
    if (gLastResult != FMOD_OK) gStringBuf[0] = '\0';
    return gStringBuf;
}

int fmod_evd_get_user_property_count(int h) {
    FMOD::Studio::EventDescription* desc = resolveDescription(h);
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    int count = 0;
    gLastResult = desc->getUserPropertyCount(&count);
    return count;
}

const char* fmod_evd_get_user_property_name(int h, int index) {
    gStringBuf[0] = '\0';
    FMOD::Studio::EventDescription* desc = resolveDescription(h);
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return gStringBuf; }
    FMOD_STUDIO_USER_PROPERTY prop;
    memset(&prop, 0, sizeof(prop));
    gLastResult = desc->getUserPropertyByIndex(index, &prop);
    if (gLastResult != FMOD_OK) return gStringBuf;
    return copyToStringBuf(prop.name);
}

int fmod_evd_get_user_property_type(int h, int index) {
    FMOD::Studio::EventDescription* desc = resolveDescription(h);
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    FMOD_STUDIO_USER_PROPERTY prop;
    memset(&prop, 0, sizeof(prop));
    gLastResult = desc->getUserPropertyByIndex(index, &prop);
    if (gLastResult != FMOD_OK) return 0;
    return (int)prop.type;
}

// int/bool coerced to float; 0.0 for string type
double fmod_evd_get_user_property_float(int h, int index) {
    FMOD::Studio::EventDescription* desc = resolveDescription(h);
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    FMOD_STUDIO_USER_PROPERTY prop;
    memset(&prop, 0, sizeof(prop));
    gLastResult = desc->getUserPropertyByIndex(index, &prop);
    if (gLastResult != FMOD_OK) return 0.0;
    switch (prop.type) {
        case FMOD_STUDIO_USER_PROPERTY_TYPE_INTEGER: return (double)prop.intvalue;
        case FMOD_STUDIO_USER_PROPERTY_TYPE_BOOLEAN: return prop.boolvalue ? 1.0 : 0.0;
        case FMOD_STUDIO_USER_PROPERTY_TYPE_FLOAT: return (double)prop.floatvalue;
        default: return 0.0;
    }
}

// "" unless the property type is string
const char* fmod_evd_get_user_property_string(int h, int index) {
    gStringBuf[0] = '\0';
    FMOD::Studio::EventDescription* desc = resolveDescription(h);
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return gStringBuf; }
    FMOD_STUDIO_USER_PROPERTY prop;
    memset(&prop, 0, sizeof(prop));
    gLastResult = desc->getUserPropertyByIndex(index, &prop);
    if (gLastResult != FMOD_OK || prop.type != FMOD_STUDIO_USER_PROPERTY_TYPE_STRING) return gStringBuf;
    return copyToStringBuf(prop.stringvalue);
}

//// EventInstance

bool fmod_evi_is_valid(int h) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    return instance != NULL && instance->isValid();
}

// Returns the description handle (cached per description, like bus lookups).
int fmod_evi_get_description(int h) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    FMOD::Studio::EventDescription* desc = NULL;
    gLastResult = instance->getDescription(&desc);
    if (gLastResult != FMOD_OK || !desc) return 0;
    return faxe_handle_find_or_alloc(desc, FAXE_TYPE_EVD);
}

int fmod_evi_start(int h) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = instance->start();
    return (int)gLastResult;
}

int fmod_evi_stop(int h, int stopMode) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = instance->stop(stopMode == 1 ? FMOD_STUDIO_STOP_IMMEDIATE : FMOD_STUDIO_STOP_ALLOWFADEOUT);
    return (int)gLastResult;
}

int fmod_evi_key_off(int h) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = instance->keyOff();
    return (int)gLastResult;
}

// Releases the instance and frees the handle (does not stop first).
int fmod_evi_release(int h) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = instance->release();
    // INVALID_HANDLE means FMOD already destroyed the instance (bank unload,
    // releaseAllInstances). The slot must still be reclaimed or it leaks for
    // the rest of the process.
    if (gLastResult == FMOD_OK || gLastResult == FMOD_ERR_INVALID_HANDLE) {
        faxe_handle_free(h);
    }
    return (int)gLastResult;
}

int fmod_evi_get_playback_state(int h) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)FMOD_STUDIO_PLAYBACK_STOPPED; }
    FMOD_STUDIO_PLAYBACK_STATE state = FMOD_STUDIO_PLAYBACK_STOPPED;
    gLastResult = instance->getPlaybackState(&state);
    return (int)state;
}

bool fmod_evi_get_paused(int h) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    bool paused = false;
    gLastResult = instance->getPaused(&paused);
    return paused;
}

int fmod_evi_set_paused(int h, bool paused) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = instance->setPaused(paused);
    return (int)gLastResult;
}

double fmod_evi_get_volume(int h) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    float volume = 0.0f;
    gLastResult = instance->getVolume(&volume, NULL);
    return (double)volume;
}

double fmod_evi_get_volume_final(int h) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    float volume = 0.0f;
    float finalVolume = 0.0f;
    gLastResult = instance->getVolume(&volume, &finalVolume);
    return (double)finalVolume;
}

int fmod_evi_set_volume(int h, double volume) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = instance->setVolume((float)volume);
    return (int)gLastResult;
}

double fmod_evi_get_pitch(int h) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    float pitch = 0.0f;
    gLastResult = instance->getPitch(&pitch, NULL);
    return (double)pitch;
}

double fmod_evi_get_pitch_final(int h) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    float pitch = 0.0f;
    float finalPitch = 0.0f;
    gLastResult = instance->getPitch(&pitch, &finalPitch);
    return (double)finalPitch;
}

int fmod_evi_set_pitch(int h, double pitch) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = instance->setPitch((float)pitch);
    return (int)gLastResult;
}

int fmod_evi_get_timeline_position(int h) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    int position = 0;
    gLastResult = instance->getTimelinePosition(&position);
    return position;
}

int fmod_evi_set_timeline_position(int h, int position) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = instance->setTimelinePosition(position);
    return (int)gLastResult;
}

bool fmod_evi_is_virtual(int h) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return false; }
    bool virtualState = false;
    gLastResult = instance->isVirtual(&virtualState);
    return virtualState;
}

// fbuf: [0]=min [1]=max
int fmod_evi_get_min_max_distance(int h, ::Array<Float> fbuf) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    float min = 0.0f;
    float max = 0.0f;
    gLastResult = instance->getMinMaxDistance(&min, &max);
    fbuf[0] = (double)min;
    fbuf[1] = (double)max;
    return (int)gLastResult;
}

// fbuf[0..11] = pos/vel/forward/up
int fmod_evi_get_3d_attributes(int h, ::Array<Float> fbuf) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    FMOD_3D_ATTRIBUTES attributes;
    memset(&attributes, 0, sizeof(attributes));
    gLastResult = instance->get3DAttributes(&attributes);
    writeAttributes(&attributes, fbuf);
    return (int)gLastResult;
}

int fmod_evi_set_3d_attributes(int h, ::Array<Float> f) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    FMOD_3D_ATTRIBUTES attrs = makeAttributes(f[0], f[1], f[2], f[3], f[4], f[5], f[6], f[7], f[8], f[9], f[10], f[11]);
    gLastResult = instance->set3DAttributes(&attrs);
    return (int)gLastResult;
}

int fmod_evi_get_listener_mask(int h) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    unsigned int mask = 0;
    gLastResult = instance->getListenerMask(&mask);
    return (int)mask;
}

int fmod_evi_set_listener_mask(int h, int mask) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = instance->setListenerMask((unsigned int)mask);
    return (int)gLastResult;
}

// index = FMOD_STUDIO_EVENT_PROPERTY
double fmod_evi_get_property(int h, int index) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    float value = 0.0f;
    gLastResult = instance->getProperty((FMOD_STUDIO_EVENT_PROPERTY)index, &value);
    return (double)value;
}

int fmod_evi_set_property(int h, int index, double value) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = instance->setProperty((FMOD_STUDIO_EVENT_PROPERTY)index, (float)value);
    return (int)gLastResult;
}

double fmod_evi_get_reverb_level(int h, int index) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    float level = 0.0f;
    gLastResult = instance->getReverbLevel(index, &level);
    return (double)level;
}

int fmod_evi_set_reverb_level(int h, int index, double level) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = instance->setReverbLevel(index, (float)level);
    return (int)gLastResult;
}

double fmod_evi_get_param_by_name(int h, const ::String& name) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    float value = 0.0f;
    gLastResult = instance->getParameterByName(name.c_str(), &value, NULL);
    return (double)value;
}

double fmod_evi_get_param_by_name_final(int h, const ::String& name) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    float value = 0.0f;
    float finalValue = 0.0f;
    gLastResult = instance->getParameterByName(name.c_str(), &value, &finalValue);
    return (double)finalValue;
}

int fmod_evi_set_param_by_name(int h, const ::String& name, double value, bool ignoreSeekSpeed) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = instance->setParameterByName(name.c_str(), (float)value, ignoreSeekSpeed);
    return (int)gLastResult;
}

int fmod_evi_set_param_by_name_with_label(int h, const ::String& name, const ::String& label, bool ignoreSeekSpeed) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = instance->setParameterByNameWithLabel(name.c_str(), label.c_str(), ignoreSeekSpeed);
    return (int)gLastResult;
}

double fmod_evi_get_param_by_id(int h, int id1, int id2) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    float value = 0.0f;
    gLastResult = instance->getParameterByID(makeParamId(id1, id2), &value, NULL);
    return (double)value;
}

double fmod_evi_get_param_by_id_final(int h, int id1, int id2) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0.0; }
    float value = 0.0f;
    float finalValue = 0.0f;
    gLastResult = instance->getParameterByID(makeParamId(id1, id2), &value, &finalValue);
    return (double)finalValue;
}

int fmod_evi_set_param_by_id(int h, int id1, int id2, double value, bool ignoreSeekSpeed) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = instance->setParameterByID(makeParamId(id1, id2), (float)value, ignoreSeekSpeed);
    return (int)gLastResult;
}

int fmod_evi_set_param_by_id_with_label(int h, int id1, int id2, const ::String& label, bool ignoreSeekSpeed) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    gLastResult = instance->setParameterByIDWithLabel(makeParamId(id1, id2), label.c_str(), ignoreSeekSpeed);
    return (int)gLastResult;
}

// out[0] = exclusive, out[1] = inclusive (microseconds)
int fmod_evi_get_cpu_usage(int h, ::Array<int> out) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    unsigned int exclusive = 0;
    unsigned int inclusive = 0;
    gLastResult = instance->getCPUUsage(&exclusive, &inclusive);
    out[0] = (int)exclusive;
    out[1] = (int)inclusive;
    return (int)gLastResult;
}

// out[0] = exclusive, out[1] = inclusive, out[2] = sampledata (bytes)
int fmod_evi_get_memory_usage(int h, ::Array<int> out) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (!instance) { gLastResult = FMOD_ERR_INVALID_HANDLE; return (int)gLastResult; }
    FMOD_STUDIO_MEMORY_USAGE usage;
    usage.exclusive = 0; usage.inclusive = 0; usage.sampledata = 0;
    gLastResult = instance->getMemoryUsage(&usage);
    out[0] = usage.exclusive;
    out[1] = usage.inclusive;
    out[2] = usage.sampledata;
    return (int)gLastResult;
}

//// Debug

int fmod_debug_live_handle_count() {
    return faxe_live_handle_count();
}

int fmod_binding_abi_version() {
    // Keep in lockstep with the manifest header "# abi-version:"
    return 8;
}

} // namespace faxe
} // namespace linc
