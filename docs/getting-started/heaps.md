# Getting started with Heaps

This walks a Heaps project from an empty hxml to a playing sound, on HashLink and in the browser. The [HeapsPlatformer example](https://github.com/Tanz0rz/haxe-fmod/tree/master/example-project/HeapsPlatformer) is a complete Heaps game using the library, with a `build.sh` that runs every step below.

## Prerequisites

**Haxe** - built and tested against 4.3.6, with 4.3.7 covered by the nightly canary. Haxe 5 is not tested yet.

**HashLink** - the desktop target runs on the HashLink VM, so install [HashLink](https://hashlink.haxe.org/) and make sure `hl` is on your path. Browser builds need no VM.

**FMOD Engine SDK** - Download version 2.03.12 from [fmod.com/download](https://www.fmod.com/download). Step 3 below covers the setup.

## 1. Add the library to your build

```bash
haxelib install haxefmod
```

Add the library and the build check to your hxml, next to the heaps entries you already have:

```text
-cp src
-lib heaps
-lib hlsdl
-lib haxefmod
-main Main
--macro haxefmod.tools.BuildCheck.verify()
-hl build/hl/game.hl
```

The `BuildCheck.verify()` macro stops the compile with a clear message when `FMOD_SDK` (or `FMOD_SDK_WEB` for a js build) is missing or points at the wrong package, so a misconfigured environment fails before the game window ever opens.

## 2. Download FMOD Studio and set up your project

All the audio for your game is authored and mixed in [FMOD Studio](https://fmod.com/download). Install the [constants export script](../guides/tools-cli.md#the-fmod-studio-export-script) in it before moving on, so building banks also writes the Haxe constants your code references.

## 3. Set up the FMOD Engine SDK

The SDK is a separate download from FMOD Studio, and the library does not bundle it. Point `FMOD_SDK` at the desktop package for HashLink builds and `FMOD_SDK_WEB` at the HTML5 package for browser builds. Both can stay set at once.

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

Only version 2.03.12 is officially supported. [Selecting an FMOD Engine version](../platforms.md#selecting-an-fmod-engine-version) covers running on another one.

## 4. Check your setup

```bash
haxelib run haxefmod check
```

Run it from the project directory. Every line should end in a check mark, and a failing line names the fix.

## 5. Play something

Call `FmodHeapsSetup.init()` once from your `hxd.App`'s `init()`. It initializes FMOD, keeps `FmodManager.Update()` running every frame, and mutes the master output while the window is unfocused (see [Heaps components](../guides/heaps.md)).

```haxe
import haxefmod.FmodManager;
import haxefmod.heaps.FmodHeapsSetup;

class Main extends hxd.App {
    override function init() {
        FmodHeapsSetup.init();
        FmodManager.PlaySong(FmodEvents.MusicMainLevel);
    }

    static function main() {
        new Main();
    }
}
```

`FmodEvents` is one of the [generated constants classes](../guides/tools-cli.md#generate). Plain event paths like `"event:/Music/MainLevel"` work as well.

Put your banks in `assets/fmod/Desktop` next to where the game runs. That folder is the default, and the `bankFolder` setting moves it (see [Banks and settings](../guides/banks-and-settings.md)).

## 6. Build and run on HashLink

Compile as usual, then stage the FMOD runtime files next to the output:

```bash
haxe build-hl.hxml
haxelib run haxefmod stage linux hl build/hl
```

Pass `mac` or `windows` instead of `linux` on those platforms. The [stage command](../guides/tools-cli.md#stage) copies the FMOD libraries and `hlaxe_fmod.hdll` into the directory and writes a launcher (`run.sh`, or `run.cmd` on Windows) that starts the game with the right library path.

```bash
cd build/hl && ./run.sh
```

You should hear your event right away. Silence with a successful build usually means the banks are missing from `assets/fmod/Desktop`, and the game's console output says so when `FmodManager.EnableDebugMessages()` is on.

## 7. Build and run in the browser

A js build stages the FMOD web engine instead of native libraries:

```bash
haxe build-js.hxml
haxelib run haxefmod stage html5 html5 build/html5/lib
```

Load the engine scripts ahead of the game in your page:

```html
<script src="lib/fmodstudio.js"></script>
<script src="lib/jaxe.js"></script>
<script src="game.js"></script>
```

Serve the directory as a static site with the banks under `assets/fmod/Desktop`. FMOD initializes asynchronously in the browser, so gate your first scene on `FmodManager.IsInitialized()`. [Platforms](../platforms.md#html5) covers the loading pattern and the browser autoplay rules.

## Next

[Heaps components](../guides/heaps.md) covers the emitters, listeners, and bank loaders that follow `h2d.Object`s for you, and [FmodManager](../guides/fmod-manager.md) covers the facade in full.
