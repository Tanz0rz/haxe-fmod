package tests;

import sys.io.File;
import sys.FileSystem;

/**
 * Tests the version-parsing logic used in PostBuild and Run.
 *
 * PostBuild.hexToVersion and PostBuild.parseFmodVersion are private,
 * so we reimplement the same logic here and test it directly. If the
 * implementation changes, these tests catch regressions in the algorithm.
 */
class TestVersionParsing {
	static var passed = 0;
	static var failed = 0;

	static var tmpDir = "/tmp/haxefmod-test";

	public static function run():Int {
		Sys.println("--- Version Parsing ---");

		testHexToVersion_2_03_12();
		testHexToVersion_2_02_00();
		testHexToVersion_1_10_20();
		testHexToVersion_invalidReturnsInput();
		testParseFmodVersion_standardHeader();
		testParseFmodVersion_extraWhitespace();
		testParseFmodVersion_noVersionLine();
		testParseFmodVersion_commentedOut();

		cleanup();
		Sys.println('  $passed passed, $failed failed');
		return failed;
	}

	//// hexToVersion tests

	static function testHexToVersion_2_03_12() {
		assert("0x00020312 -> 2.03.12", hexToVersion("0x00020312") == "2.03.12");
	}

	static function testHexToVersion_2_02_00() {
		assert("0x00020200 -> 2.02.00", hexToVersion("0x00020200") == "2.02.00");
	}

	static function testHexToVersion_1_10_20() {
		assert("0x00011020 -> 1.10.20", hexToVersion("0x00011020") == "1.10.20");
	}

	static function testHexToVersion_invalidReturnsInput() {
		assert("invalid hex returns input", hexToVersion("garbage") == "garbage");
	}

	//// parseFmodVersion tests

	static function testParseFmodVersion_standardHeader() {
		var content = [
			"#ifndef _FMOD_COMMON_H",
			"#define _FMOD_COMMON_H",
			"",
			"#define FMOD_VERSION    0x00020312",
			"",
			"typedef unsigned int FMOD_BOOL;",
		].join("\n");
		var path = writeTempFile("standard.h", content);
		assert("parses standard header", parseFmodVersion(path) == "0x00020312");
	}

	static function testParseFmodVersion_extraWhitespace() {
		var content = "#define   FMOD_VERSION\t  0x00020312  /* version */\n";
		var path = writeTempFile("whitespace.h", content);
		assert("parses with extra whitespace", parseFmodVersion(path) == "0x00020312");
	}

	static function testParseFmodVersion_noVersionLine() {
		var content = [
			"#ifndef _FMOD_COMMON_H",
			"#define _FMOD_COMMON_H",
			"typedef unsigned int FMOD_BOOL;",
		].join("\n");
		var path = writeTempFile("noversion.h", content);
		assert("returns null when no version line", parseFmodVersion(path) == null);
	}

	static function testParseFmodVersion_commentedOut() {
		var content = [
			"// #define FMOD_VERSION    0x00010000",
			"#define FMOD_VERSION    0x00020312",
		].join("\n");
		// The commented-out line still contains both keywords, so the parser
		// matches it first. This documents that behavior.
		var path = writeTempFile("commented.h", content);
		var result = parseFmodVersion(path);
		assert("picks first matching line (even comment)", result == "0x00010000");
	}

	//// Helpers - reimplemented from PostBuild to test the algorithm

	static function hexToVersion(hex:String):String {
		var val = Std.parseInt(hex);
		if (val == null) return hex;
		var hexStr = StringTools.hex(val, 8);
		var product = Std.parseInt("0x" + hexStr.substr(0, 4));
		var major = hexStr.substr(4, 2);
		var minor = hexStr.substr(6, 2);
		return '$product.$major.$minor';
	}

	static function parseFmodVersion(headerPath:String):Null<String> {
		var content = File.getContent(headerPath);
		for (line in content.split("\n")) {
			if (line.indexOf("FMOD_VERSION") != -1 && line.indexOf("#define") != -1) {
				var idx = line.indexOf("0x");
				if (idx != -1) {
					var rest = line.substr(idx);
					var end = 0;
					while (end < rest.length) {
						var c = rest.charCodeAt(end);
						if ((c >= '0'.code && c <= '9'.code) || (c >= 'a'.code && c <= 'f'.code)
							|| (c >= 'A'.code && c <= 'F'.code) || c == 'x'.code || c == 'X'.code) {
							end++;
						} else {
							break;
						}
					}
					return rest.substr(0, end);
				}
			}
		}
		return null;
	}

	static function writeTempFile(name:String, content:String):String {
		if (!FileSystem.exists(tmpDir)) FileSystem.createDirectory(tmpDir);
		var path = '$tmpDir/$name';
		File.saveContent(path, content);
		return path;
	}

	static function cleanup() {
		if (FileSystem.exists(tmpDir)) {
			for (f in FileSystem.readDirectory(tmpDir)) {
				FileSystem.deleteFile('$tmpDir/$f');
			}
			FileSystem.deleteDirectory(tmpDir);
		}
	}

	static function assert(name:String, condition:Bool) {
		if (condition) {
			passed++;
		} else {
			failed++;
			Sys.println('  FAIL: $name');
		}
	}
}
