package haxefmod.flixel;

import flixel.FlxBasic;
import flixel.FlxObject;
import haxefmod.runtime.FmodRuntime;
import haxefmod.runtime.IFmodPositionProvider;
import haxefmod.studio.EventInstance;
import haxefmod.studio.StudioSystem;
import haxefmod.studio.Types;

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
    public var instance(default, null):EventInstance;

    /**
        Stops the event with a fadeout while the emitter is beyond its
        authored max distance from the listener, and restarts it when the
        listener comes back in range, saving voices on far-away looping
        emitters. Off by default. Only an instance the emitter itself
        stopped is restarted, so an instance the game stops stays stopped.
        A restart begins from the event's start with the instance's
        parameter values still applied.
    **/
    public var stopEventsOutsideMaxDistance:Bool = false;

    /** The listener the culling distance is measured against. **/
    public var listenerIndex:Int = 0;

    /**
        Frames between culling distance checks. The default keeps the
        per-frame cost near zero; set 1 to check every frame.
    **/
    public var cullCheckInterval:Int = 6;

    /**
        Culling distance override in world units. The default -1 uses the
        event's authored max distance and applies only to 3D events. A 2D
        event is never culled by default, so give it an explicit value
        here to cull it.
    **/
    public var cullMaxDistance:Float = -1;

    var provider:FlxObjectPositionProvider;
    var culled:Bool = false;
    var cullFrameCounter:Int = 0;
    var cullOneshot:Null<Bool> = null;
    var cull3d:Null<Bool> = null;

    /**
        Attaches an existing event instance to a FlxObject. The caller is
        responsible for starting the instance. destroy() releases it.
        @param instance the event instance to position
        @param target the object to follow (midpoint and velocity)
    **/
    public function new(instance:EventInstance, target:FlxObject) {
        super();
        this.instance = instance;
        provider = new FlxObjectPositionProvider(target);
        FmodRuntime.attach(instance, provider);
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
        if (instance.isNull()) return;
        if (!stopEventsOutsideMaxDistance) {
            // Turning culling off while culled would otherwise leave the
            // event stopped with nothing left to restart it
            if (culled) {
                culled = false;
                instance.start();
            }
            return;
        }

        // The check costs a native listener fetch, so it runs on an
        // interval rather than every frame
        cullFrameCounter++;
        if (cullFrameCounter < cullCheckInterval) return;
        cullFrameCounter = 0;

        // One-shots are exempt, matching FMOD's own integration: stopping
        // and restarting a self-ending event would replay it long after it
        // would have finished
        if (cullOneshot == null) cullOneshot = instance.getDescription().isOneshot();
        if (cullOneshot) return;

        if (cullMaxDistance < 0) {
            // Authored distances only gate 3D events. A 2D event still
            // reports the default macro range from newer bank formats, so
            // a nonzero max cannot be the test here.
            if (cull3d == null) cull3d = instance.getDescription().is3D();
            if (!cull3d) return;
            var minMax = instance.getMinMaxDistance();
            if (minMax == null) return;
            cullMaxDistance = minMax.max;
        }
        if (cullMaxDistance <= 0) return;

        var listener = StudioSystem.getListenerAttributes(listenerIndex);
        if (listener == null) return;
        var dx = provider.fmodX() - listener.position.x;
        var dy = provider.fmodY() - listener.position.y;
        var outside = dx * dx + dy * dy > cullMaxDistance * cullMaxDistance;

        if (outside && !culled) {
            // Only an instance that is actually playing gets culled, and
            // culled means "stopped by this emitter" - an instance the
            // game stopped itself is never restarted on re-entry
            var state = instance.getPlaybackState();
            if (state == FmodPlaybackState.PLAYING
                || state == FmodPlaybackState.STARTING
                || state == FmodPlaybackState.SUSTAINING) {
                culled = true;
                instance.stop(FmodStopMode.ALLOWFADEOUT);
            }
        } else if (!outside && culled) {
            culled = false;
            instance.start();
        }
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
