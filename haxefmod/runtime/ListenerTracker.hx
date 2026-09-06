package haxefmod.runtime;

import haxefmod.studio.StudioSystem;

/**
    Engine-free half of a listener component: pushes a provider's position
    and velocity to an FMOD listener on every update().

    The provider is whatever the engine adapter chose to follow, a
    character or a camera. A camera has no velocity of its own, so
    adapters wrap it in DerivedVelocityProvider, which derives one from
    the movement between frames.
**/
class ListenerTracker {
    public var provider:IFmodPositionProvider;
    public var listenerIndex:Int;

    public function new(provider:IFmodPositionProvider, listenerIndex:Int = 0) {
        this.provider = provider;
        this.listenerIndex = listenerIndex;
    }

    public function update():Void {
        if (provider == null) return;
        var velX = provider.fmodVelocityX();
        var velY = provider.fmodVelocityY();
        var settings = FmodRuntime.settings();
        var maxVelocity = settings != null ? settings.maxAttachedVelocity : 0.0;
        var scale = AttachedInstances.velocityScale(velX, velY, maxVelocity);
        StudioSystem.setListenerPosition2D(listenerIndex, provider.fmodX(), provider.fmodY(),
            velX * scale, velY * scale);
    }
}

/**
    A position provider for things that move without reporting a velocity
    (a camera, a scene node). The velocity is the movement since the
    previous sample() divided by the elapsed time. A jump beyond
    teleportDistance in one frame is a cut, not movement, and reports
    zero velocity while re-seeding the tracking.

    Call sample(elapsed) once per frame before the position is read.
**/
class DerivedVelocityProvider implements IFmodPositionProvider {
    /** Jumps larger than this in one frame count as a cut. Must be > 0. **/
    public var teleportDistance:Float;

    var sampleX:Void->Float;
    var sampleY:Void->Float;
    var x:Float = 0;
    var y:Float = 0;
    var velX:Float = 0;
    var velY:Float = 0;
    var lastX:Float = 0;
    var lastY:Float = 0;
    var hasLast:Bool = false;

    public function new(sampleX:Void->Float, sampleY:Void->Float, teleportDistance:Float) {
        this.sampleX = sampleX;
        this.sampleY = sampleY;
        this.teleportDistance = teleportDistance;
    }

    /** Reads the current position and derives the velocity from the previous one. **/
    public function sample(elapsed:Float):Void {
        x = sampleX();
        y = sampleY();
        var dx = x - lastX;
        var dy = y - lastY;
        if (hasLast && elapsed > 0 && dx * dx + dy * dy <= teleportDistance * teleportDistance) {
            velX = dx / elapsed;
            velY = dy / elapsed;
        } else {
            velX = 0;
            velY = 0;
        }
        lastX = x;
        lastY = y;
        hasLast = true;
    }

    /** Forgets the previous position, so the next sample reads as a cut. **/
    public function reset():Void {
        hasLast = false;
    }

    public function fmodX():Float return x;
    public function fmodY():Float return y;
    public function fmodVelocityX():Float return velX;
    public function fmodVelocityY():Float return velY;
}
