package haxefmod.studio;

import haxefmod.core.Sound;
import haxefmod.studio.Types;
import haxefmod.studio.UserData;
import haxefmod.studio.native.NativeStudio;
import haxefmod.studio.native.Scratch;
import haxefmod.studio.SystemCallbacks;

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

    /**
     * Unloads all banks. Every handle that came from a bank dies with it,
     * so every userdata entry and every description-level callback is
     * dropped here too.
     */
    public static function unloadAll():FmodResult {
        UserData.clearAll();
        EventDescription.clearAllCallbacks();
        return NativeStudio.sys_unload_all();
    }

    /**
     * Attaches a Haxe value to the studio system. The value lives on the
     * Haxe side and is dropped by unloadAll.
     */
    public static function setUserData(value:Dynamic):Void {
        UserData.systemValue = value;
    }

    /** The value attached with setUserData, or null. */
    public static function getUserData():Dynamic {
        return UserData.systemValue;
    }

    /**
     * Loads a bank from bytes (embedded, downloaded, or packed banks).
     * The data is copied, so the buffer is free after this returns. flags
     * are the same FmodLoadBankFlags loadBankFile takes. Returns Bank.NULL
     * on failure.
     */
    public static function loadBankMemory(data:haxe.io.Bytes, flags:FmodLoadBankFlags = NORMAL):Bank {
        return NativeStudio.sys_load_bank_memory(data, data.length, flags);
    }

    /**
     * Records every API command to a file until stopCommandCapture, for
     * FMOD's analysis tools or replay through loadCommandReplay. FILEFLUSH
     * writes each command straight to disk and SKIP_INITIAL_STATE leaves
     * out the commands that recreate the current state.
     */
    public static function startCommandCapture(path:String, flags:FmodCommandCaptureFlags = NORMAL):FmodResult {
        return NativeStudio.sys_start_command_capture(path, flags);
    }

    public static function stopCommandCapture():FmodResult {
        return NativeStudio.sys_stop_command_capture();
    }

    /**
     * Loads a capture file for playback. FAST_FORWARD plays it back as fast
     * as it can, SKIP_CLEANUP leaves the objects it created alive at the
     * end, and SKIP_BANK_LOAD keeps it from loading banks. Returns
     * CommandReplay.NULL on failure.
     */
    public static function loadCommandReplay(path:String, flags:FmodCommandReplayFlags = NORMAL):CommandReplay {
        return NativeStudio.sys_load_command_replay(path, flags);
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

    /**
     * A listener's 3D attributes and its attenuation position, or null on
     * failure.
     */
    public static function getListenerAttributes(index:Int):Null<FmodListenerAttributes> {
        var result:FmodResult = NativeStudio.sys_get_listener_attributes(index);
        if (!result.isOk()) return null;
        return {
            position: {x: Scratch.readF(0), y: Scratch.readF(1), z: Scratch.readF(2)},
            velocity: {x: Scratch.readF(3), y: Scratch.readF(4), z: Scratch.readF(5)},
            forward: {x: Scratch.readF(6), y: Scratch.readF(7), z: Scratch.readF(8)},
            up: {x: Scratch.readF(9), y: Scratch.readF(10), z: Scratch.readF(11)},
            attenuationPosition: {x: Scratch.readF(12), y: Scratch.readF(13), z: Scratch.readF(14)},
        };
    }

    /**
     * Sets a listener's 3D attributes. attenuationPosition is the point
     * distance attenuation is measured from when it differs from the
     * listener position (a third-person camera that hears from the
     * character). Left out, FMOD attenuates from the listener position.
     */
    public static function setListenerAttributes(index:Int, attributes:Fmod3DAttributes,
            ?attenuationPosition:FmodVector):FmodResult {
        var hasAttenuation = attenuationPosition != null;
        return NativeStudio.sys_set_listener_attributes(index,
            attributes.position.x, attributes.position.y, attributes.position.z,
            attributes.velocity.x, attributes.velocity.y, attributes.velocity.z,
            attributes.forward.x, attributes.forward.y, attributes.forward.z,
            attributes.up.x, attributes.up.y, attributes.up.z,
            hasAttenuation,
            hasAttenuation ? attenuationPosition.x : 0,
            hasAttenuation ? attenuationPosition.y : 0,
            hasAttenuation ? attenuationPosition.z : 0);
    }

    /** Convenience for 2D games: listener position only, unit forward/up. */
    public static function setListenerPosition2D(index:Int, x:Float, y:Float,
            velocityX:Float = 0, velocityY:Float = 0):FmodResult {
        return NativeStudio.sys_set_listener_attributes(index, x, y, 0,
            velocityX, velocityY, 0, 0, 0, 1, 0, 1, 0, false, 0, 0, 0);
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

#if (macro || (js && !haxefmod_html5_allow_unsupported))
    /** System-wide memory usage, or null on failure (unsupported in HTML5, null there). */
    public static macro function getMemoryUsage():haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("StudioSystem.getMemoryUsage", "FMOD's JavaScript API does not expose memory usage");
    }
    #else
    /** System-wide memory usage, or null on failure (unsupported in HTML5, null there). */
    public static function getMemoryUsage():Null<FmodMemoryUsage> {
        var result:FmodResult = NativeStudio.sys_get_memory_usage();
        if (!result.isOk()) return null;
        return {exclusive: Scratch.readI(0), inclusive: Scratch.readI(1), sampledata: Scratch.readI(2)};
    }
    #end

    //// Version and recording

    /** The linked FMOD version as "2.03.12", or "" on failure. */
    public static inline function getVersion():String {
        return NativeStudio.sys_get_version();
    }

#if (macro || (js && !haxefmod_html5_allow_unsupported))
    /**
     * Record drivers FMOD can see (unsupported in HTML5, returns null
     * there). drivers counts every known device, connected the ones
     * plugged in right now. Machines without a microphone report 0 and 0.
     */
    public static macro function getRecordDriverCount():haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("StudioSystem.getRecordDriverCount", "the web build has no microphone recording");
    }
    #else
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
    #end

#if (macro || (js && !haxefmod_html5_allow_unsupported))
    /**
     * Name and native format of a record driver (unsupported in HTML5,
     * returns null there). state is a FmodDriverState bitmask. Null for an
     * id out of range.
     */
    public static macro function getRecordDriverInfo(id:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("StudioSystem.getRecordDriverInfo", "the web build has no microphone recording");
    }
    #else
    /**
     * Name and native format of a record driver (unsupported in HTML5,
     * returns null there). state is a FmodDriverState bitmask. Null for an
     * id out of range.
     */
    public static function getRecordDriverInfo(id:Int):Null<{name:String, systemRate:Int, speakerMode:FmodSpeakerMode, channels:Int, state:FmodDriverState}> {
        var name = NativeStudio.sys_get_record_driver_info(id);
        if (!lastResult().isOk()) return null;
        return {name: name, systemRate: Scratch.readI(0), speakerMode: Scratch.readI(1),
            channels: Scratch.readI(2), state: Scratch.readI(3)};
    }
    #end

#if (macro || (js && !haxefmod_html5_allow_unsupported))
    /**
     * Starts recording a driver into a sound from Sound.createRecordBuffer
     * (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED). With loop on
     * the buffer wraps and keeps recording, otherwise recording stops at
     * the end.
     */
    public static macro function recordStart(id:haxe.macro.Expr, sound:haxe.macro.Expr, ?loop:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("StudioSystem.recordStart", "the web build has no microphone recording");
    }
    #else
    /**
     * Starts recording a driver into a sound from Sound.createRecordBuffer
     * (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED). With loop on
     * the buffer wraps and keeps recording, otherwise recording stops at
     * the end.
     */
    public static inline function recordStart(id:Int, sound:Sound, loop:Bool = false):FmodResult {
        return NativeStudio.sys_record_start(id, sound, loop);
    }
    #end

#if (macro || (js && !haxefmod_html5_allow_unsupported))
    /** Stops recording on a driver (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED). */
    public static macro function recordStop(id:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("StudioSystem.recordStop", "the web build has no microphone recording");
    }
    #else
    /** Stops recording on a driver (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED). */
    public static inline function recordStop(id:Int):FmodResult {
        return NativeStudio.sys_record_stop(id);
    }
    #end

#if (macro || (js && !haxefmod_html5_allow_unsupported))
    /** True while a driver is recording (unsupported in HTML5, always false there). */
    public static macro function isRecording(id:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("StudioSystem.isRecording", "the web build has no microphone recording");
    }
    #else
    /** True while a driver is recording (unsupported in HTML5, always false there). */
    public static inline function isRecording(id:Int):Bool {
        return NativeStudio.sys_is_recording(id);
    }
    #end

#if (macro || (js && !haxefmod_html5_allow_unsupported))
    /** The record cursor in PCM samples, or -1 on failure (unsupported in HTML5, always -1 there). */
    public static macro function getRecordPosition(id:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("StudioSystem.getRecordPosition", "the web build has no microphone recording");
    }
    #else
    /** The record cursor in PCM samples, or -1 on failure (unsupported in HTML5, always -1 there). */
    public static inline function getRecordPosition(id:Int):Int {
        return NativeStudio.sys_get_record_position(id);
    }
    #end

    //// System callbacks

    /**
     * Installs a handler for system events (device changes from the core
     * system, bank unloads and Live Update connections from Studio).
     * Events are delivered from the callback drain on the game thread,
     * one handler at a time, registering again replaces it.
     *
     * coreMask defaults to DEVICELISTCHANGED | DEVICELOST and studioMask
     * to BANK_UNLOAD | LIVEUPDATE_CONNECTED | LIVEUPDATE_DISCONNECTED (the
     * SystemCallbacks constants). PreUpdate and PostUpdate fire on every
     * update, so add STUDIO_PREUPDATE or STUDIO_POSTUPDATE to studioMask
     * only when needed.
     *
     * BankUnload carries the path when the bank went through Bank.unload
     * or unloadAll (FMOD refuses reads on the bank inside the callback, so
     * the bindings read the path ahead of the unload). A bank that FMOD
     * drops on its own arrives with an empty path. On HTML5 the core
     * device events never fire under the browser output.
     */
    public static function setSystemCallback(handler:SystemEvent->Void, ?coreMask:Int, ?studioMask:Int):Void {
        SystemCallbacks.set(handler, coreMask, studioMask);
    }

    /** Removes the system callback handler and both native callbacks. */
    public static function clearSystemCallback():Void {
        SystemCallbacks.clear();
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
            guid: NativeStudio.sys_last_parameter_guid(),
        };
    }

    //// System extras

    /**
     * Holds the mixer until unlockDsp so several graph edits (adding,
     * removing, or reconnecting DSPs) land in one mixer update instead
     * of being heard one at a time. Keep the section short, the mixer
     * waits for it.
     */
    public static inline function lockDsp():FmodResult {
        return NativeStudio.sys_lock_dsp();
    }

    /** Releases the mixer held by lockDsp. */
    public static inline function unlockDsp():FmodResult {
        return NativeStudio.sys_unlock_dsp();
    }

    /**
     * What FMOD would load for an audio table key: the file it reports
     * (empty for a bank held in memory), the ChannelMode flags, where the
     * sample sits in that file, and the subsound index inside it. Null when
     * the key is not in any loaded audio table (lastResult says why).
     */
    public static function getSoundInfo(key:String):Null<FmodSoundInfo> {
        var name = NativeStudio.sys_get_sound_info(key);
        if (!lastResult().isOk()) return null;
        return {
            name: name,
            subSoundIndex: Scratch.readI(0),
            mode: Scratch.readI(1),
            length: Scratch.readI(2),
            fileOffset: Scratch.readI(3),
            initialSubsound: Scratch.readI(4),
            numSubsounds: Scratch.readI(5),
        };
    }

    /**
     * Bytes FMOD currently has allocated and the most it has ever had.
     * blocking makes FMOD flush pending commands first so the numbers are
     * exact. Null on failure.
     */
    public static function getMemoryStats(blocking:Bool = false):Null<{current:Int, maximum:Int}> {
        var result:FmodResult = NativeStudio.sys_get_memory_stats(blocking);
        if (!result.isOk()) return null;
        return {current: Scratch.readI(0), maximum: Scratch.readI(1)};
    }

    /**
     * Bytes FMOD has read from disk since init, split by sample loads,
     * streams, and everything else (banks, plugins). The counts are 64-bit
     * so they come back as Floats. Null on failure.
     */
    public static function getFileUsage():Null<{sampleBytesRead:Float, streamBytesRead:Float, otherBytesRead:Float}> {
        var result:FmodResult = NativeStudio.sys_get_file_usage();
        if (!result.isOk()) return null;
        return {sampleBytesRead: Scratch.readF(0), streamBytesRead: Scratch.readF(1), otherBytesRead: Scratch.readF(2)};
    }
    // Plugins. Plugin handles are FMOD's own ids, not haxefmod handles, so
    // they never show up in liveHandleCount and a stale one is reported by
    // FMOD as FMOD_ERR_INVALID_HANDLE.

#if (macro || (js && !haxefmod_html5_allow_unsupported))
    /** Sets the directory FMOD searches for plugins given by file name (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED). */
    public static macro function setPluginPath(path:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("StudioSystem.setPluginPath", "the web build has no plugin host");
    }
    #else
    /** Sets the directory FMOD searches for plugins given by file name (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED). */
    public static inline function setPluginPath(path:String):FmodResult {
        return NativeStudio.sys_set_plugin_path(path == null ? "" : path);
    }
    #end

#if (macro || (js && !haxefmod_html5_allow_unsupported))
    /**
     * Loads a plugin shared library and returns FMOD's plugin handle
     * (unsupported in HTML5, returns 0 there). 0 on failure with the reason
     * in lastResult, FMOD_ERR_FILE_NOTFOUND for a missing file. A relative
     * path is resolved against setPluginPath, not the working directory.
     */
    public static macro function loadPlugin(path:haxe.macro.Expr, ?priority:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("StudioSystem.loadPlugin", "the web build has no plugin host");
    }
    #else
    /**
     * Loads a plugin shared library and returns FMOD's plugin handle
     * (unsupported in HTML5, returns 0 there). 0 on failure with the reason
     * in lastResult, FMOD_ERR_FILE_NOTFOUND for a missing file. A relative
     * path is resolved against setPluginPath, not the working directory.
     */
    public static inline function loadPlugin(path:String, priority:Int = 0):Int {
        return NativeStudio.sys_load_plugin(path == null ? "" : path, priority);
    }
    #end

#if (macro || (js && !haxefmod_html5_allow_unsupported))
    /**
     * Unloads a plugin from loadPlugin (unsupported in HTML5, returns
     * FMOD_ERR_UNSUPPORTED). Release every Dsp created from it first. FMOD
     * frees a released unit from its mixer thread, so an unload that
     * answers FMOD_ERR_DSP_INUSE right after the release succeeds when it
     * is retried a few frames later.
     */
    public static macro function unloadPlugin(handle:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("StudioSystem.unloadPlugin", "the web build has no plugin host");
    }
    #else
    /**
     * Unloads a plugin from loadPlugin (unsupported in HTML5, returns
     * FMOD_ERR_UNSUPPORTED). Release every Dsp created from it first. FMOD
     * frees a released unit from its mixer thread, so an unload that
     * answers FMOD_ERR_DSP_INUSE right after the release succeeds when it
     * is retried a few frames later.
     */
    public static inline function unloadPlugin(handle:Int):FmodResult {
        return NativeStudio.sys_unload_plugin(handle);
    }
    #end

#if (macro || (js && !haxefmod_html5_allow_unsupported))
    /** The number of plugins of one type, built-in ones included (unsupported in HTML5, -1 there). -1 on failure. */
    public static macro function getPluginCount(type:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("StudioSystem.getPluginCount", "the web build has no plugin host");
    }
    #else
    /** The number of plugins of one type, built-in ones included (unsupported in HTML5, -1 there). -1 on failure. */
    public static inline function getPluginCount(type:FmodPluginType):Int {
        return NativeStudio.sys_get_num_plugins(type);
    }
    #end

#if (macro || (js && !haxefmod_html5_allow_unsupported))
    /** The plugin handle at an index within one type (unsupported in HTML5, 0 there). 0 for an index out of range. */
    public static macro function getPluginHandle(type:haxe.macro.Expr, index:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("StudioSystem.getPluginHandle", "the web build has no plugin host");
    }
    #else
    /** The plugin handle at an index within one type (unsupported in HTML5, 0 there). 0 for an index out of range. */
    public static inline function getPluginHandle(type:FmodPluginType, index:Int):Int {
        return NativeStudio.sys_get_plugin_handle(type, index);
    }
    #end

#if (macro || (js && !haxefmod_html5_allow_unsupported))
    /** The name, type and version a plugin registered (unsupported in HTML5, null there). Null for an unknown handle. */
    public static macro function getPluginInfo(handle:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("StudioSystem.getPluginInfo", "the web build has no plugin host");
    }
    #else
    /** The name, type and version a plugin registered (unsupported in HTML5, null there). Null for an unknown handle. */
    public static function getPluginInfo(handle:Int):Null<{name:String, type:FmodPluginType, version:Int}> {
        var name = NativeStudio.sys_get_plugin_info(handle);
        if (!lastResult().isOk()) return null;
        return {name: name, type: (Scratch.readI(0) : FmodPluginType), version: Scratch.readI(1)};
    }
    #end

#if (macro || (js && !haxefmod_html5_allow_unsupported))
    /** The number of plugins a loaded library contains, 1 for a plain plugin (unsupported in HTML5, -1 there). -1 on failure. */
    public static macro function getNestedPluginCount(handle:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("StudioSystem.getNestedPluginCount", "the web build has no plugin host");
    }
    #else
    /** The number of plugins a loaded library contains, 1 for a plain plugin (unsupported in HTML5, -1 there). -1 on failure. */
    public static inline function getNestedPluginCount(handle:Int):Int {
        return NativeStudio.sys_get_num_nested_plugins(handle);
    }
    #end

#if (macro || (js && !haxefmod_html5_allow_unsupported))
    /** The handle of one plugin inside a loaded library (unsupported in HTML5, 0 there). 0 for an index out of range. */
    public static macro function getNestedPlugin(handle:haxe.macro.Expr, index:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("StudioSystem.getNestedPlugin", "the web build has no plugin host");
    }
    #else
    /** The handle of one plugin inside a loaded library (unsupported in HTML5, 0 there). 0 for an index out of range. */
    public static inline function getNestedPlugin(handle:Int, index:Int):Int {
        return NativeStudio.sys_get_nested_plugin(handle, index);
    }
    #end

    //// Advanced settings readback

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /**
     * The core advanced settings FMOD is running with, or null on failure
     * (unsupported in HTML5, null there). Set them through FmodSettings
     * before init.
     */
    public static macro function getAdvancedSettings():haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("StudioSystem.getAdvancedSettings", "the web build's advanced settings getter rejects every call");
    }
    #else
    /**
     * The core advanced settings FMOD is running with, or null on failure
     * (unsupported in HTML5, null there). Set them through FmodSettings
     * before init.
     */
    public static function getAdvancedSettings():Null<FmodAdvancedSettings> {
        var result:FmodResult = NativeStudio.sys_get_advanced_settings();
        if (!result.isOk()) return null;
        return {
            maxMPEGCodecs: Scratch.readI(0),
            maxVorbisCodecs: Scratch.readI(1),
            maxFADPCMCodecs: Scratch.readI(2),
            defaultDecodeBufferSize: Scratch.readI(3),
            profilePort: Scratch.readI(4),
            geometryMaxFadeTime: Scratch.readI(5),
            randomSeed: Scratch.readI(6),
            vol0VirtualVol: Scratch.readF(0),
            distanceFilterCenterFreq: Scratch.readF(1),
        };
    }
    #end

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /**
     * The studio advanced settings FMOD is running with, or null on failure
     * (unsupported in HTML5, null there). The encryption key is never read back.
     */
    public static macro function getStudioAdvancedSettings():haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("StudioSystem.getStudioAdvancedSettings", "the web build's advanced settings getter rejects every call");
    }
    #else
    /**
     * The studio advanced settings FMOD is running with, or null on failure
     * (unsupported in HTML5, null there). The encryption key is never read back.
     */
    public static function getStudioAdvancedSettings():Null<FmodStudioAdvancedSettings> {
        var result:FmodResult = NativeStudio.sys_get_studio_advanced_settings();
        if (!result.isOk()) return null;
        return {
            commandQueueSize: Scratch.readI(0),
            handleInitialSize: Scratch.readI(1),
            studioUpdatePeriod: Scratch.readI(2),
            idleSampleDataPoolSize: Scratch.readI(3),
            streamingScheduleDelay: Scratch.readI(4),
        };
    }
    #end
}
