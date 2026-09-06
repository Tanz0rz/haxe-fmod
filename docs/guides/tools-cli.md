# Tools CLI

`haxelib run haxefmod <command>` runs the library's command-line tools from your project directory.

| Command | Purpose |
|---|---|
| `check` | Verifies the FMOD SDK path and version, the compiler, and the HashLink headers. |
| `generate` | Writes the `FmodEvents`, `FmodBuses`, `FmodVCAs`, `FmodSnapshots`, and `FmodParameters` constants classes from `Master.strings.bank`. |
| `todos` | Lists every `FmodManager.Todo` marker in the project. |
| `stage` | Copies the FMOD runtime files into a build output directory, for builds lime does not manage. |
| `build-hdll` | Compiles the HashLink native library against your installed FMOD SDK. |
| `verify-native` | Confirms the native shims match the binding manifest. The library's own CI uses it. |
| `help` | Prints the command list. |

`postbuild` also exists. Lime calls it after each build to copy the FMOD runtime files next to the output. There is no reason to run it by hand.

## check

```bash
haxelib run haxefmod check
```

Run it after you install the SDK and whenever a build fails unexpectedly. It reports what is missing and how to fix it. The report includes the download link for the expected FMOD version and the compiler installation steps for your platform. It also counts the sound TODO markers in the project.

## generate

Constants classes turn FMOD Studio paths into Haxe identifiers with autocomplete, so a renamed event fails at compile time.

```haxe
FmodManager.PlaySong(FmodEvents.MusicMainLevel);
FmodManager.SetBusVolume(FmodBuses.SFX, 0.8);
```

### The FMOD Studio export script

The recommended way to run the generator is from inside FMOD Studio, so constants and banks stay in step.

1. Copy [`fmod-scripts/ExportHaxeConstants.js`](https://github.com/Tanz0rz/haxe-fmod/blob/master/fmod-scripts/ExportHaxeConstants.js) into your FMOD Studio scripts folder. That is `Scripts` next to your `.fspro`, or the global scripts directory under the Studio install.
2. Reload scripts from the Scripts menu.
3. Press `Ctrl+B` (Scripts, Export Haxe Constants and Build).

The first run asks for your Haxe project's `source` folder. It caches the choice in a `CachedHaxeConstantsOutputLocation` file next to the `.fspro`. From then on `Ctrl+B` regenerates the constants and builds the banks as one step.

![Haxe constants demo](https://raw.githubusercontent.com/Tanz0rz/haxe-fmod/master/.github/fmod_constants.gif)

### Running the generator directly

```bash
haxelib run haxefmod generate [--strings <path>] [--out <dir>] [--package <pkg>]
```

- `--strings` is the path to `Master.strings.bank`. Default `assets/fmod/Desktop/Master.strings.bank`.
- `--out` is the output directory. Default `source/` if it exists, otherwise the current directory.
- `--package` is the package for the generated classes. Default top-level.

The generator parses the compiled strings bank, so it reflects exactly what the banks contain. Run it again after every bank build.

### What gets generated

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

### Auto-imports

An `import.hx` next to your `Main.hx` makes the generated classes and the library available everywhere without per-file imports. Wrap the imports in `#if !macro`. The FMOD classes use build macros, and an import inside the macro context breaks compilation.

```haxe
#if !macro
import haxefmod.FmodManager;
import FmodEvents;
#end
```

## todos

```bash
haxelib run haxefmod todos [--json]
```

Finds every `FmodManager.Todo(...)` call in the project, so the sound work they mark can be scheduled. The scanner is comment-aware and string-aware. It skips commented-out calls and mentions inside string literals. Calls with a literal first argument show their description. The scanner still finds a computed description and reports it as dynamic. `--json` prints machine-readable output for build dashboards.

## stage

```bash
haxelib run haxefmod stage <platform> <target> <outdir>
```

Lime builds get the FMOD runtime files copied next to the game automatically. Every other build runs `stage` after compiling to do the same: Heaps, Kha, and plain haxe builds. The platform is `mac`, `linux`, `windows`, or `html5`. The target is `hl` or `cpp`.

- `hl` copies the FMOD libraries and `hlaxe_fmod.hdll`, resolved through the same tiers as a lime build (see [Platforms](../platforms.md#hashlink)). It also writes a launcher that starts the game with the right library path. The launcher is `run.sh` on Linux and macOS and `run.cmd` on Windows.
- `cpp` copies the FMOD libraries only, for executables the binding was compiled into. Kha's native targets use this on Kore HL/C builds too.
- `html5` copies the FMOD web engine (`fmodstudio.js`, `fmodstudio.wasm`) and the library's `jaxe.js` glue into the directory. Your page then loads them with script tags ahead of the game.

The command reads `FMOD_SDK` (or `FMOD_SDK_WEB` for html5). It stops with the reason when the variable is unset, points at the wrong package, or holds an unusable version. The Heaps and Kha tabs of [Getting started](../getting-started.md#6-build-and-run) show it inside a full build.

## build-hdll

```bash
haxelib run haxefmod build-hdll
```

The library ships pre-built HashLink libraries for FMOD Engine 2.03.12. Any other engine version needs the hdll compiled against your installed SDK, and this command does it. It detects the platform and finds the HashLink headers in the usual locations. It compiles and places the result in a `.haxefmod/` directory in your project. The build then prefers that copy over the bundled one. Set `HASHLINK_DIR` to your HashLink installation if the command cannot find the headers. You must have a C compiler (`gcc` on Linux, `cc` on macOS, `cl` on Windows). See [Platforms](../platforms.md#hashlink) for how the hdll is resolved at build time.
