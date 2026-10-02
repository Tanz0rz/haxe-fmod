package openfl.utils;

// The project assets by path. A path with null bytes is listed with no
// file behind it.
class Assets {
	public static var files:Map<String, haxe.io.Bytes> = new Map();

	public static function exists(path:String):Bool {
		return files.exists(path);
	}

	public static function getBytes(path:String):haxe.io.Bytes {
		return files.get(path);
	}
}
