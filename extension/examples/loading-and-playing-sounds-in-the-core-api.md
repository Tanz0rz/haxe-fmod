# loading-and-playing-sounds-in-the-core-api

## 0
<!-- 4.1.1 Non-blocking Sound Creation -->
CoreSound.create loads on the calling thread and returns a ready handle. There is no non-blocking flag, so load loose files at level start or from a loading screen instead of mid-frame.
```haxe
import haxefmod.studio.CoreSound;

var sound = CoreSound.create("assets/wave.mp3");
if (sound.isNull()) {
    trace('load failed: ${StudioSystem.lastResult()}');
}
```

## 1
<!-- 4.1.1 Non-blocking Sound Creation -->
Load callbacks are not exposed. CoreSound.create returns once the sound is ready, and getOpenState reports 0 for a usable sound.
```haxe
import haxefmod.studio.CoreSound;

var sound = CoreSound.create("assets/wave.mp3");
if (!sound.isNull() && sound.getOpenState() == 0) {
    trace("Sound loaded!");
}
```

## 2
<!-- 4.1.1 Non-blocking Sound Creation -->
There is no extended-info struct or load callback. CoreSound.create takes a path and an optional loop flag and returns a ready handle, or NULL with the reason in StudioSystem.lastResult.

## 3
<!-- 4.2 Playing a sound -->
```haxe
import haxefmod.studio.CoreSound;

var sound = CoreSound.create("assets/wave.mp3");
if (sound.isNull()) {
    trace('load failed: ${StudioSystem.lastResult()}');
}

var channel = sound.play();
if (channel.isNull()) {
    trace('play failed: ${StudioSystem.lastResult()}');
}
```

## 4
<!-- 4.3.1 Creating a Sound from memory -->
Encoded memory buffers cannot be opened. CoreSound.fromPcm takes raw 16-bit PCM instead, and the bytes are copied so the buffer is free once it returns.
```haxe
import haxefmod.studio.CoreSound;

var buffer:haxe.io.Bytes = null;

//
// Fill "buffer" with interleaved 16-bit PCM here
//

var sound = CoreSound.fromPcm(buffer, 44100, 2);
if (sound.isNull()) {
    trace('create failed: ${StudioSystem.lastResult()}');
}
```

## 5
<!-- 4.3.1 Creating a Sound from memory -->
There is no point-to-memory mode. CoreSound.fromPcm always copies the bytes, so nothing needs to stay pinned and the buffer is free after the call.

## 6
<!-- 4.3.2 Creating a Sound from PCM data -->
Raw PCM files open through CoreSound.fromPcm after the game reads the file itself. The format is fixed at signed 16-bit little endian, so only the sample rate and channel count are passed.
```haxe
import haxefmod.studio.CoreSound;

var raw = sys.io.File.getBytes("assets/Your/File/Path/Here.raw");
var sound = CoreSound.fromPcm(raw, 44100, 2);
if (sound.isNull()) {
    trace('create failed: ${StudioSystem.lastResult()}');
}
```

## 7
<!-- 4.3.3 Creating a Sound by manually providing sample data -->
PCM read callbacks and Sound::lock cannot be bound, the callbacks run on FMOD's threads and lock hands out a raw pointer. PcmStream is the user-sound equivalent, a ring buffer the game writes 16-bit PCM into from the game thread while the mixer drains it, and CoreSound.readData covers reading PCM back out of a sound.
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

## 8
<!-- 4.3.4 Creating the Sound as a Streamed FSB File -->
Subsound access is not exposed, so an FSB cannot be opened at a chosen subsound. Ship the sounds in an FMOD Studio bank and play them as events, or load each loose file with CoreSound.create.

## *
<!-- page default -->
Custom file systems and async IO callbacks are not exposed. User IO callbacks would run on FMOD threads, which no Haxe target can do safely, so file loading stays with FMOD through CoreSound.create, StudioSystem.loadBankFile, and StudioSystem.loadBankMemory.
