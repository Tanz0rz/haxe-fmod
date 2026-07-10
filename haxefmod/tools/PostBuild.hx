package haxefmod.tools;

import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;

/**
 * Post-build script to copy FMOD shared libraries to lime's output directory.
 * Called automatically by lime via <postbuild> in include.xml.
 *
 * Replaces scripts/postbuild-copy-fmod.sh with pure Haxe - no bash dependency.
 */
class PostBuild {
	public static function run(platform:String, target:String, libRoot:String, projectDir:String):Void {
		var sdkEnvName = platform == "html5" ? "FMOD_SDK_WEB" : "FMOD_SDK";
		var sdkPath = Sys.getEnv(sdkEnvName);

		if (sdkPath == null || sdkPath == "") {
			if (platform == "html5") {
				printSdkWebError();
			} else {
				printSdkError();
			}
			Sys.exit(1);
		}

		// Version check
		verifyVersion(libRoot, sdkPath, sdkEnvName, projectDir, target);

		// Use project directory for finding export/ output
		var exportDir = Path.join([projectDir, "export"]);

		switch (platform) {
			case "mac":
				copyMac(sdkPath, target, libRoot, exportDir, projectDir);
			case "linux":
				copyLinux(sdkPath, target, libRoot, exportDir, projectDir);
			case "windows":
				copyWindows(sdkPath, target, libRoot, exportDir, projectDir);
			case "html5":
				copyHtml5(sdkPath, exportDir);
			default:
				log('Unknown platform: $platform (expected mac, linux, windows, or html5)');
				Sys.exit(1);
		}
	}

	//// Version verification

	static function verifyVersion(libRoot:String, sdkPath:String, sdkEnvName:String, projectDir:String, target:String):Void {
		var versionFile = Path.join([libRoot, "fmod_expected_version"]);
		var sdkHeader = Path.join([sdkPath, "api", "core", "inc", "fmod_common.h"]);

		// A set-but-wrong SDK path is provably not an SDK: hard error, the
		// same class of failure as an unset variable. A soft warning here
		// used to let typo'd paths skip the version gate entirely and ship
		// builds that only ran when stale libraries were still in export/.
		if (!FileSystem.exists(sdkHeader)) {
			log('ERROR: $sdkEnvName is set but does not point at an FMOD SDK');
			log('  $sdkEnvName = $sdkPath');
			log('  Missing: $sdkHeader');
			log("  Check the path for typos, or re-download the FMOD Engine from https://www.fmod.com/download");
			log("  Verify your setup with: haxelib run haxefmod check");
			Sys.exit(1);
		}

		// The lib-side expected-version file going missing is a packaging
		// problem, not a user setup problem - warn and continue
		if (!FileSystem.exists(versionFile)) {
			log("WARNING: Could not verify FMOD SDK version");
			log('  Missing: $versionFile');
			return;
		}

		var expectedHex = StringTools.trim(File.getContent(versionFile));
		var sdkHex = parseFmodVersion(sdkHeader);

		if (sdkHex == null) {
			log("WARNING: Could not parse FMOD_VERSION from SDK header");
			return;
		}

		if (expectedHex == sdkHex) {
			var ver = hexToVersion(expectedHex);
			if (sdkEnvName == "FMOD_SDK_WEB") {
				log('FMOD SDK Web version $ver - OK');
			} else {
				log('FMOD SDK version $ver - OK');
			}
			return;
		}

		// Version mismatch - check for project-local custom-compiled hdll via marker file
		// (HTML5 doesn't use hdlls, so marker files don't apply)
		if (sdkEnvName != "FMOD_SDK_WEB") {
			var markerFile = Path.join([projectDir, ".haxefmod", "hlaxe_fmod.version"]);
			if (FileSystem.exists(markerFile)) {
				var markerHex = StringTools.trim(File.getContent(markerFile));
				if (markerHex == sdkHex) {
					var ver = hexToVersion(sdkHex);
					log('FMOD SDK version $ver - OK (custom-compiled hdll from .haxefmod/)');
					return;
				}
			}
		}

		var expectedVer = hexToVersion(expectedHex);
		var sdkVer = hexToVersion(sdkHex);

		// HL builds: mismatched hdll/SDK will crash at runtime - hard error
		if (target == "hl") {
			Sys.println("");
			Sys.println("============================================================");
			Sys.println('  ERROR: FMOD SDK version mismatch');
			Sys.println("");
			Sys.println('  Your FMOD SDK:        $sdkVer');
			Sys.println('  Pre-built hdll:       $expectedVer');
			Sys.println("");
			Sys.println("  To compile an hdll matching your SDK, run:");
			Sys.println("    haxelib run haxefmod build-hdll");
			Sys.println("");
			Sys.println('  Or download FMOD $expectedVer from https://www.fmod.com/download');
			Sys.println("============================================================");
			Sys.println("");
			Sys.exit(1);
		}

		// Other targets: informational warning only (C++ compiles from source)
		Sys.println("");
		Sys.println("============================================================");
		Sys.println('  WARNING: FMOD SDK version mismatch');
		Sys.println("");
		Sys.println('  Your FMOD SDK:        $sdkVer');
		Sys.println('  haxe-fmod expects:    $expectedVer');
		Sys.println("");
		Sys.println("  Download the correct version from https://www.fmod.com/download");
		Sys.println("============================================================");
		Sys.println("");
	}

	public static function parseFmodVersion(headerPath:String):Null<String> {
		var content = File.getContent(headerPath);
		for (line in content.split("\n")) {
			if (line.indexOf("FMOD_VERSION") != -1 && line.indexOf("#define") != -1) {
				var idx = line.indexOf("0x");
				if (idx != -1) {
					// Extract the hex string (e.g. "0x00020312")
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

	public static function hexToVersion(hex:String):String {
		var val = Std.parseInt(hex);
		if (val == null) return hex;
		var hexStr = StringTools.hex(val, 8);
		var product = Std.parseInt("0x" + hexStr.substr(0, 4));
		var major = hexStr.substr(4, 2);
		var minor = hexStr.substr(6, 2);
		return '$product.$major.$minor';
	}

	//// hdll resolution (HL target)

	// Expected ABI version comes from the manifest header ("# abi-version: N").
	static function expectedAbiVersion(libRoot:String):Int {
		var manifestPath = Path.join([libRoot, "native", "manifest", "studio_api.txt"]);
		if (!FileSystem.exists(manifestPath)) return -1;
		for (line in File.getContent(manifestPath).split("\n")) {
			var trimmed = StringTools.trim(line);
			if (StringTools.startsWith(trimmed, "# abi-version:")) {
				var parsed = Std.parseInt(StringTools.trim(trimmed.substr("# abi-version:".length)));
				return parsed == null ? -1 : parsed;
			}
		}
		return -1;
	}

	// Scans the hdll binary for the embedded "hlaxe_fmod_abi=<N>" marker.
	// Returns the version, or 0 when no marker exists (a pre-2.0 hdll).
	static function scanHdllAbi(hdllPath:String):Int {
		var bytes = File.getBytes(hdllPath);
		var marker = "hlaxe_fmod_abi=";
		var limit = bytes.length - marker.length - 4;
		var i = 0;
		while (i < limit) {
			var matched = true;
			for (j in 0...marker.length) {
				if (bytes.get(i + j) != marker.charCodeAt(j)) {
					matched = false;
					break;
				}
			}
			if (matched) {
				var digits = "";
				var k = i + marker.length;
				while (k < bytes.length) {
					var c = bytes.get(k);
					if (c < "0".code || c > "9".code) break;
					digits += String.fromCharCode(c);
					k++;
				}
				var parsed = Std.parseInt(digits);
				return parsed == null ? 0 : parsed;
			}
			i++;
		}
		return 0;
	}

	// Tiered hdll resolution (project-local .haxefmod/ then pre-built) with a
	// binding ABI check: an hdll compiled against an older native surface is
	// missing prims and dies with a loader fatal at startup, so the build is
	// stopped here with instructions instead.
	static function copyHdll(projectDir:String, libRoot:String, platformDir:String, destDir:String):Void {
		var projectHdll = Path.join([projectDir, ".haxefmod", "hlaxe_fmod.hdll"]);
		var prebuiltHdll = Path.join([libRoot, "templates", "bin", "hl", platformDir, "hlaxe_fmod.hdll"]);
		var source:String = null;
		var flavor:String = null;
		if (FileSystem.exists(projectHdll)) {
			source = projectHdll;
			flavor = "custom-compiled from .haxefmod/";
		} else if (FileSystem.exists(prebuiltHdll)) {
			source = prebuiltHdll;
			flavor = "pre-built";
		}
		if (source == null) return;

		var expected = expectedAbiVersion(libRoot);
		if (expected > 0) {
			var found = scanHdllAbi(source);
			if (found != expected) {
				Sys.println("");
				Sys.println("  ==========================================================");
				Sys.println("  ERROR: hlaxe_fmod.hdll binding version mismatch");
				Sys.println("");
				Sys.println('  hdll: $source');
				Sys.println('  hdll binding ABI:     ' + (found == 0 ? "unknown (older than 2.0)" : Std.string(found)));
				Sys.println('  library expects ABI:  $expected');
				Sys.println("");
				Sys.println("  This hdll was compiled against a different native surface and");
				Sys.println("  would fail to load at startup. To compile a matching hdll, run:");
				Sys.println("    haxelib run haxefmod build-hdll");
				Sys.println("  from your project directory, then rebuild.");
				Sys.println("  ==========================================================");
				Sys.println("");
				Sys.exit(1);
			}
		}

		copyFile(source, Path.join([destDir, "hlaxe_fmod.hdll"]));
		log('Copied hlaxe_fmod.hdll ($flavor)');
	}

	//// Mac

	static function copyMac(sdkDir:String, target:String, libRoot:String, exportDir:String, projectDir:String):Void {
		// Find .app bundle in export directory
		var appDir:String = null;
		if (target == "hl") {
			appDir = findAppBundle(Path.join([exportDir, "hl"]));
		} else {
			// C++ Mac builds: search for .app in any subdir containing "mac"
			appDir = findAppBundleInPlatformDir(exportDir, "mac");
		}

		if (appDir == null) {
			log("No .app bundle found in export/ - skipping FMOD lib copy");
			return;
		}

		var dest = Path.join([appDir, "Contents", "MacOS"]);
		log('Copying FMOD dylibs to $dest');

		copyFile(Path.join([sdkDir, "api", "core", "lib", "libfmod.dylib"]), Path.join([dest, "libfmod.dylib"]));
		copyFile(Path.join([sdkDir, "api", "studio", "lib", "libfmodstudio.dylib"]), Path.join([dest, "libfmodstudio.dylib"]));

		// Copy hlaxe_fmod.hdll - tiered resolution with binding ABI check
		if (target == "hl") {
			copyHdll(projectDir, libRoot, "Mac64", dest);
		}

		// Set rpath so executable finds dylibs next to it (C++ only - HL exe is bytecode, not Mach-O)
		// Use Process to suppress stderr: rpath may already exist from lime/hxcpp
		if (target != "hl") {
			var exe = findExecutable(dest, [".dylib", ".ndll", ".hdll"]);
			if (exe != null) {
				try {
					var proc = new sys.io.Process("install_name_tool", ["-add_rpath", "@executable_path", exe]);
					proc.exitCode();
					proc.close();
				} catch (e:Dynamic) {}
			}
		}

		log("Done - copied libfmod.dylib and libfmodstudio.dylib");
	}

	//// Linux

	static function copyLinux(sdkDir:String, target:String, libRoot:String, exportDir:String, projectDir:String):Void {
		var binDir = findBinDir(exportDir, target, "linux");

		if (binDir == null) {
			log("No bin directory found in export/ - skipping FMOD lib copy");
			return;
		}

		log('Copying FMOD shared libraries to $binDir');

		// Copy .so files preserving symlinks (must use cp -P)
		copyGlobSymlinks(Path.join([sdkDir, "api", "core", "lib", "x86_64"]), "libfmod.so", binDir);
		copyGlobSymlinks(Path.join([sdkDir, "api", "studio", "lib", "x86_64"]), "libfmodstudio.so", binDir);

		// Copy hlaxe_fmod.hdll - tiered resolution with binding ABI check
		if (target == "hl") {
			copyHdll(projectDir, libRoot, "Linux64", binDir);
		}

		// Modern Linux kernels refuse to load libraries flagged with an
		// executable stack, and FMOD ships its .so files that way. CI has
		// always cleared the flag as a separate step. Do it here so plain
		// `lime test linux` works on end-user machines too. Silently skipped
		// when patchelf is not installed (older kernels do not need it).
		clearExecstack(binDir);

		// Create run.sh wrapper if it doesn't exist
		var runSh = Path.join([binDir, "run.sh"]);
		if (!FileSystem.exists(runSh)) {
			// .dat excluded: HL builds ship hlboot.dat next to the exe and
			// run.sh must never point at it
			var exeName = findExecutableName(binDir, [".so", ".hdll", ".ndll", ".dat"]);
			if (exeName != null) {
				var content = '#!/bin/bash\ncd "$$(dirname "$$0")"\nexport LD_LIBRARY_PATH="$$(pwd):$$LD_LIBRARY_PATH"\n./${exeName} "$$@"\n';
				File.saveContent(runSh, content);
				Sys.command("chmod", ["+x", runSh]);
			}
		}

		log("Done - copied FMOD .so files");
	}

	/** Clears the executable-stack flag on every FMOD .so in the directory. */
	static function clearExecstack(binDir:String):Void {
		for (file in FileSystem.readDirectory(binDir)) {
			if (file.indexOf("libfmod") != 0 || file.indexOf(".so") == -1) continue;
			var path = Path.join([binDir, file]);
			if (isSymlink(path)) continue;
			try {
				var proc = new sys.io.Process("patchelf", ["--clear-execstack", path]);
				var code = proc.exitCode();
				proc.close();
				if (code == 0) {
					log('Cleared executable-stack flag on $file');
				}
			} catch (e:Dynamic) {
				log("patchelf not found - skipped execstack clearing (needed on modern kernels). Install patchelf if the game fails to load libfmod.");
				return;
			}
		}
	}

	static function isSymlink(path:String):Bool {
		// Haxe sys has no lstat. Test -L works everywhere PostBuild handles symlinks (Linux only)
		try {
			var proc = new sys.io.Process("test", ["-L", path]);
			var code = proc.exitCode();
			proc.close();
			return code == 0;
		} catch (e:Dynamic) {
			return false;
		}
	}

	//// Windows

	static function copyWindows(sdkDir:String, target:String, libRoot:String, exportDir:String, projectDir:String):Void {
		var binDir = findBinDir(exportDir, target, "windows");

		if (binDir == null) {
			log("No bin directory found in export/ - skipping FMOD lib copy");
			return;
		}

		log('Copying FMOD DLLs to $binDir');

		copyFile(Path.join([sdkDir, "api", "core", "lib", "x64", "fmod.dll"]), Path.join([binDir, "fmod.dll"]));
		copyFile(Path.join([sdkDir, "api", "studio", "lib", "x64", "fmodstudio.dll"]), Path.join([binDir, "fmodstudio.dll"]));

		// Copy hlaxe_fmod.hdll - tiered resolution with binding ABI check
		if (target == "hl") {
			copyHdll(projectDir, libRoot, "Windows64", binDir);
		}

		log("Done - copied fmod.dll and fmodstudio.dll");
	}

	//// HTML5

	static function copyHtml5(sdkDir:String, exportDir:String):Void {
		var binDir = findBinDir(exportDir, "html5", "html5");
		if (binDir == null) {
			log("No html5/bin directory found - skipping FMOD file replacement");
			return;
		}

		log("Replacing FMOD placeholder files with real SDK files");

		var libDir = Path.join([binDir, "lib"]);
		if (!FileSystem.exists(libDir)) FileSystem.createDirectory(libDir);

		var jsSrc = Path.join([sdkDir, "api", "studio", "lib", "wasm", "fmodstudio.js"]);
		if (FileSystem.exists(jsSrc)) {
			copyFile(jsSrc, Path.join([libDir, "fmodstudio.js"]));
			log("Replaced fmodstudio.js");
		} else {
			log('ERROR: $jsSrc not found');
			Sys.exit(1);
		}

		var wasmSrc = Path.join([sdkDir, "api", "studio", "lib", "wasm", "fmodstudio.wasm"]);
		if (FileSystem.exists(wasmSrc)) {
			copyFile(wasmSrc, Path.join([libDir, "fmodstudio.wasm"]));
			log("Replaced fmodstudio.wasm");
		} else {
			log('ERROR: $wasmSrc not found');
			Sys.exit(1);
		}

		log("Done - FMOD files ready for HTML5");
	}

	//// Directory finding

	/**
	 * Find the bin directory for a given target and platform.
	 * Lime export structure: export/<target>/bin or export/<platform>/bin
	 */
	static function findBinDir(exportDir:String, target:String, platform:String):Null<String> {
		if (target == "hl") {
			// HL builds: export/hl/bin
			var dir = Path.join([exportDir, "hl", "bin"]);
			if (FileSystem.exists(dir) && FileSystem.isDirectory(dir)) return dir;
		} else if (target == "html5") {
			// HTML5 builds: export/html5/bin
			var dir = Path.join([exportDir, "html5", "bin"]);
			if (FileSystem.exists(dir) && FileSystem.isDirectory(dir)) return dir;
		} else {
			// C++ builds: export/<platform>/bin (e.g. export/linux/bin)
			var dir = Path.join([exportDir, platform, "bin"]);
			if (FileSystem.exists(dir) && FileSystem.isDirectory(dir)) return dir;

			// Fallback: search for a directory starting with the platform name
			if (FileSystem.exists(exportDir)) {
				try {
					for (entry in FileSystem.readDirectory(exportDir)) {
						if (StringTools.startsWith(entry.toLowerCase(), platform)) {
							var binDir = Path.join([exportDir, entry, "bin"]);
							if (FileSystem.exists(binDir) && FileSystem.isDirectory(binDir)) return binDir;
						}
					}
				} catch (e:Dynamic) {}
			}
		}
		return null;
	}

	/** Find a .app bundle directory recursively under the given directory. */
	static function findAppBundle(dir:String):Null<String> {
		if (!FileSystem.exists(dir) || !FileSystem.isDirectory(dir)) return null;
		try {
			for (entry in FileSystem.readDirectory(dir)) {
				var full = Path.join([dir, entry]);
				if (FileSystem.isDirectory(full)) {
					if (StringTools.endsWith(entry, ".app")) return full;
					var result = findAppBundle(full);
					if (result != null) return result;
				}
			}
		} catch (e:Dynamic) {}
		return null;
	}

	/** Find a .app bundle in export subdirectories that contain a platform name. */
	static function findAppBundleInPlatformDir(exportDir:String, platform:String):Null<String> {
		if (!FileSystem.exists(exportDir)) return null;
		try {
			for (entry in FileSystem.readDirectory(exportDir)) {
				if (entry.toLowerCase().indexOf(platform) != -1) {
					var result = findAppBundle(Path.join([exportDir, entry]));
					if (result != null) return result;
				}
			}
		} catch (e:Dynamic) {}
		return null;
	}

	//// Other utility functions

	static function log(msg:String):Void {
		Sys.println('[haxefmod postbuild] $msg');
	}

	static function copyFile(src:String, dst:String):Void {
		File.copy(src, dst);
	}

	/** Copy files matching a prefix from srcDir to destDir, preserving symlinks on Linux. */
	static function copyGlobSymlinks(srcDir:String, prefix:String, destDir:String):Void {
		// Copying nothing silently produced binaries that only launched when
		// stale libraries from an earlier build were still in the bin dir
		if (!FileSystem.exists(srcDir)) {
			log('ERROR: FMOD library directory not found: $srcDir');
			log("  The FMOD_SDK directory has no libraries for this platform, so the");
			log("  build output would fail to launch. Re-download the FMOD Engine or");
			log("  fix FMOD_SDK, then rebuild.");
			Sys.exit(1);
		}
		var files = FileSystem.readDirectory(srcDir);
		for (file in files) {
			if (StringTools.startsWith(file, prefix)) {
				// Use cp -P to preserve symlinks
				Sys.command("cp", ["-P", Path.join([srcDir, file]), Path.join([destDir, file])]);
			}
		}
	}

	/** Find the full path to the executable in a directory (by excluding known library extensions). */
	static function findExecutable(dir:String, excludeExts:Array<String>):Null<String> {
		if (!FileSystem.exists(dir)) return null;
		for (file in FileSystem.readDirectory(dir)) {
			if (file == "run.sh") continue;
			var excluded = false;
			for (ext in excludeExts) {
				// Use indexOf instead of endsWith to catch versioned files like libfmod.so.14
				if (file.indexOf(ext) != -1) {
					excluded = true;
					break;
				}
			}
			if (excluded) continue;
			var fullPath = Path.join([dir, file]);
			if (!FileSystem.isDirectory(fullPath)) return fullPath;
		}
		return null;
	}

	/** Find just the filename of the executable in a directory. */
	static function findExecutableName(dir:String, excludeExts:Array<String>):Null<String> {
		var path = findExecutable(dir, excludeExts);
		if (path == null) return null;
		return Path.withoutDirectory(path);
	}

	//// Error messages

	static function printSdkError():Void {
		Sys.println("");
		Sys.println("============================================================");
		Sys.println("  ERROR: FMOD_SDK environment variable is not set.");
		Sys.println("");
		Sys.println("  Your build will NOT work without FMOD libraries!");
		Sys.println("  You will see: Failed to load library hlaxe_fmod.hdll");
		Sys.println("============================================================");
		Sys.println("");
		Sys.println("  haxe-fmod requires you to supply your own FMOD Engine SDK.");
		Sys.println("");
		Sys.println("  1. Download FMOD Engine from https://www.fmod.com/download");
		Sys.println("     - All platforms: version 2.03.12");
		Sys.println("");
		Sys.println("  2. Install/extract it and set FMOD_SDK to point to the SDK directory.");
		Sys.println("");
		Sys.println("     export FMOD_SDK=/path/to/fmodstudioapi20312");
		Sys.println("");
		Sys.println("     Note: Set FMOD_SDK to the installed/extracted SDK directory.");
		Sys.println("           Switch FMOD_SDK when building for different platforms.");
		Sys.println("");
		Sys.println("  3. Run 'haxelib run haxefmod check' to verify your setup.");
		Sys.println("");
		Sys.println("============================================================");
		Sys.println("");
	}

	static function printSdkWebError():Void {
		Sys.println("");
		Sys.println("============================================================");
		Sys.println("  ERROR: FMOD_SDK_WEB environment variable is not set.");
		Sys.println("");
		Sys.println("  HTML5 builds require the FMOD Engine SDK for HTML5.");
		Sys.println("");
		Sys.println("  1. Download FMOD Engine 2.03.12 for HTML5 from:");
		Sys.println("     https://www.fmod.com/download");
		Sys.println("");
		Sys.println("  2. Extract it and set FMOD_SDK_WEB:");
		Sys.println("");
		Sys.println("     export FMOD_SDK_WEB=/path/to/fmodstudioapi20312html5");
		Sys.println("");
		Sys.println("     Or on Windows:");
		Sys.println("     set FMOD_SDK_WEB=C:\\path\\to\\fmodstudioapi20312html5");
		Sys.println("");
		Sys.println("  3. Run 'haxelib run haxefmod check' to verify your setup.");
		Sys.println("");
		Sys.println("============================================================");
		Sys.println("");
	}
}
