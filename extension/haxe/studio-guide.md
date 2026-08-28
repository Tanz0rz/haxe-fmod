# studio-guide

## 13.9.1 Scripting Example
verdict: covered No context struct is needed. The core and studio systems are global (CoreSystem, StudioSystem) and the dialogue key is stored on the instance by EventInstance.assignProgrammerSound.

## 13.9.1 Scripting Example#2
verdict: bound
Native only (unsupported in HTML5).
The create and destroy programmer sound callbacks are implemented natively. Assigning a key to the instance replaces the user data and the callback registration.
```haxe
import haxefmod.studio.FmodResult;

var eventInstance = StudioSystem.getEvent("event:/Character/Dialogue").createInstance();
var result = eventInstance.assignProgrammerSound("welcome");
if (result != FmodResult.FMOD_OK) trace("assignProgrammerSound failed: " + result);
```

## 13.9.1 Scripting Example#3
verdict: bound
Native only (unsupported in HTML5).
The key is assigned to the instance before start instead of being written into the context.
```haxe
import haxefmod.studio.Bank;
import haxefmod.studio.Types.FmodLoadBankFlags;

// Available banks
// "Dialogue_EN.bank", "Dialogue_JP.bank", "Dialogue_CN.bank"
var localizedBank:Bank = StudioSystem.loadBankFile("assets/fmod/Desktop/Dialogue_JP.bank", FmodLoadBankFlags.NORMAL);
var eventInstance = StudioSystem.getEvent("event:/Character/Dialogue").createInstance();
eventInstance.assignProgrammerSound("welcome");
eventInstance.start();
```

## 13.9.1 Scripting Example#4
verdict: library The programmer sound callback runs on FMOD's thread and is implemented once natively for every instance that has a key assigned. EventInstance.setCallback delivers the CREATE_PROGRAMMER_SOUND and DESTROY_PROGRAMMER_SOUND types on the game thread as Other(type) for observation only.

## 13.9.1 Scripting Example#5
verdict: library The create callback body runs natively when the instrument triggers. It calls getSoundInfo with the assigned key, creates the sound with FMOD_LOOP_NORMAL and FMOD_CREATECOMPRESSEDSAMPLE plus the mode getSoundInfo reports, and fills the properties. The native side does not pass FMOD_NONBLOCKING, so the create is synchronous. A key that matches no audio table entry is opened as a plain file path with FMOD_DEFAULT. StudioSystem.getSoundInfo(key) shows the name and subsound index a key resolves to.

## 13.9.1 Scripting Example#6
verdict: library The destroy callback runs natively and releases the sound when the instrument ends. EventInstance.clearProgrammerSound drops the key assignment when an instance is reused for a different line.
