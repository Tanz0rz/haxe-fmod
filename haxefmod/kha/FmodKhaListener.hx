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
        Jumps larger than this in one frame count as a cut, not movement,
        and push zero velocity instead of a doppler spike. Default 500.
    **/
    public var teleportDistance:Float = 500;

    var tracker:ListenerTracker;
    var provider:DerivedVelocityProvider;

    /**
        @param target the body to follow
        @param listenerIndex which listener to drive (0 unless using
        multiple listeners via StudioSystem.setNumListeners)
    **/
    public function new(?target:KhaBody, listenerIndex:Int = 0) {
        tracker = new ListenerTracker(null, listenerIndex);
        if (target != null) setTarget(target);
        FmodKhaUpdater.add(this);
    }

    /** Follows the body's midpoint. **/
    public function setTarget(target:KhaBody):Void {
        provider = new KhaBodyPositionProvider(target, teleportDistance);
        tracker.provider = provider;
    }

    /** Follows the position the two functions return, such as a camera center. **/
    public function setSampler(sampleX:Void->Float, sampleY:Void->Float):Void {
        provider = new DerivedVelocityProvider(sampleX, sampleY, teleportDistance);
        tracker.provider = provider;
    }

    /**
        Restarts velocity tracking after a camera cut the game performed
        itself, so the jump reads as a teleport rather than movement.
    **/
    public function resetMotion():Void {
        if (provider != null) provider.reset();
    }

    public function dispose():Void {
        FmodKhaUpdater.remove(this);
    }

    public function tick(dt:Float):Void {
        if (provider == null) return;
        provider.teleportDistance = teleportDistance;
        provider.sample(dt);
        tracker.update();
    }
}
