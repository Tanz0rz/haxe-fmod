# studio-guide

## 13.9.1 Scripting Example
verdict: bound
The core and studio systems are the static classes CoreSystem and StudioSystem in haxefmod, so the context carries them as the classes themselves next to the dialogue string. The string is what assignProgrammerSound stores on the instance in the next block.
```haxe
import haxefmod.core.CoreSystem;
import haxefmod.studio.StudioSystem;

class ProgrammerSoundContext {
    public var coreSystem:Class<CoreSystem>;
    public var system:Class<StudioSystem>;
    public var dialogueString:String;
    public function new() {}
}

var programmerSoundContext = new ProgrammerSoundContext();
programmerSoundContext.system = StudioSystem;
programmerSoundContext.coreSystem = CoreSystem;
```

## 13.9.1 Scripting Example#2
verdict: bound
Native only (unsupported in HTML5).
The create and destroy programmer sound callbacks are implemented natively. Assigning a key to the instance stands in for both the user data and the callback registration, the native side keeps the key itself.
EventInstance.setUserData and getUserData stay free for the game's own values, and setCallback still delivers ProgrammerSoundCreated(properties) and ProgrammerSoundDestroyed(properties) with the instrument name, the sound, and the subsound index.
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
verdict: library The programmer sound callback runs on FMOD's thread and is implemented once natively for every instance that has an assignment. EventInstance.setCallback delivers ProgrammerSoundCreated(properties) and ProgrammerSoundDestroyed(properties) on the game thread with the FmodProgrammerSoundProperties FMOD filled (instrument name, sound, subsound index), for observation and cleanup. An event with several programmer instruments assigns one key per instrument name with assignProgrammerSoundForName or assignProgrammerSounds.

## 13.9.1 Scripting Example#5
verdict: library The create callback body runs natively when the instrument triggers. It looks the instrument name up in the name map, falls back to the single key, calls getSoundInfo, creates the sound with FMOD_LOOP_NORMAL, FMOD_CREATECOMPRESSEDSAMPLE, and FMOD_NONBLOCKING plus the mode getSoundInfo reports, and fills the properties. A key that matches no audio table entry is opened as a plain file path. A sound assigned with assignProgrammerSoundFrom is handed over as is, with its subsound index. StudioSystem.getSoundInfo(key) shows the name and subsound index a key resolves to.

## 13.9.1 Scripting Example#6
verdict: library The destroy callback runs natively and releases the sound it created when the instrument ends. A sound assigned with assignProgrammerSoundFrom stays with the game. EventInstance.clearProgrammerSound drops every assignment when an instance is reused for a different line.
