# Generated constants

Every event, bus, VCA, snapshot, and parameter in your FMOD Studio project becomes a Haxe constant. The constants have autocomplete, and a renamed event fails at compile time.

```haxe
FmodManager.PlaySong(FmodEvents.MusicMainLevel);
FmodManager.SetBusVolume(FmodBuses.SFX, 0.8);
```

## The FMOD Studio export script

The recommended way to run the generator is from inside FMOD Studio, so constants and banks stay in step.

1. Copy [`fmod-scripts/ExportHaxeConstants.js`](https://github.com/Tanz0rz/haxe-fmod/blob/master/fmod-scripts/ExportHaxeConstants.js) into your FMOD Studio scripts folder. That is `Scripts` next to your `.fspro`, or the global scripts directory under the Studio install.
2. Reload scripts from the Scripts menu.
3. Press `Ctrl+B` (Scripts, Export Haxe Constants and Build).

The first run asks for your Haxe project's `source` folder. It caches the choice in a `CachedHaxeConstantsOutputLocation` file next to the `.fspro`. From then on `Ctrl+B` regenerates the constants and builds the banks as one step. The [generate command](tools-cli.md#generate) runs the same generator from the command line.

![Haxe constants demo](https://raw.githubusercontent.com/Tanz0rz/haxe-fmod/master/.github/fmod_constants.gif)

## What gets generated

One class per path category found in the strings bank:

| File | Paths |
|---|---|
| `FmodEvents.hx` | `event:/...` |
| `FmodBuses.hx` | `bus:/...` |
| `FmodVCAs.hx` | `vca:/...` |
| `FmodSnapshots.hx` | `snapshot:/...` |
| `FmodParameters.hx` | `parameter:/...` |

Each file also holds a companion `...Guids` class with the same identifiers mapped to GUID strings. The class is separate so autocomplete on the main class shows paths only.

```haxe
var path = FmodEvents.MusicMainLevel;      // "event:/Music/MainLevel"
var guid = FmodEventsGuids.MusicMainLevel; // "{e5187c3f-...}"
```

`FmodEventEnum.hx` holds a plain enum that covers every event, with values named like the `FmodEvents` constants. `FmodEventTools.path()` and `guid()` map the enum back, and both work as static extensions. Plain enums suit switch statements and tools that import Haxe enums, such as LDtk external enums. Projects that never touch the enum can ignore the file.

The generator derives an identifier from a path in four steps:

1. Strip the category prefix.
2. Split on `/` and on any character that is not a letter or digit.
3. Uppercase the first letter of each piece.
4. Concatenate the pieces.

`Vehicles/Ride-on Mower` becomes `VehiclesRideOnMower`. The bus root becomes `Root`. A leading digit gets an underscore prefix. Duplicates get numeric suffixes. The generator drops non-ASCII characters.

## Auto-imports

An `import.hx` next to your `Main.hx` makes the generated classes and the library available everywhere without per-file imports. Wrap the imports in `#if !macro`. The FMOD classes use build macros, and an import inside the macro context breaks compilation.

```haxe
#if !macro
import haxefmod.FmodManager;
import FmodEvents;
#end
```

