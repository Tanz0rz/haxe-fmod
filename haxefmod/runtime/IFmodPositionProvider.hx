package haxefmod.runtime;

/**
 * Anything that can feed a 2D position to an attached event instance or
 * listener. Velocity, in game units per second, is optional. The engine
 * components adapt their objects and cameras to this. Games can implement
 * it directly for custom engines.
 */
interface IFmodPositionProvider {
    /** The X position in game units. */
    function fmodX():Float;

    /** The Y position in game units. */
    function fmodY():Float;

    /** The X velocity in game units per second. */
    function fmodVelocityX():Float;

    /** The Y velocity in game units per second. */
    function fmodVelocityY():Float;
}
