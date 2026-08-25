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
		testHostileChunkSize();
		testMangling();
		testCollisionSuffixes();
		testEmitClass();
		testEventEnums();
		testGeneratedStringEscaping();

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

	static function testHostileChunkSize() {
		// A chunk whose size field reads as a negative signed int must stop
		// the scan (the old scan looped forever because the pointer never
		// advanced past such a chunk)
		var bytes = haxe.io.Bytes.alloc(28);
		bytes.blit(0, haxe.io.Bytes.ofString("RIFF"), 0, 4);
		bytes.setInt32(4, 20); // riff size
		bytes.blit(8, haxe.io.Bytes.ofString("FEV "), 0, 4);
		bytes.blit(12, haxe.io.Bytes.ofString("XXXX"), 0, 4);
		bytes.setInt32(16, 0xFFFFFFF8); // crafted size, -8 as signed
		try {
			StringsBankParser.parse(bytes, "hostile.bank");
			failed++;
			Sys.println("  FAIL: hostile chunk size did not throw");
		} catch (e:haxe.Exception) {
			assert("hostile chunk stops with the no-STDT error", e.message.indexOf("STDT") != -1);
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
		var guidLike = Generate.identifiersFor(["event:/Coin", "event:/Coin Guid"], "event:/");
		assert("Guid-suffixed paths stay distinct", guidLike.join(",") == "Coin,CoinGuid");
	}

	static function testEmitClass() {
		var entries = [
			{path: "event:/Music/MainLevel", guid: "{E5187C3F-0517-463E-B458-DE9EF1A9F750}"},
			{path: "event:/SFX/Jump", guid: "{4562f533-1e6b-4ce9-a40a-814283edde66}"},
		];
		var expected = [
			"// Generated haxefmod constants - do not edit (regenerate from FMOD Studio or via haxelib run haxefmod generate)",
			"",
			"class FmodEvents {",
			"\tpublic static inline var MusicMainLevel:String = \"event:/Music/MainLevel\";",
			"\tpublic static inline var SFXJump:String = \"event:/SFX/Jump\";",
			"}",
			"",
			"class FmodEventsGuids {",
			"\tpublic static inline var MusicMainLevel:String = \"{e5187c3f-0517-463e-b458-de9ef1a9f750}\";",
			"\tpublic static inline var SFXJump:String = \"{4562f533-1e6b-4ce9-a40a-814283edde66}\";",
			"}",
			"",
		].join("\n");
		var actual = @:privateAccess Generate.emitClass("FmodEvents", "event:/", entries, "");
		assert("emitClass golden output (paths class + Guids companion, lowercased)", actual == expected);
	}

	static function testGeneratedStringEscaping() {
		assert("quote escaped", Generate.quoteHx('He said "hi"') == 'He said \\"hi\\"');
		assert("backslash escaped", Generate.quoteHx("a\\b") == "a\\\\b");
		assert("clean path unchanged", Generate.quoteHx("event:/SFX/Jump") == "event:/SFX/Jump");

		// An event path containing a quote must emit a compilable literal
		var entries = [{path: 'event:/He said "hi"', guid: "{00000000-0000-0000-0000-000000000000}"}];
		var text = Generate.emitEventEnums(entries, "");
		assert("enum emit escapes quoted paths",
			text != null && text.indexOf('"event:/He said \\"hi\\""') >= 0);
	}

	static function testEventEnums() {
		var entries = [
			{path: "event:/SFX/Jump", guid: "{4562f533-1e6b-4ce9-a40a-814283edde66}"},
			{path: "event:/Music/MainLevel", guid: "{e5187c3f-0517-463e-b458-de9ef1a9f750}"},
			{path: "event:/Ambience/Wind", guid: "{1a13f11e-eecf-4c3c-b353-79423771ced9}"},
			{path: "bus:/Reverb", guid: "{293aa1ce-c07e-4cc2-bc41-7a082a62b7fa}"},
		];
		var expected = [
			"// Generated haxefmod constants - do not edit (regenerate from FMOD Studio or via haxelib run haxefmod generate)",
			"",
			"enum FmodEventEnum {",
			"\tAmbienceWind;",
			"\tMusicMainLevel;",
			"\tSFXJump;",
			"}",
			"",
			"// Static extension: `using FmodEventEnum.FmodEventTools;` enables",
			"// FmodEventEnum.MusicMainLevel.path() and .guid()",
			"class FmodEventTools {",
			"\tpublic static inline function path(event:FmodEventEnum):String {",
			"\t\treturn switch (event) {",
			"\t\t\tcase AmbienceWind: \"event:/Ambience/Wind\";",
			"\t\t\tcase MusicMainLevel: \"event:/Music/MainLevel\";",
			"\t\t\tcase SFXJump: \"event:/SFX/Jump\";",
			"\t\t};",
			"\t}",
			"",
			"\tpublic static inline function guid(event:FmodEventEnum):String {",
			"\t\treturn switch (event) {",
			"\t\t\tcase AmbienceWind: \"{1a13f11e-eecf-4c3c-b353-79423771ced9}\";",
			"\t\t\tcase MusicMainLevel: \"{e5187c3f-0517-463e-b458-de9ef1a9f750}\";",
			"\t\t\tcase SFXJump: \"{4562f533-1e6b-4ce9-a40a-814283edde66}\";",
			"\t\t};",
			"\t}",
			"}",
			"",
		].join("\n");
		assert("enum file covers every event with constants-matching names", Generate.emitEventEnums(entries, "") == expected);

		assert("no events yields null",
			Generate.emitEventEnums([{path: "bus:/Reverb", guid: "{293aa1ce-c07e-4cc2-bc41-7a082a62b7fa}"}], "") == null);

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
