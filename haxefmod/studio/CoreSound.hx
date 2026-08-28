package haxefmod.studio;

import haxefmod.studio.Types.FmodVector;
import haxefmod.studio.UserData;
import haxefmod.studio.native.NativeStudio;
import haxefmod.studio.native.Scratch;

/**
 * A handle to an FMOD Core sound - the micro subset of the Core API shipped
 * for programmer sounds. Create from an audio file (native: a path on disk;
 * html5: a file preloaded into the virtual filesystem).
 *
 * The full Core API is not bound. Games use this to inspect and manage
 * the loose audio files they feed to programmer sounds.
 */
abstract CoreSound(Int) from Int to Int {
    public static inline var NULL:CoreSound = cast 0;

    /**
     * Loads a sound file. Returns CoreSound.NULL on failure (see
     * StudioSystem.lastResult). openOnly keeps the file open without
     * decoding it up front (FMOD_OPENONLY), which readData needs. A sound
     * opened that way cannot be played.
     */
    public static inline function create(path:String, loop:Bool = false, openOnly:Bool = false):CoreSound {
        return NativeStudio.core_create_sound(path, loop ? 1 : 0, openOnly);
    }

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /**
     * An empty PCM16 sound of the given length for StudioSystem.recordStart
     * to fill (unsupported in HTML5). Returns CoreSound.NULL there and on
     * bad arguments. Release it like any other sound.
     */
    public static macro function createRecordBuffer(sampleRate:haxe.macro.Expr, channels:haxe.macro.Expr, seconds:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("CoreSound.createRecordBuffer", "the web build has no microphone recording");
    }
    #else
    /**
     * An empty PCM16 sound of the given length for StudioSystem.recordStart
     * to fill (unsupported in HTML5). Returns CoreSound.NULL there and on
     * bad arguments. Release it like any other sound.
     */
    public static inline function createRecordBuffer(sampleRate:Int, channels:Int, seconds:Int):CoreSound {
        return NativeStudio.core_create_record_sound(sampleRate, channels, seconds);
    }
    #end

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /**
     * Reads decoded PCM from a sound created with openOnly into buffer
     * (unsupported in HTML5). Returns the bytes read, 0 at the end of the
     * file (StudioSystem.lastResult reports FMOD_ERR_FILE_EOF), or a
     * negated FMOD error code. HTML5 returns -68. length defaults to the
     * whole buffer and is clamped to it.
     */
    public macro function readData(self:haxe.macro.Expr, buffer:haxe.macro.Expr, ?length:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("CoreSound.readData", "FMOD's web build cannot read sample data");
    }
    #else
    /**
     * Reads decoded PCM from a sound created with openOnly into buffer
     * (unsupported in HTML5). Returns the bytes read, 0 at the end of the
     * file (StudioSystem.lastResult reports FMOD_ERR_FILE_EOF), or a
     * negated FMOD error code. HTML5 returns -68. length defaults to the
     * whole buffer and is clamped to it.
     */
    public function readData(buffer:haxe.io.Bytes, length:Int = -1):Int {
        if (buffer == null) return -(FmodResult.FMOD_ERR_INVALID_PARAM : Int);
        // The HashLink shim cannot see the buffer's real size, so an
        // oversized count is clamped here before it can read past the heap
        var count = length == -1 || length > buffer.length ? buffer.length : length;
        return NativeStudio.core_sound_read_data(this, buffer, count);
    }
    #end

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /** Moves the readData cursor to a PCM sample offset (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED). */
    public macro function seekData(self:haxe.macro.Expr, pcm:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("CoreSound.seekData", "FMOD's web build cannot seek sample data");
    }
    #else
    /** Moves the readData cursor to a PCM sample offset (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED). */
    public inline function seekData(pcm:Int):FmodResult {
        return NativeStudio.core_sound_seek_data(this, pcm);
    }
    #end

    /**
     * A sound from raw 16-bit PCM in memory (interleaved when stereo).
     * The bytes are copied, so the buffer is free after this returns.
     * Works on every supported platform.
     */
    public static function fromPcm(data:haxe.io.Bytes, sampleRate:Int, channels:Int, length:Int = -1):CoreSound {
        if (data == null) return NULL;
        // Exactly -1 means the whole buffer, and an oversized count clamps
        // to the real size: the backends copy exactly the count they are
        // given, and the HashLink one cannot see the buffer's true size,
        // so a lied length would read past the heap allocation. Any other
        // negative count surfaces as FMOD_ERR_INVALID_PARAM (matching
        // PcmStream.write) so a miscomputed count is heard about.
        var count = length == -1 || length > data.length ? data.length : length;
        return NativeStudio.core_create_sound_pcm(data, count, sampleRate, channels);
    }

    /** Starts playback. Returns Channel.NULL on failure. */
    public inline function play(startPaused:Bool = false):haxefmod.core.Channel {
        return NativeStudio.core_play_sound(this, startPaused);
    }

    /** Default playback rate (samples per second) and priority (0 = highest, 256 = lowest). */
    public inline function setDefaults(frequency:Float, priority:Int):FmodResult {
        return NativeStudio.sound_set_defaults(this, frequency, priority);
    }

    public function getDefaults():Null<{frequency:Float, priority:Int}> {
        var result:FmodResult = NativeStudio.sound_get_defaults(this);
        if (!result.isOk()) return null;
        return {frequency: haxefmod.studio.native.Scratch.readF(0),
            priority: Std.int(haxefmod.studio.native.Scratch.readF(1))};
    }

    /** Loop region in milliseconds (needs a looping mode set). */
    public inline function setLoopPoints(startMs:Int, endMs:Int):FmodResult {
        return NativeStudio.sound_set_loop_points(this, startMs, endMs);
    }

    public function getLoopPoints():Null<{startMs:Int, endMs:Int}> {
        var result:FmodResult = NativeStudio.sound_get_loop_points(this);
        if (!result.isOk()) return null;
        return {startMs: haxefmod.studio.native.Scratch.readI(0),
            endMs: haxefmod.studio.native.Scratch.readI(1)};
    }

    /** Combines ChannelMode flags. New channels start with the sound's mode. */
    public inline function setMode(mode:Int):FmodResult {
        return NativeStudio.sound_set_mode(this, mode);
    }

    public inline function getMode():Int {
        return NativeStudio.sound_get_mode(this);
    }

    public function getFormat():Null<{channels:Int, bits:Int}> {
        var result:FmodResult = NativeStudio.sound_get_format(this);
        if (!result.isOk()) return null;
        return {channels: haxefmod.studio.native.Scratch.readI(0),
            bits: haxefmod.studio.native.Scratch.readI(1)};
    }

    /** FMOD_OPENSTATE value (0 = ready), or -1 on failure. Async loads report progress here. */
    public inline function getOpenState():Int {
        return NativeStudio.sound_get_open_state(this);
    }

    /**
     * Marks a timeline position. Playback crossing it delivers
     * ChannelEvent.SyncPoint (see Channel.setCallback) with the point's
     * index in offset order.
     */
    public inline function addSyncPoint(offsetMs:Int, name:String):FmodResult {
        return NativeStudio.sound_add_sync_point(this, offsetMs, name);
    }

    public inline function deleteSyncPoint(index:Int):FmodResult {
        return NativeStudio.sound_delete_sync_point(this, index);
    }

    public inline function getSyncPointCount():Int {
        return NativeStudio.sound_get_num_sync_points(this);
    }

    public inline function getSyncPointName(index:Int):String {
        return NativeStudio.sound_get_sync_point_name(this, index);
    }

    /** The point's offset in milliseconds, or -1 on failure. */
    public inline function getSyncPointOffset(index:Int):Int {
        return NativeStudio.sound_get_sync_point_offset(this, index);
    }

    /** The sound's name (raw memory sounds report an empty name). */
    public inline function getName():String {
        return NativeStudio.sound_get_name(this);
    }

    /** The group this sound belongs to (a known group returns its existing handle). */
    public inline function getSoundGroup():haxefmod.core.SoundGroup {
        return NativeStudio.sound_get_sound_group(this);
    }

    /** Times to loop before stopping (-1 = forever). New channels inherit it. */
    public inline function setLoopCount(loopCount:Int):FmodResult {
        return NativeStudio.sound_set_loop_count(this, loopCount);
    }

    public inline function getLoopCount():Int {
        return NativeStudio.sound_get_loop_count(this);
    }

    /** Moves this sound into a group (see haxefmod.core.SoundGroup). */
    public inline function setSoundGroup(group:haxefmod.core.SoundGroup):FmodResult {
        return NativeStudio.sound_set_sound_group(this, group);
    }

    public inline function isNull():Bool {
        return this == 0;
    }

    /**
     * Default 3D cone for channels played from this sound: full volume
     * inside insideAngle, fading to outsideVolume past outsideAngle.
     */
    public inline function set3DConeSettings(insideAngle:Float, outsideAngle:Float, outsideVolume:Float):FmodResult {
        return NativeStudio.core_sound_set_3d_cone_settings(this, insideAngle, outsideAngle, outsideVolume);
    }

    public function get3DConeSettings():Null<{insideAngle:Float, outsideAngle:Float, outsideVolume:Float}> {
        var result:FmodResult = NativeStudio.core_sound_get_3d_cone_settings(this);
        if (!result.isOk()) return null;
        return {insideAngle: Scratch.readF(0), outsideAngle: Scratch.readF(1), outsideVolume: Scratch.readF(2)};
    }

    /** Default rolloff distances for channels played from this sound. */
    public inline function set3DMinMaxDistance(minDistance:Float, maxDistance:Float):FmodResult {
        return NativeStudio.core_sound_set_3d_min_max(this, minDistance, maxDistance);
    }

    public function get3DMinMaxDistance():Null<{minDistance:Float, maxDistance:Float}> {
        var result:FmodResult = NativeStudio.core_sound_get_3d_min_max(this);
        if (!result.isOk()) return null;
        return {minDistance: Scratch.readF(0), maxDistance: Scratch.readF(1)};
    }

    /** Length in milliseconds, or -1 on failure. */
    public inline function getLength():Int {
        return NativeStudio.core_get_sound_length(this);
    }

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /**
     * Replaces the distance rolloff curve with the given points. Each
     * point's x is the distance and y the volume (0 to 1), sorted by
     * distance. An empty array restores the mode-driven rolloff
     * (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED). The
     * binding keeps its own copy of the points for the sound's
     * lifetime.
     */
    public macro function set3DCustomRolloff(self:haxe.macro.Expr, points:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("CoreSound.set3DCustomRolloff", "the web boundary rejects custom rolloff points");
    }
    #else
    /**
     * Replaces the distance rolloff curve with the given points. Each
     * point's x is the distance and y the volume (0 to 1), sorted by
     * distance. An empty array restores the mode-driven rolloff
     * (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED). The
     * binding keeps its own copy of the points for the sound's
     * lifetime.
     */
    public function set3DCustomRolloff(points:Array<FmodVector>):FmodResult {
        var packed = Scratch.packVectors(points);
        return NativeStudio.core_sound_set_3d_custom_rolloff(this, packed, packed == null ? 0 : points.length);
    }
    #end

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /**
     * The custom rolloff points (unsupported in HTML5, always empty
     * there), empty when none are set or on failure (see
     * StudioSystem.lastResult). Capped at Scratch.VECTOR_CAPACITY points.
     */
    public macro function get3DCustomRolloff(self:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("CoreSound.get3DCustomRolloff", "custom rolloff points cannot be set in the web build, so there is nothing to read");
    }
    #else
    /**
     * The custom rolloff points (unsupported in HTML5, always empty
     * there), empty when none are set or on failure (see
     * StudioSystem.lastResult). Capped at Scratch.VECTOR_CAPACITY points.
     */
    public function get3DCustomRolloff():Array<FmodVector> {
        var count = NativeStudio.core_sound_get_3d_custom_rolloff(this);
        if (count <= 0) return [];
        return Scratch.readVectors(count);
    }
    #end

    /** Releases the sound and invalidates this handle. */
    public inline function release():FmodResult {
        UserData.clear(UserDataKind.CoreSound, this);
        return NativeStudio.core_release_sound(this);
    }

    /**
     * Attaches a Haxe value to this handle. The value lives on the Haxe
     * side keyed by the handle and is dropped when the handle is released.
     * A recycled native slot gets a new generation and therefore a new
     * handle int, so a stale entry never shows up on a later handle.
     */
    public inline function setUserData(value:Dynamic):Void {
        UserData.set(UserDataKind.CoreSound, this, value);
    }

    /** The value attached with setUserData, or null. */
    public inline function getUserData():Dynamic {
        return UserData.get(UserDataKind.CoreSound, this);
    }
}
