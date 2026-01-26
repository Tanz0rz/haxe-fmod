package haxefmod;

import haxefmod.backends.IFmodBackend.FmodEventHandle;

/**
 * Cached event instance data.
 */
typedef CachedInstance = {
    var eventPath:String;
    var handle:FmodEventHandle;
}

/**
 * Pure Haxe cache for tracking FMOD resources.
 *
 * This is the SINGLE SOURCE OF TRUTH for name→handle mapping.
 * Native backends are stateless - they just maintain an array of FMOD pointers
 * indexed by the handle. All name resolution happens here in Haxe.
 *
 * The cache tracks:
 * - Named event instances: name → {eventPath, handle}
 * - Loaded banks: path → true
 */
class FmodCache {
    private static var instance:FmodCache;

    /** Maps event instance name → cached data (event path + native handle) */
    private var eventInstances:Map<String, CachedInstance>;

    /** Set of loaded bank file paths */
    private var loadedBanks:Map<String, Bool>;

    /** Warning threshold for too many cached instances */
    private static inline var MAX_INSTANCES_WARNING:Int = 25;

    /** Invalid handle constant */
    public static inline var INVALID_HANDLE:FmodEventHandle = -1;

    private function new() {
        eventInstances = new Map<String, CachedInstance>();
        loadedBanks = new Map<String, Bool>();
    }

    public static function getInstance():FmodCache {
        if (instance == null) {
            instance = new FmodCache();
        }
        return instance;
    }

    //// Event Instance Cache

    /**
     * Registers a new event instance in the cache.
     * @param instanceName The unique name for this instance
     * @param eventPath The FMOD event path (e.g., "event:/Music/MainLevel")
     * @param handle The native handle returned by the backend
     */
    public function registerEventInstance(instanceName:String, eventPath:String, handle:FmodEventHandle):Void {
        eventInstances.set(instanceName, {eventPath: eventPath, handle: handle});
        checkInstanceCount();
    }

    /**
     * Removes an event instance from the cache.
     */
    public function unregisterEventInstance(instanceName:String):Void {
        eventInstances.remove(instanceName);
    }

    /**
     * Checks if an event instance is registered in the cache.
     */
    public function hasEventInstance(instanceName:String):Bool {
        return eventInstances.exists(instanceName);
    }

    /**
     * Gets the native handle for a registered instance name.
     * @return The handle, or INVALID_HANDLE (-1) if not found
     */
    public function getHandle(instanceName:String):FmodEventHandle {
        var cached = eventInstances.get(instanceName);
        if (cached != null) {
            return cached.handle;
        }
        return INVALID_HANDLE;
    }

    /**
     * Gets the event path for a registered instance name.
     * @return The event path, or null if not found
     */
    public function getEventPath(instanceName:String):Null<String> {
        var cached = eventInstances.get(instanceName);
        if (cached != null) {
            return cached.eventPath;
        }
        return null;
    }

    /**
     * Gets all registered instance names.
     */
    public function getAllInstanceNames():Iterator<String> {
        return eventInstances.keys();
    }

    /**
     * Checks instance count and warns if too many are cached.
     */
    private function checkInstanceCount():Void {
        var count = 0;
        for (_ in eventInstances) {
            count++;
        }

        if (count > MAX_INSTANCES_WARNING) {
            trace('Warn: FMOD - The number of cached sounds is now $count. '
                + 'Remember to call ReleaseSound() after a sound is no longer needed to avoid memory issues.');
        }
    }

    //// Bank Cache

    /**
     * Marks a bank as loaded.
     */
    public function registerBank(bankPath:String):Void {
        loadedBanks.set(bankPath, true);
    }

    /**
     * Marks a bank as unloaded.
     */
    public function unregisterBank(bankPath:String):Void {
        loadedBanks.remove(bankPath);
    }

    /**
     * Checks if a bank is loaded.
     */
    public function isBankLoaded(bankPath:String):Bool {
        return loadedBanks.exists(bankPath);
    }

    //// Utility

    /**
     * Clears all cached data. Use with caution.
     */
    public function clear():Void {
        eventInstances = new Map<String, CachedInstance>();
        loadedBanks = new Map<String, Bool>();
    }

    /**
     * Gets the number of cached event instances.
     */
    public function getEventInstanceCount():Int {
        var count = 0;
        for (_ in eventInstances) {
            count++;
        }
        return count;
    }
}
