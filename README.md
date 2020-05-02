# FMOD for HaxeFlixel on Windows (faxe2)

**Note: This library will likely undergo many breaking changes early on**

A library to integrate HaxeFlixel games (on Haxe 4.x.x) with the FMOD audio engine for Windows deployments.

The [core C++ integration with FMOD's official API](https://github.com/uhrobots/faxe) was completed by Aaron Shea. My continuation of the project has been to update the integration, add an example project, and also make it as simple as possible to use.

This library takes a lot of setup to work correctly, so please make sure to read this page carefully as you integrate FMOD into your game!

LICENCE: [MIT](https://tanneris.me/mit-license)

## Table of Contents

 - [Features](#features)
 - [FMOD Studio Project Configuration](#fmod-studio-project-configuration)
 - [How to Use This Library](#how-to-use-this-library)
 - [Example Project (Not completed yet)](#example-project-not-completed-yet)
 - [Testing This Library](#testing-this-library)
 - [Goals](#goals)


## Features 
- FMOD in HaxeFlixel! (Windows builds only)
- FMOD Studio Live Update for real-time mixing of sounds in your game (make sure to disable auto-reconnect in FMOD Studio)
- `HaxeSoundHelper` library to simplify FMOD calls and give utility functions to support cleaner state transitions
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

**Setup your HaxeFlixel project:**

If you are using vscode and want your auto-complete and linter to be happy, make sure you add `<haxelib name="faxe2" />` to the "Libraries" section of your `Project.xml` file

**Using the library in code:**

The `HaxeSoundHelper` class is what you should be using most of the time. It abstracts away nearly all of the low-level details of interacting with the FMOD API. Always reference it by using `HaxeSoundHelper.GetInstance()`

The FMOD engine needs a constant stream of update calls to function properly. If this is not present in your game, it will seem like the engine is either buggy or simply not working at all. You can manage these update calls by calling `add(new FaxeUpdater())` in the create method of **every** state in your game.

## Example Project (Not completed yet)

Inside the `example-project` folder, you will find a simple game from the [HaxeFlixel flixel-demos repo](https://tanneris.me/haxe-flixel-demos) that I converted over to use FMOD. It has a multi-layer song that responds to the player collecting coins. All sound effects in this game have multiple versions that are picked randomly when triggered by the player. Explore the project and code to get a hands-on feel for how to leverage this project.

If you are you developing in VSCode and want auto-complete and import suggestions (assuming you have this all setup), make sure to open the `EZPlatofmrer` folder with VSCode so that the example project's `Project.xml` file is at the root of your VSCode's Explorer side bar.

## Testing This Library

The `standalone-tests` directory holds some code that can be used to build a simple non-game example executable that reads a bank file, plays music from it, and interacts with parameters.

To compile it, `cd` into the `standalone-tests` directory and run: `haxe --cpp ../build --main MainTest.hx -p ../`

This will create a `build` directory at the root of the repo. For this test executable to do anything, you will need to create a `Master.bank` and `Master.strings.bank` file using FMOD Studio 2.00.08 and place it in the `build` directory too. For further debugging, there is a boolean inside `linc/link_faxe.cpp` that can be used to get print statements to the console as it runs. Remember to recompile the example every time you change this boolean.

[Download the package via Haxelib](https://tanneris.me/faxe2)

## Goals

Long-term, I would like to make this library available for all flavors of Haxe. I think this is very doable, but I am going to stick to HaxeFlixel for now until I am happy with the project. 

I would also like to see this support HTML5 deployments, but I have no idea how much work that is going to be. PR's are welcome!