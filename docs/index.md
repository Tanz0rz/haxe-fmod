# haxefmod

FMOD Studio for Haxe on HTML5, HashLink, Windows, Linux, and macOS. The library binds the full [FMOD Studio API](https://www.fmod.com/docs/2.03/api/studio-api.html) and the FMOD Core API at runtime, and adds the pieces a game needs around them: typed sound handles, payload callbacks, refcounted bank loading, flixel components, and constants generated from your banks.

These pages cover the Haxe side of the integration. FMOD's own documentation at [fmod.com/docs](https://www.fmod.com/docs/2.03/api/welcome.html) remains the place to read about what each FMOD function does. Every haxefmod method that wraps an FMOD function keeps the FMOD name, so a page there maps directly onto a class here.

## Three tiers

Pick the lowest tier that does what you need. They compose, so a game can start on the facade and reach down when it wants more.

| Tier | Package | What it is |
|---|---|---|
| Facade | `haxefmod.FmodManager`, `haxefmod.FmodSound` | One background song slot, fire-and-forget and handle-based sound effects, bus volume helpers, window focus handling. Enough for most games. |
| Runtime | `haxefmod.runtime` | Settings-driven initialization, the bank registry, 3D attachment, and the per-frame update that everything else rides on. |
| Studio and Core | `haxefmod.studio`, `haxefmod.core` | Typed handles for every FMOD Studio and Core object. This is the complete API. |

`haxefmod.flixel` sits beside these with drop-in HaxeFlixel components, and `haxefmod.tools` is the `haxelib run haxefmod` command line.

## Where to go

- New project: [Getting started](getting-started.md).
- Playing music and sounds from game code: [FmodManager](guides/fmod-manager.md).
- How handles, null handles, and return codes behave: [Handles and results](guides/handles-and-results.md).
- Loading banks and configuring the engine: [Banks and settings](guides/banks-and-settings.md).
- Beats, markers, listeners, and moving emitters: [Callbacks and 3D](guides/callbacks-and-3d.md).
- HaxeFlixel: [Flixel components](guides/flixel.md).
- The command line (`check`, `generate`, `todos`, `build-hdll`): [Tools CLI](guides/tools-cli.md).
- Per-target behavior: [Platforms](platforms.md).
- Every class and method: [API reference](/haxe-fmod/api/).

## Getting help

[Join the Haxe Discord](https://discordapp.com/invite/0uEuWH3spjck73Lo), then find the [haxe-fmod thread](https://discord.com/channels/162395145352904705/1472372604433076446). Bugs and feature requests go to [GitHub issues](https://github.com/Tanz0rz/haxe-fmod/issues).
