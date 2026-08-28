package haxefmod.studio;

import haxefmod.studio.UserData;
import haxefmod.studio.native.NativeStudio;
import haxefmod.studio.native.Scratch;
import haxefmod.studio.Types;

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

    /** Number of commands in the capture, -1 on failure. */
    public inline function getCommandCount():Int {
        return NativeStudio.replay_get_command_count(this);
    }

    /** Details of the command at index, or null on failure. */
    public function getCommandInfo(index:Int):Null<FmodCommandInfo> {
        var name = NativeStudio.replay_get_command_info(this, index);
        if (!StudioSystem.lastResult().isOk()) return null;
        return {
            commandName: name,
            parentCommandIndex: Scratch.readI(5),
            frameNumber: Scratch.readI(4),
            frameTime: Scratch.readF(0),
            instanceType: (Scratch.readI(0) : FmodStudioInstanceType),
            outputType: (Scratch.readI(1) : FmodStudioInstanceType),
            instanceHandle: Scratch.readI(2),
            outputHandle: Scratch.readI(3),
        };
    }

    /** The command at index formatted the way FMOD's tools print it, or "" on failure. */
    public inline function getCommandString(index:Int):String {
        return NativeStudio.replay_get_command_string(this, index);
    }

    /** Index of the command playing at timeMs into the capture, -1 on failure. */
    public inline function getCommandAtTime(timeMs:Int):Int {
        return NativeStudio.replay_get_command_at_time(this, timeMs / 1000.0);
    }

    public inline function seekToCommand(index:Int):FmodResult {
        return NativeStudio.replay_seek_to_command(this, index);
    }

    /** Playback state of the replay, STOPPED on failure. */
    public inline function getPlaybackState():FmodPlaybackState {
        return NativeStudio.replay_get_playback_state(this);
    }

    /** Directory the replay loads banks from when the captured paths no longer apply. */
    public inline function setBankPath(path:String):FmodResult {
        return NativeStudio.replay_set_bank_path(this, path);
    }
    /**
     * The index of the command the replay is on and the playback time in
     * seconds, or null on failure.
     */
    public function getCurrentCommand():Null<{index:Int, time:Float}> {
        var index = NativeStudio.replay_get_current_command(this);
        if (!StudioSystem.lastResult().isOk()) return null;
        return {index: index, time: Scratch.readF(0)};
    }

}
