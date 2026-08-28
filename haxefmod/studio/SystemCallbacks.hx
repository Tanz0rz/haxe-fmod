package haxefmod.studio;

import haxefmod.studio.native.NativeStudio;

/**
 * Events raised by the core System and the Studio System.
 *
 * DeviceListChanged and DeviceLost come from the core system. The rest
 * come from Studio. BankUnload carries the bank path when the unload went
 * through Bank.unload or unloadAll, and an empty string otherwise.
 */
enum SystemEvent {
    DeviceListChanged;
    DeviceLost;
    PreUpdate;
    PostUpdate;
    BankUnload(path:String);
    LiveUpdateConnected;
    LiveUpdateDisconnected;
}

/**
 * Routing for system events. They ride the same native queue as event
 * and channel callbacks under the 0x20000000 type namespace with handle
 * 0, and the CallbackDispatcher hands them here during its per-frame
 * drain.
 *
 * Register through StudioSystem.setSystemCallback rather than directly.
 */
class SystemCallbacks {
    /** Records in this namespace belong to the system callbacks. */
    public static inline var TYPE_NAMESPACE:Int = 0x20000000;

    /** Set on the studio types so they cannot collide with the core types. */
    public static inline var STUDIO_BIT:Int = 0x100;

    /** Core System callback mask bits (FMOD_SYSTEM_CALLBACK_*). */
    public static inline var CORE_DEVICELISTCHANGED:Int = 0x1;
    public static inline var CORE_DEVICELOST:Int = 0x2;

    /** Studio System callback mask bits (FMOD_STUDIO_SYSTEM_CALLBACK_*). */
    public static inline var STUDIO_PREUPDATE:Int = 0x1;
    public static inline var STUDIO_POSTUPDATE:Int = 0x2;
    public static inline var STUDIO_BANK_UNLOAD:Int = 0x4;
    public static inline var STUDIO_LIVEUPDATE_CONNECTED:Int = 0x8;
    public static inline var STUDIO_LIVEUPDATE_DISCONNECTED:Int = 0x10;

    /** Default masks. PreUpdate and PostUpdate fire every update, so they are opt-in. */
    public static inline var DEFAULT_CORE_MASK:Int = CORE_DEVICELISTCHANGED | CORE_DEVICELOST;
    public static inline var DEFAULT_STUDIO_MASK:Int = STUDIO_BANK_UNLOAD | STUDIO_LIVEUPDATE_CONNECTED | STUDIO_LIVEUPDATE_DISCONNECTED;

    /** Queue record types, namespace applied. */
    public static inline var TYPE_DEVICELISTCHANGED:Int = TYPE_NAMESPACE | CORE_DEVICELISTCHANGED;
    public static inline var TYPE_DEVICELOST:Int = TYPE_NAMESPACE | CORE_DEVICELOST;
    public static inline var TYPE_PREUPDATE:Int = TYPE_NAMESPACE | STUDIO_BIT | STUDIO_PREUPDATE;
    public static inline var TYPE_POSTUPDATE:Int = TYPE_NAMESPACE | STUDIO_BIT | STUDIO_POSTUPDATE;
    public static inline var TYPE_BANK_UNLOAD:Int = TYPE_NAMESPACE | STUDIO_BIT | STUDIO_BANK_UNLOAD;
    public static inline var TYPE_LIVEUPDATE_CONNECTED:Int = TYPE_NAMESPACE | STUDIO_BIT | STUDIO_LIVEUPDATE_CONNECTED;
    public static inline var TYPE_LIVEUPDATE_DISCONNECTED:Int = TYPE_NAMESPACE | STUDIO_BIT | STUDIO_LIVEUPDATE_DISCONNECTED;

    /** True for queue records that belong to the system callbacks. */
    public static inline function isSystemType(type:Int):Bool {
        return (type & TYPE_NAMESPACE) != 0;
    }

    static var handler:Null<SystemEvent->Void> = null;

    /**
     * Installs the handler and tells FMOD which events to raise. Replaces
     * any existing handler. Null masks take the defaults.
     */
    public static function set(handler:SystemEvent->Void, ?coreMask:Int, ?studioMask:Int):Void {
        if (handler == null) {
            clear();
            return;
        }
        installRouter();
        SystemCallbacks.handler = handler;
        NativeStudio.sys_set_callback_mask(coreMask == null ? DEFAULT_CORE_MASK : coreMask);
        NativeStudio.sys_set_studio_callback_mask(studioMask == null ? DEFAULT_STUDIO_MASK : studioMask);
    }

    /** Removes the handler and both native callbacks. */
    public static function clear():Void {
        if (handler == null) return;
        handler = null;
        NativeStudio.sys_set_callback_mask(0);
        NativeStudio.sys_set_studio_callback_mask(0);
    }

    /** True while a handler is installed. */
    public static function isSet():Bool {
        return handler != null;
    }

    /**
     * Hooks system routing into the dispatcher drain. Installed lazily on
     * first registration. Reassignment is idempotent.
     */
    static function installRouter():Void {
        CallbackDispatcher.systemRouter = route;
    }

    static function route(type:Int, str:String):Bool {
        if (!isSystemType(type)) return false;
        deliver(type, str);
        return true;
    }

    /** Decodes a raw queue record. Null for types this class does not know. */
    public static function decode(type:Int, str:String):Null<SystemEvent> {
        return switch (type) {
            case TYPE_DEVICELISTCHANGED: DeviceListChanged;
            case TYPE_DEVICELOST: DeviceLost;
            case TYPE_PREUPDATE: PreUpdate;
            case TYPE_POSTUPDATE: PostUpdate;
            case TYPE_BANK_UNLOAD: BankUnload(str);
            case TYPE_LIVEUPDATE_CONNECTED: LiveUpdateConnected;
            case TYPE_LIVEUPDATE_DISCONNECTED: LiveUpdateDisconnected;
            default: null;
        }
    }

    /** Delivers one raw queue record. Public for unit tests. */
    public static function deliver(type:Int, str:String):Void {
        if (handler == null) return;
        var event = decode(type, str);
        if (event == null) return;
        try {
            handler(event);
        } catch (e:haxe.Exception) {
            trace('Warn: FMOD - a system callback handler threw: ${e.message}');
        }
    }
}
