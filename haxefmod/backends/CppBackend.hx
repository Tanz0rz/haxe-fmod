package haxefmod.backends;

import haxefmod.FmodInternalEnums;
import haxefmod.backends.IFmodBackend.FmodEventHandle;

#if cpp
/**
 * C++ backend implementation using linc/hxcpp bindings.
 *
 * NOTE: The underlying linc_faxe.cpp still uses name-based lookups internally.
 * This wrapper converts handles to string keys ("h0", "h1", etc.) as a bridge.
 * This keeps the Haxe API consistent while allowing gradual simplification
 * of the C++ native code later.
 */
@:keep
#if !display
@:build(faxe.Linc.touch())
@:build(faxe.Linc.xml('faxe', '../../'))
#end
@:cppInclude('linc_faxe.h')
class CppBackend implements IFmodBackend {
    private var nextHandle:Int = 0;

    public function new() {}

    // Convert handle to string key for C++ layer
    private inline function handleToKey(handle:FmodEventHandle):String {
        return 'h$handle';
    }

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

    //// Event Instances (handle-based, bridged to name-based C++)

    public function createEventInstanceOneShot(eventPath:String):Void {
        CppFmod.fmod_create_event_instance_one_shot(eventPath);
    }

    public function createEventInstance(eventPath:String):FmodEventHandle {
        var handle = nextHandle++;
        var key = handleToKey(handle);
        CppFmod.fmod_create_event_instance_named(eventPath, key);
        return handle;
    }

    public function playEventInstance(handle:FmodEventHandle):Void {
        CppFmod.fmod_play_event_instance(handleToKey(handle));
    }

    public function isEventInstancePlaying(handle:FmodEventHandle):Bool {
        return CppFmod.fmod_is_event_instance_playing(handleToKey(handle));
    }

    public function getEventInstancePlaybackState(handle:FmodEventHandle):FmodStudioPlaybackState {
        return CppFmod.fmod_get_event_instance_playback_state(handleToKey(handle));
    }

    public function setPauseOnEventInstance(handle:FmodEventHandle, shouldBePaused:Bool):Void {
        CppFmod.fmod_set_pause_on_event_instance(handleToKey(handle), shouldBePaused);
    }

    public function stopEventInstance(handle:FmodEventHandle):Void {
        CppFmod.fmod_stop_event_instance(handleToKey(handle));
    }

    public function stopEventInstanceImmediately(handle:FmodEventHandle):Void {
        CppFmod.fmod_stop_event_instance_immediately(handleToKey(handle));
    }

    public function releaseEventInstance(handle:FmodEventHandle):Void {
        CppFmod.fmod_release_event_instance(handleToKey(handle));
    }

    //// Parameters

    public function getEventInstanceParam(handle:FmodEventHandle, paramName:String):Float {
        return CppFmod.fmod_get_event_instance_param(handleToKey(handle), paramName);
    }

    public function setEventInstanceParam(handle:FmodEventHandle, paramName:String, value:Float):Void {
        CppFmod.fmod_set_event_instance_param(handleToKey(handle), paramName, value);
    }

    //// Bus operations

    public function setPauseForAllEventsOnBus(busPath:String, shouldBePaused:Bool):Void {
        CppFmod.fmod_set_pause_for_all_events_on_bus(busPath, shouldBePaused);
    }

    public function stopAllEventsOnBus(busPath:String):Void {
        CppFmod.fmod_stop_all_events_on_bus(busPath);
    }

    //// Callbacks

    public function setCallbackTrackingForEventInstance(handle:FmodEventHandle):Void {
        CppFmod.fmod_set_callback_tracking_for_event_instance(handleToKey(handle));
    }

    public function checkCallbacksForEventInstance(handle:FmodEventHandle, callbackEventMask:UInt):Bool {
        return CppFmod.fmod_check_callbacks_for_event_instance(handleToKey(handle), callbackEventMask);
    }
}

/**
 * Native extern declarations for C++ FMOD bindings.
 * These still use name-based API internally.
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
