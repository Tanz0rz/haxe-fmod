package lime.utils;

// Lime's asset library: whether an asset is preloaded, the default
// library once registered, and the fetch of an asset that is not
class Assets {
	public static var libraryRegistered:Bool = false;
	public static var remote:Map<String, PendingBytes> = new Map();

	public static function isLocal(id:String, ?type:AssetType):Bool {
		return !remote.exists(id);
	}

	public static function getLibrary(name:String):Dynamic {
		return libraryRegistered ? {} : null;
	}

	public static function loadBytes(id:String):PendingBytes {
		return remote.get(id);
	}
}

// The slice of lime.app.Future the preloader chains
class PendingBytes {
	var completeHandler:haxe.io.Bytes->Void;
	var errorHandler:Dynamic->Void;

	public function new() {}

	public function onComplete(handler:haxe.io.Bytes->Void):PendingBytes {
		completeHandler = handler;
		return this;
	}

	public function onError(handler:Dynamic->Void):PendingBytes {
		errorHandler = handler;
		return this;
	}

	public function complete(bytes:haxe.io.Bytes):Void {
		completeHandler(bytes);
	}

	public function fail(error:Dynamic):Void {
		errorHandler(error);
	}
}
