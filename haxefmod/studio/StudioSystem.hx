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
     * unknown; check lastResult() for the reason.
     */
    public static function getBus(path:String):Bus {
        if (busCache.exists(path)) {
            return busCache.get(path);
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
        var total = getBankCount();
        if (total > count) {
            trace('Warn: FMOD - bank list truncated ($count of $total); raise FAXE_LIST_MAX/Scratch.CAPACITY');
        }
        return [for (i in 0...count) (Scratch.readI(i) : Bank)];
    }

    /** Resolves a path to its GUID string ("" on failure; needs the strings bank loaded). */
    public static function lookupID(path:String):String {
        return NativeStudio.sys_lookup_id(path);
    }

    /** Resolves a GUID string to its path ("" on failure; needs the strings bank loaded). */
    public static function lookupPath(guid:String):String {
        return NativeStudio.sys_lookup_path(guid);
    }

    /**
     * Loads a bank file. On html5 the file must already be in the virtual
     * filesystem (the default banks are preloaded; use FmodRuntime for
     * fetch-based loading). Returns Bank.NULL on failure.
     */
    public static function loadBankFile(path:String, flags:FmodLoadBankFlags = NORMAL):Bank {
        return NativeStudio.sys_load_bank_file(path, flags);
    }

    /** Unloads all banks. */
    public static function unloadAll():FmodResult {
        return NativeStudio.sys_unload_all();
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
    public static function setListenerPosition2D(index:Int, x:Float, y:Float):FmodResult {
        return NativeStudio.sys_set_listener_attributes(index, x, y, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0);
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

    //// Diagnostics

    /** Result of the most recent studio binding call. */
    public static function lastResult():FmodResult {
        return NativeStudio.sys_last_result();
    }

    /** Number of live native handles - useful for leak checks in tests. */
    public static function liveHandleCount():Int {
        return NativeStudio.debug_live_handle_count();
    }

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
