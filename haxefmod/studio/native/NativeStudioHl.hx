package haxefmod.studio.native;

#if hl
/**
 * HashLink backend for the FMOD Studio bindings.
 * Converts String to hl.Bytes at the boundary. raw prims live in hlaxe_fmod.c.
 */
class NativeStudioHl {
    static inline function toBytes(text:String):hl.Bytes {
        return @:privateAccess text.toUtf8();
    }

    static inline function fromBytes(bytes:hl.Bytes):String {
        return bytes == null ? "" : @:privateAccess String.fromUTF8(bytes);
    }

    // System
    public static inline function sys_last_result():Int return Raw.sys_last_result();
    public static inline function sys_get_bus(path:String):Int return Raw.sys_get_bus(toBytes(path));
    public static inline function sys_get_bus_by_id(guid:String):Int return Raw.sys_get_bus_by_id(toBytes(guid));
    public static inline function sys_get_event(path:String):Int return Raw.sys_get_event(toBytes(path));
    public static inline function sys_get_event_by_id(guid:String):Int return Raw.sys_get_event_by_id(toBytes(guid));
    public static inline function sys_get_vca(path:String):Int return Raw.sys_get_vca(toBytes(path));
    public static inline function sys_get_vca_by_id(guid:String):Int return Raw.sys_get_vca_by_id(toBytes(guid));
    public static inline function sys_get_bank(path:String):Int return Raw.sys_get_bank(toBytes(path));
    public static inline function sys_get_bank_by_id(guid:String):Int return Raw.sys_get_bank_by_id(toBytes(guid));
    public static inline function sys_get_bank_count():Int return Raw.sys_get_bank_count();

    /** Fills Scratch int buffer with bank handles, returns the count written */
    public static inline function sys_get_bank_list():Int return Raw.sys_get_bank_list(Scratch.intBuf());

    public static inline function sys_lookup_id(path:String):String return fromBytes(Raw.sys_lookup_id(toBytes(path)));
    public static inline function sys_lookup_path(guid:String):String return fromBytes(Raw.sys_lookup_path(toBytes(guid)));
    public static inline function sys_get_param_by_name(name:String):Float return Raw.sys_get_param_by_name(toBytes(name));
    public static inline function sys_get_param_by_name_final(name:String):Float return Raw.sys_get_param_by_name_final(toBytes(name));
    public static inline function sys_set_param_by_name(name:String, value:Float, ignoreSeekSpeed:Bool):Int return Raw.sys_set_param_by_name(toBytes(name), value, ignoreSeekSpeed);
    public static inline function sys_set_param_by_name_with_label(name:String, label:String, ignoreSeekSpeed:Bool):Int return Raw.sys_set_param_by_name_with_label(toBytes(name), toBytes(label), ignoreSeekSpeed);
    public static inline function sys_get_param_by_id(id1:Int, id2:Int):Float return Raw.sys_get_param_by_id(id1, id2);
    public static inline function sys_get_param_by_id_final(id1:Int, id2:Int):Float return Raw.sys_get_param_by_id_final(id1, id2);
    public static inline function sys_set_param_by_id(id1:Int, id2:Int, value:Float, ignoreSeekSpeed:Bool):Int return Raw.sys_set_param_by_id(id1, id2, value, ignoreSeekSpeed);
    public static inline function sys_set_param_by_id_with_label(id1:Int, id2:Int, label:String, ignoreSeekSpeed:Bool):Int return Raw.sys_set_param_by_id_with_label(id1, id2, toBytes(label), ignoreSeekSpeed);
    public static inline function sys_get_parameter_description_count():Int return Raw.sys_get_parameter_description_count();

    /** Returns param name. Fills Scratch float buffer: [0]=min, [1]=max, [2]=default. int buffer: [0]=type, [1]=flags, [2]=id1, [3]=id2 */
    public static inline function sys_get_parameter_description_by_index(index:Int):String return fromBytes(Raw.sys_get_parameter_description_by_index(index, Scratch.floatBuf(), Scratch.intBuf()));

    /** Returns param name. Fills Scratch float buffer: [0]=min, [1]=max, [2]=default. int buffer: [0]=type, [1]=flags, [2]=id1, [3]=id2 */
    public static inline function sys_get_parameter_description_by_name(name:String):String return fromBytes(Raw.sys_get_parameter_description_by_name(toBytes(name), Scratch.floatBuf(), Scratch.intBuf()));

    public static inline function sys_get_parameter_label(parameterName:String, labelIndex:Int):String return fromBytes(Raw.sys_get_parameter_label(toBytes(parameterName), labelIndex));
    public static inline function sys_get_num_listeners():Int return Raw.sys_get_num_listeners();
    public static inline function sys_set_num_listeners(count:Int):Int return Raw.sys_set_num_listeners(count);

    /** Fills Scratch float buffer [0..11]: pos xyz, vel xyz, forward xyz, up xyz */
    public static inline function sys_get_listener_attributes(index:Int):Int return Raw.sys_get_listener_attributes(index, Scratch.floatBuf());

    public static function sys_set_listener_attributes(index:Int, px:Float, py:Float, pz:Float, vx:Float, vy:Float, vz:Float, fx:Float, fy:Float, fz:Float, ux:Float, uy:Float, uz:Float):Int {
        Scratch.writeF(0, px); Scratch.writeF(1, py); Scratch.writeF(2, pz);
        Scratch.writeF(3, vx); Scratch.writeF(4, vy); Scratch.writeF(5, vz);
        Scratch.writeF(6, fx); Scratch.writeF(7, fy); Scratch.writeF(8, fz);
        Scratch.writeF(9, ux); Scratch.writeF(10, uy); Scratch.writeF(11, uz);
        return Raw.sys_set_listener_attributes(index, Scratch.floatBuf());
    }
    public static inline function sys_get_listener_weight(index:Int):Float return Raw.sys_get_listener_weight(index);
    public static inline function sys_set_listener_weight(index:Int, weight:Float):Int return Raw.sys_set_listener_weight(index, weight);
    public static inline function sys_load_bank_file(path:String, flags:Int):Int return Raw.sys_load_bank_file(toBytes(path), flags);
    public static inline function sys_unload_all():Int return Raw.sys_unload_all();
    public static inline function sys_flush_commands():Int return Raw.sys_flush_commands();
    public static inline function sys_flush_sample_loading():Int return Raw.sys_flush_sample_loading();

    /** Fills Scratch float buffer: [0]=studio update us, [1..6]=core dsp/stream/geometry/update/conv1/conv2 */
    public static inline function sys_get_cpu_usage():Int return Raw.sys_get_cpu_usage(Scratch.floatBuf());

    /** Fills Scratch int buffer: [0..3]=cmdqueue cur/peak/cap/stall, [4..7]=handle cur/peak/cap/stall. float buffer: [0]=cmd stalltime, [1]=handle stalltime */
    public static inline function sys_get_buffer_usage():Int return Raw.sys_get_buffer_usage(Scratch.intBuf(), Scratch.floatBuf());

    public static inline function sys_reset_buffer_usage():Int return Raw.sys_reset_buffer_usage();

    /** Fills Scratch int buffer: [0]=exclusive, [1]=inclusive, [2]=sampledata (bytes) */
    public static inline function sys_get_memory_usage():Int return Raw.sys_get_memory_usage(Scratch.intBuf());

    public static inline function sys_init_ex(numChannels:Int, sampleRate:Int, speakerMode:Int, studioFlags:Int, dspBufferLength:Int, dspNumBuffers:Int, softwareChannels:Int, streamBufferSize:Int, initFlags:Int, maxMPEGCodecs:Int, maxVorbisCodecs:Int, maxFADPCMCodecs:Int, vol0VirtualVol:Float, defaultDecodeBufferSize:Int, profilePort:Int, geometryMaxFadeTime:Int, distanceFilterCenterFreq:Float, randomSeed:Int, commandQueueSize:Int, handleInitialSize:Int, studioUpdatePeriod:Int, idleSampleDataPoolSize:Int, streamingScheduleDelay:Int, encryptionKey:String):Int return Raw.sys_init_ex(numChannels, sampleRate, speakerMode, studioFlags, dspBufferLength, dspNumBuffers, softwareChannels, streamBufferSize, initFlags, maxMPEGCodecs, maxVorbisCodecs, maxFADPCMCodecs, vol0VirtualVol, defaultDecodeBufferSize, profilePort, geometryMaxFadeTime, distanceFilterCenterFreq, randomSeed, commandQueueSize, handleInitialSize, studioUpdatePeriod, idleSampleDataPoolSize, streamingScheduleDelay, toBytes(encryptionKey));
    public static inline function sys_set_debug_level(level:Int):Int return Raw.sys_set_debug_level(level);
    public static inline function sys_load_bank_async(path:String):Int return Raw.sys_load_bank_async(toBytes(path));
    public static inline function sys_is_initialized():Bool return Raw.sys_is_initialized();
    public static inline function sys_update():Void Raw.sys_update();
    public static inline function sys_set_auto_update(enabled:Bool):Void Raw.sys_set_auto_update(enabled);

    // Bus
    public static inline function bus_is_valid(handle:Int):Bool return Raw.bus_is_valid(handle);
    public static inline function bus_get_id(handle:Int):String return fromBytes(Raw.bus_get_id(handle));
    public static inline function bus_get_path(handle:Int):String return fromBytes(Raw.bus_get_path(handle));
    public static inline function bus_get_volume(handle:Int):Float return Raw.bus_get_volume(handle);
    public static inline function bus_get_final_volume(handle:Int):Float return Raw.bus_get_final_volume(handle);
    public static inline function bus_set_volume(handle:Int, volume:Float):Int return Raw.bus_set_volume(handle, volume);
    public static inline function bus_get_paused(handle:Int):Bool return Raw.bus_get_paused(handle);
    public static inline function bus_set_paused(handle:Int, paused:Bool):Int return Raw.bus_set_paused(handle, paused);
    public static inline function bus_get_mute(handle:Int):Bool return Raw.bus_get_mute(handle);
    public static inline function bus_set_mute(handle:Int, mute:Bool):Int return Raw.bus_set_mute(handle, mute);
    public static inline function bus_stop_all_events(handle:Int, stopMode:Int):Int return Raw.bus_stop_all_events(handle, stopMode);

    /** Fills Scratch int buffer: [0]=exclusive, [1]=inclusive (microseconds) */
    public static inline function bus_get_cpu_usage(handle:Int):Int return Raw.bus_get_cpu_usage(handle, Scratch.intBuf());

    /** Fills Scratch int buffer: [0]=exclusive, [1]=inclusive, [2]=sampledata (bytes) */
    public static inline function bus_get_memory_usage(handle:Int):Int return Raw.bus_get_memory_usage(handle, Scratch.intBuf());

    // VCA
    public static inline function vca_is_valid(handle:Int):Bool return Raw.vca_is_valid(handle);
    public static inline function vca_get_id(handle:Int):String return fromBytes(Raw.vca_get_id(handle));
    public static inline function vca_get_path(handle:Int):String return fromBytes(Raw.vca_get_path(handle));
    public static inline function vca_get_volume(handle:Int):Float return Raw.vca_get_volume(handle);
    public static inline function vca_get_final_volume(handle:Int):Float return Raw.vca_get_final_volume(handle);
    public static inline function vca_set_volume(handle:Int, volume:Float):Int return Raw.vca_set_volume(handle, volume);

    // Bank
    public static inline function bank_is_valid(handle:Int):Bool return Raw.bank_is_valid(handle);
    public static inline function bank_get_id(handle:Int):String return fromBytes(Raw.bank_get_id(handle));
    public static inline function bank_get_path(handle:Int):String return fromBytes(Raw.bank_get_path(handle));
    public static inline function bank_unload(handle:Int):Int return Raw.bank_unload(handle);
    public static inline function bank_load_sample_data(handle:Int):Int return Raw.bank_load_sample_data(handle);
    public static inline function bank_unload_sample_data(handle:Int):Int return Raw.bank_unload_sample_data(handle);
    public static inline function bank_get_loading_state(handle:Int):Int return Raw.bank_get_loading_state(handle);
    public static inline function bank_get_sample_loading_state(handle:Int):Int return Raw.bank_get_sample_loading_state(handle);
    public static inline function bank_get_event_count(handle:Int):Int return Raw.bank_get_event_count(handle);

    /** Fills Scratch int buffer with event description handles, returns the count written */
    public static inline function bank_get_event_list(handle:Int):Int return Raw.bank_get_event_list(handle, Scratch.intBuf());

    public static inline function bank_get_bus_count(handle:Int):Int return Raw.bank_get_bus_count(handle);

    /** Fills Scratch int buffer with bus handles, returns the count written */
    public static inline function bank_get_bus_list(handle:Int):Int return Raw.bank_get_bus_list(handle, Scratch.intBuf());

    public static inline function bank_get_vca_count(handle:Int):Int return Raw.bank_get_vca_count(handle);

    /** Fills Scratch int buffer with VCA handles, returns the count written */
    public static inline function bank_get_vca_list(handle:Int):Int return Raw.bank_get_vca_list(handle, Scratch.intBuf());

    public static inline function bank_get_string_count(handle:Int):Int return Raw.bank_get_string_count(handle);
    public static inline function bank_get_string_info(handle:Int, index:Int):String return fromBytes(Raw.bank_get_string_info(handle, index));
    public static inline function bank_get_string_guid(handle:Int, index:Int):String return fromBytes(Raw.bank_get_string_guid(handle, index));

    // EventDescription
    public static inline function evd_is_valid(handle:Int):Bool return Raw.evd_is_valid(handle);
    public static inline function evd_get_id(handle:Int):String return fromBytes(Raw.evd_get_id(handle));
    public static inline function evd_get_path(handle:Int):String return fromBytes(Raw.evd_get_path(handle));
    public static inline function evd_get_length(handle:Int):Int return Raw.evd_get_length(handle);

    /** Fills Scratch float buffer: [0]=min, [1]=max */
    public static inline function evd_get_min_max_distance(handle:Int):Int return Raw.evd_get_min_max_distance(handle, Scratch.floatBuf());

    public static inline function evd_get_sound_size(handle:Int):Float return Raw.evd_get_sound_size(handle);
    public static inline function evd_is_snapshot(handle:Int):Bool return Raw.evd_is_snapshot(handle);
    public static inline function evd_is_oneshot(handle:Int):Bool return Raw.evd_is_oneshot(handle);
    public static inline function evd_is_stream(handle:Int):Bool return Raw.evd_is_stream(handle);
    public static inline function evd_is_3d(handle:Int):Bool return Raw.evd_is_3d(handle);
    public static inline function evd_is_doppler_enabled(handle:Int):Bool return Raw.evd_is_doppler_enabled(handle);
    public static inline function evd_has_sustain_point(handle:Int):Bool return Raw.evd_has_sustain_point(handle);
    public static inline function evd_create_instance(handle:Int):Int return Raw.evd_create_instance(handle);
    public static inline function evd_get_instance_count(handle:Int):Int return Raw.evd_get_instance_count(handle);

    /** Fills Scratch int buffer with instance handles, returns the count written */
    public static inline function evd_get_instance_list(handle:Int):Int return Raw.evd_get_instance_list(handle, Scratch.intBuf());

    public static inline function evd_release_all_instances(handle:Int):Int return Raw.evd_release_all_instances(handle);
    public static inline function evd_load_sample_data(handle:Int):Int return Raw.evd_load_sample_data(handle);
    public static inline function evd_unload_sample_data(handle:Int):Int return Raw.evd_unload_sample_data(handle);
    public static inline function evd_get_sample_loading_state(handle:Int):Int return Raw.evd_get_sample_loading_state(handle);
    public static inline function evd_get_parameter_description_count(handle:Int):Int return Raw.evd_get_parameter_description_count(handle);

    /** Returns param name. Fills Scratch float buffer: [0]=min, [1]=max, [2]=default. int buffer: [0]=type, [1]=flags, [2]=id1, [3]=id2 */
    public static inline function evd_get_parameter_description_by_index(handle:Int, index:Int):String return fromBytes(Raw.evd_get_parameter_description_by_index(handle, index, Scratch.floatBuf(), Scratch.intBuf()));

    /** Returns param name. Fills Scratch float buffer: [0]=min, [1]=max, [2]=default. int buffer: [0]=type, [1]=flags, [2]=id1, [3]=id2 */
    public static inline function evd_get_parameter_description_by_name(handle:Int, name:String):String return fromBytes(Raw.evd_get_parameter_description_by_name(handle, toBytes(name), Scratch.floatBuf(), Scratch.intBuf()));

    public static inline function evd_get_parameter_label(handle:Int, parameterName:String, labelIndex:Int):String return fromBytes(Raw.evd_get_parameter_label(handle, toBytes(parameterName), labelIndex));
    public static inline function evd_get_user_property_count(handle:Int):Int return Raw.evd_get_user_property_count(handle);
    public static inline function evd_get_user_property_name(handle:Int, index:Int):String return fromBytes(Raw.evd_get_user_property_name(handle, index));
    public static inline function evd_get_user_property_type(handle:Int, index:Int):Int return Raw.evd_get_user_property_type(handle, index);
    public static inline function evd_get_user_property_float(handle:Int, index:Int):Float return Raw.evd_get_user_property_float(handle, index);
    public static inline function evd_get_user_property_string(handle:Int, index:Int):String return fromBytes(Raw.evd_get_user_property_string(handle, index));

    // EventInstance
    public static inline function evi_is_valid(handle:Int):Bool return Raw.evi_is_valid(handle);
    public static inline function evi_get_description(handle:Int):Int return Raw.evi_get_description(handle);
    public static inline function evi_start(handle:Int):Int return Raw.evi_start(handle);
    public static inline function evi_stop(handle:Int, stopMode:Int):Int return Raw.evi_stop(handle, stopMode);
    public static inline function evi_key_off(handle:Int):Int return Raw.evi_key_off(handle);
    public static inline function evi_release(handle:Int):Int return Raw.evi_release(handle);
    public static inline function evi_get_playback_state(handle:Int):Int return Raw.evi_get_playback_state(handle);
    public static inline function evi_get_paused(handle:Int):Bool return Raw.evi_get_paused(handle);
    public static inline function evi_set_paused(handle:Int, paused:Bool):Int return Raw.evi_set_paused(handle, paused);
    public static inline function evi_get_volume(handle:Int):Float return Raw.evi_get_volume(handle);
    public static inline function evi_get_volume_final(handle:Int):Float return Raw.evi_get_volume_final(handle);
    public static inline function evi_set_volume(handle:Int, volume:Float):Int return Raw.evi_set_volume(handle, volume);
    public static inline function evi_get_pitch(handle:Int):Float return Raw.evi_get_pitch(handle);
    public static inline function evi_get_pitch_final(handle:Int):Float return Raw.evi_get_pitch_final(handle);
    public static inline function evi_set_pitch(handle:Int, pitch:Float):Int return Raw.evi_set_pitch(handle, pitch);
    public static inline function evi_get_timeline_position(handle:Int):Int return Raw.evi_get_timeline_position(handle);
    public static inline function evi_set_timeline_position(handle:Int, positionMs:Int):Int return Raw.evi_set_timeline_position(handle, positionMs);
    public static inline function evi_is_virtual(handle:Int):Bool return Raw.evi_is_virtual(handle);

    /** Fills Scratch float buffer: [0]=min, [1]=max */
    public static inline function evi_get_min_max_distance(handle:Int):Int return Raw.evi_get_min_max_distance(handle, Scratch.floatBuf());

    /** Fills Scratch float buffer [0..11]: pos xyz, vel xyz, forward xyz, up xyz */
    public static inline function evi_get_3d_attributes(handle:Int):Int return Raw.evi_get_3d_attributes(handle, Scratch.floatBuf());

    public static function evi_set_3d_attributes(handle:Int, px:Float, py:Float, pz:Float, vx:Float, vy:Float, vz:Float, fx:Float, fy:Float, fz:Float, ux:Float, uy:Float, uz:Float):Int {
        Scratch.writeF(0, px); Scratch.writeF(1, py); Scratch.writeF(2, pz);
        Scratch.writeF(3, vx); Scratch.writeF(4, vy); Scratch.writeF(5, vz);
        Scratch.writeF(6, fx); Scratch.writeF(7, fy); Scratch.writeF(8, fz);
        Scratch.writeF(9, ux); Scratch.writeF(10, uy); Scratch.writeF(11, uz);
        return Raw.evi_set_3d_attributes(handle, Scratch.floatBuf());
    }
    public static inline function evi_get_listener_mask(handle:Int):Int return Raw.evi_get_listener_mask(handle);
    public static inline function evi_set_listener_mask(handle:Int, mask:Int):Int return Raw.evi_set_listener_mask(handle, mask);
    public static inline function evi_get_property(handle:Int, property:Int):Float return Raw.evi_get_property(handle, property);
    public static inline function evi_set_property(handle:Int, property:Int, value:Float):Int return Raw.evi_set_property(handle, property, value);
    public static inline function evi_get_reverb_level(handle:Int, index:Int):Float return Raw.evi_get_reverb_level(handle, index);
    public static inline function evi_set_reverb_level(handle:Int, index:Int, level:Float):Int return Raw.evi_set_reverb_level(handle, index, level);
    public static inline function evi_get_param_by_name(handle:Int, name:String):Float return Raw.evi_get_param_by_name(handle, toBytes(name));
    public static inline function evi_get_param_by_name_final(handle:Int, name:String):Float return Raw.evi_get_param_by_name_final(handle, toBytes(name));
    public static inline function evi_set_param_by_name(handle:Int, name:String, value:Float, ignoreSeekSpeed:Bool):Int return Raw.evi_set_param_by_name(handle, toBytes(name), value, ignoreSeekSpeed);
    public static inline function evi_set_param_by_name_with_label(handle:Int, name:String, label:String, ignoreSeekSpeed:Bool):Int return Raw.evi_set_param_by_name_with_label(handle, toBytes(name), toBytes(label), ignoreSeekSpeed);
    public static inline function evi_get_param_by_id(handle:Int, id1:Int, id2:Int):Float return Raw.evi_get_param_by_id(handle, id1, id2);
    public static inline function evi_get_param_by_id_final(handle:Int, id1:Int, id2:Int):Float return Raw.evi_get_param_by_id_final(handle, id1, id2);
    public static inline function evi_set_param_by_id(handle:Int, id1:Int, id2:Int, value:Float, ignoreSeekSpeed:Bool):Int return Raw.evi_set_param_by_id(handle, id1, id2, value, ignoreSeekSpeed);
    public static inline function evi_set_param_by_id_with_label(handle:Int, id1:Int, id2:Int, label:String, ignoreSeekSpeed:Bool):Int return Raw.evi_set_param_by_id_with_label(handle, id1, id2, toBytes(label), ignoreSeekSpeed);

    /** Fills Scratch int buffer: [0]=exclusive, [1]=inclusive (microseconds) */
    public static inline function evi_get_cpu_usage(handle:Int):Int return Raw.evi_get_cpu_usage(handle, Scratch.intBuf());

    /** Fills Scratch int buffer: [0]=exclusive, [1]=inclusive, [2]=sampledata (bytes) */
    public static inline function evi_get_memory_usage(handle:Int):Int return Raw.evi_get_memory_usage(handle, Scratch.intBuf());

    // Programmer sounds
    public static inline function ps_assign(handle:Int, key:String):Int return Raw.ps_assign(handle, toBytes(key));
    public static inline function ps_clear(handle:Int):Int return Raw.ps_clear(handle);

    // Core API micro subset
    public static inline function core_create_sound(path:String, mode:Int, openOnly:Bool):Int return Raw.core_create_sound(toBytes(path), mode, openOnly);
    public static inline function core_release_sound(handle:Int):Int return Raw.core_release_sound(handle);
    public static inline function core_get_sound_length(handle:Int):Int return Raw.core_get_sound_length(handle);

    // Core PCM streams
    public static inline function core_pcm_create(sampleRate:Int, channels:Int, ringBytes:Int):Int return Raw.core_pcm_create(sampleRate, channels, ringBytes);
    public static inline function core_pcm_write(handle:Int, data:haxe.io.Bytes, len:Int):Int return Raw.core_pcm_write(handle, data.getData().bytes, len);
    public static inline function core_pcm_space(handle:Int):Int return Raw.core_pcm_space(handle);
    public static inline function core_pcm_underruns(handle:Int):Int return Raw.core_pcm_underruns(handle);
    public static inline function core_pcm_play(handle:Int, startPaused:Bool):Int return Raw.core_pcm_play(handle, startPaused);
    public static inline function core_pcm_release(handle:Int):Int return Raw.core_pcm_release(handle);

    // Core channels
    public static inline function chan_set_volume(handle:Int, volume:Float):Int return Raw.chan_set_volume(handle, volume);
    public static inline function chan_get_volume(handle:Int):Float return Raw.chan_get_volume(handle);
    public static inline function chan_set_pitch(handle:Int, pitch:Float):Int return Raw.chan_set_pitch(handle, pitch);
    public static inline function chan_get_pitch(handle:Int):Float return Raw.chan_get_pitch(handle);
    public static inline function chan_set_paused(handle:Int, paused:Bool):Int return Raw.chan_set_paused(handle, paused);
    public static inline function chan_get_paused(handle:Int):Bool return Raw.chan_get_paused(handle);
    public static inline function chan_is_playing(handle:Int):Bool return Raw.chan_is_playing(handle);
    public static inline function chan_stop(handle:Int):Int return Raw.chan_stop(handle);

    // Core DSP effects
    public static inline function dsp_create_by_type(type:Int):Int return Raw.dsp_create_by_type(type);
    public static inline function dsp_release(handle:Int):Int return Raw.dsp_release(handle);
    public static inline function dsp_set_param_float(handle:Int, index:Int, value:Float):Int return Raw.dsp_set_param_float(handle, index, value);
    public static inline function dsp_get_param_float(handle:Int, index:Int):Float return Raw.dsp_get_param_float(handle, index);
    public static inline function dsp_set_param_int(handle:Int, index:Int, value:Int):Int return Raw.dsp_set_param_int(handle, index, value);
    public static inline function dsp_get_param_int(handle:Int, index:Int):Int return Raw.dsp_get_param_int(handle, index);
    public static inline function dsp_set_param_bool(handle:Int, index:Int, value:Bool):Int return Raw.dsp_set_param_bool(handle, index, value);
    public static inline function dsp_get_param_bool(handle:Int, index:Int):Bool return Raw.dsp_get_param_bool(handle, index);
    public static inline function dsp_get_num_params(handle:Int):Int return Raw.dsp_get_num_params(handle);
    public static inline function dsp_get_type(handle:Int):Int return Raw.dsp_get_type(handle);
    public static inline function dsp_set_bypass(handle:Int, bypass:Bool):Int return Raw.dsp_set_bypass(handle, bypass);
    public static inline function dsp_get_bypass(handle:Int):Bool return Raw.dsp_get_bypass(handle);
    public static inline function dsp_set_wet_dry_mix(handle:Int, prewet:Float, postwet:Float, dry:Float):Int return Raw.dsp_set_wet_dry_mix(handle, prewet, postwet, dry);
    public static inline function dsp_set_active(handle:Int, active:Bool):Int return Raw.dsp_set_active(handle, active);
    public static inline function dsp_reset(handle:Int):Int return Raw.dsp_reset(handle);
    public static inline function dsp_set_metering_enabled(handle:Int, input:Bool, output:Bool):Int return Raw.dsp_set_metering_enabled(handle, input, output);

    /** Fills Scratch float buffer: [0..ch-1] peak, [ch..2ch-1] rms. Returns channel count. */
    public static inline function dsp_get_metering(handle:Int):Int return Raw.dsp_get_metering(handle, Scratch.floatBuf());

    /** Fills Scratch float buffer with spectrum magnitudes. Returns bins written. */
    public static inline function dsp_fft_get_spectrum(handle:Int, maxBins:Int):Int return Raw.dsp_fft_get_spectrum(handle, Scratch.floatBuf(), maxBins);

    // Core channel groups
    public static inline function cg_get_master():Int return Raw.cg_get_master();
    public static inline function cg_create(name:String):Int return Raw.cg_create(toBytes(name));
    public static inline function cg_release(handle:Int):Int return Raw.cg_release(handle);
    public static inline function cg_set_volume(handle:Int, volume:Float):Int return Raw.cg_set_volume(handle, volume);
    public static inline function cg_get_volume(handle:Int):Float return Raw.cg_get_volume(handle);
    public static inline function cg_set_pitch(handle:Int, pitch:Float):Int return Raw.cg_set_pitch(handle, pitch);
    public static inline function cg_get_pitch(handle:Int):Float return Raw.cg_get_pitch(handle);
    public static inline function cg_set_mute(handle:Int, mute:Bool):Int return Raw.cg_set_mute(handle, mute);
    public static inline function cg_get_mute(handle:Int):Bool return Raw.cg_get_mute(handle);
    public static inline function cg_set_paused(handle:Int, paused:Bool):Int return Raw.cg_set_paused(handle, paused);
    public static inline function cg_get_paused(handle:Int):Bool return Raw.cg_get_paused(handle);
    public static inline function cg_add_dsp(handle:Int, index:Int, dspHandle:Int):Int return Raw.cg_add_dsp(handle, index, dspHandle);
    public static inline function cg_remove_dsp(handle:Int, dspHandle:Int):Int return Raw.cg_remove_dsp(handle, dspHandle);
    public static inline function cg_stop(handle:Int):Int return Raw.cg_stop(handle);

    // Core channel routing and effects
    public static inline function chan_set_pan(handle:Int, pan:Float):Int return Raw.chan_set_pan(handle, pan);
    public static inline function chan_set_frequency(handle:Int, frequency:Float):Int return Raw.chan_set_frequency(handle, frequency);
    public static inline function chan_get_frequency(handle:Int):Float return Raw.chan_get_frequency(handle);
    public static inline function chan_set_loop_count(handle:Int, loopCount:Int):Int return Raw.chan_set_loop_count(handle, loopCount);
    public static inline function chan_get_position(handle:Int):Int return Raw.chan_get_position(handle);
    public static inline function chan_set_position(handle:Int, positionMs:Int):Int return Raw.chan_set_position(handle, positionMs);
    public static inline function chan_set_channel_group(handle:Int, groupHandle:Int):Int return Raw.chan_set_channel_group(handle, groupHandle);
    public static inline function chan_add_dsp(handle:Int, index:Int, dspHandle:Int):Int return Raw.chan_add_dsp(handle, index, dspHandle);
    public static inline function chan_remove_dsp(handle:Int, dspHandle:Int):Int return Raw.chan_remove_dsp(handle, dspHandle);
    public static inline function chan_set_3d_attributes(handle:Int, posX:Float, posY:Float, posZ:Float, velX:Float, velY:Float, velZ:Float):Int return Raw.chan_set_3d_attributes(handle, posX, posY, posZ, velX, velY, velZ);
    public static inline function chan_set_3d_min_max(handle:Int, minDist:Float, maxDist:Float):Int return Raw.chan_set_3d_min_max(handle, minDist, maxDist);
    public static inline function chan_set_reverb_wet(handle:Int, instance:Int, wet:Float):Int return Raw.chan_set_reverb_wet(handle, instance, wet);

    // Studio bus to core group bridge
    public static inline function bus_lock_channel_group(handle:Int):Int return Raw.bus_lock_channel_group(handle);
    public static inline function bus_unlock_channel_group(handle:Int):Int return Raw.bus_unlock_channel_group(handle);
    public static inline function bus_get_channel_group(handle:Int):Int return Raw.bus_get_channel_group(handle);

    // Core system extras
    public static inline function sys_play_dsp(dspHandle:Int, startPaused:Bool):Int return Raw.sys_play_dsp(dspHandle, startPaused);

    /** 12 reverb property floats through the Scratch float buffer, DecayTime..WetLevel. */
    public static inline function sys_set_reverb_properties(instance:Int):Int return Raw.sys_set_reverb_properties(instance, Scratch.floatBuf());
    public static inline function sys_get_reverb_properties(instance:Int):Int return Raw.sys_get_reverb_properties(instance, Scratch.floatBuf());
    public static inline function core_pcm_create_3d(sampleRate:Int, channels:Int, ringBytes:Int):Int return Raw.core_pcm_create_3d(sampleRate, channels, ringBytes);

    // Core DSP connection graph
    public static inline function dsp_add_input(handle:Int, inputHandle:Int, type:Int):Int return Raw.dsp_add_input(handle, inputHandle, type);
    public static inline function dsp_disconnect_from(handle:Int, inputHandle:Int):Int return Raw.dsp_disconnect_from(handle, inputHandle);
    public static inline function dsp_disconnect_all(handle:Int, inputs:Bool, outputs:Bool):Int return Raw.dsp_disconnect_all(handle, inputs, outputs);
    public static inline function dsp_get_num_inputs(handle:Int):Int return Raw.dsp_get_num_inputs(handle);
    public static inline function dsp_get_num_outputs(handle:Int):Int return Raw.dsp_get_num_outputs(handle);
    public static inline function dsp_get_input_dsp(handle:Int, index:Int):Int return Raw.dsp_get_input_dsp(handle, index);
    public static inline function dsp_get_input_connection(handle:Int, index:Int):Int return Raw.dsp_get_input_connection(handle, index);
    public static inline function dspconn_set_mix(handle:Int, mix:Float):Int return Raw.dspconn_set_mix(handle, mix);
    public static inline function dspconn_get_mix(handle:Int):Float return Raw.dspconn_get_mix(handle);
    public static inline function dspconn_get_type(handle:Int):Int return Raw.dspconn_get_type(handle);

    // Core channel group nesting
    public static inline function cg_add_group(handle:Int, childHandle:Int):Int return Raw.cg_add_group(handle, childHandle);
    public static inline function cg_get_num_groups(handle:Int):Int return Raw.cg_get_num_groups(handle);
    public static inline function cg_get_group(handle:Int, index:Int):Int return Raw.cg_get_group(handle, index);
    public static inline function cg_get_parent_group(handle:Int):Int return Raw.cg_get_parent_group(handle);

    // Core channel spatial and control extras
    public static inline function chan_set_mute(handle:Int, mute:Bool):Int return Raw.chan_set_mute(handle, mute);
    public static inline function chan_get_mute(handle:Int):Bool return Raw.chan_get_mute(handle);
    public static inline function chan_set_low_pass_gain(handle:Int, gain:Float):Int return Raw.chan_set_low_pass_gain(handle, gain);
    public static inline function chan_set_mode(handle:Int, mode:Int):Int return Raw.chan_set_mode(handle, mode);
    public static inline function chan_set_3d_cone_settings(handle:Int, insideAngle:Float, outsideAngle:Float, outsideVolume:Float):Int return Raw.chan_set_3d_cone_settings(handle, insideAngle, outsideAngle, outsideVolume);
    public static inline function chan_set_3d_cone_orientation(handle:Int, x:Float, y:Float, z:Float):Int return Raw.chan_set_3d_cone_orientation(handle, x, y, z);
    public static inline function chan_set_3d_occlusion(handle:Int, direct:Float, reverb:Float):Int return Raw.chan_set_3d_occlusion(handle, direct, reverb);

    /** Fills Scratch float buffer: [0]=direct [1]=reverb */
    public static inline function chan_get_3d_occlusion(handle:Int):Int return Raw.chan_get_3d_occlusion(handle, Scratch.floatBuf());

    public static inline function chan_set_3d_spread(handle:Int, angle:Float):Int return Raw.chan_set_3d_spread(handle, angle);
    public static inline function chan_set_3d_level(handle:Int, level:Float):Int return Raw.chan_set_3d_level(handle, level);
    public static inline function chan_set_3d_doppler_level(handle:Int, level:Float):Int return Raw.chan_set_3d_doppler_level(handle, level);

    /** Matrix rows go through the Scratch float buffer, out*in gains row-major. */
    public static inline function chan_set_mix_matrix(handle:Int, outChannels:Int, inChannels:Int):Int return Raw.chan_set_mix_matrix(handle, Scratch.floatBuf(), outChannels, inChannels);

    // Core scheduling (clocks as Float doubles, exact to 2^53 samples)
    /** Fills Scratch float buffer: [0]=channel clock [1]=parent group clock */
    public static inline function chan_get_dsp_clock(handle:Int):Int return Raw.chan_get_dsp_clock(handle, Scratch.floatBuf());
    public static inline function chan_set_delay(handle:Int, startClock:Float, endClock:Float, stopChannels:Bool):Int return Raw.chan_set_delay(handle, startClock, endClock, stopChannels);
    public static inline function chan_add_fade_point(handle:Int, clock:Float, volume:Float):Int return Raw.chan_add_fade_point(handle, clock, volume);
    public static inline function chan_set_fade_point_ramp(handle:Int, clock:Float, volume:Float):Int return Raw.chan_set_fade_point_ramp(handle, clock, volume);
    public static inline function chan_remove_fade_points(handle:Int, startClock:Float, endClock:Float):Int return Raw.chan_remove_fade_points(handle, startClock, endClock);
    public static inline function cg_get_dsp_clock(handle:Int):Int return Raw.cg_get_dsp_clock(handle, Scratch.floatBuf());
    public static inline function cg_set_delay(handle:Int, startClock:Float, endClock:Float, stopChannels:Bool):Int return Raw.cg_set_delay(handle, startClock, endClock, stopChannels);
    public static inline function cg_add_fade_point(handle:Int, clock:Float, volume:Float):Int return Raw.cg_add_fade_point(handle, clock, volume);
    public static inline function cg_set_fade_point_ramp(handle:Int, clock:Float, volume:Float):Int return Raw.cg_set_fade_point_ramp(handle, clock, volume);
    public static inline function cg_remove_fade_points(handle:Int, startClock:Float, endClock:Float):Int return Raw.cg_remove_fade_points(handle, startClock, endClock);

    // Core reverb zones
    public static inline function sys_create_reverb3d():Int return Raw.sys_create_reverb3d();
    public static inline function r3d_release(handle:Int):Int return Raw.r3d_release(handle);
    public static inline function r3d_set_3d_attributes(handle:Int, x:Float, y:Float, z:Float, minDist:Float, maxDist:Float):Int return Raw.r3d_set_3d_attributes(handle, x, y, z, minDist, maxDist);

    /** 12 reverb property floats through the Scratch float buffer. */
    public static inline function r3d_set_properties(handle:Int):Int return Raw.r3d_set_properties(handle, Scratch.floatBuf());
    public static inline function r3d_get_properties(handle:Int):Int return Raw.r3d_get_properties(handle, Scratch.floatBuf());

    public static inline function r3d_set_active(handle:Int, active:Bool):Int return Raw.r3d_set_active(handle, active);

    // Core sound surface
    public static inline function core_create_sound_pcm(data:haxe.io.Bytes, len:Int, sampleRate:Int, channels:Int):Int return Raw.core_create_sound_pcm(data.getData().bytes, len, sampleRate, channels);
    public static inline function core_play_sound(handle:Int, startPaused:Bool):Int return Raw.core_play_sound(handle, startPaused);
    public static inline function sound_set_defaults(handle:Int, frequency:Float, priority:Int):Int return Raw.sound_set_defaults(handle, frequency, priority);

    /** Fills Scratch float buffer: [0]=frequency [1]=priority */
    public static inline function sound_get_defaults(handle:Int):Int return Raw.sound_get_defaults(handle, Scratch.floatBuf());

    public static inline function sound_set_loop_points(handle:Int, startMs:Int, endMs:Int):Int return Raw.sound_set_loop_points(handle, startMs, endMs);

    /** Fills Scratch int buffer: [0]=loop start ms [1]=loop end ms */
    public static inline function sound_get_loop_points(handle:Int):Int return Raw.sound_get_loop_points(handle, Scratch.intBuf());

    public static inline function sound_set_mode(handle:Int, mode:Int):Int return Raw.sound_set_mode(handle, mode);
    public static inline function sound_get_mode(handle:Int):Int return Raw.sound_get_mode(handle);

    /** Fills Scratch int buffer: [0]=channels [1]=bits */
    public static inline function sound_get_format(handle:Int):Int return Raw.sound_get_format(handle, Scratch.intBuf());

    public static inline function sound_get_open_state(handle:Int):Int return Raw.sound_get_open_state(handle);

    // Core system extras (slice 3)
    /** Fills Scratch int buffer: [0]=all channels [1]=real channels */
    public static inline function sys_get_channels_playing():Int return Raw.sys_get_channels_playing(Scratch.intBuf());

    public static inline function sys_mixer_suspend():Int return Raw.sys_mixer_suspend();
    public static inline function sys_mixer_resume():Int return Raw.sys_mixer_resume();

    /** Fills Scratch int buffer: [0]=rate [1]=speaker mode [2]=raw count */
    public static inline function sys_get_software_format():Int return Raw.sys_get_software_format(Scratch.intBuf());

    /** Fills Scratch int buffer: [0]=exclusive us [1]=inclusive us */
    public static inline function dsp_get_cpu_usage(handle:Int):Int return Raw.dsp_get_cpu_usage(handle, Scratch.intBuf());

    // Channel callbacks and sync points
    public static inline function chan_set_callback(handle:Int, enabled:Bool):Int return Raw.chan_set_callback(handle, enabled);
    public static inline function sys_set_callback_mask(mask:Int):Int return Raw.sys_set_callback_mask(mask);
    public static inline function sys_set_studio_callback_mask(mask:Int):Int return Raw.sys_set_studio_callback_mask(mask);
    public static inline function sound_add_sync_point(handle:Int, offsetMs:Int, name:String):Int return Raw.sound_add_sync_point(handle, offsetMs, toBytes(name));
    public static inline function sound_delete_sync_point(handle:Int, index:Int):Int return Raw.sound_delete_sync_point(handle, index);
    public static inline function sound_get_num_sync_points(handle:Int):Int return Raw.sound_get_num_sync_points(handle);
    public static inline function sound_get_sync_point_name(handle:Int, index:Int):String return fromBytes(Raw.sound_get_sync_point_name(handle, index));
    public static inline function sound_get_sync_point_offset(handle:Int, index:Int):Int return Raw.sound_get_sync_point_offset(handle, index);

    // Sound groups
    public static inline function sys_create_sound_group(name:String):Int return Raw.sys_create_sound_group(toBytes(name));
    public static inline function sys_get_master_sound_group():Int return Raw.sys_get_master_sound_group();
    public static inline function sg_release(handle:Int):Int return Raw.sg_release(handle);
    public static inline function sg_set_max_audible(handle:Int, maxAudible:Int):Int return Raw.sg_set_max_audible(handle, maxAudible);
    public static inline function sg_get_max_audible(handle:Int):Int return Raw.sg_get_max_audible(handle);
    public static inline function sg_set_max_audible_behavior(handle:Int, behavior:Int):Int return Raw.sg_set_max_audible_behavior(handle, behavior);
    public static inline function sg_get_max_audible_behavior(handle:Int):Int return Raw.sg_get_max_audible_behavior(handle);
    public static inline function sg_set_mute_fade_speed(handle:Int, speed:Float):Int return Raw.sg_set_mute_fade_speed(handle, speed);
    public static inline function sg_get_num_sounds(handle:Int):Int return Raw.sg_get_num_sounds(handle);
    public static inline function sg_stop(handle:Int):Int return Raw.sg_stop(handle);
    public static inline function sound_set_sound_group(handle:Int, groupHandle:Int):Int return Raw.sound_set_sound_group(handle, groupHandle);

    // System 3D settings and drivers
    public static inline function sys_set_3d_settings(doppler:Float, distanceFactor:Float, rolloffScale:Float):Int return Raw.sys_set_3d_settings(doppler, distanceFactor, rolloffScale);

    /** Fills Scratch float buffer: [0]=doppler [1]=distance factor [2]=rolloff scale */
    public static inline function sys_get_3d_settings():Int return Raw.sys_get_3d_settings(Scratch.floatBuf());

    public static inline function sys_get_num_drivers():Int return Raw.sys_get_num_drivers();
    public static inline function sys_get_driver_name(id:Int):String return fromBytes(Raw.sys_get_driver_name(id));

    // Getter symmetry for the routing and spatial setters
    public static inline function chan_get_loop_count(handle:Int):Int return Raw.chan_get_loop_count(handle);
    public static inline function chan_get_low_pass_gain(handle:Int):Float return Raw.chan_get_low_pass_gain(handle);
    public static inline function chan_get_mode(handle:Int):Int return Raw.chan_get_mode(handle);

    /** Fills Scratch float buffer: [0]=inside [1]=outside [2]=outside volume */
    public static inline function chan_get_3d_cone_settings(handle:Int):Int return Raw.chan_get_3d_cone_settings(handle, Scratch.floatBuf());

    public static inline function chan_get_3d_spread(handle:Int):Float return Raw.chan_get_3d_spread(handle);
    public static inline function chan_get_3d_level(handle:Int):Float return Raw.chan_get_3d_level(handle);
    public static inline function chan_get_3d_doppler_level(handle:Int):Float return Raw.chan_get_3d_doppler_level(handle);

    /** Fills Scratch float buffer: [0]=min [1]=max */
    public static inline function chan_get_3d_min_max(handle:Int):Int return Raw.chan_get_3d_min_max(handle, Scratch.floatBuf());

    /** Fills Scratch float buffer: [0..2]=position [3..5]=velocity */
    public static inline function chan_get_3d_attributes(handle:Int):Int return Raw.chan_get_3d_attributes(handle, Scratch.floatBuf());

    /** Fills Scratch float buffer: [0]=start clock [1]=end clock [2]=stop channels */
    public static inline function chan_get_delay(handle:Int):Int return Raw.chan_get_delay(handle, Scratch.floatBuf());

    /** Fills Scratch float buffer: [0]=prewet [1]=postwet [2]=dry */
    public static inline function dsp_get_wet_dry_mix(handle:Int):Int return Raw.dsp_get_wet_dry_mix(handle, Scratch.floatBuf());

    public static inline function dsp_get_active(handle:Int):Bool return Raw.dsp_get_active(handle);

    /** Fills Scratch int buffer: [0]=input enabled [1]=output enabled */
    public static inline function dsp_get_metering_enabled(handle:Int):Int return Raw.dsp_get_metering_enabled(handle, Scratch.intBuf());

    // Bank loading from memory
    public static inline function sys_load_bank_memory(data:haxe.io.Bytes, len:Int):Int return Raw.sys_load_bank_memory(data.getData().bytes, len);

    // Event instance core bridge
    public static inline function evi_get_channel_group(handle:Int):Int return Raw.evi_get_channel_group(handle);

    // Command capture and replay
    public static inline function sys_start_command_capture(path:String):Int return Raw.sys_start_command_capture(toBytes(path));
    public static inline function sys_stop_command_capture():Int return Raw.sys_stop_command_capture();
    public static inline function sys_load_command_replay(path:String):Int return Raw.sys_load_command_replay(toBytes(path));
    public static inline function replay_release(handle:Int):Int return Raw.replay_release(handle);
    public static inline function replay_is_valid(handle:Int):Bool return Raw.replay_is_valid(handle);
    public static inline function replay_start(handle:Int):Int return Raw.replay_start(handle);
    public static inline function replay_stop(handle:Int):Int return Raw.replay_stop(handle);
    public static inline function replay_set_paused(handle:Int, paused:Bool):Int return Raw.replay_set_paused(handle, paused);
    public static inline function replay_get_paused(handle:Int):Bool return Raw.replay_get_paused(handle);
    public static inline function replay_seek_to_time(handle:Int, timeMs:Int):Int return Raw.replay_seek_to_time(handle, timeMs);
    public static inline function replay_get_length(handle:Int):Float return Raw.replay_get_length(handle);

    // Channel priority, virtualization, and remaining getters
    public static inline function chan_set_priority(handle:Int, priority:Int):Int return Raw.chan_set_priority(handle, priority);
    public static inline function chan_get_priority(handle:Int):Int return Raw.chan_get_priority(handle);
    public static inline function chan_is_virtual(handle:Int):Bool return Raw.chan_is_virtual(handle);
    public static inline function chan_get_audibility(handle:Int):Float return Raw.chan_get_audibility(handle);
    public static inline function chan_set_volume_ramp(handle:Int, ramp:Bool):Int return Raw.chan_set_volume_ramp(handle, ramp);
    public static inline function chan_get_volume_ramp(handle:Int):Bool return Raw.chan_get_volume_ramp(handle);
    /** Borrowed reference: do not release a sound obtained this way. */
    public static inline function chan_get_current_sound(handle:Int):Int return Raw.chan_get_current_sound(handle);
    public static inline function chan_set_loop_points(handle:Int, startMs:Int, endMs:Int):Int return Raw.chan_set_loop_points(handle, startMs, endMs);
    /** Fills Scratch int buffer: [0]=loop start ms [1]=loop end ms */
    public static inline function chan_get_loop_points(handle:Int):Int return Raw.chan_get_loop_points(handle, Scratch.intBuf());
    public static inline function chan_get_reverb_wet(handle:Int, instance:Int):Float return Raw.chan_get_reverb_wet(handle, instance);
    public static inline function chan_get_index(handle:Int):Int return Raw.chan_get_index(handle);
    /** Fills Scratch float buffer: [0..2]=direction xyz */
    public static inline function chan_get_3d_cone_orientation(handle:Int):Int return Raw.chan_get_3d_cone_orientation(handle, Scratch.floatBuf());
    public static inline function chan_get_num_dsps(handle:Int):Int return Raw.chan_get_num_dsps(handle);
    public static inline function chan_get_dsp(handle:Int, index:Int):Int return Raw.chan_get_dsp(handle, index);

    // Sound name, group getter, and loop count
    public static inline function sound_get_name(handle:Int):String return fromBytes(Raw.sound_get_name(handle));
    public static inline function sound_get_sound_group(handle:Int):Int return Raw.sound_get_sound_group(handle);
    public static inline function sound_get_loop_count(handle:Int):Int return Raw.sound_get_loop_count(handle);
    public static inline function sound_set_loop_count(handle:Int, loopCount:Int):Int return Raw.sound_set_loop_count(handle, loopCount);

    // Sound group volume and counters
    public static inline function sg_set_volume(handle:Int, volume:Float):Int return Raw.sg_set_volume(handle, volume);
    public static inline function sg_get_volume(handle:Int):Float return Raw.sg_get_volume(handle);
    public static inline function sg_get_num_playing(handle:Int):Int return Raw.sg_get_num_playing(handle);
    public static inline function sg_get_mute_fade_speed(handle:Int):Float return Raw.sg_get_mute_fade_speed(handle);

    // Output device selection
    public static inline function sys_set_driver(id:Int):Int return Raw.sys_set_driver(id);
    public static inline function sys_get_driver():Int return Raw.sys_get_driver();

    // DSP data params, info, and output traversal
    /** Byte payload per the effect's data parameter contract. */
    public static inline function dsp_set_param_data(handle:Int, index:Int, data:haxe.io.Bytes, len:Int):Int return Raw.dsp_set_param_data(handle, index, data.getData().bytes, len);
    public static inline function dsp_get_idle(handle:Int):Bool return Raw.dsp_get_idle(handle);
    public static inline function dsp_get_info_name(handle:Int):String return fromBytes(Raw.dsp_get_info_name(handle));
    public static inline function dsp_get_output_dsp(handle:Int, index:Int):Int return Raw.dsp_get_output_dsp(handle, index);
    public static inline function dsp_get_output_connection(handle:Int, index:Int):Int return Raw.dsp_get_output_connection(handle, index);
    public static inline function dspconn_get_input_dsp(handle:Int):Int return Raw.dspconn_get_input_dsp(handle);
    public static inline function dspconn_get_output_dsp(handle:Int):Int return Raw.dspconn_get_output_dsp(handle);

    // Reverb3D getters
    public static inline function r3d_get_active(handle:Int):Bool return Raw.r3d_get_active(handle);
    /** Fills Scratch float buffer: [0..2]=position [3]=min distance [4]=max distance */
    public static inline function r3d_get_3d_attributes(handle:Int):Int return Raw.r3d_get_3d_attributes(handle, Scratch.floatBuf());

    // Channel group spatial mirror and remaining control surface
    public static inline function cg_set_pan(handle:Int, pan:Float):Int return Raw.cg_set_pan(handle, pan);
    public static inline function cg_set_low_pass_gain(handle:Int, gain:Float):Int return Raw.cg_set_low_pass_gain(handle, gain);
    public static inline function cg_set_mode(handle:Int, mode:Int):Int return Raw.cg_set_mode(handle, mode);
    public static inline function cg_get_mode(handle:Int):Int return Raw.cg_get_mode(handle);
    public static inline function cg_set_3d_attributes(handle:Int, posX:Float, posY:Float, posZ:Float, velX:Float, velY:Float, velZ:Float):Int return Raw.cg_set_3d_attributes(handle, posX, posY, posZ, velX, velY, velZ);
    /** Fills Scratch float buffer: [0..2]=position [3..5]=velocity */
    public static inline function cg_get_3d_attributes(handle:Int):Int return Raw.cg_get_3d_attributes(handle, Scratch.floatBuf());
    public static inline function cg_set_3d_min_max(handle:Int, minDist:Float, maxDist:Float):Int return Raw.cg_set_3d_min_max(handle, minDist, maxDist);
    /** Fills Scratch float buffer: [0]=min [1]=max */
    public static inline function cg_get_3d_min_max(handle:Int):Int return Raw.cg_get_3d_min_max(handle, Scratch.floatBuf());
    public static inline function cg_set_3d_occlusion(handle:Int, direct:Float, reverb:Float):Int return Raw.cg_set_3d_occlusion(handle, direct, reverb);
    public static inline function cg_set_3d_level(handle:Int, level:Float):Int return Raw.cg_set_3d_level(handle, level);
    public static inline function cg_get_3d_level(handle:Int):Float return Raw.cg_get_3d_level(handle);
    public static inline function cg_set_3d_spread(handle:Int, angle:Float):Int return Raw.cg_set_3d_spread(handle, angle);
    public static inline function cg_get_3d_spread(handle:Int):Float return Raw.cg_get_3d_spread(handle);
    public static inline function cg_set_3d_doppler_level(handle:Int, level:Float):Int return Raw.cg_set_3d_doppler_level(handle, level);
    public static inline function cg_get_3d_doppler_level(handle:Int):Float return Raw.cg_get_3d_doppler_level(handle);
    public static inline function cg_set_3d_cone_settings(handle:Int, insideAngle:Float, outsideAngle:Float, outsideVolume:Float):Int return Raw.cg_set_3d_cone_settings(handle, insideAngle, outsideAngle, outsideVolume);
    /** Fills Scratch float buffer: [0]=inside [1]=outside [2]=outside volume */
    public static inline function cg_get_3d_cone_settings(handle:Int):Int return Raw.cg_get_3d_cone_settings(handle, Scratch.floatBuf());
    public static inline function cg_set_3d_cone_orientation(handle:Int, x:Float, y:Float, z:Float):Int return Raw.cg_set_3d_cone_orientation(handle, x, y, z);
    /** Fills Scratch float buffer: [0..2]=direction xyz */
    public static inline function cg_get_3d_cone_orientation(handle:Int):Int return Raw.cg_get_3d_cone_orientation(handle, Scratch.floatBuf());
    public static inline function cg_set_reverb_wet(handle:Int, instance:Int, wet:Float):Int return Raw.cg_set_reverb_wet(handle, instance, wet);
    public static inline function cg_get_reverb_wet(handle:Int, instance:Int):Float return Raw.cg_get_reverb_wet(handle, instance);
    /** Matrix rows go through the Scratch float buffer, out*in gains row-major. */
    public static inline function cg_set_mix_matrix(handle:Int, outChannels:Int, inChannels:Int):Int return Raw.cg_set_mix_matrix(handle, Scratch.floatBuf(), outChannels, inChannels);
    public static inline function cg_set_volume_ramp(handle:Int, ramp:Bool):Int return Raw.cg_set_volume_ramp(handle, ramp);
    public static inline function cg_get_volume_ramp(handle:Int):Bool return Raw.cg_get_volume_ramp(handle);
    public static inline function cg_get_audibility(handle:Int):Float return Raw.cg_get_audibility(handle);
    public static inline function cg_get_name(handle:Int):String return fromBytes(Raw.cg_get_name(handle));
    public static inline function cg_get_num_channels(handle:Int):Int return Raw.cg_get_num_channels(handle);
    public static inline function cg_get_channel(handle:Int, index:Int):Int return Raw.cg_get_channel(handle, index);

    // Callbacks
    public static inline function evi_set_callback_mask(handle:Int, mask:Int):Int return Raw.evi_set_callback_mask(handle, mask);
    public static inline function cb_next():Bool return Raw.cb_next();
    public static inline function cb_handle():Int return Raw.cb_handle();
    public static inline function cb_type():Int return Raw.cb_type();
    public static inline function cb_int(index:Int):Int return Raw.cb_int(index);
    public static inline function cb_float():Float return Raw.cb_float();
    public static inline function cb_string():String return fromBytes(Raw.cb_string());
    public static inline function cb_take_overflow():Bool return Raw.cb_take_overflow();

    // Distance filter, version, sound data, and recording
    public static inline function chan_set_3d_distance_filter(handle:Int, custom:Bool, customLevel:Float, centerFreq:Float):Int return Raw.chan_set_3d_distance_filter(handle, custom, customLevel, centerFreq);
    public static inline function chan_get_3d_distance_filter(handle:Int):Int return Raw.chan_get_3d_distance_filter(handle, Scratch.floatBuf());
    public static inline function cg_set_3d_distance_filter(handle:Int, custom:Bool, customLevel:Float, centerFreq:Float):Int return Raw.cg_set_3d_distance_filter(handle, custom, customLevel, centerFreq);
    public static inline function cg_get_3d_distance_filter(handle:Int):Int return Raw.cg_get_3d_distance_filter(handle, Scratch.floatBuf());
    public static inline function sys_get_version():String return fromBytes(Raw.sys_get_version());
    public static inline function core_sound_read_data(handle:Int, data:haxe.io.Bytes, len:Int):Int return Raw.core_sound_read_data(handle, data.getData().bytes, len);
    public static inline function core_sound_seek_data(handle:Int, pcm:Int):Int return Raw.core_sound_seek_data(handle, pcm);
    public static inline function sys_get_record_num_drivers():Int return Raw.sys_get_record_num_drivers(Scratch.intBuf());
    public static inline function sys_get_record_driver_info(id:Int):String return fromBytes(Raw.sys_get_record_driver_info(id, Scratch.intBuf()));
    public static inline function core_create_record_sound(sampleRate:Int, channels:Int, seconds:Int):Int return Raw.core_create_record_sound(sampleRate, channels, seconds);
    public static inline function sys_record_start(id:Int, soundHandle:Int, loop:Bool):Int return Raw.sys_record_start(id, soundHandle, loop);
    public static inline function sys_record_stop(id:Int):Int return Raw.sys_record_stop(id);
    public static inline function sys_is_recording(id:Int):Bool return Raw.sys_is_recording(id);
    public static inline function sys_get_record_position(id:Int):Int return Raw.sys_get_record_position(id);

    // Custom 3D rolloff and geometry
    public static inline function chan_set_3d_custom_rolloff(handle:Int, data:haxe.io.Bytes, count:Int):Int return Raw.chan_set_3d_custom_rolloff(handle, data == null ? null : data.getData().bytes, count);
    public static inline function chan_get_3d_custom_rolloff(handle:Int):Int return Raw.chan_get_3d_custom_rolloff(handle, Scratch.floatBuf());
    public static inline function cg_set_3d_custom_rolloff(handle:Int, data:haxe.io.Bytes, count:Int):Int return Raw.cg_set_3d_custom_rolloff(handle, data == null ? null : data.getData().bytes, count);
    public static inline function cg_get_3d_custom_rolloff(handle:Int):Int return Raw.cg_get_3d_custom_rolloff(handle, Scratch.floatBuf());
    public static inline function core_sound_set_3d_custom_rolloff(handle:Int, data:haxe.io.Bytes, count:Int):Int return Raw.core_sound_set_3d_custom_rolloff(handle, data == null ? null : data.getData().bytes, count);
    public static inline function core_sound_get_3d_custom_rolloff(handle:Int):Int return Raw.core_sound_get_3d_custom_rolloff(handle, Scratch.floatBuf());
    public static inline function sys_create_geometry(maxPolygons:Int, maxVertices:Int):Int return Raw.sys_create_geometry(maxPolygons, maxVertices);
    public static inline function sys_set_geometry_settings(maxWorldSize:Float):Int return Raw.sys_set_geometry_settings(maxWorldSize);
    public static inline function sys_get_geometry_settings():Float return Raw.sys_get_geometry_settings();
    public static inline function sys_get_geometry_occlusion(lx:Float, ly:Float, lz:Float, sx:Float, sy:Float, sz:Float):Int return Raw.sys_get_geometry_occlusion(lx, ly, lz, sx, sy, sz, Scratch.floatBuf());
    public static inline function sys_load_geometry(data:haxe.io.Bytes, len:Int):Int return Raw.sys_load_geometry(data == null ? null : data.getData().bytes, len);
    public static inline function geo_release(handle:Int):Int return Raw.geo_release(handle);
    public static inline function geo_add_polygon(handle:Int, direct:Float, reverb:Float, doubleSided:Bool, vertices:haxe.io.Bytes, count:Int):Int return Raw.geo_add_polygon(handle, direct, reverb, doubleSided, vertices == null ? null : vertices.getData().bytes, count);
    public static inline function geo_get_num_polygons(handle:Int):Int return Raw.geo_get_num_polygons(handle);
    public static inline function geo_get_max_polygons(handle:Int):Int return Raw.geo_get_max_polygons(handle, Scratch.intBuf());
    public static inline function geo_get_polygon_num_vertices(handle:Int, index:Int):Int return Raw.geo_get_polygon_num_vertices(handle, index);
    public static inline function geo_set_polygon_vertex(handle:Int, index:Int, vertexIndex:Int, x:Float, y:Float, z:Float):Int return Raw.geo_set_polygon_vertex(handle, index, vertexIndex, x, y, z);
    public static inline function geo_get_polygon_vertex(handle:Int, index:Int, vertexIndex:Int):Int return Raw.geo_get_polygon_vertex(handle, index, vertexIndex, Scratch.floatBuf());
    public static inline function geo_set_polygon_attributes(handle:Int, index:Int, direct:Float, reverb:Float, doubleSided:Bool):Int return Raw.geo_set_polygon_attributes(handle, index, direct, reverb, doubleSided);
    public static inline function geo_get_polygon_attributes(handle:Int, index:Int):Int return Raw.geo_get_polygon_attributes(handle, index, Scratch.floatBuf());
    public static inline function geo_set_active(handle:Int, active:Bool):Int return Raw.geo_set_active(handle, active);
    public static inline function geo_get_active(handle:Int):Bool return Raw.geo_get_active(handle);
    public static inline function geo_set_rotation(handle:Int, fx:Float, fy:Float, fz:Float, ux:Float, uy:Float, uz:Float):Int return Raw.geo_set_rotation(handle, fx, fy, fz, ux, uy, uz);
    public static inline function geo_get_rotation(handle:Int):Int return Raw.geo_get_rotation(handle, Scratch.floatBuf());
    public static inline function geo_set_position(handle:Int, x:Float, y:Float, z:Float):Int return Raw.geo_set_position(handle, x, y, z);
    public static inline function geo_get_position(handle:Int):Int return Raw.geo_get_position(handle, Scratch.floatBuf());
    public static inline function geo_set_scale(handle:Int, x:Float, y:Float, z:Float):Int return Raw.geo_set_scale(handle, x, y, z);
    public static inline function geo_get_scale(handle:Int):Int return Raw.geo_get_scale(handle, Scratch.floatBuf());
    public static inline function geo_save(handle:Int, data:haxe.io.Bytes, len:Int):Int return Raw.geo_save(handle, data == null ? null : data.getData().bytes, len);

    // Completeness tail: getters and setters on objects the library already wraps
    public static inline function core_sound_set_3d_cone_settings(handle:Int, inside:Float, outside:Float, outsideVolume:Float):Int return Raw.core_sound_set_3d_cone_settings(handle, inside, outside, outsideVolume);
    public static inline function core_sound_get_3d_cone_settings(handle:Int):Int return Raw.core_sound_get_3d_cone_settings(handle, Scratch.floatBuf());
    public static inline function core_sound_set_3d_min_max(handle:Int, minDistance:Float, maxDistance:Float):Int return Raw.core_sound_set_3d_min_max(handle, minDistance, maxDistance);
    public static inline function core_sound_get_3d_min_max(handle:Int):Int return Raw.core_sound_get_3d_min_max(handle, Scratch.floatBuf());
    public static inline function chan_set_dsp_index(handle:Int, dsp:Int, index:Int):Int return Raw.chan_set_dsp_index(handle, dsp, index);
    public static inline function chan_get_dsp_index(handle:Int, dsp:Int):Int return Raw.chan_get_dsp_index(handle, dsp);
    public static inline function chan_get_fade_points(handle:Int):Int return Raw.chan_get_fade_points(handle, Scratch.floatBuf());
    public static inline function chan_get_mix_matrix(handle:Int, outChannels:Int, inChannels:Int):Int return Raw.chan_get_mix_matrix(handle, Scratch.floatBuf(), Scratch.intBuf(), outChannels, inChannels);
    public static inline function chan_get_channel_group(handle:Int):Int return Raw.chan_get_channel_group(handle);
    public static inline function cg_set_dsp_index(handle:Int, dsp:Int, index:Int):Int return Raw.cg_set_dsp_index(handle, dsp, index);
    public static inline function cg_get_dsp_index(handle:Int, dsp:Int):Int return Raw.cg_get_dsp_index(handle, dsp);
    public static inline function cg_get_fade_points(handle:Int):Int return Raw.cg_get_fade_points(handle, Scratch.floatBuf());
    public static inline function cg_get_mix_matrix(handle:Int, outChannels:Int, inChannels:Int):Int return Raw.cg_get_mix_matrix(handle, Scratch.floatBuf(), Scratch.intBuf(), outChannels, inChannels);
    public static inline function sg_get_name(handle:Int):String return fromBytes(Raw.sg_get_name(handle));
    public static inline function sg_get_sound(handle:Int, index:Int):Int return Raw.sg_get_sound(handle, index);
    public static inline function sys_get_channel(index:Int):Int return Raw.sys_get_channel(index);
    public static inline function sys_get_output():Int return Raw.sys_get_output();
    public static inline function sys_get_speaker_mode_channels(mode:Int):Int return Raw.sys_get_speaker_mode_channels(mode);
    public static inline function sys_get_default_mix_matrix(sourceMode:Int, targetMode:Int, hop:Int):Int return Raw.sys_get_default_mix_matrix(sourceMode, targetMode, hop, Scratch.floatBuf());
    public static inline function dsp_get_parameter_info(handle:Int, index:Int):String return fromBytes(Raw.dsp_get_parameter_info(handle, index, Scratch.floatBuf(), Scratch.intBuf()));
    public static inline function dsp_get_data_parameter_index(handle:Int, dataType:Int):Int return Raw.dsp_get_data_parameter_index(handle, dataType);
    public static inline function dsp_set_channel_format(handle:Int, mask:Int, channels:Int, speakerMode:Int):Int return Raw.dsp_set_channel_format(handle, mask, channels, speakerMode);
    public static inline function dsp_get_channel_format(handle:Int):Int return Raw.dsp_get_channel_format(handle, Scratch.intBuf());
    public static inline function dsp_get_output_channel_format(handle:Int, inMask:Int, inChannels:Int, inMode:Int):Int return Raw.dsp_get_output_channel_format(handle, inMask, inChannels, inMode, Scratch.intBuf());
    public static inline function conn_set_mix_matrix(handle:Int, outChannels:Int, inChannels:Int):Int return Raw.conn_set_mix_matrix(handle, Scratch.floatBuf(), outChannels, inChannels);
    public static inline function conn_get_mix_matrix(handle:Int, outChannels:Int, inChannels:Int):Int return Raw.conn_get_mix_matrix(handle, Scratch.floatBuf(), Scratch.intBuf(), outChannels, inChannels);

    // Debug
    public static inline function debug_live_handle_count():Int return Raw.debug_live_handle_count();
    public static inline function binding_abi_version():Int return Raw.binding_abi_version();

    // System extras
    public static inline function replay_get_command_count(handle:Int):Int return Raw.replay_get_command_count(handle);
    public static inline function replay_get_command_info(handle:Int, index:Int):String return fromBytes(Raw.replay_get_command_info(handle, index, Scratch.intBuf(), Scratch.floatBuf()));
    public static inline function replay_get_command_string(handle:Int, index:Int):String return fromBytes(Raw.replay_get_command_string(handle, index));
    public static inline function replay_get_command_at_time(handle:Int, seconds:Float):Int return Raw.replay_get_command_at_time(handle, seconds);
    public static inline function replay_seek_to_command(handle:Int, index:Int):Int return Raw.replay_seek_to_command(handle, index);
    public static inline function replay_get_playback_state(handle:Int):Int return Raw.replay_get_playback_state(handle);
    public static inline function replay_set_bank_path(handle:Int, path:String):Int return Raw.replay_set_bank_path(handle, toBytes(path));
    public static inline function sys_lock_dsp():Int return Raw.sys_lock_dsp();
    public static inline function sys_unlock_dsp():Int return Raw.sys_unlock_dsp();
    public static inline function sys_get_sound_info(key:String):String return fromBytes(Raw.sys_get_sound_info(toBytes(key), Scratch.intBuf()));
    public static inline function sys_get_memory_stats(blocking:Bool):Int return Raw.sys_get_memory_stats(blocking, Scratch.intBuf());
    public static inline function sys_get_file_usage():Int return Raw.sys_get_file_usage(Scratch.floatBuf());
    public static inline function sys_set_network_proxy(proxy:String):Int return Raw.sys_set_network_proxy(toBytes(proxy));
    public static inline function sys_get_network_proxy():String return fromBytes(Raw.sys_get_network_proxy());
    public static inline function sys_set_network_timeout(timeoutMs:Int):Int return Raw.sys_set_network_timeout(timeoutMs);
    public static inline function sys_get_network_timeout():Int return Raw.sys_get_network_timeout();
    public static inline function sys_set_speaker_position(speaker:Int, x:Float, y:Float, active:Bool):Int return Raw.sys_set_speaker_position(speaker, x, y, active);
    public static inline function sys_get_speaker_position(speaker:Int):Int return Raw.sys_get_speaker_position(speaker, Scratch.floatBuf());
    // Plugins
    public static inline function sys_set_plugin_path(path:String):Int return Raw.sys_set_plugin_path(toBytes(path));
    public static inline function sys_load_plugin(path:String, priority:Int):Int return Raw.sys_load_plugin(toBytes(path), priority);
    public static inline function sys_unload_plugin(handle:Int):Int return Raw.sys_unload_plugin(handle);
    public static inline function sys_get_num_plugins(type:Int):Int return Raw.sys_get_num_plugins(type);
    public static inline function sys_get_plugin_handle(type:Int, index:Int):Int return Raw.sys_get_plugin_handle(type, index);
    public static inline function sys_get_plugin_info(handle:Int):String return fromBytes(Raw.sys_get_plugin_info(handle, Scratch.intBuf()));
    public static inline function sys_get_num_nested_plugins(handle:Int):Int return Raw.sys_get_num_nested_plugins(handle);
    public static inline function sys_get_nested_plugin(handle:Int, index:Int):Int return Raw.sys_get_nested_plugin(handle, index);
    public static inline function dsp_create_by_plugin(pluginHandle:Int):Int return Raw.dsp_create_by_plugin(pluginHandle);
    public static inline function dsp_get_info_by_plugin(handle:Int):String return fromBytes(Raw.dsp_get_info_by_plugin(handle, Scratch.intBuf()));
    // Sound extras: tracker music, subsounds, tags, and advanced settings readback
    public static inline function core_sound_get_music_num_channels(handle:Int):Int return Raw.core_sound_get_music_num_channels(handle);
    public static inline function core_sound_set_music_channel_volume(handle:Int, channel:Int, volume:Float):Int return Raw.core_sound_set_music_channel_volume(handle, channel, volume);
    public static inline function core_sound_get_music_channel_volume(handle:Int, channel:Int):Float return Raw.core_sound_get_music_channel_volume(handle, channel);
    public static inline function core_sound_set_music_speed(handle:Int, speed:Float):Int return Raw.core_sound_set_music_speed(handle, speed);
    public static inline function core_sound_get_music_speed(handle:Int):Float return Raw.core_sound_get_music_speed(handle);
    public static inline function core_sound_get_num_sub_sounds(handle:Int):Int return Raw.core_sound_get_num_sub_sounds(handle);
    public static inline function core_sound_get_sub_sound(handle:Int, index:Int):Int return Raw.core_sound_get_sub_sound(handle, index);
    public static inline function core_sound_get_sub_sound_parent(handle:Int):Int return Raw.core_sound_get_sub_sound_parent(handle);
    public static inline function core_sound_get_num_tags(handle:Int):Int return Raw.core_sound_get_num_tags(handle, Scratch.intBuf());
    public static inline function core_sound_get_tag(handle:Int, name:String, index:Int):String return fromBytes(Raw.core_sound_get_tag(handle, toBytes(name), index, Scratch.intBuf(), Scratch.floatBuf()));
    public static inline function core_sound_get_tag_string(handle:Int, name:String, index:Int):String return fromBytes(Raw.core_sound_get_tag_string(handle, toBytes(name), index));
    public static inline function sys_get_advanced_settings():Int return Raw.sys_get_advanced_settings(Scratch.intBuf(), Scratch.floatBuf());
    public static inline function sys_get_studio_advanced_settings():Int return Raw.sys_get_studio_advanced_settings(Scratch.intBuf());

}

@:hlNative("hlaxe_fmod")
private extern class Raw {
    static function sys_is_initialized():Bool;
    static function sys_update():Void;
    static function sys_set_auto_update(enabled:Bool):Void;
    static function sys_last_result():Int;
    static function sys_get_bus(path:hl.Bytes):Int;
    static function sys_get_bus_by_id(guid:hl.Bytes):Int;
    static function sys_get_event(path:hl.Bytes):Int;
    static function sys_get_event_by_id(guid:hl.Bytes):Int;
    static function sys_get_vca(path:hl.Bytes):Int;
    static function sys_get_vca_by_id(guid:hl.Bytes):Int;
    static function sys_get_bank(path:hl.Bytes):Int;
    static function sys_get_bank_by_id(guid:hl.Bytes):Int;
    static function sys_get_bank_count():Int;
    static function sys_get_bank_list(out:hl.Bytes):Int;
    static function sys_lookup_id(path:hl.Bytes):hl.Bytes;
    static function sys_lookup_path(guid:hl.Bytes):hl.Bytes;
    static function sys_get_param_by_name(name:hl.Bytes):Float;
    static function sys_get_param_by_name_final(name:hl.Bytes):Float;
    static function sys_set_param_by_name(name:hl.Bytes, value:Float, ignoreSeekSpeed:Bool):Int;
    static function sys_set_param_by_name_with_label(name:hl.Bytes, label:hl.Bytes, ignoreSeekSpeed:Bool):Int;
    static function sys_get_param_by_id(id1:Int, id2:Int):Float;
    static function sys_get_param_by_id_final(id1:Int, id2:Int):Float;
    static function sys_set_param_by_id(id1:Int, id2:Int, value:Float, ignoreSeekSpeed:Bool):Int;
    static function sys_set_param_by_id_with_label(id1:Int, id2:Int, label:hl.Bytes, ignoreSeekSpeed:Bool):Int;
    static function sys_get_parameter_description_count():Int;
    static function sys_get_parameter_description_by_index(index:Int, fout:hl.Bytes, iout:hl.Bytes):hl.Bytes;
    static function sys_get_parameter_description_by_name(name:hl.Bytes, fout:hl.Bytes, iout:hl.Bytes):hl.Bytes;
    static function sys_get_parameter_label(parameterName:hl.Bytes, labelIndex:Int):hl.Bytes;
    static function sys_get_num_listeners():Int;
    static function sys_set_num_listeners(count:Int):Int;
    static function sys_get_listener_attributes(index:Int, fout:hl.Bytes):Int;
    static function sys_set_listener_attributes(index:Int, f:hl.Bytes):Int;
    static function sys_get_listener_weight(index:Int):Float;
    static function sys_set_listener_weight(index:Int, weight:Float):Int;
    static function sys_load_bank_file(path:hl.Bytes, flags:Int):Int;
    static function sys_unload_all():Int;
    static function sys_flush_commands():Int;
    static function sys_flush_sample_loading():Int;
    static function sys_get_cpu_usage(fout:hl.Bytes):Int;
    static function sys_get_buffer_usage(iout:hl.Bytes, fout:hl.Bytes):Int;
    static function sys_reset_buffer_usage():Int;
    static function sys_get_memory_usage(out:hl.Bytes):Int;
    static function sys_init_ex(numChannels:Int, sampleRate:Int, speakerMode:Int, studioFlags:Int, dspBufferLength:Int, dspNumBuffers:Int, softwareChannels:Int, streamBufferSize:Int, initFlags:Int, maxMPEGCodecs:Int, maxVorbisCodecs:Int, maxFADPCMCodecs:Int, vol0VirtualVol:Float, defaultDecodeBufferSize:Int, profilePort:Int, geometryMaxFadeTime:Int, distanceFilterCenterFreq:Float, randomSeed:Int, commandQueueSize:Int, handleInitialSize:Int, studioUpdatePeriod:Int, idleSampleDataPoolSize:Int, streamingScheduleDelay:Int, encryptionKey:hl.Bytes):Int;
    static function sys_set_debug_level(level:Int):Int;
    static function sys_load_bank_async(path:hl.Bytes):Int;
    static function bus_is_valid(handle:Int):Bool;
    static function bus_get_id(handle:Int):hl.Bytes;
    static function bus_get_path(handle:Int):hl.Bytes;
    static function bus_get_volume(handle:Int):Float;
    static function bus_get_final_volume(handle:Int):Float;
    static function bus_set_volume(handle:Int, volume:Float):Int;
    static function bus_get_paused(handle:Int):Bool;
    static function bus_set_paused(handle:Int, paused:Bool):Int;
    static function bus_get_mute(handle:Int):Bool;
    static function bus_set_mute(handle:Int, mute:Bool):Int;
    static function bus_stop_all_events(handle:Int, stopMode:Int):Int;
    static function bus_get_cpu_usage(handle:Int, out:hl.Bytes):Int;
    static function bus_get_memory_usage(handle:Int, out:hl.Bytes):Int;
    static function vca_is_valid(handle:Int):Bool;
    static function vca_get_id(handle:Int):hl.Bytes;
    static function vca_get_path(handle:Int):hl.Bytes;
    static function vca_get_volume(handle:Int):Float;
    static function vca_get_final_volume(handle:Int):Float;
    static function vca_set_volume(handle:Int, volume:Float):Int;
    static function bank_is_valid(handle:Int):Bool;
    static function bank_get_id(handle:Int):hl.Bytes;
    static function bank_get_path(handle:Int):hl.Bytes;
    static function bank_unload(handle:Int):Int;
    static function bank_load_sample_data(handle:Int):Int;
    static function bank_unload_sample_data(handle:Int):Int;
    static function bank_get_loading_state(handle:Int):Int;
    static function bank_get_sample_loading_state(handle:Int):Int;
    static function bank_get_event_count(handle:Int):Int;
    static function bank_get_event_list(handle:Int, out:hl.Bytes):Int;
    static function bank_get_bus_count(handle:Int):Int;
    static function bank_get_bus_list(handle:Int, out:hl.Bytes):Int;
    static function bank_get_vca_count(handle:Int):Int;
    static function bank_get_vca_list(handle:Int, out:hl.Bytes):Int;
    static function bank_get_string_count(handle:Int):Int;
    static function bank_get_string_info(handle:Int, index:Int):hl.Bytes;
    static function bank_get_string_guid(handle:Int, index:Int):hl.Bytes;
    static function evd_is_valid(handle:Int):Bool;
    static function evd_get_id(handle:Int):hl.Bytes;
    static function evd_get_path(handle:Int):hl.Bytes;
    static function evd_get_length(handle:Int):Int;
    static function evd_get_min_max_distance(handle:Int, fout:hl.Bytes):Int;
    static function evd_get_sound_size(handle:Int):Float;
    static function evd_is_snapshot(handle:Int):Bool;
    static function evd_is_oneshot(handle:Int):Bool;
    static function evd_is_stream(handle:Int):Bool;
    static function evd_is_3d(handle:Int):Bool;
    static function evd_is_doppler_enabled(handle:Int):Bool;
    static function evd_has_sustain_point(handle:Int):Bool;
    static function evd_create_instance(handle:Int):Int;
    static function evd_get_instance_count(handle:Int):Int;
    static function evd_get_instance_list(handle:Int, out:hl.Bytes):Int;
    static function evd_release_all_instances(handle:Int):Int;
    static function evd_load_sample_data(handle:Int):Int;
    static function evd_unload_sample_data(handle:Int):Int;
    static function evd_get_sample_loading_state(handle:Int):Int;
    static function evd_get_parameter_description_count(handle:Int):Int;
    static function evd_get_parameter_description_by_index(handle:Int, index:Int, fout:hl.Bytes, iout:hl.Bytes):hl.Bytes;
    static function evd_get_parameter_description_by_name(handle:Int, name:hl.Bytes, fout:hl.Bytes, iout:hl.Bytes):hl.Bytes;
    static function evd_get_parameter_label(handle:Int, parameterName:hl.Bytes, labelIndex:Int):hl.Bytes;
    static function evd_get_user_property_count(handle:Int):Int;
    static function evd_get_user_property_name(handle:Int, index:Int):hl.Bytes;
    static function evd_get_user_property_type(handle:Int, index:Int):Int;
    static function evd_get_user_property_float(handle:Int, index:Int):Float;
    static function evd_get_user_property_string(handle:Int, index:Int):hl.Bytes;
    static function evi_is_valid(handle:Int):Bool;
    static function evi_get_description(handle:Int):Int;
    static function evi_start(handle:Int):Int;
    static function evi_stop(handle:Int, stopMode:Int):Int;
    static function evi_key_off(handle:Int):Int;
    static function evi_release(handle:Int):Int;
    static function evi_get_playback_state(handle:Int):Int;
    static function evi_get_paused(handle:Int):Bool;
    static function evi_set_paused(handle:Int, paused:Bool):Int;
    static function evi_get_volume(handle:Int):Float;
    static function evi_get_volume_final(handle:Int):Float;
    static function evi_set_volume(handle:Int, volume:Float):Int;
    static function evi_get_pitch(handle:Int):Float;
    static function evi_get_pitch_final(handle:Int):Float;
    static function evi_set_pitch(handle:Int, pitch:Float):Int;
    static function evi_get_timeline_position(handle:Int):Int;
    static function evi_set_timeline_position(handle:Int, positionMs:Int):Int;
    static function evi_is_virtual(handle:Int):Bool;
    static function evi_get_min_max_distance(handle:Int, fout:hl.Bytes):Int;
    static function evi_get_3d_attributes(handle:Int, fout:hl.Bytes):Int;
    static function evi_set_3d_attributes(handle:Int, f:hl.Bytes):Int;
    static function evi_get_listener_mask(handle:Int):Int;
    static function evi_set_listener_mask(handle:Int, mask:Int):Int;
    static function evi_get_property(handle:Int, property:Int):Float;
    static function evi_set_property(handle:Int, property:Int, value:Float):Int;
    static function evi_get_reverb_level(handle:Int, index:Int):Float;
    static function evi_set_reverb_level(handle:Int, index:Int, level:Float):Int;
    static function evi_get_param_by_name(handle:Int, name:hl.Bytes):Float;
    static function evi_get_param_by_name_final(handle:Int, name:hl.Bytes):Float;
    static function evi_set_param_by_name(handle:Int, name:hl.Bytes, value:Float, ignoreSeekSpeed:Bool):Int;
    static function evi_set_param_by_name_with_label(handle:Int, name:hl.Bytes, label:hl.Bytes, ignoreSeekSpeed:Bool):Int;
    static function evi_get_param_by_id(handle:Int, id1:Int, id2:Int):Float;
    static function evi_get_param_by_id_final(handle:Int, id1:Int, id2:Int):Float;
    static function evi_set_param_by_id(handle:Int, id1:Int, id2:Int, value:Float, ignoreSeekSpeed:Bool):Int;
    static function evi_set_param_by_id_with_label(handle:Int, id1:Int, id2:Int, label:hl.Bytes, ignoreSeekSpeed:Bool):Int;
    static function evi_get_cpu_usage(handle:Int, out:hl.Bytes):Int;
    static function evi_get_memory_usage(handle:Int, out:hl.Bytes):Int;
    static function ps_assign(handle:Int, key:hl.Bytes):Int;
    static function ps_clear(handle:Int):Int;
    static function core_create_sound(path:hl.Bytes, mode:Int, openOnly:Bool):Int;
    static function core_release_sound(handle:Int):Int;
    static function core_get_sound_length(handle:Int):Int;
    static function core_pcm_create(sampleRate:Int, channels:Int, ringBytes:Int):Int;
    static function core_pcm_write(handle:Int, data:hl.Bytes, len:Int):Int;
    static function core_pcm_space(handle:Int):Int;
    static function core_pcm_underruns(handle:Int):Int;
    static function core_pcm_play(handle:Int, startPaused:Bool):Int;
    static function core_pcm_release(handle:Int):Int;
    static function chan_set_volume(handle:Int, volume:Float):Int;
    static function chan_get_volume(handle:Int):Float;
    static function chan_set_pitch(handle:Int, pitch:Float):Int;
    static function chan_get_pitch(handle:Int):Float;
    static function chan_set_paused(handle:Int, paused:Bool):Int;
    static function chan_get_paused(handle:Int):Bool;
    static function chan_is_playing(handle:Int):Bool;
    static function chan_stop(handle:Int):Int;
    static function dsp_create_by_type(type:Int):Int;
    static function dsp_release(handle:Int):Int;
    static function dsp_set_param_float(handle:Int, index:Int, value:Float):Int;
    static function dsp_get_param_float(handle:Int, index:Int):Float;
    static function dsp_set_param_int(handle:Int, index:Int, value:Int):Int;
    static function dsp_get_param_int(handle:Int, index:Int):Int;
    static function dsp_set_param_bool(handle:Int, index:Int, value:Bool):Int;
    static function dsp_get_param_bool(handle:Int, index:Int):Bool;
    static function dsp_get_num_params(handle:Int):Int;
    static function dsp_get_type(handle:Int):Int;
    static function dsp_set_bypass(handle:Int, bypass:Bool):Int;
    static function dsp_get_bypass(handle:Int):Bool;
    static function dsp_set_wet_dry_mix(handle:Int, prewet:Float, postwet:Float, dry:Float):Int;
    static function dsp_set_active(handle:Int, active:Bool):Int;
    static function dsp_reset(handle:Int):Int;
    static function dsp_set_metering_enabled(handle:Int, input:Bool, output:Bool):Int;
    static function dsp_get_metering(handle:Int, fbuf:hl.Bytes):Int;
    static function dsp_fft_get_spectrum(handle:Int, fbuf:hl.Bytes, maxBins:Int):Int;
    static function cg_get_master():Int;
    static function cg_create(name:hl.Bytes):Int;
    static function cg_release(handle:Int):Int;
    static function cg_set_volume(handle:Int, volume:Float):Int;
    static function cg_get_volume(handle:Int):Float;
    static function cg_set_pitch(handle:Int, pitch:Float):Int;
    static function cg_get_pitch(handle:Int):Float;
    static function cg_set_mute(handle:Int, mute:Bool):Int;
    static function cg_get_mute(handle:Int):Bool;
    static function cg_set_paused(handle:Int, paused:Bool):Int;
    static function cg_get_paused(handle:Int):Bool;
    static function cg_add_dsp(handle:Int, index:Int, dspHandle:Int):Int;
    static function cg_remove_dsp(handle:Int, dspHandle:Int):Int;
    static function cg_stop(handle:Int):Int;
    static function chan_set_pan(handle:Int, pan:Float):Int;
    static function chan_set_frequency(handle:Int, frequency:Float):Int;
    static function chan_get_frequency(handle:Int):Float;
    static function chan_set_loop_count(handle:Int, loopCount:Int):Int;
    static function chan_get_position(handle:Int):Int;
    static function chan_set_position(handle:Int, positionMs:Int):Int;
    static function chan_set_channel_group(handle:Int, groupHandle:Int):Int;
    static function chan_add_dsp(handle:Int, index:Int, dspHandle:Int):Int;
    static function chan_remove_dsp(handle:Int, dspHandle:Int):Int;
    static function chan_set_3d_attributes(handle:Int, posX:Float, posY:Float, posZ:Float, velX:Float, velY:Float, velZ:Float):Int;
    static function chan_set_3d_min_max(handle:Int, minDist:Float, maxDist:Float):Int;
    static function chan_set_reverb_wet(handle:Int, instance:Int, wet:Float):Int;
    static function bus_lock_channel_group(handle:Int):Int;
    static function bus_unlock_channel_group(handle:Int):Int;
    static function bus_get_channel_group(handle:Int):Int;
    static function sys_play_dsp(dspHandle:Int, startPaused:Bool):Int;
    static function sys_set_reverb_properties(instance:Int, fbuf:hl.Bytes):Int;
    static function sys_get_reverb_properties(instance:Int, fbuf:hl.Bytes):Int;
    static function core_pcm_create_3d(sampleRate:Int, channels:Int, ringBytes:Int):Int;
    static function dsp_add_input(handle:Int, inputHandle:Int, type:Int):Int;
    static function dsp_disconnect_from(handle:Int, inputHandle:Int):Int;
    static function dsp_disconnect_all(handle:Int, inputs:Bool, outputs:Bool):Int;
    static function dsp_get_num_inputs(handle:Int):Int;
    static function dsp_get_num_outputs(handle:Int):Int;
    static function dsp_get_input_dsp(handle:Int, index:Int):Int;
    static function dsp_get_input_connection(handle:Int, index:Int):Int;
    static function dspconn_set_mix(handle:Int, mix:Float):Int;
    static function dspconn_get_mix(handle:Int):Float;
    static function dspconn_get_type(handle:Int):Int;
    static function cg_add_group(handle:Int, childHandle:Int):Int;
    static function cg_get_num_groups(handle:Int):Int;
    static function cg_get_group(handle:Int, index:Int):Int;
    static function cg_get_parent_group(handle:Int):Int;
    static function chan_set_mute(handle:Int, mute:Bool):Int;
    static function chan_get_mute(handle:Int):Bool;
    static function chan_set_low_pass_gain(handle:Int, gain:Float):Int;
    static function chan_set_mode(handle:Int, mode:Int):Int;
    static function chan_set_3d_cone_settings(handle:Int, insideAngle:Float, outsideAngle:Float, outsideVolume:Float):Int;
    static function chan_set_3d_cone_orientation(handle:Int, x:Float, y:Float, z:Float):Int;
    static function chan_set_3d_occlusion(handle:Int, direct:Float, reverb:Float):Int;
    static function chan_get_3d_occlusion(handle:Int, fbuf:hl.Bytes):Int;
    static function chan_set_3d_spread(handle:Int, angle:Float):Int;
    static function chan_set_3d_level(handle:Int, level:Float):Int;
    static function chan_set_3d_doppler_level(handle:Int, level:Float):Int;
    static function chan_set_mix_matrix(handle:Int, fbuf:hl.Bytes, outChannels:Int, inChannels:Int):Int;
    static function chan_get_dsp_clock(handle:Int, fbuf:hl.Bytes):Int;
    static function chan_set_delay(handle:Int, startClock:Float, endClock:Float, stopChannels:Bool):Int;
    static function chan_add_fade_point(handle:Int, clock:Float, volume:Float):Int;
    static function chan_set_fade_point_ramp(handle:Int, clock:Float, volume:Float):Int;
    static function chan_remove_fade_points(handle:Int, startClock:Float, endClock:Float):Int;
    static function cg_get_dsp_clock(handle:Int, fbuf:hl.Bytes):Int;
    static function cg_set_delay(handle:Int, startClock:Float, endClock:Float, stopChannels:Bool):Int;
    static function cg_add_fade_point(handle:Int, clock:Float, volume:Float):Int;
    static function cg_set_fade_point_ramp(handle:Int, clock:Float, volume:Float):Int;
    static function cg_remove_fade_points(handle:Int, startClock:Float, endClock:Float):Int;
    static function sys_create_reverb3d():Int;
    static function r3d_release(handle:Int):Int;
    static function r3d_set_3d_attributes(handle:Int, x:Float, y:Float, z:Float, minDist:Float, maxDist:Float):Int;
    static function r3d_set_properties(handle:Int, fbuf:hl.Bytes):Int;
    static function r3d_get_properties(handle:Int, fbuf:hl.Bytes):Int;
    static function r3d_set_active(handle:Int, active:Bool):Int;
    static function core_create_sound_pcm(data:hl.Bytes, len:Int, sampleRate:Int, channels:Int):Int;
    static function core_play_sound(handle:Int, startPaused:Bool):Int;
    static function sound_set_defaults(handle:Int, frequency:Float, priority:Int):Int;
    static function sound_get_defaults(handle:Int, fbuf:hl.Bytes):Int;
    static function sound_set_loop_points(handle:Int, startMs:Int, endMs:Int):Int;
    static function sound_get_loop_points(handle:Int, ibuf:hl.Bytes):Int;
    static function sound_set_mode(handle:Int, mode:Int):Int;
    static function sound_get_mode(handle:Int):Int;
    static function sound_get_format(handle:Int, ibuf:hl.Bytes):Int;
    static function sound_get_open_state(handle:Int):Int;
    static function sys_get_channels_playing(ibuf:hl.Bytes):Int;
    static function sys_mixer_suspend():Int;
    static function sys_mixer_resume():Int;
    static function sys_get_software_format(ibuf:hl.Bytes):Int;
    static function dsp_get_cpu_usage(handle:Int, ibuf:hl.Bytes):Int;
    static function chan_set_callback(handle:Int, enabled:Bool):Int;
    static function sys_set_callback_mask(mask:Int):Int;
    static function sys_set_studio_callback_mask(mask:Int):Int;
    static function sound_add_sync_point(handle:Int, offsetMs:Int, name:hl.Bytes):Int;
    static function sound_delete_sync_point(handle:Int, index:Int):Int;
    static function sound_get_num_sync_points(handle:Int):Int;
    static function sound_get_sync_point_name(handle:Int, index:Int):hl.Bytes;
    static function sound_get_sync_point_offset(handle:Int, index:Int):Int;
    static function sys_create_sound_group(name:hl.Bytes):Int;
    static function sys_get_master_sound_group():Int;
    static function sg_release(handle:Int):Int;
    static function sg_set_max_audible(handle:Int, maxAudible:Int):Int;
    static function sg_get_max_audible(handle:Int):Int;
    static function sg_set_max_audible_behavior(handle:Int, behavior:Int):Int;
    static function sg_get_max_audible_behavior(handle:Int):Int;
    static function sg_set_mute_fade_speed(handle:Int, speed:Float):Int;
    static function sg_get_num_sounds(handle:Int):Int;
    static function sg_stop(handle:Int):Int;
    static function sound_set_sound_group(handle:Int, groupHandle:Int):Int;
    static function sys_set_3d_settings(doppler:Float, distanceFactor:Float, rolloffScale:Float):Int;
    static function sys_get_3d_settings(fbuf:hl.Bytes):Int;
    static function sys_get_num_drivers():Int;
    static function sys_get_driver_name(id:Int):hl.Bytes;
    static function chan_get_loop_count(handle:Int):Int;
    static function chan_get_low_pass_gain(handle:Int):Float;
    static function chan_get_mode(handle:Int):Int;
    static function chan_get_3d_cone_settings(handle:Int, fbuf:hl.Bytes):Int;
    static function chan_get_3d_spread(handle:Int):Float;
    static function chan_get_3d_level(handle:Int):Float;
    static function chan_get_3d_doppler_level(handle:Int):Float;
    static function chan_get_3d_min_max(handle:Int, fbuf:hl.Bytes):Int;
    static function chan_get_3d_attributes(handle:Int, fbuf:hl.Bytes):Int;
    static function chan_get_delay(handle:Int, fbuf:hl.Bytes):Int;
    static function dsp_get_wet_dry_mix(handle:Int, fbuf:hl.Bytes):Int;
    static function dsp_get_active(handle:Int):Bool;
    static function dsp_get_metering_enabled(handle:Int, ibuf:hl.Bytes):Int;

    static function sys_load_bank_memory(data:hl.Bytes, len:Int):Int;
    static function evi_get_channel_group(handle:Int):Int;
    static function sys_start_command_capture(path:hl.Bytes):Int;
    static function sys_stop_command_capture():Int;
    static function sys_load_command_replay(path:hl.Bytes):Int;
    static function replay_release(handle:Int):Int;
    static function replay_is_valid(handle:Int):Bool;
    static function replay_start(handle:Int):Int;
    static function replay_stop(handle:Int):Int;
    static function replay_set_paused(handle:Int, paused:Bool):Int;
    static function replay_get_paused(handle:Int):Bool;
    static function replay_seek_to_time(handle:Int, timeMs:Int):Int;
    static function replay_get_length(handle:Int):Float;
    static function chan_set_priority(handle:Int, priority:Int):Int;
    static function chan_get_priority(handle:Int):Int;
    static function chan_is_virtual(handle:Int):Bool;
    static function chan_get_audibility(handle:Int):Float;
    static function chan_set_volume_ramp(handle:Int, ramp:Bool):Int;
    static function chan_get_volume_ramp(handle:Int):Bool;
    static function chan_get_current_sound(handle:Int):Int;
    static function chan_set_loop_points(handle:Int, startMs:Int, endMs:Int):Int;
    static function chan_get_loop_points(handle:Int, ibuf:hl.Bytes):Int;
    static function chan_get_reverb_wet(handle:Int, instance:Int):Float;
    static function chan_get_index(handle:Int):Int;
    static function chan_get_3d_cone_orientation(handle:Int, fbuf:hl.Bytes):Int;
    static function chan_get_num_dsps(handle:Int):Int;
    static function chan_get_dsp(handle:Int, index:Int):Int;
    static function sound_get_name(handle:Int):hl.Bytes;
    static function sound_get_sound_group(handle:Int):Int;
    static function sound_get_loop_count(handle:Int):Int;
    static function sound_set_loop_count(handle:Int, loopCount:Int):Int;
    static function sg_set_volume(handle:Int, volume:Float):Int;
    static function sg_get_volume(handle:Int):Float;
    static function sg_get_num_playing(handle:Int):Int;
    static function sg_get_mute_fade_speed(handle:Int):Float;
    static function sys_set_driver(id:Int):Int;
    static function sys_get_driver():Int;
    static function dsp_set_param_data(handle:Int, index:Int, data:hl.Bytes, len:Int):Int;
    static function dsp_get_idle(handle:Int):Bool;
    static function dsp_get_info_name(handle:Int):hl.Bytes;
    static function dsp_get_output_dsp(handle:Int, index:Int):Int;
    static function dsp_get_output_connection(handle:Int, index:Int):Int;
    static function dspconn_get_input_dsp(handle:Int):Int;
    static function dspconn_get_output_dsp(handle:Int):Int;
    static function r3d_get_active(handle:Int):Bool;
    static function r3d_get_3d_attributes(handle:Int, fbuf:hl.Bytes):Int;
    static function cg_set_pan(handle:Int, pan:Float):Int;
    static function cg_set_low_pass_gain(handle:Int, gain:Float):Int;
    static function cg_set_mode(handle:Int, mode:Int):Int;
    static function cg_get_mode(handle:Int):Int;
    static function cg_set_3d_attributes(handle:Int, posX:Float, posY:Float, posZ:Float, velX:Float, velY:Float, velZ:Float):Int;
    static function cg_get_3d_attributes(handle:Int, fbuf:hl.Bytes):Int;
    static function cg_set_3d_min_max(handle:Int, minDist:Float, maxDist:Float):Int;
    static function cg_get_3d_min_max(handle:Int, fbuf:hl.Bytes):Int;
    static function cg_set_3d_occlusion(handle:Int, direct:Float, reverb:Float):Int;
    static function cg_set_3d_level(handle:Int, level:Float):Int;
    static function cg_get_3d_level(handle:Int):Float;
    static function cg_set_3d_spread(handle:Int, angle:Float):Int;
    static function cg_get_3d_spread(handle:Int):Float;
    static function cg_set_3d_doppler_level(handle:Int, level:Float):Int;
    static function cg_get_3d_doppler_level(handle:Int):Float;
    static function cg_set_3d_cone_settings(handle:Int, insideAngle:Float, outsideAngle:Float, outsideVolume:Float):Int;
    static function cg_get_3d_cone_settings(handle:Int, fbuf:hl.Bytes):Int;
    static function cg_set_3d_cone_orientation(handle:Int, x:Float, y:Float, z:Float):Int;
    static function cg_get_3d_cone_orientation(handle:Int, fbuf:hl.Bytes):Int;
    static function cg_set_reverb_wet(handle:Int, instance:Int, wet:Float):Int;
    static function cg_get_reverb_wet(handle:Int, instance:Int):Float;
    static function cg_set_mix_matrix(handle:Int, fbuf:hl.Bytes, outChannels:Int, inChannels:Int):Int;
    static function cg_set_volume_ramp(handle:Int, ramp:Bool):Int;
    static function cg_get_volume_ramp(handle:Int):Bool;
    static function cg_get_audibility(handle:Int):Float;
    static function cg_get_name(handle:Int):hl.Bytes;
    static function cg_get_num_channels(handle:Int):Int;
    static function cg_get_channel(handle:Int, index:Int):Int;
    static function evi_set_callback_mask(handle:Int, mask:Int):Int;
    static function cb_next():Bool;
    static function cb_handle():Int;
    static function cb_type():Int;
    static function cb_int(index:Int):Int;
    static function cb_float():Float;
    static function cb_string():hl.Bytes;
    static function cb_take_overflow():Bool;
    static function chan_set_3d_distance_filter(handle:Int, custom:Bool, customLevel:Float, centerFreq:Float):Int;
    static function chan_get_3d_distance_filter(handle:Int, fbuf:hl.Bytes):Int;
    static function cg_set_3d_distance_filter(handle:Int, custom:Bool, customLevel:Float, centerFreq:Float):Int;
    static function cg_get_3d_distance_filter(handle:Int, fbuf:hl.Bytes):Int;
    static function sys_get_version():hl.Bytes;
    static function core_sound_read_data(handle:Int, data:hl.Bytes, len:Int):Int;
    static function core_sound_seek_data(handle:Int, pcm:Int):Int;
    static function sys_get_record_num_drivers(ibuf:hl.Bytes):Int;
    static function sys_get_record_driver_info(id:Int, ibuf:hl.Bytes):hl.Bytes;
    static function core_create_record_sound(sampleRate:Int, channels:Int, seconds:Int):Int;
    static function sys_record_start(id:Int, soundHandle:Int, loop:Bool):Int;
    static function sys_record_stop(id:Int):Int;
    static function sys_is_recording(id:Int):Bool;
    static function sys_get_record_position(id:Int):Int;
    // Custom 3D rolloff and geometry
    static function chan_set_3d_custom_rolloff(handle:Int, data:hl.Bytes, count:Int):Int;
    static function chan_get_3d_custom_rolloff(handle:Int, fbuf:hl.Bytes):Int;
    static function cg_set_3d_custom_rolloff(handle:Int, data:hl.Bytes, count:Int):Int;
    static function cg_get_3d_custom_rolloff(handle:Int, fbuf:hl.Bytes):Int;
    static function core_sound_set_3d_custom_rolloff(handle:Int, data:hl.Bytes, count:Int):Int;
    static function core_sound_get_3d_custom_rolloff(handle:Int, fbuf:hl.Bytes):Int;
    static function sys_create_geometry(maxPolygons:Int, maxVertices:Int):Int;
    static function sys_set_geometry_settings(maxWorldSize:Float):Int;
    static function sys_get_geometry_settings():Float;
    static function sys_get_geometry_occlusion(lx:Float, ly:Float, lz:Float, sx:Float, sy:Float, sz:Float, fbuf:hl.Bytes):Int;
    static function sys_load_geometry(data:hl.Bytes, len:Int):Int;
    static function geo_release(handle:Int):Int;
    static function geo_add_polygon(handle:Int, direct:Float, reverb:Float, doubleSided:Bool, vertices:hl.Bytes, count:Int):Int;
    static function geo_get_num_polygons(handle:Int):Int;
    static function geo_get_max_polygons(handle:Int, ibuf:hl.Bytes):Int;
    static function geo_get_polygon_num_vertices(handle:Int, index:Int):Int;
    static function geo_set_polygon_vertex(handle:Int, index:Int, vertexIndex:Int, x:Float, y:Float, z:Float):Int;
    static function geo_get_polygon_vertex(handle:Int, index:Int, vertexIndex:Int, fbuf:hl.Bytes):Int;
    static function geo_set_polygon_attributes(handle:Int, index:Int, direct:Float, reverb:Float, doubleSided:Bool):Int;
    static function geo_get_polygon_attributes(handle:Int, index:Int, fbuf:hl.Bytes):Int;
    static function geo_set_active(handle:Int, active:Bool):Int;
    static function geo_get_active(handle:Int):Bool;
    static function geo_set_rotation(handle:Int, fx:Float, fy:Float, fz:Float, ux:Float, uy:Float, uz:Float):Int;
    static function geo_get_rotation(handle:Int, fbuf:hl.Bytes):Int;
    static function geo_set_position(handle:Int, x:Float, y:Float, z:Float):Int;
    static function geo_get_position(handle:Int, fbuf:hl.Bytes):Int;
    static function geo_set_scale(handle:Int, x:Float, y:Float, z:Float):Int;
    static function geo_get_scale(handle:Int, fbuf:hl.Bytes):Int;
    static function geo_save(handle:Int, data:hl.Bytes, len:Int):Int;

    static function core_sound_set_3d_cone_settings(handle:Int, inside:Float, outside:Float, outsideVolume:Float):Int;
    static function core_sound_get_3d_cone_settings(handle:Int, fbuf:hl.Bytes):Int;
    static function core_sound_set_3d_min_max(handle:Int, minDistance:Float, maxDistance:Float):Int;
    static function core_sound_get_3d_min_max(handle:Int, fbuf:hl.Bytes):Int;
    static function chan_set_dsp_index(handle:Int, dsp:Int, index:Int):Int;
    static function chan_get_dsp_index(handle:Int, dsp:Int):Int;
    static function chan_get_fade_points(handle:Int, fbuf:hl.Bytes):Int;
    static function chan_get_mix_matrix(handle:Int, fbuf:hl.Bytes, ibuf:hl.Bytes, outChannels:Int, inChannels:Int):Int;
    static function chan_get_channel_group(handle:Int):Int;
    static function cg_set_dsp_index(handle:Int, dsp:Int, index:Int):Int;
    static function cg_get_dsp_index(handle:Int, dsp:Int):Int;
    static function cg_get_fade_points(handle:Int, fbuf:hl.Bytes):Int;
    static function cg_get_mix_matrix(handle:Int, fbuf:hl.Bytes, ibuf:hl.Bytes, outChannels:Int, inChannels:Int):Int;
    static function sg_get_name(handle:Int):hl.Bytes;
    static function sg_get_sound(handle:Int, index:Int):Int;
    static function sys_get_channel(index:Int):Int;
    static function sys_get_output():Int;
    static function sys_get_speaker_mode_channels(mode:Int):Int;
    static function sys_get_default_mix_matrix(sourceMode:Int, targetMode:Int, hop:Int, fbuf:hl.Bytes):Int;
    static function dsp_get_parameter_info(handle:Int, index:Int, fbuf:hl.Bytes, ibuf:hl.Bytes):hl.Bytes;
    static function dsp_get_data_parameter_index(handle:Int, dataType:Int):Int;
    static function dsp_set_channel_format(handle:Int, mask:Int, channels:Int, speakerMode:Int):Int;
    static function dsp_get_channel_format(handle:Int, ibuf:hl.Bytes):Int;
    static function dsp_get_output_channel_format(handle:Int, inMask:Int, inChannels:Int, inMode:Int, ibuf:hl.Bytes):Int;
    static function conn_set_mix_matrix(handle:Int, fbuf:hl.Bytes, outChannels:Int, inChannels:Int):Int;
    static function conn_get_mix_matrix(handle:Int, fbuf:hl.Bytes, ibuf:hl.Bytes, outChannels:Int, inChannels:Int):Int;

    static function debug_live_handle_count():Int;
    static function binding_abi_version():Int;

    static function replay_get_command_count(handle:Int):Int;
    static function replay_get_command_info(handle:Int, index:Int, ibuf:hl.Bytes, fbuf:hl.Bytes):hl.Bytes;
    static function replay_get_command_string(handle:Int, index:Int):hl.Bytes;
    static function replay_get_command_at_time(handle:Int, seconds:Float):Int;
    static function replay_seek_to_command(handle:Int, index:Int):Int;
    static function replay_get_playback_state(handle:Int):Int;
    static function replay_set_bank_path(handle:Int, path:hl.Bytes):Int;
    static function sys_lock_dsp():Int;
    static function sys_unlock_dsp():Int;
    static function sys_get_sound_info(key:hl.Bytes, ibuf:hl.Bytes):hl.Bytes;
    static function sys_get_memory_stats(blocking:Bool, ibuf:hl.Bytes):Int;
    static function sys_get_file_usage(fbuf:hl.Bytes):Int;
    static function sys_set_network_proxy(proxy:hl.Bytes):Int;
    static function sys_get_network_proxy():hl.Bytes;
    static function sys_set_network_timeout(timeoutMs:Int):Int;
    static function sys_get_network_timeout():Int;
    static function sys_set_speaker_position(speaker:Int, x:Float, y:Float, active:Bool):Int;
    static function sys_get_speaker_position(speaker:Int, fbuf:hl.Bytes):Int;
    static function sys_set_plugin_path(path:hl.Bytes):Int;
    static function sys_load_plugin(path:hl.Bytes, priority:Int):Int;
    static function sys_unload_plugin(handle:Int):Int;
    static function sys_get_num_plugins(type:Int):Int;
    static function sys_get_plugin_handle(type:Int, index:Int):Int;
    static function sys_get_plugin_info(handle:Int, ibuf:hl.Bytes):hl.Bytes;
    static function sys_get_num_nested_plugins(handle:Int):Int;
    static function sys_get_nested_plugin(handle:Int, index:Int):Int;
    static function dsp_create_by_plugin(pluginHandle:Int):Int;
    static function dsp_get_info_by_plugin(handle:Int, ibuf:hl.Bytes):hl.Bytes;
    // Sound extras: tracker music, subsounds, tags, and advanced settings readback
    static function core_sound_get_music_num_channels(handle:Int):Int;
    static function core_sound_set_music_channel_volume(handle:Int, channel:Int, volume:Float):Int;
    static function core_sound_get_music_channel_volume(handle:Int, channel:Int):Float;
    static function core_sound_set_music_speed(handle:Int, speed:Float):Int;
    static function core_sound_get_music_speed(handle:Int):Float;
    static function core_sound_get_num_sub_sounds(handle:Int):Int;
    static function core_sound_get_sub_sound(handle:Int, index:Int):Int;
    static function core_sound_get_sub_sound_parent(handle:Int):Int;
    static function core_sound_get_num_tags(handle:Int, ibuf:hl.Bytes):Int;
    static function core_sound_get_tag(handle:Int, name:hl.Bytes, index:Int, ibuf:hl.Bytes, fbuf:hl.Bytes):hl.Bytes;
    static function core_sound_get_tag_string(handle:Int, name:hl.Bytes, index:Int):hl.Bytes;
    static function sys_get_advanced_settings(ibuf:hl.Bytes, fbuf:hl.Bytes):Int;
    static function sys_get_studio_advanced_settings(ibuf:hl.Bytes):Int;

}
#end
