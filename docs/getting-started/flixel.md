# Getting started with HaxeFlixel

This walks a new project from an empty `Project.xml` to a playing sound. The library is tested on games built with the `lime` and `openfl` CLI tools and works on any Haxe framework that uses `Project.xml` for builds. The [example project](https://github.com/Tanz0rz/haxe-fmod/tree/master/example-project/EZPlatformer) is a complete HaxeFlixel game using it.

## Prerequisites

**Haxe** - built and tested against 4.3.6, with 4.3.7 covered by the nightly canary. Haxe 5 is not tested yet.

**FMOD Engine SDK** - Download version 2.03.12 from [fmod.com/download](https://www.fmod.com/download). Step 3 below covers the setup.

Projects that need C++ builds (so building via `lime build mac`, `lime build windows`, and/or `lime build linux`) require a C++ compiler to be installed locally. HashLink and HTML5 builds do not.

- **macOS**: Xcode Command Line Tools - install with `xcode-select --install`
- **Windows**: Build Tools for Visual Studio 2022 with the "Desktop development with C++" workload selected during installation. [Direct download](https://aka.ms/vs/17/release.ltsc.17.4/vs_buildtools.exe), or find the Fall 2022 LTSC build tools link [here](https://learn.microsoft.com/en-us/visualstudio/releases/2022/release-history#release-dates-and-build-numbers).
- **Linux**: `gcc` and `g++` (install via your package manager, e.g. `sudo apt install build-essential`)

## 1. Add the library to your Haxe project

```bash
haxelib install haxefmod
```

If required, import the library in your project. On HaxeFlixel projects, add `<haxelib name="haxefmod" />` to the "Libraries" section of your `Project.xml` file.

## 2. Download FMOD Studio and set up your project

This will be the tool you use to manage all audio for your game. Download FMOD Studio [here](https://fmod.com/download). Once installed, install the [constants export script](../guides/tools-cli.md#the-fmod-studio-export-script) so building banks also writes the Haxe constants your code references.

## 3. Set up the FMOD Engine SDK

This library requires you to supply your own FMOD Engine SDK (separate from FMOD Studio). The only officially supported version is 2.03.12. Download it from [fmod.com/download](https://www.fmod.com/download).

If you would like to use any other version of the FMOD Engine, see [Selecting an FMOD Engine version](../platforms.md#selecting-an-fmod-engine-version).

**For C++ and HashLink builds**, set the `FMOD_SDK` environment variable to point to the FMOD Engine directory:

```bash
# For Linux/macOS
# in ~/.bashrc or ~/.zshrc
export FMOD_SDK="$HOME/fmod/fmodstudioapi20312" # (use $HOME, not ~)

# For Windows
# in the Environment Variables UI
# FMOD_SDK=C:\path\to\fmodstudioapi20312
```

**For HTML5 builds**, set a separate `FMOD_SDK_WEB` variable:

```bash
# For Linux/macOS
# in ~/.bashrc or ~/.zshrc
export FMOD_SDK_WEB="$HOME/fmod/fmodstudioapi20312html5" # (use $HOME, not ~)

# For Windows
# in the Environment Variables UI
# FMOD_SDK_WEB=C:\path\to\fmodstudioapi20312html5
```

This allows you to have both your C++/HashLink SDK and HTML5 SDK configured simultaneously.

## 4. Check your setup

`haxelib run haxefmod check` will check various aspects of your local dev environment to verify your setup and is **highly recommended**.

```bash
haxelib run haxefmod check
```

Every line it prints should end in a check mark. It reports what is missing and how to fix it, so run it again whenever a build fails in a way you do not understand.

## 5. Play something

Banks are loaded from `assets/fmod/Desktop` by default (see [Banks and settings](../guides/banks-and-settings.md) to change that). With `Master.bank` and `Master.strings.bank` in that folder, the facade is ready to use.

Call `haxefmod.flixel.FmodFlxSetup.init()` once in your first state. It initializes FMOD, keeps `FmodManager.Update()` running every frame in every state, and wires the flixel volume keys to the FMOD master bus (see [Flixel components](../guides/flixel.md)).

```haxe
import haxefmod.flixel.FmodFlxSetup;

public function StartGame():Void {
    FmodFlxSetup.init();
    FmodManager.PlaySong(FmodEvents.MusicMainLevel);
}

public function JumpPressed():Void {
    FmodManager.PlaySoundOneShot(FmodEvents.SFXJump);
}
```

`FmodEvents` is one of the [generated constants classes](../guides/tools-cli.md#generate). The string paths work too, for example `FmodManager.PlaySong("event:/Music/MainLevel")`.

HTML5 initializes asynchronously, so an HTML5 game waits for `FmodManager.IsInitialized()` before its first scene. [Platforms](../platforms.md#html5) shows the loading state pattern.

## 6. Build and run

All targets work with standard lime commands:

```bash
lime test html5
lime test hl
lime test windows
lime test linux
lime test mac
```

You should hear your event as soon as the game window opens. If the build succeeds but stays silent, run `haxelib run haxefmod check` from the project directory and read the game's console output with `FmodManager.EnableDebugMessages()` on.

**macOS note**: SDK libraries downloaded through a browser carry the quarantine attribute. FMOD signs its libraries so builds normally run without issue, but if macOS blocks the dylibs, clear the flag with `xattr -dr com.apple.quarantine "$FMOD_SDK"`.

## Next

[FmodManager](../guides/fmod-manager.md) covers the facade in full, [Flixel components](../guides/flixel.md) covers the drop-in emitters, listeners, and loaders, and [Handles and results](../guides/handles-and-results.md) explains the conventions every deeper call follows.
