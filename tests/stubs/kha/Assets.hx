package kha;

/** kha.Assets.blobs, looked up by the name khamake gives a file. */
class Assets {
	public static var blobs:BlobList = new BlobList();
}

class BlobList {
	public var entries:Map<String, Blob> = new Map();

	public function new() {}

	public function get(name:String):Blob {
		return entries.get(name);
	}
}
