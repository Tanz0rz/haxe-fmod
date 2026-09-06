# haxefmod

FMOD Studio for Haxe on HTML5, HashLink, Windows, Linux, and macOS, with drop-in components for HaxeFlixel, Heaps, and Kha. The library binds the full [FMOD Studio API](https://www.fmod.com/docs/2.03/api/studio-api.html) and the FMOD Core API at runtime, and adds the pieces a game needs around them: a facade, typed sound handles, payload callbacks, refcounted bank loading, engine components, and constants generated from your banks.

## Two sets of docs

FMOD's own documentation at [fmod.com/docs](https://www.fmod.com/docs/2.03/api/welcome.html) describes every FMOD function, type, and guide, and the [haxefmod for FMOD docs](https://github.com/Tanz0rz/haxe-fmod/tree/master/extension) browser extension adds a Haxe tab there with the haxefmod signature for each of them. Every haxefmod method that wraps an FMOD function keeps the FMOD name, so a page there maps directly onto a class here.

These pages cover only what the library adds on top of FMOD: setup, the facade, the runtime layer, the conventions every handle follows, the engine components, and the command line.

## Three tiers

Pick the lowest tier that does what you need. They compose, so a game can start on the facade and reach down when it wants more.

| Tier | Package | What it is |
|---|---|---|
| Facade | `haxefmod.FmodManager`, `haxefmod.FmodSound` | One background song slot, fire-and-forget and handle-based sound effects, bus volume helpers, window focus handling. Enough for most games. |
| Runtime | `haxefmod.runtime` | Settings-driven initialization, the bank registry, 3D attachment, and the per-frame update that everything else rides on. |
| Studio and Core | `haxefmod.studio`, `haxefmod.core` | Typed handles for every FMOD Studio and Core object. The binding is complete except for the callback-driven APIs no Haxe target can host, listed in [Limitations](limitations.md). |

`haxefmod.flixel`, `haxefmod.heaps`, and `haxefmod.kha` sit beside these with drop-in components for their engines, and `haxefmod.tools` is the `haxelib run haxefmod` command line.

## Where to go

- New project: [Getting started](getting-started.md), with HaxeFlixel, Heaps, and Kha tabs on every step that differs. Pick your engine once and the whole site follows.
- Playing music and sounds from game code: [FmodManager](guides/fmod-manager.md).
- How handles, null handles, and return codes behave: [Handles and results](guides/handles-and-results.md).
- Initializing the engine and loading banks: [Banks and settings](guides/banks-and-settings.md).
- Typed callbacks, listeners, and moving emitters: [Callbacks and 3D](guides/callbacks-and-3d.md).
- Generated audio and the sound factories: [Core API helpers](guides/core-api.md).
- Emitters, listeners, and loaders for your engine: [Engine components](guides/components.md).
- The command line (`check`, `generate`, `todos`, `stage`, `build-hdll`): [Tools CLI](guides/tools-cli.md).
- Per-target behavior: [Platforms](platforms.md).
- Which FMOD functions are bound, and by what: [Coverage](coverage.md).
- Every class and method: [API reference](/haxe-fmod/api/).

## Getting help

[Join the Haxe Discord](https://discordapp.com/invite/0uEuWH3spjck73Lo), then find the [haxe-fmod thread](https://discord.com/channels/162395145352904705/1472372604433076446). Bugs and feature requests go to [GitHub issues](https://github.com/Tanz0rz/haxe-fmod/issues).
