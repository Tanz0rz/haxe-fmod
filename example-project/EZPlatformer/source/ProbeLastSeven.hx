package;

import haxefmod.core.ChannelGroup;
import haxefmod.core.CoreSystem;
import haxefmod.core.Dsp;
import haxefmod.core.DspConnection;
import haxefmod.core.DspType;
import haxefmod.core.PcmStream;
import haxefmod.studio.FmodResult;
import haxefmod.studio.StudioSystem;

/**
 * Probe for the last seven bindings: the preallocated DSP input, the mix
 * level setters on channels and groups, the DSP description by type, the
 * output plugin handle, and the replay cursor. The mixer edits are undone
 * before it returns.
 */
class ProbeLastSeven {
    public static function run(state:ApiProbeState):Void {
        // The master group handle is cached by the shim, so it is taken before the baseline
        var master = ChannelGroup.master();
        var baseline = StudioSystem.liveHandleCount();

        // The preallocated input path. The only connections this library
        // can hand over come from addInput, and FMOD refuses those with
        // INVALID_PARAM, so the probe proves the refusal is clean and that
        // a NULL or stale connection never reaches FMOD.
        var echo = Dsp.create(DspType.ECHO);
        var fader = Dsp.create(DspType.FADER);
        var conn = echo.addInput(fader);
        @:privateAccess state.check("dsp_add_input_for_conn", !conn.isNull(), 'handle=${(conn : Int)}');
        #if js
        @:privateAccess state.check("dsp_add_input_preallocated_unsupported", echo.addInputPreallocated(fader, conn).isNull()
            && StudioSystem.lastResult() == FmodResult.FMOD_ERR_UNSUPPORTED,
            'lastResult=${StudioSystem.lastResult().toString()}');
        #else
        @:privateAccess state.check("dsp_add_input_preallocated_refused", echo.addInputPreallocated(fader, conn).isNull()
            && StudioSystem.lastResult() == FmodResult.FMOD_ERR_INVALID_PARAM,
            'lastResult=${StudioSystem.lastResult().toString()}');
        @:privateAccess state.check("dsp_add_input_preallocated_graph_intact", echo.getInputCount() == 1,
            'inputs=${echo.getInputCount()}');
        #end
        @:privateAccess state.check("dsp_add_input_preallocated_null_conn", echo.addInputPreallocated(fader, DspConnection.NULL).isNull()
            && StudioSystem.lastResult() == FmodResult.FMOD_ERR_INVALID_HANDLE,
            'lastResult=${StudioSystem.lastResult().toString()}');
        var stale:Dsp = cast 0x7fff0001;
        @:privateAccess state.check("dsp_add_input_preallocated_stale", stale.addInputPreallocated(fader, conn).isNull()
            && StudioSystem.lastResult() == FmodResult.FMOD_ERR_INVALID_HANDLE,
            'lastResult=${StudioSystem.lastResult().toString()}');
        @:privateAccess state.check("dsp_add_input_preallocated_disconnect", echo.disconnectFrom(fader).isOk(),
            'lastResult=${StudioSystem.lastResult().toString()}');
        fader.release();
        echo.release();

        // Mix levels on a playing channel and on the master group, restored to unity
        var stream = PcmStream.create(48000, 2);
        var channel = stream.play(true);
        var inLevels:FmodResult = channel.setMixLevelsInput([0.5, 0.5]);
        @:privateAccess state.check("chan_set_mix_levels_input", inLevels.isOk(), 'result=${inLevels.toString()}');
        @:privateAccess state.check("chan_set_mix_levels_input_empty",
            channel.setMixLevelsInput([]) == FmodResult.FMOD_ERR_INVALID_PARAM, "");
        @:privateAccess state.check("chan_set_mix_levels_input_too_many",
            channel.setMixLevelsInput([for (_ in 0...33) 1.0]) == FmodResult.FMOD_ERR_INVALID_PARAM, "");
        var outLevels:FmodResult = channel.setMixLevelsOutput(1, 1, 0, 0, 0, 0, 0, 0);
        @:privateAccess state.check("chan_set_mix_levels_output", outLevels.isOk(), 'result=${outLevels.toString()}');
        channel.setMixLevelsInput([1.0, 1.0]);
        channel.stop();
        stream.release();
        @:privateAccess state.check("chan_set_mix_levels_input_stale",
            channel.setMixLevelsInput([1.0]) == FmodResult.FMOD_ERR_INVALID_HANDLE, "");
        @:privateAccess state.check("chan_set_mix_levels_output_stale",
            channel.setMixLevelsOutput(1, 1, 0, 0, 0, 0, 0, 0) == FmodResult.FMOD_ERR_INVALID_HANDLE, "");

        var groupIn:FmodResult = master.setMixLevelsInput([0.8, 0.8]);
        @:privateAccess state.check("cg_set_mix_levels_input", groupIn.isOk(), 'result=${groupIn.toString()}');
        @:privateAccess state.check("cg_set_mix_levels_input_too_many",
            master.setMixLevelsInput([for (_ in 0...33) 1.0]) == FmodResult.FMOD_ERR_INVALID_PARAM, "");
        var groupOut:FmodResult = master.setMixLevelsOutput(1, 1, 0, 0, 0, 0, 0, 0);
        @:privateAccess state.check("cg_set_mix_levels_output", groupOut.isOk(), 'result=${groupOut.toString()}');
        master.setMixLevelsInput([1.0, 1.0]);
        var staleGroup:ChannelGroup = cast 0x7fff0001;
        @:privateAccess state.check("cg_set_mix_levels_input_stale",
            staleGroup.setMixLevelsInput([1.0]) == FmodResult.FMOD_ERR_INVALID_HANDLE, "");
        @:privateAccess state.check("cg_set_mix_levels_output_stale",
            staleGroup.setMixLevelsOutput(1, 1, 0, 0, 0, 0, 0, 0) == FmodResult.FMOD_ERR_INVALID_HANDLE, "");

        // The built-in effect descriptions
        #if js
        @:privateAccess state.check("sys_get_dsp_info_by_type_unsupported", CoreSystem.getDspInfoByType(DspType.FADER) == null
            && StudioSystem.lastResult() == FmodResult.FMOD_ERR_UNSUPPORTED,
            'lastResult=${StudioSystem.lastResult().toString()}');
        #else
        var faderInfo = CoreSystem.getDspInfoByType(DspType.FADER);
        @:privateAccess state.check("sys_get_dsp_info_by_type", faderInfo != null && faderInfo.name != ""
            && faderInfo.inputBuffers >= 1 && faderInfo.outputBuffers >= 1 && faderInfo.parameterCount >= 1,
            faderInfo == null ? 'null lastResult=${StudioSystem.lastResult().toString()}'
                : 'name=${faderInfo.name} version=${faderInfo.version} in=${faderInfo.inputBuffers} out=${faderInfo.outputBuffers} params=${faderInfo.parameterCount}');
        var echoInfo = CoreSystem.getDspInfoByType(DspType.ECHO);
        @:privateAccess state.check("sys_get_dsp_info_by_type_echo", echoInfo != null && echoInfo.name != ""
            && echoInfo.name != (faderInfo == null ? "" : faderInfo.name),
            echoInfo == null ? 'null lastResult=${StudioSystem.lastResult().toString()}' : 'name=${echoInfo.name}');
        @:privateAccess state.check("sys_get_dsp_info_by_type_invalid", CoreSystem.getDspInfoByType(cast 9999) == null,
            'lastResult=${StudioSystem.lastResult().toString()}');
        #end

        // The output plugin handle. Setting the current handle back is a
        // no-op that reports OK natively and INITIALIZED on the web build,
        // and the active output stays what it was either way. Another
        // handle would re-select the output device, so none is tried.
        var outputBefore = CoreSystem.getOutput();
        var outputPlugin = CoreSystem.getOutputByPlugin();
        @:privateAccess state.check("sys_get_output_by_plugin", outputPlugin != 0,
            'handle=$outputPlugin lastResult=${StudioSystem.lastResult().toString()}');
        var setOutput:FmodResult = CoreSystem.setOutputByPlugin(outputPlugin);
        #if js
        @:privateAccess state.check("sys_set_output_by_plugin_after_init", setOutput == FmodResult.FMOD_ERR_INITIALIZED,
            'result=${setOutput.toString()}');
        #else
        @:privateAccess state.check("sys_set_output_by_plugin_after_init", setOutput.isOk(), 'result=${setOutput.toString()}');
        #end
        @:privateAccess state.check("sys_set_output_by_plugin_leaves_output", CoreSystem.getOutput() == outputBefore,
            'before=$outputBefore now=${CoreSystem.getOutput()}');

        // The replay cursor on a short capture that has never been started
        var capturePath = "probe-lastseven.cmd.txt";
        @:privateAccess state.check("lastseven_capture_start", StudioSystem.startCommandCapture(capturePath).isOk(), "");
        FmodManager.Update();
        StudioSystem.flushCommands();
        @:privateAccess state.check("lastseven_capture_stop", StudioSystem.stopCommandCapture().isOk(), "");
        var replay = StudioSystem.loadCommandReplay(capturePath);
        @:privateAccess state.check("lastseven_replay_load", !replay.isNull(), 'handle=${(replay : Int)}');
        if (!replay.isNull()) {
            var current = replay.getCurrentCommand();
            @:privateAccess state.check("replay_get_current_command", current != null && current.index == 0 && current.time == 0,
                current == null ? 'null lastResult=${StudioSystem.lastResult().toString()}'
                    : 'index=${current.index} time=${current.time}');
            replay.release();
        }
        @:privateAccess state.check("replay_get_current_command_stale", replay.getCurrentCommand() == null
            && StudioSystem.lastResult() == FmodResult.FMOD_ERR_INVALID_HANDLE,
            'lastResult=${StudioSystem.lastResult().toString()}');

        @:privateAccess state.check("no_handle_leaks_lastseven", StudioSystem.liveHandleCount() == baseline,
            'baseline=$baseline now=${StudioSystem.liveHandleCount()}');
    }
}
