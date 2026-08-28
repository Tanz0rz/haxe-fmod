# core-api-platform-html5

## Example usage.
verdict: bound
Bank files are fetched into the browser's virtual filesystem for you. Name them in the init settings, or load one later by path.
```haxe
FmodManager.Initialize({
    bankFolder: "assets/fmod/Desktop",
    autoLoadBanks: ["Master.bank", "Master.strings.bank"]
});

var bank = StudioSystem.loadBankFile("SFX.bank");
if (bank.isNull()) {
    trace("bank load failed: " + StudioSystem.lastResult());
}
```

## Example usage.#2
verdict: bound
Data already in memory goes in as haxe.io.Bytes. The binding copies it into FMOD's heap, so there is no pointer to free.
```haxe
var bankBytes = haxe.io.Bytes.alloc(0);
var bank = StudioSystem.loadBankMemory(bankBytes);
if (bank.isNull()) {
    trace("bank load failed: " + StudioSystem.lastResult());
}
```

## Example usage.#3
verdict: review note only, decide bound or a category
Direct reads and writes of FMOD's memory only matter inside a custom DSP callback, and Haxe code cannot run on FMOD's mixer thread. Use the built-in DSP types through Dsp.create instead.

## Example usage.#4
verdict: review note only, decide bound or a category
Direct reads and writes of FMOD's memory only matter inside a custom DSP callback, and Haxe code cannot run on FMOD's mixer thread. Use the built-in DSP types through Dsp.create instead.
