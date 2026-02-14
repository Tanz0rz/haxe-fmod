package haxefmod;

#if macro
import haxe.macro.Context;
import haxe.macro.Compiler;

class FmodBuildMacro {
    public static function checkEnvironment() {
        #if js
        // For HTML5 builds, verify FMOD_SDK_WEB is set
        var fmodSdkWeb = Sys.getEnv("FMOD_SDK_WEB");
        if (fmodSdkWeb == null || fmodSdkWeb == "") {
            Context.error(
                "\n" +
                "============================================================\n" +
                "  ERROR: FMOD_SDK_WEB environment variable is not set.\n" +
                "\n" +
                "  HTML5 builds require the FMOD Engine SDK for HTML5.\n" +
                "\n" +
                "  1. Download FMOD Engine 2.03.12 for HTML5 from:\n" +
                "     https://www.fmod.com/download\n" +
                "\n" +
                "  2. Extract it and set FMOD_SDK_WEB:\n" +
                "\n" +
                "     export FMOD_SDK_WEB=/path/to/fmodstudioapi20312html5\n" +
                "\n" +
                "     Or on Windows:\n" +
                "     set FMOD_SDK_WEB=C:\\\\path\\\\to\\\\fmodstudioapi20312html5\n" +
                "\n" +
                "  3. Run 'haxelib run haxefmod doctor' to verify your setup.\n" +
                "\n" +
                "============================================================\n",
                Context.currentPos()
            );
        }
        #end
    }
}
#end
