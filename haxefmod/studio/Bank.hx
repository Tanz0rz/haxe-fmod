package haxefmod.studio;

import haxefmod.studio.Types;
import haxefmod.studio.native.NativeStudio;
import haxefmod.studio.native.Scratch;

/**
 * A handle to a loaded FMOD Studio bank.
 *
 * Obtain via StudioSystem.loadBankFile or StudioSystem.getBank. Handles are
 * plain ints under the hood. A stale or invalid handle makes every call a
 * safe no-op (getters return defaults, setters return FMOD_ERR_INVALID_HANDLE).
 */
abstract Bank(Int) from Int to Int {
    public static inline var NULL:Bank = cast 0;

    /** True if this is the invalid handle (lookup/load failed). */
    public inline function isNull():Bool {
        return this == 0;
    }

    /** True if the handle resolves to a live FMOD bank. */
    public inline function isValid():Bool {
        return this != 0 && NativeStudio.bank_is_valid(this);
    }

    /** The bank GUID as a string. */
    public inline function getID():String {
        return NativeStudio.bank_get_id(this);
    }

    /** The full bank path, e.g. "bank:/Master". */
    public inline function getPath():String {
        return NativeStudio.bank_get_path(this);
    }

    /**
     * Unloads the bank and invalidates this handle (and every event
     * description/instance handle that came from it).
     */
    public inline function unload():FmodResult {
        return NativeStudio.bank_unload(this);
    }

    /** Loads all non-streaming sample data for the bank's events. */
    public inline function loadSampleData():FmodResult {
        return NativeStudio.bank_load_sample_data(this);
    }

    public inline function unloadSampleData():FmodResult {
        return NativeStudio.bank_unload_sample_data(this);
    }

    /** Loading state of the bank metadata (poll after NONBLOCKING loads). */
    public inline function getLoadingState():FmodLoadingState {
        return NativeStudio.bank_get_loading_state(this);
    }

    /** Loading state of the bank's sample data. */
    public inline function getSampleLoadingState():FmodLoadingState {
        return NativeStudio.bank_get_sample_loading_state(this);
    }

    /** Number of event descriptions in the bank. */
    public inline function getEventCount():Int {
        return NativeStudio.bank_get_event_count(this);
    }

    /** Event descriptions in the bank (up to Scratch.CAPACITY entries). */
    public function getEventList():Array<EventDescription> {
        var count = NativeStudio.bank_get_event_list(this);
        warnTruncated("event", count, getEventCount());
        return [for (i in 0...count) (Scratch.readI(i) : EventDescription)];
    }

    public inline function getBusCount():Int {
        return NativeStudio.bank_get_bus_count(this);
    }

    /** Buses in the bank (up to Scratch.CAPACITY entries). */
    public function getBusList():Array<Bus> {
        var count = NativeStudio.bank_get_bus_list(this);
        warnTruncated("bus", count, getBusCount());
        return [for (i in 0...count) (Scratch.readI(i) : Bus)];
    }

    public inline function getVCACount():Int {
        return NativeStudio.bank_get_vca_count(this);
    }

    /** VCAs in the bank (up to Scratch.CAPACITY entries). */
    public function getVCAList():Array<Vca> {
        var count = NativeStudio.bank_get_vca_list(this);
        warnTruncated("VCA", count, getVCACount());
        return [for (i in 0...count) (Scratch.readI(i) : Vca)];
    }

    static function warnTruncated(kind:String, returned:Int, total:Int):Void {
        if (total > returned) {
            trace('Warn: FMOD - bank $kind list truncated ($returned of $total); raise FAXE_LIST_MAX/Scratch.CAPACITY');
        }
    }

    /** Number of entries in the bank's string table (strings banks only). */
    public inline function getStringCount():Int {
        return NativeStudio.bank_get_string_count(this);
    }

    /** String table path by index (e.g. "event:/Music/MainLevel"). */
    public inline function getStringPath(index:Int):String {
        return NativeStudio.bank_get_string_info(this, index);
    }

    /** String table GUID by index, formatted "{8-4-4-4-12}". */
    public inline function getStringGuid(index:Int):String {
        return NativeStudio.bank_get_string_guid(this, index);
    }
}
