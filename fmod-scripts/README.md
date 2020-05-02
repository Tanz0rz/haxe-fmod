This is a utility script that will make using your FMOD Studio events in code much easier. It will place an `FmodConstants.hx` next to your Main `.hx` file which you can then import into your project and use to access your FMOD Studio events with vscode's autocomplete feature. Just type "FmodSongs." or "FmodSFX." and the autocomplete will show all available sound clips you can play. Make sure to cast the enum value to a string when you have selected your event. 

Examples:
- Play a song: `FaxeSoundHelper.GetInstance().PlaySong(Std.string(FmodSongs.MainLevel));
- Play a sound effect: `FaxeSoundHelper.GetInstance().PlaySound(Std.string(FmodSFX.CollectionCoin));

To setup this script in your project, do the following:
- Place the ExportHaxeConstants.js file in your FMOD Studio's "scripts" folder. This folder will be found wherever you installed FMOD Studio on your computer.
- In FMOD Studio, click the Scripts dropdown at the top and select "Reload". 
- Click on the Scripts dropdown again and you will see an "Export Haxe Constants" option now available.
- When prompted, select the directory in your HaxeFlixel project where your main `.hx` file is located.

Notes:
- Make sure to run this script every time you build your master bank.