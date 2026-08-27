# Limitations

What haxefmod does not do, and why. The library keeps one API surface that behaves the same on every target, so a feature that cannot work on one platform is generally left out everywhere and listed here instead of failing quietly on the platform that lacks it. The behavioral contracts described here are pinned by the test suite.

## Platform support

| Platform | Supported | Notes |
|---|---|---|
| Windows | x86_64 | |
| Linux | x86_64 | FMOD publishes no ARM64 Linux SDK |
| macOS | Apple Silicon (arm64) | Intel Macs are not supported |
| HTML5 | WebAssembly | See the HTML5 section below |
| Mobile and consoles | No | Desktop and web only |

## HTML5

The web build runs on FMOD's Emscripten runtime, which has real differences from the native engine.

- **Initialization is asynchronous.** The wasm module and the default banks load in the background. `FmodManager.IsInitialized()` reports true once both are usable, and games gate their first scene on it. Native targets initialize synchronously, so the same polling code works everywhere.
- **Programmer sounds are unsupported.** `assignProgrammerSound` returns `FMOD_ERR_UNSUPPORTED` on HTML5. This is a defect in FMOD's JS runtime: handing the sound created in the create callback back to FMOD stops the event without playing it and permanently ends callback delivery for that instance. It reproduces with FMOD's own example pattern and no haxefmod code involved. The standalone repro is `tests/js/fmod_ps_glue_repro.html`. Until FMOD fixes it, author dialogue and other swappable audio as ordinary events on HTML5. Related FMOD behavior worth knowing: an async programmer instrument that never receives a sound holds its event open forever in the browser, so shipping an event with a programmer instrument to HTML5 is not useful even without haxefmod in the picture.
- **FSB-only codecs.** The web build cannot decode loose files or encoded memory buffers. `CoreSound.create` on a .wav/.ogg/.mp3 path returns `FMOD_ERR_FORMAT`. Bank content plays normally because banks carry FSB data. `CoreSound.fromPcm` and `PcmStream` work everywhere because they take raw PCM.
- **The Destroyed callback never arrives.** FMOD's JS glue corrupts the wasm module if an instance is destroyed while a callback is installed, so the binding uninstalls callbacks before any destruction path and `Destroyed` cannot be delivered. Handler cleanup happens in `release()` on every target, so code that cleans up there behaves identically everywhere.
- **Firefox never delivers nested timeline beats.** FMOD's JS runtime does not invoke the `NestedTimelineBeat` callback on Firefox, so beats from a referenced event's timeline reach the parent instance only on Chromium-based browsers. The parent still receives the referenced timeline's markers in both. Firefox also fires an extra empty duplicate callback (blank name, position -1) alongside each real marker. Both behaviors reproduce in the Firefox CI job with no library code in the delivery path.
- **Numeric user properties are unreadable.** Reading an INTEGER, BOOLEAN, or FLOAT typed user property crashes FMOD's JS runtime (the repro is `tests/js/fmod_userprop_glue_repro.html`), so the binding reports `FMOD_ERR_UNSUPPORTED` for them on HTML5. String properties read correctly, and FMOD Studio builds every property value it cannot parse as a number as a string anyway.
- **Microphone recording reports zero drivers** until the browser's permission prompt is granted, and the recording API is not exposed (see the next section).

## FMOD features not exposed on any target

These FMOD features exist in the native engine but are not part of the haxefmod surface, either because the web build cannot support them or because they conflict with how the binding keeps every target stable. In the future, features that are supported by native builds, but not HTML5, will be fully implemented.

- **Geometry-based occlusion** (the Geometry API). The web build reports it unsupported. The standard alternative works everywhere: a game-side raycast drives an event parameter that the sound designer hooks to a filter in FMOD Studio. Manual occlusion values are bound per channel and per group through `set3DOcclusion`.
- **Microphone recording.** Browser permission flows make behavior environment-dependent and untestable in CI.
- **DSP parameter metadata** (`getParameterInfo`). The web build has no binding for the description struct. Parameter values themselves round-trip by index on every target.
- **Custom DSP callbacks and third-party plugins.** Haxe code cannot run on FMOD's mixer thread on any target, and the web build removed the plugin-host DSP types entirely. All 33 built-in DSP types are bound.
- **Loudness meter readback** (LUFS histograms). The web build returns zeroes from a working meter, so the values cannot be trusted cross-platform. FFT spectrum readback and DSP metering are bound and work everywhere.
- **Custom 3D rolloff curves** (`set3DCustomRolloff`). The web boundary rejects the point-array argument, and FMOD requires the array to stay allocated for the object's lifetime, which a marshaled copy cannot guarantee. The built-in rolloff modes are bound.
- **Sound sample readback** (`readData`, `lock`). Unsupported on the web build. Games that need waveform data keep their own copy of the PCM they feed through `PcmStream` or `CoreSound.fromPcm`.
- **Tracker music channel control** (MOD/S3M/XM per-channel access).
- **Speaker geometry and console port APIs.**
- **userdata on FMOD objects.** The binding's handle table carries object identity, which is what userdata exists for. Typed handles and payload callbacks replace it.
- **Custom file systems and `loadBankCustom`.** User IO callbacks would run on FMOD threads, which no Haxe target can do safely. `loadBankFile` and `loadBankMemory` are the supported paths.
- **System lifecycle calls.** The library owns init and the per-frame update. There is no shutdown or re-init. FMOD initializes once per process and lives until the process exits, and every use-after-shutdown bug goes away with the capability. Init-time engine settings are exposed through `FmodSettings` and compile-time defines.
- **System diagnostic callbacks and CommandReplay tool hooks.** These are FMOD-tooling integration points. Command capture and basic replay playback are bound.
- **Tag and subsound payload access.** Counts are bound. Payloads are container internals with no cross-platform story.

## Fixed behaviors and caps

- **List getters return at most 1024 entries** (banks, events, buses, VCAs, instances, and the other enumerations). A larger result logs a truncation warning with the real total.
- **Programmer sound keys must be under 512 UTF-8 bytes.** Longer keys are rejected with `FMOD_ERR_INVALID_PARAM` on every target.
- **Live Update uses TCP port 9264 and the port is fixed** (the FMOD API has no way to change it). Enabling it triggers a firewall dialog on macOS and Windows. It defaults to on in debug builds only.
- **Numeric arguments pass through to FMOD for validation.** An out-of-range index or count comes back as an FMOD error code from the engine, the same code native FMOD would report.
- **Generated constants drop non-ASCII characters.** An event name with no ASCII characters at all mangles to `Root`, `Root2`, and so on.
- **Bank files require an FMOD runtime at least as new as the FMOD Studio version that built them.** This is FMOD's own format rule. A project that rebuilds its banks with a newer Studio raises the minimum FMOD engine version its players' builds must bundle.

## Known FMOD engine defects

These are defects in FMOD itself, kept here with standalone repros so they can be re-tested against new SDK releases.

- **HTML5 programmer-sound flow** (described above). Repro: `tests/js/fmod_ps_glue_repro.html`, verified against SDK 2.03.12.
- **HTML5 numeric user property crash** (described above). Repro: `tests/js/fmod_userprop_glue_repro.html`, verified against SDK 2.03.12.
- **Firefox nested-beat and duplicate-marker delivery** (described above). Reproduced by the linux-html5-firefox CI job against SDK 2.03.12 with Playwright Firefox.
- **Linux stream and reverb zone churn crash.** High-frequency `Reverb3D` create/release while PCM streams churn segfaults inside the FMOD engine on Linux. Normal gameplay patterns do not hit it. Repro: `tests/native/fmod_churn_crash_repro.c`, verified against SDK 2.03.12.
