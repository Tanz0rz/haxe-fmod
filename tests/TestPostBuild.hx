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
		var dir = "bin/test-postbuild";
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

		var plain = PostBuild.runShContent("Game");
		assert(plain.indexOf("\"./Game\" \"$@\"") >= 0, "run.sh plain name quoted too");
	}
}
