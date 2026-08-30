# FMOD for Haxe on HTML5, HashLink, Windows, Linux, and macOS

Works with HaxeFlixel, Heaps, and Kha, each with drop-in components and its own setup guide.

Having problems or want to chat? [Join the Haxe Discord](https://discordapp.com/invite/0uEuWH3spjck73Lo), then follow the [haxe-fmod thread](https://discord.com/channels/162395145352904705/1472372604433076446).

**Setup instructions, guides, and the API reference live on the [documentation site](https://tanz0rz.github.io/haxe-fmod/).**

## Table of Contents

 - [Features](#features)
 - [Supported Platforms](#supported-platforms)
 - [Getting Started](#getting-started)
 - [Using the Library in Code](#using-the-library-in-code)
 - [FMOD Studio Live Update](#fmod-studio-live-update)
 - [Tracking Sound Work With TODOs](#tracking-sound-work-with-todos)
 - [Migrating From Previous haxe-fmod Versions?](#migrating-from-previous-haxe-fmod-versions)
 - [License](#license)
 - [Special Thanks](#special-thanks)
 - [Feature Requests and Contact](#feature-requests-and-contact)

## Features

- [FMOD Studio API](https://www.fmod.com/docs/2.03/api/studio-api.html) at runtime: events, buses, VCAs, snapshots, banks, global and labeled [parameters](https://www.fmod.com/docs/2.03/studio/parameters-reference.html), 3D/listeners, and profiling with some known [limitations](LIMITATIONS.md)
- Typed [callbacks](https://www.fmod.com/docs/2.03/api/studio-api-eventinstance.html#fmod_studio_event_callback_type) that carry event data (beats, timeline markers, etc.)
- [Live Update](https://fmod.com/docs/2.03/studio/editing-during-live-update.html) for mixing sounds while playtesting
- Drop-in engine components for [HaxeFlixel](https://tanz0rz.github.io/haxe-fmod/guides/flixel/), [Heaps](https://tanz0rz.github.io/haxe-fmod/guides/heaps/), and [Kha](https://tanz0rz.github.io/haxe-fmod/guides/kha/): emitters that follow your game objects, listeners, bank loaders, and parameter triggers
- Helper scripts to map FMOD Studio events to game code
- Many, many more

This is a faithful implementation of the FMOD stack. If this library doesn't support something you need, make an Issue and I will try to add it!

## Supported Platforms

| Platform | Architecture | Targets |
|----------|--------------|---------|
| HTML5 | All | WebAssembly |
| Windows | x86_64 | C++, HashLink |
| Linux | x86_64 | C++, HashLink |
| macOS | ARM64 (Apple Silicon) | C++, HashLink |

## Getting Started

Every engine wires FMOD in a little differently, so the documentation site has a full walkthrough per engine, from an empty project to a playing sound:

- [HaxeFlixel](https://tanz0rz.github.io/haxe-fmod/getting-started/flixel/) (covers any project built with the `lime` and `openfl` CLI tools)
- [Heaps](https://tanz0rz.github.io/haxe-fmod/getting-started/heaps/)
- [Kha](https://tanz0rz.github.io/haxe-fmod/getting-started/kha/)

Once you are set up, `haxelib run haxefmod check` verifies your local dev environment and is **highly recommended** whenever something misbehaves.

## Using the Library in Code

The FmodManager class is the primary way to interact with FMOD in your game. It abstracts away nearly all of the low-level details of the FMOD API. The `FmodEvents` constants used below are generated from your banks (see [Generating constants](https://tanz0rz.github.io/haxe-fmod/guides/tools-cli/#generate)). You can look through all of the available function calls with descriptions [here](https://github.com/Tanz0rz/haxe-fmod/blob/master/haxefmod/FmodManager.hx).

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
        case TimelineBeat(beat): pulseUI(beat.bar, beat.beat);
        default:
    });
}
```

The FmodManager class needs to be updated to support the full capabilities of this library, so if it does not allow some functionality you need, you can reach into the deeper FMOD libraries directly:

```haxe
// Escape hatch example: everything FMOD Studio exposes is reachable
import haxefmod.studio.StudioSystem;

var music = StudioSystem.getBus("bus:/Music");
music.setVolume(0.5);

var description = StudioSystem.getEvent("event:/Ambience/Forest");
trace(description.getParameterDescriptionCount());
```

## FMOD Studio Live Update

One of the most powerful features of the FMOD ecosystem. Mix your sounds in real-time by binding FMOD Studio to a running instance of your game.

Live Update **only works on C++ and HashLink builds**. HTML5 builds will not work. The FMOD team said this is a limitation caused by running games inside web browsers and they have no plans to support this.

It is on by default in debug builds, and [Live Update in the docs](https://tanz0rz.github.io/haxe-fmod/platforms/#live-update) covers turning it on anywhere else.

## Tracking Sound Work With TODOs

Sound effects usually land after the gameplay they belong to, so leave a marker where one is missing and keep building:

```haxe
FmodManager.Todo("door creak when the vault opens");
```

`haxelib run haxefmod todos` lists every remaining marker with its file and line. The call compiles away in release builds, and debug builds can even play a placeholder blip at each marker so you hear the gaps while playtesting. Details are in [the docs](https://tanz0rz.github.io/haxe-fmod/guides/fmod-manager/#sound-todo-markers).

## Migrating From Previous haxe-fmod Versions?

See [MIGRATION.md](MIGRATION.md) for the complete mapping.

## License

[MIT](https://en.wikipedia.org/wiki/MIT_License)

## Special Thanks

This entire project was started as an expansion of Aaron Shea's [faxe](https://github.com/ashea-code/faxe).

## Feature Requests and Contact

If you have any feature requests or are having issues using the library, please do one (or both) of the following:

- [Join the Haxe Discord](https://discordapp.com/invite/0uEuWH3spjck73Lo), then ask any questions you have in the [haxe-fmod thread](https://discord.com/channels/162395145352904705/1472372604433076446). Responses will be quick!

- [Open an Issue](https://github.com/Tanz0rz/haxe-fmod/issues) here on GitHub.
