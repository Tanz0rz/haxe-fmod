package haxefmod.tools;

import sys.FileSystem;
import sys.io.File;

class Run {
	static var passCount = 0;
	static var failCount = 0;
	static var warnCount = 0;
	static var skipCount = 0;

	public static function main() {
		// haxelib passes the original cwd as the last arg.
		var args = Sys.args();
		var cwd = args.length > 0 ? args[args.length - 1] : Sys.getCwd();
		var userArgs = args.length > 1 ? args.slice(0, args.length - 1) : [];

		var command = userArgs.length > 0 ? userArgs[0] : "help";

		// Resolve the haxelib root (parent of the directory haxelib passes as last arg).
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
				// cwd from haxelib is the caller's working directory (project
				// dir). The libroot argument from include.xml is IGNORED.
				// lime splits postbuild commands on spaces with no quote
				// handling, so a haxelib path containing a space arrives
				// shattered. This process resolves the root instead.
				PostBuild.run(userArgs[1], userArgs[2], libRoot, cwd);
			case "stage":
				if (userArgs.length < 4) {
					Sys.println("Usage: haxelib run haxefmod stage <platform> <target> <outdir>");
					Sys.println("  platform: linux, mac, windows, html5");
					Sys.println("  target:   hl (program loads hlaxe_fmod.hdll), cpp (binding compiled in), or html5");
					Sys.println("  outdir:   the build output directory, relative to the project");
					Sys.exit(1);
				}
				var outDir = userArgs[3];
				if (!haxe.io.Path.isAbsolute(outDir)) outDir = haxe.io.Path.join([cwd, outDir]);
				PostBuild.stage(userArgs[1], userArgs[2], libRoot, cwd, outDir);
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
		// The library root holds haxefmod/, templates/, and the version
		// marker. The haxelib path command names the classpath inside it.
		// haxelib runs this tool from the library directory, so the working
		// directory is the fallback.
		try {
			var result = runQuiet("haxelib", ["path", "haxefmod"]);
			if (result.exitCode == 0) {
				// haxelib path outputs one path per line. The first is the source dir.
				for (line in result.stdout.split("\n")) {
					var trimmed = StringTools.trim(line);
					if (trimmed != "" && !StringTools.startsWith(trimmed, "-")) {
						// The classpath line points inside the lib. The
						// version marker identifies its parent as the root.
						if (FileSystem.exists(haxe.io.Path.join([haxe.io.Path.directory(trimmed), "fmod_expected_version"]))) {
							return haxe.io.Path.directory(trimmed);
						}
					}
				}
			}
		} catch (e:Dynamic) {}
		// haxelib changes into the library directory before running the tool.
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
		Sys.println("  stage          Copy the FMOD runtime files into a build output directory (Heaps, Kha, plain haxe builds)");
		Sys.println("  verify-native  Verify the native shims are in lockstep with the FFI manifest");
		Sys.println("  generate       Generate Haxe constant classes (FmodEvents, FmodBuses, ...) from Master.strings.bank");
		Sys.println("  todos          List every FmodManager.Todo sound marker in the project (--json for machine output)");
		Sys.println("  postbuild      Copy the FMOD runtime files after a lime build (include.xml runs this)");
		Sys.println("  help           Show this message");
	}

	/** The FMOD version the pre-built binaries expect, read from the library's marker file. */
	static function expectedFmodVersion(libRoot:String):String {
		var versionFile = haxe.io.Path.join([libRoot, "fmod_expected_version"]);
		if (!FileSystem.exists(versionFile)) return "the expected FMOD version";
		return PostBuild.hexToVersion(StringTools.trim(File.getContent(versionFile)));
	}

	/** The version as it appears in FMOD's package names, 2.03.12 as 20312. */
	static function packageDigits(version:String):String {
		return version.split(".").join("");
	}

	static function runCheck(cwd:String, libRoot:String) {
		Sys.println("haxefmod check - checking your environment...");
		Sys.println("");
		var expectedVersion = expectedFmodVersion(libRoot);
		var digits = packageDigits(expectedVersion);

		// 1. Haxe installed
		checkCommand("Haxe installed", "haxe", ["--version"]);

		// 2. Key haxelib deps
		checkHaxelibs(cwd);

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
			Sys.println('     - All platforms require version $expectedVersion');
			Sys.println("  2. Install/extract it and set FMOD_SDK to point to the SDK directory.");
			Sys.println("");
			Sys.println('     export FMOD_SDK=/path/to/fmodstudioapi$digits');
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
		var headerPath = haxe.io.Path.join([fmodSdk, "api", "core", "inc", "fmod.h"]);
		if (!FileSystem.exists(headerPath)) {
			fail('$platform SDK headers present', 'Not found: $headerPath');
			Sys.println('         Download FMOD Engine $expectedVersion for $platform from https://www.fmod.com/download');
			Sys.println('         and set FMOD_SDK to the installed/extracted SDK directory.');
		} else {
			pass('$platform SDK headers present', headerPath);
		}

		// 7. Platform runtime libs present
		checkRuntimeLibs(fmodSdk, platform, expectedVersion);

		// 8. FMOD version check
		if (FileSystem.exists(headerPath)) {
			checkFmodVersion(haxe.io.Path.join([fmodSdk, "api", "core", "inc", "fmod_common.h"]), platform, expectedVersion);
		}

		// 8b. Pre-built hdll compatibility check
		if (FileSystem.exists(headerPath)) {
			checkHdllCompatibility(fmodSdk, platform, libRoot, cwd);
		}

		// 9. HTML5 SDK check
		checkHtml5Sdk(expectedVersion, digits);

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
			// Drain stderr too, or a chatty child blocks on a full pipe
			// while this process waits for its exit code.
			proc.stderr.readAll();
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

	/**
	 * A lime project needs lime, hxcpp, and every haxelib its project file
	 * names. A Heaps or Kha project declares its libraries in an hxml or
	 * khafile instead, so those are reported without a verdict.
	 */
	static function checkHaxelibs(cwd:String) {
		var projectXml = findProjectXml(cwd);
		if (projectXml == null) {
			var found:Array<String> = [];
			for (lib in ["heaps", "hxcpp"]) {
				if (runQuiet("haxelib", ["path", lib]).exitCode == 0) found.push(lib);
			}
			skip("haxelib dependencies", "No lime project file here. Heaps and Kha projects declare their libraries in hxml or khafile.js."
				+ (found.length > 0 ? ' Installed: ${found.join(", ")}.' : ""));
			return;
		}
		var libs = ["lime", "hxcpp"];
		// Commented-out entries are scaffold leftovers, so strip them first.
		var content = ~/<!--[\s\S]*?-->/g.replace(File.getContent(projectXml), "");
		var named = ~/<haxelib\s+name="([^"]+)"/g;
		var pos = 0;
		while (named.matchSub(content, pos)) {
			var lib = named.matched(1);
			if (lib != "haxefmod" && libs.indexOf(lib) == -1) libs.push(lib);
			pos = named.matchedPos().pos + named.matchedPos().len;
		}
		var missing:Array<String> = [];
		for (lib in libs) {
			var result = runQuiet("haxelib", ["path", lib]);
			if (result.exitCode != 0) missing.push(lib);
		}
		if (missing.length > 0) {
			fail("haxelib dependencies", 'Missing: ${missing.join(", ")}. Install with: haxelib install <name>');
		} else {
			pass('haxelib dependencies (${libs.join(", ")})', "");
		}
	}

	static function checkWindowsMsvc() {
		// vswhere.exe is installed with Visual Studio 2017+ and is how hxcpp
		// locates MSVC. Without -products * it skips the standalone Build
		// Tools product, which is exactly what the remediation below tells
		// the user to install.
		var vswherePath = "C:\\Program Files (x86)\\Microsoft Visual Studio\\Installer\\vswhere.exe";
		if (FileSystem.exists(vswherePath)) {
			var result = runQuiet(vswherePath, ["-latest", "-products", "*", "-property", "installationPath"]);
			if (result.exitCode == 0 && result.stdout != "") {
				pass("Visual Studio C++ tools (for lime build windows)", result.stdout);
				return;
			}
		}

		// Fallback: cl.exe reachable in PATH. cl has no version flag and
		// exits non-zero when run bare, so the check is that it ran at all
		// (matching BuildHdll.compilerAvailable).
		var clRan = try {
			var proc = new sys.io.Process("cl", []);
			proc.stdout.readAll();
			proc.stderr.readAll();
			proc.exitCode();
			proc.close();
			true;
		} catch (e:Dynamic) false;
		if (clRan) {
			pass("Visual Studio C++ tools (for lime build windows)", "cl.exe in PATH");
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

	static function checkRuntimeLibs(fmodSdk:String, platform:String, expectedVersion:String) {
		var relative:Array<Array<String>> = switch (platform) {
			case "mac": [["api", "core", "lib", "libfmod.dylib"], ["api", "studio", "lib", "libfmodstudio.dylib"]];
			case "linux": [["api", "core", "lib", "x86_64", "libfmod.so"], ["api", "studio", "lib", "x86_64", "libfmodstudio.so"]];
			case "windows": [["api", "core", "lib", "x64", "fmod.dll"], ["api", "studio", "lib", "x64", "fmodstudio.dll"]];
			default: [];
		};
		var libs = [for (parts in relative) haxe.io.Path.join([fmodSdk].concat(parts))];
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

	static function checkFmodVersion(commonHeaderPath:String, platform:String, expected:String) {
		if (!FileSystem.exists(commonHeaderPath)) {
			fail("FMOD version", 'Header not found: $commonHeaderPath');
			return;
		}
		// The same parser the build uses, so the doctor and the build agree.
		var sdkHex = PostBuild.parseFmodVersion(commonHeaderPath);
		if (sdkHex == null || Std.parseInt(sdkHex) == null) {
			fail("FMOD version", "Could not parse FMOD_VERSION from header");
			return;
		}
		var versionStr = PostBuild.hexToVersion(sdkHex);
		if (versionStr == expected) {
			pass("FMOD version", versionStr);
		} else {
			fail("FMOD version", 'Found $versionStr, expected $expected.');
			Sys.println('         Download FMOD Engine $expected for $platform from https://www.fmod.com/download');
		}
	}

	static function checkHdllCompatibility(fmodSdk:String, platform:String, libRoot:String, projectDir:String) {
		var commonHeader = haxe.io.Path.join([fmodSdk, "api", "core", "inc", "fmod_common.h"]);
		// A truncated SDK extract can pass the fmod.h gate while this header
		// is missing. The build fails on it, so the doctor does too.
		if (!FileSystem.exists(commonHeader)) {
			fail("Pre-built hdll compatible with SDK", 'Cannot verify: missing $commonHeader. Re-download the FMOD Engine.');
			return;
		}
		var sdkHex = PostBuild.parseFmodVersion(commonHeader);
		if (sdkHex == null) {
			warn("Pre-built hdll compatible with SDK", 'Cannot verify: no FMOD_VERSION in $commonHeader');
			return;
		}

		var versionFile = haxe.io.Path.join([libRoot, "fmod_expected_version"]);
		if (!FileSystem.exists(versionFile)) {
			warn("Pre-built hdll compatible with SDK", 'Cannot verify: missing $versionFile. Reinstall haxefmod.');
			return;
		}
		var expectedHex = StringTools.trim(File.getContent(versionFile));

		// The hdll the build copies: the custom one when it exists and its
		// marker matches the SDK, the pre-built one otherwise. The same
		// choice PostBuild.copyHdll makes.
		var customHdll = haxe.io.Path.join([projectDir, ".haxefmod", "hlaxe_fmod.hdll"]);
		var markerFile = haxe.io.Path.join([projectDir, ".haxefmod", "hlaxe_fmod.version"]);
		var hdll:String = null;
		if (FileSystem.exists(customHdll) && PostBuild.customHdllMatchesSdk(projectDir)) {
			hdll = customHdll;
			if (FileSystem.exists(markerFile)) {
				pass("Custom-compiled hdll matches SDK", '${PostBuild.hexToVersion(sdkHex)} (from .haxefmod/)');
			} else {
				pass("Custom-compiled hdll present", ".haxefmod/ (no version marker, trusted as-is)");
			}
		} else if (PostBuild.sameVersion(sdkHex, expectedHex)) {
			pass("Pre-built hdll compatible with SDK", "");
			hdll = haxe.io.Path.join([libRoot, "templates", "bin", "hl", prebuiltPlatformDir(platform), "hlaxe_fmod.hdll"]);
		} else {
			var sdkVer = PostBuild.hexToVersion(sdkHex);
			var expectedVer = PostBuild.hexToVersion(expectedHex);
			fail("Pre-built hdll compatible with SDK", 'SDK is $sdkVer, pre-built hdll is for $expectedVer');
			if (FileSystem.exists(markerFile) && !FileSystem.exists(customHdll)) {
				Sys.println('         .haxefmod/ has a version marker but no hlaxe_fmod.hdll next to it.');
			}
			Sys.println('         Run: haxelib run haxefmod build-hdll');
			Sys.println('         That compiles hlaxe_fmod.hdll against your SDK.');
			return;
		}

		// The binding ABI half of the build gate.
		var expectedAbi = PostBuild.expectedAbiVersion(libRoot);
		if (expectedAbi <= 0) return;
		if (!FileSystem.exists(hdll)) {
			fail("hlaxe_fmod.hdll binding ABI", 'Missing: $hdll. Reinstall haxefmod, or run: haxelib run haxefmod build-hdll');
			return;
		}
		var found = PostBuild.scanHdllAbi(hdll);
		if (found == expectedAbi) {
			pass("hlaxe_fmod.hdll binding ABI", '$found');
		} else {
			fail("hlaxe_fmod.hdll binding ABI", 'hdll has ' + (found == 0 ? "no marker" : Std.string(found)) + ', the library needs $expectedAbi');
			Sys.println('         Run: haxelib run haxefmod build-hdll');
		}
	}

	static function prebuiltPlatformDir(platform:String):String {
		return switch (platform) {
			case "windows": "Windows64";
			case "mac": "Mac64";
			default: "Linux64";
		}
	}

	static function checkHtml5Sdk(expectedVersion:String, digits:String) {
		var fmodSdkWeb = Sys.getEnv("FMOD_SDK_WEB");
		if (fmodSdkWeb == null || fmodSdkWeb == "") {
			skip("FMOD_SDK_WEB environment variable set", "Not set. Only needed for HTML5 builds.");
			Sys.println('         To build for HTML5 later: download FMOD Engine $expectedVersion for HTML5 from https://www.fmod.com/download and');
			Sys.println('         export FMOD_SDK_WEB=/path/to/fmodstudioapi${digits}html5');
			return;
		}

		if (!FileSystem.exists(fmodSdkWeb) || !FileSystem.isDirectory(fmodSdkWeb)) {
			fail("FMOD_SDK_WEB directory exists", 'Directory not found: $fmodSdkWeb');
			return;
		}

		var jsPath = haxe.io.Path.join([fmodSdkWeb, "api", "studio", "lib", "wasm", "fmodstudio.js"]);
		var wasmPath = haxe.io.Path.join([fmodSdkWeb, "api", "studio", "lib", "wasm", "fmodstudio.wasm"]);
		var jsExists = FileSystem.exists(jsPath);
		var wasmExists = FileSystem.exists(wasmPath);
		if (jsExists && wasmExists) {
			pass("HTML5 SDK present", fmodSdkWeb);
		} else {
			var missing:Array<String> = [];
			if (!jsExists) missing.push("fmodstudio.js");
			if (!wasmExists) missing.push("fmodstudio.wasm");
			fail("HTML5 SDK files present", 'Missing: ${missing.join(", ")} in $fmodSdkWeb/api/studio/lib/wasm/');
			Sys.println('         Download FMOD Engine $expectedVersion for HTML5 from https://www.fmod.com/download');
		}
	}

	// Lime accepts project.xml, Project.xml, and application.xml, so the
	// diagnostics must find any of them on a case-sensitive filesystem.
	static function findProjectXml(cwd:String):Null<String> {
		for (name in ["Project.xml", "project.xml", "application.xml"]) {
			var path = haxe.io.Path.join([cwd, name]);
			if (FileSystem.exists(path)) return path;
		}
		return null;
	}

	static function checkProjectXml(cwd:String) {
		var projectXml = findProjectXml(cwd);
		if (projectXml == null) {
			// Not in a project directory, skip silently.
			return;
		}
		var content = File.getContent(projectXml);
		if (content.indexOf("haxefmod") != -1) {
			pass("Project file includes haxefmod", projectXml);
		} else {
			fail("Project file includes haxefmod", 'Add <haxelib name="haxefmod" /> to $projectXml');
		}
	}

	static function checkBankFiles(cwd:String) {
		var bankPath = haxe.io.Path.join([cwd, "assets", "fmod", "Desktop", "Master.bank"]);
		if (findProjectXml(cwd) == null) {
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
		if (total == 0) {
			Sys.println("No checks ran.");
			return;
		}
		if (failCount == 0) {
			var notes = new Array<String>();
			if (warnCount > 0) notes.push('$warnCount warning' + (warnCount == 1 ? "" : "s"));
			if (skipCount > 0) notes.push('$skipCount skipped');
			var suffix = notes.length > 0 ? ' (${notes.join(", ")})' : "";
			Sys.println('All $total checks passed!$suffix');
		} else {
			Sys.println('$passCount/$total checks passed, $failCount failed.');
			// Scripts and CI rely on the exit code reflecting the result.
			Sys.exit(1);
		}
	}
}
