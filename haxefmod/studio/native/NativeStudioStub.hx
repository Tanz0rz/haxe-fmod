package haxefmod.studio.native;

/**
 * Stub backend for targets without a native FMOD shim (eval/interp, used by
 * unit tests). Every call is a safe no-op: results report
 * FMOD_ERR_UNSUPPORTED, lookups return the invalid handle 0.
 *
 * This file is also the canonical wrapper API surface: the Cpp/Hl/Js
 * wrappers expose exactly these signatures.
 */
class NativeStudioStub {
    static inline var ERR_UNSUPPORTED = 68;

    // Test hooks: unit tests set these to simulate specific backend
    // behavior that the uniform no-op defaults cannot express. The
    // defaults keep every hook inert.
    public static var testPlaybackState:Int = 2;
    public static var testPlaybackStateQueue:Array<Int> = [];
    public static var testInitialized:Bool = false;
    public static var testCallbackMaskResult:Int = ERR_UNSUPPORTED;
    public static var testLastCallbackMask:Int = -1;
    public static var testLastCallbackMaskHandle:Int = 0;
    // Synthetic handles let FmodManager tests drive the song slot: lookups and
    // creates return incrementing nonzero handles instead of 0
    public static var testSyntheticHandles:Bool = false;
    public static var testNextHandle:Int = 2000;
    public static var testStartCalls:Int = 0;
    public static var testBankLoadingState:Int = 3;
    public static var testBankValid:Null<Bool> = null;
    public static var testBankUnloadCalls:Int = 0;

    // System
    public static function sys_last_result():Int return ERR_UNSUPPORTED;
    public static function sys_get_bus(path:String):Int return 0;
    public static function sys_get_bus_by_id(guid:String):Int return 0;
    public static function sys_get_event(path:String):Int
        return testSyntheticHandles ? ++testNextHandle : 0;
    public static function sys_get_event_by_id(guid:String):Int return 0;
    public static function sys_get_vca(path:String):Int return 0;
    public static function sys_get_vca_by_id(guid:String):Int return 0;
    public static function sys_get_bank(path:String):Int return 0;
    public static function sys_get_bank_by_id(guid:String):Int return 0;
    public static function sys_get_bank_count():Int return 0;
    public static function sys_get_bank_list():Int return 0;
    public static function sys_lookup_id(path:String):String return "";
    public static function sys_lookup_path(guid:String):String return "";
    public static function sys_get_param_by_name(name:String):Float return 0.0;
    public static function sys_get_param_by_name_final(name:String):Float return 0.0;
    public static function sys_set_param_by_name(name:String, value:Float, ignoreSeekSpeed:Bool):Int return ERR_UNSUPPORTED;
    public static function sys_set_param_by_name_with_label(name:String, label:String, ignoreSeekSpeed:Bool):Int return ERR_UNSUPPORTED;
    public static function sys_get_param_by_id(id1:Int, id2:Int):Float return 0.0;
    public static function sys_get_param_by_id_final(id1:Int, id2:Int):Float return 0.0;
    public static function sys_set_param_by_id(id1:Int, id2:Int, value:Float, ignoreSeekSpeed:Bool):Int return ERR_UNSUPPORTED;
    public static function sys_set_param_by_id_with_label(id1:Int, id2:Int, label:String, ignoreSeekSpeed:Bool):Int return ERR_UNSUPPORTED;
    public static function sys_get_parameter_description_count():Int return 0;
    public static function sys_get_parameter_description_by_index(index:Int):String return "";
    public static function sys_get_parameter_description_by_name(name:String):String return "";
    public static function sys_get_parameter_label(parameterName:String, labelIndex:Int):String return "";
    public static function sys_get_num_listeners():Int return 0;
    public static function sys_set_num_listeners(count:Int):Int return ERR_UNSUPPORTED;
    public static function sys_get_listener_attributes(index:Int):Int return ERR_UNSUPPORTED;
    public static function sys_set_listener_attributes(index:Int, px:Float, py:Float, pz:Float, vx:Float, vy:Float, vz:Float, fx:Float, fy:Float, fz:Float, ux:Float, uy:Float, uz:Float, hasAttenuation:Bool, ax:Float, ay:Float, az:Float):Int return ERR_UNSUPPORTED;
    public static function sys_last_parameter_guid():String return "";
    public static function sys_get_listener_weight(index:Int):Float return 0.0;
    public static function sys_set_listener_weight(index:Int, weight:Float):Int return ERR_UNSUPPORTED;
    public static function sys_load_bank_file(path:String, flags:Int):Int
        return testSyntheticHandles ? ++testNextHandle : 0;
    public static function sys_unload_all():Int return ERR_UNSUPPORTED;
    public static function sys_flush_commands():Int return ERR_UNSUPPORTED;
    public static function sys_flush_sample_loading():Int return ERR_UNSUPPORTED;
    public static function sys_get_cpu_usage():Int return ERR_UNSUPPORTED;
    public static function sys_get_buffer_usage():Int return ERR_UNSUPPORTED;
    public static function sys_reset_buffer_usage():Int return ERR_UNSUPPORTED;
    public static function sys_get_memory_usage():Int return ERR_UNSUPPORTED;
    // Records the last init call so the runtime tests can see which
    // settings reach the native surface. Null until init runs.
    public static var testLastInit:Null<{numChannels:Int, sampleRate:Int, speakerMode:Int, studioFlags:Int,
        dspBufferLength:Int, dspNumBuffers:Int, softwareChannels:Int, streamBufferSize:Int, initFlags:Int,
        maxMPEGCodecs:Int, maxVorbisCodecs:Int, maxFADPCMCodecs:Int, vol0VirtualVol:Float, defaultDecodeBufferSize:Int,
        profilePort:Int, geometryMaxFadeTime:Int, distanceFilterCenterFreq:Float, randomSeed:Int, commandQueueSize:Int,
        handleInitialSize:Int, studioUpdatePeriod:Int, idleSampleDataPoolSize:Int, streamingScheduleDelay:Int, encryptionKey:String}> = null;
    /** Every pre-create call the runtime made before sys_init_ex, in order, for the unit tests. */
    public static var testPreInitCalls:Array<String> = [];
    public static function sys_init_ex(numChannels:Int, sampleRate:Int, speakerMode:Int, studioFlags:Int, dspBufferLength:Int, dspNumBuffers:Int, softwareChannels:Int, streamBufferSize:Int, initFlags:Int, maxMPEGCodecs:Int, maxVorbisCodecs:Int, maxFADPCMCodecs:Int, vol0VirtualVol:Float, defaultDecodeBufferSize:Int, profilePort:Int, geometryMaxFadeTime:Int, distanceFilterCenterFreq:Float, randomSeed:Int, commandQueueSize:Int, handleInitialSize:Int, studioUpdatePeriod:Int, idleSampleDataPoolSize:Int, streamingScheduleDelay:Int, encryptionKey:String):Int {
        testLastInit = {numChannels: numChannels, sampleRate: sampleRate, speakerMode: speakerMode, studioFlags: studioFlags,
            dspBufferLength: dspBufferLength, dspNumBuffers: dspNumBuffers, softwareChannels: softwareChannels,
            streamBufferSize: streamBufferSize, initFlags: initFlags,
            maxMPEGCodecs: maxMPEGCodecs, maxVorbisCodecs: maxVorbisCodecs, maxFADPCMCodecs: maxFADPCMCodecs,
            vol0VirtualVol: vol0VirtualVol, defaultDecodeBufferSize: defaultDecodeBufferSize, profilePort: profilePort,
            geometryMaxFadeTime: geometryMaxFadeTime, distanceFilterCenterFreq: distanceFilterCenterFreq, randomSeed: randomSeed,
            commandQueueSize: commandQueueSize, handleInitialSize: handleInitialSize, studioUpdatePeriod: studioUpdatePeriod,
            idleSampleDataPoolSize: idleSampleDataPoolSize, streamingScheduleDelay: streamingScheduleDelay, encryptionKey: encryptionKey};
        return ERR_UNSUPPORTED;
    }
    public static function sys_set_debug_level(level:Int):Int return ERR_UNSUPPORTED;
    public static function sys_load_bank_async(path:String):Int
        return testSyntheticHandles ? ++testNextHandle : 0;
    public static function sys_is_initialized():Bool return testInitialized;
    public static var testUpdateCalls:Int = 0;
    public static function sys_update():Void testUpdateCalls++;
    public static function sys_set_auto_update(enabled:Bool):Void {}

    // Bus
    public static function bus_is_valid(handle:Int):Bool return false;
    public static function bus_get_id(handle:Int):String return "";
    public static function bus_get_path(handle:Int):String return "";
    public static function bus_get_volume(handle:Int):Float return 0.0;
    public static function bus_get_final_volume(handle:Int):Float return 0.0;
    public static function bus_set_volume(handle:Int, volume:Float):Int return ERR_UNSUPPORTED;
    public static function bus_get_paused(handle:Int):Bool return false;
    public static function bus_set_paused(handle:Int, paused:Bool):Int return ERR_UNSUPPORTED;
    public static function bus_get_mute(handle:Int):Bool return false;
    public static function bus_set_mute(handle:Int, mute:Bool):Int return ERR_UNSUPPORTED;
    public static function bus_stop_all_events(handle:Int, stopMode:Int):Int return ERR_UNSUPPORTED;
    public static function bus_get_cpu_usage(handle:Int):Int return ERR_UNSUPPORTED;
    public static function bus_get_memory_usage(handle:Int):Int return ERR_UNSUPPORTED;

    // VCA
    public static function vca_is_valid(handle:Int):Bool return false;
    public static function vca_get_id(handle:Int):String return "";
    public static function vca_get_path(handle:Int):String return "";
    public static function vca_get_volume(handle:Int):Float return 0.0;
    public static function vca_get_final_volume(handle:Int):Float return 0.0;
    public static function vca_set_volume(handle:Int, volume:Float):Int return ERR_UNSUPPORTED;

    // Bank
    public static function bank_is_valid(handle:Int):Bool {
        if (!testSyntheticHandles || handle <= 0) return false;
        return testBankValid != null ? testBankValid : testBankLoadingState == 3;
    }
    public static function bank_get_id(handle:Int):String return "";
    public static function bank_get_path(handle:Int):String return "";
    public static function bank_unload(handle:Int):Int {
        testBankUnloadCalls++;
        return ERR_UNSUPPORTED;
    }
    public static function bank_load_sample_data(handle:Int):Int return ERR_UNSUPPORTED;
    public static function bank_unload_sample_data(handle:Int):Int return ERR_UNSUPPORTED;
    public static function bank_get_loading_state(handle:Int):Int
        return testSyntheticHandles && handle > 0 ? testBankLoadingState : 1;
    public static function bank_get_sample_loading_state(handle:Int):Int return 1;
    public static function bank_get_event_count(handle:Int):Int return 0;
    public static function bank_get_event_list(handle:Int):Int return 0;
    public static function bank_get_bus_count(handle:Int):Int return 0;
    public static function bank_get_bus_list(handle:Int):Int return 0;
    public static function bank_get_vca_count(handle:Int):Int return 0;
    public static function bank_get_vca_list(handle:Int):Int return 0;
    public static function bank_get_string_count(handle:Int):Int return 0;
    public static function bank_get_string_info(handle:Int, index:Int):String return "";
    public static function bank_get_string_guid(handle:Int, index:Int):String return "";

    // EventDescription
    public static function evd_is_valid(handle:Int):Bool return false;
    public static function evd_get_id(handle:Int):String return "";
    public static function evd_get_path(handle:Int):String return "";
    public static function evd_get_length(handle:Int):Int return 0;
    public static function evd_get_min_max_distance(handle:Int):Int return ERR_UNSUPPORTED;
    public static function evd_get_sound_size(handle:Int):Float return 0.0;
    public static function evd_is_snapshot(handle:Int):Bool return false;
    public static function evd_is_oneshot(handle:Int):Bool return false;
    public static function evd_is_stream(handle:Int):Bool return false;
    public static function evd_is_3d(handle:Int):Bool return false;
    public static function evd_is_doppler_enabled(handle:Int):Bool return false;
    public static function evd_has_sustain_point(handle:Int):Bool return false;
    public static function evd_create_instance(handle:Int):Int
        return testSyntheticHandles ? ++testNextHandle : 0;
    public static function evd_get_instance_count(handle:Int):Int return 0;
    public static function evd_get_instance_list(handle:Int):Int return 0;
    public static function evd_release_all_instances(handle:Int):Int return ERR_UNSUPPORTED;
    public static function evd_load_sample_data(handle:Int):Int return ERR_UNSUPPORTED;
    public static function evd_unload_sample_data(handle:Int):Int return ERR_UNSUPPORTED;
    public static function evd_get_sample_loading_state(handle:Int):Int return 1;
    public static function evd_get_parameter_description_count(handle:Int):Int return 0;
    public static function evd_get_parameter_description_by_index(handle:Int, index:Int):String return "";
    public static function evd_get_parameter_description_by_name(handle:Int, name:String):String return "";
    public static function evd_get_parameter_label(handle:Int, parameterName:String, labelIndex:Int):String return "";
    public static function evd_get_user_property_count(handle:Int):Int return 0;
    public static function evd_get_user_property_name(handle:Int, index:Int):String return "";
    public static function evd_get_user_property_type(handle:Int, index:Int):Int return 0;
    public static function evd_get_user_property_float(handle:Int, index:Int):Float return 0.0;
    public static function evd_get_user_property_string(handle:Int, index:Int):String return "";

    // EventInstance
    public static function evi_is_valid(handle:Int):Bool
        return testSyntheticHandles && handle > 0 && !testReleasedHandles.contains(handle);
    public static function evi_get_description(handle:Int):Int return 0;
    public static function evi_start(handle:Int):Int {
        testStartCalls++;
        return ERR_UNSUPPORTED;
    }
    public static function evi_stop(handle:Int, stopMode:Int):Int return ERR_UNSUPPORTED;
    public static function evi_key_off(handle:Int):Int return ERR_UNSUPPORTED;
    public static var testReleasedHandles:Array<Int> = [];
    public static function evi_release(handle:Int):Int {
        if (testSyntheticHandles) { testReleasedHandles.push(handle); return 0; }
        return ERR_UNSUPPORTED;
    }
    public static function evi_get_playback_state(handle:Int):Int
        return testPlaybackStateQueue.length > 0 ? testPlaybackStateQueue.shift() : testPlaybackState;
    public static function evi_get_paused(handle:Int):Bool return false;
    public static var testPausedState:Null<Bool> = null;
    public static function evi_set_paused(handle:Int, paused:Bool):Int {
        if (testSyntheticHandles) { testPausedState = paused; return 0; }
        return ERR_UNSUPPORTED;
    }
    public static function evi_get_volume(handle:Int):Float return 0.0;
    public static function evi_get_volume_final(handle:Int):Float return 0.0;
    public static function evi_set_volume(handle:Int, volume:Float):Int return ERR_UNSUPPORTED;
    public static function evi_get_pitch(handle:Int):Float return 0.0;
    public static function evi_get_pitch_final(handle:Int):Float return 0.0;
    public static function evi_set_pitch(handle:Int, pitch:Float):Int return ERR_UNSUPPORTED;
    public static function evi_get_timeline_position(handle:Int):Int return 0;
    public static function evi_set_timeline_position(handle:Int, positionMs:Int):Int return ERR_UNSUPPORTED;
    public static function evi_is_virtual(handle:Int):Bool return false;
    public static function evi_get_min_max_distance(handle:Int):Int return ERR_UNSUPPORTED;
    public static function evi_get_3d_attributes(handle:Int):Int return ERR_UNSUPPORTED;
    public static function evi_set_3d_attributes(handle:Int, px:Float, py:Float, pz:Float, vx:Float, vy:Float, vz:Float, fx:Float, fy:Float, fz:Float, ux:Float, uy:Float, uz:Float):Int return ERR_UNSUPPORTED;
    public static function evi_get_listener_mask(handle:Int):Int return 0;
    public static function evi_set_listener_mask(handle:Int, mask:Int):Int return ERR_UNSUPPORTED;
    public static function evi_get_property(handle:Int, property:Int):Float return 0.0;
    public static function evi_set_property(handle:Int, property:Int, value:Float):Int return ERR_UNSUPPORTED;
    public static function evi_get_reverb_level(handle:Int, index:Int):Float return 0.0;
    public static function evi_set_reverb_level(handle:Int, index:Int, level:Float):Int return ERR_UNSUPPORTED;
    public static function evi_get_param_by_name(handle:Int, name:String):Float return 0.0;
    public static function evi_get_param_by_name_final(handle:Int, name:String):Float return 0.0;
    public static function evi_set_param_by_name(handle:Int, name:String, value:Float, ignoreSeekSpeed:Bool):Int return ERR_UNSUPPORTED;
    public static function evi_set_param_by_name_with_label(handle:Int, name:String, label:String, ignoreSeekSpeed:Bool):Int return ERR_UNSUPPORTED;
    public static function evi_get_param_by_id(handle:Int, id1:Int, id2:Int):Float return 0.0;
    public static function evi_get_param_by_id_final(handle:Int, id1:Int, id2:Int):Float return 0.0;
    public static function evi_set_param_by_id(handle:Int, id1:Int, id2:Int, value:Float, ignoreSeekSpeed:Bool):Int return ERR_UNSUPPORTED;
    public static function evi_set_param_by_id_with_label(handle:Int, id1:Int, id2:Int, label:String, ignoreSeekSpeed:Bool):Int return ERR_UNSUPPORTED;
    public static function evi_get_cpu_usage(handle:Int):Int return ERR_UNSUPPORTED;
    public static function evi_get_memory_usage(handle:Int):Int return ERR_UNSUPPORTED;

    // Programmer sounds
    public static function ps_assign(handle:Int, key:String):Int return ERR_UNSUPPORTED;
    public static var testLastPsSound:Int = -1;
    public static var testLastPsSubsound:Int = -99;
    public static function ps_assign_sound(handle:Int, sound:Int, subsoundIndex:Int):Int {
        testLastPsSound = sound;
        testLastPsSubsound = subsoundIndex;
        return ERR_UNSUPPORTED;
    }
    public static var testLastPsNamed:Array<String> = null;
    public static function ps_assign_named(handle:Int, name:String, key:String):Int {
        testLastPsNamed = [name, key];
        return ERR_UNSUPPORTED;
    }
    public static function ps_clear(handle:Int):Int return ERR_UNSUPPORTED;

    // Core API micro subset
    public static var testLastCreateSoundMode:Int = -1;
    public static var testLastCreateSoundSubsound:Int = -99;
    public static function core_create_sound(path:String, mode:Int, initialSubsound:Int):Int {
        testLastCreateSoundMode = mode;
        testLastCreateSoundSubsound = initialSubsound;
        return 0;
    }
    public static var testLastMemoryLen:Int = -1;
    public static var testLastMemoryMode:Int = -1;
    public static function core_create_sound_memory(data:haxe.io.Bytes, len:Int, mode:Int):Int {
        testLastMemoryLen = len;
        testLastMemoryMode = mode;
        return 0;
    }
    public static var testLastExInfoInts:Array<Int> = null;
    public static var testLastExInfoStrings:Array<String> = null;
    public static function core_create_sound_ex(path:String, mode:Int, dls:String, key:String, guid:String):Int {
        testLastCreateSoundMode = mode;
        testLastExInfoInts = [for (i in 0...20 + Scratch.readI(19)) Scratch.readI(i)];
        testLastExInfoStrings = [dls, key, guid];
        return 0;
    }
    public static function core_create_sound_memory_ex(data:haxe.io.Bytes, len:Int, mode:Int, dls:String, key:String, guid:String):Int {
        testLastMemoryLen = len;
        testLastMemoryMode = mode;
        testLastExInfoInts = [for (i in 0...20 + Scratch.readI(19)) Scratch.readI(i)];
        testLastExInfoStrings = [dls, key, guid];
        return 0;
    }
    public static var testLastPlayGroup:Int = -1;
    public static function core_release_sound(handle:Int):Int return ERR_UNSUPPORTED;
    public static function core_get_sound_length(handle:Int, unit:Int):Int return -1;

    // Core PCM streams
    public static function core_pcm_create(sampleRate:Int, channels:Int, ringBytes:Int):Int return 0;
    public static var testPcmSpace:Int = 0;
    public static var testLastPcmWriteLen:Int = -1;
    public static function core_pcm_write(handle:Int, data:haxe.io.Bytes, len:Int):Int {
        testLastPcmWriteLen = len;
        return 0;
    }
    public static function core_pcm_space(handle:Int):Int return testPcmSpace;
    public static function core_pcm_underruns(handle:Int):Int return 0;
    public static function core_pcm_play(handle:Int, group:Int, startPaused:Bool):Int {
        testLastPlayGroup = group;
        return 0;
    }
    public static function core_pcm_release(handle:Int):Int return ERR_UNSUPPORTED;

    // Core channels
    public static function chan_set_volume(handle:Int, volume:Float):Int return ERR_UNSUPPORTED;
    public static function chan_get_volume(handle:Int):Float return 0.0;
    public static function chan_set_pitch(handle:Int, pitch:Float):Int return ERR_UNSUPPORTED;
    public static function chan_get_pitch(handle:Int):Float return 0.0;
    public static function chan_set_paused(handle:Int, paused:Bool):Int return ERR_UNSUPPORTED;
    public static function chan_get_paused(handle:Int):Bool return false;
    public static function chan_is_playing(handle:Int):Bool return false;
    public static function chan_stop(handle:Int):Int return ERR_UNSUPPORTED;

    // Core DSP effects
    public static function dsp_create_by_type(type:Int):Int return 0;
    public static function dsp_release(handle:Int):Int return ERR_UNSUPPORTED;
    public static function dsp_set_param_float(handle:Int, index:Int, value:Float):Int return ERR_UNSUPPORTED;
    public static function dsp_get_param_float(handle:Int, index:Int):Float return 0.0;
    public static function dsp_set_param_int(handle:Int, index:Int, value:Int):Int return ERR_UNSUPPORTED;
    public static function dsp_get_param_int(handle:Int, index:Int):Int return 0;
    public static function dsp_set_param_bool(handle:Int, index:Int, value:Bool):Int return ERR_UNSUPPORTED;
    public static function dsp_get_param_bool(handle:Int, index:Int):Bool return false;
    public static function dsp_get_num_params(handle:Int):Int return 0;
    public static function dsp_get_type(handle:Int):Int return 0;
    public static function dsp_set_bypass(handle:Int, bypass:Bool):Int return ERR_UNSUPPORTED;
    public static function dsp_get_bypass(handle:Int):Bool return false;
    public static function dsp_set_wet_dry_mix(handle:Int, prewet:Float, postwet:Float, dry:Float):Int return ERR_UNSUPPORTED;
    public static function dsp_set_active(handle:Int, active:Bool):Int return ERR_UNSUPPORTED;
    public static function dsp_reset(handle:Int):Int return ERR_UNSUPPORTED;
    public static function dsp_set_metering_enabled(handle:Int, input:Bool, output:Bool):Int return ERR_UNSUPPORTED;
    public static function dsp_get_metering(handle:Int):Int return 0;
    public static function dsp_fft_get_spectrum(handle:Int, maxBins:Int):Int return 0;

    // Core channel groups
    public static function cg_get_master():Int return 0;
    public static function cg_create(name:String):Int return 0;
    public static function cg_release(handle:Int):Int return ERR_UNSUPPORTED;
    public static function cg_set_volume(handle:Int, volume:Float):Int return ERR_UNSUPPORTED;
    public static function cg_get_volume(handle:Int):Float return 0.0;
    public static function cg_set_pitch(handle:Int, pitch:Float):Int return ERR_UNSUPPORTED;
    public static function cg_get_pitch(handle:Int):Float return 0.0;
    public static function cg_set_mute(handle:Int, mute:Bool):Int return ERR_UNSUPPORTED;
    public static function cg_get_mute(handle:Int):Bool return false;
    public static function cg_set_paused(handle:Int, paused:Bool):Int return ERR_UNSUPPORTED;
    public static function cg_get_paused(handle:Int):Bool return false;
    public static function cg_add_dsp(handle:Int, index:Int, dspHandle:Int):Int return ERR_UNSUPPORTED;
    public static function cg_remove_dsp(handle:Int, dspHandle:Int):Int return ERR_UNSUPPORTED;
    public static function cg_stop(handle:Int):Int return ERR_UNSUPPORTED;

    // Core channel routing and effects
    public static function chan_set_pan(handle:Int, pan:Float):Int return ERR_UNSUPPORTED;
    public static function chan_set_frequency(handle:Int, frequency:Float):Int return ERR_UNSUPPORTED;
    public static function chan_get_frequency(handle:Int):Float return 0.0;
    public static function chan_set_loop_count(handle:Int, loopCount:Int):Int return ERR_UNSUPPORTED;
    public static function chan_get_position(handle:Int, unit:Int):Int return -1;
    public static function chan_set_position(handle:Int, position:Int, unit:Int):Int return ERR_UNSUPPORTED;
    public static function chan_set_channel_group(handle:Int, groupHandle:Int):Int return ERR_UNSUPPORTED;
    public static function chan_add_dsp(handle:Int, index:Int, dspHandle:Int):Int return ERR_UNSUPPORTED;
    public static function chan_remove_dsp(handle:Int, dspHandle:Int):Int return ERR_UNSUPPORTED;
    public static function chan_set_3d_attributes(handle:Int, posX:Float, posY:Float, posZ:Float, velX:Float, velY:Float, velZ:Float):Int return ERR_UNSUPPORTED;
    public static function chan_set_3d_min_max(handle:Int, minDist:Float, maxDist:Float):Int return ERR_UNSUPPORTED;
    public static function chan_set_reverb_wet(handle:Int, instance:Int, wet:Float):Int return ERR_UNSUPPORTED;

    // Studio bus to core group bridge
    public static function bus_lock_channel_group(handle:Int):Int return ERR_UNSUPPORTED;
    public static function bus_unlock_channel_group(handle:Int):Int return ERR_UNSUPPORTED;
    public static function bus_get_channel_group(handle:Int):Int return 0;

    // Core system extras
    public static function sys_play_dsp(dspHandle:Int, group:Int, startPaused:Bool):Int {
        testLastPlayGroup = group;
        return 0;
    }
    public static function sys_set_reverb_properties(instance:Int):Int return ERR_UNSUPPORTED;
    public static function sys_get_reverb_properties(instance:Int):Int return ERR_UNSUPPORTED;
    public static function core_pcm_create_3d(sampleRate:Int, channels:Int, ringBytes:Int):Int return 0;

    // Core parity tail (slice 3)
    public static function dsp_add_input(handle:Int, inputHandle:Int, type:Int):Int return 0;
    public static function dsp_disconnect_from(handle:Int, inputHandle:Int, connHandle:Int):Int return ERR_UNSUPPORTED;
    public static function dsp_disconnect_all(handle:Int, inputs:Bool, outputs:Bool):Int return ERR_UNSUPPORTED;
    public static function dsp_get_num_inputs(handle:Int):Int return 0;
    public static function dsp_get_num_outputs(handle:Int):Int return 0;
    public static function dsp_get_input_dsp(handle:Int, index:Int):Int return 0;
    public static function dsp_get_input_connection(handle:Int, index:Int):Int return 0;
    public static function dspconn_set_mix(handle:Int, mix:Float):Int return ERR_UNSUPPORTED;
    public static function dspconn_get_mix(handle:Int):Float return 0.0;
    public static function dspconn_get_type(handle:Int):Int return 0;
    public static function cg_add_group(handle:Int, childHandle:Int, propagateDspClock:Bool):Int return 0;
    public static function cg_get_num_groups(handle:Int):Int return 0;
    public static function cg_get_group(handle:Int, index:Int):Int return 0;
    public static function cg_get_parent_group(handle:Int):Int return 0;
    public static function chan_set_mute(handle:Int, mute:Bool):Int return ERR_UNSUPPORTED;
    public static function chan_get_mute(handle:Int):Bool return false;
    public static function chan_set_low_pass_gain(handle:Int, gain:Float):Int return ERR_UNSUPPORTED;
    public static function chan_set_mode(handle:Int, mode:Int):Int return ERR_UNSUPPORTED;
    public static function chan_set_3d_cone_settings(handle:Int, insideAngle:Float, outsideAngle:Float, outsideVolume:Float):Int return ERR_UNSUPPORTED;
    public static function chan_set_3d_cone_orientation(handle:Int, x:Float, y:Float, z:Float):Int return ERR_UNSUPPORTED;
    public static function chan_set_3d_occlusion(handle:Int, direct:Float, reverb:Float):Int return ERR_UNSUPPORTED;
    public static function chan_get_3d_occlusion(handle:Int):Int return ERR_UNSUPPORTED;
    public static function chan_set_3d_spread(handle:Int, angle:Float):Int return ERR_UNSUPPORTED;
    public static function chan_set_3d_level(handle:Int, level:Float):Int return ERR_UNSUPPORTED;
    public static function chan_set_3d_doppler_level(handle:Int, level:Float):Int return ERR_UNSUPPORTED;
    public static function chan_set_mix_matrix(handle:Int, outChannels:Int, inChannels:Int, inChannelHop:Int):Int return ERR_UNSUPPORTED;
    public static function chan_get_dsp_clock(handle:Int):Int return ERR_UNSUPPORTED;
    public static function chan_set_delay(handle:Int, startClock:Float, endClock:Float, stopChannels:Bool):Int return ERR_UNSUPPORTED;
    public static function chan_add_fade_point(handle:Int, clock:Float, volume:Float):Int return ERR_UNSUPPORTED;
    public static function chan_set_fade_point_ramp(handle:Int, clock:Float, volume:Float):Int return ERR_UNSUPPORTED;
    public static function chan_remove_fade_points(handle:Int, startClock:Float, endClock:Float):Int return ERR_UNSUPPORTED;
    public static function cg_get_dsp_clock(handle:Int):Int return ERR_UNSUPPORTED;
    public static function cg_set_delay(handle:Int, startClock:Float, endClock:Float, stopChannels:Bool):Int return ERR_UNSUPPORTED;
    public static function cg_add_fade_point(handle:Int, clock:Float, volume:Float):Int return ERR_UNSUPPORTED;
    public static function cg_set_fade_point_ramp(handle:Int, clock:Float, volume:Float):Int return ERR_UNSUPPORTED;
    public static function cg_remove_fade_points(handle:Int, startClock:Float, endClock:Float):Int return ERR_UNSUPPORTED;
    public static function sys_create_reverb3d():Int return 0;
    public static function r3d_release(handle:Int):Int return ERR_UNSUPPORTED;
    public static function r3d_set_3d_attributes(handle:Int, x:Float, y:Float, z:Float, minDist:Float, maxDist:Float):Int return ERR_UNSUPPORTED;
    public static function r3d_set_properties(handle:Int):Int return ERR_UNSUPPORTED;
    public static function r3d_get_properties(handle:Int):Int return ERR_UNSUPPORTED;
    public static function r3d_set_active(handle:Int, active:Bool):Int return ERR_UNSUPPORTED;
    public static var testPcmCreateLen:Int = -999;
    public static function core_create_sound_pcm(data:haxe.io.Bytes, len:Int, sampleRate:Int, channels:Int):Int {
        testPcmCreateLen = len;
        return 0;
    }
    public static function core_play_sound(handle:Int, group:Int, startPaused:Bool):Int {
        testLastPlayGroup = group;
        return 0;
    }
    public static function sound_set_defaults(handle:Int, frequency:Float, priority:Int):Int return ERR_UNSUPPORTED;
    public static function sound_get_defaults(handle:Int):Int return ERR_UNSUPPORTED;
    public static var testLastLoopUnits:Array<Int> = null;
    public static function sound_set_loop_points(handle:Int, start:Int, startType:Int, end:Int, endType:Int):Int {
        testLastLoopUnits = [startType, endType];
        return ERR_UNSUPPORTED;
    }
    public static function sound_get_loop_points(handle:Int, startType:Int, endType:Int):Int {
        testLastLoopUnits = [startType, endType];
        return ERR_UNSUPPORTED;
    }
    public static function sound_set_mode(handle:Int, mode:Int):Int return ERR_UNSUPPORTED;
    public static function sound_get_mode(handle:Int):Int return 0;
    public static function sound_get_format(handle:Int):Int return ERR_UNSUPPORTED;
    public static function sound_get_open_state(handle:Int):Int return -1;
    public static function sound_get_open_state_info(handle:Int):Int return ERR_UNSUPPORTED;
    public static function sys_get_channels_playing():Int return ERR_UNSUPPORTED;
    public static function sys_mixer_suspend():Int return ERR_UNSUPPORTED;
    public static function sys_mixer_resume():Int return ERR_UNSUPPORTED;
    public static function sys_get_software_format():Int return ERR_UNSUPPORTED;
    public static function dsp_get_cpu_usage(handle:Int):Int return ERR_UNSUPPORTED;

    // Channel callbacks and sync points
    public static function chan_set_callback(handle:Int, enabled:Bool):Int return ERR_UNSUPPORTED;
    public static function sys_set_callback_mask(mask:Int):Int return ERR_UNSUPPORTED;
    public static function sys_set_studio_callback_mask(mask:Int):Int return ERR_UNSUPPORTED;
    public static function sound_add_sync_point(handle:Int, offset:Int, unit:Int, name:String):Int return -1;
    public static function sound_delete_sync_point(handle:Int, index:Int):Int return ERR_UNSUPPORTED;
    public static function sound_get_num_sync_points(handle:Int):Int return 0;
    public static function sound_get_sync_point_name(handle:Int, index:Int):String return "";
    public static function sound_get_sync_point_offset(handle:Int, index:Int, unit:Int):Int return -1;

    // Sound groups
    public static function sys_create_sound_group(name:String):Int return 0;
    public static function sys_get_master_sound_group():Int return 0;
    public static function sg_release(handle:Int):Int return ERR_UNSUPPORTED;
    public static function sg_set_max_audible(handle:Int, maxAudible:Int):Int return ERR_UNSUPPORTED;
    public static function sg_get_max_audible(handle:Int):Int return 0;
    public static function sg_set_max_audible_behavior(handle:Int, behavior:Int):Int return ERR_UNSUPPORTED;
    public static function sg_get_max_audible_behavior(handle:Int):Int return 0;
    public static function sg_set_mute_fade_speed(handle:Int, speed:Float):Int return ERR_UNSUPPORTED;
    public static function sg_get_num_sounds(handle:Int):Int return 0;
    public static function sg_stop(handle:Int):Int return ERR_UNSUPPORTED;
    public static function sound_set_sound_group(handle:Int, groupHandle:Int):Int return ERR_UNSUPPORTED;

    // System 3D settings and drivers
    public static function sys_set_3d_settings(doppler:Float, distanceFactor:Float, rolloffScale:Float):Int return ERR_UNSUPPORTED;
    public static function sys_get_3d_settings():Int return ERR_UNSUPPORTED;
    public static function sys_get_num_drivers():Int return 0;
    public static function sys_get_driver_name(id:Int):String return "";

    // Getter symmetry for the routing and spatial setters
    public static function chan_get_loop_count(handle:Int):Int return 0;
    public static function chan_get_low_pass_gain(handle:Int):Float return 0.0;
    public static function chan_get_mode(handle:Int):Int return 0;
    public static function chan_get_3d_cone_settings(handle:Int):Int return ERR_UNSUPPORTED;
    public static function chan_get_3d_spread(handle:Int):Float return 0.0;
    public static function chan_get_3d_level(handle:Int):Float return 0.0;
    public static function chan_get_3d_doppler_level(handle:Int):Float return 0.0;
    public static function chan_get_3d_min_max(handle:Int):Int return ERR_UNSUPPORTED;
    public static function chan_get_3d_attributes(handle:Int):Int return ERR_UNSUPPORTED;
    public static function chan_get_delay(handle:Int):Int return ERR_UNSUPPORTED;
    public static function dsp_get_wet_dry_mix(handle:Int):Int return ERR_UNSUPPORTED;
    public static function dsp_get_active(handle:Int):Bool return false;
    public static function dsp_get_metering_enabled(handle:Int):Int return ERR_UNSUPPORTED;

    // Bank loading from memory
    public static function sys_load_bank_memory(data:haxe.io.Bytes, len:Int, flags:Int):Int return 0;

    // Event instance core bridge
    public static function evi_get_channel_group(handle:Int):Int return 0;

    // Command capture and replay
    public static function sys_start_command_capture(path:String, flags:Int):Int return ERR_UNSUPPORTED;
    public static function sys_stop_command_capture():Int return ERR_UNSUPPORTED;
    public static function sys_load_command_replay(path:String, flags:Int):Int return 0;
    public static function replay_release(handle:Int):Int return ERR_UNSUPPORTED;
    public static function replay_is_valid(handle:Int):Bool return false;
    public static function replay_start(handle:Int):Int return ERR_UNSUPPORTED;
    public static function replay_stop(handle:Int):Int return ERR_UNSUPPORTED;
    public static function replay_set_paused(handle:Int, paused:Bool):Int return ERR_UNSUPPORTED;
    public static function replay_get_paused(handle:Int):Bool return false;
    public static function replay_seek_to_time(handle:Int, seconds:Float):Int return ERR_UNSUPPORTED;
    public static function replay_get_length(handle:Int):Float return 0.0;

    // Channel priority, virtualization, and remaining getters
    public static function chan_set_priority(handle:Int, priority:Int):Int return ERR_UNSUPPORTED;
    public static function chan_get_priority(handle:Int):Int return 0;
    public static function chan_is_virtual(handle:Int):Bool return false;
    public static function chan_get_audibility(handle:Int):Float return 0.0;
    public static function chan_set_volume_ramp(handle:Int, ramp:Bool):Int return ERR_UNSUPPORTED;
    public static function chan_get_volume_ramp(handle:Int):Bool return false;
    public static function chan_get_current_sound(handle:Int):Int return 0;
    public static function chan_set_loop_points(handle:Int, start:Int, startType:Int, end:Int, endType:Int):Int {
        testLastLoopUnits = [startType, endType];
        return ERR_UNSUPPORTED;
    }
    public static function chan_get_loop_points(handle:Int, startType:Int, endType:Int):Int {
        testLastLoopUnits = [startType, endType];
        return ERR_UNSUPPORTED;
    }
    public static function chan_get_reverb_wet(handle:Int, instance:Int):Float return 0.0;
    public static function chan_get_index(handle:Int):Int return -1;
    public static function chan_get_3d_cone_orientation(handle:Int):Int return ERR_UNSUPPORTED;
    public static function chan_get_num_dsps(handle:Int):Int return 0;
    public static function chan_get_dsp(handle:Int, index:Int):Int return 0;

    // Sound name, group getter, and loop count
    public static function sound_get_name(handle:Int):String return "";
    public static function sound_get_sound_group(handle:Int):Int return 0;
    public static function sound_get_loop_count(handle:Int):Int return 0;
    public static function sound_set_loop_count(handle:Int, loopCount:Int):Int return ERR_UNSUPPORTED;

    // Sound group volume and counters
    public static function sg_set_volume(handle:Int, volume:Float):Int return ERR_UNSUPPORTED;
    public static function sg_get_volume(handle:Int):Float return 0.0;
    public static function sg_get_num_playing(handle:Int):Int return 0;
    public static function sg_get_mute_fade_speed(handle:Int):Float return 0.0;

    // Output device selection
    public static function sys_set_driver(id:Int):Int return ERR_UNSUPPORTED;
    public static function sys_get_driver():Int return 0;

    // DSP data params, info, and output traversal
    public static function dsp_set_param_data(handle:Int, index:Int, data:haxe.io.Bytes, len:Int):Int return ERR_UNSUPPORTED;
    public static function dsp_get_idle(handle:Int):Bool return false;
    public static function dsp_get_info_name(handle:Int):String return "";
    public static function dsp_get_output_dsp(handle:Int, index:Int):Int return 0;
    public static function dsp_get_output_connection(handle:Int, index:Int):Int return 0;
    public static function dspconn_get_input_dsp(handle:Int):Int return 0;
    public static function dspconn_get_output_dsp(handle:Int):Int return 0;

    // Reverb3D getters
    public static function r3d_get_active(handle:Int):Bool return false;
    public static function r3d_get_3d_attributes(handle:Int):Int return ERR_UNSUPPORTED;

    // Channel group spatial mirror and remaining control surface
    public static function cg_set_pan(handle:Int, pan:Float):Int return ERR_UNSUPPORTED;
    public static function cg_set_low_pass_gain(handle:Int, gain:Float):Int return ERR_UNSUPPORTED;
    public static function cg_set_mode(handle:Int, mode:Int):Int return ERR_UNSUPPORTED;
    public static function cg_get_mode(handle:Int):Int return 0;
    public static function cg_set_3d_attributes(handle:Int, posX:Float, posY:Float, posZ:Float, velX:Float, velY:Float, velZ:Float):Int return ERR_UNSUPPORTED;
    public static function cg_get_3d_attributes(handle:Int):Int return ERR_UNSUPPORTED;
    public static function cg_set_3d_min_max(handle:Int, minDist:Float, maxDist:Float):Int return ERR_UNSUPPORTED;
    public static function cg_get_3d_min_max(handle:Int):Int return ERR_UNSUPPORTED;
    public static function cg_set_3d_occlusion(handle:Int, direct:Float, reverb:Float):Int return ERR_UNSUPPORTED;
    public static function cg_get_3d_occlusion(handle:Int):Int return ERR_UNSUPPORTED;
    public static function cg_get_delay(handle:Int):Int return ERR_UNSUPPORTED;
    public static function cg_get_low_pass_gain(handle:Int):Float return 0.0;
    public static function cg_is_playing(handle:Int):Bool return false;
    public static function cg_set_callback(handle:Int, enabled:Bool):Int return ERR_UNSUPPORTED;
    public static function cg_set_3d_level(handle:Int, level:Float):Int return ERR_UNSUPPORTED;
    public static function cg_get_3d_level(handle:Int):Float return 0.0;
    public static function cg_set_3d_spread(handle:Int, angle:Float):Int return ERR_UNSUPPORTED;
    public static function cg_get_3d_spread(handle:Int):Float return 0.0;
    public static function cg_set_3d_doppler_level(handle:Int, level:Float):Int return ERR_UNSUPPORTED;
    public static function cg_get_3d_doppler_level(handle:Int):Float return 0.0;
    public static function cg_set_3d_cone_settings(handle:Int, insideAngle:Float, outsideAngle:Float, outsideVolume:Float):Int return ERR_UNSUPPORTED;
    public static function cg_get_3d_cone_settings(handle:Int):Int return ERR_UNSUPPORTED;
    public static function cg_set_3d_cone_orientation(handle:Int, x:Float, y:Float, z:Float):Int return ERR_UNSUPPORTED;
    public static function cg_get_3d_cone_orientation(handle:Int):Int return ERR_UNSUPPORTED;
    public static function cg_set_reverb_wet(handle:Int, instance:Int, wet:Float):Int return ERR_UNSUPPORTED;
    public static function cg_get_reverb_wet(handle:Int, instance:Int):Float return 0.0;
    public static function cg_set_mix_matrix(handle:Int, outChannels:Int, inChannels:Int, inChannelHop:Int):Int return ERR_UNSUPPORTED;
    public static function cg_set_volume_ramp(handle:Int, ramp:Bool):Int return ERR_UNSUPPORTED;
    public static function cg_get_volume_ramp(handle:Int):Bool return false;
    public static function cg_get_audibility(handle:Int):Float return 0.0;
    public static function cg_get_name(handle:Int):String return "";
    public static function cg_get_num_channels(handle:Int):Int return 0;
    public static function cg_get_channel(handle:Int, index:Int):Int return 0;

    // Callbacks
    public static function evi_set_callback_mask(handle:Int, mask:Int):Int {
        testLastCallbackMaskHandle = handle;
        testLastCallbackMask = mask;
        return testCallbackMaskResult;
    }
    public static function cb_next():Bool return false;
    public static function cb_handle():Int return 0;
    public static function cb_type():Int return 0;
    public static function cb_int(index:Int):Int return 0;
    public static function cb_float():Float return 0.0;
    public static function cb_string():String return "";
    public static function cb_string2():String return "";
    public static function cb_take_overflow():Bool return false;

    // Distance filter, version, sound data, and recording
    public static function chan_set_3d_distance_filter(handle:Int, custom:Bool, customLevel:Float, centerFreq:Float):Int return ERR_UNSUPPORTED;
    public static function chan_get_3d_distance_filter(handle:Int):Int return ERR_UNSUPPORTED;
    public static function cg_set_3d_distance_filter(handle:Int, custom:Bool, customLevel:Float, centerFreq:Float):Int return ERR_UNSUPPORTED;
    public static function cg_get_3d_distance_filter(handle:Int):Int return ERR_UNSUPPORTED;
    public static function sys_get_version():String return "";
    public static var testReadDataLen:Int = -999;
    public static function core_sound_read_data(handle:Int, data:haxe.io.Bytes, len:Int):Int {
        testReadDataLen = len;
        return -ERR_UNSUPPORTED;
    }
    public static function core_sound_seek_data(handle:Int, pcm:Int):Int return ERR_UNSUPPORTED;
    public static function sys_get_record_num_drivers():Int return -1;
    public static function sys_get_record_driver_info(id:Int):String return "";
    public static function sys_get_record_driver_guid(id:Int):String return "";
    public static function core_create_record_sound(sampleRate:Int, channels:Int, seconds:Int):Int return 0;
    public static function sys_record_start(id:Int, soundHandle:Int, loop:Bool):Int return ERR_UNSUPPORTED;
    public static function sys_record_stop(id:Int):Int return ERR_UNSUPPORTED;
    public static function sys_is_recording(id:Int):Bool return false;
    public static function sys_get_record_position(id:Int):Int return -1;

    // Custom 3D rolloff and geometry
    public static function chan_set_3d_custom_rolloff(handle:Int, data:haxe.io.Bytes, count:Int):Int return ERR_UNSUPPORTED;
    public static function chan_get_3d_custom_rolloff(handle:Int):Int return -1;
    public static function cg_set_3d_custom_rolloff(handle:Int, data:haxe.io.Bytes, count:Int):Int return ERR_UNSUPPORTED;
    public static function cg_get_3d_custom_rolloff(handle:Int):Int return -1;
    public static function core_sound_set_3d_custom_rolloff(handle:Int, data:haxe.io.Bytes, count:Int):Int return ERR_UNSUPPORTED;
    public static function core_sound_get_3d_custom_rolloff(handle:Int):Int return -1;
    public static function sys_create_geometry(maxPolygons:Int, maxVertices:Int):Int return 0;
    public static function sys_set_geometry_settings(maxWorldSize:Float):Int return ERR_UNSUPPORTED;
    public static function sys_get_geometry_settings():Float return 0;
    public static function sys_get_geometry_occlusion(lx:Float, ly:Float, lz:Float, sx:Float, sy:Float, sz:Float):Int return ERR_UNSUPPORTED;
    public static function sys_load_geometry(data:haxe.io.Bytes, len:Int):Int return 0;
    public static function geo_release(handle:Int):Int return ERR_UNSUPPORTED;
    public static function geo_add_polygon(handle:Int, direct:Float, reverb:Float, doubleSided:Bool, vertices:haxe.io.Bytes, count:Int):Int return -1;
    public static function geo_get_num_polygons(handle:Int):Int return -1;
    public static function geo_get_max_polygons(handle:Int):Int return ERR_UNSUPPORTED;
    public static function geo_get_polygon_num_vertices(handle:Int, index:Int):Int return -1;
    public static function geo_set_polygon_vertex(handle:Int, index:Int, vertexIndex:Int, x:Float, y:Float, z:Float):Int return ERR_UNSUPPORTED;
    public static function geo_get_polygon_vertex(handle:Int, index:Int, vertexIndex:Int):Int return ERR_UNSUPPORTED;
    public static function geo_set_polygon_attributes(handle:Int, index:Int, direct:Float, reverb:Float, doubleSided:Bool):Int return ERR_UNSUPPORTED;
    public static function geo_get_polygon_attributes(handle:Int, index:Int):Int return ERR_UNSUPPORTED;
    public static function geo_set_active(handle:Int, active:Bool):Int return ERR_UNSUPPORTED;
    public static function geo_get_active(handle:Int):Bool return false;
    public static function geo_set_rotation(handle:Int, fx:Float, fy:Float, fz:Float, ux:Float, uy:Float, uz:Float):Int return ERR_UNSUPPORTED;
    public static function geo_get_rotation(handle:Int):Int return ERR_UNSUPPORTED;
    public static function geo_set_position(handle:Int, x:Float, y:Float, z:Float):Int return ERR_UNSUPPORTED;
    public static function geo_get_position(handle:Int):Int return ERR_UNSUPPORTED;
    public static function geo_set_scale(handle:Int, x:Float, y:Float, z:Float):Int return ERR_UNSUPPORTED;
    public static function geo_get_scale(handle:Int):Int return ERR_UNSUPPORTED;
    public static function geo_save(handle:Int, data:haxe.io.Bytes, len:Int):Int return -1;

    // Completeness tail: getters and setters on objects the library already wraps
    public static function core_sound_set_3d_cone_settings(handle:Int, inside:Float, outside:Float, outsideVolume:Float):Int return ERR_UNSUPPORTED;
    public static function core_sound_get_3d_cone_settings(handle:Int):Int return ERR_UNSUPPORTED;
    public static function core_sound_set_3d_min_max(handle:Int, minDistance:Float, maxDistance:Float):Int return ERR_UNSUPPORTED;
    public static function core_sound_get_3d_min_max(handle:Int):Int return ERR_UNSUPPORTED;
    public static function chan_set_dsp_index(handle:Int, dsp:Int, index:Int):Int return ERR_UNSUPPORTED;
    public static function chan_get_dsp_index(handle:Int, dsp:Int):Int return -1;
    public static function chan_get_fade_points(handle:Int):Int return 0;
    public static function chan_get_mix_matrix(handle:Int, inChannelHop:Int):Int return 0;
    public static function chan_get_channel_group(handle:Int):Int return 0;
    public static function cg_set_dsp_index(handle:Int, dsp:Int, index:Int):Int return ERR_UNSUPPORTED;
    public static function cg_get_dsp_index(handle:Int, dsp:Int):Int return -1;
    public static function cg_get_fade_points(handle:Int):Int return 0;
    public static function cg_get_mix_matrix(handle:Int, inChannelHop:Int):Int return 0;
    public static function sg_get_name(handle:Int):String return "";
    public static function sg_get_sound(handle:Int, index:Int):Int return 0;
    public static function sys_get_channel(index:Int):Int return 0;
    public static function sys_get_output():Int return -1;
    public static function sys_get_speaker_mode_channels(mode:Int):Int return 0;
    public static function sys_get_default_mix_matrix(sourceMode:Int, targetMode:Int, hop:Int):Int return 0;
    public static function dsp_get_parameter_info(handle:Int, index:Int):String return "";
    public static function dsp_get_info(handle:Int):String return "";
    public static function dsp_get_param_data(handle:Int, index:Int, out:haxe.io.Bytes, cap:Int):Int return -1;
    public static function dsp_set_param_3d_attributes(handle:Int, index:Int):Int return ERR_UNSUPPORTED;
    public static function dsp_set_param_3d_attributes_multi(handle:Int, index:Int, numListeners:Int):Int return ERR_UNSUPPORTED;
    public static function dsp_get_metering_info(handle:Int, input:Bool):Int return 0;
    public static function dsp_fft_get_spectrum_channel(handle:Int, channel:Int, maxBins:Int):Int return 0;
    public static function dsp_get_parameter_text(handle:Int, index:Int, kind:Int):String return "";
    public static function dsp_set_param_typed(handle:Int, index:Int, kind:Int):Int return ERR_UNSUPPORTED;
    public static function dsp_get_param_typed(handle:Int, index:Int, kind:Int):Int return ERR_UNSUPPORTED;
    public static function dsp_get_data_parameter_index(handle:Int, dataType:Int):Int return -1;
    public static function dsp_set_channel_format(handle:Int, mask:Int, channels:Int, speakerMode:Int):Int return ERR_UNSUPPORTED;
    public static function dsp_get_channel_format(handle:Int):Int return ERR_UNSUPPORTED;
    public static function dsp_get_output_channel_format(handle:Int, inMask:Int, inChannels:Int, inMode:Int):Int return ERR_UNSUPPORTED;
    public static function conn_set_mix_matrix(handle:Int, outChannels:Int, inChannels:Int, inChannelHop:Int):Int return ERR_UNSUPPORTED;
    public static function conn_get_mix_matrix(handle:Int, inChannelHop:Int):Int return 0;

    // Debug
    public static function debug_live_handle_count():Int return 0;
    public static function binding_abi_version():Int return 0;

    // System extras
    public static function replay_get_command_count(handle:Int):Int return -1;
    public static function replay_get_command_info(handle:Int, index:Int):String return "";
    public static function replay_get_command_string(handle:Int, index:Int):String return "";
    public static function replay_get_command_at_time(handle:Int, seconds:Float):Int return -1;
    public static function replay_seek_to_command(handle:Int, index:Int):Int return ERR_UNSUPPORTED;
    public static function replay_get_playback_state(handle:Int):Int return 2;
    public static function replay_set_bank_path(handle:Int, path:String):Int return ERR_UNSUPPORTED;
    public static function sys_lock_dsp():Int return ERR_UNSUPPORTED;
    public static function sys_unlock_dsp():Int return ERR_UNSUPPORTED;
    public static function sys_get_sound_info(key:String):String return "";
    public static function sys_get_memory_stats(blocking:Bool):Int return ERR_UNSUPPORTED;
    public static function sys_get_file_usage():Int return ERR_UNSUPPORTED;
    public static function sys_set_network_proxy(proxy:String):Int return ERR_UNSUPPORTED;
    public static function sys_get_network_proxy():String return "";
    public static function sys_set_network_timeout(timeoutMs:Int):Int return ERR_UNSUPPORTED;
    public static function sys_get_network_timeout():Int return -1;
    public static function sys_set_speaker_position(speaker:Int, x:Float, y:Float, active:Bool):Int return ERR_UNSUPPORTED;
    public static function sys_get_speaker_position(speaker:Int):Int return ERR_UNSUPPORTED;
    // Plugins
    public static function sys_set_plugin_path(path:String):Int return ERR_UNSUPPORTED;
    public static function sys_load_plugin(path:String, priority:Int):Int return 0;
    public static function sys_unload_plugin(handle:Int):Int return ERR_UNSUPPORTED;
    public static function sys_get_num_plugins(type:Int):Int return -1;
    public static function sys_get_plugin_handle(type:Int, index:Int):Int return 0;
    public static function sys_get_plugin_info(handle:Int):String return "";
    public static function sys_get_num_nested_plugins(handle:Int):Int return -1;
    public static function sys_get_nested_plugin(handle:Int, index:Int):Int return 0;
    public static function dsp_create_by_plugin(pluginHandle:Int):Int return 0;
    public static function dsp_get_info_by_plugin(handle:Int):String return "";
    // Sound extras: tracker music, subsounds, tags, and advanced settings readback
    public static function core_sound_get_music_num_channels(handle:Int):Int return -1;
    public static function core_sound_set_music_channel_volume(handle:Int, channel:Int, volume:Float):Int return ERR_UNSUPPORTED;
    public static function core_sound_get_music_channel_volume(handle:Int, channel:Int):Float return 0.0;
    public static function core_sound_set_music_speed(handle:Int, speed:Float):Int return ERR_UNSUPPORTED;
    public static function core_sound_get_music_speed(handle:Int):Float return 0.0;
    public static function core_sound_get_num_sub_sounds(handle:Int):Int return -1;
    public static function core_sound_get_sub_sound(handle:Int, index:Int):Int return 0;
    public static function core_sound_get_sub_sound_parent(handle:Int):Int return 0;
    public static function core_sound_get_num_tags(handle:Int):Int return -1;
    public static function core_sound_get_tag(handle:Int, name:String, index:Int):String return "";
    public static function core_sound_get_tag_string(handle:Int, name:String, index:Int):String return "";
    public static function sys_get_advanced_settings():Int return ERR_UNSUPPORTED;
    public static function sys_get_studio_advanced_settings():Int return ERR_UNSUPPORTED;
    public static function dsp_add_input_preallocated(handle:Int, inputHandle:Int, connHandle:Int):Int return 0;
    public static function chan_set_mix_levels_input(handle:Int, count:Int):Int return ERR_UNSUPPORTED;
    public static function chan_set_mix_levels_output(handle:Int, fl:Float, fr:Float, c:Float, lfe:Float, sl:Float, sr:Float, bl:Float, br:Float):Int return ERR_UNSUPPORTED;
    public static function cg_set_mix_levels_input(handle:Int, count:Int):Int return ERR_UNSUPPORTED;
    public static function cg_set_mix_levels_output(handle:Int, fl:Float, fr:Float, c:Float, lfe:Float, sl:Float, sr:Float, bl:Float, br:Float):Int return ERR_UNSUPPORTED;
    public static function sys_get_dsp_info_by_type(type:Int):String return "";
    public static function sys_get_output_by_plugin():Int return 0;
    public static function sys_set_output_by_plugin(handle:Int):Int return ERR_UNSUPPORTED;
    public static var testLockArgs:String = "";
    public static function core_sound_lock(handle:Int, offset:Int, length:Int, out:haxe.io.Bytes):Int {
        testLockArgs = 'lock:$offset:$length:${out.length}';
        return -ERR_UNSUPPORTED;
    }
    public static function core_sound_unlock(handle:Int, data:haxe.io.Bytes, len:Int):Int {
        testLockArgs = 'unlock:$len:${data.length}';
        return ERR_UNSUPPORTED;
    }
    public static function sys_set_disk_busy(busy:Bool):Int return ERR_UNSUPPORTED;
    public static function sys_get_disk_busy():Bool return false;
    public static function replay_get_current_command(handle:Int):Int return -1;


    public static function cg_get_num_dsps(handle:Int):Int return 0;
    public static function cg_get_dsp(handle:Int, index:Int):Int return 0;

    //// Init settings and system info
    public static function sys_set_init_format(outputType:Int, resamplerMethod:Int, rawSpeakers:Int):Int {
        testPreInitCalls.push('format:$outputType,$resamplerMethod,$rawSpeakers');
        return 0;
    }
    public static function sys_memory_initialize(poolSize:Int):Int {
        testPreInitCalls.push('memory:$poolSize');
        return ERR_UNSUPPORTED;
    }
    public static function sys_thread_set_attributes(type:Int, priority:Int, stackSize:Int, affinity:Int):Int {
        testPreInitCalls.push('thread:$type,$priority,$stackSize,$affinity');
        return ERR_UNSUPPORTED;
    }
    public static function sys_debug_initialize(flags:Int, mode:Int, filename:String):Int {
        testPreInitCalls.push('debug:$flags,$mode,$filename');
        return ERR_UNSUPPORTED;
    }
    public static function sys_get_driver_info(id:Int):String return "";
    public static function sys_get_driver_guid(id:Int):String return "";
    public static function sys_attach_channel_group_to_port(portType:Int, portIndex:Int, group:Int, passThru:Bool):Int return ERR_UNSUPPORTED;
    public static function sys_detach_channel_group_from_port(group:Int):Int return ERR_UNSUPPORTED;

    //// Audit against FMOD's C# integration
    public static function bus_get_port_index(handle:Int):Int return -1;
    public static function bus_set_port_index(handle:Int, index:Int):Int return ERR_UNSUPPORTED;
    public static function evd_get_parameter_label_by_index(handle:Int, index:Int, labelIndex:Int):String return "";
    public static function sys_set_parameters_by_ids(count:Int, ignoreSeekSpeed:Bool):Int return ERR_UNSUPPORTED;
    public static function evi_set_parameters_by_ids(handle:Int, count:Int, ignoreSeekSpeed:Bool):Int return ERR_UNSUPPORTED;
    public static function sys_get_software_channels():Int return 0;
    public static function sys_get_dsp_buffer_size():Int return ERR_UNSUPPORTED;
    public static function sys_get_stream_buffer_size():Int return ERR_UNSUPPORTED;
}
