package haxefmod.runtime;

/**
 * Anything that can feed a 2D position (and optionally velocity, in game
 * units per second) to an attached event instance or listener. The flixel
 * components adapt FlxObject/FlxCamera to this; games can implement it
 * directly for custom engines.
 */
interface IFmodPositionProvider {
    function fmodX():Float;
    function fmodY():Float;
    function fmodVelocityX():Float;
    function fmodVelocityY():Float;
}
