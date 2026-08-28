# Core API

FMOD Studio events cover almost everything a game plays. The Core API underneath is for the cases they do not: audio generated at runtime, effects attached to a specific bus or event, sound groups that cap polyphony, and the global reverb. `haxefmod.core` binds it with the same handle conventions as the studio layer (see [Handles and results](handles-and-results.md)), and the pieces connect to Studio audio through `Bus.getChannelGroup` and `EventInstance.getChannelGroup`.

Every method keeps the FMOD name, so the [FMOD Core API reference](https://www.fmod.com/docs/2.03/api/core-api.html) describes what each one does. This page covers how the pieces fit together from Haxe.

## Generated audio

`PcmStream` plays audio the game produces frame by frame: procedural synths, a tracker, a network voice stream. `create(sampleRate, channels, ?ringBytes)` makes an FMOD user sound backed by a ring buffer, `write` queues 16-bit signed PCM bytes (interleaved when stereo), and FMOD's mixer drains them as the sound plays.

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

`CoreSound.fromPcm(bytes, sampleRate, channels)` is the static counterpart for a sample that is fully known ahead of time. Both work on every target because they take raw PCM.

## Channels

A `Channel` is a playing instance of a core sound, returned by `PcmStream.play`, `CoreSound.play`, and `Dsp.play`. It carries volume, pitch, pan, pause, frequency, loop count, position, mute, a built-in lowpass, 3D attributes and cone settings, occlusion, a mix matrix, and sample-accurate scheduling through `getDspClock` and `setDelay`.

```haxe
var sound = haxefmod.studio.CoreSound.create("assets/voice/line01.ogg");
var channel = sound.play();
channel.setVolume(0.6);
channel.setPitch(1.2);
channel.setPan(-0.3);
channel.setLoopCount(-1);
```

Channels end on their own when playback stops, so a handle can go stale before you call `stop()`. Call `stop()` when you are done with it either way, since that always frees the handle slot.

`Channel.setCallback` delivers `ChannelEvent` values (`End`, `SyncPoint(index)`) on the game thread through the same per-frame drain as studio callbacks. Sync points are set on the sound with `CoreSound.addSyncPoint`.

## Channel groups

A `ChannelGroup` is a mixing bus for raw channels. `ChannelGroup.master()` is the final mix everything passes through. `create(name)` makes a custom group, and `Channel.setChannelGroup` routes a channel into it. Groups nest through `addGroup`, and each carries volume, pitch, mute, pause, pan, lowpass, a DSP chain, 3D attributes, and fade points scheduled against the mixer clock.

```haxe
import haxefmod.core.ChannelGroup;

var voices = ChannelGroup.create("voices");
channel.setChannelGroup(voices);
voices.setVolume(0.8);
```

Studio audio is reachable the same way. `Bus.getChannelGroup()` returns the group behind a Studio bus and `EventInstance.getChannelGroup()` the group carrying one started instance. Never release those two, since Studio owns them. The focus mute described in [FmodManager](fmod-manager.md#window-focus) is applied to the master group, which is why it composes with any mute a game sets on the Studio master bus.

## Effects

A `Dsp` is one effect unit. Create it from a `DspType` (all 33 built-in types are available on every target), set its parameters by index, and attach it to a channel or group with `addDsp`. Parameter indices for each effect are in the [FMOD DSP effect reference](https://www.fmod.com/docs/2.03/api/effects-reference.html).

```haxe
import haxefmod.core.ChannelGroup;
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var lowpass = Dsp.create(DspType.LOWPASS);
lowpass.setParameter(0, 800); // cutoff in Hz
StudioSystem.getBus("bus:/SFX").getChannelGroup().addDsp(ChannelGroup.DSP_HEAD, lowpass);

// later
StudioSystem.getBus("bus:/SFX").getChannelGroup().removeDsp(lowpass);
lowpass.release();
```

`setParameterInt`, `setParameterBool`, and `setParameterData` cover the other parameter kinds, and `setBypass`, `setActive`, `setWetDryMix`, and `reset` control the unit. Detach an effect before releasing it.

Two effects double as analyzers. A `DspType.FFT` unit attached where you want to listen exposes `getFftSpectrum(maxBins)`, and any unit reports `getMetering()` (peak and RMS per output channel) once `setMeteringEnabled` is on.

```haxe
import haxefmod.core.ChannelGroup;
import haxefmod.core.Dsp;
import haxefmod.core.DspType;

var fft = Dsp.create(DspType.FFT);
ChannelGroup.master().addDsp(ChannelGroup.DSP_TAIL, fft);
// each frame
var spectrum = fft.getFftSpectrum(64);
if (spectrum != null) trace('bass ${spectrum[1]}');
```

`Dsp.play` plays a generator unit such as `DspType.OSCILLATOR` as a sound source. `addInput`, `disconnectFrom`, and the `DspConnection` handle build custom mixer topologies, including send and sidechain routings through `DspConnection.TYPE_SEND` and `TYPE_SIDECHAIN` with a per-connection mix level. Any graph change invalidates every connection handle, so query them again through `getInputConnection` afterwards.

Custom DSP callbacks and third-party plugins are unavailable, since Haxe code cannot run on FMOD's mixer thread on any target.

## Reverb

`Reverb` is the built-in system reverb. Set an environment on instance 0 (FMOD has four, games normally use one) and channels contribute through their reverb wet level, which defaults to full.

```haxe
import haxefmod.core.Reverb;

Reverb.set(0, Reverb.PRESET_CAVE);
channel.setReverbWet(0, 0.5);
// later
Reverb.off(0);
```

The presets match FMOD's `FMOD_PRESET_*` set, and `ReverbProperties` exposes all twelve fields for custom environments. `Reverb3D` is a positional zone, a sphere at full strength inside its minimum distance and fading out to the maximum, blended automatically with overlapping zones, so each room can carry its own environment.

Studio events route through the Studio mixer, where reverb is authored in FMOD Studio. The core reverb applies to core channels.

## Sound groups

A `SoundGroup` caps how many sounds from a set play at once. `setMaxAudible` sets the limit and `setMaxAudibleBehavior` chooses what happens past it: `BEHAVIOR_FAIL` refuses the new sound, `BEHAVIOR_MUTE` plays it silently, and `BEHAVIOR_STEAL_LOWEST` stops the quietest. Assign sounds with `CoreSound.setSoundGroup`. Every sound belongs to `SoundGroup.master()` until moved.

```haxe
import haxefmod.core.SoundGroup;

var footsteps = SoundGroup.create("footsteps");
footsteps.setMaxAudible(3);
footsteps.setMaxAudibleBehavior(SoundGroup.BEHAVIOR_STEAL_LOWEST);
```

## Mixer and 3D settings

`CoreSystem` holds the calls that belong to no single object. `getChannelsPlaying()` reports total and real (audible) channel counts, `getSoftwareFormat()` the mixer's sample rate and speaker mode, and `mixerSuspend` and `mixerResume` stop and restart the mixer for platforms that demand silence in the background. `set3DSettings(dopplerScale, distanceFactor, rolloffScale)` rescales doppler, world units per meter, and distance attenuation for every 3D sound, Studio events included. Output device selection goes through `getDriverCount`, `getDriverName`, `setDriver`, and `getDriver`.

## Profiling

`StudioSystem.getCpuUsage()` breaks mixer time down per subsystem, `getMemoryUsage()` reports bytes (native only), and `getBufferUsage()` shows the Studio command queue and handle buffer with their stall counts. `Bus`, `EventInstance`, and `Dsp` have `getCpuUsage()` as well, but FMOD only fills those in when the system was initialized with its profiling flag, which the library does not set, so they return `null`.

`StudioSystem.startCommandCapture(path)` records every Studio API call to a file that FMOD's tools can analyze, `stopCommandCapture()` ends it, and `loadCommandReplay(path)` plays a capture back through the live system as a `CommandReplay` handle.
