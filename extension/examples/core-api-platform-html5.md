# core-api-platform-html5

## 1
<!-- Example usage. -->
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

## 3
<!-- Example usage. -->
Data already in memory goes in as haxe.io.Bytes. The binding copies it into FMOD's heap, so there is no pointer to free.
```haxe
var bankBytes = haxe.io.Bytes.alloc(0);
var bank = StudioSystem.loadBankMemory(bankBytes);
if (bank.isNull()) {
    trace("bank load failed: " + StudioSystem.lastResult());
}
```

## 10
<!-- Example usage. -->
Direct reads and writes of FMOD's memory only matter inside a custom DSP callback, and Haxe code cannot run on FMOD's mixer thread. Use the built-in DSP types through Dsp.create instead.

## 12
<!-- Example usage. -->
Direct reads and writes of FMOD's memory only matter inside a custom DSP callback, and Haxe code cannot run on FMOD's mixer thread. Use the built-in DSP types through Dsp.create instead.

## *
<!-- page default -->
The library's post-build step copies fmodstudio.js and fmodstudio.wasm from FMOD_SDK_WEB next to the output and loads the module for you, so the HTML5 module and filesystem helpers on this page are handled by the binding and have no Haxe equivalent.
