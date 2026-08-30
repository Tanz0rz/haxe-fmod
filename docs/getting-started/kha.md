# Getting started with Kha

This walks a Kha project from an empty khafile to a playing sound, natively and in the browser. The [KhaPlatformer example](https://github.com/Tanz0rz/haxe-fmod/tree/master/example-project/KhaPlatformer) is a complete Kha game using the library, with a `build.sh` that runs every step below.

## Prerequisites

**Haxe and Node.js** - Kha builds run through khamake from a [Kha](https://github.com/Kode/Kha) checkout, which brings its own Haxe. Node runs `make.js`.

**A C++ compiler** - Kha's native targets always compile C++ through Kore, so the platform toolchain is required: Xcode Command Line Tools on macOS, Visual Studio 2022 on Windows, `gcc` and `g++` on Linux.

**FMOD Engine SDK** - Download version 2.03.12 from [fmod.com/download](https://www.fmod.com/download). Step 3 below covers the setup.

## 1. Add the library to your khafile

```bash
haxelib install haxefmod
```

```js
project.addLibrary('haxefmod');
project.addParameter('--macro haxefmod.tools.BuildCheck.verify()');
```

Adding the library also pulls in its `kfile.js`, so the native FMOD binding is compiled straight into your executable. There is no separate native library to manage on Kha.

The `BuildCheck.verify()` parameter fails the build early with a clear message when `FMOD_SDK` (or `FMOD_SDK_WEB` for html5) is missing or points at the wrong package.

## 2. Download FMOD Studio and set up your project

Your game's audio is authored in [FMOD Studio](https://fmod.com/download), so grab it next if you have not already. Add the [constants export script](../guides/tools-cli.md#the-fmod-studio-export-script) to it, and every bank build also refreshes the Haxe constants your code references.

## 3. Set up the FMOD Engine SDK

FMOD Studio and the FMOD Engine SDK are separate downloads, and the library bundles neither. Native builds read `FMOD_SDK`, html5 builds read `FMOD_SDK_WEB`, and both can stay set at once.

```bash
# For Linux/macOS
# in ~/.bashrc or ~/.zshrc
export FMOD_SDK="$HOME/fmod/fmodstudioapi20312" # (use $HOME, not ~)
export FMOD_SDK_WEB="$HOME/fmod/fmodstudioapi20312html5"

# For Windows
# in the Environment Variables UI
# FMOD_SDK=C:\path\to\fmodstudioapi20312
# FMOD_SDK_WEB=C:\path\to\fmodstudioapi20312html5
```

On Linux the linker also needs the SDK's library directories, since the binding links `-lfmod -lfmodstudio`:

```bash
export LIBRARY_PATH="$FMOD_SDK/api/core/lib/x86_64:$FMOD_SDK/api/studio/lib/x86_64${LIBRARY_PATH:+:$LIBRARY_PATH}"
```

Version 2.03.12 is the tested one. For anything else, read [Selecting an FMOD Engine version](../platforms.md#selecting-an-fmod-engine-version) first.

## 4. Check your setup

```bash
haxelib run haxefmod check
```

Run it from the project directory and read any line that does not end in a check mark. Each failure names its fix.

## 5. Play something

Call `FmodKhaSetup.init()` once from the `System.start` callback. It initializes FMOD, keeps `FmodManager.Update()` running every frame, and mutes the master output while the application is in the background (see [Kha components](../guides/kha.md)).

```haxe
import haxefmod.FmodManager;
import haxefmod.kha.FmodKhaSetup;
import kha.System;

class Main {
    static function main() {
        System.start({title: "Game", width: 640, height: 480}, _ -> {
            FmodKhaSetup.init();
            FmodManager.PlaySong(FmodEvents.MusicMainLevel);
        });
    }
}
```

The `FmodEvents` constants come from the [generator](../guides/tools-cli.md#generate), and every call also accepts the raw event path string.

Banks load from `assets/fmod/Desktop` relative to where the game runs, and the `bankFolder` setting moves that (see [Banks and settings](../guides/banks-and-settings.md)).

## 6. Build and run natively

Build through khamake, then stage the FMOD runtime files next to the executable:

```bash
node /path/to/Kha/make.js linux --compile
haxelib run haxefmod stage linux cpp path/to/output
```

Pass `osx` or `windows` to khamake on those platforms, and their platform name to the [stage command](../guides/tools-cli.md#stage). The target is `cpp` on every native Kha build, Kore HL/C included, because the binding is compiled into the executable rather than loaded from an hdll. Copy your banks to `assets/fmod/Desktop` next to the executable and run it from that directory.

You should hear your event as soon as the window opens. A silent run with a clean build points at missing banks, and the console output names the failing path when `FmodManager.EnableDebugMessages()` is on.

For a Kore HL/C build, set `HAXEFMOD_KHA_HL=1` in the environment before khamake so the library compiles its HashLink binding instead of the hxcpp one.

## 7. Build and run in the browser

```bash
node /path/to/Kha/make.js html5
haxelib run haxefmod stage html5 html5 build/html5/lib
```

khamake writes an `index.html` only when none exists, so provide your own that loads the FMOD engine ahead of the game:

```html
<script src="lib/fmodstudio.js"></script>
<script src="lib/jaxe.js"></script>
<script src="kha.js"></script>
```

Host the directory as a static site, banks included under `assets/fmod/Desktop`. In the browser FMOD comes up asynchronously, so hold your first scene until `FmodManager.IsInitialized()` reports true. The loading pattern and the autoplay rules are on the [Platforms](../platforms.md#html5) page.

## Next

[Kha components](../guides/kha.md) covers the emitters, listeners, and bank loaders that follow your game objects, and [FmodManager](../guides/fmod-manager.md) covers the facade in full.
