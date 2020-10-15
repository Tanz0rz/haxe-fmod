package haxefmod;

import haxefmod.FmodInternalEnums;
private abstract FaxeString(hl.Bytes) from hl.Bytes to hl.Bytes {
	@:from static function fromHaxe(s:String)
		return @:privateAccess new FaxeString(s.toUtf8());

	inline function new(b:hl.Bytes)
		this = b;

	@:to function toHaxe() {
		return @:privateAccess String.fromUTF8(this);
	}
}
extern class HaxeFmod {
	// FMOD System
	@:hlNative("faxe","fmod_set_debug")
	public static function fmod_set_debug(onOff:Bool):Void;
	@:hlNative("faxe","fmod_is_initialized")
	public static function fmod_is_initialized():Bool;
	@:hlNative("faxe","fmod_init")
	public static function fmod_init(numChannels:Int):Void;
	@:hlNative("faxe","fmod_update")
	public static function fmod_update():Void;

	// Sound Banks
	@:hlNative("faxe","fmod_load_bank")
	public static function fmod_load_bank(bankFilePath:FaxeString):Void;
	@:hlNative("faxe","fmod_unload_bank")
	public static function fmod_unload_bank(bankFilePath:FaxeString):Void;

	// Events
	@:hlNative("faxe","fmod_create_event_instance_one_shot")
	public static function fmod_create_event_instance_one_shot(eventPath:FaxeString):Void;
	@:hlNative("faxe","fmod_create_event_instance_named")
	public static function fmod_create_event_instance_named(eventPath:FaxeString, eventInstanceName:FaxeString):Void;
	@:hlNative("faxe","fmod_is_event_instance_loaded")
	public static function fmod_is_event_instance_loaded(eventInstanceName:FaxeString):Bool;
	@:hlNative("faxe","fmod_play_event_instance")
	public static function fmod_play_event_instance(eventInstanceName:FaxeString):Void;
	@:hlNative("faxe","fmod_set_pause_on_event_instance")
	public static function fmod_set_pause_on_event_instance(eventInstanceName:FaxeString, shouldBePaused:Bool):Void;
	@:hlNative("faxe","fmod_stop_event_instance")
	public static function fmod_stop_event_instance(eventInstanceName:FaxeString):Void;
	@:hlNative("faxe","fmod_stop_event_instance")
	public static function fmod_stop_event_instance_immediately(eventInstanceName:FaxeString):Void;
	@:hlNative("faxe","fmod_release_event_instance")
	public static function fmod_release_event_instance(eventInstanceName:FaxeString):Void;
	@:hlNative("faxe","fmod_is_event_instance_playing")
	public static function fmod_is_event_instance_playing(eventInstanceName:FaxeString):Bool;
	@:hlNative("faxe","fmod_get_event_instance_playback_state")
	public static function fmod_get_event_instance_playback_state(eventInstanceName:FaxeString):FmodStudioPlaybackState;
	@:hlNative("faxe","fmod_get_event_instance_param")
	public static function fmod_get_event_instance_param(eventInstanceName:FaxeString, paramName:FaxeString):hl.F32;
	@:hlNative("faxe","fmod_set_event_instance_param")
	public static function fmod_set_event_instance_param(eventInstanceName:FaxeString, paramName:FaxeString, value:hl.F32):Void;

	// Callbacks
	@:hlNative("faxe","fmod_set_callback_tracking_for_event_instance")
	public static function fmod_set_callback_tracking_for_event_instance(eventInstanceName:FaxeString):Void;
	@:hlNative("faxe","fmod_check_callbacks_for_event_instance")
	public static function fmod_check_callbacks_for_event_instance(eventInstanceName:FaxeString, callbackEventMask:UInt):Bool;
}
