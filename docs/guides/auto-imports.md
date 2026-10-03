# Auto-imports

An `import.hx` at the root of your source path imports its contents into every module under that path. This is a Haxe compiler feature. It works the same on every engine and target.

```haxe
#if !macro
import haxefmod.FmodManager;
import FmodEvents;
#end
```

Add one line for each generated class your game uses, such as `FmodBuses` or `FmodParameters`.

The `#if !macro` guard keeps these imports out of the macro context. Haxe applies `import.hx` to macro code in the same folder too.
