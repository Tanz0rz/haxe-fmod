package haxefmod.backends;

import haxefmod.FmodInternalEnums;

/**
 * Handle type for FMOD event instances.
 * This is an opaque integer - the native backend interprets it as an array index.
 */
typedef FmodEventHandle = Int;

/**
 * Minimal interface for FMOD native backends.
 *
 * DESIGN: The native layer is stateless and handle-based.
 * - createEventInstance() returns an integer handle
 * - All operations take handles, not string names
 * - The Haxe layer (FmodCache) manages name→handle mapping
 * - Native code is just a thin array of FMOD pointers
 *
 * This eliminates duplicate caching logic across C++/JS/HL backends.
 */
interface IFmodBackend {
    //// System
    function setDebug(onOff:Bool):Void;
    function isInitialized():Bool;
    function init(numChannels:Int):Void;
    function update():Void;

    /** Enables/disables automatic FMOD updates on a background timer (~60fps).
        When enabled, FMOD processes changes even when the game loop is paused. */
    function setAutoUpdate(enabled:Bool):Void;

    //// Banks
    function loadBank(bankFilePath:String):Void;
    function unloadBank(bankFilePath:String):Void;

    //// Event Instances (handle-based)

    /** Creates a one-shot event (plays immediately, auto-releases when done) */
    function createEventInstanceOneShot(eventPath:String):Void;

    /**
     * Creates an event instance and returns a handle to control it.
     * Returns -1 if creation failed.
     */
    function createEventInstance(eventPath:String):FmodEventHandle;

    /** Starts playback of an event instance */
    function playEventInstance(handle:FmodEventHandle):Void;

    /** Checks if an event instance is currently playing */
    function isEventInstancePlaying(handle:FmodEventHandle):Bool;

    /** Gets the playback state of an event instance */
    function getEventInstancePlaybackState(handle:FmodEventHandle):FmodStudioPlaybackState;

    /** Pauses or unpauses an event instance */
    function setPauseOnEventInstance(handle:FmodEventHandle, shouldBePaused:Bool):Void;

    /** Stops an event instance (allows fadeout via AHDSR) */
    function stopEventInstance(handle:FmodEventHandle):Void;

    /** Stops an event instance immediately (no fadeout) */
    function stopEventInstanceImmediately(handle:FmodEventHandle):Void;

    /** Releases an event instance from memory. The handle becomes invalid. */
    function releaseEventInstance(handle:FmodEventHandle):Void;

    //// Parameters
    function getEventInstanceParam(handle:FmodEventHandle, paramName:String):Float;
    function setEventInstanceParam(handle:FmodEventHandle, paramName:String, value:Float):Void;

    //// Bus operations
    function setPauseForAllEventsOnBus(busPath:String, shouldBePaused:Bool):Void;
    function stopAllEventsOnBus(busPath:String):Void;
    function setBusVolume(busPath:String, volume:Float):Void;
    function getBusVolume(busPath:String):Float;
    function setBusMute(busPath:String, mute:Bool):Void;
    function getBusMute(busPath:String):Bool;

    //// Callbacks

    /** Enables callback tracking for an event instance */
    function setCallbackTrackingForEventInstance(handle:FmodEventHandle):Void;

    /** Checks and clears callback flags for an event instance */
    function checkCallbacksForEventInstance(handle:FmodEventHandle, callbackEventMask:UInt):Bool;
}
