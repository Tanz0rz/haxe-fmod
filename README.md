# FMOD for Haxe on HTML5, HashLink, Windows, Linux, and macOS

Having problems or want to chat? [Join the Haxe Discord](https://discordapp.com/invite/0uEuWH3spjck73Lo), then follow the [haxe-fmod thread](https://discord.com/channels/162395145352904705/1472372604433076446).

## Table of Contents

 - [Features](#features)
 - [Supported Platforms](#supported-platforms)
 - [Prerequisites](#prerequisites)
 - [How to Use This Library](#how-to-use-this-library)
 - [The API Layers](#api-layers)
 - [Generating Constants From Your Banks](#generating-constants)
 - [Selecting an FMOD Engine Version](#selecting-an-fmod-engine-version)
 - [HTML5 Builds](#html5-builds)
 - [FMOD Studio Project Configuration](#fmod-studio-project-configuration)
 - [Migrating From 1.x](#migrating)
 - [License](#license)
 - [Special Thanks](#special-thanks)
 - [Feature Requests and Contact](#feature-requests-and-contact)


## <a name="features"></a>Features
- The full [FMOD Studio API](https://www.fmod.com/docs/2.03/api/studio-api.html) at runtime: events, buses, VCAs, snapshots, banks, global and labeled [parameters](https://www.fmod.com/docs/2.03/studio/parameters-reference.html), 3D/listeners, and profiling - with a friendly facade on top for the common cases
- Typed, payload-carrying [callbacks](https://www.fmod.com/docs/2.03/api/studio-api-eventinstance.html#fmod_studio_event_callback_type): react to beats, timeline markers, and playback lifecycle events, each with its payload
- Refcounted bank loading with real unload and async loading
- HaxeFlixel components: one-call setup that routes the flixel sound tray and volume keys to FMOD, emitter and listener for positional audio, bank loader, and zone-based parameter triggers
- Programmer sounds for dialogue and other runtime-selected audio
- [Live Update](https://fmod.com/docs/2.03/studio/editing-during-live-update.html) for mixing sounds while playtesting (on by default in debug builds)
- Constants that never drift: the FMOD Studio export script regenerates event/bus/VCA/parameter constants on every `Ctrl+B` bank build, and `haxelib run haxefmod generate` produces the identical files from a built bank

## <a name="supported-platforms"></a>Supported Platforms

| Platform | Architecture | Targets |
|----------|--------------|---------|
| HTML5 | All | WebAssembly |
| Windows | x86_64 | C++, HashLink |
| Linux | x86_64 | C++, HashLink |
| macOS | ARM64 (Apple Silicon) | C++, HashLink |

## <a name="prerequisites"></a>Prerequisites

**FMOD Engine SDK** - Download version 2.03.12 from [fmod.com/download](https://www.fmod.com/download). See [How to Use This Library](#how-to-use-this-library) for setup instructions.

**C++ compiler** (C++ builds only) - `lime build mac`, `lime build windows`, and `lime build linux` require a C++ compiler. HashLink and HTML5 builds do not.

- **macOS**: Xcode Command Line Tools - install with `xcode-select --install`
- **Windows**: Build Tools for Visual Studio 2022 with the "Desktop development with C++" workload selected during installation. [Direct download](https://aka.ms/vs/17/release.ltsc.17.4/vs_buildtools.exe), or find the Fall 2022 LTSC build tools link [here](https://learn.microsoft.com/en-us/visualstudio/releases/2022/release-history#release-dates-and-build-numbers).
- **Linux**: `gcc` and `g++` (install via your package manager, e.g. `sudo apt install build-essential`)

## <a name="how-to-use-this-library"></a>How to Use This Library

This library has been tested on games built with the `lime` and `openfl` CLI tools, and should work on any Haxe framework that utilizes the `Project.xml` file for builds.

See [haxe-fmod-test](https://github.com/Tanz0rz/haxe-fmod-test) for a working example of a HaxeFlixel game with this FMOD integration.

**1. Add the library to your Haxe project:**

[Download the package via Haxelib](https://lib.haxe.org/p/haxefmod)

If required, import the library in your project. On HaxeFlixel projects, add `<haxelib name="haxefmod" />` to the "Libraries" section of your `Project.xml` file.

**2. Download FMOD Studio and set up your project:**

This will be the tool you use to manage all audio for your game. Download FMOD Studio [here](https://fmod.com/download). Once installed, follow the [FMOD Studio Project Configuration](#fmod-studio-project-configuration) section before moving on.

**3. Set up the FMOD Engine SDK:**

This library requires you to supply your own FMOD Engine SDK (separate from FMOD Studio). The only officially supported version is 2.03.12. Download it from [fmod.com/download](https://www.fmod.com/download).

If you would like to use any other version of the FMOD Engine, see [Selecting an FMOD Engine Version](#selecting-an-fmod-engine-version).

**For C++ and HashLink builds**, set the `FMOD_SDK` environment variable to point to the FMOD Engine directory:

```bash
# For Linux/macOS
# in ~/.bashrc or ~/.zshrc
export FMOD_SDK="$HOME/fmod/fmodstudioapi20312" # (use $HOME, not ~)

# For Windows
# in the Environment Variables UI
# FMOD_SDK=C:\path\to\fmodstudioapi20312
```

**For HTML5 builds**, set a separate `FMOD_SDK_WEB` variable:

```bash
# For Linux/macOS
# in ~/.bashrc or ~/.zshrc
export FMOD_SDK_WEB="$HOME/fmod/fmodstudioapi20312html5" # (use $HOME, not ~)

# For Windows
# in the Environment Variables UI
# FMOD_SDK_WEB=C:\path\to\fmodstudioapi20312html5
```

This allows you to have both your C++/HashLink SDK and HTML5 SDK configured simultaneously.

**4. Check your setup:**

`haxelib run haxefmod check` will check various aspects of your local dev environment to verify your setup and is **highly recommended**.

**5. Use the library in code:**

The `FmodManager` class is the friendly way to interact with FMOD in your game: a background song slot plus fire-and-forget and handle-based sound effects. The `FmodEvents` constants used below are generated from your banks (see [Generating Constants](#generating-constants)). You can look through all of the available function calls with descriptions [here](https://github.com/Tanz0rz/haxe-fmod/blob/master/haxefmod/FmodManager.hx).

```haxe
public function StartLevel():Void {
    // One background song at a time. Transitions ride the authored fadeout
    FmodManager.PlaySong(FmodEvents.MusicMainLevel);
}

public function JumpPressed():Void {
    // Fire-and-forget playback
    FmodManager.PlaySoundOneShot(FmodEvents.SFXJump);
}

public function StartEngine():Void {
    // Handle-based playback for sounds you control over time
    engineSound = FmodManager.PlaySound(FmodEvents.SFXEngine);
    engineSound.setParameter("RPM", 0.2);
}

public function OnBeat():Void {
    // Typed callbacks with payloads
    FmodManager.OnSongEvent(data -> switch (data) {
        case TimelineBeat(bar, beat, _, _): pulseUI(bar, beat);
        default:
    });
}
```

Call `FmodManager.Update()` once per frame. HaxeFlixel games (flixel 5.9.0 or newer) can call `haxefmod.flixel.FmodFlxSetup.init()` once in their first state instead: it initializes FMOD, adds the `FmodFlxUpdater` plugin (which handles the per-frame update), routes `FlxG.sound` volume and mute (the plus, minus, and zero keys and the sound tray) to the FMOD master bus, and silences the sound tray's own beep so all audio comes from FMOD. Generate the `FmodEvents` constants with `haxelib run haxefmod generate` (see [Generating Constants](#generating-constants)).

**6. Build and run:**

All targets work with standard lime commands:

```bash
lime test html5
lime test hl
lime test windows
lime test linux
lime test mac
```

**macOS note**: SDK libraries downloaded through a browser carry the quarantine attribute. FMOD signs its libraries so builds normally run without issue, but if macOS blocks the dylibs, clear the flag with `xattr -dr com.apple.quarantine "$FMOD_SDK"`.

## <a name="api-layers"></a>The API Layers

Everything in 2.0 is layered, and every layer is public:

| Layer | Use it for |
|---|---|
| `FmodManager` + `FmodSound` | The common cases: one song, sound effects, bus volume/mute |
| `haxefmod.flixel.*` | HaxeFlixel components: `FmodFlxSetup`, `FmodFlxUpdater`, `FmodFlxEmitter`, `FmodFlxListener`, `FmodFlxBankLoader`, `FmodFlxParameterTrigger` |
| `haxefmod.runtime.FmodRuntime` | Init settings, refcounted banks, 3D attachment, listeners |
| `haxefmod.studio.*` | The complete FMOD Studio API: `StudioSystem`, `EventDescription`, `EventInstance`, `Bus`, `Vca`, `Bank` |

```haxe
// Escape hatch example: everything FMOD Studio exposes is reachable
import haxefmod.studio.StudioSystem;

var music = StudioSystem.getBus("bus:/Music");
music.setVolume(0.5);

var description = StudioSystem.getEvent("event:/Ambience/Forest");
trace(description.getParameterDescriptionCount());
```

Initialization is settings-driven when you need it to be:

```haxe
FmodManager.Initialize({
    liveUpdate: true,        // defaults to true only in -debug builds
    numChannels: 256,
    bankFolder: "assets/audio",
    autoLoadBanks: ["Master.bank", "Master.strings.bank", "SFX.bank"],
});
```

**Compile-time defines** (set in `Project.xml` via `<haxedef name="..." value="..." />` or on the command line with `-D`):

| Define | Effect | Default |
|---|---|---|
| `haxefmod_num_channels` | Max virtual voices | 128 |
| `haxefmod_sample_rate` | Mixer sample rate | FMOD device default |
| `haxefmod_live_update` | Force Live Update on in any build | debug builds only |
| `haxefmod_no_live_update` | Force Live Update off in any build | |
| `haxefmod_bank_folder` | Folder the auto-loaded banks live in | `assets/fmod/Desktop` |
| `haxefmod_log_level` | FMOD debug logging: 0 none, 1 error, 2 warning, 3 log | 1 |

Runtime settings passed to `FmodManager.Initialize(...)` override the defines.

**HTML5 specifics**: initialization is asynchronous (see [HTML5 Builds](#html5-builds) for the loading-scene pattern). The FMOD web build ships FSB-only codecs, so loose wav/ogg loading and file-path programmer sounds are native-only (use audio table keys on HTML5). `Destroyed` callback events are not delivered on HTML5 (clean up in `release()`, which works on every target).

## <a name="generating-constants"></a>Generating Constants From Your Banks

Two generators emit identical files (`FmodEvents.hx`, `FmodBuses.hx`, `FmodVCAs.hx`, `FmodSnapshots.hx`, `FmodParameters.hx`). Each file also holds a `...Guids` companion class with the matching GUIDs under the same identifiers (`FmodEventsGuids.MusicMainLevel`) for GUID-based lookups, kept separate so autocomplete on the main class only shows the paths. A parity test in CI keeps the generators in lockstep.

**Recommended: generate on every export from inside FMOD Studio.** Install the [fmod-scripts](https://github.com/Tanz0rz/haxe-fmod/tree/master/fmod-scripts) script once. `Ctrl+B` in FMOD Studio then writes the constants and builds your banks in one step, so they can never drift from the project.

**Alternative: generate from a built bank** (CI, or teammates without FMOD Studio):

```
haxelib run haxefmod generate
```

Parses `assets/fmod/Desktop/Master.strings.bank` (override with `--strings`) and writes the files into `source/` (override with `--out`, add a package with `--package`).

**Optional event enums:** both generators can additionally emit `FmodEventEnum.hx` - a plain `FmodEventEnum` enum covering every event, with values named exactly like the `FmodEvents` constants (`MusicMainLevel`, `SFXJump`), plus `path()` and `guid()` mappers back to the path and GUID strings (`FmodEventEnum.SFXJump.path()` with `using FmodEventEnum.FmodEventTools`). In code the constants are cleaner (the enums add a mapping call), so the enums exist for integrations that need a real type: binding levels to specific songs in external tools like LDtk (which imports Haxe enums directly), or exhaustive switch statements. Use `Ctrl+Shift+B` in FMOD Studio or `haxelib run haxefmod generate --enums`.

## <a name="migrating"></a>Migrating From 1.x

2.0 is a clean break: string sound IDs became typed `FmodSound` handles and bitmask polling callbacks became typed payload callbacks. See [MIGRATION.md](MIGRATION.md) for a complete 1.x to 2.0 mapping.

## <a name="selecting-an-fmod-engine-version"></a>Selecting an FMOD Engine Version

The officially supported FMOD Engine version is 2.03.12. Other versions **may work fine**, but I have not tested them.

Importantly, this library comes pre-bundled with HashLink binaries (hdlls) for FMOD Engine version 2.03.12.

If you use a different FMOD Engine version and want HashLink builds, you **must** compile the hdll for your platform from source against your installed version of the FMOD Engine:

```bash
# 1. Set FMOD_SDK to your version
export FMOD_SDK=/path/to/your/fmodstudioapi

# 2. Compile the hdll (from your project directory)
haxelib run haxefmod build-hdll

# 3. Build as normal
lime test hl
```

This requires a C compiler (`gcc` on Linux, `cc` on macOS, `cl` on Windows) and HashLink headers installed on your system.

The `build-hdll` command will auto-detect your platform, find HashLink headers in common locations, compile the hdll, and place it in a `.haxefmod/` directory in your project. If HashLink headers aren't found automatically, set `HASHLINK_DIR` to your HashLink installation directory.

### How the hdll is resolved

At build time, `lime test hl` uses a tiered fallback to find the right hdll:

1. **Project-local `.haxefmod/hlaxe_fmod.hdll`** - used if present (custom-compiled via `build-hdll`)
2. **Pre-built `<haxefmod_library_install_location>/templates/bin/hl/<Platform>/hlaxe_fmod.hdll`** - ships with the library (FMOD Engine 2.03.12)

The build log will tell you which one was used.

C++ and HTML5 targets do not rely on the hdll and will work with any FMOD version (although they will warn if you use anything other than 2.03.12).

## <a name="html5-builds"></a>HTML5 Builds

For HTML5 builds to work, a dedicated scene must be run before the game starts to give the FMOD Engine a chance to fully load. See the [example project](https://github.com/Tanz0rz/haxe-fmod-test) for a demonstration of how to handle this. The `Main.hx` file loads the startup scene, the startup scene initializes FMOD and waits for it to report back as initialized, then the game is started.

## <a name="fmod-studio-project-configuration"></a>FMOD Studio Project Configuration

**FMOD Studio project structure**:

Organize events into any folder structure you like. Folder names become part of the generated constant names (`event:/Music/MainLevel` becomes `FmodEvents.MusicMainLevel`), so top-level folders like "Music" and "SFX" keep the generated names readable.

**FMOD Studio bank builds**:

This library only supports loading a single master bank for all sounds.

Set your FMOD Studio project to build banks to the correct location:

- Create an `fmod` folder in your `assets` folder (so the path `assets/fmod/` exists in your project)
- Open your FMOD Studio project and at the top of the window, click Edit->Preferences, then click the "Build" tab on the window that pops up.
- Under "Built banks output directory (optional)", click "Browse" and navigate to the new `fmod` folder and select it.

From now on, your `Master.bank` and `Master.strings.bank` files should be built in a folder found at `assets/fmod/Desktop` (the Desktop folder is created by FMOD Studio).

**Constants generation:**

Install the [fmod-scripts](https://github.com/Tanz0rz/haxe-fmod/tree/master/fmod-scripts) export script so `Ctrl+B` in FMOD Studio regenerates your Haxe constants and builds banks in one step, or run `haxelib run haxefmod generate` against a built bank (see [Generating Constants](#generating-constants)). Both generators produce identical files.

**FMOD Studio Live Update:**

One of the most powerful features of the FMOD ecosystem. Mix your sounds in real-time by binding FMOD Studio to a running instance of your game.

Live Update **only works on C++ and HashLink builds**. HTML5 builds will not work. The FMOD team said this is a limitation caused by running games inside web browsers and they have no plans to support this.

**Note**: On macOS and Windows, you may see a firewall dialog asking to allow incoming network connections when running your game. This is caused by the Live Update feature, which opens a local network socket (port 9264) so FMOD Studio can connect to your game for real-time audio mixing.

## <a name="license"></a>License

[MIT](https://en.wikipedia.org/wiki/MIT_License)

## <a name="special-thanks"></a>Special Thanks

This entire project was started as an expansion of Aaron Shea's [faxe](https://github.com/ashea-code/faxe).

## <a name="feature-requests-and-contact"></a>Feature Requests and Contact

If you have any feature requests or are having issues using the library, please do one (or both) of the following:

- [Join the Haxe Discord](https://discordapp.com/invite/0uEuWH3spjck73Lo), then ask any questions you have in the [haxe-fmod thread](https://discord.com/channels/162395145352904705/1472372604433076446). Responses will be quick!

- [Open an Issue](https://github.com/Tanz0rz/haxe-fmod/issues) here on GitHub.