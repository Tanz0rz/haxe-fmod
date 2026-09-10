package haxefmod.flixel;

import flixel.FlxBasic;
import flixel.FlxG;
import flixel.FlxObject;
import haxefmod.flixel.FmodFlxEmitter.FlxObjectPositionProvider;
import haxefmod.runtime.ListenerTracker;

/**
    Positions an FMOD listener every frame.

    With a target, the listener follows the target's midpoint (typical for
    a player character). Without one, it follows the center of FlxG.camera.
    That suits games where the camera is the player's ear.

    Listener velocity is pushed along with the position. The velocity is
    the target's velocity, or the camera center's movement per second.
    Authored doppler therefore responds to listener movement. The
    maxAttachedVelocity setting caps it for very fast movers.

    Add it to the state so its update() runs:

        add(new FmodFlxListener(player));
**/
class FmodFlxListener extends FlxBasic {
    /**
        Camera jumps larger than this in one frame count as a cut. A cut
        pushes zero velocity instead of a doppler spike. 0 means auto: one
        camera width. Only applies in camera-follow mode.
    **/
    public var teleportDistance:Float = 0;

    var target:FlxObject;
    var tracker:ListenerTracker;
    var cameraProvider:DerivedVelocityProvider;

    /**
        @param target The object to follow. Omit to follow the camera center.
        @param listenerIndex The listener to drive. Leave it at 0 unless the
        game uses multiple listeners through StudioSystem.setNumListeners.
    **/
    public function new(?target:FlxObject, listenerIndex:Int = 0) {
        super();
        tracker = new ListenerTracker(null, listenerIndex);
        cameraProvider = new DerivedVelocityProvider(cameraX, cameraY, 0);
        setTarget(target);
        FmodFlxUpdater.init();
    }

    /** Retargets the listener. Pass nothing to fall back to the camera. **/
    public function setTarget(?target:FlxObject):Void {
        this.target = target;
        tracker.provider = target != null ? new FlxObjectPositionProvider(target) : cameraProvider;
        cameraProvider.reset();
    }

    /**
        Restarts velocity tracking after a camera cut the game performed
        itself. The jump then reads as a teleport with zero velocity. The
        automatic teleportDistance guard covers cuts without this call.
    **/
    public function resetMotion():Void {
        cameraProvider.reset();
    }

    static function cameraX():Float {
        var camera = FlxG.camera;
        return camera.scroll.x + camera.width / 2;
    }

    static function cameraY():Float {
        var camera = FlxG.camera;
        return camera.scroll.y + camera.height / 2;
    }

    /** Samples the camera when no target is set, then pushes the listener position. **/
    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        if (target == null) {
            var camera = FlxG.camera;
            if (camera == null) return;
            // The camera has no velocity of its own. Derive it from the
            // center's movement since the previous frame. A jump beyond the
            // teleport threshold is a cut: zero velocity, re-seed tracking.
            cameraProvider.teleportDistance = teleportDistance > 0 ? teleportDistance : camera.width;
            cameraProvider.sample(elapsed);
        }
        tracker.update();
    }
}
