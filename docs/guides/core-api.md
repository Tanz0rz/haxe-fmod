# Core API helpers

`haxefmod.core` binds the FMOD Core API with the handle conventions of [Handles and results](handles-and-results.md). Every method keeps its FMOD name. The [FMOD Core API reference](https://www.fmod.com/docs/2.03/api/core-api.html) with its Haxe tab describes each method.

## Where FMOD's objects live

| FMOD | haxefmod |
|---|---|
| `Studio::System` | `haxefmod.studio.StudioSystem`, all static. It also holds the core `System` calls a Studio game uses: plugins, recording, profiling, listeners, the DSP lock, and `lastResult()`. |
| `System` | `haxefmod.core.CoreSystem`, all static. It holds the mixer, driver, speaker, network, and 3D settings calls. Every value FMOD accepts only before initialization is a [setting](banks-and-settings.md#settings). |
| `System::getMasterChannelGroup`, `getMasterSoundGroup` | `ChannelGroup.master()`, `SoundGroup.master()` |
| `System::createChannelGroup`, `createSoundGroup`, `createDSPByType`, `createDSPByPlugin`, `createGeometry`, `createReverb3D` | `ChannelGroup.create`, `SoundGroup.create`, `Dsp.create`, `Dsp.createByPlugin`, `Geometry.create`, `Reverb3D.create` |
| `System::setReverbProperties`, `getReverbProperties` | `Reverb.set`, `Reverb.get`, and `Reverb.off`. The `FMOD_PRESET_*` environments are `Reverb.PRESET_*`. |
| `ChannelControl` | No class of its own. Its methods appear on both `Channel` and `ChannelGroup`. |
| `System::createSound`, `playSound`, `playDSP` | The factories below, and `play(?startPaused, ?group)` on `Sound`, `PcmStream`, and `Dsp`. |

## Sound factories

FMOD creates every sound through `System::createSound` with a mode and an exinfo struct. haxefmod splits that call into factories on `Sound`. Each factory returns `Sound.NULL` on failure and puts the reason in `StudioSystem.lastResult()`.

- `Sound.create(path, ?loop, ?openOnly, ?mode, ?initialSubsound, ?exinfo)` loads a file. `loop` and `openOnly` set the matching mode bits. `mode` takes any further `ChannelMode` flags. `initialSubsound` picks the subsound an FSB stream starts on. `exinfo` is an `FmodCreateSoundExInfo` for the rest of `FMOD_CREATESOUNDEXINFO`. A sound opened with `openOnly` cannot play. It exists to be read.
- `Sound.fromMemory(bytes, ?mode, ?length, ?exinfo)` takes an encoded file image the game already holds. FMOD copies the bytes, so the buffer can go after the call returns.
- `Sound.fromPcm(bytes, sampleRate, channels, ?length)` makes a sample from 16-bit signed PCM. Stereo data is interleaved.
- `Sound.createRecordBuffer(sampleRate, channels, seconds)` makes an empty 16-bit PCM sound of that length. `StudioSystem.recordStart` fills it.

```haxe
import haxefmod.core.ChannelMode;
import haxefmod.core.Sound;

var music = Sound.create("assets/music/level1.ogg", true, false, ChannelMode.CREATESTREAM | ChannelMode.MODE_3D);
var pending = Sound.create("assets/voice/line01.ogg", false, false, ChannelMode.NONBLOCKING);
// Later, once pending.getOpenState() == FmodOpenState.READY
var channel = pending.play();
```

On HTML5 only FSB images decode. See [Limitations](../limitations.md#html5). `fromPcm` and `PcmStream` work on every target because they take raw PCM.

### Sample data

`readData(buffer, ?length)` decodes PCM from a sound opened with `openOnly` into the buffer. It returns the number of bytes read. At the end of the file it returns `0`, and `StudioSystem.lastResult()` reports `FMOD_ERR_FILE_EOF`. On an error it returns the negated FMOD error code.

`lock(offset, length)` returns a copy of a byte range of a sample sound as `haxe.io.Bytes`. `unlock(data)` writes the edited copy back and closes the lock. Only one lock can be open per sound. A release with a lock open unlocks the sound first.

## PcmStream

`PcmStream` plays audio the game produces frame by frame. Examples are a procedural synth, a tracker, or a network voice stream. `create(sampleRate, channels, ?ringBytes)` makes an FMOD user sound with a ring buffer behind it. `write` queues 16-bit signed PCM bytes, interleaved when stereo. FMOD's mixer drains the ring as the sound plays. `setReadCallback` reverses the flow. The `PcmReadCallback` runs from `FmodManager.Update` when the ring has room. It fills the buffer it receives and returns `FMOD_OK` to have the buffer written.

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

`write` returns the number of bytes accepted. When the ring is full, the stream drops the rest. Keep the unaccepted bytes and send them again when `space()` reports room. The default ring holds half a second. A bigger ring absorbs frame spikes. A smaller ring lets generated audio react faster.

`takeUnderruns()` reports how many times the mixer needed audio and found the ring empty, then clears the count. `create3d` makes a positional stream. Its channel takes `set3DAttributes` and attenuates with distance from the Studio listener. `release()` stops playback and frees the stream.
