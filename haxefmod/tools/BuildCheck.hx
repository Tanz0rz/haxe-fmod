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
        // shell environment; never block those
        if (Context.defined("display")) return;
        // Only lime builds ship FMOD runtimes; unit tests and plain haxe
        // compiles have nothing to verify
        if (!Context.defined("lime")) return;

        // Lime defines "html5" for the html5 target; "js" covers the same
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

        // A set-but-wrong path must fail just as loudly as an unset one:
        // the postbuild guards also catch it, but lime can bury their exit
        // code, so the compile-time check is the reliable block
        if (Context.defined("html5") || Context.defined("js")) {
            requireSdkFile("FMOD_SDK_WEB", ["api", "studio", "lib", "wasm", "fmodstudio.js"]);
        } else if (Context.defined("hl") || Context.defined("cpp")) {
            requireSdkFile("FMOD_SDK", ["api", "core", "inc", "fmod_common.h"]);
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

    /** Prints the full instruction block cleanly (a multi-line
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
