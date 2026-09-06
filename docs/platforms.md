# Platforms

The Haxe API is identical on every target. Underneath, the targets differ in what initializes asynchronously and in how the build finds the native binding. They also differ in how a build uses another FMOD Engine version. [Limitations](limitations.md#html5) has the FMOD features the web build lacks.

## HTML5

The FMOD web build is a WebAssembly module. The library's post-build step copies `fmodstudio.js` and `fmodstudio.wasm` from `FMOD_SDK_WEB` next to the output. On Heaps and Kha the [stage command](guides/tools-cli.md#stage) does this copy. An HTML5 build must have `FMOD_SDK_WEB` set, even when `FMOD_SDK` is also set.

### Asynchronous initialization

The wasm module and the default banks load in the background. `FmodManager.IsInitialized()` (or `FmodRuntime.isInitialized()`) reports true once both are usable. An HTML5 game runs a loading scene first and starts the real game from it. The same code is correct on native targets, where the check is true immediately.

```haxe
function update():Void {
    if (FmodManager.IsInitialized()) {
        startGame();
    }
}
```

The [example project's `LoadFmodState.hx`](https://github.com/Tanz0rz/haxe-fmod/blob/master/example-project/EZPlatformer/source/LoadFmodState.hx) is the flixel version of this pattern. Setup code that pushes state to FMOD can use `FmodRuntime.onceReady` instead of a poll.

Bank loads are always asynchronous on HTML5. A bank file exists in the browser's virtual filesystem only after a fetch wrote it. `BankRegistry.load` and `loadAsync` behave the same there. See [Banks and settings](guides/banks-and-settings.md#bank-loading).

### Browser autoplay

Browsers refuse to start audio before the user interacts with the page. The library resumes FMOD's mixer on the first click in the page. Audio started before that click plays from that moment on. A game that wants sound from the first frame puts a "click to start" screen ahead of it.

### Native-only calls

A call to a feature the web build lacks is a compile error in a js build. The compiler stops at the call site, names the method and the reason, and points at the opt-out. A project that shares code across targets and branches at runtime sets `-D haxefmod_html5_allow_unsupported`. The calls then compile and return `FMOD_ERR_UNSUPPORTED` at runtime in the browser. The library prints one warning per build that says so.

## HashLink

HashLink loads the binding from `hlaxe_fmod.hdll`, a native library compiled against one FMOD Engine version. The library bundles pre-built hdlls for 2.03.12 on Linux, macOS, and Windows.

At build time `lime test hl` looks for the hdll in this order. The [stage command](guides/tools-cli.md#stage) does the same for Heaps builds.

1. Project-local `.haxefmod/hlaxe_fmod.hdll`, when present. `haxelib run haxefmod build-hdll` writes it there.
2. The pre-built `templates/bin/hl/<Platform>/hlaxe_fmod.hdll` inside the installed library.

The build log states which one it used. At runtime the library checks the hdll's binding version against its own. On a mismatch it refuses to initialize and prints the `build-hdll` command to run.

Kha builds never use the hdll, the Kore HL/C target included, because the binding is compiled into the executable there.

## C++

C++ builds compile the binding (`linc_faxe.cpp`) into the executable next to your game. They link against the FMOD libraries in `FMOD_SDK`. Kha's native targets do this through the library's `kfile.js`. There is nothing version-specific to rebuild. To switch FMOD Engine versions, point `FMOD_SDK` at the new SDK and rebuild.

## Other FMOD Engine versions

The officially supported FMOD Engine version is 2.03.12. Other versions can work but are not tested. C++, Kha, and HTML5 builds compile or load against the SDK that `FMOD_SDK` and `FMOD_SDK_WEB` point at. They need nothing extra. HashLink builds load the pre-built hdll, which is compiled against 2.03.12. For another version, compile the hdll from source against your installed SDK.

```bash
# 1. Set FMOD_SDK to your version
export FMOD_SDK=/path/to/your/fmodstudioapi

# 2. Compile the hdll (from your project directory)
haxelib run haxefmod build-hdll

# 3. Build as normal
lime test hl
```

[build-hdll](guides/tools-cli.md#build-hdll) covers what the command needs. Bank files require an engine at least as new as the FMOD Studio that built them. The Studio version and the engine version therefore move together. `StudioSystem.getVersion()` reports the engine that the running build loaded, formatted like `"2.03.12"`. That value confirms where `FMOD_SDK`, `FMOD_SDK_WEB`, or the hdll points.

## Live Update

FMOD Studio Live Update connects Studio to the running game, so you can mix in real time. It works on C++ and HashLink builds. It opens TCP port 9264, and the FMOD API does not allow another port. It is on by default in `-debug` builds. The `liveUpdate` setting or the `haxefmod_live_update` and `haxefmod_no_live_update` defines force it on or off.

```haxe
FmodManager.Initialize({liveUpdate: true});
```

The game listens on a local socket. macOS and Windows therefore show a firewall dialog the first time a Live Update build runs.
