package haxefmod.kha;

import haxefmod.kha.FmodKhaEmitter.KhaBody;
import haxefmod.kha.FmodKhaEmitter.KhaBodyPositionProvider;
import haxefmod.kha.FmodKhaUpdater.IKhaTicker;
import haxefmod.runtime.ListenerTracker;

/**
    Positions an FMOD listener every frame.

    With a body, the listener follows its midpoint (typical for a player
    character). With a pair of sampler functions, it follows whatever
    they return, such as the center of the game's camera view.

    Velocity is derived from the movement between frames, so authored
    doppler responds to listener movement. The maxAttachedVelocity
    setting caps it for very fast movers. The listener registers with
    FmodKhaUpdater and needs no per-frame call of its own.

        var listener = new FmodKhaListener(player);
**/
class FmodKhaListener implements IKhaTicker {
    /**
        Jumps larger than this in one frame count as a cut. A cut pushes
        zero velocity instead of a doppler spike. 0 means auto: 500 units,
        the same default the Heaps listener uses for an object. Kha has no
        camera to measure a view width from.
    **/
    public var teleportDistance:Float = 0;

    static inline var AUTO_TELEPORT_DISTANCE:Float = 500;

    inline function effectiveTeleportDistance():Float {
        return teleportDistance > 0 ? teleportDistance : AUTO_TELEPORT_DISTANCE;
    }

    var tracker:ListenerTracker;
    var provider:DerivedVelocityProvider;

    /**
        @param target The body to follow.
        @param listenerIndex The listener to drive. Leave it at 0 unless the
        game uses multiple listeners through StudioSystem.setNumListeners.
    **/
    public function new(?target:KhaBody, listenerIndex:Int = 0) {
        tracker = new ListenerTracker(null, listenerIndex);
        if (target != null) setTarget(target);
        FmodKhaUpdater.add(this);
    }

    /** Follows the body's midpoint. **/
    public function setTarget(target:KhaBody):Void {
        provider = new KhaBodyPositionProvider(target, effectiveTeleportDistance());
        tracker.provider = provider;
    }

    /** Follows the position the two functions return, such as a camera center. **/
    public function setSampler(sampleX:Void->Float, sampleY:Void->Float):Void {
        provider = new DerivedVelocityProvider(sampleX, sampleY, effectiveTeleportDistance());
        tracker.provider = provider;
    }

    /**
        Restarts velocity tracking after a camera cut the game performed
        itself. The jump then reads as a teleport with zero velocity.
    **/
    public function resetMotion():Void {
        if (provider != null) provider.reset();
    }

    /** Unregisters the listener from FmodKhaUpdater. **/
    public function dispose():Void {
        FmodKhaUpdater.remove(this);
    }

    /** Samples the followed position and pushes it to the listener. **/
    public function tick(dt:Float):Void {
        if (provider == null) return;
        provider.teleportDistance = effectiveTeleportDistance();
        provider.sample(dt);
        tracker.update();
    }
}
