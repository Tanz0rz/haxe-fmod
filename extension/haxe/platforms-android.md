# platforms-android

## Java
verdict: cannot Android is not a haxefmod target, the library ships Windows, Linux, and macOS (C++ and HashLink) and HTML5 builds only

## Java#2
verdict: cannot Android is not a haxefmod target, the library ships Windows, Linux, and macOS (C++ and HashLink) and HTML5 builds only

## Application Lifecycle Management
verdict: cannot Android is not a haxefmod target, the library ships Windows, Linux, and macOS (C++ and HashLink) and HTML5 builds only

## Application Lifecycle Management#2
verdict: bound
Android is not a haxefmod target. The same calls suspend and resume the mixer on desktop when the game goes to the background.
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
