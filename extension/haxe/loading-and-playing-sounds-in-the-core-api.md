# loading-and-playing-sounds-in-the-core-api

## 4.1.1 Non-blocking Sound Creation
verdict: bound
Sound.create loads on the calling thread and returns a ready handle. There is no non-blocking flag, so load loose files at level start or from a loading screen instead of mid-frame.
```haxe
import haxefmod.core.Sound;

var sound = Sound.create("assets/wave.mp3");
if (sound.isNull()) {
    trace('load failed: ${StudioSystem.lastResult()}');
}
```

## 4.1.1 Non-blocking Sound Creation#2
verdict: bound
Load callbacks are not exposed. Sound.create returns once the sound is ready, and getOpenState reports 0 for a usable sound.
```haxe
import haxefmod.core.Sound;

var sound = Sound.create("assets/wave.mp3");
if (!sound.isNull() && sound.getOpenState() == 0) {
    trace("Sound loaded!");
}
```

## 4.1.1 Non-blocking Sound Creation#3
verdict: review note only, decide bound or a category
There is no extended-info struct or load callback. Sound.create takes a path and an optional loop flag and returns a ready handle, or NULL with the reason in StudioSystem.lastResult.

## 4.2 Playing a sound
verdict: bound
```haxe
import haxefmod.core.Sound;

var sound = Sound.create("assets/wave.mp3");
if (sound.isNull()) {
    trace('load failed: ${StudioSystem.lastResult()}');
}

var channel = sound.play();
if (channel.isNull()) {
    trace('play failed: ${StudioSystem.lastResult()}');
}
```

## 4.3.1 Creating a Sound from memory
verdict: bound
Encoded memory buffers cannot be opened. Sound.fromPcm takes raw 16-bit PCM instead, and the bytes are copied so the buffer is free once it returns.
```haxe
import haxefmod.core.Sound;

var buffer:haxe.io.Bytes = null;

//
// Fill "buffer" with interleaved 16-bit PCM here
//

var sound = Sound.fromPcm(buffer, 44100, 2);
if (sound.isNull()) {
    trace('create failed: ${StudioSystem.lastResult()}');
}
```

## 4.3.1 Creating a Sound from memory#2
verdict: review note only, decide bound or a category
There is no point-to-memory mode. Sound.fromPcm always copies the bytes, so nothing needs to stay pinned and the buffer is free after the call.

## 4.3.2 Creating a Sound from PCM data
verdict: bound
Raw PCM files open through Sound.fromPcm after the game reads the file itself. The format is fixed at signed 16-bit little endian, so only the sample rate and channel count are passed.
```haxe
import haxefmod.core.Sound;

var raw = sys.io.File.getBytes("assets/Your/File/Path/Here.raw");
var sound = Sound.fromPcm(raw, 44100, 2);
if (sound.isNull()) {
    trace('create failed: ${StudioSystem.lastResult()}');
}
```

## 4.3.3 Creating a Sound by manually providing sample data
verdict: bound
PCM read callbacks and Sound::lock cannot be bound, the callbacks run on FMOD's threads and lock hands out a raw pointer. PcmStream is the user-sound equivalent, a ring buffer the game writes 16-bit PCM into from the game thread while the mixer drains it, and Sound.readData covers reading PCM back out of a sound.
```haxe
import haxefmod.core.PcmStream;

var stream = PcmStream.create(44100, 2);
var channel = stream.play();

// each frame, keep the ring topped up
var buffer = haxe.io.Bytes.alloc(stream.space());
for (i in 0...Std.int(buffer.length / 2)) {
    buffer.setUInt16(i * 2, nextSample() & 0xFFFF);
}
stream.write(buffer);
```

## 4.3.4 Creating the Sound as a Streamed FSB File
verdict: review note only, decide bound or a category
Subsound access is not exposed, so an FSB cannot be opened at a chosen subsound. Ship the sounds in an FMOD Studio bank and play them as events, or load each loose file with Sound.create.

## 4.5.1 Setup : Override FMOD's file system with callbacks
verdict: review note only, decide bound or a category
Custom file systems and async IO callbacks are not exposed. User IO callbacks would run on FMOD threads, which no Haxe target can do safely, so file loading stays with FMOD through Sound.create, StudioSystem.loadBankFile, and StudioSystem.loadBankMemory.

## 4.5.1 Setup : Override FMOD's file system with callbacks#2
verdict: review note only, decide bound or a category
Custom file systems and async IO callbacks are not exposed. User IO callbacks would run on FMOD threads, which no Haxe target can do safely, so file loading stays with FMOD through Sound.create, StudioSystem.loadBankFile, and StudioSystem.loadBankMemory.

## 4.5.2 Defining the basics - opening and closing the file handle.
verdict: review note only, decide bound or a category
Custom file systems and async IO callbacks are not exposed. User IO callbacks would run on FMOD threads, which no Haxe target can do safely, so file loading stays with FMOD through Sound.create, StudioSystem.loadBankFile, and StudioSystem.loadBankMemory.

## 4.5.3 Defining 'userasyncread'
verdict: review note only, decide bound or a category
Custom file systems and async IO callbacks are not exposed. User IO callbacks would run on FMOD threads, which no Haxe target can do safely, so file loading stays with FMOD through Sound.create, StudioSystem.loadBankFile, and StudioSystem.loadBankMemory.

## 4.5.4 Defining 'userasynccancel'
verdict: review note only, decide bound or a category
Custom file systems and async IO callbacks are not exposed. User IO callbacks would run on FMOD threads, which no Haxe target can do safely, so file loading stays with FMOD through Sound.create, StudioSystem.loadBankFile, and StudioSystem.loadBankMemory.

## 4.5.5 Filling out the FMOD_ASYNCREADINFO structure when performing a deferred read
verdict: review note only, decide bound or a category
Custom file systems and async IO callbacks are not exposed. User IO callbacks would run on FMOD threads, which no Haxe target can do safely, so file loading stays with FMOD through Sound.create, StudioSystem.loadBankFile, and StudioSystem.loadBankMemory.
