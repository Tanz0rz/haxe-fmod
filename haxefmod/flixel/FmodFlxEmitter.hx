package haxefmod.flixel;

import flixel.FlxBasic;
import flixel.FlxObject;
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

        var emitter = FmodFlxEmitter.play(FmodSFX.Engine, car);
        add(emitter);
        // later: emitter.destroy() detaches and releases the instance
**/
class FmodFlxEmitter extends FlxBasic {
    /** The attached event instance (EventInstance.NULL after destroy). **/
    public var instance(default, null):EventInstance;

    /**
        Attaches an existing event instance to a FlxObject. The caller is
        responsible for starting the instance; destroy() releases it.
        @param instance the event instance to position
        @param target the object to follow (midpoint and velocity)
    **/
    public function new(instance:EventInstance, target:FlxObject) {
        super();
        this.instance = instance;
        FmodRuntime.attach(instance, new FlxObjectPositionProvider(target));
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

    /** Detaches and releases the instance (it plays out unless stopped). **/
    override public function destroy():Void {
        if (!instance.isNull()) {
            FmodRuntime.detach(instance);
            instance.release();
            instance = EventInstance.NULL;
        }
        super.destroy();
    }
}

/** Adapts a FlxObject (midpoint + velocity) to the runtime's position interface. **/
private class FlxObjectPositionProvider implements IFmodPositionProvider {
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
        return target.velocity.x;
    }

    public function fmodVelocityY():Float {
        return target.velocity.y;
    }
}
