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
Getters return the value directly, there is no out object. A failed getter returns its default and StudioSystem.lastResult() holds the error.
```haxe
import haxefmod.core.Sound;

var sound = Sound.create("lion.wav");
var name:String; // to store name of sound.

name = sound.getName();

trace(name);
```

## Using structures
verdict: covered FMOD_GUID is FmodGuid, the text form FMOD Studio shows, returned by EventDescription.getID and taken by StudioSystem.getEventByID, and FMOD_STUDIO_BANK_INFO is not exposed because StudioSystem.loadBankFile and StudioSystem.loadBankMemory load banks without file callbacks

## Direct from host, via FMOD's filesystem
verdict: library the library fetches banks itself, FmodRuntime.banks.load (and the autoLoadBanks list in FmodSettings, resolved against bankFolder) fetches the path relative to the page and writes it into FMOD's virtual filesystem before calling loadBankFile, and loose audio files are not preloaded because the web build decodes FSB only

## Direct from host, via FMOD's filesystem#2
verdict: bound
Sound.create reads the path from FMOD's virtual filesystem, where the library preloads banks only, and the web build decodes FSB only. On HTML5 a loose wav returns Sound.NULL, with FMOD_ERR_FILE_NOTFOUND when nothing put the file there or FMOD_ERR_FORMAT for a file that is not an FSB. Play bank content, load an FSB with Sound.fromMemory, or feed raw PCM through Sound.fromPcm. The second argument is loop, false stands for FMOD_LOOP_OFF.
```haxe
import haxefmod.core.Sound;

var sound = Sound.create("lion.wav", false);
if (sound.isNull()) {
    trace("createSound failed: " + StudioSystem.lastResult());
}
```

## Via memory
verdict: bound
Data already in memory goes in as haxe.io.Bytes and is copied into FMOD's heap. Sound.fromMemory takes an encoded file image, the ChannelMode flags to open it with (OPENMEMORY is added by the library, CREATESTREAM stands for createStream), and the length that fills CREATESOUNDEXINFO.length, which defaults to the size of the bytes. The web build decodes FSB images only, so a wav or ogg image returns Sound.NULL with FMOD_ERR_FORMAT there. Sound.fromPcm takes raw PCM, its sampleRate and channels arguments stand in for the CREATESOUNDEXINFO fields. Bank data in memory goes through StudioSystem.loadBankMemory.
```haxe
import haxefmod.core.Sound;
import haxefmod.core.ChannelMode;

var image = haxe.io.Bytes.alloc(0); // an FSB file image fetched by the game

var sound = Sound.fromMemory(image, ChannelMode.LOOP_OFF | ChannelMode.CREATESTREAM, image.length);
if (sound.isNull()) {
    trace("fromMemory failed: " + StudioSystem.lastResult());
}

var bytes = haxe.io.Bytes.alloc(48000 * 2 * 2);

var pcmSound = Sound.fromPcm(bytes, 48000, 2);
if (pcmSound.isNull()) {
    trace("fromPcm failed: " + StudioSystem.lastResult());
}

var bankBytes = haxe.io.Bytes.alloc(0);
var bank = StudioSystem.loadBankMemory(bankBytes);
if (bank.isNull()) {
    trace("loadBankMemory failed: " + StudioSystem.lastResult());
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
The dspBufferSize and dspNumBuffers fields of FmodSettings set the mixer block before the system initializes. Unset, the web build runs at 2048 samples by 2 buffers.
```haxe
FmodManager.Initialize({dspBufferSize: 2048, dspNumBuffers: 2});
```
