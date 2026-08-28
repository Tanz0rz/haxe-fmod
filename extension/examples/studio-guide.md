# studio-guide

## 0
<!-- 13.9.1 Scripting Example -->
No context struct is needed. The core and studio systems are global in haxefmod, and the programmer sound key is stored on the instance itself through EventInstance.assignProgrammerSound.

## 1
<!-- 13.9.1 Scripting Example -->
Instead of a callback and userdata, assign the key to the instance. The native side handles the create and destroy programmer sound callbacks on FMOD's thread, so nothing runs in Haxe during playback.
```haxe
var instance = StudioSystem.getEvent("event:/Character/Dialogue").createInstance();
var result = instance.assignProgrammerSound("welcome");
if (!result.isOk()) trace('programmer sounds unavailable: $result');
```

## 2
<!-- 13.9.1 Scripting Example -->
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

## 3
<!-- 13.9.1 Scripting Example -->
There is no programmer sound callback to write in Haxe. The native side implements it once for every instance that has a key assigned.

## 4
<!-- 13.9.1 Scripting Example -->
The create callback body (getSoundInfo, createSound, filling the properties) runs natively when the instrument triggers. The key is looked up in the loaded audio tables first, and a key that matches no entry is treated as a file path, so a loose file can be injected the same way.
```haxe
var instance = StudioSystem.getEvent("event:/Character/Dialogue").createInstance();
instance.assignProgrammerSound("assets/dialogue/welcome_extra.ogg");
instance.start();
```

## 5
<!-- 13.9.1 Scripting Example -->
The destroy callback runs natively and releases the sound when the instrument ends. Call EventInstance.clearProgrammerSound to drop the assignment if the instance is reused for a different line.
```haxe
instance.clearProgrammerSound();
instance.assignProgrammerSound("goodbye");
instance.start();
```
