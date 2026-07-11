/**
 * Faxe - C++ FMOD bindings - Minimal FFI layer
 *
 * The MIT License (MIT)
 * Copyright (c) 2016 Aaron M. Shea
 * Copyright (c) 2020 Tanner Moore
 */
#pragma once

#define IMPLEMENT_API

namespace linc {
namespace faxe {

//// System
extern bool fmod_is_initialized();
extern int fmod_init(int numChannels);
extern void fmod_update();
extern void fmod_set_auto_update(bool enabled);

//// Banks
extern int fmod_load_bank(const ::String& path);
extern void fmod_unload_bank(const ::String& path);

//// Events - One shot
extern int fmod_fire_one_shot(const ::String& eventPath);

//// Events - Managed instances (handle-based)
extern int fmod_create_instance(const ::String& eventPath);
extern void fmod_start(int handle);
extern void fmod_stop(int handle, int immediate);
extern void fmod_release(int handle);
extern void fmod_set_paused(int handle, bool paused);
extern int fmod_get_playback_state(int handle);
extern int fmod_get_timeline_position(int handle);

//// Parameters
extern float fmod_get_param(int handle, const ::String& name);
extern void fmod_set_param(int handle, const ::String& name, float value);

//// Bus
extern void fmod_set_bus_paused(const ::String& path, bool paused);
extern void fmod_stop_bus(const ::String& path);
extern void fmod_set_bus_volume(const ::String& path, float volume);
extern float fmod_get_bus_volume(const ::String& path);
extern void fmod_set_bus_mute(const ::String& path, bool mute);
extern bool fmod_get_bus_mute(const ::String& path);

//// Callbacks
extern int fmod_evi_set_callback_mask(int handle, int mask);
extern bool fmod_cb_next();
extern int fmod_cb_handle();
extern int fmod_cb_type();
extern int fmod_cb_int(int index);
extern double fmod_cb_float();
extern const char* fmod_cb_string();
extern bool fmod_cb_take_overflow();

//// Studio System
extern int fmod_sys_last_result();
extern int fmod_sys_init_ex(int numChannels, int sampleRate, int speakerMode, int studioFlags);
extern int fmod_sys_set_debug_level(int level);
extern int fmod_sys_load_bank_async(const ::String& path);
extern int fmod_sys_get_bus(const ::String& path);
extern int fmod_sys_get_bus_by_id(const ::String& guid);
extern int fmod_sys_get_event(const ::String& path);
extern int fmod_sys_get_event_by_id(const ::String& guid);
extern int fmod_sys_get_vca(const ::String& path);
extern int fmod_sys_get_vca_by_id(const ::String& guid);
extern int fmod_sys_get_bank(const ::String& path);
extern int fmod_sys_get_bank_by_id(const ::String& guid);
extern int fmod_sys_get_bank_count();
extern int fmod_sys_get_bank_list(::Array<int> out);
extern const char* fmod_sys_lookup_id(const ::String& path);
extern const char* fmod_sys_lookup_path(const ::String& guid);
extern double fmod_sys_get_param_by_name(const ::String& name);
extern double fmod_sys_get_param_by_name_final(const ::String& name);
extern int fmod_sys_set_param_by_name(const ::String& name, double value, bool ignoreSeekSpeed);
extern int fmod_sys_set_param_by_name_with_label(const ::String& name, const ::String& label, bool ignoreSeekSpeed);
extern double fmod_sys_get_param_by_id(int id1, int id2);
extern double fmod_sys_get_param_by_id_final(int id1, int id2);
extern int fmod_sys_set_param_by_id(int id1, int id2, double value, bool ignoreSeekSpeed);
extern int fmod_sys_set_param_by_id_with_label(int id1, int id2, const ::String& label, bool ignoreSeekSpeed);
extern int fmod_sys_get_parameter_description_count();
extern const char* fmod_sys_get_parameter_description_by_index(int index, ::Array<Float> fbuf, ::Array<int> ibuf);
extern const char* fmod_sys_get_parameter_description_by_name(const ::String& name, ::Array<Float> fbuf, ::Array<int> ibuf);
extern const char* fmod_sys_get_parameter_label(const ::String& name, int labelIndex);
extern int fmod_sys_get_num_listeners();
extern int fmod_sys_set_num_listeners(int num);
extern int fmod_sys_get_listener_attributes(int index, ::Array<Float> fbuf);
extern int fmod_sys_set_listener_attributes(int index, ::Array<Float> f);
extern double fmod_sys_get_listener_weight(int index);
extern int fmod_sys_set_listener_weight(int index, double weight);
extern int fmod_sys_load_bank_file(const ::String& path, int flags);
extern int fmod_sys_unload_all();
extern int fmod_sys_flush_commands();
extern int fmod_sys_flush_sample_loading();
extern int fmod_sys_get_cpu_usage(::Array<Float> fbuf);
extern int fmod_sys_get_buffer_usage(::Array<int> ibuf, ::Array<Float> fbuf);
extern int fmod_sys_reset_buffer_usage();
extern int fmod_sys_get_memory_usage(::Array<int> ibuf);

//// Bus
extern bool fmod_bus_is_valid(int handle);
extern const char* fmod_bus_get_id(int handle);
extern const char* fmod_bus_get_path(int handle);
extern double fmod_bus_get_volume(int handle);
extern double fmod_bus_get_final_volume(int handle);
extern int fmod_bus_set_volume(int handle, double volume);
extern bool fmod_bus_get_paused(int handle);
extern int fmod_bus_set_paused(int handle, bool paused);
extern bool fmod_bus_get_mute(int handle);
extern int fmod_bus_set_mute(int handle, bool mute);
extern int fmod_bus_stop_all_events(int handle, int stopMode);
extern int fmod_bus_get_cpu_usage(int handle, ::Array<int> out);
extern int fmod_bus_get_memory_usage(int handle, ::Array<int> out);

//// VCA
extern bool fmod_vca_is_valid(int handle);
extern const char* fmod_vca_get_id(int handle);
extern const char* fmod_vca_get_path(int handle);
extern double fmod_vca_get_volume(int handle);
extern double fmod_vca_get_final_volume(int handle);
extern int fmod_vca_set_volume(int handle, double volume);

//// Bank
extern bool fmod_bank_is_valid(int handle);
extern const char* fmod_bank_get_id(int handle);
extern const char* fmod_bank_get_path(int handle);
extern int fmod_bank_unload(int handle);
extern int fmod_bank_load_sample_data(int handle);
extern int fmod_bank_unload_sample_data(int handle);
extern int fmod_bank_get_loading_state(int handle);
extern int fmod_bank_get_sample_loading_state(int handle);
extern int fmod_bank_get_event_count(int handle);
extern int fmod_bank_get_event_list(int handle, ::Array<int> out);
extern int fmod_bank_get_bus_count(int handle);
extern int fmod_bank_get_bus_list(int handle, ::Array<int> out);
extern int fmod_bank_get_vca_count(int handle);
extern int fmod_bank_get_vca_list(int handle, ::Array<int> out);
extern int fmod_bank_get_string_count(int handle);
extern const char* fmod_bank_get_string_info(int handle, int index);
extern const char* fmod_bank_get_string_guid(int handle, int index);

//// EventDescription
extern bool fmod_evd_is_valid(int handle);
extern const char* fmod_evd_get_id(int handle);
extern const char* fmod_evd_get_path(int handle);
extern int fmod_evd_get_length(int handle);
extern int fmod_evd_get_min_max_distance(int handle, ::Array<Float> fbuf);
extern double fmod_evd_get_sound_size(int handle);
extern bool fmod_evd_is_snapshot(int handle);
extern bool fmod_evd_is_oneshot(int handle);
extern bool fmod_evd_is_stream(int handle);
extern bool fmod_evd_is_3d(int handle);
extern bool fmod_evd_is_doppler_enabled(int handle);
extern bool fmod_evd_has_sustain_point(int handle);
extern int fmod_evd_create_instance(int handle);
extern int fmod_evd_get_instance_count(int handle);
extern int fmod_evd_get_instance_list(int handle, ::Array<int> out);
extern int fmod_evd_release_all_instances(int handle);
extern int fmod_evd_load_sample_data(int handle);
extern int fmod_evd_unload_sample_data(int handle);
extern int fmod_evd_get_sample_loading_state(int handle);
extern int fmod_evd_get_parameter_description_count(int handle);
extern const char* fmod_evd_get_parameter_description_by_index(int handle, int index, ::Array<Float> fbuf, ::Array<int> ibuf);
extern const char* fmod_evd_get_parameter_description_by_name(int handle, const ::String& name, ::Array<Float> fbuf, ::Array<int> ibuf);
extern const char* fmod_evd_get_parameter_label(int handle, const ::String& name, int labelIndex);
extern int fmod_evd_get_user_property_count(int handle);
extern const char* fmod_evd_get_user_property_name(int handle, int index);
extern int fmod_evd_get_user_property_type(int handle, int index);
extern double fmod_evd_get_user_property_float(int handle, int index);
extern const char* fmod_evd_get_user_property_string(int handle, int index);

//// EventInstance
extern bool fmod_evi_is_valid(int handle);
extern int fmod_evi_get_description(int handle);
extern int fmod_evi_start(int handle);
extern int fmod_evi_stop(int handle, int stopMode);
extern int fmod_evi_key_off(int handle);
extern int fmod_evi_release(int handle);
extern int fmod_evi_get_playback_state(int handle);
extern bool fmod_evi_get_paused(int handle);
extern int fmod_evi_set_paused(int handle, bool paused);
extern double fmod_evi_get_volume(int handle);
extern double fmod_evi_get_volume_final(int handle);
extern int fmod_evi_set_volume(int handle, double volume);
extern double fmod_evi_get_pitch(int handle);
extern double fmod_evi_get_pitch_final(int handle);
extern int fmod_evi_set_pitch(int handle, double pitch);
extern int fmod_evi_get_timeline_position(int handle);
extern int fmod_evi_set_timeline_position(int handle, int position);
extern bool fmod_evi_is_virtual(int handle);
extern int fmod_evi_get_min_max_distance(int handle, ::Array<Float> fbuf);
extern int fmod_evi_get_3d_attributes(int handle, ::Array<Float> fbuf);
extern int fmod_evi_set_3d_attributes(int handle, ::Array<Float> f);
extern int fmod_evi_get_listener_mask(int handle);
extern int fmod_evi_set_listener_mask(int handle, int mask);
extern double fmod_evi_get_property(int handle, int index);
extern int fmod_evi_set_property(int handle, int index, double value);
extern double fmod_evi_get_reverb_level(int handle, int index);
extern int fmod_evi_set_reverb_level(int handle, int index, double level);
extern double fmod_evi_get_param_by_name(int handle, const ::String& name);
extern double fmod_evi_get_param_by_name_final(int handle, const ::String& name);
extern int fmod_evi_set_param_by_name(int handle, const ::String& name, double value, bool ignoreSeekSpeed);
extern int fmod_evi_set_param_by_name_with_label(int handle, const ::String& name, const ::String& label, bool ignoreSeekSpeed);
extern double fmod_evi_get_param_by_id(int handle, int id1, int id2);
extern double fmod_evi_get_param_by_id_final(int handle, int id1, int id2);
extern int fmod_evi_set_param_by_id(int handle, int id1, int id2, double value, bool ignoreSeekSpeed);
extern int fmod_evi_set_param_by_id_with_label(int handle, int id1, int id2, const ::String& label, bool ignoreSeekSpeed);
extern int fmod_evi_get_cpu_usage(int handle, ::Array<int> out);
extern int fmod_evi_get_memory_usage(int handle, ::Array<int> out);

//// Programmer sounds
extern int fmod_ps_assign(int handle, const ::String& key);
extern int fmod_ps_clear(int handle);

//// Core API micro subset (programmer sounds only)
extern int fmod_core_create_sound(const ::String& path, int mode);
extern int fmod_core_release_sound(int handle);
extern int fmod_core_get_sound_length(int handle);

//// Core PCM streams
extern int fmod_core_pcm_create(int sampleRate, int channels, int ringBytes);
extern int fmod_core_pcm_write(int handle, ::Array<unsigned char> data, int len);
extern int fmod_core_pcm_space(int handle);
extern int fmod_core_pcm_underruns(int handle);
extern int fmod_core_pcm_play(int handle, bool paused);
extern int fmod_core_pcm_release(int handle);

//// Core channels
extern int fmod_chan_set_volume(int handle, float volume);
extern float fmod_chan_get_volume(int handle);
extern int fmod_chan_set_pitch(int handle, float pitch);
extern float fmod_chan_get_pitch(int handle);
extern int fmod_chan_set_paused(int handle, bool paused);
extern bool fmod_chan_get_paused(int handle);
extern bool fmod_chan_is_playing(int handle);
extern int fmod_chan_stop(int handle);

// Core DSP effects
extern int fmod_dsp_create_by_type(int type);
extern int fmod_dsp_release(int handle);
extern int fmod_dsp_set_param_float(int handle, int index, float value);
extern float fmod_dsp_get_param_float(int handle, int index);
extern int fmod_dsp_set_param_int(int handle, int index, int value);
extern int fmod_dsp_get_param_int(int handle, int index);
extern int fmod_dsp_set_param_bool(int handle, int index, bool value);
extern bool fmod_dsp_get_param_bool(int handle, int index);
extern int fmod_dsp_get_num_params(int handle);
extern int fmod_dsp_get_type(int handle);
extern int fmod_dsp_set_bypass(int handle, bool bypass);
extern bool fmod_dsp_get_bypass(int handle);
extern int fmod_dsp_set_wet_dry_mix(int handle, float prewet, float postwet, float dry);
extern int fmod_dsp_set_active(int handle, bool active);
extern int fmod_dsp_reset(int handle);
extern int fmod_dsp_set_metering_enabled(int handle, bool input, bool output);
extern int fmod_dsp_get_metering(int handle, ::Array<Float> fbuf);
extern int fmod_dsp_fft_get_spectrum(int handle, ::Array<Float> fbuf, int maxBins);

// Core channel groups
extern int fmod_cg_get_master();
extern int fmod_cg_create(const ::String& name);
extern int fmod_cg_release(int handle);
extern int fmod_cg_set_volume(int handle, float volume);
extern float fmod_cg_get_volume(int handle);
extern int fmod_cg_set_pitch(int handle, float pitch);
extern float fmod_cg_get_pitch(int handle);
extern int fmod_cg_set_mute(int handle, bool mute);
extern bool fmod_cg_get_mute(int handle);
extern int fmod_cg_set_paused(int handle, bool paused);
extern bool fmod_cg_get_paused(int handle);
extern int fmod_cg_add_dsp(int handle, int index, int dspHandle);
extern int fmod_cg_remove_dsp(int handle, int dspHandle);
extern int fmod_cg_stop(int handle);

// Core channel routing and effects
extern int fmod_chan_set_pan(int handle, float pan);
extern int fmod_chan_set_frequency(int handle, float frequency);
extern float fmod_chan_get_frequency(int handle);
extern int fmod_chan_set_loop_count(int handle, int loopCount);
extern int fmod_chan_get_position(int handle);
extern int fmod_chan_set_position(int handle, int positionMs);
extern int fmod_chan_set_channel_group(int handle, int groupHandle);
extern int fmod_chan_add_dsp(int handle, int index, int dspHandle);
extern int fmod_chan_remove_dsp(int handle, int dspHandle);
extern int fmod_chan_set_3d_attributes(int handle, float posX, float posY, float posZ, float velX, float velY, float velZ);
extern int fmod_chan_set_3d_min_max(int handle, float minDist, float maxDist);
extern int fmod_chan_set_reverb_wet(int handle, int instance, float wet);

// Studio bus to core group bridge
extern int fmod_bus_lock_channel_group(int handle);
extern int fmod_bus_unlock_channel_group(int handle);
extern int fmod_bus_get_channel_group(int handle);

// Core system extras
extern int fmod_sys_play_dsp(int dspHandle, bool startPaused);
extern int fmod_sys_set_reverb_properties(int instance, ::Array<Float> fbuf);
extern int fmod_sys_get_reverb_properties(int instance, ::Array<Float> fbuf);
extern int fmod_core_pcm_create_3d(int sampleRate, int channels, int ringBytes);

// Core DSP connection graph
extern int fmod_dsp_add_input(int handle, int inputHandle, int type);
extern int fmod_dsp_disconnect_from(int handle, int inputHandle);
extern int fmod_dsp_disconnect_all(int handle, bool inputs, bool outputs);
extern int fmod_dsp_get_num_inputs(int handle);
extern int fmod_dsp_get_num_outputs(int handle);
extern int fmod_dsp_get_input_dsp(int handle, int index);
extern int fmod_dsp_get_input_connection(int handle, int index);
extern int fmod_dspconn_set_mix(int handle, float mix);
extern float fmod_dspconn_get_mix(int handle);
extern int fmod_dspconn_get_type(int handle);

// Core channel group nesting
extern int fmod_cg_add_group(int handle, int childHandle);
extern int fmod_cg_get_num_groups(int handle);
extern int fmod_cg_get_group(int handle, int index);
extern int fmod_cg_get_parent_group(int handle);

// Core channel spatial and control extras
extern int fmod_chan_set_mute(int handle, bool mute);
extern bool fmod_chan_get_mute(int handle);
extern int fmod_chan_set_low_pass_gain(int handle, float gain);
extern int fmod_chan_set_mode(int handle, int mode);
extern int fmod_chan_set_3d_cone_settings(int handle, float insideAngle, float outsideAngle, float outsideVolume);
extern int fmod_chan_set_3d_cone_orientation(int handle, float x, float y, float z);
extern int fmod_chan_set_3d_occlusion(int handle, float direct, float reverb);
extern int fmod_chan_get_3d_occlusion(int handle, ::Array<Float> fbuf);
extern int fmod_chan_set_3d_spread(int handle, float angle);
extern int fmod_chan_set_3d_level(int handle, float level);
extern int fmod_chan_set_3d_doppler_level(int handle, float level);
extern int fmod_chan_set_mix_matrix(int handle, ::Array<Float> fbuf, int outChannels, int inChannels);

// Core scheduling
extern int fmod_chan_get_dsp_clock(int handle, ::Array<Float> fbuf);
extern int fmod_chan_set_delay(int handle, double startClock, double endClock, bool stopChannels);
extern int fmod_chan_add_fade_point(int handle, double clock, float volume);
extern int fmod_chan_set_fade_point_ramp(int handle, double clock, float volume);
extern int fmod_chan_remove_fade_points(int handle, double startClock, double endClock);
extern int fmod_cg_get_dsp_clock(int handle, ::Array<Float> fbuf);
extern int fmod_cg_set_delay(int handle, double startClock, double endClock, bool stopChannels);
extern int fmod_cg_add_fade_point(int handle, double clock, float volume);
extern int fmod_cg_set_fade_point_ramp(int handle, double clock, float volume);
extern int fmod_cg_remove_fade_points(int handle, double startClock, double endClock);

// Core reverb zones
extern int fmod_sys_create_reverb3d();
extern int fmod_r3d_release(int handle);
extern int fmod_r3d_set_3d_attributes(int handle, float x, float y, float z, float minDist, float maxDist);
extern int fmod_r3d_set_properties(int handle, ::Array<Float> fbuf);
extern int fmod_r3d_get_properties(int handle, ::Array<Float> fbuf);
extern int fmod_r3d_set_active(int handle, bool active);

// Core sound surface
extern int fmod_core_create_sound_pcm(::Array<unsigned char> data, int len, int sampleRate, int channels);
extern int fmod_core_play_sound(int handle, bool startPaused);
extern int fmod_sound_set_defaults(int handle, float frequency, int priority);
extern int fmod_sound_get_defaults(int handle, ::Array<Float> fbuf);
extern int fmod_sound_set_loop_points(int handle, int startMs, int endMs);
extern int fmod_sound_get_loop_points(int handle, ::Array<int> ibuf);
extern int fmod_sound_set_mode(int handle, int mode);
extern int fmod_sound_get_mode(int handle);
extern int fmod_sound_get_format(int handle, ::Array<int> ibuf);
extern int fmod_sound_get_open_state(int handle);

// Core system extras (slice 3)
extern int fmod_sys_get_channels_playing(::Array<int> ibuf);
extern int fmod_sys_mixer_suspend();
extern int fmod_sys_mixer_resume();
extern int fmod_sys_get_software_format(::Array<int> ibuf);
extern int fmod_dsp_get_cpu_usage(int handle, ::Array<int> ibuf);

//// Debug
extern int fmod_debug_live_handle_count();
extern int fmod_binding_abi_version();

// Channel callbacks and sync points
extern int fmod_chan_set_callback(int handle, bool enabled);
extern int fmod_sound_add_sync_point(int handle, int offsetMs, const ::String& name);
extern int fmod_sound_delete_sync_point(int handle, int index);
extern int fmod_sound_get_num_sync_points(int handle);
extern const char* fmod_sound_get_sync_point_name(int handle, int index);
extern int fmod_sound_get_sync_point_offset(int handle, int index);

// Sound groups
extern int fmod_sys_create_sound_group(const ::String& name);
extern int fmod_sys_get_master_sound_group();
extern int fmod_sg_release(int handle);
extern int fmod_sg_set_max_audible(int handle, int maxAudible);
extern int fmod_sg_get_max_audible(int handle);
extern int fmod_sg_set_max_audible_behavior(int handle, int behavior);
extern int fmod_sg_get_max_audible_behavior(int handle);
extern int fmod_sg_set_mute_fade_speed(int handle, float speed);
extern int fmod_sg_get_num_sounds(int handle);
extern int fmod_sg_stop(int handle);
extern int fmod_sound_set_sound_group(int handle, int groupHandle);

// System 3D settings and drivers
extern int fmod_sys_set_3d_settings(float doppler, float distanceFactor, float rolloffScale);
extern int fmod_sys_get_3d_settings(::Array<Float> fbuf);
extern int fmod_sys_get_num_drivers();
extern const char* fmod_sys_get_driver_name(int id);

// Getter symmetry for the routing and spatial setters
extern int fmod_chan_get_loop_count(int handle);
extern float fmod_chan_get_low_pass_gain(int handle);
extern int fmod_chan_get_mode(int handle);
extern int fmod_chan_get_3d_cone_settings(int handle, ::Array<Float> fbuf);
extern float fmod_chan_get_3d_spread(int handle);
extern float fmod_chan_get_3d_level(int handle);
extern float fmod_chan_get_3d_doppler_level(int handle);
extern int fmod_chan_get_3d_min_max(int handle, ::Array<Float> fbuf);
extern int fmod_chan_get_3d_attributes(int handle, ::Array<Float> fbuf);
extern int fmod_chan_get_delay(int handle, ::Array<Float> fbuf);
extern int fmod_dsp_get_wet_dry_mix(int handle, ::Array<Float> fbuf);
extern bool fmod_dsp_get_active(int handle);
extern int fmod_dsp_get_metering_enabled(int handle, ::Array<int> ibuf);

} // namespace faxe
} // namespace linc
