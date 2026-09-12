package haxefmod.tools;

#if macro
import haxe.macro.Context;

/**
 * Compile-time environment check, wired by include.xml so it runs on every
 * lime build of a project using haxefmod. Heaps and Kha builds run it
 * too, and any other build opts in with --macro
 * haxefmod.tools.BuildCheck.verify() in its hxml. The check applies to
 * the hl, cpp, and js targets, the ones that ship an FMOD runtime.
 *
 * The checks live in a macro because lime ignores postbuild failures. An
 * error reported there scrolls past while the game still compiles. The game
 * then launches with no audio or crashes loading libraries. Failing
 * compilation is the only reliable way to stop `lime test` before the game
 * window ever opens.
 */
class BuildCheck {
    public static function verify():Void {
        // IDE completion/diagnostics runs compile the project without the
        // shell environment. Never block those.
        if (Context.defined("display")) return;
        // Only a build that ships an FMOD runtime has anything to verify.
        // An interp or neko run of the tools has none.
        if (!Context.defined("hl") && !Context.defined("cpp") && !Context.defined("js")) return;
        var expectedVersion = expectedFmodVersion();
        var digits = expectedVersion.split(".").join("");

        // Lime defines "html5" for the html5 target. "js" covers the same
        // build if that define ever changes (the only lime js target is html5).
        if (Context.defined("html5") || Context.defined("js")) {
            requireEnv("FMOD_SDK_WEB",
                "haxefmod: FMOD_SDK_WEB is not set - HTML5 builds cannot include the FMOD engine.\n"
                + "\n"
                + '  1. Download the FMOD Engine HTML5 package (version $expectedVersion) from https://www.fmod.com/download\n'
                + "  2. Set FMOD_SDK_WEB to the extracted directory, e.g.\n"
                + '       export FMOD_SDK_WEB="$$HOME/fmod/fmodstudioapi${digits}html5"\n'
                + "  3. Restart your terminal (or IDE) so the build sees the variable\n"
                + "\n"
                + "  Verify your setup with: haxelib run haxefmod check");
        } else if (Context.defined("hl") || Context.defined("cpp")) {
            requireEnv("FMOD_SDK",
                "haxefmod: FMOD_SDK is not set - the game would launch without any audio.\n"
                + "\n"
                + '  1. Download the FMOD Engine (version $expectedVersion) from https://www.fmod.com/download\n'
                + "  2. Set FMOD_SDK to the extracted directory, e.g.\n"
                + '       export FMOD_SDK="$$HOME/fmod/fmodstudioapi$digits"   (Linux/macOS)\n'
                + '       FMOD_SDK=C:\\path\\to\\fmodstudioapi$digits           (Windows)\n'
                + "  3. Restart your terminal (or IDE) so the build sees the variable\n"
                + "\n"
                + "  Verify your setup with: haxelib run haxefmod check");
        }

        // A set-but-wrong path must fail the same as an unset one.
        // The postbuild guards also catch it, but lime can bury their exit
        // code. The compile-time check is the reliable block.
        if (Context.defined("html5") || Context.defined("js")) {
            requirePackage("FMOD_SDK_WEB", true);
            requireSdkFile("FMOD_SDK_WEB", ["api", "studio", "lib", "wasm", "fmodstudio.js"]);
        } else if (Context.defined("hl") || Context.defined("cpp")) {
            requirePackage("FMOD_SDK", false);
            requireSdkFile("FMOD_SDK", ["api", "core", "inc", "fmod_common.h"]);
            // The header above ships in every FMOD package, the HTML5 one
            // included, so it cannot tell them apart. The platform's own
            // core library can, and it is the file the postbuild copies.
            requireSdkFile("FMOD_SDK", PostBuild.nativeCoreLib(targetPlatform()));
        }

        // Kha's HashLink target is HL/C with hlaxe_fmod.c compiled into the
        // executable, so no hdll is ever loaded there.
        if (Context.defined("hl") && !Context.defined("kha")) {
            verifyHlHdllGate();
        }
        if (Context.defined("html5") || Context.defined("js")) {
            verifyWebSdkVersionGate();
        }
    }

    /**
     * html5 supports exactly the expected FMOD web SDK version. The JS
     * shim's numeric tables (DSP types among them) are that version's
     * values. The wasm exposes no version query to adapt at runtime.
     * This target has no custom-hdll escape hatch. A mismatched web SDK
     * creates the wrong DSP effects at runtime, so the build stops here.
     */
    static function verifyWebSdkVersionGate():Void {
        var sdkPath = Sys.getEnv("FMOD_SDK_WEB");
        if (sdkPath == null || sdkPath == "") return; // requireEnv handled it.
        var sdkHeader = haxe.io.Path.join([sdkPath, "api", "core", "inc", "fmod_common.h"]);
        if (!sys.FileSystem.exists(sdkHeader)) return; // header layout varies, postbuild warns.
        var libRoot = resolveLibRoot();
        if (libRoot == null) return;
        var versionFile = haxe.io.Path.join([libRoot, "fmod_expected_version"]);
        if (!sys.FileSystem.exists(versionFile)) return;
        var expectedHex = StringTools.trim(sys.io.File.getContent(versionFile));
        var sdkHex = PostBuild.parseFmodVersion(sdkHeader);
        if (sdkHex == null || PostBuild.sameVersion(sdkHex, expectedHex)) return;

        var sdkVer = PostBuild.hexToVersion(sdkHex);
        var expectedVer = PostBuild.hexToVersion(expectedHex);
        fail('FMOD web SDK version mismatch ($sdkVer, this release needs $expectedVer)',
            'haxefmod: FMOD web SDK version mismatch - the game would create wrong DSP effects.\n'
            + "\n"
            + '  Your FMOD_SDK_WEB:  $sdkVer\n'
            + '  This release needs: $expectedVer\n'
            + "\n"
            + '  Download FMOD Engine $expectedVer for HTML5 from https://www.fmod.com/download\n'
            + "  and point FMOD_SDK_WEB at it.");
    }

    /**
     * HL version and ABI gate at compile time. The postbuild step prints
     * the same diagnosis, but lime DISCARDS postbuild exit codes
     * (CommandHelper.executeCommands ignores the Sys.command result).
     * Only failing compilation reliably stops `lime test` before a
     * mismatched hdll crashes the game at startup.
     */
    static function verifyHlHdllGate():Void {
        var sdkPath = Sys.getEnv("FMOD_SDK");
        if (sdkPath == null || sdkPath == "") return; // requireEnv handled it.
        var sdkHeader = haxe.io.Path.join([sdkPath, "api", "core", "inc", "fmod_common.h"]);
        if (!sys.FileSystem.exists(sdkHeader)) return; // requireSdkFile handled it.
        var libRoot = resolveLibRoot();
        if (libRoot == null) return;
        var versionFile = haxe.io.Path.join([libRoot, "fmod_expected_version"]);
        if (!sys.FileSystem.exists(versionFile)) return; // packaging problem, postbuild warns.
        var expectedHex = StringTools.trim(sys.io.File.getContent(versionFile));
        var sdkHex = PostBuild.parseFmodVersion(sdkHeader);

        var projectDir = Sys.getCwd();
        var customHdll = haxe.io.Path.join([projectDir, ".haxefmod", "hlaxe_fmod.hdll"]);
        var markerFile = haxe.io.Path.join([projectDir, ".haxefmod", "hlaxe_fmod.version"]);
        var haveCustom = sys.FileSystem.exists(customHdll);
        var markerHex = sys.FileSystem.exists(markerFile)
            ? StringTools.trim(sys.io.File.getContent(markerFile)) : null;

        // An unparseable header skips the version gate (postbuild warns)
        // but never the ABI gate below.
        // A custom hdll without a marker is trusted, the same policy as
        // PostBuild.customHdllMatchesSdk and the ABI gate below.
        var customMatches = haveCustom && (markerHex == null || PostBuild.sameVersion(markerHex, sdkHex));
        if (sdkHex != null && !PostBuild.sameVersion(expectedHex, sdkHex) && !customMatches) {
            var sdkVer = PostBuild.hexToVersion(sdkHex);
            var expectedVer = PostBuild.hexToVersion(expectedHex);
            fail('FMOD SDK version mismatch ($sdkVer, the pre-built hdll needs $expectedVer)',
                'haxefmod: FMOD SDK version mismatch - the game would crash at startup.\n'
                + "\n"
                + '  Your FMOD SDK:   $sdkVer\n'
                + '  Pre-built hdll:  $expectedVer\n'
                + "\n"
                + "  To compile an hdll matching your SDK, run:\n"
                + "    haxelib run haxefmod build-hdll\n"
                + "\n"
                + '  Or download FMOD $expectedVer from https://www.fmod.com/download');
        }

        // ABI check on the hdll the build uses (the custom one when its
        // marker matches the SDK, the shipped pre-built one otherwise).
        var expectedAbi = PostBuild.expectedAbiVersion(libRoot);
        if (expectedAbi <= 0) {
            // The manifest ships with the library, so an unreadable header
            // is a broken install rather than a choice to skip the gate
            fail("haxefmod install has no readable native manifest",
                'haxefmod: native/manifest/studio_api.txt under $libRoot has no readable "# abi-version:" header.\n'
                + "  Reinstall haxefmod.");
            return;
        }
        var useCustom = haveCustom
            && (markerHex == null || sdkHex == null || PostBuild.sameVersion(markerHex, sdkHex));
        var hdll = useCustom ? customHdll : haxe.io.Path.join(
            [libRoot, "templates", "bin", "hl", prebuiltPlatformDir(), "hlaxe_fmod.hdll"]);
        if (!sys.FileSystem.exists(hdll)) {
            fail("hlaxe_fmod.hdll is missing", 'haxefmod: hlaxe_fmod.hdll is missing - the game would fail to load.\n'
                + "\n"
                + '  Checked: $hdll\n'
                + "\n"
                + "  Reinstall haxefmod, or compile one with: haxelib run haxefmod build-hdll");
            return;
        }
        var found = PostBuild.scanHdllAbi(hdll);
        if (found != expectedAbi) {
            fail('hlaxe_fmod.hdll binding ABI mismatch (hdll has '
                + (found == 0 ? "no marker" : Std.string(found)) + ', the library needs $expectedAbi)',
                'haxefmod: hlaxe_fmod.hdll binding ABI mismatch - the game would fail to load.\n'
                + "\n"
                + '  hdll: $hdll\n'
                + '  hdll binding ABI:     ' + (found == 0 ? "unknown (no ABI marker)" : Std.string(found)) + "\n"
                + '  library expects ABI:  $expectedAbi\n'
                + "\n"
                + "  To compile a matching hdll, run:\n"
                + "    haxelib run haxefmod build-hdll\n"
                + "  from your project directory, then rebuild.");
        }
    }

    /**
     * Stops the build when the desktop and HTML5 FMOD packages have been
     * swapped. Both ship api/core/inc, so this names the actual mistake
     * instead of leaving a missing-library message to be puzzled over.
     */
    static function requirePackage(name:String, wantWeb:Bool):Void {
        var value = Sys.getEnv(name);
        if (value == null || value == "") return; // requireEnv handled it.
        // A path that does not exist at all is a plain typo, and
        // requireSdkFile says so more clearly.
        if (!sys.FileSystem.exists(value)) return;
        if (PostBuild.looksLikeWebSdk(value) == wantWeb) return;

        if (wantWeb) {
            fail('$name does not point at the HTML5 FMOD Engine package',
                'haxefmod: $name does not point at the HTML5 FMOD Engine package.\n'
                + "\n"
                + '  $name = $value\n'
                + "\n"
                + "  HTML5 builds need the HTML5 package. FMOD_SDK is where the desktop one goes.\n"
                + "  Download it from https://www.fmod.com/download\n"
                + "\n"
                + "  Verify your setup with: haxelib run haxefmod check");
        } else {
            fail('$name points at the HTML5 FMOD Engine package',
                'haxefmod: $name points at the HTML5 FMOD Engine package.\n'
                + "\n"
                + '  $name = $value\n'
                + "\n"
                + "  Native builds need the desktop FMOD Engine package, which has\n"
                + "  the libraries this build has to ship. The HTML5 package is what\n"
                + "  FMOD_SDK_WEB is for.\n"
                + "  Download the desktop package from https://www.fmod.com/download\n"
                + "\n"
                + "  Verify your setup with: haxelib run haxefmod check");
        }
    }

    /** The platform being built for, as PostBuild names them. */
    static function targetPlatform():String {
        if (Context.defined("mac")) return "mac";
        if (Context.defined("windows")) return "windows";
        if (Context.defined("linux")) return "linux";
        return switch (Sys.systemName()) {
            case "Windows": "windows";
            case "Mac": "mac";
            default: "linux";
        };
    }

    /** The pre-built hdll directory for the platform being built for, the one PostBuild copies. */
    static function prebuiltPlatformDir():String {
        return switch (targetPlatform()) {
            case "windows": "Windows64";
            case "mac": "Mac64";
            default: "Linux64";
        }
    }

    // The library root is the parent of the haxefmod/ classpath this macro
    // was loaded from. Path-based, so it survives lime's space-splitting of
    // postbuild arguments and needs no haxelib subprocess.
    /** The FMOD version the pre-built binaries expect, from the library's marker file. */
    static function expectedFmodVersion():String {
        var libRoot = resolveLibRoot();
        if (libRoot == null) return "the expected FMOD version";
        var versionFile = haxe.io.Path.join([libRoot, "fmod_expected_version"]);
        if (!sys.FileSystem.exists(versionFile)) return "the expected FMOD version";
        return PostBuild.hexToVersion(StringTools.trim(sys.io.File.getContent(versionFile)));
    }

    static function resolveLibRoot():Null<String> {
        try {
            var here = Context.resolvePath("haxefmod/tools/BuildCheck.hx");
            return haxe.io.Path.directory(haxe.io.Path.directory(haxe.io.Path.directory(here)));
        } catch (e:Dynamic) {
            return null;
        }
    }

    static function requireEnv(name:String, message:String):Void {
        var value = Sys.getEnv(name);
        if (value == null || value == "") {
            fail('$name is not set', message);
        }
    }

    static function requireSdkFile(name:String, relParts:Array<String>):Void {
        var value = Sys.getEnv(name);
        if (value == null || value == "") return; // requireEnv already handled it
        var marker = haxe.io.Path.join([value].concat(relParts));
        if (!sys.FileSystem.exists(marker)) {
            fail('$name is set but does not look like an FMOD Engine SDK',
                'haxefmod: $name is set but does not look like an FMOD Engine SDK.\n'
                + "\n"
                + '  $name = $value\n'
                + '  Missing: $marker\n'
                + "\n"
                + "  Check the path for typos, or re-download the FMOD Engine from https://www.fmod.com/download\n"
                + "\n"
                + "  Verify your setup with: haxelib run haxefmod check");
        }
    }

    /** Prints the full instruction block, then fails compilation with a
        one-line error anchored to the project file. A multi-line
        Context.fatalError renders every line behind a position prefix,
        "(unknown) : ..." under --macro. */
    static function fail(summary:String, details:String):Void {
        var stderr = Sys.stderr();
        stderr.writeString("\n" + details + "\n\n");
        stderr.flush();
        Context.fatalError('haxefmod: $summary (setup instructions above)', errorPos());
    }

    /** A real position for the error line: the project's own project.xml,
        the file that pulls in haxefmod. The message then names the project
        configuration problem instead of "(unknown)". */
    static function errorPos() {
        // Heaps and Kha projects have no lime project file, so their
        // build file or khafile carries the error instead
        var candidates = ["project.xml", "Project.xml", "application.xml", "khafile.js"];
        for (file in sys.FileSystem.readDirectory(".")) {
            if (StringTools.endsWith(file, ".hxml")) candidates.push(file);
        }
        for (candidate in candidates) {
            if (sys.FileSystem.exists(candidate)) {
                return Context.makePosition({min: 0, max: 0, file: candidate});
            }
        }
        return Context.currentPos();
    }
}
#end
