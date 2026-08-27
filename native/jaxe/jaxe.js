/**
 * Jaxe - JavaScript FMOD bindings - Minimal FFI layer
 *
 * Raw FMOD calls only against the Emscripten Studio API. Typed wrappers
 * live in haxefmod/studio and haxefmod/core. Numeric arguments pass
 * through for FMOD to validate. This shim guards what the embind layer
 * makes dangerous instead: argument arities, null out-params, wrapper
 * identity, and callback teardown ordering.
 */

class jaxe {
    static FMOD = {};
    static gSystem = {};
    static gSystemCore = {};
    static gAudioResumed = false;
    static FmodIsInitialized = false;
    static autoUpdateIntervalId = null;

    // Init settings stored by fmod_sys_init_ex and consumed by
    // onRuntimeInitialized. Legacy fmod_init leaves this null (defaults).
    static pendingInit = null;
    // Counter for unique MEMFS names used by fmod_sys_load_bank_async.
    static asyncBankCounter = 0;
    // bank rawPtr -> MEMFS file name, so unload can delete the copied bytes
    static asyncBankFiles = new Map();
    // Async bank fetches are aborted after this many ms (tests shrink it);
    // the placeholder then reports loading state ERROR.
    static ASYNC_FETCH_TIMEOUT_MS = 30000;

    // Generational handle table - JS mirror of native/shared/faxe_handles.h.
    // Handle encoding: (generation << 16) | index. Handle 0 is always invalid.
    // Type tags match native/shared/faxe_handles.h.
    static TYPE_EVI = 1;
    static TYPE_EVD = 2;
    static TYPE_BANK = 3;
    static TYPE_BUS = 4;
    static TYPE_VCA = 5;
    static TYPE_SOUND = 6;
    static TYPE_PCM = 7;
    static TYPE_CHAN = 8;
    static TYPE_DSP = 9;
    static TYPE_CHANGROUP = 10;
    static TYPE_DSPCONN = 11;
    static TYPE_REVERB3D = 12;
    static TYPE_SOUNDGROUP = 13;
    static TYPE_REPLAY = 14;
    static LIST_MAX = 1024;
    static slots = [];       // {ptr, raw, gen, type, alive}
    static freeList = [];    // stack of free slot indices
    static liveCount = 0;

    // Callback event queue - JS mirror of native/shared/faxe_cbqueue.h.
    // JS is single-threaded so a plain array needs no locking.
    static CBQ_CAPACITY = 256;
    static cbQueue = [];
    static cbOverflow = false;
    static cbCurrent = { handle: 0, type: 0, i1: 0, i2: 0, i3: 0, i4: 0, i5: 0, f1: 0.0, str: "" };

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
                // FMOD can hand a recycled address to a new object after an
                // unload. A match on a dead cached wrapper must not alias it.
                if (!jaxe.lookupSlotUsable(s)) {
                    jaxe.handleFree((s.gen << 16) | i);
                    continue;
                }
                return (s.gen << 16) | i;
            }
        }
        return jaxe.handleAlloc(ptr, type);
    }

    // A cached wrapper is usable when it has not been deleted and its FMOD
    // object still reports valid (safe to ask of destroyed objects). Core
    // sounds have no isValid and pass the deleted-wrapper check only.
    static lookupSlotUsable(s) {
        if (!s.ptr || !s.ptr.$$ || !s.ptr.$$.ptr) return false;
        try {
            if (s.ptr.isValid) return s.ptr.isValid();
            // Core objects have no isValid. FMOD validates its own handles,
            // so a benign getter reports INVALID_HANDLE on a destroyed one.
            if (s.type === jaxe.TYPE_CHANGROUP) {
                return s.ptr.getVolume({}) != jaxe.ERR_INVALID_HANDLE;
            }
            return true;
        } catch (e) {
            return false;
        }
    }

    // After an unload destroys bank content, drop every cached lookup slot
    // whose object died so a reload cannot alias a recycled address under a
    // stale handle. Flushing first makes the async unload observable to
    // isValid. Mirrors faxe_handles_sweep_lookups in the native shims, and
    // additionally sweeps instance slots: the native shims reclaim those
    // when the DESTROYED event drains, which this target never receives.
    static sweepDeadLookups() {
        if (jaxe.gSystem) jaxe.gSystem.flushCommands();
        for (var i = 0; i < jaxe.slots.length; i++) {
            var s = jaxe.slots[i];
            if (!s.alive) continue;
            if (s.type != jaxe.TYPE_BUS && s.type != jaxe.TYPE_VCA && s.type != jaxe.TYPE_EVD
                && s.type != jaxe.TYPE_CHANGROUP && s.type != jaxe.TYPE_EVI) continue;
            if (!jaxe.lookupSlotUsable(s)) jaxe.handleFree((s.gen << 16) | i);
        }
    }

    // Graph changes invalidate connection objects on the mixer's schedule,
    // so graph-changing calls drop every connection handle deterministically.
    // Mirrors faxe_handles_free_type in the native shims.
    static freeAllOfType(type) {
        for (var i = 0; i < jaxe.slots.length; i++) {
            var s = jaxe.slots[i];
            if (s.alive && s.type === type) jaxe.handleFree((s.gen << 16) | i);
        }
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

    static fmod_sys_is_initialized() {
        return jaxe.FmodIsInitialized;
    }

    static fmod_sys_update() {
        // gSystem is a placeholder object until the async module load
        // finishes, matching the native shims' not-yet-initialized no-op
        if (jaxe.gSystem && jaxe.gSystem.update) jaxe.gSystem.update();
    }

    static fmod_sys_set_auto_update(enabled) {
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

    //// Callbacks

    // Per-instance callback masks and programmer-sound keys, keyed by handle.
    // JS is single-threaded (callbacks run on the main thread), so plain maps
    // are safe where cpp/hl need the userdata context struct.
    static cbMasks = {};
    static psKeys = {};

    // UTF-8 byte length without allocating an encoder per call
    static utf8Encoder = null;
    static utf8ByteLength(s) {
        if (!jaxe.utf8Encoder) jaxe.utf8Encoder = new TextEncoder();
        return jaxe.utf8Encoder.encode(s).length;
    }

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
                // The JS glue fills the out object with flat properties
                // (name_or_data, mode, subsoundindex) and writes exinfo
                // fields onto a pre-existing exinfo object. Without one it
                // throws mid-fill.
                var info = { exinfo: {} };
                var soundOut = {};
                if (jaxe.gSystem.getSoundInfo(key, info) == jaxe.FMOD.OK) {
                    // createSound's exinfo conversion requires a real
                    // SoundGroup instance (null and undefined both throw),
                    // and getSoundInfo does not write the field. The master
                    // group is where sounds land by default anyway.
                    var masterSg = {};
                    jaxe.gSystemCore.getMasterSoundGroup(masterSg);
                    info.exinfo.initialsoundgroup = masterSg.val;
                    // Audio table entry: decode the FSB slice the info describes
                    if (jaxe.gSystemCore.createSound(info.name_or_data,
                            (jaxe.FMOD.LOOP_NORMAL | jaxe.FMOD.CREATECOMPRESSEDSAMPLE | info.mode) >>> 0,
                            info.exinfo, soundOut) == jaxe.FMOD.OK) {
                        parameters.sound = soundOut.val;
                        parameters.subsoundIndex = info.subsoundindex | 0;
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

        var ev = { handle: handle, type: type, i1: 0, i2: 0, i3: 0, i4: 0, i5: 0, f1: 0.0, str: "" };

        if (type == 0x00000800 /* TIMELINE_MARKER */ && parameters) {
            if (typeof parameters.name === "string") ev.str = parameters.name;
            if (typeof parameters.position === "number") ev.i1 = parameters.position;
        } else if (type == 0x00001000 /* TIMELINE_BEAT */ && parameters) {
            ev.i1 = parameters.bar | 0;
            ev.i2 = parameters.beat | 0;
            ev.i3 = parameters.position | 0;
            ev.i4 = parameters.timesignatureupper | 0;
            ev.i5 = parameters.timesignaturelower | 0;
            ev.f1 = parameters.tempo || 0.0;
        } else if (type == 0x00040000 /* NESTED_TIMELINE_BEAT */ && parameters) {
            // FMOD's JS glue has no marshaler for the nested-beat struct, so
            // the C-side properties sub-object never appears. Read the flat
            // beat keys when the glue provides them and fall back to the
            // nested shape in case a future glue adds it.
            var beatProps = parameters.properties ? parameters.properties : parameters;
            ev.i1 = beatProps.bar | 0;
            ev.i2 = beatProps.beat | 0;
            ev.i3 = beatProps.position | 0;
            ev.i4 = beatProps.timesignatureupper | 0;
            ev.i5 = beatProps.timesignaturelower | 0;
            ev.f1 = beatProps.tempo || 0.0;
        }

        // Destroyed events are documented as never delivered on this
        // target (the uninstall-before-destroy design normally prevents
        // them entirely). If a glue ever fires one anyway, the per-handle
        // state still ends with the instance, but the record stays out of
        // the queue so the documented contract holds.
        if (type == 0x02 /* DESTROYED */) {
            delete jaxe.cbMasks[handle];
            delete jaxe.psKeys[handle];
            return jaxe.FMOD.OK;
        }

        jaxe.cbQueue.push(ev);
        if (jaxe.cbQueue.length > jaxe.CBQ_CAPACITY) {
            jaxe.cbQueue.shift(); // drop oldest
            jaxe.cbOverflow = true;
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
        switch (index) {
            case 0: return jaxe.cbCurrent.i1;
            case 1: return jaxe.cbCurrent.i2;
            case 2: return jaxe.cbCurrent.i3;
            case 3: return jaxe.cbCurrent.i4;
            case 4: return jaxe.cbCurrent.i5;
            default: return 0;
        }
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

    //// Studio System

    static lastResult = 0;
    static ERR_INVALID_HANDLE = 30;
    static ERR_INVALID_PARAM = 31;
    static ERR_UNSUPPORTED = 68;
    static ERR_INVALID_GUID = 31;   // malformed GUID string -> FMOD_ERR_INVALID_PARAM (shared shim convention)
    static ERR_NOTREADY = 46;
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

    // Parameter IDs cross the boundary as two i32. FMOD JS wants an object
    // with lowercase data1/data2 holding the unsigned 32-bit values
    static paramId(d1, d2) {
        return { data1: d1 >>> 0, data2: d2 >>> 0 };
    }

    // Shared writer for parameter descriptions. FMOD JS writes the struct
    // fields directly onto the out object (not out.val).
    // Layout: fbuf [0]=min [1]=max [2]=default. ibuf [0]=type [1]=flags
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
    // the out object ("position.x" ... "up.z"). flatten into fbuf[0..11]
    // in pos/vel/forward/up order
    // The C shims copy zero-initialized locals into the caller's buffer
    // when the FMOD call fails after handle validation. Mirror that here so
    // error paths leave the same buffer contents on every target.
    static zeroFill(buf, count) {
        for (var i = 0; i < count; i++) buf[i] = 0;
    }

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

    // List getters fill ibuf with handles (capped at LIST_MAX, kept in
    // lockstep with Scratch.CAPACITY and the C shims' FAXE_LIST_MAX) and return the
    // count written. Entries the table has seen keep their existing handle
    static writeHandleList(items, count, ibuf, type) {
        var n = count | 0;
        if (n > jaxe.LIST_MAX) n = jaxe.LIST_MAX;
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
    // asynchronous - poll fmod_sys_is_initialized for completion. Returns 0 (OK).
    static fmod_sys_init_ex(numChannels, sampleRate, speakerMode, studioFlags) {
        jaxe.pendingInit = {
            numChannels: numChannels,
            sampleRate: sampleRate,
            speakerMode: speakerMode,
            studioFlags: studioFlags
        };
        jaxe.FMOD['preRun'] = jaxe.preRun;
        jaxe.FMOD['onRuntimeInitialized'] = jaxe.onRuntimeInitialized;
        // The Emscripten build reads INITIAL_MEMORY (TOTAL_MEMORY is the
        // pre-1.39 name and is ignored), so this pre-allocates 64MB up
        // front instead of growing mid-gameplay
        jaxe.FMOD['INITIAL_MEMORY'] = 64 * 1024 * 1024;
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
        if (typeof path !== "string") { jaxe.lastResult = jaxe.ERR_INVALID_PARAM; return 0; }
        if (!jaxe.sysReady()) return 0;
        var bus = {};
        jaxe.lastResult = jaxe.gSystem.getBus(path, bus);
        if (jaxe.lastResult != jaxe.FMOD.OK || !bus.val) return 0;
        return jaxe.handleFindOrAlloc(bus.val, jaxe.TYPE_BUS);
    }

    static fmod_sys_get_bus_by_id(guid) {
        if (typeof guid !== "string") { jaxe.lastResult = jaxe.ERR_INVALID_PARAM; return 0; }
        if (!jaxe.sysReady()) return 0;
        var id = jaxe.parseGuid(guid);
        if (!id) { jaxe.lastResult = jaxe.ERR_INVALID_GUID; return 0; }
        var bus = {};
        jaxe.lastResult = jaxe.gSystem.getBusByID(id, bus);
        if (jaxe.lastResult != jaxe.FMOD.OK || !bus.val) return 0;
        return jaxe.handleFindOrAlloc(bus.val, jaxe.TYPE_BUS);
    }

    static fmod_sys_get_event(path) {
        if (typeof path !== "string") { jaxe.lastResult = jaxe.ERR_INVALID_PARAM; return 0; }
        if (!jaxe.sysReady()) return 0;
        var desc = {};
        jaxe.lastResult = jaxe.gSystem.getEvent(path, desc);
        if (jaxe.lastResult != jaxe.FMOD.OK || !desc.val) return 0;
        return jaxe.handleFindOrAlloc(desc.val, jaxe.TYPE_EVD);
    }

    static fmod_sys_get_event_by_id(guid) {
        if (typeof guid !== "string") { jaxe.lastResult = jaxe.ERR_INVALID_PARAM; return 0; }
        if (!jaxe.sysReady()) return 0;
        var id = jaxe.parseGuid(guid);
        if (!id) { jaxe.lastResult = jaxe.ERR_INVALID_GUID; return 0; }
        var desc = {};
        jaxe.lastResult = jaxe.gSystem.getEventByID(id, desc);
        if (jaxe.lastResult != jaxe.FMOD.OK || !desc.val) return 0;
        return jaxe.handleFindOrAlloc(desc.val, jaxe.TYPE_EVD);
    }

    static fmod_sys_get_vca(path) {
        if (typeof path !== "string") { jaxe.lastResult = jaxe.ERR_INVALID_PARAM; return 0; }
        if (!jaxe.sysReady()) return 0;
        var vca = {};
        jaxe.lastResult = jaxe.gSystem.getVCA(path, vca);
        if (jaxe.lastResult != jaxe.FMOD.OK || !vca.val) return 0;
        return jaxe.handleFindOrAlloc(vca.val, jaxe.TYPE_VCA);
    }

    static fmod_sys_get_vca_by_id(guid) {
        if (typeof guid !== "string") { jaxe.lastResult = jaxe.ERR_INVALID_PARAM; return 0; }
        if (!jaxe.sysReady()) return 0;
        var id = jaxe.parseGuid(guid);
        if (!id) { jaxe.lastResult = jaxe.ERR_INVALID_GUID; return 0; }
        var vca = {};
        jaxe.lastResult = jaxe.gSystem.getVCAByID(id, vca);
        if (jaxe.lastResult != jaxe.FMOD.OK || !vca.val) return 0;
        return jaxe.handleFindOrAlloc(vca.val, jaxe.TYPE_VCA);
    }

    static fmod_sys_get_bank(path) {
        if (typeof path !== "string") { jaxe.lastResult = jaxe.ERR_INVALID_PARAM; return 0; }
        if (!jaxe.sysReady()) return 0;
        var bank = {};
        jaxe.lastResult = jaxe.gSystem.getBank(path, bank);
        if (jaxe.lastResult != jaxe.FMOD.OK || !bank.val) return 0;
        return jaxe.handleFindOrAlloc(bank.val, jaxe.TYPE_BANK);
    }

    static fmod_sys_get_bank_by_id(guid) {
        if (typeof guid !== "string") { jaxe.lastResult = jaxe.ERR_INVALID_PARAM; return 0; }
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
        jaxe.lastResult = jaxe.gSystem.getBankList(list, jaxe.LIST_MAX, count);
        if (jaxe.lastResult != jaxe.FMOD.OK || !list.val) return 0;
        return jaxe.writeHandleList(list.val, count.val, ibuf, jaxe.TYPE_BANK);
    }

    static fmod_sys_lookup_id(path) {
        if (typeof path !== "string") { jaxe.lastResult = jaxe.ERR_INVALID_PARAM; return ''; }
        if (!jaxe.sysReady()) return "";
        // lookupID writes the GUID fields directly into a pre-shaped out
        var id = jaxe.guidOut();
        jaxe.lastResult = jaxe.gSystem.lookupID(path, id);
        if (jaxe.lastResult != jaxe.FMOD.OK) return "";
        return jaxe.formatGuid(id);
    }

    static fmod_sys_lookup_path(guid) {
        if (typeof guid !== "string") { jaxe.lastResult = jaxe.ERR_INVALID_PARAM; return ''; }
        if (!jaxe.sysReady()) return "";
        var id = jaxe.parseGuid(guid);
        if (!id) { jaxe.lastResult = jaxe.ERR_INVALID_GUID; return ""; }
        var outval = {};
        jaxe.lastResult = jaxe.gSystem.lookupPath(id, outval, 512, null);
        if (jaxe.lastResult != jaxe.FMOD.OK) return "";
        return outval.val;
    }

    static fmod_sys_get_param_by_name(name) {
        if (typeof name !== "string") { jaxe.lastResult = jaxe.ERR_INVALID_PARAM; return jaxe.lastResult; }
        if (!jaxe.sysReady()) return 0.0;
        var value = {};
        jaxe.lastResult = jaxe.gSystem.getParameterByName(name, value, null);
        return jaxe.lastResult == jaxe.FMOD.OK ? value.val : 0.0;
    }

    static fmod_sys_get_param_by_name_final(name) {
        if (typeof name !== "string") { jaxe.lastResult = jaxe.ERR_INVALID_PARAM; return jaxe.lastResult; }
        if (!jaxe.sysReady()) return 0.0;
        var value = {};
        var finalValue = {};
        jaxe.lastResult = jaxe.gSystem.getParameterByName(name, value, finalValue);
        return jaxe.lastResult == jaxe.FMOD.OK ? finalValue.val : 0.0;
    }

    static fmod_sys_set_param_by_name(name, value, ignoreSeekSpeed) {
        if (typeof name !== "string") { jaxe.lastResult = jaxe.ERR_INVALID_PARAM; return jaxe.lastResult; }
        if (!jaxe.sysReady()) return jaxe.lastResult;
        jaxe.lastResult = jaxe.gSystem.setParameterByName(name, value, ignoreSeekSpeed);
        return jaxe.lastResult;
    }

    static fmod_sys_set_param_by_name_with_label(name, label, ignoreSeekSpeed) {
        if (typeof name !== "string") { jaxe.lastResult = jaxe.ERR_INVALID_PARAM; return jaxe.lastResult; }
        if (typeof label !== "string") { jaxe.lastResult = jaxe.ERR_INVALID_PARAM; return jaxe.lastResult; }
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
        if (typeof label !== "string") { jaxe.lastResult = jaxe.ERR_INVALID_PARAM; return jaxe.lastResult; }
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

    // returns param name. fbuf/ibuf layout documented on writeParamDesc.
    // The JS System API has no getParameterDescriptionByIndex, only
    // getParameterDescriptionList - index into the fetched list instead.
    static fmod_sys_get_parameter_description_by_index(index, fbuf, ibuf) {
        if (!jaxe.sysReady()) return "";
        var list = {};
        var count = {};
        // The glue fills the list object as a flat array (list[0..n-1])
        jaxe.lastResult = jaxe.gSystem.getParameterDescriptionList(list, jaxe.LIST_MAX, count);
        if (jaxe.lastResult != jaxe.FMOD.OK) return "";
        if (index < 0 || index >= (count.val | 0) || !list[index]) {
            jaxe.lastResult = jaxe.ERR_INVALID_PARAM;
            return "";
        }
        return jaxe.writeParamDesc(list[index], fbuf, ibuf);
    }

    static fmod_sys_get_parameter_description_by_name(name, fbuf, ibuf) {
        if (typeof name !== "string") { jaxe.lastResult = jaxe.ERR_INVALID_PARAM; return ''; }
        if (!jaxe.sysReady()) return "";
        var outval = {};
        jaxe.lastResult = jaxe.gSystem.getParameterDescriptionByName(name, outval);
        if (jaxe.lastResult != jaxe.FMOD.OK) return "";
        return jaxe.writeParamDesc(outval, fbuf, ibuf);
    }

    // global parameter labels (paramName, labelIndex)
    static fmod_sys_get_parameter_label(name, labelIndex) {
        if (typeof name !== "string") { jaxe.lastResult = jaxe.ERR_INVALID_PARAM; return ''; }
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
        else jaxe.zeroFill(fbuf, 12);
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

    // bank loading (flags: bit0 = nonblocking). Returns bank handle or 0.
    // Resolves bare filenames from the MEMFS root; on this target files
    // only exist there after an async load's fetch wrote them, so the
    // registry routes html5 loads through fmod_sys_load_bank_async.
    static fmod_sys_load_bank_file(path, flags) {
        if (typeof path !== "string") { jaxe.lastResult = jaxe.ERR_INVALID_PARAM; return 0; }
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
    // path relative to the page origin, writes the bytes into MEMFS under
    // a unique flat name, then swaps the real bank into the slot. Poll
    // bank_get_loading_state: 2 (LOADING) while the fetch is pending,
    // 4 (ERROR) if the fetch or load failed or ASYNC_FETCH_TIMEOUT_MS
    // elapsed. fmod_bank_unload on a still-pending placeholder cancels the
    // fetch and frees the handle. The pendingBankCancelled flag keeps
    // a fetch that settles after that from ever reaching FMOD.
    static fmod_sys_load_bank_async(path) {
        if (typeof path !== "string") { jaxe.lastResult = jaxe.ERR_INVALID_PARAM; return 0; }
        if (!jaxe.sysReady()) return 0;
        var placeholder = { pendingBankPath: path };
        var handle = jaxe.handleAlloc(placeholder, jaxe.TYPE_BANK);
        if (handle == 0) return 0;
        jaxe.lastResult = jaxe.FMOD.OK;
        var idx = handle & 0xFFFF;
        var memfsName = "async_" + (++jaxe.asyncBankCounter) + ".bank";
        // Abort support is optional (missing AbortController just means the
        // fetch keeps running in the background). The timeout below flips
        // the placeholder to ERROR either way.
        var controller = (typeof AbortController != "undefined") ? new AbortController() : null;
        placeholder.pendingBankController = controller;
        placeholder.pendingBankTimer = setTimeout(function () {
            placeholder.pendingBankTimer = null;
            placeholder.pendingBankError = true;
            if (controller) controller.abort();
        }, jaxe.ASYNC_FETCH_TIMEOUT_MS);
        // clears the timeout once the fetch settles (success, error, abort)
        var settle = function () {
            if (placeholder.pendingBankTimer != null) {
                clearTimeout(placeholder.pendingBankTimer);
                placeholder.pendingBankTimer = null;
            }
        };
        try {
            fetch(path, controller ? { signal: controller.signal } : undefined).then(function (response) {
                if (!response.ok) throw new Error("HTTP " + response.status);
                return response.arrayBuffer();
            }).then(function (buffer) {
                settle();
                // dropped: cancelled by unload, or already timed out (a
                // fetch that ignores the abort can still resolve late)
                if (placeholder.pendingBankCancelled || placeholder.pendingBankError) return;
                var s = jaxe.slots[idx];
                // handle freed (or recycled) while the fetch was in flight
                if (!s || !s.alive || s.ptr !== placeholder) return;
                jaxe.FMOD.FS_createDataFile('/', memfsName, new Uint8Array(buffer), true, false, false);
                var bank = {};
                var result = jaxe.gSystem.loadBankFile("/" + memfsName, jaxe.FMOD.STUDIO_LOAD_BANK_NORMAL, bank);
                if (result != jaxe.FMOD.OK || !bank.val) {
                    placeholder.pendingBankError = true;
                    jaxe.unlinkMemfsFile(memfsName);
                    return;
                }
                // Swap the real bank into the slot. The handle stays valid.
                s.ptr = bank.val;
                s.raw = jaxe.rawPtr(bank.val);
                // The MEMFS copy backs the loaded bank (streaming sample
                // data reads from it), so it is deleted at unload, not here
                jaxe.asyncBankFiles.set(s.raw, memfsName);
            }).catch(function () {
                settle();
                placeholder.pendingBankError = true;
            });
        } catch (e) {
            settle();
            placeholder.pendingBankError = true;
        }
        return handle;
    }

    static fmod_sys_unload_all() {
        if (!jaxe.FmodIsInitialized) { jaxe.lastResult = jaxe.ERR_STUDIO_UNINITIALIZED; return jaxe.lastResult; }
        // All bank content is going away. Uninstall every callback first or
        // the FMOD JS module is corrupted.
        jaxe.uninstallCallbacksFor(null);
        jaxe.lastResult = jaxe.gSystem.unloadAll();
        if (jaxe.lastResult == jaxe.FMOD.OK) {
            // Every async-loaded bank just died without passing through
            // fmod_bank_unload, so their MEMFS copies are deleted here
            for (const name of jaxe.asyncBankFiles.values()) {
                jaxe.unlinkMemfsFile(name);
            }
            jaxe.asyncBankFiles.clear();
            jaxe.sweepDeadLookups();
        }
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
        } else {
            jaxe.zeroFill(fbuf, 7);
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
        } else {
            jaxe.zeroFill(ibuf, 8);
            jaxe.zeroFill(fbuf, 2);
        }
        return jaxe.lastResult;
    }

    static fmod_sys_reset_buffer_usage() {
        if (!jaxe.sysReady()) return jaxe.lastResult;
        jaxe.lastResult = jaxe.gSystem.resetBufferUsage();
        return jaxe.lastResult;
    }

    // ibuf: [0]=exclusive [1]=inclusive [2]=sampledata. Not exposed by the
    // FMOD JS API, so this reports ERR_UNSUPPORTED
    static fmod_sys_get_memory_usage(ibuf) {
        if (!jaxe.sysReady()) return jaxe.lastResult;
        if (!jaxe.gSystem.getMemoryUsage) {
            ibuf[0] = 0; ibuf[1] = 0; ibuf[2] = 0;
            jaxe.lastResult = jaxe.ERR_UNSUPPORTED;
            return jaxe.lastResult;
        }
        var outval = {};
        jaxe.lastResult = jaxe.gSystem.getMemoryUsage(outval);
        if (jaxe.lastResult == jaxe.FMOD.OK && outval.val) {
            ibuf[0] = outval.val.exclusive | 0;
            ibuf[1] = outval.val.inclusive | 0;
            ibuf[2] = outval.val.sampledata | 0;
        } else {
            jaxe.zeroFill(ibuf, 3);
        }
        return jaxe.lastResult;
    }

    //// Bus

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
        if (!bus.getCPUUsage) {
            out[0] = 0; out[1] = 0;
            jaxe.lastResult = jaxe.ERR_UNSUPPORTED;
            return jaxe.lastResult;
        }
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
        if (!bus.getMemoryUsage) {
            out[0] = 0; out[1] = 0; out[2] = 0;
            jaxe.lastResult = jaxe.ERR_UNSUPPORTED;
            return jaxe.lastResult;
        }
        var outval = {};
        jaxe.lastResult = bus.getMemoryUsage(outval);
        if (jaxe.lastResult == jaxe.FMOD.OK && outval.val) {
            out[0] = outval.val.exclusive | 0;
            out[1] = outval.val.inclusive | 0;
            out[2] = outval.val.sampledata | 0;
        } else {
            // Error paths zero-fill on every target, so a wrapper reading
            // the scratch buffer never sees a previous call's values
            out[0] = 0;
            out[1] = 0;
            out[2] = 0;
        }
        return jaxe.lastResult;
    }

    //// VCA

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

    //// Bank

    // Resolves a bank handle for the fmod_bank_* functions, treating async
    // placeholders from fmod_sys_load_bank_async as not ready: sets
    // lastResult = 46 (ERR_NOTREADY) and returns null so callers never touch
    // a placeholder. bank_get_loading_state, bank_is_valid and bank_unload
    // special-case placeholders instead of using this helper.
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

    // real unload. Frees the bank handle on success. An async placeholder
    // (pending or errored) is cancelled instead: abort the fetch, clear the
    // timeout, free the handle, FMOD_OK - the bank never reached FMOD, so
    // there is nothing to unload there.
    static fmod_bank_unload(handle) {
        var pending = jaxe.handleResolve(handle, jaxe.TYPE_BANK);
        if (pending && pending.pendingBankPath) {
            pending.pendingBankCancelled = true;
            if (pending.pendingBankTimer != null) {
                clearTimeout(pending.pendingBankTimer);
                pending.pendingBankTimer = null;
            }
            if (pending.pendingBankController) pending.pendingBankController.abort();
            jaxe.handleFree(handle);
            jaxe.lastResult = jaxe.FMOD.OK;
            return jaxe.lastResult;
        }
        var bank = jaxe.resolveBankReady(handle);
        if (!bank) return jaxe.lastResult;
        // Unloading destroys the bank's event instances. Uninstall their
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
        var raw = jaxe.rawPtr(bank);
        jaxe.lastResult = bank.unload();
        if (jaxe.lastResult == jaxe.FMOD.OK) {
            // Async loads copied the bank into MEMFS. Delete the copy or
            // every load/unload cycle retains a full bank in memory.
            var memfsName = jaxe.asyncBankFiles.get(raw);
            if (memfsName) {
                jaxe.asyncBankFiles.delete(raw);
                jaxe.unlinkMemfsFile(memfsName);
            }
            jaxe.handleFree(handle);
            jaxe.sweepDeadLookups();
        }
        return jaxe.lastResult;
    }

    // Deleting is best-effort: a missing FS_unlink export or an already
    // removed file must not fail the unload
    static unlinkMemfsFile(name) {
        try {
            if (jaxe.FMOD.FS_unlink) jaxe.FMOD.FS_unlink('/' + name);
        } catch (e) {
        }
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

    // FMOD_STUDIO_LOADING_STATE. Invalid handle reports 1 (UNLOADED). async
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
        jaxe.lastResult = bank.getEventList(list, jaxe.LIST_MAX, count);
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
        jaxe.lastResult = bank.getBusList(list, jaxe.LIST_MAX, count);
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
        jaxe.lastResult = bank.getVCAList(list, jaxe.LIST_MAX, count);
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

    //// EventDescription

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
        } else {
            jaxe.zeroFill(fbuf, 2);
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

    // returns instance handle or 0. Stores the handle in FMOD userdata so
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

    // fills ibuf with instance handles. Instances the table has already seen
    // keep their handle, unseen ones (created outside this binding) get a
    // fresh handle stamped into their userdata for callback identification
    static fmod_evd_get_instance_list(handle, ibuf) {
        var evd = jaxe.handleResolve(handle, jaxe.TYPE_EVD);
        if (!evd) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var list = {};
        var count = {};
        jaxe.lastResult = evd.getInstanceList(list, jaxe.LIST_MAX, count);
        if (jaxe.lastResult != jaxe.FMOD.OK || !list.val) return 0;
        var n = count.val | 0;
        if (n > jaxe.LIST_MAX) n = jaxe.LIST_MAX;
        if (list.val.length < n) n = list.val.length;
        for (var i = 0; i < n; i++) {
            var eviHandle = jaxe.handleFindOrAlloc(list.val[i], jaxe.TYPE_EVI);
            if (eviHandle != 0) {
                // Stamp the handle whenever userdata disagrees, so re-minted
                // and alias-recycled instances route callbacks to the live
                // handle. (A liveCount delta cannot detect the alias path:
                // its free and alloc cancel out.)
                var ud = {};
                if (list.val[i].getUserData(ud) != jaxe.FMOD.OK || ud.val !== eviHandle) {
                    list.val[i].setUserData(eviHandle);
                }
            }
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
        // With no DESTROYED events on this target, the sweep is what
        // reclaims the destroyed instances' handle slots
        if (jaxe.lastResult == jaxe.FMOD.OK) jaxe.sweepDeadLookups();
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

    // returns param name. fbuf/ibuf layout documented on writeParamDesc
    static fmod_evd_get_parameter_description_by_index(handle, index, fbuf, ibuf) {
        var evd = jaxe.handleResolve(handle, jaxe.TYPE_EVD);
        if (!evd) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return ""; }
        var outval = {};
        jaxe.lastResult = evd.getParameterDescriptionByIndex(index, outval);
        if (jaxe.lastResult != jaxe.FMOD.OK) return "";
        return jaxe.writeParamDesc(outval, fbuf, ibuf);
    }

    static fmod_evd_get_parameter_description_by_name(handle, name, fbuf, ibuf) {
        if (typeof name !== "string") { jaxe.lastResult = jaxe.ERR_INVALID_PARAM; return ''; }
        var evd = jaxe.handleResolve(handle, jaxe.TYPE_EVD);
        if (!evd) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return ""; }
        var outval = {};
        jaxe.lastResult = evd.getParameterDescriptionByName(name, outval);
        if (jaxe.lastResult != jaxe.FMOD.OK) return "";
        return jaxe.writeParamDesc(outval, fbuf, ibuf);
    }

    // (paramName, labelIndex) -> label
    static fmod_evd_get_parameter_label(handle, name, labelIndex) {
        if (typeof name !== "string") { jaxe.lastResult = jaxe.ERR_INVALID_PARAM; return ''; }
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

    // Shared user property fetch. struct fields land directly on the out
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

    //// EventInstance

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
        // INVALID_HANDLE means FMOD already destroyed the instance (bank
        // unload, releaseAllInstances). The slot must still be reclaimed or
        // it leaks for the rest of the session.
        if (jaxe.lastResult == jaxe.FMOD.OK || jaxe.lastResult == jaxe.ERR_INVALID_HANDLE) {
            jaxe.handleFree(handle);
        }
        return jaxe.lastResult;
    }

    // FMOD_STUDIO_PLAYBACK_STATE. Invalid handle reports 2 (STOPPED)
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
        } else {
            jaxe.zeroFill(fbuf, 2);
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
        else jaxe.zeroFill(fbuf, 12);
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
        if (typeof name !== "string") { jaxe.lastResult = jaxe.ERR_INVALID_PARAM; return jaxe.lastResult; }
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0.0; }
        var value = {};
        jaxe.lastResult = inst.getParameterByName(name, value, null);
        return jaxe.lastResult == jaxe.FMOD.OK ? value.val : 0.0;
    }

    static fmod_evi_get_param_by_name_final(handle, name) {
        if (typeof name !== "string") { jaxe.lastResult = jaxe.ERR_INVALID_PARAM; return jaxe.lastResult; }
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0.0; }
        var value = {};
        var finalValue = {};
        jaxe.lastResult = inst.getParameterByName(name, value, finalValue);
        return jaxe.lastResult == jaxe.FMOD.OK ? finalValue.val : 0.0;
    }

    static fmod_evi_set_param_by_name(handle, name, value, ignoreSeekSpeed) {
        if (typeof name !== "string") { jaxe.lastResult = jaxe.ERR_INVALID_PARAM; return jaxe.lastResult; }
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = inst.setParameterByName(name, value, ignoreSeekSpeed);
        return jaxe.lastResult;
    }

    static fmod_evi_set_param_by_name_with_label(handle, name, label, ignoreSeekSpeed) {
        if (typeof name !== "string") { jaxe.lastResult = jaxe.ERR_INVALID_PARAM; return jaxe.lastResult; }
        if (typeof label !== "string") { jaxe.lastResult = jaxe.ERR_INVALID_PARAM; return jaxe.lastResult; }
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
        if (typeof label !== "string") { jaxe.lastResult = jaxe.ERR_INVALID_PARAM; return jaxe.lastResult; }
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = inst.setParameterByIDWithLabel(jaxe.paramId(id1, id2), label, ignoreSeekSpeed);
        return jaxe.lastResult;
    }

    // ibuf: [0]=exclusive [1]=inclusive us. Not exposed by the FMOD JS API,
    // so this reports ERR_UNSUPPORTED
    static fmod_evi_get_cpu_usage(handle, ibuf) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        if (!inst.getCPUUsage) {
            ibuf[0] = 0; ibuf[1] = 0;
            jaxe.lastResult = jaxe.ERR_UNSUPPORTED;
            return jaxe.lastResult;
        }
        var exclusive = {};
        var inclusive = {};
        jaxe.lastResult = inst.getCPUUsage(exclusive, inclusive);
        ibuf[0] = exclusive.val | 0;
        ibuf[1] = inclusive.val | 0;
        return jaxe.lastResult;
    }

    // ibuf: [0]=exclusive [1]=inclusive [2]=sampledata. Not exposed by the
    // FMOD JS API, so this reports ERR_UNSUPPORTED
    static fmod_evi_get_memory_usage(handle, ibuf) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        if (!inst.getMemoryUsage) {
            ibuf[0] = 0; ibuf[1] = 0; ibuf[2] = 0;
            jaxe.lastResult = jaxe.ERR_UNSUPPORTED;
            return jaxe.lastResult;
        }
        var outval = {};
        jaxe.lastResult = inst.getMemoryUsage(outval);
        if (jaxe.lastResult == jaxe.FMOD.OK && outval.val) {
            ibuf[0] = outval.val.exclusive | 0;
            ibuf[1] = outval.val.inclusive | 0;
            ibuf[2] = outval.val.sampledata | 0;
        } else {
            jaxe.zeroFill(ibuf, 3);
        }
        return jaxe.lastResult;
    }

    //// Programmer sounds

    static fmod_ps_assign(handle, key) {
        if (typeof key !== "string") { jaxe.lastResult = jaxe.ERR_INVALID_PARAM; return jaxe.lastResult; }
        // Native stores keys in a 512-byte buffer (FAXE_PS_KEY_MAX) and
        // rejects longer ones. Reject here too, measured in UTF-8 bytes,
        // so a key that works on html5 also works native.
        if (jaxe.utf8ByteLength(key) >= 512) { jaxe.lastResult = jaxe.ERR_INVALID_PARAM; return jaxe.lastResult; }
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
        if (typeof path !== "string") { jaxe.lastResult = jaxe.ERR_INVALID_PARAM; return 0; }
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

    //// Core PCM streams (user-generated audio)

    // The JS mirror of the native ring contract. Single-threaded, so plain
    // fields need no locking. The pcmread callback drains it and pads a
    // shortfall with silence, counting the underrun.
    static pcmRingRead(ring, dataPtr, datalen) {
        var have = ring.fill < datalen ? ring.fill : datalen;
        var heap = jaxe.FMOD.HEAPU8;
        var first = ring.buf.length - ring.readPos;
        if (first > have) first = have;
        heap.set(ring.buf.subarray(ring.readPos, ring.readPos + first), dataPtr);
        if (have > first) heap.set(ring.buf.subarray(0, have - first), dataPtr + first);
        ring.readPos = (ring.readPos + have) % ring.buf.length;
        ring.fill -= have;
        if (have < datalen) {
            heap.fill(0, dataPtr + have, dataPtr + datalen);
            ring.underruns++;
        }
        return have;
    }

    static fmod_core_pcm_create(sampleRate, channels, ringBytes) {
        if (!jaxe.FmodIsInitialized) { jaxe.lastResult = jaxe.ERR_STUDIO_UNINITIALIZED; return 0; }
        if (sampleRate <= 0 || channels < 1 || channels > 2 || ringBytes <= 0) {
            jaxe.lastResult = jaxe.ERR_INVALID_PARAM;
            return 0;
        }
        var ring = {
            buf: new Uint8Array(ringBytes),
            readPos: 0,
            writePos: 0,
            fill: 0,
            underruns: 0,
        };
        var exinfo = jaxe.FMOD.CREATESOUNDEXINFO();
        exinfo.numchannels = channels;
        exinfo.defaultfrequency = sampleRate;
        exinfo.format = jaxe.FMOD.SOUND_FORMAT_PCM16;
        exinfo.decodebuffersize = 4096;
        exinfo.length = sampleRate * channels * 2; // a one second window
        exinfo.pcmreadcallback = function (sound, data, datalen) {
            jaxe.pcmRingRead(ring, data, datalen);
            return jaxe.FMOD.OK;
        };
        var soundOut = {};
        jaxe.lastResult = jaxe.gSystemCore.createSound('',
            (jaxe.FMOD.OPENUSER | jaxe.FMOD.LOOP_NORMAL | jaxe.FMOD.CREATESTREAM) >>> 0,
            exinfo, soundOut);
        if (jaxe.lastResult != jaxe.FMOD.OK || !soundOut.val) return 0;
        var ps = { sound: soundOut.val, ring: ring };
        var handle = jaxe.handleAlloc(ps, jaxe.TYPE_PCM);
        if (handle == 0) {
            soundOut.val.release();
            return 0;
        }
        return handle;
    }

    static fmod_core_pcm_create_3d(sampleRate, channels, ringBytes) {
        if (!jaxe.FmodIsInitialized) { jaxe.lastResult = jaxe.ERR_STUDIO_UNINITIALIZED; return 0; }
        if (sampleRate <= 0 || channels < 1 || channels > 2 || ringBytes <= 0) {
            jaxe.lastResult = jaxe.ERR_INVALID_PARAM;
            return 0;
        }
        var ring = {
            buf: new Uint8Array(ringBytes),
            readPos: 0,
            writePos: 0,
            fill: 0,
            underruns: 0,
        };
        var exinfo = jaxe.FMOD.CREATESOUNDEXINFO();
        exinfo.numchannels = channels;
        exinfo.defaultfrequency = sampleRate;
        exinfo.format = jaxe.FMOD.SOUND_FORMAT_PCM16;
        exinfo.decodebuffersize = 4096;
        exinfo.length = sampleRate * channels * 2; // a one second window
        exinfo.pcmreadcallback = function (sound, data, datalen) {
            jaxe.pcmRingRead(ring, data, datalen);
            return jaxe.FMOD.OK;
        };
        var soundOut = {};
        jaxe.lastResult = jaxe.gSystemCore.createSound('',
            (jaxe.FMOD.OPENUSER | jaxe.FMOD.LOOP_NORMAL | jaxe.FMOD.CREATESTREAM | jaxe.FMOD._3D) >>> 0,
            exinfo, soundOut);
        if (jaxe.lastResult != jaxe.FMOD.OK || !soundOut.val) return 0;
        var ps = { sound: soundOut.val, ring: ring };
        var handle = jaxe.handleAlloc(ps, jaxe.TYPE_PCM);
        if (handle == 0) {
            soundOut.val.release();
            return 0;
        }
        return handle;
    }

    static fmod_core_pcm_write(handle, data, len) {
        var ps = jaxe.handleResolve(handle, jaxe.TYPE_PCM);
        if (!ps) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        if (!data || len <= 0) { jaxe.lastResult = jaxe.ERR_INVALID_PARAM; return 0; }
        var src = new Uint8Array(data, 0, Math.min(len, data.byteLength));
        var ring = ps.ring;
        var space = ring.buf.length - ring.fill;
        var n = src.length < space ? src.length : space;
        var first = ring.buf.length - ring.writePos;
        if (first > n) first = n;
        ring.buf.set(src.subarray(0, first), ring.writePos);
        if (n > first) ring.buf.set(src.subarray(first, n), 0);
        ring.writePos = (ring.writePos + n) % ring.buf.length;
        ring.fill += n;
        jaxe.lastResult = jaxe.FMOD.OK;
        return n;
    }

    static fmod_core_pcm_space(handle) {
        var ps = jaxe.handleResolve(handle, jaxe.TYPE_PCM);
        if (!ps) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        return ps.ring.buf.length - ps.ring.fill;
    }

    static fmod_core_pcm_underruns(handle) {
        var ps = jaxe.handleResolve(handle, jaxe.TYPE_PCM);
        if (!ps) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var n = ps.ring.underruns;
        ps.ring.underruns = 0;
        return n;
    }

    static fmod_core_pcm_play(handle, paused) {
        var ps = jaxe.handleResolve(handle, jaxe.TYPE_PCM);
        if (!ps) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var chOut = {};
        jaxe.lastResult = jaxe.gSystemCore.playSound(ps.sound, null, !!paused, chOut);
        if (jaxe.lastResult != jaxe.FMOD.OK || !chOut.val) return 0;
        var ch = jaxe.handleAlloc(chOut.val, jaxe.TYPE_CHAN);
        if (ch == 0) {
            chOut.val.stop();
            return 0;
        }
        return ch;
    }

    static fmod_core_pcm_release(handle) {
        var ps = jaxe.handleResolve(handle, jaxe.TYPE_PCM);
        if (!ps) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = ps.sound.release();
        if (jaxe.lastResult != jaxe.FMOD.OK) return jaxe.lastResult;
        ps.ring = null;
        jaxe.handleFree(handle);
        return jaxe.lastResult;
    }

    //// Core channels

    static resolveChan(handle) {
        return jaxe.handleResolve(handle, jaxe.TYPE_CHAN);
    }

    static fmod_chan_set_volume(handle, volume) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = ch.setVolume(volume);
        return jaxe.lastResult;
    }

    static fmod_chan_get_volume(handle) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0.0; }
        var out = {};
        jaxe.lastResult = ch.getVolume(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? out.val : 0.0;
    }

    static fmod_chan_set_pitch(handle, pitch) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = ch.setPitch(pitch);
        return jaxe.lastResult;
    }

    static fmod_chan_get_pitch(handle) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0.0; }
        var out = {};
        jaxe.lastResult = ch.getPitch(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? out.val : 0.0;
    }

    static fmod_chan_set_paused(handle, paused) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = ch.setPaused(!!paused);
        return jaxe.lastResult;
    }

    static fmod_chan_get_paused(handle) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return false; }
        var out = {};
        jaxe.lastResult = ch.getPaused(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? !!out.val : false;
    }

    static fmod_chan_is_playing(handle) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return false; }
        var out = {};
        jaxe.lastResult = ch.isPlaying(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? !!out.val : false;
    }

    static fmod_chan_stop(handle) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        // The channel is finished either way, so the slot is freed even
        // when FMOD reports the channel already gone. The map entry goes
        // first: the glue fires the END callback synchronously inside
        // stop(), which would otherwise enqueue an event for the handle
        // this call is about to free.
        jaxe.chanCallbackHandles.delete(jaxe.rawPtr(ch));
        jaxe.lastResult = ch.stop();
        jaxe.handleFree(handle);
        // Stopping tears down the channel's DSP chain, which destroys its
        // connection objects
        jaxe.freeAllOfType(jaxe.TYPE_DSPCONN);
        return jaxe.lastResult;
    }

    //// Core DSP effects

    static resolveDsp(handle) {
        return jaxe.handleResolve(handle, jaxe.TYPE_DSP);
    }

    static resolveCg(handle) {
        return jaxe.handleResolve(handle, jaxe.TYPE_CHANGROUP);
    }

    static fmod_dsp_create_by_type(type) {
        if (!jaxe.FmodIsInitialized) { jaxe.lastResult = jaxe.ERR_STUDIO_UNINITIALIZED; return 0; }
        var out = {};
        jaxe.lastResult = jaxe.gSystemCore.createDSPByType(type, out);
        if (jaxe.lastResult != jaxe.FMOD.OK || !out.val) return 0;
        var handle = jaxe.handleAlloc(out.val, jaxe.TYPE_DSP);
        if (handle == 0) {
            out.val.release();
            return 0;
        }
        return handle;
    }

    static fmod_dsp_release(handle) {
        var dsp = jaxe.resolveDsp(handle);
        if (!dsp) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = dsp.release();
        if (jaxe.lastResult == jaxe.FMOD.OK) {
            jaxe.handleFree(handle);
            // Releasing a DSP tears down its connections
            jaxe.freeAllOfType(jaxe.TYPE_DSPCONN);
        }
        return jaxe.lastResult;
    }

    static fmod_dsp_set_param_float(handle, index, value) {
        var dsp = jaxe.resolveDsp(handle);
        if (!dsp) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = dsp.setParameterFloat(index, value);
        return jaxe.lastResult;
    }

    static fmod_dsp_get_param_float(handle, index) {
        var dsp = jaxe.resolveDsp(handle);
        if (!dsp) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0.0; }
        var out = {};
        // embind drops the valuestr length arg: (index, valueOut, valuestrOut)
        jaxe.lastResult = dsp.getParameterFloat(index, out, null);
        return jaxe.lastResult == jaxe.FMOD.OK ? out.val : 0.0;
    }

    static fmod_dsp_set_param_int(handle, index, value) {
        var dsp = jaxe.resolveDsp(handle);
        if (!dsp) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = dsp.setParameterInt(index, value);
        return jaxe.lastResult;
    }

    static fmod_dsp_get_param_int(handle, index) {
        var dsp = jaxe.resolveDsp(handle);
        if (!dsp) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var out = {};
        jaxe.lastResult = dsp.getParameterInt(index, out, null);
        return jaxe.lastResult == jaxe.FMOD.OK ? out.val : 0;
    }

    static fmod_dsp_set_param_bool(handle, index, value) {
        var dsp = jaxe.resolveDsp(handle);
        if (!dsp) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = dsp.setParameterBool(index, !!value);
        return jaxe.lastResult;
    }

    static fmod_dsp_get_param_bool(handle, index) {
        var dsp = jaxe.resolveDsp(handle);
        if (!dsp) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return false; }
        var out = {};
        jaxe.lastResult = dsp.getParameterBool(index, out, null);
        return jaxe.lastResult == jaxe.FMOD.OK ? !!out.val : false;
    }

    static fmod_dsp_get_num_params(handle) {
        var dsp = jaxe.resolveDsp(handle);
        if (!dsp) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var out = {};
        jaxe.lastResult = dsp.getNumParameters(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? out.val : 0;
    }

    static fmod_dsp_get_type(handle) {
        var dsp = jaxe.resolveDsp(handle);
        if (!dsp) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var out = {};
        jaxe.lastResult = dsp.getType(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? out.val : 0;
    }

    static fmod_dsp_set_bypass(handle, bypass) {
        var dsp = jaxe.resolveDsp(handle);
        if (!dsp) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = dsp.setBypass(!!bypass);
        return jaxe.lastResult;
    }

    static fmod_dsp_get_bypass(handle) {
        var dsp = jaxe.resolveDsp(handle);
        if (!dsp) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return false; }
        var out = {};
        jaxe.lastResult = dsp.getBypass(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? !!out.val : false;
    }

    static fmod_dsp_set_wet_dry_mix(handle, prewet, postwet, dry) {
        var dsp = jaxe.resolveDsp(handle);
        if (!dsp) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = dsp.setWetDryMix(prewet, postwet, dry);
        return jaxe.lastResult;
    }

    static fmod_dsp_set_active(handle, active) {
        var dsp = jaxe.resolveDsp(handle);
        if (!dsp) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = dsp.setActive(!!active);
        return jaxe.lastResult;
    }

    static fmod_dsp_reset(handle) {
        var dsp = jaxe.resolveDsp(handle);
        if (!dsp) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = dsp.reset();
        return jaxe.lastResult;
    }

    static fmod_dsp_set_metering_enabled(handle, input, output) {
        var dsp = jaxe.resolveDsp(handle);
        if (!dsp) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = dsp.setMeteringEnabled(!!input, !!output);
        return jaxe.lastResult;
    }

    // fbuf = [0..ch-1] output peak, [ch..2ch-1] output rms. Returns channel count.
    static fmod_dsp_get_metering(handle, fbuf) {
        var dsp = jaxe.resolveDsp(handle);
        if (!dsp) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        // The embind binding writes into pre-shaped array fields only
        var inInfo = { peaklevel: [], rmslevel: [] };
        var outInfo = { peaklevel: [], rmslevel: [] };
        jaxe.lastResult = dsp.getMeteringInfo(inInfo, outInfo);
        if (jaxe.lastResult != jaxe.FMOD.OK) return 0;
        var ch = outInfo.numchannels || outInfo.peaklevel.length;
        if (ch > 32) ch = 32;
        for (var i = 0; i < ch; i++) {
            fbuf[i] = outInfo.peaklevel[i] || 0;
            fbuf[ch + i] = outInfo.rmslevel[i] || 0;
        }
        return ch;
    }

    // fbuf = channel-0 spectrum magnitudes, capped at maxBins. Returns bins written.
    static fmod_dsp_fft_get_spectrum(handle, fbuf, maxBins) {
        var dsp = jaxe.resolveDsp(handle);
        if (!dsp) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        // 2.03 SPECTRUMDATA index is 4. The struct lands as flat keys on
        // the out object (length, numchannels, spectrum[]).
        var out = {};
        jaxe.lastResult = dsp.getParameterData(4, out, null, null);
        if (jaxe.lastResult != jaxe.FMOD.OK || !out.spectrum || !out.spectrum[0]) return 0;
        var spec = out.spectrum[0];
        var count = spec.length < maxBins ? spec.length : maxBins;
        for (var i = 0; i < count; i++) fbuf[i] = spec[i];
        return count;
    }

    //// Core channel groups

    static fmod_cg_get_master() {
        if (!jaxe.FmodIsInitialized) { jaxe.lastResult = jaxe.ERR_STUDIO_UNINITIALIZED; return 0; }
        var out = {};
        jaxe.lastResult = jaxe.gSystemCore.getMasterChannelGroup(out);
        if (jaxe.lastResult != jaxe.FMOD.OK || !out.val) return 0;
        return jaxe.handleFindOrAlloc(out.val, jaxe.TYPE_CHANGROUP);
    }

    static fmod_cg_create(name) {
        if (typeof name !== "string") { jaxe.lastResult = jaxe.ERR_INVALID_PARAM; return 0; }
        if (!jaxe.FmodIsInitialized) { jaxe.lastResult = jaxe.ERR_STUDIO_UNINITIALIZED; return 0; }
        var out = {};
        jaxe.lastResult = jaxe.gSystemCore.createChannelGroup(name, out);
        if (jaxe.lastResult != jaxe.FMOD.OK || !out.val) return 0;
        var handle = jaxe.handleAlloc(out.val, jaxe.TYPE_CHANGROUP);
        if (handle == 0) {
            out.val.release();
            return 0;
        }
        return handle;
    }

    static fmod_cg_release(handle) {
        var group = jaxe.resolveCg(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = group.release();
        if (jaxe.lastResult == jaxe.FMOD.OK) {
            jaxe.handleFree(handle);
            // Releasing the group destroys the connections of every DSP in it
            jaxe.freeAllOfType(jaxe.TYPE_DSPCONN);
        }
        return jaxe.lastResult;
    }

    static fmod_cg_set_volume(handle, volume) {
        var group = jaxe.resolveCg(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = group.setVolume(volume);
        return jaxe.lastResult;
    }

    static fmod_cg_get_volume(handle) {
        var group = jaxe.resolveCg(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0.0; }
        var out = {};
        jaxe.lastResult = group.getVolume(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? out.val : 0.0;
    }

    static fmod_cg_set_pitch(handle, pitch) {
        var group = jaxe.resolveCg(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = group.setPitch(pitch);
        return jaxe.lastResult;
    }

    static fmod_cg_get_pitch(handle) {
        var group = jaxe.resolveCg(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0.0; }
        var out = {};
        jaxe.lastResult = group.getPitch(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? out.val : 0.0;
    }

    static fmod_cg_set_mute(handle, mute) {
        var group = jaxe.resolveCg(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = group.setMute(!!mute);
        return jaxe.lastResult;
    }

    static fmod_cg_get_mute(handle) {
        var group = jaxe.resolveCg(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return false; }
        var out = {};
        jaxe.lastResult = group.getMute(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? !!out.val : false;
    }

    static fmod_cg_set_paused(handle, paused) {
        var group = jaxe.resolveCg(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = group.setPaused(!!paused);
        return jaxe.lastResult;
    }

    static fmod_cg_get_paused(handle) {
        var group = jaxe.resolveCg(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return false; }
        var out = {};
        jaxe.lastResult = group.getPaused(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? !!out.val : false;
    }

    static fmod_cg_add_dsp(handle, index, dspHandle) {
        var group = jaxe.resolveCg(handle);
        var dsp = jaxe.resolveDsp(dspHandle);
        if (!group || !dsp) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = group.addDSP(index, dsp);
        return jaxe.lastResult;
    }

    static fmod_cg_remove_dsp(handle, dspHandle) {
        var group = jaxe.resolveCg(handle);
        var dsp = jaxe.resolveDsp(dspHandle);
        if (!group || !dsp) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = group.removeDSP(dsp);
        // Removing a DSP rebuilds that part of the graph and destroys the
        // affected connection objects
        if (jaxe.lastResult == jaxe.FMOD.OK) jaxe.freeAllOfType(jaxe.TYPE_DSPCONN);
        return jaxe.lastResult;
    }

    static fmod_cg_stop(handle) {
        var group = jaxe.resolveCg(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = group.stop();
        return jaxe.lastResult;
    }

    //// Core channel routing and effects

    static fmod_chan_set_pan(handle, pan) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = ch.setPan(pan);
        return jaxe.lastResult;
    }

    static fmod_chan_set_frequency(handle, frequency) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = ch.setFrequency(frequency);
        return jaxe.lastResult;
    }

    static fmod_chan_get_frequency(handle) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0.0; }
        var out = {};
        jaxe.lastResult = ch.getFrequency(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? out.val : 0.0;
    }

    static fmod_chan_set_loop_count(handle, loopCount) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = ch.setLoopCount(loopCount);
        return jaxe.lastResult;
    }

    static fmod_chan_get_position(handle) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return -1; }
        var out = {};
        jaxe.lastResult = ch.getPosition(out, jaxe.FMOD.TIMEUNIT_MS);
        return jaxe.lastResult == jaxe.FMOD.OK ? out.val : -1;
    }

    static fmod_chan_set_position(handle, positionMs) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = ch.setPosition(positionMs, jaxe.FMOD.TIMEUNIT_MS);
        return jaxe.lastResult;
    }

    static fmod_chan_set_channel_group(handle, groupHandle) {
        var ch = jaxe.resolveChan(handle);
        var group = jaxe.resolveCg(groupHandle);
        if (!ch || !group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = ch.setChannelGroup(group);
        return jaxe.lastResult;
    }

    static fmod_chan_add_dsp(handle, index, dspHandle) {
        var ch = jaxe.resolveChan(handle);
        var dsp = jaxe.resolveDsp(dspHandle);
        if (!ch || !dsp) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = ch.addDSP(index, dsp);
        return jaxe.lastResult;
    }

    static fmod_chan_remove_dsp(handle, dspHandle) {
        var ch = jaxe.resolveChan(handle);
        var dsp = jaxe.resolveDsp(dspHandle);
        if (!ch || !dsp) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = ch.removeDSP(dsp);
        // Removing a DSP rebuilds that part of the graph and destroys the
        // affected connection objects
        if (jaxe.lastResult == jaxe.FMOD.OK) jaxe.freeAllOfType(jaxe.TYPE_DSPCONN);
        return jaxe.lastResult;
    }

    static fmod_chan_set_3d_attributes(handle, posX, posY, posZ, velX, velY, velZ) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = ch.set3DAttributes(
            { x: posX, y: posY, z: posZ }, { x: velX, y: velY, z: velZ });
        return jaxe.lastResult;
    }

    static fmod_chan_set_3d_min_max(handle, minDist, maxDist) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = ch.set3DMinMaxDistance(minDist, maxDist);
        return jaxe.lastResult;
    }

    static fmod_chan_set_reverb_wet(handle, instance, wet) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = ch.setReverbProperties(instance, wet);
        return jaxe.lastResult;
    }

    //// Studio bus to core group bridge

    static fmod_bus_lock_channel_group(handle) {
        var bus = jaxe.handleResolve(handle, jaxe.TYPE_BUS);
        if (!bus) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = bus.lockChannelGroup();
        // The group is created on the async command queue. Flushing makes
        // it resolvable before the matching fmod_bus_get_channel_group.
        if (jaxe.lastResult == jaxe.FMOD.OK && jaxe.gSystem) jaxe.gSystem.flushCommands();
        return jaxe.lastResult;
    }

    static fmod_bus_unlock_channel_group(handle) {
        var bus = jaxe.handleResolve(handle, jaxe.TYPE_BUS);
        if (!bus) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = bus.unlockChannelGroup();
        // The group may be destroyed once unlocked: reclaim its cached
        // handle before a recycled address can alias it
        if (jaxe.lastResult == jaxe.FMOD.OK) jaxe.sweepDeadLookups();
        return jaxe.lastResult;
    }

    static fmod_bus_get_channel_group(handle) {
        var bus = jaxe.handleResolve(handle, jaxe.TYPE_BUS);
        if (!bus) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var out = {};
        jaxe.lastResult = bus.getChannelGroup(out);
        if (jaxe.lastResult != jaxe.FMOD.OK || !out.val) return 0;
        return jaxe.handleFindOrAlloc(out.val, jaxe.TYPE_CHANGROUP);
    }

    //// Core system extras

    static fmod_sys_play_dsp(dspHandle, startPaused) {
        var dsp = jaxe.resolveDsp(dspHandle);
        if (!dsp) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var out = {};
        jaxe.lastResult = jaxe.gSystemCore.playDSP(dsp, null, !!startPaused, out);
        if (jaxe.lastResult != jaxe.FMOD.OK || !out.val) return 0;
        var handle = jaxe.handleAlloc(out.val, jaxe.TYPE_CHAN);
        if (handle == 0) {
            out.val.stop();
            return 0;
        }
        return handle;
    }

    // Reverb property structs cross the boundary as 12 floats in
    // fmod_common.h field order (DecayTime .. WetLevel)
    static REVERB_FIELDS = ['DecayTime', 'EarlyDelay', 'LateDelay', 'HFReference',
        'HFDecayRatio', 'Diffusion', 'Density', 'LowShelfFrequency',
        'LowShelfGain', 'HighCut', 'EarlyLateMix', 'WetLevel'];

    static fmod_sys_set_reverb_properties(instance, fbuf) {
        if (!jaxe.FmodIsInitialized) { jaxe.lastResult = jaxe.ERR_STUDIO_UNINITIALIZED; return jaxe.lastResult; }
        var props = {};
        for (var i = 0; i < jaxe.REVERB_FIELDS.length; i++) props[jaxe.REVERB_FIELDS[i]] = fbuf[i];
        jaxe.lastResult = jaxe.gSystemCore.setReverbProperties(instance, props);
        return jaxe.lastResult;
    }

    static fmod_sys_get_reverb_properties(instance, fbuf) {
        if (!jaxe.FmodIsInitialized) { jaxe.lastResult = jaxe.ERR_STUDIO_UNINITIALIZED; return jaxe.lastResult; }
        // The binding writes the fields flat onto the out object
        var out = {};
        jaxe.lastResult = jaxe.gSystemCore.getReverbProperties(instance, out);
        if (jaxe.lastResult != jaxe.FMOD.OK) return jaxe.lastResult;
        for (var i = 0; i < jaxe.REVERB_FIELDS.length; i++) fbuf[i] = out[jaxe.REVERB_FIELDS[i]] || 0;
        return jaxe.lastResult;
    }

    //// Core DSP connection graph

    static resolveDspConn(handle) {
        return jaxe.handleResolve(handle, jaxe.TYPE_DSPCONN);
    }

    static fmod_dsp_add_input(handle, inputHandle, type) {
        var dsp = jaxe.resolveDsp(handle);
        var input = jaxe.resolveDsp(inputHandle);
        if (!dsp || !input) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var out = {};
        jaxe.lastResult = dsp.addInput(input, out, type);
        if (jaxe.lastResult != jaxe.FMOD.OK || !out.val) return 0;
        return jaxe.handleFindOrAlloc(out.val, jaxe.TYPE_DSPCONN);
    }

    static fmod_dsp_disconnect_from(handle, inputHandle) {
        var dsp = jaxe.resolveDsp(handle);
        var input = jaxe.resolveDsp(inputHandle);
        if (!dsp || !input) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = dsp.disconnectFrom(input, null);
        if (jaxe.lastResult == jaxe.FMOD.OK) jaxe.freeAllOfType(jaxe.TYPE_DSPCONN);
        return jaxe.lastResult;
    }

    static fmod_dsp_disconnect_all(handle, inputs, outputs) {
        var dsp = jaxe.resolveDsp(handle);
        if (!dsp) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = dsp.disconnectAll(!!inputs, !!outputs);
        if (jaxe.lastResult == jaxe.FMOD.OK) jaxe.freeAllOfType(jaxe.TYPE_DSPCONN);
        return jaxe.lastResult;
    }

    static fmod_dsp_get_num_inputs(handle) {
        var dsp = jaxe.resolveDsp(handle);
        if (!dsp) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var out = {};
        jaxe.lastResult = dsp.getNumInputs(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? out.val : 0;
    }

    static fmod_dsp_get_num_outputs(handle) {
        var dsp = jaxe.resolveDsp(handle);
        if (!dsp) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var out = {};
        jaxe.lastResult = dsp.getNumOutputs(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? out.val : 0;
    }

    static fmod_dsp_get_input_dsp(handle, index) {
        var dsp = jaxe.resolveDsp(handle);
        if (!dsp) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var dspOut = {};
        var connOut = {};
        jaxe.lastResult = dsp.getInput(index, dspOut, connOut);
        if (jaxe.lastResult != jaxe.FMOD.OK || !dspOut.val) return 0;
        return jaxe.handleFindOrAlloc(dspOut.val, jaxe.TYPE_DSP);
    }

    static fmod_dsp_get_input_connection(handle, index) {
        var dsp = jaxe.resolveDsp(handle);
        if (!dsp) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var dspOut = {};
        var connOut = {};
        jaxe.lastResult = dsp.getInput(index, dspOut, connOut);
        if (jaxe.lastResult != jaxe.FMOD.OK || !connOut.val) return 0;
        return jaxe.handleFindOrAlloc(connOut.val, jaxe.TYPE_DSPCONN);
    }

    static fmod_dspconn_set_mix(handle, mix) {
        var conn = jaxe.resolveDspConn(handle);
        if (!conn) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = conn.setMix(mix);
        return jaxe.lastResult;
    }

    static fmod_dspconn_get_mix(handle) {
        var conn = jaxe.resolveDspConn(handle);
        if (!conn) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0.0; }
        var out = {};
        jaxe.lastResult = conn.getMix(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? out.val : 0.0;
    }

    static fmod_dspconn_get_type(handle) {
        var conn = jaxe.resolveDspConn(handle);
        if (!conn) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var out = {};
        jaxe.lastResult = conn.getType(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? out.val : 0;
    }

    //// Core channel group nesting

    static fmod_cg_add_group(handle, childHandle) {
        var group = jaxe.resolveCg(handle);
        var child = jaxe.resolveCg(childHandle);
        if (!group || !child) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = group.addGroup(child, true, {});
        return jaxe.lastResult;
    }

    static fmod_cg_get_num_groups(handle) {
        var group = jaxe.resolveCg(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var out = {};
        jaxe.lastResult = group.getNumGroups(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? out.val : 0;
    }

    static fmod_cg_get_group(handle, index) {
        var group = jaxe.resolveCg(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var out = {};
        jaxe.lastResult = group.getGroup(index, out);
        if (jaxe.lastResult != jaxe.FMOD.OK || !out.val) return 0;
        return jaxe.handleFindOrAlloc(out.val, jaxe.TYPE_CHANGROUP);
    }

    static fmod_cg_get_parent_group(handle) {
        var group = jaxe.resolveCg(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var out = {};
        jaxe.lastResult = group.getParentGroup(out);
        if (jaxe.lastResult != jaxe.FMOD.OK || !out.val) return 0;
        return jaxe.handleFindOrAlloc(out.val, jaxe.TYPE_CHANGROUP);
    }

    //// Core channel spatial and control extras

    static fmod_chan_set_mute(handle, mute) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = ch.setMute(!!mute);
        return jaxe.lastResult;
    }

    static fmod_chan_get_mute(handle) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return false; }
        var out = {};
        jaxe.lastResult = ch.getMute(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? !!out.val : false;
    }

    static fmod_chan_set_low_pass_gain(handle, gain) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = ch.setLowPassGain(gain);
        return jaxe.lastResult;
    }

    static fmod_chan_set_mode(handle, mode) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = ch.setMode(mode >>> 0);
        return jaxe.lastResult;
    }

    static fmod_chan_set_3d_cone_settings(handle, insideAngle, outsideAngle, outsideVolume) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = ch.set3DConeSettings(insideAngle, outsideAngle, outsideVolume);
        return jaxe.lastResult;
    }

    static fmod_chan_set_3d_cone_orientation(handle, x, y, z) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = ch.set3DConeOrientation({ x: x, y: y, z: z });
        return jaxe.lastResult;
    }

    static fmod_chan_set_3d_occlusion(handle, direct, reverb) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = ch.set3DOcclusion(direct, reverb);
        return jaxe.lastResult;
    }

    static fmod_chan_get_3d_occlusion(handle, fbuf) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        var direct = {};
        var reverb = {};
        jaxe.lastResult = ch.get3DOcclusion(direct, reverb);
        fbuf[0] = direct.val || 0;
        fbuf[1] = reverb.val || 0;
        return jaxe.lastResult;
    }

    static fmod_chan_set_3d_spread(handle, angle) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = ch.set3DSpread(angle);
        return jaxe.lastResult;
    }

    static fmod_chan_set_3d_level(handle, level) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = ch.set3DLevel(level);
        return jaxe.lastResult;
    }

    static fmod_chan_set_3d_doppler_level(handle, level) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = ch.set3DDopplerLevel(level);
        return jaxe.lastResult;
    }

    static fmod_chan_set_mix_matrix(handle, fbuf, outChannels, inChannels) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        var total = outChannels * inChannels;
        if (total < 0 || total > 32 * 32) { jaxe.lastResult = jaxe.ERR_INVALID_PARAM; return jaxe.lastResult; }
        var matrix = [];
        for (var i = 0; i < total; i++) matrix.push(fbuf[i] || 0);
        jaxe.lastResult = ch.setMixMatrix(matrix, outChannels, inChannels, 0);
        return jaxe.lastResult;
    }

    //// Core scheduling (DSP clocks cross as doubles: exact to 2^53 samples)

    static fmod_chan_get_dsp_clock(handle, fbuf) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        var clock = {};
        var parent = {};
        jaxe.lastResult = ch.getDSPClock(clock, parent);
        fbuf[0] = clock.val || 0;
        fbuf[1] = parent.val || 0;
        return jaxe.lastResult;
    }

    static fmod_chan_set_delay(handle, startClock, endClock, stopChannels) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = ch.setDelay(startClock, endClock, !!stopChannels);
        return jaxe.lastResult;
    }

    static fmod_chan_add_fade_point(handle, clock, volume) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = ch.addFadePoint(clock, volume);
        return jaxe.lastResult;
    }

    static fmod_chan_set_fade_point_ramp(handle, clock, volume) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = ch.setFadePointRamp(clock, volume);
        return jaxe.lastResult;
    }

    static fmod_chan_remove_fade_points(handle, startClock, endClock) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = ch.removeFadePoints(startClock, endClock);
        return jaxe.lastResult;
    }

    static fmod_cg_get_dsp_clock(handle, fbuf) {
        var group = jaxe.resolveCg(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        var clock = {};
        var parent = {};
        jaxe.lastResult = group.getDSPClock(clock, parent);
        fbuf[0] = clock.val || 0;
        fbuf[1] = parent.val || 0;
        return jaxe.lastResult;
    }

    static fmod_cg_set_delay(handle, startClock, endClock, stopChannels) {
        var group = jaxe.resolveCg(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = group.setDelay(startClock, endClock, !!stopChannels);
        return jaxe.lastResult;
    }

    static fmod_cg_add_fade_point(handle, clock, volume) {
        var group = jaxe.resolveCg(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = group.addFadePoint(clock, volume);
        return jaxe.lastResult;
    }

    static fmod_cg_set_fade_point_ramp(handle, clock, volume) {
        var group = jaxe.resolveCg(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = group.setFadePointRamp(clock, volume);
        return jaxe.lastResult;
    }

    static fmod_cg_remove_fade_points(handle, startClock, endClock) {
        var group = jaxe.resolveCg(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = group.removeFadePoints(startClock, endClock);
        return jaxe.lastResult;
    }

    //// Core reverb zones

    static resolveReverb3d(handle) {
        return jaxe.handleResolve(handle, jaxe.TYPE_REVERB3D);
    }

    static fmod_sys_create_reverb3d() {
        if (!jaxe.FmodIsInitialized) { jaxe.lastResult = jaxe.ERR_STUDIO_UNINITIALIZED; return 0; }
        var out = {};
        jaxe.lastResult = jaxe.gSystemCore.createReverb3D(out);
        if (jaxe.lastResult != jaxe.FMOD.OK || !out.val) return 0;
        var handle = jaxe.handleAlloc(out.val, jaxe.TYPE_REVERB3D);
        if (handle == 0) {
            out.val.release();
            return 0;
        }
        return handle;
    }

    static fmod_r3d_release(handle) {
        var reverb = jaxe.resolveReverb3d(handle);
        if (!reverb) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = reverb.release();
        if (jaxe.lastResult == jaxe.FMOD.OK) jaxe.handleFree(handle);
        return jaxe.lastResult;
    }

    static fmod_r3d_set_3d_attributes(handle, x, y, z, minDist, maxDist) {
        var reverb = jaxe.resolveReverb3d(handle);
        if (!reverb) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = reverb.set3DAttributes({ x: x, y: y, z: z }, minDist, maxDist);
        return jaxe.lastResult;
    }

    static fmod_r3d_set_properties(handle, fbuf) {
        var reverb = jaxe.resolveReverb3d(handle);
        if (!reverb) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        var props = {};
        for (var i = 0; i < jaxe.REVERB_FIELDS.length; i++) props[jaxe.REVERB_FIELDS[i]] = fbuf[i];
        jaxe.lastResult = reverb.setProperties(props);
        return jaxe.lastResult;
    }

    static fmod_r3d_get_properties(handle, fbuf) {
        var reverb = jaxe.resolveReverb3d(handle);
        if (!reverb) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        // The binding writes the fields flat onto the out object
        var out = {};
        jaxe.lastResult = reverb.getProperties(out);
        if (jaxe.lastResult != jaxe.FMOD.OK) return jaxe.lastResult;
        for (var i = 0; i < jaxe.REVERB_FIELDS.length; i++) fbuf[i] = out[jaxe.REVERB_FIELDS[i]] || 0;
        return jaxe.lastResult;
    }

    static fmod_r3d_set_active(handle, active) {
        var reverb = jaxe.resolveReverb3d(handle);
        if (!reverb) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = reverb.setActive(!!active);
        return jaxe.lastResult;
    }

    //// Core sound surface

    static resolveCoreSound(handle) {
        return jaxe.handleResolve(handle, jaxe.TYPE_SOUND);
    }

    static fmod_core_create_sound_pcm(data, len, sampleRate, channels) {
        if (!jaxe.FmodIsInitialized) { jaxe.lastResult = jaxe.ERR_STUDIO_UNINITIALIZED; return 0; }
        if (!data || len <= 0 || len > data.byteLength || sampleRate <= 0 || channels < 1 || channels > 2) {
            jaxe.lastResult = jaxe.ERR_INVALID_PARAM;
            return 0;
        }
        var bytes = new Uint8Array(data, 0, len);
        var exinfo = jaxe.FMOD.CREATESOUNDEXINFO();
        exinfo.length = bytes.length;
        exinfo.numchannels = channels;
        exinfo.defaultfrequency = sampleRate;
        exinfo.format = jaxe.FMOD.SOUND_FORMAT_PCM16;
        var out = {};
        jaxe.lastResult = jaxe.gSystemCore.createSound(bytes,
            (jaxe.FMOD.OPENMEMORY | jaxe.FMOD.OPENRAW) >>> 0, exinfo, out);
        if (jaxe.lastResult != jaxe.FMOD.OK || !out.val) return 0;
        var handle = jaxe.handleAlloc(out.val, jaxe.TYPE_SOUND);
        if (handle == 0) {
            out.val.release();
            return 0;
        }
        return handle;
    }

    static fmod_core_play_sound(handle, startPaused) {
        var sound = jaxe.resolveCoreSound(handle);
        if (!sound) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var out = {};
        jaxe.lastResult = jaxe.gSystemCore.playSound(sound, null, !!startPaused, out);
        if (jaxe.lastResult != jaxe.FMOD.OK || !out.val) return 0;
        var chHandle = jaxe.handleAlloc(out.val, jaxe.TYPE_CHAN);
        if (chHandle == 0) {
            out.val.stop();
            return 0;
        }
        return chHandle;
    }

    static fmod_sound_set_defaults(handle, frequency, priority) {
        var sound = jaxe.resolveCoreSound(handle);
        if (!sound) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = sound.setDefaults(frequency, priority);
        return jaxe.lastResult;
    }

    static fmod_sound_get_defaults(handle, fbuf) {
        var sound = jaxe.resolveCoreSound(handle);
        if (!sound) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        var frequency = {};
        var priority = {};
        jaxe.lastResult = sound.getDefaults(frequency, priority);
        fbuf[0] = frequency.val || 0;
        fbuf[1] = priority.val || 0;
        return jaxe.lastResult;
    }

    static fmod_sound_set_loop_points(handle, startMs, endMs) {
        var sound = jaxe.resolveCoreSound(handle);
        if (!sound) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = sound.setLoopPoints(startMs, jaxe.FMOD.TIMEUNIT_MS, endMs, jaxe.FMOD.TIMEUNIT_MS);
        return jaxe.lastResult;
    }

    static fmod_sound_get_loop_points(handle, ibuf) {
        var sound = jaxe.resolveCoreSound(handle);
        if (!sound) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        var start = {};
        var end = {};
        jaxe.lastResult = sound.getLoopPoints(start, jaxe.FMOD.TIMEUNIT_MS, end, jaxe.FMOD.TIMEUNIT_MS);
        ibuf[0] = start.val || 0;
        ibuf[1] = end.val || 0;
        return jaxe.lastResult;
    }

    static fmod_sound_set_mode(handle, mode) {
        var sound = jaxe.resolveCoreSound(handle);
        if (!sound) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = sound.setMode(mode >>> 0);
        return jaxe.lastResult;
    }

    static fmod_sound_get_mode(handle) {
        var sound = jaxe.resolveCoreSound(handle);
        if (!sound) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var out = {};
        jaxe.lastResult = sound.getMode(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? out.val : 0;
    }

    static fmod_sound_get_format(handle, ibuf) {
        var sound = jaxe.resolveCoreSound(handle);
        if (!sound) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        var type = {};
        var format = {};
        var channels = {};
        var bits = {};
        jaxe.lastResult = sound.getFormat(type, format, channels, bits);
        ibuf[0] = channels.val || 0;
        ibuf[1] = bits.val || 0;
        return jaxe.lastResult;
    }

    static fmod_sound_get_open_state(handle) {
        var sound = jaxe.resolveCoreSound(handle);
        if (!sound) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return -1; }
        var state = {};
        var buffered = {};
        var starving = {};
        var diskBusy = {};
        jaxe.lastResult = sound.getOpenState(state, buffered, starving, diskBusy);
        return jaxe.lastResult == jaxe.FMOD.OK ? state.val : -1;
    }

    //// Core system extras (slice 3)

    static fmod_sys_get_channels_playing(ibuf) {
        if (!jaxe.FmodIsInitialized) { jaxe.lastResult = jaxe.ERR_STUDIO_UNINITIALIZED; return jaxe.lastResult; }
        var all = {};
        var real = {};
        jaxe.lastResult = jaxe.gSystemCore.getChannelsPlaying(all, real);
        ibuf[0] = all.val || 0;
        ibuf[1] = real.val || 0;
        return jaxe.lastResult;
    }

    static fmod_sys_mixer_suspend() {
        if (!jaxe.FmodIsInitialized) { jaxe.lastResult = jaxe.ERR_STUDIO_UNINITIALIZED; return jaxe.lastResult; }
        jaxe.lastResult = jaxe.gSystemCore.mixerSuspend();
        return jaxe.lastResult;
    }

    static fmod_sys_mixer_resume() {
        if (!jaxe.FmodIsInitialized) { jaxe.lastResult = jaxe.ERR_STUDIO_UNINITIALIZED; return jaxe.lastResult; }
        jaxe.lastResult = jaxe.gSystemCore.mixerResume();
        return jaxe.lastResult;
    }

    static fmod_sys_get_software_format(ibuf) {
        if (!jaxe.FmodIsInitialized) { jaxe.lastResult = jaxe.ERR_STUDIO_UNINITIALIZED; return jaxe.lastResult; }
        var rate = {};
        var mode = {};
        var raw = {};
        jaxe.lastResult = jaxe.gSystemCore.getSoftwareFormat(rate, mode, raw);
        ibuf[0] = rate.val || 0;
        ibuf[1] = mode.val || 0;
        ibuf[2] = raw.val || 0;
        return jaxe.lastResult;
    }

    static fmod_dsp_get_cpu_usage(handle, ibuf) {
        var dsp = jaxe.resolveDsp(handle);
        if (!dsp) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        var exclusive = {};
        var inclusive = {};
        jaxe.lastResult = dsp.getCPUUsage(exclusive, inclusive);
        ibuf[0] = exclusive.val || 0;
        ibuf[1] = inclusive.val || 0;
        return jaxe.lastResult;
    }

    //// Channel callbacks and sync points

    // Channel events ride the callback queue under the 0x40000000 namespace
    static CB_CHAN_END = 0x40000001;
    static CB_CHAN_SYNCPOINT = 0x40000002;

    static channelCallback(channelcontrol, controltype, callbacktype, commanddata1, commanddata2) {
        // controltype 0 = channel. The handle rides in the channel userdata.
        if (controltype !== 0) return jaxe.FMOD.OK;
        var handle = jaxe.chanCallbackHandles.get(jaxe.rawPtr(channelcontrol)) || 0;
        if (!handle) return jaxe.FMOD.OK;
        var ev = { handle: handle, type: 0, i1: 0, i2: 0, i3: 0, i4: 0, i5: 0, f1: 0.0, str: "" };
        if (callbacktype === 0) {
            ev.type = jaxe.CB_CHAN_END;
            // The channel is done: without this the map entry outlives every
            // naturally-ended channel for the rest of the session
            jaxe.chanCallbackHandles.delete(jaxe.rawPtr(channelcontrol));
        }
        else if (callbacktype === 2) { ev.type = jaxe.CB_CHAN_SYNCPOINT; ev.i1 = commanddata1 | 0; }
        else return jaxe.FMOD.OK;
        jaxe.cbQueue.push(ev);
        if (jaxe.cbQueue.length > jaxe.CBQ_CAPACITY) {
            jaxe.cbQueue.shift();
            jaxe.cbOverflow = true;
        }
        return jaxe.FMOD.OK;
    }

    // The embind userdata API cannot carry plain ints, so the handle map is
    // keyed by the channel's raw pointer instead
    static chanCallbackHandles = new Map();

    static fmod_chan_set_callback(handle, enabled) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        if (enabled) {
            jaxe.chanCallbackHandles.set(jaxe.rawPtr(ch), handle);
            jaxe.lastResult = ch.setCallback(jaxe.channelCallback);
        } else {
            jaxe.lastResult = ch.setCallback(null);
            jaxe.chanCallbackHandles.delete(jaxe.rawPtr(ch));
        }
        return jaxe.lastResult;
    }

    static fmod_sound_add_sync_point(handle, offsetMs, name) {
        if (typeof name !== "string") { jaxe.lastResult = jaxe.ERR_INVALID_PARAM; return jaxe.lastResult; }
        var sound = jaxe.resolveCoreSound(handle);
        if (!sound) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        var point = {};
        jaxe.lastResult = sound.addSyncPoint(offsetMs, jaxe.FMOD.TIMEUNIT_MS, name, point);
        return jaxe.lastResult;
    }

    static fmod_sound_delete_sync_point(handle, index) {
        var sound = jaxe.resolveCoreSound(handle);
        if (!sound) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        var point = {};
        jaxe.lastResult = sound.getSyncPoint(index, point);
        if (jaxe.lastResult != jaxe.FMOD.OK) return jaxe.lastResult;
        jaxe.lastResult = sound.deleteSyncPoint(point.val);
        return jaxe.lastResult;
    }

    static fmod_sound_get_num_sync_points(handle) {
        var sound = jaxe.resolveCoreSound(handle);
        if (!sound) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var out = {};
        jaxe.lastResult = sound.getNumSyncPoints(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? out.val : 0;
    }

    static fmod_sound_get_sync_point_name(handle, index) {
        var sound = jaxe.resolveCoreSound(handle);
        if (!sound) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return ""; }
        var point = {};
        jaxe.lastResult = sound.getSyncPoint(index, point);
        if (jaxe.lastResult != jaxe.FMOD.OK) return "";
        var name = {};
        var offset = {};
        jaxe.lastResult = sound.getSyncPointInfo(point.val, name, 512, offset, jaxe.FMOD.TIMEUNIT_MS);
        return jaxe.lastResult == jaxe.FMOD.OK ? (name.val || "") : "";
    }

    static fmod_sound_get_sync_point_offset(handle, index) {
        var sound = jaxe.resolveCoreSound(handle);
        if (!sound) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return -1; }
        var point = {};
        jaxe.lastResult = sound.getSyncPoint(index, point);
        if (jaxe.lastResult != jaxe.FMOD.OK) return -1;
        var name = {};
        var offset = {};
        jaxe.lastResult = sound.getSyncPointInfo(point.val, name, 512, offset, jaxe.FMOD.TIMEUNIT_MS);
        return jaxe.lastResult == jaxe.FMOD.OK ? offset.val : -1;
    }

    //// Sound groups

    static resolveSoundGroup(handle) {
        return jaxe.handleResolve(handle, jaxe.TYPE_SOUNDGROUP);
    }

    static fmod_sys_create_sound_group(name) {
        if (typeof name !== "string") { jaxe.lastResult = jaxe.ERR_INVALID_PARAM; return 0; }
        if (!jaxe.FmodIsInitialized) { jaxe.lastResult = jaxe.ERR_STUDIO_UNINITIALIZED; return 0; }
        var out = {};
        jaxe.lastResult = jaxe.gSystemCore.createSoundGroup(name, out);
        if (jaxe.lastResult != jaxe.FMOD.OK || !out.val) return 0;
        var handle = jaxe.handleAlloc(out.val, jaxe.TYPE_SOUNDGROUP);
        if (handle == 0) {
            out.val.release();
            return 0;
        }
        return handle;
    }

    static fmod_sys_get_master_sound_group() {
        if (!jaxe.FmodIsInitialized) { jaxe.lastResult = jaxe.ERR_STUDIO_UNINITIALIZED; return 0; }
        var out = {};
        jaxe.lastResult = jaxe.gSystemCore.getMasterSoundGroup(out);
        if (jaxe.lastResult != jaxe.FMOD.OK || !out.val) return 0;
        return jaxe.handleFindOrAlloc(out.val, jaxe.TYPE_SOUNDGROUP);
    }

    static fmod_sg_release(handle) {
        var group = jaxe.resolveSoundGroup(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = group.release();
        if (jaxe.lastResult == jaxe.FMOD.OK) jaxe.handleFree(handle);
        return jaxe.lastResult;
    }

    static fmod_sg_set_max_audible(handle, maxAudible) {
        var group = jaxe.resolveSoundGroup(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = group.setMaxAudible(maxAudible);
        return jaxe.lastResult;
    }

    static fmod_sg_get_max_audible(handle) {
        var group = jaxe.resolveSoundGroup(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var out = {};
        jaxe.lastResult = group.getMaxAudible(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? out.val : 0;
    }

    static fmod_sg_set_max_audible_behavior(handle, behavior) {
        var group = jaxe.resolveSoundGroup(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = group.setMaxAudibleBehavior(behavior);
        return jaxe.lastResult;
    }

    static fmod_sg_get_max_audible_behavior(handle) {
        var group = jaxe.resolveSoundGroup(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var out = {};
        jaxe.lastResult = group.getMaxAudibleBehavior(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? out.val : 0;
    }

    static fmod_sg_set_mute_fade_speed(handle, speed) {
        var group = jaxe.resolveSoundGroup(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = group.setMuteFadeSpeed(speed);
        return jaxe.lastResult;
    }

    static fmod_sg_get_num_sounds(handle) {
        var group = jaxe.resolveSoundGroup(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var out = {};
        jaxe.lastResult = group.getNumSounds(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? out.val : 0;
    }

    static fmod_sg_stop(handle) {
        var group = jaxe.resolveSoundGroup(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = group.stop();
        return jaxe.lastResult;
    }

    static fmod_sound_set_sound_group(handle, groupHandle) {
        var sound = jaxe.resolveCoreSound(handle);
        var group = jaxe.resolveSoundGroup(groupHandle);
        if (!sound || !group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = sound.setSoundGroup(group);
        return jaxe.lastResult;
    }

    //// System 3D settings and drivers

    static fmod_sys_set_3d_settings(doppler, distanceFactor, rolloffScale) {
        if (!jaxe.FmodIsInitialized) { jaxe.lastResult = jaxe.ERR_STUDIO_UNINITIALIZED; return jaxe.lastResult; }
        jaxe.lastResult = jaxe.gSystemCore.set3DSettings(doppler, distanceFactor, rolloffScale);
        return jaxe.lastResult;
    }

    static fmod_sys_get_3d_settings(fbuf) {
        if (!jaxe.FmodIsInitialized) { jaxe.lastResult = jaxe.ERR_STUDIO_UNINITIALIZED; return jaxe.lastResult; }
        var doppler = {};
        var distanceFactor = {};
        var rolloffScale = {};
        jaxe.lastResult = jaxe.gSystemCore.get3DSettings(doppler, distanceFactor, rolloffScale);
        fbuf[0] = doppler.val || 0;
        fbuf[1] = distanceFactor.val || 0;
        fbuf[2] = rolloffScale.val || 0;
        return jaxe.lastResult;
    }

    static fmod_sys_get_num_drivers() {
        if (!jaxe.FmodIsInitialized) { jaxe.lastResult = jaxe.ERR_STUDIO_UNINITIALIZED; return 0; }
        var out = {};
        jaxe.lastResult = jaxe.gSystemCore.getNumDrivers(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? out.val : 0;
    }

    static fmod_sys_get_driver_name(id) {
        if (!jaxe.FmodIsInitialized) { jaxe.lastResult = jaxe.ERR_STUDIO_UNINITIALIZED; return ""; }
        // embind drops the name length arg from getDriverInfo
        var name = {};
        var guid = {};
        var rate = {};
        var mode = {};
        var channels = {};
        jaxe.lastResult = jaxe.gSystemCore.getDriverInfo(id, name, guid, rate, mode, channels);
        return jaxe.lastResult == jaxe.FMOD.OK ? (name.val || "") : "";
    }

    //// Getter symmetry for the routing and spatial setters

    static fmod_chan_get_loop_count(handle) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var out = {};
        jaxe.lastResult = ch.getLoopCount(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? out.val : 0;
    }

    static fmod_chan_get_low_pass_gain(handle) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0.0; }
        var out = {};
        jaxe.lastResult = ch.getLowPassGain(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? out.val : 0.0;
    }

    static fmod_chan_get_mode(handle) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var out = {};
        jaxe.lastResult = ch.getMode(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? out.val : 0;
    }

    static fmod_chan_get_3d_cone_settings(handle, fbuf) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        var inside = {};
        var outside = {};
        var volume = {};
        jaxe.lastResult = ch.get3DConeSettings(inside, outside, volume);
        fbuf[0] = inside.val || 0;
        fbuf[1] = outside.val || 0;
        fbuf[2] = volume.val || 0;
        return jaxe.lastResult;
    }

    static fmod_chan_get_3d_spread(handle) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0.0; }
        var out = {};
        jaxe.lastResult = ch.get3DSpread(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? out.val : 0.0;
    }

    static fmod_chan_get_3d_level(handle) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0.0; }
        var out = {};
        jaxe.lastResult = ch.get3DLevel(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? out.val : 0.0;
    }

    static fmod_chan_get_3d_doppler_level(handle) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0.0; }
        var out = {};
        jaxe.lastResult = ch.get3DDopplerLevel(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? out.val : 0.0;
    }

    static fmod_chan_get_3d_min_max(handle, fbuf) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        var minDist = {};
        var maxDist = {};
        jaxe.lastResult = ch.get3DMinMaxDistance(minDist, maxDist);
        fbuf[0] = minDist.val || 0;
        fbuf[1] = maxDist.val || 0;
        return jaxe.lastResult;
    }

    static fmod_chan_get_3d_attributes(handle, fbuf) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        // The binding writes the vectors as flat dotted keys on the outs
        var pos = {};
        var vel = {};
        jaxe.lastResult = ch.get3DAttributes(pos, vel);
        fbuf[0] = pos["position.x"] !== undefined ? pos["position.x"] : (pos.x || 0);
        fbuf[1] = pos["position.y"] !== undefined ? pos["position.y"] : (pos.y || 0);
        fbuf[2] = pos["position.z"] !== undefined ? pos["position.z"] : (pos.z || 0);
        fbuf[3] = vel["velocity.x"] !== undefined ? vel["velocity.x"] : (vel.x || 0);
        fbuf[4] = vel["velocity.y"] !== undefined ? vel["velocity.y"] : (vel.y || 0);
        fbuf[5] = vel["velocity.z"] !== undefined ? vel["velocity.z"] : (vel.z || 0);
        return jaxe.lastResult;
    }

    static fmod_chan_get_delay(handle, fbuf) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        var startClock = {};
        var endClock = {};
        var stopChannels = {};
        jaxe.lastResult = ch.getDelay(startClock, endClock, stopChannels);
        fbuf[0] = startClock.val || 0;
        fbuf[1] = endClock.val || 0;
        fbuf[2] = stopChannels.val ? 1 : 0;
        return jaxe.lastResult;
    }

    static fmod_dsp_get_wet_dry_mix(handle, fbuf) {
        var dsp = jaxe.resolveDsp(handle);
        if (!dsp) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        var prewet = {};
        var postwet = {};
        var dry = {};
        jaxe.lastResult = dsp.getWetDryMix(prewet, postwet, dry);
        fbuf[0] = prewet.val || 0;
        fbuf[1] = postwet.val || 0;
        fbuf[2] = dry.val || 0;
        return jaxe.lastResult;
    }

    static fmod_dsp_get_active(handle) {
        var dsp = jaxe.resolveDsp(handle);
        if (!dsp) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return false; }
        var out = {};
        jaxe.lastResult = dsp.getActive(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? !!out.val : false;
    }

    static fmod_dsp_get_metering_enabled(handle, ibuf) {
        var dsp = jaxe.resolveDsp(handle);
        if (!dsp) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        var inputEnabled = {};
        var outputEnabled = {};
        jaxe.lastResult = dsp.getMeteringEnabled(inputEnabled, outputEnabled);
        ibuf[0] = inputEnabled.val ? 1 : 0;
        ibuf[1] = outputEnabled.val ? 1 : 0;
        return jaxe.lastResult;
    }

    //// Bank loading from memory

    static fmod_sys_load_bank_memory(data, len) {
        if (!jaxe.sysReady()) return 0;
        var bytes = new Uint8Array(data, 0, Math.min(len, data.byteLength));
        var bank = {};
        jaxe.lastResult = jaxe.gSystem.loadBankMemory(bytes, bytes.length,
            jaxe.FMOD.STUDIO_LOAD_MEMORY, jaxe.FMOD.STUDIO_LOAD_BANK_NORMAL, bank);
        if (jaxe.lastResult != jaxe.FMOD.OK || !bank.val) return 0;
        return jaxe.handleFindOrAlloc(bank.val, jaxe.TYPE_BANK);
    }

    //// Event instance core bridge

    static fmod_evi_get_channel_group(handle) {
        var inst = jaxe.handleResolve(handle, jaxe.TYPE_EVI);
        if (!inst) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var out = {};
        jaxe.lastResult = inst.getChannelGroup(out);
        if (jaxe.lastResult != jaxe.FMOD.OK || !out.val) return 0;
        return jaxe.handleFindOrAlloc(out.val, jaxe.TYPE_CHANGROUP);
    }

    //// Command capture and replay

    static resolveReplay(handle) {
        return jaxe.handleResolve(handle, jaxe.TYPE_REPLAY);
    }

    static fmod_sys_start_command_capture(path) {
        if (typeof path !== "string") { jaxe.lastResult = jaxe.ERR_INVALID_PARAM; return jaxe.lastResult; }
        if (!jaxe.sysReady()) return jaxe.lastResult;
        jaxe.lastResult = jaxe.gSystem.startCommandCapture(path, 0);
        return jaxe.lastResult;
    }

    static fmod_sys_stop_command_capture() {
        if (!jaxe.sysReady()) return jaxe.lastResult;
        jaxe.lastResult = jaxe.gSystem.stopCommandCapture();
        return jaxe.lastResult;
    }

    static fmod_sys_load_command_replay(path) {
        if (typeof path !== "string") { jaxe.lastResult = jaxe.ERR_INVALID_PARAM; return 0; }
        if (!jaxe.sysReady()) return 0;
        var out = {};
        jaxe.lastResult = jaxe.gSystem.loadCommandReplay(path, 0, out);
        if (jaxe.lastResult != jaxe.FMOD.OK || !out.val) return 0;
        var handle = jaxe.handleAlloc(out.val, jaxe.TYPE_REPLAY);
        if (handle == 0) {
            out.val.release();
            return 0;
        }
        return handle;
    }

    static fmod_replay_release(handle) {
        var replay = jaxe.resolveReplay(handle);
        if (!replay) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = replay.release();
        if (jaxe.lastResult == jaxe.FMOD.OK) jaxe.handleFree(handle);
        return jaxe.lastResult;
    }

    static fmod_replay_is_valid(handle) {
        var replay = jaxe.resolveReplay(handle);
        // isValid returns 1/0 from the wasm side, coerce to a real bool
        return replay != null && (!replay.isValid || !!replay.isValid());
    }

    static fmod_replay_start(handle) {
        var replay = jaxe.resolveReplay(handle);
        if (!replay) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = replay.start();
        return jaxe.lastResult;
    }

    static fmod_replay_stop(handle) {
        var replay = jaxe.resolveReplay(handle);
        if (!replay) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = replay.stop();
        return jaxe.lastResult;
    }

    static fmod_replay_set_paused(handle, paused) {
        var replay = jaxe.resolveReplay(handle);
        if (!replay) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = replay.setPaused(!!paused);
        return jaxe.lastResult;
    }

    static fmod_replay_get_paused(handle) {
        var replay = jaxe.resolveReplay(handle);
        if (!replay) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return false; }
        var out = {};
        jaxe.lastResult = replay.getPaused(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? !!out.val : false;
    }

    static fmod_replay_seek_to_time(handle, timeMs) {
        var replay = jaxe.resolveReplay(handle);
        if (!replay) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = replay.seekToTime(timeMs / 1000.0);
        return jaxe.lastResult;
    }

    static fmod_replay_get_length(handle) {
        var replay = jaxe.resolveReplay(handle);
        if (!replay) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0.0; }
        var out = {};
        jaxe.lastResult = replay.getLength(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? out.val : 0.0;
    }

    //// Channel priority, virtualization, and remaining getters

    static fmod_chan_set_priority(handle, priority) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = ch.setPriority(priority);
        return jaxe.lastResult;
    }

    static fmod_chan_get_priority(handle) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var out = {};
        jaxe.lastResult = ch.getPriority(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? out.val : 0;
    }

    static fmod_chan_is_virtual(handle) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return false; }
        var out = {};
        jaxe.lastResult = ch.isVirtual(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? !!out.val : false;
    }

    static fmod_chan_get_audibility(handle) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0.0; }
        var out = {};
        jaxe.lastResult = ch.getAudibility(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? out.val : 0.0;
    }

    static fmod_chan_set_volume_ramp(handle, ramp) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = ch.setVolumeRamp(!!ramp);
        return jaxe.lastResult;
    }

    static fmod_chan_get_volume_ramp(handle) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return false; }
        var out = {};
        jaxe.lastResult = ch.getVolumeRamp(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? !!out.val : false;
    }

    static fmod_chan_get_current_sound(handle) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var out = {};
        jaxe.lastResult = ch.getCurrentSound(out);
        if (jaxe.lastResult != jaxe.FMOD.OK || !out.val) return 0;
        // Borrowed reference: releasing it would pull the sound out from
        // under its owner
        return jaxe.handleFindOrAlloc(out.val, jaxe.TYPE_SOUND);
    }

    static fmod_chan_set_loop_points(handle, startMs, endMs) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = ch.setLoopPoints(startMs, jaxe.FMOD.TIMEUNIT_MS, endMs, jaxe.FMOD.TIMEUNIT_MS);
        return jaxe.lastResult;
    }

    static fmod_chan_get_loop_points(handle, ibuf) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        var start = {};
        var end = {};
        jaxe.lastResult = ch.getLoopPoints(start, jaxe.FMOD.TIMEUNIT_MS, end, jaxe.FMOD.TIMEUNIT_MS);
        ibuf[0] = start.val || 0;
        ibuf[1] = end.val || 0;
        return jaxe.lastResult;
    }

    static fmod_chan_get_reverb_wet(handle, instance) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0.0; }
        var out = {};
        jaxe.lastResult = ch.getReverbProperties(instance, out);
        return jaxe.lastResult == jaxe.FMOD.OK ? (out.val || 0) : 0.0;
    }

    static fmod_chan_get_index(handle) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return -1; }
        var out = {};
        jaxe.lastResult = ch.getIndex(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? out.val : -1;
    }

    static fmod_chan_get_3d_cone_orientation(handle, fbuf) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        var out = {};
        jaxe.lastResult = ch.get3DConeOrientation(out);
        fbuf[0] = out.x || 0;
        fbuf[1] = out.y || 0;
        fbuf[2] = out.z || 0;
        return jaxe.lastResult;
    }

    static fmod_chan_get_num_dsps(handle) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var out = {};
        jaxe.lastResult = ch.getNumDSPs(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? out.val : 0;
    }

    static fmod_chan_get_dsp(handle, index) {
        var ch = jaxe.resolveChan(handle);
        if (!ch) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var out = {};
        jaxe.lastResult = ch.getDSP(index, out);
        if (jaxe.lastResult != jaxe.FMOD.OK || !out.val) return 0;
        return jaxe.handleFindOrAlloc(out.val, jaxe.TYPE_DSP);
    }

    //// Sound name, group getter, and loop count

    static fmod_sound_get_name(handle) {
        var sound = jaxe.resolveCoreSound(handle);
        if (!sound) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return ""; }
        // embind drops the buffer length arg
        var out = {};
        jaxe.lastResult = sound.getName(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? (out.val || "") : "";
    }

    static fmod_sound_get_sound_group(handle) {
        var sound = jaxe.resolveCoreSound(handle);
        if (!sound) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var out = {};
        jaxe.lastResult = sound.getSoundGroup(out);
        if (jaxe.lastResult != jaxe.FMOD.OK || !out.val) return 0;
        return jaxe.handleFindOrAlloc(out.val, jaxe.TYPE_SOUNDGROUP);
    }

    static fmod_sound_get_loop_count(handle) {
        var sound = jaxe.resolveCoreSound(handle);
        if (!sound) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var out = {};
        jaxe.lastResult = sound.getLoopCount(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? out.val : 0;
    }

    static fmod_sound_set_loop_count(handle, loopCount) {
        var sound = jaxe.resolveCoreSound(handle);
        if (!sound) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = sound.setLoopCount(loopCount);
        return jaxe.lastResult;
    }

    //// Sound group volume and counters

    static fmod_sg_set_volume(handle, volume) {
        var group = jaxe.resolveSoundGroup(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = group.setVolume(volume);
        return jaxe.lastResult;
    }

    static fmod_sg_get_volume(handle) {
        var group = jaxe.resolveSoundGroup(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0.0; }
        var out = {};
        jaxe.lastResult = group.getVolume(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? out.val : 0.0;
    }

    static fmod_sg_get_num_playing(handle) {
        var group = jaxe.resolveSoundGroup(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var out = {};
        jaxe.lastResult = group.getNumPlaying(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? out.val : 0;
    }

    static fmod_sg_get_mute_fade_speed(handle) {
        var group = jaxe.resolveSoundGroup(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0.0; }
        var out = {};
        jaxe.lastResult = group.getMuteFadeSpeed(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? out.val : 0.0;
    }

    //// Output device selection

    static fmod_sys_set_driver(id) {
        if (!jaxe.FmodIsInitialized) { jaxe.lastResult = jaxe.ERR_STUDIO_UNINITIALIZED; return jaxe.lastResult; }
        jaxe.lastResult = jaxe.gSystemCore.setDriver(id);
        return jaxe.lastResult;
    }

    static fmod_sys_get_driver() {
        if (!jaxe.FmodIsInitialized) { jaxe.lastResult = jaxe.ERR_STUDIO_UNINITIALIZED; return 0; }
        var out = {};
        jaxe.lastResult = jaxe.gSystemCore.getDriver(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? out.val : 0;
    }

    //// DSP data params, info, and output traversal

    static fmod_dsp_set_param_data(handle, index, data, len) {
        var dsp = jaxe.resolveDsp(handle);
        if (!dsp) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        if (!data || len <= 0) { jaxe.lastResult = jaxe.ERR_INVALID_PARAM; return jaxe.lastResult; }
        var bytes = new Uint8Array(data, 0, Math.min(len, data.byteLength));
        jaxe.lastResult = dsp.setParameterData(index, bytes, bytes.length);
        return jaxe.lastResult;
    }

    static fmod_dsp_get_idle(handle) {
        var dsp = jaxe.resolveDsp(handle);
        if (!dsp) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return false; }
        var out = {};
        jaxe.lastResult = dsp.getIdle(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? !!out.val : false;
    }

    static fmod_dsp_get_info_name(handle) {
        var dsp = jaxe.resolveDsp(handle);
        if (!dsp) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return ""; }
        var name = {};
        var version = {};
        var channels = {};
        var configWidth = {};
        var configHeight = {};
        jaxe.lastResult = dsp.getInfo(name, version, channels, configWidth, configHeight);
        return jaxe.lastResult == jaxe.FMOD.OK ? (name.val || "") : "";
    }

    static fmod_dsp_get_output_dsp(handle, index) {
        var dsp = jaxe.resolveDsp(handle);
        if (!dsp) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var dspOut = {};
        var connOut = {};
        jaxe.lastResult = dsp.getOutput(index, dspOut, connOut);
        if (jaxe.lastResult != jaxe.FMOD.OK || !dspOut.val) return 0;
        return jaxe.handleFindOrAlloc(dspOut.val, jaxe.TYPE_DSP);
    }

    static fmod_dsp_get_output_connection(handle, index) {
        var dsp = jaxe.resolveDsp(handle);
        if (!dsp) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var dspOut = {};
        var connOut = {};
        jaxe.lastResult = dsp.getOutput(index, dspOut, connOut);
        if (jaxe.lastResult != jaxe.FMOD.OK || !connOut.val) return 0;
        return jaxe.handleFindOrAlloc(connOut.val, jaxe.TYPE_DSPCONN);
    }

    static fmod_dspconn_get_input_dsp(handle) {
        var conn = jaxe.resolveDspConn(handle);
        if (!conn) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var out = {};
        jaxe.lastResult = conn.getInput(out);
        if (jaxe.lastResult != jaxe.FMOD.OK || !out.val) return 0;
        return jaxe.handleFindOrAlloc(out.val, jaxe.TYPE_DSP);
    }

    static fmod_dspconn_get_output_dsp(handle) {
        var conn = jaxe.resolveDspConn(handle);
        if (!conn) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var out = {};
        jaxe.lastResult = conn.getOutput(out);
        if (jaxe.lastResult != jaxe.FMOD.OK || !out.val) return 0;
        return jaxe.handleFindOrAlloc(out.val, jaxe.TYPE_DSP);
    }

    //// Reverb3D getters

    static fmod_r3d_get_active(handle) {
        var reverb = jaxe.resolveReverb3d(handle);
        if (!reverb) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return false; }
        var out = {};
        jaxe.lastResult = reverb.getActive(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? !!out.val : false;
    }

    static fmod_r3d_get_3d_attributes(handle, fbuf) {
        var reverb = jaxe.resolveReverb3d(handle);
        if (!reverb) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        var pos = {};
        var minDist = {};
        var maxDist = {};
        jaxe.lastResult = reverb.get3DAttributes(pos, minDist, maxDist);
        fbuf[0] = pos.x !== undefined ? pos.x : (pos.val && pos.val.x || 0);
        fbuf[1] = pos.y !== undefined ? pos.y : (pos.val && pos.val.y || 0);
        fbuf[2] = pos.z !== undefined ? pos.z : (pos.val && pos.val.z || 0);
        fbuf[3] = minDist.val || 0;
        fbuf[4] = maxDist.val || 0;
        return jaxe.lastResult;
    }

    //// Channel group spatial mirror and remaining control surface

    static fmod_cg_set_pan(handle, pan) {
        var group = jaxe.resolveCg(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = group.setPan(pan);
        return jaxe.lastResult;
    }

    static fmod_cg_set_low_pass_gain(handle, gain) {
        var group = jaxe.resolveCg(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = group.setLowPassGain(gain);
        return jaxe.lastResult;
    }

    static fmod_cg_set_mode(handle, mode) {
        var group = jaxe.resolveCg(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = group.setMode(mode >>> 0);
        return jaxe.lastResult;
    }

    static fmod_cg_get_mode(handle) {
        var group = jaxe.resolveCg(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var out = {};
        jaxe.lastResult = group.getMode(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? out.val : 0;
    }

    static fmod_cg_set_3d_attributes(handle, posX, posY, posZ, velX, velY, velZ) {
        var group = jaxe.resolveCg(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = group.set3DAttributes(
            { x: posX, y: posY, z: posZ }, { x: velX, y: velY, z: velZ });
        return jaxe.lastResult;
    }

    static fmod_cg_get_3d_attributes(handle, fbuf) {
        var group = jaxe.resolveCg(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        // The ChannelGroup binding writes plain x/y/z keys here, unlike the
        // Channel binding which writes flat dotted keys (probed on the real
        // 2.03.12 wasm). The asymmetry is the binding's, keep both as is.
        var pos = {};
        var vel = {};
        jaxe.lastResult = group.get3DAttributes(pos, vel);
        fbuf[0] = pos.x || 0;
        fbuf[1] = pos.y || 0;
        fbuf[2] = pos.z || 0;
        fbuf[3] = vel.x || 0;
        fbuf[4] = vel.y || 0;
        fbuf[5] = vel.z || 0;
        return jaxe.lastResult;
    }

    static fmod_cg_set_3d_min_max(handle, minDist, maxDist) {
        var group = jaxe.resolveCg(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = group.set3DMinMaxDistance(minDist, maxDist);
        return jaxe.lastResult;
    }

    static fmod_cg_get_3d_min_max(handle, fbuf) {
        var group = jaxe.resolveCg(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        var minDist = {};
        var maxDist = {};
        jaxe.lastResult = group.get3DMinMaxDistance(minDist, maxDist);
        fbuf[0] = minDist.val || 0;
        fbuf[1] = maxDist.val || 0;
        return jaxe.lastResult;
    }

    static fmod_cg_set_3d_occlusion(handle, direct, reverb) {
        var group = jaxe.resolveCg(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = group.set3DOcclusion(direct, reverb);
        return jaxe.lastResult;
    }

    static fmod_cg_set_3d_level(handle, level) {
        var group = jaxe.resolveCg(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = group.set3DLevel(level);
        return jaxe.lastResult;
    }

    static fmod_cg_get_3d_level(handle) {
        var group = jaxe.resolveCg(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0.0; }
        var out = {};
        jaxe.lastResult = group.get3DLevel(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? out.val : 0.0;
    }

    static fmod_cg_set_3d_spread(handle, angle) {
        var group = jaxe.resolveCg(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = group.set3DSpread(angle);
        return jaxe.lastResult;
    }

    static fmod_cg_get_3d_spread(handle) {
        var group = jaxe.resolveCg(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0.0; }
        var out = {};
        jaxe.lastResult = group.get3DSpread(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? out.val : 0.0;
    }

    static fmod_cg_set_3d_doppler_level(handle, level) {
        var group = jaxe.resolveCg(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = group.set3DDopplerLevel(level);
        return jaxe.lastResult;
    }

    static fmod_cg_get_3d_doppler_level(handle) {
        var group = jaxe.resolveCg(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0.0; }
        var out = {};
        jaxe.lastResult = group.get3DDopplerLevel(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? out.val : 0.0;
    }

    static fmod_cg_set_3d_cone_settings(handle, insideAngle, outsideAngle, outsideVolume) {
        var group = jaxe.resolveCg(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = group.set3DConeSettings(insideAngle, outsideAngle, outsideVolume);
        return jaxe.lastResult;
    }

    static fmod_cg_get_3d_cone_settings(handle, fbuf) {
        var group = jaxe.resolveCg(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        var inside = {};
        var outside = {};
        var volume = {};
        jaxe.lastResult = group.get3DConeSettings(inside, outside, volume);
        fbuf[0] = inside.val || 0;
        fbuf[1] = outside.val || 0;
        fbuf[2] = volume.val || 0;
        return jaxe.lastResult;
    }

    static fmod_cg_set_3d_cone_orientation(handle, x, y, z) {
        var group = jaxe.resolveCg(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = group.set3DConeOrientation({ x: x, y: y, z: z });
        return jaxe.lastResult;
    }

    static fmod_cg_get_3d_cone_orientation(handle, fbuf) {
        var group = jaxe.resolveCg(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        var out = {};
        jaxe.lastResult = group.get3DConeOrientation(out);
        fbuf[0] = out.x || 0;
        fbuf[1] = out.y || 0;
        fbuf[2] = out.z || 0;
        return jaxe.lastResult;
    }

    static fmod_cg_set_reverb_wet(handle, instance, wet) {
        var group = jaxe.resolveCg(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = group.setReverbProperties(instance, wet);
        return jaxe.lastResult;
    }

    static fmod_cg_get_reverb_wet(handle, instance) {
        var group = jaxe.resolveCg(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0.0; }
        var out = {};
        jaxe.lastResult = group.getReverbProperties(instance, out);
        return jaxe.lastResult == jaxe.FMOD.OK ? (out.val || 0) : 0.0;
    }

    static fmod_cg_set_mix_matrix(handle, fbuf, outChannels, inChannels) {
        var group = jaxe.resolveCg(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        var total = outChannels * inChannels;
        if (total < 0 || total > 32 * 32) { jaxe.lastResult = jaxe.ERR_INVALID_PARAM; return jaxe.lastResult; }
        var matrix = [];
        for (var i = 0; i < total; i++) matrix.push(fbuf[i] || 0);
        jaxe.lastResult = group.setMixMatrix(matrix, outChannels, inChannels, 0);
        return jaxe.lastResult;
    }

    static fmod_cg_set_volume_ramp(handle, ramp) {
        var group = jaxe.resolveCg(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return jaxe.lastResult; }
        jaxe.lastResult = group.setVolumeRamp(!!ramp);
        return jaxe.lastResult;
    }

    static fmod_cg_get_volume_ramp(handle) {
        var group = jaxe.resolveCg(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return false; }
        var out = {};
        jaxe.lastResult = group.getVolumeRamp(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? !!out.val : false;
    }

    static fmod_cg_get_audibility(handle) {
        var group = jaxe.resolveCg(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0.0; }
        var out = {};
        jaxe.lastResult = group.getAudibility(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? out.val : 0.0;
    }

    static fmod_cg_get_name(handle) {
        var group = jaxe.resolveCg(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return ""; }
        // embind drops the buffer length arg
        var out = {};
        jaxe.lastResult = group.getName(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? (out.val || "") : "";
    }

    static fmod_cg_get_num_channels(handle) {
        var group = jaxe.resolveCg(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var out = {};
        jaxe.lastResult = group.getNumChannels(out);
        return jaxe.lastResult == jaxe.FMOD.OK ? out.val : 0;
    }

    static fmod_cg_get_channel(handle, index) {
        var group = jaxe.resolveCg(handle);
        if (!group) { jaxe.lastResult = jaxe.ERR_INVALID_HANDLE; return 0; }
        var out = {};
        jaxe.lastResult = group.getChannel(index, out);
        if (jaxe.lastResult != jaxe.FMOD.OK || !out.val) return 0;
        return jaxe.handleFindOrAlloc(out.val, jaxe.TYPE_CHAN);
    }

    //// Debug

    static fmod_debug_live_handle_count() {
        return jaxe.liveCount;
    }

    static fmod_binding_abi_version() {
        // Keep in lockstep with the manifest header "# abi-version:"
        return 8;
    }

    //// Initialization (Emscripten-specific, must stay here)

    // Nothing to preload. The runtime registry owns bank loading,
    // driven by the game's settings through the async fetch pipeline.
    static preRun = function () {
    }

    static onRuntimeInitialized = function () {
        var outval = {};
        // Settings from fmod_sys_init_ex. null on the legacy fmod_init path
        // (defaults below match the legacy behavior exactly).
        var init = jaxe.pendingInit;

        jaxe.FMOD.Studio_System_Create(outval);
        jaxe.gSystem = outval.val;

        jaxe.gSystem.getCoreSystem(outval);
        jaxe.gSystemCore = outval.val;

        jaxe.gSystemCore.setDSPBufferSize(2048, 2);

        // Mirrors the native shims: a requested speaker mode is honored
        // even when the sample rate is left at the driver default
        if (init && (init.sampleRate > 0 || init.speakerMode > 0)) {
            var initRate = init.sampleRate;
            if (initRate <= 0) {
                jaxe.gSystemCore.getDriverInfo(0, null, null, outval, null, null);
                initRate = outval.val;
            }
            jaxe.gSystemCore.setSoftwareFormat(initRate,
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

        // 128 matches the native shims' fallback for a missing channel count
        var numChannels = (init && init.numChannels > 0) ? init.numChannels : 128;
        var studioInitFlags = (init && (init.studioFlags & 1))
            ? jaxe.FMOD.STUDIO_INIT_LIVEUPDATE
            : jaxe.FMOD.STUDIO_INIT_NORMAL;
        jaxe.gSystem.initialize(numChannels, studioInitFlags, jaxe.FMOD.INIT_NORMAL, null);

        // Enable auto-update by default (the runtime applies the
        // configured setting on its first serviced frame)
        jaxe.fmod_sys_set_auto_update(true);

        jaxe.FmodIsInitialized = true;
        return jaxe.FMOD.OK;
    }
}
