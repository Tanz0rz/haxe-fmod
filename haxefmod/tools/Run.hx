package haxefmod.tools;

import sys.FileSystem;
import sys.io.File;

class Run {
	static var passCount = 0;
	static var failCount = 0;
	static var warnCount = 0;
	static var skipCount = 0;

	public static function main() {
		// haxelib passes the original cwd as the last arg
		var args = Sys.args();
		var cwd = args.length > 0 ? args[args.length - 1] : Sys.getCwd();
		var userArgs = args.length > 1 ? args.slice(0, args.length - 1) : [];

		var command = userArgs.length > 0 ? userArgs[0] : "help";

		// Resolve the haxelib root (parent of the directory haxelib passes as last arg)
		var libRoot = resolveLibRoot();

		switch (command) {
			case "check":
				runCheck(cwd, libRoot);
			case "build-hdll":
				BuildHdll.run(libRoot, cwd);
			case "postbuild":
				if (userArgs.length < 4) {
					Sys.println("Usage: haxelib run haxefmod postbuild <platform> <target> <libroot>");
					Sys.exit(1);
				}
				// cwd from haxelib is the caller's working directory (project dir)
				// libRoot is passed explicitly from include.xml via ${haxelib:haxefmod}
				PostBuild.run(userArgs[1], userArgs[2], userArgs[3], cwd);
			case "verify-native":
				Sys.exit(NativeManifestCheck.run(libRoot));
			case "generate":
				Generate.run(userArgs.slice(1), cwd);
			case "todos":
				Todos.run(userArgs.slice(1), cwd);
			case "help":
				printUsage();
			case other:
				Sys.println('Unknown command: $other');
				Sys.println("");
				printUsage();
				Sys.exit(1);
		}
	}

	static function resolveLibRoot():String {
		// When run via haxelib, we can find our own root by checking where Run.hx lives
		// The haxelib root is the directory containing haxefmod/, templates/, and the version marker
		// Use Sys.programPath() to find ourselves, then navigate up
		try {
			var result = runQuiet("haxelib", ["path", "haxefmod"]);
			if (result.exitCode == 0) {
				// haxelib path outputs one path per line. The first is the source dir
				for (line in result.stdout.split("\n")) {
					var trimmed = StringTools.trim(line);
					if (trimmed != "" && !StringTools.startsWith(trimmed, "-")) {
						// The classpath line points inside the lib. The
						// version marker identifies its parent as the root
						if (FileSystem.exists(haxe.io.Path.join([haxe.io.Path.directory(trimmed), "fmod_expected_version"]))) {
							return haxe.io.Path.directory(trimmed);
						}
					}
				}
			}
		} catch (e:Dynamic) {}
		// Fallback: use CWD (won't work in all cases but is better than nothing)
		return Sys.getCwd();
	}

	static function printUsage() {
		Sys.println("haxefmod - FMOD audio engine bindings for Haxe");
		Sys.println("");
		Sys.println("Usage: haxelib run haxefmod <command>");
		Sys.println("");
		Sys.println("Commands:");
		Sys.println("  check          Check your environment for correct FMOD SDK setup");
		Sys.println("  build-hdll     Compile hlaxe_fmod.hdll from source against your FMOD SDK");
		Sys.println("  verify-native  Verify the native shims are in lockstep with the FFI manifest");
		Sys.println("  generate       Generate Haxe constant classes (FmodEvents, FmodBuses, ...) from Master.strings.bank");
		Sys.println("  todos          List every FmodManager.Todo sound marker in the project");
		Sys.println("  help           Show this message");
	}

	static function runCheck(cwd:String, libRoot:String) {
		Sys.println("haxefmod check - checking your environment...");
		Sys.println("");

		// 1. Haxe installed
		checkCommand("Haxe installed", "haxe", ["--version"]);

		// 2. Key haxelib deps
		checkHaxelibs();

		// 3. Windows: Check for Visual Studio C++ tools
		if (detectPlatform() == "windows") {
			checkWindowsMsvc();
		}

		// 4. FMOD_SDK env var set
		var fmodSdk = Sys.getEnv("FMOD_SDK");
		if (fmodSdk == null || fmodSdk == "") {
			fail("FMOD_SDK environment variable set", "Not set.");
			Sys.println("");
			Sys.println("  To fix this:");
			Sys.println("  1. Download FMOD Engine from https://www.fmod.com/download");
			Sys.println('     - All platforms require version 2.03.12');
			Sys.println("  2. Install/extract it and set FMOD_SDK to point to the SDK directory.");
			Sys.println("");
			Sys.println("     export FMOD_SDK=/path/to/fmodstudioapi20312");
			Sys.println("");
			Sys.println("  Note: Set FMOD_SDK to the installed/extracted SDK directory.");
			Sys.println("        Switch FMOD_SDK when building for different platforms.");
			Sys.println("");
			printSummary();
			return;
		}
		pass("FMOD_SDK environment variable set", fmodSdk);

		// 5. FMOD_SDK dir exists
		if (!FileSystem.exists(fmodSdk) || !FileSystem.isDirectory(fmodSdk)) {
			fail("FMOD_SDK directory exists", 'Directory not found: $fmodSdk');
			Sys.println('         Check that the path in FMOD_SDK is correct: $fmodSdk');
			printSummary();
			return;
		}
		pass("FMOD_SDK directory exists", fmodSdk);

		// 6. Current platform SDK present
		var platform = detectPlatform();
		var headerPath = '$fmodSdk/api/core/inc/fmod.h';
		var expectedVersion = "2.03.12";
		if (!FileSystem.exists(headerPath)) {
			fail('$platform SDK headers present', 'Not found: $headerPath');
			Sys.println('         Download FMOD Engine $expectedVersion for $platform from https://www.fmod.com/download');
			Sys.println('         and set FMOD_SDK to the installed/extracted SDK directory.');
		} else {
			pass('$platform SDK headers present', headerPath);
		}

		// 7. Platform runtime libs present
		checkRuntimeLibs(fmodSdk, platform);

		// 8. FMOD version check
		if (FileSystem.exists(headerPath)) {
			checkFmodVersion('$fmodSdk/api/core/inc/fmod_common.h', platform);
		}

		// 8b. Pre-built hdll compatibility check
		if (FileSystem.exists(headerPath)) {
			checkHdllCompatibility(fmodSdk, platform, libRoot, cwd);
		}

		// 9. HTML5 SDK check
		checkHtml5Sdk(fmodSdk);

		// 10. Project.xml check (if in a project directory)
		checkProjectXml(cwd);

		// 11. Bank files check (if in a project directory)
		checkBankFiles(cwd);

		// 12. Sound TODO markers (informational only)
		var todos = Todos.scanDirectory(cwd);
		if (todos.length > 0) {
			Sys.println('  Note: ${todos.length} sound TODO(s) in this project. List them with: haxelib run haxefmod todos');
		}

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

	static function checkWindowsMsvc() {
		// vswhere.exe is installed with Visual Studio 2017+ and is how hxcpp locates MSVC
		var vswherePath = "C:\\Program Files (x86)\\Microsoft Visual Studio\\Installer\\vswhere.exe";
		if (FileSystem.exists(vswherePath)) {
			var result = runQuiet(vswherePath, ["-latest", "-property", "installationPath"]);
			if (result.exitCode == 0 && result.stdout != "") {
				pass("Visual Studio C++ tools (for lime build windows)", result.stdout);
				return;
			}
		}

		// Fallback: check if cl.exe is in PATH
		var result = runQuiet("cl", ["--version"]);
		if (result.exitCode == 0) {
			pass("Visual Studio C++ tools (for lime build windows)", "");
		} else {
			fail("Visual Studio C++ tools (needed for lime build windows, not needed for lime build hl)", "Not detected via vswhere or PATH");
			Sys.println("         Install Build Tools for Visual Studio 2022:");
			Sys.println("");
			Sys.println("         Direct download:");
			Sys.println("         https://aka.ms/vs/17/release.ltsc.17.4/vs_buildtools.exe");
			Sys.println("");
			Sys.println("         Or find the Fall 2022 LTSC build tools link at:");
			Sys.println("         https://learn.microsoft.com/en-us/visualstudio/releases/2022/release-history#release-dates-and-build-numbers");
			Sys.println("");
			Sys.println('         During installation, select "Desktop development with C++" workload');
			Sys.println("");
			Sys.println("         Note: lime build hl does not require this (uses pre-built hdlls)");
		}
	}

	static function checkRuntimeLibs(fmodSdk:String, platform:String) {
		var libs:Array<String> = switch (platform) {
			case "mac": ['$fmodSdk/api/core/lib/libfmod.dylib', '$fmodSdk/api/studio/lib/libfmodstudio.dylib'];
			case "linux": [
				'$fmodSdk/api/core/lib/x86_64/libfmod.so',
				'$fmodSdk/api/studio/lib/x86_64/libfmodstudio.so'
			];
			case "windows": [
				'$fmodSdk/api/core/lib/x64/fmod.dll',
				'$fmodSdk/api/studio/lib/x64/fmodstudio.dll'
			];
			default: [];
		};
		var expectedVersion = "2.03.12";
		var missing:Array<String> = [];
		for (lib in libs) {
			if (!FileSystem.exists(lib)) missing.push(lib);
		}
		if (missing.length > 0) {
			fail('$platform runtime libraries', 'Missing: ${missing.join(", ")}');
			Sys.println('         Download FMOD Engine $expectedVersion for $platform from https://www.fmod.com/download');
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

		// All platforms now use 2.03.12
		var expected = "2.03.12";
		if (versionStr == expected) {
			pass("FMOD version", versionStr);
		} else {
			fail("FMOD version", 'Found $versionStr, expected $expected.');
			Sys.println('         Download FMOD Engine $expected for $platform from https://www.fmod.com/download');
		}
	}

	static function checkHdllCompatibility(fmodSdk:String, platform:String, libRoot:String, projectDir:String) {
		var commonHeader = '$fmodSdk/api/core/inc/fmod_common.h';
		var sdkHex = PostBuild.parseFmodVersion(commonHeader);
		if (sdkHex == null) return;

		var versionFile = haxe.io.Path.join([libRoot, "fmod_expected_version"]);
		if (!FileSystem.exists(versionFile)) return;
		var expectedHex = StringTools.trim(File.getContent(versionFile));

		if (sdkHex == expectedHex) {
			pass("Pre-built hdll compatible with SDK", "");
			return;
		}

		// SDK doesn't match pre-built version - check for project-local custom-compiled hdll
		var markerFile = haxe.io.Path.join([projectDir, ".haxefmod", "hlaxe_fmod.version"]);
		if (FileSystem.exists(markerFile)) {
			var markerHex = StringTools.trim(File.getContent(markerFile));
			if (markerHex == sdkHex) {
				var ver = PostBuild.hexToVersion(sdkHex);
				pass("Custom-compiled hdll matches SDK", '$ver (from .haxefmod/)');
				return;
			}
		}

		var sdkVer = PostBuild.hexToVersion(sdkHex);
		var expectedVer = PostBuild.hexToVersion(expectedHex);
		fail("Pre-built hdll compatible with SDK", 'SDK is $sdkVer, pre-built hdll is for $expectedVer');
		Sys.println('         Run: haxelib run haxefmod build-hdll');
		Sys.println('         This will compile hlaxe_fmod.hdll against your SDK.');
	}

	static function checkHtml5Sdk(fmodSdk:String) {
		var fmodSdkWeb = Sys.getEnv("FMOD_SDK_WEB");
		if (fmodSdkWeb == null || fmodSdkWeb == "") {
			skip("FMOD_SDK_WEB environment variable set", "Not set. Only needed for lime build html5.");
			Sys.println('         To build for HTML5 later: download FMOD Engine 2.03.12 for HTML5 from https://www.fmod.com/download and');
			Sys.println('         export FMOD_SDK_WEB=/path/to/fmodstudioapi20312html5');
			return;
		}

		if (!FileSystem.exists(fmodSdkWeb) || !FileSystem.isDirectory(fmodSdkWeb)) {
			fail("FMOD_SDK_WEB directory exists", 'Directory not found: $fmodSdkWeb');
			return;
		}

		var jsPath = '$fmodSdkWeb/api/studio/lib/wasm/fmodstudio.js';
		var wasmPath = '$fmodSdkWeb/api/studio/lib/wasm/fmodstudio.wasm';
		var jsExists = FileSystem.exists(jsPath);
		var wasmExists = FileSystem.exists(wasmPath);
		if (jsExists && wasmExists) {
			pass("HTML5 SDK present", fmodSdkWeb);
		} else {
			var missing:Array<String> = [];
			if (!jsExists) missing.push("fmodstudio.js");
			if (!wasmExists) missing.push("fmodstudio.wasm");
			fail("HTML5 SDK files present", 'Missing: ${missing.join(", ")} in $fmodSdkWeb/api/studio/lib/wasm/');
			Sys.println('         Download FMOD Engine 2.03.12 for HTML5 from https://www.fmod.com/download');
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
			warn("FMOD bank files present", 'Not found: assets/fmod/Desktop/Master.bank. Build banks in FMOD Studio (Ctrl+B) before running the game.');
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

	/** A check that does not apply to this machine. Not counted. */
	static function skip(label:String, detail:String) {
		skipCount++;
		Sys.println('  [SKIP] $label');
		if (detail != "") Sys.println('         $detail');
	}

	/** A heads-up that is normal during setup. Not counted as a failure. */
	static function warn(label:String, detail:String) {
		warnCount++;
		Sys.println('  [WARN] $label');
		if (detail != "") Sys.println('         $detail');
	}

	static function printSummary() {
		var total = passCount + failCount;
		if (failCount == 0) {
			var notes = new Array<String>();
			if (warnCount > 0) notes.push('$warnCount warning' + (warnCount == 1 ? "" : "s"));
			if (skipCount > 0) notes.push('$skipCount skipped');
			var suffix = notes.length > 0 ? ' (${notes.join(", ")})' : "";
			Sys.println('All $total checks passed!$suffix');
		} else {
			Sys.println('$passCount/$total checks passed, $failCount failed.');
			// Scripts and CI rely on the exit code reflecting the result
			Sys.exit(1);
		}
	}
}
