package haxefmod.studio;

import haxefmod.studio.native.NativeStudio;

/**
 * A handle to an FMOD Core sound - the micro subset of the Core API shipped
 * for programmer sounds. Create from an audio file (native: a path on disk;
 * html5: a file preloaded into the virtual filesystem).
 *
 * The full Core API is out of scope for 2.0; this exists so games can
 * inspect and manage the loose audio files they feed to programmer sounds.
 */
abstract CoreSound(Int) from Int to Int {
    public static inline var NULL:CoreSound = cast 0;

    /** Loads a sound file. Returns CoreSound.NULL on failure (see StudioSystem.lastResult). */
    public static inline function create(path:String, loop:Bool = false):CoreSound {
        return NativeStudio.core_create_sound(path, loop ? 1 : 0);
    }

    public inline function isNull():Bool {
        return this == 0;
    }

    /** Length in milliseconds, or -1 on failure. */
    public inline function getLength():Int {
        return NativeStudio.core_get_sound_length(this);
    }

    /** Releases the sound and invalidates this handle. */
    public inline function release():FmodResult {
        return NativeStudio.core_release_sound(this);
    }
}
