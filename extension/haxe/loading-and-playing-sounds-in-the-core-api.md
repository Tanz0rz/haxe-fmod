# loading-and-playing-sounds-in-the-core-api

## 4.1.1 Non-blocking Sound Creation
verdict: bound
Sound.create has no NONBLOCKING mode. It loads on the calling thread and returns a ready handle, so load loose files at level start or from a loading screen.
```haxe
import haxefmod.core.Sound;

var sound = Sound.create("../media/wave.mp3"); // Loads the file on the calling thread and returns once it is ready.
if (sound.isNull()) {
    trace('load failed: ${StudioSystem.lastResult()}');
}
```

## 4.1.1 Non-blocking Sound Creation#2
verdict: cannot FMOD calls the callback on its async loader thread, no Haxe target can run code there. Sound.create returns a ready handle, and Sound.getOpenState reports READY for a usable sound.

## 4.1.1 Non-blocking Sound Creation#3
verdict: cannot FMOD_CREATESOUNDEXINFO is not exposed and the callback runs on FMOD's async loader thread. Sound.create takes the path and a loop flag and returns a ready handle, or Sound.NULL with the reason in StudioSystem.lastResult.

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
Encoded files cannot be opened from memory. Sound.fromPcm takes raw 16-bit PCM and the sample rate and channel count stand in for the exinfo fields.
```haxe
import haxefmod.core.Sound;

var sound:Sound;
var buffer:haxe.io.Bytes = null;

//
// Load your interleaved 16-bit PCM data to the "buffer" bytes here
//

sound = Sound.fromPcm(buffer, 44100, 2); // The buffer's length is the length of the sound in bytes
// The audio data stored in "buffer" has been duplicated into FMOD's buffers, and can now be freed
```

## 4.3.1 Creating a Sound from memory#2
verdict: covered there is no point-to-memory mode. Sound.fromPcm always copies the bytes, so nothing stays pinned and the buffer is free after the call.

## 4.3.2 Creating a Sound from PCM data
verdict: bound
Raw PCM files are read by the game and passed to Sound.fromPcm. The format is fixed at signed 16-bit PCM, so only the channel count and playback rate are passed.
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
PCM read callbacks run on FMOD's threads and Sound::lock hands out a raw pointer, so neither is exposed. PcmStream plays the user sound role. The game writes 16-bit PCM into its ring buffer while the mixer drains it.
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
Sound.create has no NONBLOCKING mode and no initial subsound field. The FSB loads on the calling thread and getSubSound picks the subsound to play.
```haxe
import haxefmod.core.Sound;

var sound:Sound;

sound = Sound.create("../media/sounds.fsb");
if (sound.isNull()) {
    trace('load failed: ${StudioSystem.lastResult()}');
}

var subsound = sound.getSubSound(1);
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
