package haxefmod.backends;

import haxefmod.FmodInternalEnums;

#if hl
/**
 * HashLink backend implementation using native FFI bindings.
 * Calls FMOD Studio C API functions directly via hlaxe_fmod.hdll.
 */
class HlBackend implements IFmodBackend {
    public function new() {}

    //// System

    public function setDebug(onOff:Bool):Void {
        HlFmod.set_debug(onOff);
    }

    public function isInitialized():Bool {
        return HlFmod.is_initialized();
    }

    public function init(numChannels:Int):Void {
        HlFmod.init(numChannels);
    }

    public function update():Void {
        HlFmod.update();
    }

    //// Banks

    public function loadBank(bankFilePath:String):Void {
        HlFmod.load_bank(toBytes(bankFilePath));
    }

    public function unloadBank(bankFilePath:String):Void {
        HlFmod.unload_bank(toBytes(bankFilePath));
    }

    //// Event Instances

    public function createEventInstanceOneShot(eventPath:String):Void {
        HlFmod.create_event_instance_one_shot(toBytes(eventPath));
    }

    public function createEventInstanceNamed(eventPath:String, eventInstanceName:String):Void {
        HlFmod.create_event_instance_named(toBytes(eventPath), toBytes(eventInstanceName));
    }

    public function isEventInstanceLoaded(eventInstanceName:String):Bool {
        return HlFmod.is_event_instance_loaded(toBytes(eventInstanceName));
    }

    public function playEventInstance(eventInstanceName:String):Void {
        HlFmod.play_event_instance(toBytes(eventInstanceName));
    }

    public function isEventInstancePlaying(eventInstanceName:String):Bool {
        return HlFmod.is_event_instance_playing(toBytes(eventInstanceName));
    }

    public function getEventInstancePlaybackState(eventInstanceName:String):FmodStudioPlaybackState {
        var state = HlFmod.get_event_instance_playback_state(toBytes(eventInstanceName));
        return cast state;
    }

    public function setPauseOnEventInstance(eventInstanceName:String, shouldBePaused:Bool):Void {
        HlFmod.set_pause_on_event_instance(toBytes(eventInstanceName), shouldBePaused);
    }

    public function stopEventInstance(eventInstanceName:String):Void {
        HlFmod.stop_event_instance(toBytes(eventInstanceName));
    }

    public function stopEventInstanceImmediately(eventInstanceName:String):Void {
        HlFmod.stop_event_instance_immediately(toBytes(eventInstanceName));
    }

    public function releaseEventInstance(eventInstanceName:String):Void {
        HlFmod.release_event_instance(toBytes(eventInstanceName));
    }

    //// Parameters

    public function getEventInstanceParam(eventInstanceName:String, paramName:String):Float {
        return HlFmod.get_event_instance_param(toBytes(eventInstanceName), toBytes(paramName));
    }

    public function setEventInstanceParam(eventInstanceName:String, paramName:String, value:Float):Void {
        HlFmod.set_event_instance_param(toBytes(eventInstanceName), toBytes(paramName), value);
    }

    //// Bus operations

    public function setPauseForAllEventsOnBus(busPath:String, shouldBePaused:Bool):Void {
        HlFmod.set_pause_for_all_events_on_bus(toBytes(busPath), shouldBePaused);
    }

    public function stopAllEventsOnBus(busPath:String):Void {
        HlFmod.stop_all_events_on_bus(toBytes(busPath));
    }

    //// Callbacks

    public function setCallbackTrackingForEventInstance(eventInstanceName:String):Void {
        HlFmod.set_callback_tracking_for_event_instance(toBytes(eventInstanceName));
    }

    public function checkCallbacksForEventInstance(eventInstanceName:String, callbackEventMask:UInt):Bool {
        return HlFmod.check_callbacks_for_event_instance(toBytes(eventInstanceName), callbackEventMask);
    }

    //// Utility

    private static inline function toBytes(s:String):hl.Bytes {
        return @:privateAccess s.toUtf8();
    }
}

/**
 * Native extern declarations for HashLink FMOD bindings.
 * These map to functions in hlaxe_fmod.c compiled as hlaxe_fmod.hdll.
 */
@:hlNative("hlaxe_fmod")
private extern class HlFmod {
    static function set_debug(onOff:Bool):Void;
    static function is_initialized():Bool;
    static function init(numChannels:Int):Void;
    static function update():Void;

    static function load_bank(bankFilePath:hl.Bytes):Void;
    static function unload_bank(bankFilePath:hl.Bytes):Void;

    static function create_event_instance_one_shot(eventPath:hl.Bytes):Void;
    static function create_event_instance_named(eventPath:hl.Bytes, eventInstanceName:hl.Bytes):Void;
    static function is_event_instance_loaded(eventInstanceName:hl.Bytes):Bool;
    static function play_event_instance(eventInstanceName:hl.Bytes):Void;
    static function is_event_instance_playing(eventInstanceName:hl.Bytes):Bool;
    static function get_event_instance_playback_state(eventInstanceName:hl.Bytes):Int;
    static function set_pause_on_event_instance(eventInstanceName:hl.Bytes, shouldBePaused:Bool):Void;
    static function stop_event_instance(eventInstanceName:hl.Bytes):Void;
    static function stop_event_instance_immediately(eventInstanceName:hl.Bytes):Void;
    static function release_event_instance(eventInstanceName:hl.Bytes):Void;

    static function get_event_instance_param(eventInstanceName:hl.Bytes, paramName:hl.Bytes):Float;
    static function set_event_instance_param(eventInstanceName:hl.Bytes, paramName:hl.Bytes, value:Float):Void;

    static function set_pause_for_all_events_on_bus(busPath:hl.Bytes, shouldBePaused:Bool):Void;
    static function stop_all_events_on_bus(busPath:hl.Bytes):Void;

    static function set_callback_tracking_for_event_instance(eventInstanceName:hl.Bytes):Void;
    static function check_callbacks_for_event_instance(eventInstanceName:hl.Bytes, callbackEventMask:Int):Bool;
}
#end
