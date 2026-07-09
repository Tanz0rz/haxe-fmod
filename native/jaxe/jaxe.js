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

    // Init settings stored by fmod_sys_init_ex and consumed by
    // onRuntimeInitialized. Legacy fmod_init leaves this null (defaults).
    static pendingInit = null;
    // Counter for unique MEMFS names used by fmod_sys_load_bank_async.
    static asyncBankCounter = 0;

    // Generational handle table - JS mirror of native/shared/faxe_handles.h.
    // Handle encoding: (generation << 16) | index. Handle 0 is always invalid.
    // Type tags match native/shared/faxe_handles.h.
    static TYPE_EVI = 1;
    static TYPE_EVD = 2;
    static TYPE_BANK = 3;
    static TYPE_BUS = 4;
    static TYPE_VCA = 5;
    static TYPE_SOUND = 6;
    static slots = [];       // {ptr, raw, gen, type, alive}
    static freeList = [];    // stack of free slot indices
    static liveCount = 0;

    // Callback event queue - JS mirror of native/shared/faxe_cbqueue.h.
    // JS is single-threaded so a plain array needs no locking.
    static CBQ_CAPACITY = 256;
    static cbQueue = [];
    static cbOverflow = false;
    static cbCurrent = { handle: 0, type: 0, i1: 0, i2: 0, i3: 0, f1: 0.0, str: "" };

    // The FMOD JS bindings return a fresh wrapper object from every call, so
    // wrappers have no JS identity (=== and isAliasOf never match across
    // calls). Each wrapper's $$.ptr points at a small proxy struct whose
    // first word is the real FMOD object pointer - read that word for
    // identity (verified against the FMOD 2.03.12 wasm build).
    static rawPtr(obj) {
        if (obj && obj.$$ && jaxe.FMOD.HEAPU32) {
            return jaxe.FMOD.HEAPU32[obj.$$.ptr >> 2];
        }
        return 0;
    }

    static handleAlloc(ptr, type) {
        if (!ptr) return 0;
        var idx;
        if (jaxe.freeList.length > 0) {
            idx = jaxe.freeList.pop();
        } else {
            idx = jaxe.slots.length;
            if (idx >= 0x10000) return 0;
            jaxe.slots.push({ ptr: null, raw: 0, gen: 0, type: 0, alive: false });
        }
        var s = jaxe.slots[idx];
        s.ptr = ptr;
        s.raw = jaxe.rawPtr(ptr);
        s.type = type;
        s.alive = true;
        if (s.gen == 0) s.gen = 1; // first use of this slot
        jaxe.liveCount++;
        return (s.gen << 16) | idx;
    }

    // JS mirror of faxe_handle_find_or_alloc: reuse the existing handle when
    // FMOD returns an object the table has already seen, otherwise allocate.
    // Prevents duplicate handles when the same object comes back from
    // multiple lookups (e.g. getBus by path then by ID).
    static handleFindOrAlloc(ptr, type) {
        if (!ptr) return 0;
        var raw = jaxe.rawPtr(ptr);
        for (var i = 0; i < jaxe.slots.length; i++) {
            var s = jaxe.slots[i];
            if (!s.alive || s.type != type) continue;
            if ((raw != 0 && s.raw === raw) || s.ptr === ptr
                || (s.ptr.isAliasOf && s.ptr.isAliasOf(ptr))) {
                return (s.gen << 16) | i;
            }
        }
        return jaxe.handleAlloc(ptr, type);
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
        s.raw = 0;
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
        // Store the handle in FMOD userdata so callbacks can identify the
        // instance. The wrapper object FMOD passes to callbacks is a fresh
        // binding object each time, so JS identity (===) never matches the
        // stored wrapper; userdata is the reliable channel (mirrors cpp/hl).
        instance.val.setUserData(handle);
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
            // Uninstall the callback first: destroying an instance with a
            // callback installed corrupts the FMOD JS module.
            jaxe.uninstallCallback(handle);
            inst.stop(jaxe.FMOD.STUDIO_STOP_IMMEDIATE);
            inst.release();
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
        // (name, value, finalvalue) - unwanted outs must be explicit null
        inst.getParameterByName(name, outval, null);
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
            // (volume, finalvolume) - unwanted outs must be explicit null
            bus.val.getVolume(outval, null);
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

    // Per-instance callback masks and programmer-sound keys, keyed by handle.
    // JS is single-threaded (callbacks run on the main thread), so plain maps
    // are safe where cpp/hl need the userdata context struct.
    static cbMasks = {};
    static psKeys = {};

    // The programmer-sound bits are added while a key is assigned. Unlike
    // cpp/hl, DESTROYED is NOT forced in: FMOD's JS glue corrupts the wasm
    // module if an instance is destroyed while a callback is installed
    // ("Cannot use deleted val"), so callbacks are uninstalled in every
    // destruction path instead (see uninstallCallback) and Destroyed events
    // are never delivered on this backend.
    static effectiveCallbackMask(handle) {
        var mask = (jaxe.cbMasks[handle] || 0) >>> 0;
        if (jaxe.psKeys[handle]) {
            mask |= 0x80 /* CREATE_PROGRAMMER_SOUND */ | 0x100 /* DESTROY_PROGRAMMER_SOUND */;
        }
        return mask >>> 0;
    }

    // True if this handle has an FMOD callback installed (mask or ps key).
    static hasCallbackState(handle) {
        return jaxe.cbMasks[handle] !== undefined || jaxe.psKeys[handle] !== undefined;
    }

    // Removes the FMOD callback and per-handle state. MUST be called before
    // any operation that can destroy the instance, or the FMOD JS glue
    // corrupts the module.
    static uninstallCallback(handle) {
        if (!jaxe.hasCallbackState(handle)) return;
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (inst) inst.setCallback(null, 0);
        delete jaxe.cbMasks[handle];
        delete jaxe.psKeys[handle];
    }

    // Uninstalls callbacks on every tracked instance (or only those whose
    // description raw pointer is in descPtrs when given). Used before
    // bulk-destroy operations: releaseAllInstances, bank unload, unloadAll.
    static uninstallCallbacksFor(descPtrs) {
        var handles = Object.keys(jaxe.cbMasks).concat(Object.keys(jaxe.psKeys));
        for (var i = 0; i < handles.length; i++) {
            var handle = handles[i] | 0;
            var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
            if (!inst) {
                delete jaxe.cbMasks[handle];
                delete jaxe.psKeys[handle];
                continue;
            }
            if (descPtrs != null) {
                var d = {};
                if (inst.getDescription(d) != jaxe.FMOD.OK || !descPtrs.has(jaxe.rawPtr(d.val))) continue;
            }
            jaxe.uninstallCallback(handle);
        }
    }

    static fmod_evi_set_callback_mask(handle, mask) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.cbMasks[handle] = mask >>> 0;
        jaxe.lastResult = inst.setCallback(jaxe.callbackHandler, jaxe.effectiveCallbackMask(handle));
        return jaxe.lastResult;
    }

    static callbackHandler(type, event, parameters) {
        // The event wrapper here is a fresh binding object (no JS identity
        // with the stored wrapper), so read the handle from FMOD userdata -
        // same mechanism as the cpp/hl shims.
        var handle = 0;
        if (event && event.getUserData) {
            var ud = {};
            if (event.getUserData(ud) == jaxe.FMOD.OK && typeof ud.val === "number") {
                handle = ud.val | 0;
            }
        }
        if (handle <= 0) return jaxe.FMOD.OK;

        if (type == 0x80 /* CREATE_PROGRAMMER_SOUND */ && parameters) {
            var key = jaxe.psKeys[handle];
            if (key) {
                var info = {};
                var soundOut = {};
                if (jaxe.gSystem.getSoundInfo(key, info) == jaxe.FMOD.OK) {
                    // Audio table entry. The JS API takes the sound info object
                    // directly in place of name/exinfo.
                    if (jaxe.gSystemCore.createSound(info.val.name_or_data,
                            (jaxe.FMOD.LOOP_NORMAL | jaxe.FMOD.CREATECOMPRESSEDSAMPLE | info.val.mode) >>> 0,
                            info.val.exinfo, soundOut) == jaxe.FMOD.OK) {
                        parameters.sound = soundOut.val;
                        parameters.subsoundIndex = info.val.subsoundindex;
                    }
                } else if (jaxe.gSystemCore.createSound("/" + key, jaxe.FMOD.DEFAULT, null, soundOut) == jaxe.FMOD.OK) {
                    // Plain file path fallback (relative to the MEMFS root)
                    parameters.sound = soundOut.val;
                    parameters.subsoundIndex = -1;
                }
            }
        } else if (type == 0x100 /* DESTROY_PROGRAMMER_SOUND */ && parameters) {
            if (parameters.sound && parameters.sound.release) {
                parameters.sound.release();
            }
        }

        var ev = { handle: handle, type: type, i1: 0, i2: 0, i3: 0, f1: 0.0, str: "" };

        if (type == 0x00000800 /* TIMELINE_MARKER */ && parameters) {
            if (typeof parameters.name === "string") ev.str = parameters.name;
            if (typeof parameters.position === "number") ev.i1 = parameters.position;
        } else if (type == 0x00001000 /* TIMELINE_BEAT */ && parameters) {
            ev.i1 = parameters.bar | 0;
            ev.i2 = parameters.beat | 0;
            ev.i3 = parameters.position | 0;
            ev.f1 = parameters.tempo || 0.0;
        } else if (type == 0x00040000 /* NESTED_TIMELINE_BEAT */ && parameters && parameters.properties) {
            ev.i1 = parameters.properties.bar | 0;
            ev.i2 = parameters.properties.beat | 0;
            ev.i3 = parameters.properties.position | 0;
            ev.f1 = parameters.properties.tempo || 0.0;
        }

        jaxe.cbQueue.push(ev);
        if (jaxe.cbQueue.length > jaxe.CBQ_CAPACITY) {
            jaxe.cbQueue.shift(); // drop oldest
            jaxe.cbOverflow = true;
        }

        // Per-handle state ends with the instance (DESTROYED is always in
        // the installed mask).
        if (type == 0x02 /* DESTROYED */) {
            delete jaxe.cbMasks[handle];
            delete jaxe.psKeys[handle];
        }
        return jaxe.FMOD.OK;
    }

    static fmod_cb_next() {
        if (jaxe.cbQueue.length == 0) return false;
        jaxe.cbCurrent = jaxe.cbQueue.shift();
        return true;
    }

    static fmod_cb_handle() {
        return jaxe.cbCurrent.handle;
    }

    static fmod_cb_type() {
        return jaxe.cbCurrent.type;
    }

    static fmod_cb_int(index) {
        return index == 0 ? jaxe.cbCurrent.i1 : (index == 1 ? jaxe.cbCurrent.i2 : jaxe.cbCurrent.i3);
    }

    static fmod_cb_float() {
        return jaxe.cbCurrent.f1;
    }

    static fmod_cb_string() {
        return jaxe.cbCurrent.str;
    }

    static fmod_cb_take_overflow() {
        var overflowed = jaxe.cbOverflow;
        jaxe.cbOverflow = false;
        return overflowed;
    }

    //// Studio System (2.0 bindings)

    static lastResult = 0;
    static ERR_INVALID_HANDLE = 30;
    static ERR_INVALID_PARAM = 31;
    static ERR_UNSUPPORTED = 68;
    static ERR_INVALID_GUID = 31;   // malformed GUID string -> FMOD_ERR_INVALID_PARAM (shared shim convention)
    static ERR_NOTREADY = 82;
    static ERR_STUDIO_UNINITIALIZED = 75;

    static sysReady() {
        if (jaxe.FmodIsInitialized) return true;
        jaxe.lastResult = jaxe.ERR_STUDIO_UNINITIALIZED;
        return false;
    }

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

    // Parse "{8-4-4-4-12}" (braces optional) into the {Data1..Data4} object
    // shape the FMOD JS by-ID lookups require - they reject GUID strings
    // with FMOD_ERR_INVALID_PARAM. Returns null on malformed input.
    static parseGuid(text) {
        if (typeof text !== "string") return null;
        var t = text.trim();
        if (t.charAt(0) == "{" && t.charAt(t.length - 1) == "}") {
            t = t.substring(1, t.length - 1);
        }
        var m = t.match(/^([0-9a-fA-F]{8})-([0-9a-fA-F]{4})-([0-9a-fA-F]{4})-([0-9a-fA-F]{4})-([0-9a-fA-F]{12})$/);
        if (!m) return null;
        var tail = m[4] + m[5];
        var d4 = [];
        for (var i = 0; i < 8; i++) {
            d4.push(parseInt(tail.substr(i * 2, 2), 16));
        }
        return { Data1: parseInt(m[1], 16), Data2: parseInt(m[2], 16), Data3: parseInt(m[3], 16), Data4: d4 };
    }

    // lookupID and getStringInfo write GUID fields directly into a
    // pre-shaped out object (Data4 must already be an 8-slot array)
    static guidOut() {
        return { Data1: 0, Data2: 0, Data3: 0, Data4: [0, 0, 0, 0, 0, 0, 0, 0] };
    }

    // Parameter IDs cross the boundary as two i32; FMOD JS wants an object
    // with lowercase data1/data2 holding the unsigned 32-bit values
    static paramId(d1, d2) {
        return { data1: d1 >>> 0, data2: d2 >>> 0 };
    }

    // Shared writer for parameter descriptions. FMOD JS writes the struct
    // fields directly onto the out object (not out.val).
    // Layout: fbuf [0]=min [1]=max [2]=default; ibuf [0]=type [1]=flags
    // [2]=id1 [3]=id2. Returns the parameter name.
    static writeParamDesc(pd, fbuf, ibuf) {
        fbuf[0] = pd.minimum || 0.0;
        fbuf[1] = pd.maximum || 0.0;
        fbuf[2] = pd.defaultvalue || 0.0;
        ibuf[0] = pd.type | 0;
        ibuf[1] = pd.flags | 0;
        ibuf[2] = pd.id ? pd.id.data1 | 0 : 0;
        ibuf[3] = pd.id ? pd.id.data2 | 0 : 0;
        return pd.name || "";
    }

    // FMOD JS writes 3D attribute getters as flat dotted keys directly on
    // the out object ("position.x" ... "up.z"); flatten into fbuf[0..11]
    // in pos/vel/forward/up order
    static readAttributes3D(attr, fbuf) {
        var parts = ["position", "velocity", "forward", "up"];
        var axes = ["x", "y", "z"];
        for (var i = 0; i < 4; i++) {
            for (var k = 0; k < 3; k++) {
                fbuf[i * 3 + k] = attr[parts[i] + "." + axes[k]] || 0.0;
            }
        }
    }

    // The setters take the nested object form
    static buildAttributes3D(px, py, pz, vx, vy, vz, fx, fy, fz, ux, uy, uz) {
        return {
            position: { x: px, y: py, z: pz },
            velocity: { x: vx, y: vy, z: vz },
            forward: { x: fx, y: fy, z: fz },
            up: { x: ux, y: uy, z: uz }
        };
    }

    // List getters fill ibuf with handles (capped at 64) and return the
    // count written; entries the table has seen keep their existing handle
    static writeHandleList(items, count, ibuf, type) {
        var n = count | 0;
        if (n > 64) n = 64;
        if (items.length < n) n = items.length;
        for (var i = 0; i < n; i++) {
            ibuf[i] = jaxe.handleFindOrAlloc(items[i], type);
        }
        return n;
    }

    static fmod_sys_last_result() {
        return jaxe.lastResult;
    }

    // Settings-driven init: stores the settings for onRuntimeInitialized and
    // kicks off module init exactly like fmod_init. Module startup is
    // asynchronous - poll fmod_is_initialized for completion. Returns 0 (OK).
    static fmod_sys_init_ex(numChannels, sampleRate, speakerMode, studioFlags) {
        jaxe.pendingInit = {
            numChannels: numChannels,
            sampleRate: sampleRate,
            speakerMode: speakerMode,
            studioFlags: studioFlags
        };
        jaxe.FMOD['preRun'] = jaxe.preRun;
        jaxe.FMOD['onRuntimeInitialized'] = jaxe.onRuntimeInitialized;
        jaxe.FMOD['TOTAL_MEMORY'] = 64 * 1024 * 1024;
        FMODModule(jaxe.FMOD);
        return 0; // FMOD_OK
    }

    // FMOD_Debug_Initialize level mapping (0=none 1=error 2=warning 3=log),
    // TTY mode, no file logging. Logging is baked into the wasm build, so
    // the binding is usually absent - report 68 (ERR_UNSUPPORTED). The
    // try/catch guards against arity differences across FMOD JS builds.
    static fmod_sys_set_debug_level(level) {
        if (!jaxe.FMOD.Debug_Initialize) { jaxe.lastResult = jaxe.ERR_UNSUPPORTED; return jaxe.lastResult; }
        var flags = 0;
        if (level == 1) flags = 1;      // FMOD_DEBUG_LEVEL_ERROR
        else if (level == 2) flags = 2; // FMOD_DEBUG_LEVEL_WARNING
        else if (level >= 3) flags = 4; // FMOD_DEBUG_LEVEL_LOG
        try {
            jaxe.lastResult = jaxe.FMOD.Debug_Initialize(flags, jaxe.FMOD.DEBUG_MODE_TTY, null, null);
        } catch (e) {
            jaxe.lastResult = jaxe.ERR_UNSUPPORTED;
        }
        return jaxe.lastResult;
    }

    static fmod_sys_get_bus(path) {
        if (!jaxe.sysReady()) return 0;
        var bus = {};
        jaxe.lastResult = jaxe.gSystem.getBus(path, bus);
        if (jaxe.lastResult != jaxe.FMOD.OK || !bus.val) return 0;
        return jaxe.handleFindOrAlloc(bus.val, jaxe.TYPE_BUS);
    }

    static fmod_sys_get_bus_by_id(guid) {
        if (!jaxe.sysReady()) return 0;
        var id = jaxe.parseGuid(guid);
        if (!id) { jaxe.lastResult = jaxe.ERR_INVALID_GUID; return 0; }
        var bus = {};
        jaxe.lastResult = jaxe.gSystem.getBusByID(id, bus);
        if (jaxe.lastResult != jaxe.FMOD.OK || !bus.val) return 0;
        return jaxe.handleFindOrAlloc(bus.val, jaxe.TYPE_BUS);
    }

    static fmod_sys_get_event(path) {
        if (!jaxe.sysReady()) return 0;
        var desc = {};
        jaxe.lastResult = jaxe.gSystem.getEvent(path, desc);
        if (jaxe.lastResult != jaxe.FMOD.OK || !desc.val) return 0;
        return jaxe.handleFindOrAlloc(desc.val, jaxe.TYPE_EVD);
    }

    static fmod_sys_get_event_by_id(guid) {
        if (!jaxe.sysReady()) return 0;
        var id = jaxe.parseGuid(guid);
        if (!id) { jaxe.lastResult = jaxe.ERR_INVALID_GUID; return 0; }
        var desc = {};
        jaxe.lastResult = jaxe.gSystem.getEventByID(id, desc);
        if (jaxe.lastResult != jaxe.FMOD.OK || !desc.val) return 0;
        return jaxe.handleFindOrAlloc(desc.val, jaxe.TYPE_EVD);
    }

    static fmod_sys_get_vca(path) {
        if (!jaxe.sysReady()) return 0;
        var vca = {};
        jaxe.lastResult = jaxe.gSystem.getVCA(path, vca);
        if (jaxe.lastResult != jaxe.FMOD.OK || !vca.val) return 0;
        return jaxe.handleFindOrAlloc(vca.val, jaxe.TYPE_VCA);
    }

    static fmod_sys_get_vca_by_id(guid) {
        if (!jaxe.sysReady()) return 0;
        var id = jaxe.parseGuid(guid);
        if (!id) { jaxe.lastResult = jaxe.ERR_INVALID_GUID; return 0; }
        var vca = {};
        jaxe.lastResult = jaxe.gSystem.getVCAByID(id, vca);
        if (jaxe.lastResult != jaxe.FMOD.OK || !vca.val) return 0;
        return jaxe.handleFindOrAlloc(vca.val, jaxe.TYPE_VCA);
    }

    static fmod_sys_get_bank(path) {
        if (!jaxe.sysReady()) return 0;
        var bank = {};
        jaxe.lastResult = jaxe.gSystem.getBank(path, bank);
        if (jaxe.lastResult != jaxe.FMOD.OK || !bank.val) return 0;
        return jaxe.handleFindOrAlloc(bank.val, jaxe.TYPE_BANK);
    }

    static fmod_sys_get_bank_by_id(guid) {
        if (!jaxe.sysReady()) return 0;
        var id = jaxe.parseGuid(guid);
        if (!id) { jaxe.lastResult = jaxe.ERR_INVALID_GUID; return 0; }
        var bank = {};
        jaxe.lastResult = jaxe.gSystem.getBankByID(id, bank);
        if (jaxe.lastResult != jaxe.FMOD.OK || !bank.val) return 0;
        return jaxe.handleFindOrAlloc(bank.val, jaxe.TYPE_BANK);
    }

    static fmod_sys_get_bank_count() {
        if (!jaxe.sysReady()) return 0;
        var outval = {};
        jaxe.lastResult = jaxe.gSystem.getBankCount(outval);
        return jaxe.lastResult == jaxe.FMOD.OK ? outval.val | 0 : 0;
    }

    // fills ibuf with bank handles, returns count
    static fmod_sys_get_bank_list(ibuf) {
        if (!jaxe.sysReady()) return 0;
        var list = {};
        var count = {};
        jaxe.lastResult = jaxe.gSystem.getBankList(list, 64, count);
        if (jaxe.lastResult != jaxe.FMOD.OK || !list.val) return 0;
        return jaxe.writeHandleList(list.val, count.val, ibuf, jaxe.TYPE_BANK);
    }

    static fmod_sys_lookup_id(path) {
        if (!jaxe.sysReady()) return "";
        // lookupID writes the GUID fields directly into a pre-shaped out
        var id = jaxe.guidOut();
        jaxe.lastResult = jaxe.gSystem.lookupID(path, id);
        if (jaxe.lastResult != jaxe.FMOD.OK) return "";
        return jaxe.formatGuid(id);
    }

    static fmod_sys_lookup_path(guid) {
        if (!jaxe.sysReady()) return "";
        var id = jaxe.parseGuid(guid);
        if (!id) { jaxe.lastResult = jaxe.ERR_INVALID_GUID; return ""; }
        var outval = {};
        jaxe.lastResult = jaxe.gSystem.lookupPath(id, outval, 512, null);
        if (jaxe.lastResult != jaxe.FMOD.OK) return "";
        return outval.val;
    }

    static fmod_sys_get_param_by_name(name) {
        if (!jaxe.sysReady()) return 0.0;
        var value = {};
        jaxe.lastResult = jaxe.gSystem.getParameterByName(name, value, null);
        return jaxe.lastResult == jaxe.FMOD.OK ? value.val : 0.0;
    }

    static fmod_sys_get_param_by_name_final(name) {
        if (!jaxe.sysReady()) return 0.0;
        var value = {};
        var finalValue = {};
        jaxe.lastResult = jaxe.gSystem.getParameterByName(name, value, finalValue);
        return jaxe.lastResult == jaxe.FMOD.OK ? finalValue.val : 0.0;
    }

    static fmod_sys_set_param_by_name(name, value, ignoreSeekSpeed) {
        if (!jaxe.sysReady()) return jaxe.lastResult;
        jaxe.lastResult = jaxe.gSystem.setParameterByName(name, value, ignoreSeekSpeed);
        return jaxe.lastResult;
    }

    static fmod_sys_set_param_by_name_with_label(name, label, ignoreSeekSpeed) {
        if (!jaxe.sysReady()) return jaxe.lastResult;
        jaxe.lastResult = jaxe.gSystem.setParameterByNameWithLabel(name, label, ignoreSeekSpeed);
        return jaxe.lastResult;
    }

    static fmod_sys_get_param_by_id(id1, id2) {
        if (!jaxe.sysReady()) return 0.0;
        var value = {};
        jaxe.lastResult = jaxe.gSystem.getParameterByID(jaxe.paramId(id1, id2), value, null);
        return jaxe.lastResult == jaxe.FMOD.OK ? value.val : 0.0;
    }

    static fmod_sys_get_param_by_id_final(id1, id2) {
        if (!jaxe.sysReady()) return 0.0;
        var value = {};
        var finalValue = {};
        jaxe.lastResult = jaxe.gSystem.getParameterByID(jaxe.paramId(id1, id2), value, finalValue);
        return jaxe.lastResult == jaxe.FMOD.OK ? finalValue.val : 0.0;
    }

    static fmod_sys_set_param_by_id(id1, id2, value, ignoreSeekSpeed) {
        if (!jaxe.sysReady()) return jaxe.lastResult;
        jaxe.lastResult = jaxe.gSystem.setParameterByID(jaxe.paramId(id1, id2), value, ignoreSeekSpeed);
        return jaxe.lastResult;
    }

    static fmod_sys_set_param_by_id_with_label(id1, id2, label, ignoreSeekSpeed) {
        if (!jaxe.sysReady()) return jaxe.lastResult;
        jaxe.lastResult = jaxe.gSystem.setParameterByIDWithLabel(jaxe.paramId(id1, id2), label, ignoreSeekSpeed);
        return jaxe.lastResult;
    }

    static fmod_sys_get_parameter_description_count() {
        if (!jaxe.sysReady()) return 0;
        var outval = {};
        jaxe.lastResult = jaxe.gSystem.getParameterDescriptionCount(outval);
        return jaxe.lastResult == jaxe.FMOD.OK ? outval.val | 0 : 0;
    }

    // returns param name; fbuf/ibuf layout documented on writeParamDesc.
    // The JS System API has no getParameterDescriptionByIndex, only
    // getParameterDescriptionList - index into the fetched list instead.
    static fmod_sys_get_parameter_description_by_index(index, fbuf, ibuf) {
        if (!jaxe.sysReady()) return "";
        var list = {};
        var count = {};
        jaxe.lastResult = jaxe.gSystem.getParameterDescriptionList(list, 64, count);
        if (jaxe.lastResult != jaxe.FMOD.OK) return "";
        if (index < 0 || index >= (count.val | 0) || !list.val || !list.val[index]) {
            jaxe.lastResult = jaxe.ERR_INVALID_PARAM;
            return "";
        }
        return jaxe.writeParamDesc(list.val[index], fbuf, ibuf);
    }

    static fmod_sys_get_parameter_description_by_name(name, fbuf, ibuf) {
        if (!jaxe.sysReady()) return "";
        var outval = {};
        jaxe.lastResult = jaxe.gSystem.getParameterDescriptionByName(name, outval);
        if (jaxe.lastResult != jaxe.FMOD.OK) return "";
        return jaxe.writeParamDesc(outval, fbuf, ibuf);
    }

    // global parameter labels (paramName, labelIndex)
    static fmod_sys_get_parameter_label(name, labelIndex) {
        if (!jaxe.sysReady()) return "";
        var outval = {};
        // (name, labelindex, label, size, retrieved)
        jaxe.lastResult = jaxe.gSystem.getParameterLabelByName(name, labelIndex, outval, 512, null);
        if (jaxe.lastResult != jaxe.FMOD.OK) return "";
        return outval.val;
    }

    static fmod_sys_get_num_listeners() {
        if (!jaxe.sysReady()) return 0;
        var outval = {};
        jaxe.lastResult = jaxe.gSystem.getNumListeners(outval);
        return jaxe.lastResult == jaxe.FMOD.OK ? outval.val | 0 : 0;
    }

    static fmod_sys_set_num_listeners(count) {
        if (!jaxe.sysReady()) return jaxe.lastResult;
        jaxe.lastResult = jaxe.gSystem.setNumListeners(count);
        return jaxe.lastResult;
    }

    // fbuf[0..11] = 3D attributes (pos/vel/forward/up)
    static fmod_sys_get_listener_attributes(index, fbuf) {
        if (!jaxe.sysReady()) return jaxe.lastResult;
        var attr = {};
        // (index, attributes, attenuationposition) - attenuation not exposed
        jaxe.lastResult = jaxe.gSystem.getListenerAttributes(index, attr, null);
        if (jaxe.lastResult == jaxe.FMOD.OK) jaxe.readAttributes3D(attr, fbuf);
        return jaxe.lastResult;
    }

    static fmod_sys_set_listener_attributes(index, f) {
        if (!jaxe.FmodIsInitialized) { jaxe.lastResult = jaxe.ERR_STUDIO_UNINITIALIZED; return jaxe.lastResult; }
        jaxe.lastResult = jaxe.gSystem.setListenerAttributes(index,
            jaxe.buildAttributes3D(f[0], f[1], f[2], f[3], f[4], f[5], f[6], f[7], f[8], f[9], f[10], f[11]), null);
        return jaxe.lastResult;
    }

    static fmod_sys_get_listener_weight(index) {
        if (!jaxe.sysReady()) return 0.0;
        var outval = {};
        jaxe.lastResult = jaxe.gSystem.getListenerWeight(index, outval);
        return jaxe.lastResult == jaxe.FMOD.OK ? outval.val : 0.0;
    }

    static fmod_sys_set_listener_weight(index, weight) {
        if (!jaxe.sysReady()) return jaxe.lastResult;
        jaxe.lastResult = jaxe.gSystem.setListenerWeight(index, weight);
        return jaxe.lastResult;
    }

    // bank loading (flags: bit0 = nonblocking); returns bank handle or 0.
    // Banks are preloaded into MEMFS at "/<name>" by preRun, so bare
    // filenames are resolved from the filesystem root like fmod_load_bank.
    static fmod_sys_load_bank_file(path, flags) {
        if (!jaxe.sysReady()) return 0;
        var fsPath = (path.charAt(0) == "/") ? path : "/" + path;
        var loadFlags = (flags & 1)
            ? jaxe.FMOD.STUDIO_LOAD_BANK_NONBLOCKING
            : jaxe.FMOD.STUDIO_LOAD_BANK_NORMAL;
        var bank = {};
        jaxe.lastResult = jaxe.gSystem.loadBankFile(fsPath, loadFlags, bank);
        if (jaxe.lastResult != jaxe.FMOD.OK || !bank.val) return 0;
        return jaxe.handleFindOrAlloc(bank.val, jaxe.TYPE_BANK);
    }

    // Async bank load over HTTP (the file is NOT in MEMFS): allocates a
    // handle backed by a {pendingBankPath} placeholder immediately, fetches
    // `path` relative to the page origin, writes the bytes into MEMFS under
    // a unique flat name, then swaps the real bank into the slot. Poll
    // bank_get_loading_state: 2 (LOADING) while the fetch is pending,
    // 4 (ERROR) if the fetch or load failed.
    static fmod_sys_load_bank_async(path) {
        if (!jaxe.sysReady()) return 0;
        var placeholder = { pendingBankPath: path };
        var handle = jaxe.handleAlloc(placeholder, jaxe.TYPE_BANK);
        if (handle == 0) return 0;
        jaxe.lastResult = jaxe.FMOD.OK;
        var idx = handle & 0xFFFF;
        var memfsName = "async_" + (++jaxe.asyncBankCounter) + ".bank";
        try {
            fetch(path).then(function (response) {
                if (!response.ok) throw new Error("HTTP " + response.status);
                return response.arrayBuffer();
            }).then(function (buffer) {
                var s = jaxe.slots[idx];
                // handle freed (or recycled) while the fetch was in flight
                if (!s || !s.alive || s.ptr !== placeholder) return;
                jaxe.FMOD.FS_createDataFile('/', memfsName, new Uint8Array(buffer), true, false, false);
                var bank = {};
                var result = jaxe.gSystem.loadBankFile("/" + memfsName, jaxe.FMOD.STUDIO_LOAD_BANK_NORMAL, bank);
                if (result != jaxe.FMOD.OK || !bank.val) {
                    placeholder.pendingBankError = true;
                    return;
                }
                // Swap the real bank into the slot; the handle stays valid.
                s.ptr = bank.val;
                s.raw = jaxe.rawPtr(bank.val);
            }).catch(function () {
                placeholder.pendingBankError = true;
            });
        } catch (e) {
            placeholder.pendingBankError = true;
        }
        return handle;
    }

    static fmod_sys_unload_all() {
        if (!jaxe.FmodIsInitialized) { jaxe.lastResult = jaxe.ERR_STUDIO_UNINITIALIZED; return jaxe.lastResult; }
        // All bank content is going away; uninstall every callback first or
        // the FMOD JS module is corrupted.
        jaxe.uninstallCallbacksFor(null);
        jaxe.lastResult = jaxe.gSystem.unloadAll();
        return jaxe.lastResult;
    }

    static fmod_sys_flush_commands() {
        if (!jaxe.sysReady()) return jaxe.lastResult;
        jaxe.lastResult = jaxe.gSystem.flushCommands();
        return jaxe.lastResult;
    }

    static fmod_sys_flush_sample_loading() {
        if (!jaxe.sysReady()) return jaxe.lastResult;
        jaxe.lastResult = jaxe.gSystem.flushSampleLoading();
        return jaxe.lastResult;
    }

    // fbuf: [0]=studio update us, [1..6]=core dsp/stream/geometry/update/conv1/conv2.
    // FMOD JS writes the usage fields directly onto the out objects.
    static fmod_sys_get_cpu_usage(fbuf) {
        if (!jaxe.sysReady()) return jaxe.lastResult;
        var studio = {};
        var core = {};
        jaxe.lastResult = jaxe.gSystem.getCPUUsage(studio, core);
        if (jaxe.lastResult == jaxe.FMOD.OK) {
            fbuf[0] = studio.update || 0.0;
            fbuf[1] = core.dsp || 0.0;
            fbuf[2] = core.stream || 0.0;
            fbuf[3] = core.geometry || 0.0;
            fbuf[4] = core.update || 0.0;
            fbuf[5] = core.convolution1 || 0.0;
            fbuf[6] = core.convolution2 || 0.0;
        }
        return jaxe.lastResult;
    }

    // ibuf: [0..3]=cmdqueue cur/peak/cap/stall [4..7]=handle cur/peak/cap/stall;
    // fbuf: [0]=cmd stalltime [1]=handle stalltime.
    // FMOD JS writes the struct as flat dotted keys directly on the out object.
    static fmod_sys_get_buffer_usage(ibuf, fbuf) {
        if (!jaxe.sysReady()) return jaxe.lastResult;
        var usage = {};
        jaxe.lastResult = jaxe.gSystem.getBufferUsage(usage);
        if (jaxe.lastResult == jaxe.FMOD.OK) {
            ibuf[0] = usage["studiocommandqueue.currentusage"] | 0;
            ibuf[1] = usage["studiocommandqueue.peakusage"] | 0;
            ibuf[2] = usage["studiocommandqueue.capacity"] | 0;
            ibuf[3] = usage["studiocommandqueue.stallcount"] | 0;
            ibuf[4] = usage["studiohandle.currentusage"] | 0;
            ibuf[5] = usage["studiohandle.peakusage"] | 0;
            ibuf[6] = usage["studiohandle.capacity"] | 0;
            ibuf[7] = usage["studiohandle.stallcount"] | 0;
            fbuf[0] = usage["studiocommandqueue.stalltime"] || 0.0;
            fbuf[1] = usage["studiohandle.stalltime"] || 0.0;
        }
        return jaxe.lastResult;
    }

    static fmod_sys_reset_buffer_usage() {
        if (!jaxe.sysReady()) return jaxe.lastResult;
        jaxe.lastResult = jaxe.gSystem.resetBufferUsage();
        return jaxe.lastResult;
    }

    // ibuf: [0]=exclusive [1]=inclusive [2]=sampledata; not exposed by the
    // FMOD JS API, so this reports ERR_UNSUPPORTED
    static fmod_sys_get_memory_usage(ibuf) {
        if (!jaxe.sysReady()) return jaxe.lastResult;
        if (!jaxe.gSystem.getMemoryUsage) { jaxe.lastResult = jaxe.ERR_UNSUPPORTED; return jaxe.lastResult; }
        var outval = {};
        jaxe.lastResult = jaxe.gSystem.getMemoryUsage(outval);
        if (jaxe.lastResult == jaxe.FMOD.OK && outval.val) {
            ibuf[0] = outval.val.exclusive | 0;
            ibuf[1] = outval.val.inclusive | 0;
            ibuf[2] = outval.val.sampledata | 0;
        }
        return jaxe.lastResult;
    }

    //// Bus (2.0 bindings)

    static fmod_bus_is_valid(handle) {
        var bus = jaxe.handleResolve(handle, jaxe.TYPE_BUS);
        // isValid returns 1/0 from the wasm side, coerce to a real bool
        return bus != null && (!bus.isValid || !!bus.isValid());
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
        // FMOD JS bindings validate argument counts: unwanted out-params must
        // be passed as an explicit null, never omitted
        jaxe.lastResult = bus.getVolume(outval, null);
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

    //// VCA (2.0 bindings)

    static fmod_vca_is_valid(handle) {
        var vca = jaxe.handleResolve(handle, jaxe.TYPE_VCA);
        return vca != null && (!vca.isValid || !!vca.isValid());
    }

    static fmod_vca_get_id(handle) {
        var vca = jaxe.handleResolve(handle, jaxe.TYPE_VCA);
        if (!vca) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return ""; }
        if (!vca.getID) { jaxe.lastResult = jaxe.ERR_UNSUPPORTED; return ""; }
        var outval = {};
        jaxe.lastResult = vca.getID(outval);
        if (jaxe.lastResult != jaxe.FMOD.OK) return "";
        return jaxe.formatGuid(outval.val);
    }

    static fmod_vca_get_path(handle) {
        var vca = jaxe.handleResolve(handle, jaxe.TYPE_VCA);
        if (!vca) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return ""; }
        var outval = {};
        jaxe.lastResult = vca.getPath(outval, 512, null);
        if (jaxe.lastResult != jaxe.FMOD.OK) return "";
        return outval.val;
    }

    static fmod_vca_get_volume(handle) {
        var vca = jaxe.handleResolve(handle, jaxe.TYPE_VCA);
        if (!vca) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0.0; }
        var outval = {};
        jaxe.lastResult = vca.getVolume(outval, null);
        return outval.val || 0.0;
    }

    static fmod_vca_get_final_volume(handle) {
        var vca = jaxe.handleResolve(handle, jaxe.TYPE_VCA);
        if (!vca) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0.0; }
        var volume = {};
        var finalVolume = {};
        jaxe.lastResult = vca.getVolume(volume, finalVolume);
        return finalVolume.val || 0.0;
    }

    static fmod_vca_set_volume(handle, volume) {
        var vca = jaxe.handleResolve(handle, jaxe.TYPE_VCA);
        if (!vca) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = vca.setVolume(volume);
        return jaxe.lastResult;
    }

    //// Bank (2.0 bindings)

    // Resolves a bank handle for the fmod_bank_* functions, treating async
    // placeholders from fmod_sys_load_bank_async as not ready: sets
    // lastResult = 82 (ERR_NOTREADY) and returns null so callers never touch
    // a placeholder. bank_get_loading_state and bank_is_valid special-case
    // placeholders instead of using this helper.
    static resolveBankReady(handle) {
        var bank = jaxe.handleResolve(handle, jaxe.TYPE_BANK);
        if (!bank) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return null; }
        if (bank.pendingBankPath) { jaxe.lastResult = jaxe.ERR_NOTREADY; return null; }
        return bank;
    }

    static fmod_bank_is_valid(handle) {
        var bank = jaxe.handleResolve(handle, jaxe.TYPE_BANK);
        // async placeholders are not valid banks until the fetch lands
        if (bank && bank.pendingBankPath) return false;
        return bank != null && (!bank.isValid || !!bank.isValid());
    }

    static fmod_bank_get_id(handle) {
        var bank = jaxe.resolveBankReady(handle);
        if (!bank) return "";
        if (!bank.getID) { jaxe.lastResult = jaxe.ERR_UNSUPPORTED; return ""; }
        var outval = {};
        jaxe.lastResult = bank.getID(outval);
        if (jaxe.lastResult != jaxe.FMOD.OK) return "";
        return jaxe.formatGuid(outval.val);
    }

    static fmod_bank_get_path(handle) {
        var bank = jaxe.resolveBankReady(handle);
        if (!bank) return "";
        var outval = {};
        jaxe.lastResult = bank.getPath(outval, 512, null);
        if (jaxe.lastResult != jaxe.FMOD.OK) return "";
        return outval.val;
    }

    // real unload; frees the bank handle on success
    static fmod_bank_unload(handle) {
        var bank = jaxe.resolveBankReady(handle);
        if (!bank) return jaxe.lastResult;
        // Unloading destroys the bank's event instances; uninstall their
        // callbacks first or the FMOD JS module is corrupted.
        var cnt = {};
        if (bank.getEventCount(cnt) == jaxe.FMOD.OK && cnt.val > 0) {
            var list = {};
            var listed = {};
            if (bank.getEventList(list, cnt.val, listed) == jaxe.FMOD.OK && list.val) {
                var ptrs = new Set();
                for (var i = 0; i < list.val.length; i++) ptrs.add(jaxe.rawPtr(list.val[i]));
                jaxe.uninstallCallbacksFor(ptrs);
            }
        }
        jaxe.lastResult = bank.unload();
        if (jaxe.lastResult == jaxe.FMOD.OK) jaxe.handleFree(handle);
        return jaxe.lastResult;
    }

    static fmod_bank_load_sample_data(handle) {
        var bank = jaxe.resolveBankReady(handle);
        if (!bank) return jaxe.lastResult;
        jaxe.lastResult = bank.loadSampleData();
        return jaxe.lastResult;
    }

    static fmod_bank_unload_sample_data(handle) {
        var bank = jaxe.resolveBankReady(handle);
        if (!bank) return jaxe.lastResult;
        jaxe.lastResult = bank.unloadSampleData();
        return jaxe.lastResult;
    }

    // FMOD_STUDIO_LOADING_STATE; invalid handle reports 1 (UNLOADED); async
    // placeholders report 2 (LOADING) while the fetch is pending and
    // 4 (ERROR) when it failed
    static fmod_bank_get_loading_state(handle) {
        var bank = jaxe.handleResolve(handle, jaxe.TYPE_BANK);
        if (!bank) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 1; }
        if (bank.pendingBankPath) {
            jaxe.lastResult = jaxe.FMOD.OK;
            return bank.pendingBankError ? 4 : 2;
        }
        var outval = {};
        jaxe.lastResult = bank.getLoadingState(outval);
        return jaxe.lastResult == jaxe.FMOD.OK ? outval.val | 0 : 1;
    }

    static fmod_bank_get_sample_loading_state(handle) {
        var bank = jaxe.resolveBankReady(handle);
        if (!bank) return 1;
        var outval = {};
        jaxe.lastResult = bank.getSampleLoadingState(outval);
        return jaxe.lastResult == jaxe.FMOD.OK ? outval.val | 0 : 1;
    }

    static fmod_bank_get_event_count(handle) {
        var bank = jaxe.resolveBankReady(handle);
        if (!bank) return 0;
        var outval = {};
        jaxe.lastResult = bank.getEventCount(outval);
        return jaxe.lastResult == jaxe.FMOD.OK ? outval.val | 0 : 0;
    }

    // fills ibuf with event description handles, returns count
    static fmod_bank_get_event_list(handle, ibuf) {
        var bank = jaxe.resolveBankReady(handle);
        if (!bank) return 0;
        var list = {};
        var count = {};
        jaxe.lastResult = bank.getEventList(list, 64, count);
        if (jaxe.lastResult != jaxe.FMOD.OK || !list.val) return 0;
        return jaxe.writeHandleList(list.val, count.val, ibuf, jaxe.TYPE_EVD);
    }

    static fmod_bank_get_bus_count(handle) {
        var bank = jaxe.resolveBankReady(handle);
        if (!bank) return 0;
        var outval = {};
        jaxe.lastResult = bank.getBusCount(outval);
        return jaxe.lastResult == jaxe.FMOD.OK ? outval.val | 0 : 0;
    }

    static fmod_bank_get_bus_list(handle, ibuf) {
        var bank = jaxe.resolveBankReady(handle);
        if (!bank) return 0;
        var list = {};
        var count = {};
        jaxe.lastResult = bank.getBusList(list, 64, count);
        if (jaxe.lastResult != jaxe.FMOD.OK || !list.val) return 0;
        return jaxe.writeHandleList(list.val, count.val, ibuf, jaxe.TYPE_BUS);
    }

    static fmod_bank_get_vca_count(handle) {
        var bank = jaxe.resolveBankReady(handle);
        if (!bank) return 0;
        var outval = {};
        jaxe.lastResult = bank.getVCACount(outval);
        return jaxe.lastResult == jaxe.FMOD.OK ? outval.val | 0 : 0;
    }

    static fmod_bank_get_vca_list(handle, ibuf) {
        var bank = jaxe.resolveBankReady(handle);
        if (!bank) return 0;
        var list = {};
        var count = {};
        jaxe.lastResult = bank.getVCAList(list, 64, count);
        if (jaxe.lastResult != jaxe.FMOD.OK || !list.val) return 0;
        return jaxe.writeHandleList(list.val, count.val, ibuf, jaxe.TYPE_VCA);
    }

    static fmod_bank_get_string_count(handle) {
        var bank = jaxe.resolveBankReady(handle);
        if (!bank) return 0;
        var outval = {};
        jaxe.lastResult = bank.getStringCount(outval);
        return jaxe.lastResult == jaxe.FMOD.OK ? outval.val | 0 : 0;
    }

    // string table path by index
    static fmod_bank_get_string_info(handle, index) {
        var bank = jaxe.resolveBankReady(handle);
        if (!bank) return "";
        var pathOut = {};
        // (index, id, path, size, retrieved) - unwanted id out passed as null
        jaxe.lastResult = bank.getStringInfo(index, null, pathOut, 512, null);
        if (jaxe.lastResult != jaxe.FMOD.OK) return "";
        return pathOut.val;
    }

    // string table GUID by index (formatted string)
    static fmod_bank_get_string_guid(handle, index) {
        var bank = jaxe.resolveBankReady(handle);
        if (!bank) return "";
        var id = jaxe.guidOut();
        var pathOut = {};
        jaxe.lastResult = bank.getStringInfo(index, id, pathOut, 512, null);
        if (jaxe.lastResult != jaxe.FMOD.OK) return "";
        return jaxe.formatGuid(id);
    }

    //// EventDescription (2.0 bindings)

    static fmod_evd_is_valid(handle) {
        var evd = jaxe.handleResolve(handle, jaxe.TYPE_EVD);
        return evd != null && (!evd.isValid || !!evd.isValid());
    }

    static fmod_evd_get_id(handle) {
        var evd = jaxe.handleResolve(handle, jaxe.TYPE_EVD);
        if (!evd) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return ""; }
        if (!evd.getID) { jaxe.lastResult = jaxe.ERR_UNSUPPORTED; return ""; }
        var outval = {};
        jaxe.lastResult = evd.getID(outval);
        if (jaxe.lastResult != jaxe.FMOD.OK) return "";
        return jaxe.formatGuid(outval.val);
    }

    static fmod_evd_get_path(handle) {
        var evd = jaxe.handleResolve(handle, jaxe.TYPE_EVD);
        if (!evd) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return ""; }
        var outval = {};
        jaxe.lastResult = evd.getPath(outval, 512, null);
        if (jaxe.lastResult != jaxe.FMOD.OK) return "";
        return outval.val;
    }

    static fmod_evd_get_length(handle) {
        var evd = jaxe.handleResolve(handle, jaxe.TYPE_EVD);
        if (!evd) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var outval = {};
        jaxe.lastResult = evd.getLength(outval);
        return jaxe.lastResult == jaxe.FMOD.OK ? outval.val | 0 : 0;
    }

    // fbuf: [0]=min [1]=max
    static fmod_evd_get_min_max_distance(handle, fbuf) {
        var evd = jaxe.handleResolve(handle, jaxe.TYPE_EVD);
        if (!evd) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        var min = {};
        var max = {};
        jaxe.lastResult = evd.getMinMaxDistance(min, max);
        if (jaxe.lastResult == jaxe.FMOD.OK) {
            fbuf[0] = min.val || 0.0;
            fbuf[1] = max.val || 0.0;
        }
        return jaxe.lastResult;
    }

    static fmod_evd_get_sound_size(handle) {
        var evd = jaxe.handleResolve(handle, jaxe.TYPE_EVD);
        if (!evd) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0.0; }
        var outval = {};
        jaxe.lastResult = evd.getSoundSize(outval);
        return jaxe.lastResult == jaxe.FMOD.OK ? outval.val || 0.0 : 0.0;
    }

    static fmod_evd_is_snapshot(handle) {
        var evd = jaxe.handleResolve(handle, jaxe.TYPE_EVD);
        if (!evd) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return false; }
        var outval = {};
        jaxe.lastResult = evd.isSnapshot(outval);
        return !!outval.val;
    }

    static fmod_evd_is_oneshot(handle) {
        var evd = jaxe.handleResolve(handle, jaxe.TYPE_EVD);
        if (!evd) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return false; }
        var outval = {};
        jaxe.lastResult = evd.isOneshot(outval);
        return !!outval.val;
    }

    static fmod_evd_is_stream(handle) {
        var evd = jaxe.handleResolve(handle, jaxe.TYPE_EVD);
        if (!evd) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return false; }
        var outval = {};
        jaxe.lastResult = evd.isStream(outval);
        return !!outval.val;
    }

    static fmod_evd_is_3d(handle) {
        var evd = jaxe.handleResolve(handle, jaxe.TYPE_EVD);
        if (!evd) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return false; }
        var outval = {};
        jaxe.lastResult = evd.is3D(outval);
        return !!outval.val;
    }

    static fmod_evd_is_doppler_enabled(handle) {
        var evd = jaxe.handleResolve(handle, jaxe.TYPE_EVD);
        if (!evd) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return false; }
        var outval = {};
        jaxe.lastResult = evd.isDopplerEnabled(outval);
        return !!outval.val;
    }

    static fmod_evd_has_sustain_point(handle) {
        var evd = jaxe.handleResolve(handle, jaxe.TYPE_EVD);
        if (!evd) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return false; }
        var outval = {};
        jaxe.lastResult = evd.hasSustainPoint(outval);
        return !!outval.val;
    }

    // returns instance handle or 0; stores the handle in FMOD userdata so
    // callbacks can identify the instance (same mechanism as fmod_create_instance)
    static fmod_evd_create_instance(handle) {
        var evd = jaxe.handleResolve(handle, jaxe.TYPE_EVD);
        if (!evd) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var instance = {};
        jaxe.lastResult = evd.createInstance(instance);
        if (jaxe.lastResult != jaxe.FMOD.OK || !instance.val) return 0;
        var eviHandle = jaxe.handleAlloc(instance.val, jaxe.TYPE_EVI);
        if (eviHandle == 0) {
            instance.val.release();
            return 0;
        }
        instance.val.setUserData(eviHandle);
        return eviHandle;
    }

    static fmod_evd_get_instance_count(handle) {
        var evd = jaxe.handleResolve(handle, jaxe.TYPE_EVD);
        if (!evd) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var outval = {};
        jaxe.lastResult = evd.getInstanceCount(outval);
        return jaxe.lastResult == jaxe.FMOD.OK ? outval.val | 0 : 0;
    }

    // fills ibuf with instance handles; instances the table has already seen
    // keep their handle, unseen ones (created outside this binding) get a
    // fresh handle stamped into their userdata for callback identification
    static fmod_evd_get_instance_list(handle, ibuf) {
        var evd = jaxe.handleResolve(handle, jaxe.TYPE_EVD);
        if (!evd) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var list = {};
        var count = {};
        jaxe.lastResult = evd.getInstanceList(list, 64, count);
        if (jaxe.lastResult != jaxe.FMOD.OK || !list.val) return 0;
        var n = count.val | 0;
        if (n > 64) n = 64;
        if (list.val.length < n) n = list.val.length;
        for (var i = 0; i < n; i++) {
            var before = jaxe.liveCount;
            var eviHandle = jaxe.handleFindOrAlloc(list.val[i], jaxe.TYPE_EVI);
            if (eviHandle != 0 && jaxe.liveCount != before) list.val[i].setUserData(eviHandle);
            ibuf[i] = eviHandle;
        }
        return n;
    }

    static fmod_evd_release_all_instances(handle) {
        var evd = jaxe.handleResolve(handle, jaxe.TYPE_EVD);
        if (!evd) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        // Uninstall callbacks on this event's instances first: destroying an
        // instance with a callback installed corrupts the FMOD JS module.
        jaxe.uninstallCallbacksFor(new Set([jaxe.rawPtr(evd)]));
        jaxe.lastResult = evd.releaseAllInstances();
        return jaxe.lastResult;
    }

    static fmod_evd_load_sample_data(handle) {
        var evd = jaxe.handleResolve(handle, jaxe.TYPE_EVD);
        if (!evd) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = evd.loadSampleData();
        return jaxe.lastResult;
    }

    static fmod_evd_unload_sample_data(handle) {
        var evd = jaxe.handleResolve(handle, jaxe.TYPE_EVD);
        if (!evd) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = evd.unloadSampleData();
        return jaxe.lastResult;
    }

    static fmod_evd_get_sample_loading_state(handle) {
        var evd = jaxe.handleResolve(handle, jaxe.TYPE_EVD);
        if (!evd) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 1; }
        var outval = {};
        jaxe.lastResult = evd.getSampleLoadingState(outval);
        return jaxe.lastResult == jaxe.FMOD.OK ? outval.val | 0 : 1;
    }

    static fmod_evd_get_parameter_description_count(handle) {
        var evd = jaxe.handleResolve(handle, jaxe.TYPE_EVD);
        if (!evd) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var outval = {};
        jaxe.lastResult = evd.getParameterDescriptionCount(outval);
        return jaxe.lastResult == jaxe.FMOD.OK ? outval.val | 0 : 0;
    }

    // returns param name; fbuf/ibuf layout documented on writeParamDesc
    static fmod_evd_get_parameter_description_by_index(handle, index, fbuf, ibuf) {
        var evd = jaxe.handleResolve(handle, jaxe.TYPE_EVD);
        if (!evd) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return ""; }
        var outval = {};
        jaxe.lastResult = evd.getParameterDescriptionByIndex(index, outval);
        if (jaxe.lastResult != jaxe.FMOD.OK) return "";
        return jaxe.writeParamDesc(outval, fbuf, ibuf);
    }

    static fmod_evd_get_parameter_description_by_name(handle, name, fbuf, ibuf) {
        var evd = jaxe.handleResolve(handle, jaxe.TYPE_EVD);
        if (!evd) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return ""; }
        var outval = {};
        jaxe.lastResult = evd.getParameterDescriptionByName(name, outval);
        if (jaxe.lastResult != jaxe.FMOD.OK) return "";
        return jaxe.writeParamDesc(outval, fbuf, ibuf);
    }

    // (paramName, labelIndex) -> label
    static fmod_evd_get_parameter_label(handle, name, labelIndex) {
        var evd = jaxe.handleResolve(handle, jaxe.TYPE_EVD);
        if (!evd) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return ""; }
        var outval = {};
        jaxe.lastResult = evd.getParameterLabelByName(name, labelIndex, outval, 512, null);
        if (jaxe.lastResult != jaxe.FMOD.OK) return "";
        return outval.val;
    }

    static fmod_evd_get_user_property_count(handle) {
        var evd = jaxe.handleResolve(handle, jaxe.TYPE_EVD);
        if (!evd) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var outval = {};
        jaxe.lastResult = evd.getUserPropertyCount(outval);
        return jaxe.lastResult == jaxe.FMOD.OK ? outval.val | 0 : 0;
    }

    // Shared user property fetch; struct fields land directly on the out
    // object, with .val as a fallback in case a build wraps them
    static evdUserProp(handle, index) {
        var evd = jaxe.handleResolve(handle, jaxe.TYPE_EVD);
        if (!evd) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return null; }
        var outval = {};
        jaxe.lastResult = evd.getUserPropertyByIndex(index, outval);
        if (jaxe.lastResult != jaxe.FMOD.OK) return null;
        return (outval.val && typeof outval.val === "object") ? outval.val : outval;
    }

    static fmod_evd_get_user_property_name(handle, index) {
        var prop = jaxe.evdUserProp(handle, index);
        return prop ? (prop.name || "") : "";
    }

    // FMOD_STUDIO_USER_PROPERTY_TYPE (0=int 1=bool 2=float 3=string)
    static fmod_evd_get_user_property_type(handle, index) {
        var prop = jaxe.evdUserProp(handle, index);
        return prop ? prop.type | 0 : 0;
    }

    // int/bool coerced to float
    static fmod_evd_get_user_property_float(handle, index) {
        var prop = jaxe.evdUserProp(handle, index);
        if (!prop) return 0.0;
        if (prop.type == 0) return prop.intvalue | 0;
        if (prop.type == 1) return prop.boolvalue ? 1.0 : 0.0;
        if (prop.type == 2) return +prop.floatvalue || 0.0;
        return 0.0;
    }

    static fmod_evd_get_user_property_string(handle, index) {
        var prop = jaxe.evdUserProp(handle, index);
        if (!prop || prop.type != 3) return "";
        return prop.stringvalue || "";
    }

    //// EventInstance (2.0 bindings)

    static fmod_evi_is_valid(handle) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        return inst != null && (!inst.isValid || !!inst.isValid());
    }

    // returns the description handle (cached per description, like bus lookups)
    static fmod_evi_get_description(handle) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var desc = {};
        jaxe.lastResult = inst.getDescription(desc);
        if (jaxe.lastResult != jaxe.FMOD.OK || !desc.val) return 0;
        return jaxe.handleFindOrAlloc(desc.val, jaxe.TYPE_EVD);
    }

    static fmod_evi_start(handle) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = inst.start();
        return jaxe.lastResult;
    }

    static fmod_evi_stop(handle, stopMode) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = inst.stop(
            stopMode == 1 ? jaxe.FMOD.STUDIO_STOP_IMMEDIATE : jaxe.FMOD.STUDIO_STOP_ALLOWFADEOUT);
        return jaxe.lastResult;
    }

    static fmod_evi_key_off(handle) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = inst.keyOff();
        return jaxe.lastResult;
    }

    // releases the instance and frees the handle (no implicit stop)
    static fmod_evi_release(handle) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        // Uninstall the callback first: destroying an instance with a
        // callback installed corrupts the FMOD JS module.
        jaxe.uninstallCallback(handle);
        jaxe.lastResult = inst.release();
        if (jaxe.lastResult == jaxe.FMOD.OK) jaxe.handleFree(handle);
        return jaxe.lastResult;
    }

    // FMOD_STUDIO_PLAYBACK_STATE; invalid handle reports 2 (STOPPED)
    static fmod_evi_get_playback_state(handle) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 2; }
        var outval = {};
        jaxe.lastResult = inst.getPlaybackState(outval);
        return jaxe.lastResult == jaxe.FMOD.OK ? outval.val | 0 : 2;
    }

    static fmod_evi_get_paused(handle) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return false; }
        var outval = {};
        jaxe.lastResult = inst.getPaused(outval);
        return !!outval.val;
    }

    static fmod_evi_set_paused(handle, paused) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = inst.setPaused(paused);
        return jaxe.lastResult;
    }

    static fmod_evi_get_volume(handle) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0.0; }
        var outval = {};
        jaxe.lastResult = inst.getVolume(outval, null);
        return outval.val || 0.0;
    }

    static fmod_evi_get_volume_final(handle) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0.0; }
        var volume = {};
        var finalVolume = {};
        jaxe.lastResult = inst.getVolume(volume, finalVolume);
        return finalVolume.val || 0.0;
    }

    static fmod_evi_set_volume(handle, volume) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = inst.setVolume(volume);
        return jaxe.lastResult;
    }

    static fmod_evi_get_pitch(handle) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0.0; }
        var outval = {};
        jaxe.lastResult = inst.getPitch(outval, null);
        return outval.val || 0.0;
    }

    static fmod_evi_get_pitch_final(handle) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0.0; }
        var pitch = {};
        var finalPitch = {};
        jaxe.lastResult = inst.getPitch(pitch, finalPitch);
        return finalPitch.val || 0.0;
    }

    static fmod_evi_set_pitch(handle, pitch) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = inst.setPitch(pitch);
        return jaxe.lastResult;
    }

    static fmod_evi_get_timeline_position(handle) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var outval = {};
        jaxe.lastResult = inst.getTimelinePosition(outval);
        return jaxe.lastResult == jaxe.FMOD.OK ? outval.val | 0 : 0;
    }

    static fmod_evi_set_timeline_position(handle, position) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = inst.setTimelinePosition(position);
        return jaxe.lastResult;
    }

    static fmod_evi_is_virtual(handle) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return false; }
        var outval = {};
        jaxe.lastResult = inst.isVirtual(outval);
        return !!outval.val;
    }

    // fbuf: [0]=min [1]=max
    static fmod_evi_get_min_max_distance(handle, fbuf) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        var min = {};
        var max = {};
        jaxe.lastResult = inst.getMinMaxDistance(min, max);
        if (jaxe.lastResult == jaxe.FMOD.OK) {
            fbuf[0] = min.val || 0.0;
            fbuf[1] = max.val || 0.0;
        }
        return jaxe.lastResult;
    }

    // fbuf[0..11] = pos/vel/forward/up
    static fmod_evi_get_3d_attributes(handle, fbuf) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        var attr = {};
        jaxe.lastResult = inst.get3DAttributes(attr);
        if (jaxe.lastResult == jaxe.FMOD.OK) jaxe.readAttributes3D(attr, fbuf);
        return jaxe.lastResult;
    }

    static fmod_evi_set_3d_attributes(handle, f) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = inst.set3DAttributes(
            jaxe.buildAttributes3D(f[0], f[1], f[2], f[3], f[4], f[5], f[6], f[7], f[8], f[9], f[10], f[11]));
        return jaxe.lastResult;
    }

    static fmod_evi_get_listener_mask(handle) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var outval = {};
        jaxe.lastResult = inst.getListenerMask(outval);
        return jaxe.lastResult == jaxe.FMOD.OK ? outval.val | 0 : 0;
    }

    static fmod_evi_set_listener_mask(handle, mask) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = inst.setListenerMask(mask >>> 0);
        return jaxe.lastResult;
    }

    // FMOD_STUDIO_EVENT_PROPERTY index
    static fmod_evi_get_property(handle, propertyIndex) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0.0; }
        var outval = {};
        jaxe.lastResult = inst.getProperty(propertyIndex, outval);
        return jaxe.lastResult == jaxe.FMOD.OK ? outval.val || 0.0 : 0.0;
    }

    static fmod_evi_set_property(handle, propertyIndex, value) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = inst.setProperty(propertyIndex, value);
        return jaxe.lastResult;
    }

    static fmod_evi_get_reverb_level(handle, index) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0.0; }
        var outval = {};
        jaxe.lastResult = inst.getReverbLevel(index, outval);
        return jaxe.lastResult == jaxe.FMOD.OK ? outval.val || 0.0 : 0.0;
    }

    static fmod_evi_set_reverb_level(handle, index, level) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = inst.setReverbLevel(index, level);
        return jaxe.lastResult;
    }

    static fmod_evi_get_param_by_name(handle, name) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0.0; }
        var value = {};
        jaxe.lastResult = inst.getParameterByName(name, value, null);
        return jaxe.lastResult == jaxe.FMOD.OK ? value.val : 0.0;
    }

    static fmod_evi_get_param_by_name_final(handle, name) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0.0; }
        var value = {};
        var finalValue = {};
        jaxe.lastResult = inst.getParameterByName(name, value, finalValue);
        return jaxe.lastResult == jaxe.FMOD.OK ? finalValue.val : 0.0;
    }

    static fmod_evi_set_param_by_name(handle, name, value, ignoreSeekSpeed) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = inst.setParameterByName(name, value, ignoreSeekSpeed);
        return jaxe.lastResult;
    }

    static fmod_evi_set_param_by_name_with_label(handle, name, label, ignoreSeekSpeed) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = inst.setParameterByNameWithLabel(name, label, ignoreSeekSpeed);
        return jaxe.lastResult;
    }

    static fmod_evi_get_param_by_id(handle, id1, id2) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0.0; }
        var value = {};
        jaxe.lastResult = inst.getParameterByID(jaxe.paramId(id1, id2), value, null);
        return jaxe.lastResult == jaxe.FMOD.OK ? value.val : 0.0;
    }

    static fmod_evi_get_param_by_id_final(handle, id1, id2) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0.0; }
        var value = {};
        var finalValue = {};
        jaxe.lastResult = inst.getParameterByID(jaxe.paramId(id1, id2), value, finalValue);
        return jaxe.lastResult == jaxe.FMOD.OK ? finalValue.val : 0.0;
    }

    static fmod_evi_set_param_by_id(handle, id1, id2, value, ignoreSeekSpeed) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = inst.setParameterByID(jaxe.paramId(id1, id2), value, ignoreSeekSpeed);
        return jaxe.lastResult;
    }

    static fmod_evi_set_param_by_id_with_label(handle, id1, id2, label, ignoreSeekSpeed) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = inst.setParameterByIDWithLabel(jaxe.paramId(id1, id2), label, ignoreSeekSpeed);
        return jaxe.lastResult;
    }

    // ibuf: [0]=exclusive [1]=inclusive us; not exposed by the FMOD JS API,
    // so this reports ERR_UNSUPPORTED
    static fmod_evi_get_cpu_usage(handle, ibuf) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        if (!inst.getCPUUsage) { jaxe.lastResult = jaxe.ERR_UNSUPPORTED; return jaxe.lastResult; }
        var exclusive = {};
        var inclusive = {};
        jaxe.lastResult = inst.getCPUUsage(exclusive, inclusive);
        ibuf[0] = exclusive.val | 0;
        ibuf[1] = inclusive.val | 0;
        return jaxe.lastResult;
    }

    // ibuf: [0]=exclusive [1]=inclusive [2]=sampledata; not exposed by the
    // FMOD JS API, so this reports ERR_UNSUPPORTED
    static fmod_evi_get_memory_usage(handle, ibuf) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        if (!inst.getMemoryUsage) { jaxe.lastResult = jaxe.ERR_UNSUPPORTED; return jaxe.lastResult; }
        var outval = {};
        jaxe.lastResult = inst.getMemoryUsage(outval);
        if (jaxe.lastResult == jaxe.FMOD.OK && outval.val) {
            ibuf[0] = outval.val.exclusive | 0;
            ibuf[1] = outval.val.inclusive | 0;
            ibuf[2] = outval.val.sampledata | 0;
        }
        return jaxe.lastResult;
    }

    //// Programmer sounds

    static fmod_ps_assign(handle, key) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.psKeys[handle] = key;
        jaxe.lastResult = inst.setCallback(jaxe.callbackHandler, jaxe.effectiveCallbackMask(handle));
        return jaxe.lastResult;
    }

    static fmod_ps_clear(handle) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        delete jaxe.psKeys[handle];
        jaxe.lastResult = inst.setCallback(jaxe.callbackHandler, jaxe.effectiveCallbackMask(handle));
        return jaxe.lastResult;
    }

    //// Core API micro subset (programmer sounds only)

    static fmod_core_create_sound(path, mode) {
        if (!jaxe.FmodIsInitialized) { jaxe.lastResult = jaxe.ERR_STUDIO_UNINITIALIZED; return 0; }
        var soundOut = {};
        var fmodMode = jaxe.FMOD.DEFAULT >>> 0;
        if (mode & 1) fmodMode = (fmodMode | jaxe.FMOD.LOOP_NORMAL) >>> 0;
        // Files live in the MEMFS root (banks are preloaded there)
        jaxe.lastResult = jaxe.gSystemCore.createSound("/" + path, fmodMode, null, soundOut);
        if (jaxe.lastResult != jaxe.FMOD.OK || !soundOut.val) return 0;
        var handle = jaxe.handleAlloc(soundOut.val, jaxe.TYPE_SOUND);
        if (handle == 0) {
            soundOut.val.release();
            return 0;
        }
        return handle;
    }

    static fmod_core_release_sound(handle) {
        var sound = jaxe.handleResolve(handle, jaxe.TYPE_SOUND);
        if (!sound) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = sound.release();
        if (jaxe.lastResult == jaxe.FMOD.OK) jaxe.handleFree(handle);
        return jaxe.lastResult;
    }

    static fmod_core_get_sound_length(handle) {
        var sound = jaxe.handleResolve(handle, jaxe.TYPE_SOUND);
        if (!sound) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return -1; }
        var outval = {};
        jaxe.lastResult = sound.getLength(outval, jaxe.FMOD.TIMEUNIT_MS);
        if (jaxe.lastResult != jaxe.FMOD.OK) return -1;
        return outval.val | 0;
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
        // Settings from fmod_sys_init_ex; null on the legacy fmod_init path
        // (defaults below match the legacy behavior exactly).
        var init = jaxe.pendingInit;

        jaxe.FMOD.Studio_System_Create(outval);
        jaxe.gSystem = outval.val;

        jaxe.gSystem.getCoreSystem(outval);
        jaxe.gSystemCore = outval.val;

        jaxe.gSystemCore.setDSPBufferSize(2048, 2);

        if (init && init.sampleRate > 0) {
            jaxe.gSystemCore.setSoftwareFormat(init.sampleRate,
                init.speakerMode > 0 ? init.speakerMode : jaxe.FMOD.SPEAKERMODE_DEFAULT, 0);
        } else {
            jaxe.gSystemCore.getDriverInfo(0, null, null, outval, null, null);
            jaxe.gSystemCore.setSoftwareFormat(outval.val, jaxe.FMOD.SPEAKERMODE_DEFAULT, 0);
        }

        // Browser audio resume handler
        document.addEventListener('click', function () {
            if (!jaxe.gAudioResumed) {
                jaxe.gSystemCore.mixerSuspend();
                jaxe.gSystemCore.mixerResume();
                jaxe.gAudioResumed = true;
            }
        });

        var numChannels = (init && init.numChannels > 0) ? init.numChannels : 1024;
        var studioInitFlags = (init && (init.studioFlags & 1))
            ? jaxe.FMOD.STUDIO_INIT_LIVEUPDATE
            : jaxe.FMOD.STUDIO_INIT_NORMAL;
        jaxe.gSystem.initialize(numChannels, studioInitFlags, jaxe.FMOD.INIT_NORMAL, null);

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
