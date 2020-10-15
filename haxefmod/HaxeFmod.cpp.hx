package haxefmod;

import haxefmod.FmodInternalEnums;

@:keep
@:include('linc_faxe.h')
#if !display
@:build(faxe.Linc.touch())
@:build(faxe.Linc.xml('faxe'))
#end
extern class HaxeFmod {
	// FMOD System
	@:native("faxe_fmod_set_debug")
	public static function fmod_set_debug(onOff:Bool):Void;
	@:native("faxe_fmod_is_initialized")
	public static function fmod_is_initialized():Bool;
	@:native("faxe_fmod_init")
	public static function fmod_init(numChannels:Int = 128):Void;
	@:native("faxe_fmod_update")
	public static function fmod_update():Void;

	// Sound Banks
	@:native("faxe_fmod_load_bank")
	public static function fmod_load_bank(bankFilePath:String):Void;
	@:native("faxe_fmod_unload_bank")
	public static function fmod_unload_bank(bankFilePath:String):Void;

	// Events
	@:native("faxe_fmod_create_event_instance_one_shot")
	public static function fmod_create_event_instance_one_shot(eventPath:String):Void;
	@:native("faxe_fmod_create_event_instance_named")
	public static function fmod_create_event_instance_named(eventPath:String, eventInstanceName:String):Void;
	@:native("faxe_fmod_is_event_instance_loaded")
	public static function fmod_is_event_instance_loaded(eventInstanceName:String):Bool;
	@:native("faxe_fmod_play_event_instance")
	public static function fmod_play_event_instance(eventInstanceName:String):Void;
	@:native("faxe_fmod_set_pause_on_event_instance")
	public static function fmod_set_pause_on_event_instance(eventInstanceName:String, shouldBePaused:Bool):Void;
	@:native("faxe_fmod_stop_event_instance")
	public static function fmod_stop_event_instance(eventInstanceName:String):Void;
	@:native("faxe_fmod_stop_event_instance")
	public static function fmod_stop_event_instance_immediately(eventInstanceName:String):Void;
	@:native("faxe_fmod_release_event_instance")
	public static function fmod_release_event_instance(eventInstanceName:String):Void;
	@:native("faxe_fmod_is_event_instance_playing")
	public static function fmod_is_event_instance_playing(eventInstanceName:String):Bool;
	@:native("faxe_fmod_get_event_instance_playback_state")
	public static function fmod_get_event_instance_playback_state(eventInstanceName:String):FmodStudioPlaybackState;
	@:native("faxe_fmod_get_event_instance_param")
	public static function fmod_get_event_instance_param(eventInstanceName:String, paramName:String):Float;
	@:native("faxe_fmod_set_event_instance_param")
	public static function fmod_set_event_instance_param(eventInstanceName:String, paramName:String, value:Float):Void;

	// Callbacks
	@:native("faxe_fmod_set_callback_tracking_for_event_instance")
	public static function fmod_set_callback_tracking_for_event_instance(eventInstanceName:String):Void;
	@:native("faxe_fmod_check_callbacks_for_event_instance")
	public static function fmod_check_callbacks_for_event_instance(eventInstanceName:String, callbackEventMask:UInt):Bool;
}