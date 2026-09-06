# Banks and settings

`haxefmod.runtime` is the layer between the facade and the raw FMOD Studio bindings. `FmodRuntime` initializes the engine from a settings object, loads the default banks, owns the bank registry, and runs the per-frame update. `FmodManager` is built on it, and games that want more control use it directly.

## Initialization

`FmodRuntime.init(?settings)` creates the FMOD system. There is exactly one system per process, created on the first `init` and alive until the process exits. There is no shutdown or re-init call, which removes the whole class of use-after-shutdown bugs and costs nothing games actually use. The first `init` wins and later calls return `FMOD_OK` without changing anything.

```haxe
import haxefmod.runtime.FmodRuntime;

FmodRuntime.init({liveUpdate: true, bankFolder: "assets/audio"});
var jump = FmodRuntime.createInstance("event:/SFX/Jump");
jump.start();
jump.release();
```

`FmodRuntime.isInitialized()` is true once the system is up and every bank in `autoLoadBanks` is loaded. Native targets do both synchronously inside `init`. HTML5 does both asynchronously, so an HTML5 game polls it, or hands work to `onceReady`.

```haxe
import haxefmod.runtime.FmodRuntime;

FmodRuntime.onceReady(() -> {
    StudioSystem.setParameter("TimeOfDay", 0.5);
});
```

`onceReady` runs the handler immediately when initialization already completed, otherwise on the first serviced frame after it does. Values pushed to FMOD before that point land on objects that do not exist yet, so setup code that applies state belongs inside it.

`StudioSystem.getVersion()` returns the FMOD Engine version the running build loaded, as a string like `"2.03.12"`, or an empty string on failure. It is the quickest way to confirm which SDK or hdll a build picked up.

`FmodRuntime.update()` services the runtime. It drains the callback queue, pushes attached-instance positions, and calls FMOD's update when the background auto-update is off. `FmodManager.Update()` calls it, so a game only needs one of the two.

## Settings

`FmodSettings` is a typedef with every field optional. An unset field falls back to a compile-time define, then to the built-in default.

The engine reports what it runs with after init: `CoreSystem.getSoftwareFormat()`, `getSoftwareChannels()`, `getDSPBufferSize()`, and `getStreamBufferSize()` read the values FMOD settled on, defaults included.

| Field | Define | Default | Meaning |
|---|---|---|---|
| `numChannels` | `haxefmod_num_channels` | 128 | Maximum virtual voices. |
| `sampleRate` | `haxefmod_sample_rate` | 0 | Mixer sample rate. 0 uses the device default. |
| `speakerMode` | | 0 | `FMOD_SPEAKERMODE` value. 0 uses the device default. |
| `rawSpeakers` | | 0 | Speaker count for `speakerMode` `RAW`. Ignored for every other mode. |
| `output` | | `AUTODETECT` | `FmodOutputType` applied before init: `NOSOUND` and `NOSOUND_NRT` mix without a device, `WAVWRITER` writes the mix to a file, and the platform values pick a driver. The `FMOD_WAVWRITER` environment variable still forces `WAVWRITER` into the file it names. On HTML5 only `WEBAUDIO`, `AUDIOWORKLET`, `NOSOUND`, and `NOSOUND_NRT` exist, and any other value makes init fail with `FMOD_ERR_UNSUPPORTED`. |
| `resamplerMethod` | | `DEFAULT` | `FmodDspResampler` for sounds playing at another rate than the mixer. `DEFAULT` is FMOD's choice, `LINEAR`. |
| `dspBufferSize` | `haxefmod_dsp_buffer_size` | 0 | Mixer block size in samples. Smaller buffers cut latency and cost CPU. 0 uses FMOD's default, 1024 on desktop and 2048 on the web build. |
| `dspNumBuffers` | | 0 | Mixer blocks queued ahead. 0 uses FMOD's default of 2. |
| `memoryPoolSize` | | 0 | Bytes of a fixed pool FMOD allocates from instead of the heap. The pool never grows, so an exhausted pool fails later calls with `FMOD_ERR_MEMORY`. Rounded up to a multiple of 512. Native only, the web build allocates from the wasm heap. |
| `memoryTracking` | | false | Tracks memory per object so `getMemoryUsage` on `StudioSystem`, `Bank`, `Bus`, and `EventInstance` reports real numbers. Only the logging FMOD libraries (`libfmodstudioL`) count, the release libraries report zero. Costs a little CPU per allocation. |
| `threadAttributes` | | `[]` | One `{type, priority, stackSize, affinity}` per FMOD worker thread to change, applied before the system is created. An unset field keeps FMOD's default for that thread. `affinity` is a 32-bit core mask (`FmodThreadAffinity`), the 64-bit group values stay FMOD's. Native only, the web build has no threads to place. |
| `logFile` | | none | File FMOD writes its log to at `logLevel` instead of the console. Native only. |
| `logFlags` | | 0 | Extra `FmodDebugFlags` bits: the `TYPE_` bits add memory, file, codec, trace, and virtual voice lines, the `DISPLAY_` bits add timestamps, line numbers, and thread ids. Native only. |
| `softwareChannels` | `haxefmod_software_channels` | 0 | Real (audible) voices the mixer runs at once. Voices past the cap go virtual. 0 uses FMOD's default of 64. |
| `streamBufferSize` | | 0 | File buffer size in bytes for streamed sounds. 0 uses FMOD's default of 16384. |
| `profiling` | | false | Turns on FMOD profiling. `Bus`, `EventInstance`, and `Dsp` report `getCpuUsage()` only with this on, and the FMOD Profiler can connect to the game. |
| `distanceFilter` | | false | Turns on the per-channel distance lowpass. 3D core channels then muffle with distance, and `Channel.set3DDistanceFilter` tunes it. See [Core API](core-api.md#channels). |
| `liveUpdate` | `haxefmod_live_update`, `haxefmod_no_live_update` | true in `-debug` builds | Opens the Live Update connection on TCP port 9264. Native only. |
| `logLevel` | `haxefmod_log_level` | 1 | FMOD debug logging. 0 none, 1 errors, 2 warnings, 3 everything. |
| `bankFolder` | `haxefmod_bank_folder` | `assets/fmod/Desktop` | Folder bank file names resolve against. |
| `autoLoadBanks` | | `["Master.bank", "Master.strings.bank"]` | Banks loaded during init. Pass `[]` to manage all loading yourself. |
| `autoUpdate` | | true | Services FMOD from a background thread (native) or timer (HTML5) so audio keeps running when the game loop stalls. |
| `muteWhenUnfocused` | `haxefmod_no_mute_when_unfocused` | true | Mutes the master output while the window is unfocused. See [FmodManager](fmod-manager.md#window-focus). |
| `maxMPEGCodecs`, `maxVorbisCodecs`, `maxFADPCMCodecs` | | 0 | Codec pool sizes. 0 keeps FMOD's default for each. |
| `vol0VirtualVol` | | 0 | Volume below which a voice goes virtual. 0 keeps FMOD's default. |
| `defaultDecodeBufferSize`, `profilePort`, `geometryMaxFadeTime`, `distanceFilterCenterFreq`, `randomSeed` | | 0 | The remaining core advanced settings, passed through as given. 0 keeps FMOD's default. |
| `commandQueueSize`, `handleInitialSize`, `studioUpdatePeriod`, `idleSampleDataPoolSize`, `streamingScheduleDelay` | | 0 | The Studio advanced settings. 0 keeps FMOD's default. |
| `encryptionKey` | | none | The key for banks built with encryption in FMOD Studio. |
| `maxAttachedVelocity` | | 0 | Caps the velocity magnitude pushed for attached instances and the engine listeners, in game units per second. 0 means no cap. See [Callbacks and 3D](callbacks-and-3d.md#doppler-and-velocity). |

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

`FmodRuntime.settings()` returns the fully resolved settings after init, and `null` before it.

`StudioSystem.getAdvancedSettings()` and `getStudioAdvancedSettings()` read the advanced settings FMOD is running with (unsupported in HTML5, where they return `null`).

The Live Update port is fixed at 9264 by FMOD. Enabling it triggers a firewall dialog on macOS and Windows the first time the game runs.

## Bank loading

`FmodRuntime.banks` is a `BankRegistry`, a refcounted loader keyed by normalized path. Several systems can ask for the same bank, and it is unloaded only when the last of them lets go. Bank file names without a directory resolve against `bankFolder` through `FmodRuntime.bankPath`.

```haxe
import haxefmod.runtime.FmodRuntime;

var path = FmodRuntime.bankPath("Vehicles.bank");
var bank = FmodRuntime.banks.load(path);
if (bank.isNull()) trace("Vehicles.bank failed to load");
// later, when the level ends
FmodRuntime.banks.unload(path);
```

`load` blocks on native and always runs asynchronously on HTML5, where a file exists in the browser's virtual filesystem only after a fetch wrote it. `loadAsync` starts a background load on every target and returns a handle that becomes usable once `loadingState(path)` reports `LOADED`. The other registry calls are `isLoaded`, `loadingState`, `refCount`, `get`, `anyLoading`, and `anyError`, and `unload` returns true when the bank was actually unloaded rather than just decremented.

```haxe
import haxefmod.runtime.FmodRuntime;

FmodRuntime.banks.loadAsync(FmodRuntime.bankPath("Vehicles.bank"));
// in update, once per frame
if (FmodRuntime.banks.isLoaded(FmodRuntime.bankPath("Vehicles.bank"))) {
    FmodManager.PlaySoundOneShot("event:/Vehicles/Horn");
}
```

A path that settles in `ERROR` is not deduplicated. Loading it again replaces the dead entry, so a failed fetch can be retried. A bank that was loaded outside the registry (for example through `StudioSystem.loadBankFile`) is adopted on the first registry load rather than reported as an error.

Two spellings of one file share one refcount, since `BankRegistry.normalizePath` collapses separators and `.` segments. Windows backslashes are accepted.

## Direct bank calls

The registry is a convenience over `StudioSystem` and `Bank`, which remain available.

- `StudioSystem.loadBankFile(path, ?flags)` loads a bank and returns its handle. `NONBLOCKING` starts an asynchronous load.
- `StudioSystem.loadBankMemory(bytes, ?flags)` loads a bank from bytes you fetched or embedded, with the same flags. The data is copied.
- `StudioSystem.getBank("bank:/Master")` looks a loaded bank up by its FMOD path, and `getBankList()` enumerates them.
- `Bank.getLoadingState()`, `loadSampleData()`, `unloadSampleData()`, `getSampleLoadingState()`, `getEventList()`, `getBusList()`, `getVCAList()`, and `unload()`.
- `StudioSystem.unloadAll()` unloads everything. The registry keeps its reference counts, so a later registry load carries them forward.

Sample data (the audio itself) loads lazily the first time an event plays unless you call `loadSampleData` on the bank or event description ahead of time. `StudioSystem.flushSampleLoading()` blocks until pending sample loads finish.

## Bank version rule

Bank files require an FMOD Engine at least as new as the FMOD Studio that built them. Rebuilding banks with a newer Studio raises the minimum engine version players' builds must bundle.
