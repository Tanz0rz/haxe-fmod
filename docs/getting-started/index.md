# Getting started

Every engine wires FMOD in a little differently, so setup is documented per engine. Pick yours and follow the page top to bottom. By the end your project plays an FMOD event on every platform it builds for.

- [HaxeFlixel](flixel.md) is for games built with the `lime` and `openfl` CLI tools. Any Haxe framework that uses `Project.xml` for builds follows this page.
- [Heaps](heaps.md) is for hxml builds targeting HashLink or the browser.
- [Kha](kha.md) is for khafile projects built through khamake.

The engine pages differ only in project setup and build commands. Playing sounds, loading banks, callbacks, and 3D are the same code everywhere, covered engine-free in the [guides](../guides/fmod-manager.md).

## Supported platforms

| Platform | Architecture | Targets |
|---|---|---|
| HTML5 | All | WebAssembly |
| Windows | x86_64 | C++, HashLink |
| Linux | x86_64 | C++, HashLink |
| macOS | ARM64 (Apple Silicon) | C++, HashLink |

## Using another framework?

The library has no hard dependency on any engine. Add `-lib haxefmod` to your build, follow the [Heaps](heaps.md) page for the SDK and staging steps, and call `FmodManager.Update()` once per frame from your game loop.
