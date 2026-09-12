# Platforms

The Haxe API is identical on every target. Underneath, the targets differ in what initializes asynchronously and in how the build finds the native binding. They also differ in how a build uses another FMOD Engine version. [Limitations](limitations.md#html5) has the FMOD features the web build lacks.

## HTML5

The FMOD web build is a WebAssembly module. The library's post-build step copies `fmodstudio.js` and `fmodstudio.wasm` from `FMOD_SDK_WEB` next to the output. On Heaps and Kha the [stage command](guides/tools-cli.md#stage) does this copy. An HTML5 build must have `FMOD_SDK_WEB` set, even when `FMOD_SDK` is also set.

### Asynchronous initialization

The wasm module and the default banks load in the background. `FmodManager.IsInitialized()` (or `FmodRuntime.isInitialized()`) reports true once the module is up and every default bank is loaded or has failed.

The engine preloaders make that wait invisible. `FmodFlxPreloader` runs inside lime's preloader, and `FmodHeapsSetup.preload` and `FmodKhaSetup.preload` call back once FMOD is ready. Each hands the default banks to the runtime as bytes it read during loading. The banks are fetched once, and the first scene starts with FMOD usable. [Engine components](guides/components.md#setup) shows the three.

The bytes go through `FmodRuntime.provideBank(fileName, bytes)`, with the `banksProvided` setting on. A game on another engine does the same from whatever loads its assets, then calls `FmodRuntime.onceReady(start, onFailed)`.

A game that starts FMOD without a preloader polls the flag from a loading scene. It starts the real game from there. The same code is correct on native targets, where the check is true immediately.

```haxe
function update():Void {
    if (FmodManager.IsInitialized()) {
        startGame();
    }
}
```

`FmodManager.InitializeFailed()` reports that a default bank failed to load, or that FMOD refused to initialize. A missing bank leaves the system running without it. `InitializeSettled()` turns true once every default bank is loaded or has failed, or FMOD refused. A loading scene shows a message and starts the game on that. `FmodFlxPreloader` does this for you. `FmodHeapsSetup.preload` and `FmodKhaSetup.preload` run the `onFailed` callback the game passed, or `onReady` anyway when there is none. `AnyBankFailed()` reports the same for a bank loaded later.

```haxe
var audioWarned = false;

function updateLoadingScene():Void {
    if (FmodManager.InitializeFailed() && !audioWarned) {
        audioWarned = true;
        trace("Audio did not fully start, the console names the cause");
    }
    if (FmodManager.InitializeSettled()) startGame();
}
```

The three example games start through their preloaders and have no loading scene. Setup code that pushes state to FMOD can use `FmodRuntime.onceReady` instead of a poll.

Bank loads are always asynchronous on HTML5. A bank file exists in the browser's virtual filesystem only after a fetch wrote it. `BankRegistry.load` and `loadAsync` behave the same there. See [Bank loading](guides/bank-loading.md).

### Browser autoplay

Browsers refuse to start audio before the user interacts with the page. The library listens for `click`, `keydown`, `pointerdown`, and `touchstart` from the moment its script loads. It resumes FMOD's mixer on the first of them, so a gesture made during the loading screen counts. An event started before that gesture is silent until the mixer resumes, then plays from that moment on. A game that wants sound from the first frame puts a "click to start" screen ahead of it.

### Native-only calls

A call to a feature the web build lacks is a compile error in a js build. A js build refuses the call at compile time and names the method and the reason. Set `-D haxefmod_html5_allow_unsupported` to compile it anyway. The call then returns `FMOD_ERR_UNSUPPORTED` in the browser, and the build prints one warning.

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
