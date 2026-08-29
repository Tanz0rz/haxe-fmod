package haxefmod.tools;

import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;

/**
 * Compiles hlaxe_fmod.hdll from source against the user's FMOD SDK.
 *
 * For users whose FMOD version differs from the pre-built hdlls
 * (which target 2.03.12) to compile a compatible hdll for HashLink builds.
 *
 * Usage: haxelib run haxefmod build-hdll
 *
 * Requires:
 *   - $FMOD_SDK pointing to the FMOD Engine SDK
 *   - A C compiler (gcc on Linux, cc on Mac, cl on Windows)
 *   - HashLink headers (auto-detected from common locations or $HASHLINK_DIR)
 */
class BuildHdll {
	public static function run(libRoot:String, projectDir:String):Void {
		Sys.println("");
		Sys.println("haxefmod build-hdll - compiling hlaxe_fmod.hdll from source");
		Sys.println("");

		// 1. Validate FMOD_SDK
		var fmodSdk = Sys.getEnv("FMOD_SDK");
		if (fmodSdk == null || fmodSdk == "") {
			error("FMOD_SDK environment variable is not set.");
			Sys.println("  Set it to point to your FMOD Engine SDK directory:");
			Sys.println("  export FMOD_SDK=/path/to/fmodstudioapi");
			Sys.exit(1);
		}

		var coreInc = Path.join([fmodSdk, "api", "core", "inc"]);
		var studioInc = Path.join([fmodSdk, "api", "studio", "inc"]);
		if (!FileSystem.exists(Path.join([coreInc, "fmod.h"]))) {
			error('FMOD headers not found at: $coreInc');
			Sys.println("  Check that FMOD_SDK points to the correct directory.");
			Sys.exit(1);
		}

		// 2. Detect platform
		var platform = detectPlatform();
		info('Platform: $platform');

		// 3. Parse FMOD version from SDK headers
		var sdkHex = PostBuild.parseFmodVersion(Path.join([coreInc, "fmod_common.h"]));
		if (sdkHex == null) {
			error("Could not parse FMOD_VERSION from SDK headers.");
			Sys.exit(1);
		}
		var sdkVer = PostBuild.hexToVersion(sdkHex);
		info('FMOD SDK version: $sdkVer ($sdkHex)');

		// 4. Find HashLink headers
		var hlInclude = findHashlinkInclude(platform);
		if (hlInclude == null) {
			error("Could not find HashLink headers (hl.h).");
			Sys.println("  Searched common locations. Set HASHLINK_DIR to your HashLink installation:");
			Sys.println("  export HASHLINK_DIR=/path/to/hashlink");
			Sys.exit(1);
		}
		info('HashLink headers: $hlInclude');

		// 5. Check C compiler availability
		var compiler = getCompiler(platform);
		if (!compilerAvailable(compiler, platform)) {
			error('C compiler not found: $compiler');
			if (platform == "windows") {
				Sys.println("  Open a Visual Studio Developer Command Prompt, or run vcvars64.bat first.");
			} else {
				Sys.println("  Install gcc (Linux) or Xcode command-line tools (Mac).");
			}
			Sys.exit(1);
		}
		info('Compiler: $compiler');

		// 6. Validate FMOD link libraries exist
		var missingLibs = checkFmodLibs(fmodSdk, platform);
		if (missingLibs.length > 0) {
			error("FMOD link libraries not found:");
			for (lib in missingLibs) {
				Sys.println('    $lib');
			}
			Sys.println("");
			Sys.println("  Check that FMOD_SDK points to the correct SDK directory for your platform.");
			Sys.exit(1);
		}
		info("FMOD link libraries found");

		// 7. Build
		var sourceFile = Path.join([libRoot, "native", "hlaxe", "hlaxe_fmod.c"]);
		if (!FileSystem.exists(sourceFile)) {
			error('Source file not found: $sourceFile');
			Sys.exit(1);
		}

		var outputDir = Path.join([projectDir, ".haxefmod"]);
		if (!FileSystem.exists(outputDir)) {
			FileSystem.createDirectory(outputDir);
		}
		var outputFile = Path.join([outputDir, "hlaxe_fmod.hdll"]);

		Sys.println("");
		info("Compiling hlaxe_fmod.hdll...");

		var args = buildCompilerArgs(platform, sourceFile, outputFile, fmodSdk, coreInc, studioInc, hlInclude);
		info('Running: $compiler ${args.join(" ")}');
		Sys.println("");

		var exitCode = Sys.command(compiler, args);
		if (exitCode != 0) {
			Sys.println("");
			error('Compilation failed (exit code $exitCode).');
			Sys.exit(1);
		}

		// 7. Verify output exists
		if (!FileSystem.exists(outputFile)) {
			error("Compilation appeared to succeed but output file not found.");
			Sys.exit(1);
		}

		// 8. Write version marker file
		var versionFile = Path.join([outputDir, "hlaxe_fmod.version"]);
		File.saveContent(versionFile, sdkHex);

		Sys.println("");
		Sys.println("============================================================");
		Sys.println("  Successfully compiled hlaxe_fmod.hdll!");
		Sys.println("");
		Sys.println('  FMOD version:  $sdkVer');
		Sys.println('  Output:        $outputFile');
		Sys.println('  Version file:  $versionFile');
		Sys.println("");
		Sys.println("  The .haxefmod/ directory is project-local and survives");
		Sys.println("  library updates. Commit it to share with your team.");
		Sys.println("");
		Sys.println("  You can now run: lime build hl");
		Sys.println("============================================================");
		Sys.println("");
	}

	static function detectPlatform():String {
		var name = Sys.systemName();
		if (name == "Windows") return "windows";
		if (name == "Mac") return "mac";
		return "linux";
	}

	static function getCompiler(platform:String):String {
		return switch (platform) {
			case "mac": "cc";
			case "windows": "cl";
			default: "gcc";
		};
	}

	static function checkFmodLibs(fmodSdk:String, platform:String):Array<String> {
		var expected:Array<String> = switch (platform) {
			case "linux": [
				Path.join([fmodSdk, "api", "core", "lib", "x86_64", "libfmod.so"]),
				Path.join([fmodSdk, "api", "studio", "lib", "x86_64", "libfmodstudio.so"]),
			];
			case "mac": [
				Path.join([fmodSdk, "api", "core", "lib", "libfmod.dylib"]),
				Path.join([fmodSdk, "api", "studio", "lib", "libfmodstudio.dylib"]),
			];
			case "windows": [
				Path.join([fmodSdk, "api", "core", "lib", "x64", "fmod_vc.lib"]),
				Path.join([fmodSdk, "api", "studio", "lib", "x64", "fmodstudio_vc.lib"]),
			];
			default: [];
		};
		var missing:Array<String> = [];
		for (lib in expected) {
			if (!FileSystem.exists(lib)) missing.push(lib);
		}
		return missing;
	}

	static function compilerAvailable(compiler:String, platform:String):Bool {
		try {
			var testArgs = if (platform == "windows") [] else ["--version"];
			var proc = new sys.io.Process(compiler, testArgs);
			// Read output to prevent pipe blocking
			proc.stdout.readAll();
			proc.stderr.readAll();
			var code = proc.exitCode();
			proc.close();
			// cl.exe with no args exits non-zero but that's fine - it ran
			return platform == "windows" || code == 0;
		} catch (e:Dynamic) {
			return false;
		}
	}

	static function findHashlinkInclude(platform:String):Null<String> {
		// Check HASHLINK_DIR env var first
		var hlDir = Sys.getEnv("HASHLINK_DIR");
		if (hlDir != null && hlDir != "") {
			var inc = Path.join([hlDir, "include"]);
			if (FileSystem.exists(Path.join([inc, "hl.h"]))) return inc;
			// Maybe headers are directly in HASHLINK_DIR
			if (FileSystem.exists(Path.join([hlDir, "hl.h"]))) return hlDir;
		}

		// Platform-specific common locations
		var candidates:Array<String> = switch (platform) {
			case "mac": [
				// Homebrew (Apple Silicon)
				brewPrefix() + "/opt/hashlink/include",
				// Homebrew (Intel)
				"/usr/local/opt/hashlink/include",
				"/usr/local/include",
			];
			case "linux": [
				"/usr/local/include",
				"/usr/include",
			];
			case "windows": [
				// Common Windows HL install locations
				"C:\\HaxeToolkit\\hashlink",
				"C:\\hashlink",
			];
			default: [];
		};

		for (path in candidates) {
			if (FileSystem.exists(Path.join([path, "hl.h"]))) return path;
		}

		return null;
	}

	static function brewPrefix():String {
		try {
			var proc = new sys.io.Process("brew", ["--prefix"]);
			var out = StringTools.trim(proc.stdout.readAll().toString());
			proc.close();
			if (out != "") return out;
		} catch (e:Dynamic) {}
		return "/opt/homebrew";
	}

	static function macArch():String {
		var arch = Sys.getEnv("HAXEFMOD_HDLL_ARCH");
		return arch == null || arch == "" ? "x86_64" : arch;
	}

	static function buildCompilerArgs(platform:String, source:String, output:String, fmodSdk:String, coreInc:String,
			studioInc:String, hlInclude:String):Array<String> {
		return switch (platform) {
			case "linux":
				var coreLib = Path.join([fmodSdk, "api", "core", "lib", "x86_64"]);
				var studioLib = Path.join([fmodSdk, "api", "studio", "lib", "x86_64"]);
				[
					"-shared", "-fPIC", "-O2",
					"-Wl,-rpath,$ORIGIN",
					"-o", output,
					source,
					'-I$hlInclude',
					'-I$coreInc',
					'-I$studioInc',
					'-L$coreLib',
					'-L$studioLib',
					"-lfmod", "-lfmodstudio", "-lpthread",
				];
			case "mac":
				var coreLib = Path.join([fmodSdk, "api", "core", "lib"]);
				var studioLib = Path.join([fmodSdk, "api", "studio", "lib"]);
				[
					"-dynamiclib", "-O2",
					// x86_64 matches lime's bundled HashLink VM. An arm64 HashLink
					// (Homebrew's libhl, HL/C builds) needs HAXEFMOD_HDLL_ARCH=arm64.
					"-arch", macArch(),
					"-install_name", "@executable_path/hlaxe_fmod.hdll",
					"-o", output,
					source,
					'-I$hlInclude',
					'-I$coreInc',
					'-I$studioInc',
					'-L$coreLib',
					'-L$studioLib',
					"-lfmod", "-lfmodstudio", "-lpthread",
				];
			case "windows":
				var coreLib = Path.join([fmodSdk, "api", "core", "lib", "x64"]);
				var studioLib = Path.join([fmodSdk, "api", "studio", "lib", "x64"]);
				// Find libhl.lib
				var hlLib = findHashlinkLib(hlInclude);
				var args = [
					"/LD", "/O2", "/DWIN32",
					source,
					// cl writes the .obj into the process cwd by default,
					// which under haxelib run is the installed library
					// directory (possibly read-only)
					"/Fo" + Path.join([Path.directory(output), "hlaxe_fmod.obj"]),
					'/I$hlInclude',
					'/I$coreInc',
					'/I$studioInc',
					"/link",
					'/LIBPATH:$coreLib',
					'/LIBPATH:$studioLib',
					"fmod_vc.lib", "fmodstudio_vc.lib",
				];
				if (hlLib != null) {
					args.push('/LIBPATH:$hlLib');
				}
				args.push("libhl.lib");
				args.push('/OUT:$output');
				args;
			default: [];
		};
	}

	static function findHashlinkLib(hlInclude:String):Null<String> {
		// Check for libhl.lib in common locations relative to hl.h
		var parent = Path.directory(hlInclude);
		var candidates = [
			Path.join([parent, "lib"]),
			parent,
			hlInclude,
		];
		for (path in candidates) {
			if (FileSystem.exists(Path.join([path, "libhl.lib"]))) return path;
		}

		// Check HASHLINK_DIR directly
		var hlDir = Sys.getEnv("HASHLINK_DIR");
		if (hlDir != null && hlDir != "") {
			if (FileSystem.exists(Path.join([hlDir, "libhl.lib"]))) return hlDir;
		}

		return null;
	}

	static function info(msg:String):Void {
		Sys.println('  $msg');
	}

	static function error(msg:String):Void {
		Sys.println('  ERROR: $msg');
	}
}
