# studio-guide

## 13.9.1 Scripting Example
verdict: covered No context struct is needed. The core and studio systems are global (CoreSystem, StudioSystem) and the dialogue key is stored on the instance by EventInstance.assignProgrammerSound.

## 13.9.1 Scripting Example#2
verdict: bound
Native only (unsupported in HTML5).
The create and destroy programmer sound callbacks are implemented natively. Assigning a key to the instance stands in for both the user data and the callback registration, the native side keeps the key itself.
EventInstance.setUserData and getUserData stay free for the game's own values, and setCallback still delivers ProgrammerSoundCreated(name) and ProgrammerSoundDestroyed(name).
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
verdict: library The programmer sound callback runs on FMOD's thread and is implemented once natively for every instance that has an assignment. EventInstance.setCallback delivers ProgrammerSoundCreated(name) and ProgrammerSoundDestroyed(name) on the game thread with the instrument's name, for observation and cleanup. An event with several programmer instruments assigns one key per instrument name with assignProgrammerSoundForName or assignProgrammerSounds.

## 13.9.1 Scripting Example#5
verdict: library The create callback body runs natively when the instrument triggers. It looks the instrument name up in the name map, falls back to the single key, calls getSoundInfo, creates the sound with FMOD_LOOP_NORMAL, FMOD_CREATECOMPRESSEDSAMPLE, and FMOD_NONBLOCKING plus the mode getSoundInfo reports, and fills the properties. A key that matches no audio table entry is opened as a plain file path. A sound assigned with assignProgrammerSoundFrom is handed over as is, with its subsound index. StudioSystem.getSoundInfo(key) shows the name and subsound index a key resolves to.

## 13.9.1 Scripting Example#6
verdict: library The destroy callback runs natively and releases the sound it created when the instrument ends. A sound assigned with assignProgrammerSoundFrom stays with the game. EventInstance.clearProgrammerSound drops every assignment when an instance is reused for a different line.
