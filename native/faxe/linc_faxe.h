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

//// Studio System (2.0 bindings)
extern int fmod_sys_last_result();
extern int fmod_sys_get_bus(const ::String& path);

//// Bus (2.0 bindings)
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

//// Debug
extern int fmod_debug_live_handle_count();

} // namespace faxe
} // namespace linc
