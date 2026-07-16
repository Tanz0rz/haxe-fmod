package;

import flixel.FlxG;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxefmod.core.Channel;
import haxefmod.core.ChannelGroup;
import haxefmod.runtime.FmodRuntime;
import haxefmod.runtime.IFmodPositionProvider;
import haxefmod.core.ChannelMode;
import haxefmod.core.CoreSystem;
import haxefmod.core.Dsp;
import haxefmod.core.DspConnection;
import haxefmod.core.DspType;
import haxefmod.core.PcmStream;
import haxefmod.core.ChannelCallbacks;
import haxefmod.core.ChannelEvent;
import haxefmod.core.Reverb;
import haxefmod.core.Reverb3D;
import haxefmod.core.SoundGroup;
import haxefmod.studio.CommandReplay;
import haxefmod.studio.CoreSound;
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
        probeParityTail();
        probeSoundGroupsAndSystem();
        probeAuditClosure();
        probeFlixelBridge();
        probeFocusMute();
        _statusLabel = label;

        // Channel event delivery is asynchronous: the probe finishes from
        // update() once the events arrive (or the wait times out)
        probeChannelEvents();
    }

    /** Exercises the audit-closure surface through the real FFI. */
    function probeAuditClosure():Void {
        // Per-instance channel group: effects on one event. Runs before the
        // baseline snapshot because the group's cached lookup handle
        // legitimately outlives the instance (reclaimed by the next unload
        // sweep, like the bus group).
        var desc = StudioSystem.getEvent(FmodEvents.MusicMainLevel);
        var instance = desc.createInstance();
        instance.start();
        StudioSystem.flushCommands();
        var instanceGroup = instance.getChannelGroup();
        check("evi_channel_group", !instanceGroup.isNull(), 'handle=${(instanceGroup : Int)}');
        if (!instanceGroup.isNull()) {
            var lowpass = Dsp.create(DspType.LOWPASS_SIMPLE);
            check("evi_group_effect", instanceGroup.addDsp(0, lowpass).isOk()
                && instanceGroup.removeDsp(lowpass).isOk(), "");
            lowpass.release();
        }
        instance.stop(FmodStopMode.IMMEDIATE);
        instance.release();

        var baseline = StudioSystem.liveHandleCount();

        // Channel odds on a paused stream
        var stream = PcmStream.create(48000, 1);
        var channel = stream.play(true);
        check("chan_priority_roundtrip", channel.setPriority(100).isOk()
            && channel.getPriority() == 100, 'value=${channel.getPriority()}');
        check("chan_volume_ramp_roundtrip", channel.setVolumeRamp(true).isOk()
            && channel.getVolumeRamp(), "");
        info("chan_is_virtual", Std.string(channel.isVirtual()));
        info("chan_audibility", Std.string(channel.getAudibility()));
        info("chan_index", Std.string(channel.getIndex()));
        check("chan_loop_points_roundtrip", channel.setLoopPoints(10, 90).isOk()
            && channel.getLoopPoints() != null && channel.getLoopPoints().startMs == 10, "");
        channel.setReverbWet(0, 0.4);
        check("chan_reverb_wet_roundtrip", Math.abs(channel.getReverbWet(0) - 0.4) < 0.001,
            'value=${channel.getReverbWet(0)}');
        channel.set3DConeOrientation(0, 0, 1);
        var orientation = channel.get3DConeOrientation();
        // Cone orientation reads back on 3D channels only, informational here
        info("chan_cone_orientation", orientation == null ? "unavailable" : 'z=${orientation.z}');
        var echo = Dsp.create(DspType.ECHO);
        channel.addDsp(0, echo);
        check("chan_dsp_introspection", channel.getDspCount() >= 1
            && !channel.getDsp(0).isNull(), 'count=${channel.getDspCount()}');
        channel.removeDsp(echo);
        echo.release();
        channel.stop();
        stream.release();

        // Memory sounds and their metadata
        var pcm = haxe.io.Bytes.alloc(9600);
        var sound = CoreSound.fromPcm(pcm, 48000, 1);
        info("sound_name", '"${sound.getName()}"');
        check("sound_group_getter", !sound.getSoundGroup().isNull(), "");
        check("sound_loop_count_roundtrip", sound.setLoopCount(2).isOk()
            && sound.getLoopCount() == 2, "");
        var playChannel = sound.play(true);
        check("chan_current_sound_dedup", (playChannel.getCurrentSound() : Int) == (sound : Int),
            'current=${(playChannel.getCurrentSound() : Int)} sound=${(sound : Int)}');
        playChannel.stop();
        sound.release();

        // Sound group volume and counters
        var soundGroup = SoundGroup.create("probe-audit-sg");
        check("sg_volume_roundtrip", soundGroup.setVolume(0.5).isOk()
            && Math.abs(soundGroup.getVolume() - 0.5) < 0.001, "");
        check("sg_fade_getter", soundGroup.setMuteFadeSpeed(0.7).isOk()
            && Math.abs(soundGroup.getMuteFadeSpeed() - 0.7) < 0.001, "");
        info("sg_playing_count", Std.string(soundGroup.getPlayingCount()));
        soundGroup.release();

        // Drivers
        check("sys_driver_roundtrip", CoreSystem.setDriver(0).isOk()
            && CoreSystem.getDriver() == 0, "");

        // DSP data params, info, and traversal
        var convolution = Dsp.create(DspType.CONVOLUTIONREVERB);
        var ir = haxe.io.Bytes.alloc((1 + 480) * 2);
        ir.setUInt16(0, 1);
        for (i in 0...480) {
            var v = Std.int(Math.exp(-i / 100) * 16000);
            ir.setUInt16((1 + i) * 2, v & 0xFFFF);
        }
        check("dsp_data_param_ir", convolution.setParameterData(0, ir).isOk(), "");
        check("dsp_info_name", convolution.getName().indexOf("Convolution") >= 0,
            'name=${convolution.getName()}');
        info("dsp_idle", Std.string(convolution.isIdle()));
        var target = Dsp.create(DspType.LOWPASS_SIMPLE);
        var connection = target.addInput(convolution);
        check("dsp_output_traversal", (convolution.getOutput(0) : Int) == (target : Int)
            && (convolution.getOutputConnection(0) : Int) == (connection : Int), "");
        check("conn_endpoints", (connection.getInputDsp() : Int) == (convolution : Int)
            && (connection.getOutputDsp() : Int) == (target : Int), "");
        target.disconnectFrom(convolution);
        target.release();
        convolution.release();

        // Reverb3D getters
        var zone = Reverb3D.create();
        zone.set3DAttributes(1, 2, 3, 5, 20);
        zone.setActive(true);
        check("r3d_active_getter", zone.getActive(), "");
        var zoneAttrs = zone.get3DAttributes();
        check("r3d_attrs_roundtrip", zoneAttrs != null && Math.abs(zoneAttrs.x - 1) < 0.001
            && Math.abs(zoneAttrs.minDistance - 5) < 0.001, "");
        zone.release();

        // Group spatial mirror round-trips
        var group = ChannelGroup.create("probe-audit-cg");
        check("cg_mirror_setters", group.setPan(0.5).isOk()
            && group.setLowPassGain(0.5).isOk()
            && group.setMode(ChannelMode.MODE_3D).isOk()
            && group.set3DAttributes(1, 2, 3).isOk()
            && group.set3DMinMaxDistance(2, 50).isOk()
            && group.set3DOcclusion(0.4, 0.2).isOk()
            && group.setMixMatrix([1, 0, 0, 1], 2, 2).isOk(), "");
        var groupAttrs = group.get3DAttributes();
        check("cg_attrs_roundtrip", groupAttrs != null && Math.abs(groupAttrs.posX - 1) < 0.001, "");
        var groupMinMax = group.get3DMinMaxDistance();
        check("cg_min_max_roundtrip", groupMinMax != null
            && Math.abs(groupMinMax.minDistance - 2) < 0.001, "");
        check("cg_level_roundtrip", group.set3DLevel(0.8).isOk()
            && Math.abs(group.get3DLevel() - 0.8) < 0.001, "");
        check("cg_spread_roundtrip", group.set3DSpread(45).isOk()
            && Math.abs(group.get3DSpread() - 45) < 0.1, "");
        check("cg_doppler_roundtrip", group.set3DDopplerLevel(0.7).isOk()
            && Math.abs(group.get3DDopplerLevel() - 0.7) < 0.001, "");
        check("cg_cone_roundtrip", group.set3DConeSettings(30, 60, 0.5).isOk()
            && group.get3DConeSettings() != null
            && Math.abs(group.get3DConeSettings().insideAngle - 30) < 0.1, "");
        check("cg_cone_orient_roundtrip", group.set3DConeOrientation(0, 0, 1).isOk()
            && group.get3DConeOrientation() != null
            && Math.abs(group.get3DConeOrientation().z - 1) < 0.001, "");
        check("cg_reverb_wet_roundtrip", group.setReverbWet(0, 0.4).isOk()
            && Math.abs(group.getReverbWet(0) - 0.4) < 0.001, "");
        check("cg_volume_ramp_roundtrip", group.setVolumeRamp(true).isOk()
            && group.getVolumeRamp(), "");
        check("cg_name", group.getName() == "probe-audit-cg", 'name=${group.getName()}');
        info("cg_audibility", Std.string(group.getAudibility()));
        check("cg_channel_introspection", group.getChannelCount() == 0
            && group.getChannel(0).isNull(), "");
        group.release();

        // Command capture round-trip with replay lifecycle
        var capturePath = "probe-capture.cmd.txt";
        check("capture_start", StudioSystem.startCommandCapture(capturePath).isOk(), "");
        FmodManager.Update();
        check("capture_stop", StudioSystem.stopCommandCapture().isOk(), "");
        var replay = StudioSystem.loadCommandReplay(capturePath);
        check("replay_load", !replay.isNull(), 'handle=${(replay : Int)}');
        if (!replay.isNull()) {
            info("replay_length", Std.string(replay.getLength()));
            check("replay_is_valid", replay.isValid(), "");
            check("replay_pause_roundtrip", replay.setPaused(true).isOk() && replay.getPaused(), "");
            replay.setPaused(false);
            check("replay_release", replay.release().isOk(), "");
            check("replay_stale_invalid", !replay.isValid(), "");
        }

        // Bank from memory: covered by the js harness on html5; native loads
        // the real bank bytes here
        #if sys
        var bankBytes = try sys.io.File.getBytes("assets/fmod/Desktop/Master.bank") catch (e:Dynamic) null;
        if (bankBytes == null) {
            info("bank_memory", "bank file not reachable from cwd, skipped");
        } else {
            var memoryBank = StudioSystem.loadBankMemory(bankBytes);
            // The example project has one bank, already loaded: ALREADY_LOADED
            // proves the path reaches FMOD either way
            var loaded = !memoryBank.isNull()
                || StudioSystem.lastResult() == FmodResult.FMOD_ERR_EVENT_ALREADY_LOADED;
            check("bank_memory", loaded, 'result=${StudioSystem.lastResult().toString()}');
            if (!memoryBank.isNull()) memoryBank.unload();
        }
        #else
        info("bank_memory", "verified by the js harness");
        #end

        check("no_handle_leaks_audit", StudioSystem.liveHandleCount() == baseline,
            'baseline=$baseline now=${StudioSystem.liveHandleCount()}');
    }

    var _statusLabel:FlxText;
    var _chanEvents:Array<ChannelEvent> = [];
    var _chanEventSound:CoreSound = CoreSound.NULL;
    var _chanEventChannel:Channel = Channel.NULL;
    var _chanEventBaseline:Int = 0;
    var _chanEventFrames:Int = 0;
    var _waitingForChannelEvents:Bool = false;
    var _oneShotFrames:Int = 0;
    var _waitingForOneShot:Bool = false;
    var _oneShotBaseline:Int = 0;
    var _oneShotAttachedBaseline:Int = 0;

    /**
     * Plays a tenth of a second of PCM with a sync point at its middle and
     * a channel callback registered. Both events must arrive through the
     * per-frame queue drain before the probe completes.
     */
    function probeChannelEvents():Void {
        _chanEventBaseline = StudioSystem.liveHandleCount();
        var samples = 4800;
        var pcm = haxe.io.Bytes.alloc(samples * 2);
        _chanEventSound = CoreSound.fromPcm(pcm, 48000, 1);
        check("chanev_sound", !_chanEventSound.isNull(), 'handle=${(_chanEventSound : Int)}');
        var syncResult = _chanEventSound.addSyncPoint(50, "mid");
        check("chanev_sync_point", syncResult.isOk(), 'result=${syncResult.toString()}');
        check("chanev_sync_info", _chanEventSound.getSyncPointCount() == 1
            && _chanEventSound.getSyncPointName(0) == "mid"
            && _chanEventSound.getSyncPointOffset(0) == 50, "");
        _chanEventChannel = _chanEventSound.play(false);
        check("chanev_play", !_chanEventChannel.isNull(), 'handle=${(_chanEventChannel : Int)}');
        _chanEventChannel.setCallback(function(e) _chanEvents.push(e));
        _waitingForChannelEvents = true;
    }

    function finishChannelEvents():Void {
        var sawSync = false;
        var sawEnd = false;
        for (e in _chanEvents) {
            switch (e) {
                case SyncPoint(0): sawSync = true;
                case End: sawEnd = true;
                default:
            }
        }
        check("chanev_syncpoint_delivered", sawSync, 'events=${_chanEvents.length} frames=$_chanEventFrames');
        check("chanev_end_delivered", sawEnd, 'events=${_chanEvents.length} frames=$_chanEventFrames');
        _chanEventChannel.stop();
        _chanEventSound.release();
        check("no_handle_leaks_chanev", StudioSystem.liveHandleCount() == _chanEventBaseline,
            'baseline=$_chanEventBaseline now=${StudioSystem.liveHandleCount()}');

        probeOneShotAttached();
    }

    /**
     * A one-shot played attached must track its instance while playing,
     * release it when the event stops, and prune the attachment. Async:
     * finishes from update() once the attachment count drops back (or the
     * wait times out).
     */
    function probeOneShotAttached():Void {
        // Warm the description lookup so its persistent dedup handle is
        // inside the baseline
        StudioSystem.getEvent(FmodEvents.SFXJump);
        _oneShotBaseline = StudioSystem.liveHandleCount();
        _oneShotAttachedBaseline = FmodRuntime.attachedCount();
        FmodRuntime.playOneShotAttached(FmodEvents.SFXJump, new ProbeMovingProvider());
        check("oneshot_attached_tracked", FmodRuntime.attachedCount() == _oneShotAttachedBaseline + 1,
            'count=${FmodRuntime.attachedCount()}');
        _waitingForOneShot = true;
    }

    function finishOneShotAttached():Void {
        check("oneshot_attached_pruned", FmodRuntime.attachedCount() == _oneShotAttachedBaseline,
            'count=${FmodRuntime.attachedCount()} frames=$_oneShotFrames');
        check("no_handle_leaks_oneshot", StudioSystem.liveHandleCount() == _oneShotBaseline,
            'baseline=$_oneShotBaseline now=${StudioSystem.liveHandleCount()}');

        info("live_handle_count_after", Std.string(StudioSystem.liveHandleCount()));
        log('API_PROBE: COMPLETE passed=$_passCount failed=$_failCount');
        _statusLabel.text = 'API_PROBE complete: $_passCount passed, $_failCount failed';
        _done = true;
    }

    /** Exercises the sound group and remaining system surface through the real FFI. */
    function probeSoundGroupsAndSystem():Void {
        var baseline = StudioSystem.liveHandleCount();
        var group = SoundGroup.create("probe-sg");
        check("sg_create", !group.isNull(), 'handle=${(group : Int)}');
        check("sg_max_audible_roundtrip", group.setMaxAudible(2).isOk()
            && group.getMaxAudible() == 2, 'value=${group.getMaxAudible()}');
        check("sg_behavior_roundtrip", group.setMaxAudibleBehavior(SoundGroup.BEHAVIOR_STEAL_LOWEST).isOk()
            && group.getMaxAudibleBehavior() == SoundGroup.BEHAVIOR_STEAL_LOWEST, "");
        check("sg_mute_fade", group.setMuteFadeSpeed(0.5).isOk(), "");

        var pcm = haxe.io.Bytes.alloc(9600);
        var sound = CoreSound.fromPcm(pcm, 48000, 1);
        check("sg_assign", sound.setSoundGroup(group).isOk(), "");
        check("sg_sound_count", group.getSoundCount() == 1, 'value=${group.getSoundCount()}');
        check("sg_stop", group.stop().isOk(), "");
        var master = SoundGroup.master();
        check("sg_master", !master.isNull(), 'handle=${(master : Int)}');
        sound.setSoundGroup(master);
        check("sg_release", group.release().isOk(), "");
        sound.release();

        check("sys_3d_settings_roundtrip", CoreSystem.set3DSettings(1.5, 1.0, 1.0).isOk()
            && CoreSystem.get3DSettings() != null
            && Math.abs(CoreSystem.get3DSettings().dopplerScale - 1.5) < 0.001, "");
        CoreSystem.set3DSettings(1.0, 1.0, 1.0);
        check("sys_drivers", CoreSystem.getDriverCount() >= 1
            && CoreSystem.getDriverName(0).length > 0, 'name=${CoreSystem.getDriverName(0)}');

        // Getter symmetry through the real FFI
        var stream = PcmStream.create3d(48000, 1);
        var channel = stream.play(true);
        channel.setLoopCount(-1);
        check("chan_get_loop_count", channel.getLoopCount() == -1, "");
        channel.setLowPassGain(0.5);
        check("chan_get_low_pass_gain", Math.abs(channel.getLowPassGain() - 0.5) < 0.001, "");
        check("chan_get_mode", channel.getMode() != 0, 'mode=${channel.getMode()}');
        channel.set3DConeSettings(30, 60, 0.5);
        var cone = channel.get3DConeSettings();
        check("chan_get_cone", cone != null && Math.abs(cone.insideAngle - 30) < 0.1, "");
        channel.set3DSpread(45);
        check("chan_get_spread", Math.abs(channel.get3DSpread() - 45) < 0.1, "");
        channel.set3DMinMaxDistance(2, 50);
        var minMax = channel.get3DMinMaxDistance();
        check("chan_get_min_max", minMax != null && Math.abs(minMax.minDistance - 2) < 0.001, "");
        channel.set3DAttributes(1, 2, 3);
        var attrs = channel.get3DAttributes();
        check("chan_get_3d_attributes", attrs != null && Math.abs(attrs.posX - 1) < 0.001
            && Math.abs(attrs.posY - 2) < 0.001, "");
        var clocks = channel.getDspClock();
        if (clocks != null) {
            channel.setDelay(0, clocks.parent + 96000);
            var delay = channel.getDelay();
            check("chan_get_delay", delay != null
                && Math.abs(delay.endClock - (clocks.parent + 96000)) < 1, "");
        }
        channel.stop();
        stream.release();

        var dsp = Dsp.create(DspType.LOWPASS_SIMPLE);
        dsp.setWetDryMix(1, 0.8, 0.2);
        var mix = dsp.getWetDryMix();
        check("dsp_get_wet_dry", mix != null && Math.abs(mix.postwet - 0.8) < 0.001, "");
        // A detached DSP's default active state varies by platform, so the
        // round-trip sets it explicitly first
        dsp.setActive(true);
        check("dsp_get_active", dsp.getActive(), "");
        dsp.setMeteringEnabled(true, false);
        var metering = dsp.getMeteringEnabled();
        check("dsp_get_metering_enabled", metering != null && metering.input && !metering.output, "");
        dsp.release();

        // The master sound group handle persists like the other master lookups
        var now = StudioSystem.liveHandleCount();
        check("no_handle_leaks_sg", now == baseline + 1,
            'baseline=$baseline now=$now');
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
                // The ID from the by-index fetch must resolve back to the
                // same description through the by-ID lookup
                var byId = desc.getParameterDescriptionByID(param.id);
                check("evd_get_parameter_description_by_id", byId != null && byId.name == param.name,
                    byId == null ? 'id=${param.id.data1}/${param.id.data2}' : 'name=${byId.name}');
                var missing = desc.getParameterDescriptionByID({data1: 0x7FFFFFFF, data2: 0x7FFFFFFF});
                check("evd_param_desc_by_id_miss", missing == null, "");
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

        // Write validation: an oversized count clamps to the real buffer
        // size (an unclamped count would read past the buffer), and a zero
        // count is rejected with INVALID_PARAM on every backend
        var spaceLeft = stream.space();
        var oversized = stream.write(data, data.length * 4);
        var clampExpected = data.length < spaceLeft ? data.length : spaceLeft;
        check("core_pcm_write_oversized_clamped", oversized == clampExpected,
            'wrote=$oversized expected=$clampExpected');
        var zeroWrite = stream.write(data, 0);
        check("core_pcm_write_zero_rejected", zeroWrite == 0
            && StudioSystem.lastResult() == FmodResult.FMOD_ERR_INVALID_PARAM,
            'wrote=$zeroWrite result=${StudioSystem.lastResult().toString()}');

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
     * Exercises the parity tail through the real FFI: the connection
     * graph, group nesting, scheduling, spatial extras, reverb zones,
     * memory sounds, and system queries, with handle safety over the
     * new type tags.
     */
    function probeParityTail():Void {
        var baseline = StudioSystem.liveHandleCount();

        // Connection graph: an oscillator wired into a lowpass
        var osc = Dsp.create(DspType.OSCILLATOR);
        var lowpass = Dsp.create(DspType.LOWPASS_SIMPLE);
        var conn = lowpass.addInput(osc);
        check("dsp_add_input", !conn.isNull(), 'handle=${(conn : Int)}');
        check("conn_mix_roundtrip", conn.setMix(0.5).isOk()
            && Math.abs(conn.getMix() - 0.5) < 0.001, 'value=${conn.getMix()}');
        check("dsp_input_count", lowpass.getInputCount() == 1,
            'value=${lowpass.getInputCount()}');
        check("dsp_input_dedup", (lowpass.getInput(0) : Int) == (osc : Int), "");
        check("dsp_input_conn_dedup", (lowpass.getInputConnection(0) : Int) == (conn : Int), "");
        var disconnect = lowpass.disconnectFrom(osc);
        check("dsp_disconnect", disconnect.isOk(), 'result=${disconnect.toString()}');
        // Graph changes invalidate every connection handle deterministically
        var staleConn:FmodResult = conn.setMix(1.0);
        check("stale_conn_invalid_handle", staleConn == FmodResult.FMOD_ERR_INVALID_HANDLE,
            'result=${staleConn.toString()}');

        // Nesting
        var parent = ChannelGroup.create("probe-parent");
        var child = ChannelGroup.create("probe-child");
        check("cg_add_group", parent.addGroup(child).isOk(), "");
        check("cg_group_count", parent.getGroupCount() == 1, 'value=${parent.getGroupCount()}');
        check("cg_group_dedup", (parent.getGroup(0) : Int) == (child : Int), "");
        check("cg_parent_dedup", (child.getParentGroup() : Int) == (parent : Int), "");

        // Scheduling on a live channel
        var oscChannel = osc.play(true);
        var clocks = oscChannel.getDspClock();
        check("chan_dsp_clock", clocks != null, clocks == null ? "" : 'parent=${clocks.parent}');
        if (clocks != null) {
            var base = clocks.parent;
            check("chan_set_delay", oscChannel.setDelay(0, base + 96000).isOk(), "");
            check("chan_fade_points", oscChannel.addFadePoint(base + 4800, 1.0).isOk()
                && oscChannel.addFadePoint(base + 48000, 0.0).isOk(), "");
            check("chan_fade_ramp", oscChannel.setFadePointRamp(base + 9600, 0.5).isOk(), "");
            check("chan_remove_fades", oscChannel.removeFadePoints(0, base + 96000).isOk(), "");
            check("cg_scheduling", parent.getDspClock() != null
                && parent.addFadePoint(base + 4800, 0.5).isOk()
                && parent.removeFadePoints(0, base + 96000).isOk()
                && parent.setDelay(0, base + 96000).isOk(), "");
        }
        check("chan_mute_roundtrip", oscChannel.setMute(true).isOk() && oscChannel.getMute()
            && oscChannel.setMute(false).isOk() && !oscChannel.getMute(), "");
        check("chan_low_pass_gain", oscChannel.setLowPassGain(0.5).isOk(), "");
        check("chan_mix_matrix", oscChannel.setMixMatrix([1, 0, 0, 1], 2, 2).isOk(), "");
        oscChannel.stop();
        osc.release();
        lowpass.release();
        child.release();
        parent.release();

        // Spatial extras on a positional stream
        var stream3d = PcmStream.create3d(48000, 1);
        var channel3d = stream3d.play(true);
        check("chan_cone", channel3d.set3DConeSettings(30, 60, 0.5).isOk()
            && channel3d.set3DConeOrientation(0, 0, 1).isOk(), "");
        check("chan_occlusion_roundtrip", channel3d.set3DOcclusion(0.5, 0.3).isOk()
            && channel3d.get3DOcclusion() != null
            && Math.abs(channel3d.get3DOcclusion().direct - 0.5) < 0.001, "");
        check("chan_spatial_extras", channel3d.set3DSpread(45).isOk()
            && channel3d.set3DLevel(0.8).isOk()
            && channel3d.set3DDopplerLevel(1.0).isOk(), "");
        check("chan_set_mode", channel3d.setMode(ChannelMode.MODE_3D | ChannelMode.LINEAR_ROLLOFF_3D).isOk(), "");
        channel3d.stop();
        stream3d.release();

        // Reverb zone lifecycle
        var zone = Reverb3D.create();
        check("reverb3d_create", !zone.isNull(), 'handle=${(zone : Int)}');
        check("reverb3d_surface", zone.set3DAttributes(0, 0, 0, 5, 20).isOk()
            && zone.setProperties(Reverb.PRESET_CAVE).isOk()
            && zone.getProperties() != null
            && zone.setActive(true).isOk(), "");
        check("reverb3d_release", zone.release().isOk(), "");
        var staleZone:FmodResult = zone.setActive(false);
        check("stale_reverb3d", staleZone == FmodResult.FMOD_ERR_INVALID_HANDLE,
            'result=${staleZone.toString()}');

        // Memory sounds
        var samples = 4800;
        var pcm = haxe.io.Bytes.alloc(samples * 2);
        for (i in 0...samples) {
            var v = Std.int(Math.sin(2 * Math.PI * 440 * i / 48000) * 0x3000);
            pcm.setUInt16(i * 2, v & 0xFFFF);
        }
        var sound = CoreSound.fromPcm(pcm, 48000, 1);
        check("coresound_from_pcm", !sound.isNull(), 'handle=${(sound : Int)}');
        check("coresound_defaults", sound.setDefaults(24000, 128).isOk()
            && sound.getDefaults() != null
            && Math.abs(sound.getDefaults().frequency - 24000) < 1, "");
        check("coresound_mode", sound.setMode(ChannelMode.LOOP_NORMAL).isOk()
            && (sound.getMode() & ChannelMode.LOOP_NORMAL) != 0, "");
        check("coresound_loop_points", sound.setLoopPoints(10, 90).isOk()
            && sound.getLoopPoints() != null && sound.getLoopPoints().startMs == 10, "");
        check("coresound_format", sound.getFormat() != null
            && sound.getFormat().channels == 1 && sound.getFormat().bits == 16, "");
        check("coresound_open_state", sound.getOpenState() == 0,
            'state=${sound.getOpenState()}');
        var soundChannel = sound.play(true);
        check("coresound_play", !soundChannel.isNull(), 'handle=${(soundChannel : Int)}');
        soundChannel.stop();
        check("coresound_release", sound.release().isOk(), "");

        // System queries
        check("sys_channels_playing", CoreSystem.getChannelsPlaying() != null, "");
        check("sys_mixer_suspend_resume", CoreSystem.mixerSuspend().isOk()
            && CoreSystem.mixerResume().isOk(), "");
        var format = CoreSystem.getSoftwareFormat();
        check("sys_software_format", format != null && format.sampleRate > 0,
            format == null ? "" : 'rate=${format.sampleRate}');

        check("no_handle_leaks_tail", StudioSystem.liveHandleCount() == baseline,
            'baseline=$baseline now=${StudioSystem.liveHandleCount()}');
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

    /**
     * Verifies focus-driven muting through the real FFI and the Flixel
     * focus wiring installed by FmodFlxSetup in create(). Losing focus
     * mutes the core master channel group, regaining it unmutes, and the
     * opt-out keeps audio playing while unfocused. Restores focus at the
     * end so the run never finishes muted.
     */
    function probeFocusMute():Void {
        // The master group is cached by the DSP probe above, so this lookup
        // allocates nothing and the live count must hold across the section.
        var master = ChannelGroup.master();
        var baseline = StudioSystem.liveHandleCount();

        check("focus_starts_focused", FmodManager.IsWindowFocused(), "");
        check("focus_master_unmuted", !master.getMute(), "");

        // Losing and regaining focus mutes and unmutes the real master group
        FmodManager.SetWindowFocused(false);
        check("focus_lost_mutes_master", master.getMute(), "");
        FmodManager.SetWindowFocused(true);
        check("focus_gained_unmutes_master", !master.getMute(), "");

        // The Flixel focus signals drive the same path end to end
        FlxG.signals.focusLost.dispatch();
        check("focus_flx_signal_mutes", master.getMute(), "");
        FlxG.signals.focusGained.dispatch();
        check("focus_flx_signal_unmutes", !master.getMute(), "");

        // Opting out keeps the master group unmuted while unfocused
        FmodManager.SetMuteWhenUnfocused(false);
        FmodManager.SetWindowFocused(false);
        check("focus_optout_keeps_playing", !master.getMute(), "");
        // Re-enabling the policy while already unfocused mutes right away
        FmodManager.SetMuteWhenUnfocused(true);
        check("focus_reenable_mutes", master.getMute(), "");

        // Restore defaults so the run never finishes muted or unfocused
        FmodManager.SetWindowFocused(true);
        check("focus_restored_unmuted", FmodManager.IsWindowFocused() && !master.getMute(), "");

        check("no_handle_leaks_focus", StudioSystem.liveHandleCount() == baseline,
            'baseline=$baseline now=${StudioSystem.liveHandleCount()}');
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        if (_waitingForChannelEvents) {
            _chanEventFrames++;
            var sawEnd = false;
            for (e in _chanEvents) if (e.match(End)) sawEnd = true;
            // 0.1s of audio: events land within a few frames. The timeout
            // makes a broken delivery path fail loudly instead of hanging.
            if (sawEnd || _chanEventFrames > 300) {
                _waitingForChannelEvents = false;
                finishChannelEvents();
            }
        }
        if (_waitingForOneShot) {
            _oneShotFrames++;
            // The jump blip is well under a second. The generous timeout
            // makes a broken release path fail loudly instead of hanging
            if (FmodRuntime.attachedCount() == _oneShotAttachedBaseline || _oneShotFrames > 600) {
                _waitingForOneShot = false;
                finishOneShotAttached();
            }
        }
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

/** A drifting position source for the one-shot attachment probe. */
private class ProbeMovingProvider implements IFmodPositionProvider {
    var x:Float = 10;

    public function new() {}

    public function fmodX():Float {
        x += 1;
        return x;
    }

    public function fmodY():Float return 5;
    public function fmodVelocityX():Float return 60;
    public function fmodVelocityY():Float return 0;
}
