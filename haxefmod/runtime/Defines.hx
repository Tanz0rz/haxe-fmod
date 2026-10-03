package haxefmod.runtime;

import haxe.macro.Context;
import haxe.macro.Expr;

/**
 * Compile-time access to -D haxefmod_* define values (getDefine is only
 * available in macro context, so runtime code goes through these helpers).
 */
@:dox(hide)
class Defines {
    public static macro function getInt(name:String, fallback:Int):Expr {
        var value = Context.definedValue(name);
        // A define with no value reads as "1", the way a flag does. It
        // means the fallback here, since 1 is never a wanted count.
        var parsed = value == null || value == "1" ? null : Std.parseInt(value);
        return macro $v{parsed == null ? fallback : parsed};
    }

    public static macro function getString(name:String, fallback:String):Expr {
        var value = Context.definedValue(name);
        return macro $v{value == null || value == "1" ? fallback : value};
    }
}
