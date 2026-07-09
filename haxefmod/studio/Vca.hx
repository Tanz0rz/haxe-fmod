package haxefmod.studio;

import haxefmod.studio.native.NativeStudio;

/**
 * A handle to an FMOD Studio VCA.
 *
 * Obtain via StudioSystem.getVCA("vca:/..."). Handles are plain ints under
 * the hood; a stale or invalid handle makes every call a safe no-op (getters
 * return defaults, setters return FMOD_ERR_INVALID_HANDLE).
 */
abstract Vca(Int) from Int to Int {
    public static inline var NULL:Vca = cast 0;

    /** True if this is the invalid handle (lookup failed). */
    public inline function isNull():Bool {
        return this == 0;
    }

    /** True if the handle resolves to a live FMOD VCA. */
    public inline function isValid():Bool {
        return this != 0 && NativeStudio.vca_is_valid(this);
    }

    /** The VCA GUID as a string, e.g. "{1f687138-e06c-40f5-9bac-57f84bbcedd3}". */
    public inline function getID():String {
        return NativeStudio.vca_get_id(this);
    }

    /** The full VCA path, e.g. "vca:/Environment". */
    public inline function getPath():String {
        return NativeStudio.vca_get_path(this);
    }

    /** The volume as set by the API (linear: 0.0 = silent, 1.0 = full). */
    public inline function getVolume():Float {
        return NativeStudio.vca_get_volume(this);
    }

    /** The final combined volume (set volume x snapshots/automation). */
    public inline function getFinalVolume():Float {
        return NativeStudio.vca_get_final_volume(this);
    }

    public inline function setVolume(volume:Float):FmodResult {
        return NativeStudio.vca_set_volume(this, volume);
    }
}
