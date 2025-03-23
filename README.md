# FMOD for Haxe on Windows and HTML5

**Note: The API of this library will change early on**

**Other Note: Remember to follow the rules of [FMOD's license](https://www.fmod.com/licensing) when using this library**

A library to integrate the FMOD audio engine with Haxe 4 games for Windows and HTML5 deployments

Primarily focuses on simplifying the FMOD Studio project workflow through the use of a well-documented [helper library](https://github.com/Tanz0rz/haxe-fmod/blob/master/haxefmod/FmodManager.hx)

The Windows integration was built on top of Aaron Shea's [C++ integration with FMOD's official API](https://github.com/ashea-code/faxe)

LICENSE: [MIT](https://en.wikipedia.org/wiki/MIT_License)

[Download the package via Haxelib](https://lib.haxe.org/p/haxefmod)

## Table of Contents

 - [Features](#features)
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
- [Live Update](https://fmod.com/docs/2.00/studio/editing-during-live-update.html) for mixing sounds while play testing (must be done on Windows game builds)
- Easy referencing of FMOD Studio bank events in game code with the help of an [auto-updated constants file](https://github.com/Tanz0rz/haxe-fmod/tree/master/fmod-scripts) (optional)

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

This will be the tool you use to manage all audio for your game. Download FMOD Studio version 2.00.08 [here](https://fmod.com/download). Once installed, follow the [FMOD Studio Project Configuration](#fmod-studio-project-configuration) section before moving on.

**Add the library to your Haxe project:**

[Download the package via Haxelib](https://lib.haxe.org/p/haxefmod)

If required, import the library in your project. On HaxeFlixel projects, add `<haxelib name="haxefmod" />` to the "Libraries" section of your `Project.xml` file

**Use the library in code:**

The `FmodManager` class is the primary way to interact with FMOD in your game. It abstracts away nearly all of the low-level details of the FMOD API. You can look through all of the available `FmodManager` function calls with descriptions [here](https://github.com/Tanz0rz/haxe-fmod/blob/master/haxefmod/FmodManager.hx).

Songs and sound effects are triggered by passing in the full FMOD bank event path to the `FmodManager.PlaySong`, `FmodManager.PlaySoundOneShot`, `FmodManager.PlaySoundWithReference`, `FmodManager.PlaySoundAndAssignId` functions. To use constants to reference the events instead of strings, follow the additional set up instructions found in the [fmod-scripts](https://github.com/Tanz0rz/haxe-fmod/tree/master/fmod-scripts) folder of this repo (highly recommended).

**important**: This library needs a constant stream of update calls to function properly. Remember to call `FmodManager.Update()` at the beginning of **every** update loop of **every** state in your game.

**Global library settings:**

Global settings for `haxefmod` are in a `Settings.hx` file found in the installation location of this library. The relative location of this file from the root of the library is `haxefmod/Settings.hx`. Updating this library to newer versions will likely reset all global settings to their defaults.

Settings available:
```Haxe
DebugMessages //Bool: Enables console output for internal FMOD API calls (can be helpful if things aren't working)
```

## <a name="html5-builds"></a>HTML5 Builds

For HTML5 builds to work, a dedicated scene must be run before the game starts to give the FMOD engine a chance to fully load. See the [EZPlatformer example project (HaxeFlixel)](https://github.com/Tanz0rz/haxe-fmod/tree/master/example-project/EZPlatformer/source) in the `example-project` folder of this repo for a demonstration of how to handle this. The `Main.hx` file loads the startup scene, the startup scene initializes FMOD and waits for it to report back as initialized, then the game is started.

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

**Note**: The Live Update feature will only work for Windows builds. It is officially unsupported for HTML5 builds. The FMOD team said this has to do with limitations caused by running games inside a browser.

## <a name="example-project"></a>Example Project

Inside the `example-project` folder, you will find a simple game from the [HaxeFlixel flixel-demos repo](https://github.com/HaxeFlixel/flixel-demos) with this FMOD library added to it. It showcases the following:
- A song with an additional layer that uses an event parameter controlled by how fast the player can collect coins.
- A coin sound with multiple versions that are automatically randomized
- A dynamic high-pass filter that is applied to the song when the game is paused (click off the screen to pause)

The FMOD Studio project for the example game is also included.

Play the game, explore the code, and open up the FMOD Studio project (try [Live Update](https://fmod.com/docs/2.00/studio/editing-during-live-update.html)!). This will provide insight into the workflow, library calls, and features of this tool. Open the `EZPlatformer` folder directly with vscode to get autocomplete and function lookups as you look around the code.

To play the game, run `lime test windows` or `lime test html5` in the `EZPlatformer` folder

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
