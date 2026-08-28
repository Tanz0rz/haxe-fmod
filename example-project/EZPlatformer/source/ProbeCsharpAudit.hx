package;

import haxefmod.core.CoreSystem;
import haxefmod.studio.FmodResult;
import haxefmod.studio.StudioSystem;
import haxefmod.studio.Types;

/**
 * Probe for the members added by the audit against FMOD's C# integration:
 * bus port indices, parameter labels by index, parameter batches by ID,
 * the parameter description list, the user property lookups, the bank
 * string info pair, the mixer and stream buffer readback, and the
 * renamed getters.
 */
class ProbeCsharpAudit {
    public static function run(state:ApiProbeState):Void {
        var baseline = StudioSystem.liveHandleCount();

        // Bus port index: FMOD only routes buses to ports on consoles, so
        // desktop reports FMOD_ERR_UNSUPPORTED on the setter and NONE on the
        // getter, which is the shape the binding carries through
        var master = StudioSystem.getBus(FmodBuses.Root);
        @:privateAccess state.check("audit_bus_port_index_none", master.getPortIndex() == FmodPortIndex.NONE,
            'index=${(master.getPortIndex() : Int)} result=${StudioSystem.lastResult().toString()}');
        var setPort:FmodResult = master.setPortIndex(3);
        @:privateAccess state.check("audit_bus_set_port_index", setPort.isOk() || setPort == FmodResult.FMOD_ERR_UNSUPPORTED,
            'result=${setPort.toString()}');
        var readBack:Int = master.getPortIndex();
        @:privateAccess state.check("audit_bus_get_port_index", setPort.isOk() ? readBack == 3 : readBack == -1,
            'index=$readBack');
        var resetPort:FmodResult = master.setPortIndex(FmodPortIndex.NONE);
        @:privateAccess state.check("audit_bus_port_index_reset", (resetPort.isOk() || resetPort == FmodResult.FMOD_ERR_UNSUPPORTED)
            && master.getPortIndex() == FmodPortIndex.NONE, 'index=${(master.getPortIndex() : Int)}');
        @:privateAccess state.check("audit_bus_port_index_stale", haxefmod.studio.Bus.NULL.getPortIndex() == FmodPortIndex.NONE
            && StudioSystem.lastResult() == FmodResult.FMOD_ERR_INVALID_HANDLE, 'result=${StudioSystem.lastResult().toString()}');

        // Labels by index and by name on the music event, the same text either way
        var music = StudioSystem.getEvent(FmodEvents.MusicMainLevel);
        var count = music.getParameterDescriptionCount();
        var labelMatch = count > 0;
        var labeledSeen = false;
        for (i in 0...count) {
            var p = music.getParameterDescriptionByIndex(i);
            if (p == null) continue;
            var byIndex = music.getParameterLabelByIndex(i, 0);
            var byName = music.getParameterLabelByName(p.name, 0);
            if (byIndex != byName || byName != music.getParameterLabel(p.name, 0)) labelMatch = false;
            if ((p.flags & FmodParameterFlags.LABELED) != 0 && byIndex != "") labeledSeen = true;
        }
        @:privateAccess state.check("audit_evd_label_by_index", labelMatch, 'count=$count');
        @:privateAccess state.info("audit_evd_labeled_parameter_seen", Std.string(labeledSeen));
        @:privateAccess state.check("audit_evd_label_by_index_miss", music.getParameterLabelByIndex(99, 0) == ""
            && !StudioSystem.lastResult().isOk(), 'result=${StudioSystem.lastResult().toString()}');

        // User properties: by name is the FMOD call, by index walks the list
        var byName = music.getUserProperty("probe_int");
        var byIndex = music.getUserPropertyByIndex(0);
        @:privateAccess state.check("audit_evd_user_property_by_name", byName != null && byName.name == "probe_int",
            'name=${byName == null ? "null" : byName.name}');
        @:privateAccess state.check("audit_evd_user_property_by_index", byIndex != null && byIndex.name != "",
            'name=${byIndex == null ? "null" : byIndex.name}');
        @:privateAccess state.check("audit_evd_user_property_miss", music.getUserProperty("nope") == null
            && music.getUserPropertyByIndex(99) == null, "");

        // Parameter batch by ID on an instance, read back by name
        if (count > 0) {
            var p = music.getParameterDescriptionByIndex(0);
            var instance = music.createInstance();
            var batch:FmodResult = instance.setParametersByIDs([p.id], [p.maximum]);
            @:privateAccess state.check("audit_evi_set_parameters_by_ids", batch.isOk(), 'result=${batch.toString()}');
            @:privateAccess state.check("audit_evi_set_parameters_by_ids_value",
                Math.abs(instance.getParameterByName(p.name) - p.maximum) < 0.001,
                'value=${instance.getParameterByName(p.name)}');
            @:privateAccess state.check("audit_evi_by_name_aliases",
                instance.setParameterByName(p.name, p.minimum).isOk()
                && Math.abs(instance.getParameterByName(p.name) - p.minimum) < 0.001
                && instance.getParameterByNameFinal(p.name) == instance.getParameterFinal(p.name),
                'value=${instance.getParameterByName(p.name)}');
            @:privateAccess state.check("audit_evi_set_parameters_by_ids_empty", instance.setParametersByIDs([], []).isOk(),
                'result=${StudioSystem.lastResult().toString()}');
            instance.release();
        }

        // Global parameter batch and the description list
        var list = StudioSystem.getParameterDescriptionList();
        @:privateAccess state.check("audit_sys_parameter_description_list", list.length == StudioSystem.getParameterDescriptionCount(),
            'list=${list.length} count=${StudioSystem.getParameterDescriptionCount()}');
        var intensity = StudioSystem.getParameterDescriptionByName("Intensity");
        if (intensity != null) {
            var before = StudioSystem.getParameterByName("Intensity");
            var mid = (intensity.minimum + intensity.maximum) / 2;
            var batch:FmodResult = StudioSystem.setParametersByIDs([intensity.id], [mid]);
            @:privateAccess state.check("audit_sys_set_parameters_by_ids", batch.isOk(), 'result=${batch.toString()}');
            @:privateAccess state.check("audit_sys_set_parameters_by_ids_value",
                Math.abs(StudioSystem.getParameterByName("Intensity") - mid) < 0.001,
                'value=${StudioSystem.getParameterByName("Intensity")}');
            @:privateAccess state.check("audit_sys_by_name_aliases", StudioSystem.setParameterByName("Intensity", before).isOk()
                && Math.abs(StudioSystem.getParameterByName("Intensity") - before) < 0.001
                && StudioSystem.getParameterLabelByName("Weather", 0) == StudioSystem.getParameterLabel("Weather", 0),
                'value=${StudioSystem.getParameterByName("Intensity")}');
        }

        // Bank string info pairs the GUID with the path
        var strings = haxefmod.studio.Bank.NULL;
        for (bank in StudioSystem.getBankList()) if (bank.getStringCount() > 0) strings = bank;
        var info = strings.isNull() ? null : strings.getStringInfo(0);
        @:privateAccess state.check("audit_bank_string_info", info != null && info.id.length == 38 && info.path != ""
            && info.path == strings.getStringPath(0) && info.id == strings.getStringGuid(0),
            info == null ? 'null result=${StudioSystem.lastResult().toString()}' : 'path=${info.path}');
        @:privateAccess state.check("audit_bank_string_info_miss", strings.isNull() || strings.getStringInfo(100000) == null, "");

        // Mixer and stream buffer readback from the running system
        var channels = CoreSystem.getSoftwareChannels();
        @:privateAccess state.check("audit_sys_software_channels", channels > 0, 'channels=$channels');
        var mixer = CoreSystem.getDSPBufferSize();
        @:privateAccess state.check("audit_sys_dsp_buffer_size", mixer != null && mixer.bufferLength > 0 && mixer.numBuffers > 0,
            mixer == null ? 'null result=${StudioSystem.lastResult().toString()}' : 'length=${mixer.bufferLength} buffers=${mixer.numBuffers}');
        var stream = CoreSystem.getStreamBufferSize();
        @:privateAccess state.check("audit_sys_stream_buffer_size", stream != null && stream.fileBufferSize > 0
            && (stream.fileBufferSizeType == FmodTimeUnit.RAWBYTES || stream.fileBufferSizeType == FmodTimeUnit.MS),
            stream == null ? 'null result=${StudioSystem.lastResult().toString()}' : 'size=${stream.fileBufferSize} unit=${(stream.fileBufferSizeType : Int)}');
        @:privateAccess state.check("audit_sys_num_drivers_alias", CoreSystem.getNumDrivers() == CoreSystem.getDriverCount(),
            'drivers=${CoreSystem.getNumDrivers()}');

        // Renamed getters on a live channel and DSP agree with the originals
        var group = haxefmod.core.ChannelGroup.create("audit-group");
        var dsp = haxefmod.core.Dsp.create(haxefmod.core.DspType.LOWPASS);
        @:privateAccess state.check("audit_cg_reverb_properties", group.setReverbProperties(0, 0.25).isOk()
            && Math.abs(group.getReverbProperties(0) - 0.25) < 0.001 && group.getReverbProperties(0) == group.getReverbWet(0),
            'wet=${group.getReverbProperties(0)}');
        @:privateAccess state.check("audit_cg_num_aliases", group.getNumDSPs() == group.getDspCount()
            && group.getNumChannels() == group.getChannelCount() && group.getNumGroups() == group.getGroupCount(),
            'dsps=${group.getNumDSPs()}');
        @:privateAccess state.check("audit_dsp_parameter_float", dsp.setParameterFloat(0, 1000.0).isOk()
            && Math.abs(dsp.getParameterFloat(0) - 1000.0) < 0.5 && dsp.getParameterFloat(0) == dsp.getParameter(0),
            'cutoff=${dsp.getParameterFloat(0)}');
        @:privateAccess state.check("audit_dsp_num_aliases", dsp.getNumParameters() == dsp.getParameterCount()
            && dsp.getNumInputs() == dsp.getInputCount() && dsp.getNumOutputs() == dsp.getOutputCount(),
            'params=${dsp.getNumParameters()}');
        var soundGroup = haxefmod.core.SoundGroup.master();
        @:privateAccess state.check("audit_sg_num_aliases", soundGroup.getNumSounds() == soundGroup.getSoundCount()
            && soundGroup.getNumPlaying() == soundGroup.getPlayingCount(), 'sounds=${soundGroup.getNumSounds()}');
        dsp.release();
        group.release();

        @:privateAccess state.check("no_handle_leaks_csharp_audit", StudioSystem.liveHandleCount() == baseline,
            'baseline=$baseline now=${StudioSystem.liveHandleCount()}');
    }
}
