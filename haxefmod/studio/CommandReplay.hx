package haxefmod.studio;

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
        return NativeStudio.replay_release(this);
    }
}
