# FMOD for Haxe on Windows (faxe2)

**Note: This library will likely undergo many breaking changes early on**

A library to integrate Haxe 4.x.x games with the FMOD audio engine for Windows deployments.

The [core C++ integration with FMOD's official API](https://github.com/uhrobots/faxe) was completed by Aaron Shea. My continuation of the project has been to update the integration, add an example project, and also make it as simple as possible to use.

This library takes a lot of setup to work correctly, so please make sure to read this page carefully as you integrate FMOD into your game!

[Download the package via Haxelib](https://tanneris.me/faxe2)

LICENCE: [MIT](https://tanneris.me/mit-license)

## Table of Contents

 - [Features](#features)
 - [FMOD Studio Project Configuration](#fmod-studio-project-configuration)
 - [How to Use This Library](#how-to-use-this-library)
 - [Example Project](#example-project)
 - [Local Development](#local-development)
 - [Testing This Library (currently outdated)](#testing-this-library-currently-outdated)
 - [Goals](#goals)
 - [Contact](#contact)


## Features 
- FMOD in Haxe! (Windows builds only)
  - Haxe version 4.x.x
  - FMOD Studio/API version 2.00.08
- FMOD Studio Live Update for real-time mixing of sounds in your game (make sure to disable auto-reconnect in FMOD Studio)
- `FaxeSoundHelper` library to simplify FMOD calls
- `FaxeUtilitiesFlixel` and `FaxeFlxUpdater` libraries with additional convenience methods for `Flixel` projects
- FMOD Studio script to automatically generate a Haxe constants file (`.hx`) that can be used to reference your Music and SFX in code without using strings

## FMOD Studio Project Configuration

**FMOD Studio project structure**:
- Songs should be placed inside a folder titled "Music" in your FMOD Studio project
- Sound effects should be placed inside a folder titled "SFX" in your FMOD Studio project

**FMOD Studio bank builds**:

This library only supports loading a single master bank for all sounds.

Set your FMOD Studio project to build banks to the correct location:

- Create an `fmod` folder in your `assets` folder (so the path `assets/fmod/` exists in your project) 
- Open up your FMOD Studio project and at the top of the window click Edit->Preferences, then click the "Build" tab on the window that pops up.
- Under "Built banks output directory (optional)", click browse and navigate to the new `fmod` folder and select it.

From now on, your `Master.bank` and `Master.strings.bank` files should be built in a folder found at `assets/fmod/Desktop` (the Desktop folder is created by FMOD Studio). 

**FMOD Studio Scripts:**

Checkout the `fmod-scripts` folder to learn how to setup FMOD Studio to generate a Haxe constants file (`.hx`) that can be used to reference your Music and SFX in code without using strings.

**FMOD Studio Live Update:**

When using Live Update in FMOD Studio, turn the auto-reconnect feature off or your game will not start. Hopefully that issue can be resolved fairly easily.

## How to Use This Library

**Download the FMOD API first:**

First thing you need to do is get FMOD Studio API version 2.00.08. It can be found [here](https://tanneris.me/fmod-downloads) under the "FMOD Studio" dropdown. Once installed, find the `FMOD Studio API Windows` folder in the FMOD Studio API's installation directory. Take the entire `api` folder and copy it into the `lib/Windows` directory in this project. The path to the API in your local install of this library should look like this: `lib/Windows/api`.

**Setup your Haxe project:**

If you are using vscode and want your auto-complete and linter to be happy, make sure you add `<haxelib name="faxe2" />` to the "Libraries" section of your `Project.xml` file

**Using the library in code:**

The `FaxeSoundHelper` class is what you should be using most of the time. It abstracts away nearly all of the low-level details of interacting with the FMOD API.

The FMOD engine needs a constant stream of update calls to function properly. If this is not present in your game, it will seem like the engine is either buggy or simply not working at all. Remember to call `FaxeSoundHelper.Update()` at the beginning of **every** update loop of **every** state in your game.

## Example Project

Inside the `example-project` folder, you will find a simple game from the [HaxeFlixel flixel-demos repo](https://tanneris.me/haxe-flixel-demos) with this FMOD library added to it. It showcases the following:
- A song with an additional layer that uses an event parameter controlled by how fast the player can collect coins.
- A coin sound with multiple versions that are automatically randomized
- A dynamic high-pass filter that is applied to the song when the game is paused (click off the screen to pause)

The FMOD Studio project for the example game is also included.

Play the game, explore the code, and open up the FMOD Studio project (try Live Update!). This will provide insight into the workflow, library calls, and features of this tool. Open the `EZPlatofmrer` folder directly with vscode to get autocomplete and function lookups as you look around the code.

To play the game, run `lime test windows` in the `EZPlatformer` folder

## Local Development

1. Make sure `faxe2` is not installed on your system by checking the output of `haxelib list`. If it _is_ installed, you can uninstall it using `haxelib remove faxe2`
2. Clone down this repo
3. Point your `haxelib` at the local repo using `haxelib dev faxe2 <directory_to_the_git_clone>`

This will setup the git repo as an "installed" version of `faxe2` which can be imported by your projects the same way you import other libraries. You can see the special `dev` status when you find `faxe2` in the output of `haxelib list` and your Faxe imports in your Haxe game

### IDE configuration

#### Formatting

This repo uses [Haxe Checkstyle](https://haxecheckstyle.github.io/docs/haxe-checkstyle/home.html) for formatting of `.hx` files. Formatting configuration can be found in [hxformat.json](./hxformat.json)

See the VS Code [Haxe Checkstyle plugin](https://marketplace.visualstudio.com/items?itemName=vshaxe.haxe-checkstyle). Note that format on save should be enabled for the best experience per the [VS Haxe formatting configuration](https://github.com/vshaxe/vshaxe/wiki/Formatting)




## Testing This Library (currently outdated)

The `standalone-tests` directory holds some code that can be used to build a simple non-game example executable that reads a bank file, plays music from it, and interacts with parameters.

To compile it, `cd` into the `standalone-tests` directory and run: `haxe --cpp ../build --main MainTest.hx -p ../`

This will create a `build` directory at the root of the repo. For this test executable to do anything, you will need to create a `Master.bank` and `Master.strings.bank` file using FMOD Studio 2.00.08 and place it in the `build` directory too. For further debugging, there is a boolean inside `linc/link_faxe.cpp` that can be used to get print statements to the console as it runs. Remember to recompile the example every time you change this boolean.

## Goals

I would like to see this library support HTML5 deployments, but I have no idea how much work that is going to be. PR's here are welcome!

## Contact

Please use the ["Issues" tab](https://github.com/Tanz0rz/faxe2/issues) to report any problems!