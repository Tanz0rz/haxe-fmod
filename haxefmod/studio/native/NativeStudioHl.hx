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

    public static inline function sys_init_ex(numChannels:Int, sampleRate:Int, speakerMode:Int, studioFlags:Int):Int return Raw.sys_init_ex(numChannels, sampleRate, speakerMode, studioFlags);
    public static inline function sys_set_debug_level(level:Int):Int return Raw.sys_set_debug_level(level);
    public static inline function sys_load_bank_async(path:String):Int return Raw.sys_load_bank_async(toBytes(path));
    public static inline function sys_is_initialized():Bool return Raw.is_initialized();
    public static inline function sys_update():Void Raw.update();
    public static inline function sys_set_auto_update(enabled:Bool):Void Raw.set_auto_update(enabled);

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
    public static inline function core_create_sound(path:String, mode:Int):Int return Raw.core_create_sound(toBytes(path), mode);
    public static inline function core_release_sound(handle:Int):Int return Raw.core_release_sound(handle);
    public static inline function core_get_sound_length(handle:Int):Int return Raw.core_get_sound_length(handle);

    // Callbacks
    public static inline function evi_set_callback_mask(handle:Int, mask:Int):Int return Raw.evi_set_callback_mask(handle, mask);
    public static inline function cb_next():Bool return Raw.cb_next();
    public static inline function cb_handle():Int return Raw.cb_handle();
    public static inline function cb_type():Int return Raw.cb_type();
    public static inline function cb_int(index:Int):Int return Raw.cb_int(index);
    public static inline function cb_float():Float return Raw.cb_float();
    public static inline function cb_string():String return fromBytes(Raw.cb_string());
    public static inline function cb_take_overflow():Bool return Raw.cb_take_overflow();

    // Debug
    public static inline function debug_live_handle_count():Int return Raw.debug_live_handle_count();
    public static inline function binding_abi_version():Int return Raw.binding_abi_version();
}

@:hlNative("hlaxe_fmod")
private extern class Raw {
    static function is_initialized():Bool;
    static function update():Void;
    static function set_auto_update(enabled:Bool):Void;
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
    static function sys_init_ex(numChannels:Int, sampleRate:Int, speakerMode:Int, studioFlags:Int):Int;
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
    static function core_create_sound(path:hl.Bytes, mode:Int):Int;
    static function core_release_sound(handle:Int):Int;
    static function core_get_sound_length(handle:Int):Int;
    static function evi_set_callback_mask(handle:Int, mask:Int):Int;
    static function cb_next():Bool;
    static function cb_handle():Int;
    static function cb_type():Int;
    static function cb_int(index:Int):Int;
    static function cb_float():Float;
    static function cb_string():hl.Bytes;
    static function cb_take_overflow():Bool;
    static function debug_live_handle_count():Int;
    static function binding_abi_version():Int;
}
#end
