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

FMOD Studio is the tool you use to manage all audio for your game. Download it [here](https://fmod.com/download). Then install the [constants export script](guides/constants.md#the-fmod-studio-export-script). A bank build then also writes the Haxe constants your code references.

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

Each check line begins with `[OK]`, `[FAIL]`, `[WARN]`, or `[SKIP]`. A `[FAIL]` line names what is missing and how to fix it. `[WARN]` marks a step that is normal to have open during setup. `[SKIP]` marks a check that does not apply to your machine. Run it again whenever a build fails in a way you do not understand.

## 5. Play something

Banks load from `assets/fmod/Desktop` by default. [Bank loading](guides/bank-loading.md) and the [settings](guides/settings.md#settings) show how to change that. With `Master.bank` and `Master.strings.bank` in that folder, the helper class is ready to use.

=== "HaxeFlixel"

    Call `haxefmod.flixel.FmodFlxSetup.init()` once in your first state. It initializes FMOD and keeps the per-frame update running. See [Engine components](guides/components.md#setup).

    ```haxe
    import haxefmod.FmodManager;
    import haxefmod.flixel.FmodFlxSetup;

    class PlayState extends flixel.FlxState {
        var started = false;

        override function create():Void {
            super.create();
            FmodFlxSetup.init();
        }

        override function update(elapsed:Float):Void {
            super.update(elapsed);
            // Initialization is asynchronous on HTML5, so the first
            // scene waits for it
            if (!started && FmodManager.IsInitialized()) {
                started = true;
                FmodManager.PlaySong(FmodEvents.MusicMainLevel);
            }
        }

        function JumpPressed():Void {
            FmodManager.PlayOneShot(FmodEvents.SFXJump);
        }
    }
    ```

=== "Heaps"

    Call `FmodHeapsSetup.init()` once from your `hxd.App`'s `init()`. It initializes FMOD and keeps the per-frame update running. See [Engine components](guides/components.md#setup).

    ```haxe
    import haxefmod.FmodManager;
    import haxefmod.heaps.FmodHeapsSetup;

    class Main extends hxd.App {
        var started = false;

        override function init() {
            FmodHeapsSetup.init();
        }

        override function update(dt:Float) {
            // Initialization is asynchronous on HTML5, so the first
            // scene waits for it
            if (!started && FmodManager.IsInitialized()) {
                started = true;
                FmodManager.PlaySong(FmodEvents.MusicMainLevel);
            }
        }

        function JumpPressed() {
            FmodManager.PlayOneShot(FmodEvents.SFXJump);
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
    import kha.Scheduler;
    import kha.System;

    class Main {
        static function main() {
            System.start({title: "Game", width: 640, height: 480}, _ -> {
                FmodKhaSetup.init();
                Scheduler.addFrameTask(update, 0);
            });
        }

        static var started = false;

        static function update() {
            // Initialization is asynchronous on HTML5, so the first
            // scene waits for it
            if (!started && FmodManager.IsInitialized()) {
                started = true;
                FmodManager.PlaySong(FmodEvents.MusicMainLevel);
            }
        }

        static function JumpPressed() {
            FmodManager.PlayOneShot(FmodEvents.SFXJump);
        }
    }
    ```

`FmodEvents` is one of the [generated constants classes](guides/constants.md). The string paths work too, for example `FmodManager.PlaySong("event:/Music/MainLevel")`.

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

    On a native target you hear your event as soon as the game window opens. In the browser audio starts after the player's first click, key press, pointer, or touch. Browsers hold audio suspended until then, and the loading screen counts.

    If the build succeeds but stays silent, run `haxelib run haxefmod check` from the project directory. It covers the environment. Then read the game's console output with `FmodManager.EnableDebugMessages()` on. In the browser the network tab shows whether the bank files were fetched.

=== "Heaps"

    Compile as usual. Then stage the FMOD runtime files next to the output:

    ```bash
    haxe build-hl.hxml
    haxelib run haxefmod stage linux hl build/hl
    ```

    Pass `windows` instead of `linux` on Windows, and swap `-lib hlsdl` for `-lib hldx` in the hxml. Heaps runs on DirectX there. A machine with no OpenGL driver, such as a CI runner, cannot create the context `hlsdl` needs.

    The [stage command](guides/tools-cli.md#stage) copies the FMOD libraries and `hlaxe_fmod.hdll` into the directory. It also writes a launcher that starts the game with the right library path. The launcher is `run.sh`, or `run.cmd` on Windows.

    ```bash
    cd build/hl && ./run.sh
    ```

    **On macOS**: the game compiles through HL/C into a native executable, so the steps differ. Run `haxelib run haxefmod build-hdll` first, so `.haxefmod/hlaxe_fmod.hdll` exists. Then send the compile to C and link it against your HashLink installation.

    ```bash
    HL_PREFIX=$(brew --prefix)
    haxe $(grep -v '^#' build-hl.hxml | grep -v '^-hl ') -hl build/hlc/main.c
    clang -O2 -std=gnu11 -w -o build/hl/game build/hlc/main.c -I build/hlc \
      -I "$HL_PREFIX/include" -L "$HL_PREFIX/lib" -lhl -luv $LIBS \
      -Wl,-rpath,@executable_path -Wl,-rpath,"$HL_PREFIX/lib"
    haxelib run haxefmod stage mac hl build/hl
    cd build/hl && ./game
    ```

    `$LIBS` holds one `.hdll` path for each library that `build/hlc/hlc.json` names, apart from `std`. Take `hlaxe_fmod.hdll` from `.haxefmod/` and the rest from `$HL_PREFIX/lib`. `libuv` links directly, because the generated C calls its functions by name.

    You hear your event right away. Silence with a successful build usually means the banks are missing from `assets/fmod/Desktop`. The game's console output says so when `FmodManager.EnableDebugMessages()` is on. `haxelib run haxefmod check` covers the environment.

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

    In the browser audio starts after the player's first click, key press, pointer, or touch. Browsers hold audio suspended until then, and the loading screen counts. A silent page with no errors is usually a bank that never arrived. Check the network tab for the `.bank` requests.

=== "Kha"

    Build through khamake, then stage the FMOD runtime files next to the executable. On Linux and macOS, export the SDK's library directories before khamake runs. The binding links `-lfmod -lfmodstudio`, so the linker needs them.

    ```bash
    # Linux
    export LIBRARY_PATH="$FMOD_SDK/api/core/lib/x86_64:$FMOD_SDK/api/studio/lib/x86_64${LIBRARY_PATH:+:$LIBRARY_PATH}"
    # macOS
    export LIBRARY_PATH="$FMOD_SDK/api/core/lib:$FMOD_SDK/api/studio/lib${LIBRARY_PATH:+:$LIBRARY_PATH}"
    ```

    ```bash
    node /path/to/Kha/make.js linux --compile --graphics opengl
    haxelib run haxefmod stage linux cpp path/to/output
    ```

    Linux and macOS ask for OpenGL instead of Kinc's default of Vulkan or Metal. OpenGL runs on any display, a virtual or GPU-less one included. Windows keeps Direct3D and takes no `--graphics` flag.

    `linux` is the Kore C++ target. `linux-hl` builds the same game as HashLink instead, and Kore compiles it to a native executable. For the HashLink targets, set `HAXEFMOD_KHA_HL=1` in the environment before khamake. The library then compiles its HashLink binding into the executable instead of the C++ one. On the other platforms the khamake targets are `osx`/`osx-hl` and `windows`/`windows-hl`. Pass the platform name to the [stage command](guides/tools-cli.md#stage).

    The stage target is `cpp` for every native Kha build, the HashLink ones included. The binding is inside the executable either way, so no hdll or VM is involved. Only the FMOD libraries need staging. Copy your banks to `assets/fmod/Desktop` next to the executable and start it through the `run.sh` the stage command wrote there.

    You hear your event as soon as the window opens. A silent run with a clean build points at missing banks. The console output names the failing path when `FmodManager.EnableDebugMessages()` is on.

    **In the browser**: khamake writes an `index.html` only when none exists. Copy your own into the output directory before the build, so the page loads the FMOD engine first. Host the directory as a static site with the banks under `assets/fmod/Desktop`.

    ```bash
    mkdir -p build/html5
    cp index.html build/html5/index.html
    node /path/to/Kha/make.js html5
    haxelib run haxefmod stage html5 html5 build/html5/lib
    ```

    ```html
    <script src="lib/fmodstudio.js"></script>
    <script src="lib/jaxe.js"></script>
    <script src="kha.js"></script>
    ```

    In the browser audio starts after the player's first click, key press, pointer, or touch. Browsers hold audio suspended until then, and the loading screen counts. Check the network tab for the `.bank` requests when the page stays silent.

**macOS note**: SDK libraries downloaded through a browser carry the quarantine attribute. FMOD signs its libraries, so builds normally run without issue. If macOS blocks the dylibs, clear the flag with `xattr -dr com.apple.quarantine "$FMOD_SDK"`.

## Using another framework?

The library has no hard dependency on any engine. Add `-lib haxefmod` to your build. Follow the Heaps tabs for the SDK and staging steps. Call `FmodManager.Update()` once per frame from your game loop.

