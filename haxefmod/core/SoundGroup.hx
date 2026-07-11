package haxefmod.core;

import haxefmod.studio.FmodResult;
import haxefmod.studio.native.NativeStudio;

/**
 * A handle to an FMOD sound group: polyphony caps and behaviors across any
 * set of sounds (e.g. at most three footstep sounds at once, stealing the
 * quietest). Assign sounds with CoreSound.setSoundGroup. Every sound
 * belongs to the master group until moved.
 */
abstract SoundGroup(Int) from Int to Int {
    public static inline var NULL:SoundGroup = cast 0;

    /** Behaviors when a group is past maxAudible (FMOD_SOUNDGROUP_BEHAVIOR). */
    public static inline var BEHAVIOR_FAIL:Int = 0;
    public static inline var BEHAVIOR_MUTE:Int = 1;
    public static inline var BEHAVIOR_STEAL_LOWEST:Int = 2;

    /** Creates a group. Returns SoundGroup.NULL on failure. */
    public static inline function create(name:String):SoundGroup {
        return NativeStudio.sys_create_sound_group(name);
    }

    /** The master group every sound starts in. One shared handle per session. */
    public static inline function master():SoundGroup {
        return NativeStudio.sys_get_master_sound_group();
    }

    public inline function isNull():Bool {
        return this == 0;
    }

    /** Most sounds from this group audible at once (-1 = unlimited). */
    public inline function setMaxAudible(maxAudible:Int):FmodResult {
        return NativeStudio.sg_set_max_audible(this, maxAudible);
    }

    public inline function getMaxAudible():Int {
        return NativeStudio.sg_get_max_audible(this);
    }

    /** One of the BEHAVIOR_* values. */
    public inline function setMaxAudibleBehavior(behavior:Int):FmodResult {
        return NativeStudio.sg_set_max_audible_behavior(this, behavior);
    }

    public inline function getMaxAudibleBehavior():Int {
        return NativeStudio.sg_get_max_audible_behavior(this);
    }

    /** Fade time in seconds when BEHAVIOR_MUTE kicks in (0 = instant). */
    public inline function setMuteFadeSpeed(seconds:Float):FmodResult {
        return NativeStudio.sg_set_mute_fade_speed(this, seconds);
    }

    public inline function getSoundCount():Int {
        return NativeStudio.sg_get_num_sounds(this);
    }

    /** Stops every playing sound in the group. */
    public inline function stop():FmodResult {
        return NativeStudio.sg_stop(this);
    }

    /**
     * Frees a group made with create() and invalidates this handle. Its
     * sounds move back to the master group. Do not release the master.
     */
    public inline function release():FmodResult {
        return NativeStudio.sg_release(this);
    }
}
