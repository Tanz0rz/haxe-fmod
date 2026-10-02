package flixel;

// The slice of flixel that FmodFlxUtilities and FmodFlxUpdater touch.
// A state is a string here, and switchState records each request.
class Signal {
	public var handlers:Array<Void->Void> = [];

	var pendingRemove:Array<Void->Void> = [];
	var dispatching = false;

	public function new() {}

	public function add(h:Void->Void) {
		for (x in handlers) if (Reflect.compareMethods(x, h)) return;
		handlers.push(h);
	}

	public function has(h:Void->Void):Bool {
		for (x in handlers) if (Reflect.compareMethods(x, h)) return true;
		return false;
	}

	public function remove(h:Void->Void) {
		if (dispatching) {
			pendingRemove.push(h);
			return;
		}
		for (x in handlers.copy()) if (Reflect.compareMethods(x, h)) handlers.remove(x);
	}

	public function dispatch() {
		dispatching = true;
		var i = 0;
		// Flixel still runs a listener removed during the dispatch. The
		// removal lands when the dispatch ends.
		while (i < handlers.length) {
			handlers[i]();
			i++;
		}
		dispatching = false;
		for (p in pendingRemove) remove(p);
		pendingRemove = [];
	}
}

class Signals {
	public var preUpdate = new Signal();
	public var postUpdate = new Signal();

	public function new() {}
}

class FlxG {
	public static var signals = new Signals();
	public static var switches:Array<String> = [];
	public static var state:String = "Start";
	public static var camera:FlxCamera = null;

	public static function switchState(s:String) {
		switches.push(s);
	}

	public static function frame() {
		signals.preUpdate.dispatch();
		signals.postUpdate.dispatch();
	}
}
