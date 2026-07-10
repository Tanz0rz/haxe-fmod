package haxefmod.runtime;

import haxefmod.studio.Callbacks;
import haxefmod.studio.native.NativeStudio;

/**
 * Drains the native callback event queue and dispatches typed callbacks on
 * the game thread.
 *
 * FMOD fires callbacks on its own threads. The native shims copy payloads
 * into a plain C ring buffer. update() (called from FmodManager.Update)
 * drains that ring and delivers EventCallbackData to registered handlers.
 *
 * One handler per event instance handle (registering again replaces it).
 * Handlers are removed automatically when the instance reports Destroyed.
 */
class CallbackDispatcher {
    static var handlers:Map<Int, EventCallbackData->Void> = new Map();

    /**
     * Registers a handler for an event instance and tells FMOD which
     * callback types to deliver. Replaces any existing handler.
     */
    public static function setCallback(handle:Int, handler:EventCallbackData->Void, ?mask:Int):Void {
        if (handle == 0 || handler == null) return;
        var callbackMask:Int = mask == null ? EventCallbackType.PLAYBACK_ALL : mask;
        // Always include DESTROYED so registrations clean themselves up.
        callbackMask |= EventCallbackType.DESTROYED;
        handlers.set(handle, handler);
        NativeStudio.evi_set_callback_mask(handle, callbackMask);
    }

    /** Removes the handler for an event instance. */
    public static function remove(handle:Int):Void {
        handlers.remove(handle);
    }

    /** Removes all handlers. */
    public static function clearAll():Void {
        handlers = new Map();
    }

    public static function hasHandler(handle:Int):Bool {
        return handlers.exists(handle);
    }

    /**
     * Drains the native queue and dispatches. Call once per frame.
     */
    public static function update():Void {
        while (NativeStudio.cb_next()) {
            deliver(NativeStudio.cb_handle(), NativeStudio.cb_type(),
                NativeStudio.cb_int(0), NativeStudio.cb_int(1), NativeStudio.cb_int(2),
                NativeStudio.cb_float(), NativeStudio.cb_string());
        }
        if (NativeStudio.cb_take_overflow()) {
            trace("Warn: FMOD - callback event queue overflowed; oldest events were dropped");
        }
    }

    /**
     * Delivers one raw queue record to its handler. Handlers may mutate
     * registrations freely (remove themselves, register other handles,
     * release instances): delivery looks up the handler per event and never
     * iterates the registration map. Public for unit tests.
     */
    public static function deliver(handle:Int, type:Int, i1:Int, i2:Int, i3:Int, f1:Float, str:String):Void {
        var handler = handlers.get(handle);
        if (handler != null) {
            handler(decode(type, i1, i2, i3, f1, str));
        }
        if (type == (EventCallbackType.DESTROYED : Int)) {
            handlers.remove(handle);
        }
    }

    /** Decodes a raw callback record into typed data. Public for unit tests. */
    public static function decode(type:Int, i1:Int, i2:Int, i3:Int, f1:Float, str:String):EventCallbackData {
        return switch (type : EventCallbackType) {
            case CREATED: Created;
            case DESTROYED: Destroyed;
            case STARTING: Starting;
            case STARTED: Started;
            case RESTARTED: Restarted;
            case STOPPED: Stopped;
            case START_FAILED: StartFailed;
            case TIMELINE_MARKER: TimelineMarker(str, i1);
            case TIMELINE_BEAT: TimelineBeat(i1, i2, i3, f1);
            case NESTED_TIMELINE_BEAT: NestedTimelineBeat(i1, i2, i3, f1);
            case SOUND_PLAYED: SoundPlayed;
            case SOUND_STOPPED: SoundStopped;
            case REAL_TO_VIRTUAL: RealToVirtual;
            case VIRTUAL_TO_REAL: VirtualToReal;
            default: Other(type);
        }
    }
}
