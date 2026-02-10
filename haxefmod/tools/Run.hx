package haxefmod.tools;

import sys.FileSystem;
import sys.io.File;

class Run {
	static var passCount = 0;
	static var failCount = 0;

	public static function main() {
		// haxelib passes the original cwd as the last arg
		var args = Sys.args();
		var cwd = args.length > 0 ? args[args.length - 1] : Sys.getCwd();
		var userArgs = args.length > 1 ? args.slice(0, args.length - 1) : [];

		var command = userArgs.length > 0 ? userArgs[0] : "help";

		switch (command) {
			case "doctor":
				runDoctor(cwd);
			default:
				printUsage();
		}
	}

	static function printUsage() {
		Sys.println("haxefmod - FMOD audio engine bindings for Haxe");
		Sys.println("");
		Sys.println("Usage: haxelib run haxefmod <command>");
		Sys.println("");
		Sys.println("Commands:");
		Sys.println("  doctor    Check your environment for correct FMOD SDK setup");
		Sys.println("  help      Show this message");
	}

	static function runDoctor(cwd:String) {
		Sys.println("haxefmod doctor - checking your environment...");
		Sys.println("");

		// 1. Haxe installed
		checkCommand("Haxe installed", "haxe", ["--version"]);

		// 2. Key haxelib deps
		checkHaxelibs();

		// 3. FMOD_SDK env var set
		var fmodSdk = Sys.getEnv("FMOD_SDK");
		if (fmodSdk == null || fmodSdk == "") {
			fail("FMOD_SDK environment variable set", "Not set. Export FMOD_SDK pointing to your FMOD Engine SDK directory.");
			printSummary();
			return;
		}
		pass("FMOD_SDK environment variable set", fmodSdk);

		// 4. FMOD_SDK dir exists
		if (!FileSystem.exists(fmodSdk) || !FileSystem.isDirectory(fmodSdk)) {
			fail("FMOD_SDK directory exists", 'Directory not found: $fmodSdk');
			printSummary();
			return;
		}
		pass("FMOD_SDK directory exists", fmodSdk);

		// 5. Current platform SDK present
		var platform = detectPlatform();
		var platformDir = '$fmodSdk/$platform';
		var headerPath = '$platformDir/api/core/inc/fmod.h';
		if (!FileSystem.exists(headerPath)) {
			fail('$platform SDK headers present', 'Not found: $headerPath\nDownload FMOD Engine for $platform and extract to $$FMOD_SDK/$platform/');
		} else {
			pass('$platform SDK headers present', headerPath);
		}

		// 6. Platform runtime libs present
		checkRuntimeLibs(platformDir, platform);

		// 7. FMOD version check
		if (FileSystem.exists(headerPath)) {
			checkFmodVersion('$platformDir/api/core/inc/fmod_common.h', platform);
		}

		// 8. HashLink installed
		checkCommand("HashLink installed", "hl", ["--version"]);

		// 9. Project.xml check (if in a project directory)
		checkProjectXml(cwd);

		// 10. Bank files check (if in a project directory)
		checkBankFiles(cwd);

		Sys.println("");
		printSummary();
	}

	static function detectPlatform():String {
		var name = Sys.systemName();
		if (name == "Windows") return "windows";
		if (name == "Mac") return "mac";
		return "linux";
	}

	static function runQuiet(cmd:String, args:Array<String>):{exitCode:Int, stdout:String} {
		try {
			var proc = new sys.io.Process(cmd, args);
			var stdout = proc.stdout.readAll().toString();
			var exitCode = proc.exitCode();
			proc.close();
			return {exitCode: exitCode, stdout: StringTools.trim(stdout)};
		} catch (e:Dynamic) {
			return {exitCode: 1, stdout: ""};
		}
	}

	static function checkCommand(label:String, cmd:String, args:Array<String>) {
		var result = runQuiet(cmd, args);
		if (result.exitCode == 0) {
			pass(label, result.stdout);
		} else {
			fail(label, '$cmd not found in PATH');
		}
	}

	static function checkHaxelibs() {
		var libs = ["lime", "openfl", "flixel", "hxcpp"];
		var missing:Array<String> = [];
		for (lib in libs) {
			var result = runQuiet("haxelib", ["path", lib]);
			if (result.exitCode != 0) missing.push(lib);
		}
		if (missing.length > 0) {
			fail("haxelib dependencies", 'Missing: ${missing.join(", ")}. Install with: haxelib install <name>');
		} else {
			pass("haxelib dependencies (lime, openfl, flixel, hxcpp)", "");
		}
	}

	static function checkRuntimeLibs(platformDir:String, platform:String) {
		var libs:Array<String> = switch (platform) {
			case "mac": ['$platformDir/api/core/lib/libfmod.dylib', '$platformDir/api/studio/lib/libfmodstudio.dylib'];
			case "linux": [
				'$platformDir/api/core/lib/x86_64/libfmod.so',
				'$platformDir/api/studio/lib/x86_64/libfmodstudio.so'
			];
			case "windows": [
				'$platformDir/api/core/lib/x64/fmod.dll',
				'$platformDir/api/studio/lib/x64/fmodstudio.dll'
			];
			default: [];
		};
		var missing:Array<String> = [];
		for (lib in libs) {
			if (!FileSystem.exists(lib)) missing.push(lib);
		}
		if (missing.length > 0) {
			fail('$platform runtime libraries', 'Missing: ${missing.join(", ")}');
		} else {
			pass('$platform runtime libraries', "");
		}
	}

	static function checkFmodVersion(commonHeaderPath:String, platform:String) {
		if (!FileSystem.exists(commonHeaderPath)) {
			fail("FMOD version", 'Header not found: $commonHeaderPath');
			return;
		}
		var content = File.getContent(commonHeaderPath);
		// Look for: #define FMOD_VERSION    0x00020312
		var versionHex:Null<Int> = null;
		for (line in content.split("\n")) {
			if (line.indexOf("FMOD_VERSION") != -1 && line.indexOf("#define") != -1) {
				// Extract hex value
				var idx = line.indexOf("0x");
				if (idx != -1) {
					var hexStr = line.substr(idx, 10);
					versionHex = Std.parseInt(hexStr);
				}
				break;
			}
		}
		if (versionHex == null) {
			fail("FMOD version", "Could not parse FMOD_VERSION from header");
			return;
		}
		// FMOD version is BCD-like: 0x00020312 = "2.03.12" (hex digits ARE the version digits)
		var hexStr = StringTools.hex(versionHex, 8);
		var product = Std.parseInt("0x" + hexStr.substr(0, 4));
		var major = hexStr.substr(4, 2);
		var minor = hexStr.substr(6, 2);
		var versionStr = '$product.$major.$minor';

		// Expected versions
		var expected = switch (platform) {
			case "mac": "2.03.12";
			default: "2.00.08";
		};
		if (versionStr == expected) {
			pass("FMOD version", '$versionStr (expected $expected)');
		} else {
			fail("FMOD version", 'Found $versionStr, expected $expected');
		}
	}

	static function checkProjectXml(cwd:String) {
		var projectXml = '$cwd/Project.xml';
		if (!FileSystem.exists(projectXml)) {
			// Not in a project directory, skip silently
			return;
		}
		var content = File.getContent(projectXml);
		if (content.indexOf("haxefmod") != -1) {
			pass("Project.xml includes haxefmod", "");
		} else {
			fail("Project.xml includes haxefmod", 'Add <haxelib name="haxefmod" /> to your Project.xml');
		}
	}

	static function checkBankFiles(cwd:String) {
		var bankPath = '$cwd/assets/fmod/Desktop/Master.bank';
		if (!FileSystem.exists('$cwd/Project.xml')) {
			return; // Not in a project directory
		}
		if (FileSystem.exists(bankPath)) {
			pass("FMOD bank files present", bankPath);
		} else {
			fail("FMOD bank files present", 'Not found: assets/fmod/Desktop/Master.bank');
		}
	}

	static function pass(label:String, detail:String) {
		passCount++;
		var msg = '  [OK]   $label';
		if (detail != "") msg += ' ($detail)';
		Sys.println(msg);
	}

	static function fail(label:String, detail:String) {
		failCount++;
		Sys.println('  [FAIL] $label');
		if (detail != "") Sys.println('         $detail');
	}

	static function printSummary() {
		var total = passCount + failCount;
		if (failCount == 0) {
			Sys.println('All $total checks passed!');
		} else {
			Sys.println('$passCount/$total checks passed, $failCount failed.');
		}
	}
}
