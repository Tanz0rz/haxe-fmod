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

// Auto-update thread
static std::thread* gUpdateThread = NULL;
static std::atomic<bool> gAutoUpdateRunning(false);

// Instance handles live in the shared generational table (faxe_handles.h).
// Legacy callback flags, indexed by slot index (replaced by payload queue in M2).
// Fixed size so the FMOD callback thread never races a Haxe-thread realloc.
static unsigned int gCbFlags[FAXE_MAX_SLOTS];

// Resolve an event instance handle to its FMOD pointer (NULL if stale/invalid)
static inline FMOD::Studio::EventInstance* resolveInstance(int h) {
    return (FMOD::Studio::EventInstance*)faxe_handle_resolve(h, FAXE_TYPE_EVI);
}

// Callback handler - runs on an FMOD thread. Must not touch the handle table;
// the instance's handle is read back from FMOD userdata instead.
static FMOD_RESULT F_CALLBACK eventCallback(FMOD_STUDIO_EVENT_CALLBACK_TYPE type,
    FMOD_STUDIO_EVENTINSTANCE* event, void* parameters) {
    FMOD::Studio::EventInstance* instance = (FMOD::Studio::EventInstance*)event;
    void* userData = NULL;
    instance->getUserData(&userData);
    int handle = (int)(intptr_t)userData;
    if (handle > 0) {
        gCbFlags[handle & 0xFFFF] |= type;
    }
    return FMOD_OK;
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

    // Store the handle in userdata so FMOD-thread callbacks can find it
    // without touching the handle table.
    instance->setUserData((void*)(intptr_t)handle);
    gCbFlags[handle & 0xFFFF] = 0; // slot may be recycled - clear stale flags
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
        gCbFlags[h & 0xFFFF] = 0;
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

void fmod_enable_callbacks(int h) {
    FMOD::Studio::EventInstance* instance = resolveInstance(h);
    if (instance) {
        instance->setCallback(eventCallback,
            FMOD_STUDIO_EVENT_CALLBACK_STARTED | FMOD_STUDIO_EVENT_CALLBACK_STOPPED |
            FMOD_STUDIO_EVENT_CALLBACK_SOUND_PLAYED | FMOD_STUDIO_EVENT_CALLBACK_SOUND_STOPPED);
        gCbFlags[h & 0xFFFF] = 0;
    }
}

bool fmod_poll_callbacks(int h, unsigned int mask) {
    if (!resolveInstance(h)) return false;
    int idx = h & 0xFFFF;
    bool fired = (gCbFlags[idx] & mask) != 0;
    gCbFlags[idx] &= ~mask;
    return fired;
}

//// Studio System (2.0 bindings)

// Result of the most recent studio binding call made from the Haxe thread.
static FMOD_RESULT gLastResult = FMOD_OK;
// Static buffer for string out-params. Contents are only valid until the
// next binding call; the Haxe wrappers copy immediately.
static char gStringBuf[512];

int fmod_sys_last_result() {
    return (int)gLastResult;
}

int fmod_sys_get_bus(const ::String& path) {
    if (!gStudioSystem) { gLastResult = FMOD_ERR_STUDIO_UNINITIALIZED; return 0; }
    FMOD::Studio::Bus* bus = NULL;
    gLastResult = gStudioSystem->getBus(path.c_str(), &bus);
    if (gLastResult != FMOD_OK || !bus) return 0;
    return faxe_handle_alloc(bus, FAXE_TYPE_BUS);
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
    if (gLastResult == FMOD_OK) {
        snprintf(gStringBuf, sizeof(gStringBuf),
            "{%08x-%04x-%04x-%02x%02x-%02x%02x%02x%02x%02x%02x}",
            id.Data1, id.Data2, id.Data3,
            id.Data4[0], id.Data4[1], id.Data4[2], id.Data4[3],
            id.Data4[4], id.Data4[5], id.Data4[6], id.Data4[7]);
    }
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

//// Debug

int fmod_debug_live_handle_count() {
    return faxe_live_handle_count();
}

} // namespace faxe
} // namespace linc
