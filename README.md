# FMOD for Haxe on HTML5, HashLink, Windows, Linux, and macOS

**Other Note: Remember to follow the rules of [FMOD's license](https://www.fmod.com/licensing) when using this library**

A library to integrate the FMOD audio engine with Haxe 4 games for HTML5, HashLink, Windows, Linux, and macOS deployments

Primarily focuses on simplifying the FMOD Studio project workflow through the use of a well-documented [helper library](https://github.com/Tanz0rz/haxe-fmod/blob/master/haxefmod/FmodManager.hx)

The Windows integration was built on top of Aaron Shea's [C++ integration with FMOD's official API](https://github.com/ashea-code/faxe)

LICENSE: [MIT](https://en.wikipedia.org/wiki/MIT_License)

[Download the package via Haxelib](https://lib.haxe.org/p/haxefmod)

## Table of Contents

 - [Features](#features)
 - [Supported Platforms](#supported-platforms)
 - [How to Use This Library](#how-to-use-this-library)
 - [HTML5 Builds](#html5-builds)
 - [FMOD Studio Project Configuration](#fmod-studio-project-configuration)
 - [Example Project](#example-project)
 - [Local Development](#local-development)
 - [Future Goals](#future-goals)
 - [Feature Requests and Contact](#feature-requests-and-contact)


## <a name="features"></a>Features
- Sounds loaded using an [FMOD bank](https://www.fmod.com/docs/2.00/studio/fmod-studio-concepts.html#banks) file
- [Event parameters](https://www.fmod.com/docs/2.00/studio/parameters-reference.html) for dynamically altering sounds based on in-game actions
- [Callbacks](https://www.fmod.com/docs/2.00/api/studio-api-eventinstance.html#fmod_studio_event_callback_type) which enable the game to respond to the audio
- [Live Update](https://fmod.com/docs/2.00/studio/editing-during-live-update.html) for mixing sounds while play testing
- Easy referencing of FMOD Studio bank events in game code with the help of an [auto-updated constants file](https://github.com/Tanz0rz/haxe-fmod/tree/master/fmod-scripts) (optional)

## <a name="supported-platforms"></a>Supported Platforms

| Platform | Target | Status |
|----------|--------|--------|
| HTML5 | WebAssembly | Supported |
| HashLink | Windows / Linux / macOS | Supported |
| Windows | C++ | Supported |
| Linux | C++ | Supported |
| macOS | C++ | Supported |

## <a name="how-to-use-this-library"></a>How to Use This Library

This library has been tested on games built with the `lime` and `openfl` cli tools, and should work on any Haxe framework that utilizes the `Project.xml` file for builds.

After configuring your project to work with this library, playing a song or sound effect is extremely simple:

```haxe
    // This example uses the create and update calls found in HaxeFlixel games

    override public function create():Void {
        // Plays a song in your game
        FmodManager.PlaySong("event:/Music/MainLevel");

        // Plays a sound in your game
        FmodManager.PlaySoundOneShot("event:/SFX/Jump");
    }

    override public function update(elapsed:Float):Void {
        // Update call required to process any asynchronous events
        FmodManager.Update();
    }
```
**Important note:** HTML5 builds require a "startup scene" to load FMOD before the game starts. See the [HTML5 Builds](#html5-builds) section for more information

**Download FMOD Studio and set up your project:**

This will be the tool you use to manage all audio for your game. Download FMOD Studio [here](https://fmod.com/download). Once installed, follow the [FMOD Studio Project Configuration](#fmod-studio-project-configuration) section before moving on.

**Add the library to your Haxe project:**

[Download the package via Haxelib](https://lib.haxe.org/p/haxefmod)

If required, import the library in your project. On HaxeFlixel projects, add `<haxelib name="haxefmod" />` to the "Libraries" section of your `Project.xml` file

**Use the library in code:**

The `FmodManager` class is the primary way to interact with FMOD in your game. It abstracts away nearly all of the low-level details of the FMOD API. You can look through all of the available `FmodManager` function calls with descriptions [here](https://github.com/Tanz0rz/haxe-fmod/blob/master/haxefmod/FmodManager.hx).

Songs and sound effects are triggered by passing in the full FMOD bank event path to the `FmodManager.PlaySong`, `FmodManager.PlaySoundOneShot`, `FmodManager.PlaySoundWithReference`, `FmodManager.PlaySoundAndAssignId` functions. To use constants to reference the events instead of strings, follow the additional set up instructions found in the [fmod-scripts](https://github.com/Tanz0rz/haxe-fmod/tree/master/fmod-scripts) folder of this repo (highly recommended).

**Set up the FMOD Engine SDK:**

This library requires you to supply your own FMOD Engine SDK (separate from FMOD Studio). Download it from [fmod.com/download](https://www.fmod.com/download) and extract it. The simplest place to store this would be at the root level of your project.

Required version:
- **All platforms**: FMOD Engine 2.03.12

Set the `FMOD_SDK` environment variable to point to the directory containing platform subdirs:

```bash
export FMOD_SDK=/path/to/your-project/fmod-sdk
```

Expected layout:
```
$FMOD_SDK/
├── mac/api/core/inc/fmod.h        (macOS)
├── linux/api/core/inc/fmod.h      (Linux)
├── windows/api/core/inc/fmod.h    (Windows)
└── html5/api/studio/lib/wasm/     (HTML5)
```

Run `haxelib run haxefmod doctor` to verify your setup.

**Troubleshooting: `Failed to load library hlaxe_fmod.hdll`**

This error means the FMOD runtime libraries (`fmod.dll`, `libfmod.dylib`, etc.) are missing from your build output. Make sure `FMOD_SDK` is set before building. The build may appear to succeed without it, but the game will crash at startup. Run `haxelib run haxefmod doctor` to diagnose.

**Build and run:**

All targets work with standard lime commands. FMOD libraries and native bindings are automatically copied to the output directory:

```bash
lime test windows
lime test mac
lime test linux
lime test hl
lime test html5
```

**Adding FMOD to your game loop:**

This library runs FMOD updates automatically (~60fps) independent of your game loop, so your game will function correctly even without directly calling the library's update method manually. Each platform handles this differently:

**C++**: Uses `std::thread` to run FMOD updates on a background thread

**HashLink**: Uses `pthread` (Linux/macOS) or Windows threads to run FMOD updates in the background

**HTML5**: Uses `setInterval` to schedule FMOD updates on the main thread


**Global library settings:**

Global settings for `haxefmod` are in a `Settings.hx` file found in the installation location of this library. The relative location of this file from the root of the library is `haxefmod/Settings.hx`. Updating this library to newer versions will likely reset all global settings to their defaults.

Settings available:
```Haxe
DebugMessages //Bool: Enables console output for internal FMOD API calls (can be helpful if things aren't working)
```

## <a name="html5-builds"></a>HTML5 Builds

For HTML5 builds to work, a dedicated scene must be run before the game starts to give the FMOD engine a chance to fully load. See the [example project](https://github.com/Tanz0rz/haxe-fmod-test) for a demonstration of how to handle this. The `Main.hx` file loads the startup scene, the startup scene initializes FMOD and waits for it to report back as initialized, then the game is started.

## <a name="fmod-studio-project-configuration"></a>FMOD Studio Project Configuration

**FMOD Studio project structure**:

This structure is only required if you plan to utilize the [code generation script](https://github.com/Tanz0rz/haxe-fmod/tree/master/fmod-scripts) to sync your FMOD Studio project with your game code (highly recommended)

- Songs should be placed inside a folder titled "Music" in your FMOD Studio project
- Sound effects should be placed inside a folder titled "SFX" in your FMOD Studio project

**FMOD Studio bank builds**:

This library only supports loading a single master bank for all sounds.

Set your FMOD Studio project to build banks to the correct location:

- Create an `fmod` folder in your `assets` folder (so the path `assets/fmod/` exists in your project)
- Open up your FMOD Studio project and at the top of the window, click Edit->Preferences, then click the "Build" tab on the window that pops up.
- Under "Built banks output directory (optional)", click browse and navigate to the new `fmod` folder and select it.

From now on, your `Master.bank` and `Master.strings.bank` files should be built in a folder found at `assets/fmod/Desktop` (the Desktop folder is created by FMOD Studio).

**FMOD Studio Scripts:**

Checkout the [fmod-scripts](https://github.com/Tanz0rz/haxe-fmod/tree/master/fmod-scripts) folder in this repo to learn how to set up FMOD Studio to generate a Haxe constants file (`.hx`) that can be used to reference your Music and SFX in code without using strings.

**FMOD Studio Live Update:**

When using [Live Update](https://fmod.com/docs/2.00/studio/editing-during-live-update.html) in FMOD Studio, turn the auto-reconnect feature off or your game will not start. Hopefully this issue can be resolved fairly easily.

**Note**: Live Update only works on native builds (not HTML5). The FMOD team said this has to do with limitations caused by running games inside a browser.

## <a name="example-project"></a>Example Project

See [haxe-fmod-test](https://github.com/Tanz0rz/haxe-fmod-test) for a complete working example — a HaxeFlixel game with FMOD audio, buildable on all supported platforms.

## <a name="local-development"></a>Local Development

1. Make sure `haxefmod` is not installed on your system by checking the output of `haxelib list`. If it _is_ installed, you can uninstall it using `haxelib remove haxefmod`
2. Clone down this repo
3. Point your `haxelib` at the local repo using `haxelib dev haxefmod <directory_to_the_git_clone>`

This will set up the git repo as an "installed" version of `haxefmod` which can be imported by your projects the same way you import other libraries. You can see the special `dev` status when you find `haxefmod` in the output of `haxelib list`

## <a name="future-goals"></a>Future Goals

- Ability to attach callback functions to any event instance
- Support for more banks than just the Master bank

## <a name="feature-requests-and-contact"></a>Feature Requests and Contact

If you have any feature requests or are having issues using the library, please [open an Issue](https://github.com/Tanz0rz/haxe-fmod/issues) here on Github
