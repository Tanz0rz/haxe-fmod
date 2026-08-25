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
		testCustomHdllMarkerCheck();

		Sys.println('  $passed passed, $failed failed');
		return failed;
	}

	/**
	 * A project-local custom hdll is trusted only while its version marker
	 * matches the SDK in use. A leftover build for a different FMOD version
	 * must fall back to the pre-built hdll instead of shipping next to
	 * mismatched runtime libraries.
	 */
	static function testCustomHdllMarkerCheck():Void {
		var base = "tests/fixtures/tmp-hdll-marker";
		var projectDir = '$base/project';
		var sdkDir = '$base/sdk';
		var savedSdk = Sys.getEnv("FMOD_SDK");

		function write(path:String, content:String):Void {
			var dir = haxe.io.Path.directory(path);
			if (!sys.FileSystem.exists(dir)) sys.FileSystem.createDirectory(dir);
			sys.io.File.saveContent(path, content);
		}

		write('$sdkDir/api/core/inc/fmod_common.h',
			"#define FMOD_VERSION    0x00020312\n");
		write('$projectDir/.haxefmod/hlaxe_fmod.version', "0x00020312\n");
		Sys.putEnv("FMOD_SDK", sdkDir);

		assert(PostBuild.customHdllMatchesSdk(projectDir),
			"matching marker keeps the custom hdll");

		write('$projectDir/.haxefmod/hlaxe_fmod.version', "0x00020233\n");
		assert(!PostBuild.customHdllMatchesSdk(projectDir),
			"stale marker rejects the custom hdll");

		// Marker markers written by older build-hdll versions may be absent:
		// the old trust-the-custom-hdll behavior applies then
		sys.FileSystem.deleteFile('$projectDir/.haxefmod/hlaxe_fmod.version');
		assert(PostBuild.customHdllMatchesSdk(projectDir),
			"missing marker keeps the old trusting behavior");

		// An unreadable SDK cannot veto the custom hdll
		write('$projectDir/.haxefmod/hlaxe_fmod.version', "0x00020233\n");
		Sys.putEnv("FMOD_SDK", '$base/nowhere');
		assert(PostBuild.customHdllMatchesSdk(projectDir),
			"missing SDK header keeps the custom hdll");

		if (savedSdk != null) {
			Sys.putEnv("FMOD_SDK", savedSdk);
		} else {
			Sys.putEnv("FMOD_SDK", null);
		}
		function rmTree(path:String):Void {
			if (!sys.FileSystem.exists(path)) return;
			for (name in sys.FileSystem.readDirectory(path)) {
				var child = '$path/$name';
				if (sys.FileSystem.isDirectory(child)) rmTree(child) else sys.FileSystem.deleteFile(child);
			}
			sys.FileSystem.deleteDirectory(path);
		}
		rmTree(base);
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
