package openfl;

class Lib {
	public static var current:Current = new Current();
}

class Current {
	public var stage:Stage = new Stage();

	public function new() {}
}

class Stage {
	public var stageWidth:Int = 640;
	public var stageHeight:Int = 480;

	public function new() {}
}
