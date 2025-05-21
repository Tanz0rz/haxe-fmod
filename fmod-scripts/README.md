# Connecting Bank Events to Your Code

This script utilizes a very cool feature in FMOD Studio to give your code access to an always-up-to-date list of every event in your sound bank (using autocomplete!).


It does this by generating haxe source code next to your main `.hx` file which you can then import into your project.

If you are using vscode, its autocomplete can be triggered by typing in "FmodSong." or "FmodSFX." 

![Haxe Constants Demo](https://raw.githubusercontent.com/Tanz0rz/haxe-fmod/34baff733a24e4301b6b8457066cae870fb22570/HaxeConstants.gif)

The generated code can be done in two different ways, depending on which is more useful for the given project: Either as Constants or Enums.

Both methods automatically build your FMOD Studio sound bank after generating the constants file

## Constants

### Features:
- Generates `FmodConstants.hx` in the project directory of your choosing
- Can be triggered using the hotkey `Ctrl+B` while FMOD Studio is in focus (you can then use `enter` to jump through the prompts quickly once the script is pointing at the right directory)
placing an `FmodConstants.hx` file

### Usage Examples:
- Play a song: `FmodManager.PlaySong(FmodSong.MainSong);`
- Play a sound effect: `FmodManager.PlaySound(FmodSFX.CollectionCoin);`


## Enums

### Features:
- Allows for more advanced integrations in exchange for slightly more cumbersome calls to FmodManager 
- Generates `FmodEventEnum.hx` in the project directory of your choosing
- Can be triggered using the hotkey `Ctrl+Shift+B` while FMOD Studio is in focus (you can then use `enter` to jump through the prompts quickly once the script is pointing at the right directory)
placing an `FmodEventEnum.hx` file

### Usage Examples:
- Play a song: `FmodManager.PlaySong(FmodEvent.event(FmodSong.MainSong));`
- Play a sound effect: `FmodManager.PlaySound(FmodEvent.event(FmodSFX.CollectionCoin));`

This can be shortened by leveraging `using FmodEventEnum.FmodEvent;` in your imports to make the calls look like:

- Play a song: `FmodManager.PlaySong(FmodSong.MainSong.event());`
- Play a sound effect: `FmodManager.PlaySound(FmodSFX.CollectionCoin.event());`

## Auto-imports:

To avoid having to import the classes in every file of your game code, you can create an `import.hx` file next to your game's `Main.hx` to make the helpers globally available.

`import.hx`:
```haxe
// Fmod helper library
import haxefmod.FmodManager;
// Static class containing all sound effect names
import FmodConstants.FmodSFX;
// Static class containing all song names
import FmodConstants.FmodSong;
```

## Installing the script:
- Place either the `ExportHaxeConstants.js`  or `ExportHaxeEnums.js` file in your FMOD projects's "scripts" folder (`%project_root_directory%/Scripts`).
- In FMOD Studio, click the Scripts dropdown at the top and select "Reload". 
- Click on the Scripts dropdown again and you will see either "Export Haxe Constants and Build" or "Export Haxe Enums and Build option now available, depending on which script file was copied.
- When prompted, select the directory in your Haxe project that contains your `Main.hx` file (this is usually the `/source` directory).


**Note:** For your generated code to stay up to date, this script must be run *every* time you build your sound bank (the script triggers the bank build for you!)
