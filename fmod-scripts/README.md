This is a utility script that will make using your FMOD Studio events in code much easier by giving your project autocomplete for your FMOD Sound Events. 

It does this by placing an `FmodConstants.hx` file next to your Main `.hx` file which you can then import into your project.

If you are using vscode, its autocomplete can be triggered by typing in "FmodSongs." or "FmodSFX." to pull up all available sounds in a nice list to browse though at your cursor.

Make sure to cast the enum value to a string when you have selected your event.

## Features:
- Builds `FmodConstants.hx` in the project directory of your choosing
- Automatically builds your FMOD Studio sound bank after generating the constant files
- Can be triggered using the hotkey `Ctrl+B` while FMOD Studio is in focus (you can then use `enter` to jump through the prompts quickly once the script is setup)

## Usage Examples:
- Play a song: `FaxeSoundHelper.GetInstance().PlaySong(Std.string(FmodSongs.MainSong));`
- Play a sound effect: `FaxeSoundHelper.GetInstance().PlaySound(Std.string(FmodSFX.CollectionCoin));`

## To setup this script in your project, do the following:
- Place the ExportHaxeConstants.js file in your FMOD Studio's "scripts" folder. This folder will be found wherever you installed FMOD Studio on your computer.
- In FMOD Studio, click the Scripts dropdown at the top and select "Reload". 
- Click on the Scripts dropdown again and you will see an "Export Haxe Constants" option now available.
- When prompted, select the directory in your HaxeFlixel project where your main `.hx` file is located.


**Note:** For your new constants file to stay up to date, this script must be run *every* time you build your sound bank (the  script triggers the build for you!)
