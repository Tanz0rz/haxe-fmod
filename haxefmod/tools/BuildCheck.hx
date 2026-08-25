package haxefmod.tools;

#if macro
import haxe.macro.Context;

/**
 * Compile-time environment check, wired by include.xml so it runs on every
 * lime build of a project using haxefmod.
 *
 * A missing FMOD SDK previously only surfaced through the postbuild step,
 * whose failure lime ignores: the game would compile, launch, and run with
 * no audio (or crash loading libraries) while the real error scrolled past
 * in the build output. Failing COMPILATION is the only reliable way to stop
 * `lime test` before the game window ever opens.
 */
class BuildCheck {
    public static function verify():Void {
        // IDE completion/diagnostics runs compile the project without the
        // shell environment. Never block those
        if (Context.defined("display")) return;
        // Only lime builds ship FMOD runtimes. Unit tests and plain haxe
        // compiles have nothing to verify
        if (!Context.defined("lime")) return;

        // Lime defines "html5" for the html5 target. "js" covers the same
        // build if that define ever changes (the only lime js target is html5)
        if (Context.defined("html5") || Context.defined("js")) {
            requireEnv("FMOD_SDK_WEB",
                "haxefmod: FMOD_SDK_WEB is not set - HTML5 builds cannot include the FMOD engine.\n"
                + "\n"
                + "  1. Download the FMOD Engine HTML5 package (version 2.03.12) from https://www.fmod.com/download\n"
                + "  2. Set FMOD_SDK_WEB to the extracted directory, e.g.\n"
                + "       export FMOD_SDK_WEB=\"$HOME/fmod/fmodstudioapi20312html5\"\n"
                + "  3. Restart your terminal (or IDE) so the build sees the variable\n"
                + "\n"
                + "  Verify your setup with: haxelib run haxefmod check");
        } else if (Context.defined("hl") || Context.defined("cpp")) {
            requireEnv("FMOD_SDK",
                "haxefmod: FMOD_SDK is not set - the game would launch without any audio.\n"
                + "\n"
                + "  1. Download the FMOD Engine (version 2.03.12) from https://www.fmod.com/download\n"
                + "  2. Set FMOD_SDK to the extracted directory, e.g.\n"
                + "       export FMOD_SDK=\"$HOME/fmod/fmodstudioapi20312\"   (Linux/macOS)\n"
                + "       FMOD_SDK=C:\\path\\to\\fmodstudioapi20312           (Windows)\n"
                + "  3. Restart your terminal (or IDE) so the build sees the variable\n"
                + "\n"
                + "  Verify your setup with: haxelib run haxefmod check");
        }

        // A set-but-wrong path must fail the same as an unset one:
        // the postbuild guards also catch it, but lime can bury their exit
        // code, so the compile-time check is the reliable block
        if (Context.defined("html5") || Context.defined("js")) {
            requireSdkFile("FMOD_SDK_WEB", ["api", "studio", "lib", "wasm", "fmodstudio.js"]);
        } else if (Context.defined("hl") || Context.defined("cpp")) {
            requireSdkFile("FMOD_SDK", ["api", "core", "inc", "fmod_common.h"]);
        }

        if (Context.defined("hl")) {
            verifyHlHdllGate();
        }
        if (Context.defined("html5") || Context.defined("js")) {
            verifyWebSdkVersionGate();
        }
    }

    /**
     * html5 supports exactly the expected FMOD web SDK version: the JS
     * shim's numeric tables (DSP types among them) are that version's
     * values, the wasm exposes no version query to adapt at runtime, and
     * there is no custom-hdll escape hatch on this target. A mismatched
     * web SDK previously built with only a postbuild warning and created
     * WRONG DSP EFFECTS at runtime.
     */
    static function verifyWebSdkVersionGate():Void {
        var sdkPath = Sys.getEnv("FMOD_SDK_WEB");
        if (sdkPath == null || sdkPath == "") return; // requireEnv handled it
        var sdkHeader = haxe.io.Path.join([sdkPath, "api", "core", "inc", "fmod_common.h"]);
        if (!sys.FileSystem.exists(sdkHeader)) return; // header layout varies, postbuild warns
        var libRoot = resolveLibRoot();
        if (libRoot == null) return;
        var versionFile = haxe.io.Path.join([libRoot, "fmod_expected_version"]);
        if (!sys.FileSystem.exists(versionFile)) return;
        var expectedHex = StringTools.trim(sys.io.File.getContent(versionFile));
        var sdkHex = PostBuild.parseFmodVersion(sdkHeader);
        if (sdkHex == null || sdkHex == expectedHex) return;

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
     * (CommandHelper.executeCommands ignores the Sys.command result), so
     * only failing compilation reliably stops `lime test` before a
     * mismatched hdll crashes the game at startup.
     */
    static function verifyHlHdllGate():Void {
        var sdkPath = Sys.getEnv("FMOD_SDK");
        if (sdkPath == null || sdkPath == "") return; // requireEnv handled it
        var sdkHeader = haxe.io.Path.join([sdkPath, "api", "core", "inc", "fmod_common.h"]);
        if (!sys.FileSystem.exists(sdkHeader)) return; // requireSdkFile handled it
        var libRoot = resolveLibRoot();
        if (libRoot == null) return;
        var versionFile = haxe.io.Path.join([libRoot, "fmod_expected_version"]);
        if (!sys.FileSystem.exists(versionFile)) return; // packaging problem, postbuild warns
        var expectedHex = StringTools.trim(sys.io.File.getContent(versionFile));
        var sdkHex = PostBuild.parseFmodVersion(sdkHeader);

        var projectDir = Sys.getCwd();
        var customHdll = haxe.io.Path.join([projectDir, ".haxefmod", "hlaxe_fmod.hdll"]);
        var markerFile = haxe.io.Path.join([projectDir, ".haxefmod", "hlaxe_fmod.version"]);
        var haveCustom = sys.FileSystem.exists(customHdll);
        var markerHex = sys.FileSystem.exists(markerFile)
            ? StringTools.trim(sys.io.File.getContent(markerFile)) : null;

        // An unparseable header skips the version gate (postbuild warns)
        // but never the ABI gate below
        if (sdkHex != null && expectedHex != sdkHex && !(haveCustom && markerHex == sdkHex)) {
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

        // ABI check on the hdll the build will use (the custom one when its
        // marker matches the SDK, the shipped pre-built one otherwise)
        var expectedAbi = PostBuild.expectedAbiVersion(libRoot);
        if (expectedAbi <= 0) return;
        var useCustom = haveCustom
            && (markerHex == null || sdkHex == null || markerHex == sdkHex);
        var hdll = useCustom ? customHdll : haxe.io.Path.join(
            [libRoot, "templates", "bin", "hl", prebuiltPlatformDir(), "hlaxe_fmod.hdll"]);
        if (!sys.FileSystem.exists(hdll)) return; // postbuild reports the missing hdll
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

    static function prebuiltPlatformDir():String {
        return switch (Sys.systemName()) {
            case "Windows": "Windows64";
            case "Mac": "Mac64";
            default: "Linux64";
        }
    }

    // The library root is the parent of the haxefmod/ classpath this macro
    // was loaded from. Path-based, so it survives lime's space-splitting of
    // postbuild arguments and needs no haxelib subprocess.
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

    /** Prints the full instruction block (a multi-line
        Context.fatalError renders every line behind a position prefix,
        "(unknown) : ..." under --macro), then fails compilation with a
        one-line error anchored to the project file. */
    static function fail(summary:String, details:String):Void {
        var stderr = Sys.stderr();
        stderr.writeString("\n" + details + "\n\n");
        stderr.flush();
        Context.fatalError('haxefmod: $summary (setup instructions above)', errorPos());
    }

    /** A real position for the error line: the project's own project.xml
        (the file that pulls in haxefmod), so the message reads as the
        project configuration problem it is instead of "(unknown)". */
    static function errorPos() {
        for (candidate in ["project.xml", "Project.xml", "application.xml"]) {
            if (sys.FileSystem.exists(candidate)) {
                return Context.makePosition({min: 0, max: 0, file: candidate});
            }
        }
        return Context.currentPos();
    }
}
#end
