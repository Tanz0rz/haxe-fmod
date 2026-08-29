package;

import haxefmod.core.ChannelGroup;
import haxefmod.core.CoreSystem;
import haxefmod.core.Dsp;
import haxefmod.core.DspType;
import haxefmod.core.Sound;
import haxefmod.studio.FmodResult;
import haxefmod.studio.StudioSystem;
import haxefmod.studio.Types;

/**
 * Probe for the system extras: command replay inspection, the DSP lock,
 * audio table sound info, memory and file statistics, the network
 * settings, and speaker positions. Every setting it changes is restored
 * before it returns.
 */
class ProbeSysExtras {
    public static function run(state:ApiProbeState):Void {
        // The master group handle is cached by the shim, so it is taken before the baseline
        var master = ChannelGroup.master();
        var baseline = StudioSystem.liveHandleCount();

        // A short capture to inspect. One update lands a frame of commands.
        var capturePath = "probe-sysextras.cmd.txt";
        @:privateAccess state.check("sysextras_capture_start", StudioSystem.startCommandCapture(capturePath).isOk(), "");
        FmodManager.Update();
        StudioSystem.flushCommands();
        @:privateAccess state.check("sysextras_capture_stop", StudioSystem.stopCommandCapture().isOk(), "");
        var replay = StudioSystem.loadCommandReplay(capturePath);
        @:privateAccess state.check("sysextras_replay_load", !replay.isNull(), 'handle=${(replay : Int)}');
        if (!replay.isNull()) {
            var count = replay.getCommandCount();
            @:privateAccess state.check("replay_get_command_count", count > 0, 'count=$count');
            var info = replay.getCommandInfo(0);
            @:privateAccess state.check("replay_get_command_info", info != null && info.commandName.length > 0
                && info.frameNumber == 0, info == null ? 'result=${StudioSystem.lastResult().toString()}'
                : 'name=${info.commandName} frame=${info.frameNumber} time=${info.frameTime} type=${info.instanceType}');
            var text = replay.getCommandString(0);
            @:privateAccess state.check("replay_get_command_string", text.length > 0 && info != null
                && StringTools.startsWith(text, info.commandName), 'text=$text');
            var atZero = replay.getCommandAtTime(0);
            @:privateAccess state.check("replay_get_command_at_time", atZero == 0, 'index=$atZero');
            var seek:FmodResult = replay.seekToCommand(0);
            @:privateAccess state.check("replay_seek_to_command", seek.isOk(), 'result=${seek.toString()}');
            @:privateAccess state.check("replay_get_playback_state", replay.getPlaybackState() == FmodPlaybackState.STOPPED,
                'state=${(replay.getPlaybackState() : Int)}');
            var bankPath:FmodResult = replay.setBankPath("assets/fmod/Desktop");
            @:privateAccess state.check("replay_set_bank_path", bankPath.isOk(), 'result=${bankPath.toString()}');
            // Out of range indices fail cleanly and leave the getters at their defaults
            @:privateAccess state.check("replay_get_command_info_out_of_range", replay.getCommandInfo(count + 10) == null, "");
            @:privateAccess state.check("replay_get_command_string_out_of_range", replay.getCommandString(count + 10) == "", "");
            replay.release();
        }
        @:privateAccess state.check("replay_get_command_count_stale", replay.getCommandCount() == -1
            && StudioSystem.lastResult() == FmodResult.FMOD_ERR_INVALID_HANDLE, "");
        @:privateAccess state.check("replay_seek_to_command_stale", replay.seekToCommand(0) == FmodResult.FMOD_ERR_INVALID_HANDLE, "");
        @:privateAccess state.check("replay_get_playback_state_stale", replay.getPlaybackState() == FmodPlaybackState.STOPPED, "");

        // The DSP lock around a pair of graph edits
        var lowpass = Dsp.create(DspType.LOWPASS_SIMPLE);
        var lock:FmodResult = StudioSystem.lockDsp();
        @:privateAccess state.check("sys_lock_dsp", lock.isOk(), 'result=${lock.toString()}');
        var added:FmodResult = master.addDsp(0, lowpass);
        var removed:FmodResult = master.removeDsp(lowpass);
        var unlock:FmodResult = StudioSystem.unlockDsp();
        @:privateAccess state.check("sys_unlock_dsp", unlock.isOk() && added.isOk() && removed.isOk(),
            'unlock=${unlock.toString()} add=${added.toString()} remove=${removed.toString()}');
        lowpass.release();

        // Sound info on a key no audio table holds
        var missing = StudioSystem.getSoundInfo("probe-sysextras-no-such-key");
        @:privateAccess state.check("sys_get_sound_info_missing", missing == null && !StudioSystem.lastResult().isOk(),
            'result=${StudioSystem.lastResult().toString()}');

        // Memory statistics, current is never zero on a running system
        var stats = StudioSystem.getMemoryStats();
        @:privateAccess state.check("sys_get_memory_stats", stats != null && stats.current > 0 && stats.maximum >= stats.current,
            stats == null ? 'result=${StudioSystem.lastResult().toString()}' : 'current=${stats.current} max=${stats.maximum}');
        var blocking = StudioSystem.getMemoryStats(true);
        @:privateAccess state.check("sys_get_memory_stats_blocking", blocking != null && blocking.current > 0,
            blocking == null ? 'result=${StudioSystem.lastResult().toString()}' : 'current=${blocking.current}');

        // File usage after a sound has been read from disk
        #if sys
        var wavPath = @:privateAccess ApiProbeState.writeProbeWav();
        var sound = Sound.create(wavPath);
        var channel = sound.play(true);
        channel.stop();
        sound.release();
        #end
        var usage = StudioSystem.getFileUsage();
        @:privateAccess state.check("sys_get_file_usage", usage != null && usage.sampleBytesRead + usage.streamBytesRead + usage.otherBytesRead > 0,
            usage == null ? 'result=${StudioSystem.lastResult().toString()}'
            : 'sample=${usage.sampleBytesRead} stream=${usage.streamBytesRead} other=${usage.otherBytesRead}');

        // Network proxy and timeout round trips, restored afterwards
        var proxyBefore = CoreSystem.getNetworkProxy();
        var timeoutBefore = CoreSystem.getNetworkTimeout();
        @:privateAccess state.check("sys_get_network_timeout_default", timeoutBefore > 0, 'value=$timeoutBefore');
        @:privateAccess state.check("sys_network_proxy_roundtrip", CoreSystem.setNetworkProxy("proxy.example:8080").isOk()
            && CoreSystem.getNetworkProxy() == "proxy.example:8080", 'value=${CoreSystem.getNetworkProxy()}');
        @:privateAccess state.check("sys_network_timeout_roundtrip", CoreSystem.setNetworkTimeout(1234).isOk()
            && CoreSystem.getNetworkTimeout() == 1234, 'value=${CoreSystem.getNetworkTimeout()}');
        CoreSystem.setNetworkProxy(proxyBefore);
        CoreSystem.setNetworkTimeout(timeoutBefore);
        @:privateAccess state.check("sys_network_restored", CoreSystem.getNetworkProxy() == proxyBefore
            && CoreSystem.getNetworkTimeout() == timeoutBefore, "");

        // Speaker position round trip on front left, restored afterwards
        var speakerBefore = CoreSystem.getSpeakerPosition(0);
        @:privateAccess state.check("sys_get_speaker_position", speakerBefore != null,
            speakerBefore == null ? 'result=${StudioSystem.lastResult().toString()}'
            : 'x=${speakerBefore.x} y=${speakerBefore.y} active=${speakerBefore.active}');
        var set:FmodResult = CoreSystem.setSpeakerPosition(0, -0.5, 0.5, true);
        var moved = CoreSystem.getSpeakerPosition(0);
        @:privateAccess state.check("sys_speaker_position_roundtrip", set.isOk() && moved != null
            && Math.abs(moved.x + 0.5) < 0.001 && Math.abs(moved.y - 0.5) < 0.001 && moved.active,
            moved == null ? 'result=${set.toString()}' : 'x=${moved.x} y=${moved.y} active=${moved.active}');
        if (speakerBefore != null) {
            CoreSystem.setSpeakerPosition(0, speakerBefore.x, speakerBefore.y, speakerBefore.active);
            var restored = CoreSystem.getSpeakerPosition(0);
            @:privateAccess state.check("sys_speaker_position_restored", restored != null
                && Math.abs(restored.x - speakerBefore.x) < 0.001 && Math.abs(restored.y - speakerBefore.y) < 0.001, "");
        }

        @:privateAccess state.check("no_handle_leaks_sysextras", StudioSystem.liveHandleCount() == baseline,
            'baseline=$baseline now=${StudioSystem.liveHandleCount()}');
    }
}
