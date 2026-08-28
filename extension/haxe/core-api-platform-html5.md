# core-api-platform-html5

## Example usage.
verdict: library the library fetches bank files into the browser's virtual filesystem itself. The names in FmodSettings.autoLoadBanks are fetched during FmodManager.Initialize, and FmodRuntime.banks.loadAsync(path) fetches any other bank and loads it once loadingState(path) reports LOADED. StudioSystem.loadBankFile only sees files already placed there.

## Example usage.#2
verdict: covered StudioSystem.loadBankMemory(bytes) plays this role. It takes haxe.io.Bytes the game fetched itself and copies them into FMOD's heap, so there is no file read through FMOD and no pointer to free.

## Example usage.#3
verdict: cannot this is the read callback of a custom DSP working on FMOD's mix buffers through raw heap addresses. haxefmod exposes no custom DSP callback on any target. Dsp.create(DspType) gives the built-in effects.

## Example usage.#4
verdict: cannot this is the read callback of a custom DSP working on FMOD's mix buffers through raw heap addresses. haxefmod exposes no custom DSP callback on any target. Dsp.create(DspType) gives the built-in effects.
