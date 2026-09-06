# Platforms

The Haxe API is identical on every target. This page covers what differs underneath: what initializes asynchronously, how the native binding is found, and how to run an FMOD Engine other than the bundled one. The FMOD features the web build lacks are listed in [Limitations](limitations.md#html5).

## HTML5

The FMOD web build is a WebAssembly module. The library's post-build step (the [stage command](guides/tools-cli.md#stage) on Heaps and Kha) copies `fmodstudio.js` and `fmodstudio.wasm` from `FMOD_SDK_WEB` next to the output, so an HTML5 build needs that variable set even when `FMOD_SDK` is also set.

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

### Native-only calls

A call to a feature the web build lacks is a compile error in a js build. The compiler stops at the call site, names the method and the reason, and points at the opt-out. Projects that share code across targets and branch at runtime set `-D haxefmod_html5_allow_unsupported`. The calls then compile, return `FMOD_ERR_UNSUPPORTED` at runtime in the browser, and the library prints one warning per build saying so.

## HashLink

HashLink loads the binding from `hlaxe_fmod.hdll`, a native library compiled against a specific FMOD Engine version. The library bundles pre-built hdlls for 2.03.12 on Linux, macOS, and Windows.

At build time `lime test hl` (and the [stage command](guides/tools-cli.md#stage) for Heaps builds) looks for the hdll in order:

1. Project-local `.haxefmod/hlaxe_fmod.hdll`, when present. `haxelib run haxefmod build-hdll` writes it there.
2. The pre-built `templates/bin/hl/<Platform>/hlaxe_fmod.hdll` inside the installed library.

The build log states which one was used. At runtime the library checks the hdll's binding version against its own and refuses to initialize on a mismatch, printing the `build-hdll` command to run.

Kha builds never involve the hdll, on the Kore HL/C target included, since the binding is compiled into the executable there.

## C++

C++ builds compile the binding (`linc_faxe.cpp`) into the executable alongside your game and link against the FMOD libraries in `FMOD_SDK`. Kha's native targets do this through the library's `kfile.js`. There is nothing version-specific to rebuild. Switching FMOD Engine versions means pointing `FMOD_SDK` at the new SDK and rebuilding.

## Other FMOD Engine versions

The officially supported FMOD Engine version is 2.03.12. Other versions may work but are not tested. C++, Kha, and HTML5 builds compile or load against whichever SDK `FMOD_SDK` and `FMOD_SDK_WEB` point at, so they need nothing extra. HashLink builds load the pre-built hdll, which is compiled against 2.03.12, so another version needs the hdll compiled from source against your installed SDK:

```bash
# 1. Set FMOD_SDK to your version
export FMOD_SDK=/path/to/your/fmodstudioapi

# 2. Compile the hdll (from your project directory)
haxelib run haxefmod build-hdll

# 3. Build as normal
lime test hl
```

[build-hdll](guides/tools-cli.md#build-hdll) covers what the command needs. Bank files require an engine at least as new as the FMOD Studio that built them, so the Studio version and the engine version move together. `StudioSystem.getVersion()` reports the engine the running build loaded, formatted like `"2.03.12"`, which confirms where `FMOD_SDK`, `FMOD_SDK_WEB`, or the hdll points.

## Live Update

FMOD Studio Live Update connects Studio to the running game for mixing in real time. It works on C++ and HashLink builds and opens TCP port 9264, which the FMOD API does not allow changing. It is on by default in `-debug` builds, and can be forced either way with the `liveUpdate` setting or the `haxefmod_live_update` and `haxefmod_no_live_update` defines.

```haxe
FmodManager.Initialize({liveUpdate: true});
```

macOS and Windows show a firewall dialog the first time a Live Update build runs, since the game is listening on a local socket.
