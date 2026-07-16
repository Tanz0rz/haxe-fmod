package tests;

import sys.FileSystem;

/**
 * Guards the package layering rules by scanning source text:
 *
 *   studio  - may not reference runtime or flixel
 *   core    - may not reference runtime or flixel
 *   runtime - may not reference flixel
 *
 * Imports alone are not enough to check because a fully-qualified name
 * (haxefmod.runtime.Foo.bar()) creates the same dependency without one.
 */
class TestLayering {
	static var passed = 0;
	static var failed = 0;

	public static function run():Int {
		Sys.println("--- Layering ---");

		checkTree("haxefmod/studio", ["haxefmod.runtime", "haxefmod.flixel"]);
		checkTree("haxefmod/core", ["haxefmod.runtime", "haxefmod.flixel"]);
		checkTree("haxefmod/runtime", ["haxefmod.flixel"]);

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
		for (file in collectHx(dir)) {
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
