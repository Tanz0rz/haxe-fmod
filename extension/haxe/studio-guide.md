# studio-guide

## 13.9.1 Scripting Example
verdict: bound
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
```haxe
// The library owns the programmer-sound callback and its user data.
var result = eventInstance.assignProgrammerSound(key);
```

## 13.9.1 Scripting Example#3
verdict: bound
```haxe
import haxefmod.studio.Bank;
import haxefmod.studio.Types.FmodLoadBankFlags;

// Available banks
// "Dialogue_EN.bank", "Dialogue_JP.bank", "Dialogue_CN.bank"
var localizedBank:Bank = StudioSystem.loadBankFile("Dialogue_JP.bank", FmodLoadBankFlags.NORMAL);
eventInstance.assignProgrammerSound("welcome");
eventInstance.start();
```

## 13.9.1 Scripting Example#4
verdict: library The programmer sound callback runs on FMOD's thread and is implemented once natively for every instance that has an assignment. EventInstance.setCallback delivers ProgrammerSoundCreated(properties) and ProgrammerSoundDestroyed(properties) on the game thread with the FmodProgrammerSoundProperties FMOD filled (instrument name, sound, subsound index), for observation and cleanup. An event with several programmer instruments assigns one key per instrument name with assignProgrammerSoundForName or assignProgrammerSounds.

## 13.9.1 Scripting Example#5
verdict: library The create callback body runs natively when the instrument triggers. It looks the instrument name up in the name map, falls back to the single key, calls getSoundInfo, creates the sound with FMOD_LOOP_NORMAL, FMOD_CREATECOMPRESSEDSAMPLE, and FMOD_NONBLOCKING plus the mode getSoundInfo reports, and fills the properties. A key that matches no audio table entry is opened as a plain file path. A sound assigned with assignProgrammerSoundFrom is handed over as is, with its subsound index. StudioSystem.getSoundInfo(key) shows the name and subsound index a key resolves to.

## 13.9.1 Scripting Example#6
verdict: library The destroy callback runs natively and releases the sound it created when the instrument ends. A sound assigned with assignProgrammerSoundFrom stays with the game. EventInstance.clearProgrammerSound drops every assignment when an instance is reused for a different line.
