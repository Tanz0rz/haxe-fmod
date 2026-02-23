/**
 * Jaxe - JavaScript FMOD bindings - Minimal FFI layer
 *
 * DESIGN: This is the thinnest possible wrapper around FMOD.
 * - No logic, minimal error handling
 * - Just raw FMOD API calls
 * - All logic lives in Haxe (JsBackend.hx)
 */

class jaxe {
    static FMOD = {};
    static gSystem = {};
    static gSystemCore = {};
    static gAudioResumed = false;
    static FmodIsInitialized = false;
    static loadedBanks = {};
    static autoUpdateIntervalId = null;

    // Instance storage (must be native - these are JS FMOD objects)
    static instances = [];
    static callbackFlags = [];

    //// System

    static fmod_is_initialized() {
        return jaxe.FmodIsInitialized;
    }

    static fmod_init(numChannels) {
        jaxe.FMOD['preRun'] = jaxe.preRun;
        jaxe.FMOD['onRuntimeInitialized'] = jaxe.onRuntimeInitialized;
        jaxe.FMOD['TOTAL_MEMORY'] = 64 * 1024 * 1024;
        FMODModule(jaxe.FMOD);
    }

    static fmod_update() {
        jaxe.gSystem.update();
    }

    static fmod_set_auto_update(enabled) {
        if (enabled && !jaxe.autoUpdateIntervalId) {
            jaxe.autoUpdateIntervalId = window.setInterval(function() {
                if (jaxe.gSystem && jaxe.gSystem.update) {
                    jaxe.gSystem.update();
                }
            }, 16); // ~60fps
        } else if (!enabled && jaxe.autoUpdateIntervalId) {
            window.clearInterval(jaxe.autoUpdateIntervalId);
            jaxe.autoUpdateIntervalId = null;
        }
    }

    //// Banks

    static fmod_load_bank(path) {
        var outval = {};
        var result = jaxe.gSystem.loadBankFile("/" + path, jaxe.FMOD.STUDIO_LOAD_BANK_NORMAL, outval);
        if (result == jaxe.FMOD.OK) {
            jaxe.loadedBanks[path] = outval.val;
        }
        return result;
    }

    static fmod_unload_bank(path) {
        if (jaxe.loadedBanks[path]) {
            jaxe.loadedBanks[path].unload();
            jaxe.loadedBanks[path] = undefined;
        }
    }

    //// Events - One shot

    static fmod_fire_one_shot(eventPath) {
        var desc = {};
        var result = jaxe.gSystem.getEvent(eventPath, desc);
        if (result != jaxe.FMOD.OK) return result;

        var instance = {};
        result = desc.val.createInstance(instance);
        if (result != jaxe.FMOD.OK) return result;

        instance.val.start();
        instance.val.release();
        return jaxe.FMOD.OK;
    }

    //// Events - Managed instances

    static fmod_create_instance(eventPath) {
        var desc = {};
        var result = jaxe.gSystem.getEvent(eventPath, desc);
        if (result != jaxe.FMOD.OK) return -1;

        var instance = {};
        result = desc.val.createInstance(instance);
        if (result != jaxe.FMOD.OK) return -1;

        var handle = jaxe.instances.length;
        jaxe.instances.push(instance.val);
        jaxe.callbackFlags.push(0);
        return handle;
    }

    static fmod_start(handle) {
        var inst = jaxe.instances[handle];
        if (inst) inst.start();
    }

    static fmod_stop(handle, immediate) {
        var inst = jaxe.instances[handle];
        if (inst) {
            inst.stop(immediate ? jaxe.FMOD.STUDIO_STOP_IMMEDIATE : jaxe.FMOD.STUDIO_STOP_ALLOWFADEOUT);
        }
    }

    static fmod_release(handle) {
        var inst = jaxe.instances[handle];
        if (inst) {
            inst.stop(jaxe.FMOD.STUDIO_STOP_IMMEDIATE);
            inst.release();
            jaxe.instances[handle] = null;
            jaxe.callbackFlags[handle] = 0;
        }
    }

    static fmod_set_paused(handle, paused) {
        var inst = jaxe.instances[handle];
        if (inst) inst.setPaused(paused);
    }

    static fmod_get_playback_state(handle) {
        var inst = jaxe.instances[handle];
        if (!inst) return jaxe.FMOD.STUDIO_PLAYBACK_STOPPED;
        var outval = {};
        inst.getPlaybackState(outval);
        return outval.val;
    }

    //// Parameters

    static fmod_get_param(handle, name) {
        var inst = jaxe.instances[handle];
        if (!inst) return 0.0;
        var outval = {};
        inst.getParameterByName(name, outval);
        return outval.val;
    }

    static fmod_set_param(handle, name, value) {
        var inst = jaxe.instances[handle];
        if (inst) inst.setParameterByName(name, value, false);
    }

    //// Bus

    static fmod_set_bus_paused(path, paused) {
        var bus = {};
        if (jaxe.gSystem.getBus(path, bus) == jaxe.FMOD.OK) {
            bus.val.setPaused(paused);
        }
    }

    static fmod_stop_bus(path) {
        var bus = {};
        if (jaxe.gSystem.getBus(path, bus) == jaxe.FMOD.OK) {
            bus.val.stopAllEvents(jaxe.FMOD.STUDIO_STOP_IMMEDIATE);
        }
    }

    static fmod_set_bus_volume(path, volume) {
        var bus = {};
        if (jaxe.gSystem.getBus(path, bus) == jaxe.FMOD.OK) {
            bus.val.setVolume(volume);
        }
    }

    static fmod_get_bus_volume(path) {
        var bus = {};
        if (jaxe.gSystem.getBus(path, bus) == jaxe.FMOD.OK) {
            var outval = {};
            bus.val.getVolume(outval);
            return outval.val;
        }
        return 0.0;
    }

    static fmod_set_bus_mute(path, mute) {
        var bus = {};
        if (jaxe.gSystem.getBus(path, bus) == jaxe.FMOD.OK) {
            bus.val.setMute(mute);
        }
    }

    static fmod_get_bus_mute(path) {
        var bus = {};
        if (jaxe.gSystem.getBus(path, bus) == jaxe.FMOD.OK) {
            var outval = {};
            bus.val.getMute(outval);
            return outval.val;
        }
        return false;
    }

    //// Callbacks

    static fmod_enable_callbacks(handle) {
        var inst = jaxe.instances[handle];
        if (inst) {
            inst.setCallback(jaxe.callbackHandler, jaxe.FMOD.STUDIO_EVENT_CALLBACK_ALL);
            jaxe.callbackFlags[handle] = 0;
        }
    }

    static fmod_poll_callbacks(handle, mask) {
        if (handle < 0 || handle >= jaxe.callbackFlags.length) return false;
        var fired = (jaxe.callbackFlags[handle] & mask) != 0;
        jaxe.callbackFlags[handle] &= ~mask;
        return fired;
    }

    static callbackHandler(type, event, parameters) {
        for (var i = 0; i < jaxe.instances.length; i++) {
            if (jaxe.instances[i] === event) {
                jaxe.callbackFlags[i] |= type;
                break;
            }
        }
        return jaxe.FMOD.OK;
    }

    //// Initialization (Emscripten-specific, must stay here)

    static preRun = function () {
        var files = ["Master.bank", "Master.strings.bank"];
        var appRoot = window.location.pathname;
        var gameRoot = appRoot.substring(0, appRoot.lastIndexOf("/"));
        var fileUrl = gameRoot + "/assets/fmod/Desktop/";

        for (var i = 0; i < files.length; i++) {
            jaxe.FMOD.FS_createPreloadedFile("/", files[i], fileUrl + files[i], true, false);
        }
    }

    static onRuntimeInitialized = function () {
        var outval = {};

        jaxe.FMOD.Studio_System_Create(outval);
        jaxe.gSystem = outval.val;

        jaxe.gSystem.getCoreSystem(outval);
        jaxe.gSystemCore = outval.val;

        jaxe.gSystemCore.setDSPBufferSize(2048, 2);

        jaxe.gSystemCore.getDriverInfo(0, null, null, outval, null, null);
        jaxe.gSystemCore.setSoftwareFormat(outval.val, jaxe.FMOD.SPEAKERMODE_DEFAULT, 0);

        // Browser audio resume handler
        document.addEventListener('click', function () {
            if (!jaxe.gAudioResumed) {
                jaxe.gSystemCore.mixerSuspend();
                jaxe.gSystemCore.mixerResume();
                jaxe.gAudioResumed = true;
            }
        });

        jaxe.gSystem.initialize(1024, jaxe.FMOD.STUDIO_INIT_NORMAL, jaxe.FMOD.INIT_NORMAL, null);

        // Enable auto-update by default
        jaxe.fmod_set_auto_update(true);

        // Load default banks
        jaxe.gSystem.loadBankFile("/Master.bank", jaxe.FMOD.STUDIO_LOAD_BANK_NORMAL, outval);
        jaxe.loadedBanks["Master.bank"] = outval.val;
        jaxe.gSystem.loadBankFile("/Master.strings.bank", jaxe.FMOD.STUDIO_LOAD_BANK_NORMAL, outval);
        jaxe.loadedBanks["Master.strings.bank"] = outval.val;

        jaxe.FmodIsInitialized = true;
        return jaxe.FMOD.OK;
    }
}
