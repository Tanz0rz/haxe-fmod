package flixel;

// The camera fields FmodFlxListener reads. viewWidth is width / zoom.
// That matches flixel 6 at an initial zoom of 1.
class FlxCamera {
	public var scroll:{x:Float, y:Float} = {x: 0.0, y: 0.0};
	public var width:Int;
	public var height:Int;
	public var zoom:Float;
	public var viewWidth(get, never):Float;

	public function new(width:Int, height:Int, zoom:Float) {
		this.width = width;
		this.height = height;
		this.zoom = zoom;
	}

	function get_viewWidth():Float {
		return width / zoom;
	}
}
