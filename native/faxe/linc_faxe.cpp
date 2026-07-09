/**
 * Faxe - C++ FMOD bindings - Minimal FFI layer
 *
 * DESIGN: This is the thinnest possible wrapper around FMOD.
 * - No logic, no error handling, no debug printing
 * - Just raw FMOD API calls
 * - All logic lives in Haxe (CppBackend.hx)
 *
 * The MIT License (MIT)
 * Copyright (c) 2016 Aaron M. Shea
 * Copyright (c) 2020 Tanner Moore
 */

#include <hxcpp.h>
#include <fmod_studio.hpp>
#include "linc_faxe.h"
#include "../shared/faxe_handles.h"
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
    if (!ctx || ctx->handle <= 0) return FMOD_OK;
    int handle = ctx->handle;

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
    // the installed mask (see attachInstanceCtx), so cleanup is guaranteed.
    if (type == FMOD_STUDIO_EVENT_CALLBACK_DESTROYED) {
        instance->setUserData(NULL);
        faxe_instctx_destroy(ctx);
    }
    return FMOD_OK;
}

// Attaches the per-instance context and installs the shim callback with at
// least the DESTROYED bit so the context is always reclaimed. Called from
// every managed-instance creation path (Haxe thread).
static bool attachInstanceCtx(FMOD::Studio::EventInstance* instance, int handle) {
    FaxeInstCtx* ctx = faxe_instctx_create(handle);
    if (!ctx) return false;
    instance->setUserData(ctx);
    instance->setCallback(eventCallback, FMOD_STUDIO_EVENT_CALLBACK_DESTROYED);
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

bool fmod_is_initialized() {
    return gStudioSystem != NULL;
}

int fmod_init(int numChannels) {
    if (gStudioSystem != NULL) return FMOD_OK;
    if (numChannels == 0) numChannels = 36;

    FMOD_RESULT result = FMOD::Studio::System::create(&gStudioSystem);
    if (result != FMOD_OK) return result;

    // FMOD_WAVWRITER env var: write mixed audio to WAV file (for CI recording)
    const char* wavWriterPath = std::getenv("FMOD_WAVWRITER");
    void* extradriverdata = nullptr;
    if (wavWriterPath && wavWriterPath[0] != '\0') {
        gStudioSystem->getCoreSystem(&gCoreSystem);
        gCoreSystem->setOutput(FMOD_OUTPUTTYPE_WAVWRITER);
        // Explicit stereo format so WAV header has correct channel count (Windows needs this)
        gCoreSystem->setSoftwareFormat(48000, FMOD_SPEAKERMODE_STEREO, 0);
        extradriverdata = (void*)wavWriterPath;
    }

    result = gStudioSystem->initialize(numChannels, FMOD_STUDIO_INIT_LIVEUPDATE, FMOD_INIT_NORMAL, extradriverdata);
    if (result != FMOD_OK) {
        gStudioSystem->release();
        gStudioSystem = NULL;
        return result;
    }

    gStudioSystem->getCoreSystem(&gCoreSystem);
    faxe_cbq_init();
    return FMOD_OK;
}

void fmod_update() {
    if (gStudioSystem) gStudioSystem->update();
}

void fmod_set_auto_update(bool enabled) {
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

//// Banks

int fmod_load_bank(const ::String& path) {
    if (!gStudioSystem) return FMOD_ERR_NOTREADY;
    FMOD::Studio::Bank* bank;
    return gStudioSystem->loadBankFile(path.c_str(), FMOD_STUDIO_LOAD_BANK_NORMAL, &bank);
}

void fmod_unload_bank(const ::String& path) {
    // Note: Would need bank tracking to implement properly
    // For now, this is a no-op matching HL behavior
}

//// Events - One shot

int fmod_fire_one_shot(const ::String& eventPath) {
    if (!gStudioSystem) return FMOD_ERR_NOTREADY;

    FMOD::Studio::EventDescription* desc;
    FMOD_RESULT result = gStudioSystem->getEvent(eventPath.c_str(), &desc);
    if (result != FMOD_OK) return result;

    FMOD::Studio::EventInstance* instance;
    result = desc->createInstance(&instance);
    if (result != FMOD_OK) return result;

    instance->start();
    instance->release();
    return FMOD_OK;
}

//// Events - Managed instances

int fmod_create_instance(const ::String& eventPath) {
    if (!gStudioSystem) return -1;

    FMOD::Studio::EventDescription* desc;
    if (gStudioSystem->getEvent(eventPath.c_str(), &desc) != FMOD_OK) return -1;

    FMOD::Studio::EventInstance* instance;
    if (desc->createInstance(&instance) != FMOD_OK) return -1;

    int handle = faxe_handle_alloc(instance, FAXE_TYPE_EVI);
    if (handle == 0) {
        instance->release();
        return -1;
    }

    // Attach the per-instance context so FMOD-thread callbacks can find the
    // handle (and programmer-sound key) without touching the handle table.
    if (!attachInstanceCtx(instance, handle)) {
        faxe_handle_free(handle);
        instance->release();
        return -1;
    }
    return handle;
}

void fmod_start(int h) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (instance) instance->start();
}

void fmod_stop(int h, int immediate) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (instance)
        instance->stop(immediate ? FMOD_STUDIO_STOP_IMMEDIATE : FMOD_STUDIO_STOP_ALLOWFADEOUT);
}

void fmod_release(int h) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (instance) {
        instance->stop(FMOD_STUDIO_STOP_IMMEDIATE);
        instance->release();
        faxe_handle_free(h);
    }
}

void fmod_set_paused(int h, bool paused) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (instance) instance->setPaused(paused);
}

int fmod_get_playback_state(int h) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (!instance) return FMOD_STUDIO_PLAYBACK_STOPPED;
    FMOD_STUDIO_PLAYBACK_STATE state;
    instance->getPlaybackState(&state);
    return (int)state;
}

int fmod_get_timeline_position(int h) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (!instance) return 0;
    int position = 0;
    instance->getTimelinePosition(&position);
    return position;
}

//// Parameters

float fmod_get_param(int h, const ::String& name) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (!instance) return 0.0f;
    float value = 0.0f;
    instance->getParameterByName(name.c_str(), &value);
    return value;
}

void fmod_set_param(int h, const ::String& name, float value) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (instance) instance->setParameterByName(name.c_str(), value, false);
}

//// Bus

void fmod_set_bus_paused(const ::String& path, bool paused) {
    if (!gStudioSystem) return;
    FMOD::Studio::Bus* bus;
    if (gStudioSystem->getBus(path.c_str(), &bus) == FMOD_OK)
        bus->setPaused(paused);
}

void fmod_stop_bus(const ::String& path) {
    if (!gStudioSystem) return;
    FMOD::Studio::Bus* bus;
    if (gStudioSystem->getBus(path.c_str(), &bus) == FMOD_OK)
        bus->stopAllEvents(FMOD_STUDIO_STOP_IMMEDIATE);
}

void fmod_set_bus_volume(const ::String& path, float volume) {
    if (!gStudioSystem) return;
    FMOD::Studio::Bus* bus;
    if (gStudioSystem->getBus(path.c_str(), &bus) == FMOD_OK)
        bus->setVolume(volume);
}

float fmod_get_bus_volume(const ::String& path) {
    if (!gStudioSystem) return 0.0f;
    FMOD::Studio::Bus* bus;
    if (gStudioSystem->getBus(path.c_str(), &bus) == FMOD_OK) {
        float volume = 0.0f;
        bus->getVolume(&volume, NULL);
        return volume;
    }
    return 0.0f;
}

void fmod_set_bus_mute(const ::String& path, bool mute) {
    if (!gStudioSystem) return;
    FMOD::Studio::Bus* bus;
    if (gStudioSystem->getBus(path.c_str(), &bus) == FMOD_OK)
        bus->setMute(mute);
}

bool fmod_get_bus_mute(const ::String& path) {
    if (!gStudioSystem) return false;
    FMOD::Studio::Bus* bus;
    if (gStudioSystem->getBus(path.c_str(), &bus) == FMOD_OK) {
        bool mute = false;
        bus->getMute(&mute);
        return mute;
    }
    return false;
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

// Drain protocol: cb_next pops the oldest queued event into a static slot;
// the accessors read fields from that slot. Haxe thread only.
static FaxeCbEvent gCbCurrent;

bool fmod_cb_next() {
    return faxe_cbq_pop(&gCbCurrent) == 1;
}

int fmod_cb_handle() {
    return gCbCurrent.handle;
}

int fmod_cb_type() {
    return (int)gCbCurrent.type;
}

int fmod_cb_int(int index) {
    return index == 0 ? gCbCurrent.i1 : (index == 1 ? gCbCurrent.i2 : gCbCurrent.i3);
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

//// Studio System (2.0 bindings)

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

// Fills out with bank handles, returns the count written (capped at 64).
int fmod_sys_get_bank_list(::Array<int> out) {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    FMOD::Studio::Bank* banks[64];
    int count = 0;
    gLastResult = gStudioSystem->getBankList(banks, 64, &count);
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
    if (index < 0) { gLastResult = FMOD_ERR_INVALID_PARAM; return gStringBuf; }
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

int fmod_sys_unload_all() {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return (int)gLastResult; }
    gLastResult = gStudioSystem->unloadAll();
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
    if (gLastResult == FMOD_OK) faxe_handle_free(h);
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

// Fills out with event description handles, returns the count written (capped at 64).
int fmod_bank_get_event_list(int h, ::Array<int> out) {
    FMOD::Studio::Bank* bank = resolveBank(h);
    if (!bank) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    FMOD::Studio::EventDescription* descs[64];
    int count = 0;
    gLastResult = bank->getEventList(descs, 64, &count);
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
    FMOD::Studio::Bus* buses[64];
    int count = 0;
    gLastResult = bank->getBusList(buses, 64, &count);
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
    FMOD::Studio::VCA* vcas[64];
    int count = 0;
    gLastResult = bank->getVCAList(vcas, 64, &count);
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

// Fills out with instance handles, returns the count written (capped at 64).
// Instances FMOD returns that we have not seen get fresh handles.
int fmod_evd_get_instance_list(int h, ::Array<int> out) {
    FMOD::Studio::EventDescription* desc = resolveDescription(h);
    if (!desc) { gLastResult = FMOD_ERR_INVALID_HANDLE; return 0; }
    FMOD::Studio::EventInstance* instances[64];
    int count = 0;
    gLastResult = desc->getInstanceList(instances, 64, &count);
    if (gLastResult != FMOD_OK) return 0;
    int written = 0;
    for (int i = 0; i < count; i++) {
        int handle = faxe_handle_find_or_alloc(instances[i], FAXE_TYPE_EVI);
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
    if (gLastResult == FMOD_OK) faxe_handle_free(h);
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
    return 2;
}

} // namespace faxe
} // namespace linc
