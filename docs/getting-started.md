# Getting started

This walks a new project from an empty `Project.xml` to a playing sound. The library is tested on games built with the `lime` and `openfl` CLI tools and works on any Haxe framework that uses `Project.xml` for builds. The [example project](https://github.com/Tanz0rz/haxe-fmod/tree/master/example-project/EZPlatformer) is a complete HaxeFlixel game using it.

## Supported platforms

| Platform | Architecture | Targets |
|---|---|---|
| HTML5 | All | WebAssembly |
| Windows | x86_64 | C++, HashLink |
| Linux | x86_64 | C++, HashLink |
| macOS | ARM64 (Apple Silicon) | C++, HashLink |

## Prerequisites

**Haxe** 4.3.6 or 4.3.7. Haxe 5 is untested.

**FMOD Engine SDK** 2.03.12 from [fmod.com/download](https://www.fmod.com/download). See [Selecting an FMOD Engine version](platforms.md#selecting-an-fmod-engine-version) for other versions.

**A C++ compiler** for C++ builds only (`lime build windows`, `linux`, or `mac`). HashLink and HTML5 builds do not need one.

- macOS: Xcode Command Line Tools, `xcode-select --install`.
- Windows: Build Tools for Visual Studio 2022 with the "Desktop development with C++" workload. [Direct download](https://aka.ms/vs/17/release.ltsc.17.4/vs_buildtools.exe).
- Linux: `gcc` and `g++`, for example `sudo apt install build-essential`.

## 1. Add the library

Install from haxelib and add it to your project.

```bash
haxelib install haxefmod
```

```xml
<haxelib name="haxefmod" />
```

## 2. Set up FMOD Studio

FMOD Studio is the authoring tool your sound designer uses. Download it from [fmod.com/download](https://fmod.com/download), then install the [constants export script](guides/tools-cli.md#the-fmod-studio-export-script) so building banks also writes the Haxe constants your code references.

## 3. Point the library at the FMOD Engine SDK

The SDK is separate from FMOD Studio and is not bundled with the library. Set `FMOD_SDK` for C++ and HashLink builds and `FMOD_SDK_WEB` for HTML5 builds. Both can be set at once.

```bash
# Linux/macOS, in ~/.bashrc or ~/.zshrc (use $HOME, not ~)
export FMOD_SDK="$HOME/fmod/fmodstudioapi20312"
export FMOD_SDK_WEB="$HOME/fmod/fmodstudioapi20312html5"
```

On Windows set the same two variables in the Environment Variables UI, for example `FMOD_SDK=C:\path\to\fmodstudioapi20312`.

## 4. Check the setup

```bash
haxelib run haxefmod check
```

The check verifies the SDK path and version, the compiler for your platform, and the HashLink headers. Run it whenever a build fails in a way you do not understand.

## 5. Play something

Banks are loaded from `assets/fmod/Desktop` by default (see [Banks and settings](guides/banks-and-settings.md) to change that). With `Master.bank` and `Master.strings.bank` in that folder, the facade is ready to use.

```haxe
public function StartLevel():Void {
    FmodManager.PlaySong(FmodEvents.MusicMainLevel);
}

public function JumpPressed():Void {
    FmodManager.PlaySoundOneShot(FmodEvents.SFXJump);
}

public function StartEngine():Void {
    engineSound = FmodManager.PlaySound(FmodEvents.SFXEngine);
    engineSound.setParameter("RPM", 0.2);
}
```

`FmodEvents` is one of the [generated constants classes](guides/tools-cli.md#generate). The string paths work too, for example `FmodManager.PlaySong("event:/Music/MainLevel")`.

Call `FmodManager.Update()` once per frame. HaxeFlixel games can call `haxefmod.flixel.FmodFlxSetup.init()` once in their first state instead, which also wires the flixel volume keys to FMOD (see [Flixel components](guides/flixel.md)).

HTML5 initializes asynchronously, so an HTML5 game waits for `FmodManager.IsInitialized()` before its first scene. [Platforms](platforms.md#html5) shows the loading state pattern.

## 6. Build and run

```bash
lime test html5
lime test hl
lime test windows
lime test linux
lime test mac
```

On macOS, SDK libraries downloaded through a browser carry the quarantine attribute. FMOD signs its libraries so builds normally run without issue. If macOS blocks the dylibs anyway, clear the flag with `xattr -dr com.apple.quarantine "$FMOD_SDK"`.

## Next

[FmodManager](guides/fmod-manager.md) covers the facade in full, and [Handles and results](guides/handles-and-results.md) explains the conventions every deeper call follows.
