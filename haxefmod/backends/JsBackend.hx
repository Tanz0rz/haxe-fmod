package haxefmod.backends;

import haxefmod.FmodInternalEnums;
import haxefmod.backends.IFmodBackend.FmodEventHandle;

#if js
/**
 * JavaScript backend - All logic lives here, native code is minimal FFI.
 *
 * DESIGN: Native jaxe.js is just raw FMOD API calls.
 * All error handling, debug logging, and state comparison happens here in Haxe.
 */
class JsBackend implements IFmodBackend {
    private var debug:Bool = false;

    public function new() {}

    private inline function log(msg:String):Void {
        if (debug) js.Browser.console.log('FMOD JS: $msg');
    }

    //// System

    public function setDebug(onOff:Bool):Void {
        debug = onOff;
        log('Debug ${onOff ? "enabled" : "disabled"}');
    }

    public function isInitialized():Bool {
        return JsFmod.fmod_is_initialized();
    }

    public function init(numChannels:Int):Void {
        JsFmod.fmod_init(numChannels);
        log('Initializing...');
    }

    public function update():Void {
        JsFmod.fmod_update();
    }

    public function setAutoUpdate(enabled:Bool):Void {
        JsFmod.fmod_set_auto_update(enabled);
        log('Auto-update ${enabled ? "enabled" : "disabled"}');
    }

    //// Banks

    public function loadBank(bankFilePath:String):Void {
        var result = JsFmod.fmod_load_bank(bankFilePath);
        if (result == 0) {
            log('Loaded bank: $bankFilePath');
        } else {
            log('Failed to load bank $bankFilePath (error $result)');
        }
    }

    public function unloadBank(bankFilePath:String):Void {
        JsFmod.fmod_unload_bank(bankFilePath);
        log('Unloaded bank: $bankFilePath');
    }

    //// Event Instances

    public function createEventInstanceOneShot(eventPath:String):Void {
        var result = JsFmod.fmod_fire_one_shot(eventPath);
        if (result != 0) {
            log('Failed to fire one-shot $eventPath (error $result)');
        }
    }

    public function createEventInstance(eventPath:String):FmodEventHandle {
        var handle = JsFmod.fmod_create_instance(eventPath);
        if (handle >= 0) {
            // Auto-start on creation
            JsFmod.fmod_start(handle);
            log('Created instance $handle for $eventPath');
        } else {
            log('Failed to create instance for $eventPath');
        }
        return handle;
    }

    public function playEventInstance(handle:FmodEventHandle):Void {
        JsFmod.fmod_start(handle);
    }

    public function isEventInstancePlaying(handle:FmodEventHandle):Bool {
        var state:FmodStudioPlaybackState = cast JsFmod.fmod_get_playback_state(handle);
        return state == FmodStudioPlaybackState.FMOD_STUDIO_PLAYBACK_PLAYING;
    }

    public function getEventInstancePlaybackState(handle:FmodEventHandle):FmodStudioPlaybackState {
        return cast JsFmod.fmod_get_playback_state(handle);
    }

    public function setPauseOnEventInstance(handle:FmodEventHandle, shouldBePaused:Bool):Void {
        JsFmod.fmod_set_paused(handle, shouldBePaused);
    }

    public function stopEventInstance(handle:FmodEventHandle):Void {
        JsFmod.fmod_stop(handle, 0); // Allow fadeout
    }

    public function stopEventInstanceImmediately(handle:FmodEventHandle):Void {
        JsFmod.fmod_stop(handle, 1); // Immediate
    }

    public function releaseEventInstance(handle:FmodEventHandle):Void {
        JsFmod.fmod_release(handle);
    }

    //// Parameters

    public function getEventInstanceParam(handle:FmodEventHandle, paramName:String):Float {
        return JsFmod.fmod_get_param(handle, paramName);
    }

    public function setEventInstanceParam(handle:FmodEventHandle, paramName:String, value:Float):Void {
        JsFmod.fmod_set_param(handle, paramName, value);
    }

    //// Bus operations

    public function setPauseForAllEventsOnBus(busPath:String, shouldBePaused:Bool):Void {
        JsFmod.fmod_set_bus_paused(busPath, shouldBePaused);
    }

    public function stopAllEventsOnBus(busPath:String):Void {
        JsFmod.fmod_stop_bus(busPath);
    }

    public function setBusVolume(busPath:String, volume:Float):Void {
        JsFmod.fmod_set_bus_volume(busPath, volume);
    }

    public function getBusVolume(busPath:String):Float {
        return JsFmod.fmod_get_bus_volume(busPath);
    }

    public function setBusMute(busPath:String, mute:Bool):Void {
        JsFmod.fmod_set_bus_mute(busPath, mute);
    }

    public function getBusMute(busPath:String):Bool {
        return JsFmod.fmod_get_bus_mute(busPath);
    }

    //// Callbacks

    public function setCallbackTrackingForEventInstance(handle:FmodEventHandle):Void {
        JsFmod.fmod_enable_callbacks(handle);
    }

    public function checkCallbacksForEventInstance(handle:FmodEventHandle, callbackEventMask:UInt):Bool {
        return JsFmod.fmod_poll_callbacks(handle, callbackEventMask);
    }
}

/**
 * Minimal native FFI declarations.
 * These map directly to raw FMOD API calls in jaxe.js.
 */
@:native("jaxe")
private extern class JsFmod {
    // System
    public static function fmod_is_initialized():Bool;
    public static function fmod_init(numChannels:Int):Void;
    public static function fmod_update():Void;
    public static function fmod_set_auto_update(enabled:Bool):Void;

    // Banks
    public static function fmod_load_bank(path:String):Int;
    public static function fmod_unload_bank(path:String):Void;

    // Events
    public static function fmod_fire_one_shot(eventPath:String):Int;
    public static function fmod_create_instance(eventPath:String):Int;
    public static function fmod_start(handle:Int):Void;
    public static function fmod_stop(handle:Int, immediate:Int):Void;
    public static function fmod_release(handle:Int):Void;
    public static function fmod_set_paused(handle:Int, paused:Bool):Void;
    public static function fmod_get_playback_state(handle:Int):Int;

    // Parameters
    public static function fmod_get_param(handle:Int, name:String):Float;
    public static function fmod_set_param(handle:Int, name:String, value:Float):Void;

    // Bus
    public static function fmod_set_bus_paused(path:String, paused:Bool):Void;
    public static function fmod_stop_bus(path:String):Void;
    public static function fmod_set_bus_volume(path:String, volume:Float):Void;
    public static function fmod_get_bus_volume(path:String):Float;
    public static function fmod_set_bus_mute(path:String, mute:Bool):Void;
    public static function fmod_get_bus_mute(path:String):Bool;

    // Callbacks
    public static function fmod_enable_callbacks(handle:Int):Void;
    public static function fmod_poll_callbacks(handle:Int, mask:Int):Bool;
}
#end
