# FMOD for Haxe on HTML5, HashLink, Windows, Linux, and macOS

A library to integrate the [FMOD](https://www.fmod.com/) audio engine with Haxe 4 games for HTML5, HashLink, Windows, Linux, and macOS.

Primarily focuses on simplifying the FMOD Studio project workflow through a well-documented [helper library](https://github.com/Tanz0rz/haxe-fmod/blob/master/haxefmod/FmodManager.hx).

The Windows integration was built on top of Aaron Shea's [C++ integration with FMOD's official API](https://github.com/ashea-code/faxe).

**Remember to follow the rules of [FMOD's license](https://www.fmod.com/licensing) when using this library.**

LICENSE: [MIT](https://en.wikipedia.org/wiki/MIT_License)

## Features

- Sounds loaded using an [FMOD bank](https://www.fmod.com/docs/2.00/studio/fmod-studio-concepts.html#banks) file
- [Event parameters](https://www.fmod.com/docs/2.00/studio/parameters-reference.html) for dynamically altering sounds based on in-game actions
- [Callbacks](https://www.fmod.com/docs/2.00/api/studio-api-eventinstance.html#fmod_studio_event_callback_type) which enable the game to respond to the audio
- [Live Update](https://fmod.com/docs/2.00/studio/editing-during-live-update.html) for mixing sounds while play testing
- Auto-generated [Haxe constants](https://github.com/Tanz0rz/haxe-fmod/tree/master/fmod-scripts) for type-safe FMOD event references with autocomplete

## Supported Platforms

| Platform | Target | Status |
|----------|--------|--------|
| HTML5 | WebAssembly | Supported |
| HashLink | Windows / Linux / macOS | Supported |
| Windows | C++ | Supported |
| Linux | C++ | Supported |
| macOS | C++ | Supported |

## How to Use This Library

### 1. Install

```bash
haxelib git haxefmod https://github.com/Tanz0rz/haxe-fmod.git
```

### 2. Add to Your Project

Add `<haxelib name="haxefmod" />` to the Libraries section of your `Project.xml`:

```xml
<haxelib name="haxefmod" />
```

### 3. Set Up FMOD Banks

Download [FMOD Studio](https://fmod.com/download) and configure it to build banks into your project:

1. Create `assets/fmod/` in your project directory
2. In FMOD Studio: Edit > Preferences > Build tab
3. Set "Built banks output directory" to your `assets/fmod/` folder

FMOD Studio will build `Master.bank` and `Master.strings.bank` into `assets/fmod/Desktop/`.

### 4. Use in Code

```haxe
override public function create():Void {
    FmodManager.PlaySong("event:/Music/MainLevel");
    FmodManager.PlaySoundOneShot("event:/SFX/Jump");
}

override public function update(elapsed:Float):Void {
    FmodManager.Update();
}
```

See all available functions in [FmodManager.hx](https://github.com/Tanz0rz/haxe-fmod/blob/master/haxefmod/FmodManager.hx).

### 5. Build and Run

All targets work with standard lime commands:

```bash
lime test windows
lime test mac
lime test linux
lime test hl
lime test html5
```

FMOD libraries and native bindings are automatically copied to the output directory. No extra build steps needed.

## FMOD Studio Helper Script

An [FMOD Studio script](https://github.com/Tanz0rz/haxe-fmod/tree/master/fmod-scripts) is included that auto-generates `FmodSongs` and `FmodSFX` constants from your FMOD Studio project, giving you autocomplete instead of raw strings:

```haxe
FmodManager.PlaySong(FmodSongs.MainLevel);
FmodManager.PlaySoundOneShot(FmodSFX.Coin);
```

See the [fmod-scripts README](https://github.com/Tanz0rz/haxe-fmod/tree/master/fmod-scripts) for setup instructions.

## FMOD Studio Project Structure

If using the [constants generation script](https://github.com/Tanz0rz/haxe-fmod/tree/master/fmod-scripts), organize your FMOD Studio project with:
- Songs inside a folder titled **Music**
- Sound effects inside a folder titled **SFX**

This library only supports loading a single master bank.

## HTML5 Builds

HTML5 builds require a startup scene to load FMOD before the game starts. See the [example project](https://github.com/Tanz0rz/haxe-fmod-test) for a working implementation.

## Live Update

[Live Update](https://fmod.com/docs/2.00/studio/editing-during-live-update.html) lets you mix sounds in FMOD Studio while play testing. Turn auto-reconnect off in FMOD Studio or the game won't start. Live Update only works on native builds (not HTML5).

## Example Project

See [haxe-fmod-test](https://github.com/Tanz0rz/haxe-fmod-test) for a complete working example — a HaxeFlixel game with FMOD audio, buildable on all supported platforms.

## Local Development

1. Clone this repo
2. Point haxelib at your local clone: `haxelib dev haxefmod /path/to/haxe-fmod`
3. The library is now available to your projects via `<haxelib name="haxefmod" />`

## Feature Requests and Contact

If you have any feature requests or issues, please [open an Issue](https://github.com/Tanz0rz/haxe-fmod/issues) on GitHub.
