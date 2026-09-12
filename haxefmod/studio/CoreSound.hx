package haxefmod.studio;

/**
 * The core sound type lives in haxefmod.core as Sound. This name stays
 * for one release so existing code keeps compiling, with a warning at
 * every use.
 */
@:deprecated("haxefmod.studio.CoreSound moved to haxefmod.core.Sound, import that instead")
typedef CoreSound = haxefmod.core.Sound;
