package haxefmod.core;

import haxefmod.studio.FmodResult;
import haxefmod.studio.StudioSystem;
import haxefmod.studio.Types;
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
abstract Sound(Int) from Int to Int {
    public static inline var NULL:Sound = cast 0;

    /**
     * Loads a sound file. Returns Sound.NULL on failure (see
     * StudioSystem.lastResult). openOnly keeps the file open without
     * decoding it up front (FMOD_OPENONLY), which readData needs. A sound
     * opened that way cannot be played.
     */
    public static inline function create(path:String, loop:Bool = false, openOnly:Bool = false):Sound {
        return NativeStudio.core_create_sound(path, loop ? 1 : 0, openOnly);
    }

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /**
     * An empty PCM16 sound of the given length for StudioSystem.recordStart
     * to fill (unsupported in HTML5). Returns Sound.NULL there and on
     * bad arguments. Release it like any other sound.
     */
    public static macro function createRecordBuffer(sampleRate:haxe.macro.Expr, channels:haxe.macro.Expr, seconds:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("Sound.createRecordBuffer", "the web build has no microphone recording");
    }
    #else
    /**
     * An empty PCM16 sound of the given length for StudioSystem.recordStart
     * to fill (unsupported in HTML5). Returns Sound.NULL there and on
     * bad arguments. Release it like any other sound.
     */
    public static inline function createRecordBuffer(sampleRate:Int, channels:Int, seconds:Int):Sound {
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
        return haxefmod.studio.native.Html5Gate.block("Sound.readData", "FMOD's web build cannot read sample data");
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
        return haxefmod.studio.native.Html5Gate.block("Sound.seekData", "FMOD's web build cannot seek sample data");
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
    public static function fromPcm(data:haxe.io.Bytes, sampleRate:Int, channels:Int, length:Int = -1):Sound {
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

    /**
     * The sound's open state, READY once it can play. Async loads report
     * their progress here. A failed query also comes back as ERROR, with
     * the reason in StudioSystem.lastResult().
     */
    public function getOpenState():FmodOpenState {
        var state = NativeStudio.sound_get_open_state(this);
        return state < 0 ? FmodOpenState.ERROR : (state : FmodOpenState);
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
        return haxefmod.studio.native.Html5Gate.block("Sound.set3DCustomRolloff", "the web boundary rejects custom rolloff points");
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
        return haxefmod.studio.native.Html5Gate.block("Sound.get3DCustomRolloff", "custom rolloff points cannot be set in the web build, so there is nothing to read");
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
        UserData.clear(UserDataKind.Sound, this);
        return NativeStudio.core_release_sound(this);
    }

    /**
     * Attaches a Haxe value to this handle. The value lives on the Haxe
     * side keyed by the handle and is dropped when the handle is released.
     * A recycled native slot gets a new generation and therefore a new
     * handle int, so a stale entry never shows up on a later handle.
     */
    public inline function setUserData(value:Dynamic):Void {
        UserData.set(UserDataKind.Sound, this, value);
    }

    /** The value attached with setUserData, or null. */
    public inline function getUserData():Dynamic {
        return UserData.get(UserDataKind.Sound, this);
    }
    //// Tracker music

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /**
     * Channel count of a tracker module (MOD, S3M, XM, IT) (unsupported in
     * HTML5, returns -1 there). -1 on failure, and any other format reports
     * FMOD_ERR_FORMAT through StudioSystem.lastResult.
     */
    public macro function getMusicNumChannels(self:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("Sound.getMusicNumChannels", "the web build cannot load tracker modules");
    }
    #else
    /**
     * Channel count of a tracker module (MOD, S3M, XM, IT) (unsupported in
     * HTML5, returns -1 there). -1 on failure, and any other format reports
     * FMOD_ERR_FORMAT through StudioSystem.lastResult.
     */
    public inline function getMusicNumChannels():Int {
        return NativeStudio.core_sound_get_music_num_channels(this);
    }
    #end

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /** Volume of one tracker channel, 0 to 1 (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED). */
    public macro function setMusicChannelVolume(self:haxe.macro.Expr, channel:haxe.macro.Expr, volume:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("Sound.setMusicChannelVolume", "the web build cannot load tracker modules");
    }
    #else
    /** Volume of one tracker channel, 0 to 1 (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED). */
    public inline function setMusicChannelVolume(channel:Int, volume:Float):FmodResult {
        return NativeStudio.core_sound_set_music_channel_volume(this, channel, volume);
    }
    #end

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /** Volume of one tracker channel (unsupported in HTML5, returns 0 there). 0 on failure. */
    public macro function getMusicChannelVolume(self:haxe.macro.Expr, channel:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("Sound.getMusicChannelVolume", "the web build cannot load tracker modules");
    }
    #else
    /** Volume of one tracker channel (unsupported in HTML5, returns 0 there). 0 on failure. */
    public inline function getMusicChannelVolume(channel:Int):Float {
        return NativeStudio.core_sound_get_music_channel_volume(this, channel);
    }
    #end

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /** Playback speed of a tracker module, 1 is normal, 0.01 to 100 (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED). */
    public macro function setMusicSpeed(self:haxe.macro.Expr, speed:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("Sound.setMusicSpeed", "the web build cannot load tracker modules");
    }
    #else
    /** Playback speed of a tracker module, 1 is normal, 0.01 to 100 (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED). */
    public inline function setMusicSpeed(speed:Float):FmodResult {
        return NativeStudio.core_sound_set_music_speed(this, speed);
    }
    #end

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /** Playback speed of a tracker module (unsupported in HTML5, returns 0 there). 0 on failure. */
    public macro function getMusicSpeed(self:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("Sound.getMusicSpeed", "the web build cannot load tracker modules");
    }
    #else
    /** Playback speed of a tracker module (unsupported in HTML5, returns 0 there). 0 on failure. */
    public inline function getMusicSpeed():Float {
        return NativeStudio.core_sound_get_music_speed(this);
    }
    #end

    //// Subsounds and tags

    /** Number of subsounds (FSB and multi-stream containers). 0 for plain sounds, -1 on failure. */
    public inline function getNumSubSounds():Int {
        return NativeStudio.core_sound_get_num_sub_sounds(this);
    }

    /**
     * A subsound by index, or Sound.NULL when the index is out of
     * range (StudioSystem.lastResult reports FMOD_ERR_INVALID_PARAM). The
     * subsound belongs to its parent, so never call release() on it: FMOD
     * frees it with the parent, and releasing the parent also drops every
     * subsound handle taken from it.
     */
    public inline function getSubSound(index:Int):Sound {
        return NativeStudio.core_sound_get_sub_sound(this, index);
    }

    /** The sound this one is a subsound of, or Sound.NULL for a top-level sound (lastResult stays FMOD_OK). */
    public inline function getSubSoundParent():Sound {
        return NativeStudio.core_sound_get_sub_sound_parent(this);
    }

    /** Number of metadata tags, -1 on failure. Streams grow this as they play. */
    public inline function getNumTags():Int {
        return NativeStudio.core_sound_get_num_tags(this);
    }

    /** Tags that changed since the last getTag pass, -1 on failure. Meant for stream metadata polling. */
    public function getNumTagsUpdated():Int {
        if (NativeStudio.core_sound_get_num_tags(this) < 0) return -1;
        return Scratch.readI(0);
    }

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /**
     * Reads one metadata tag (unsupported in HTML5, returns null there).
     * A null name walks every tag by index, a name picks the index-th tag
     * of that name. Null when the tag does not exist
     * (StudioSystem.lastResult reports FMOD_ERR_TAGNOTFOUND). String
     * payloads come back in stringValue, INT and FLOAT payloads in their
     * fields, binary and UTF16 payloads only report their length.
     */
    public macro function getTag(self:haxe.macro.Expr, name:haxe.macro.Expr, ?index:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("Sound.getTag", "the web build cannot hand the tag payload to JavaScript");
    }
    #else
    /**
     * Reads one metadata tag (unsupported in HTML5, returns null there).
     * A null name walks every tag by index, a name picks the index-th tag
     * of that name. Null when the tag does not exist
     * (StudioSystem.lastResult reports FMOD_ERR_TAGNOTFOUND). String
     * payloads come back in stringValue, INT and FLOAT payloads in their
     * fields, binary and UTF16 payloads only report their length.
     */
    public function getTag(name:String, index:Int = 0):Null<FmodTag> {
        var key = name == null ? "" : name;
        var tagName = NativeStudio.core_sound_get_tag(this, key, index);
        var result:FmodResult = StudioSystem.lastResult();
        if (!result.isOk()) return null;
        var dataType:FmodTagDataType = Scratch.readI(1);
        var text = "";
        if (dataType == FmodTagDataType.STRING || dataType == FmodTagDataType.STRING_UTF8) {
            text = NativeStudio.core_sound_get_tag_string(this, key, index);
        }
        return {
            name: tagName,
            type: (Scratch.readI(0) : FmodTagType),
            dataType: dataType,
            updated: Scratch.readI(2) != 0,
            length: Scratch.readI(3),
            intValue: Scratch.readI(4),
            floatValue: Scratch.readF(0),
            stringValue: text,
        };
    }
    #end
}
