package haxefmod;

import haxefmod.FmodEvents.FmodCallback;
import haxefmod.backends.IFmodBackend.FmodEventHandle;

/**
 * Callback registration info for an event instance.
 */
class FmodCallbackRegistration {
    public var callbackFunction:Void->Void;
    public var playbackEventMask:UInt;
    public var eventPath:String;
    public var handle:FmodEventHandle;

    public function new(callbackFunction:Void->Void, playbackEventMask:UInt, eventPath:String, handle:FmodEventHandle) {
        this.callbackFunction = callbackFunction;
        this.playbackEventMask = playbackEventMask;
        this.eventPath = eventPath;
        this.handle = handle;
    }
}

/**
 * Pure Haxe manager for FMOD callback tracking.
 *
 * This centralizes callback registration and polling logic that was previously
 * split between Haxe (registration) and native (flag accumulation).
 *
 * Workflow:
 * 1. User calls registerCallback() to register interest in specific events
 * 2. Native backend is told to track callbacks for that instance (via handle)
 * 3. On each update(), we poll the native layer for triggered callbacks
 * 4. If callbacks fired, we execute the registered Haxe functions
 */
class FmodCallbackManager {
    private static var instance:FmodCallbackManager;

    /** Maps event instance name -> callback registration */
    private var registrations:Map<String, FmodCallbackRegistration>;

    private function new() {
        registrations = new Map<String, FmodCallbackRegistration>();
    }

    public static function getInstance():FmodCallbackManager {
        if (instance == null) {
            instance = new FmodCallbackManager();
        }
        return instance;
    }

    /**
     * Registers a callback for an event instance.
     *
     * @param instanceName The event instance name (for lookup/unregistration)
     * @param eventPath The FMOD event path for this instance
     * @param handle The native handle for this instance
     * @param callback The function to call when the event fires
     * @param eventMask Bitmask of FmodCallback values to listen for
     */
    public function registerCallback(instanceName:String, eventPath:String, handle:FmodEventHandle, callback:Void->Void, eventMask:UInt):Void {
        var registration = new FmodCallbackRegistration(callback, eventMask, eventPath, handle);
        registrations.set(instanceName, registration);
    }

    /**
     * Unregisters callbacks for an event instance.
     */
    public function unregisterCallback(instanceName:String):Void {
        registrations.remove(instanceName);
    }

    /**
     * Checks if callbacks are registered for an instance.
     */
    public function hasCallback(instanceName:String):Bool {
        return registrations.exists(instanceName);
    }

    /**
     * Gets the callback registration for an instance.
     */
    public function getRegistration(instanceName:String):Null<FmodCallbackRegistration> {
        return registrations.get(instanceName);
    }

    /**
     * Gets all instance names that have registered callbacks.
     */
    public function getRegisteredInstances():Iterator<String> {
        return registrations.keys();
    }

    /**
     * Processes callbacks by polling the native backend.
     * Should be called each frame from FmodManager.Update().
     *
     * @param checkCallback Function that checks native callback flags.
     *        Signature: (handle:FmodEventHandle, eventMask:UInt) -> Bool
     */
    public function processCallbacks(checkCallback:(FmodEventHandle, UInt) -> Bool):Void {
        for (instanceName in registrations.keys()) {
            var reg = registrations.get(instanceName);
            if (reg != null && checkCallback(reg.handle, reg.playbackEventMask)) {
                reg.callbackFunction();
            }
        }
    }

    /**
     * Clears all callback registrations.
     */
    public function clearAll():Void {
        registrations = new Map<String, FmodCallbackRegistration>();
    }

    /**
     * Gets the number of registered callbacks.
     */
    public function getRegistrationCount():Int {
        var count = 0;
        for (_ in registrations) {
            count++;
        }
        return count;
    }
}
