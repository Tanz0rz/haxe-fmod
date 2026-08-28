# platforms-html5

## Libraries
verdict: review note only, decide bound or a category
The library's post-build step copies fmodstudio.js and fmodstudio.wasm from FMOD_SDK_WEB next to the output, loads the module, and wires up the FMOD object, so there is no script tag, Emscripten flag, or out-value plumbing to write. The Haxe API is the same on every target. FmodManager.IsInitialized() reports true once the wasm module and the default banks are usable, and the library resumes FMOD's mixer on the first click in the page. CoreSystem.mixerSuspend and CoreSystem.mixerResume are available when a game wants to stop and restart the mixer itself.

## Libraries#2
verdict: review note only, decide bound or a category
The library's post-build step copies fmodstudio.js and fmodstudio.wasm from FMOD_SDK_WEB next to the output, loads the module, and wires up the FMOD object, so there is no script tag, Emscripten flag, or out-value plumbing to write. The Haxe API is the same on every target. FmodManager.IsInitialized() reports true once the wasm module and the default banks are usable, and the library resumes FMOD's mixer on the first click in the page. CoreSystem.mixerSuspend and CoreSystem.mixerResume are available when a game wants to stop and restart the mixer itself.

## Using FMOD with C/C++
verdict: review note only, decide bound or a category
The library's post-build step copies fmodstudio.js and fmodstudio.wasm from FMOD_SDK_WEB next to the output, loads the module, and wires up the FMOD object, so there is no script tag, Emscripten flag, or out-value plumbing to write. The Haxe API is the same on every target. FmodManager.IsInitialized() reports true once the wasm module and the default banks are usable, and the library resumes FMOD's mixer on the first click in the page. CoreSystem.mixerSuspend and CoreSystem.mixerResume are available when a game wants to stop and restart the mixer itself.

## Flags using WASM pthread build
verdict: review note only, decide bound or a category
The library's post-build step copies fmodstudio.js and fmodstudio.wasm from FMOD_SDK_WEB next to the output, loads the module, and wires up the FMOD object, so there is no script tag, Emscripten flag, or out-value plumbing to write. The Haxe API is the same on every target. FmodManager.IsInitialized() reports true once the wasm module and the default banks are usable, and the library resumes FMOD's mixer on the first click in the page. CoreSystem.mixerSuspend and CoreSystem.mixerResume are available when a game wants to stop and restart the mixer itself.

## Overriding FMOD's 'window' handle.
verdict: review note only, decide bound or a category
The library's post-build step copies fmodstudio.js and fmodstudio.wasm from FMOD_SDK_WEB next to the output, loads the module, and wires up the FMOD object, so there is no script tag, Emscripten flag, or out-value plumbing to write. The Haxe API is the same on every target. FmodManager.IsInitialized() reports true once the wasm module and the default banks are usable, and the library resumes FMOD's mixer on the first click in the page. CoreSystem.mixerSuspend and CoreSystem.mixerResume are available when a game wants to stop and restart the mixer itself.

## Application setup
verdict: review note only, decide bound or a category
The library's post-build step copies fmodstudio.js and fmodstudio.wasm from FMOD_SDK_WEB next to the output, loads the module, and wires up the FMOD object, so there is no script tag, Emscripten flag, or out-value plumbing to write. The Haxe API is the same on every target. FmodManager.IsInitialized() reports true once the wasm module and the default banks are usable, and the library resumes FMOD's mixer on the first click in the page. CoreSystem.mixerSuspend and CoreSystem.mixerResume are available when a game wants to stop and restart the mixer itself.

## Setting and getting
verdict: review note only, decide bound or a category
The library's post-build step copies fmodstudio.js and fmodstudio.wasm from FMOD_SDK_WEB next to the output, loads the module, and wires up the FMOD object, so there is no script tag, Emscripten flag, or out-value plumbing to write. The Haxe API is the same on every target. FmodManager.IsInitialized() reports true once the wasm module and the default banks are usable, and the library resumes FMOD's mixer on the first click in the page. CoreSystem.mixerSuspend and CoreSystem.mixerResume are available when a game wants to stop and restart the mixer itself.

## Using structures
verdict: review note only, decide bound or a category
The library's post-build step copies fmodstudio.js and fmodstudio.wasm from FMOD_SDK_WEB next to the output, loads the module, and wires up the FMOD object, so there is no script tag, Emscripten flag, or out-value plumbing to write. The Haxe API is the same on every target. FmodManager.IsInitialized() reports true once the wasm module and the default banks are usable, and the library resumes FMOD's mixer on the first click in the page. CoreSystem.mixerSuspend and CoreSystem.mixerResume are available when a game wants to stop and restart the mixer itself.

## Direct from host, via FMOD's filesystem
verdict: review note only, decide bound or a category
The library's post-build step copies fmodstudio.js and fmodstudio.wasm from FMOD_SDK_WEB next to the output, loads the module, and wires up the FMOD object, so there is no script tag, Emscripten flag, or out-value plumbing to write. The Haxe API is the same on every target. FmodManager.IsInitialized() reports true once the wasm module and the default banks are usable, and the library resumes FMOD's mixer on the first click in the page. CoreSystem.mixerSuspend and CoreSystem.mixerResume are available when a game wants to stop and restart the mixer itself.

## Direct from host, via FMOD's filesystem#2
verdict: bound
The web build decodes FSB only, so Sound.create on a loose .wav path returns FMOD_ERR_FORMAT on HTML5. Load a bank instead, or feed raw PCM through Sound.fromPcm. Banks are fetched into the browser's virtual filesystem for you, and StudioSystem.lastResult() holds the error when a load fails.
```haxe
import haxefmod.core.Sound;

var bank = StudioSystem.loadBankFile("SFX.bank");
if (bank.isNull()) {
    trace("bank load failed: " + StudioSystem.lastResult());
}

var pcm = haxe.io.Bytes.alloc(48000 * 2 * 2);
var sound = Sound.fromPcm(pcm, 48000, 2);
if (!sound.isNull()) {
    var ch = sound.play();
}
```

## Via memory
verdict: bound
Data already in memory goes in as haxe.io.Bytes. The binding copies it into FMOD's heap, so there is no pointer to manage.
```haxe
import haxefmod.core.Sound;

var bankBytes = haxe.io.Bytes.alloc(0);
var bank = StudioSystem.loadBankMemory(bankBytes);
if (bank.isNull()) {
    trace("bank load failed: " + StudioSystem.lastResult());
}

var pcm = haxe.io.Bytes.alloc(48000 * 2 * 2);
var sound = Sound.fromPcm(pcm, 48000, 2);
```

## Via callbacks
verdict: review note only, decide bound or a category
Custom file callbacks are not exposed because they would run on FMOD threads, which Haxe code cannot do. Fetch the data yourself and hand it to StudioSystem.loadBankMemory.

## Via callbacks#2
verdict: review note only, decide bound or a category
Custom file callbacks are not exposed because they would run on FMOD threads, which Haxe code cannot do. Fetch the data yourself and hand it to StudioSystem.loadBankMemory.

## Via callbacks#3
verdict: review note only, decide bound or a category
Custom file callbacks are not exposed because they would run on FMOD threads, which Haxe code cannot do. Fetch the data yourself and hand it to StudioSystem.loadBankMemory.

## CPU Overhead
verdict: bound
The mixer sample rate is an init-time setting. Pass it to FmodManager.Initialize, or set -D haxefmod_sample_rate in project.xml. CoreSystem.getDriverName names the output device, its native rate is not reported, and CoreSystem.getSoftwareFormat reports the rate in use.
```haxe
import haxefmod.core.CoreSystem;

FmodManager.Initialize({sampleRate: 44100});

trace("output device " + CoreSystem.getDriverName(0));

var format = CoreSystem.getSoftwareFormat();
if (format != null) {
    trace("mixing at " + format.sampleRate + " Hz");
}
```

## Audio Stability (Stuttering)
verdict: review note only, decide bound or a category
The dspBufferSize and dspNumBuffers fields of FmodSettings are native only (unsupported in HTML5). The web build fixes the mixer at 2048 samples by 2 buffers and ignores them.
