package haxefmod.studio;

import haxefmod.studio.Callbacks;
import haxefmod.studio.Types;
import haxefmod.studio.UserData;
import haxefmod.studio.native.NativeStudio;
import haxefmod.studio.native.Scratch;

/**
 * A handle to a playable FMOD Studio event instance.
 *
 * Obtain via EventDescription.createInstance (or the FmodRuntime helpers).
 * Handles are plain ints under the hood. A stale or invalid handle makes
 * every call a safe no-op (getters return defaults, setters return
 * FMOD_ERR_INVALID_HANDLE).
 */
abstract EventInstance(Int) from Int to Int {
    // The group handle each instance handed out, so a release drops its
    // Haxe handler and user data with the instance, and mints nothing
    static var walkedGroups:Map<Int, Int> = new Map();

    /** The null handle. Every call on it is a safe no-op. */
    public static inline var NULL:EventInstance = cast 0;

    /** True if this is the invalid handle (creation failed). */
    public inline function isNull():Bool {
        return this == 0;
    }

    /** True if the handle resolves to a live FMOD event instance. */
    public inline function isValid():Bool {
        return this != 0 && NativeStudio.evi_is_valid(this);
    }

    /**
     * The description this instance was created from. Returns EventDescription.NULL on failure, with the reason
     * in StudioSystem.lastResult().
     */
    public inline function getDescription():EventDescription {
        return NativeStudio.evi_get_description(this);
    }

    /** Starts playback. On an instance that is already playing it restarts the event. */
    public inline function start():FmodResult {
        return NativeStudio.evi_start(this);
    }

    /** Stops playback. ALLOWFADEOUT lets AHDSR releases and effect tails finish, IMMEDIATE stops at once. */
    public inline function stop(stopMode:FmodStopMode = ALLOWFADEOUT):FmodResult {
        return NativeStudio.evi_stop(this, stopMode);
    }

    /** Advances past the current sustain point. */
    public inline function keyOff():FmodResult {
        return NativeStudio.evi_key_off(this);
    }

    /**
     * The core channel group carrying this instance's audio, for attaching DSP effects to a single event. The
     * instance must be started. The instance owns the group, so its release is refused. Returns
     * ChannelGroup.NULL on failure, with the reason in StudioSystem.lastResult().
     */
    public function getChannelGroup():haxefmod.core.ChannelGroup {
        var group:haxefmod.core.ChannelGroup = NativeStudio.evi_get_channel_group(this);
        if (!group.isNull()) walkedGroups.set(this, group);
        return group;
    }

    /**
     * Releases the instance. FMOD destroys it once it stops. Once FMOD
     * accepted the call, the handle is dead and the registered callback
     * and user data are dropped. A refused release keeps both.
     * The HTML5 backend cannot deliver events after release, so the
     * cleanup happens here on every target for consistent behavior.
     */
    public function release():FmodResult {
        var result:FmodResult = NativeStudio.evi_release(this);
        if (UserData.releaseTookEffect(result)) {
            CallbackDispatcher.remove(this);
            UserData.clear(UserDataKind.EventInstance, this);
            // The instance's group dies with it, so its handler and user
            // data go too
            var group = walkedGroups.get(this);
            walkedGroups.remove(this);
            if (group != null) {
                haxefmod.core.ChannelCallbacks.forgetGroup(group);
                UserData.clear(UserDataKind.ChannelGroup, group);
            }
        }
        return result;
    }

    /**
     * The playback state (see FmodPlaybackState). Returns STOPPED both on failure and for a stopped instance.
     * StudioSystem.lastResult() tells the two apart.
     */
    public inline function getPlaybackState():FmodPlaybackState {
        return NativeStudio.evi_get_playback_state(this);
    }

    /**
     * True if the instance is paused. Returns false both on failure and for an instance that runs.
     * StudioSystem.lastResult() tells the two apart.
     */
    public inline function getPaused():Bool {
        return NativeStudio.evi_get_paused(this);
    }

    /** Pauses or resumes the instance. */
    public inline function setPaused(paused:Bool):FmodResult {
        return NativeStudio.evi_set_paused(this, paused);
    }

    /**
     * The volume as set by the API (linear: 0.0 = silent, 1.0 = full). Returns 0.0 both on failure and for a
     * silent instance. StudioSystem.lastResult() tells the two apart.
     */
    public inline function getVolume():Float {
        return NativeStudio.evi_get_volume(this);
    }

    /**
     * The final combined volume (set volume x event/snapshot automation). Returns 0.0 both on failure and for a
     * silent instance. StudioSystem.lastResult() tells the two apart.
     */
    public inline function getFinalVolume():Float {
        return NativeStudio.evi_get_volume_final(this);
    }

    /** Sets the volume as a linear level (0.0 = silent, 1.0 = full). */
    public inline function setVolume(volume:Float):FmodResult {
        return NativeStudio.evi_set_volume(this, volume);
    }

    /**
     * The pitch multiplier as set by the API (1.0 = unchanged). Returns 0.0 both on failure and for a pitch of
     * zero. StudioSystem.lastResult() tells the two apart.
     */
    public inline function getPitch():Float {
        return NativeStudio.evi_get_pitch(this);
    }

    /**
     * The final combined pitch multiplier (set pitch x event/snapshot automation). Returns 0.0 both on failure
     * and for a pitch of zero. StudioSystem.lastResult() tells the two apart.
     */
    public inline function getFinalPitch():Float {
        return NativeStudio.evi_get_pitch_final(this);
    }

    /** Sets the pitch multiplier applied to the event's pitch (1.0 = unchanged). */
    public inline function setPitch(pitch:Float):FmodResult {
        return NativeStudio.evi_set_pitch(this, pitch);
    }

    /**
     * Timeline position in milliseconds. Returns 0 both on failure and for a cursor at the start.
     * StudioSystem.lastResult() tells the two apart.
     */
    public inline function getTimelinePosition():Int {
        return NativeStudio.evi_get_timeline_position(this);
    }

    /** Moves the timeline cursor to a position in milliseconds. */
    public inline function setTimelinePosition(positionMs:Int):FmodResult {
        return NativeStudio.evi_set_timeline_position(this, positionMs);
    }

    /**
     * True if the instance has been virtualized. A virtual instance is inaudible and stays out of the mix.
     * Returns false both on failure and for an audible instance. StudioSystem.lastResult() tells the two apart.
     */
    public inline function isVirtual():Bool {
        return NativeStudio.evi_is_virtual(this);
    }

    /** Minimum and maximum attenuation distances, or null on failure. */
    public function getMinMaxDistance():Null<FmodEventMinMaxDistance> {
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

    /** Sets the instance's 3D position, velocity, forward, and up vectors. */
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

    /**
     * Bitmask of listeners this instance is audible to. Returns 0 both on failure and for an instance no
     * listener hears. StudioSystem.lastResult() tells the two apart.
     */
    public inline function getListenerMask():Int {
        return NativeStudio.evi_get_listener_mask(this);
    }

    /** Sets the bitmask of listeners this instance is audible to. */
    public inline function setListenerMask(mask:Int):FmodResult {
        return NativeStudio.evi_set_listener_mask(this, mask);
    }

    /**
     * An overridable instance property (see FmodEventProperty). Returns 0.0 both on failure and for a property
     * set to zero. StudioSystem.lastResult() tells the two apart.
     */
    public inline function getProperty(property:FmodEventProperty):Float {
        return NativeStudio.evi_get_property(this, property);
    }

    /** Overrides an instance property (see FmodEventProperty). */
    public inline function setProperty(property:FmodEventProperty, value:Float):FmodResult {
        return NativeStudio.evi_set_property(this, property, value);
    }

    /**
     * Core reverb send level for reverb instance 0-3. Returns 0.0 both on failure and for a dry send.
     * StudioSystem.lastResult() tells the two apart.
     */
    public inline function getReverbLevel(index:Int):Float {
        return NativeStudio.evi_get_reverb_level(this, index);
    }

    /** Sets the core reverb send level for reverb instance 0-3. */
    public inline function setReverbLevel(index:Int, level:Float):FmodResult {
        return NativeStudio.evi_set_reverb_level(this, index, level);
    }

    /**
     * A parameter's value as set by the API, by name. Returns 0.0 both on failure and for a parameter set to
     * zero. StudioSystem.lastResult() tells the two apart.
     */
    public inline function getParameter(name:String):Float {
        return NativeStudio.evi_get_param_by_name(this, bareParameterName(name));
    }

    /**
     * The name FMOD's parameter calls take. The generated FmodParameters
     * constants hold `parameter:/Name` paths, so the prefix is stripped.
     */
    public static inline function bareParameterName(name:String):String {
        return StringTools.startsWith(name, "parameter:/") ? name.substr("parameter:/".length) : name;
    }

    /**
     * The final parameter value after automation/seek speed. Returns 0.0 both on failure and for a parameter
     * set to zero. StudioSystem.lastResult() tells the two apart.
     */
    public inline function getParameterFinal(name:String):Float {
        return NativeStudio.evi_get_param_by_name_final(this, bareParameterName(name));
    }

    /** Sets a parameter by name. ignoreSeekSpeed skips the parameter's seek speed and applies the value at once. */
    public inline function setParameter(name:String, value:Float, ignoreSeekSpeed:Bool = false):FmodResult {
        return NativeStudio.evi_set_param_by_name(this, bareParameterName(name), value, ignoreSeekSpeed);
    }

    /** Sets a labeled parameter by label text (e.g. discrete enum names). */
    public inline function setParameterWithLabel(name:String, label:String, ignoreSeekSpeed:Bool = false):FmodResult {
        return NativeStudio.evi_set_param_by_name_with_label(this, bareParameterName(name), label, ignoreSeekSpeed);
    }

    /**
     * A parameter's value as set by the API, by ID. Returns 0.0 both on failure and for a parameter set to
     * zero. StudioSystem.lastResult() tells the two apart.
     */
    public inline function getParameterByID(id:FmodParameterId):Float {
        return NativeStudio.evi_get_param_by_id(this, id.data1, id.data2);
    }

    /**
     * The final value of a parameter after automation and seek speed, by ID. Returns 0.0 both on failure and
     * for a parameter set to zero. StudioSystem.lastResult() tells the two apart.
     */
    public inline function getParameterByIDFinal(id:FmodParameterId):Float {
        return NativeStudio.evi_get_param_by_id_final(this, id.data1, id.data2);
    }

    /** Sets a parameter by ID. ignoreSeekSpeed skips the parameter's seek speed and applies the value at once. */
    public inline function setParameterByID(id:FmodParameterId, value:Float, ignoreSeekSpeed:Bool = false):FmodResult {
        return NativeStudio.evi_set_param_by_id(this, id.data1, id.data2, value, ignoreSeekSpeed);
    }

    /** Sets a labeled parameter by ID and label text. ignoreSeekSpeed skips the seek speed and applies the value at once. */
    public inline function setParameterByIDWithLabel(id:FmodParameterId, label:String, ignoreSeekSpeed:Bool = false):FmodResult {
        return NativeStudio.evi_set_param_by_id_with_label(this, id.data1, id.data2, label, ignoreSeekSpeed);
    }

    /**
     * The same parameter read as getParameter, under FMOD's name. Returns 0.0 both on failure and for a
     * parameter set to zero. StudioSystem.lastResult() tells the two apart.
     */
    public inline function getParameterByName(name:String):Float {
        return NativeStudio.evi_get_param_by_name(this, name);
    }

    /**
     * The final value of a parameter after automation and seek speed, by name. Returns 0.0 both on failure and
     * for a parameter set to zero. StudioSystem.lastResult() tells the two apart.
     */
    public inline function getParameterByNameFinal(name:String):Float {
        return NativeStudio.evi_get_param_by_name_final(this, name);
    }

    /** The same parameter write as setParameter, under FMOD's name. */
    public inline function setParameterByName(name:String, value:Float, ignoreSeekSpeed:Bool = false):FmodResult {
        return NativeStudio.evi_set_param_by_name(this, name, value, ignoreSeekSpeed);
    }

    /** The same labeled write as setParameterWithLabel, under FMOD's name. */
    public inline function setParameterByNameWithLabel(name:String, label:String, ignoreSeekSpeed:Bool = false):FmodResult {
        return NativeStudio.evi_set_param_by_name_with_label(this, name, label, ignoreSeekSpeed);
    }

    /**
     * Sets several parameters on this instance in one call. ids and values
     * pair up by index, the shorter list sets the count. At most
     * Scratch.CAPACITY / 2 pairs, more returns FMOD_ERR_INVALID_PARAM.
     */
    public function setParametersByIDs(ids:Array<FmodParameterId>, values:Array<Float>, ignoreSeekSpeed:Bool = false):FmodResult {
        var count = @:privateAccess StudioSystem.packParameterBatch(ids, values);
        if (count < 0) return FmodResult.FMOD_ERR_INVALID_PARAM;
        return NativeStudio.evi_set_parameters_by_ids(this, count, ignoreSeekSpeed);
    }

    /**
     * Registers a typed payload callback for this instance. It replaces
     * any existing handler, and it is removed when the instance is
     * destroyed. Delivered from FmodManager.Update / FmodRuntime.update.
     */
    public inline function setCallback(handler:EventCallback, ?mask:Int):Void {
        CallbackDispatcher.setCallback(this, handler, mask);
    }

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /**
     * Assigns the audio-table key (or file path fallback) this instance's
     * programmer instrument plays (unsupported in HTML5). The native
     * shim resolves it on the FMOD thread when the instrument triggers.
     * Assign BEFORE start().
     *
     * Returns FMOD_ERR_UNSUPPORTED on HTML5. FMOD's JS runtime cannot
     * complete the programmer-sound flow. Assigning the created sound
     * stops the event and ends its callback delivery. The page
     * tests/js/fmod_ps_glue_repro.html reproduces this with FMOD's own
     * example pattern.
     */
    public macro function assignProgrammerSound(self:haxe.macro.Expr, key:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("EventInstance.assignProgrammerSound", "programmer sounds fail inside FMOD's JavaScript runtime");
    }
    #else
    /**
     * Assigns the audio-table key (or file path fallback) this instance's
     * programmer instrument plays (unsupported in HTML5). The native
     * shim resolves it on the FMOD thread when the instrument triggers.
     * Assign BEFORE start().
     *
     * Returns FMOD_ERR_UNSUPPORTED on HTML5. FMOD's JS runtime cannot
     * complete the programmer-sound flow. Assigning the created sound
     * stops the event and ends its callback delivery. The page
     * tests/js/fmod_ps_glue_repro.html reproduces this with FMOD's own
     * example pattern.
     */
    public inline function assignProgrammerSound(key:String):FmodResult {
        if (key == null) return FmodResult.FMOD_ERR_INVALID_PARAM;
        return NativeStudio.ps_assign(this, key);
    }
    #end

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /**
     * Hands a sound the game owns to this instance's programmer
     * instrument (unsupported in HTML5). The subsoundIndex argument picks
     * a subsound of an FSB or other container, -1 plays the sound itself.
     * The instrument never releases the sound. The game releases it once
     * the instrument is finished (ProgrammerSoundDestroyed in setCallback,
     * or after the event stops). A sound still loading (NONBLOCKING) is
     * fine, FMOD waits for it. Assign BEFORE start(). Wins over a key or
     * name assignment.
     */
    public macro function assignProgrammerSoundFrom(self:haxe.macro.Expr, sound:haxe.macro.Expr, ?subsoundIndex:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("EventInstance.assignProgrammerSoundFrom", "programmer sounds fail inside FMOD's JavaScript runtime");
    }
    #else
    /**
     * Hands a sound the game owns to this instance's programmer
     * instrument (unsupported in HTML5). The subsoundIndex argument picks
     * a subsound of an FSB or other container, -1 plays the sound itself.
     * The instrument never releases the sound. The game releases it once
     * the instrument is finished (ProgrammerSoundDestroyed in setCallback,
     * or after the event stops). A sound still loading (NONBLOCKING) is
     * fine, FMOD waits for it. Assign BEFORE start(). Wins over a key or
     * name assignment.
     */
    public inline function assignProgrammerSoundFrom(sound:haxefmod.core.Sound, subsoundIndex:Int = -1):FmodResult {
        if (sound.isNull()) return FmodResult.FMOD_ERR_INVALID_PARAM;
        return NativeStudio.ps_assign_sound(this, sound, subsoundIndex);
    }
    #end

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /**
     * Maps one programmer instrument name to the audio table key or file
     * path it plays (unsupported in HTML5). An event with several
     * programmer instruments gets one entry per instrument name, up to
     * eight per instance. A name with no entry falls back to the single
     * assignProgrammerSound key. Names must be under 64 UTF-8 bytes and
     * keys under 512. Assign BEFORE start().
     */
    public macro function assignProgrammerSoundForName(self:haxe.macro.Expr, name:haxe.macro.Expr, key:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("EventInstance.assignProgrammerSoundForName", "programmer sounds fail inside FMOD's JavaScript runtime");
    }
    #else
    /**
     * Maps one programmer instrument name to the audio table key or file
     * path it plays (unsupported in HTML5). An event with several
     * programmer instruments gets one entry per instrument name, up to
     * eight per instance. A name with no entry falls back to the single
     * assignProgrammerSound key. Names must be under 64 UTF-8 bytes and
     * keys under 512. Assign BEFORE start().
     */
    public inline function assignProgrammerSoundForName(name:String, key:String):FmodResult {
        if (name == null || key == null) return FmodResult.FMOD_ERR_INVALID_PARAM;
        return NativeStudio.ps_assign_named(this, name, key);
    }
    #end

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /**
     * assignProgrammerSoundForName for every entry of a name to key map
     * (unsupported in HTML5). Stops at the first failure and returns it.
     */
    public macro function assignProgrammerSounds(self:haxe.macro.Expr, names:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("EventInstance.assignProgrammerSounds", "programmer sounds fail inside FMOD's JavaScript runtime");
    }
    #else
    /**
     * assignProgrammerSoundForName for every entry of a name to key map
     * (unsupported in HTML5). Stops at the first failure and returns it.
     */
    public function assignProgrammerSounds(names:Map<String, String>):FmodResult {
        if (names == null) return FmodResult.FMOD_ERR_INVALID_PARAM;
        for (name => key in names) {
            var result = assignProgrammerSoundForName(name, key);
            if (!result.isOk()) return result;
        }
        return FmodResult.FMOD_OK;
    }
    #end

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /** Removes every programmer-sound assignment, key, game sound, and names (unsupported in HTML5, where nothing can be assigned). */
    public macro function clearProgrammerSound(self:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("EventInstance.clearProgrammerSound", "programmer sounds fail inside FMOD's JavaScript runtime, so there is no assignment to clear");
    }
    #else
    /** Removes every programmer-sound assignment, key, game sound, and names (unsupported in HTML5, where nothing can be assigned). */
    public inline function clearProgrammerSound():FmodResult {
        return NativeStudio.ps_clear(this);
    }
    #end

#if (macro || (js && !haxefmod_html5_allow_unsupported))
    /** CPU usage of this instance, or null on failure. Needs the profiling setting on at init (unsupported in HTML5, null there). */
    public macro function getCpuUsage(self:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("EventInstance.getCpuUsage", "FMOD's JavaScript API does not expose per-object CPU usage");
    }
    #else
    /** CPU usage of this instance, or null on failure. Needs the profiling setting on at init (unsupported in HTML5, null there). */
    public function getCpuUsage():Null<FmodCpuUsage> {
        var result:FmodResult = NativeStudio.evi_get_cpu_usage(this);
        if (!result.isOk()) return null;
        return {exclusive: Scratch.readI(0), inclusive: Scratch.readI(1)};
    }
    #end

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /** Memory usage of this instance, or null on failure (unsupported in HTML5, null there). */
    public macro function getMemoryUsage(self:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("EventInstance.getMemoryUsage", "FMOD's JavaScript API does not expose memory usage");
    }
    #else
    /** Memory usage of this instance, or null on failure (unsupported in HTML5, null there). */
    public function getMemoryUsage():Null<FmodMemoryUsage> {
        var result:FmodResult = NativeStudio.evi_get_memory_usage(this);
        if (!result.isOk()) return null;
        return {exclusive: Scratch.readI(0), inclusive: Scratch.readI(1), sampledata: Scratch.readI(2)};
    }
    #end

    /**
     * Attaches a Haxe value to this handle. The value lives on the Haxe
     * side keyed by the handle and is dropped when the handle is released.
     * A recycled native slot gets a new generation and therefore a new
     * handle int. Thus a stale entry does not show up on the next handle
     * in that slot.
     */
    public inline function setUserData(value:Dynamic):Void {
        UserData.set(UserDataKind.EventInstance, this, value);
    }

    /** The value attached with setUserData, or null. */
    public inline function getUserData():Dynamic {
        return UserData.get(UserDataKind.EventInstance, this);
    }
}
