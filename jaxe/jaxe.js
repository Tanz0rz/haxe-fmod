/**
* Haxejs - FMOD bindings for Haxe
*
* The MIT License (MIT)
*
* Copyright (c) 2020 Tanner Moore
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
* THE SOFTWARE.
*/

class jaxe {
	static fmod_set_debug(onOff){
		console.log('fmod_set_debug');
	}
	static fmod_init(numChannels){

		console.log('fmod_init');
	}
	static fmod_update(){
		console.log('fmod_update');
	}
	static fmod_load_bank(bankFilePath){
		console.log('fmod_load_bank');
	}
	static fmod_unload_bank(bankFilePath){
		console.log('fmod_unload_bank');
	}
	static fmod_create_event_instance_one_shot(eventPath){
		console.log('fmod_create_event_instance_one_shot');
	}
	static fmod_create_event_instance_named(eventPath, eventInstanceName){
		console.log('fmod_create_event_instance_named');
	}
	static fmod_is_event_instance_loaded(eventPath){
		console.log('fmod_is_event_instance_loaded');
	}
	static fmod_play_event_instance(eventInstanceName){
		console.log('fmod_play_event_instance');
	}
	static fmod_set_pause_on_event_instance(eventInstanceName, shouldBePaused){
		console.log('fmod_set_pause_on_event_instance');
	}
	static fmod_stop_event_instance(eventInstanceName, forceStop){
		console.log('fmod_stop_event_instance');
	}
	static fmod_release_event_instance(eventInstanceName){
		console.log('fmod_release_event_instance');
	}
	static fmod_is_event_instance_playing(eventInstanceName){
		console.log('fmod_is_event_instance_playing');
	}
	static fmod_get_event_instance_playback_state(eventInstanceName){
		console.log('fmod_get_event_instance_playback_state');
	}
	static fmod_get_event_instance_param(eventInstanceName, paramName){
		console.log('fmod_get_event_instance_param');
	}
	static fmod_set_event_instance_param(eventInstanceName, paramName, value){
		console.log('fmod_set_event_instance_param');
	}
	static fmod_add_playback_listener_to_primary_event_instance(eventInstanceName){
		console.log('fmod_add_playback_listener_to_primary_event_instance');
	}
	static fmod_check_for_primary_event_instance_callback(callbackEventMask){
		console.log('fmod_check_for_primary_event_instance_callback');
	}
}