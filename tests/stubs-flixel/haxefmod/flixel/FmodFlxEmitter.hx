package haxefmod.flixel;

// Stands in for the real emitter file, which needs the whole engine
class FlxObjectPositionProvider implements haxefmod.runtime.IFmodPositionProvider {
	public function new(o:flixel.FlxObject) {}

	public function fmodX() return 0.0;

	public function fmodY() return 0.0;

	public function fmodVelocityX() return 0.0;

	public function fmodVelocityY() return 0.0;
}
