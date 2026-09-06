# Banks and settings

`haxefmod.runtime` sits between the helper class and the FMOD Studio bindings. `FmodRuntime` initializes the engine from a settings object and loads the default banks. It owns the bank registry and runs the per-frame update. `FmodManager` is built on it. A game that wants more control uses it directly.

## Initialization

`FmodRuntime.init(?settings)` creates the FMOD system. One system exists per process. The first `init` creates it, and it lives until the process exits. There is no shutdown or re-init call. The first `init` wins. Later calls return `FMOD_OK` and change nothing.

```haxe
import haxefmod.runtime.FmodRuntime;

FmodRuntime.init({liveUpdate: true, bankFolder: "assets/audio"});
var jump = FmodRuntime.createInstance("event:/SFX/Jump");
jump.start();
jump.release();
```

`FmodRuntime.isInitialized()` is true once the system is up and every bank in `autoLoadBanks` is loaded. Native targets do both synchronously inside `init`. HTML5 does both asynchronously. An HTML5 game polls the flag or hands work to `onceReady`.

```haxe
import haxefmod.runtime.FmodRuntime;

FmodRuntime.onceReady(() -> {
    StudioSystem.setParameter("TimeOfDay", 0.5);
});
```

`onceReady` runs the handler immediately when initialization is already complete. Otherwise it runs the handler on the first serviced frame after initialization completes. Values pushed to FMOD before that point land on objects that do not exist yet. Setup code that applies state belongs inside the handler.

`FmodRuntime.update()` services the runtime. It drains the callback queue and pushes the positions of attached instances. It also calls FMOD's update when the background auto-update is off. `FmodManager.Update()` calls it, so a game needs only one of the two.

## Settings

`FmodSettings` is a typedef. Every field is optional. An unset field falls back to a compile-time define, then to the built-in default.

| Field | Define | Default | Meaning |
|---|---|---|---|
| `numChannels` | `haxefmod_num_channels` | 128 | Maximum virtual voices. |
| `sampleRate` | `haxefmod_sample_rate` | 0 | Mixer sample rate. 0 uses the device default. |
| `speakerMode` | | 0 | `FMOD_SPEAKERMODE` value. 0 uses the device default. |
| `rawSpeakers` | | 0 | Speaker count for `speakerMode` `RAW`. Every other mode ignores it. |
| `output` | | `AUTODETECT` | `FmodOutputType` applied before init. `NOSOUND` and `NOSOUND_NRT` mix without a device. `WAVWRITER` writes the mix to a file. The platform values pick a driver. The `FMOD_WAVWRITER` environment variable still forces `WAVWRITER` into the file it names. HTML5 has only `WEBAUDIO`, `AUDIOWORKLET`, `NOSOUND`, and `NOSOUND_NRT`. Any other value there makes init fail with `FMOD_ERR_UNSUPPORTED`. |
| `resamplerMethod` | | `DEFAULT` | `FmodDspResampler` for sounds that play at another rate than the mixer. `DEFAULT` is FMOD's choice, `LINEAR`. |
| `dspBufferSize` | `haxefmod_dsp_buffer_size` | 0 | Mixer block size in samples. Smaller buffers cut latency and cost CPU. 0 uses FMOD's default. That default is 1024 on desktop and 2048 on the web build. |
| `dspNumBuffers` | | 0 | Mixer blocks queued ahead. 0 uses FMOD's default of 2. |
| `memoryPoolSize` | | 0 | Bytes of a fixed pool FMOD allocates from instead of the heap. The pool never grows. An exhausted pool fails later calls with `FMOD_ERR_MEMORY`. The size is rounded up to a multiple of 512. Native only. The web build allocates from the wasm heap. |
| `memoryTracking` | | false | Tracks memory per object. `getMemoryUsage` on `StudioSystem`, `Bank`, `Bus`, and `EventInstance` then reports real numbers. Only the logging FMOD libraries (`libfmodstudioL`) count. The release libraries report zero. Tracking costs a little CPU per allocation. |
| `threadAttributes` | | `[]` | One `{type, priority, stackSize, affinity}` per FMOD worker thread to change. The library applies them before it creates the system. An unset field keeps FMOD's default for that thread. `affinity` is a 32-bit core mask (`FmodThreadAffinity`). The 64-bit group values stay FMOD's. Native only. The web build has no threads to place. |
| `logFile` | | none | File that receives FMOD's log at `logLevel` instead of the console. Native only. |
| `logFlags` | | 0 | Extra `FmodDebugFlags` bits. The `TYPE_` bits add memory, file, codec, trace, and virtual voice lines. The `DISPLAY_` bits add timestamps, line numbers, and thread ids. Native only. |
| `softwareChannels` | `haxefmod_software_channels` | 0 | Real (audible) voices that the mixer runs at once. Voices past the cap go virtual. 0 uses FMOD's default of 64. |
| `streamBufferSize` | | 0 | File buffer size in bytes for streamed sounds. 0 uses FMOD's default of 16384. |
| `profiling` | | false | Turns on FMOD profiling. `Bus`, `EventInstance`, and `Dsp` report `getCpuUsage()` only with this on. The FMOD Profiler can then connect to the game. |
| `distanceFilter` | | false | Turns on the per-channel distance lowpass. 3D core channels then muffle with distance. `Channel.set3DDistanceFilter` tunes the filter. |
| `liveUpdate` | `haxefmod_live_update`, `haxefmod_no_live_update` | true in `-debug` builds | Opens the Live Update connection on TCP port 9264. Native only. |
| `logLevel` | `haxefmod_log_level` | 1 | FMOD debug logging. 0 none, 1 errors, 2 warnings, 3 everything. |
| `bankFolder` | `haxefmod_bank_folder` | `assets/fmod/Desktop` | Folder that bank file names resolve against. |
| `autoLoadBanks` | | `["Master.bank", "Master.strings.bank"]` | Banks that init loads. Pass `[]` to manage all loading yourself. |
| `autoUpdate` | | true | Services FMOD from a background thread (native) or timer (HTML5). Audio then keeps running when the game loop stalls. |
| `muteWhenUnfocused` | `haxefmod_no_mute_when_unfocused` | true | Mutes the master output while the window is unfocused. See [FmodManager](fmod-manager.md#window-focus). |
| `maxMPEGCodecs`, `maxVorbisCodecs`, `maxFADPCMCodecs` | | 0 | Codec pool sizes. 0 keeps FMOD's default for each. |
| `vol0VirtualVol` | | 0 | Volume below which a voice goes virtual. 0 keeps FMOD's default. |
| `defaultDecodeBufferSize`, `profilePort`, `geometryMaxFadeTime`, `distanceFilterCenterFreq`, `randomSeed` | | 0 | The remaining core advanced settings. The library passes them through as given. 0 keeps FMOD's default. |
| `commandQueueSize`, `handleInitialSize`, `studioUpdatePeriod`, `idleSampleDataPoolSize`, `streamingScheduleDelay` | | 0 | The Studio advanced settings. 0 keeps FMOD's default. |
| `encryptionKey` | | none | The key for banks built with encryption in FMOD Studio. |
| `maxAttachedVelocity` | | 0 | Caps the velocity magnitude pushed for attached instances and the engine listeners. The unit is game units per second. 0 means no cap. See [Callbacks and 3D](callbacks-and-3d.md#doppler-and-velocity). |

=== "HaxeFlixel"

    Defines go in `Project.xml`:

    ```xml
    <haxedef name="haxefmod_num_channels" value="256" />
    ```

=== "Heaps"

    Defines go in the hxml:

    ```text
    -D haxefmod_num_channels=256
    ```

=== "Kha"

    Defines go in the khafile:

    ```js
    project.addDefine('haxefmod_num_channels=256');
    ```

`FmodRuntime.settings()` returns the fully resolved settings after init. Before init it returns `null`.

## Bank loading

`FmodRuntime.banks` is a `BankRegistry`, a refcounted loader keyed by normalized path. Several systems can ask for the same bank. The registry unloads it only when the last of them lets go. Bank file names without a directory resolve against `bankFolder` through `FmodRuntime.bankPath`.

```haxe
import haxefmod.runtime.FmodRuntime;

var path = FmodRuntime.bankPath("Vehicles.bank");
var bank = FmodRuntime.banks.load(path);
if (bank.isNull()) trace("Vehicles.bank failed to load");
// later, when the level ends
FmodRuntime.banks.unload(path);
```

`load` blocks on native. On HTML5 it always runs asynchronously. A file exists in the browser's virtual filesystem only after a fetch wrote it. `loadAsync` starts a background load on every target. It returns a handle that becomes usable once `loadingState(path)` reports `LOADED`. The other registry calls are `isLoaded`, `loadingState`, `refCount`, `get`, `anyLoading`, and `anyError`. `unload` returns true when it unloaded the bank. It returns false when it only decremented the count.

```haxe
import haxefmod.runtime.FmodRuntime;

FmodRuntime.banks.loadAsync(FmodRuntime.bankPath("Vehicles.bank"));
// in update, once per frame
if (FmodRuntime.banks.isLoaded(FmodRuntime.bankPath("Vehicles.bank"))) {
    FmodManager.PlaySoundOneShot("event:/Vehicles/Horn");
}
```

A path that settles in `ERROR` is not deduplicated. A second load replaces the dead entry, so a game can retry a failed fetch.

Two spellings of one file share one refcount, because `BankRegistry.normalizePath` collapses separators and `.` segments. Windows backslashes are accepted.

## Loading outside the registry

`StudioSystem.loadBankFile`, `loadBankMemory`, `getBank`, and the `Bank` methods are FMOD's own calls and remain available. The registry adopts a bank loaded that way on the first registry load of the same path. `StudioSystem.unloadAll()` unloads everything, and the registry keeps its reference counts. A later registry load carries those counts forward.
