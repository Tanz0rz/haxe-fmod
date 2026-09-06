package haxefmod.heaps;

import h2d.Object;
import h2d.Scene;
import haxefmod.heaps.FmodHeapsEmitter.H2dObjectPositionProvider;
import haxefmod.heaps.FmodHeapsUpdater.IHeapsTicker;
import haxefmod.runtime.ListenerTracker;

/**
    Positions an FMOD listener every frame.

    With a target object, the listener follows the center of its bounds
    (typical for a player character). With a scene, it follows the center
    of the scene's camera view, which suits games where the camera is the
    player's ear.

    Velocity is derived from the movement between frames, so authored
    doppler responds to listener movement. The maxAttachedVelocity
    setting caps it for very fast movers. The listener registers with
    FmodHeapsUpdater and needs no per-frame call of its own.

        var listener = new FmodHeapsListener(player);
**/
class FmodHeapsListener implements IHeapsTicker {
    /**
        Jumps larger than this in one frame count as a cut, not movement,
        and push zero velocity instead of a doppler spike. 0 means auto:
        one view width in scene-follow mode, 500 units for an object.
    **/
    public var teleportDistance:Float = 0;

    var tracker:ListenerTracker;
    var provider:DerivedVelocityProvider;
    var scene:Scene;

    /**
        @param target the object to follow
        @param listenerIndex which listener to drive (0 unless using
        multiple listeners via StudioSystem.setNumListeners)
    **/
    public function new(?target:Object, listenerIndex:Int = 0) {
        tracker = new ListenerTracker(null, listenerIndex);
        if (target != null) setTarget(target);
        FmodHeapsUpdater.add(this);
    }

    /** Follows the center of the object's bounds. **/
    public function setTarget(target:Object):Void {
        scene = null;
        provider = new H2dObjectPositionProvider(target);
        tracker.provider = provider;
    }

    /** Follows the center of the scene's camera view. **/
    public function setScene(scene:Scene):Void {
        this.scene = scene;
        provider = new DerivedVelocityProvider(viewCenterX, viewCenterY, 0);
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
        FmodHeapsUpdater.remove(this);
    }

    function viewCenterX():Float {
        var camera = scene.camera;
        return camera.x + (0.5 - camera.anchorX) * scene.width / camera.scaleX;
    }

    function viewCenterY():Float {
        var camera = scene.camera;
        return camera.y + (0.5 - camera.anchorY) * scene.height / camera.scaleY;
    }

    public function tick(dt:Float):Void {
        if (provider == null) return;
        if (scene != null) {
            provider.teleportDistance = teleportDistance > 0 ? teleportDistance : scene.width / scene.camera.scaleX;
        } else if (teleportDistance > 0) {
            provider.teleportDistance = teleportDistance;
        }
        provider.sample(dt);
        tracker.update();
    }
}
