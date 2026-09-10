package haxefmod.studio;

import haxefmod.studio.Callbacks;
import haxefmod.studio.Types;
import haxefmod.studio.UserData;
import haxefmod.studio.native.NativeStudio;
import haxefmod.studio.native.Scratch;

/**
 * A handle to an FMOD Studio event description (the event "template" that
 * instances are created from). Snapshots are event descriptions too.
 *
 * Obtain via StudioSystem.getEvent("event:/..."). Handles are plain ints
 * under the hood. A stale or invalid handle makes every call a safe no-op.
 */
abstract EventDescription(Int) from Int to Int {
    /** The null handle. Every call on it is a safe no-op. */
    public static inline var NULL:EventDescription = cast 0;

    /** True if this is the invalid handle (lookup failed). */
    public inline function isNull():Bool {
        return this == 0;
    }

    /** True if the handle resolves to a live FMOD event description. */
    public inline function isValid():Bool {
        return this != 0 && NativeStudio.evd_is_valid(this);
    }

    /** The event GUID. Returns an empty FmodGuid on failure, with the reason in StudioSystem.lastResult(). */
    public inline function getID():FmodGuid {
        return NativeStudio.evd_get_id(this);
    }

    /**
     * The full event path, e.g. "event:/Music/MainLevel". Returns "" on failure, with the reason in
     * StudioSystem.lastResult().
     */
    public inline function getPath():String {
        return NativeStudio.evd_get_path(this);
    }

    /**
     * Timeline length in milliseconds. Returns 0 both on failure and for an event with no timeline.
     * StudioSystem.lastResult() tells the two apart.
     */
    public inline function getLength():Int {
        return NativeStudio.evd_get_length(this);
    }

    /** Minimum and maximum attenuation distances, or null on failure. */
    public function getMinMaxDistance():Null<FmodEventMinMaxDistance> {
        var result:FmodResult = NativeStudio.evd_get_min_max_distance(this);
        if (!result.isOk()) return null;
        return {min: Scratch.readF(0), max: Scratch.readF(1)};
    }

    /**
     * The largest Sound Size of the spatializers on the event's master track, in world units. Zero without a
     * spatializer, and on failure. StudioSystem.lastResult() holds the reason for a failure.
     */
    public inline function getSoundSize():Float {
        return NativeStudio.evd_get_sound_size(this);
    }

    /**
     * True if this description is a snapshot. Returns false both on failure and for a plain event.
     * StudioSystem.lastResult() tells the two apart.
     */
    public inline function isSnapshot():Bool {
        return NativeStudio.evd_is_snapshot(this);
    }

    /**
     * True if the event is oneshot. A oneshot event ends on its own in bounded time after it starts. Returns
     * false both on failure and for an event that runs until it is stopped. StudioSystem.lastResult() tells the
     * two apart.
     */
    public inline function isOneshot():Bool {
        return NativeStudio.evd_is_oneshot(this);
    }

    /**
     * True if the event contains streamed sound. Returns false both on failure and for an event with no
     * streamed sound. StudioSystem.lastResult() tells the two apart.
     */
    public inline function isStream():Bool {
        return NativeStudio.evd_is_stream(this);
    }

    /**
     * True if the event is 3D. FMOD counts an event as 3D when its master track carries a spatializer effect.
     * Returns false both on failure and for a 2D event. StudioSystem.lastResult() tells the two apart.
     */
    public inline function is3D():Bool {
        return NativeStudio.evd_is_3d(this);
    }

    /**
     * True if the event has Doppler enabled. Returns false both on failure and for an event with Doppler off.
     * StudioSystem.lastResult() tells the two apart.
     */
    public inline function isDopplerEnabled():Bool {
        return NativeStudio.evd_is_doppler_enabled(this);
    }

    /**
     * True if the event has at least one sustain point on its timeline. Returns false both on failure and for a
     * timeline with no sustain point. StudioSystem.lastResult() tells the two apart.
     */
    public inline function hasSustainPoint():Bool {
        return NativeStudio.evd_has_sustain_point(this);
    }

    /**
     * Creates a playable instance of this event. Returns EventInstance.NULL
     * on failure. A handler registered with setCallback is installed on
     * the new instance before it is returned.
     */
    public function createInstance():EventInstance {
        var instance:EventInstance = NativeStudio.evd_create_instance(this);
        if (instance.isNull()) return instance;
        var entry = descriptionCallbacks.get(this);
        if (entry != null) instance.setCallback(entry.handler, entry.mask);
        return instance;
    }

    static var descriptionCallbacks:Map<Int, {handler:EventCallbackData->Void, mask:Null<Int>}> = new Map();

    /**
     * Remembers a handler that createInstance installs on every later
     * instance made from this description, the way
     * Studio::EventDescription::setCallback does. Instances created before
     * this call keep whatever handler they already had. The mask defaults
     * to every type, as on EventInstance.setCallback. Calling again
     * replaces the remembered handler for future instances only.
     */
    public function setCallback(handler:EventCallback, ?mask:Int):Void {
        if (this == 0) return;
        if (handler == null) {
            descriptionCallbacks.remove(this);
            return;
        }
        descriptionCallbacks.set(this, {handler: handler, mask: mask});
    }

    /** Forgets the handler set with setCallback. Existing instances keep theirs. */
    public inline function clearCallback():Void {
        descriptionCallbacks.remove(this);
    }

    /** True if setCallback remembers a handler for this description. */
    public inline function hasCallback():Bool {
        return descriptionCallbacks.exists(this);
    }

    /** Forgets every description-level handler. */
    public static function clearAllCallbacks():Void {
        descriptionCallbacks = new Map();
    }

    /**
     * Number of live instances of this event. Returns 0 both on failure and for an event with no live instance.
     * StudioSystem.lastResult() tells the two apart.
     */
    public inline function getInstanceCount():Int {
        return NativeStudio.evd_get_instance_count(this);
    }

    /** Live instances of this event (up to Scratch.CAPACITY entries). */
    public function getInstanceList():Array<EventInstance> {
        var count = NativeStudio.evd_get_instance_list(this);
        Scratch.warnTruncated("instance", count, getInstanceCount());
        return [for (i in 0...count) (Scratch.readI(i) : EventInstance)];
    }

    /** Stops and releases all instances of this event. */
    public inline function releaseAllInstances():FmodResult {
        return NativeStudio.evd_release_all_instances(this);
    }

    /** Loads non-streaming sample data ahead of time (refcounted by FMOD). */
    public inline function loadSampleData():FmodResult {
        return NativeStudio.evd_load_sample_data(this);
    }

    /** Unloads the non-streaming sample data from loadSampleData. FMOD reference counts it, so it stays loaded until every load has a matching unload. */
    public inline function unloadSampleData():FmodResult {
        return NativeStudio.evd_unload_sample_data(this);
    }

    /**
     * Loading state of the event's non-streaming sample data. Returns FmodLoadingState.UNLOADED both on failure
     * and for sample data that is not loaded. StudioSystem.lastResult() tells the two apart.
     */
    public inline function getSampleLoadingState():FmodLoadingState {
        return NativeStudio.evd_get_sample_loading_state(this);
    }

    /**
     * Number of parameters on this event. Returns 0 both on failure and for an event with no parameter.
     * StudioSystem.lastResult() tells the two apart.
     */
    public inline function getParameterDescriptionCount():Int {
        return NativeStudio.evd_get_parameter_description_count(this);
    }

    /** Parameter description by index, or null on failure. */
    public function getParameterDescriptionByIndex(index:Int):Null<FmodParameterDescription> {
        var name = NativeStudio.evd_get_parameter_description_by_index(this, index);
        return readParameterDescription(name);
    }

    /** Parameter description by name, or null on failure. */
    public function getParameterDescriptionByName(name:String):Null<FmodParameterDescription> {
        var resolved = NativeStudio.evd_get_parameter_description_by_name(this, name);
        return readParameterDescription(resolved);
    }

    /**
     * Label text for a labeled parameter's value index (e.g. discrete enums). Returns "" on failure, with the
     * reason in StudioSystem.lastResult().
     */
    public inline function getParameterLabel(parameterName:String, labelIndex:Int):String {
        return NativeStudio.evd_get_parameter_label(this, parameterName, labelIndex);
    }

    /**
     * Label text for a labeled parameter named by name, the same call as getParameterLabel under FMOD's name.
     * Returns "" on failure, with the reason in StudioSystem.lastResult().
     */
    public inline function getParameterLabelByName(name:String, labelIndex:Int):String {
        return NativeStudio.evd_get_parameter_label(this, name, labelIndex);
    }

    /**
     * Label text for a labeled parameter at a description index, "" when the index or the label is out of
     * range. Any other failure reports "" as well, with the reason in StudioSystem.lastResult().
     */
    public inline function getParameterLabelByIndex(index:Int, labelIndex:Int):String {
        return NativeStudio.evd_get_parameter_label_by_index(this, index, labelIndex);
    }

    /**
     * Parameter description by parameter ID, or null when the event has no
     * parameter with that ID. Resolved by scanning the description list,
     * so it covers the same indexes getParameterDescriptionByIndex does.
     */
    public function getParameterDescriptionByID(id:FmodParameterId):Null<FmodParameterDescription> {
        var handle:EventDescription = this;
        return @:privateAccess StudioSystem.scanDescriptionsByID(
            getParameterDescriptionCount(), i -> handle.getParameterDescriptionByIndex(i), id);
    }

    /**
     * Label text for a labeled parameter identified by ID. Returns "" on failure, with the reason in
     * StudioSystem.lastResult().
     */
    public function getParameterLabelByID(id:FmodParameterId, labelIndex:Int):String {
        var desc = getParameterDescriptionByID(id);
        return desc == null ? "" : getParameterLabel(desc.name, labelIndex);
    }

    /**
     * Number of user properties authored on the event. Returns 0 both on failure and for an event with no user
     * property. StudioSystem.lastResult() tells the two apart.
     */
    public inline function getUserPropertyCount():Int {
        return NativeStudio.evd_get_user_property_count(this);
    }

    /** User property by name, or null when the event has none with it. */
    public function getUserProperty(name:String):Null<FmodUserProperty> {
        var count = getUserPropertyCount();
        for (i in 0...count) {
            var prop = getUserPropertyByIndex(i);
            if (prop != null && prop.name == name) return prop;
        }
        return null;
    }

    /** User property by name, the same lookup as getUserProperty. */
    public inline function getUserPropertyByName(name:String):Null<FmodUserProperty> {
        return getUserProperty(name);
    }

    /** User property by index, or null on failure. */
    public function getUserPropertyByIndex(index:Int):Null<FmodUserProperty> {
        var name = NativeStudio.evd_get_user_property_name(this, index);
        if (name == "" && !StudioSystem.lastResult().isOk()) return null;
        return {
            name: name,
            type: (NativeStudio.evd_get_user_property_type(this, index) : FmodUserPropertyType),
            floatValue: NativeStudio.evd_get_user_property_float(this, index),
            stringValue: NativeStudio.evd_get_user_property_string(this, index),
        };
    }

    static function readParameterDescription(name:String):Null<FmodParameterDescription> {
        return @:privateAccess StudioSystem.readParameterDescription(name);
    }

    /**
     * Attaches a Haxe value to this handle. The value lives on the Haxe
     * side keyed by the handle and is dropped when its bank unloads.
     * A recycled native slot gets a new generation and therefore a new
     * handle int, so a stale entry does not show up on the next handle
     * in that slot.
     */
    public inline function setUserData(value:Dynamic):Void {
        UserData.set(UserDataKind.EventDescription, this, value);
    }

    /** The value attached with setUserData, or null. */
    public inline function getUserData():Dynamic {
        return UserData.get(UserDataKind.EventDescription, this);
    }
}
