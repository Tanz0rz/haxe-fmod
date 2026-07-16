package haxefmod.flixel;

import flixel.FlxBasic;
import flixel.FlxG;
import flixel.FlxObject;
import haxefmod.runtime.FmodRuntime;
import haxefmod.studio.StudioSystem;

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
    var listenerIndex:Int;
    var lastX:Float = 0;
    var lastY:Float = 0;
    var hasLast:Bool = false;

    /**
        @param target the object to follow. Omit to follow the camera center
        @param listenerIndex which listener to drive (0 unless using
        multiple listeners via StudioSystem.setNumListeners)
    **/
    public function new(?target:FlxObject, listenerIndex:Int = 0) {
        super();
        this.target = target;
        this.listenerIndex = listenerIndex;
    }

    /** Retargets the listener. Pass nothing to fall back to the camera. **/
    public function setTarget(?target:FlxObject):Void {
        this.target = target;
        hasLast = false;
    }

    /**
        Restarts velocity tracking after a camera cut the game performed
        itself, so the jump reads as a teleport rather than movement. The
        automatic teleportDistance guard covers cuts this is not called for.
    **/
    public function resetMotion():Void {
        hasLast = false;
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        var x:Float;
        var y:Float;
        var velX:Float;
        var velY:Float;
        if (target != null) {
            x = target.x + target.width / 2;
            y = target.y + target.height / 2;
            velX = target.velocity.x;
            velY = target.velocity.y;
        } else {
            var camera = FlxG.camera;
            if (camera == null) return;
            x = camera.scroll.x + camera.width / 2;
            y = camera.scroll.y + camera.height / 2;
            // The camera has no velocity of its own - derive it from the
            // center's movement since the previous frame. A jump beyond the
            // teleport threshold is a cut: zero velocity, re-seed tracking.
            var threshold = teleportDistance > 0 ? teleportDistance : camera.width;
            var dx = x - lastX;
            var dy = y - lastY;
            if (hasLast && elapsed > 0 && dx * dx + dy * dy <= threshold * threshold) {
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

        var settings = FmodRuntime.settings();
        var maxVelocity = settings != null ? settings.maxAttachedVelocity : 0.0;
        var scale = haxefmod.runtime.AttachedInstances.velocityScale(velX, velY, maxVelocity);
        StudioSystem.setListenerPosition2D(listenerIndex, x, y, velX * scale, velY * scale);
    }
}
