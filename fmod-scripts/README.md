# Keeping Your Constants Synced From Inside FMOD Studio

This script bakes constants generation into the export itself: press `Ctrl+B` in FMOD Studio and it writes the Haxe constants files AND builds your banks in one step. Because it runs on every export, the constants can never drift from the project - this is the recommended workflow.

It emits the same files as `haxelib run haxefmod generate` (`FmodEvents.hx`, `FmodBuses.hx`, `FmodVCAs.hx`, `FmodSnapshots.hx`, `FmodParameters.hx`, each with a `...Guids` companion class holding the matching GUIDs), byte-identical - a parity test in CI keeps the two generators in lockstep. Use the CLI when you want to generate from a built bank without opening FMOD Studio (CI, teammates without Studio).

## Setup

1. Copy `ExportHaxeConstants.js` into your FMOD Studio scripts folder (`Scripts` next to your `.fspro`, or the global scripts directory from Preferences).
2. Reload scripts in FMOD Studio (Scripts menu) or restart Studio.
3. Press `Ctrl+B` (or Scripts -> Export Haxe Constants and Build), pick your Haxe project's `source` folder once - the choice is cached next to the project.

From then on `Ctrl+B` regenerates the constants and builds banks in one keystroke.

## Legacy note

Before haxefmod 2.0 this script emitted a single `FmodConstants.hx` with `FmodSongs`/`FmodSFX` classes based on Music/SFX folder conventions. The 2.0 output covers every event, bus, VCA, snapshot, and global parameter, with GUIDs available through `...Guids` companion classes. See `MIGRATION.md` for the rename mapping.

# Event Enums (optional)

Alongside the constants, both generators can emit `FmodEventEnum.hx`: a plain `FmodEventEnum` enum covering every event, with values named exactly like the `FmodEvents` constants, plus a `FmodEventTools.path()` mapper back to the path string. Plain enums suit switch statements and tools that import Haxe enums, such as LDtk external enums. Autocomplete filters the same way as the constants: typing `Mus` narrows to the music events.

- FMOD Studio: press `Ctrl+Shift+B` (or Scripts -> Export Haxe Constants + Enums and Build) - writes the constants files, `FmodEventEnum.hx`, and builds banks.
- CLI: `haxelib run haxefmod generate --enums`

Usage:

```haxe
FmodManager.PlaySong(FmodEventTools.path(FmodEventEnum.MusicMainLevel));
FmodManager.PlaySoundOneShot(FmodEventTools.path(FmodEventEnum.SFXCoin));
```

With `using FmodEventEnum.FmodEventTools;` in scope the calls shorten to `FmodEventEnum.MusicMainLevel.path()` and `FmodEventEnum.SFXCoin.path()`.

# Auto-imports

To make the generated classes and the library available everywhere without per-file imports, create an `import.hx` next to your game's `Main.hx`. Wrap the imports in `#if !macro`: the FMOD classes use build macros and importing them inside the macro context breaks compilation.

```haxe
#if !macro
import haxefmod.FmodManager;
import FmodEvents;
#end
```

**Note:** for the generated files to stay up to date, run the export every time you build your sound bank (the script builds the banks for you, so `Ctrl+B` or `Ctrl+Shift+B` is the whole loop).
