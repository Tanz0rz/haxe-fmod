package h2d;

/**
 * The h2d.Object fields the Heaps components read. getBounds returns
 * scene-space bounds. Width and height stand in for the drawable extent.
 */
class Object {
	public var x:Float = 0;
	public var y:Float = 0;
	public var width:Float = 0;
	public var height:Float = 0;

	public function new() {}

	public function getBounds(?relativeTo:Object, ?out:h2d.col.Bounds):h2d.col.Bounds {
		return new h2d.col.Bounds(x, y, x + width, y + height);
	}
}
