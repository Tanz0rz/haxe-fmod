package haxefmod.backends;

import haxefmod.FmodInternalEnums;
import haxefmod.backends.IFmodBackend.FmodEventHandle;

#if cpp
/**
 * C++ backend - All logic lives here, native code is minimal FFI.
 *
 * DESIGN: Native linc_faxe.cpp is just raw FMOD API calls.
 * All error handling, debug logging, and state comparison happens here in Haxe.
 */
@:keep
#if !display
@:build(haxefmod.backends.CppBackend_Linc.touch())
@:build(haxefmod.backends.CppBackend_Linc.xml('faxe', '../../'))
#end
@:cppInclude('linc_faxe.h')
class CppBackend implements IFmodBackend {
    private var debug:Bool = false;

    public function new() {}

    private inline function log(msg:String):Void {
        if (debug) trace('FMOD CPP: $msg');
    }

    //// System

    public function setDebug(onOff:Bool):Void {
        debug = onOff;
        log('Debug ${onOff ? "enabled" : "disabled"}');
    }

    public function isInitialized():Bool {
        return CppFmod.fmod_is_initialized();
    }

    public function init(numChannels:Int):Void {
        var result = CppFmod.fmod_init(numChannels);
        if (result == 0) {
            log('Initialized with $numChannels channels');
        } else {
            trace('FMOD ERROR: Init failed with error code $result');
        }
    }

    public function update():Void {
        CppFmod.fmod_update();
    }

    public function setAutoUpdate(enabled:Bool):Void {
        CppFmod.fmod_set_auto_update(enabled);
        log('Auto-update ${enabled ? "enabled" : "disabled"}');
    }

    //// Banks

    public function loadBank(bankFilePath:String):Void {
        var result = CppFmod.fmod_load_bank(bankFilePath);
        if (result == 0) {
            log('Loaded bank: $bankFilePath');
        } else {
            trace('FMOD ERROR: Failed to load bank $bankFilePath (error $result)');
        }
    }

    public function unloadBank(bankFilePath:String):Void {
        CppFmod.fmod_unload_bank(bankFilePath);
        log('Unloaded bank: $bankFilePath');
    }

    //// Event Instances

    public function createEventInstanceOneShot(eventPath:String):Void {
        var result = CppFmod.fmod_fire_one_shot(eventPath);
        if (result != 0) {
            log('Failed to fire one-shot $eventPath (error $result)');
        }
    }

    public function createEventInstance(eventPath:String):FmodEventHandle {
        var handle = CppFmod.fmod_create_instance(eventPath);
        if (handle >= 0) {
            // Auto-start on creation
            CppFmod.fmod_start(handle);
            log('Created instance $handle for $eventPath');
        } else {
            log('Failed to create instance for $eventPath');
        }
        return handle;
    }

    public function playEventInstance(handle:FmodEventHandle):Void {
        CppFmod.fmod_start(handle);
    }

    public function isEventInstancePlaying(handle:FmodEventHandle):Bool {
        var state:FmodStudioPlaybackState = cast CppFmod.fmod_get_playback_state(handle);
        return state == FmodStudioPlaybackState.FMOD_STUDIO_PLAYBACK_PLAYING;
    }

    public function getEventInstancePlaybackState(handle:FmodEventHandle):FmodStudioPlaybackState {
        return cast CppFmod.fmod_get_playback_state(handle);
    }

    public function setPauseOnEventInstance(handle:FmodEventHandle, shouldBePaused:Bool):Void {
        CppFmod.fmod_set_paused(handle, shouldBePaused);
    }

    public function stopEventInstance(handle:FmodEventHandle):Void {
        CppFmod.fmod_stop(handle, 0); // Allow fadeout
    }

    public function stopEventInstanceImmediately(handle:FmodEventHandle):Void {
        CppFmod.fmod_stop(handle, 1); // Immediate
    }

    public function releaseEventInstance(handle:FmodEventHandle):Void {
        CppFmod.fmod_release(handle);
    }

    //// Parameters

    public function getEventInstanceParam(handle:FmodEventHandle, paramName:String):Float {
        return CppFmod.fmod_get_param(handle, paramName);
    }

    public function setEventInstanceParam(handle:FmodEventHandle, paramName:String, value:Float):Void {
        CppFmod.fmod_set_param(handle, paramName, value);
    }

    //// Bus operations

    public function setPauseForAllEventsOnBus(busPath:String, shouldBePaused:Bool):Void {
        CppFmod.fmod_set_bus_paused(busPath, shouldBePaused);
    }

    public function stopAllEventsOnBus(busPath:String):Void {
        CppFmod.fmod_stop_bus(busPath);
    }

    public function setBusVolume(busPath:String, volume:Float):Void {
        CppFmod.fmod_set_bus_volume(busPath, volume);
    }

    public function getBusVolume(busPath:String):Float {
        return CppFmod.fmod_get_bus_volume(busPath);
    }

    public function setBusMute(busPath:String, mute:Bool):Void {
        CppFmod.fmod_set_bus_mute(busPath, mute);
    }

    public function getBusMute(busPath:String):Bool {
        return CppFmod.fmod_get_bus_mute(busPath);
    }

    //// Callbacks

    public function setCallbackTrackingForEventInstance(handle:FmodEventHandle):Void {
        CppFmod.fmod_enable_callbacks(handle);
    }

    public function checkCallbacksForEventInstance(handle:FmodEventHandle, callbackEventMask:UInt):Bool {
        return CppFmod.fmod_poll_callbacks(handle, callbackEventMask);
    }
}

/**
 * Minimal native FFI declarations.
 * These map directly to raw FMOD API calls in linc_faxe.cpp.
 */
@:keep
private extern class CppFmod {
    // System
    @:native("linc::faxe::fmod_is_initialized")
    static function fmod_is_initialized():Bool;

    @:native("linc::faxe::fmod_init")
    static function fmod_init(numChannels:Int):Int;

    @:native("linc::faxe::fmod_update")
    static function fmod_update():Void;

    @:native("linc::faxe::fmod_set_auto_update")
    static function fmod_set_auto_update(enabled:Bool):Void;

    // Banks
    @:native("linc::faxe::fmod_load_bank")
    static function fmod_load_bank(path:String):Int;

    @:native("linc::faxe::fmod_unload_bank")
    static function fmod_unload_bank(path:String):Void;

    // Events
    @:native("linc::faxe::fmod_fire_one_shot")
    static function fmod_fire_one_shot(eventPath:String):Int;

    @:native("linc::faxe::fmod_create_instance")
    static function fmod_create_instance(eventPath:String):Int;

    @:native("linc::faxe::fmod_start")
    static function fmod_start(handle:Int):Void;

    @:native("linc::faxe::fmod_stop")
    static function fmod_stop(handle:Int, immediate:Int):Void;

    @:native("linc::faxe::fmod_release")
    static function fmod_release(handle:Int):Void;

    @:native("linc::faxe::fmod_set_paused")
    static function fmod_set_paused(handle:Int, paused:Bool):Void;

    @:native("linc::faxe::fmod_get_playback_state")
    static function fmod_get_playback_state(handle:Int):Int;

    // Parameters
    @:native("linc::faxe::fmod_get_param")
    static function fmod_get_param(handle:Int, name:String):Float;

    @:native("linc::faxe::fmod_set_param")
    static function fmod_set_param(handle:Int, name:String, value:Float):Void;

    // Bus
    @:native("linc::faxe::fmod_set_bus_paused")
    static function fmod_set_bus_paused(path:String, paused:Bool):Void;

    @:native("linc::faxe::fmod_stop_bus")
    static function fmod_stop_bus(path:String):Void;

    @:native("linc::faxe::fmod_set_bus_volume")
    static function fmod_set_bus_volume(path:String, volume:Float):Void;

    @:native("linc::faxe::fmod_get_bus_volume")
    static function fmod_get_bus_volume(path:String):Float;

    @:native("linc::faxe::fmod_set_bus_mute")
    static function fmod_set_bus_mute(path:String, mute:Bool):Void;

    @:native("linc::faxe::fmod_get_bus_mute")
    static function fmod_get_bus_mute(path:String):Bool;

    // Callbacks
    @:native("linc::faxe::fmod_enable_callbacks")
    static function fmod_enable_callbacks(handle:Int):Void;

    @:native("linc::faxe::fmod_poll_callbacks")
    static function fmod_poll_callbacks(handle:Int, mask:Int):Bool;
}
#end
