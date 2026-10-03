package h2d.col;

/** The h2d.col.Bounds members the Heaps components read, with Heaps' width, height and fromValues. */
class Bounds {
	public var xMin:Float;
	public var yMin:Float;
	public var xMax:Float;
	public var yMax:Float;
	public var width(get, never):Float;
	public var height(get, never):Float;

	public function new(xMin:Float, yMin:Float, xMax:Float, yMax:Float) {
		this.xMin = xMin;
		this.yMin = yMin;
		this.xMax = xMax;
		this.yMax = yMax;
	}

	function get_width():Float return xMax - xMin;

	function get_height():Float return yMax - yMin;

	public static function fromValues(x:Float, y:Float, width:Float, height:Float):Bounds {
		return new Bounds(x, y, x + width, y + height);
	}
}
