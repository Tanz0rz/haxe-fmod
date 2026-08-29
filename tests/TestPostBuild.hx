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
		testClearExecstack();
		testSdkPackageDetection();
		testStage();

		Sys.println('  $passed passed, $failed failed');
		return failed;
	}

	// Builds a minimal little endian ELF64 in memory: the file header, one
	// PT_LOAD program header, and one PT_GNU_STACK header with the given
	// flags. Layout matches what the patcher reads.
	static function fakeElf(stackFlags:Int, ?includeStack:Bool = true):haxe.io.Bytes {
		var phnum = includeStack ? 2 : 1;
		var bytes = haxe.io.Bytes.alloc(64 + phnum * 56);
		bytes.set(0, 0x7F);
		bytes.set(1, 0x45); // E
		bytes.set(2, 0x4C); // L
		bytes.set(3, 0x46); // F
		bytes.set(4, 2); // ELF64
		bytes.set(5, 1); // little endian
		bytes.setInt32(0x20, 64); // e_phoff (low half, high stays 0)
		bytes.setUInt16(0x36, 56); // e_phentsize
		bytes.setUInt16(0x38, phnum); // e_phnum
		bytes.setInt32(64, 1); // phdr[0] PT_LOAD
		bytes.setInt32(68, 5); // phdr[0] flags R+X
		if (includeStack) {
			bytes.setInt32(120, 0x6474E551); // phdr[1] PT_GNU_STACK
			bytes.setInt32(124, stackFlags);
		}
		return bytes;
	}

	static function writeTemp(name:String, bytes:haxe.io.Bytes):String {
		// Gitignored scratch space: the runner's cwd is the repo root and
		// nothing here may ever end up tracked
		var dir = "tests/.tmp";
		if (!sys.FileSystem.exists(dir)) sys.FileSystem.createDirectory(dir);
		var path = dir + "/" + name;
		sys.io.File.saveBytes(path, bytes);
		return path;
	}

	/**
	 * The executable-stack flag is cleared by rewriting the PT_GNU_STACK
	 * program header in place, with no external tools. Anything that does
	 * not parse as a little endian ELF64 with an executable stack entry
	 * must come back byte-identical.
	 */
	static function testClearExecstack():Void {
		// The flagged library gets exactly one bit cleared
		var flagged = fakeElf(7); // RWE
		var path = writeTemp("libfmod.so", flagged);
		check("execstack cleared reports change", PostBuild.clearExecstackFile(path));
		var after = sys.io.File.getBytes(path);
		check("execstack flag cleared", after.getInt32(124) == 6);
		var identicalElsewhere = true;
		for (i in 0...after.length) {
			if (i >= 124 && i < 128) continue;
			if (after.get(i) != flagged.get(i)) identicalElsewhere = false;
		}
		check("only the flags field changed", identicalElsewhere);
		check("second pass reports no change", !PostBuild.clearExecstackFile(path));

		// An already-clear stack entry is left alone
		var clear = writeTemp("libfmod-clear.so", fakeElf(6));
		check("clear flag untouched", !PostBuild.clearExecstackFile(clear));

		// No PT_GNU_STACK entry at all
		var noStack = writeTemp("libfmod-nostack.so", fakeElf(7, false));
		check("missing stack entry untouched", !PostBuild.clearExecstackFile(noStack));

		// Not an ELF file
		var junk = haxe.io.Bytes.alloc(200);
		for (i in 0...200) junk.set(i, i & 0xFF);
		var junkPath = writeTemp("libfmod-junk.so", junk);
		check("non-elf untouched", !PostBuild.clearExecstackFile(junkPath));
		check("non-elf bytes identical", sys.io.File.getBytes(junkPath).compare(junk) == 0);

		// ELF32 is not FMOD's layout and is skipped
		var elf32 = fakeElf(7);
		elf32.set(4, 1);
		check("elf32 untouched", !PostBuild.clearExecstackFile(writeTemp("libfmod-32.so", elf32)));

		// A header pointing past the end of the file is refused
		var truncated = fakeElf(7);
		truncated.setInt32(0x20, 4096);
		check("out of bounds phoff untouched", !PostBuild.clearExecstackFile(writeTemp("libfmod-trunc.so", truncated)));
	}

	static function check(name:String, pass:Bool):Void {
		if (pass) passed++ else { failed++; Sys.println('  FAIL: $name'); }
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

		var mac = PostBuild.runShContent("game.hl", true, true);
		check("mac launcher runs the bytecode through hl", mac.indexOf('hl "./game.hl"') != -1);
		check("mac launcher sets DYLD_LIBRARY_PATH", mac.indexOf("DYLD_LIBRARY_PATH") != -1 && mac.indexOf("LD_LIBRARY_PATH=\"") == -1);
		var cmd = PostBuild.runCmdContent("game.hl");
		check("windows launcher changes to its own directory", cmd.indexOf('cd /d "%~dp0"') != -1);
		check("windows launcher runs the bytecode through hl", cmd.indexOf('hl "game.hl" %*') != -1);
		check("windows launcher uses CRLF", cmd.indexOf("\r\n") != -1);
		var plain = PostBuild.runShContent("Game");
		assert(plain.indexOf("\"./Game\" \"$@\"") >= 0, "run.sh plain name quoted too");
	}

	static function makeDir(path:String):Void {
		if (!sys.FileSystem.exists(path)) sys.FileSystem.createDirectory(path);
	}

	static function touch(dir:String, name:String):Void {
		var parts = dir.split("/");
		var built = "";
		for (part in parts) {
			built = built == "" ? part : built + "/" + part;
			makeDir(built);
		}
		sys.io.File.saveContent(dir + "/" + name, "");
	}

	/**
	 * Telling the two FMOD packages apart. The HTML5 package ships the same
	 * api/core/inc headers as the desktop one, so a header check passes on
	 * both and a native build got as far as copying a library that was
	 * never there. The core library is what actually separates them.
	 */
	static function testSdkPackageDetection():Void {
		var root = "tests/.tmp/sdk";
		var web = root + "/web";
		var desktop = root + "/desktop";

		// Both packages carry the headers, and only the web one carries the
		// wasm build of the studio library
		touch(web + "/api/core/inc", "fmod_common.h");
		touch(web + "/api/studio/lib/wasm", "fmodstudio.js");
		touch(web + "/api/core/lib/js", "fmod.js");
		touch(desktop + "/api/core/inc", "fmod_common.h");
		touch(desktop + "/api/core/lib", "libfmod.dylib");
		touch(desktop + "/api/core/lib/x64", "fmod.dll");
		touch(desktop + "/api/core/lib/x86_64", "libfmod.so");

		assert(PostBuild.looksLikeWebSdk(web), "html5 package detected");
		assert(!PostBuild.looksLikeWebSdk(desktop), "desktop package not mistaken for html5");
		assert(!PostBuild.looksLikeWebSdk(root + "/missing"), "absent path is not the html5 package");

		// The header both packages share cannot separate them
		assert(sys.FileSystem.exists(web + "/api/core/inc/fmod_common.h"),
			"html5 package ships the core headers too");

		for (platform in ["mac", "windows", "linux"]) {
			var marker = haxe.io.Path.join([desktop].concat(PostBuild.nativeCoreLib(platform)));
			assert(sys.FileSystem.exists(marker), 'desktop package has the $platform core library');
			var missing = haxe.io.Path.join([web].concat(PostBuild.nativeCoreLib(platform)));
			assert(!sys.FileSystem.exists(missing), 'html5 package has no $platform core library');
		}
	}

	/**
	 * stage() copies into the directory it is given with no lime layout
	 * involved. A HashLink VM output (bytecode, no executable) gets a
	 * launcher that runs the bytecode through hl, and the web trio
	 * includes jaxe.js, which lime bundles on its own.
	 */
	static function testStage():Void {
		// cp -P and test -L run here, and the symlink layout is the Linux
		// SDK's. The Windows runner never executes this file.
		if (Sys.systemName() == "Windows") return;
		var base = "tests/.tmp/stage";
		var libRoot = '$base/lib';
		var projectDir = '$base/project';
		var sdk = '$base/sdk';
		var savedSdk = Sys.getEnv("FMOD_SDK");
		var savedWeb = Sys.getEnv("FMOD_SDK_WEB");

		function write(path:String, content:String):Void {
			var dir = haxe.io.Path.directory(path);
			if (!sys.FileSystem.exists(dir)) sys.FileSystem.createDirectory(dir);
			sys.io.File.saveContent(path, content);
		}
		function writeBytes(path:String, bytes:haxe.io.Bytes):Void {
			var dir = haxe.io.Path.directory(path);
			if (!sys.FileSystem.exists(dir)) sys.FileSystem.createDirectory(dir);
			sys.io.File.saveBytes(path, bytes);
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

		// Library side: version marker, a pre-built hdll, jaxe.js
		write('$libRoot/fmod_expected_version', "0x00020312\n");
		write('$libRoot/templates/bin/hl/Linux64/hlaxe_fmod.hdll', "hdll bytes");
		write('$libRoot/native/jaxe/jaxe.js', "// jaxe");

		// Desktop SDK: header plus versioned .so files with the symlinks
		// FMOD ships, executable stack flag set like the real ones
		write('$sdk/api/core/inc/fmod_common.h', "#define FMOD_VERSION 0x00020312\n");
		var coreDir = '$sdk/api/core/lib/x86_64';
		var studioDir = '$sdk/api/studio/lib/x86_64';
		writeBytes('$coreDir/libfmod.so.14.12', fakeElf(7));
		writeBytes('$studioDir/libfmodstudio.so.14.12', fakeElf(7));
		Sys.command("ln", ["-s", "libfmod.so.14.12", '$coreDir/libfmod.so.14']);
		Sys.command("ln", ["-s", "libfmod.so.14", '$coreDir/libfmod.so']);
		Sys.command("ln", ["-s", "libfmodstudio.so.14.12", '$studioDir/libfmodstudio.so']);

		var out = '$projectDir/build/hl';
		write('$out/main.hl', "bytecode");
		Sys.putEnv("FMOD_SDK", sdk);
		PostBuild.stage("linux", "hl", libRoot, projectDir, out);

		check("stage copies libfmod.so", sys.FileSystem.exists('$out/libfmod.so'));
		check("stage copies libfmodstudio.so", sys.FileSystem.exists('$out/libfmodstudio.so'));
		check("stage copies the versioned library", sys.FileSystem.exists('$out/libfmod.so.14.12'));
		check("stage copies the pre-built hdll", sys.FileSystem.exists('$out/hlaxe_fmod.hdll')
			&& sys.io.File.getContent('$out/hlaxe_fmod.hdll') == "hdll bytes");
		check("stage clears the executable stack flag",
			sys.io.File.getBytes('$out/libfmod.so.14.12').getInt32(124) & 1 == 0);
		var runSh = '$out/run.sh';
		check("stage writes an hl launcher for a bytecode build", sys.FileSystem.exists(runSh)
			&& sys.io.File.getContent(runSh).indexOf('hl "./main.hl"') != -1);

		// A project-local custom hdll wins when its marker matches the SDK
		write('$projectDir/.haxefmod/hlaxe_fmod.hdll', "custom hdll");
		write('$projectDir/.haxefmod/hlaxe_fmod.version', "0x00020312\n");
		PostBuild.stage("linux", "hl", libRoot, projectDir, out);
		check("stage prefers the custom hdll",
			sys.io.File.getContent('$out/hlaxe_fmod.hdll') == "custom hdll");

		// cpp target: libraries only, no hdll, and the directory is created
		var cppOut = '$projectDir/build/cpp';
		PostBuild.stage("linux", "cpp", libRoot, projectDir, cppOut);
		check("stage creates the output directory", sys.FileSystem.isDirectory(cppOut));
		check("stage cpp copies libfmod.so", sys.FileSystem.exists('$cppOut/libfmod.so'));
		check("stage cpp skips the hdll", !sys.FileSystem.exists('$cppOut/hlaxe_fmod.hdll'));
		check("stage cpp writes no launcher without an executable", !sys.FileSystem.exists('$cppOut/run.sh'));

		// Web SDK: the engine pair plus jaxe.js land side by side
		var web = '$base/web';
		write('$web/api/core/inc/fmod_common.h', "#define FMOD_VERSION 0x00020312\n");
		write('$web/api/studio/lib/wasm/fmodstudio.js', "// engine");
		write('$web/api/studio/lib/wasm/fmodstudio.wasm', "wasm");
		var webOut = '$projectDir/build/html5/lib';
		Sys.putEnv("FMOD_SDK_WEB", web);
		PostBuild.stage("html5", "ignored", libRoot, projectDir, webOut);
		for (name in ["fmodstudio.js", "fmodstudio.wasm", "jaxe.js"]) {
			check('stage html5 copies $name', sys.FileSystem.exists('$webOut/$name'));
		}

		Sys.putEnv("FMOD_SDK", savedSdk);
		Sys.putEnv("FMOD_SDK_WEB", savedWeb);
		rmTree(base);
	}
}
