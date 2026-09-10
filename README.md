# FMOD for Haxe on HTML5, HashLink, Windows, Linux, and macOS

Works natively on HaxeFlixel, Heaps, and Kha

Having problems or want to chat? [Join the Haxe Discord](https://discordapp.com/invite/0uEuWH3spjck73Lo), then follow the [haxe-fmod thread](https://discord.com/channels/162395145352904705/1472372604433076446).

**Setup instructions, guides, and the API reference live on the [documentation site](https://tanz0rz.com/haxe-fmod/).**

## Features

- The [FMOD Studio API](https://www.fmod.com/docs/2.03/api/studio-api.html) and [FMOD Core API](https://www.fmod.com/docs/2.03/api/core-api.html) at runtime, with some known [limitations](https://tanz0rz.com/haxe-fmod/limitations/)
  - Events, buses, VCAs, snapshots, banks, global and labeled [parameters](https://www.fmod.com/docs/2.03/studio/parameters-reference.html), and more
- Typed [callbacks](https://www.fmod.com/docs/2.03/api/studio-api-eventinstance.html#fmod_studio_event_callback_type) with payloads (beats, timeline markers, etc.)
- [Live Update](https://fmod.com/docs/2.03/studio/editing-during-live-update.html) for mixing sounds while playtesting
- [Helper class](https://tanz0rz.com/haxe-fmod/guides/fmod-manager/) to map FMOD Studio calls/events to game code
- [Generated constants](https://tanz0rz.com/haxe-fmod/guides/constants/) for every event, bus, VCA, snapshot, and parameter in your banks
- [TODO markers](#tracking-sound-work-with-todos) for sound effects to add later
- An [extension for fmod.com](https://tanz0rz.com/haxe-fmod/guides/extension/) to integrate Haxe examples into the official docs

This is a faithful implementation of the FMOD stack. If this library does not support something you need, open an Issue.

## Supported Platforms

| Platform | Architecture          | HaxeFlixel    | Heaps                 | Kha                 |
| -------- | --------------------- | ------------- | --------------------- | ------------------- |
| HTML5    | All                   | WebAssembly   | WebAssembly           | WebAssembly         |
| Windows  | x86_64                | C++, HashLink | HashLink              | Kore C++, Kore HL/C |
| Linux    | x86_64                | C++, HashLink | HashLink              | Kore C++, Kore HL/C |
| macOS    | ARM64 (Apple Silicon) | C++, HashLink | HashLink through HL/C | Kore C++, Kore HL/C |

## Getting Started

The [getting started walkthrough](https://tanz0rz.com/haxe-fmod/getting-started/) takes a new project from an empty build file to a playing sound. Every step that differs by engine has HaxeFlixel, Heaps, and Kha tabs.

Once you are set up, `haxelib run haxefmod check` verifies your local dev environment and is **highly recommended** whenever something misbehaves.

## Using the Library in Code

The FmodManager class is the primary way to interact with FMOD in your game. The `FmodEvents` constants used below are generated from your banks (see [Generating constants](https://tanz0rz.com/haxe-fmod/guides/constants/)). Every call and its description is in the [FmodManager API reference](https://tanz0rz.com/haxe-fmod/api/haxefmod/FmodManager.html).

```haxe
var engine:FmodEvent;

public function StartLevel():Void {
    // One background song at a time. Transitions ride the authored fadeout
    FmodManager.PlaySong(FmodEvents.MusicMainLevel);
}

public function JumpPressed():Void {
    // Fire-and-forget playback
    FmodManager.PlayOneShot(FmodEvents.SFXJump);
}

public function StartEngine():Void {
    // Handle-based playback for events you control over time
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

FmodManager covers the common cases. Anything else FMOD exposes is reachable through the deeper layers:

```haxe
// Escape hatch example: everything FMOD Studio exposes is reachable
import haxefmod.studio.StudioSystem;

var music = StudioSystem.getBus("bus:/Music");
music.setVolume(0.5);

var description = StudioSystem.getEvent("event:/Ambience/Forest");
trace(description.getParameterDescriptionCount());
```

## Generating Constants From Your Banks

The [export script](https://github.com/Tanz0rz/haxe-fmod/blob/master/fmod-scripts/ExportHaxeConstants.js) turns every event, bus, VCA, snapshot, and parameter in your FMOD Studio project into a Haxe constant. Once installed, `Ctrl+B` in FMOD Studio writes the constants to your project and builds your banks in one step.

![Haxe Constants Demo](https://raw.githubusercontent.com/Tanz0rz/haxe-fmod/master/.github/fmod_constants.gif)

```haxe
FmodManager.PlaySong(FmodEvents.MusicLetsGo);
FmodManager.PlaySong("event:/Music/LetsGo"); // the same call with the path
```

[Generating constants in the docs](https://tanz0rz.com/haxe-fmod/guides/constants/) covers the setup and what gets generated.

## FMOD Studio Live Update

One of the most powerful features of the FMOD ecosystem. Mix your sounds in real-time by binding FMOD Studio to a running instance of your game.

Live Update **only works on C++ and HashLink builds**. HTML5 builds do not support it. The FMOD team says this is a limitation of running games inside web browsers, with no plans to support it.

[Live Update in the docs](https://tanz0rz.com/haxe-fmod/live-update/) covers turning it on and off.

## Tracking Sound Work With TODOs

Sound effects usually land after the gameplay they belong to. Leave a marker where one is missing and keep building:

```haxe
FmodManager.Todo("door creak when the vault opens");
```

`haxelib run haxefmod todos` lists every remaining marker with its file and line. The call compiles away in release builds. A build with `-D haxefmod_todo_beep` also plays a short placeholder blip, so you hear the gaps while playtesting. Details are in [the docs](https://tanz0rz.com/haxe-fmod/guides/fmod-manager/#sound-todo-markers).

## fmod.com Extension

The [fmod.com extension](https://tanz0rz.com/haxe-fmod/guides/extension/) adds a Haxe tab to every function of the [FMOD API reference](https://www.fmod.com/docs/2.03/api/core-api.html). The tab sits beside C, C++, C#, and JS. The tab shows the haxefmod method that wraps the function. Functions haxefmod does not expose say so and give the reason. The [install steps](https://tanz0rz.com/haxe-fmod/guides/extension/#install) cover Chrome, Firefox, and the userscript.

![The Haxe tab on fmod.com](https://raw.githubusercontent.com/Tanz0rz/haxe-fmod/master/.github/fmod_extension.png)

## Migrating From Previous haxe-fmod Versions?

See [Migrating](https://tanz0rz.com/haxe-fmod/migration/) for the complete mapping.

## License

[MIT](https://en.wikipedia.org/wiki/MIT_License)

## Special Thanks

This entire project was started as an expansion of Aaron Shea's [faxe](https://github.com/ashea-code/faxe).

## Feature Requests and Contact

For feature requests or problems with the library, do one or both of the following:

- [Join the Haxe Discord](https://discordapp.com/invite/0uEuWH3spjck73Lo), then ask any questions you have in the [haxe-fmod thread](https://discord.com/channels/162395145352904705/1472372604433076446). Responses are quick.

- [Open an Issue](https://github.com/Tanz0rz/haxe-fmod/issues) here on GitHub.
