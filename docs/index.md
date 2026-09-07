# haxefmod

haxefmod is FMOD Studio for Haxe on HTML5, HashLink, Windows, Linux, and macOS, with native support for HaxeFlixel, Heaps, and Kha.

- The [FMOD Studio API](https://www.fmod.com/docs/2.03/api/studio-api.html) and [FMOD Core API](https://www.fmod.com/docs/2.03/api/core-api.html) at runtime, with some known [limitations](limitations.md)
    - Events, buses, VCAs, snapshots, banks, global and labeled parameters, and more
- Typed callbacks with payloads (beats, timeline markers, etc.), see [Callbacks](guides/callbacks.md)
- [Live Update](live-update.md) for mixing sounds while playtesting
- [Helper class](guides/fmod-manager.md) to map FMOD Studio calls/events to game code
- [Generated constants](guides/constants.md) for every event, bus, VCA, snapshot, and parameter in your banks
- [TODO markers](guides/fmod-manager.md#sound-todo-markers) for sound effects that will be added later
- An [extension for fmod.com](guides/extension.md) to integrate Haxe examples into the official docs

## Two sets of docs

FMOD's own documentation at [fmod.com/docs](https://www.fmod.com/docs/2.03/api/welcome.html) describes every FMOD function, type, and guide. The [fmod.com extension](guides/extension.md) adds a Haxe tab to each of them with the haxefmod signature. Every haxefmod method that wraps an FMOD function keeps the FMOD name. A page there maps directly onto a class here.

These pages cover only what the library adds: setup, the helper class, the runtime layer, handle conventions, engine components, and the command line.

## Three tiers

Pick the lowest tier that does what you need. The tiers compose. A game can start on the helper class and reach down when it wants more.

| Tier            | Package                                      | What it is                                                                                                                                                                               |
| --------------- | -------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [Helper class](guides/fmod-manager.md) | `haxefmod.FmodManager`, `haxefmod.FmodSound` | One background song slot, fire-and-forget and handle-based sound effects, bus volume helpers, and window focus handling. Enough for most games.                                          |
| Runtime         | `haxefmod.runtime`                           | Settings-driven initialization, the bank registry, 3D attachment, and the per-frame update that everything else rides on.                                                                |
| Studio and Core | `haxefmod.studio`, `haxefmod.core`           | Typed handles for every FMOD Studio and Core object. The binding is complete except for the callback-driven APIs that no Haxe target can host. [Limitations](limitations.md) lists them. |

`haxefmod.flixel`, `haxefmod.heaps`, and `haxefmod.kha` hold drop-in components for their engines. `haxefmod.tools` is the `haxelib run haxefmod` command line.

## Getting help

[Join the Haxe Discord](https://discordapp.com/invite/0uEuWH3spjck73Lo), then find the [haxe-fmod thread](https://discord.com/channels/162395145352904705/1472372604433076446). Bugs and feature requests go to [GitHub issues](https://github.com/Tanz0rz/haxe-fmod/issues).
