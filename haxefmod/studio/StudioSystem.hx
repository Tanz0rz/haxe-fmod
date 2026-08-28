package haxefmod.studio;

import haxefmod.studio.Types;
import haxefmod.studio.native.NativeStudio;
import haxefmod.studio.native.Scratch;

/**
 * Entry point for the FMOD Studio bindings.
 *
 * There is exactly one FMOD Studio system per process (created by
 * FmodManager.Initialize), so this class is all statics. It is the escape
 * hatch for anything the high-level API does not cover:
 *
 *   import haxefmod.studio.StudioSystem;
 *   var music = StudioSystem.getBus("bus:/Music");
 *   music.setVolume(0.5);
 *
 * Lookups by GUID take formatted strings: "{1f687138-e06c-40f5-9bac-57f84bbcedd3}".
 * Repeated lookups of the same object return the same handle (deduplicated
 * natively), so handles can be compared with ==.
 */
class StudioSystem {
    /** One handle per bus path - repeated lookups return the cached handle. */
    static var busCache:Map<String, Bus> = new Map();

    /**
     * Looks up a bus by path (e.g. "bus:/" for the master bus).
     * Returns Bus.NULL if the system is not initialized or the path is
     * unknown. check lastResult() for the reason.
     */
    public static function getBus(path:String):Bus {
        if (busCache.exists(path)) {
            // A cached handle can go stale when its bank is unloaded, so
            // re-validate before serving it and refresh on a miss
            var cached = busCache.get(path);
            if (cached.isValid()) {
                return cached;
            }
            busCache.remove(path);
        }
        var bus:Bus = NativeStudio.sys_get_bus(path);
        if (!bus.isNull()) {
            busCache.set(path, bus);
        }
        return bus;
    }

    /** Looks up a bus by GUID string. */
    public static function getBusByID(guid:String):Bus {
        return NativeStudio.sys_get_bus_by_id(guid);
    }

    /** Looks up an event description by path (e.g. "event:/Music/MainLevel" or "snapshot:/..."). */
    public static function getEvent(path:String):EventDescription {
        return NativeStudio.sys_get_event(path);
    }

    /** Looks up an event description by GUID string. */
    public static function getEventByID(guid:String):EventDescription {
        return NativeStudio.sys_get_event_by_id(guid);
    }

    /** Looks up a VCA by path (e.g. "vca:/Environment"). */
    public static function getVCA(path:String):Vca {
        return NativeStudio.sys_get_vca(path);
    }

    public static function getVCAByID(guid:String):Vca {
        return NativeStudio.sys_get_vca_by_id(guid);
    }

    /** Looks up a loaded bank by path (e.g. "bank:/Master"). */
    public static function getBank(path:String):Bank {
        return NativeStudio.sys_get_bank(path);
    }

    public static function getBankByID(guid:String):Bank {
        return NativeStudio.sys_get_bank_by_id(guid);
    }

    /** Number of loaded banks. */
    public static function getBankCount():Int {
        return NativeStudio.sys_get_bank_count();
    }

    /** Loaded banks (up to Scratch.CAPACITY entries). */
    public static function getBankList():Array<Bank> {
        var count = NativeStudio.sys_get_bank_list();
        Scratch.warnTruncated("bank", count, getBankCount());
        return [for (i in 0...count) (Scratch.readI(i) : Bank)];
    }

    /** Resolves a path to its GUID string ("" on failure. Needs the strings bank loaded). */
    public static function lookupID(path:String):String {
        return NativeStudio.sys_lookup_id(path);
    }

    /** Resolves a GUID string to its path ("" on failure. Needs the strings bank loaded). */
    public static function lookupPath(guid:String):String {
        return NativeStudio.sys_lookup_path(guid);
    }

    /**
     * Loads a bank file. On html5 the file must already be in the virtual
     * filesystem (the default banks are preloaded. Use FmodRuntime for
     * fetch-based loading). Returns Bank.NULL on failure.
     */
    public static function loadBankFile(path:String, flags:FmodLoadBankFlags = NORMAL):Bank {
        return NativeStudio.sys_load_bank_file(path, flags);
    }

    /** Unloads all banks. */
    public static function unloadAll():FmodResult {
        return NativeStudio.sys_unload_all();
    }

    /**
     * Loads a bank from bytes (embedded, downloaded, or packed banks).
     * The data is copied, so the buffer is free after this returns.
     * Returns Bank.NULL on failure.
     */
    public static function loadBankMemory(data:haxe.io.Bytes):Bank {
        return NativeStudio.sys_load_bank_memory(data, data.length);
    }

    /**
     * Records every API command to a file until stopCommandCapture, for
     * FMOD's analysis tools or replay through loadCommandReplay.
     */
    public static function startCommandCapture(path:String):FmodResult {
        return NativeStudio.sys_start_command_capture(path);
    }

    public static function stopCommandCapture():FmodResult {
        return NativeStudio.sys_stop_command_capture();
    }

    /** Loads a capture file for playback. Returns CommandReplay.NULL on failure. */
    public static function loadCommandReplay(path:String):CommandReplay {
        return NativeStudio.sys_load_command_replay(path);
    }

    /** Blocks until all pending commands have executed. */
    public static function flushCommands():FmodResult {
        return NativeStudio.sys_flush_commands();
    }

    /** Blocks until all sample loading/unloading has completed. */
    public static function flushSampleLoading():FmodResult {
        return NativeStudio.sys_flush_sample_loading();
    }

    //// Global parameters

    public static function getParameter(name:String):Float {
        return NativeStudio.sys_get_param_by_name(name);
    }

    public static function getParameterFinal(name:String):Float {
        return NativeStudio.sys_get_param_by_name_final(name);
    }

    public static function setParameter(name:String, value:Float, ignoreSeekSpeed:Bool = false):FmodResult {
        return NativeStudio.sys_set_param_by_name(name, value, ignoreSeekSpeed);
    }

    public static function setParameterWithLabel(name:String, label:String, ignoreSeekSpeed:Bool = false):FmodResult {
        return NativeStudio.sys_set_param_by_name_with_label(name, label, ignoreSeekSpeed);
    }

    public static function getParameterByID(id:FmodParameterId):Float {
        return NativeStudio.sys_get_param_by_id(id.data1, id.data2);
    }

    public static function getParameterByIDFinal(id:FmodParameterId):Float {
        return NativeStudio.sys_get_param_by_id_final(id.data1, id.data2);
    }

    public static function setParameterByID(id:FmodParameterId, value:Float, ignoreSeekSpeed:Bool = false):FmodResult {
        return NativeStudio.sys_set_param_by_id(id.data1, id.data2, value, ignoreSeekSpeed);
    }

    public static function setParameterByIDWithLabel(id:FmodParameterId, label:String, ignoreSeekSpeed:Bool = false):FmodResult {
        return NativeStudio.sys_set_param_by_id_with_label(id.data1, id.data2, label, ignoreSeekSpeed);
    }

    /** Number of global parameters. */
    public static function getParameterDescriptionCount():Int {
        return NativeStudio.sys_get_parameter_description_count();
    }

    /** Global parameter description by index, or null on failure. */
    public static function getParameterDescriptionByIndex(index:Int):Null<FmodParameterDescription> {
        var name = NativeStudio.sys_get_parameter_description_by_index(index);
        return readParameterDescription(name);
    }

    /** Global parameter description by name, or null on failure. */
    public static function getParameterDescriptionByName(name:String):Null<FmodParameterDescription> {
        var resolved = NativeStudio.sys_get_parameter_description_by_name(name);
        return readParameterDescription(resolved);
    }

    /** Label text for a labeled global parameter's value index. */
    public static function getParameterLabel(parameterName:String, labelIndex:Int):String {
        return NativeStudio.sys_get_parameter_label(parameterName, labelIndex);
    }

    /**
     * Global parameter description by parameter ID, or null when no global
     * parameter carries that ID. Resolved by scanning the description list,
     * so it covers the same indexes getParameterDescriptionByIndex does.
     */
    public static function getParameterDescriptionByID(id:FmodParameterId):Null<FmodParameterDescription> {
        return scanDescriptionsByID(getParameterDescriptionCount(), getParameterDescriptionByIndex, id);
    }

    /** Shared ID scan over an indexed description getter (EventDescription
        reuses it, like readParameterDescription). */
    @:allow(haxefmod.studio.EventDescription)
    static function scanDescriptionsByID(count:Int, byIndex:Int -> Null<FmodParameterDescription>,
            id:FmodParameterId):Null<FmodParameterDescription> {
        for (i in 0...count) {
            var desc = byIndex(i);
            if (desc != null && desc.id.data1 == id.data1 && desc.id.data2 == id.data2) {
                return desc;
            }
        }
        return null;
    }

    /** Label text for a labeled global parameter identified by ID. */
    public static function getParameterLabelByID(id:FmodParameterId, labelIndex:Int):String {
        var desc = getParameterDescriptionByID(id);
        return desc == null ? "" : getParameterLabel(desc.name, labelIndex);
    }

    //// Listeners

    public static function getNumListeners():Int {
        return NativeStudio.sys_get_num_listeners();
    }

    public static function setNumListeners(count:Int):FmodResult {
        return NativeStudio.sys_set_num_listeners(count);
    }

    /** A listener's 3D attributes, or null on failure. */
    public static function getListenerAttributes(index:Int):Null<Fmod3DAttributes> {
        var result:FmodResult = NativeStudio.sys_get_listener_attributes(index);
        if (!result.isOk()) return null;
        return {
            position: {x: Scratch.readF(0), y: Scratch.readF(1), z: Scratch.readF(2)},
            velocity: {x: Scratch.readF(3), y: Scratch.readF(4), z: Scratch.readF(5)},
            forward: {x: Scratch.readF(6), y: Scratch.readF(7), z: Scratch.readF(8)},
            up: {x: Scratch.readF(9), y: Scratch.readF(10), z: Scratch.readF(11)},
        };
    }

    public static function setListenerAttributes(index:Int, attributes:Fmod3DAttributes):FmodResult {
        return NativeStudio.sys_set_listener_attributes(index,
            attributes.position.x, attributes.position.y, attributes.position.z,
            attributes.velocity.x, attributes.velocity.y, attributes.velocity.z,
            attributes.forward.x, attributes.forward.y, attributes.forward.z,
            attributes.up.x, attributes.up.y, attributes.up.z);
    }

    /** Convenience for 2D games: listener position only, unit forward/up. */
    public static function setListenerPosition2D(index:Int, x:Float, y:Float,
            velocityX:Float = 0, velocityY:Float = 0):FmodResult {
        return NativeStudio.sys_set_listener_attributes(index, x, y, 0,
            velocityX, velocityY, 0, 0, 0, 1, 0, 1, 0);
    }

    public static function getListenerWeight(index:Int):Float {
        return NativeStudio.sys_get_listener_weight(index);
    }

    public static function setListenerWeight(index:Int, weight:Float):FmodResult {
        return NativeStudio.sys_set_listener_weight(index, weight);
    }

    //// Profiling

    /** System-wide CPU usage, or null on failure. */
    public static function getCpuUsage():Null<FmodSystemCpuUsage> {
        var result:FmodResult = NativeStudio.sys_get_cpu_usage();
        if (!result.isOk()) return null;
        return {
            studioUpdate: Scratch.readF(0),
            dsp: Scratch.readF(1),
            stream: Scratch.readF(2),
            geometry: Scratch.readF(3),
            update: Scratch.readF(4),
            convolution1: Scratch.readF(5),
            convolution2: Scratch.readF(6),
        };
    }

    /** Studio internal buffer usage, or null on failure. */
    public static function getBufferUsage():Null<FmodBufferUsage> {
        var result:FmodResult = NativeStudio.sys_get_buffer_usage();
        if (!result.isOk()) return null;
        return {
            studioCommandQueue: {
                currentUsage: Scratch.readI(0),
                peakUsage: Scratch.readI(1),
                capacity: Scratch.readI(2),
                stallCount: Scratch.readI(3),
                stallTime: Scratch.readF(0),
            },
            studioHandle: {
                currentUsage: Scratch.readI(4),
                peakUsage: Scratch.readI(5),
                capacity: Scratch.readI(6),
                stallCount: Scratch.readI(7),
                stallTime: Scratch.readF(1),
            },
        };
    }

    public static function resetBufferUsage():FmodResult {
        return NativeStudio.sys_reset_buffer_usage();
    }

    /** System-wide memory usage, or null on failure (unsupported on html5). */
    public static function getMemoryUsage():Null<FmodMemoryUsage> {
        var result:FmodResult = NativeStudio.sys_get_memory_usage();
        if (!result.isOk()) return null;
        return {exclusive: Scratch.readI(0), inclusive: Scratch.readI(1), sampledata: Scratch.readI(2)};
    }

    //// Version and recording

    /** The linked FMOD version as "2.03.12", or "" on failure. */
    public static inline function getVersion():String {
        return NativeStudio.sys_get_version();
    }

    /**
     * Record drivers FMOD can see (unsupported in HTML5, returns null
     * there). drivers counts every known device, connected the ones
     * plugged in right now. Machines without a microphone report 0 and 0.
     */
    public static function getRecordDriverCount():Null<{drivers:Int, connected:Int}> {
        var drivers = NativeStudio.sys_get_record_num_drivers();
        if (drivers < 0) return null;
        return {drivers: drivers, connected: Scratch.readI(0)};
    }

    /**
     * Name and native format of a record driver (unsupported in HTML5,
     * returns null there). state is an FMOD_DRIVER_STATE bitmask (1 =
     * connected, 2 = default). Null for an id out of range.
     */
    public static function getRecordDriverInfo(id:Int):Null<{name:String, systemRate:Int, speakerMode:Int, channels:Int, state:Int}> {
        var name = NativeStudio.sys_get_record_driver_info(id);
        if (!lastResult().isOk()) return null;
        return {name: name, systemRate: Scratch.readI(0), speakerMode: Scratch.readI(1),
            channels: Scratch.readI(2), state: Scratch.readI(3)};
    }

    /**
     * Starts recording a driver into a sound from CoreSound.createRecordBuffer
     * (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED). With loop on
     * the buffer wraps and keeps recording, otherwise recording stops at
     * the end.
     */
    public static inline function recordStart(id:Int, sound:CoreSound, loop:Bool = false):FmodResult {
        return NativeStudio.sys_record_start(id, sound, loop);
    }

    /** Stops recording on a driver (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED). */
    public static inline function recordStop(id:Int):FmodResult {
        return NativeStudio.sys_record_stop(id);
    }

    /** True while a driver is recording (unsupported in HTML5, always false there). */
    public static inline function isRecording(id:Int):Bool {
        return NativeStudio.sys_is_recording(id);
    }

    /** The record cursor in PCM samples, or -1 on failure (unsupported in HTML5, always -1 there). */
    public static inline function getRecordPosition(id:Int):Int {
        return NativeStudio.sys_get_record_position(id);
    }

    //// Diagnostics

    /** Result of the most recent studio binding call. */
    public static function lastResult():FmodResult {
        return NativeStudio.sys_last_result();
    }

    /** Number of live native handles - useful for leak checks in tests. */
    public static function liveHandleCount():Int {
        return NativeStudio.debug_live_handle_count();
    }

    /** Shared decode for the parameter-description scratch layout
        (lockstep with the native writeParamDesc buffer order). */
    @:allow(haxefmod.studio.EventDescription)
    static function readParameterDescription(name:String):Null<FmodParameterDescription> {
        if (!lastResult().isOk()) return null;
        return {
            name: name,
            id: {data1: Scratch.readI(2), data2: Scratch.readI(3)},
            minimum: Scratch.readF(0),
            maximum: Scratch.readF(1),
            defaultValue: Scratch.readF(2),
            type: (Scratch.readI(0) : FmodParameterType),
            flags: Scratch.readI(1),
        };
    }
}
