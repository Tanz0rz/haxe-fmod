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

        if (Context.defined("html5")) {
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
    }

    static function requireEnv(name:String, message:String):Void {
        var value = Sys.getEnv(name);
        if (value == null || value == "") {
            Context.fatalError(message, Context.currentPos());
        }
    }
}
#end
