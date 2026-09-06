# platforms-html5

## Libraries
verdict: library the post-build step (haxefmod.tools.PostBuild) copies fmodstudio.js and fmodstudio.wasm from FMOD_SDK_WEB into the output's lib folder and jaxe.js loads them, a Haxe project adds no script tag

## Libraries#2
verdict: library the post-build step (haxefmod.tools.PostBuild) copies fmodstudio.js and fmodstudio.wasm from FMOD_SDK_WEB into the output's lib folder and jaxe.js loads them, a Haxe project adds no script tag

## Using FMOD with C/C++
verdict: cannot Emscripten link flags for a C or C++ program compiled against FMOD, a Haxe HTML5 build compiles to JavaScript and runs FMOD's prebuilt fmodstudio.js, there is nothing to link

## Flags using WASM pthread build
verdict: cannot Emscripten link flags for a C or C++ program compiled against FMOD, a Haxe HTML5 build compiles to JavaScript and runs FMOD's prebuilt fmodstudio.js, there is nothing to link

## Overriding FMOD's 'window' handle.
verdict: library jaxe.js runs in the page's own window and calls FMODModule from it, so the module sees the right window and nothing is overridden

## Application setup
verdict: library FmodManager.Initialize does this through jaxe.js, which sets preRun, onRuntimeInitialized, and a 64 MB INITIAL_MEMORY on the FMOD object and calls FMODModule, the game's main becomes FmodManager.IsInitialized() polled from a loading scene or a handler passed to FmodRuntime.onceReady

## Setting and getting
verdict: bound
```haxe
import haxefmod.core.Sound;

var name:String; // to store name of sound.

name = sound.getName(); // the returned value. Assign it to the variable we want to keep.

trace(name);
```

## Using structures
verdict: covered FMOD_GUID is FmodGuid, the text form FMOD Studio shows, returned by EventDescription.getID and taken by StudioSystem.getEventByID, and FMOD_STUDIO_BANK_INFO is not exposed because StudioSystem.loadBankFile and StudioSystem.loadBankMemory load banks without file callbacks

## Direct from host, via FMOD's filesystem
verdict: library the library fetches banks itself, FmodRuntime.banks.load (and the autoLoadBanks list in FmodSettings, resolved against bankFolder) fetches the path relative to the page and writes it into FMOD's virtual filesystem before calling loadBankFile, and loose audio files are not preloaded because the web build decodes FSB only

## Direct from host, via FMOD's filesystem#2
verdict: bound
```haxe
import haxefmod.core.Sound;

var sound = Sound.create("/lion.wav", false);
if (sound.isNull()) {
    trace(StudioSystem.lastResult());
}
```

## Via memory
verdict: bound
waive: extra-calls the web snippet's createStream is Sound.fromMemory with the CREATESTREAM mode
```haxe
import haxefmod.core.Sound;
import haxefmod.core.ChannelMode;

var sound = Sound.fromMemory(chars, ChannelMode.LOOP_OFF | ChannelMode.CREATESTREAM, chars.length);
if (sound.isNull()) {
    trace(StudioSystem.lastResult());
}
```

## Via callbacks
verdict: cannot file callbacks run on FMOD's file threads and custom file systems are not exposed, fetch the bytes yourself and hand them to StudioSystem.loadBankMemory

## Via callbacks#2
verdict: cannot file callbacks run on FMOD's file threads and custom file systems are not exposed, fetch the bytes yourself and hand them to StudioSystem.loadBankMemory

## Via callbacks#3
verdict: cannot file callbacks run on FMOD's file threads and custom file systems are not exposed, fetch the bytes yourself and hand them to StudioSystem.loadBankMemory

## CPU Overhead
verdict: library jaxe.js does this at init, it reads the driver's rate with getDriverInfo and passes it to setSoftwareFormat when the sampleRate setting is 0 (the default), a game that wants another rate passes FmodManager.Initialize({sampleRate: 48000}) or sets -D haxefmod_sample_rate and reads the rate in use from CoreSystem.getSoftwareFormat()

## Audio Stability (Stuttering)
verdict: bound
```haxe
FmodManager.Initialize({dspBufferSize: 2048, dspNumBuffers: 2});
```

