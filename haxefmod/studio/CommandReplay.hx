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
    /** The invalid handle, what loadCommandReplay returns on failure. */
    public static inline var NULL:CommandReplay = cast 0;

    /** True for the invalid handle. */
    public inline function isNull():Bool {
        return this == 0;
    }

    /** True while the handle points at a live FMOD replay object. */
    public inline function isValid():Bool {
        return this != 0 && NativeStudio.replay_is_valid(this);
    }

    /** Begins playing the captured commands into the Studio system. */
    public inline function start():FmodResult {
        return NativeStudio.replay_start(this);
    }

    /** Stops the replay. */
    public inline function stop():FmodResult {
        return NativeStudio.replay_stop(this);
    }

    /** Pauses or resumes the replay. */
    public inline function setPaused(paused:Bool):FmodResult {
        return NativeStudio.replay_set_paused(this, paused);
    }

    /**
     * True while the replay is paused, false on failure. A running replay reports false as well.
     * StudioSystem.lastResult() tells the two apart.
     */
    public inline function getPaused():Bool {
        return NativeStudio.replay_get_paused(this);
    }

    /** Moves playback to a time in seconds into the capture. */
    public inline function seekToTime(seconds:Float):FmodResult {
        return NativeStudio.replay_seek_to_time(this, seconds);
    }

    @:deprecated("CommandReplay.seekToTimeMs is now seekToTime, which takes seconds")
    public inline function seekToTimeMs(timeMs:Int):FmodResult {
        return seekToTime(timeMs / 1000.0);
    }

    /**
     * Total capture length in seconds. Returns 0.0 both on failure and for an empty capture.
     * StudioSystem.lastResult() tells the two apart.
     */
    public inline function getLength():Float {
        return NativeStudio.replay_get_length(this);
    }

    /** Frees the replay and invalidates this handle. */
    public inline function release():FmodResult {
        var result:FmodResult = NativeStudio.replay_release(this);
        if (UserData.releaseTookEffect(result)) UserData.clear(UserDataKind.CommandReplay, this);
        return result;
    }

    /**
     * Attaches a Haxe value to this handle. The value lives on the Haxe
     * side keyed by the handle and is dropped when the handle is released.
     * A recycled native slot gets a new generation and therefore a new
     * handle int. Thus a stale entry does not show up on the next handle
     * in that slot.
     */
    public inline function setUserData(value:Dynamic):Void {
        UserData.set(UserDataKind.CommandReplay, this, value);
    }

    /** The value attached with setUserData, or null. */
    public inline function getUserData():Dynamic {
        return UserData.get(UserDataKind.CommandReplay, this);
    }

    /** Number of commands in the capture, -1 on failure. StudioSystem.lastResult() holds the reason for a failure. */
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

    /**
     * The command at index formatted the way FMOD's tools print it, or "" on failure. StudioSystem.lastResult()
     * holds the reason for a failure.
     */
    public inline function getCommandString(index:Int):String {
        return NativeStudio.replay_get_command_string(this, index);
    }

    /**
     * Index of the command playing at a time in seconds into the capture, -1 on failure.
     * StudioSystem.lastResult() holds the reason for a failure.
     */
    public inline function getCommandAtTime(seconds:Float):Int {
        return NativeStudio.replay_get_command_at_time(this, seconds);
    }

    /** Moves the replay to the command at the index. */
    public inline function seekToCommand(index:Int):FmodResult {
        return NativeStudio.replay_seek_to_command(this, index);
    }

    /**
     * Playback state of the replay. Returns STOPPED both on failure and for a stopped replay.
     * StudioSystem.lastResult() tells the two apart.
     */
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
    public function getCurrentCommand():Null<FmodReplayCommand> {
        var index = NativeStudio.replay_get_current_command(this);
        if (!StudioSystem.lastResult().isOk()) return null;
        return {index: index, time: Scratch.readF(0)};
    }

}
