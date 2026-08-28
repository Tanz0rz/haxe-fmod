# Platforms

The Haxe API is identical on every target. This page covers what differs underneath: how the native library is found, what initializes asynchronously, and which FMOD features the web build lacks. The complete list of unsupported features is in [Limitations](limitations.md).

## HTML5

The FMOD web build is a WebAssembly module. The library's post-build step copies `fmodstudio.js` and `fmodstudio.wasm` from `FMOD_SDK_WEB` next to the output, so an HTML5 build needs that variable set even when `FMOD_SDK` is also set.

### Asynchronous initialization

The wasm module and the default banks load in the background. `FmodManager.IsInitialized()` (or `FmodRuntime.isInitialized()`) reports true once both are usable, so an HTML5 game runs a loading scene first and starts the real game from it. The same code is correct on native targets, where the check is true immediately.

```haxe
function update():Void {
    if (FmodManager.IsInitialized()) {
        startGame();
    }
}
```

The [example project's `LoadFmodState.hx`](https://github.com/Tanz0rz/haxe-fmod/blob/master/example-project/EZPlatformer/source/LoadFmodState.hx) is the flixel version of this pattern. Work that pushes state to FMOD during setup can use `FmodRuntime.onceReady` instead of polling.

Bank loads are always asynchronous on HTML5, because a bank file exists in the browser's virtual filesystem only once a fetch has written it. `BankRegistry.load` and `loadAsync` behave the same there. See [Banks and settings](guides/banks-and-settings.md#bank-loading).

### Browser autoplay

Browsers refuse to start audio before the user interacts with the page. The library resumes FMOD's mixer on the first click in the page, so audio started before that plays from that moment on. Games that want sound from the first frame put a "click to start" screen ahead of it.

### What the web build cannot do

- Programmer sounds. `assignProgrammerSound` returns `FMOD_ERR_UNSUPPORTED` because of a defect in FMOD's JavaScript runtime. Author dialogue and swappable audio as ordinary events on HTML5.
- Loose audio files. The web build decodes FSB only, so `Sound.create` on a `.wav`, `.ogg`, or `.mp3` path returns `FMOD_ERR_FORMAT`, and so does `Sound.fromMemory` with such an image. An FSB image loads from memory. Bank content plays normally, and `Sound.fromPcm` and `PcmStream` work everywhere because they take raw PCM. `NONBLOCKING` loads run synchronously on the web, the sound is `READY` when `create` returns.
- The `Destroyed` callback. FMOD's JavaScript glue corrupts the module if an instance is destroyed while a callback is installed, so callbacks are uninstalled before destruction and `Destroyed` cannot be delivered. `release()` removes handlers on every target, so cleanup placed there behaves identically everywhere.
- Numeric user properties. Reading an integer, boolean, or float user property crashes FMOD's runtime, so those reads return `FMOD_ERR_UNSUPPORTED`. String properties work.
- Live Update. FMOD does not support it in browsers.
- Firefox never delivers `NestedTimelineBeat`, and fires an extra empty callback alongside each real marker. Chromium-based browsers deliver both correctly.
- Geometry occlusion, microphone recording, custom 3D rolloff curves, sample readback, plugin loading, console output ports, and the mix matrix, fade point, DSP parameter description, and default mix matrix readers. These are native only, and [Limitations](limitations.md#html5) lists what each call returns on HTML5.
- The init settings `memoryPoolSize`, `threadAttributes`, `logFile`, and `logFlags`. The web build allocates from the wasm heap, runs on the browser's audio thread, and logs to the console, so the runtime warns once and skips them. `output` accepts only `WEBAUDIO`, `AUDIOWORKLET`, `NOSOUND`, and `NOSOUND_NRT` there, and any other value fails init with `FMOD_ERR_UNSUPPORTED`. `dspBufferSize` and `dspNumBuffers` apply on HTML5 like everywhere else, with 2048 samples by 2 buffers as the web default.

A call from that native-only group is a compile error in a js build. The compiler stops at the call site, names the method and the reason, and points at the opt-out, so a web build cannot ship a call that silently does nothing. Projects that share code across targets and branch at runtime set `-D haxefmod_html5_allow_unsupported`. The calls then compile, return `FMOD_ERR_UNSUPPORTED` at runtime in the browser, and the library prints one warning per build saying so.

## HashLink

HashLink loads the binding from `hlaxe_fmod.hdll`, a native library compiled against a specific FMOD Engine version. The library bundles pre-built hdlls for 2.03.12 on Linux, macOS, and Windows.

### How the hdll is resolved

At build time `lime test hl` looks for the hdll in order:

1. Project-local `.haxefmod/hlaxe_fmod.hdll`, when present. `haxelib run haxefmod build-hdll` writes it there.
2. The pre-built `templates/bin/hl/<Platform>/hlaxe_fmod.hdll` inside the installed library.

The build log states which one was used. At runtime the library checks the hdll's binding version against its own and refuses to initialize on a mismatch, printing the `build-hdll` command to run.

### HashLink headers

`build-hdll` finds HashLink's headers in the common install locations. Set `HASHLINK_DIR` to the HashLink installation directory when it cannot.

## C++

C++ builds compile the binding (`linc_faxe.cpp`) into the executable alongside your game and link against the FMOD libraries in `FMOD_SDK`. There is nothing version-specific to rebuild. Switching FMOD Engine versions means pointing `FMOD_SDK` at the new SDK and rebuilding.

macOS may block the FMOD dylibs downloaded through a browser. `xattr -dr com.apple.quarantine "$FMOD_SDK"` clears the quarantine flag.

## Selecting an FMOD Engine version

The supported FMOD Engine version is 2.03.12, and it is the only version tested. Other versions may work.

- C++ and HTML5 builds pick up whichever SDK the environment variables point at.
- HashLink builds need a matching hdll. Set `FMOD_SDK`, run `haxelib run haxefmod build-hdll` from the project directory, and build as normal.

```bash
export FMOD_SDK=/path/to/your/fmodstudioapi
haxelib run haxefmod build-hdll
lime test hl
```

Bank files require an engine at least as new as the FMOD Studio that built them, so the Studio version and the engine version move together.

`StudioSystem.getVersion()` reports the engine version the running build actually loaded, as a string like `"2.03.12"`. Log it at startup to confirm that `FMOD_SDK`, `FMOD_SDK_WEB`, or the hdll points where you expect.

## Live Update

FMOD Studio Live Update connects Studio to the running game for mixing in real time. It works on C++ and HashLink builds and opens TCP port 9264, which the FMOD API does not allow changing. It is on by default in `-debug` builds, and can be forced either way with the `liveUpdate` setting or the `haxefmod_live_update` and `haxefmod_no_live_update` defines.

```haxe
FmodManager.Initialize({liveUpdate: true});
```

macOS and Windows show a firewall dialog the first time a Live Update build runs, since the game is listening on a local socket.
