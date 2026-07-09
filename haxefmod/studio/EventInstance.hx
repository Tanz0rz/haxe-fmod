package haxefmod.studio;

import haxefmod.studio.Callbacks;
import haxefmod.studio.Types;
import haxefmod.studio.native.NativeStudio;
import haxefmod.studio.native.Scratch;

/**
 * A handle to a playable FMOD Studio event instance.
 *
 * Obtain via EventDescription.createInstance (or the FmodRuntime helpers).
 * Handles are plain ints under the hood; a stale or invalid handle makes
 * every call a safe no-op (getters return defaults, setters return
 * FMOD_ERR_INVALID_HANDLE).
 */
abstract EventInstance(Int) from Int to Int {
    public static inline var NULL:EventInstance = cast 0;

    public inline function isNull():Bool {
        return this == 0;
    }

    public inline function isValid():Bool {
        return this != 0 && NativeStudio.evi_is_valid(this);
    }

    /** The description this instance was created from. */
    public inline function getDescription():EventDescription {
        return NativeStudio.evi_get_description(this);
    }

    public inline function start():FmodResult {
        return NativeStudio.evi_start(this);
    }

    public inline function stop(stopMode:FmodStopMode = ALLOWFADEOUT):FmodResult {
        return NativeStudio.evi_stop(this, stopMode);
    }

    /** Advances past the current sustain point. */
    public inline function keyOff():FmodResult {
        return NativeStudio.evi_key_off(this);
    }

    /**
     * Releases the instance. FMOD destroys it once it stops; the handle
     * becomes invalid immediately and any registered callback is removed
     * (the html5 backend cannot deliver events after release, so cleanup
     * happens here on every target for consistent behavior).
     */
    public inline function release():FmodResult {
        haxefmod.runtime.CallbackDispatcher.remove(this);
        return NativeStudio.evi_release(this);
    }

    public inline function getPlaybackState():FmodPlaybackState {
        return NativeStudio.evi_get_playback_state(this);
    }

    public inline function getPaused():Bool {
        return NativeStudio.evi_get_paused(this);
    }

    public inline function setPaused(paused:Bool):FmodResult {
        return NativeStudio.evi_set_paused(this, paused);
    }

    public inline function getVolume():Float {
        return NativeStudio.evi_get_volume(this);
    }

    /** The final combined volume (set volume x event/snapshot automation). */
    public inline function getFinalVolume():Float {
        return NativeStudio.evi_get_volume_final(this);
    }

    public inline function setVolume(volume:Float):FmodResult {
        return NativeStudio.evi_set_volume(this, volume);
    }

    public inline function getPitch():Float {
        return NativeStudio.evi_get_pitch(this);
    }

    public inline function getFinalPitch():Float {
        return NativeStudio.evi_get_pitch_final(this);
    }

    public inline function setPitch(pitch:Float):FmodResult {
        return NativeStudio.evi_set_pitch(this, pitch);
    }

    /** Timeline position in milliseconds. */
    public inline function getTimelinePosition():Int {
        return NativeStudio.evi_get_timeline_position(this);
    }

    public inline function setTimelinePosition(positionMs:Int):FmodResult {
        return NativeStudio.evi_set_timeline_position(this, positionMs);
    }

    /** True if the instance has been virtualized (inaudible, not mixed). */
    public inline function isVirtual():Bool {
        return NativeStudio.evi_is_virtual(this);
    }

    /** Minimum and maximum attenuation distances, or null on failure. */
    public function getMinMaxDistance():Null<{min:Float, max:Float}> {
        var result:FmodResult = NativeStudio.evi_get_min_max_distance(this);
        if (!result.isOk()) return null;
        return {min: Scratch.readF(0), max: Scratch.readF(1)};
    }

    /** The instance's 3D attributes, or null on failure. */
    public function get3DAttributes():Null<Fmod3DAttributes> {
        var result:FmodResult = NativeStudio.evi_get_3d_attributes(this);
        if (!result.isOk()) return null;
        return {
            position: {x: Scratch.readF(0), y: Scratch.readF(1), z: Scratch.readF(2)},
            velocity: {x: Scratch.readF(3), y: Scratch.readF(4), z: Scratch.readF(5)},
            forward: {x: Scratch.readF(6), y: Scratch.readF(7), z: Scratch.readF(8)},
            up: {x: Scratch.readF(9), y: Scratch.readF(10), z: Scratch.readF(11)},
        };
    }

    public inline function set3DAttributes(attributes:Fmod3DAttributes):FmodResult {
        return NativeStudio.evi_set_3d_attributes(this,
            attributes.position.x, attributes.position.y, attributes.position.z,
            attributes.velocity.x, attributes.velocity.y, attributes.velocity.z,
            attributes.forward.x, attributes.forward.y, attributes.forward.z,
            attributes.up.x, attributes.up.y, attributes.up.z);
    }

    /** Convenience for 2D games: position only, unit forward/up. */
    public inline function setPosition2D(x:Float, y:Float, ?velocityX:Float = 0, ?velocityY:Float = 0):FmodResult {
        return NativeStudio.evi_set_3d_attributes(this, x, y, 0, velocityX, velocityY, 0, 0, 0, 1, 0, 1, 0);
    }

    /** Bitmask of listeners this instance is audible to. */
    public inline function getListenerMask():Int {
        return NativeStudio.evi_get_listener_mask(this);
    }

    public inline function setListenerMask(mask:Int):FmodResult {
        return NativeStudio.evi_set_listener_mask(this, mask);
    }

    /** An overridable instance property (see FmodEventProperty). */
    public inline function getProperty(property:FmodEventProperty):Float {
        return NativeStudio.evi_get_property(this, property);
    }

    public inline function setProperty(property:FmodEventProperty, value:Float):FmodResult {
        return NativeStudio.evi_set_property(this, property, value);
    }

    /** Core reverb send level for reverb instance 0-3. */
    public inline function getReverbLevel(index:Int):Float {
        return NativeStudio.evi_get_reverb_level(this, index);
    }

    public inline function setReverbLevel(index:Int, level:Float):FmodResult {
        return NativeStudio.evi_set_reverb_level(this, index, level);
    }

    public inline function getParameter(name:String):Float {
        return NativeStudio.evi_get_param_by_name(this, name);
    }

    /** The final parameter value after automation/seek speed. */
    public inline function getParameterFinal(name:String):Float {
        return NativeStudio.evi_get_param_by_name_final(this, name);
    }

    public inline function setParameter(name:String, value:Float, ignoreSeekSpeed:Bool = false):FmodResult {
        return NativeStudio.evi_set_param_by_name(this, name, value, ignoreSeekSpeed);
    }

    /** Sets a labeled parameter by label text (e.g. discrete enum names). */
    public inline function setParameterWithLabel(name:String, label:String, ignoreSeekSpeed:Bool = false):FmodResult {
        return NativeStudio.evi_set_param_by_name_with_label(this, name, label, ignoreSeekSpeed);
    }

    public inline function getParameterByID(id:FmodParameterId):Float {
        return NativeStudio.evi_get_param_by_id(this, id.data1, id.data2);
    }

    public inline function getParameterByIDFinal(id:FmodParameterId):Float {
        return NativeStudio.evi_get_param_by_id_final(this, id.data1, id.data2);
    }

    public inline function setParameterByID(id:FmodParameterId, value:Float, ignoreSeekSpeed:Bool = false):FmodResult {
        return NativeStudio.evi_set_param_by_id(this, id.data1, id.data2, value, ignoreSeekSpeed);
    }

    public inline function setParameterByIDWithLabel(id:FmodParameterId, label:String, ignoreSeekSpeed:Bool = false):FmodResult {
        return NativeStudio.evi_set_param_by_id_with_label(this, id.data1, id.data2, label, ignoreSeekSpeed);
    }

    /**
     * Registers a typed payload callback for this instance (replaces any
     * existing handler; removed automatically when the instance is
     * destroyed). Delivered from FmodManager.Update / FmodRuntime.update.
     */
    public inline function setCallback(handler:EventCallbackData->Void, ?mask:Int):Void {
        haxefmod.runtime.CallbackDispatcher.setCallback(this, handler, mask);
    }

    /**
     * Assigns the audio-table key (or file path fallback) this instance's
     * programmer instrument should play. The native shim resolves it on the
     * FMOD thread when the instrument triggers. Assign BEFORE start().
     */
    public inline function assignProgrammerSound(key:String):FmodResult {
        return NativeStudio.ps_assign(this, key);
    }

    /** Removes the programmer-sound assignment. */
    public inline function clearProgrammerSound():FmodResult {
        return NativeStudio.ps_clear(this);
    }

    /** CPU usage of this instance, or null on failure (unsupported on html5). */
    public function getCpuUsage():Null<FmodCpuUsage> {
        var result:FmodResult = NativeStudio.evi_get_cpu_usage(this);
        if (!result.isOk()) return null;
        return {exclusive: Scratch.readI(0), inclusive: Scratch.readI(1)};
    }

    /** Memory usage of this instance, or null on failure (unsupported on html5). */
    public function getMemoryUsage():Null<FmodMemoryUsage> {
        var result:FmodResult = NativeStudio.evi_get_memory_usage(this);
        if (!result.isOk()) return null;
        return {exclusive: Scratch.readI(0), inclusive: Scratch.readI(1), sampledata: Scratch.readI(2)};
    }
}
