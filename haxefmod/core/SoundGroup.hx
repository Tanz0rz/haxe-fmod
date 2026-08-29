package haxefmod.core;

import haxefmod.studio.FmodResult;
import haxefmod.studio.Types.SoundGroupBehavior;
import haxefmod.studio.UserData;
import haxefmod.studio.native.NativeStudio;

/**
 * A handle to an FMOD sound group: polyphony caps and behaviors across any
 * set of sounds (e.g. at most three footstep sounds at once, stealing the
 * quietest). Assign sounds with Sound.setSoundGroup. Every sound
 * belongs to the master group until moved.
 */
abstract SoundGroup(Int) from Int to Int {
    public static inline var NULL:SoundGroup = cast 0;

    /** Behaviors when a group is past maxAudible, the same values as SoundGroupBehavior. */
    public static inline var BEHAVIOR_FAIL:SoundGroupBehavior = SoundGroupBehavior.FAIL;
    public static inline var BEHAVIOR_MUTE:SoundGroupBehavior = SoundGroupBehavior.MUTE;
    public static inline var BEHAVIOR_STEAL_LOWEST:SoundGroupBehavior = SoundGroupBehavior.STEALLOWEST;

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

    /** What happens to a new sound once the group is at maxAudible. */
    public inline function setMaxAudibleBehavior(behavior:SoundGroupBehavior):FmodResult {
        return NativeStudio.sg_set_max_audible_behavior(this, behavior);
    }

    /** The current behavior, FAIL on failure. */
    public inline function getMaxAudibleBehavior():SoundGroupBehavior {
        return NativeStudio.sg_get_max_audible_behavior(this);
    }

    /** Fade time in seconds when BEHAVIOR_MUTE kicks in (0 = instant). */
    public inline function setMuteFadeSpeed(seconds:Float):FmodResult {
        return NativeStudio.sg_set_mute_fade_speed(this, seconds);
    }

    /** Volume scale over every sound in the group (linear, 1.0 = full). */
    public inline function setVolume(volume:Float):FmodResult {
        return NativeStudio.sg_set_volume(this, volume);
    }

    public inline function getVolume():Float {
        return NativeStudio.sg_get_volume(this);
    }

    public inline function getMuteFadeSpeed():Float {
        return NativeStudio.sg_get_mute_fade_speed(this);
    }

    public inline function getSoundCount():Int {
        return NativeStudio.sg_get_num_sounds(this);
    }

    /** The name given at create(), "FMOD master" for the master group. */
    public inline function getName():String {
        return NativeStudio.sg_get_name(this);
    }

    /**
     * The sound at position index in this group (a known sound returns its
     * existing handle). Sound.NULL past the end. The group does not own
     * the sound, so do not release a handle obtained this way.
     */
    public inline function getSound(index:Int):haxefmod.core.Sound {
        return NativeStudio.sg_get_sound(this, index);
    }

    /** Sounds from this group audible right now. */
    public inline function getPlayingCount():Int {
        return NativeStudio.sg_get_num_playing(this);
    }

    /** The same count as getSoundCount under FMOD's name. */
    public inline function getNumSounds():Int {
        return NativeStudio.sg_get_num_sounds(this);
    }

    /** The same count as getPlayingCount under FMOD's name. */
    public inline function getNumPlaying():Int {
        return NativeStudio.sg_get_num_playing(this);
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
        UserData.clear(UserDataKind.SoundGroup, this);
        return NativeStudio.sg_release(this);
    }

    /**
     * Attaches a Haxe value to this handle. The value lives on the Haxe
     * side keyed by the handle and is dropped when the handle is released.
     * A recycled native slot gets a new generation and therefore a new
     * handle int, so a stale entry never shows up on a later handle.
     */
    public inline function setUserData(value:Dynamic):Void {
        UserData.set(UserDataKind.SoundGroup, this, value);
    }

    /** The value attached with setUserData, or null. */
    public inline function getUserData():Dynamic {
        return UserData.get(UserDataKind.SoundGroup, this);
    }
}
