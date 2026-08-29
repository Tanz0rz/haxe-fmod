# loading-and-playing-sounds-in-the-core-api

## 4.1.1 Non-blocking Sound Creation
verdict: bound
```haxe
import haxefmod.core.ChannelMode;
import haxefmod.core.Sound;

var sound = Sound.create("../media/wave.mp3", false, false, ChannelMode.CREATESTREAM | ChannelMode.NONBLOCKING); // Returns at once, the stream opens on FMOD's thread.
if (sound.isNull()) {
    trace('load failed: ${StudioSystem.lastResult()}');
}
```

## 4.1.1 Non-blocking Sound Creation#2
verdict: cannot FMOD calls the callback on its async loader thread, no Haxe target can run code there. Poll Sound.getOpenState each frame instead, it reports READY once the sound can play and ERROR when the load failed.

## 4.1.1 Non-blocking Sound Creation#3
verdict: bound
```haxe
import haxefmod.core.ChannelMode;
import haxefmod.core.Sound;
import haxefmod.studio.Types.FmodOpenState;

var sound = Sound.create("../media/wave.mp3", false, false, ChannelMode.CREATESTREAM | ChannelMode.NONBLOCKING);
if (sound.isNull()) {
    trace('load failed: ${StudioSystem.lastResult()}');
}

// Each frame until it is ready
if (sound.getOpenState() == FmodOpenState.READY) {
    trace("Sound loaded!");
}
```

## 4.2 Playing a sound
verdict: bound
```haxe
import haxefmod.core.Sound;
import haxefmod.core.Channel;

var sound:Sound;
var channel:Channel;

sound = Sound.create("../media/wave.mp3");
if (sound.isNull()) {
    trace('load failed: ${StudioSystem.lastResult()}');
}

channel = sound.play();
if (channel.isNull()) {
    trace('play failed: ${StudioSystem.lastResult()}');
}
```

## 4.3.1 Creating a Sound from memory
verdict: bound
```haxe
import haxefmod.core.Sound;

var sound:Sound;
var buffer:haxe.io.Bytes = null;

//
// Load your file image (wav, ogg, mp3, fsb) into the "buffer" bytes here
//

sound = Sound.fromMemory(buffer); // The buffer's length is the length of the file image in bytes
// The audio data stored in "buffer" has been duplicated into FMOD's buffers, and can now be freed
```

## 4.3.1 Creating a Sound from memory#2
verdict: covered there is no point-to-memory mode. Sound.fromMemory and Sound.fromPcm always copy the bytes, so nothing stays pinned and the buffer is free after the call.

## 4.3.2 Creating a Sound from PCM data
verdict: bound
```haxe
import haxefmod.core.Sound;

var sound:Sound;
var raw = sys.io.File.getBytes("./Your/File/Path/Here.raw");

sound = Sound.fromPcm(raw,
    44100,   // Playback rate of sound
    2);      // Number of channels in the sound
```

## 4.3.3 Creating a Sound by manually providing sample data
verdict: bound
```haxe
import haxefmod.core.PcmStream;

var stream = PcmStream.create(
    44100,                   // Playback rate of sound
    2,                       // Number of channels in the sound
    44100 * 2 * 2 * 5);      // Ring size in bytes. 2 = bytes per sample and 5 = seconds
var channel = stream.play();

// Each frame, write sample data instead of a read callback
var buffer = haxe.io.Bytes.alloc(stream.space());
for (i in 0...Std.int(buffer.length / 2)) {
    buffer.setUInt16(i * 2, nextSample() & 0xFFFF);
}
stream.write(buffer);
```

## 4.3.4 Creating the Sound as a Streamed FSB File
verdict: bound
```haxe
import haxefmod.core.ChannelMode;
import haxefmod.core.Sound;

var sound:Sound;

sound = Sound.create("../media/sounds.fsb", false, false, ChannelMode.CREATESTREAM | ChannelMode.NONBLOCKING, 1);
if (sound.isNull()) {
    trace('load failed: ${StudioSystem.lastResult()}');
}
```

## 4.5.1 Setup : Override FMOD's file system with callbacks
verdict: cannot file callbacks run on FMOD's file threads, no Haxe target can run code there. Sound.create and StudioSystem.loadBankFile read the platform file system and StudioSystem.loadBankMemory takes bytes the game loaded itself.

## 4.5.1 Setup : Override FMOD's file system with callbacks#2
verdict: cannot async file callbacks run on FMOD's file threads, no Haxe target can run code there. Sound.create and StudioSystem.loadBankFile read the platform file system and StudioSystem.loadBankMemory takes bytes the game loaded itself.

## 4.5.2 Defining the basics - opening and closing the file handle.
verdict: cannot file callbacks run on FMOD's file threads, no Haxe target can run code there. Sound.create and StudioSystem.loadBankFile read the platform file system and StudioSystem.loadBankMemory takes bytes the game loaded itself.

## 4.5.3 Defining 'userasyncread'
verdict: cannot async file callbacks run on FMOD's file threads, no Haxe target can run code there. Sound.create and StudioSystem.loadBankFile read the platform file system and StudioSystem.loadBankMemory takes bytes the game loaded itself.

## 4.5.4 Defining 'userasynccancel'
verdict: cannot async file callbacks run on FMOD's file threads, no Haxe target can run code there. Sound.create and StudioSystem.loadBankFile read the platform file system and StudioSystem.loadBankMemory takes bytes the game loaded itself.

## 4.5.5 Filling out the FMOD_ASYNCREADINFO structure when performing a deferred read
verdict: cannot the payload of an async read callback, which runs on FMOD's file threads and carries raw buffer pointers. Custom file systems are not exposed.
