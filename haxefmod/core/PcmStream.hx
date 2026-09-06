package haxefmod.core;

import haxefmod.studio.FmodResult;
import haxefmod.studio.UserData;
import haxefmod.studio.native.NativeStudio;

/**
 * FMOD_SOUND_PCMREAD_CALLBACK as game code holds it. FMOD's version runs
 * on the mixer thread, where no Haxe code can run. This one runs on the
 * game thread from FmodManager.Update whenever the stream's ring has
 * room, through PcmStream.setReadCallback. Fill data with dataLen bytes
 * of 16-bit PCM and return FmodResult.FMOD_OK. Any other result skips
 * the write for that frame.
 */
typedef PcmReadCallback = (stream:PcmStream, data:haxe.io.Bytes, dataLen:Int)->FmodResult;

/**
 * A stream for playing audio generated at runtime.
 *
 * create() makes an FMOD user sound backed by a ring buffer. The game
 * writes PCM bytes with write() and FMOD's mixer drains them as the sound
 * plays. Keep the ring topped up: when it runs dry the mixer plays silence
 * and counts an underrun (see takeUnderruns()).
 *
 * Samples are 16-bit signed integers in system byte order, interleaved
 * when stereo.
 */
abstract PcmStream(Int) from Int to Int {
    public static inline var NULL:PcmStream = cast 0;

    /**
     * Creates a stream. channels is 1 (mono) or 2 (stereo). ringBytes sets
     * how much audio can be buffered between the game and the mixer. The
     * default holds half a second: bigger rides out frame spikes without
     * underruns, smaller lets generated audio react faster.
     * Returns PcmStream.NULL on failure (see StudioSystem.lastResult).
     */
    public static inline function create(sampleRate:Int, channels:Int, ringBytes:Int = 0):PcmStream {
        // The default ring holds 0.5s of 16-bit PCM (2 bytes per sample)
        return NativeStudio.core_pcm_create(sampleRate, channels,
            ringBytes > 0 ? ringBytes : sampleRate * channels);
    }

    /**
     * Like create() but positional: the channel from play() accepts
     * set3DAttributes and attenuates with distance from the listener.
     */
    public static inline function create3d(sampleRate:Int, channels:Int, ringBytes:Int = 0):PcmStream {
        return NativeStudio.core_pcm_create_3d(sampleRate, channels,
            ringBytes > 0 ? ringBytes : sampleRate * channels);
    }

    /** True if this is the invalid handle (create failed). */
    public inline function isNull():Bool {
        return this == 0;
    }

    // Read callbacks keyed by handle, pumped once per frame after the
    // callback drain. One buffer per stream grows to the largest fill.
    static var readers:Map<Int, PcmReadCallback> = new Map();
    static var buffers:Map<Int, haxe.io.Bytes> = new Map();

    /**
     * Installs a callback that fills the ring from the game thread. Every
     * frame the ring has room, the callback receives a buffer and the
     * byte count to fill, and the bytes go into the ring when it returns
     * FMOD_OK. Replaces any earlier callback, null removes it.
     */
    public function setReadCallback(callback:PcmReadCallback):Void {
        if (this == 0) return;
        if (callback == null) {
            clearReadCallback();
            return;
        }
        readers.set(this, callback);
        haxefmod.studio.CallbackDispatcher.frameHook = pump;
    }

    /** Removes the read callback. release() does this too. */
    public function clearReadCallback():Void {
        readers.remove(this);
        buffers.remove(this);
    }

    /** True while a read callback is installed on this stream. */
    public inline function hasReadCallback():Bool {
        return readers.exists(this);
    }

    /** Drops every read callback. FmodManager.ClearAllCallbacks calls this. */
    public static function clearAllReadCallbacks():Void {
        readers = new Map();
        buffers = new Map();
    }

    /** Fills every stream with a read callback. Public for tests, runs from the frame drain otherwise. */
    public static function pump():Void {
        // A callback may remove itself, so walk a copy of the keys
        for (handle in [for (k in readers.keys()) k]) {
            if (!readers.exists(handle)) continue;
            var stream:PcmStream = handle;
            var room = stream.space();
            if (room <= 0) continue;
            var buffer = buffers.get(handle);
            if (buffer == null || buffer.length < room) {
                buffer = haxe.io.Bytes.alloc(room);
                buffers.set(handle, buffer);
            }
            var result:FmodResult = FmodResult.FMOD_ERR_INVALID_PARAM;
            try {
                result = readers.get(handle)(stream, buffer, room);
            } catch (e:haxe.Exception) {
                trace('Warn: FMOD - a PCM read callback threw: ${e.message}');
            }
            if (result == FmodResult.FMOD_OK) stream.write(buffer, room);
        }
    }

    /**
     * Queues PCM bytes for the mixer. Returns how many were accepted.
     * When the ring is full the rest are dropped, so hold on to anything
     * unaccepted and resend it once space() opens up.
     */
    public inline function write(data:haxe.io.Bytes, length:Int = -1):Int {
        if (data == null) return 0;
        // Exactly -1 means the whole buffer. Any other non-positive count
        // reaches the native layer and reports FMOD_ERR_INVALID_PARAM, so
        // a miscomputed count surfaces instead of writing everything.
        var len = length == -1 ? data.length : length;
        // Clamp to the real buffer size. The HashLink shim receives a bare
        // byte pointer with no length of its own, so an oversized count
        // would read past the buffer without this guard.
        if (len > data.length) len = data.length;
        return NativeStudio.core_pcm_write(this, data, len);
    }

    /** Bytes that can be written right now. */
    public inline function space():Int {
        return NativeStudio.core_pcm_space(this);
    }

    /**
     * Underruns since the last call, clearing the count. An underrun means
     * the mixer needed audio while the ring was empty and played silence.
     */
    public inline function takeUnderruns():Int {
        return NativeStudio.core_pcm_underruns(this);
    }

    /**
     * Starts playback. Returns Channel.NULL on failure. group routes the
     * new channel into a ChannelGroup from the first sample, null means
     * the master group.
     */
    public inline function play(startPaused:Bool = false, ?group:ChannelGroup):Channel {
        return NativeStudio.core_pcm_play(this, group == null ? 0 : (group : Int), startPaused);
    }

    /** Stops playback, frees the stream, and invalidates this handle. */
    public inline function release():FmodResult {
        clearReadCallback();
        UserData.clear(UserDataKind.PcmStream, this);
        return NativeStudio.core_pcm_release(this);
    }

    /**
     * Attaches a Haxe value to this handle. The value lives on the Haxe
     * side keyed by the handle and is dropped when the handle is released.
     * A recycled native slot gets a new generation and therefore a new
     * handle int, so a stale entry never shows up on a later handle.
     */
    public inline function setUserData(value:Dynamic):Void {
        UserData.set(UserDataKind.PcmStream, this, value);
    }

    /** The value attached with setUserData, or null. */
    public inline function getUserData():Dynamic {
        return UserData.get(UserDataKind.PcmStream, this);
    }
}
