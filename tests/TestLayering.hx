package tests;

import sys.FileSystem;

/**
 * Guards the package layering rules by scanning source text.
 * The studio package references neither runtime nor any engine package.
 * The core package references neither runtime nor any engine package.
 * The runtime package references no engine package.
 * The engine packages are haxefmod.flixel, haxefmod.heaps and haxefmod.kha.
 * Imports alone are not enough to check. A fully-qualified name such as
 * haxefmod.runtime.Foo.bar() creates the same dependency without an import.
 */
class TestLayering {
	static var passed = 0;
	static var failed = 0;

	public static function run():Int {
		Sys.println("--- Layering ---");

		var engines = ["haxefmod.flixel", "haxefmod.heaps", "haxefmod.kha"];
		checkTree("haxefmod/studio", ["haxefmod.runtime"].concat(engines));
		checkTree("haxefmod/core", ["haxefmod.runtime"].concat(engines));
		checkTree("haxefmod/runtime", engines);

		Sys.println('  $passed passed, $failed failed');
		return failed;
	}

	static function assert(condition:Bool, name:String):Void {
		if (condition) passed++ else {
			failed++;
			Sys.println('  FAIL: $name');
		}
	}

	static function checkTree(dir:String, forbidden:Array<String>):Void {
		assert(FileSystem.exists(dir), '$dir exists (run tests from the repo root)');
		if (!FileSystem.exists(dir)) return;
		var files = collectHx(dir);
		// An empty list would pass every rule below without reading anything
		assert(files.length > 0, '$dir holds at least one .hx file');
		for (file in files) {
			var content = sys.io.File.getContent(file);
			for (needle in forbidden) {
				assert(content.indexOf(needle) < 0, '$file does not reference $needle');
			}
		}
	}

	static function collectHx(dir:String):Array<String> {
		var out = [];
		for (entry in FileSystem.readDirectory(dir)) {
			var path = '$dir/$entry';
			if (FileSystem.isDirectory(path)) {
				for (sub in collectHx(path)) out.push(sub);
			} else if (StringTools.endsWith(entry, ".hx")) {
				out.push(path);
			}
		}
		return out;
	}
}
