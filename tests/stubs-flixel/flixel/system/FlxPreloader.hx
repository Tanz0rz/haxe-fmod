package flixel.system;

// The FlxPreloader members FmodFlxPreloader uses. frame() is
// FlxBasePreloader.onEnterFrame with no minimum display time: update,
// then destroy once _loaded is set.
class FlxPreloader {
	var _loaded:Bool = false;

	public var children:Array<Dynamic> = [];
	public var visualsDrawn:Int = 0;
	public var finished:Bool = false;

	public function new() {}

	function create():Void {
		visualsDrawn++;
	}

	function update(percent:Float):Void {}

	public function onLoaded():Void {
		_loaded = true;
	}

	function destroy():Void {}

	public function addChild(child:Dynamic):Dynamic {
		children.push(child);
		return child;
	}

	public function removeChild(child:Dynamic):Dynamic {
		children.remove(child);
		return child;
	}

	public function frame():Void {
		if (finished) return;
		update(1);
		if (_loaded) {
			destroy();
			finished = true;
		}
	}
}
