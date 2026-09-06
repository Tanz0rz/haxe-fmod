# Getting started

Where engines differ, a step shows one tab per engine. Pick yours on any tab group and every tab group on the site follows.

The library is tested on HaxeFlixel and other `lime` and `openfl` games, on Heaps, and on Kha. Each engine has a complete example game: [EZPlatformer](https://github.com/Tanz0rz/haxe-fmod/tree/master/example-project/EZPlatformer) (HaxeFlixel), [HeapsPlatformer](https://github.com/Tanz0rz/haxe-fmod/tree/master/example-project/HeapsPlatformer), and [KhaPlatformer](https://github.com/Tanz0rz/haxe-fmod/tree/master/example-project/KhaPlatformer). [Using another framework?](#using-another-framework) covers everything else.

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

**Haxe** - the library is built and tested against 4.3.6. The nightly canary covers 4.3.7. Haxe 5 is not tested yet.

**FMOD Engine SDK** - Download version 2.03.12 from [fmod.com/download](https://www.fmod.com/download). Step 3 below covers the setup.

=== "HaxeFlixel"

    C++ builds (`lime build mac`, `lime build windows`, and `lime build linux`) need a local C++ compiler. HashLink and HTML5 builds do not.

    - **macOS**: Xcode Command Line Tools. Install them with `xcode-select --install`.
    - **Windows**: Build Tools for Visual Studio 2022 with the "Desktop development with C++" workload selected during installation. Use the [Direct download](https://aka.ms/vs/17/release.ltsc.17.4/vs_buildtools.exe), or find the Fall 2022 LTSC build tools link [here](https://learn.microsoft.com/en-us/visualstudio/releases/2022/release-history#release-dates-and-build-numbers).
    - **Linux**: `gcc` and `g++`. Install them with your package manager, for example `sudo apt install build-essential`.

=== "Heaps"

    **HashLink** - the desktop target runs on the HashLink VM. Install [HashLink](https://hashlink.haxe.org/) and make sure `hl` is on your path. Browser builds need no VM.

=== "Kha"

    **Node.js and a Kha checkout** - builds run through khamake (`node make.js` from a [Kha](https://github.com/Kode/Kha) checkout). Kha brings its own Haxe.

    **A C++ compiler** - Kha's native targets always compile C++ through Kore, so the platform toolchain is required. Install Xcode Command Line Tools on macOS, Visual Studio 2022 on Windows, and `gcc` and `g++` on Linux.

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

    The `BuildCheck.verify()` macro stops the compile with a clear message when `FMOD_SDK` is missing or points at the wrong package. A js build checks `FMOD_SDK_WEB` instead. A misconfigured environment then fails before the game window opens.

=== "Kha"

    ```js
    project.addLibrary('haxefmod');
    project.addParameter('--macro haxefmod.tools.BuildCheck.verify()');
    ```

    The library also brings its `kfile.js` into the build, so Kore compiles the native FMOD binding into your executable. There is no separate native library to manage on Kha. The `BuildCheck.verify()` parameter fails the build early with a clear message. It triggers when `FMOD_SDK` is missing or points at the wrong package. An html5 build checks `FMOD_SDK_WEB` instead.

## 2. Download FMOD Studio and set up your project

FMOD Studio is the tool you use to manage all audio for your game. Download it [here](https://fmod.com/download). Then install the [constants export script](guides/tools-cli.md#the-fmod-studio-export-script). A bank build then also writes the Haxe constants your code references.

## 3. Set up the FMOD Engine SDK

You must supply your own FMOD Engine SDK, separate from FMOD Studio. The only officially supported version is 2.03.12. Download it from [fmod.com/download](https://www.fmod.com/download).

To use another FMOD Engine version, see [Other FMOD Engine versions](platforms.md#other-fmod-engine-versions).

**For C++ and HashLink builds**, set the `FMOD_SDK` environment variable to the FMOD Engine directory:

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

Both variables can be set at the same time, so one machine holds the desktop SDK and the HTML5 SDK.

## 4. Check your setup

`haxelib run haxefmod check` checks your local dev environment and is **highly recommended**.

```bash
haxelib run haxefmod check
```

Every line it prints must end in a check mark. It reports what is missing and how to fix it. Run it again whenever a build fails in a way you do not understand.

## 5. Play something

Banks load from `assets/fmod/Desktop` by default. [Banks and settings](guides/banks-and-settings.md) shows how to change that. With `Master.bank` and `Master.strings.bank` in that folder, the facade is ready to use.

=== "HaxeFlixel"

    Call `haxefmod.flixel.FmodFlxSetup.init()` once in your first state. It initializes FMOD and keeps the per-frame update running. See [Engine components](guides/components.md#setup).

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

    Call `FmodHeapsSetup.init()` once from your `hxd.App`'s `init()`. It initializes FMOD and keeps the per-frame update running. See [Engine components](guides/components.md#setup).

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

    Call `FmodKhaSetup.init()` once from the `System.start` callback. It initializes FMOD and keeps the per-frame update running. See [Engine components](guides/components.md#setup).

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

HTML5 initializes asynchronously. An HTML5 game waits for `FmodManager.IsInitialized()` before its first scene. [Platforms](platforms.md#html5) shows the loading state pattern.

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

    You hear your event as soon as the game window opens. If the build succeeds but stays silent, run `haxelib run haxefmod check` from the project directory. Then read the game's console output with `FmodManager.EnableDebugMessages()` on.

=== "Heaps"

    Compile as usual. Then stage the FMOD runtime files next to the output:

    ```bash
    haxe build-hl.hxml
    haxelib run haxefmod stage linux hl build/hl
    ```

    Pass `mac` or `windows` instead of `linux` on those platforms. The [stage command](guides/tools-cli.md#stage) copies the FMOD libraries and `hlaxe_fmod.hdll` into the directory. It also writes a launcher that starts the game with the right library path. The launcher is `run.sh`, or `run.cmd` on Windows.

    ```bash
    cd build/hl && ./run.sh
    ```

    You hear your event right away. Silence with a successful build usually means the banks are missing from `assets/fmod/Desktop`. The game's console output says so when `FmodManager.EnableDebugMessages()` is on.

    **In the browser**: a js build stages the FMOD web engine instead of native libraries.

    ```bash
    haxe build-js.hxml
    haxelib run haxefmod stage html5 html5 build/html5/lib
    ```

    Load the engine scripts ahead of the game in your page. Then serve the directory as a static site with the banks under `assets/fmod/Desktop`.

    ```html
    <script src="lib/fmodstudio.js"></script>
    <script src="lib/jaxe.js"></script>
    <script src="game.js"></script>
    ```

=== "Kha"

    Build through khamake. Then stage the FMOD runtime files next to the executable:

    ```bash
    node /path/to/Kha/make.js linux --compile
    haxelib run haxefmod stage linux cpp path/to/output
    ```

    `linux` is the Kore C++ target. `linux-hl` builds the same game as HashLink instead, and Kore compiles it to a native executable. For the HashLink targets, set `HAXEFMOD_KHA_HL=1` in the environment before khamake. The library then compiles its HashLink binding into the executable instead of the C++ one. On the other platforms the khamake targets are `osx`/`osx-hl` and `windows`/`windows-hl`. Pass the platform name to the [stage command](guides/tools-cli.md#stage).

    The stage target is `cpp` for every native Kha build, the HashLink ones included. The binding is inside the executable either way, so no hdll or VM is involved. Only the FMOD libraries need staging. Copy your banks to `assets/fmod/Desktop` next to the executable and run it from that directory.

    On Linux the linker also needs the SDK's library directories, since the binding links `-lfmod -lfmodstudio`:

    ```bash
    export LIBRARY_PATH="$FMOD_SDK/api/core/lib/x86_64:$FMOD_SDK/api/studio/lib/x86_64${LIBRARY_PATH:+:$LIBRARY_PATH}"
    ```

    You hear your event as soon as the window opens. A silent run with a clean build points at missing banks. The console output names the failing path when `FmodManager.EnableDebugMessages()` is on.

    **In the browser**: khamake writes an `index.html` only when none exists. Provide your own that loads the FMOD engine ahead of the game. Then host the directory as a static site with the banks under `assets/fmod/Desktop`.

    ```bash
    node /path/to/Kha/make.js html5
    haxelib run haxefmod stage html5 html5 build/html5/lib
    ```

    ```html
    <script src="lib/fmodstudio.js"></script>
    <script src="lib/jaxe.js"></script>
    <script src="kha.js"></script>
    ```

**macOS note**: SDK libraries downloaded through a browser carry the quarantine attribute. FMOD signs its libraries, so builds normally run without issue. If macOS blocks the dylibs, clear the flag with `xattr -dr com.apple.quarantine "$FMOD_SDK"`.

## Using another framework?

The library has no hard dependency on any engine. Add `-lib haxefmod` to your build. Follow the Heaps tabs for the SDK and staging steps. Call `FmodManager.Update()` once per frame from your game loop.

