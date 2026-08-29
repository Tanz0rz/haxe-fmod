package haxefmod.heaps;

import h2d.Object;
import haxefmod.heaps.FmodHeapsUpdater.IHeapsTicker;
import haxefmod.runtime.EmitterTracker;
import haxefmod.runtime.FmodRuntime;
import haxefmod.runtime.ListenerTracker.DerivedVelocityProvider;
import haxefmod.runtime.IFmodPositionProvider;
import haxefmod.studio.EventInstance;

/**
    Keeps an event instance's 3D position synced to a moving h2d.Object.

    The instance follows the center of the object's bounds. Heaps objects
    carry no velocity, so one is derived from the movement between frames
    (a jump larger than teleportDistance in one frame counts as a cut).
    The emitter registers with FmodHeapsUpdater and needs no per-frame
    call of its own.

        var emitter = FmodHeapsEmitter.play(FmodEvents.SFXEngine, car);
        // later: emitter.dispose() detaches and releases the instance
**/
class FmodHeapsEmitter implements IHeapsTicker {
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
    var provider:H2dObjectPositionProvider;

    /**
        Attaches an existing event instance to an object. The caller is
        responsible for starting the instance. dispose() releases it.
    **/
    public function new(instance:EventInstance, target:Object) {
        provider = new H2dObjectPositionProvider(target);
        tracker = new EmitterTracker(instance, provider);
        FmodHeapsUpdater.add(this);
    }

    /** Creates an instance of the event, starts it, and attaches it to the target. **/
    public static function play(eventPath:String, target:Object):FmodHeapsEmitter {
        var instance = FmodRuntime.createInstance(eventPath);
        if (!instance.isNull()) {
            instance.start();
        }
        return new FmodHeapsEmitter(instance, target);
    }

    public function tick(dt:Float):Void {
        provider.sample(dt);
        tracker.update();
    }

    /** Detaches and releases the instance (it plays out unless stopped). **/
    public function dispose():Void {
        FmodHeapsUpdater.remove(this);
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
    Adapts an h2d.Object to the runtime's position interface: the center
    of its scene-space bounds, with velocity derived between samples.
    Call sample(dt) once per frame (the heaps components do).
**/
class H2dObjectPositionProvider extends DerivedVelocityProvider {
    public function new(target:Object, teleportDistance:Float = 500) {
        super(() -> centerX(target), () -> centerY(target), teleportDistance);
    }

    public static function centerX(target:Object):Float {
        var bounds = target.getBounds();
        return bounds.isEmpty() ? target.x : (bounds.xMin + bounds.xMax) / 2;
    }

    public static function centerY(target:Object):Float {
        var bounds = target.getBounds();
        return bounds.isEmpty() ? target.y : (bounds.yMin + bounds.yMax) / 2;
    }
}
