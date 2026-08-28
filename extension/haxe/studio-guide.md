# studio-guide

## 13.9.1 Scripting Example
verdict: review note only, decide bound or a category
No Haxe equivalent. The core and studio systems are global in haxefmod, and the programmer sound key is stored on the instance through EventInstance.assignProgrammerSound.

## 13.9.1 Scripting Example#2
verdict: bound
Instead of a callback and userdata, assign the key to the instance. The native side handles the create and destroy programmer sound callbacks on FMOD's thread, so nothing runs in Haxe during playback.
```haxe
var instance = StudioSystem.getEvent("event:/Character/Dialogue").createInstance();
var result = instance.assignProgrammerSound("welcome");
if (!result.isOk()) trace('programmer sounds unavailable: $result');
```

## 13.9.1 Scripting Example#3
verdict: bound
Load the localized bank, assign the key, and start. The bank loaded decides which audio file the key resolves to.
```haxe
// Available banks
// "Dialogue_EN.bank", "Dialogue_JP.bank", "Dialogue_CN.bank"
var localizedBank = StudioSystem.loadBankFile("assets/fmod/Desktop/Dialogue_JP.bank");
if (localizedBank.isNull()) trace('bank failed: ${StudioSystem.lastResult()}');

var instance = StudioSystem.getEvent("event:/Character/Dialogue").createInstance();
instance.assignProgrammerSound("welcome");
instance.start();
```

## 13.9.1 Scripting Example#4
verdict: review note only, decide bound or a category
There is no programmer sound callback to write in Haxe. The native side implements it once for every instance that has a key assigned.

## 13.9.1 Scripting Example#5
verdict: bound
The create callback body (getSoundInfo, createSound, filling the properties) runs natively when the instrument triggers. StudioSystem.getSoundInfo shows what a key resolves to. The key is looked up in the loaded audio tables first, and a key that matches no entry is treated as a file path, so a loose file can be injected the same way.
```haxe
var key = "welcome";
var info = StudioSystem.getSoundInfo(key);
if (info != null) {
    trace("key " + key + " plays " + info.name + " subsound " + info.subSoundIndex);
}
var instance = StudioSystem.getEvent("event:/Character/Dialogue").createInstance();
instance.assignProgrammerSound(key);
instance.start();
```

## 13.9.1 Scripting Example#6
verdict: bound
The destroy callback runs natively and releases the sound when the instrument ends. Call EventInstance.clearProgrammerSound to drop the assignment if the instance is reused for a different line.
```haxe
instance.clearProgrammerSound();
instance.assignProgrammerSound("goodbye");
instance.start();
```
