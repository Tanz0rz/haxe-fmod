# core-api-platform-html5

## Example usage.
verdict: library the library fetches bank files into the browser's virtual filesystem itself. The names in FmodSettings.autoLoadBanks are fetched during FmodManager.Initialize, and FmodRuntime.banks.loadAsync(path) fetches any other bank and loads it once loadingState(path) reports LOADED. StudioSystem.loadBankFile only sees files already placed there.

## Example usage.#2
verdict: bound
```haxe
import haxefmod.studio.Bank;
import haxefmod.studio.Types;

var bytes = haxe.io.Bytes.alloc(0); // the bank file fetched by the game
var bank:Bank = StudioSystem.loadBankMemory(bytes, FmodLoadBankFlags.NONBLOCKING);
```

## Example usage.#3
verdict: cannot this is the read callback of a custom DSP working on FMOD's mix buffers through raw heap addresses. haxefmod exposes no custom DSP callback on any target. Dsp.create(DspType) gives the built-in effects.

## Example usage.#4
verdict: cannot this is the read callback of a custom DSP working on FMOD's mix buffers through raw heap addresses. haxefmod exposes no custom DSP callback on any target. Dsp.create(DspType) gives the built-in effects.
