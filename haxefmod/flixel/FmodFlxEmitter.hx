package haxefmod.flixel;

import flixel.FlxBasic;
import flixel.FlxObject;
import haxefmod.runtime.EmitterTracker;
import haxefmod.runtime.FmodRuntime;
import haxefmod.runtime.IFmodPositionProvider;
import haxefmod.studio.EventInstance;

/**
    Keeps an event instance's 3D position synced to a moving FlxObject.

    The instance follows the object's midpoint and velocity for as long as
    both are alive. Positions are pushed by FmodRuntime.update() (which
    FmodManager.Update() calls), so this component needs no per-frame work
    of its own - just make sure Update() runs every frame (or add
    FmodFlxUpdater once).

        var emitter = FmodFlxEmitter.play(FmodEvents.SFXEngine, car);
        add(emitter);
        // later: emitter.destroy() detaches and releases the instance
**/
class FmodFlxEmitter extends FlxBasic {
    /** The attached event instance (EventInstance.NULL after destroy). **/
    public var instance(get, never):EventInstance;

    /**
        Stops the event with a fadeout while the emitter is beyond its
        authored max distance from the listener, and restarts it when the
        listener comes back in range, saving voices on far-away looping
        emitters. Off by default. Only an instance the emitter itself
        stopped is restarted, so an instance the game stops stays stopped.
        A restart begins from the event's start with the instance's
        parameter values still applied.
    **/
    public var stopEventsOutsideMaxDistance(get, set):Bool;

    /** The listener the culling distance is measured against. **/
    public var listenerIndex(get, set):Int;

    /**
        Frames between culling distance checks. The default keeps the
        per-frame cost near zero; set 1 to check every frame.
    **/
    public var cullCheckInterval(get, set):Int;

    /**
        Culling distance override in world units. The default -1 uses the
        event's authored max distance and applies only to 3D events. A 2D
        event is never culled by default, so give it an explicit value
        here to cull it.
    **/
    public var cullMaxDistance(get, set):Float;

    var tracker:EmitterTracker;

    /**
        Attaches an existing event instance to a FlxObject. The caller is
        responsible for starting the instance. destroy() releases it.
        @param instance the event instance to position
        @param target the object to follow (midpoint and velocity)
    **/
    public function new(instance:EventInstance, target:FlxObject) {
        super();
        tracker = new EmitterTracker(instance, new FlxObjectPositionProvider(target));
    }

    /**
        Convenience: creates an instance of the event, starts it, and
        attaches it to the target in one call.
        @param eventPath the full event path (e.g. "event:/SFX/Engine")
        @param target the object to follow
    **/
    public static function play(eventPath:String, target:FlxObject):FmodFlxEmitter {
        var instance = FmodRuntime.createInstance(eventPath);
        if (!instance.isNull()) {
            instance.start();
        }
        return new FmodFlxEmitter(instance, target);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        tracker.update();
    }

    /** Detaches and releases the instance (it plays out unless stopped). **/
    override public function destroy():Void {
        tracker.dispose();
        super.destroy();
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
}

/** Adapts a FlxObject (midpoint + velocity) to the runtime's position interface. **/
class FlxObjectPositionProvider implements IFmodPositionProvider {
    var target:FlxObject;

    public function new(target:FlxObject) {
        this.target = target;
    }

    public function fmodX():Float {
        return target.x + target.width / 2;
    }

    public function fmodY():Float {
        return target.y + target.height / 2;
    }

    public function fmodVelocityX():Float {
        // A destroyed FlxObject nulls its velocity while position fields
        // stay readable, so a stale target reports zero motion instead of
        // crashing the per-frame push
        var velocity = target.velocity;
        return velocity == null ? 0 : velocity.x;
    }

    public function fmodVelocityY():Float {
        var velocity = target.velocity;
        return velocity == null ? 0 : velocity.y;
    }
}
