# FMOD for Haxe on HTML5, HashLink, Windows, Linux, and macOS



[MIT License](https://en.wikipedia.org/wiki/MIT_License) 

## Table of Contents

 - [Features](#features)
 - [Supported Platforms](#supported-platforms)
 - [How to Use This Library](#how-to-use-this-library)
 - [HTML5 Builds](#html5-builds)
 - [FMOD Studio Project Configuration](#fmod-studio-project-configuration)
 - [Special Thanks](#special-thanks)
 - [Feature Requests and Contact](#feature-requests-and-contact)


## <a name="features"></a>Features
- Sounds loaded using an [FMOD bank](https://www.fmod.com/docs/2.03/studio/fmod-studio-concepts.html#banks) file
- [Event parameters](https://www.fmod.com/docs/2.03/studio/parameters-reference.html) for dynamically altering sounds based on in-game actions
- [Callbacks](https://www.fmod.com/docs/2.03/api/studio-api-eventinstance.html#fmod_studio_event_callback_type) which enable the game to respond to the audio
- [Live Update](https://fmod.com/docs/2.03/studio/editing-during-live-update.html) for mixing sounds while play testing
- Easy referencing of FMOD Studio bank events in game code with the help of an [auto-updated constants file](https://github.com/Tanz0rz/haxe-fmod/tree/master/fmod-scripts) (optional)

## <a name="supported-platforms"></a>Supported Platforms

| Platform | Architecture | Targets |
|----------|--------------|---------|
| HTML5 | All | WebAssembly |
| Windows | x86_64 | C++, HashLink |
| Linux | x86_64 | C++, HashLink |
| macOS | ARM64 (Apple Silicon) | C++, HashLink |

## <a name="how-to-use-this-library"></a>How to Use This Library

This library has been tested on games built with the `lime` and `openfl` CLI tools, and should work on any Haxe framework that utilizes the `Project.xml` file for builds.

See [haxe-fmod-test](https://github.com/Tanz0rz/haxe-fmod-test) for a working example of a haxe-flixel game with this FMOD integration.

**1. Add the library to your Haxe project:**

[Download the package via Haxelib](https://lib.haxe.org/p/haxefmod)

If required, import the library in your project. On HaxeFlixel projects, add `<haxelib name="haxefmod" />` to the "Libraries" section of your `Project.xml` file.

**2. Download FMOD Studio and set up your project:**

This will be the tool you use to manage all audio for your game. Download FMOD Studio [here](https://fmod.com/download). Once installed, follow the [FMOD Studio Project Configuration](#fmod-studio-project-configuration) section before moving on.

**3. Set up the FMOD Engine SDK:**

This library requires you to supply your own FMOD Engine SDK (separate from FMOD Studio). Download it from [fmod.com/download](https://www.fmod.com/download).

Required version:
- **All platforms**: FMOD Engine 2.03.12

**For OS-native builds**, set the `FMOD_SDK` environment variable to point to the FMOD Engine directory:

```bash
# For Linux/macOS (use $HOME, not ~)
# in ~/.bashrc or ~/.zshrc
export FMOD_SDK="$HOME/fmod/fmodstudioapi20312"

# For Windows
# in the Environment Variables UI
# FMOD_SDK=C:\path\to\installer\output
```

**For HTML5 builds**, set a separate `FMOD_SDK_WEB` variable:

```bash
# For Linux/macOS (use $HOME, not ~)
# in ~/.bashrc or ~/.zshrc
export FMOD_SDK_WEB="$HOME/fmod/fmodstudioapi20312html5"

# For Windows
# in the Environment Variables UI
# FMOD_SDK_WEB=C:\path\to\fmodstudioapi20312html5
```

This allows you to have both your native SDK and HTML5 SDK configured simultaneously.

**4. Check your setup:**

`haxelib run haxefmod check` will check various aspects of your local dev environment to verify your setup and is **highly recommended**.

**5. Use the library in code:**

The `FmodManager` class is the primary way to interact with FMOD in your game. It abstracts away nearly all of the low-level details of the FMOD API. You can look through all of the available function calls with descriptions [here](https://github.com/Tanz0rz/haxe-fmod/blob/master/haxefmod/FmodManager.hx).

Songs and sound effects are triggered by passing the full FMOD bank event path to functions like:
- `FmodManager.PlaySong`
- `FmodManager.PlaySoundOneShot`
- `FmodManager.PlaySoundWithReference`
- `FmodManager.PlaySoundAndAssignId`

To use constants instead of strings to reference events, follow the instructions in the [fmod-scripts](https://github.com/Tanz0rz/haxe-fmod/tree/master/fmod-scripts).

```haxe
public function StartLevel():Void {
    // Plays a song in your game
    FmodManager.PlaySong("event:/Music/MainLevel");
    // or if using the FMOD Studio enum generation script
    FmodManager.PlaySong(FmodSongs.MainLevel);
}

public function JumpPressed():Void {
    // Plays a sound in your game
    FmodManager.PlaySoundOneShot("event:/SFX/Jump");
    // or if using the FMOD Studio enum generation script
    FmodManager.PlaySoundOneShot(FmodSFX.Jump);
}
```

**6. Build and run:**

All targets work with standard lime commands:

```bash
lime test html5
lime test hl
lime test windows
lime test linux
lime test mac
```

## <a name="html5-builds"></a>HTML5 Builds

For HTML5 builds to work, a dedicated scene must be run before the game starts to give the FMOD engine a chance to fully load. See the [example project](https://github.com/Tanz0rz/haxe-fmod-test) for a demonstration of how to handle this. The `Main.hx` file loads the startup scene, the startup scene initializes FMOD and waits for it to report back as initialized, then the game is started.

## <a name="fmod-studio-project-configuration"></a>FMOD Studio Project Configuration

**FMOD Studio project structure**:

If you would like to utilize the [code generation script](https://github.com/Tanz0rz/haxe-fmod/tree/master/fmod-scripts) to sync your FMOD Studio project with your game code (highly recommended), use the following structure:

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

Check out the [fmod-scripts](https://github.com/Tanz0rz/haxe-fmod/tree/master/fmod-scripts) folder in this repo to learn how to set up FMOD Studio to generate a Haxe constants file (`.hx`) that can be used to reference your Music and SFX in code without using strings.

**FMOD Studio Live Update:**

One of the most powerful features of the FMOD ecosystem. Mix your sounds in real-time by binding FMOD Studio to a running instance of your game.

Live Update **only works on native builds** (not HTML5). The FMOD team said this is a limitation caused by running games inside web browsers and they have no plans to support this.

**Note**: On macOS and Windows, you may see a firewall dialog asking to allow incoming network connections when running your game. This is caused by the Live Update feature, which opens a local network socket (port 9264) so FMOD Studio can connect to your game for real-time audio mixing.


## <a name="special-thanks"></a>Special Thanks
This entire project was started as an expansion of Aaron Shea's [faxe](https://github.com/ashea-code/faxe).

## <a name="feature-requests-and-contact"></a>Feature Requests and Contact

If you have any feature requests or are having issues using the library, please [open an Issue](https://github.com/Tanz0rz/haxe-fmod/issues) here on GitHub.
