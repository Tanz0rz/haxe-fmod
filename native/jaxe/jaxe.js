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

    // Generational handle table - JS mirror of native/shared/faxe_handles.h.
    // Handle encoding: (generation << 16) | index. Handle 0 is always invalid.
    static TYPE_EVI = 1;
    static slots = [];       // {ptr, gen, type, alive}
    static freeList = [];    // stack of free slot indices
    static liveCount = 0;
    static callbackFlags = []; // legacy poll flags, indexed by slot index (replaced in M2)

    static handleAlloc(ptr, type) {
        if (!ptr) return 0;
        var idx;
        if (jaxe.freeList.length > 0) {
            idx = jaxe.freeList.pop();
        } else {
            idx = jaxe.slots.length;
            if (idx >= 0x10000) return 0;
            jaxe.slots.push({ ptr: null, gen: 0, type: 0, alive: false });
            jaxe.callbackFlags.push(0);
        }
        var s = jaxe.slots[idx];
        s.ptr = ptr;
        s.type = type;
        s.alive = true;
        if (s.gen == 0) s.gen = 1; // first use of this slot
        jaxe.liveCount++;
        return (s.gen << 16) | idx;
    }

    static handleResolve(handle, type) {
        if (handle <= 0) return null;
        var idx = handle & 0xFFFF;
        var gen = (handle >> 16) & 0x7FFF;
        var s = jaxe.slots[idx];
        if (!s || !s.alive || s.gen != gen || s.type != type) return null;
        return s.ptr;
    }

    static handleFree(handle) {
        if (handle <= 0) return;
        var idx = handle & 0xFFFF;
        var gen = (handle >> 16) & 0x7FFF;
        var s = jaxe.slots[idx];
        if (!s || !s.alive || s.gen != gen) return;
        s.alive = false;
        s.ptr = null;
        s.type = 0;
        s.gen = (s.gen % 0x7FFF) + 1; // wraps 1..0x7FFF, never 0
        jaxe.freeList.push(idx);
        jaxe.liveCount--;
    }

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

        var handle = jaxe.handleAlloc(instance.val, jaxe.TYPE_EVI);
        if (handle == 0) {
            instance.val.release();
            return -1;
        }
        jaxe.callbackFlags[handle & 0xFFFF] = 0; // slot may be recycled - clear stale flags
        return handle;
    }

    static fmod_start(handle) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (inst) inst.start();
    }

    static fmod_stop(handle, immediate) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (inst) {
            inst.stop(immediate ? jaxe.FMOD.STUDIO_STOP_IMMEDIATE : jaxe.FMOD.STUDIO_STOP_ALLOWFADEOUT);
        }
    }

    static fmod_release(handle) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (inst) {
            inst.stop(jaxe.FMOD.STUDIO_STOP_IMMEDIATE);
            inst.release();
            jaxe.callbackFlags[handle & 0xFFFF] = 0;
            jaxe.handleFree(handle);
        }
    }

    static fmod_set_paused(handle, paused) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (inst) inst.setPaused(paused);
    }

    static fmod_get_playback_state(handle) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) return jaxe.FMOD.STUDIO_PLAYBACK_STOPPED;
        var outval = {};
        inst.getPlaybackState(outval);
        return outval.val;
    }

    static fmod_get_timeline_position(handle) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) return 0;
        var outval = {};
        inst.getTimelinePosition(outval);
        return outval.val;
    }

    //// Parameters

    static fmod_get_param(handle, name) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) return 0.0;
        var outval = {};
        inst.getParameterByName(name, outval);
        return outval.val;
    }

    static fmod_set_param(handle, name, value) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
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
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (inst) {
            inst.setCallback(jaxe.callbackHandler, jaxe.FMOD.STUDIO_EVENT_CALLBACK_ALL);
            jaxe.callbackFlags[handle & 0xFFFF] = 0;
        }
    }

    static fmod_poll_callbacks(handle, mask) {
        if (!jaxe.handleResolve(handle, jaxe.TYPE_EVI)) return false;
        var idx = handle & 0xFFFF;
        var fired = (jaxe.callbackFlags[idx] & mask) != 0;
        jaxe.callbackFlags[idx] &= ~mask;
        return fired;
    }

    static callbackHandler(type, event, parameters) {
        // JS is single-threaded, so scanning the table here is safe.
        for (var i = 0; i < jaxe.slots.length; i++) {
            var s = jaxe.slots[i];
            if (s.alive && s.ptr === event) {
                jaxe.callbackFlags[i] |= type;
                break;
            }
        }
        return jaxe.FMOD.OK;
    }

    //// Studio System (2.0 bindings)

    static TYPE_BUS = 4;
    static lastResult = 0;
    static ERR_INVALID_HANDLE = 30;
    static ERR_UNSUPPORTED = 68;
    static ERR_STUDIO_UNINITIALIZED = 75;

    static fmod_sys_last_result() {
        return jaxe.lastResult;
    }

    static fmod_sys_get_bus(path) {
        if (!jaxe.FmodIsInitialized) {
            jaxe.lastResult = jaxe.ERR_STUDIO_UNINITIALIZED;
            return 0;
        }
        var bus = {};
        jaxe.lastResult = jaxe.gSystem.getBus(path, bus);
        if (jaxe.lastResult != jaxe.FMOD.OK || !bus.val) return 0;
        return jaxe.handleAlloc(bus.val, jaxe.TYPE_BUS);
    }

    //// Bus (2.0 bindings)

    static formatGuid(id) {
        // FMOD JS GUID objects have Data1..Data3 ints and Data4 as an 8-byte array
        if (typeof id === "string") return id;
        function hex(value, width) {
            var text = (value >>> 0).toString(16);
            while (text.length < width) text = "0" + text;
            return text.slice(-width);
        }
        var d4 = id.Data4;
        return "{" + hex(id.Data1, 8) + "-" + hex(id.Data2, 4) + "-" + hex(id.Data3, 4) + "-"
            + hex(d4[0], 2) + hex(d4[1], 2) + "-"
            + hex(d4[2], 2) + hex(d4[3], 2) + hex(d4[4], 2) + hex(d4[5], 2) + hex(d4[6], 2) + hex(d4[7], 2) + "}";
    }

    static fmod_bus_is_valid(handle) {
        var bus = jaxe.handleResolve(handle, jaxe.TYPE_BUS);
        return bus != null && (!bus.isValid || bus.isValid());
    }

    static fmod_bus_get_id(handle) {
        var bus = jaxe.handleResolve(handle, jaxe.TYPE_BUS);
        if (!bus) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return ""; }
        if (!bus.getID) { jaxe.lastResult = jaxe.ERR_UNSUPPORTED; return ""; }
        var outval = {};
        jaxe.lastResult = bus.getID(outval);
        if (jaxe.lastResult != jaxe.FMOD.OK) return "";
        return jaxe.formatGuid(outval.val);
    }

    static fmod_bus_get_path(handle) {
        var bus = jaxe.handleResolve(handle, jaxe.TYPE_BUS);
        if (!bus) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return ""; }
        var outval = {};
        jaxe.lastResult = bus.getPath(outval, 512, null);
        if (jaxe.lastResult != jaxe.FMOD.OK) return "";
        return outval.val;
    }

    static fmod_bus_get_volume(handle) {
        var bus = jaxe.handleResolve(handle, jaxe.TYPE_BUS);
        if (!bus) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0.0; }
        var outval = {};
        jaxe.lastResult = bus.getVolume(outval);
        return outval.val || 0.0;
    }

    static fmod_bus_get_final_volume(handle) {
        var bus = jaxe.handleResolve(handle, jaxe.TYPE_BUS);
        if (!bus) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0.0; }
        var volume = {};
        var finalVolume = {};
        jaxe.lastResult = bus.getVolume(volume, finalVolume);
        return finalVolume.val || 0.0;
    }

    static fmod_bus_set_volume(handle, volume) {
        var bus = jaxe.handleResolve(handle, jaxe.TYPE_BUS);
        if (!bus) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = bus.setVolume(volume);
        return jaxe.lastResult;
    }

    static fmod_bus_get_paused(handle) {
        var bus = jaxe.handleResolve(handle, jaxe.TYPE_BUS);
        if (!bus) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return false; }
        var outval = {};
        jaxe.lastResult = bus.getPaused(outval);
        return !!outval.val;
    }

    static fmod_bus_set_paused(handle, paused) {
        var bus = jaxe.handleResolve(handle, jaxe.TYPE_BUS);
        if (!bus) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = bus.setPaused(paused);
        return jaxe.lastResult;
    }

    static fmod_bus_get_mute(handle) {
        var bus = jaxe.handleResolve(handle, jaxe.TYPE_BUS);
        if (!bus) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return false; }
        var outval = {};
        jaxe.lastResult = bus.getMute(outval);
        return !!outval.val;
    }

    static fmod_bus_set_mute(handle, mute) {
        var bus = jaxe.handleResolve(handle, jaxe.TYPE_BUS);
        if (!bus) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = bus.setMute(mute);
        return jaxe.lastResult;
    }

    static fmod_bus_stop_all_events(handle, stopMode) {
        var bus = jaxe.handleResolve(handle, jaxe.TYPE_BUS);
        if (!bus) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = bus.stopAllEvents(
            stopMode == 1 ? jaxe.FMOD.STUDIO_STOP_IMMEDIATE : jaxe.FMOD.STUDIO_STOP_ALLOWFADEOUT);
        return jaxe.lastResult;
    }

    // out = int[2]: exclusive, inclusive (microseconds)
    static fmod_bus_get_cpu_usage(handle, out) {
        var bus = jaxe.handleResolve(handle, jaxe.TYPE_BUS);
        if (!bus) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        if (!bus.getCPUUsage) { jaxe.lastResult = jaxe.ERR_UNSUPPORTED; return jaxe.lastResult; }
        var exclusive = {};
        var inclusive = {};
        jaxe.lastResult = bus.getCPUUsage(exclusive, inclusive);
        out[0] = exclusive.val | 0;
        out[1] = inclusive.val | 0;
        return jaxe.lastResult;
    }

    // out = int[3]: exclusive, inclusive, sampledata (bytes)
    static fmod_bus_get_memory_usage(handle, out) {
        var bus = jaxe.handleResolve(handle, jaxe.TYPE_BUS);
        if (!bus) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        if (!bus.getMemoryUsage) { jaxe.lastResult = jaxe.ERR_UNSUPPORTED; return jaxe.lastResult; }
        var outval = {};
        jaxe.lastResult = bus.getMemoryUsage(outval);
        if (jaxe.lastResult == jaxe.FMOD.OK && outval.val) {
            out[0] = outval.val.exclusive | 0;
            out[1] = outval.val.inclusive | 0;
            out[2] = outval.val.sampledata | 0;
        }
        return jaxe.lastResult;
    }

    //// Debug

    static fmod_debug_live_handle_count() {
        return jaxe.liveCount;
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
