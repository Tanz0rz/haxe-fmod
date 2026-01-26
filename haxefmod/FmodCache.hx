package haxefmod;

/**
 * Pure Haxe cache for tracking FMOD resources.
 *
 * This replaces the caching logic that was previously duplicated in both
 * C++ (std::map in linc_faxe.cpp) and JavaScript (object in jaxe.js).
 *
 * The cache tracks:
 * - Named event instances that have been created
 * - Loaded banks
 * - Event paths associated with instance names (for callbacks)
 */
class FmodCache {
    private static var instance:FmodCache;

    /** Maps event instance name -> event path (e.g., "SongEventInstance" -> "event:/Music/MainLevel") */
    private var eventInstances:Map<String, String>;

    /** Set of loaded bank file paths */
    private var loadedBanks:Map<String, Bool>;

    /** Warning threshold for too many cached instances */
    private static inline var MAX_INSTANCES_WARNING:Int = 25;

    private function new() {
        eventInstances = new Map<String, String>();
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
     */
    public function registerEventInstance(instanceName:String, eventPath:String):Void {
        eventInstances.set(instanceName, eventPath);
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
     * Gets the event path for a registered instance name.
     * @return The event path, or null if not found
     */
    public function getEventPath(instanceName:String):Null<String> {
        return eventInstances.get(instanceName);
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
        eventInstances = new Map<String, String>();
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
