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
		testScanHdllSource();
		testProjectHdllSourceWarning();
		testSourceHashParity();
		testClearExecstack();
		testSdkPackageDetection();
		testStage();
		testToolExits();
		testBuildCheckOldWebSdk();
		testRpathToRewrite();
		testProjectPath();

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
		// nothing here must ever end up tracked
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

	static function testScanHdllSource():Void {
		var dir = "tests/.tmp/hdll-source";
		sys.FileSystem.createDirectory(dir);
		var stamped = haxe.io.Path.join([dir, "stamped.hdll"]);
		sys.io.File.saveContent(stamped, "\x7fELF junk hlaxe_fmod_abi=14\x00 more hlaxe_fmod_src=0123abcdef\x00 tail");
		assert(PostBuild.scanHdllSource(stamped) == "0123abcdef", "the source marker of an hdll is read up to its end");
		var unknown = haxe.io.Path.join([dir, "unknown.hdll"]);
		sys.io.File.saveContent(unknown, "junk hlaxe_fmod_src=unknown\x00");
		assert(PostBuild.scanHdllSource(unknown) == null, "an hdll built without the hash reads as no marker");
		var bare = haxe.io.Path.join([dir, "bare.hdll"]);
		sys.io.File.saveContent(bare, "junk with no marker");
		assert(PostBuild.scanHdllSource(bare) == null, "an hdll with no source marker reads as none");
	}

	static function testProjectHdllSourceWarning():Void {
		var warn = "was built from other shim sources";
		function run(marker:String):String {
			var p = new sys.io.Process("haxe", ["-cp", ".", "-cp", "tests", "--run", "PostBuildHdllWarn", "tests/.tmp/hdll-warn-" + marker, marker]);
			var out = p.stdout.readAll().toString();
			p.close();
			return out;
		}
		assert(run("deadbeef").indexOf(warn) != -1, "a project hdll built from other shim sources warns");
		assert(run("current").indexOf(warn) == -1, "a project hdll built from these shim sources does not warn");
	}

	// build-hdll and the package check must compute one hash. The exit
	// code and stderr reach the message, so a missing python3 reads as such.
	static function testSourceHashParity():Void {
		var process = new sys.io.Process("python3", ["ci/hlaxe-src-hash.py", "."]);
		var scripted = StringTools.trim(process.stdout.readAll().toString());
		var err = StringTools.trim(process.stderr.readAll().toString());
		var code = process.exitCode();
		process.close();
		var built = haxefmod.tools.BuildHdll.sourceHash(".");
		assert(code == 0 && scripted.length == 40 && scripted == built,
			'source hash parity: exit=$code script=$scripted tool=$built stderr=$err');

		// A Windows checkout carries CRLF, and both sides must hash it the same
		// Gitignored scratch space, like every other temporary tree here
		var crlfRoot = "tests/.tmp/crlf-root";
		for (rel in ["native/hlaxe/hlaxe_fmod.c", "native/manifest/studio_api.txt"].concat(
				[for (f in sys.FileSystem.readDirectory("native/shared")) if (StringTools.endsWith(f, ".h")) "native/shared/" + f])) {
			var target = '$crlfRoot/$rel';
			var dir = haxe.io.Path.directory(target);
			if (!sys.FileSystem.exists(dir)) sys.FileSystem.createDirectory(dir);
			// A working tree that already holds CRLF is folded first
			var content = StringTools.replace(sys.io.File.getContent(rel), "\r\n", "\n");
			sys.io.File.saveContent(target, StringTools.replace(content, "\n", "\r\n"));
		}
		var crlfBuilt = haxefmod.tools.BuildHdll.sourceHash(crlfRoot);
		var crlfProcess = new sys.io.Process("python3", ["ci/hlaxe-src-hash.py", crlfRoot]);
		var crlfScripted = StringTools.trim(crlfProcess.stdout.readAll().toString());
		var crlfErr = StringTools.trim(crlfProcess.stderr.readAll().toString());
		var crlfCode = crlfProcess.exitCode();
		crlfProcess.close();
		assert(crlfCode == 0 && crlfBuilt == built && crlfScripted == built,
			'source hash ignores line endings: exit=$crlfCode tool=$crlfBuilt script=$crlfScripted lf=$built stderr=$crlfErr');
		removeTree(crlfRoot);
	}

	/**
	 * A project-local custom hdll is trusted only while its version marker
	 * matches the SDK in use. A leftover build for a different FMOD version
	 * must fall back to the pre-built hdll instead of shipping next to
	 * mismatched runtime libraries.
	 */
	static function testCustomHdllMarkerCheck():Void {
		var base = "tests/.tmp/hdll-marker";
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

		// A custom hdll can lack the marker. The build then trusts the custom hdll
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

	static function removeTree(path:String):Void {
		if (!sys.FileSystem.exists(path)) return;
		if (sys.FileSystem.isDirectory(path)) {
			for (f in sys.FileSystem.readDirectory(path)) removeTree('$path/$f');
			sys.FileSystem.deleteDirectory(path);
		} else {
			sys.FileSystem.deleteFile(path);
		}
	}

	static function assert(condition:Bool, name:String):Void {
		if (condition) passed++ else {
			failed++;
			Sys.println('  FAIL: $name');
		}
	}

	static function testProjectPath():Void {
		assert(PostBuild.projectPath("/home/me/game", "sdk") == "/home/me/game/sdk", "a relative SDK path resolves from the project");
		assert(PostBuild.projectPath("/home/me/game", "/opt/sdk") == "/opt/sdk", "an absolute SDK path stays as it is");
		assert(PostBuild.projectPath("C:\\game", "D:\\fmod") == "D:\\fmod", "a drive path stays as it is");
		assert(PostBuild.projectPath("C:\\game", "\\fmod\\sdk") == "\\fmod\\sdk", "a Windows path from the drive root stays as it is");
	}

	static function testRpathToRewrite():Void {
		// otool -l output for a fat binary lists the load commands per slice
		var slice = "Load command 14\n          cmd LC_RPATH\n      cmdsize 72\n         path /Users/runner/work/fmod-sdk/api/core/lib (offset 12)\n"
			+ "Load command 15\n          cmd LC_RPATH\n      cmdsize 80\n         path /Users/runner/work/fmod-sdk/api/studio/lib (offset 12)\n"
			+ "Load command 16\n          cmd LC_LOAD_DYLIB\n      cmdsize 48\n         name @rpath/libfmod.dylib (offset 24)\n";
		var fat = "KhaPlatformer (architecture x86_64):\n" + slice + "KhaPlatformer (architecture arm64):\n" + slice;
		check("the SDK search path is the one rewritten", PostBuild.rpathToRewrite(fat, "/Users/runner/work/fmod-sdk") == "/Users/runner/work/fmod-sdk/api/core/lib");
		check("a trailing slash on the SDK path is fine", PostBuild.rpathToRewrite(fat, "/Users/runner/work/fmod-sdk/") == "/Users/runner/work/fmod-sdk/api/core/lib");
		check("a path shaped like an SDK lib directory serves without the SDK prefix", PostBuild.rpathToRewrite(fat, "/opt/other-sdk") == "/Users/runner/work/fmod-sdk/api/core/lib");
		var foreign = "          cmd LC_RPATH\n      cmdsize 40\n         path /opt/homebrew/lib (offset 12)\n";
		check("a search path the game needs is never rewritten", PostBuild.rpathToRewrite(foreign, "/opt/other-sdk") == null);
		var short = "          cmd LC_RPATH\n      cmdsize 24\n         path /usr/lib (offset 12)\n";
		check("a path shorter than the new value is left alone", PostBuild.rpathToRewrite(short, "/opt/sdk") == null);
		var shortSdk = "          cmd LC_RPATH\n      cmdsize 32\n         path /f/api/core/lib (offset 12)\n";
		check("a short SDK search path is left alone", PostBuild.rpathToRewrite(shortSdk, "/f") == null);
		check("a short SDK-shaped search path is left alone", PostBuild.rpathToRewrite(shortSdk, "/other") == null);
		var relative = "          cmd LC_RPATH\n      cmdsize 40\n         path @loader_path/../Frameworks (offset 12)\n";
		check("a relative search path is left alone", PostBuild.rpathToRewrite(relative, "/opt/sdk") == null);
		var present = slice + "          cmd LC_RPATH\n      cmdsize 32\n         path @executable_path (offset 12)\n";
		check("an executable that has the search path needs no rewrite", PostBuild.rpathToRewrite(present, "/Users/runner/work/fmod-sdk") == null);
		var dylibOnly = "          cmd LC_LOAD_DYLIB\n      cmdsize 48\n         name @rpath/libfmod.dylib (offset 24)\n         path /not/an/rpath/entry (offset 12)\n";
		check("a path line outside an LC_RPATH command is skipped", PostBuild.rpathToRewrite(dylibOnly, "/opt/sdk") == null);
		check("no load commands gives null", PostBuild.rpathToRewrite("", "/opt/sdk") == null);
		var mixed = "          cmd LC_RPATH\n      cmdsize 40\n         path /usr/local/lib/elsewhere (offset 12)\n" + slice;
		check("the SDK search path wins over an earlier absolute one", PostBuild.rpathToRewrite(mixed, "/Users/runner/work/fmod-sdk") == "/Users/runner/work/fmod-sdk/api/core/lib");
		var otherSdk = "          cmd LC_RPATH\n      cmdsize 40\n         path /opt/old-fmod/api/core/lib (offset 12)\n" + slice;
		check("the SDK search path wins over another SDK-shaped one", PostBuild.rpathToRewrite(otherSdk, "/Users/runner/work/fmod-sdk") == "/Users/runner/work/fmod-sdk/api/core/lib");
		check("a trailing slash still prefers the SDK over another SDK-shaped one", PostBuild.rpathToRewrite(otherSdk, "/Users/runner/work/fmod-sdk/") == "/Users/runner/work/fmod-sdk/api/core/lib");
		check("a trailing slash on the SDK path still prefers the SDK", PostBuild.rpathToRewrite(mixed, "/Users/runner/work/fmod-sdk/") == "/Users/runner/work/fmod-sdk/api/core/lib");
	}

	static function testRunShContent():Void {
		// Expected strings use double quotes: Haxe double-quoted strings do
		// not interpolate, so the shell $ tokens stay literal
		var script = PostBuild.runShContent("My Game");
		assert(StringTools.startsWith(script, "#!/bin/bash\n"), "run.sh shebang");
		assert(script.indexOf("export LD_LIBRARY_PATH=\"$(pwd):$LD_LIBRARY_PATH\"") >= 0, "run.sh library path");
		// The exe invocation is quoted, so a name with spaces launches
		assert(script.indexOf("\"./My Game\" \"$@\"") >= 0, "run.sh quoted exe invocation");
		assert(script.indexOf("\nexec \"./My Game\"") >= 0, "run.sh execs the game so the launcher pid is the game");
		assert(script.indexOf("cd \"$(dirname \"$0\")\"") >= 0, "run.sh cd to script dir");

		var mac = PostBuild.runShContent("game.hl", true, true);
		check("mac launcher runs the bytecode through hl", mac.indexOf('hl "./game.hl"') != -1);
		check("mac launcher sets DYLD_LIBRARY_PATH", mac.indexOf("export DYLD_LIBRARY_PATH") != -1 && mac.indexOf("export LD_LIBRARY_PATH") == -1);
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
	 * api/core/inc headers as the desktop one. A header check therefore
	 * passes on both. A native build got as far as copying a library that
	 * was never there. The core library is what actually separates them.
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

		// The per-platform core library path, the file the package check
		// looks for
		assert(PostBuild.nativeCoreLib("mac").join("/") == "api/core/lib/libfmod.dylib", "mac core library path");
		assert(PostBuild.nativeCoreLib("windows").join("/") == "api/core/lib/x64/fmod.dll", "windows core library path");
		assert(PostBuild.nativeCoreLib("linux").join("/") == "api/core/lib/x86_64/libfmod.so", "linux core library path");
	}

	/**
	 * stage() copies into the directory it is given with no lime layout
	 * involved. A HashLink VM output (bytecode, no executable) gets a
	 * launcher that runs the bytecode through hl. The web trio includes
	 * jaxe.js, which lime bundles on its own.
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

		// Library side: version marker, the manifest header, a pre-built
		// hdll carrying the matching ABI marker, jaxe.js
		write('$libRoot/fmod_expected_version', "0x00020312\n");
		write('$libRoot/native/manifest/studio_api.txt', "# abi-version: 13\n");
		write('$libRoot/templates/bin/hl/Linux64/hlaxe_fmod.hdll', "hdll bytes hlaxe_fmod_abi=13");
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
			&& sys.io.File.getContent('$out/hlaxe_fmod.hdll') == "hdll bytes hlaxe_fmod_abi=13");
		check("stage clears the executable stack flag",
			sys.io.File.getBytes('$out/libfmod.so.14.12').getInt32(124) & 1 == 0);
		var runSh = '$out/run.sh';
		check("stage writes an hl launcher for a bytecode build", sys.FileSystem.exists(runSh)
			&& sys.io.File.getContent(runSh).indexOf('hl "./main.hl"') != -1);
		// A stale native build and a Windows launcher in the same directory
		// never displace the bytecode
		write('$out/game', "stale native build");
		Sys.command("chmod", ["+x", '$out/game']);
		write('$out/run.cmd', "@echo off");
		sys.FileSystem.deleteFile(runSh);
		PostBuild.stage("linux", "hl", libRoot, projectDir, out);
		check("stage keeps the bytecode launcher over a stale executable", sys.FileSystem.exists(runSh)
			&& sys.io.File.getContent(runSh).indexOf('hl "./main.hl"') != -1);

		// A project-local custom hdll wins when its marker matches the SDK
		write('$projectDir/.haxefmod/hlaxe_fmod.hdll', "custom hdll hlaxe_fmod_abi=13");
		write('$projectDir/.haxefmod/hlaxe_fmod.version', "0x00020312\n");
		PostBuild.stage("linux", "hl", libRoot, projectDir, out);
		check("stage prefers the custom hdll",
			sys.io.File.getContent('$out/hlaxe_fmod.hdll') == "custom hdll hlaxe_fmod_abi=13");

		// cpp target: libraries only, no hdll, and the directory is created
		var cppOut = '$projectDir/build/cpp';
		PostBuild.stage("linux", "cpp", libRoot, projectDir, cppOut);
		check("stage creates the output directory", sys.FileSystem.isDirectory(cppOut));
		check("stage cpp copies libfmod.so", sys.FileSystem.exists('$cppOut/libfmod.so'));
		check("stage cpp skips the hdll", !sys.FileSystem.exists('$cppOut/hlaxe_fmod.hdll'));
		check("stage cpp writes no launcher without an executable", !sys.FileSystem.exists('$cppOut/run.sh'));
		// A data file without the executable bit is never taken for the game
		write('$cppOut/notes', "a data file");
		PostBuild.stage("linux", "cpp", libRoot, projectDir, cppOut);
		check("stage cpp skips a file without the executable bit", !sys.FileSystem.exists('$cppOut/run.sh'));
		write('$cppOut/game', "native build");
		Sys.command("chmod", ["+x", '$cppOut/game']);
		PostBuild.stage("linux", "cpp", libRoot, projectDir, cppOut);
		check("stage cpp launches the executable", sys.FileSystem.exists('$cppOut/run.sh')
			&& sys.io.File.getContent('$cppOut/run.sh').indexOf('"./game"') != -1);
		// FMOD's libraries can carry the executable bit. A versioned one is
		// never taken for a game whose file name has a dot in it.
		var dotted = '$projectDir/build/dotted';
		PostBuild.stage("linux", "cpp", libRoot, projectDir, dotted);
		for (name in sys.FileSystem.readDirectory(dotted)) Sys.command("chmod", ["+x", '$dotted/$name']);
		write('$dotted/tank.x86_64', "native build");
		Sys.command("chmod", ["+x", '$dotted/tank.x86_64']);
		PostBuild.stage("linux", "cpp", libRoot, projectDir, dotted);
		check("stage skips the versioned libraries when it looks for the game", sys.FileSystem.exists('$dotted/run.sh')
			&& sys.io.File.getContent('$dotted/run.sh').indexOf('"./tank.x86_64"') != -1);

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

	// Runs a CLI command in a child process the way haxelib runs it. The
	// caller's directory is the last argument. Sys.exit ends only the
	// child. The env entries hold for the child's lifetime.
	static function runTool(args:Array<String>, cwd:String, env:Map<String, String>):{code:Int, out:String} {
		var saved = new Map<String, Null<String>>();
		for (key in env.keys()) {
			saved.set(key, Sys.getEnv(key));
			Sys.putEnv(key, env.get(key));
		}
		var p = new sys.io.Process("haxe", ["-cp", ".", "--run", "haxefmod.tools.Run"].concat(args).concat([cwd]));
		var out = p.stdout.readAll().toString();
		var err = p.stderr.readAll().toString();
		var code = p.exitCode();
		p.close();
		for (key in saved.keys()) Sys.putEnv(key, saved.get(key));
		return {code: code, out: out + err};
	}

	static function writeFile(path:String, content:String):Void {
		var dir = haxe.io.Path.directory(path);
		if (!sys.FileSystem.exists(dir)) sys.FileSystem.createDirectory(dir);
		sys.io.File.saveContent(path, content);
	}

	static function fakeDesktopSdk(dir:String, version:String, libs:Bool):String {
		writeFile('$dir/api/core/inc/fmod_common.h', '#define FMOD_VERSION $version\n');
		writeFile('$dir/api/core/inc/fmod.h', "");
		if (libs) {
			for (lib in [["core", "libfmod"], ["studio", "libfmodstudio"]]) {
				writeFile('$dir/api/${lib[0]}/lib/x86_64/${lib[1]}.so', "so");
				writeFile('$dir/api/${lib[0]}/lib/${lib[1]}.dylib', "dylib");
			}
		}
		return dir;
	}

	// The FMOD 2.02 HTML5 package keeps fmodstudio.js outside
	// lib/wasm. The build check named it a desktop package.
	static function testBuildCheckOldWebSdk():Void {
		var dir = "tests/.tmp/buildcheck-web";
		writeFile('$dir/sdk/api/core/inc/fmod_common.h', "#define FMOD_VERSION 0x00020233\n");
		writeFile('$dir/sdk/api/studio/lib/upstream/wasm/fmodstudio.js', "");
		writeFile('$dir/Main.hx', "class Main { static function main() {} }\n");
		var saved = Sys.getEnv("FMOD_SDK_WEB");
		Sys.putEnv("FMOD_SDK_WEB", sys.FileSystem.fullPath('$dir/sdk'));
		var p = new sys.io.Process("haxe", ["-cp", ".", "-cp", dir, "-main", "Main", "-js", '$dir/out.js', "--no-output",
			"--macro", "haxefmod.tools.BuildCheck.verify()"]);
		var out = p.stdout.readAll().toString() + p.stderr.readAll().toString();
		var code = p.exitCode();
		p.close();
		Sys.putEnv("FMOD_SDK_WEB", saved);
		assert(code != 0 && out.indexOf("version mismatch") != -1 && out.indexOf("does not point at the HTML5") == -1,
			"an HTML5 package of another FMOD version reports the version");

		// lime ignores the postbuild exit code, so the compile refuses
		// what the stage refuses
		var noHeader = '$dir/no-header';
		writeFile('$noHeader/api/studio/lib/wasm/fmodstudio.js', "");
		Sys.putEnv("FMOD_SDK_WEB", sys.FileSystem.fullPath(noHeader));
		p = new sys.io.Process("haxe", ["-cp", ".", "-cp", dir, "-main", "Main", "-js", '$dir/out.js', "--no-output",
			"--macro", "haxefmod.tools.BuildCheck.verify()"]);
		out = p.stdout.readAll().toString() + p.stderr.readAll().toString();
		code = p.exitCode();
		p.close();
		Sys.putEnv("FMOD_SDK_WEB", saved);
		assert(code != 0 && out.indexOf("fmod_common.h") != -1, "a web package without its headers stops the compile");

		// The stage copies the wasm too, and lime ships the placeholder when it is missing
		var noWasm = '$dir/no-wasm';
		writeFile('$noWasm/api/core/inc/fmod_common.h',
			"#define FMOD_VERSION " + StringTools.trim(sys.io.File.getContent("fmod_expected_version")) + "\n");
		writeFile('$noWasm/api/studio/lib/wasm/fmodstudio.js', "");
		Sys.putEnv("FMOD_SDK_WEB", sys.FileSystem.fullPath(noWasm));
		p = new sys.io.Process("haxe", ["-cp", ".", "-cp", dir, "-main", "Main", "-js", '$dir/out.js', "--no-output",
			"--macro", "haxefmod.tools.BuildCheck.verify()"]);
		out = p.stdout.readAll().toString() + p.stderr.readAll().toString();
		code = p.exitCode();
		p.close();
		Sys.putEnv("FMOD_SDK_WEB", saved);
		assert(code != 0 && out.indexOf("fmodstudio.wasm") != -1, "a web package without its wasm stops the compile");
	}

	/**
	 * The exit codes and refusals of stage, check, build-hdll and an
	 * unknown command. A refusal that exits 0 ships a build that fails
	 * at startup, and a doctor that passes a broken setup hides it.
	 */
	static function testToolExits():Void {
		if (Sys.systemName() == "Windows") return;
		var base = sys.FileSystem.absolutePath("tests/.tmp/tools");
		removeTree(base);
		var expected = StringTools.trim(sys.io.File.getContent("fmod_expected_version"));
		var abi = PostBuild.expectedAbiVersion(".");
		var platform = Sys.systemName() == "Mac" ? "mac" : "linux";
		var sdk = fakeDesktopSdk('$base/sdk', expected, true);
		var oldSdk = fakeDesktopSdk('$base/old-sdk', "0x00010101", false);
		// With its libraries, so only the version check can stop a stage
		var oldSdkLibs = fakeDesktopSdk('$base/old-sdk-libs', "0x00010101", true);
		var plain = '$base/plain';
		sys.FileSystem.createDirectory(plain);
		// A project hdll whose marker names the expected version
		var stale = '$base/stale-marker';
		writeFile('$stale/.haxefmod/hlaxe_fmod.hdll', 'custom hlaxe_fmod_abi=$abi\x00');
		writeFile('$stale/.haxefmod/hlaxe_fmod.version', expected);
		var oldAbi = '$base/old-abi';
		writeFile('$oldAbi/.haxefmod/hlaxe_fmod.hdll', 'custom hlaxe_fmod_abi=${abi + 100}\x00');
		writeFile('$oldAbi/.haxefmod/hlaxe_fmod.version', expected);

		var out = '$base/out-unknown';
		var r = runTool(["stage", platform, "HL", out], plain, ["FMOD_SDK" => sdk]);
		check("stage refuses an unknown target", r.code == 1 && !sys.FileSystem.exists(out));

		out = '$base/out-old';
		r = runTool(["stage", platform, "hl", out], plain, ["FMOD_SDK" => oldSdkLibs]);
		check("stage refuses an SDK the pre-built hdll was not built for",
			r.code == 1 && r.out.indexOf("ERROR: FMOD SDK version mismatch") != -1 && !sys.FileSystem.exists('$out/hlaxe_fmod.hdll'));

		out = '$base/out-stale';
		r = runTool(["stage", platform, "hl", out], stale, ["FMOD_SDK" => oldSdkLibs]);
		check("stage refuses a project hdll built for another SDK", r.code == 1 && !sys.FileSystem.exists('$out/hlaxe_fmod.hdll'));

		out = '$base/out-abi';
		r = runTool(["stage", platform, "hl", out], oldAbi, ["FMOD_SDK" => sdk]);
		check("stage refuses an hdll of another binding ABI",
			r.code == 1 && r.out.indexOf("binding version mismatch") != -1 && !sys.FileSystem.exists('$out/hlaxe_fmod.hdll'));

		var web = '$base/old-web';
		writeFile('$web/api/core/inc/fmod_common.h', "#define FMOD_VERSION 0x00010101\n");
		writeFile('$web/api/studio/lib/wasm/fmodstudio.js', "// engine");
		writeFile('$web/api/studio/lib/wasm/fmodstudio.wasm', "wasm");
		r = runTool(["stage", "html5", "html5", '$base/out-web'], plain, ["FMOD_SDK_WEB" => web]);
		check("stage refuses a web SDK of another version", r.code == 1 && r.out.indexOf("web SDK version mismatch") != -1);

		// The FMOD 2.02 HTML5 package keeps fmodstudio.js outside lib/wasm
		var oldLayout = '$base/old-layout-web';
		writeFile('$oldLayout/api/core/inc/fmod_common.h', "#define FMOD_VERSION 0x00020233\n");
		writeFile('$oldLayout/api/studio/lib/upstream/wasm/fmodstudio.js', "// engine");
		r = runTool(["stage", "html5", "html5", '$base/out-old-layout'], plain, ["FMOD_SDK_WEB" => oldLayout]);
		check("stage names the version of an HTML5 package of another FMOD version", r.code == 1
			&& r.out.indexOf("web SDK version mismatch") != -1 && r.out.indexOf("does not point at the HTML5") == -1);

		// The same packages in FMOD_SDK are no desktop packages, whatever their version
		r = runTool(["stage", platform, "hl", '$base/out-web-native'], plain, ["FMOD_SDK" => web]);
		check("stage names an HTML5 package in FMOD_SDK before its version", r.code == 1
			&& r.out.indexOf("points at the HTML5 FMOD Engine package") != -1 && r.out.indexOf("version mismatch") == -1);
		r = runTool(["stage", platform, "hl", '$base/out-old-layout-native'], plain, ["FMOD_SDK" => oldLayout]);
		check("stage names an HTML5 package of another FMOD version in FMOD_SDK", r.code == 1
			&& r.out.indexOf("points at the HTML5 FMOD Engine package") != -1 && r.out.indexOf("version mismatch") == -1);

		// An SDK folder with no libraries in it stages nothing, so the
		// command fails instead of reporting success
		var empty = fakeDesktopSdk('$base/empty-sdk', expected, false);
		sys.FileSystem.createDirectory('$empty/api/core/lib/x86_64');
		sys.FileSystem.createDirectory('$empty/api/studio/lib/x86_64');
		if (platform == "linux") {
			r = runTool(["stage", "linux", "cpp", '$base/out-empty'], plain, ["FMOD_SDK" => empty]);
			check("stage fails on an SDK folder with no libraries", r.code == 1 && r.out.indexOf("no file named libfmod.so") != -1);
		}
		var noWasm = '$base/no-wasm';
		writeFile('$noWasm/api/core/inc/fmod_common.h', '#define FMOD_VERSION $expected\n');
		writeFile('$noWasm/api/studio/lib/wasm/fmodstudio.js', "// engine");
		r = runTool(["stage", "html5", "html5", '$base/out-no-wasm'], plain, ["FMOD_SDK_WEB" => noWasm]);
		check("stage fails on a web SDK without the wasm", r.code == 1 && r.out.indexOf("fmodstudio.wasm not found") != -1);

		// The doctor fails what the build would refuse
		r = runTool(["check"], plain, ["FMOD_SDK" => oldSdk, "FMOD_SDK_WEB" => ""]);
		check("check fails a wrong SDK version", r.code == 1 && r.out.indexOf("[FAIL] FMOD version") != -1);
		check("check fails missing runtime libraries", r.out.indexOf('[FAIL] $platform runtime libraries') != -1);
		check("check fails a pre-built hdll for another SDK", r.out.indexOf("[FAIL] Pre-built hdll compatible with SDK") != -1);
		r = runTool(["check"], plain, ["FMOD_SDK" => sdk, "FMOD_SDK_WEB" => web]);
		check("check fails a web SDK of another version", r.code == 1 && r.out.indexOf("[FAIL] FMOD web SDK version") != -1);

		// The stage refuses a web package without its headers, so the doctor does too
		var noHeader = '$base/no-header-web';
		writeFile('$noHeader/api/studio/lib/wasm/fmodstudio.js', "// engine");
		writeFile('$noHeader/api/studio/lib/wasm/fmodstudio.wasm', "wasm");
		r = runTool(["check"], plain, ["FMOD_SDK" => sdk, "FMOD_SDK_WEB" => noHeader]);
		check("check fails a web SDK without its headers", r.code == 1 && r.out.indexOf("[FAIL] FMOD web SDK headers present") != -1);
		r = runTool(["check"], oldAbi, ["FMOD_SDK" => sdk, "FMOD_SDK_WEB" => ""]);
		check("check fails an hdll of another binding ABI", r.code == 1 && r.out.indexOf("[FAIL] hlaxe_fmod.hdll binding ABI") != -1);

		// A failed compile keeps the old hdll's marker, so the build
		// never takes the old hdll for one built against this SDK
		var bin = '$base/bin';
		for (name in ["gcc", "cc"]) {
			writeFile('$bin/$name', '#!/bin/sh\n[ "$$1" = "--version" ] && exit 0\nexit 1\n');
			Sys.command("chmod", ["+x", '$bin/$name']);
		}
		writeFile('$base/hl/include/hl.h', "");
		var project = '$base/rebuild';
		writeFile('$project/.haxefmod/hlaxe_fmod.hdll', "old hdll");
		writeFile('$project/.haxefmod/hlaxe_fmod.version', "0x00010101");
		r = runTool(["build-hdll"], project, ["FMOD_SDK" => sdk, "HASHLINK_DIR" => '$base/hl', "PATH" => bin + ":" + Sys.getEnv("PATH")]);
		check("build-hdll fails when the compiler fails and keeps the old marker",
			r.code == 1 && StringTools.trim(sys.io.File.getContent('$project/.haxefmod/hlaxe_fmod.version')) == "0x00010101");

		// lime's and openfl's project templates build into Export, and the
		// postbuild must find the build there (Linux paths are case sensitive)
		var goodWeb = '$base/good-web';
		writeFile('$goodWeb/api/core/inc/fmod_common.h', '#define FMOD_VERSION $expected\n');
		writeFile('$goodWeb/api/studio/lib/wasm/fmodstudio.js', "// engine");
		writeFile('$goodWeb/api/studio/lib/wasm/fmodstudio.wasm', "wasm");
		var limeExport = '$base/lime-export';
		sys.FileSystem.createDirectory('$limeExport/Export/html5/bin');
		r = runTool(["postbuild", "html5", "html5", "x"], limeExport, ["FMOD_SDK_WEB" => goodWeb]);
		check("postbuild replaces the placeholders in a lime build under Export",
			sys.FileSystem.exists('$limeExport/Export/html5/bin/lib/fmodstudio.wasm'));

		var limeDefault = '$base/lime-default';
		sys.FileSystem.createDirectory('$limeDefault/bin/html5/bin');
		r = runTool(["postbuild", "html5", "html5", "x"], limeDefault, ["FMOD_SDK_WEB" => goodWeb]);
		check("postbuild replaces the placeholders in a lime build under lime's default bin",
			sys.FileSystem.exists('$limeDefault/bin/html5/bin/lib/fmodstudio.wasm'));

		// A stale build under lime's default bin never takes the files a
		// build under export or Export needs
		for (folder in ["export", "Export"]) {
			var limeBoth = '$base/lime-both-$folder';
			sys.FileSystem.createDirectory('$limeBoth/$folder/html5/bin');
			sys.FileSystem.createDirectory('$limeBoth/bin/html5/bin');
			r = runTool(["postbuild", "html5", "html5", "x"], limeBoth, ["FMOD_SDK_WEB" => goodWeb]);
			check('postbuild prefers $folder over a stale build under bin',
				sys.FileSystem.exists('$limeBoth/$folder/html5/bin/lib/fmodstudio.wasm') && !sys.FileSystem.exists('$limeBoth/bin/html5/bin/lib'));
		}

		// A file system that folds case answers to both names with one folder
		var limeCase = '$base/lime-case';
		sys.FileSystem.createDirectory('$limeCase/Export/html5/bin');
		if (!sys.FileSystem.exists('$limeCase/export')) {
			sys.FileSystem.createDirectory('$limeCase/export/html5/bin');
			r = runTool(["postbuild", "html5", "html5", "x"], limeCase, ["FMOD_SDK_WEB" => goodWeb]);
			check("postbuild prefers export over Export",
				sys.FileSystem.exists('$limeCase/export/html5/bin/lib/fmodstudio.wasm') && !sys.FileSystem.exists('$limeCase/Export/html5/bin/lib'));
		}

		// The compile check reads an SDK path relative to the project, so the
		// postbuild and the stage read it from there too
		var relProject = '$base/relative';
		writeFile('$relProject/websdk/api/core/inc/fmod_common.h', '#define FMOD_VERSION $expected\n');
		writeFile('$relProject/websdk/api/studio/lib/wasm/fmodstudio.js', "// engine");
		writeFile('$relProject/websdk/api/studio/lib/wasm/fmodstudio.wasm', "wasm");
		sys.FileSystem.createDirectory('$relProject/export/html5/bin');
		r = runTool(["postbuild", "html5", "html5", "x"], relProject, ["FMOD_SDK_WEB" => "websdk"]);
		check("postbuild reads a relative FMOD_SDK_WEB from the project",
			r.code == 0 && sys.FileSystem.exists('$relProject/export/html5/bin/lib/fmodstudio.wasm'));

		var relNative = '$base/relative-native';
		fakeDesktopSdk('$relNative/sdk', expected, true);
		r = runTool(["stage", platform, "cpp", '$base/out-relative-native'], relNative, ["FMOD_SDK" => "sdk"]);
		check("stage reads a relative FMOD_SDK from the project",
			r.code == 0 && sys.FileSystem.exists('$base/out-relative-native/' + (platform == "mac" ? "libfmod.dylib" : "libfmod.so")));

		// lime ignores the postbuild exit code, so the compile refuses a
		// desktop package without the studio library the postbuild copies
		var noStudio = fakeDesktopSdk('$base/no-studio', expected, true);
		sys.FileSystem.deleteFile('$noStudio/api/studio/lib/x86_64/libfmodstudio.so');
		sys.FileSystem.deleteFile('$noStudio/api/studio/lib/libfmodstudio.dylib');
		var mainDir = '$base/main';
		writeFile('$mainDir/Main.hx', "class Main { static function main() {} }\n");
		var savedSdk = Sys.getEnv("FMOD_SDK");
		Sys.putEnv("FMOD_SDK", noStudio);
		var p = new sys.io.Process("haxe", ["-cp", ".", "-cp", mainDir, "-main", "Main", "-hl", '$mainDir/out.hl', "--no-output",
			"--macro", "haxefmod.tools.BuildCheck.verify()"]);
		var compileOut = p.stdout.readAll().toString() + p.stderr.readAll().toString();
		var compileCode = p.exitCode();
		p.close();
		check("a desktop package without the studio library stops the compile",
			compileCode != 0 && compileOut.indexOf("libfmodstudio") != -1);

		// The compile trusts a custom hdll without a version marker next to
		// an SDK of another version, so the stage does too
		var unmarked = '$base/unmarked';
		writeFile('$unmarked/Main.hx', "class Main { static function main() {} }\n");
		writeFile('$unmarked/.haxefmod/hlaxe_fmod.hdll', 'custom hlaxe_fmod_abi=$abi\x00');
		Sys.putEnv("FMOD_SDK", oldSdkLibs);
		p = new sys.io.Process("haxe", ["--cwd", unmarked, "-cp", sys.FileSystem.absolutePath("."), "-main", "Main", "-hl", "out.hl",
			"--no-output", "--macro", "haxefmod.tools.BuildCheck.verify()"]);
		compileOut = p.stdout.readAll().toString() + p.stderr.readAll().toString();
		compileCode = p.exitCode();
		p.close();
		r = runTool(["stage", platform, "hl", '$base/out-unmarked'], unmarked, ["FMOD_SDK" => oldSdkLibs]);
		check("a custom hdll without a marker gets the same verdict from the compile and the stage",
			r.code == 0 && compileCode == 0 && sys.FileSystem.exists('$base/out-unmarked/hlaxe_fmod.hdll'));
		Sys.putEnv("FMOD_SDK", savedSdk);

		var orphan = '$base/orphan-marker';
		writeFile('$orphan/.haxefmod/hlaxe_fmod.version', "0x00010101");
		r = runTool(["stage", platform, "hl", '$base/out-orphan'], orphan, ["FMOD_SDK" => oldSdkLibs]);
		check("stage ignores a version marker without its hdll",
			r.code == 1 && r.out.indexOf("ERROR: FMOD SDK version mismatch") != -1 && !sys.FileSystem.exists('$base/out-orphan/hlaxe_fmod.hdll'));

		r = runTool(["no-such-command"], plain, []);
		check("an unknown command exits nonzero", r.code == 1 && r.out.indexOf("Unknown command") != -1);
		removeTree(base);
	}
}
