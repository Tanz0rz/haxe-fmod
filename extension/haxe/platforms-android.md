# platforms-android

## Java
verdict: cannot Android is not a haxefmod target, the library ships Windows, Linux, and macOS (C++ and HashLink) and HTML5 builds only

## Java#2
verdict: cannot Android is not a haxefmod target, the library ships Windows, Linux, and macOS (C++ and HashLink) and HTML5 builds only

## Application Lifecycle Management
verdict: cannot Android is not a haxefmod target, the library ships Windows, Linux, and macOS (C++ and HashLink) and HTML5 builds only

## Application Lifecycle Management#2
verdict: bound
```haxe
import haxefmod.core.CoreSystem;

function onStart():Void {
    CoreSystem.mixerResume();
}

function onStop():Void {
    CoreSystem.mixerSuspend();
}

function onDestroy():Void {
    CoreSystem.mixerResume();
}
```

