package;

import h2d.Scene;

/** One screen of the game. create() builds into the scene, update() runs every frame. */
interface GameScene {
    function create(s2d:Scene):Void;
    function update(dt:Float):Void;
    function dispose():Void;
}
