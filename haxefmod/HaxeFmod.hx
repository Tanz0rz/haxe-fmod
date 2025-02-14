package haxefmod;

import haxefmod.FmodInternalEnums;

#if (windows||linux)
@:keep
@:include('linc_faxe.h')
#if !display
@:build(faxe.Linc.touch())
@:build(faxe.Linc.xml('faxe'))
#end
extern class HaxeFmod {

    //// FMOD System

    @:native("linc::faxe::fmod_set_debug")
    public static function fmod_set_debug(onOff:Bool):Void;
    @:native("linc::faxe::fmod_is_initialized")
    public static function fmod_is_initialized():Bool;
    @:native("linc::faxe::fmod_init")
    public static function fmod_init(numChannels:Int = 128):Void;
    @:native("linc::faxe::fmod_update")
    public static function fmod_update():Void;

    //// Sound Banks

    @:native("linc::faxe::fmod_load_bank")
    public static function fmod_load_bank(bankFilePath:String):Void;
    @:native("linc::faxe::fmod_unload_bank")
    public static function fmod_unload_bank(bankFilePath:String):Void;

    //// Events

    @:native("linc::faxe::fmod_create_event_instance_one_shot")
    public static function fmod_create_event_instance_one_shot(eventPath:String):Void;
    @:native("linc::faxe::fmod_create_event_instance_named")
    public static function fmod_create_event_instance_named(eventPath:String, eventInstanceName:String):Void;
    @:native("linc::faxe::fmod_is_event_instance_loaded")
    public static function fmod_is_event_instance_loaded(eventInstanceName:String):Bool;
    @:native("linc::faxe::fmod_play_event_instance")
    public static function fmod_play_event_instance(eventInstanceName:String):Void;
    @:native("linc::faxe::fmod_set_pause_for_all_events_on_bus")
    public static function fmod_set_pause_for_all_events_on_bus(busPath:String, shouldBePaused:Bool):Void;
    @:native("linc::faxe::fmod_stop_all_events_on_bus")
    public static function fmod_stop_all_events_on_bus(busPath:String):Void;
    @:native("linc::faxe::fmod_set_pause_on_event_instance")
    public static function fmod_set_pause_on_event_instance(eventInstanceName:String, shouldBePaused:Bool):Void;
    @:native("linc::faxe::fmod_stop_event_instance")
    public static function fmod_stop_event_instance(eventInstanceName:String):Void;
    @:native("linc::faxe::fmod_stop_event_instance")
    public static function fmod_stop_event_instance_immediately(eventInstanceName:String):Void;
    @:native("linc::faxe::fmod_release_event_instance")
    public static function fmod_release_event_instance(eventInstanceName:String):Void;
    @:native("linc::faxe::fmod_is_event_instance_playing")
    public static function fmod_is_event_instance_playing(eventInstanceName:String):Bool;
    @:native("linc::faxe::fmod_get_event_instance_playback_state")
    public static function fmod_get_event_instance_playback_state(eventInstanceName:String):FmodStudioPlaybackState;
    @:native("linc::faxe::fmod_get_event_instance_param")
    public static function fmod_get_event_instance_param(eventInstanceName:String, paramName:String):Float;
    @:native("linc::faxe::fmod_set_event_instance_param")
    public static function fmod_set_event_instance_param(eventInstanceName:String, paramName:String, value:Float):Void;

    //// Callbacks

    @:native("linc::faxe::fmod_set_callback_tracking_for_event_instance")
    public static function fmod_set_callback_tracking_for_event_instance(eventInstanceName:String):Void;
    @:native("linc::faxe::fmod_check_callbacks_for_event_instance")
    public static function fmod_check_callbacks_for_event_instance(eventInstanceName:String, callbackEventMask:UInt):Bool; 
}

#elseif html5
@:native("jaxe")
extern class HaxeFmod {

    //// FMOD System

    public static function fmod_set_debug(onOff:Bool):Void;
    public static function fmod_is_initialized():Bool;
    public static function fmod_init(numChannels:Int = 128):Void;
    public static function fmod_update():Void;

    //// Sound Banks

    public static function fmod_load_bank(bankFilePath:String):Void;
    public static function fmod_unload_bank(bankFilePath:String):Void;

    //// Events

    public static function fmod_create_event_instance_one_shot(eventPath:String):Void;
    public static function fmod_create_event_instance_named(eventPath:String, eventInstanceName:String):Void;
    public static function fmod_is_event_instance_loaded(eventInstanceName:String):Bool;
    public static function fmod_play_event_instance(eventInstanceName:String):Void;
    public static function fmod_set_pause_for_all_events_on_bus(busPath:String, shouldBePaused:Bool):Void;
    public static function fmod_stop_all_events_on_bus(busPath:String):Void;
    public static function fmod_set_pause_on_event_instance(eventInstanceName:String, shouldBePaused:Bool):Void;
    public static function fmod_stop_event_instance(eventInstanceName:String):Void;
    public static function fmod_stop_event_instance_immediately(eventInstanceName:String):Void;
    public static function fmod_release_event_instance(eventInstanceName:String):Void;
    public static function fmod_is_event_instance_playing(eventInstanceName:String):Bool;
    public static function fmod_get_event_instance_playback_state(eventInstanceName:String):FmodStudioPlaybackState;
    public static function fmod_get_event_instance_param(eventInstanceName:String, paramName:String):Float;
    public static function fmod_set_event_instance_param(eventInstanceName:String, paramName:String, value:Float):Void;

    //// Callbacks

    public static function fmod_set_callback_tracking_for_event_instance(eventInstanceName:String):Void;
    public static function fmod_check_callbacks_for_event_instance(eventInstanceName:String, callbackEventMask:UInt):Bool; 
}
#end