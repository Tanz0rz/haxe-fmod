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

    // System
    public static function sys_last_result():Int return ERR_UNSUPPORTED;
    public static function sys_get_bus(path:String):Int return 0;
    public static function sys_get_bus_by_id(guid:String):Int return 0;
    public static function sys_get_event(path:String):Int return 0;
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
    public static function sys_set_listener_attributes(index:Int, px:Float, py:Float, pz:Float, vx:Float, vy:Float, vz:Float, fx:Float, fy:Float, fz:Float, ux:Float, uy:Float, uz:Float):Int return ERR_UNSUPPORTED;
    public static function sys_get_listener_weight(index:Int):Float return 0.0;
    public static function sys_set_listener_weight(index:Int, weight:Float):Int return ERR_UNSUPPORTED;
    public static function sys_load_bank_file(path:String, flags:Int):Int return 0;
    public static function sys_unload_all():Int return ERR_UNSUPPORTED;
    public static function sys_flush_commands():Int return ERR_UNSUPPORTED;
    public static function sys_flush_sample_loading():Int return ERR_UNSUPPORTED;
    public static function sys_get_cpu_usage():Int return ERR_UNSUPPORTED;
    public static function sys_get_buffer_usage():Int return ERR_UNSUPPORTED;
    public static function sys_reset_buffer_usage():Int return ERR_UNSUPPORTED;
    public static function sys_get_memory_usage():Int return ERR_UNSUPPORTED;
    public static function sys_init_ex(numChannels:Int, sampleRate:Int, speakerMode:Int, studioFlags:Int):Int return ERR_UNSUPPORTED;
    public static function sys_set_debug_level(level:Int):Int return ERR_UNSUPPORTED;
    public static function sys_load_bank_async(path:String):Int return 0;
    public static function sys_is_initialized():Bool return false;
    public static function sys_update():Void {}
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
    public static function bank_is_valid(handle:Int):Bool return false;
    public static function bank_get_id(handle:Int):String return "";
    public static function bank_get_path(handle:Int):String return "";
    public static function bank_unload(handle:Int):Int return ERR_UNSUPPORTED;
    public static function bank_load_sample_data(handle:Int):Int return ERR_UNSUPPORTED;
    public static function bank_unload_sample_data(handle:Int):Int return ERR_UNSUPPORTED;
    public static function bank_get_loading_state(handle:Int):Int return 1;
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
    public static function evd_create_instance(handle:Int):Int return 0;
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
    public static function evi_is_valid(handle:Int):Bool return false;
    public static function evi_get_description(handle:Int):Int return 0;
    public static function evi_start(handle:Int):Int return ERR_UNSUPPORTED;
    public static function evi_stop(handle:Int, stopMode:Int):Int return ERR_UNSUPPORTED;
    public static function evi_key_off(handle:Int):Int return ERR_UNSUPPORTED;
    public static function evi_release(handle:Int):Int return ERR_UNSUPPORTED;
    public static function evi_get_playback_state(handle:Int):Int return 2;
    public static function evi_get_paused(handle:Int):Bool return false;
    public static function evi_set_paused(handle:Int, paused:Bool):Int return ERR_UNSUPPORTED;
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
    public static function ps_clear(handle:Int):Int return ERR_UNSUPPORTED;

    // Core API micro subset
    public static function core_create_sound(path:String, mode:Int):Int return 0;
    public static function core_release_sound(handle:Int):Int return ERR_UNSUPPORTED;
    public static function core_get_sound_length(handle:Int):Int return -1;

    // Core PCM streams
    public static function core_pcm_create(sampleRate:Int, channels:Int, ringBytes:Int):Int return 0;
    public static function core_pcm_write(handle:Int, data:haxe.io.Bytes, len:Int):Int return 0;
    public static function core_pcm_space(handle:Int):Int return 0;
    public static function core_pcm_underruns(handle:Int):Int return 0;
    public static function core_pcm_play(handle:Int, startPaused:Bool):Int return 0;
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

    // Callbacks
    public static function evi_set_callback_mask(handle:Int, mask:Int):Int return ERR_UNSUPPORTED;
    public static function cb_next():Bool return false;
    public static function cb_handle():Int return 0;
    public static function cb_type():Int return 0;
    public static function cb_int(index:Int):Int return 0;
    public static function cb_float():Float return 0.0;
    public static function cb_string():String return "";
    public static function cb_take_overflow():Bool return false;

    // Debug
    public static function debug_live_handle_count():Int return 0;
    public static function binding_abi_version():Int return 0;
}
