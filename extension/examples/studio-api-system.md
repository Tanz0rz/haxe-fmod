# studio-api-system

## 0
<!-- FMOD_STUDIO_ADVANCEDSETTINGS -->
Init-time engine settings go through the FmodSettings structure passed to FmodManager.Initialize (channel count, sample rate, speaker mode, live update, logging, bank folder). The Studio advanced settings struct itself is not exposed, and the library owns initialization, so there is no way to set the command queue size, handle pool, or encryption key from Haxe.
```haxe
FmodManager.Initialize({numChannels: 256, sampleRate: 48000, liveUpdate: false});
```

## 1
<!-- FMOD_STUDIO_BANK_INFO -->
User file callbacks would run on FMOD's threads, which no Haxe target can do safely, so loadBankCustom is not exposed. Load banks with StudioSystem.loadBankFile(path) or StudioSystem.loadBankMemory(bytes).

## 2
<!-- FMOD_STUDIO_BUFFER_INFO -->
FmodBufferInfo has the same fields as currentUsage, peakUsage, capacity, stallCount, and stallTime.
```haxe
var usage = StudioSystem.getBufferUsage();
if (usage != null) {
    var queue = usage.studioCommandQueue;
    if (queue.stallCount > 0) {
        trace('command queue stalled ${queue.stallCount} times, peak ${queue.peakUsage} of ${queue.capacity}');
    }
}
```

## 3
<!-- FMOD_STUDIO_BUFFER_USAGE -->
StudioSystem.getBufferUsage returns FmodBufferUsage with studioCommandQueue and studioHandle, or null on failure. StudioSystem.resetBufferUsage clears the peaks and stall counts.
```haxe
var usage = StudioSystem.getBufferUsage();
if (usage != null) {
    trace('handles ${usage.studioHandle.currentUsage} of ${usage.studioHandle.capacity}');
}
StudioSystem.resetBufferUsage();
```

## 4
<!-- FMOD_STUDIO_COMMANDCAPTURE_FLAGS -->
StudioSystem.startCommandCapture(path) always captures with the normal flags. File flushing and skipping the initial state are not exposed.
```haxe
StudioSystem.startCommandCapture("capture.cmd.txt");
// later
StudioSystem.stopCommandCapture();
```

## 5
<!-- FMOD_STUDIO_COMMANDREPLAY_FLAGS -->
StudioSystem.loadCommandReplay(path) always loads with the normal flags. Skip cleanup, fast forward, and skip bank load are not exposed.
```haxe
var replay = StudioSystem.loadCommandReplay("capture.cmd.txt");
if (!replay.isNull()) {
    replay.start();
}
```

## 6
<!-- FMOD_STUDIO_CPU_USAGE -->
StudioSystem.getCpuUsage returns FmodSystemCpuUsage, which merges the Studio update time with the core breakdown (dsp, stream, geometry, update, convolution) in percent of one core.
```haxe
var cpu = StudioSystem.getCpuUsage();
if (cpu != null) {
    trace('studio ${cpu.studioUpdate}% dsp ${cpu.dsp}% stream ${cpu.stream}%');
}
```

## 7
<!-- FMOD_STUDIO_INITFLAGS -->
Live update is the one init flag a game chooses, through the liveUpdate field of FmodSettings. It defaults to on in debug builds and off otherwise. The other flags are fixed by the library.
```haxe
FmodManager.Initialize({liveUpdate: true});
```

## 8
<!-- FMOD_STUDIO_LOAD_BANK_FLAGS -->
FmodLoadBankFlags has NORMAL and NONBLOCKING. Decompress samples and unencrypted are not exposed. A nonblocking bank reports its progress through Bank.getLoadingState.
```haxe
var bank = StudioSystem.loadBankFile("assets/fmod/Desktop/Level1.bank", NONBLOCKING);
if (bank.isNull()) {
    trace('load failed: ${StudioSystem.lastResult()}');
}
```

## 9
<!-- FMOD_STUDIO_LOAD_MEMORY_ALIGNMENT -->
StudioSystem.loadBankMemory copies the bytes into memory FMOD owns, so alignment is handled for you and the Haxe buffer is free once the call returns.
```haxe
var bytes = sys.io.File.getBytes("assets/fmod/Desktop/Level1.bank");
var bank = StudioSystem.loadBankMemory(bytes);
```

## 10
<!-- FMOD_STUDIO_LOAD_MEMORY_MODE -->
StudioSystem.loadBankMemory always uses the copying mode. The point mode is not exposed because the binding cannot pin a Haxe buffer for the bank's lifetime.
```haxe
var bytes = haxe.Resource.getBytes("Level1.bank");
var bank = StudioSystem.loadBankMemory(bytes);
if (bank.isNull()) trace('load failed: ${StudioSystem.lastResult()}');
```

## 11
<!-- FMOD_STUDIO_LOAD_MEMORY_MODE -->
StudioSystem.loadBankMemory copies the bytes, which matches the memory mode of this example. The point mode is not exposed.

## 12
<!-- FMOD_STUDIO_SOUND_INFO -->
Audio table lookups happen natively. Pass the key to EventInstance.assignProgrammerSound before start(), and the native side calls getSoundInfo and creates the sound when the programmer instrument triggers. The key can also be a file path. Programmer sounds are native only (unsupported in HTML5), where the call returns FMOD_ERR_UNSUPPORTED.
```haxe
var instance = StudioSystem.getEvent("event:/Dialogue/Line").createInstance();
instance.assignProgrammerSound("welcome");
instance.start();
```

## 13
<!-- FMOD_STUDIO_SYSTEM_CALLBACK -->
StudioSystem.setSystemCallback takes one handler and delivers the events from FmodManager.Update() on the game thread: device list changed, device lost, bank unload with the bank's path, live update connected and disconnected, and pre and post update.
```haxe
StudioSystem.setSystemCallback(event -> switch (event) {
    case BankUnload(path): trace('unloaded $path');
    case LiveUpdateConnected: trace("live update connected");
    default:
});
```

## 14
<!-- FMOD_STUDIO_SYSTEM_CALLBACK_TYPE -->
No system callback is exposed, so there is no callback type enum. Do per-frame work right after FmodManager.Update in your game loop instead of in a pre or post update hook.
