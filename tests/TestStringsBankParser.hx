package tests;

import haxefmod.tools.Generate;
import haxefmod.tools.StringsBankParser;
import sys.io.File;
import sys.FileSystem;

/**
 * Tests StringsBankParser against a checked-in copy of the example
 * project's Master.strings.bank (tests/fixtures/), plus the identifier
 * mangling used by the generate command.
 *
 * The expected path/GUID pairs are the exact set the FMOD 2.03.12 runtime
 * reports for this bank via Bank::getStringInfo, so the parser is held to
 * byte-for-byte parity with FMOD's own string table decoding.
 */
class TestStringsBankParser {
	static var passed = 0;
	static var failed = 0;

	static var fixture = "tests/fixtures/Master.strings.bank";
	static var tmpDir = "/tmp/haxefmod-stringsbank-test";

	public static function run():Int {
		Sys.println("--- Strings Bank Parser ---");

		testGoldenFixture();
		testMissingFile();
		testNotABank();
		testMangling();
		testCollisionSuffixes();
		testEventEnums();

		cleanup();
		Sys.println('  $passed passed, $failed failed');
		return failed;
	}

	//// golden-file test: exact entry set as reported by the FMOD runtime

	static function testGoldenFixture() {
		var expected = [
			"{1a13f11e-eecf-4c3c-b353-79423771ced9} bus:/Reverb",
			"{293aa1ce-c07e-4cc2-bc41-7a082a62b7fa} parameter:/FadeArpIn",
			"{4562f533-1e6b-4ce9-a40a-814283edde66} event:/SFX/Jump",
			"{4e75eb97-ff6c-459d-a75b-0576603fe118} parameter:/HighPass",
			"{66f6c0e2-d897-0a5b-0d20-44f9abca2481} bank:/Master.strings",
			"{6c656399-97f5-432f-9817-c10c8c56939d} event:/SFX/Coin",
			"{7a6e2e04-9ca1-4dc4-9df2-20f23d4a9d52} bus:/",
			"{e5187c3f-0517-463e-b458-de9ef1a9f750} event:/Music/MainLevel",
			"{feebe036-a9ec-4619-8b69-ce075a392219} bank:/Master",
		];
		try {
			var entries = StringsBankParser.parseFile(fixture);
			var actual = entries.map(e -> '${e.guid} ${e.path}');
			actual.sort(Reflect.compare);
			assert("fixture has 9 entries", entries.length == 9);
			assert("fixture entries match FMOD runtime output exactly", actual.join("\n") == expected.join("\n"));
			if (actual.join("\n") != expected.join("\n")) {
				Sys.println("  parsed:");
				for (line in actual)
					Sys.println('    $line');
			}
		} catch (e:haxe.Exception) {
			failed++;
			Sys.println('  FAIL: fixture parse threw: ${e.message}');
		}
	}

	//// error paths

	static function testMissingFile() {
		var missing = "tests/fixtures/DoesNotExist.strings.bank";
		try {
			StringsBankParser.parseFile(missing);
			failed++;
			Sys.println("  FAIL: missing file did not throw");
		} catch (e:haxe.Exception) {
			assert("missing file error names the file", e.message.indexOf(missing) != -1);
			assert("missing file error says what was expected", e.message.indexOf("Master.strings.bank") != -1);
		}
	}

	static function testNotABank() {
		if (!FileSystem.exists(tmpDir)) FileSystem.createDirectory(tmpDir);
		var path = '$tmpDir/garbage.strings.bank';
		File.saveContent(path, "this is not a bank file at all, just text padding to pass length checks");
		try {
			StringsBankParser.parseFile(path);
			failed++;
			Sys.println("  FAIL: non-bank file did not throw");
		} catch (e:haxe.Exception) {
			assert("non-bank error names the file", e.message.indexOf(path) != -1);
			assert("non-bank error mentions the expected format", e.message.indexOf("RIFF") != -1);
		}
	}

	//// identifier mangling

	static function testMangling() {
		assert("basic path", Generate.mangle("event:/Music/MainLevel", "event:/") == "MusicMainLevel");
		assert("space becomes CamelCase", Generate.mangle("event:/VO/Main Menu", "event:/") == "VOMainMenu");
		assert("hyphen becomes CamelCase", Generate.mangle("event:/Vehicles/Ride-on Mower", "event:/") == "VehiclesRideOnMower");
		assert("illegal chars dropped", Generate.mangle("parameter:/A.B (C)", "parameter:/") == "ABC");
		assert("root bus", Generate.mangle("bus:/", "bus:/") == "Root");
		assert("leading digit underscored", Generate.mangle("event:/2nd Floor/Door", "event:/") == "_2ndFloorDoor");
		assert("case preserved after first letter", Generate.mangle("event:/SFX/Coin", "event:/") == "SFXCoin");
	}

	static function testCollisionSuffixes() {
		var names = Generate.identifiersFor(["event:/A B", "event:/A/B", "event:/AB"], "event:/");
		assert("collisions get numeric suffixes", names.join(",") == "AB,AB2,AB3");
		var guidClash = Generate.identifiersFor(["event:/Coin", "event:/Coin Guid"], "event:/");
		assert("Guid pair names are reserved too", guidClash.join(",") == "Coin,CoinGuid2");
	}

	static function testEventEnums() {
		var entries = [
			{path: "event:/SFX/Jump", guid: "{4562f533-1e6b-4ce9-a40a-814283edde66}"},
			{path: "event:/Music/MainLevel", guid: "{e5187c3f-0517-463e-b458-de9ef1a9f750}"},
			{path: "event:/SFX/Coin", guid: "{6c656399-97f5-432f-9817-c10c8c56939d}"},
			{path: "bus:/Reverb", guid: "{1a13f11e-eecf-4c3c-b353-79423771ced9}"},
		];
		var expected = [
			"// Generated haxefmod constants - do not edit (regenerate from FMOD Studio or via haxelib run haxefmod generate)",
			"",
			"enum FmodSong {",
			"\tMainLevel;",
			"}",
			"",
			"enum FmodSFX {",
			"\tCoin;",
			"\tJump;",
			"}",
			"",
			"class FmodEvent {",
			"\tpublic static inline extern overload function event(song:FmodSong):String {",
			"\t\treturn switch (song) {",
			"\t\t\tcase MainLevel: \"event:/Music/MainLevel\";",
			"\t\t};",
			"\t}",
			"",
			"\tpublic static inline extern overload function event(sfx:FmodSFX):String {",
			"\t\treturn switch (sfx) {",
			"\t\t\tcase Coin: \"event:/SFX/Coin\";",
			"\t\t\tcase Jump: \"event:/SFX/Jump\";",
			"\t\t};",
			"\t}",
			"}",
			"",
		].join("\n");
		assert("enum file emits both groups sorted", Generate.emitEventEnums(entries, "") == expected);

		var musicOnly = Generate.emitEventEnums([{path: "event:/Music/MainLevel", guid: "{e5187c3f-0517-463e-b458-de9ef1a9f750}"}], "");
		assert("music-only file has FmodSong but no FmodSFX",
			musicOnly != null && musicOnly.indexOf("enum FmodSong") != -1 && musicOnly.indexOf("FmodSFX") == -1);

		assert("no matching events yields null",
			Generate.emitEventEnums([{path: "event:/Ambience/Wind", guid: "{1a13f11e-eecf-4c3c-b353-79423771ced9}"}], "") == null);

		var pkg = Generate.emitEventEnums([{path: "event:/SFX/Coin", guid: "{6c656399-97f5-432f-9817-c10c8c56939d}"}], "sounds");
		assert("package line included when requested", pkg != null && pkg.indexOf("package sounds;") != -1);
	}

	//// helpers

	static function cleanup() {
		if (FileSystem.exists(tmpDir)) {
			for (f in FileSystem.readDirectory(tmpDir))
				FileSystem.deleteFile('$tmpDir/$f');
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
