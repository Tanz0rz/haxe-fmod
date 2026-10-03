package flixel;

class FlxBasic {
	public var exists:Bool = true;

	public function new() {}

	public function update(elapsed:Float):Void {}

	public function destroy():Void {
		exists = false;
	}
}
