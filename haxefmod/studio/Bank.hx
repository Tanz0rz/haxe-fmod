package haxefmod.studio;

import haxefmod.studio.Types;
import haxefmod.studio.UserData;
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
    /** The null handle. Every call on it is a safe no-op. */
    public static inline var NULL:Bank = cast 0;

    /** True if this is the invalid handle (lookup/load failed). */
    public inline function isNull():Bool {
        return this == 0;
    }

    /** True if the handle resolves to a live FMOD bank. */
    public inline function isValid():Bool {
        return this != 0 && NativeStudio.bank_is_valid(this);
    }

    /** The bank GUID. Returns an empty FmodGuid on failure, with the reason in StudioSystem.lastResult(). */
    public inline function getID():FmodGuid {
        return NativeStudio.bank_get_id(this);
    }

    /**
     * The full bank path, e.g. "bank:/Master". Returns "" on failure, with the reason in
     * StudioSystem.lastResult().
     */
    public inline function getPath():String {
        return NativeStudio.bank_get_path(this);
    }

    /**
     * Unloads the bank and invalidates this handle and every event
     * description and instance handle that died with it. The userdata
     * and the description-level callbacks of those descriptions are
     * dropped, for the first 1024 events of the bank. A description
     * another loaded bank still owns keeps both. A larger bank keeps the
     * rest until StudioSystem.unloadAll. The handler and user data of
     * every channel group that died with the bank go too.
     */
    public function unload():FmodResult {
        // The descriptions are read while the bank is loaded, and their
        // entries go once FMOD accepted the unload or reported the bank gone
        var descriptions = getEventList();
        var result:FmodResult = NativeStudio.bank_unload(this);
        if (UserData.releaseTookEffect(result)) {
            for (description in descriptions) {
                // An event assigned to another loaded bank survives the
                // unload, and the native sweep freed the slots of the dead
                if (NativeStudio.debug_handle_is_live(description)) continue;
                UserData.clear(UserDataKind.EventDescription, description);
                description.clearCallback();
            }
            UserData.clear(UserDataKind.Bank, this);
            EventInstance.dropDeadGroups();
        }
        return result;
    }

    /** Loads all non-streaming sample data for the bank's events. */
    public inline function loadSampleData():FmodResult {
        return NativeStudio.bank_load_sample_data(this);
    }

    /** Unloads the non-streaming sample data for the bank's events. FMOD reference counts it, so it stays loaded until every load has a matching unload. */
    public inline function unloadSampleData():FmodResult {
        return NativeStudio.bank_unload_sample_data(this);
    }

    /**
     * Loading state of the bank metadata (poll after NONBLOCKING loads). Returns FmodLoadingState.UNLOADED both
     * on failure and for a bank that is not loaded. StudioSystem.lastResult() tells the two apart.
     */
    public inline function getLoadingState():FmodLoadingState {
        return NativeStudio.bank_get_loading_state(this);
    }

    /**
     * Loading state of the bank's sample data. Returns FmodLoadingState.UNLOADED both on failure and for sample
     * data that is not loaded. StudioSystem.lastResult() tells the two apart.
     */
    public inline function getSampleLoadingState():FmodLoadingState {
        return NativeStudio.bank_get_sample_loading_state(this);
    }

    /**
     * Number of event descriptions in the bank. Returns 0 both on failure and for a bank with no events.
     * StudioSystem.lastResult() tells the two apart.
     */
    public inline function getEventCount():Int {
        return NativeStudio.bank_get_event_count(this);
    }

    /** Event descriptions in the bank (up to Scratch.CAPACITY entries). */
    public function getEventList():Array<EventDescription> {
        var count = NativeStudio.bank_get_event_list(this);
        Scratch.warnTruncated("bank event", count, getEventCount());
        return [for (i in 0...count) (Scratch.readI(i) : EventDescription)];
    }

    /**
     * Number of buses in the bank. Returns 0 both on failure and for a bank with no buses.
     * StudioSystem.lastResult() tells the two apart.
     */
    public inline function getBusCount():Int {
        return NativeStudio.bank_get_bus_count(this);
    }

    /** Buses in the bank (up to Scratch.CAPACITY entries). */
    public function getBusList():Array<Bus> {
        var count = NativeStudio.bank_get_bus_list(this);
        Scratch.warnTruncated("bank bus", count, getBusCount());
        return [for (i in 0...count) (Scratch.readI(i) : Bus)];
    }

    /**
     * Number of VCAs in the bank. Returns 0 both on failure and for a bank with no VCAs.
     * StudioSystem.lastResult() tells the two apart.
     */
    public inline function getVCACount():Int {
        return NativeStudio.bank_get_vca_count(this);
    }

    /** VCAs in the bank (up to Scratch.CAPACITY entries). */
    public function getVCAList():Array<Vca> {
        var count = NativeStudio.bank_get_vca_list(this);
        Scratch.warnTruncated("bank VCA", count, getVCACount());
        return [for (i in 0...count) (Scratch.readI(i) : Vca)];
    }

    /**
     * Number of entries in the bank's string table (strings banks only). Returns 0 both on failure and for a
     * bank with no string table. StudioSystem.lastResult() tells the two apart.
     */
    public inline function getStringCount():Int {
        return NativeStudio.bank_get_string_count(this);
    }

    /**
     * String table path by index (e.g. "event:/Music/MainLevel"). Returns "" on failure, with the reason in
     * StudioSystem.lastResult().
     */
    public inline function getStringPath(index:Int):String {
        return NativeStudio.bank_get_string_info(this, index);
    }

    /**
     * String table GUID by index. Returns an empty FmodGuid on failure, with the reason in
     * StudioSystem.lastResult().
     */
    public inline function getStringGuid(index:Int):FmodGuid {
        return NativeStudio.bank_get_string_guid(this, index);
    }

    /** A string table entry's GUID and path together, null for an index out of range. */
    public function getStringInfo(index:Int):Null<FmodBankStringInfo> {
        var path = NativeStudio.bank_get_string_info(this, index);
        if (!StudioSystem.lastResult().isOk()) return null;
        return {id: NativeStudio.bank_get_string_guid(this, index), path: path};
    }

    /**
     * Attaches a Haxe value to this handle. The value lives on the Haxe
     * side keyed by the handle and is dropped when the handle is released.
     * A recycled native slot gets a new generation and therefore a new
     * handle int. Thus a stale entry does not show up on the next handle
     * in that slot.
     */
    public inline function setUserData(value:Dynamic):Void {
        UserData.set(UserDataKind.Bank, this, value);
    }

    /** The value attached with setUserData, or null. */
    public inline function getUserData():Dynamic {
        return UserData.get(UserDataKind.Bank, this);
    }
}
