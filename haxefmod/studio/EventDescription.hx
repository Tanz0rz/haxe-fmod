package haxefmod.studio;

import haxefmod.studio.Types;
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
    public static inline var NULL:EventDescription = cast 0;

    public inline function isNull():Bool {
        return this == 0;
    }

    public inline function isValid():Bool {
        return this != 0 && NativeStudio.evd_is_valid(this);
    }

    /** The event GUID as a string. */
    public inline function getID():String {
        return NativeStudio.evd_get_id(this);
    }

    /** The full event path, e.g. "event:/Music/MainLevel". */
    public inline function getPath():String {
        return NativeStudio.evd_get_path(this);
    }

    /** Timeline length in milliseconds. */
    public inline function getLength():Int {
        return NativeStudio.evd_get_length(this);
    }

    /** Minimum and maximum attenuation distances, or null on failure. */
    public function getMinMaxDistance():Null<{min:Float, max:Float}> {
        var result:FmodResult = NativeStudio.evd_get_min_max_distance(this);
        if (!result.isOk()) return null;
        return {min: Scratch.readF(0), max: Scratch.readF(1)};
    }

    /** Estimated non-streaming sample data size in bytes. */
    public inline function getSoundSize():Float {
        return NativeStudio.evd_get_sound_size(this);
    }

    public inline function isSnapshot():Bool {
        return NativeStudio.evd_is_snapshot(this);
    }

    public inline function isOneshot():Bool {
        return NativeStudio.evd_is_oneshot(this);
    }

    public inline function isStream():Bool {
        return NativeStudio.evd_is_stream(this);
    }

    public inline function is3D():Bool {
        return NativeStudio.evd_is_3d(this);
    }

    public inline function isDopplerEnabled():Bool {
        return NativeStudio.evd_is_doppler_enabled(this);
    }

    public inline function hasSustainPoint():Bool {
        return NativeStudio.evd_has_sustain_point(this);
    }

    /** Creates a playable instance of this event. Returns EventInstance.NULL on failure. */
    public inline function createInstance():EventInstance {
        return NativeStudio.evd_create_instance(this);
    }

    /** Number of live instances of this event. */
    public inline function getInstanceCount():Int {
        return NativeStudio.evd_get_instance_count(this);
    }

    /** Live instances of this event (up to Scratch.CAPACITY entries). */
    public function getInstanceList():Array<EventInstance> {
        var count = NativeStudio.evd_get_instance_list(this);
        var total = getInstanceCount();
        if (total > count) {
            trace('Warn: FMOD - instance list truncated ($count of $total); raise FAXE_LIST_MAX/Scratch.CAPACITY');
        }
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

    public inline function unloadSampleData():FmodResult {
        return NativeStudio.evd_unload_sample_data(this);
    }

    public inline function getSampleLoadingState():FmodLoadingState {
        return NativeStudio.evd_get_sample_loading_state(this);
    }

    /** Number of parameters on this event. */
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

    /** Label text for a labeled parameter's value index (e.g. discrete enums). */
    public inline function getParameterLabel(parameterName:String, labelIndex:Int):String {
        return NativeStudio.evd_get_parameter_label(this, parameterName, labelIndex);
    }

    /** Number of user properties authored on the event. */
    public inline function getUserPropertyCount():Int {
        return NativeStudio.evd_get_user_property_count(this);
    }

    /** User property by index, or null on failure. */
    public function getUserProperty(index:Int):Null<FmodUserProperty> {
        var name = NativeStudio.evd_get_user_property_name(this, index);
        if (name == "" && !StudioSystem.lastResult().isOk()) return null;
        return {
            name: name,
            type: (NativeStudio.evd_get_user_property_type(this, index) : FmodUserPropertyType),
            floatValue: NativeStudio.evd_get_user_property_float(this, index),
            stringValue: NativeStudio.evd_get_user_property_string(this, index),
        };
    }

    /** Shared decode for the parameter-description scratch layout. */
    static function readParameterDescription(name:String):Null<FmodParameterDescription> {
        if (!StudioSystem.lastResult().isOk()) return null;
        return {
            name: name,
            id: {data1: Scratch.readI(2), data2: Scratch.readI(3)},
            minimum: Scratch.readF(0),
            maximum: Scratch.readF(1),
            defaultValue: Scratch.readF(2),
            type: (Scratch.readI(0) : FmodParameterType),
            flags: Scratch.readI(1),
        };
    }
}
