# Core API helpers

`haxefmod.core` binds the FMOD Core API with the same handle conventions as the studio layer (see [Handles and results](handles-and-results.md)). Every method keeps its FMOD name, so the [FMOD Core API reference](https://www.fmod.com/docs/2.03/api/core-api.html) with its Haxe tab describes each one. This page covers only what the library adds: where FMOD's objects live, the sound factories, and `PcmStream`.

## Where FMOD's objects live

| FMOD | haxefmod |
|---|---|
| `Studio::System` | `haxefmod.studio.StudioSystem`, all static. It also fronts the core `System` calls a Studio game reaches for: plugins, recording, profiling, listeners, the DSP lock, and `lastResult()`. |
| `System` | `haxefmod.core.CoreSystem`, all static, for the mixer, driver, speaker, network, and 3D settings calls. Everything FMOD only accepts before initialization is a [setting](banks-and-settings.md#settings) instead. |
| `System::getMasterChannelGroup`, `getMasterSoundGroup` | `ChannelGroup.master()`, `SoundGroup.master()` |
| `System::createChannelGroup`, `createSoundGroup`, `createDSPByType`, `createDSPByPlugin`, `createGeometry`, `createReverb3D` | `ChannelGroup.create`, `SoundGroup.create`, `Dsp.create`, `Dsp.createByPlugin`, `Geometry.create`, `Reverb3D.create` |
| `System::setReverbProperties`, `getReverbProperties` | `Reverb.set`, `Reverb.get`, and `Reverb.off`, with the `FMOD_PRESET_*` environments as `Reverb.PRESET_*` |
| `ChannelControl` | No class of its own. Its methods appear on both `Channel` and `ChannelGroup`. |
| `System::createSound`, `playSound`, `playDSP` | The factories below, and `play(?startPaused, ?group)` on `Sound`, `PcmStream`, and `Dsp`. |

## Sound factories

FMOD creates every sound through `System::createSound` with a mode and an exinfo struct. haxefmod splits that into factories on `Sound`, each returning `Sound.NULL` on failure with the reason in `StudioSystem.lastResult()`.

- `Sound.create(path, ?loop, ?openOnly, ?mode, ?initialSubsound, ?exinfo)` loads a file. `loop` and `openOnly` set the matching mode bits, `mode` takes any further `ChannelMode` flags, `initialSubsound` picks the subsound an FSB stream starts on, and `exinfo` is an `FmodCreateSoundExInfo` for the rest of `FMOD_CREATESOUNDEXINFO`. A sound opened with `openOnly` exists to be read and cannot be played.
- `Sound.fromMemory(bytes, ?mode, ?length, ?exinfo)` takes an encoded file image the game already holds. FMOD copies the bytes, so the buffer can go once the call returns.
- `Sound.fromPcm(bytes, sampleRate, channels, ?length)` makes a sample from 16-bit signed PCM, interleaved when stereo.
- `Sound.createRecordBuffer(sampleRate, channels, seconds)` makes an empty 16-bit PCM sound of that length for `StudioSystem.recordStart` to fill.

```haxe
import haxefmod.core.ChannelMode;
import haxefmod.core.Sound;

var music = Sound.create("assets/music/level1.ogg", true, false, ChannelMode.CREATESTREAM | ChannelMode.MODE_3D);
var pending = Sound.create("assets/voice/line01.ogg", false, false, ChannelMode.NONBLOCKING);
// Later, once pending.getOpenState() == FmodOpenState.READY
var channel = pending.play();
```

On HTML5 only FSB images decode, see [Limitations](../limitations.md#html5). `fromPcm` and `PcmStream` work everywhere because they take raw PCM.

### Sample data

`readData(buffer, ?length)` decodes PCM from a sound opened with `openOnly` into the buffer. It returns the bytes read, `0` at the end of the file with `StudioSystem.lastResult()` reporting `FMOD_ERR_FILE_EOF`, or a negated FMOD error code. `lock(offset, length)` returns a copy of a sample sound's byte range as `haxe.io.Bytes`, and `unlock(data)` writes the edited copy back and closes the lock. One lock is open at a time per sound, and releasing a sound with a lock open unlocks it first.

## PcmStream

`PcmStream` plays audio the game produces frame by frame: procedural synths, a tracker, a network voice stream. `create(sampleRate, channels, ?ringBytes)` makes an FMOD user sound backed by a ring buffer, `write` queues 16-bit signed PCM bytes (interleaved when stereo), and FMOD's mixer drains them as the sound plays. `setReadCallback` turns that around: the `PcmReadCallback` runs from `FmodManager.Update` whenever the ring has room, fills the buffer it is handed, and returns `FMOD_OK` to have it written.

```haxe
import haxefmod.core.PcmStream;

var stream = PcmStream.create(48000, 1);
var channel = stream.play();

// each frame, keep the ring topped up
var buffer = haxe.io.Bytes.alloc(stream.space());
for (i in 0...Std.int(buffer.length / 2)) {
    buffer.setUInt16(i * 2, nextSample() & 0xFFFF);
}
stream.write(buffer);

if (stream.takeUnderruns() > 0) trace("ring ran dry");
```

`write` returns how many bytes were accepted. When the ring is full the rest are dropped, so hold on to anything unaccepted and resend it once `space()` opens up. The default ring holds half a second. A bigger ring rides out frame spikes, a smaller one lets generated audio react faster. `takeUnderruns()` reports how many times the mixer needed audio and found the ring empty, clearing the count. `create3d` makes a positional stream whose channel takes `set3DAttributes` and attenuates with distance from the Studio listener. `release()` stops playback and frees the stream.
