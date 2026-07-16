package tests;

import haxefmod.tools.PostBuild;

/**
 * Unit tests for the pure content-building pieces of PostBuild (the file
 * copying itself only runs against real build output in CI).
 */
class TestPostBuild {
	static var passed = 0;
	static var failed = 0;

	public static function run():Int {
		Sys.println("--- PostBuild ---");

		testRunShContent();

		Sys.println('  $passed passed, $failed failed');
		return failed;
	}

	static function assert(condition:Bool, name:String):Void {
		if (condition) passed++ else {
			failed++;
			Sys.println('  FAIL: $name');
		}
	}

	static function testRunShContent():Void {
		// Expected strings use double quotes: Haxe double-quoted strings do
		// not interpolate, so the shell $ tokens stay literal
		var script = PostBuild.runShContent("My Game");
		assert(StringTools.startsWith(script, "#!/bin/bash\n"), "run.sh shebang");
		assert(script.indexOf("export LD_LIBRARY_PATH=\"$(pwd):$LD_LIBRARY_PATH\"") >= 0, "run.sh library path");
		// The exe invocation is quoted, so a name with spaces launches
		assert(script.indexOf("\"./My Game\" \"$@\"") >= 0, "run.sh quoted exe invocation");
		assert(script.indexOf("cd \"$(dirname \"$0\")\"") >= 0, "run.sh cd to script dir");

		var plain = PostBuild.runShContent("Game");
		assert(plain.indexOf("\"./Game\" \"$@\"") >= 0, "run.sh plain name quoted too");
	}
}
