# FMOD for Haxe

This library provides FMOD Studio and FMOD Core support for Haxe

Setup instructions, guides, and the API reference live on the [documentation site](https://www.tanz0rz.com/haxe-fmod/).

Having problems or want to chat? [Join the Haxe Discord](https://discordapp.com/invite/0uEuWH3spjck73Lo), then follow the [haxe-fmod thread](https://discord.com/channels/162395145352904705/1472372604433076446).

## Features

- The [FMOD Studio API](https://www.fmod.com/docs/2.03/api/studio-api.html) and [FMOD Core API](https://www.fmod.com/docs/2.03/api/core-api.html) at runtime, with some known [limitations](https://www.tanz0rz.com/haxe-fmod/limitations/)
- Events, buses, VCAs, snapshots, banks, global and labeled [parameters](https://www.fmod.com/docs/2.03/studio/parameters-reference.html), and more
- Typed [callbacks](https://www.fmod.com/docs/2.03/api/studio-api-eventinstance.html#fmod_studio_event_callback_type) with payloads (beats, timeline markers, etc.)
- [Live Update](https://fmod.com/docs/2.03/studio/editing-during-live-update.html) for mixing sounds while playtesting
- [Helper class](https://www.tanz0rz.com/haxe-fmod/guides/fmod-manager/) to map FMOD Studio calls/events to game code
- [Generated constants](https://www.tanz0rz.com/haxe-fmod/guides/constants/) for every event, bus, VCA, snapshot, and parameter in your banks 
- [TODO markers](https://www.tanz0rz.com/haxe-fmod/guides/fmod-manager/#sound-todo-markers) for sound effects you plan to add later
- [fmod.com extension (beta)](https://www.tanz0rz.com/haxe-fmod/guides/extension/) to integrate Haxe examples into the official FMOD docs

If this library does not support something you need, open an Issue.

## Supported Platforms

Built and tested on Haxe `4.3.6` and FMOD Engine `2.03.12`

| Platform | Architecture          | HaxeFlixel    | Heaps                 | Kha                 |
| -------- | --------------------- | ------------- | --------------------- | ------------------- |
| HTML5    | All                   | WebAssembly   | WebAssembly           | WebAssembly         |
| Windows  | x86_64                | C++, HashLink | HashLink              | Kore C++, Kore HL/C |
| Linux    | x86_64                | C++, HashLink | HashLink              | Kore C++, Kore HL/C |
| macOS    | ARM64 (Apple Silicon) | C++, HashLink | HashLink through HL/C | Kore C++, Kore HL/C |

## Getting Started

The [Getting Started section on the docs site](https://www.tanz0rz.com/haxe-fmod/getting-started/) is a complete guide to setting up this library in your Haxe project.

## Using the Library in Code

The `FmodManager` class is the primary way to interact with FMOD in your game. The `FmodEvents` constants used below are generated from your banks (see [Generating constants](https://www.tanz0rz.com/haxe-fmod/guides/constants/)). Every call and its description is in the [FmodManager API reference](https://www.tanz0rz.com/haxe-fmod/api/haxefmod/FmodManager.html).

```haxe
public function StartLevel():Void {
    // One background song at a time, additional transition functions available when using this to manage game music
    FmodManager.PlaySong(FmodEvents.MusicMainLevel);
}

public function JumpPressed():Void {
    // Fire-and-forget playback
    FmodManager.PlayOneShot(FmodEvents.SFXJump);
}

var engine:FmodEvent;
public function StartEngine():Void {
    // Handle-based playback for events you control after starting
    engine = FmodManager.PlayEvent(FmodEvents.SFXEngine);
    engine.setParameter("RPM", 0.2);
}

public function OnBeat():Void {
    // Typed callbacks with payloads
    FmodManager.OnSongEvent(data -> switch (data) {
        case TimelineBeat(beat): pulseUI(beat.bar, beat.beat); // your own function
        default:
    });
}
```

FmodManager covers most common cases, but deeper layers are available for more explicit control:

```haxe
// Example of reaching beyond FmodManager: everything FMOD Studio exposes is reachable
import haxefmod.studio.StudioSystem;

var music = StudioSystem.getBus("bus:/Music");
music.setVolume(0.5);

var description = StudioSystem.getEvent("event:/Ambience/Forest");
trace(description.getParameterDescriptionCount());
```

## Generating Constants From Your Banks

The [export script](https://github.com/Tanz0rz/haxe-fmod/blob/master/fmod-scripts/ExportHaxeConstants.js) turns every event, bus, VCA, snapshot, and parameter in your FMOD Studio project into a Haxe constant. Once installed, `Ctrl+B` in FMOD Studio writes the constants to your project and builds your banks.

[Generating constants in the docs](https://www.tanz0rz.com/haxe-fmod/guides/constants/) covers the details of the setup and what gets generated.

![Haxe Constants Demo](https://raw.githubusercontent.com/Tanz0rz/haxe-fmod/master/.github/fmod_constants.gif)

```haxe
FmodManager.PlaySong(FmodEvents.MusicLetsGo);
FmodManager.PlaySong("event:/Music/LetsGo"); // the same call using the explicit path string
```

## FMOD Studio Live Update

One of the most powerful features of the FMOD ecosystem. Mix your sounds in real-time by binding FMOD Studio to a running instance of your game.

Live Update **only works on HashLink and C++ builds**. HTML5 builds do not support it. The FMOD team says this is a limitation of running games inside web browsers and they do not have plans to support it.

[Live Update in the docs](https://www.tanz0rz.com/haxe-fmod/live-update/) covers turning it on and off.

## Tracking Sound Work With TODOs

If your code is ready for a sound effect that doesn't exist yet, leave an intelligent marker as a placeholder.

```haxe
FmodManager.Todo("door creak when the vault opens");
```

- `haxelib run haxefmod todos` lists every remaining marker with its file and line. 
- Builds with `-D haxefmod_todo_beep` play a short placeholder blip so you hear the sounds that are still missing while playtesting. 

More details can be found [in the docs here](https://www.tanz0rz.com/haxe-fmod/guides/fmod-manager/#sound-todo-markers).

## fmod.com Extension (beta)

**Experimental feature**: The code snippets are occasionally incorrect, but this will still provide value if you are a docs-first developer

This modifies the code examples in the official fmod.com documentation to natively include Haxe

![The Haxe tab on fmod.com](https://raw.githubusercontent.com/Tanz0rz/haxe-fmod/master/.github/fmod_extension.png)

## Migrating From Previous haxe-fmod Versions?

See [MIGRATION.md](https://github.com/Tanz0rz/haxe-fmod/blob/master/MIGRATION.md) for the complete mapping.

## License

[MIT](https://en.wikipedia.org/wiki/MIT_License)

## Special Thanks

This entire project was started as an expansion of Aaron Shea's [faxe](https://github.com/ashea-code/faxe).

## Feature Requests and Contact

For feature requests or problems with the library, do one or both of the following:

- [Join the Haxe Discord](https://discordapp.com/invite/0uEuWH3spjck73Lo), then ask any questions you have in the [haxe-fmod thread](https://discord.com/channels/162395145352904705/1472372604433076446). Responses are quick.

- [Open an Issue](https://github.com/Tanz0rz/haxe-fmod/issues) here on GitHub.
