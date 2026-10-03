package flixel.math;

// The FlxRect fields FmodFlxParameterTrigger reads
class FlxRect {
	public var x:Float;
	public var y:Float;
	public var width:Float;
	public var height:Float;

	function new(x:Float, y:Float, width:Float, height:Float) {
		this.x = x;
		this.y = y;
		this.width = width;
		this.height = height;
	}

	public static function get(x:Float = 0, y:Float = 0, width:Float = 0, height:Float = 0):FlxRect {
		return new FlxRect(x, y, width, height);
	}
}
