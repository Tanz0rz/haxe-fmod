package haxefmod.core;

import haxefmod.studio.native.NativeStudio;

/**
 * A channel playback event delivered to a Channel.setCallback handler.
 */
enum ChannelEvent {
    /** The channel finished playing (also fires on stop). */
    End;
    /** Playback crossed a sync point (see CoreSound.addSyncPoint). */
    SyncPoint(index:Int);
}

/**
 * Routing for channel events. Channel events ride the same native queue
 * as studio event callbacks under a dedicated type namespace, and the
 * CallbackDispatcher hands them here during its per-frame drain.
 *
 * Register through Channel.setCallback rather than directly.
 */
class ChannelCallbacks {
    /** Channel event types in the queue's 0x40000000 namespace. */
    public static inline var TYPE_END:Int = 0x40000001;
    public static inline var TYPE_SYNCPOINT:Int = 0x40000002;

    /** True for queue records that belong to channels rather than events. */
    public static inline function isChannelType(type:Int):Bool {
        return (type & 0x40000000) != 0;
    }

    static var handlers:Map<Int, ChannelEvent->Void> = new Map();

    public static function set(handle:Int, handler:ChannelEvent->Void):Void {
        if (handle == 0 || handler == null) return;
        handlers.set(handle, handler);
        NativeStudio.chan_set_callback(handle, true);
    }

    public static function remove(handle:Int):Void {
        if (handlers.exists(handle)) {
            handlers.remove(handle);
            NativeStudio.chan_set_callback(handle, false);
        }
    }

    public static function clearAll():Void {
        handlers = new Map();
    }

    /**
     * Delivers one raw queue record. A channel ends once, so End also
     * removes the registration. Public for unit tests.
     */
    public static function deliver(handle:Int, type:Int, i1:Int):Void {
        var handler = handlers.get(handle);
        if (handler != null) {
            switch (type) {
                case TYPE_END: handler(End);
                case TYPE_SYNCPOINT: handler(SyncPoint(i1));
                default:
            }
        }
        if (type == TYPE_END) handlers.remove(handle);
    }
}
