package;

import haxefmod.FmodManager;
import haxefmod.studio.FmodResult;
import haxefmod.studio.StudioSystem;
import haxefmod.studio.Types;

/**
 * Probe for the Studio API parity round: capture and replay flags, the
 * replay time cursor in seconds, bank loading from memory with flags,
 * the listener attenuation position, the parameter description GUID on
 * every reader, and the sound info fields for an audio table key.
 */
class ProbeStudioParity {
    public static function run(state:ApiProbeState):Void {
        var baseline = StudioSystem.liveHandleCount();

        // Capture with flags, replay with flags, and the seconds cursor
        var capturePath = "probe-parity.cmd.txt";
        var captureFlags = FmodCommandCaptureFlags.FILEFLUSH | FmodCommandCaptureFlags.SKIP_INITIAL_STATE;
        @:privateAccess state.check("parity_capture_start_flags", StudioSystem.startCommandCapture(capturePath, captureFlags).isOk(),
            'result=${StudioSystem.lastResult().toString()}');
        FmodManager.Update();
        @:privateAccess state.check("parity_capture_stop", StudioSystem.stopCommandCapture().isOk(), "");
        var replay = StudioSystem.loadCommandReplay(capturePath, FmodCommandReplayFlags.FAST_FORWARD | FmodCommandReplayFlags.SKIP_BANK_LOAD);
        @:privateAccess state.check("parity_replay_load_flags", !replay.isNull(), 'result=${StudioSystem.lastResult().toString()}');
        if (!replay.isNull()) {
            var length = replay.getLength();
            @:privateAccess state.check("parity_replay_seek_seconds", replay.seekToTime(0.0).isOk(),
                'result=${StudioSystem.lastResult().toString()} length=$length');
            // Half a second past the end is still a valid seek target
            @:privateAccess state.check("parity_replay_seek_past_end", replay.seekToTime(length + 0.5).isOk(),
                'result=${StudioSystem.lastResult().toString()}');
            @:privateAccess state.check("parity_replay_command_at_time", replay.getCommandAtTime(0.0) == 0,
                'index=${replay.getCommandAtTime(0.0)}');
            @:privateAccess state.check("parity_replay_release", replay.release().isOk(), "");
        }

        // A bank from memory with a flag, the example bank is already loaded
        // so ALREADY_LOADED proves the flag reached FMOD too
        #if sys
        var bankBytes = try sys.io.File.getBytes("assets/fmod/Desktop/Master.bank") catch (e:Dynamic) null;
        if (bankBytes == null) {
            @:privateAccess state.info("parity_bank_memory_flags", "bank file not reachable from cwd, skipped");
        } else {
            var memoryBank = StudioSystem.loadBankMemory(bankBytes, FmodLoadBankFlags.DECOMPRESS_SAMPLES);
            var loaded = !memoryBank.isNull()
                || StudioSystem.lastResult() == FmodResult.FMOD_ERR_EVENT_ALREADY_LOADED;
            @:privateAccess state.check("parity_bank_memory_flags", loaded, 'result=${StudioSystem.lastResult().toString()}');
            if (!memoryBank.isNull()) memoryBank.unload();
        }
        #else
        @:privateAccess state.info("parity_bank_memory_flags", "verified by the js harness");
        #end

        // Listener attenuation position round trip, then back to the origin
        var attrs:Fmod3DAttributes = {
            position: {x: 1, y: 2, z: 3},
            velocity: {x: 0, y: 0, z: 0},
            forward: {x: 0, y: 0, z: 1},
            up: {x: 0, y: 1, z: 0},
        };
        var set = StudioSystem.setListenerAttributes(0, attrs, {x: 7, y: 8, z: 9});
        @:privateAccess state.check("parity_listener_set_attenuation", set.isOk(), 'result=${set.toString()}');
        var listener = StudioSystem.getListenerAttributes(0);
        @:privateAccess state.check("parity_listener_get_attenuation", listener != null
            && Math.abs(listener.position.x - 1) < 0.001
            && Math.abs(listener.attenuationPosition.x - 7) < 0.001
            && Math.abs(listener.attenuationPosition.y - 8) < 0.001
            && Math.abs(listener.attenuationPosition.z - 9) < 0.001,
            listener == null ? "unavailable" : 'attenuation=${listener.attenuationPosition.x},${listener.attenuationPosition.y},${listener.attenuationPosition.z}');
        // Without one the attenuation position follows the listener
        set = StudioSystem.setListenerAttributes(0, attrs);
        listener = StudioSystem.getListenerAttributes(0);
        @:privateAccess state.check("parity_listener_attenuation_follows", set.isOk() && listener != null
            && Math.abs(listener.attenuationPosition.x - 1) < 0.001
            && Math.abs(listener.attenuationPosition.y - 2) < 0.001,
            listener == null ? "unavailable" : 'attenuation=${listener.attenuationPosition.x},${listener.attenuationPosition.y}');
        StudioSystem.setListenerPosition2D(0, 0, 0);

        @:privateAccess state.check("parity_sound_info_missing", StudioSystem.getSoundInfo("no-such-key") == null, "");

        @:privateAccess state.check("no_handle_leaks_studio_parity", StudioSystem.liveHandleCount() == baseline,
            'baseline=$baseline now=${StudioSystem.liveHandleCount()}');
    }

    /** The parts that need the authored parameters and audio table. */
    public static function runAuthored(state:ApiProbeState):Void {
        var baseline = StudioSystem.liveHandleCount();

        // The GUID on every parameter description reader matches lookupID
        var intensityGuid = StudioSystem.lookupID("parameter:/Intensity");
        var byName = StudioSystem.getParameterDescriptionByName("Intensity");
        @:privateAccess state.check("parity_param_guid_by_name", byName != null && intensityGuid != "" && byName.guid == intensityGuid,
            'guid=${byName == null ? "null" : byName.guid} lookup=$intensityGuid');
        if (byName != null) {
            var byId = StudioSystem.getParameterDescriptionByID(byName.id);
            @:privateAccess state.check("parity_param_guid_by_id", byId != null && byId.guid == intensityGuid,
                'guid=${byId == null ? "null" : byId.guid}');
        }
        var indexed = 0;
        var indexedOk = true;
        for (i in 0...StudioSystem.getParameterDescriptionCount()) {
            var p = StudioSystem.getParameterDescriptionByIndex(i);
            if (p == null) continue;
            indexed++;
            if (p.guid.length != 38 || p.guid != StudioSystem.lookupID('parameter:/${p.name}')) indexedOk = false;
        }
        @:privateAccess state.check("parity_param_guid_by_index", indexed > 0 && indexedOk, 'count=$indexed');
        var jumpDesc = StudioSystem.getEvent(FmodEvents.SFXJump);
        var surface = jumpDesc.getParameterDescriptionByName("Surface");
        var surfaceIndexed = jumpDesc.getParameterDescriptionCount() > 0 ? jumpDesc.getParameterDescriptionByIndex(0) : null;
        @:privateAccess state.check("parity_event_param_guid", surface != null && surface.guid.length == 38
            && surfaceIndexed != null && surfaceIndexed.guid.length == 38
            && jumpDesc.getParameterDescriptionByID(surface.id).guid == surface.guid,
            'guid=${surface == null ? "null" : surface.guid}');

        // Sound info for an audio table key: the sample sits inside the bank
        var info = StudioSystem.getSoundInfo("hello");
        @:privateAccess state.check("parity_sound_info_fields", info != null && info.length > 0 && info.fileOffset > 0
            && info.numSubsounds >= 1 && info.initialSubsound >= 0 && info.subSoundIndex >= 0
            && (info.mode & haxefmod.core.ChannelMode.CREATECOMPRESSEDSAMPLE) != 0,
            info == null ? 'null result=${StudioSystem.lastResult().toString()}'
                : 'name=${info.name} mode=${info.mode} length=${info.length} offset=${info.fileOffset} initial=${info.initialSubsound} subsounds=${info.numSubsounds} index=${info.subSoundIndex}');

        @:privateAccess state.check("no_handle_leaks_studio_parity_authored", StudioSystem.liveHandleCount() == baseline,
            'baseline=$baseline now=${StudioSystem.liveHandleCount()}');
    }
}
