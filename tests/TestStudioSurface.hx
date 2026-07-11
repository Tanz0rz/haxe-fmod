package tests;

import haxefmod.core.Channel;
import haxefmod.core.ChannelCallbacks;
import haxefmod.core.ChannelGroup;
import haxefmod.core.ChannelMode;
import haxefmod.core.CoreSystem;
import haxefmod.core.Dsp;
import haxefmod.core.DspConnection;
import haxefmod.core.DspType;
import haxefmod.core.PcmStream;
import haxefmod.core.Reverb;
import haxefmod.core.Reverb3D;
import haxefmod.core.SoundGroup;
import haxefmod.studio.Bank;
import haxefmod.studio.Bus;
import haxefmod.studio.CommandReplay;
import haxefmod.studio.CoreSound;
import haxefmod.studio.FmodResult;
import haxefmod.studio.EventDescription;
import haxefmod.studio.EventInstance;
import haxefmod.studio.StudioSystem;
import haxefmod.studio.Types;
import haxefmod.studio.Vca;

/**
 * Sweeps the whole haxefmod.studio abstract surface against the stub
 * backend. Proves the studio package compiles without flixel and that every
 * abstract method behaves safely on invalid handles (defaults returned,
 * no exceptions).
 */
class TestStudioSurface {
	static var passed = 0;
	static var failed = 0;

	public static function run():Int {
		Sys.println("--- Studio surface (stub backend) ---");

		testNullHandles();
		testSystemSurface();
		testStructReturns();
		testCoreSurface();

		Sys.println('  $passed passed, $failed failed');
		return failed;
	}

	static function assert(condition:Bool, name:String):Void {
		if (condition) passed++ else {
			failed++;
			Sys.println('  FAIL: $name');
		}
	}

	static function testNullHandles():Void {
		var bus:Bus = Bus.NULL;
		assert(bus.isNull(), "bus null");
		assert(!bus.isValid(), "bus invalid");
		assert(bus.getPath() == "", "bus path default");
		assert(!bus.setVolume(1.0).isOk(), "bus setVolume result");
		assert(!bus.lockChannelGroup().isOk(), "bus lockChannelGroup result");
		assert(!bus.unlockChannelGroup().isOk(), "bus unlockChannelGroup result");
		assert(bus.getChannelGroup().isNull(), "bus channelGroup default");

		var vca:Vca = Vca.NULL;
		assert(!vca.isValid(), "vca invalid");
		assert(vca.getVolume() == 0.0, "vca volume default");
		assert(!vca.setVolume(1.0).isOk(), "vca setVolume result");

		var bank:Bank = Bank.NULL;
		assert(!bank.isValid(), "bank invalid");
		assert(bank.getLoadingState() == FmodLoadingState.UNLOADED, "bank loading state default");
		assert(bank.getEventList().length == 0, "bank event list empty");
		assert(bank.getBusList().length == 0, "bank bus list empty");
		assert(bank.getVCAList().length == 0, "bank vca list empty");
		assert(!bank.unload().isOk(), "bank unload result");

		var desc:EventDescription = EventDescription.NULL;
		assert(!desc.isValid(), "evd invalid");
		assert(desc.getLength() == 0, "evd length default");
		assert(desc.getMinMaxDistance() == null, "evd minmax null");
		assert(desc.createInstance().isNull(), "evd createInstance null");
		assert(desc.getInstanceList().length == 0, "evd instance list empty");
		assert(desc.getParameterDescriptionByIndex(0) == null, "evd param desc null");
		assert(desc.getParameterLabel("x", 0) == "", "evd param label default");

		var instance:EventInstance = EventInstance.NULL;
		assert(!instance.isValid(), "evi invalid");
		assert(instance.getDescription().isNull(), "evi description null");
		assert(!instance.start().isOk(), "evi start result");
		assert(!instance.stop().isOk(), "evi stop result");
		assert(!instance.keyOff().isOk(), "evi keyOff result");
		assert(!instance.release().isOk(), "evi release result");
		assert(instance.getPlaybackState() == FmodPlaybackState.STOPPED, "evi playback state default");
		assert(instance.getVolume() == 0.0, "evi volume default");
		assert(instance.getTimelinePosition() == 0, "evi timeline default");
		assert(instance.getMinMaxDistance() == null, "evi minmax null");
		assert(instance.get3DAttributes() == null, "evi 3d attrs null");
		assert(!instance.setPosition2D(1, 2).isOk(), "evi setPosition2D result");
		assert(instance.getParameter("x") == 0.0, "evi param default");
		assert(!instance.setParameter("x", 1.0).isOk(), "evi setParameter result");
		assert(!instance.setParameterWithLabel("x", "label").isOk(), "evi setParameterWithLabel result");
		assert(instance.getProperty(CHANNELPRIORITY) == 0.0, "evi property default");
		assert(instance.getReverbLevel(0) == 0.0, "evi reverb default");
		assert(instance.getCpuUsage() == null, "evi cpu null");
		assert(instance.getMemoryUsage() == null, "evi memory null");
	}

	static function testSystemSurface():Void {
		assert(StudioSystem.getEvent("event:/x").isNull(), "sys getEvent null");
		assert(StudioSystem.getEventByID("{0}").isNull(), "sys getEventByID null");
		assert(StudioSystem.getVCA("vca:/x").isNull(), "sys getVCA null");
		assert(StudioSystem.getBank("bank:/x").isNull(), "sys getBank null");
		assert(StudioSystem.getBankCount() == 0, "sys bank count default");
		assert(StudioSystem.getBankList().length == 0, "sys bank list empty");
		assert(StudioSystem.lookupID("event:/x") == "", "sys lookupID default");
		assert(StudioSystem.lookupPath("{0}") == "", "sys lookupPath default");
		assert(StudioSystem.loadBankFile("x.bank").isNull(), "sys loadBankFile null");
		assert(!StudioSystem.unloadAll().isOk(), "sys unloadAll result");
		assert(StudioSystem.getParameter("x") == 0.0, "sys param default");
		assert(!StudioSystem.setParameter("x", 1.0).isOk(), "sys setParameter result");
		assert(!StudioSystem.setParameterByID({data1: 1, data2: 2}, 0.5).isOk(), "sys setParameterByID result");
		assert(StudioSystem.getParameterDescriptionCount() == 0, "sys param count default");
		assert(StudioSystem.getParameterDescriptionByIndex(0) == null, "sys param desc null");
		assert(StudioSystem.getNumListeners() == 0, "sys listeners default");
		assert(!StudioSystem.setListenerPosition2D(0, 1, 2).isOk(), "sys listener pos result");
		assert(StudioSystem.getListenerAttributes(0) == null, "sys listener attrs null");
	}

	static function testStructReturns():Void {
		assert(StudioSystem.getCpuUsage() == null, "sys cpu null");
		assert(StudioSystem.getBufferUsage() == null, "sys buffer null");
		assert(StudioSystem.getMemoryUsage() == null, "sys memory null");

		// setListenerAttributes with a full struct exercises the flattening path
		var attrs:Fmod3DAttributes = {
			position: {x: 1, y: 2, z: 3},
			velocity: {x: 0, y: 0, z: 0},
			forward: {x: 0, y: 0, z: 1},
			up: {x: 0, y: 1, z: 0},
		};
		assert(!StudioSystem.setListenerAttributes(0, attrs).isOk(), "sys setListenerAttributes result");

		var instance:EventInstance = EventInstance.NULL;
		assert(!instance.set3DAttributes(attrs).isOk(), "evi set3DAttributes result");

		// Programmer sounds + core micro subset
		assert(!instance.assignProgrammerSound("key").isOk(), "evi assignProgrammerSound result");
		assert(!instance.clearProgrammerSound().isOk(), "evi clearProgrammerSound result");
		var sound = CoreSound.create("missing.wav");
		assert(sound.isNull(), "core sound null");
		assert(sound.getLength() == -1, "core sound length default");
		assert(!sound.release().isOk(), "core sound release result");
	}

	static function testCoreSurface():Void {
		var stream = PcmStream.create(48000, 1);
		assert(stream.isNull(), "pcm stream null");
		assert(stream.write(haxe.io.Bytes.alloc(16)) == 0, "pcm write default");
		assert(stream.write(haxe.io.Bytes.alloc(16), 8) == 0, "pcm write with length");
		assert(stream.space() == 0, "pcm space default");
		assert(stream.takeUnderruns() == 0, "pcm underruns default");
		assert(!stream.release().isOk(), "pcm release result");

		var channel:Channel = stream.play();
		assert(channel.isNull(), "channel null");
		assert(!channel.setVolume(1.0).isOk(), "chan setVolume result");
		assert(channel.getVolume() == 0.0, "chan volume default");
		assert(!channel.setPitch(1.0).isOk(), "chan setPitch result");
		assert(channel.getPitch() == 0.0, "chan pitch default");
		assert(!channel.setPaused(true).isOk(), "chan setPaused result");
		assert(!channel.getPaused(), "chan paused default");
		assert(!channel.isPlaying(), "chan playing default");
		assert(!channel.setPan(0.5).isOk(), "chan setPan result");
		assert(channel.getFrequency() == 0.0, "chan frequency default");
		assert(!channel.setFrequency(48000).isOk(), "chan setFrequency result");
		assert(!channel.setLoopCount(-1).isOk(), "chan setLoopCount result");
		assert(channel.getPosition() == -1, "chan position default");
		assert(!channel.setPosition(0).isOk(), "chan setPosition result");
		assert(!channel.set3DAttributes(1, 2, 3).isOk(), "chan set3DAttributes result");
		assert(!channel.set3DMinMaxDistance(1, 100).isOk(), "chan set3DMinMax result");
		assert(!channel.setReverbWet(0, 0.5).isOk(), "chan setReverbWet result");
		assert(!channel.stop().isOk(), "chan stop result");

		var stream3d = PcmStream.create3d(48000, 1);
		assert(stream3d.isNull(), "pcm stream 3d null");

		var dsp = Dsp.create(DspType.LOWPASS_SIMPLE);
		assert(dsp.isNull(), "dsp null");
		assert(dsp.play().isNull(), "dsp play null");
		assert(!dsp.setParameter(0, 2000).isOk(), "dsp setParameter result");
		assert(dsp.getParameter(0) == 0.0, "dsp parameter default");
		assert(!dsp.setParameterInt(0, 1).isOk(), "dsp setParameterInt result");
		assert(dsp.getParameterInt(0) == 0, "dsp parameterInt default");
		assert(!dsp.setParameterBool(0, true).isOk(), "dsp setParameterBool result");
		assert(!dsp.getParameterBool(0), "dsp parameterBool default");
		assert(dsp.getParameterCount() == 0, "dsp parameterCount default");
		assert(dsp.getType() == DspType.UNKNOWN, "dsp type default");
		assert(!dsp.setBypass(true).isOk(), "dsp setBypass result");
		assert(!dsp.getBypass(), "dsp bypass default");
		assert(!dsp.setWetDryMix(1, 1, 0).isOk(), "dsp setWetDryMix result");
		assert(!dsp.setActive(true).isOk(), "dsp setActive result");
		assert(!dsp.reset().isOk(), "dsp reset result");
		assert(!dsp.setMeteringEnabled(true, true).isOk(), "dsp setMeteringEnabled result");
		assert(dsp.getMetering() == null, "dsp metering default");
		assert(dsp.getFftSpectrum() == null, "dsp spectrum default");
		assert(!dsp.release().isOk(), "dsp release result");

		var group = ChannelGroup.master();
		assert(group.isNull(), "cg master null");
		assert(ChannelGroup.create("test").isNull(), "cg create null");
		assert(!group.setVolume(0.5).isOk(), "cg setVolume result");
		assert(group.getVolume() == 0.0, "cg volume default");
		assert(!group.setPitch(1.0).isOk(), "cg setPitch result");
		assert(group.getPitch() == 0.0, "cg pitch default");
		assert(!group.setMute(true).isOk(), "cg setMute result");
		assert(!group.getMute(), "cg mute default");
		assert(!group.setPaused(true).isOk(), "cg setPaused result");
		assert(!group.getPaused(), "cg paused default");
		assert(!group.addDsp(0, dsp).isOk(), "cg addDsp result");
		assert(!group.removeDsp(dsp).isOk(), "cg removeDsp result");
		assert(!group.stop().isOk(), "cg stop result");
		assert(!group.release().isOk(), "cg release result");
		assert(!channel.setChannelGroup(group).isOk(), "chan setChannelGroup result");
		assert(!channel.addDsp(0, dsp).isOk(), "chan addDsp result");
		assert(!channel.removeDsp(dsp).isOk(), "chan removeDsp result");

		assert(!Reverb.set(0, Reverb.PRESET_CONCERTHALL).isOk(), "reverb set result");
		assert(Reverb.get(0) == null, "reverb get default");
		assert(Reverb.PRESET_CONCERTHALL.decayTime == 3900, "reverb preset values");

		// Slice-3 surface on the stub
		var conn = dsp.addInput(dsp);
		assert(conn.isNull(), "conn null");
		assert(!conn.setMix(0.5).isOk(), "conn setMix result");
		assert(conn.getMix() == 0.0, "conn mix default");
		assert(conn.getType() == 0, "conn type default");
		assert(!dsp.disconnectFrom(dsp).isOk(), "dsp disconnectFrom result");
		assert(!dsp.disconnectAll().isOk(), "dsp disconnectAll result");
		assert(dsp.getInputCount() == 0, "dsp inputCount default");
		assert(dsp.getOutputCount() == 0, "dsp outputCount default");
		assert(dsp.getInput(0).isNull(), "dsp input default");
		assert(dsp.getInputConnection(0).isNull(), "dsp inputConn default");
		assert(dsp.getCpuUsage() == null, "dsp cpu default");

		assert(!group.addGroup(group).isOk(), "cg addGroup result");
		assert(group.getGroupCount() == 0, "cg groupCount default");
		assert(group.getGroup(0).isNull(), "cg getGroup default");
		assert(group.getParentGroup().isNull(), "cg parent default");
		assert(group.getDspClock() == null, "cg clock default");
		assert(!group.setDelay(0, 100).isOk(), "cg setDelay result");
		assert(!group.addFadePoint(0, 1).isOk(), "cg addFadePoint result");
		assert(!group.setFadePointRamp(0, 1).isOk(), "cg fadeRamp result");
		assert(!group.removeFadePoints(0, 100).isOk(), "cg removeFades result");

		assert(!channel.setMute(true).isOk(), "chan setMute result");
		assert(!channel.getMute(), "chan mute default");
		assert(!channel.setLowPassGain(0.5).isOk(), "chan lowPassGain result");
		assert(!channel.setMode(ChannelMode.LOOP_NORMAL | ChannelMode.MODE_3D).isOk(), "chan setMode result");
		assert(!channel.set3DConeSettings(30, 60, 0.5).isOk(), "chan cone result");
		assert(!channel.set3DConeOrientation(0, 0, 1).isOk(), "chan coneOrient result");
		assert(!channel.set3DOcclusion(0.5, 0.3).isOk(), "chan occlusion result");
		assert(channel.get3DOcclusion() == null, "chan occlusion default");
		assert(!channel.set3DSpread(45).isOk(), "chan spread result");
		assert(!channel.set3DLevel(0.8).isOk(), "chan 3dLevel result");
		assert(!channel.set3DDopplerLevel(1).isOk(), "chan doppler result");
		assert(!channel.setMixMatrix([1, 0, 0, 1], 2, 2).isOk(), "chan mixMatrix result");
		assert(channel.setMixMatrix([1], 2, 2) == FmodResult.FMOD_ERR_INVALID_PARAM, "chan mixMatrix bounds");
		assert(channel.getDspClock() == null, "chan clock default");
		assert(!channel.setDelay(0, 100).isOk(), "chan setDelay result");
		assert(!channel.addFadePoint(0, 1).isOk(), "chan addFadePoint result");
		assert(!channel.setFadePointRamp(0, 1).isOk(), "chan fadeRamp result");
		assert(!channel.removeFadePoints(0, 100).isOk(), "chan removeFades result");

		var zone = Reverb3D.create();
		assert(zone.isNull(), "reverb3d null");
		assert(!zone.set3DAttributes(0, 0, 0, 5, 20).isOk(), "reverb3d attributes result");
		assert(!zone.setProperties(Reverb.PRESET_CAVE).isOk(), "reverb3d setProps result");
		assert(zone.getProperties() == null, "reverb3d getProps default");
		assert(!zone.setActive(true).isOk(), "reverb3d active result");
		assert(!zone.release().isOk(), "reverb3d release result");

		var pcmSound = CoreSound.fromPcm(haxe.io.Bytes.alloc(64), 48000, 1);
		assert(pcmSound.isNull(), "coresound fromPcm null");
		assert(pcmSound.play().isNull(), "coresound play null");
		assert(!pcmSound.setDefaults(24000, 128).isOk(), "coresound defaults result");
		assert(pcmSound.getDefaults() == null, "coresound defaults default");
		assert(!pcmSound.setLoopPoints(0, 100).isOk(), "coresound loopPoints result");
		assert(pcmSound.getLoopPoints() == null, "coresound loopPoints default");
		assert(!pcmSound.setMode(ChannelMode.LOOP_NORMAL).isOk(), "coresound setMode result");
		assert(pcmSound.getMode() == 0, "coresound mode default");
		assert(pcmSound.getFormat() == null, "coresound format default");
		assert(pcmSound.getOpenState() == -1, "coresound openState default");

		assert(CoreSystem.getChannelsPlaying() == null, "sys channelsPlaying default");
		assert(!CoreSystem.mixerSuspend().isOk(), "sys mixerSuspend result");
		assert(!CoreSystem.mixerResume().isOk(), "sys mixerResume result");
		assert(CoreSystem.getSoftwareFormat() == null, "sys softwareFormat default");

		// Slice-4 surface on the stub
		assert(!pcmSound.addSyncPoint(50, "mid").isOk(), "sound addSyncPoint result");
		assert(!pcmSound.deleteSyncPoint(0).isOk(), "sound deleteSyncPoint result");
		assert(pcmSound.getSyncPointCount() == 0, "sound syncPointCount default");
		assert(pcmSound.getSyncPointName(0) == "", "sound syncPointName default");
		assert(pcmSound.getSyncPointOffset(0) == -1, "sound syncPointOffset default");

		var soundGroup = SoundGroup.create("test");
		assert(soundGroup.isNull(), "sg create null");
		assert(SoundGroup.master().isNull(), "sg master null");
		assert(!soundGroup.setMaxAudible(2).isOk(), "sg setMaxAudible result");
		assert(soundGroup.getMaxAudible() == 0, "sg maxAudible default");
		assert(!soundGroup.setMaxAudibleBehavior(SoundGroup.BEHAVIOR_STEAL_LOWEST).isOk(), "sg behavior result");
		assert(soundGroup.getMaxAudibleBehavior() == 0, "sg behavior default");
		assert(!soundGroup.setMuteFadeSpeed(0.5).isOk(), "sg muteFade result");
		assert(soundGroup.getSoundCount() == 0, "sg soundCount default");
		assert(!soundGroup.stop().isOk(), "sg stop result");
		assert(!soundGroup.release().isOk(), "sg release result");
		assert(!pcmSound.setSoundGroup(soundGroup).isOk(), "sound setSoundGroup result");

		assert(!CoreSystem.set3DSettings(1, 1, 1).isOk(), "sys set3DSettings result");
		assert(CoreSystem.get3DSettings() == null, "sys get3DSettings default");
		assert(CoreSystem.getDriverCount() == 0, "sys driverCount default");
		assert(CoreSystem.getDriverName(0) == "", "sys driverName default");

		assert(channel.getLoopCount() == 0, "chan loopCount default");
		assert(channel.getLowPassGain() == 0.0, "chan lowPassGain default");
		assert(channel.getMode() == 0, "chan mode default");
		assert(channel.get3DConeSettings() == null, "chan coneSettings default");
		assert(channel.get3DSpread() == 0.0, "chan spread default");
		assert(channel.get3DLevel() == 0.0, "chan 3dLevel default");
		assert(channel.get3DDopplerLevel() == 0.0, "chan doppler default");
		assert(channel.get3DMinMaxDistance() == null, "chan minMax default");
		assert(channel.get3DAttributes() == null, "chan 3dAttributes default");
		assert(channel.getDelay() == null, "chan delay default");
		assert(dsp.getWetDryMix() == null, "dsp wetDryMix default");
		assert(!dsp.getActive(), "dsp active default");
		assert(dsp.getMeteringEnabled() == null, "dsp meteringEnabled default");

		// Slice-5 surface on the stub
		assert(StudioSystem.loadBankMemory(haxe.io.Bytes.alloc(16)).isNull(), "sys loadBankMemory null");
		assert(!StudioSystem.startCommandCapture("x.cmd.txt").isOk(), "sys startCapture result");
		assert(!StudioSystem.stopCommandCapture().isOk(), "sys stopCapture result");
		var replay = StudioSystem.loadCommandReplay("x.cmd.txt");
		assert(replay.isNull(), "sys loadReplay null");
		assert(!replay.start().isOk(), "replay start result");
		assert(!replay.stop().isOk(), "replay stop result");
		assert(!replay.setPaused(true).isOk(), "replay setPaused result");
		assert(!replay.getPaused(), "replay paused default");
		assert(!replay.seekToTime(0).isOk(), "replay seek result");
		assert(replay.getLength() == 0.0, "replay length default");
		assert(!replay.release().isOk(), "replay release result");

		var nullInstance:haxefmod.studio.EventInstance = haxefmod.studio.EventInstance.NULL;
		assert(nullInstance.getChannelGroup().isNull(), "evi channelGroup default");

		assert(!channel.setPriority(128).isOk(), "chan setPriority result");
		assert(channel.getPriority() == 0, "chan priority default");
		assert(!channel.isVirtual(), "chan virtual default");
		assert(channel.getAudibility() == 0.0, "chan audibility default");
		assert(!channel.setVolumeRamp(true).isOk(), "chan setVolumeRamp result");
		assert(!channel.getVolumeRamp(), "chan volumeRamp default");
		assert(channel.getCurrentSound().isNull(), "chan currentSound default");
		assert(!channel.setLoopPoints(0, 100).isOk(), "chan setLoopPoints result");
		assert(channel.getLoopPoints() == null, "chan loopPoints default");
		assert(channel.getReverbWet(0) == 0.0, "chan reverbWet default");
		assert(channel.getIndex() == -1, "chan index default");
		assert(channel.get3DConeOrientation() == null, "chan coneOrientation default");
		assert(channel.getDspCount() == 0, "chan dspCount default");
		assert(channel.getDsp(0).isNull(), "chan getDsp default");

		assert(pcmSound.getName() == "", "sound name default");
		assert(pcmSound.getSoundGroup().isNull(), "sound group getter default");
		assert(!pcmSound.setLoopCount(2).isOk(), "sound setLoopCount result");
		assert(pcmSound.getLoopCount() == 0, "sound loopCount default");

		assert(!soundGroup.setVolume(0.5).isOk(), "sg setVolume result");
		assert(soundGroup.getVolume() == 0.0, "sg volume default");
		assert(soundGroup.getPlayingCount() == 0, "sg playingCount default");
		assert(soundGroup.getMuteFadeSpeed() == 0.0, "sg muteFade getter default");

		assert(!CoreSystem.setDriver(0).isOk(), "sys setDriver result");
		assert(CoreSystem.getDriver() == 0, "sys getDriver default");

		assert(!dsp.setParameterData(0, haxe.io.Bytes.alloc(8)).isOk(), "dsp setParameterData result");
		assert(!dsp.isIdle(), "dsp idle default");
		assert(dsp.getName() == "", "dsp name default");
		assert(dsp.getOutput(0).isNull(), "dsp output default");
		assert(dsp.getOutputConnection(0).isNull(), "dsp outputConn default");
		assert(conn.getInputDsp().isNull(), "conn inputDsp default");
		assert(conn.getOutputDsp().isNull(), "conn outputDsp default");

		assert(!zone.getActive(), "reverb3d active default");
		assert(zone.get3DAttributes() == null, "reverb3d attributes default");

		assert(!group.setPan(0.5).isOk(), "cg setPan result");
		assert(!group.setLowPassGain(0.5).isOk(), "cg setLowPassGain result");
		assert(!group.setMode(ChannelMode.MODE_3D).isOk(), "cg setMode result");
		assert(group.getMode() == 0, "cg mode default");
		assert(!group.set3DAttributes(1, 2, 3).isOk(), "cg set3DAttributes result");
		assert(group.get3DAttributes() == null, "cg 3dAttributes default");
		assert(!group.set3DMinMaxDistance(1, 100).isOk(), "cg minMax result");
		assert(group.get3DMinMaxDistance() == null, "cg minMax default");
		assert(!group.set3DOcclusion(0.5, 0.3).isOk(), "cg occlusion result");
		assert(!group.set3DLevel(0.8).isOk(), "cg 3dLevel result");
		assert(group.get3DLevel() == 0.0, "cg 3dLevel default");
		assert(!group.set3DSpread(45).isOk(), "cg spread result");
		assert(group.get3DSpread() == 0.0, "cg spread default");
		assert(!group.set3DDopplerLevel(1).isOk(), "cg doppler result");
		assert(group.get3DDopplerLevel() == 0.0, "cg doppler default");
		assert(!group.set3DConeSettings(30, 60, 0.5).isOk(), "cg cone result");
		assert(group.get3DConeSettings() == null, "cg cone default");
		assert(!group.set3DConeOrientation(0, 0, 1).isOk(), "cg coneOrient result");
		assert(group.get3DConeOrientation() == null, "cg coneOrient default");
		assert(!group.setReverbWet(0, 0.5).isOk(), "cg setReverbWet result");
		assert(group.getReverbWet(0) == 0.0, "cg reverbWet default");
		assert(!group.setMixMatrix([1, 0, 0, 1], 2, 2).isOk(), "cg mixMatrix result");
		assert(group.setMixMatrix([1], 2, 2) == FmodResult.FMOD_ERR_INVALID_PARAM, "cg mixMatrix bounds");
		assert(!group.setVolumeRamp(true).isOk(), "cg setVolumeRamp result");
		assert(!group.getVolumeRamp(), "cg volumeRamp default");
		assert(group.getAudibility() == 0.0, "cg audibility default");
		assert(group.getName() == "", "cg name default");
		assert(group.getChannelCount() == 0, "cg channelCount default");
		assert(group.getChannel(0).isNull(), "cg getChannel default");

		// Channel event routing: namespaced records reach the channel map
		// and End removes the registration
		var received:Array<haxefmod.core.ChannelEvent> = [];
		ChannelCallbacks.set(1234, function(e) received.push(e));
		haxefmod.runtime.CallbackDispatcher.deliver(1234, ChannelCallbacks.TYPE_SYNCPOINT, 3, 0, 0, 0, "");
		haxefmod.runtime.CallbackDispatcher.deliver(1234, ChannelCallbacks.TYPE_END, 0, 0, 0, 0, "");
		haxefmod.runtime.CallbackDispatcher.deliver(1234, ChannelCallbacks.TYPE_END, 0, 0, 0, 0, "");
		assert(received.length == 2, "chan events delivered");
		assert(received[0].match(SyncPoint(3)), "chan syncpoint payload");
		assert(received[1].match(End), "chan end payload");
		ChannelCallbacks.clearAll();
	}
}
