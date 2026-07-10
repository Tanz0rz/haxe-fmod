# Connecting Bank Events to Your Code

This script gives your code an always-up-to-date, autocompletable list of everything in your sound banks. Press `Ctrl+B` in FMOD Studio and it writes the Haxe constants files AND builds your banks in one step. Because it runs as part of every export, the constants can never drift from the project - this is the recommended workflow.

![Haxe Constants Demo](../.github/fmod_constants.gif)

## What gets generated

- `FmodEvents.hx`, `FmodBuses.hx`, `FmodVCAs.hx`, `FmodSnapshots.hx`, and `FmodParameters.hx` - one class per category, one constant per path
- A `...Guids` companion class in each file holding the matching GUIDs under the same identifiers, kept separate so autocomplete on the main class only shows the paths
- `FmodEventEnum.hx` - a plain enum covering every event, for tool integrations (see [Event Enums](#event-enums))

Use the constants anywhere a path is expected:

```haxe
FmodManager.PlaySong(FmodEvents.MusicMainLevel);
FmodManager.PlaySoundOneShot(FmodEvents.SFXCoin);

var engine = FmodManager.PlaySound(FmodEvents.SFXEngine);
engine.setParameter("RPM", 0.5);
```

`haxelib run haxefmod generate` emits byte-identical files from a built `Master.strings.bank` (a parity test in CI keeps the two generators in lockstep). Use the CLI when you want to generate without opening FMOD Studio (CI, teammates without Studio).

### Event Enums

If you are using a flow or tool that works better with enums, `FmodEventEnum.hx` holds enum representations of all sounds with additional helper functions that map them back to the path and GUID strings.

## Setup

1. Copy `ExportHaxeConstants.js` into your FMOD Studio scripts folder (`Scripts` next to your `.fspro`, or the global scripts directory from Preferences).
2. Reload scripts in FMOD Studio (Scripts menu) or restart Studio.
3. Press `Ctrl+B` (or Scripts -> Export Haxe Constants and Build) and pick your Haxe project's `source` folder once. The choice is cached next to the project.

From then on `Ctrl+B` regenerates the constants and builds banks in one keystroke.

## Auto-imports

To make the generated classes and the library available everywhere without per-file imports, create an `import.hx` next to your game's `Main.hx`. Wrap the imports in `#if !macro`: the FMOD classes use build macros and importing them inside the macro context breaks compilation.

```haxe
#if !macro
import haxefmod.FmodManager;
import FmodEvents;
#end
```

**Note:** for the generated files to stay up to date, run the export every time you build your sound bank (the script builds the banks for you, so `Ctrl+B` is the whole loop).

Migrating from the 1.x `FmodConstants.hx` output? See `MIGRATION.md` for the rename mapping.
