package haxefmod.studio;

import haxefmod.studio.UserData;
import haxefmod.studio.native.NativeStudio;

/**
 * A handle to a loaded command capture, played back through the live
 * system. Capture a session with StudioSystem.startCommandCapture, then
 * load the file here (or hand it to FMOD's tools for analysis).
 */
abstract CommandReplay(Int) from Int to Int {
    public static inline var NULL:CommandReplay = cast 0;

    public inline function isNull():Bool {
        return this == 0;
    }

    /** True while the handle points at a live FMOD replay object. */
    public inline function isValid():Bool {
        return this != 0 && NativeStudio.replay_is_valid(this);
    }

    public inline function start():FmodResult {
        return NativeStudio.replay_start(this);
    }

    public inline function stop():FmodResult {
        return NativeStudio.replay_stop(this);
    }

    public inline function setPaused(paused:Bool):FmodResult {
        return NativeStudio.replay_set_paused(this, paused);
    }

    public inline function getPaused():Bool {
        return NativeStudio.replay_get_paused(this);
    }

    public inline function seekToTime(timeMs:Int):FmodResult {
        return NativeStudio.replay_seek_to_time(this, timeMs);
    }

    /** Total capture length in seconds. */
    public inline function getLength():Float {
        return NativeStudio.replay_get_length(this);
    }

    /** Frees the replay and invalidates this handle. */
    public inline function release():FmodResult {
        UserData.clear(UserDataKind.CommandReplay, this);
        return NativeStudio.replay_release(this);
    }

    /**
     * Attaches a Haxe value to this handle. The value lives on the Haxe
     * side keyed by the handle and is dropped when the handle is released.
     * A recycled native slot gets a new generation and therefore a new
     * handle int, so a stale entry never shows up on a later handle.
     */
    public inline function setUserData(value:Dynamic):Void {
        UserData.set(UserDataKind.CommandReplay, this, value);
    }

    /** The value attached with setUserData, or null. */
    public inline function getUserData():Dynamic {
        return UserData.get(UserDataKind.CommandReplay, this);
    }
}
