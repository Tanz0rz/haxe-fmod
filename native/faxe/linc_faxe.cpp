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
#include <thread>
#include <atomic>
#include <chrono>
#include <cstdlib>

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

// Instance storage (array-based, handle = index)
#define MAX_INSTANCES 256
static FMOD::Studio::EventInstance* gInstances[MAX_INSTANCES];
static unsigned int gCallbackFlags[MAX_INSTANCES];
static int gInstanceCount = 0;

// Callback handler
static FMOD_RESULT F_CALLBACK eventCallback(FMOD_STUDIO_EVENT_CALLBACK_TYPE type,
    FMOD_STUDIO_EVENTINSTANCE* event, void* parameters) {
    for (int i = 0; i < gInstanceCount; i++) {
        if (gInstances[i] == (FMOD::Studio::EventInstance*)event) {
            gCallbackFlags[i] |= type;
            break;
        }
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
    if (gInstanceCount >= MAX_INSTANCES) return -1;

    FMOD::Studio::EventDescription* desc;
    if (gStudioSystem->getEvent(eventPath.c_str(), &desc) != FMOD_OK) return -1;

    FMOD::Studio::EventInstance* instance;
    if (desc->createInstance(&instance) != FMOD_OK) return -1;

    int handle = gInstanceCount++;
    gInstances[handle] = instance;
    gCallbackFlags[handle] = 0;
    return handle;
}

void fmod_start(int h) {
    if (h >= 0 && h < gInstanceCount && gInstances[h])
        gInstances[h]->start();
}

void fmod_stop(int h, int immediate) {
    if (h >= 0 && h < gInstanceCount && gInstances[h])
        gInstances[h]->stop(immediate ? FMOD_STUDIO_STOP_IMMEDIATE : FMOD_STUDIO_STOP_ALLOWFADEOUT);
}

void fmod_release(int h) {
    if (h >= 0 && h < gInstanceCount && gInstances[h]) {
        gInstances[h]->stop(FMOD_STUDIO_STOP_IMMEDIATE);
        gInstances[h]->release();
        gInstances[h] = NULL;
        gCallbackFlags[h] = 0;
    }
}

void fmod_set_paused(int h, bool paused) {
    if (h >= 0 && h < gInstanceCount && gInstances[h])
        gInstances[h]->setPaused(paused);
}

int fmod_get_playback_state(int h) {
    if (h < 0 || h >= gInstanceCount || !gInstances[h]) return FMOD_STUDIO_PLAYBACK_STOPPED;
    FMOD_STUDIO_PLAYBACK_STATE state;
    gInstances[h]->getPlaybackState(&state);
    return (int)state;
}

int fmod_get_timeline_position(int h) {
    if (h < 0 || h >= gInstanceCount || !gInstances[h]) return 0;
    int position = 0;
    gInstances[h]->getTimelinePosition(&position);
    return position;
}

//// Parameters

float fmod_get_param(int h, const ::String& name) {
    if (h < 0 || h >= gInstanceCount || !gInstances[h]) return 0.0f;
    float value = 0.0f;
    gInstances[h]->getParameterByName(name.c_str(), &value);
    return value;
}

void fmod_set_param(int h, const ::String& name, float value) {
    if (h >= 0 && h < gInstanceCount && gInstances[h])
        gInstances[h]->setParameterByName(name.c_str(), value, false);
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
    if (h >= 0 && h < gInstanceCount && gInstances[h]) {
        gInstances[h]->setCallback(eventCallback,
            FMOD_STUDIO_EVENT_CALLBACK_STARTED | FMOD_STUDIO_EVENT_CALLBACK_STOPPED |
            FMOD_STUDIO_EVENT_CALLBACK_SOUND_PLAYED | FMOD_STUDIO_EVENT_CALLBACK_SOUND_STOPPED);
        gCallbackFlags[h] = 0;
    }
}

bool fmod_poll_callbacks(int h, unsigned int mask) {
    if (h < 0 || h >= gInstanceCount) return false;
    bool fired = (gCallbackFlags[h] & mask) != 0;
    gCallbackFlags[h] &= ~mask;
    return fired;
}

} // namespace faxe
} // namespace linc
