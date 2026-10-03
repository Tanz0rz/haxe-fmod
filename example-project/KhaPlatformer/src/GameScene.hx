package;

import kha.graphics2.Graphics;

/** One screen of the game. update() runs every frame, render() every drawn frame. */
interface GameScene {
    function create():Void;
    function update(dt:Float):Void;
    function render(g2:Graphics):Void;
    function dispose():Void;
}
