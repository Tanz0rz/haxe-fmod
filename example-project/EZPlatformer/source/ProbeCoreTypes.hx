package;

import haxefmod.core.Channel;
import haxefmod.core.ChannelMode;
import haxefmod.core.PcmStream;
import haxefmod.core.Reverb;
import haxefmod.core.Sound;
import haxefmod.core.SoundGroup;
import haxefmod.studio.CallbackDispatcher;
import haxefmod.studio.FmodResult;
import haxefmod.studio.StudioSystem;
import haxefmod.studio.SystemCallbacks;
import haxefmod.studio.Types;

/**
 * Probe for the core types that mirror FMOD structs and handles on the
 * real backend: FmodGuid round trips, FmodSyncPoint handles, loop points
 * with a unit per end, FmodCreateSoundExInfo on both create forms, the
 * error callback record, the PcmStream read callback, the reverb presets
 * under their FMOD names, and FmodVersion against the running engine.
 * Leaves the reverb and the system callback as it found them.
 */
class ProbeCoreTypes {
    public static function run(state:ApiProbeState):Void {
        var baseline = StudioSystem.liveHandleCount();

        // FmodGuid: what getID returns finds the same object again, in any case
        var master = StudioSystem.getBus("bus:/");
        var id = master.getID();
        @:privateAccess state.check("types_guid_fields", !id.isNull() && (id.data1 != 0 || id.data2 != 0 || id.data4[7] != 0)
            && id.data4.length == 8, 'id=$id');
        @:privateAccess state.check("types_guid_lookup_round_trip", (StudioSystem.getBusByID(id) : Int) == (master : Int), 'id=$id');
        var upper:FmodGuid = (id : String).toUpperCase();
        @:privateAccess state.check("types_guid_lookup_upper_case", (StudioSystem.getBusByID(upper) : Int) == (master : Int) && upper == id, 'upper=$upper');
        @:privateAccess state.check("types_guid_from_fields", FmodGuid.fromFields(id.data1, id.data2, id.data3, id.data4) == id
            && FmodGuid.fromString(id.toString()) == id, 'rebuilt=${FmodGuid.fromFields(id.data1, id.data2, id.data3, id.data4)}');
        var looked = StudioSystem.lookupID("bus:/");
        @:privateAccess state.check("types_guid_lookup_id", looked == id && StudioSystem.lookupPath(looked) == "bus:/", 'looked=$looked');
        @:privateAccess state.check("types_guid_missing_is_null", StudioSystem.lookupID("bus:/NoSuchBus").isNull()
            && StudioSystem.getBusByID(FmodGuid.NULL).isNull(), "");

        // FmodSyncPoint: handles are indices in offset order, so adding an
        // earlier point moves the later ones up
        var frames = 4800;
        var sound = Sound.fromPcm(haxe.io.Bytes.alloc(frames * 2), 48000, 1);
        var a = sound.addSyncPoint(30, "a");
        var b = sound.addSyncPoint(10, "b");
        var c = sound.addSyncPoint(20, "c");
        @:privateAccess state.check("types_syncpoint_add_indices", a.index() == 0 && b.index() == 0 && c.index() == 1,
            'a=${a.index()} b=${b.index()} c=${c.index()}');
        @:privateAccess state.check("types_syncpoint_count", sound.getNumSyncPoints() == 3 && sound.getSyncPointCount() == 3, 'count=${sound.getNumSyncPoints()}');
        var names = [for (i in 0...3) sound.getSyncPointInfo(sound.getSyncPoint(i)).name];
        @:privateAccess state.check("types_syncpoint_sorted_names", names.join(",") == "b,c,a", 'names=${names.join(",")}');
        var second = sound.getSyncPointInfo(sound.getSyncPoint(1), FmodTimeUnit.PCM);
        @:privateAccess state.check("types_syncpoint_info_unit", second != null && second.offset == 960 && second.name == "c",
            second == null ? "null" : 'offset=${second.offset}');
        @:privateAccess state.check("types_syncpoint_out_of_range", sound.getSyncPoint(3).isNull() && sound.getSyncPointInfo(FmodSyncPoint.NULL) == null
            && StudioSystem.lastResult() == FmodResult.FMOD_ERR_INVALID_PARAM, 'result=${StudioSystem.lastResult().toString()}');
        @:privateAccess state.check("types_syncpoint_delete", sound.deleteSyncPoint(sound.getSyncPoint(0)).isOk() && sound.getNumSyncPoints() == 2
            && sound.getSyncPointInfo(sound.getSyncPoint(0)).name == "c", 'count=${sound.getNumSyncPoints()}');
        @:privateAccess state.check("types_syncpoint_delete_stale", !sound.deleteSyncPoint(5).isOk(), "");

        // Loop points with a unit per end
        sound.setMode(ChannelMode.LOOP_NORMAL);
        @:privateAccess state.check("types_loop_points_mixed_units", sound.setLoopPoints(480, 50, FmodTimeUnit.PCM, FmodTimeUnit.MS).isOk(),
            'result=${StudioSystem.lastResult().toString()}');
        var pcm = sound.getLoopPoints(FmodTimeUnit.PCM);
        var mixed = sound.getLoopPoints(FmodTimeUnit.MS, FmodTimeUnit.PCM);
        @:privateAccess state.check("types_loop_points_read_pcm", pcm != null && pcm.loopStart == 480 && pcm.loopEnd == 2400,
            pcm == null ? "null" : 'start=${pcm.loopStart} end=${pcm.loopEnd}');
        @:privateAccess state.check("types_loop_points_read_mixed", mixed != null && mixed.loopStart == 10 && mixed.loopEnd == 2400,
            mixed == null ? "null" : 'start=${mixed.loopStart} end=${mixed.loopEnd}');
        var channel = sound.play(true);
        @:privateAccess state.check("types_chan_loop_points_mixed_units", channel.setLoopPoints(20, 1920, FmodTimeUnit.MS, FmodTimeUnit.PCM).isOk(),
            'result=${StudioSystem.lastResult().toString()}');
        var chanMs = channel.getLoopPoints();
        @:privateAccess state.check("types_chan_loop_points_read", chanMs != null && chanMs.loopStart == 20 && chanMs.loopEnd == 40,
            chanMs == null ? "null" : 'start=${chanMs.loopStart} end=${chanMs.loopEnd}');
        channel.stop();

        // FmodCreateSoundExInfo: raw PCM through fromMemory, a file through create
        var group = SoundGroup.create("exinfo");
        var raw = Sound.fromMemory(haxe.io.Bytes.alloc(frames * 2), ChannelMode.OPENRAW,
            {numChannels: 1, defaultFrequency: 48000, format: FmodSoundFormat.PCM16, initialSoundGroup: group});
        @:privateAccess state.check("types_exinfo_from_memory_raw", !raw.isNull() && raw.getLength(FmodTimeUnit.PCM) == frames,
            'handle=${(raw : Int)} result=${StudioSystem.lastResult().toString()} length=${raw.isNull() ? -1 : raw.getLength(FmodTimeUnit.PCM)}');
        var rawFormat = raw.getFormat();
        @:privateAccess state.check("types_exinfo_format", rawFormat != null && rawFormat.channels == 1 && rawFormat.format == FmodSoundFormat.PCM16,
            rawFormat == null ? "null" : 'channels=${rawFormat.channels} format=${(rawFormat.format : Int)}');
        @:privateAccess state.check("types_exinfo_initial_sound_group", !raw.isNull() && (raw.getSoundGroup() : Int) == (group : Int),
            'group=${(group : Int)} got=${raw.isNull() ? 0 : (raw.getSoundGroup() : Int)}');
        var badGuid = Sound.fromMemory(haxe.io.Bytes.alloc(frames * 2), ChannelMode.OPENRAW,
            {numChannels: 1, defaultFrequency: 48000, format: FmodSoundFormat.PCM16, fsbGuid: "not-a-guid"});
        @:privateAccess state.check("types_exinfo_bad_guid", badGuid.isNull() && StudioSystem.lastResult() == FmodResult.FMOD_ERR_INVALID_PARAM,
            'result=${StudioSystem.lastResult().toString()}');
        var plain = Sound.create("assets/fmod/Jump.wav");
        if (plain.isNull()) {
            @:privateAccess state.info("types_exinfo_create_file", 'Jump.wav not loadable here, skipped (result=${StudioSystem.lastResult().toString()})');
        } else {
            plain.release();
            var hinted = Sound.create("assets/fmod/Jump.wav", false, false, 0, -1, {suggestedSoundType: FmodSoundType.WAV, fileBufferSize: 32768});
            var hintedFormat = hinted.getFormat();
            @:privateAccess state.check("types_exinfo_create_file", !hinted.isNull() && hintedFormat != null && hintedFormat.type == FmodSoundType.WAV,
                'handle=${(hinted : Int)} result=${StudioSystem.lastResult().toString()}');
            hinted.release();
        }
        badGuid.release();
        raw.release();
        group.release();

        // The error callback record, opt-in through CORE_ERROR
        var errors:Array<FmodErrorCallbackInfo> = [];
        var others = 0;
        StudioSystem.setSystemCallback(function(e) switch (e) {
            case Error(info): errors.push(info);
            default: others++;
        }, SystemCallbacks.DEFAULT_CORE_MASK | SystemCallbacks.CORE_ERROR, SystemCallbacks.DEFAULT_STUDIO_MASK);
        @:privateAccess state.check("types_error_mask_accepted", StudioSystem.lastResult().isOk(), 'result=${StudioSystem.lastResult().toString()}');
        sound.getSyncPointInfo(99);
        CallbackDispatcher.update();
        #if js
        @:privateAccess state.check("types_error_web_silent", errors.length == 0, 'errors=${errors.length}');
        #else
        var first = errors.length > 0 ? errors[0] : null;
        @:privateAccess state.check("types_error_delivered", first != null, 'errors=${errors.length}');
        @:privateAccess state.check("types_error_fields", first != null && first.result == FmodResult.FMOD_ERR_INVALID_PARAM
            && first.instanceType == FmodErrorCallbackInstanceType.SOUND && first.instance == (sound : Int)
            && first.functionName.indexOf("SyncPoint") >= 0 && first.functionParams.length > 0,
            first == null ? "null" : 'result=${first.result.toString()} type=${(first.instanceType : Int)} instance=${first.instance} fn=${first.functionName} params=${first.functionParams}');
        #end
        StudioSystem.setSystemCallback(function(e) switch (e) {
            case Error(info): errors.push(info);
            default: others++;
        }, SystemCallbacks.DEFAULT_CORE_MASK, SystemCallbacks.DEFAULT_STUDIO_MASK);
        errors = [];
        sound.getSyncPointInfo(99);
        CallbackDispatcher.update();
        @:privateAccess state.check("types_error_silent_without_mask", errors.length == 0, 'errors=${errors.length}');
        StudioSystem.clearSystemCallback();

        // PcmStream read callback: filled from the frame drain until the ring is full
        var ringBytes = 4800 * 2;
        var stream = PcmStream.create(48000, 1, ringBytes);
        var fills = 0;
        var filled = 0;
        stream.setReadCallback(function(s, data, len) {
            fills++;
            filled += len;
            data.fill(0, len, 0);
            return FmodResult.FMOD_OK;
        });
        var roomBefore = stream.space();
        CallbackDispatcher.update();
        var roomAfter = stream.space();
        CallbackDispatcher.update();
        @:privateAccess state.check("types_pcm_read_callback_fills", fills == 1 && filled == roomBefore && roomBefore > 0 && roomAfter == 0,
            'fills=$fills filled=$filled before=$roomBefore after=$roomAfter');
        stream.release();
        @:privateAccess state.check("types_pcm_read_callback_released", !stream.hasReadCallback(), "");

        // Reverb presets under FMOD's names reach the engine
        var before = Reverb.get(0);
        @:privateAccess state.check("types_reverb_preset_cave", Reverb.set(0, ReverbPresets.CAVE).isOk()
            && Reverb.get(0) != null && Reverb.get(0).decayTime == Reverb.PRESET_CAVE.decayTime,
            'result=${StudioSystem.lastResult().toString()} decay=${Reverb.get(0) == null ? -1 : Reverb.get(0).decayTime}');
        Reverb.set(0, before == null ? ReverbPresets.OFF : before);

        // FmodVersion against the engine that loaded
        var expected = '${FmodVersion.VERSION >> 16}.${StringTools.hex((FmodVersion.VERSION >> 8) & 0xFF, 2)}.${StringTools.hex(FmodVersion.VERSION & 0xFF, 2)}';
        @:privateAccess state.check("types_version_matches_engine", StudioSystem.getVersion() == expected,
            'engine=${StudioSystem.getVersion()} constant=$expected');

        sound.release();
        @:privateAccess state.check("no_handle_leaks_core_types", StudioSystem.liveHandleCount() == baseline,
            'baseline=$baseline now=${StudioSystem.liveHandleCount()}');
    }
}
