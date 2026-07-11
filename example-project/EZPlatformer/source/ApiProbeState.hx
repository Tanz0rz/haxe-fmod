package;

import flixel.FlxG;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxefmod.core.Channel;
import haxefmod.core.ChannelGroup;
import haxefmod.core.Dsp;
import haxefmod.core.DspType;
import haxefmod.core.PcmStream;
import haxefmod.core.Reverb;
import haxefmod.studio.Bus;
import haxefmod.studio.EventInstance;
import haxefmod.studio.FmodResult;
import haxefmod.studio.StudioSystem;
import haxefmod.studio.Types;

/**
 * CI probe for the haxefmod.studio binding surface.
 *
 * Exercises every Bus binding and logs one "API_PROBE:" line per check so
 * CI can assert coverage from the game log. On HTML5 this is the source of
 * truth for which functions FMOD's Emscripten API actually supports:
 * gating checks log pass=true/false, informational checks log info=... and
 * never fail the probe (e.g. CPU/memory profiling, which can legitimately
 * report FMOD_ERR_UNSUPPORTED).
 *
 * Select via HAXEFMOD_TEST_STATE=api-probe (native) or ?test=api-probe (HTML5).
 */
class ApiProbeState extends FlxState {
    var _failCount:Int = 0;
    var _passCount:Int = 0;
    var _done:Bool = false;
    var _framesWaited:Int = 0;

    static inline function log(message:String):Void {
        #if js
        js.Browser.console.log(message);
        #else
        trace(message);
        #end
    }

    function check(name:String, pass:Bool, detail:String):Void {
        if (pass) _passCount++ else _failCount++;
        log('API_PROBE: $name pass=$pass $detail');
    }

    function info(name:String, detail:String):Void {
        log('API_PROBE: $name info=$detail');
    }

    override public function create():Void {
        super.create();

        var label = new FlxText(0, 0, FlxG.width, "API_PROBE running");
        label.setFormat(null, 16, FlxColor.WHITE, FlxTextAlign.CENTER, NONE, FlxColor.BLACK);
        label.y = (FlxG.height / 2) - (label.height / 2);
        add(label);

        log("API_PROBE: Starting");

        // Installed here (instead of LoadFmodState) because the updater
        // plugin it adds would drain the callback queue every frame and
        // defeat cb-test's overflow phase
        haxefmod.flixel.FmodFlxSetup.init();

        var handlesBefore = StudioSystem.liveHandleCount();
        info("live_handle_count_before", Std.string(handlesBefore));

        // Lookup
        var master = StudioSystem.getBus("bus:/");
        check("sys_get_bus", !master.isNull(), 'handle=${(master : Int)}');
        check("bus_is_valid", master.isValid(), "");

        var missing = StudioSystem.getBus("bus:/DoesNotExist");
        check("sys_get_bus_missing", missing.isNull(),
            'lastResult=${StudioSystem.lastResult().toString()}');

        // Path and GUID
        var path = master.getPath();
        check("bus_get_path", path == "bus:/", 'value=$path');

        var guid = master.getID();
        // "{8-4-4-4-12}" formatted GUID is exactly 38 chars
        check("bus_get_id", guid.length == 38 && StringTools.startsWith(guid, "{"), 'value=$guid');

        // Volume round trip
        var setResult:FmodResult = master.setVolume(0.5);
        check("bus_set_volume", setResult.isOk(), 'result=${setResult.toString()}');
        var volume = master.getVolume();
        check("bus_get_volume", Math.abs(volume - 0.5) < 0.001, 'value=$volume');
        info("bus_get_final_volume", Std.string(master.getFinalVolume()));
        master.setVolume(1.0);

        // Pause round trip
        var pauseResult = master.setPaused(true);
        check("bus_set_paused", pauseResult.isOk(), 'result=${pauseResult.toString()}');
        check("bus_get_paused", master.getPaused(), "");
        master.setPaused(false);
        check("bus_get_paused_cleared", !master.getPaused(), "");

        // Mute round trip
        var muteResult = master.setMute(true);
        check("bus_set_mute", muteResult.isOk(), 'result=${muteResult.toString()}');
        check("bus_get_mute", master.getMute(), "");
        master.setMute(false);
        check("bus_get_mute_cleared", !master.getMute(), "");

        // Stop all events (no events playing - just verify the call succeeds)
        var stopResult = master.stopAllEvents(FmodStopMode.IMMEDIATE);
        check("bus_stop_all_events", stopResult.isOk(), 'result=${stopResult.toString()}');

        // Profiling - informational only (needs profiling enabled. May be
        // unsupported on some targets, especially HTML5)
        var cpu = master.getCpuUsage();
        info("bus_get_cpu_usage", cpu == null
            ? 'unavailable result=${StudioSystem.lastResult().toString()}'
            : 'exclusive=${cpu.exclusive} inclusive=${cpu.inclusive}');
        var memory = master.getMemoryUsage();
        info("bus_get_memory_usage", memory == null
            ? 'unavailable result=${StudioSystem.lastResult().toString()}'
            : 'exclusive=${memory.exclusive} inclusive=${memory.inclusive} sampledata=${memory.sampledata}');

        // Cached lookups must not allocate new handles
        var again = StudioSystem.getBus("bus:/");
        check("bus_lookup_cached", (again : Int) == (master : Int), "");

        probeM3Surface();
        probeHandleSafety();
        probeCoreSurface();
        probeDspSurface();
        probeFlixelBridge();

        info("live_handle_count_after", Std.string(StudioSystem.liveHandleCount()));

        log('API_PROBE: COMPLETE passed=$_passCount failed=$_failCount');
        label.text = 'API_PROBE complete: $_passCount passed, $_failCount failed';
        _done = true;
    }

    /** Exercises the M3 mass-binding surface: events, instances, banks, VCAs, system. */
    function probeM3Surface():Void {
        // Event description lookup and queries
        var desc = StudioSystem.getEvent(FmodEvents.MusicMainLevel);
        check("sys_get_event", !desc.isNull(), 'handle=${(desc : Int)}');
        check("evd_is_valid", desc.isValid(), "");
        check("evd_get_path", desc.getPath() == FmodEvents.MusicMainLevel, 'value=${desc.getPath()}');
        var descGuid = desc.getID();
        check("evd_get_id", descGuid.length == 38, 'value=$descGuid');
        check("evd_get_length", desc.getLength() > 0, 'value=${desc.getLength()}');
        info("evd_is_snapshot", Std.string(desc.isSnapshot()));
        info("evd_is_oneshot", Std.string(desc.isOneshot()));
        info("evd_is_stream", Std.string(desc.isStream()));
        info("evd_is_3d", Std.string(desc.is3D()));

        // GUID round trip: path -> GUID -> event -> same handle
        var lookedUp = StudioSystem.lookupID(FmodEvents.MusicMainLevel);
        check("sys_lookup_id", lookedUp == descGuid, 'value=$lookedUp');
        var byId = StudioSystem.getEventByID(descGuid);
        check("sys_get_event_by_id", (byId : Int) == (desc : Int), 'handle=${(byId : Int)}');
        var pathBack = StudioSystem.lookupPath(descGuid);
        check("sys_lookup_path", pathBack == FmodEvents.MusicMainLevel, 'value=$pathBack');

        // Parameters on the event
        var paramCount = desc.getParameterDescriptionCount();
        info("evd_parameter_description_count", Std.string(paramCount));
        if (paramCount > 0) {
            var param = desc.getParameterDescriptionByIndex(0);
            check("evd_get_parameter_description_by_index", param != null,
                param == null ? "" : 'name=${param.name} min=${param.minimum} max=${param.maximum} default=${param.defaultValue}');
            if (param != null) {
                var byName = desc.getParameterDescriptionByName(param.name);
                check("evd_get_parameter_description_by_name", byName != null && byName.name == param.name, "");
            }
        }

        // Instance lifecycle. Every handle created between this baseline and
        // the leak check below is released, so the live count must not move.
        var lifecycleBaseline = StudioSystem.liveHandleCount();
        var instance = desc.createInstance();
        check("evd_create_instance", !instance.isNull(), 'handle=${(instance : Int)}');
        check("evi_is_valid", instance.isValid(), "");
        check("evi_get_description", (instance.getDescription() : Int) == (desc : Int), "");

        var volResult = instance.setVolume(0.8);
        check("evi_set_volume", volResult.isOk(), "");
        check("evi_get_volume", Math.abs(instance.getVolume() - 0.8) < 0.001, 'value=${instance.getVolume()}');
        var pitchResult = instance.setPitch(1.5);
        check("evi_set_pitch", pitchResult.isOk(), "");
        check("evi_get_pitch", Math.abs(instance.getPitch() - 1.5) < 0.001, 'value=${instance.getPitch()}');
        instance.setPitch(1.0);

        if (paramCount > 0) {
            var param = desc.getParameterDescriptionByIndex(0);
            if (param != null) {
                var target = param.maximum;
                check("evi_set_param_by_name", instance.setParameter(param.name, target).isOk(), 'name=${param.name}');
                check("evi_get_param_by_name", Math.abs(instance.getParameter(param.name) - target) < 0.001,
                    'value=${instance.getParameter(param.name)}');
                check("evi_set_param_by_id", instance.setParameterByID(param.id, param.defaultValue).isOk(), "");
            }
        }

        var startResult = instance.start();
        check("evi_start", startResult.isOk(), 'result=${startResult.toString()}');
        info("evi_get_playback_state", Std.string((instance.getPlaybackState() : Int)));
        info("evi_is_virtual", Std.string(instance.isVirtual()));

        var stopResult = instance.stop(FmodStopMode.IMMEDIATE);
        check("evi_stop", stopResult.isOk(), 'result=${stopResult.toString()}');
        var releaseResult = instance.release();
        check("evi_release", releaseResult.isOk(), 'result=${releaseResult.toString()}');
        check("evi_released_handle_invalid", !instance.isValid(), "");

        // Instance property and 3D surface (event may be 2D - informational)
        var instance2 = desc.createInstance();
        if (!instance2.isNull()) {
            info("evi_get_property_channelpriority", Std.string(instance2.getProperty(CHANNELPRIORITY)));
            var attrResult = instance2.setPosition2D(3.0, 4.0);
            info("evi_set_3d_attributes", attrResult.toString());
            var attrs = instance2.get3DAttributes();
            info("evi_get_3d_attributes", attrs == null ? "unavailable" : 'x=${attrs.position.x} y=${attrs.position.y}');
            instance2.release();
        }
        check("no_handle_leaks_lifecycle", StudioSystem.liveHandleCount() == lifecycleBaseline,
            'baseline=$lifecycleBaseline now=${StudioSystem.liveHandleCount()}');

        // Bank surface
        var bankCount = StudioSystem.getBankCount();
        check("sys_get_bank_count", bankCount >= 2, 'value=$bankCount');
        var banks = StudioSystem.getBankList();
        check("sys_get_bank_list", banks.length == bankCount, 'count=${banks.length}');
        if (banks.length > 0) {
            var foundEvents = false;
            for (bank in banks) {
                check("bank_is_valid", bank.isValid(), 'path=${bank.getPath()}');
                info("bank_loading_state", Std.string((bank.getLoadingState() : Int)));
                var eventCount = bank.getEventCount();
                if (eventCount > 0) {
                    foundEvents = true;
                    var events = bank.getEventList();
                    check("bank_get_event_list", events.length == eventCount, 'count=${events.length}');
                    check("bank_event_valid", events[0].isValid(), 'path=${events[0].getPath()}');
                }
                var stringCount = bank.getStringCount();
                if (stringCount > 0) {
                    info("bank_string_info_first", bank.getStringPath(0));
                }
            }
            check("bank_events_enumerated", foundEvents, "");
        }

        // VCA (the example project has no VCAs - a missing lookup must return null, not crash)
        var vca = StudioSystem.getVCA("vca:/DoesNotExist");
        check("sys_get_vca_missing", vca.isNull(), 'lastResult=${StudioSystem.lastResult().toString()}');

        // Global parameters (none in the example project - count must not crash)
        info("sys_parameter_description_count", Std.string(StudioSystem.getParameterDescriptionCount()));

        // Listeners
        var listenerCount = StudioSystem.getNumListeners();
        check("sys_get_num_listeners", listenerCount >= 1, 'value=$listenerCount');
        var listenerResult = StudioSystem.setListenerPosition2D(0, 1.0, 2.0);
        check("sys_set_listener_attributes", listenerResult.isOk(), 'result=${listenerResult.toString()}');
        var listener = StudioSystem.getListenerAttributes(0);
        check("sys_get_listener_attributes", listener != null && Math.abs(listener.position.x - 1.0) < 0.001,
            listener == null ? "unavailable" : 'x=${listener.position.x} y=${listener.position.y}');
        StudioSystem.setListenerPosition2D(0, 0.0, 0.0);
        info("sys_get_listener_weight", Std.string(StudioSystem.getListenerWeight(0)));

        // System profiling - informational (unsupported pieces on html5)
        var sysCpu = StudioSystem.getCpuUsage();
        info("sys_get_cpu_usage", sysCpu == null ? 'unavailable result=${StudioSystem.lastResult().toString()}' : 'dsp=${sysCpu.dsp}');
        var sysMem = StudioSystem.getMemoryUsage();
        info("sys_get_memory_usage", sysMem == null ? 'unavailable result=${StudioSystem.lastResult().toString()}' : 'inclusive=${sysMem.inclusive}');
        var bufferUsage = StudioSystem.getBufferUsage();
        info("sys_get_buffer_usage", bufferUsage == null ? "unavailable" : 'cmdqueue_peak=${bufferUsage.studioCommandQueue.peakUsage}');

        // Sample data round trip
        var sampleResult = desc.loadSampleData();
        check("evd_load_sample_data", sampleResult.isOk(), 'result=${sampleResult.toString()}');
        info("evd_get_sample_loading_state", Std.string((desc.getSampleLoadingState() : Int)));
        desc.unloadSampleData();
    }

    /**
     * Runtime-verifies the generational handle table's safety promises
     * through the real FFI: stale handles, cross-type misuse, double
     * release, and slot reuse must all return
     * FMOD_ERR_INVALID_HANDLE (or default getter values) instead of
     * crashing or touching another object.
     */
    function probeHandleSafety():Void {
        // Lookups below are deduplicated, so every handle this section
        // creates is released and the live count must return to baseline
        var baseline = StudioSystem.liveHandleCount();
        var desc = StudioSystem.getEvent(FmodEvents.MusicMainLevel);
        var master = StudioSystem.getBus("bus:/");

        // Stale handle: every call must be a safe no-op after release
        var stale:EventInstance = desc.createInstance();
        check("abuse_setup_instance", !stale.isNull(), 'handle=${(stale : Int)}');
        stale.release();
        check("stale_handle_invalid", !stale.isValid(), "");
        var staleStart:FmodResult = stale.start();
        check("stale_start_invalid_handle", staleStart == FmodResult.FMOD_ERR_INVALID_HANDLE,
            'result=${staleStart.toString()}');
        check("stale_get_volume_default", stale.getVolume() == 0.0, 'value=${stale.getVolume()}');
        check("stale_get_timeline_default", stale.getTimelinePosition() == 0,
            'value=${stale.getTimelinePosition()}');

        // Cross-type misuse: a Bus handle passed as an EventInstance
        var wrongInstance:EventInstance = cast (master : Int);
        check("crosstype_bus_as_instance_invalid", !wrongInstance.isValid(), "");
        var wrongStart:FmodResult = wrongInstance.start();
        check("crosstype_bus_as_instance_start", wrongStart == FmodResult.FMOD_ERR_INVALID_HANDLE,
            'result=${wrongStart.toString()}');

        // ... and the reverse: an EventInstance handle passed as a Bus
        var live:EventInstance = desc.createInstance();
        var wrongBus:Bus = cast (live : Int);
        var wrongSet:FmodResult = wrongBus.setVolume(1.0);
        check("crosstype_instance_as_bus_set_volume", wrongSet == FmodResult.FMOD_ERR_INVALID_HANDLE,
            'result=${wrongSet.toString()}');
        live.release();

        // Double release must report INVALID_HANDLE, not crash
        var doubleRelease:FmodResult = stale.release();
        check("double_release_invalid_handle", doubleRelease == FmodResult.FMOD_ERR_INVALID_HANDLE,
            'result=${doubleRelease.toString()}');

        // Slot reuse: a new instance may reuse the freed slot, but the old
        // handle's generation is stale and must never resolve to it
        var reused:EventInstance = desc.createInstance();
        check("reuse_new_instance_valid", reused.isValid(), 'handle=${(reused : Int)}');
        check("reuse_stale_still_invalid", !stale.isValid(),
            'stale=${(stale : Int)} new=${(reused : Int)}');
        reused.release();

        check("no_handle_leaks_abuse", StudioSystem.liveHandleCount() == baseline,
            'baseline=$baseline now=${StudioSystem.liveHandleCount()}');
    }

    /**
     * Exercises the Core PCM stream and channel surface through the real
     * FFI: ring write accounting, channel control round-trips, and the
     * handle-safety promises extended to the new type tags. The channel
     * starts paused so the probe stays deterministic (drain timing is
     * covered by the js harness and the synth test, which pump the mixer).
     */
    function probeCoreSurface():Void {
        var baseline = StudioSystem.liveHandleCount();

        var stream = PcmStream.create(48000, 1);
        check("core_pcm_create", !stream.isNull(), 'handle=${(stream : Int)}');

        // A quarter second of a 440Hz sine (16-bit mono, little-endian)
        var samples = Std.int(48000 * 0.25);
        var data = haxe.io.Bytes.alloc(samples * 2);
        for (i in 0...samples) {
            var v = Std.int(Math.sin(2 * Math.PI * 440 * i / 48000) * 0x3000);
            data.setUInt16(i * 2, v & 0xFFFF);
        }
        var spaceBefore = stream.space();
        check("core_pcm_space", spaceBefore > 0, 'value=$spaceBefore');
        var wrote = stream.write(data);
        var expected = data.length < spaceBefore ? data.length : spaceBefore;
        check("core_pcm_write", wrote == expected, 'wrote=$wrote expected=$expected');
        check("core_pcm_space_shrinks", stream.space() == spaceBefore - wrote,
            'value=${stream.space()}');
        info("core_pcm_underruns", Std.string(stream.takeUnderruns()));

        var channel = stream.play(true);
        check("core_pcm_play", !channel.isNull(), 'handle=${(channel : Int)}');
        check("chan_starts_paused", channel.getPaused(), "");
        // A paused channel is still live as far as FMOD is concerned
        check("chan_is_playing", channel.isPlaying(), "");

        var volResult:FmodResult = channel.setVolume(0.5);
        check("chan_set_volume", volResult.isOk(), 'result=${volResult.toString()}');
        check("chan_get_volume", Math.abs(channel.getVolume() - 0.5) < 0.001,
            'value=${channel.getVolume()}');
        var pitchResult:FmodResult = channel.setPitch(1.5);
        check("chan_set_pitch", pitchResult.isOk(), 'result=${pitchResult.toString()}');
        check("chan_get_pitch", Math.abs(channel.getPitch() - 1.5) < 0.001,
            'value=${channel.getPitch()}');

        // Stop always frees the channel slot
        channel.stop();
        var staleChanSet:FmodResult = channel.setVolume(1.0);
        check("stale_chan_invalid_handle", staleChanSet == FmodResult.FMOD_ERR_INVALID_HANDLE,
            'result=${staleChanSet.toString()}');
        check("stale_chan_getter_defaults", channel.getVolume() == 0.0 && !channel.isPlaying(), "");

        // Cross-type misuse across the new tags
        var wrongChannel:Channel = cast (stream : Int);
        var wrongSet:FmodResult = wrongChannel.setVolume(1.0);
        check("crosstype_pcm_as_chan", wrongSet == FmodResult.FMOD_ERR_INVALID_HANDLE,
            'result=${wrongSet.toString()}');

        var releaseResult:FmodResult = stream.release();
        check("core_pcm_release", releaseResult.isOk(), 'result=${releaseResult.toString()}');
        var staleWrite = stream.write(data, 4);
        check("stale_pcm_write", staleWrite == 0, 'wrote=$staleWrite');
        var doubleRelease:FmodResult = stream.release();
        check("pcm_double_release_invalid_handle", doubleRelease == FmodResult.FMOD_ERR_INVALID_HANDLE,
            'result=${doubleRelease.toString()}');

        check("no_handle_leaks_core", StudioSystem.liveHandleCount() == baseline,
            'baseline=$baseline now=${StudioSystem.liveHandleCount()}');
    }

    /**
     * Exercises the DSP, channel group, bus bridge, and reverb surface
     * through the real FFI, with the handle-safety promises extended to
     * the new type tags.
     */
    function probeDspSurface():Void {
        var baseline = StudioSystem.liveHandleCount();

        var lowpass = Dsp.create(DspType.LOWPASS_SIMPLE);
        check("dsp_create", !lowpass.isNull(), 'handle=${(lowpass : Int)}');
        var setResult = lowpass.setParameter(0, 2000);
        check("dsp_set_parameter", setResult.isOk(), 'result=${setResult.toString()}');
        check("dsp_get_parameter", Math.abs(lowpass.getParameter(0) - 2000) < 1,
            'value=${lowpass.getParameter(0)}');
        check("dsp_get_type", lowpass.getType() == DspType.LOWPASS_SIMPLE,
            'value=${(lowpass.getType() : Int)}');
        check("dsp_get_parameter_count", lowpass.getParameterCount() > 0,
            'value=${lowpass.getParameterCount()}');
        check("dsp_bypass_roundtrip", lowpass.setBypass(true).isOk() && lowpass.getBypass()
            && lowpass.setBypass(false).isOk() && !lowpass.getBypass(), "");

        // Master group round-trips and effect attach
        var master = ChannelGroup.master();
        check("cg_get_master", !master.isNull(), 'handle=${(master : Int)}');
        var again = ChannelGroup.master();
        check("cg_master_dedup", (again : Int) == (master : Int), "");
        var addResult = master.addDsp(0, lowpass);
        check("cg_add_dsp", addResult.isOk(), 'result=${addResult.toString()}');
        var removeResult = master.removeDsp(lowpass);
        check("cg_remove_dsp", removeResult.isOk(), 'result=${removeResult.toString()}');

        // Custom group lifecycle
        var group = ChannelGroup.create("probe-group");
        check("cg_create", !group.isNull(), 'handle=${(group : Int)}');
        check("cg_volume_roundtrip", group.setVolume(0.5).isOk()
            && Math.abs(group.getVolume() - 0.5) < 0.001, 'value=${group.getVolume()}');
        check("cg_pitch_roundtrip", group.setPitch(1.25).isOk()
            && Math.abs(group.getPitch() - 1.25) < 0.001, 'value=${group.getPitch()}');
        check("cg_mute_roundtrip", group.setMute(true).isOk() && group.getMute()
            && group.setMute(false).isOk() && !group.getMute(), "");
        check("cg_paused_roundtrip", group.setPaused(true).isOk() && group.getPaused()
            && group.setPaused(false).isOk() && !group.getPaused(), "");

        // A stream channel reroutes into the group and gets a per-channel effect
        var stream = PcmStream.create(48000, 1);
        var channel = stream.play(true);
        check("chan_set_channel_group", channel.setChannelGroup(group).isOk(), "");
        var echo = Dsp.create(DspType.ECHO);
        check("chan_add_dsp", channel.addDsp(0, echo).isOk(), "");
        check("chan_remove_dsp", channel.removeDsp(echo).isOk(), "");
        echo.release();
        check("chan_set_pan", channel.setPan(0.5).isOk(), "");
        check("chan_frequency_roundtrip", channel.setFrequency(24000).isOk()
            && Math.abs(channel.getFrequency() - 24000) < 1, 'value=${channel.getFrequency()}');
        check("chan_set_reverb_wet", channel.setReverbWet(0, 0.5).isOk(), "");
        channel.stop();
        stream.release();
        check("cg_release", group.release().isOk(), "");

        // Oscillator through playDSP proves DSPs as sound sources
        var osc = Dsp.create(DspType.OSCILLATOR);
        osc.setParameterInt(0, 0);
        osc.setParameter(1, 440);
        var oscChannel = osc.play(true);
        check("sys_play_dsp", !oscChannel.isNull(), 'handle=${(oscChannel : Int)}');
        oscChannel.stop();
        osc.release();

        // Studio bus bridge: effects attach to Studio-mixed audio
        var bus = StudioSystem.getBus("bus:/");
        var lockResult = bus.lockChannelGroup();
        check("bus_lock_channel_group", lockResult.isOk(), 'result=${lockResult.toString()}');
        var busGroup = bus.getChannelGroup();
        check("bus_get_channel_group", !busGroup.isNull(), 'handle=${(busGroup : Int)}');
        check("bus_group_add_dsp", busGroup.addDsp(0, lowpass).isOk(), "");
        check("bus_group_remove_dsp", busGroup.removeDsp(lowpass).isOk(), "");
        check("bus_unlock_channel_group", bus.unlockChannelGroup().isOk(), "");

        // Reverb properties round-trip, then off
        var props = Reverb.PRESET_CONCERTHALL;
        check("reverb_set", Reverb.set(0, props).isOk(), "");
        var back = Reverb.get(0);
        check("reverb_get_roundtrip", back != null && Math.abs(back.decayTime - 3900) < 1,
            'decayTime=${back == null ? -1 : back.decayTime}');
        Reverb.off(0);

        // 3D stream accepts positional control
        var stream3d = PcmStream.create3d(48000, 1);
        check("pcm_create_3d", !stream3d.isNull(), 'handle=${(stream3d : Int)}');
        var channel3d = stream3d.play(true);
        check("chan_set_3d_attributes", channel3d.set3DAttributes(1, 0, 0).isOk(), "");
        check("chan_set_3d_min_max", channel3d.set3DMinMaxDistance(1, 100).isOk(), "");
        channel3d.stop();
        stream3d.release();

        // Handle safety over the new tags
        var staleDsp:FmodResult = lowpass.setParameter(0, 500);
        check("dsp_live_before_release", staleDsp.isOk(), 'result=${staleDsp.toString()}');
        lowpass.release();
        staleDsp = lowpass.setParameter(0, 500);
        check("stale_dsp_invalid_handle", staleDsp == FmodResult.FMOD_ERR_INVALID_HANDLE,
            'result=${staleDsp.toString()}');
        var wrongDsp:Dsp = cast (master : Int);
        var crossResult:FmodResult = wrongDsp.setParameter(0, 500);
        check("crosstype_cg_as_dsp", crossResult == FmodResult.FMOD_ERR_INVALID_HANDLE,
            'result=${crossResult.toString()}');

        // Two lookup handles may legitimately persist: the cached master
        // group, and the bus group if FMOD kept it alive after the unlock.
        // Everything owned (DSPs, streams, the custom group) must be gone.
        var persistent = 1; // the master group handle cached above
        busGroup.getVolume();
        var busGroupAlive = StudioSystem.lastResult() != FmodResult.FMOD_ERR_INVALID_HANDLE;
        if (busGroupAlive && (busGroup : Int) != (master : Int)) persistent++;
        var now = StudioSystem.liveHandleCount();
        check("no_handle_leaks_dsp", now == baseline + persistent,
            'baseline=$baseline now=$now persistent=$persistent busGroupAlive=$busGroupAlive');
    }

    /**
     * Verifies the FmodFlxSetup volume bridge installed in create():
     * FlxG.sound volume and mute changes must land on the FMOD master bus.
     */
    function probeFlixelBridge():Void {
        FlxG.sound.volume = 0.5;
        check("flx_bridge_volume", Math.abs(FmodManager.GetBusVolumeMaster() - 0.5) < 0.001,
            'value=${FmodManager.GetBusVolumeMaster()}');
        FlxG.sound.toggleMuted();
        check("flx_bridge_mute", FmodManager.GetBusMuteMaster(), "");
        // Volume is carried by the mute flag, so it must survive the mute
        check("flx_bridge_volume_kept", Math.abs(FmodManager.GetBusVolumeMaster() - 0.5) < 0.001,
            'value=${FmodManager.GetBusVolumeMaster()}');
        FlxG.sound.toggleMuted();
        check("flx_bridge_mute_cleared", !FmodManager.GetBusMuteMaster(), "");
        FlxG.sound.volume = 1.0;
        check("flx_bridge_volume_restored", Math.abs(FmodManager.GetBusVolumeMaster() - 1.0) < 0.001,
            'value=${FmodManager.GetBusVolumeMaster()}');
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        if (!_done) return;

        // Give the renderer a few frames so the result text is visible, then exit
        _framesWaited++;
        if (_framesWaited > 30) {
            #if sys
            Sys.exit(_failCount > 0 ? 1 : 0);
            #end
        }
    }
}
