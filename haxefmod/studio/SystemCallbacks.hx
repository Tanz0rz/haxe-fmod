package haxefmod.studio;

import haxefmod.studio.Types.FmodErrorCallbackInfo;
import haxefmod.studio.native.NativeStudio;

/**
 * Events raised by the core System and the Studio System.
 *
 * DeviceListChanged, DeviceLost, and Error come from the core system. The
 * rest come from Studio. BankUnload carries the bank path when the unload
 * went through Bank.unload or unloadAll, and an empty string otherwise.
 * Error arrives only when CORE_ERROR is in the core mask and never on
 * HTML5, where FMOD's web build does not raise the error callback.
 */
enum SystemEvent {
    DeviceListChanged;
    DeviceLost;
    /** An FMOD call failed. info says which call, on what, and with which result. */
    Error(info:FmodErrorCallbackInfo);
    PreUpdate;
    PostUpdate;
    BankUnload(path:String);
    LiveUpdateConnected;
    LiveUpdateDisconnected;
}

/**
 * FMOD_SYSTEM_CALLBACK and FMOD_STUDIO_SYSTEM_CALLBACK as game code holds
 * them. One handler receives both systems' events on the game thread from
 * FmodManager.Update, so there is no system, commanddata, or userdata
 * argument and nothing to return. StudioSystem.setSystemCallback takes one.
 */
typedef SystemCallback = SystemEvent->Void;

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
    /** FMOD_SYSTEM_CALLBACK_ERROR, opt-in. Delivered as Error(info). */
    public static inline var CORE_ERROR:Int = 0x80;

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
    public static inline var TYPE_ERROR:Int = TYPE_NAMESPACE | CORE_ERROR;
    public static inline var TYPE_PREUPDATE:Int = TYPE_NAMESPACE | STUDIO_BIT | STUDIO_PREUPDATE;
    public static inline var TYPE_POSTUPDATE:Int = TYPE_NAMESPACE | STUDIO_BIT | STUDIO_POSTUPDATE;
    public static inline var TYPE_BANK_UNLOAD:Int = TYPE_NAMESPACE | STUDIO_BIT | STUDIO_BANK_UNLOAD;
    public static inline var TYPE_LIVEUPDATE_CONNECTED:Int = TYPE_NAMESPACE | STUDIO_BIT | STUDIO_LIVEUPDATE_CONNECTED;
    public static inline var TYPE_LIVEUPDATE_DISCONNECTED:Int = TYPE_NAMESPACE | STUDIO_BIT | STUDIO_LIVEUPDATE_DISCONNECTED;

    /** True for queue records that belong to the system callbacks. */
    public static inline function isSystemType(type:Int):Bool {
        return (type & TYPE_NAMESPACE) != 0;
    }

    static var handler:Null<SystemCallback> = null;

    /**
     * Installs the handler and tells FMOD which events to raise. Replaces
     * any existing handler. Null masks take the defaults.
     */
    public static function set(handler:SystemCallback, ?coreMask:Int, ?studioMask:Int):Void {
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

    static function route(type:Int, i1:Int, i2:Int, i3:Int, str:String, str2:String):Bool {
        if (!isSystemType(type)) return false;
        deliver(type, str, i1, i2, i3, str2);
        return true;
    }

    /**
     * Decodes a raw queue record. Null for types this class does not know.
     * An Error record carries the result in i1, the instance type in i2,
     * the instance handle in i3, the function name in str, and the
     * parameters in str2.
     */
    public static function decode(type:Int, str:String, i1:Int = 0, i2:Int = 0, i3:Int = 0, str2:String = ""):Null<SystemEvent> {
        return switch (type) {
            case TYPE_DEVICELISTCHANGED: DeviceListChanged;
            case TYPE_DEVICELOST: DeviceLost;
            case TYPE_ERROR: Error({
                result: (i1 : haxefmod.studio.FmodResult),
                instanceType: (i2 : haxefmod.studio.Types.FmodErrorCallbackInstanceType),
                instance: i3,
                functionName: str,
                functionParams: str2 == null ? "" : str2,
            });
            case TYPE_PREUPDATE: PreUpdate;
            case TYPE_POSTUPDATE: PostUpdate;
            case TYPE_BANK_UNLOAD: BankUnload(str);
            case TYPE_LIVEUPDATE_CONNECTED: LiveUpdateConnected;
            case TYPE_LIVEUPDATE_DISCONNECTED: LiveUpdateDisconnected;
            default: null;
        }
    }

    /** Delivers one raw queue record. Public for unit tests. */
    public static function deliver(type:Int, str:String, i1:Int = 0, i2:Int = 0, i3:Int = 0, str2:String = ""):Void {
        if (handler == null) return;
        var event = decode(type, str, i1, i2, i3, str2);
        if (event == null) return;
        try {
            handler(event);
        } catch (e:haxe.Exception) {
            trace('Warn: FMOD - a system callback handler threw: ${e.message}');
        }
    }
}
