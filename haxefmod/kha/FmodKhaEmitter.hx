package haxefmod.kha;

import haxefmod.kha.FmodKhaUpdater.IKhaTicker;
import haxefmod.runtime.EmitterTracker;
import haxefmod.runtime.FmodRuntime;
import haxefmod.runtime.ListenerTracker.DerivedVelocityProvider;
import haxefmod.studio.EventInstance;

/**
    Anything with a position the Kha components can follow. Kha has no
    scene graph, so a plain object with x and y (and optionally a size,
    to follow the midpoint) is the target.
**/
typedef KhaBody = {
    var x:Float;
    var y:Float;
    @:optional var width:Float;
    @:optional var height:Float;
}

/**
    Keeps an event instance's 3D position synced to a moving body.

    The instance follows the body's midpoint. Kha bodies carry no
    velocity for FMOD, so one is derived from the movement between
    frames (a jump larger than teleportDistance in one frame counts as a
    cut). The emitter registers with FmodKhaUpdater and needs no
    per-frame call of its own.

        var emitter = FmodKhaEmitter.play(FmodEvents.SFXEngine, car);
        // later: emitter.dispose() detaches and releases the instance
**/
class FmodKhaEmitter implements IKhaTicker {
    /** The attached event instance (EventInstance.NULL after dispose). **/
    public var instance(get, never):EventInstance;

    /** See EmitterTracker.stopEventsOutsideMaxDistance. **/
    public var stopEventsOutsideMaxDistance(get, set):Bool;

    /** The listener the culling distance is measured against. **/
    public var listenerIndex(get, set):Int;

    /** Frames between culling distance checks. **/
    public var cullCheckInterval(get, set):Int;

    /** Culling distance override in world units, -1 for the authored max. **/
    public var cullMaxDistance(get, set):Float;

    /** One-frame jumps beyond this report zero velocity. Default 500 units. **/
    public var teleportDistance(get, set):Float;

    var tracker:EmitterTracker;
    var provider:KhaBodyPositionProvider;

    /**
        Attaches an existing event instance to a body. The caller is
        responsible for starting the instance. dispose() releases it.
    **/
    public function new(instance:EventInstance, target:KhaBody) {
        provider = new KhaBodyPositionProvider(target);
        tracker = new EmitterTracker(instance, provider);
        FmodKhaUpdater.add(this);
    }

    /** Creates an instance of the event, starts it, and attaches it to the target. **/
    public static function play(eventPath:String, target:KhaBody):FmodKhaEmitter {
        var instance = FmodRuntime.createInstance(eventPath);
        if (!instance.isNull()) {
            instance.start();
        }
        return new FmodKhaEmitter(instance, target);
    }

    public function tick(dt:Float):Void {
        provider.sample(dt);
        tracker.update();
    }

    /** Detaches and releases the instance (it plays out unless stopped). **/
    public function dispose():Void {
        FmodKhaUpdater.remove(this);
        tracker.dispose();
    }

    function get_instance():EventInstance return tracker.instance;
    function get_stopEventsOutsideMaxDistance():Bool return tracker.stopEventsOutsideMaxDistance;
    function set_stopEventsOutsideMaxDistance(value:Bool):Bool return tracker.stopEventsOutsideMaxDistance = value;
    function get_listenerIndex():Int return tracker.listenerIndex;
    function set_listenerIndex(value:Int):Int return tracker.listenerIndex = value;
    function get_cullCheckInterval():Int return tracker.cullCheckInterval;
    function set_cullCheckInterval(value:Int):Int return tracker.cullCheckInterval = value;
    function get_cullMaxDistance():Float return tracker.cullMaxDistance;
    function set_cullMaxDistance(value:Float):Float return tracker.cullMaxDistance = value;
    function get_teleportDistance():Float return provider.teleportDistance;
    function set_teleportDistance(value:Float):Float return provider.teleportDistance = value;
}

/**
    Adapts a body to the runtime's position interface: its midpoint, with
    velocity derived between samples. Call sample(dt) once per frame
    (the Kha components do).
**/
class KhaBodyPositionProvider extends DerivedVelocityProvider {
    public function new(target:KhaBody, teleportDistance:Float = 500) {
        super(() -> midX(target), () -> midY(target), teleportDistance);
    }

    public static function midX(target:KhaBody):Float {
        return target.x + (target.width == null ? 0 : target.width / 2);
    }

    public static function midY(target:KhaBody):Float {
        return target.y + (target.height == null ? 0 : target.height / 2);
    }
}
