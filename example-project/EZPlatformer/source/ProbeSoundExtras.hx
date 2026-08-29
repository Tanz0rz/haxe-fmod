package;

import haxefmod.core.Sound;
import haxefmod.studio.FmodResult;
import haxefmod.studio.StudioSystem;
import haxefmod.studio.Types;

/**
 * The api-probe section for tracker music, subsounds, tags, and the
 * advanced settings readback. The test build's init block sets a
 * nondefault vol0VirtualVol, randomSeed, and commandQueueSize, and this
 * checks they reach FMOD.
 */
class ProbeSoundExtras {
    public static function run(state:ApiProbeState):Void {
        var baseline = StudioSystem.liveHandleCount();

        // --- advanced settings readback ---
        #if js
        // FMOD's web build rejects every getAdvancedSettings argument
        // shape with INVALID_PARAM, so both readbacks are unsupported there
        @:privateAccess state.check("sys_get_advanced_settings_unsupported", StudioSystem.getAdvancedSettings() == null
            && StudioSystem.lastResult() == FmodResult.FMOD_ERR_UNSUPPORTED, 'result=${StudioSystem.lastResult().toString()}');
        @:privateAccess state.check("sys_get_studio_advanced_settings_unsupported", StudioSystem.getStudioAdvancedSettings() == null
            && StudioSystem.lastResult() == FmodResult.FMOD_ERR_UNSUPPORTED, 'result=${StudioSystem.lastResult().toString()}');
        #else
        var adv = StudioSystem.getAdvancedSettings();
        @:privateAccess state.check("sys_get_advanced_settings", adv != null,
            'result=${StudioSystem.lastResult().toString()}');
        @:privateAccess state.check("init_vol0_virtual_vol_reaches_fmod",
            adv != null && Math.abs(adv.vol0VirtualVol - 0.01) < 0.0001,
            'value=${adv == null ? "null" : Std.string(adv.vol0VirtualVol)}');
        @:privateAccess state.check("init_random_seed_reaches_fmod", adv != null && adv.randomSeed == 12345,
            'value=${adv == null ? "null" : Std.string(adv.randomSeed)}');
        @:privateAccess state.check("sys_get_advanced_settings_defaults",
            adv != null && adv.defaultDecodeBufferSize > 0 && adv.distanceFilterCenterFreq > 0,
            'decode=${adv == null ? -1 : adv.defaultDecodeBufferSize} center=${adv == null ? -1.0 : adv.distanceFilterCenterFreq}');
        var sadv = StudioSystem.getStudioAdvancedSettings();
        @:privateAccess state.check("sys_get_studio_advanced_settings", sadv != null,
            'result=${StudioSystem.lastResult().toString()}');
        @:privateAccess state.check("init_command_queue_size_reaches_fmod", sadv != null && sadv.commandQueueSize == 65536,
            'value=${sadv == null ? "null" : Std.string(sadv.commandQueueSize)}');
        @:privateAccess state.check("sys_get_studio_advanced_settings_defaults",
            sadv != null && sadv.studioUpdatePeriod > 0 && sadv.handleInitialSize > 0,
            'period=${sadv == null ? -1 : sadv.studioUpdatePeriod} handles=${sadv == null ? -1 : sadv.handleInitialSize}');
        #end

        // --- subsounds on a plain sound ---
        var pcm = haxe.io.Bytes.alloc(4096);
        var plain = Sound.fromPcm(pcm, 8000, 1);
        @:privateAccess state.check("sound_extras_pcm_sound", !plain.isNull(),
            'result=${StudioSystem.lastResult().toString()}');
        @:privateAccess state.check("core_sound_get_num_sub_sounds", plain.getNumSubSounds() == 0,
            'value=${plain.getNumSubSounds()}');
        var missingSub = plain.getSubSound(0);
        @:privateAccess state.check("core_sound_get_sub_sound_missing",
            missingSub.isNull() && StudioSystem.lastResult() == FmodResult.FMOD_ERR_INVALID_PARAM,
            'handle=${(missingSub : Int)} result=${StudioSystem.lastResult().toString()}');
        var parent = plain.getSubSoundParent();
        @:privateAccess state.check("core_sound_get_sub_sound_parent_top_level",
            parent.isNull() && StudioSystem.lastResult().isOk(),
            'handle=${(parent : Int)} result=${StudioSystem.lastResult().toString()}');
        @:privateAccess state.check("core_sound_get_num_tags_plain", plain.getNumTags() == 0,
            'value=${plain.getNumTags()}');
        var notTracker = plain.getMusicNumChannels();
        #if js
        // The web build decodes no tracker format (a module image reports
        // FORMAT from createSound), so the music calls are unsupported there
        @:privateAccess state.check("core_sound_get_music_num_channels_unsupported",
            notTracker == -1 && StudioSystem.lastResult() == FmodResult.FMOD_ERR_UNSUPPORTED,
            'value=$notTracker result=${StudioSystem.lastResult().toString()}');
        #else
        // A plain sound is not a tracker module, so the music calls report FORMAT
        @:privateAccess state.check("core_sound_get_music_num_channels_format",
            notTracker == -1 && StudioSystem.lastResult() == FmodResult.FMOD_ERR_FORMAT,
            'value=$notTracker result=${StudioSystem.lastResult().toString()}');
        #end

        // --- tracker music and tags on a real module ---
        #if sys
        var modPath = TrackerFixture.write();
        var mod = Sound.create(modPath);
        @:privateAccess state.check("sound_extras_tracker_loads", !mod.isNull(),
            'result=${StudioSystem.lastResult().toString()} path=$modPath');
        if (!mod.isNull()) {
            @:privateAccess state.check("core_sound_get_music_num_channels",
                mod.getMusicNumChannels() == TrackerFixture.CHANNELS, 'value=${mod.getMusicNumChannels()}');
            var setVol:FmodResult = mod.setMusicChannelVolume(1, 0.25);
            @:privateAccess state.check("core_sound_set_music_channel_volume", setVol.isOk(), 'result=${setVol.toString()}');
            var vol = mod.getMusicChannelVolume(1);
            @:privateAccess state.check("core_sound_get_music_channel_volume", Math.abs(vol - 0.25) < 0.001, 'value=$vol');
            var untouched = mod.getMusicChannelVolume(0);
            @:privateAccess state.check("core_sound_get_music_channel_volume_default",
                Math.abs(untouched - 1.0) < 0.001, 'value=$untouched');
            var badChannel:FmodResult = mod.setMusicChannelVolume(TrackerFixture.CHANNELS + 10, 0.5);
            @:privateAccess state.check("core_sound_set_music_channel_volume_out_of_range",
                badChannel == FmodResult.FMOD_ERR_INVALID_PARAM, 'result=${badChannel.toString()}');
            var setSpeed:FmodResult = mod.setMusicSpeed(1.5);
            @:privateAccess state.check("core_sound_set_music_speed", setSpeed.isOk(), 'result=${setSpeed.toString()}');
            var speed = mod.getMusicSpeed();
            @:privateAccess state.check("core_sound_get_music_speed", Math.abs(speed - 1.5) < 0.001, 'value=$speed');

            var tags = mod.getNumTags();
            var updatedBefore = mod.getNumTagsUpdated();
            @:privateAccess state.check("core_sound_get_num_tags", tags >= 1 && updatedBefore == tags,
                'count=$tags updated=$updatedBefore');
            var first = mod.getTag(null, 0);
            @:privateAccess state.check("core_sound_get_tag_first",
                first != null && first.name == "Number of channels" && first.type == FmodTagType.FMOD
                    && first.dataType == FmodTagDataType.INT && first.intValue == TrackerFixture.CHANNELS
                    && first.length == 4 && first.updated,
                first == null ? 'null result=${StudioSystem.lastResult().toString()}'
                    : 'name=${first.name} type=${(first.type : Int)} data=${(first.dataType : Int)} int=${first.intValue} len=${first.length}');
            var sampleName = mod.getTag("Sample name 0");
            @:privateAccess state.check("core_sound_get_tag_string",
                sampleName != null && sampleName.dataType == FmodTagDataType.STRING
                    && sampleName.stringValue == TrackerFixture.SAMPLE_NAME,
                sampleName == null ? 'null result=${StudioSystem.lastResult().toString()}'
                    : 'value=${sampleName.stringValue} len=${sampleName.length}');
            var updatedAfter = mod.getNumTagsUpdated();
            @:privateAccess state.check("core_sound_get_num_tags_updated_drops", updatedAfter < updatedBefore,
                'before=$updatedBefore after=$updatedAfter');
            var missing = mod.getTag("no such tag");
            @:privateAccess state.check("core_sound_get_tag_missing",
                missing == null && StudioSystem.lastResult() == FmodResult.FMOD_ERR_TAGNOTFOUND,
                'result=${StudioSystem.lastResult().toString()}');
            var released:FmodResult = mod.release();
            @:privateAccess state.check("sound_extras_tracker_release", released.isOk(), 'result=${released.toString()}');
            @:privateAccess state.check("core_sound_get_music_speed_stale",
                mod.getMusicSpeed() == 0 && StudioSystem.lastResult() == FmodResult.FMOD_ERR_INVALID_HANDLE,
                'result=${StudioSystem.lastResult().toString()}');
        }
        try sys.FileSystem.deleteFile(modPath) catch (e:Dynamic) {}
        #else
        @:privateAccess state.info("sound_extras_tracker", "skipped (no filesystem)");
        #end

        plain.release();
        @:privateAccess state.check("core_sound_get_num_sub_sounds_stale",
            plain.getNumSubSounds() == -1 && StudioSystem.lastResult() == FmodResult.FMOD_ERR_INVALID_HANDLE,
            'result=${StudioSystem.lastResult().toString()}');
        @:privateAccess state.check("core_sound_get_tag_stale",
            plain.getTag(null, 0) == null && StudioSystem.lastResult() == FmodResult.FMOD_ERR_INVALID_HANDLE,
            'result=${StudioSystem.lastResult().toString()}');

        @:privateAccess state.check("no_handle_leaks_sound_extras", StudioSystem.liveHandleCount() == baseline,
            'baseline=$baseline now=${StudioSystem.liveHandleCount()}');
    }
}
