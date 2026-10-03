package haxefmod.studio.native;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

/**
 * Compile-time gate for calls FMOD's web build cannot make.
 *
 * A method that works on native targets only is declared twice in its
 * type. One declaration is the real inline body. The other sits under
 * `#if (macro || (js && !haxefmod_html5_allow_unsupported))` and is a
 * macro method that calls `block`. On a js build the macro runs at every
 * call site and stops compilation there. The error names the method and
 * the reason.
 *
 * Projects that share code across targets and branch at runtime opt out
 * with `-D haxefmod_html5_allow_unsupported`. The call then compiles to
 * the real method, which fails with FMOD_ERR_UNSUPPORTED in the browser.
 * EventInstance.clearProgrammerSound returns FMOD_OK there. The library
 * prints one warning per build saying so.
 */
class Html5Gate {
    #if macro
    /** The error every gated method raises at its call site on a js build. */
    public static function block(method:String, reason:String, ?outcome:String):Expr {
        if (outcome == null) outcome = "The call then fails with FMOD_ERR_UNSUPPORTED at runtime in the browser. A getter returns its failure value. The game must handle that.";
        Context.error(method + " is unsupported in HTML5 (" + reason + ")."
            + " FMOD's web build cannot do this, so haxefmod refuses to compile the call for a js target."
            + " Build with -D haxefmod_html5_allow_unsupported to compile it anyway."
            + " " + outcome,
            Context.currentPos());
        return macro null;
    }

    /**
     * Build macro on the js backend class. Prints the opt-out disclaimer
     * once per build when the define is set, so nobody forgets it is on.
     */
    public static function disclaim():Array<Field> {
        if (Context.defined("js") && Context.defined("haxefmod_html5_allow_unsupported")) {
            Context.warning("haxefmod_html5_allow_unsupported is set: calls that FMOD's web build cannot make"
                + " compile in this build and fail with FMOD_ERR_UNSUPPORTED at runtime in the browser. EventInstance.clearProgrammerSound returns FMOD_OK there."
                + " Check those results, or drop the define to have the compiler point out every such call.",
                Context.currentPos());
        }
        return Context.getBuildFields();
    }
    #end
}
