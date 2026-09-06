# Getting started

This walks a new project from an empty build file to a playing sound. Where engines differ, the step shows one tab per engine. Pick yours on any tab group and every tab group on the site follows, so this page and the guides read as if they were written for your engine alone.

The library is tested on games built with the `lime` and `openfl` CLI tools (HaxeFlixel and friends), on Heaps, and on Kha. Each engine has a complete example game: [EZPlatformer](https://github.com/Tanz0rz/haxe-fmod/tree/master/example-project/EZPlatformer) (HaxeFlixel), [HeapsPlatformer](https://github.com/Tanz0rz/haxe-fmod/tree/master/example-project/HeapsPlatformer), and [KhaPlatformer](https://github.com/Tanz0rz/haxe-fmod/tree/master/example-project/KhaPlatformer). [Using another framework?](#using-another-framework) covers everything else.

## Supported platforms

=== "HaxeFlixel"

    | Platform | Architecture | Targets |
    |---|---|---|
    | HTML5 | All | WebAssembly |
    | Windows | x86_64 | C++, HashLink |
    | Linux | x86_64 | C++, HashLink |
    | macOS | ARM64 (Apple Silicon) | C++, HashLink |

=== "Heaps"

    | Platform | Architecture | Targets |
    |---|---|---|
    | HTML5 | All | WebAssembly |
    | Windows | x86_64 | HashLink |
    | Linux | x86_64 | HashLink |
    | macOS | ARM64 (Apple Silicon) | HashLink (compiled through HL/C) |

=== "Kha"

    | Platform | Architecture | Targets |
    |---|---|---|
    | HTML5 | All | WebAssembly |
    | Windows | x86_64 | Kore C++, Kore HL/C |
    | Linux | x86_64 | Kore C++, Kore HL/C |
    | macOS | ARM64 (Apple Silicon) | Kore C++, Kore HL/C |

## Prerequisites

**Haxe** - built and tested against 4.3.6, with 4.3.7 covered by the nightly canary. Haxe 5 is not tested yet.

**FMOD Engine SDK** - Download version 2.03.12 from [fmod.com/download](https://www.fmod.com/download). Step 3 below covers the setup.

=== "HaxeFlixel"

    Projects that need C++ builds (so building via `lime build mac`, `lime build windows`, and/or `lime build linux`) require a C++ compiler to be installed locally. HashLink and HTML5 builds do not.

    - **macOS**: Xcode Command Line Tools - install with `xcode-select --install`
    - **Windows**: Build Tools for Visual Studio 2022 with the "Desktop development with C++" workload selected during installation. [Direct download](https://aka.ms/vs/17/release.ltsc.17.4/vs_buildtools.exe), or find the Fall 2022 LTSC build tools link [here](https://learn.microsoft.com/en-us/visualstudio/releases/2022/release-history#release-dates-and-build-numbers).
    - **Linux**: `gcc` and `g++` (install via your package manager, e.g. `sudo apt install build-essential`)

=== "Heaps"

    **HashLink** - the desktop target runs on the HashLink VM, so install [HashLink](https://hashlink.haxe.org/) and make sure `hl` is on your path. Browser builds need no VM.

=== "Kha"

    **Node.js and a Kha checkout** - builds run through khamake (`node make.js` from a [Kha](https://github.com/Kode/Kha) checkout), and Kha brings its own Haxe.

    **A C++ compiler** - Kha's native targets always compile C++ through Kore, so the platform toolchain is required: Xcode Command Line Tools on macOS, Visual Studio 2022 on Windows, `gcc` and `g++` on Linux.

## 1. Add the library to your project

```bash
haxelib install haxefmod
```

=== "HaxeFlixel"

    If required, import the library in your project. On HaxeFlixel projects, add `<haxelib name="haxefmod" />` to the "Libraries" section of your `Project.xml` file.

=== "Heaps"

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

=== "Kha"

    ```js
    project.addLibrary('haxefmod');
    project.addParameter('--macro haxefmod.tools.BuildCheck.verify()');
    ```

    Adding the library also pulls in its `kfile.js`, so the native FMOD binding is compiled straight into your executable. There is no separate native library to manage on Kha. The `BuildCheck.verify()` parameter fails the build early with a clear message when `FMOD_SDK` (or `FMOD_SDK_WEB` for html5) is missing or points at the wrong package.

## 2. Download FMOD Studio and set up your project

This will be the tool you use to manage all audio for your game. Download FMOD Studio [here](https://fmod.com/download). Once installed, install the [constants export script](guides/tools-cli.md#the-fmod-studio-export-script) so building banks also writes the Haxe constants your code references.

## 3. Set up the FMOD Engine SDK

This library requires you to supply your own FMOD Engine SDK (separate from FMOD Studio). The only officially supported version is 2.03.12. Download it from [fmod.com/download](https://www.fmod.com/download).

If you would like to use any other version of the FMOD Engine, see [Other FMOD Engine versions](platforms.md#other-fmod-engine-versions).

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

Banks are loaded from `assets/fmod/Desktop` by default (see [Banks and settings](guides/banks-and-settings.md) to change that). With `Master.bank` and `Master.strings.bank` in that folder, the facade is ready to use.

=== "HaxeFlixel"

    Call `haxefmod.flixel.FmodFlxSetup.init()` once in your first state. It initializes FMOD and keeps the per-frame update running, see [Engine components](guides/components.md#setup).

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

=== "Heaps"

    Call `FmodHeapsSetup.init()` once from your `hxd.App`'s `init()`. It initializes FMOD and keeps the per-frame update running, see [Engine components](guides/components.md#setup).

    ```haxe
    import haxefmod.FmodManager;
    import haxefmod.heaps.FmodHeapsSetup;

    class Main extends hxd.App {
        override function init() {
            FmodHeapsSetup.init();
            FmodManager.PlaySong(FmodEvents.MusicMainLevel);
        }

        function JumpPressed() {
            FmodManager.PlaySoundOneShot(FmodEvents.SFXJump);
        }

        static function main() {
            new Main();
        }
    }
    ```

=== "Kha"

    Call `FmodKhaSetup.init()` once from the `System.start` callback. It initializes FMOD and keeps the per-frame update running, see [Engine components](guides/components.md#setup).

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

        static function JumpPressed() {
            FmodManager.PlaySoundOneShot(FmodEvents.SFXJump);
        }
    }
    ```

`FmodEvents` is one of the [generated constants classes](guides/tools-cli.md#generate). The string paths work too, for example `FmodManager.PlaySong("event:/Music/MainLevel")`.

HTML5 initializes asynchronously, so an HTML5 game waits for `FmodManager.IsInitialized()` before its first scene. [Platforms](platforms.md#html5) shows the loading state pattern.

## 6. Build and run

=== "HaxeFlixel"

    All targets work with standard lime commands:

    ```bash
    lime test html5
    lime test hl
    lime test windows
    lime test linux
    lime test mac
    ```

    You should hear your event as soon as the game window opens. If the build succeeds but stays silent, run `haxelib run haxefmod check` from the project directory and read the game's console output with `FmodManager.EnableDebugMessages()` on.

=== "Heaps"

    Compile as usual, then stage the FMOD runtime files next to the output:

    ```bash
    haxe build-hl.hxml
    haxelib run haxefmod stage linux hl build/hl
    ```

    Pass `mac` or `windows` instead of `linux` on those platforms. The [stage command](guides/tools-cli.md#stage) copies the FMOD libraries and `hlaxe_fmod.hdll` into the directory and writes a launcher (`run.sh`, or `run.cmd` on Windows) that starts the game with the right library path.

    ```bash
    cd build/hl && ./run.sh
    ```

    You should hear your event right away. Silence with a successful build usually means the banks are missing from `assets/fmod/Desktop`, and the game's console output says so when `FmodManager.EnableDebugMessages()` is on.

    **In the browser**: a js build stages the FMOD web engine instead of native libraries.

    ```bash
    haxe build-js.hxml
    haxelib run haxefmod stage html5 html5 build/html5/lib
    ```

    Load the engine scripts ahead of the game in your page, then serve the directory as a static site with the banks under `assets/fmod/Desktop`.

    ```html
    <script src="lib/fmodstudio.js"></script>
    <script src="lib/jaxe.js"></script>
    <script src="game.js"></script>
    ```

=== "Kha"

    Build through khamake, then stage the FMOD runtime files next to the executable:

    ```bash
    node /path/to/Kha/make.js linux --compile
    haxelib run haxefmod stage linux cpp path/to/output
    ```

    `linux` is the Kore C++ target. `linux-hl` builds the same game as HashLink instead, which Kore compiles to a native executable rather than running in a VM. For the HashLink targets, set `HAXEFMOD_KHA_HL=1` in the environment before khamake so the library compiles its HashLink binding into the executable instead of the C++ one. On the other platforms the khamake targets are `osx`/`osx-hl` and `windows`/`windows-hl`, with the platform name passed to the [stage command](guides/tools-cli.md#stage).

    The stage target is `cpp` for every native Kha build, the HashLink ones included: either way the binding is inside the executable, so no hdll or VM is involved and only the FMOD libraries need staging. Copy your banks to `assets/fmod/Desktop` next to the executable and run it from that directory.

    On Linux the linker also needs the SDK's library directories, since the binding links `-lfmod -lfmodstudio`:

    ```bash
    export LIBRARY_PATH="$FMOD_SDK/api/core/lib/x86_64:$FMOD_SDK/api/studio/lib/x86_64${LIBRARY_PATH:+:$LIBRARY_PATH}"
    ```

    You should hear your event as soon as the window opens. A silent run with a clean build points at missing banks, and the console output names the failing path when `FmodManager.EnableDebugMessages()` is on.

    **In the browser**: khamake writes an `index.html` only when none exists, so provide your own that loads the FMOD engine ahead of the game, then host the directory as a static site with the banks under `assets/fmod/Desktop`.

    ```bash
    node /path/to/Kha/make.js html5
    haxelib run haxefmod stage html5 html5 build/html5/lib
    ```

    ```html
    <script src="lib/fmodstudio.js"></script>
    <script src="lib/jaxe.js"></script>
    <script src="kha.js"></script>
    ```

**macOS note**: SDK libraries downloaded through a browser carry the quarantine attribute. FMOD signs its libraries so builds normally run without issue, but if macOS blocks the dylibs, clear the flag with `xattr -dr com.apple.quarantine "$FMOD_SDK"`.

## Using another framework?

The library has no hard dependency on any engine. Add `-lib haxefmod` to your build, follow the Heaps tabs for the SDK and staging steps, and call `FmodManager.Update()` once per frame from your game loop.

