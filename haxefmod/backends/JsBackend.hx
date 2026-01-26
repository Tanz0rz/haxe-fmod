package haxefmod.backends;

import haxefmod.FmodInternalEnums;

#if js
/**
 * JavaScript/HTML5 backend implementation.
 * Wraps the native functions in jaxe.js.
 */
class JsBackend implements IFmodBackend {
    public function new() {}

    //// System

    public function setDebug(onOff:Bool):Void {
        JsFmod.fmod_set_debug(onOff);
    }

    public function isInitialized():Bool {
        return JsFmod.fmod_is_initialized();
    }

    public function init(numChannels:Int):Void {
        JsFmod.fmod_init(numChannels);
    }

    public function update():Void {
        JsFmod.fmod_update();
    }

    //// Banks

    public function loadBank(bankFilePath:String):Void {
        JsFmod.fmod_load_bank(bankFilePath);
    }

    public function unloadBank(bankFilePath:String):Void {
        JsFmod.fmod_unload_bank(bankFilePath);
    }

    //// Event Instances

    public function createEventInstanceOneShot(eventPath:String):Void {
        JsFmod.fmod_create_event_instance_one_shot(eventPath);
    }

    public function createEventInstanceNamed(eventPath:String, eventInstanceName:String):Void {
        JsFmod.fmod_create_event_instance_named(eventPath, eventInstanceName);
    }

    public function isEventInstanceLoaded(eventInstanceName:String):Bool {
        return JsFmod.fmod_is_event_instance_loaded(eventInstanceName);
    }

    public function playEventInstance(eventInstanceName:String):Void {
        JsFmod.fmod_play_event_instance(eventInstanceName);
    }

    public function isEventInstancePlaying(eventInstanceName:String):Bool {
        return JsFmod.fmod_is_event_instance_playing(eventInstanceName);
    }

    public function getEventInstancePlaybackState(eventInstanceName:String):FmodStudioPlaybackState {
        return JsFmod.fmod_get_event_instance_playback_state(eventInstanceName);
    }

    public function setPauseOnEventInstance(eventInstanceName:String, shouldBePaused:Bool):Void {
        JsFmod.fmod_set_pause_on_event_instance(eventInstanceName, shouldBePaused);
    }

    public function stopEventInstance(eventInstanceName:String):Void {
        JsFmod.fmod_stop_event_instance(eventInstanceName);
    }

    public function stopEventInstanceImmediately(eventInstanceName:String):Void {
        JsFmod.fmod_stop_event_instance_immediately(eventInstanceName);
    }

    public function releaseEventInstance(eventInstanceName:String):Void {
        JsFmod.fmod_release_event_instance(eventInstanceName);
    }

    //// Parameters

    public function getEventInstanceParam(eventInstanceName:String, paramName:String):Float {
        return JsFmod.fmod_get_event_instance_param(eventInstanceName, paramName);
    }

    public function setEventInstanceParam(eventInstanceName:String, paramName:String, value:Float):Void {
        JsFmod.fmod_set_event_instance_param(eventInstanceName, paramName, value);
    }

    //// Bus operations

    public function setPauseForAllEventsOnBus(busPath:String, shouldBePaused:Bool):Void {
        JsFmod.fmod_set_pause_for_all_events_on_bus(busPath, shouldBePaused);
    }

    public function stopAllEventsOnBus(busPath:String):Void {
        JsFmod.fmod_stop_all_events_on_bus(busPath);
    }

    //// Callbacks

    public function setCallbackTrackingForEventInstance(eventInstanceName:String):Void {
        JsFmod.fmod_set_callback_tracking_for_event_instance(eventInstanceName);
    }

    public function checkCallbacksForEventInstance(eventInstanceName:String, callbackEventMask:UInt):Bool {
        return JsFmod.fmod_check_callbacks_for_event_instance(eventInstanceName, callbackEventMask);
    }
}

/**
 * Native extern declarations for JavaScript FMOD bindings.
 */
@:native("jaxe")
private extern class JsFmod {
    public static function fmod_set_debug(onOff:Bool):Void;
    public static function fmod_is_initialized():Bool;
    public static function fmod_init(numChannels:Int):Void;
    public static function fmod_update():Void;
    public static function fmod_load_bank(bankFilePath:String):Void;
    public static function fmod_unload_bank(bankFilePath:String):Void;
    public static function fmod_create_event_instance_one_shot(eventPath:String):Void;
    public static function fmod_create_event_instance_named(eventPath:String, eventInstanceName:String):Void;
    public static function fmod_is_event_instance_loaded(eventInstanceName:String):Bool;
    public static function fmod_play_event_instance(eventInstanceName:String):Void;
    public static function fmod_is_event_instance_playing(eventInstanceName:String):Bool;
    public static function fmod_get_event_instance_playback_state(eventInstanceName:String):FmodStudioPlaybackState;
    public static function fmod_set_pause_on_event_instance(eventInstanceName:String, shouldBePaused:Bool):Void;
    public static function fmod_stop_event_instance(eventInstanceName:String):Void;
    public static function fmod_stop_event_instance_immediately(eventInstanceName:String):Void;
    public static function fmod_release_event_instance(eventInstanceName:String):Void;
    public static function fmod_get_event_instance_param(eventInstanceName:String, paramName:String):Float;
    public static function fmod_set_event_instance_param(eventInstanceName:String, paramName:String, value:Float):Void;
    public static function fmod_set_pause_for_all_events_on_bus(busPath:String, shouldBePaused:Bool):Void;
    public static function fmod_stop_all_events_on_bus(busPath:String):Void;
    public static function fmod_set_callback_tracking_for_event_instance(eventInstanceName:String):Void;
    public static function fmod_check_callbacks_for_event_instance(eventInstanceName:String, callbackEventMask:UInt):Bool;
}
#end
