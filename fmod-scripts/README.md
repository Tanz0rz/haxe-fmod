# Keeping Your Constants Synced From Inside FMOD Studio

This script bakes constants generation into the export itself: press `Ctrl+B` in FMOD Studio and it writes the Haxe constants files AND builds your banks in one step. Because it runs on every export, the constants can never drift from the project - this is the recommended workflow.

It emits the same files as `haxelib run haxefmod generate` (`FmodEvents.hx`, `FmodBuses.hx`, `FmodVCAs.hx`, `FmodSnapshots.hx`, `FmodParameters.hx`, each constant paired with a `...Guid` companion), byte-identical - a parity test in CI keeps the two generators in lockstep. Use the CLI when you want to generate from a built bank without opening FMOD Studio (CI, teammates without Studio).

## Setup

1. Copy `ExportHaxeConstants.js` into your FMOD Studio scripts folder (`Scripts` next to your `.fspro`, or the global scripts directory from Preferences).
2. Reload scripts in FMOD Studio (Scripts menu) or restart Studio.
3. Press `Ctrl+B` (or Scripts -> Export Haxe Constants and Build), pick your Haxe project's `source` folder once - the choice is cached next to the project.

From then on `Ctrl+B` regenerates the constants and builds banks in one keystroke.

## Legacy note

Before haxefmod 2.0 this script emitted a single `FmodConstants.hx` with `FmodSongs`/`FmodSFX` classes based on Music/SFX folder conventions. The 2.0 output covers every event, bus, VCA, snapshot, and global parameter with GUID companions; see `MIGRATION.md` for the rename mapping.

# Connecting Bank Events to Your Code

This script utilizes a very cool feature in FMOD Studio to give your code access to an always-up-to-date list of every event in your sound bank (using autocomplete!).

It does this by placing an `FmodConstants.hx` file next to your main `.hx` file, which you can then import into your project.

If you are using vscode, its autocomplete can be triggered by typing in "FmodSongs." or "FmodSFX." 

![Haxe Constants Demo](https://raw.githubusercontent.com/Tanz0rz/haxe-fmod/34baff733a24e4301b6b8457066cae870fb22570/HaxeConstants.gif)

## Features:
- Builds `FmodConstants.hx` in the project directory of your choosing
- Automatically builds your FMOD Studio sound bank after generating the constants file
- Can be triggered using the hotkey `Ctrl+B` while FMOD Studio is in focus (you can then use `Enter` to jump through the prompts quickly once the script is pointing at the right directory)

## Usage Examples:
- Play a song: `FmodManager.PlaySong(FmodSongs.MainSong);`
- Play a sound effect: `FmodManager.PlaySoundOneShot(FmodSFX.CollectionCoin);`

## Auto-imports:

To avoid having to import three classes in every file of your game code, you can create an `import.hx` file next to your game's `Main.hx` to make the helpers globally available.

`import.hx`:
```haxe
// Fmod helper library
import haxefmod.FmodManager;
// Static class containing all sound effect names
import FmodConstants.FmodSFX;
// Static class containing all song names
import FmodConstants.FmodSongs;
```

## Installing the script:
- Place the ExportHaxeConstants.js file in your FMOD Studio's "scripts" folder. This folder will be found wherever you installed FMOD Studio on your computer.
- In FMOD Studio, click the Scripts dropdown at the top and select "Reload". 
- Click on the Scripts dropdown again and you will see an "Export Haxe Constants" option now available.
- When prompted, select the directory in your Haxe project that contains your `Main.hx` file (this is usually the `/source` directory).


**Note:** For your new constants file to stay up to date, this script must be run *every* time you build your sound bank (the script triggers the bank build for you!)
