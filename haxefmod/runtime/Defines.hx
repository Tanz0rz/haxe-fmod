package haxefmod.runtime;

import haxe.macro.Context;
import haxe.macro.Expr;

/**
 * Compile-time access to -D haxefmod_* define values (getDefine is only
 * available in macro context, so runtime code goes through these helpers).
 */
class Defines {
    public static macro function getInt(name:String, fallback:Int):Expr {
        var value = Context.definedValue(name);
        var parsed = value == null ? null : Std.parseInt(value);
        return macro $v{parsed == null ? fallback : parsed};
    }

    public static macro function getString(name:String, fallback:String):Expr {
        var value = Context.definedValue(name);
        return macro $v{value == null || value == "1" ? fallback : value};
    }
}
