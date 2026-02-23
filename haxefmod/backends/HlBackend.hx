package haxefmod.backends;

import haxefmod.FmodInternalEnums;
import haxefmod.backends.IFmodBackend.FmodEventHandle;

#if hl
/**
 * HashLink backend - All logic lives here, native code is minimal FFI.
 *
 * DESIGN: Native hlaxe_fmod.c is just raw FMOD API calls.
 * All error handling, debug logging, and state comparison happens here in Haxe.
 */
class HlBackend implements IFmodBackend {
    private var debug:Bool = false;

    public function new() {}

    private inline function log(msg:String):Void {
        if (debug) trace('FMOD HL: $msg');
    }

    private static inline function toBytes(s:String):hl.Bytes {
        return @:privateAccess s.toUtf8();
    }

    //// System

    public function setDebug(onOff:Bool):Void {
        debug = onOff;
        log('Debug ${onOff ? "enabled" : "disabled"}');
    }

    public function isInitialized():Bool {
        return HlFmod.is_initialized();
    }

    public function init(numChannels:Int):Void {
        var result = HlFmod.init(numChannels);
        if (result == 0) {
            log('Initialized with $numChannels channels');
        } else {
            trace('FMOD ERROR: Init failed with error code $result');
        }
    }

    public function update():Void {
        HlFmod.update();
    }

    public function setAutoUpdate(enabled:Bool):Void {
        HlFmod.set_auto_update(enabled);
        log('Auto-update ${enabled ? "enabled" : "disabled"}');
    }

    //// Banks

    public function loadBank(bankFilePath:String):Void {
        var result = HlFmod.load_bank(toBytes(bankFilePath));
        if (result == 0) {
            log('Loaded bank: $bankFilePath');
        } else {
            trace('FMOD ERROR: Failed to load bank $bankFilePath (error $result)');
        }
    }

    public function unloadBank(bankFilePath:String):Void {
        trace('FMOD HL: unloadBank not implemented for HashLink target');
    }

    //// Event Instances

    public function createEventInstanceOneShot(eventPath:String):Void {
        var result = HlFmod.fire_one_shot(toBytes(eventPath));
        if (result != 0) {
            log('Failed to fire one-shot $eventPath (error $result)');
        }
    }

    public function createEventInstance(eventPath:String):FmodEventHandle {
        var handle = HlFmod.create_instance(toBytes(eventPath));
        if (handle >= 0) {
            // Auto-start on creation
            HlFmod.start(handle);
            log('Created instance $handle for $eventPath');
        } else {
            log('Failed to create instance for $eventPath');
        }
        return handle;
    }

    public function playEventInstance(handle:FmodEventHandle):Void {
        HlFmod.start(handle);
    }

    public function isEventInstancePlaying(handle:FmodEventHandle):Bool {
        var state:FmodStudioPlaybackState = cast HlFmod.get_playback_state(handle);
        return state == FmodStudioPlaybackState.FMOD_STUDIO_PLAYBACK_PLAYING;
    }

    public function getEventInstancePlaybackState(handle:FmodEventHandle):FmodStudioPlaybackState {
        return cast HlFmod.get_playback_state(handle);
    }

    public function setPauseOnEventInstance(handle:FmodEventHandle, shouldBePaused:Bool):Void {
        HlFmod.set_paused(handle, shouldBePaused);
    }

    public function getTimelinePosition(handle:FmodEventHandle):Int {
        return HlFmod.get_timeline_position(handle);
    }

    public function stopEventInstance(handle:FmodEventHandle):Void {
        HlFmod.stop(handle, 0); // Allow fadeout
    }

    public function stopEventInstanceImmediately(handle:FmodEventHandle):Void {
        HlFmod.stop(handle, 1); // Immediate
    }

    public function releaseEventInstance(handle:FmodEventHandle):Void {
        HlFmod.release(handle);
    }

    //// Parameters

    public function getEventInstanceParam(handle:FmodEventHandle, paramName:String):Float {
        return HlFmod.get_param(handle, toBytes(paramName));
    }

    public function setEventInstanceParam(handle:FmodEventHandle, paramName:String, value:Float):Void {
        HlFmod.set_param(handle, toBytes(paramName), value);
    }

    //// Bus operations

    public function setPauseForAllEventsOnBus(busPath:String, shouldBePaused:Bool):Void {
        HlFmod.set_bus_paused(toBytes(busPath), shouldBePaused);
    }

    public function stopAllEventsOnBus(busPath:String):Void {
        HlFmod.stop_bus(toBytes(busPath));
    }

    public function setBusVolume(busPath:String, volume:Float):Void {
        HlFmod.set_bus_volume(toBytes(busPath), volume);
    }

    public function getBusVolume(busPath:String):Float {
        return HlFmod.get_bus_volume(toBytes(busPath));
    }

    public function setBusMute(busPath:String, mute:Bool):Void {
        HlFmod.set_bus_mute(toBytes(busPath), mute);
    }

    public function getBusMute(busPath:String):Bool {
        return HlFmod.get_bus_mute(toBytes(busPath));
    }

    //// Callbacks

    public function setCallbackTrackingForEventInstance(handle:FmodEventHandle):Void {
        HlFmod.enable_callbacks(handle);
    }

    public function checkCallbacksForEventInstance(handle:FmodEventHandle, callbackEventMask:UInt):Bool {
        return HlFmod.poll_callbacks(handle, callbackEventMask);
    }
}

/**
 * Minimal native FFI declarations.
 * These map directly to raw FMOD API calls in hlaxe_fmod.c.
 */
@:hlNative("hlaxe_fmod")
private extern class HlFmod {
    // System
    static function is_initialized():Bool;
    static function init(numChannels:Int):Int; // Returns FMOD_RESULT
    static function update():Void;
    static function set_auto_update(enabled:Bool):Void;

    // Banks
    static function load_bank(path:hl.Bytes):Int; // Returns FMOD_RESULT

    // Events
    static function fire_one_shot(eventPath:hl.Bytes):Int; // Returns FMOD_RESULT
    static function create_instance(eventPath:hl.Bytes):Int; // Returns handle or -1
    static function start(handle:Int):Void;
    static function stop(handle:Int, immediate:Int):Void;
    static function release(handle:Int):Void;
    static function set_paused(handle:Int, paused:Bool):Void;
    static function get_playback_state(handle:Int):Int;
    static function get_timeline_position(handle:Int):Int;

    // Parameters
    static function get_param(handle:Int, name:hl.Bytes):Float;
    static function set_param(handle:Int, name:hl.Bytes, value:Float):Void;

    // Bus
    static function set_bus_paused(path:hl.Bytes, paused:Bool):Void;
    static function stop_bus(path:hl.Bytes):Void;
    static function set_bus_volume(path:hl.Bytes, volume:Float):Void;
    static function get_bus_volume(path:hl.Bytes):Float;
    static function set_bus_mute(path:hl.Bytes, mute:Bool):Void;
    static function get_bus_mute(path:hl.Bytes):Bool;

    // Callbacks
    static function enable_callbacks(handle:Int):Void;
    static function poll_callbacks(handle:Int, mask:Int):Bool;
}
#end
