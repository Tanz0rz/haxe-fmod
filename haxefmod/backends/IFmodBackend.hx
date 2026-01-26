package haxefmod.backends;

import haxefmod.FmodInternalEnums;

/**
 * Minimal interface for FMOD native backends.
 * Each backend implements raw FMOD API calls only - no caching or high-level logic.
 *
 * Event instances are identified by name strings. The backend maintains the mapping
 * from names to native FMOD handles internally.
 */
interface IFmodBackend {
    //// System
    function setDebug(onOff:Bool):Void;
    function isInitialized():Bool;
    function init(numChannels:Int):Void;
    function update():Void;

    //// Banks
    function loadBank(bankFilePath:String):Void;
    function unloadBank(bankFilePath:String):Void;

    //// Event Instances

    /** Creates a one-shot event (plays immediately, auto-releases when done) */
    function createEventInstanceOneShot(eventPath:String):Void;

    /** Creates a named event instance that can be controlled */
    function createEventInstanceNamed(eventPath:String, eventInstanceName:String):Void;

    /** Checks if a named event instance exists in the native cache */
    function isEventInstanceLoaded(eventInstanceName:String):Bool;

    /** Starts playback of a named event instance */
    function playEventInstance(eventInstanceName:String):Void;

    /** Checks if a named event instance is currently playing */
    function isEventInstancePlaying(eventInstanceName:String):Bool;

    /** Gets the playback state of a named event instance */
    function getEventInstancePlaybackState(eventInstanceName:String):FmodStudioPlaybackState;

    /** Pauses or unpauses a named event instance */
    function setPauseOnEventInstance(eventInstanceName:String, shouldBePaused:Bool):Void;

    /** Stops a named event instance (allows fadeout via AHDSR) */
    function stopEventInstance(eventInstanceName:String):Void;

    /** Stops a named event instance immediately (no fadeout) */
    function stopEventInstanceImmediately(eventInstanceName:String):Void;

    /** Releases a named event instance from memory */
    function releaseEventInstance(eventInstanceName:String):Void;

    //// Parameters
    function getEventInstanceParam(eventInstanceName:String, paramName:String):Float;
    function setEventInstanceParam(eventInstanceName:String, paramName:String, value:Float):Void;

    //// Bus operations
    function setPauseForAllEventsOnBus(busPath:String, shouldBePaused:Bool):Void;
    function stopAllEventsOnBus(busPath:String):Void;

    //// Callbacks

    /** Enables callback tracking for a named event instance */
    function setCallbackTrackingForEventInstance(eventInstanceName:String):Void;

    /** Checks and clears callback flags for a named event instance */
    function checkCallbacksForEventInstance(eventInstanceName:String, callbackEventMask:UInt):Bool;
}
