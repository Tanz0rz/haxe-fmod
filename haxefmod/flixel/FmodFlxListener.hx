package haxefmod.flixel;

import flixel.FlxBasic;
import flixel.FlxG;
import flixel.FlxObject;
import haxefmod.flixel.FmodFlxEmitter.FlxObjectPositionProvider;
import haxefmod.runtime.ListenerTracker;

/**
    Positions an FMOD listener every frame.

    With a target, the listener follows the target's midpoint (typical for
    a player character). Without one, it follows the center of FlxG.camera,
    which suits games where the camera is the player's ear.

    Listener velocity is pushed along with the position (the target's
    velocity, or the camera center's movement per second), so authored
    doppler responds to listener movement. The maxAttachedVelocity setting
    caps it for very fast movers.

    Add it to the state so its update() runs:

        add(new FmodFlxListener(player));
**/
class FmodFlxListener extends FlxBasic {
    /**
        Camera jumps larger than this (in one frame) count as a cut, not
        movement, and push zero velocity instead of a doppler spike.
        0 means auto: one camera width. Only applies in camera-follow mode.
    **/
    public var teleportDistance:Float = 0;

    var target:FlxObject;
    var tracker:ListenerTracker;
    var cameraProvider:DerivedVelocityProvider;

    /**
        @param target the object to follow. Omit to follow the camera center
        @param listenerIndex which listener to drive (0 unless using
        multiple listeners via StudioSystem.setNumListeners)
    **/
    public function new(?target:FlxObject, listenerIndex:Int = 0) {
        super();
        tracker = new ListenerTracker(null, listenerIndex);
        cameraProvider = new DerivedVelocityProvider(cameraX, cameraY, 0);
        setTarget(target);
    }

    /** Retargets the listener. Pass nothing to fall back to the camera. **/
    public function setTarget(?target:FlxObject):Void {
        this.target = target;
        tracker.provider = target != null ? new FlxObjectPositionProvider(target) : cameraProvider;
        cameraProvider.reset();
    }

    /**
        Restarts velocity tracking after a camera cut the game performed
        itself, so the jump reads as a teleport rather than movement. The
        automatic teleportDistance guard covers cuts this is not called for.
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

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        if (target == null) {
            var camera = FlxG.camera;
            if (camera == null) return;
            // The camera has no velocity of its own - derive it from the
            // center's movement since the previous frame. A jump beyond the
            // teleport threshold is a cut: zero velocity, re-seed tracking.
            cameraProvider.teleportDistance = teleportDistance > 0 ? teleportDistance : camera.width;
            cameraProvider.sample(elapsed);
        }
        tracker.update();
    }
}
