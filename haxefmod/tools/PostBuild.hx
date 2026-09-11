package haxefmod.tools;

import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;

/**
 * Copies the FMOD runtime files a build needs to launch (shared libraries,
 * the HashLink hdll, the html5 engine scripts) into a build output
 * directory.
 *
 * Two entry points share the copy code. run() is what lime calls from
 * include.xml and finds the output directory in lime's export/ layout.
 * stage() takes the directory as an argument and is for builds lime does
 * not drive (Heaps hxml builds, Kha's khamake, plain haxe).
 */
class PostBuild {
	public static function run(platform:String, target:String, libRoot:String, projectDir:String):Void {
		var sdkPath = checkSdk(platform, target, libRoot, projectDir);

		// Use project directory for finding export/ output.
		var exportDir = Path.join([projectDir, "export"]);
		var dest = findLimeOutputDir(platform, target, exportDir);
		if (dest == null) {
			if (platform == "mac") {
				log("No .app bundle found in export/ - skipping FMOD lib copy");
			} else if (platform == "html5") {
				log("No html5/bin directory found - skipping FMOD file replacement");
			} else {
				log("No bin directory found in export/ - skipping FMOD lib copy");
			}
			return;
		}
		stageInto(platform, target, sdkPath, libRoot, projectDir, dest, false);
	}

	/**
	 * Stages the FMOD runtime files into destDir, creating it if needed.
	 * platform is mac, linux, windows or html5. target is hl when the
	 * program loads hlaxe_fmod.hdll at runtime (the HashLink VM, HL/C
	 * output linked against libhl). target is cpp when the binding
	 * compiles into the executable (hxcpp, Kha's Kore and Kore HL builds).
	 * html5 ignores target.
	 */
	public static function stage(platform:String, target:String, libRoot:String, projectDir:String, destDir:String):Void {
		if (["mac", "linux", "windows", "html5"].indexOf(platform) == -1) {
			log('Unknown platform: $platform (expected mac, linux, windows, or html5)');
			Sys.exit(1);
		}
		if (platform == "html5") {
			target = "html5";
		} else if (target != "hl" && target != "cpp") {
			log('Unknown target: $target (expected hl or cpp)');
			Sys.exit(1);
		}
		var sdkPath = checkSdk(platform, target, libRoot, projectDir);
		if (!FileSystem.exists(destDir)) FileSystem.createDirectory(destDir);
		if (!FileSystem.isDirectory(destDir)) {
			log('ERROR: $destDir is not a directory');
			Sys.exit(1);
		}
		stageInto(platform, target, sdkPath, libRoot, projectDir, destDir, true);
	}

	/**
	 * Resolves the SDK env var for the platform. Stops the build when it
	 * is unset, points at the wrong package, or holds a version this
	 * release cannot use. Returns the SDK path.
	 */
	static function checkSdk(platform:String, target:String, libRoot:String, projectDir:String):String {
		var sdkEnvName = platform == "html5" ? "FMOD_SDK_WEB" : "FMOD_SDK";
		var sdkPath = Sys.getEnv(sdkEnvName);

		if (sdkPath == null || sdkPath == "") {
			if (platform == "html5") {
				printSdkWebError(libRoot);
			} else {
				printSdkError(libRoot, target);
			}
			Sys.exit(1);
		}

		// Both FMOD packages ship api/core/inc, so a header check cannot
		// tell the desktop SDK from the HTML5 one. Name the mix-up here
		// rather than failing later on a library that was never there.
		verifyPackage(platform, sdkPath, sdkEnvName);

		// Version check
		verifyVersion(libRoot, sdkPath, sdkEnvName, projectDir, target);
		return sdkPath;
	}

	/**
	 * Copies into destDir, which already exists. standalone marks a
	 * stage() call, where the web files include jaxe.js (lime bundles
	 * that one itself) and a Linux HashLink VM build gets a launcher.
	 */
	public static function stageInto(platform:String, target:String, sdkPath:String, libRoot:String,
			projectDir:String, destDir:String, standalone:Bool):Void {
		switch (platform) {
			case "mac":
				copyMac(sdkPath, target, libRoot, destDir, projectDir, standalone);
			case "linux":
				copyLinux(sdkPath, target, libRoot, destDir, projectDir, standalone);
			case "windows":
				copyWindows(sdkPath, target, libRoot, destDir, projectDir, standalone);
			case "html5":
				copyHtml5(sdkPath, libRoot, destDir, standalone);
			default:
				log('Unknown platform: $platform (expected mac, linux, windows, or html5)');
				Sys.exit(1);
		}
	}

	/** The directory lime built into, or null when no build output exists. */
	static function findLimeOutputDir(platform:String, target:String, exportDir:String):Null<String> {
		if (platform == "mac") {
			var appDir = target == "hl"
				? findAppBundle(Path.join([exportDir, "hl"]))
				: findAppBundleInPlatformDir(exportDir, "mac");
			if (appDir == null) return null;
			return Path.join([appDir, "Contents", "MacOS"]);
		}
		if (platform == "html5") {
			var binDir = findBinDir(exportDir, "html5", "html5");
			if (binDir == null) return null;
			var libDir = Path.join([binDir, "lib"]);
			if (!FileSystem.exists(libDir)) FileSystem.createDirectory(libDir);
			return libDir;
		}
		return findBinDir(exportDir, target, platform);
	}

	//// SDK package verification

	/**
	 * The core library every native build copies, relative to the SDK root.
	 * This is what separates a desktop FMOD package from the HTML5 one:
	 * both ship the same api/core/inc headers, but only the desktop
	 * package has these.
	 */
	public static function nativeCoreLib(platform:String):Array<String> {
		return switch (platform) {
			case "mac": ["api", "core", "lib", "libfmod.dylib"];
			case "windows": ["api", "core", "lib", "x64", "fmod.dll"];
			default: ["api", "core", "lib", "x86_64", "libfmod.so"];
		};
	}

	/** True when the path holds the HTML5 FMOD Engine package. */
	public static function looksLikeWebSdk(sdkPath:String):Bool {
		return FileSystem.exists(Path.join([sdkPath, "api", "studio", "lib", "wasm", "fmodstudio.js"]));
	}

	/** Stops the build when the two FMOD packages have been swapped. */
	static function verifyPackage(platform:String, sdkPath:String, sdkEnvName:String):Void {
		// A path that does not exist at all is a plain typo: the version
		// check and the copy guards give a better message for that.
		if (!FileSystem.exists(sdkPath)) return;
		var wantWeb = platform == "html5";
		if (looksLikeWebSdk(sdkPath) == wantWeb) return;

		if (wantWeb) {
			log('ERROR: $sdkEnvName does not point at the HTML5 FMOD Engine package');
			log('  $sdkEnvName = $sdkPath');
			log("  HTML5 builds need the HTML5 package. FMOD_SDK is where the desktop one goes.");
		} else {
			log('ERROR: $sdkEnvName points at the HTML5 FMOD Engine package');
			log('  $sdkEnvName = $sdkPath');
			log("  Native builds need the desktop FMOD Engine package. The HTML5");
			log("  package is what FMOD_SDK_WEB is for.");
		}
		log("  Download the right package from https://www.fmod.com/download");
		log("  Verify your setup with: haxelib run haxefmod check");
		Sys.exit(1);
	}

	//// Version verification

	static function verifyVersion(libRoot:String, sdkPath:String, sdkEnvName:String, projectDir:String, target:String):Void {
		var versionFile = Path.join([libRoot, "fmod_expected_version"]);
		var sdkHeader = Path.join([sdkPath, "api", "core", "inc", "fmod_common.h"]);

		// A set-but-wrong SDK path is provably not an SDK: hard error, the
		// same class of failure as an unset variable. Anything softer lets
		// a typo'd path skip the version gate and ship builds that only
		// run while stale libraries remain in export/.
		if (!FileSystem.exists(sdkHeader)) {
			log('ERROR: $sdkEnvName is set but does not point at an FMOD SDK');
			log('  $sdkEnvName = $sdkPath');
			log('  Missing: $sdkHeader');
			log("  Check the path for typos, or re-download the FMOD Engine from https://www.fmod.com/download");
			log("  Verify your setup with: haxelib run haxefmod check");
			Sys.exit(1);
		}

		// The lib-side expected-version file only goes missing when the
		// package itself is broken - warn and continue.
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

		if (sameVersion(expectedHex, sdkHex)) {
			var ver = hexToVersion(expectedHex);
			if (sdkEnvName == "FMOD_SDK_WEB") {
				log('FMOD SDK Web version $ver - OK');
			} else {
				log('FMOD SDK version $ver - OK');
			}
			return;
		}

		// Version mismatch - check for project-local custom-compiled hdll via marker file.
		// HTML5 does not use hdlls, so marker files do not apply.
		if (sdkEnvName != "FMOD_SDK_WEB") {
			var markerFile = Path.join([projectDir, ".haxefmod", "hlaxe_fmod.version"]);
			var customHdll = Path.join([projectDir, ".haxefmod", "hlaxe_fmod.hdll"]);
			// A marker left behind by a deleted hdll proves nothing: the
			// build then falls back to the pre-built hdll for another SDK.
			if (FileSystem.exists(markerFile) && FileSystem.exists(customHdll)) {
				var markerHex = StringTools.trim(File.getContent(markerFile));
				if (sameVersion(markerHex, sdkHex)) {
					var ver = hexToVersion(sdkHex);
					log('FMOD SDK version $ver - OK (custom-compiled hdll from .haxefmod/)');
					return;
				}
			}
		}

		var expectedVer = hexToVersion(expectedHex);
		var sdkVer = hexToVersion(sdkHex);

		// html5: the JS shim's numeric tables are the expected version's
		// values and the wasm has no version query. Any other web SDK
		// creates wrong DSP effects. Hard error, like the HL gate.
		if (sdkEnvName == "FMOD_SDK_WEB") {
			Sys.println("");
			Sys.println("============================================================");
			Sys.println('  ERROR: FMOD web SDK version mismatch');
			Sys.println("");
			Sys.println('  Your FMOD_SDK_WEB:    $sdkVer');
			Sys.println('  This release needs:   $expectedVer');
			Sys.println("");
			Sys.println('  Download FMOD Engine $expectedVer for HTML5 from https://www.fmod.com/download');
			Sys.println("============================================================");
			Sys.println("");
			Sys.exit(1);
		}

		// HL builds: a mismatched hdll and SDK crash at runtime, so this is a hard error.
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

		// Other targets: informational warning only (C++ compiles from source).
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
					// Extract the hex string (e.g. "0x00020312").
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

	/**
	 * True when two FMOD_VERSION literals name the same version. The
	 * literals are compared as numbers, so 0x00020312, 0X20312, and the
	 * marker file's text all agree.
	 */
	public static function sameVersion(a:String, b:String):Bool {
		if (a == null || b == null) return false;
		var x = Std.parseInt(StringTools.trim(a));
		var y = Std.parseInt(StringTools.trim(b));
		return x != null && y != null && x == y;
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
	public static function expectedAbiVersion(libRoot:String):Int {
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
	// Returns the version, or 0 when the hdll carries no marker.
	public static function scanHdllAbi(hdllPath:String):Int {
		var bytes = File.getBytes(hdllPath);
		var marker = "hlaxe_fmod_abi=";
		var limit = bytes.length - marker.length;
		var i = 0;
		while (i <= limit) {
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

	// A custom hdll is only preferred while its version marker matches the
	// SDK in use. A leftover .haxefmod/ from a different SDK would otherwise
	// ship next to mismatched runtime libraries and fail at startup. That
	// happens even when the SDK matches the pre-built expectation.
	// A missing or unreadable marker means the custom hdll is trusted
	// as-is (build-hdll always writes one).
	public static function customHdllMatchesSdk(projectDir:String, quiet:Bool = false):Bool {
		var markerFile = Path.join([projectDir, ".haxefmod", "hlaxe_fmod.version"]);
		if (!FileSystem.exists(markerFile)) return true;
		var sdkPath = Sys.getEnv("FMOD_SDK");
		if (sdkPath == null || sdkPath == "") return true;
		var sdkHeader = Path.join([sdkPath, "api", "core", "inc", "fmod_common.h"]);
		if (!FileSystem.exists(sdkHeader)) return true;
		var sdkHex = parseFmodVersion(sdkHeader);
		if (sdkHex == null) return true;
		var markerHex = StringTools.trim(File.getContent(markerFile));
		if (sameVersion(markerHex, sdkHex)) return true;
		if (!quiet) {
			log('Custom hdll in .haxefmod/ was built for FMOD ${hexToVersion(markerHex)},'
				+ ' the SDK is ${hexToVersion(sdkHex)} - using the pre-built hdll.'
				+ ' Run "haxelib run haxefmod build-hdll" to rebuild it, or delete .haxefmod/.');
		}
		return false;
	}

	// Tiered hdll resolution (project-local .haxefmod/ then pre-built) with a
	// binding ABI check. An hdll compiled against a different native surface
	// is missing prims and dies with a loader fatal at startup. The check
	// stops the build here with instructions instead.
	static function copyHdll(projectDir:String, libRoot:String, platformDir:String, destDir:String):Void {
		var projectHdll = Path.join([projectDir, ".haxefmod", "hlaxe_fmod.hdll"]);
		var prebuiltHdll = Path.join([libRoot, "templates", "bin", "hl", platformDir, "hlaxe_fmod.hdll"]);
		var source:String = null;
		var flavor:String = null;
		if (FileSystem.exists(projectHdll) && customHdllMatchesSdk(projectDir)) {
			source = projectHdll;
			flavor = "custom-compiled from .haxefmod/";
		} else if (FileSystem.exists(prebuiltHdll)) {
			source = prebuiltHdll;
			flavor = "pre-built";
		}
		if (source == null) {
			// An HL build with no hdll dies at runtime with a bare loader
			// error, so the build stops here with the paths it checked.
			log('ERROR: no hlaxe_fmod.hdll found');
			log('  Checked: $projectHdll');
			log('  Checked: $prebuiltHdll');
			log("  Reinstall haxefmod, or compile one with: haxelib run haxefmod build-hdll");
			Sys.exit(1);
		}

		var expected = expectedAbiVersion(libRoot);
		if (expected > 0) {
			var found = scanHdllAbi(source);
			if (found != expected) {
				Sys.println("");
				Sys.println("  ==========================================================");
				Sys.println("  ERROR: hlaxe_fmod.hdll binding version mismatch");
				Sys.println("");
				Sys.println('  hdll: $source');
				Sys.println('  hdll binding ABI:     ' + (found == 0 ? "unknown (no ABI marker)" : Std.string(found)));
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

	static function copyMac(sdkDir:String, target:String, libRoot:String, dest:String, projectDir:String, standalone:Bool = false):Void {
		log('Copying FMOD dylibs to $dest');

		copyRequired(Path.join([sdkDir, "api", "core", "lib", "libfmod.dylib"]), Path.join([dest, "libfmod.dylib"]));
		copyRequired(Path.join([sdkDir, "api", "studio", "lib", "libfmodstudio.dylib"]), Path.join([dest, "libfmodstudio.dylib"]));

		// Copy hlaxe_fmod.hdll - tiered resolution with binding ABI check.
		if (target == "hl") {
			copyHdll(projectDir, libRoot, "Mac64", dest);
		}

		// Set rpath so the executable finds the dylibs next to it. C++ only,
		// because the HL executable is bytecode. The output is captured
		// because lime or hxcpp can have added the rpath already, and
		// install_name_tool reports that as an error.
		if (target != "hl") {
			var exe = findExecutable(dest, [".dylib", ".ndll", ".hdll"]);
			if (exe != null) {
				try {
					var proc = new sys.io.Process("install_name_tool", ["-add_rpath", "@executable_path", exe]);
					var out = proc.stdout.readAll().toString();
					var err = proc.stderr.readAll().toString();
					var code = proc.exitCode();
					proc.close();
					if (code != 0 && err.indexOf("would duplicate") == -1) {
						log('ERROR: install_name_tool could not add the dylib search path to $exe (exit $code)');
						if (StringTools.trim(err + out) != "") log("  " + StringTools.trim(err + out));
						log("  The game then fails at startup with: Library not loaded: @rpath/libfmod.dylib");
						log("  Link the executable with -Wl,-headerpad_max_install_names, or add an rpath at link time.");
						// The architectures and load commands say which slice lacks the room
						for (probe in [["lipo", "-info", exe], ["otool", "-l", exe]]) {
							try {
								var p = new sys.io.Process(probe[0], probe.slice(1));
								var text = p.stdout.readAll().toString();
								p.stderr.readAll();
								p.exitCode();
								p.close();
								if (probe[0] == "otool") {
									var kept = [for (line in text.split("\n")) if (line.indexOf("LC_RPATH") != -1 || line.indexOf("path ") != -1 || line.indexOf("libfmod") != -1) StringTools.trim(line)];
									text = kept.join("\n");
								}
								log('  ${probe[0]}: ' + StringTools.trim(text));
							} catch (e:Dynamic) {}
						}
						Sys.exit(1);
					}
				} catch (e:Dynamic) {
					log('WARNING: install_name_tool could not run: $e');
				}
			}
		}

		// A HashLink VM build (Heaps, plain haxe -hl) has no executable of
		// its own. The launcher runs the bytecode through hl with the
		// library path set, since the hl binary carries no rpath to here.
		if (standalone && target == "hl") {
			var bytecode = findBytecodeName(dest);
			if (bytecode != null) writeLauncher(Path.join([dest, "run.sh"]), runShContent(bytecode, true, true), true);
		}

		log("Done - copied libfmod.dylib and libfmodstudio.dylib");
	}

	//// Linux

	static function copyLinux(sdkDir:String, target:String, libRoot:String, binDir:String, projectDir:String, standalone:Bool):Void {
		log('Copying FMOD shared libraries to $binDir');

		// Copy .so files preserving symlinks (must use cp -P).
		copyGlobSymlinks(Path.join([sdkDir, "api", "core", "lib", "x86_64"]), "libfmod.so", binDir);
		copyGlobSymlinks(Path.join([sdkDir, "api", "studio", "lib", "x86_64"]), "libfmodstudio.so", binDir);

		// Copy hlaxe_fmod.hdll - tiered resolution with binding ABI check.
		if (target == "hl") {
			copyHdll(projectDir, libRoot, "Linux64", binDir);
		}

		// Modern Linux kernels refuse to load libraries flagged with an
		// executable stack, and FMOD ships its .so files that way. The
		// flag is one program header bit, so it is cleared right here and
		// plain lime test linux works with no extra tooling installed.
		clearExecstack(binDir);

		// The run.sh wrapper. It is rewritten when its content changed,
		// so a fix to the script reaches an existing build directory.
		var runSh = Path.join([binDir, "run.sh"]);
		// .dat excluded: HL builds ship hlboot.dat next to the exe and
		// run.sh must never point at it. .hl excluded for the same
		// reason, a VM build's bytecode is launched through hl below.
		var exeName = findExecutableName(binDir, [".so", ".hdll", ".ndll", ".dat", ".hl"]);
		if (exeName != null) {
			writeLauncher(runSh, runShContent(exeName), true);
		} else if (standalone && target == "hl") {
			// A HashLink VM build (Heaps, plain haxe -hl) has no
			// executable of its own. The launcher runs the bytecode
			// through hl with the library path set.
			var bytecode = findBytecodeName(binDir);
			if (bytecode != null) writeLauncher(runSh, runShContent(bytecode, true), true);
		}

		log("Done - copied FMOD .so files");
	}

	/** The .hl bytecode file in a directory, or null when there is none. */
	static function findBytecodeName(dir:String):Null<String> {
		for (file in FileSystem.readDirectory(dir)) {
			if (StringTools.endsWith(file, ".hl") && !FileSystem.isDirectory(Path.join([dir, file]))) return file;
		}
		return null;
	}

	/**
	 * Clears the executable-stack flag inside one ELF shared library by
	 * rewriting the PT_GNU_STACK program header's flags in place, the
	 * same four byte edit patchelf performs. Returns true when the file
	 * changed. Anything that does not parse as a little endian ELF64
	 * with an executable stack entry comes back untouched. A malformed
	 * or foreign file can never be corrupted.
	 */
	public static function clearExecstackFile(path:String):Bool {
		var bytes = try File.getBytes(path) catch (e:Dynamic) return false;
		if (bytes.length < 64) return false;
		if (bytes.get(0) != 0x7F || bytes.get(1) != 0x45
			|| bytes.get(2) != 0x4C || bytes.get(3) != 0x46) return false;
		// FMOD ships little endian ELF64 on the one supported Linux arch.
		if (bytes.get(4) != 2 || bytes.get(5) != 1) return false;
		var phoff = bytes.getInt32(0x20);
		var phoffHigh = bytes.getInt32(0x24);
		if (phoffHigh != 0 || phoff <= 0) return false;
		var phentsize = bytes.getUInt16(0x36);
		var phnum = bytes.getUInt16(0x38);
		if (phentsize < 56) return false;
		var changed = false;
		for (i in 0...phnum) {
			var base = phoff + i * phentsize;
			if (base + phentsize > bytes.length) break;
			if (bytes.getInt32(base) != 0x6474E551) continue; // PT_GNU_STACK
			var flags = bytes.getInt32(base + 4);
			if (flags & 1 == 0) continue; // PF_X already clear
			bytes.setInt32(base + 4, flags & ~1);
			changed = true;
		}
		if (changed) File.saveBytes(path, bytes);
		return changed;
	}

	/** Clears the executable-stack flag on every FMOD .so in the directory. */
	static function clearExecstack(binDir:String):Void {
		for (file in FileSystem.readDirectory(binDir)) {
			if (file.indexOf("libfmod") != 0 || file.indexOf(".so") == -1) continue;
			var path = Path.join([binDir, file]);
			if (isSymlink(path)) continue;
			if (clearExecstackFile(path)) {
				log('Cleared executable-stack flag on $file');
			}
		}
	}

	static function isSymlink(path:String):Bool {
		// Haxe sys has no lstat. Test -L works everywhere PostBuild handles symlinks (Linux only).
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

	static function copyWindows(sdkDir:String, target:String, libRoot:String, binDir:String, projectDir:String, standalone:Bool = false):Void {
		log('Copying FMOD DLLs to $binDir');

		copyRequired(Path.join([sdkDir, "api", "core", "lib", "x64", "fmod.dll"]), Path.join([binDir, "fmod.dll"]));
		copyRequired(Path.join([sdkDir, "api", "studio", "lib", "x64", "fmodstudio.dll"]), Path.join([binDir, "fmodstudio.dll"]));

		// Copy hlaxe_fmod.hdll - tiered resolution with binding ABI check.
		if (target == "hl") {
			copyHdll(projectDir, libRoot, "Windows64", binDir);
		}

		// Launcher for a HashLink VM build: hl.exe on PATH, DLLs and hdll
		// next to the bytecode.
		if (standalone && target == "hl") {
			var bytecode = findBytecodeName(binDir);
			if (bytecode != null) writeLauncher(Path.join([binDir, "run.cmd"]), runCmdContent(bytecode), false);
		}

		log("Done - copied fmod.dll and fmodstudio.dll");
	}

	//// HTML5

	static function copyHtml5(sdkDir:String, libRoot:String, libDir:String, standalone:Bool):Void {
		if (standalone) {
			log('Copying FMOD web engine and jaxe.js to $libDir');
			// lime bundles jaxe.js through include.xml. Every other build
			// system gets it here, next to the engine it drives. The page
			// script-tags all three files in this order: fmodstudio.js,
			// jaxe.js, then the game.
			copyRequired(Path.join([libRoot, "native", "jaxe", "jaxe.js"]), Path.join([libDir, "jaxe.js"]));
		} else {
			log("Replacing FMOD placeholder files with real SDK files");
		}

		var jsSrc = Path.join([sdkDir, "api", "studio", "lib", "wasm", "fmodstudio.js"]);
		if (FileSystem.exists(jsSrc)) {
			copyFile(jsSrc, Path.join([libDir, "fmodstudio.js"]));
			log(standalone ? "Copied fmodstudio.js" : "Replaced fmodstudio.js");
		} else {
			log('ERROR: $jsSrc not found');
			Sys.exit(1);
		}

		var wasmSrc = Path.join([sdkDir, "api", "studio", "lib", "wasm", "fmodstudio.wasm"]);
		if (FileSystem.exists(wasmSrc)) {
			copyFile(wasmSrc, Path.join([libDir, "fmodstudio.wasm"]));
			log(standalone ? "Copied fmodstudio.wasm" : "Replaced fmodstudio.wasm");
		} else {
			log('ERROR: $wasmSrc not found');
			Sys.exit(1);
		}

		log("Done - FMOD files ready for HTML5");
	}

	//// Directory finding

	/**
	 * Find the bin directory for a given target and platform.
	 * Lime export structure: export/<target>/bin or export/<platform>/bin.
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

			// Fallback: search for a directory starting with the platform name.
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

	/**
	 * Copies a library the build cannot run without. A missing one is a
	 * setup problem and gets a setup message: File.copy on its own throws
	 * an uncaught exception naming nothing but the path.
	 */
	static function copyRequired(src:String, dst:String):Void {
		if (!FileSystem.exists(src)) {
			log('ERROR: FMOD library not found: $src');
			log("  FMOD_SDK has no libraries for this platform, so the build output");
			log("  would fail to launch. Re-download the FMOD Engine or fix FMOD_SDK,");
			log("  then rebuild.");
			log("  Verify your setup with: haxelib run haxefmod check");
			Sys.exit(1);
		}
		copyFile(src, dst);
	}

	/** Copy files matching a prefix from srcDir to destDir, preserving symlinks on Linux. */
	static function copyGlobSymlinks(srcDir:String, prefix:String, destDir:String):Void {
		// Copying nothing silently produced binaries that only launched when
		// stale libraries from an earlier build were still in the bin dir.
		if (!FileSystem.exists(srcDir)) {
			log('ERROR: FMOD library directory not found: $srcDir');
			log("  The FMOD_SDK directory has no libraries for this platform, so the");
			log("  build output would fail to launch. Re-download the FMOD Engine or");
			log("  fix FMOD_SDK, then rebuild.");
			Sys.exit(1);
		}
		var files = FileSystem.readDirectory(srcDir);
		var copied = 0;
		for (file in files) {
			if (StringTools.startsWith(file, prefix)) {
				// cp -P keeps the symlinks FMOD ships next to the real files.
				var code = Sys.command("cp", ["-P", Path.join([srcDir, file]), Path.join([destDir, file])]);
				if (code != 0) {
					log('ERROR: could not copy $file from $srcDir to $destDir (cp exited with $code)');
					Sys.exit(1);
				}
				copied++;
			}
		}
		if (copied == 0) {
			log('ERROR: no file named $prefix* in $srcDir');
			log("  The FMOD_SDK directory has no libraries for this platform, so the");
			log("  build output would fail to launch. Re-download the FMOD Engine or");
			log("  fix FMOD_SDK, then rebuild.");
			Sys.exit(1);
		}
	}

	/**
	 * Finds the executable in a build directory by excluding the library
	 * extensions. A versioned library such as libfmod.so.14 is excluded
	 * too. Several candidates are reported, and the first in sorted order
	 * is returned.
	 */
	static function findExecutable(dir:String, excludeExts:Array<String>):Null<String> {
		if (!FileSystem.exists(dir)) return null;
		var candidates:Array<String> = [];
		var names = FileSystem.readDirectory(dir);
		names.sort(Reflect.compare);
		for (file in names) {
			if (file == "run.sh" || isLibraryFile(file, excludeExts)) continue;
			var fullPath = Path.join([dir, file]);
			if (!FileSystem.isDirectory(fullPath)) candidates.push(fullPath);
		}
		if (candidates.length == 0) return null;
		// An asset khamake copied next to the executable carries an
		// extension, the executable itself carries none
		var plain = [for (c in candidates) if (Path.withoutDirectory(c).indexOf(".") == -1) c];
		if (plain.length > 0) candidates = plain;
		if (candidates.length > 1) {
			log('WARNING: several files in $dir look like the executable, using ${candidates[0]}');
			for (other in candidates.slice(1)) log('  also: $other');
		}
		return candidates[0];
	}

	/** True when the name ends in one of the extensions, with or without a version suffix. */
	public static function isLibraryFile(file:String, excludeExts:Array<String>):Bool {
		for (ext in excludeExts) {
			if (StringTools.endsWith(file, ext)) return true;
			// libfmod.so.14, libfmodstudio.so.14.5
			var at = file.indexOf(ext + ".");
			if (at != -1 && ~/^[0-9.]+$/.match(file.substr(at + ext.length + 1))) return true;
		}
		return false;
	}

	/**
	 * The generated Linux launcher script. The exe invocation is quoted so
	 * a name with spaces still launches. Public for unit tests.
	 */
	/**
	 * Writes a launcher when it is missing or its content changed, and
	 * makes it executable. An unchanged file is left alone, so its
	 * timestamp does not move on every build.
	 */
	static function writeLauncher(path:String, content:String, executable:Bool):Void {
		if (!FileSystem.exists(path) || File.getContent(path) != content) File.saveContent(path, content);
		if (executable) Sys.command("chmod", ["+x", path]);
	}

	public static function runShContent(exeName:String, viaHl:Bool = false, mac:Bool = false):String {
		var launch = viaHl ? 'hl "./${exeName}"' : '"./${exeName}"';
		var libPath = mac ? "DYLD_LIBRARY_PATH" : "LD_LIBRARY_PATH";
		// exec makes the launcher's pid the game's, so a signal to the
		// launcher reaches the game
		return '#!/bin/bash\ncd "$$(dirname "$$0")"\nexport ${libPath}="$$(pwd):$$${libPath}"\nexec ${launch} "$$@"\n';
	}

	/** The Windows launcher for a HashLink bytecode build. Public for unit tests. */
	public static function runCmdContent(bytecode:String):String {
		return '@echo off\r\ncd /d "%~dp0"\r\nhl "${bytecode}" %*\r\n';
	}

	/** Find just the filename of the executable in a directory. */
	static function findExecutableName(dir:String, excludeExts:Array<String>):Null<String> {
		var path = findExecutable(dir, excludeExts);
		if (path == null) return null;
		return Path.withoutDirectory(path);
	}

	//// Error messages

	/** The FMOD version the pre-built binaries expect, from the library's marker file. */
	public static function expectedFmodVersion(libRoot:String):String {
		var versionFile = Path.join([libRoot, "fmod_expected_version"]);
		if (!FileSystem.exists(versionFile)) return "the expected FMOD version";
		return hexToVersion(StringTools.trim(File.getContent(versionFile)));
	}

	/** The version as it appears in FMOD's package names, 2.03.12 as 20312. */
	public static function packageDigits(version:String):String {
		return version.split(".").join("");
	}

	static function printSdkError(libRoot:String, target:String):Void {
		var version = expectedFmodVersion(libRoot);
		var digits = packageDigits(version);
		Sys.println("");
		Sys.println("============================================================");
		Sys.println("  ERROR: FMOD_SDK environment variable is not set.");
		Sys.println("");
		if (target == "hl") {
			Sys.println("  The error reads: Failed to load library hlaxe_fmod.hdll");
		} else {
			Sys.println("  The game exits at startup because libfmod is missing.");
		}
		Sys.println("============================================================");
		Sys.println("");
		Sys.println("  haxe-fmod requires you to supply your own FMOD Engine SDK.");
		Sys.println("");
		Sys.println("  1. Download FMOD Engine from https://www.fmod.com/download");
		Sys.println('     - All platforms: version $version');
		Sys.println("");
		Sys.println("  2. Install/extract it and set FMOD_SDK to point to the SDK directory.");
		Sys.println("");
		Sys.println('     export FMOD_SDK=/path/to/fmodstudioapi$digits');
		Sys.println('     set FMOD_SDK=C:\\path\\to\\fmodstudioapi$digits   (Windows)');
		Sys.println("");
		Sys.println("     Note: Set FMOD_SDK to the installed/extracted SDK directory.");
		Sys.println("           Switch FMOD_SDK when building for different platforms.");
		Sys.println("");
		Sys.println("  3. Run 'haxelib run haxefmod check' to verify your setup.");
		Sys.println("");
		Sys.println("============================================================");
		Sys.println("");
	}

	static function printSdkWebError(libRoot:String):Void {
		var version = expectedFmodVersion(libRoot);
		var digits = packageDigits(version);
		Sys.println("");
		Sys.println("============================================================");
		Sys.println("  ERROR: FMOD_SDK_WEB environment variable is not set.");
		Sys.println("");
		Sys.println("  HTML5 builds require the FMOD Engine SDK for HTML5.");
		Sys.println("");
		Sys.println('  1. Download FMOD Engine $version for HTML5 from:');
		Sys.println("     https://www.fmod.com/download");
		Sys.println("");
		Sys.println("  2. Extract it and set FMOD_SDK_WEB:");
		Sys.println("");
		Sys.println('     export FMOD_SDK_WEB=/path/to/fmodstudioapi${digits}html5');
		Sys.println("");
		Sys.println("     Or on Windows:");
		Sys.println('     set FMOD_SDK_WEB=C:\\path\\to\\fmodstudioapi${digits}html5');
		Sys.println("");
		Sys.println("  3. Run 'haxelib run haxefmod check' to verify your setup.");
		Sys.println("");
		Sys.println("============================================================");
		Sys.println("");
	}
}
