package haxefmod.studio;

import haxefmod.studio.Callbacks;
import haxefmod.studio.Types;
import haxefmod.studio.FmodResult;
import haxefmod.studio.UserData;
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
    /**
     * Queue records with this bit set belong to core channel callbacks,
     * not event instances (the shims reserve the namespace when encoding).
     */
    public static inline var CHANNEL_TYPE_NAMESPACE:Int = 0x40000000;

    /**
     * Queue records with this bit set belong to the system callbacks
     * (core and studio), carried with handle 0.
     */
    public static inline var SYSTEM_TYPE_NAMESPACE:Int = 0x20000000;

    static var handlers:Map<Int, EventCallback> = new Map();

    /**
     * Router consulted before event-instance dispatch. Queue records that
     * belong to other subsystems (core channel callbacks) are claimed here.
     * ChannelCallbacks installs itself when its first handler registers,
     * which keeps this class free of any dependency outside the studio
     * package. Returns true when the record was consumed.
     */
    public static var channelRouter:Null<(handle:Int, type:Int, i1:Int, f1:Float) -> Bool> = null;

    /**
     * Router for system records, installed by SystemCallbacks when its
     * handler registers. Returns true when the record was consumed.
     */
    public static var systemRouter:Null<(type:Int, i1:Int, i2:Int, i3:Int, str:String, str2:String) -> Bool> = null;

    /**
     * Runs after every drain, on the game thread. PcmStream installs its
     * read callback pump here, which keeps the core package out of this
     * class the same way the routers do.
     */
    public static var frameHook:Null<Void->Void> = null;

    /**
     * Registers a handler for an event instance and tells FMOD which
     * callback types to deliver. Replaces any existing handler. A null
     * handler removes the current registration.
     */
    public static function setCallback(handle:Int, handler:EventCallback, ?mask:Int):Void {
        if (handle == 0) return;
        if (handler == null) {
            handlers.remove(handle);
            // Shrink the native mask back to the always-on DESTROYED bit so
            // a beat-heavy instance stops filling the queue with records
            // nobody consumes
            NativeStudio.evi_set_callback_mask(handle, 0);
            return;
        }
        // Every type when no mask is given, the default FMOD's own API and its C# integration use
        var callbackMask:Int = mask == null ? EventCallbackType.ALL : mask;
        // Always include DESTROYED so registrations clean themselves up.
        callbackMask |= EventCallbackType.DESTROYED;
        var result:FmodResult = NativeStudio.evi_set_callback_mask(handle, callbackMask);
        // A stale handle will never deliver DESTROYED, so registering the
        // handler anyway would leak the closure for the rest of the session
        if (result == FmodResult.FMOD_ERR_INVALID_HANDLE) return;
        handlers.set(handle, handler);
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
                NativeStudio.cb_int(3), NativeStudio.cb_int(4),
                NativeStudio.cb_float(), NativeStudio.cb_string(), NativeStudio.cb_string2());
        }
        if (NativeStudio.cb_take_overflow()) {
            trace("Warn: FMOD - callback event queue overflowed. Oldest events were dropped.");
        }
        #if js
        UserData.dropDeadInstances();
        #end
        if (frameHook != null) frameHook();
    }

    /**
     * Delivers one raw queue record to its handler. Handlers may mutate
     * registrations freely (remove themselves, register other handles,
     * release instances): delivery looks up the handler per event and never
     * iterates the registration map. Public for unit tests.
     */
    public static function deliver(handle:Int, type:Int, i1:Int, i2:Int, i3:Int, i4:Int, i5:Int, f1:Float, str:String, str2:String = ""):Void {
        // Channel-domain records never reach event dispatch: routed when a
        // router is installed, dropped otherwise
        if ((type & CHANNEL_TYPE_NAMESPACE) != 0) {
            if (channelRouter != null) channelRouter(handle, type, i1, f1);
            return;
        }
        // Same for system records
        if ((type & SYSTEM_TYPE_NAMESPACE) != 0) {
            if (systemRouter != null) systemRouter(type, i1, i2, i3, str, str2);
            return;
        }
        var handler = handlers.get(handle);
        if (handler != null) {
            // A throwing handler must not wedge the drain or skip the
            // DESTROYED cleanup below - that registration would leak with
            // no second DESTROYED ever coming
            try {
                handler(decode(type, i1, i2, i3, i4, i5, f1, str));
            } catch (e:haxe.Exception) {
                trace('Warn: FMOD - a callback handler threw: ${e.message}');
            }
        }
        if (type == (EventCallbackType.DESTROYED : Int)) {
            handlers.remove(handle);
            // FMOD tore the instance down on its own, so release() never
            // ran and its userdata entry would otherwise outlive it
            UserData.clear(UserDataKind.EventInstance, handle);
        }
    }

    /** Decodes a raw callback record into typed data. Public for unit tests. */
    public static function decode(type:Int, i1:Int, i2:Int, i3:Int, i4:Int, i5:Int, f1:Float, str:String):EventCallbackData {
        return switch (type : EventCallbackType) {
            case CREATED: Created;
            case DESTROYED: Destroyed;
            case STARTING: Starting;
            case STARTED: Started;
            case RESTARTED: Restarted;
            case STOPPED: Stopped;
            case START_FAILED: StartFailed;
            case TIMELINE_MARKER: TimelineMarker({name: str, position: i1});
            case TIMELINE_BEAT: TimelineBeat(beatProperties(i1, i2, i3, i4, i5, f1));
            case NESTED_TIMELINE_BEAT: NestedTimelineBeat({eventId: str, properties: beatProperties(i1, i2, i3, i4, i5, f1)});
            case PLUGIN_CREATED: PluginCreated({name: str, dsp: (i1 : haxefmod.core.Dsp)});
            case PLUGIN_DESTROYED: PluginDestroyed({name: str, dsp: (i1 : haxefmod.core.Dsp)});
            case SOUND_PLAYED: SoundPlayed;
            case SOUND_STOPPED: SoundStopped;
            case REAL_TO_VIRTUAL: RealToVirtual;
            case VIRTUAL_TO_REAL: VirtualToReal;
            // The drain writes the sound handle into i1 and the subsound index into i2
            case CREATE_PROGRAMMER_SOUND: ProgrammerSoundCreated({name: str, sound: (i1 : haxefmod.core.Sound), subsoundIndex: i2});
            case DESTROY_PROGRAMMER_SOUND: ProgrammerSoundDestroyed({name: str, sound: (i1 : haxefmod.core.Sound), subsoundIndex: i2});
            default: Other(type);
        }
    }

    static function beatProperties(bar:Int, beat:Int, position:Int, upper:Int, lower:Int, tempo:Float):FmodTimelineBeatProperties {
        return {bar: bar, beat: beat, position: position, tempo: tempo, timeSignatureUpper: upper, timeSignatureLower: lower};
    }
}
