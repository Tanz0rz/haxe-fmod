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
    of the scene's camera view. That suits games where the camera is the
    player's ear.

    Velocity is derived from the movement between frames, so authored
    doppler responds to listener movement. The maxAttachedVelocity
    setting caps it for very fast movers. The listener registers with
    FmodHeapsUpdater and needs no per-frame call of its own.

        var listener = new FmodHeapsListener(player);
**/
class FmodHeapsListener implements IHeapsTicker {
    /**
        Jumps larger than this in one frame count as a cut. A cut pushes
        zero velocity instead of a doppler spike. 0 means auto: one view
        width in scene-follow mode, 500 units for an object.
    **/
    public var teleportDistance:Float = 0;

    /** The auto teleport distance for an object, in scene units. **/
    static inline var AUTO_TELEPORT_DISTANCE:Float = 500;

    var tracker:ListenerTracker;
    var provider:DerivedVelocityProvider;
    var scene:Scene;

    /**
        @param target The object to follow. Omit it to set one later with
        setTarget. The listener stays idle until then.
        @param listenerIndex The listener to drive. Leave it at 0 unless the
        game uses multiple listeners through StudioSystem.setNumListeners.
    **/
    public function new(?target:Object, listenerIndex:Int = 0) {
        tracker = new ListenerTracker(null, listenerIndex);
        if (target != null) setTarget(target);
        FmodHeapsUpdater.add(this);
    }

    /** Follows the center of the object's bounds. **/
    public function setTarget(target:Object):Void {
        scene = null;
        // No target leaves the listener idle, like the constructor does
        provider = target == null ? null : new H2dObjectPositionProvider(target);
        tracker.provider = provider;
    }

    /** Follows the center of the scene's camera view. **/
    public function setScene(scene:Scene):Void {
        this.scene = scene;
        provider = scene == null ? null : new DerivedVelocityProvider(viewCenterX, viewCenterY, 0);
        tracker.provider = provider;
    }

    /**
        Restarts velocity tracking after a camera cut the game performed
        itself. The jump then reads as a teleport with zero velocity.
    **/
    public function resetMotion():Void {
        if (provider != null) provider.reset();
    }

    /** Unregisters the listener from FmodHeapsUpdater. **/
    public function dispose():Void {
        FmodHeapsUpdater.remove(this);
    }

    // The world point under the viewport center, from the camera's own
    // fields. The camera matrix is rebuilt at render time, so a move
    // this frame counts at once here. The camera maps a world offset
    // through scale then rotation, and this is the inverse of that.
    function viewCenterX():Float {
        var camera = scene.camera;
        var dx = camera.viewportWidth * (0.5 - camera.anchorX);
        var dy = camera.viewportHeight * (0.5 - camera.anchorY);
        return camera.x + (dx * Math.cos(camera.rotation) + dy * Math.sin(camera.rotation)) / camera.scaleX;
    }

    function viewCenterY():Float {
        var camera = scene.camera;
        var dx = camera.viewportWidth * (0.5 - camera.anchorX);
        var dy = camera.viewportHeight * (0.5 - camera.anchorY);
        return camera.y + (dy * Math.cos(camera.rotation) - dx * Math.sin(camera.rotation)) / camera.scaleY;
    }

    /** Samples the followed position and pushes it to the listener. **/
    @:dox(hide)
    public function tick(dt:Float):Void {
        if (provider == null) return;
        if (scene != null) {
            provider.teleportDistance = teleportDistance > 0 ? teleportDistance : scene.camera.viewportWidth / scene.camera.scaleX;
        } else {
            provider.teleportDistance = teleportDistance > 0 ? teleportDistance : AUTO_TELEPORT_DISTANCE;
        }
        provider.sample(dt);
        tracker.update();
    }
}
