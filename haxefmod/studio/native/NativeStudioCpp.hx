package haxefmod.studio.native;

#if cpp
/**
 * C++ (hxcpp) backend for the FMOD Studio bindings.
 * Converts const char* returns to Haxe String at the boundary. raw functions
 * live in linc_faxe.cpp.
 *
 * This class carries the linc build wiring (LincBuild adds the @:buildXml
 * meta pointing at native/faxe/linc_faxe.xml), so compiling it is what makes
 * hxcpp build and link linc_faxe.cpp into the host project.
 */
@:keep
#if !display
@:build(haxefmod.studio.native.LincBuild.touch())
@:build(haxefmod.studio.native.LincBuild.xml('faxe', '../../../'))
#end
@:cppInclude('linc_faxe.h')
class NativeStudioCpp {
    // System
    public static inline function sys_last_result():Int return Raw.sys_last_result();
    public static inline function sys_get_bus(path:String):Int return Raw.sys_get_bus(path);
    public static inline function sys_get_bus_by_id(guid:String):Int return Raw.sys_get_bus_by_id(guid);
    public static inline function sys_get_event(path:String):Int return Raw.sys_get_event(path);
    public static inline function sys_get_event_by_id(guid:String):Int return Raw.sys_get_event_by_id(guid);
    public static inline function sys_get_vca(path:String):Int return Raw.sys_get_vca(path);
    public static inline function sys_get_vca_by_id(guid:String):Int return Raw.sys_get_vca_by_id(guid);
    public static inline function sys_get_bank(path:String):Int return Raw.sys_get_bank(path);
    public static inline function sys_get_bank_by_id(guid:String):Int return Raw.sys_get_bank_by_id(guid);
    public static inline function sys_get_bank_count():Int return Raw.sys_get_bank_count();

    /** Fills Scratch int buffer with bank handles, returns the count written */
    public static inline function sys_get_bank_list():Int return Raw.sys_get_bank_list(Scratch.intBuf());

    public static inline function sys_lookup_id(path:String):String return Raw.sys_lookup_id(path).toString();
    public static inline function sys_lookup_path(guid:String):String return Raw.sys_lookup_path(guid).toString();
    public static inline function sys_get_param_by_name(name:String):Float return Raw.sys_get_param_by_name(name);
    public static inline function sys_get_param_by_name_final(name:String):Float return Raw.sys_get_param_by_name_final(name);
    public static inline function sys_set_param_by_name(name:String, value:Float, ignoreSeekSpeed:Bool):Int return Raw.sys_set_param_by_name(name, value, ignoreSeekSpeed);
    public static inline function sys_set_param_by_name_with_label(name:String, label:String, ignoreSeekSpeed:Bool):Int return Raw.sys_set_param_by_name_with_label(name, label, ignoreSeekSpeed);
    public static inline function sys_get_param_by_id(id1:Int, id2:Int):Float return Raw.sys_get_param_by_id(id1, id2);
    public static inline function sys_get_param_by_id_final(id1:Int, id2:Int):Float return Raw.sys_get_param_by_id_final(id1, id2);
    public static inline function sys_set_param_by_id(id1:Int, id2:Int, value:Float, ignoreSeekSpeed:Bool):Int return Raw.sys_set_param_by_id(id1, id2, value, ignoreSeekSpeed);
    public static inline function sys_set_param_by_id_with_label(id1:Int, id2:Int, label:String, ignoreSeekSpeed:Bool):Int return Raw.sys_set_param_by_id_with_label(id1, id2, label, ignoreSeekSpeed);
    public static inline function sys_get_parameter_description_count():Int return Raw.sys_get_parameter_description_count();

    /** Returns param name. Fills Scratch float buffer: [0]=min, [1]=max, [2]=default. int buffer: [0]=type, [1]=flags, [2]=id1, [3]=id2 */
    public static inline function sys_get_parameter_description_by_index(index:Int):String return Raw.sys_get_parameter_description_by_index(index, Scratch.floatBuf(), Scratch.intBuf()).toString();

    /** Returns param name. Fills Scratch float buffer: [0]=min, [1]=max, [2]=default. int buffer: [0]=type, [1]=flags, [2]=id1, [3]=id2 */
    public static inline function sys_get_parameter_description_by_name(name:String):String return Raw.sys_get_parameter_description_by_name(name, Scratch.floatBuf(), Scratch.intBuf()).toString();

    public static inline function sys_get_parameter_label(parameterName:String, labelIndex:Int):String return Raw.sys_get_parameter_label(parameterName, labelIndex).toString();
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
    public static inline function sys_load_bank_file(path:String, flags:Int):Int return Raw.sys_load_bank_file(path, flags);
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

    public static inline function sys_init_ex(numChannels:Int, sampleRate:Int, speakerMode:Int, studioFlags:Int):Int return Raw.sys_init_ex(numChannels, sampleRate, speakerMode, studioFlags);
    public static inline function sys_set_debug_level(level:Int):Int return Raw.sys_set_debug_level(level);
    public static inline function sys_load_bank_async(path:String):Int return Raw.sys_load_bank_async(path);
    public static inline function sys_is_initialized():Bool return Raw.is_initialized();
    public static inline function sys_update():Void Raw.update();
    public static inline function sys_set_auto_update(enabled:Bool):Void Raw.set_auto_update(enabled);

    // Bus
    public static inline function bus_is_valid(handle:Int):Bool return Raw.bus_is_valid(handle);
    public static inline function bus_get_id(handle:Int):String return Raw.bus_get_id(handle).toString();
    public static inline function bus_get_path(handle:Int):String return Raw.bus_get_path(handle).toString();
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
    public static inline function vca_get_id(handle:Int):String return Raw.vca_get_id(handle).toString();
    public static inline function vca_get_path(handle:Int):String return Raw.vca_get_path(handle).toString();
    public static inline function vca_get_volume(handle:Int):Float return Raw.vca_get_volume(handle);
    public static inline function vca_get_final_volume(handle:Int):Float return Raw.vca_get_final_volume(handle);
    public static inline function vca_set_volume(handle:Int, volume:Float):Int return Raw.vca_set_volume(handle, volume);

    // Bank
    public static inline function bank_is_valid(handle:Int):Bool return Raw.bank_is_valid(handle);
    public static inline function bank_get_id(handle:Int):String return Raw.bank_get_id(handle).toString();
    public static inline function bank_get_path(handle:Int):String return Raw.bank_get_path(handle).toString();
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
    public static inline function bank_get_string_info(handle:Int, index:Int):String return Raw.bank_get_string_info(handle, index).toString();
    public static inline function bank_get_string_guid(handle:Int, index:Int):String return Raw.bank_get_string_guid(handle, index).toString();

    // EventDescription
    public static inline function evd_is_valid(handle:Int):Bool return Raw.evd_is_valid(handle);
    public static inline function evd_get_id(handle:Int):String return Raw.evd_get_id(handle).toString();
    public static inline function evd_get_path(handle:Int):String return Raw.evd_get_path(handle).toString();
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
    public static inline function evd_get_parameter_description_by_index(handle:Int, index:Int):String return Raw.evd_get_parameter_description_by_index(handle, index, Scratch.floatBuf(), Scratch.intBuf()).toString();

    /** Returns param name. Fills Scratch float buffer: [0]=min, [1]=max, [2]=default. int buffer: [0]=type, [1]=flags, [2]=id1, [3]=id2 */
    public static inline function evd_get_parameter_description_by_name(handle:Int, name:String):String return Raw.evd_get_parameter_description_by_name(handle, name, Scratch.floatBuf(), Scratch.intBuf()).toString();

    public static inline function evd_get_parameter_label(handle:Int, parameterName:String, labelIndex:Int):String return Raw.evd_get_parameter_label(handle, parameterName, labelIndex).toString();
    public static inline function evd_get_user_property_count(handle:Int):Int return Raw.evd_get_user_property_count(handle);
    public static inline function evd_get_user_property_name(handle:Int, index:Int):String return Raw.evd_get_user_property_name(handle, index).toString();
    public static inline function evd_get_user_property_type(handle:Int, index:Int):Int return Raw.evd_get_user_property_type(handle, index);
    public static inline function evd_get_user_property_float(handle:Int, index:Int):Float return Raw.evd_get_user_property_float(handle, index);
    public static inline function evd_get_user_property_string(handle:Int, index:Int):String return Raw.evd_get_user_property_string(handle, index).toString();

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
    public static inline function evi_get_param_by_name(handle:Int, name:String):Float return Raw.evi_get_param_by_name(handle, name);
    public static inline function evi_get_param_by_name_final(handle:Int, name:String):Float return Raw.evi_get_param_by_name_final(handle, name);
    public static inline function evi_set_param_by_name(handle:Int, name:String, value:Float, ignoreSeekSpeed:Bool):Int return Raw.evi_set_param_by_name(handle, name, value, ignoreSeekSpeed);
    public static inline function evi_set_param_by_name_with_label(handle:Int, name:String, label:String, ignoreSeekSpeed:Bool):Int return Raw.evi_set_param_by_name_with_label(handle, name, label, ignoreSeekSpeed);
    public static inline function evi_get_param_by_id(handle:Int, id1:Int, id2:Int):Float return Raw.evi_get_param_by_id(handle, id1, id2);
    public static inline function evi_get_param_by_id_final(handle:Int, id1:Int, id2:Int):Float return Raw.evi_get_param_by_id_final(handle, id1, id2);
    public static inline function evi_set_param_by_id(handle:Int, id1:Int, id2:Int, value:Float, ignoreSeekSpeed:Bool):Int return Raw.evi_set_param_by_id(handle, id1, id2, value, ignoreSeekSpeed);
    public static inline function evi_set_param_by_id_with_label(handle:Int, id1:Int, id2:Int, label:String, ignoreSeekSpeed:Bool):Int return Raw.evi_set_param_by_id_with_label(handle, id1, id2, label, ignoreSeekSpeed);

    /** Fills Scratch int buffer: [0]=exclusive, [1]=inclusive (microseconds) */
    public static inline function evi_get_cpu_usage(handle:Int):Int return Raw.evi_get_cpu_usage(handle, Scratch.intBuf());

    /** Fills Scratch int buffer: [0]=exclusive, [1]=inclusive, [2]=sampledata (bytes) */
    public static inline function evi_get_memory_usage(handle:Int):Int return Raw.evi_get_memory_usage(handle, Scratch.intBuf());

    // Programmer sounds
    public static inline function ps_assign(handle:Int, key:String):Int return Raw.ps_assign(handle, key);
    public static inline function ps_clear(handle:Int):Int return Raw.ps_clear(handle);

    // Core API micro subset
    public static inline function core_create_sound(path:String, mode:Int):Int return Raw.core_create_sound(path, mode);
    public static inline function core_release_sound(handle:Int):Int return Raw.core_release_sound(handle);
    public static inline function core_get_sound_length(handle:Int):Int return Raw.core_get_sound_length(handle);

    // Core PCM streams
    public static inline function core_pcm_create(sampleRate:Int, channels:Int, ringBytes:Int):Int return Raw.core_pcm_create(sampleRate, channels, ringBytes);
    public static inline function core_pcm_write(handle:Int, data:haxe.io.Bytes, len:Int):Int return Raw.core_pcm_write(handle, data.getData(), len);
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
    public static inline function cg_create(name:String):Int return Raw.cg_create(name);
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
    public static inline function core_create_sound_pcm(data:haxe.io.Bytes, len:Int, sampleRate:Int, channels:Int):Int return Raw.core_create_sound_pcm(data.getData(), len, sampleRate, channels);
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

    // Callbacks
    public static inline function evi_set_callback_mask(handle:Int, mask:Int):Int return Raw.evi_set_callback_mask(handle, mask);
    public static inline function cb_next():Bool return Raw.cb_next();
    public static inline function cb_handle():Int return Raw.cb_handle();
    public static inline function cb_type():Int return Raw.cb_type();
    public static inline function cb_int(index:Int):Int return Raw.cb_int(index);
    public static inline function cb_float():Float return Raw.cb_float();
    public static inline function cb_string():String return Raw.cb_string().toString();
    public static inline function cb_take_overflow():Bool return Raw.cb_take_overflow();

    // Debug
    public static inline function debug_live_handle_count():Int return Raw.debug_live_handle_count();
    public static inline function binding_abi_version():Int return Raw.binding_abi_version();
}

@:keep
@:include("linc_faxe.h")
private extern class Raw {
    @:native("linc::faxe::fmod_is_initialized")
    static function is_initialized():Bool;

    @:native("linc::faxe::fmod_update")
    static function update():Void;

    @:native("linc::faxe::fmod_set_auto_update")
    static function set_auto_update(enabled:Bool):Void;

    @:native("linc::faxe::fmod_sys_last_result")
    static function sys_last_result():Int;

    @:native("linc::faxe::fmod_sys_get_bus")
    static function sys_get_bus(path:String):Int;

    @:native("linc::faxe::fmod_sys_get_bus_by_id")
    static function sys_get_bus_by_id(guid:String):Int;

    @:native("linc::faxe::fmod_sys_get_event")
    static function sys_get_event(path:String):Int;

    @:native("linc::faxe::fmod_sys_get_event_by_id")
    static function sys_get_event_by_id(guid:String):Int;

    @:native("linc::faxe::fmod_sys_get_vca")
    static function sys_get_vca(path:String):Int;

    @:native("linc::faxe::fmod_sys_get_vca_by_id")
    static function sys_get_vca_by_id(guid:String):Int;

    @:native("linc::faxe::fmod_sys_get_bank")
    static function sys_get_bank(path:String):Int;

    @:native("linc::faxe::fmod_sys_get_bank_by_id")
    static function sys_get_bank_by_id(guid:String):Int;

    @:native("linc::faxe::fmod_sys_get_bank_count")
    static function sys_get_bank_count():Int;

    @:native("linc::faxe::fmod_sys_get_bank_list")
    static function sys_get_bank_list(out:Array<Int>):Int;

    @:native("linc::faxe::fmod_sys_lookup_id")
    static function sys_lookup_id(path:String):cpp.ConstCharStar;

    @:native("linc::faxe::fmod_sys_lookup_path")
    static function sys_lookup_path(guid:String):cpp.ConstCharStar;

    @:native("linc::faxe::fmod_sys_get_param_by_name")
    static function sys_get_param_by_name(name:String):Float;

    @:native("linc::faxe::fmod_sys_get_param_by_name_final")
    static function sys_get_param_by_name_final(name:String):Float;

    @:native("linc::faxe::fmod_sys_set_param_by_name")
    static function sys_set_param_by_name(name:String, value:Float, ignoreSeekSpeed:Bool):Int;

    @:native("linc::faxe::fmod_sys_set_param_by_name_with_label")
    static function sys_set_param_by_name_with_label(name:String, label:String, ignoreSeekSpeed:Bool):Int;

    @:native("linc::faxe::fmod_sys_get_param_by_id")
    static function sys_get_param_by_id(id1:Int, id2:Int):Float;

    @:native("linc::faxe::fmod_sys_get_param_by_id_final")
    static function sys_get_param_by_id_final(id1:Int, id2:Int):Float;

    @:native("linc::faxe::fmod_sys_set_param_by_id")
    static function sys_set_param_by_id(id1:Int, id2:Int, value:Float, ignoreSeekSpeed:Bool):Int;

    @:native("linc::faxe::fmod_sys_set_param_by_id_with_label")
    static function sys_set_param_by_id_with_label(id1:Int, id2:Int, label:String, ignoreSeekSpeed:Bool):Int;

    @:native("linc::faxe::fmod_sys_get_parameter_description_count")
    static function sys_get_parameter_description_count():Int;

    @:native("linc::faxe::fmod_sys_get_parameter_description_by_index")
    static function sys_get_parameter_description_by_index(index:Int, fout:Array<Float>, iout:Array<Int>):cpp.ConstCharStar;

    @:native("linc::faxe::fmod_sys_get_parameter_description_by_name")
    static function sys_get_parameter_description_by_name(name:String, fout:Array<Float>, iout:Array<Int>):cpp.ConstCharStar;

    @:native("linc::faxe::fmod_sys_get_parameter_label")
    static function sys_get_parameter_label(parameterName:String, labelIndex:Int):cpp.ConstCharStar;

    @:native("linc::faxe::fmod_sys_get_num_listeners")
    static function sys_get_num_listeners():Int;

    @:native("linc::faxe::fmod_sys_set_num_listeners")
    static function sys_set_num_listeners(count:Int):Int;

    @:native("linc::faxe::fmod_sys_get_listener_attributes")
    static function sys_get_listener_attributes(index:Int, fout:Array<Float>):Int;

    @:native("linc::faxe::fmod_sys_set_listener_attributes")
    static function sys_set_listener_attributes(index:Int, f:Array<Float>):Int;

    @:native("linc::faxe::fmod_sys_get_listener_weight")
    static function sys_get_listener_weight(index:Int):Float;

    @:native("linc::faxe::fmod_sys_set_listener_weight")
    static function sys_set_listener_weight(index:Int, weight:Float):Int;

    @:native("linc::faxe::fmod_sys_load_bank_file")
    static function sys_load_bank_file(path:String, flags:Int):Int;

    @:native("linc::faxe::fmod_sys_unload_all")
    static function sys_unload_all():Int;

    @:native("linc::faxe::fmod_sys_flush_commands")
    static function sys_flush_commands():Int;

    @:native("linc::faxe::fmod_sys_flush_sample_loading")
    static function sys_flush_sample_loading():Int;

    @:native("linc::faxe::fmod_sys_get_cpu_usage")
    static function sys_get_cpu_usage(fout:Array<Float>):Int;

    @:native("linc::faxe::fmod_sys_get_buffer_usage")
    static function sys_get_buffer_usage(iout:Array<Int>, fout:Array<Float>):Int;

    @:native("linc::faxe::fmod_sys_reset_buffer_usage")
    static function sys_reset_buffer_usage():Int;

    @:native("linc::faxe::fmod_sys_get_memory_usage")
    static function sys_get_memory_usage(out:Array<Int>):Int;

    @:native("linc::faxe::fmod_sys_init_ex")
    static function sys_init_ex(numChannels:Int, sampleRate:Int, speakerMode:Int, studioFlags:Int):Int;

    @:native("linc::faxe::fmod_sys_set_debug_level")
    static function sys_set_debug_level(level:Int):Int;

    @:native("linc::faxe::fmod_sys_load_bank_async")
    static function sys_load_bank_async(path:String):Int;

    @:native("linc::faxe::fmod_bus_is_valid")
    static function bus_is_valid(handle:Int):Bool;

    @:native("linc::faxe::fmod_bus_get_id")
    static function bus_get_id(handle:Int):cpp.ConstCharStar;

    @:native("linc::faxe::fmod_bus_get_path")
    static function bus_get_path(handle:Int):cpp.ConstCharStar;

    @:native("linc::faxe::fmod_bus_get_volume")
    static function bus_get_volume(handle:Int):Float;

    @:native("linc::faxe::fmod_bus_get_final_volume")
    static function bus_get_final_volume(handle:Int):Float;

    @:native("linc::faxe::fmod_bus_set_volume")
    static function bus_set_volume(handle:Int, volume:Float):Int;

    @:native("linc::faxe::fmod_bus_get_paused")
    static function bus_get_paused(handle:Int):Bool;

    @:native("linc::faxe::fmod_bus_set_paused")
    static function bus_set_paused(handle:Int, paused:Bool):Int;

    @:native("linc::faxe::fmod_bus_get_mute")
    static function bus_get_mute(handle:Int):Bool;

    @:native("linc::faxe::fmod_bus_set_mute")
    static function bus_set_mute(handle:Int, mute:Bool):Int;

    @:native("linc::faxe::fmod_bus_stop_all_events")
    static function bus_stop_all_events(handle:Int, stopMode:Int):Int;

    @:native("linc::faxe::fmod_bus_get_cpu_usage")
    static function bus_get_cpu_usage(handle:Int, out:Array<Int>):Int;

    @:native("linc::faxe::fmod_bus_get_memory_usage")
    static function bus_get_memory_usage(handle:Int, out:Array<Int>):Int;

    @:native("linc::faxe::fmod_vca_is_valid")
    static function vca_is_valid(handle:Int):Bool;

    @:native("linc::faxe::fmod_vca_get_id")
    static function vca_get_id(handle:Int):cpp.ConstCharStar;

    @:native("linc::faxe::fmod_vca_get_path")
    static function vca_get_path(handle:Int):cpp.ConstCharStar;

    @:native("linc::faxe::fmod_vca_get_volume")
    static function vca_get_volume(handle:Int):Float;

    @:native("linc::faxe::fmod_vca_get_final_volume")
    static function vca_get_final_volume(handle:Int):Float;

    @:native("linc::faxe::fmod_vca_set_volume")
    static function vca_set_volume(handle:Int, volume:Float):Int;

    @:native("linc::faxe::fmod_bank_is_valid")
    static function bank_is_valid(handle:Int):Bool;

    @:native("linc::faxe::fmod_bank_get_id")
    static function bank_get_id(handle:Int):cpp.ConstCharStar;

    @:native("linc::faxe::fmod_bank_get_path")
    static function bank_get_path(handle:Int):cpp.ConstCharStar;

    @:native("linc::faxe::fmod_bank_unload")
    static function bank_unload(handle:Int):Int;

    @:native("linc::faxe::fmod_bank_load_sample_data")
    static function bank_load_sample_data(handle:Int):Int;

    @:native("linc::faxe::fmod_bank_unload_sample_data")
    static function bank_unload_sample_data(handle:Int):Int;

    @:native("linc::faxe::fmod_bank_get_loading_state")
    static function bank_get_loading_state(handle:Int):Int;

    @:native("linc::faxe::fmod_bank_get_sample_loading_state")
    static function bank_get_sample_loading_state(handle:Int):Int;

    @:native("linc::faxe::fmod_bank_get_event_count")
    static function bank_get_event_count(handle:Int):Int;

    @:native("linc::faxe::fmod_bank_get_event_list")
    static function bank_get_event_list(handle:Int, out:Array<Int>):Int;

    @:native("linc::faxe::fmod_bank_get_bus_count")
    static function bank_get_bus_count(handle:Int):Int;

    @:native("linc::faxe::fmod_bank_get_bus_list")
    static function bank_get_bus_list(handle:Int, out:Array<Int>):Int;

    @:native("linc::faxe::fmod_bank_get_vca_count")
    static function bank_get_vca_count(handle:Int):Int;

    @:native("linc::faxe::fmod_bank_get_vca_list")
    static function bank_get_vca_list(handle:Int, out:Array<Int>):Int;

    @:native("linc::faxe::fmod_bank_get_string_count")
    static function bank_get_string_count(handle:Int):Int;

    @:native("linc::faxe::fmod_bank_get_string_info")
    static function bank_get_string_info(handle:Int, index:Int):cpp.ConstCharStar;

    @:native("linc::faxe::fmod_bank_get_string_guid")
    static function bank_get_string_guid(handle:Int, index:Int):cpp.ConstCharStar;

    @:native("linc::faxe::fmod_evd_is_valid")
    static function evd_is_valid(handle:Int):Bool;

    @:native("linc::faxe::fmod_evd_get_id")
    static function evd_get_id(handle:Int):cpp.ConstCharStar;

    @:native("linc::faxe::fmod_evd_get_path")
    static function evd_get_path(handle:Int):cpp.ConstCharStar;

    @:native("linc::faxe::fmod_evd_get_length")
    static function evd_get_length(handle:Int):Int;

    @:native("linc::faxe::fmod_evd_get_min_max_distance")
    static function evd_get_min_max_distance(handle:Int, fout:Array<Float>):Int;

    @:native("linc::faxe::fmod_evd_get_sound_size")
    static function evd_get_sound_size(handle:Int):Float;

    @:native("linc::faxe::fmod_evd_is_snapshot")
    static function evd_is_snapshot(handle:Int):Bool;

    @:native("linc::faxe::fmod_evd_is_oneshot")
    static function evd_is_oneshot(handle:Int):Bool;

    @:native("linc::faxe::fmod_evd_is_stream")
    static function evd_is_stream(handle:Int):Bool;

    @:native("linc::faxe::fmod_evd_is_3d")
    static function evd_is_3d(handle:Int):Bool;

    @:native("linc::faxe::fmod_evd_is_doppler_enabled")
    static function evd_is_doppler_enabled(handle:Int):Bool;

    @:native("linc::faxe::fmod_evd_has_sustain_point")
    static function evd_has_sustain_point(handle:Int):Bool;

    @:native("linc::faxe::fmod_evd_create_instance")
    static function evd_create_instance(handle:Int):Int;

    @:native("linc::faxe::fmod_evd_get_instance_count")
    static function evd_get_instance_count(handle:Int):Int;

    @:native("linc::faxe::fmod_evd_get_instance_list")
    static function evd_get_instance_list(handle:Int, out:Array<Int>):Int;

    @:native("linc::faxe::fmod_evd_release_all_instances")
    static function evd_release_all_instances(handle:Int):Int;

    @:native("linc::faxe::fmod_evd_load_sample_data")
    static function evd_load_sample_data(handle:Int):Int;

    @:native("linc::faxe::fmod_evd_unload_sample_data")
    static function evd_unload_sample_data(handle:Int):Int;

    @:native("linc::faxe::fmod_evd_get_sample_loading_state")
    static function evd_get_sample_loading_state(handle:Int):Int;

    @:native("linc::faxe::fmod_evd_get_parameter_description_count")
    static function evd_get_parameter_description_count(handle:Int):Int;

    @:native("linc::faxe::fmod_evd_get_parameter_description_by_index")
    static function evd_get_parameter_description_by_index(handle:Int, index:Int, fout:Array<Float>, iout:Array<Int>):cpp.ConstCharStar;

    @:native("linc::faxe::fmod_evd_get_parameter_description_by_name")
    static function evd_get_parameter_description_by_name(handle:Int, name:String, fout:Array<Float>, iout:Array<Int>):cpp.ConstCharStar;

    @:native("linc::faxe::fmod_evd_get_parameter_label")
    static function evd_get_parameter_label(handle:Int, parameterName:String, labelIndex:Int):cpp.ConstCharStar;

    @:native("linc::faxe::fmod_evd_get_user_property_count")
    static function evd_get_user_property_count(handle:Int):Int;

    @:native("linc::faxe::fmod_evd_get_user_property_name")
    static function evd_get_user_property_name(handle:Int, index:Int):cpp.ConstCharStar;

    @:native("linc::faxe::fmod_evd_get_user_property_type")
    static function evd_get_user_property_type(handle:Int, index:Int):Int;

    @:native("linc::faxe::fmod_evd_get_user_property_float")
    static function evd_get_user_property_float(handle:Int, index:Int):Float;

    @:native("linc::faxe::fmod_evd_get_user_property_string")
    static function evd_get_user_property_string(handle:Int, index:Int):cpp.ConstCharStar;

    @:native("linc::faxe::fmod_evi_is_valid")
    static function evi_is_valid(handle:Int):Bool;

    @:native("linc::faxe::fmod_evi_get_description")
    static function evi_get_description(handle:Int):Int;

    @:native("linc::faxe::fmod_evi_start")
    static function evi_start(handle:Int):Int;

    @:native("linc::faxe::fmod_evi_stop")
    static function evi_stop(handle:Int, stopMode:Int):Int;

    @:native("linc::faxe::fmod_evi_key_off")
    static function evi_key_off(handle:Int):Int;

    @:native("linc::faxe::fmod_evi_release")
    static function evi_release(handle:Int):Int;

    @:native("linc::faxe::fmod_evi_get_playback_state")
    static function evi_get_playback_state(handle:Int):Int;

    @:native("linc::faxe::fmod_evi_get_paused")
    static function evi_get_paused(handle:Int):Bool;

    @:native("linc::faxe::fmod_evi_set_paused")
    static function evi_set_paused(handle:Int, paused:Bool):Int;

    @:native("linc::faxe::fmod_evi_get_volume")
    static function evi_get_volume(handle:Int):Float;

    @:native("linc::faxe::fmod_evi_get_volume_final")
    static function evi_get_volume_final(handle:Int):Float;

    @:native("linc::faxe::fmod_evi_set_volume")
    static function evi_set_volume(handle:Int, volume:Float):Int;

    @:native("linc::faxe::fmod_evi_get_pitch")
    static function evi_get_pitch(handle:Int):Float;

    @:native("linc::faxe::fmod_evi_get_pitch_final")
    static function evi_get_pitch_final(handle:Int):Float;

    @:native("linc::faxe::fmod_evi_set_pitch")
    static function evi_set_pitch(handle:Int, pitch:Float):Int;

    @:native("linc::faxe::fmod_evi_get_timeline_position")
    static function evi_get_timeline_position(handle:Int):Int;

    @:native("linc::faxe::fmod_evi_set_timeline_position")
    static function evi_set_timeline_position(handle:Int, positionMs:Int):Int;

    @:native("linc::faxe::fmod_evi_is_virtual")
    static function evi_is_virtual(handle:Int):Bool;

    @:native("linc::faxe::fmod_evi_get_min_max_distance")
    static function evi_get_min_max_distance(handle:Int, fout:Array<Float>):Int;

    @:native("linc::faxe::fmod_evi_get_3d_attributes")
    static function evi_get_3d_attributes(handle:Int, fout:Array<Float>):Int;

    @:native("linc::faxe::fmod_evi_set_3d_attributes")
    static function evi_set_3d_attributes(handle:Int, f:Array<Float>):Int;

    @:native("linc::faxe::fmod_evi_get_listener_mask")
    static function evi_get_listener_mask(handle:Int):Int;

    @:native("linc::faxe::fmod_evi_set_listener_mask")
    static function evi_set_listener_mask(handle:Int, mask:Int):Int;

    @:native("linc::faxe::fmod_evi_get_property")
    static function evi_get_property(handle:Int, property:Int):Float;

    @:native("linc::faxe::fmod_evi_set_property")
    static function evi_set_property(handle:Int, property:Int, value:Float):Int;

    @:native("linc::faxe::fmod_evi_get_reverb_level")
    static function evi_get_reverb_level(handle:Int, index:Int):Float;

    @:native("linc::faxe::fmod_evi_set_reverb_level")
    static function evi_set_reverb_level(handle:Int, index:Int, level:Float):Int;

    @:native("linc::faxe::fmod_evi_get_param_by_name")
    static function evi_get_param_by_name(handle:Int, name:String):Float;

    @:native("linc::faxe::fmod_evi_get_param_by_name_final")
    static function evi_get_param_by_name_final(handle:Int, name:String):Float;

    @:native("linc::faxe::fmod_evi_set_param_by_name")
    static function evi_set_param_by_name(handle:Int, name:String, value:Float, ignoreSeekSpeed:Bool):Int;

    @:native("linc::faxe::fmod_evi_set_param_by_name_with_label")
    static function evi_set_param_by_name_with_label(handle:Int, name:String, label:String, ignoreSeekSpeed:Bool):Int;

    @:native("linc::faxe::fmod_evi_get_param_by_id")
    static function evi_get_param_by_id(handle:Int, id1:Int, id2:Int):Float;

    @:native("linc::faxe::fmod_evi_get_param_by_id_final")
    static function evi_get_param_by_id_final(handle:Int, id1:Int, id2:Int):Float;

    @:native("linc::faxe::fmod_evi_set_param_by_id")
    static function evi_set_param_by_id(handle:Int, id1:Int, id2:Int, value:Float, ignoreSeekSpeed:Bool):Int;

    @:native("linc::faxe::fmod_evi_set_param_by_id_with_label")
    static function evi_set_param_by_id_with_label(handle:Int, id1:Int, id2:Int, label:String, ignoreSeekSpeed:Bool):Int;

    @:native("linc::faxe::fmod_evi_get_cpu_usage")
    static function evi_get_cpu_usage(handle:Int, out:Array<Int>):Int;

    @:native("linc::faxe::fmod_evi_get_memory_usage")
    static function evi_get_memory_usage(handle:Int, out:Array<Int>):Int;

    @:native("linc::faxe::fmod_ps_assign")
    static function ps_assign(handle:Int, key:String):Int;

    @:native("linc::faxe::fmod_ps_clear")
    static function ps_clear(handle:Int):Int;

    @:native("linc::faxe::fmod_core_create_sound")
    static function core_create_sound(path:String, mode:Int):Int;

    @:native("linc::faxe::fmod_core_release_sound")
    static function core_release_sound(handle:Int):Int;

    @:native("linc::faxe::fmod_core_get_sound_length")
    static function core_get_sound_length(handle:Int):Int;

    @:native("linc::faxe::fmod_core_pcm_create")
    static function core_pcm_create(sampleRate:Int, channels:Int, ringBytes:Int):Int;

    @:native("linc::faxe::fmod_core_pcm_write")
    static function core_pcm_write(handle:Int, data:haxe.io.BytesData, len:Int):Int;

    @:native("linc::faxe::fmod_core_pcm_space")
    static function core_pcm_space(handle:Int):Int;

    @:native("linc::faxe::fmod_core_pcm_underruns")
    static function core_pcm_underruns(handle:Int):Int;

    @:native("linc::faxe::fmod_core_pcm_play")
    static function core_pcm_play(handle:Int, startPaused:Bool):Int;

    @:native("linc::faxe::fmod_core_pcm_release")
    static function core_pcm_release(handle:Int):Int;

    @:native("linc::faxe::fmod_chan_set_volume")
    static function chan_set_volume(handle:Int, volume:Float):Int;

    @:native("linc::faxe::fmod_chan_get_volume")
    static function chan_get_volume(handle:Int):Float;

    @:native("linc::faxe::fmod_chan_set_pitch")
    static function chan_set_pitch(handle:Int, pitch:Float):Int;

    @:native("linc::faxe::fmod_chan_get_pitch")
    static function chan_get_pitch(handle:Int):Float;

    @:native("linc::faxe::fmod_chan_set_paused")
    static function chan_set_paused(handle:Int, paused:Bool):Int;

    @:native("linc::faxe::fmod_chan_get_paused")
    static function chan_get_paused(handle:Int):Bool;

    @:native("linc::faxe::fmod_chan_is_playing")
    static function chan_is_playing(handle:Int):Bool;

    @:native("linc::faxe::fmod_chan_stop")
    static function chan_stop(handle:Int):Int;

    @:native("linc::faxe::fmod_dsp_create_by_type")
    static function dsp_create_by_type(type:Int):Int;

    @:native("linc::faxe::fmod_dsp_release")
    static function dsp_release(handle:Int):Int;

    @:native("linc::faxe::fmod_dsp_set_param_float")
    static function dsp_set_param_float(handle:Int, index:Int, value:Float):Int;

    @:native("linc::faxe::fmod_dsp_get_param_float")
    static function dsp_get_param_float(handle:Int, index:Int):Float;

    @:native("linc::faxe::fmod_dsp_set_param_int")
    static function dsp_set_param_int(handle:Int, index:Int, value:Int):Int;

    @:native("linc::faxe::fmod_dsp_get_param_int")
    static function dsp_get_param_int(handle:Int, index:Int):Int;

    @:native("linc::faxe::fmod_dsp_set_param_bool")
    static function dsp_set_param_bool(handle:Int, index:Int, value:Bool):Int;

    @:native("linc::faxe::fmod_dsp_get_param_bool")
    static function dsp_get_param_bool(handle:Int, index:Int):Bool;

    @:native("linc::faxe::fmod_dsp_get_num_params")
    static function dsp_get_num_params(handle:Int):Int;

    @:native("linc::faxe::fmod_dsp_get_type")
    static function dsp_get_type(handle:Int):Int;

    @:native("linc::faxe::fmod_dsp_set_bypass")
    static function dsp_set_bypass(handle:Int, bypass:Bool):Int;

    @:native("linc::faxe::fmod_dsp_get_bypass")
    static function dsp_get_bypass(handle:Int):Bool;

    @:native("linc::faxe::fmod_dsp_set_wet_dry_mix")
    static function dsp_set_wet_dry_mix(handle:Int, prewet:Float, postwet:Float, dry:Float):Int;

    @:native("linc::faxe::fmod_dsp_set_active")
    static function dsp_set_active(handle:Int, active:Bool):Int;

    @:native("linc::faxe::fmod_dsp_reset")
    static function dsp_reset(handle:Int):Int;

    @:native("linc::faxe::fmod_dsp_set_metering_enabled")
    static function dsp_set_metering_enabled(handle:Int, input:Bool, output:Bool):Int;

    @:native("linc::faxe::fmod_dsp_get_metering")
    static function dsp_get_metering(handle:Int, fbuf:Array<Float>):Int;

    @:native("linc::faxe::fmod_dsp_fft_get_spectrum")
    static function dsp_fft_get_spectrum(handle:Int, fbuf:Array<Float>, maxBins:Int):Int;

    @:native("linc::faxe::fmod_cg_get_master")
    static function cg_get_master():Int;

    @:native("linc::faxe::fmod_cg_create")
    static function cg_create(name:String):Int;

    @:native("linc::faxe::fmod_cg_release")
    static function cg_release(handle:Int):Int;

    @:native("linc::faxe::fmod_cg_set_volume")
    static function cg_set_volume(handle:Int, volume:Float):Int;

    @:native("linc::faxe::fmod_cg_get_volume")
    static function cg_get_volume(handle:Int):Float;

    @:native("linc::faxe::fmod_cg_set_pitch")
    static function cg_set_pitch(handle:Int, pitch:Float):Int;

    @:native("linc::faxe::fmod_cg_get_pitch")
    static function cg_get_pitch(handle:Int):Float;

    @:native("linc::faxe::fmod_cg_set_mute")
    static function cg_set_mute(handle:Int, mute:Bool):Int;

    @:native("linc::faxe::fmod_cg_get_mute")
    static function cg_get_mute(handle:Int):Bool;

    @:native("linc::faxe::fmod_cg_set_paused")
    static function cg_set_paused(handle:Int, paused:Bool):Int;

    @:native("linc::faxe::fmod_cg_get_paused")
    static function cg_get_paused(handle:Int):Bool;

    @:native("linc::faxe::fmod_cg_add_dsp")
    static function cg_add_dsp(handle:Int, index:Int, dspHandle:Int):Int;

    @:native("linc::faxe::fmod_cg_remove_dsp")
    static function cg_remove_dsp(handle:Int, dspHandle:Int):Int;

    @:native("linc::faxe::fmod_cg_stop")
    static function cg_stop(handle:Int):Int;

    @:native("linc::faxe::fmod_chan_set_pan")
    static function chan_set_pan(handle:Int, pan:Float):Int;

    @:native("linc::faxe::fmod_chan_set_frequency")
    static function chan_set_frequency(handle:Int, frequency:Float):Int;

    @:native("linc::faxe::fmod_chan_get_frequency")
    static function chan_get_frequency(handle:Int):Float;

    @:native("linc::faxe::fmod_chan_set_loop_count")
    static function chan_set_loop_count(handle:Int, loopCount:Int):Int;

    @:native("linc::faxe::fmod_chan_get_position")
    static function chan_get_position(handle:Int):Int;

    @:native("linc::faxe::fmod_chan_set_position")
    static function chan_set_position(handle:Int, positionMs:Int):Int;

    @:native("linc::faxe::fmod_chan_set_channel_group")
    static function chan_set_channel_group(handle:Int, groupHandle:Int):Int;

    @:native("linc::faxe::fmod_chan_add_dsp")
    static function chan_add_dsp(handle:Int, index:Int, dspHandle:Int):Int;

    @:native("linc::faxe::fmod_chan_remove_dsp")
    static function chan_remove_dsp(handle:Int, dspHandle:Int):Int;

    @:native("linc::faxe::fmod_chan_set_3d_attributes")
    static function chan_set_3d_attributes(handle:Int, posX:Float, posY:Float, posZ:Float, velX:Float, velY:Float, velZ:Float):Int;

    @:native("linc::faxe::fmod_chan_set_3d_min_max")
    static function chan_set_3d_min_max(handle:Int, minDist:Float, maxDist:Float):Int;

    @:native("linc::faxe::fmod_chan_set_reverb_wet")
    static function chan_set_reverb_wet(handle:Int, instance:Int, wet:Float):Int;

    @:native("linc::faxe::fmod_bus_lock_channel_group")
    static function bus_lock_channel_group(handle:Int):Int;

    @:native("linc::faxe::fmod_bus_unlock_channel_group")
    static function bus_unlock_channel_group(handle:Int):Int;

    @:native("linc::faxe::fmod_bus_get_channel_group")
    static function bus_get_channel_group(handle:Int):Int;

    @:native("linc::faxe::fmod_sys_play_dsp")
    static function sys_play_dsp(dspHandle:Int, startPaused:Bool):Int;

    @:native("linc::faxe::fmod_sys_set_reverb_properties")
    static function sys_set_reverb_properties(instance:Int, fbuf:Array<Float>):Int;

    @:native("linc::faxe::fmod_sys_get_reverb_properties")
    static function sys_get_reverb_properties(instance:Int, fbuf:Array<Float>):Int;

    @:native("linc::faxe::fmod_core_pcm_create_3d")
    static function core_pcm_create_3d(sampleRate:Int, channels:Int, ringBytes:Int):Int;

    @:native("linc::faxe::fmod_dsp_add_input")
    static function dsp_add_input(handle:Int, inputHandle:Int, type:Int):Int;

    @:native("linc::faxe::fmod_dsp_disconnect_from")
    static function dsp_disconnect_from(handle:Int, inputHandle:Int):Int;

    @:native("linc::faxe::fmod_dsp_disconnect_all")
    static function dsp_disconnect_all(handle:Int, inputs:Bool, outputs:Bool):Int;

    @:native("linc::faxe::fmod_dsp_get_num_inputs")
    static function dsp_get_num_inputs(handle:Int):Int;

    @:native("linc::faxe::fmod_dsp_get_num_outputs")
    static function dsp_get_num_outputs(handle:Int):Int;

    @:native("linc::faxe::fmod_dsp_get_input_dsp")
    static function dsp_get_input_dsp(handle:Int, index:Int):Int;

    @:native("linc::faxe::fmod_dsp_get_input_connection")
    static function dsp_get_input_connection(handle:Int, index:Int):Int;

    @:native("linc::faxe::fmod_dspconn_set_mix")
    static function dspconn_set_mix(handle:Int, mix:Float):Int;

    @:native("linc::faxe::fmod_dspconn_get_mix")
    static function dspconn_get_mix(handle:Int):Float;

    @:native("linc::faxe::fmod_dspconn_get_type")
    static function dspconn_get_type(handle:Int):Int;

    @:native("linc::faxe::fmod_cg_add_group")
    static function cg_add_group(handle:Int, childHandle:Int):Int;

    @:native("linc::faxe::fmod_cg_get_num_groups")
    static function cg_get_num_groups(handle:Int):Int;

    @:native("linc::faxe::fmod_cg_get_group")
    static function cg_get_group(handle:Int, index:Int):Int;

    @:native("linc::faxe::fmod_cg_get_parent_group")
    static function cg_get_parent_group(handle:Int):Int;

    @:native("linc::faxe::fmod_chan_set_mute")
    static function chan_set_mute(handle:Int, mute:Bool):Int;

    @:native("linc::faxe::fmod_chan_get_mute")
    static function chan_get_mute(handle:Int):Bool;

    @:native("linc::faxe::fmod_chan_set_low_pass_gain")
    static function chan_set_low_pass_gain(handle:Int, gain:Float):Int;

    @:native("linc::faxe::fmod_chan_set_mode")
    static function chan_set_mode(handle:Int, mode:Int):Int;

    @:native("linc::faxe::fmod_chan_set_3d_cone_settings")
    static function chan_set_3d_cone_settings(handle:Int, insideAngle:Float, outsideAngle:Float, outsideVolume:Float):Int;

    @:native("linc::faxe::fmod_chan_set_3d_cone_orientation")
    static function chan_set_3d_cone_orientation(handle:Int, x:Float, y:Float, z:Float):Int;

    @:native("linc::faxe::fmod_chan_set_3d_occlusion")
    static function chan_set_3d_occlusion(handle:Int, direct:Float, reverb:Float):Int;

    @:native("linc::faxe::fmod_chan_get_3d_occlusion")
    static function chan_get_3d_occlusion(handle:Int, fbuf:Array<Float>):Int;

    @:native("linc::faxe::fmod_chan_set_3d_spread")
    static function chan_set_3d_spread(handle:Int, angle:Float):Int;

    @:native("linc::faxe::fmod_chan_set_3d_level")
    static function chan_set_3d_level(handle:Int, level:Float):Int;

    @:native("linc::faxe::fmod_chan_set_3d_doppler_level")
    static function chan_set_3d_doppler_level(handle:Int, level:Float):Int;

    @:native("linc::faxe::fmod_chan_set_mix_matrix")
    static function chan_set_mix_matrix(handle:Int, fbuf:Array<Float>, outChannels:Int, inChannels:Int):Int;

    @:native("linc::faxe::fmod_chan_get_dsp_clock")
    static function chan_get_dsp_clock(handle:Int, fbuf:Array<Float>):Int;

    @:native("linc::faxe::fmod_chan_set_delay")
    static function chan_set_delay(handle:Int, startClock:Float, endClock:Float, stopChannels:Bool):Int;

    @:native("linc::faxe::fmod_chan_add_fade_point")
    static function chan_add_fade_point(handle:Int, clock:Float, volume:Float):Int;

    @:native("linc::faxe::fmod_chan_set_fade_point_ramp")
    static function chan_set_fade_point_ramp(handle:Int, clock:Float, volume:Float):Int;

    @:native("linc::faxe::fmod_chan_remove_fade_points")
    static function chan_remove_fade_points(handle:Int, startClock:Float, endClock:Float):Int;

    @:native("linc::faxe::fmod_cg_get_dsp_clock")
    static function cg_get_dsp_clock(handle:Int, fbuf:Array<Float>):Int;

    @:native("linc::faxe::fmod_cg_set_delay")
    static function cg_set_delay(handle:Int, startClock:Float, endClock:Float, stopChannels:Bool):Int;

    @:native("linc::faxe::fmod_cg_add_fade_point")
    static function cg_add_fade_point(handle:Int, clock:Float, volume:Float):Int;

    @:native("linc::faxe::fmod_cg_set_fade_point_ramp")
    static function cg_set_fade_point_ramp(handle:Int, clock:Float, volume:Float):Int;

    @:native("linc::faxe::fmod_cg_remove_fade_points")
    static function cg_remove_fade_points(handle:Int, startClock:Float, endClock:Float):Int;

    @:native("linc::faxe::fmod_sys_create_reverb3d")
    static function sys_create_reverb3d():Int;

    @:native("linc::faxe::fmod_r3d_release")
    static function r3d_release(handle:Int):Int;

    @:native("linc::faxe::fmod_r3d_set_3d_attributes")
    static function r3d_set_3d_attributes(handle:Int, x:Float, y:Float, z:Float, minDist:Float, maxDist:Float):Int;

    @:native("linc::faxe::fmod_r3d_set_properties")
    static function r3d_set_properties(handle:Int, fbuf:Array<Float>):Int;

    @:native("linc::faxe::fmod_r3d_get_properties")
    static function r3d_get_properties(handle:Int, fbuf:Array<Float>):Int;

    @:native("linc::faxe::fmod_r3d_set_active")
    static function r3d_set_active(handle:Int, active:Bool):Int;

    @:native("linc::faxe::fmod_core_create_sound_pcm")
    static function core_create_sound_pcm(data:haxe.io.BytesData, len:Int, sampleRate:Int, channels:Int):Int;

    @:native("linc::faxe::fmod_core_play_sound")
    static function core_play_sound(handle:Int, startPaused:Bool):Int;

    @:native("linc::faxe::fmod_sound_set_defaults")
    static function sound_set_defaults(handle:Int, frequency:Float, priority:Int):Int;

    @:native("linc::faxe::fmod_sound_get_defaults")
    static function sound_get_defaults(handle:Int, fbuf:Array<Float>):Int;

    @:native("linc::faxe::fmod_sound_set_loop_points")
    static function sound_set_loop_points(handle:Int, startMs:Int, endMs:Int):Int;

    @:native("linc::faxe::fmod_sound_get_loop_points")
    static function sound_get_loop_points(handle:Int, ibuf:Array<Int>):Int;

    @:native("linc::faxe::fmod_sound_set_mode")
    static function sound_set_mode(handle:Int, mode:Int):Int;

    @:native("linc::faxe::fmod_sound_get_mode")
    static function sound_get_mode(handle:Int):Int;

    @:native("linc::faxe::fmod_sound_get_format")
    static function sound_get_format(handle:Int, ibuf:Array<Int>):Int;

    @:native("linc::faxe::fmod_sound_get_open_state")
    static function sound_get_open_state(handle:Int):Int;

    @:native("linc::faxe::fmod_sys_get_channels_playing")
    static function sys_get_channels_playing(ibuf:Array<Int>):Int;

    @:native("linc::faxe::fmod_sys_mixer_suspend")
    static function sys_mixer_suspend():Int;

    @:native("linc::faxe::fmod_sys_mixer_resume")
    static function sys_mixer_resume():Int;

    @:native("linc::faxe::fmod_sys_get_software_format")
    static function sys_get_software_format(ibuf:Array<Int>):Int;

    @:native("linc::faxe::fmod_dsp_get_cpu_usage")
    static function dsp_get_cpu_usage(handle:Int, ibuf:Array<Int>):Int;



    @:native("linc::faxe::fmod_evi_set_callback_mask")
    static function evi_set_callback_mask(handle:Int, mask:Int):Int;

    @:native("linc::faxe::fmod_cb_next")
    static function cb_next():Bool;

    @:native("linc::faxe::fmod_cb_handle")
    static function cb_handle():Int;

    @:native("linc::faxe::fmod_cb_type")
    static function cb_type():Int;

    @:native("linc::faxe::fmod_cb_int")
    static function cb_int(index:Int):Int;

    @:native("linc::faxe::fmod_cb_float")
    static function cb_float():Float;

    @:native("linc::faxe::fmod_cb_string")
    static function cb_string():cpp.ConstCharStar;

    @:native("linc::faxe::fmod_cb_take_overflow")
    static function cb_take_overflow():Bool;

    @:native("linc::faxe::fmod_debug_live_handle_count")
    static function debug_live_handle_count():Int;

    @:native("linc::faxe::fmod_binding_abi_version")
    static function binding_abi_version():Int;
}
#end
