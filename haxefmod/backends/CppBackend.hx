package haxefmod.backends;

import haxefmod.FmodInternalEnums;

#if cpp
/**
 * C++ backend implementation using linc/hxcpp bindings.
 * Wraps the native functions in linc_faxe.cpp.
 */
@:keep
@:include('linc_faxe.h')
#if !display
@:build(faxe.Linc.touch())
@:build(faxe.Linc.xml('faxe'))
#end
class CppBackend implements IFmodBackend {
    public function new() {}

    //// System

    public function setDebug(onOff:Bool):Void {
        CppFmod.fmod_set_debug(onOff);
    }

    public function isInitialized():Bool {
        return CppFmod.fmod_is_initialized();
    }

    public function init(numChannels:Int):Void {
        CppFmod.fmod_init(numChannels);
    }

    public function update():Void {
        CppFmod.fmod_update();
    }

    //// Banks

    public function loadBank(bankFilePath:String):Void {
        CppFmod.fmod_load_bank(bankFilePath);
    }

    public function unloadBank(bankFilePath:String):Void {
        CppFmod.fmod_unload_bank(bankFilePath);
    }

    //// Event Instances

    public function createEventInstanceOneShot(eventPath:String):Void {
        CppFmod.fmod_create_event_instance_one_shot(eventPath);
    }

    public function createEventInstanceNamed(eventPath:String, eventInstanceName:String):Void {
        CppFmod.fmod_create_event_instance_named(eventPath, eventInstanceName);
    }

    public function isEventInstanceLoaded(eventInstanceName:String):Bool {
        return CppFmod.fmod_is_event_instance_loaded(eventInstanceName);
    }

    public function playEventInstance(eventInstanceName:String):Void {
        CppFmod.fmod_play_event_instance(eventInstanceName);
    }

    public function isEventInstancePlaying(eventInstanceName:String):Bool {
        return CppFmod.fmod_is_event_instance_playing(eventInstanceName);
    }

    public function getEventInstancePlaybackState(eventInstanceName:String):FmodStudioPlaybackState {
        return CppFmod.fmod_get_event_instance_playback_state(eventInstanceName);
    }

    public function setPauseOnEventInstance(eventInstanceName:String, shouldBePaused:Bool):Void {
        CppFmod.fmod_set_pause_on_event_instance(eventInstanceName, shouldBePaused);
    }

    public function stopEventInstance(eventInstanceName:String):Void {
        CppFmod.fmod_stop_event_instance(eventInstanceName);
    }

    public function stopEventInstanceImmediately(eventInstanceName:String):Void {
        CppFmod.fmod_stop_event_instance_immediately(eventInstanceName);
    }

    public function releaseEventInstance(eventInstanceName:String):Void {
        CppFmod.fmod_release_event_instance(eventInstanceName);
    }

    //// Parameters

    public function getEventInstanceParam(eventInstanceName:String, paramName:String):Float {
        return CppFmod.fmod_get_event_instance_param(eventInstanceName, paramName);
    }

    public function setEventInstanceParam(eventInstanceName:String, paramName:String, value:Float):Void {
        CppFmod.fmod_set_event_instance_param(eventInstanceName, paramName, value);
    }

    //// Bus operations

    public function setPauseForAllEventsOnBus(busPath:String, shouldBePaused:Bool):Void {
        CppFmod.fmod_set_pause_for_all_events_on_bus(busPath, shouldBePaused);
    }

    public function stopAllEventsOnBus(busPath:String):Void {
        CppFmod.fmod_stop_all_events_on_bus(busPath);
    }

    //// Callbacks

    public function setCallbackTrackingForEventInstance(eventInstanceName:String):Void {
        CppFmod.fmod_set_callback_tracking_for_event_instance(eventInstanceName);
    }

    public function checkCallbacksForEventInstance(eventInstanceName:String, callbackEventMask:UInt):Bool {
        return CppFmod.fmod_check_callbacks_for_event_instance(eventInstanceName, callbackEventMask);
    }
}

/**
 * Native extern declarations for C++ FMOD bindings.
 */
@:keep
private extern class CppFmod {
    @:native("linc::faxe::fmod_set_debug")
    public static function fmod_set_debug(onOff:Bool):Void;

    @:native("linc::faxe::fmod_is_initialized")
    public static function fmod_is_initialized():Bool;

    @:native("linc::faxe::fmod_init")
    public static function fmod_init(numChannels:Int):Void;

    @:native("linc::faxe::fmod_update")
    public static function fmod_update():Void;

    @:native("linc::faxe::fmod_load_bank")
    public static function fmod_load_bank(bankFilePath:String):Void;

    @:native("linc::faxe::fmod_unload_bank")
    public static function fmod_unload_bank(bankFilePath:String):Void;

    @:native("linc::faxe::fmod_create_event_instance_one_shot")
    public static function fmod_create_event_instance_one_shot(eventPath:String):Void;

    @:native("linc::faxe::fmod_create_event_instance_named")
    public static function fmod_create_event_instance_named(eventPath:String, eventInstanceName:String):Void;

    @:native("linc::faxe::fmod_is_event_instance_loaded")
    public static function fmod_is_event_instance_loaded(eventInstanceName:String):Bool;

    @:native("linc::faxe::fmod_play_event_instance")
    public static function fmod_play_event_instance(eventInstanceName:String):Void;

    @:native("linc::faxe::fmod_is_event_instance_playing")
    public static function fmod_is_event_instance_playing(eventInstanceName:String):Bool;

    @:native("linc::faxe::fmod_get_event_instance_playback_state")
    public static function fmod_get_event_instance_playback_state(eventInstanceName:String):FmodStudioPlaybackState;

    @:native("linc::faxe::fmod_set_pause_on_event_instance")
    public static function fmod_set_pause_on_event_instance(eventInstanceName:String, shouldBePaused:Bool):Void;

    @:native("linc::faxe::fmod_stop_event_instance")
    public static function fmod_stop_event_instance(eventInstanceName:String):Void;

    @:native("linc::faxe::fmod_stop_event_instance_immediately")
    public static function fmod_stop_event_instance_immediately(eventInstanceName:String):Void;

    @:native("linc::faxe::fmod_release_event_instance")
    public static function fmod_release_event_instance(eventInstanceName:String):Void;

    @:native("linc::faxe::fmod_get_event_instance_param")
    public static function fmod_get_event_instance_param(eventInstanceName:String, paramName:String):Float;

    @:native("linc::faxe::fmod_set_event_instance_param")
    public static function fmod_set_event_instance_param(eventInstanceName:String, paramName:String, value:Float):Void;

    @:native("linc::faxe::fmod_set_pause_for_all_events_on_bus")
    public static function fmod_set_pause_for_all_events_on_bus(busPath:String, shouldBePaused:Bool):Void;

    @:native("linc::faxe::fmod_stop_all_events_on_bus")
    public static function fmod_stop_all_events_on_bus(busPath:String):Void;

    @:native("linc::faxe::fmod_set_callback_tracking_for_event_instance")
    public static function fmod_set_callback_tracking_for_event_instance(eventInstanceName:String):Void;

    @:native("linc::faxe::fmod_check_callbacks_for_event_instance")
    public static function fmod_check_callbacks_for_event_instance(eventInstanceName:String, callbackEventMask:UInt):Bool;
}
#end
