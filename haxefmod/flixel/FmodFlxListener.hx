package haxefmod.flixel;

import flixel.FlxBasic;
import flixel.FlxG;
import flixel.FlxObject;
import haxefmod.studio.StudioSystem;

/**
    Positions an FMOD listener every frame.

    With a target, the listener follows the target's midpoint (typical for
    a player character); without one, it follows the center of FlxG.camera,
    which suits games where the camera is the player's ear.

    Add it to the state so its update() runs:

        add(new FmodFlxListener(player));
**/
class FmodFlxListener extends FlxBasic {
    var target:FlxObject;
    var listenerIndex:Int;

    /**
        @param target the object to follow; omit to follow the camera center
        @param listenerIndex which listener to drive (0 unless using
        multiple listeners via StudioSystem.setNumListeners)
    **/
    public function new(?target:FlxObject, listenerIndex:Int = 0) {
        super();
        this.target = target;
        this.listenerIndex = listenerIndex;
    }

    /** Retargets the listener; pass nothing to fall back to the camera. **/
    public function setTarget(?target:FlxObject):Void {
        this.target = target;
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        var x:Float;
        var y:Float;
        if (target != null) {
            x = target.x + target.width / 2;
            y = target.y + target.height / 2;
        } else {
            var camera = FlxG.camera;
            if (camera == null) return;
            x = camera.scroll.x + camera.width / 2;
            y = camera.scroll.y + camera.height / 2;
        }
        StudioSystem.setListenerPosition2D(listenerIndex, x, y);
    }
}
