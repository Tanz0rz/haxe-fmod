/**
 * HashLink FMOD bindings
 *
 * This file wraps the FMOD Studio C API for use with HashLink.
 * Compile with: gcc -shared -fPIC -o hlaxe_fmod.hdll hlaxe_fmod.c -I<hl_include> -I<fmod_include> -L<fmod_lib> -lfmod -lfmodstudio
 */

#define HL_NAME(n) hlaxe_fmod_##n
#include <hl.h>
#include <fmod_studio.h>
#include <fmod.h>
#include <fmod_errors.h>
#include <string.h>
#include <stdio.h>

// Global state
static FMOD_STUDIO_SYSTEM* gStudioSystem = NULL;
static FMOD_SYSTEM* gCoreSystem = NULL;
static bool gDebug = false;

// Simple hash map for event instances (name -> instance pointer)
#define MAX_INSTANCES 256
typedef struct {
    char name[256];
    FMOD_STUDIO_EVENTINSTANCE* instance;
    unsigned int callbackFlags;
} InstanceEntry;

static InstanceEntry gInstances[MAX_INSTANCES];
static int gInstanceCount = 0;

// Callback flags accumulator
static FMOD_RESULT F_CALLBACK eventCallback(FMOD_STUDIO_EVENT_CALLBACK_TYPE type,
    FMOD_STUDIO_EVENTINSTANCE* event, void* parameters) {

    // Find the instance in our table and accumulate flags
    for (int i = 0; i < gInstanceCount; i++) {
        if (gInstances[i].instance == event) {
            gInstances[i].callbackFlags |= type;
            break;
        }
    }
    return FMOD_OK;
}

// Helper to find an instance by name
static InstanceEntry* findInstance(const char* name) {
    for (int i = 0; i < gInstanceCount; i++) {
        if (strcmp(gInstances[i].name, name) == 0) {
            return &gInstances[i];
        }
    }
    return NULL;
}

// Helper to add an instance
static InstanceEntry* addInstance(const char* name, FMOD_STUDIO_EVENTINSTANCE* instance) {
    if (gInstanceCount >= MAX_INSTANCES) {
        if (gDebug) printf("FMOD HL: Max instances reached!\n");
        return NULL;
    }

    InstanceEntry* entry = &gInstances[gInstanceCount++];
    strncpy(entry->name, name, 255);
    entry->name[255] = '\0';
    entry->instance = instance;
    entry->callbackFlags = 0;
    return entry;
}

// Helper to remove an instance
static void removeInstance(const char* name) {
    for (int i = 0; i < gInstanceCount; i++) {
        if (strcmp(gInstances[i].name, name) == 0) {
            // Shift remaining entries
            for (int j = i; j < gInstanceCount - 1; j++) {
                gInstances[j] = gInstances[j + 1];
            }
            gInstanceCount--;
            return;
        }
    }
}

//// System functions

HL_PRIM void HL_NAME(set_debug)(bool onOff) {
    gDebug = onOff;
}
DEFINE_PRIM(_VOID, set_debug, _BOOL);

HL_PRIM bool HL_NAME(is_initialized)() {
    return gStudioSystem != NULL;
}
DEFINE_PRIM(_BOOL, is_initialized, _NO_ARG);

HL_PRIM void HL_NAME(init)(int numChannels) {
    if (gStudioSystem != NULL) return;

    FMOD_RESULT result = FMOD_Studio_System_Create(&gStudioSystem, FMOD_VERSION);
    if (result != FMOD_OK) {
        if (gDebug) printf("FMOD HL: Failed to create system: %s\n", FMOD_ErrorString(result));
        return;
    }

    result = FMOD_Studio_System_Initialize(gStudioSystem, numChannels,
        FMOD_STUDIO_INIT_LIVEUPDATE, FMOD_INIT_NORMAL, NULL);
    if (result != FMOD_OK) {
        if (gDebug) printf("FMOD HL: Failed to initialize: %s\n", FMOD_ErrorString(result));
        FMOD_Studio_System_Release(gStudioSystem);
        gStudioSystem = NULL;
        return;
    }

    FMOD_Studio_System_GetCoreSystem(gStudioSystem, &gCoreSystem);
    if (gDebug) printf("FMOD HL: Initialized with %d channels\n", numChannels);
}
DEFINE_PRIM(_VOID, init, _I32);

HL_PRIM void HL_NAME(update)() {
    if (gStudioSystem) {
        FMOD_Studio_System_Update(gStudioSystem);
    }
}
DEFINE_PRIM(_VOID, update, _NO_ARG);

//// Bank functions

HL_PRIM void HL_NAME(load_bank)(vbyte* bankFilePath) {
    if (!gStudioSystem) return;

    FMOD_STUDIO_BANK* bank;
    FMOD_RESULT result = FMOD_Studio_System_LoadBankFile(gStudioSystem,
        (const char*)bankFilePath, FMOD_STUDIO_LOAD_BANK_NORMAL, &bank);

    if (result != FMOD_OK) {
        if (gDebug) printf("FMOD HL: Failed to load bank %s: %s\n",
            (const char*)bankFilePath, FMOD_ErrorString(result));
    } else if (gDebug) {
        printf("FMOD HL: Loaded bank %s\n", (const char*)bankFilePath);
    }
}
DEFINE_PRIM(_VOID, load_bank, _BYTES);

HL_PRIM void HL_NAME(unload_bank)(vbyte* bankFilePath) {
    // Bank unloading would require tracking bank pointers
    // For now, this is a no-op
    if (gDebug) printf("FMOD HL: unloadBank not fully implemented\n");
}
DEFINE_PRIM(_VOID, unload_bank, _BYTES);

//// Event instance functions

HL_PRIM void HL_NAME(create_event_instance_one_shot)(vbyte* eventPath) {
    if (!gStudioSystem) return;

    FMOD_STUDIO_EVENTDESCRIPTION* desc;
    FMOD_RESULT result = FMOD_Studio_System_GetEvent(gStudioSystem,
        (const char*)eventPath, &desc);
    if (result != FMOD_OK) {
        if (gDebug) printf("FMOD HL: Failed to get event %s: %s\n",
            (const char*)eventPath, FMOD_ErrorString(result));
        return;
    }

    FMOD_STUDIO_EVENTINSTANCE* instance;
    result = FMOD_Studio_EventDescription_CreateInstance(desc, &instance);
    if (result != FMOD_OK) {
        if (gDebug) printf("FMOD HL: Failed to create instance: %s\n", FMOD_ErrorString(result));
        return;
    }

    FMOD_Studio_EventInstance_Start(instance);
    FMOD_Studio_EventInstance_Release(instance);
}
DEFINE_PRIM(_VOID, create_event_instance_one_shot, _BYTES);

HL_PRIM void HL_NAME(create_event_instance_named)(vbyte* eventPath, vbyte* eventInstanceName) {
    if (!gStudioSystem) return;

    const char* name = (const char*)eventInstanceName;

    // Check if instance already exists
    InstanceEntry* existing = findInstance(name);
    if (existing) {
        // Stop and release existing instance
        FMOD_Studio_EventInstance_Stop(existing->instance, FMOD_STUDIO_STOP_IMMEDIATE);
        FMOD_Studio_EventInstance_Release(existing->instance);
        removeInstance(name);
        if (gDebug) printf("FMOD HL: Replaced existing instance %s\n", name);
    }

    FMOD_STUDIO_EVENTDESCRIPTION* desc;
    FMOD_RESULT result = FMOD_Studio_System_GetEvent(gStudioSystem,
        (const char*)eventPath, &desc);
    if (result != FMOD_OK) {
        if (gDebug) printf("FMOD HL: Failed to get event %s: %s\n",
            (const char*)eventPath, FMOD_ErrorString(result));
        return;
    }

    FMOD_STUDIO_EVENTINSTANCE* instance;
    result = FMOD_Studio_EventDescription_CreateInstance(desc, &instance);
    if (result != FMOD_OK) {
        if (gDebug) printf("FMOD HL: Failed to create instance: %s\n", FMOD_ErrorString(result));
        return;
    }

    addInstance(name, instance);
    FMOD_Studio_EventInstance_Start(instance);

    if (gDebug) printf("FMOD HL: Created and started instance %s\n", name);
}
DEFINE_PRIM(_VOID, create_event_instance_named, _BYTES _BYTES);

HL_PRIM bool HL_NAME(is_event_instance_loaded)(vbyte* eventInstanceName) {
    return findInstance((const char*)eventInstanceName) != NULL;
}
DEFINE_PRIM(_BOOL, is_event_instance_loaded, _BYTES);

HL_PRIM void HL_NAME(play_event_instance)(vbyte* eventInstanceName) {
    InstanceEntry* entry = findInstance((const char*)eventInstanceName);
    if (entry) {
        FMOD_Studio_EventInstance_Start(entry->instance);
    }
}
DEFINE_PRIM(_VOID, play_event_instance, _BYTES);

HL_PRIM bool HL_NAME(is_event_instance_playing)(vbyte* eventInstanceName) {
    InstanceEntry* entry = findInstance((const char*)eventInstanceName);
    if (!entry) return false;

    FMOD_STUDIO_PLAYBACK_STATE state;
    FMOD_Studio_EventInstance_GetPlaybackState(entry->instance, &state);
    return state == FMOD_STUDIO_PLAYBACK_PLAYING;
}
DEFINE_PRIM(_BOOL, is_event_instance_playing, _BYTES);

HL_PRIM int HL_NAME(get_event_instance_playback_state)(vbyte* eventInstanceName) {
    InstanceEntry* entry = findInstance((const char*)eventInstanceName);
    if (!entry) return FMOD_STUDIO_PLAYBACK_STOPPED;

    FMOD_STUDIO_PLAYBACK_STATE state;
    FMOD_Studio_EventInstance_GetPlaybackState(entry->instance, &state);
    return (int)state;
}
DEFINE_PRIM(_I32, get_event_instance_playback_state, _BYTES);

HL_PRIM void HL_NAME(set_pause_on_event_instance)(vbyte* eventInstanceName, bool shouldBePaused) {
    InstanceEntry* entry = findInstance((const char*)eventInstanceName);
    if (entry) {
        FMOD_Studio_EventInstance_SetPaused(entry->instance, shouldBePaused);
    }
}
DEFINE_PRIM(_VOID, set_pause_on_event_instance, _BYTES _BOOL);

HL_PRIM void HL_NAME(stop_event_instance)(vbyte* eventInstanceName) {
    InstanceEntry* entry = findInstance((const char*)eventInstanceName);
    if (entry) {
        FMOD_Studio_EventInstance_Stop(entry->instance, FMOD_STUDIO_STOP_ALLOWFADEOUT);
    }
}
DEFINE_PRIM(_VOID, stop_event_instance, _BYTES);

HL_PRIM void HL_NAME(stop_event_instance_immediately)(vbyte* eventInstanceName) {
    InstanceEntry* entry = findInstance((const char*)eventInstanceName);
    if (entry) {
        FMOD_Studio_EventInstance_Stop(entry->instance, FMOD_STUDIO_STOP_IMMEDIATE);
    }
}
DEFINE_PRIM(_VOID, stop_event_instance_immediately, _BYTES);

HL_PRIM void HL_NAME(release_event_instance)(vbyte* eventInstanceName) {
    InstanceEntry* entry = findInstance((const char*)eventInstanceName);
    if (entry) {
        FMOD_Studio_EventInstance_Release(entry->instance);
        removeInstance((const char*)eventInstanceName);
    }
}
DEFINE_PRIM(_VOID, release_event_instance, _BYTES);

//// Parameter functions

HL_PRIM double HL_NAME(get_event_instance_param)(vbyte* eventInstanceName, vbyte* paramName) {
    InstanceEntry* entry = findInstance((const char*)eventInstanceName);
    if (!entry) return 0.0;

    float value = 0.0f;
    FMOD_Studio_EventInstance_GetParameterByName(entry->instance,
        (const char*)paramName, &value, NULL);
    return (double)value;
}
DEFINE_PRIM(_F64, get_event_instance_param, _BYTES _BYTES);

HL_PRIM void HL_NAME(set_event_instance_param)(vbyte* eventInstanceName, vbyte* paramName, double value) {
    InstanceEntry* entry = findInstance((const char*)eventInstanceName);
    if (entry) {
        FMOD_Studio_EventInstance_SetParameterByName(entry->instance,
            (const char*)paramName, (float)value, false);
    }
}
DEFINE_PRIM(_VOID, set_event_instance_param, _BYTES _BYTES _F64);

//// Bus functions

HL_PRIM void HL_NAME(set_pause_for_all_events_on_bus)(vbyte* busPath, bool shouldBePaused) {
    if (!gStudioSystem) return;

    FMOD_STUDIO_BUS* bus;
    FMOD_RESULT result = FMOD_Studio_System_GetBus(gStudioSystem, (const char*)busPath, &bus);
    if (result == FMOD_OK) {
        FMOD_Studio_Bus_SetPaused(bus, shouldBePaused);
    }
}
DEFINE_PRIM(_VOID, set_pause_for_all_events_on_bus, _BYTES _BOOL);

HL_PRIM void HL_NAME(stop_all_events_on_bus)(vbyte* busPath) {
    if (!gStudioSystem) return;

    FMOD_STUDIO_BUS* bus;
    FMOD_RESULT result = FMOD_Studio_System_GetBus(gStudioSystem, (const char*)busPath, &bus);
    if (result == FMOD_OK) {
        FMOD_Studio_Bus_StopAllEvents(bus, FMOD_STUDIO_STOP_ALLOWFADEOUT);
    }
}
DEFINE_PRIM(_VOID, stop_all_events_on_bus, _BYTES);

//// Callback functions

HL_PRIM void HL_NAME(set_callback_tracking_for_event_instance)(vbyte* eventInstanceName) {
    InstanceEntry* entry = findInstance((const char*)eventInstanceName);
    if (entry) {
        FMOD_Studio_EventInstance_SetCallback(entry->instance, eventCallback,
            FMOD_STUDIO_EVENT_CALLBACK_STARTED |
            FMOD_STUDIO_EVENT_CALLBACK_STOPPED |
            FMOD_STUDIO_EVENT_CALLBACK_SOUND_PLAYED |
            FMOD_STUDIO_EVENT_CALLBACK_SOUND_STOPPED);
    }
}
DEFINE_PRIM(_VOID, set_callback_tracking_for_event_instance, _BYTES);

HL_PRIM bool HL_NAME(check_callbacks_for_event_instance)(vbyte* eventInstanceName, int callbackEventMask) {
    InstanceEntry* entry = findInstance((const char*)eventInstanceName);
    if (!entry) return false;

    bool happened = (entry->callbackFlags & callbackEventMask) != 0;
    entry->callbackFlags &= ~callbackEventMask; // Clear checked flags
    return happened;
}
DEFINE_PRIM(_BOOL, check_callbacks_for_event_instance, _BYTES _I32);
