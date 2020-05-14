# Connecting Bank Events to your Code

This script utilizes a very cool feature in FMOD Studio to give your code access to an always-up-to-date list of every event in your sound bank (using autocomplete!).

It does this by placing an `FmodConstants.hx` file next to your main `.hx` file which you can then import into your project.

If you are using vscode, its autocomplete can be triggered by typing in "FmodSongs." or "FmodSFX." 

![Haxe Constants Demo](https://raw.githubusercontent.com/Tanz0rz/haxe-fmod/34baff733a24e4301b6b8457066cae870fb22570/HaxeConstants.gif)

## Features:
- Builds `FmodConstants.hx` in the project directory of your choosing
- Automatically builds your FMOD Studio sound bank after generating the constants file
- Can be triggered using the hotkey `Ctrl+B` while FMOD Studio is in focus (you can then use `enter` to jump through the prompts quickly once the script is pointing at the right directory)

## Usage Examples:
- Play a song: `FmodManager.PlaySong(FmodSongs.MainSong);`
- Play a sound effect: `FmodManager.PlaySound(FmodSFX.CollectionCoin);`

## Installing the script:
- Place the ExportHaxeConstants.js file in your FMOD Studio's "scripts" folder. This folder will be found wherever you installed FMOD Studio on your computer.
- In FMOD Studio, click the Scripts dropdown at the top and select "Reload". 
- Click on the Scripts dropdown again and you will see an "Export Haxe Constants" option now available.
- When prompted, select the directory in your Haxe project where your main `.hx` file is located.


**Note:** For your new constants file to stay up to date, this script must be run *every* time you build your sound bank (the script triggers the bank build for you!)
