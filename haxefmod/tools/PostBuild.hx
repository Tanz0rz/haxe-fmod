package haxefmod.tools;

import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;

/**
 * Post-build script to copy FMOD shared libraries to lime's output directory.
 * Called automatically by lime via <postbuild> in include.xml.
 *
 * Replaces scripts/postbuild-copy-fmod.sh with pure Haxe — no bash dependency.
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
		verifyVersion(libRoot, sdkPath, sdkEnvName);

		// Use project directory for finding export/ output
		var exportDir = Path.join([projectDir, "export"]);

		switch (platform) {
			case "mac":
				copyMac(sdkPath, target, libRoot, exportDir);
			case "linux":
				copyLinux(sdkPath, target, libRoot, exportDir);
			case "windows":
				copyWindows(sdkPath, target, libRoot, exportDir);
			case "html5":
				copyHtml5(sdkPath, exportDir);
			default:
				log('Unknown platform: $platform (expected mac, linux, windows, or html5)');
				Sys.exit(1);
		}
	}

	//// Version verification

	static function verifyVersion(libRoot:String, sdkPath:String, sdkEnvName:String):Void {
		var versionFile = Path.join([libRoot, "scripts", "fmod_expected_version"]);
		var sdkHeader = Path.join([sdkPath, "api", "core", "inc", "fmod_common.h"]);

		if (!FileSystem.exists(versionFile) || !FileSystem.exists(sdkHeader)) {
			log("WARNING: Could not verify FMOD SDK version");
			if (!FileSystem.exists(versionFile)) log('  Missing: $versionFile');
			if (!FileSystem.exists(sdkHeader)) log('  Missing: $sdkHeader');
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

		// Version mismatch — check for user-compiled hdll via marker file
		// (HTML5 doesn't use hdlls, so marker files don't apply)
		if (sdkEnvName != "FMOD_SDK_WEB") {
			var platform = detectPlatform();
			var platformDir = switch (platform) {
				case "mac": "Mac64";
				case "windows": "Windows64";
				default: "Linux64";
			};
			var markerFile = Path.join([libRoot, "templates", "bin", "hl", platformDir, "hlaxe_fmod.version"]);
			if (FileSystem.exists(markerFile)) {
				var markerHex = StringTools.trim(File.getContent(markerFile));
				if (markerHex == sdkHex) {
					var ver = hexToVersion(sdkHex);
					log('FMOD SDK version $ver - OK (custom-compiled hdll)');
					return;
				}
			}
		}

		var expectedVer = hexToVersion(expectedHex);
		var sdkVer = hexToVersion(sdkHex);

		// Check for strict mode (old hard-fail behavior)
		var strict = Sys.getEnv("FMOD_STRICT_VERSION");
		if (strict == "1") {
			Sys.println("");
			Sys.println("============================================================");
			Sys.println('  ERROR: FMOD SDK version mismatch!');
			Sys.println("");
			if (sdkEnvName == "FMOD_SDK_WEB") {
				Sys.println('  Your FMOD SDK Web:    $sdkVer');
			} else {
				Sys.println('  Your FMOD SDK:        $sdkVer');
			}
			Sys.println('  haxe-fmod expects:    $expectedVer');
			Sys.println("");
			Sys.println("  Download the correct version from https://www.fmod.com/download");
			Sys.println("============================================================");
			Sys.println("");
			Sys.exit(1);
		}

		// Warn and suggest build-hdll instead of hard-failing
		Sys.println("");
		Sys.println("============================================================");
		Sys.println('  WARNING: FMOD SDK version mismatch');
		Sys.println("");
		if (sdkEnvName == "FMOD_SDK_WEB") {
			Sys.println('  Your FMOD SDK Web:    $sdkVer');
			Sys.println('  haxe-fmod expects:    $expectedVer');
			Sys.println("");
			Sys.println("  Download the correct version from https://www.fmod.com/download");
		} else {
			Sys.println('  Your FMOD SDK:        $sdkVer');
			Sys.println('  Pre-built hdll:       $expectedVer');
			Sys.println("");
			Sys.println("  To compile an hdll matching your SDK, run:");
			Sys.println("    haxelib run haxefmod build-hdll");
			Sys.println("");
			Sys.println("  Or download FMOD $expectedVer from https://www.fmod.com/download");
		}
		Sys.println("============================================================");
		Sys.println("");

		// For HTML5, still fail — there are no pre-compiled binaries to swap
		if (sdkEnvName == "FMOD_SDK_WEB") {
			Sys.exit(1);
		}
	}

	static function detectPlatform():String {
		var name = Sys.systemName();
		if (name == "Windows") return "windows";
		if (name == "Mac") return "mac";
		return "linux";
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

	//// Mac

	static function copyMac(sdkDir:String, target:String, libRoot:String, exportDir:String):Void {
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

		// Copy hlaxe_fmod.hdll from templates
		if (target == "hl") {
			var hdllSrc = Path.join([libRoot, "templates", "bin", "hl", "Mac64", "hlaxe_fmod.hdll"]);
			if (FileSystem.exists(hdllSrc)) {
				copyFile(hdllSrc, Path.join([dest, "hlaxe_fmod.hdll"]));
				log("Copied hlaxe_fmod.hdll");
			}
		}

		// Set rpath so executable finds dylibs next to it (C++ only — HL exe is bytecode, not Mach-O)
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

	static function copyLinux(sdkDir:String, target:String, libRoot:String, exportDir:String):Void {
		var binDir = findBinDir(exportDir, target, "linux");

		if (binDir == null) {
			log("No bin directory found in export/ - skipping FMOD lib copy");
			return;
		}

		log('Copying FMOD shared libraries to $binDir');

		// Copy .so files preserving symlinks (must use cp -P)
		copyGlobSymlinks(Path.join([sdkDir, "api", "core", "lib", "x86_64"]), "libfmod.so", binDir);
		copyGlobSymlinks(Path.join([sdkDir, "api", "studio", "lib", "x86_64"]), "libfmodstudio.so", binDir);

		// Copy hlaxe_fmod.hdll from templates
		if (target == "hl") {
			var hdllSrc = Path.join([libRoot, "templates", "bin", "hl", "Linux64", "hlaxe_fmod.hdll"]);
			if (FileSystem.exists(hdllSrc)) {
				copyFile(hdllSrc, Path.join([binDir, "hlaxe_fmod.hdll"]));
				log("Copied hlaxe_fmod.hdll");
			}
		}

		// Create run.sh wrapper if it doesn't exist
		var runSh = Path.join([binDir, "run.sh"]);
		if (!FileSystem.exists(runSh)) {
			var exeName = findExecutableName(binDir, [".so", ".hdll"]);
			if (exeName != null) {
				var content = '#!/bin/bash\ncd "$$(dirname "$$0")"\nexport LD_LIBRARY_PATH="$$(pwd):$$LD_LIBRARY_PATH"\n./${exeName} "$$@"\n';
				File.saveContent(runSh, content);
				Sys.command("chmod", ["+x", runSh]);
			}
		}

		log("Done - copied FMOD .so files");
	}

	//// Windows

	static function copyWindows(sdkDir:String, target:String, libRoot:String, exportDir:String):Void {
		var binDir = findBinDir(exportDir, target, "windows");

		if (binDir == null) {
			log("No bin directory found in export/ - skipping FMOD lib copy");
			return;
		}

		log('Copying FMOD DLLs to $binDir');

		copyFile(Path.join([sdkDir, "api", "core", "lib", "x64", "fmod.dll"]), Path.join([binDir, "fmod.dll"]));
		copyFile(Path.join([sdkDir, "api", "studio", "lib", "x64", "fmodstudio.dll"]), Path.join([binDir, "fmodstudio.dll"]));

		// Copy hlaxe_fmod.hdll from templates
		if (target == "hl") {
			var hdllSrc = Path.join([libRoot, "templates", "bin", "hl", "Windows64", "hlaxe_fmod.hdll"]);
			if (FileSystem.exists(hdllSrc)) {
				copyFile(hdllSrc, Path.join([binDir, "hlaxe_fmod.hdll"]));
				log("Copied hlaxe_fmod.hdll");
			}
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
		if (!FileSystem.exists(srcDir)) return;
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
				if (StringTools.endsWith(file, ext)) {
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
