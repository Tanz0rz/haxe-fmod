package haxefmod.studio;

import haxefmod.studio.UserData;
import haxefmod.studio.Types;
import haxefmod.studio.native.NativeStudio;

/**
 * A handle to an FMOD Studio VCA.
 *
 * Obtain via StudioSystem.getVCA("vca:/..."). Handles are plain ints under
 * the hood. A stale or invalid handle makes every call a safe no-op (getters
 * return defaults, setters return FMOD_ERR_INVALID_HANDLE).
 */
abstract Vca(Int) from Int to Int {
    /** The null handle. Every call on it is a safe no-op. */
    public static inline var NULL:Vca = cast 0;

    /** True if this is the invalid handle (lookup failed). */
    public inline function isNull():Bool {
        return this == 0;
    }

    /** True if the handle resolves to a live FMOD VCA. */
    public inline function isValid():Bool {
        return this != 0 && NativeStudio.vca_is_valid(this);
    }

    /** The VCA GUID. Returns an empty FmodGuid on failure, with the reason in StudioSystem.lastResult(). */
    public inline function getID():FmodGuid {
        return NativeStudio.vca_get_id(this);
    }

    /**
     * The full VCA path, e.g. "vca:/Environment". Returns "" on failure, with the reason in
     * StudioSystem.lastResult().
     */
    public inline function getPath():String {
        return NativeStudio.vca_get_path(this);
    }

    /**
     * The volume as set by the API (linear: 0.0 = silent, 1.0 = full). Returns 0.0 both on failure and for a
     * silent VCA. StudioSystem.lastResult() tells the two apart.
     */
    public inline function getVolume():Float {
        return NativeStudio.vca_get_volume(this);
    }

    /**
     * The final combined volume (set volume x snapshots/automation). Returns 0.0 both on failure and for a
     * silent VCA. StudioSystem.lastResult() tells the two apart.
     */
    public inline function getFinalVolume():Float {
        return NativeStudio.vca_get_final_volume(this);
    }

    /** Sets the volume as a linear level (0.0 = silent, 1.0 = full). */
    public inline function setVolume(volume:Float):FmodResult {
        return NativeStudio.vca_set_volume(this, volume);
    }

    /**
     * Attaches a Haxe value to this handle. The value lives on the Haxe
     * side keyed by the handle and is dropped by StudioSystem.unloadAll.
     * A recycled native slot gets a new generation and therefore a new
     * handle int, so a stale entry does not show up on the next handle
     * in that slot.
     */
    public inline function setUserData(value:Dynamic):Void {
        UserData.set(UserDataKind.Vca, this, value);
    }

    /** The value attached with setUserData, or null. */
    public inline function getUserData():Dynamic {
        return UserData.get(UserDataKind.Vca, this);
    }
}
