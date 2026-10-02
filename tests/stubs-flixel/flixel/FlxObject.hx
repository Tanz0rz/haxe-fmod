package flixel;

// The FlxObject fields the flixel components read. A destroyed object
// nulls velocity, as flixel's does.
class FlxObject extends FlxBasic {
	public var x:Float = 0;
	public var y:Float = 0;
	public var width:Float = 0;
	public var height:Float = 0;
	public var velocity:{x:Float, y:Float} = {x: 0.0, y: 0.0};

	public function new(x:Float = 0, y:Float = 0, width:Float = 0, height:Float = 0) {
		super();
		this.x = x;
		this.y = y;
		this.width = width;
		this.height = height;
	}

	override public function destroy():Void {
		velocity = null;
		super.destroy();
	}
}
