package tests;

import haxefmod.core.Channel;
import haxefmod.core.ChannelCallbacks;
import haxefmod.core.ChannelGroup;
import haxefmod.core.ChannelMode;
import haxefmod.core.CoreSystem;
import haxefmod.core.Dsp;
import haxefmod.core.DspConnection;
import haxefmod.core.DspParameters;
import haxefmod.core.DspType;
import haxefmod.core.DspEnums;
import haxefmod.core.Geometry;
import haxefmod.core.PcmStream;
import haxefmod.core.Reverb;
import haxefmod.core.Reverb3D;
import haxefmod.core.SoundGroup;
import haxefmod.studio.Bank;
import haxefmod.studio.Bus;
import haxefmod.studio.Callbacks;
import haxefmod.studio.CommandReplay;
import haxefmod.core.Sound;
import haxefmod.studio.FmodResult;
import haxefmod.studio.EventDescription;
import haxefmod.studio.EventInstance;
import haxefmod.studio.CallbackDispatcher;
import haxefmod.studio.StudioSystem;
import haxefmod.studio.Types;
import haxefmod.studio.Types.FmodVector;
import haxefmod.studio.Vca;

/**
 * Sweeps the whole haxefmod.studio abstract surface against the stub
 * backend. Proves the studio package compiles without flixel and that every
 * abstract method behaves safely on invalid handles (defaults returned,
 * no exceptions).
 */
@:access(haxefmod.studio.StudioSystem)
class TestStudioSurface {
	static var passed = 0;
	static var failed = 0;

	public static function run():Int {
		Sys.println("--- Studio surface (stub backend) ---");

		testNullHandles();
		testSystemSurface();
		testBusCache();
		testStructReturns();
		testCoreSurface();
		testVersionDataAndRecording();
		testSoundCreationAndRouting();
		testRolloffAndGeometry();
		testSystemCallbackStub();
		testCompletenessTail();
		testSysExtras();
		testSoundExtrasStub();
		testLastSevenStub();
		testDspParameters();
		testGroupDspChain();
		testChannelControlParity();
		testValueEnums();
		testTypedSignatures();
		testCoreTypes();

		Sys.println('  $passed passed, $failed failed');
		return failed;
	}

	static function assert(condition:Bool, name:String):Void {
		if (condition) passed++ else {
			failed++;
			Sys.println('  FAIL: $name');
		}
	}

	static function testBusCache():Void {
		// A cached bus handle can outlive its bank. getBus must re-validate
		// cached entries instead of serving stale handles forever.
		StudioSystem.busCache.set("bus:/stale", cast 123);
		var got = StudioSystem.getBus("bus:/stale");
		assert(got.isNull(), "stale cached bus not served");
		assert(!StudioSystem.busCache.exists("bus:/stale"), "stale cache entry evicted");
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
		assert(desc.getParameterDescriptionByID({data1: 1, data2: 2}) == null, "evd param desc by id null");
		assert(desc.getParameterLabelByID({data1: 1, data2: 2}, 0) == "", "evd param label by id default");
		assert(desc.getUserPropertyByName("x") == null, "evd user property by name null");

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
		assert(StudioSystem.getParameterDescriptionByID({data1: 1, data2: 2}) == null, "sys param desc by id null");
		assert(StudioSystem.getParameterLabelByID({data1: 1, data2: 2}, 0) == "", "sys param label by id default");
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
		assert(!StudioSystem.setListenerAttributes(0, attrs, {x: 4, y: 5, z: 6}).isOk(), "sys setListenerAttributes attenuation result");
		// The listener getter's shape extends Fmod3DAttributes, so it still
		// lands in a variable of that type
		var plain:Null<Fmod3DAttributes> = StudioSystem.getListenerAttributes(0);
		assert(plain == null, "sys listener attrs assignable");

		var instance:EventInstance = EventInstance.NULL;
		assert(!instance.set3DAttributes(attrs).isOk(), "evi set3DAttributes result");

		// Programmer sounds + core micro subset
		assert(!instance.assignProgrammerSound("key").isOk(), "evi assignProgrammerSound result");
		// A null key crashed the C++ shim's strncpy before the wrapper
		// guard existed (the one place a shim consumes a string itself)
		assert(instance.assignProgrammerSound(null) == FmodResult.FMOD_ERR_INVALID_PARAM,
			"evi assignProgrammerSound null key rejected in the wrapper");
		assert(!instance.clearProgrammerSound().isOk(), "evi clearProgrammerSound result");
		var sound = Sound.create("missing.wav");
		assert(sound.isNull(), "core sound null");
		assert(sound.getLength() == -1, "core sound length default");
		assert(!sound.release().isOk(), "core sound release result");
	}

	// Sound creation flags, memory images, play routing, and the
	// programmer sound forms. The mode composition and the null guards are
	// the logic here, the rest routes through the stub.
	static function testSoundCreationAndRouting():Void {
		var stub = haxefmod.studio.native.NativeStudioStub;

		stub.testLastCreateSoundMode = -1;
		stub.testLastCreateSoundSubsound = -99;
		Sound.create("x.fsb", true, false, ChannelMode.MODE_3D | ChannelMode.CREATESTREAM, 2);
		assert(stub.testLastCreateSoundMode == (ChannelMode.LOOP_NORMAL | ChannelMode.MODE_3D | ChannelMode.CREATESTREAM),
			"create composes loop with the mode flags");
		assert(stub.testLastCreateSoundSubsound == 2, "create passes the initial subsound through");
		Sound.create("x.wav", false, true, ChannelMode.NONBLOCKING);
		assert(stub.testLastCreateSoundMode == (ChannelMode.OPENONLY | ChannelMode.NONBLOCKING),
			"create composes openOnly with NONBLOCKING");
		assert(stub.testLastCreateSoundSubsound == -1, "create defaults the subsound to -1");

		assert(Sound.fromMemory(null).isNull(), "fromMemory null bytes");
		stub.testLastMemoryLen = -1;
		stub.testLastMemoryMode = -1;
		assert(Sound.fromMemory(haxe.io.Bytes.alloc(64), ChannelMode.CREATESAMPLE).isNull(), "fromMemory stub null");
		assert(stub.testLastMemoryLen == 64 && stub.testLastMemoryMode == ChannelMode.CREATESAMPLE,
			"fromMemory passes the whole buffer and the mode");
		Sound.fromMemory(haxe.io.Bytes.alloc(64), 0, 1024);
		assert(stub.testLastMemoryLen == 64, "fromMemory clamps a lied length");
		Sound.fromMemory(haxe.io.Bytes.alloc(64), 0, 16);
		assert(stub.testLastMemoryLen == 16, "fromMemory passes a partial length");

		var sound:Sound = cast 0;
		var group:ChannelGroup = cast 7;
		stub.testLastPlayGroup = -1;
		assert(sound.play().isNull(), "sound play null");
		assert(stub.testLastPlayGroup == 0, "sound play defaults to the master group");
		sound.play(true, group);
		assert(stub.testLastPlayGroup == 7, "sound play routes into the group");
		var dsp:Dsp = cast 0;
		stub.testLastPlayGroup = -1;
		dsp.play(false, group);
		assert(stub.testLastPlayGroup == 7, "dsp play routes into the group");
		dsp.play();
		assert(stub.testLastPlayGroup == 0, "dsp play defaults to the master group");
		var stream:PcmStream = cast 0;
		stub.testLastPlayGroup = -1;
		stream.play(false, group);
		assert(stub.testLastPlayGroup == 7, "pcm play routes into the group");
		stream.play();
		assert(stub.testLastPlayGroup == 0, "pcm play defaults to the master group");

		assert(Channel.DSP_HEAD == ChannelGroup.DSP_HEAD && Channel.DSP_FADER == ChannelGroup.DSP_FADER
			&& Channel.DSP_TAIL == ChannelGroup.DSP_TAIL, "channel chain positions match the group's");

		var instance:EventInstance = EventInstance.NULL;
		assert(instance.assignProgrammerSoundFrom(Sound.NULL) == FmodResult.FMOD_ERR_INVALID_PARAM,
			"assignProgrammerSoundFrom rejects a null sound in the wrapper");
		stub.testLastPsSound = -1;
		assert(!instance.assignProgrammerSoundFrom(cast 5, 3).isOk(), "assignProgrammerSoundFrom result");
		assert(stub.testLastPsSound == 5 && stub.testLastPsSubsound == 3, "assignProgrammerSoundFrom passes sound and subsound");
		instance.assignProgrammerSoundFrom(cast 5);
		assert(stub.testLastPsSubsound == -1, "assignProgrammerSoundFrom defaults the subsound to -1");
		assert(instance.assignProgrammerSoundForName(null, "k") == FmodResult.FMOD_ERR_INVALID_PARAM,
			"assignProgrammerSoundForName rejects a null name");
		assert(instance.assignProgrammerSoundForName("n", null) == FmodResult.FMOD_ERR_INVALID_PARAM,
			"assignProgrammerSoundForName rejects a null key");
		stub.testLastPsNamed = null;
		assert(!instance.assignProgrammerSoundForName("Line", "hello").isOk(), "assignProgrammerSoundForName result");
		assert(stub.testLastPsNamed != null && stub.testLastPsNamed[0] == "Line" && stub.testLastPsNamed[1] == "hello",
			"assignProgrammerSoundForName passes name and key");
		assert(instance.assignProgrammerSounds(null) == FmodResult.FMOD_ERR_INVALID_PARAM,
			"assignProgrammerSounds rejects a null map");
		assert(instance.assignProgrammerSounds(new Map()) == FmodResult.FMOD_OK,
			"assignProgrammerSounds with no entries is a no-op");
		stub.testLastPsNamed = null;
		assert(!instance.assignProgrammerSounds(["A" => "x"]).isOk(), "assignProgrammerSounds stops at the stub's failure");
		assert(stub.testLastPsNamed != null && stub.testLastPsNamed[0] == "A", "assignProgrammerSounds visits the entry");

		// The programmer sound callbacks decode with the instrument name
		switch (CallbackDispatcher.decode(EventCallbackType.CREATE_PROGRAMMER_SOUND, 0, 0, 0, 0, 0, 0, "Line")) {
			case ProgrammerSoundCreated(name): assert(name == "Line", "create decodes the instrument name");
			default: assert(false, "create decodes to ProgrammerSoundCreated");
		}
		switch (CallbackDispatcher.decode(EventCallbackType.DESTROY_PROGRAMMER_SOUND, 0, 0, 0, 0, 0, 0, "Line")) {
			case ProgrammerSoundDestroyed(name): assert(name == "Line", "destroy decodes the instrument name");
			default: assert(false, "destroy decodes to ProgrammerSoundDestroyed");
		}
	}

	// The distance filter, version, sound data, and recording surface
	// routes through the stub like everything else. The readData clamp is
	// the one piece of real logic here (the HashLink shim cannot see the
	// buffer size), so it gets the same treatment as fromPcm.
	static function testVersionDataAndRecording():Void {
		var stub = haxefmod.studio.native.NativeStudioStub;
		var channel:Channel = cast 0;
		assert(!channel.set3DDistanceFilter(true, 0.5, 1000).isOk(), "chan distance filter result");
		assert(channel.get3DDistanceFilter() == null, "chan distance filter default");
		var group:ChannelGroup = cast 0;
		assert(!group.set3DDistanceFilter(false, 1.0, 1500).isOk(), "cg distance filter result");
		assert(group.get3DDistanceFilter() == null, "cg distance filter default");

		assert(StudioSystem.getVersion() == "", "sys getVersion default");

		stub.testLastCreateSoundMode = -1;
		assert(Sound.create("x.wav").isNull(), "coresound create null");
		assert(stub.testLastCreateSoundMode == 0, "create defaults openOnly off");
		Sound.create("x.wav", false, true);
		assert(stub.testLastCreateSoundMode == ChannelMode.OPENONLY, "create passes openOnly through");

		var sound:Sound = cast 0;
		stub.testReadDataLen = -999;
		assert(sound.readData(haxe.io.Bytes.alloc(64)) == -68, "readData surfaces the negated result");
		assert(stub.testReadDataLen == 64, "readData sentinel means the whole buffer");
		stub.testReadDataLen = -999;
		sound.readData(haxe.io.Bytes.alloc(64), 4096);
		assert(stub.testReadDataLen == 64, "readData clamps a lied length to the buffer size");
		stub.testReadDataLen = -999;
		sound.readData(haxe.io.Bytes.alloc(64), 16);
		assert(stub.testReadDataLen == 16, "readData passes an honest partial length through");
		stub.testReadDataLen = -999;
		assert(sound.readData(null) == -31, "readData null buffer rejected with INVALID_PARAM");
		assert(stub.testReadDataLen == -999, "readData null buffer never reaches the backend");
		assert(!sound.seekData(0).isOk(), "seekData result");

		assert(StudioSystem.getRecordDriverCount() == null, "sys record driver count default");
		assert(StudioSystem.getRecordDriverInfo(0) == null, "sys record driver info default");
		assert(Sound.createRecordBuffer(48000, 1, 2).isNull(), "coresound createRecordBuffer null");
		assert(!StudioSystem.recordStart(0, sound).isOk(), "sys recordStart result");
		assert(!StudioSystem.recordStop(0).isOk(), "sys recordStop result");
		assert(!StudioSystem.isRecording(0), "sys isRecording default");
		assert(StudioSystem.getRecordPosition(0) == -1, "sys getRecordPosition default");
	}

	// Custom rolloff and geometry route through the stub like everything
	// else. The point packing is the one piece of real logic (float32 xyz
	// triples, empty list means clear), so it is checked byte for byte.
	static function testRolloffAndGeometry():Void {
		var points:Array<FmodVector> = [{x: 0, y: 1, z: 0}, {x: 10, y: 0.5, z: 0}, {x: 20, y: 0, z: 0}];
		var packed = haxefmod.studio.native.Scratch.packVectors(points);
		assert(packed.length == 36, "packVectors sizes three points at 12 bytes each");
		assert(Math.abs(packed.getFloat(12) - 10) < 0.0001 && Math.abs(packed.getFloat(16) - 0.5) < 0.0001,
			"packVectors writes x,y,z float32 triples in order");
		assert(haxefmod.studio.native.Scratch.packVectors([]) == null, "packVectors empty list is null (clear)");
		assert(haxefmod.studio.native.Scratch.packVectors(null) == null, "packVectors null list is null");
		assert(haxefmod.studio.native.Scratch.readVectors(0).length == 0, "readVectors zero count is empty");
		assert(haxefmod.studio.native.Scratch.readVectors(9999).length == haxefmod.studio.native.Scratch.VECTOR_CAPACITY,
			"readVectors caps at the scratch capacity");

		var channel:Channel = cast 0;
		assert(!channel.set3DCustomRolloff(points).isOk(), "chan set3DCustomRolloff result");
		assert(!channel.set3DCustomRolloff([]).isOk(), "chan set3DCustomRolloff clear result");
		assert(channel.get3DCustomRolloff().length == 0, "chan get3DCustomRolloff default");
		var group:ChannelGroup = cast 0;
		assert(!group.set3DCustomRolloff(points).isOk(), "cg set3DCustomRolloff result");
		assert(group.get3DCustomRolloff().length == 0, "cg get3DCustomRolloff default");
		var sound:Sound = cast 0;
		assert(!sound.set3DCustomRolloff(points).isOk(), "sound set3DCustomRolloff result");
		assert(sound.get3DCustomRolloff().length == 0, "sound get3DCustomRolloff default");

		assert(Geometry.create(8, 32).isNull(), "geometry create null");
		assert(Geometry.load(haxe.io.Bytes.alloc(16)).isNull(), "geometry load null");
		assert(Geometry.load(null).isNull(), "geometry load null data");
		assert(!Geometry.setWorldSize(1000).isOk(), "geometry setWorldSize result");
		assert(Geometry.getWorldSize() == 0, "geometry getWorldSize default");
		assert(Geometry.getOcclusion({x: 0, y: 0, z: 0}, {x: 1, y: 0, z: 0}) == null, "geometry getOcclusion default");
		assert(Geometry.getOcclusion(null, null) == null, "geometry getOcclusion null vectors");

		var geometry:Geometry = cast 0;
		assert(geometry.isNull(), "geometry isNull");
		assert(!geometry.release().isOk(), "geometry release result");
		var quad:Array<FmodVector> = [{x: 0, y: -1, z: -1}, {x: 0, y: 1, z: -1}, {x: 0, y: 1, z: 1}, {x: 0, y: -1, z: 1}];
		assert(geometry.addPolygon(1, 0.5, true, quad) == -1, "geometry addPolygon default");
		assert(geometry.addPolygon(1, 0.5, true, [quad[0], quad[1]]) == -1, "geometry addPolygon rejects fewer than three vertices");
		assert(geometry.addPolygon(1, 0.5, true, null) == -1, "geometry addPolygon rejects null vertices");
		assert(geometry.getNumPolygons() == -1, "geometry getNumPolygons default");
		assert(geometry.getMaxPolygons() == null, "geometry getMaxPolygons default");
		assert(geometry.getPolygonNumVertices(0) == -1, "geometry getPolygonNumVertices default");
		assert(!geometry.setPolygonVertex(0, 0, quad[0]).isOk(), "geometry setPolygonVertex result");
		assert(geometry.setPolygonVertex(0, 0, null) == FmodResult.FMOD_ERR_INVALID_PARAM, "geometry setPolygonVertex null vertex");
		assert(geometry.getPolygonVertex(0, 0) == null, "geometry getPolygonVertex default");
		assert(!geometry.setPolygonAttributes(0, 1, 1, false).isOk(), "geometry setPolygonAttributes result");
		assert(geometry.getPolygonAttributes(0) == null, "geometry getPolygonAttributes default");
		assert(!geometry.setActive(true).isOk(), "geometry setActive result");
		assert(!geometry.getActive(), "geometry getActive default");
		assert(!geometry.setRotation({x: 0, y: 0, z: 1}, {x: 0, y: 1, z: 0}).isOk(), "geometry setRotation result");
		assert(geometry.setRotation(null, {x: 0, y: 1, z: 0}) == FmodResult.FMOD_ERR_INVALID_PARAM, "geometry setRotation null vector");
		assert(geometry.getRotation() == null, "geometry getRotation default");
		assert(!geometry.setPosition({x: 1, y: 2, z: 3}).isOk(), "geometry setPosition result");
		assert(geometry.setPosition(null) == FmodResult.FMOD_ERR_INVALID_PARAM, "geometry setPosition null vector");
		assert(geometry.getPosition() == null, "geometry getPosition default");
		assert(!geometry.setScale({x: 1, y: 1, z: 1}).isOk(), "geometry setScale result");
		assert(geometry.setScale(null) == FmodResult.FMOD_ERR_INVALID_PARAM, "geometry setScale null vector");
		assert(geometry.getScale() == null, "geometry getScale default");
		assert(geometry.save() == null, "geometry save default");
	}

	static function testCoreSurface():Void {
		var stream = PcmStream.create(48000, 1);
		assert(stream.isNull(), "pcm stream null");
		assert(stream.write(haxe.io.Bytes.alloc(16)) == 0, "pcm write default");
		assert(stream.write(haxe.io.Bytes.alloc(16), 8) == 0, "pcm write with length");
		assert(stream.write(haxe.io.Bytes.alloc(16), 1 << 20) == 0, "pcm write oversized length clamped");
		assert(stream.write(null) == 0, "pcm write null data");
		assert(stream.write(haxe.io.Bytes.alloc(16), -8) == 0, "pcm write bad negative count");
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
		assert(conn.getType() == DspConnectionType.STANDARD, "conn type default");
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

		var pcmSound = Sound.fromPcm(haxe.io.Bytes.alloc(64), 48000, 1);
		assert(pcmSound.isNull(), "coresound fromPcm null");

		// The wrapper must never let a lied length reach a backend: the
		// HashLink shim cannot see the buffer's real size, and an
		// oversized count over-read the heap inside FMOD's memcpy
		var stub = haxefmod.studio.native.NativeStudioStub;
		stub.testPcmCreateLen = -999;
		Sound.fromPcm(haxe.io.Bytes.alloc(64), 48000, 1, 1024);
		assert(stub.testPcmCreateLen == 64, "fromPcm clamps a lied length to the buffer size");
		stub.testPcmCreateLen = -999;
		Sound.fromPcm(haxe.io.Bytes.alloc(64), 48000, 1, 32);
		assert(stub.testPcmCreateLen == 32, "fromPcm passes an honest partial length through");
		stub.testPcmCreateLen = -999;
		Sound.fromPcm(haxe.io.Bytes.alloc(64), 48000, 1);
		assert(stub.testPcmCreateLen == 64, "fromPcm sentinel means the whole buffer");
		stub.testPcmCreateLen = -999;
		Sound.fromPcm(haxe.io.Bytes.alloc(64), 48000, 1, -5);
		assert(stub.testPcmCreateLen == -5, "fromPcm surfaces a negative non-sentinel to the backend");
		stub.testPcmCreateLen = -999;
		assert(Sound.fromPcm(null, 48000, 1).isNull(), "fromPcm null bytes rejected");
		assert(stub.testPcmCreateLen == -999, "fromPcm null bytes never reach the backend");
		assert(pcmSound.play().isNull(), "coresound play null");
		assert(!pcmSound.setDefaults(24000, 128).isOk(), "coresound defaults result");
		assert(pcmSound.getDefaults() == null, "coresound defaults default");
		assert(!pcmSound.setLoopPoints(0, 100).isOk(), "coresound loopPoints result");
		assert(pcmSound.getLoopPoints() == null, "coresound loopPoints default");
		assert(!pcmSound.setMode(ChannelMode.LOOP_NORMAL).isOk(), "coresound setMode result");
		assert(pcmSound.getMode() == 0, "coresound mode default");
		assert(pcmSound.getFormat() == null, "coresound format default");
		assert(pcmSound.getOpenState() == FmodOpenState.ERROR, "coresound openState default");

		assert(CoreSystem.getChannelsPlaying() == null, "sys channelsPlaying default");
		assert(!CoreSystem.mixerSuspend().isOk(), "sys mixerSuspend result");
		assert(!CoreSystem.mixerResume().isOk(), "sys mixerResume result");
		assert(CoreSystem.getSoftwareFormat() == null, "sys softwareFormat default");

		// Slice-4 surface on the stub
		assert(pcmSound.addSyncPoint(50, "mid").isNull(), "sound addSyncPoint null point");
		assert(!pcmSound.deleteSyncPoint(0).isOk(), "sound deleteSyncPoint result");
		assert(pcmSound.getSyncPointCount() == 0, "sound syncPointCount default");
		assert(pcmSound.getNumSyncPoints() == 0, "sound getNumSyncPoints default");
		assert(pcmSound.getSyncPoint(0).isNull(), "sound getSyncPoint null");
		assert(pcmSound.getSyncPointInfo(0) == null, "sound getSyncPointInfo default");

		// Time units are an optional trailing parameter, milliseconds when left out
		assert(pcmSound.getLength() == -1 && pcmSound.getLength(FmodTimeUnit.PCM) == -1, "sound length takes a unit");
		assert(!pcmSound.setLoopPoints(0, 100, FmodTimeUnit.PCM).isOk(), "sound setLoopPoints takes a unit");
		assert(pcmSound.getLoopPoints(FmodTimeUnit.PCMBYTES) == null, "sound getLoopPoints takes a unit");
		assert(pcmSound.addSyncPoint(50, "mid", FmodTimeUnit.PCM).isNull(), "sound addSyncPoint takes a unit");
		assert(pcmSound.getSyncPointInfo(0, FmodTimeUnit.PCM) == null, "sound getSyncPointInfo takes a unit");
		assert(pcmSound.getOpenStateInfo() == null, "sound openStateInfo default");
		assert(pcmSound.getOpenState() == FmodOpenState.ERROR, "sound openState stays a plain state");

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
		assert(CoreSystem.getDriverInfo(0) == null, "sys getDriverInfo default");
		assert(CoreSystem.attachChannelGroupToPort(FmodPortType.MUSIC, FmodPortIndex.NONE, ChannelGroup.master()) == FmodResult.FMOD_ERR_UNSUPPORTED,
			"sys attachChannelGroupToPort default");
		assert(CoreSystem.attachChannelGroupToPort(FmodPortType.VOICE, 0, ChannelGroup.master(), true) == FmodResult.FMOD_ERR_UNSUPPORTED,
			"sys attachChannelGroupToPort passthru default");
		assert(CoreSystem.detachChannelGroupFromPort(ChannelGroup.master()) == FmodResult.FMOD_ERR_UNSUPPORTED,
			"sys detachChannelGroupFromPort default");
		assert(FmodLimits.MAX_CHANNEL_WIDTH == 32 && FmodLimits.MAX_LISTENERS == 8 && FmodLimits.MAX_SYSTEMS == 8
			&& FmodLimits.REVERB_MAXINSTANCES == 4 && FmodLimits.STUDIO_LOAD_MEMORY_ALIGNMENT == 32, "FmodLimits values");
		assert((FmodPortIndex.NONE : Int) == -1, "FmodPortIndex.NONE crosses as -1");
		assert((FmodThreadAffinity.CORE_15 : Int) == 0x8000 && (FmodThreadAffinity.CORE_ALL : Int) == 0, "FmodThreadAffinity masks");

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
		assert(StudioSystem.loadBankMemory(haxe.io.Bytes.alloc(16), FmodLoadBankFlags.NONBLOCKING).isNull(), "sys loadBankMemory flags null");
		assert(!StudioSystem.startCommandCapture("x.cmd.txt").isOk(), "sys startCapture result");
		assert(!StudioSystem.startCommandCapture("x.cmd.txt", FmodCommandCaptureFlags.FILEFLUSH | FmodCommandCaptureFlags.SKIP_INITIAL_STATE).isOk(), "sys startCapture flags result");
		assert(StudioSystem.loadCommandReplay("x.cmd.txt", FmodCommandReplayFlags.FAST_FORWARD).isNull(), "sys loadReplay flags null");
		assert(!StudioSystem.stopCommandCapture().isOk(), "sys stopCapture result");
		var replay = StudioSystem.loadCommandReplay("x.cmd.txt");
		assert(replay.isNull(), "sys loadReplay null");
		assert(!replay.isValid(), "replay invalid");
		assert(!replay.start().isOk(), "replay start result");
		assert(!replay.stop().isOk(), "replay stop result");
		assert(!replay.setPaused(true).isOk(), "replay setPaused result");
		assert(!replay.getPaused(), "replay paused default");
		assert(!replay.seekToTime(0).isOk(), "replay seek result");
		assert(!replay.seekToTime(1.5).isOk(), "replay seek seconds result");
		assert(replay.getCommandAtTime(1.5) == -1, "replay command at time default");
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
		assert(!channel.setLoopPoints(0, 100, FmodTimeUnit.PCM).isOk(), "chan setLoopPoints takes a unit");
		assert(channel.getLoopPoints(FmodTimeUnit.PCM) == null, "chan getLoopPoints takes a unit");
		assert(channel.getPosition(FmodTimeUnit.PCM) == -1, "chan getPosition takes a unit");
		assert(!channel.setPosition(0, FmodTimeUnit.PCM).isOk(), "chan setPosition takes a unit");
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
		assert(haxefmod.studio.CallbackDispatcher.channelRouter != null, "chan router self-installed");
		haxefmod.studio.CallbackDispatcher.deliver(1234, ChannelCallbacks.TYPE_SYNCPOINT, 3, 0, 0, 0, 0, 0, "");
		haxefmod.studio.CallbackDispatcher.deliver(1234, ChannelCallbacks.TYPE_END, 0, 0, 0, 0, 0, 0, "");
		haxefmod.studio.CallbackDispatcher.deliver(1234, ChannelCallbacks.TYPE_END, 0, 0, 0, 0, 0, 0, "");
		assert(received.length == 2, "chan events delivered");
		assert(received[0].match(SyncPoint(3)), "chan syncpoint payload");
		assert(received[1].match(End), "chan end payload");
		// Event-instance records still dispatch normally with the router in
		// place (the router must decline non-channel types)
		var eviEvents = 0;
		haxefmod.studio.CallbackDispatcher.setCallback(1235, function(_) eviEvents++, 0x20);
		haxefmod.studio.CallbackDispatcher.deliver(1235, 0x20, 0, 0, 0, 0, 0, 0, "");
		assert(eviEvents == 1, "event dispatch unaffected by chan router");
		haxefmod.studio.CallbackDispatcher.remove(1235);
		ChannelCallbacks.clearAll();
	}

	// The ChannelGroup half of the ChannelControl surface on the stub, the
	// setDelay default, the mix matrix hop bounds (pure Haxe checks that
	// never reach the backend), the connection from addGroup, and the
	// connection-narrowed disconnect.
	static function testChannelControlParity() {
		var group = ChannelGroup.create("parity");
		var stale:ChannelGroup = cast 0x7fff0001;
		assert(group.get3DOcclusion() == null, "cg occlusion getter default");
		assert(group.getDelay() == null, "cg delay getter default");
		assert(group.getLowPassGain() == 0.0, "cg lowPassGain getter default");
		assert(!group.isPlaying(), "cg isPlaying default");
		assert(!stale.isPlaying(), "cg isPlaying stale");
		assert(group.addGroupConnection(group).isNull(), "cg addGroupConnection default");
		assert(!group.addGroup(group, false).isOk(), "cg addGroup no propagate result");

		var dsp = Dsp.create(DspType.LOWPASS);
		var conn:DspConnection = cast 0;
		assert(!dsp.disconnectFrom(dsp, conn).isOk(), "dsp disconnectFrom connection result");

		// The hop widens each row, and a hop below the input count or above 32 is refused before the backend
		var channel:Channel = cast 0;
		var wide:Array<Float> = [1, 0, 0, 0, 0, 1, 0, 0];
		assert(channel.setMixMatrix(wide, 2, 2, 4) == FmodResult.FMOD_ERR_UNSUPPORTED, "chan mixMatrix hop reaches backend");
		assert(channel.setMixMatrix(wide, 2, 2, 1) == FmodResult.FMOD_ERR_INVALID_PARAM, "chan mixMatrix hop too narrow");
		assert(channel.setMixMatrix(wide, 2, 2, 33) == FmodResult.FMOD_ERR_INVALID_PARAM, "chan mixMatrix hop too wide");
		assert(channel.setMixMatrix([1, 0, 0, 1], 2, 2, 4) == FmodResult.FMOD_ERR_INVALID_PARAM, "chan mixMatrix hop needs the wide array");
		assert(channel.setMixMatrix(wide, 0, 2) == FmodResult.FMOD_ERR_INVALID_PARAM, "chan mixMatrix zero rows");
		assert(channel.setMixMatrix(wide, 33, 1) == FmodResult.FMOD_ERR_INVALID_PARAM, "chan mixMatrix too many rows");
		assert(channel.getMixMatrix() == null, "chan mixMatrix getter no dims default");
		assert(channel.getMixMatrix(0, 0, 4) == null, "chan mixMatrix getter hop default");
		assert(group.setMixMatrix(wide, 2, 2, 4) == FmodResult.FMOD_ERR_UNSUPPORTED, "cg mixMatrix hop reaches backend");
		assert(group.setMixMatrix(wide, 2, 2, 1) == FmodResult.FMOD_ERR_INVALID_PARAM, "cg mixMatrix hop too narrow");
		assert(group.getMixMatrix() == null, "cg mixMatrix getter no dims default");
		assert(conn.setMixMatrix(wide, 2, 2, 4) == FmodResult.FMOD_ERR_UNSUPPORTED, "conn mixMatrix hop reaches backend");
		assert(conn.setMixMatrix(wide, 2, 2, 33) == FmodResult.FMOD_ERR_INVALID_PARAM, "conn mixMatrix hop too wide");
		assert(conn.getMixMatrix() == null, "conn mixMatrix getter no dims default");

		// The read side unpacks the scratch layout: two rows of four with a 2 by 2 region kept
		haxefmod.studio.native.Scratch.writeI(0, 2);
		haxefmod.studio.native.Scratch.writeI(1, 2);
		for (i in 0...8) haxefmod.studio.native.Scratch.writeF(i, wide[i]);
		var hopped = haxefmod.core.MixMatrix.read(8, 0, 0, 4);
		assert(hopped.matrix.length == 8 && hopped.matrix[5] == 1 && hopped.outChannels == 2 && hopped.inChannels == 2, "mixMatrix read hop");
		var trimmed = haxefmod.core.MixMatrix.read(8, 2, 2, 4);
		assert(trimmed.matrix.length == 4 && trimmed.matrix[0] == 1 && trimmed.matrix[3] == 1, "mixMatrix read region");
		var packed = haxefmod.core.MixMatrix.read(4, 0, 0, 0);
		assert(packed.matrix.length == 4 && packed.matrix[1] == 0, "mixMatrix read packed");
		var oneRow = haxefmod.core.MixMatrix.read(4, 1, 0, 0);
		assert(oneRow.matrix.length == 2 && oneRow.outChannels == 2, "mixMatrix read row cap keeps reported counts");

		// Group callbacks share the channel map and clear through the group
		// native. The stub creates no groups, so a fake handle stands in.
		var received:Array<haxefmod.core.ChannelEvent> = [];
		group = cast 4321;
		group.setCallback(function(e) received.push(e));
		assert(StudioSystem.lastResult() == FmodResult.FMOD_ERR_UNSUPPORTED, "cg setCallback reaches the stub");
		haxefmod.studio.CallbackDispatcher.deliver((group : Int), ChannelCallbacks.TYPE_OCCLUSION, haxe.io.FPHelper.floatToI32(0.25), 0, 0, 0, 0, 0.5, "");
		haxefmod.studio.CallbackDispatcher.deliver((group : Int), ChannelCallbacks.TYPE_VIRTUALVOICE, 1, 0, 0, 0, 0, 0, "");
		assert(received.length == 2, "cg events delivered");
		assert(received[0].match(Occlusion(0.5, 0.25)), "cg occlusion payload");
		assert(received[1].match(VirtualVoice(true)), "cg virtual voice payload");
		group.clearCallback();
		haxefmod.studio.CallbackDispatcher.deliver((group : Int), ChannelCallbacks.TYPE_OCCLUSION, 0, 0, 0, 0, 0, 0.5, "");
		assert(received.length == 2, "cg clearCallback stops delivery");
		group.setCallback(function(e) received.push(e));
		group.release();
		haxefmod.studio.CallbackDispatcher.deliver((group : Int), ChannelCallbacks.TYPE_OCCLUSION, 0, 0, 0, 0, 0, 0.5, "");
		assert(received.length == 2, "cg release removes the handler");
		ChannelCallbacks.clearAll();
	}

	static function testSystemCallbackStub() {
		// The stub backend reports UNSUPPORTED from both mask setters, and
		// the wrappers route to them
		assert(haxefmod.studio.native.NativeStudio.sys_set_callback_mask(0x3) == FmodResult.FMOD_ERR_UNSUPPORTED,
			"sys_set_callback_mask stub unsupported");
		assert(haxefmod.studio.native.NativeStudio.sys_set_studio_callback_mask(0x1f) == FmodResult.FMOD_ERR_UNSUPPORTED,
			"sys_set_studio_callback_mask stub unsupported");
		assert(haxefmod.studio.SystemCallbacks.DEFAULT_CORE_MASK == 0x3, "default core mask");
		assert(haxefmod.studio.SystemCallbacks.DEFAULT_STUDIO_MASK == 0x1c, "default studio mask leaves pre/post update out");
		assert(haxefmod.studio.SystemCallbacks.decode(0x20000104, "bank:/X").match(BankUnload("bank:/X")), "decode bank unload");
		assert(haxefmod.studio.SystemCallbacks.decode(0x20000001, "") == DeviceListChanged, "decode core type");
		assert(haxefmod.studio.SystemCallbacks.decode(0x20000101, "") == PreUpdate, "decode studio type");
		assert(haxefmod.studio.SystemCallbacks.decode(0x20000040, "") == null, "decode unknown type");
	}
	static function testCompletenessTail():Void {
		// Sound cone and rolloff distances
		var sound = Sound.fromPcm(haxe.io.Bytes.alloc(16), 48000, 1);
		assert(!sound.set3DConeSettings(30, 60, 0.5).isOk(), "sound cone result");
		assert(sound.get3DConeSettings() == null, "sound cone default");
		assert(!sound.set3DMinMaxDistance(1, 100).isOk(), "sound minmax result");
		assert(sound.get3DMinMaxDistance() == null, "sound minmax default");

		// Channel and group DSP chain positions, fade points, mix matrices
		var channel:Channel = cast 0;
		var dsp = Dsp.create(DspType.LOWPASS);
		assert(!channel.setDspIndex(dsp, 1).isOk(), "chan setDspIndex result");
		assert(channel.getDspIndex(dsp) == -1, "chan dspIndex default");
		assert(channel.getChannelGroup().isNull(), "chan channelGroup default");
		assert(channel.getFadePoints() == null, "chan fadePoints default");
		assert(channel.getMixMatrix(2, 2) == null, "chan mixMatrix getter default");
		var group = ChannelGroup.create("tail");
		assert(!group.setDspIndex(dsp, 1).isOk(), "cg setDspIndex result");
		assert(group.getDspIndex(dsp) == -1, "cg dspIndex default");
		assert(group.getFadePoints() == null, "cg fadePoints default");
		assert(group.getMixMatrix(2, 2) == null, "cg mixMatrix getter default");

		// Sound group name and enumeration
		var soundGroup = SoundGroup.create("tail");
		assert(soundGroup.getName() == "", "sg name default");
		assert(soundGroup.getSound(0).isNull(), "sg getSound default");

		// System queries
		assert(CoreSystem.getChannel(0).isNull(), "sys getChannel default");
		assert(CoreSystem.getOutput() == -1, "sys getOutput default");
		assert(CoreSystem.getSpeakerModeChannels(3) == 0, "sys speakerModeChannels default");
		assert(CoreSystem.getDefaultMixMatrix(3, 3) == null, "sys defaultMixMatrix default");
		assert(haxefmod.studio.native.NativeStudio.sys_get_default_mix_matrix(3, 3, 0) == 0,
			"sys_get_default_mix_matrix stub zero");

		// DSP descriptors and channel formats
		assert(dsp.getParameterInfo(0) == null, "dsp parameterInfo default");
		assert(dsp.getInfo() == null, "dsp info default");
		assert(dsp.getParameterData(0) == null, "dsp parameterData default");
		assert(dsp.getOverallGain() == null, "dsp overallGain default");
		assert(dsp.getOverallGain(3) == null, "dsp overallGain by index default");
		assert(dsp.getLoudnessMeterInfo() == null, "dsp loudnessMeterInfo default");
		assert(dsp.getFftSpectrumInfo() == null, "dsp fftSpectrumInfo default");
		assert(dsp.getInputMetering() == null, "dsp inputMetering default");
		assert(dsp.getMetering(true) == null, "dsp metering input default");
		var origin:Fmod3DAttributes = {position: {x: 0, y: 0, z: 0}, velocity: {x: 0, y: 0, z: 0}, forward: {x: 0, y: 0, z: 1}, up: {x: 0, y: 1, z: 0}};
		assert(!dsp.setParameter3DAttributes(0, origin).isOk(), "dsp setParameter3DAttributes result");
		assert(!dsp.setParameter3DAttributes(0, origin, origin).isOk(), "dsp setParameter3DAttributes relative result");
		assert(dsp.setParameter3DAttributes(0, null) == FmodResult.FMOD_ERR_INVALID_PARAM, "dsp setParameter3DAttributes null absolute");
		assert(!dsp.setParameter3DAttributesMulti(0, origin, [origin]).isOk(), "dsp setParameter3DAttributesMulti result");
		assert(dsp.setParameter3DAttributesMulti(0, origin, []) == FmodResult.FMOD_ERR_INVALID_PARAM, "dsp setParameter3DAttributesMulti empty");
		assert(dsp.setParameter3DAttributesMulti(0, origin, [for (_ in 0...9) origin]) == FmodResult.FMOD_ERR_INVALID_PARAM, "dsp setParameter3DAttributesMulti oversized");
		assert(dsp.setParameter3DAttributesMulti(0, origin, null) == FmodResult.FMOD_ERR_INVALID_PARAM, "dsp setParameter3DAttributesMulti null list");
		assert(Dsp.LOUDNESS_INFO_BYTES == 292, "loudness payload size matches FMOD_DSP_LOUDNESS_METER_INFO_TYPE");
		assert(Dsp.MAX_LISTENERS == 8, "MAX_LISTENERS matches FMOD_MAX_LISTENERS");
		assert(dsp.getDataParameterIndex(-4) == -1, "dsp dataParameterIndex default");
		assert(!dsp.setChannelFormat(0, 2, 3).isOk(), "dsp setChannelFormat result");
		assert(dsp.getChannelFormat() == null, "dsp channelFormat default");
		assert(dsp.getOutputChannelFormat(0, 2, 3) == null, "dsp outputChannelFormat default");
		assert(Dsp.PARAMETER_FLOAT == 0 && Dsp.PARAMETER_DATA == 3, "dsp parameter type constants");

		// Connection mix matrix, including the pure bounds checks
		var conn:DspConnection = cast 0;
		assert(conn.setMixMatrix([1, 0, 0, 1], 2, 2) == FmodResult.FMOD_ERR_UNSUPPORTED, "conn mixMatrix stub unsupported");
		assert(conn.setMixMatrix([1], 2, 2) == FmodResult.FMOD_ERR_INVALID_PARAM, "conn mixMatrix bounds");
		assert(conn.setMixMatrix([], 40, 40) == FmodResult.FMOD_ERR_INVALID_PARAM, "conn mixMatrix capacity");
		assert(conn.getMixMatrix(2, 2) == null, "conn mixMatrix getter default");
	}

	// Replay inspection, the DSP lock, sound info, memory and file stats,
	// the network settings, and speaker positions all route through the
	// stub like everything else, so the checks are the failure defaults.
	static function testSysExtras():Void {
		var replay:CommandReplay = cast 0;
		assert(replay.getCommandCount() == -1, "replay getCommandCount default");
		assert(replay.getCommandInfo(0) == null, "replay getCommandInfo default");
		assert(replay.getCommandString(0) == "", "replay getCommandString default");
		assert(replay.getCommandAtTime(0) == -1, "replay getCommandAtTime default");
		assert(!replay.seekToCommand(0).isOk(), "replay seekToCommand result");
		assert(replay.getPlaybackState() == FmodPlaybackState.STOPPED, "replay getPlaybackState default");
		assert(!replay.setBankPath("banks").isOk(), "replay setBankPath result");

		assert(!StudioSystem.lockDsp().isOk(), "sys lockDsp result");
		assert(!StudioSystem.unlockDsp().isOk(), "sys unlockDsp result");
		assert(StudioSystem.getSoundInfo("missing") == null, "sys getSoundInfo default");
		assert(StudioSystem.getMemoryStats() == null, "sys getMemoryStats default");
		assert(StudioSystem.getMemoryStats(true) == null, "sys getMemoryStats blocking default");
		assert(StudioSystem.getFileUsage() == null, "sys getFileUsage default");

		assert(!CoreSystem.setNetworkProxy("proxy:8080").isOk(), "sys setNetworkProxy result");
		assert(CoreSystem.getNetworkProxy() == "", "sys getNetworkProxy default");
		assert(!CoreSystem.setNetworkTimeout(1000).isOk(), "sys setNetworkTimeout result");
		assert(CoreSystem.getNetworkTimeout() == -1, "sys getNetworkTimeout default");
		assert(!CoreSystem.setSpeakerPosition(0, -1, 1, true).isOk(), "sys setSpeakerPosition result");
		assert(CoreSystem.getSpeakerPosition(0) == null, "sys getSpeakerPosition default");
	}

	static function testSoundExtrasStub() {
		// The stub reports failure from every sound extra and the wrappers
		// route to it, so the abstract methods surface -1, 0, NULL, or null
		var sound:Sound = cast 1;
		assert(sound.getMusicNumChannels() == -1, "getMusicNumChannels stub -1");
		assert(sound.setMusicChannelVolume(0, 0.5) == FmodResult.FMOD_ERR_UNSUPPORTED, "setMusicChannelVolume stub unsupported");
		assert(sound.getMusicChannelVolume(0) == 0.0, "getMusicChannelVolume stub 0");
		assert(sound.setMusicSpeed(1.5) == FmodResult.FMOD_ERR_UNSUPPORTED, "setMusicSpeed stub unsupported");
		assert(sound.getMusicSpeed() == 0.0, "getMusicSpeed stub 0");
		assert(sound.getNumSubSounds() == -1, "getNumSubSounds stub -1");
		assert(sound.getSubSound(0).isNull(), "getSubSound stub NULL");
		assert(sound.getSubSoundParent().isNull(), "getSubSoundParent stub NULL");
		assert(sound.getNumTags() == -1, "getNumTags stub -1");
		assert(sound.getNumTagsUpdated() == -1, "getNumTagsUpdated stub -1");
		assert(sound.getTag(null, 0) == null, "getTag stub null");
		assert(sound.getTag("TITLE") == null, "getTag by name stub null");
		assert(StudioSystem.getAdvancedSettings() == null, "getAdvancedSettings stub null");
		assert(StudioSystem.getStudioAdvancedSettings() == null, "getStudioAdvancedSettings stub null");
		assert(haxefmod.studio.native.NativeStudio.sys_get_advanced_settings() == FmodResult.FMOD_ERR_UNSUPPORTED,
			"sys_get_advanced_settings stub unsupported");
		assert(haxefmod.studio.native.NativeStudio.sys_get_studio_advanced_settings() == FmodResult.FMOD_ERR_UNSUPPORTED,
			"sys_get_studio_advanced_settings stub unsupported");
		assert(haxefmod.studio.native.NativeStudio.core_sound_get_tag_string(1, "", 0) == "", "core_sound_get_tag_string stub empty");
		// The resolver turns a missing key into "" so no null reaches the shims
		var resolved = haxefmod.runtime.FmodSettings.FmodSettingsResolver.resolve({numChannels: 32});
		assert(resolved.encryptionKey == "", "encryptionKey resolves to empty");
		assert(resolved.randomSeed == 0 && resolved.vol0VirtualVol == 0.0 && resolved.commandQueueSize == 0,
			"advanced settings default to zero");
		var keyed = haxefmod.runtime.FmodSettings.FmodSettingsResolver.resolve({encryptionKey: "k", studioUpdatePeriod: 10});
		assert(keyed.encryptionKey == "k" && keyed.studioUpdatePeriod == 10, "advanced settings pass through");
	}

	static function testLastSevenStub():Void {
		// The stub reports failure from each of the last seven bindings and
		// the wrappers route to it, so the abstracts surface NULL, null,
		// UNSUPPORTED, or 0
		var dsp:Dsp = cast 1;
		var conn:DspConnection = cast 1;
		assert(dsp.addInputPreallocated(dsp, conn).isNull(), "addInputPreallocated stub NULL");
		var channel:Channel = cast 1;
		assert(channel.setMixLevelsInput([1.0, 0.5]) == FmodResult.FMOD_ERR_UNSUPPORTED, "channel setMixLevelsInput stub unsupported");
		assert(channel.setMixLevelsInput(null) == FmodResult.FMOD_ERR_INVALID_PARAM, "channel setMixLevelsInput null rejected");
		assert(channel.setMixLevelsInput([for (_ in 0...33) 1.0]) == FmodResult.FMOD_ERR_INVALID_PARAM, "channel setMixLevelsInput 33 levels rejected");
		assert(channel.setMixLevelsInput([]) == FmodResult.FMOD_ERR_INVALID_PARAM, "channel setMixLevelsInput empty rejected");
		assert(channel.setMixLevelsOutput(1, 1, 0, 0, 0, 0, 0, 0) == FmodResult.FMOD_ERR_UNSUPPORTED, "channel setMixLevelsOutput stub unsupported");
		var group:ChannelGroup = cast 1;
		assert(group.setMixLevelsInput([1.0]) == FmodResult.FMOD_ERR_UNSUPPORTED, "group setMixLevelsInput stub unsupported");
		assert(group.setMixLevelsInput([for (_ in 0...33) 1.0]) == FmodResult.FMOD_ERR_INVALID_PARAM, "group setMixLevelsInput 33 levels rejected");
		assert(group.setMixLevelsOutput(1, 1, 0, 0, 0, 0, 0, 0) == FmodResult.FMOD_ERR_UNSUPPORTED, "group setMixLevelsOutput stub unsupported");
		assert(CoreSystem.getDspInfoByType(DspType.FADER) == null, "getDspInfoByType stub null");
		assert(haxefmod.studio.native.NativeStudio.sys_get_dsp_info_by_type(DspType.FADER) == "", "sys_get_dsp_info_by_type stub empty");
		assert(CoreSystem.getOutputByPlugin() == 0, "getOutputByPlugin stub 0");
		assert(CoreSystem.setOutputByPlugin(4) == FmodResult.FMOD_ERR_UNSUPPORTED, "setOutputByPlugin stub unsupported");
		var replay:CommandReplay = cast 1;
		assert(replay.getCurrentCommand() == null, "getCurrentCommand stub null");
		assert(haxefmod.studio.native.NativeStudio.replay_get_current_command(1) == -1, "replay_get_current_command stub -1");
	}

	static function testValueEnums():Void {
		// The retyped signatures take the enum abstracts and every value
		// matches the FMOD header number
		assert(CoreSystem.setSpeakerPosition(FmodSpeaker.FRONT_LEFT, -1, 1, true) == FmodResult.FMOD_ERR_UNSUPPORTED, "setSpeakerPosition takes FmodSpeaker");
		assert(CoreSystem.getSpeakerPosition(FmodSpeaker.NONE) == null, "getSpeakerPosition takes FmodSpeaker");
		assert(CoreSystem.getSpeakerModeChannels(FmodSpeakerMode.STEREO) == 0, "getSpeakerModeChannels takes FmodSpeakerMode");
		assert(CoreSystem.getDefaultMixMatrix(FmodSpeakerMode.MONO, FmodSpeakerMode._5POINT1) == null, "getDefaultMixMatrix takes FmodSpeakerMode");
		var output:FmodOutputType = CoreSystem.getOutput();
		assert((output : Int) == -1 || output == FmodOutputType.AUTODETECT, "getOutput returns FmodOutputType");
		var format = CoreSystem.getSoftwareFormat();
		assert(format == null, "getSoftwareFormat stub null");
		var dsp:Dsp = cast 1;
		assert(dsp.setChannelFormat(FmodChannelMask.STEREO, 2, FmodSpeakerMode.STEREO) == FmodResult.FMOD_ERR_UNSUPPORTED, "setChannelFormat takes the mask and mode enums");
		assert(dsp.getOutputChannelFormat(FmodChannelMask._5POINT1, 6, FmodSpeakerMode._5POINT1) == null, "getOutputChannelFormat takes the mask and mode enums");
		assert(StudioSystem.getRecordDriverInfo(0) == null, "getRecordDriverInfo stub null");
		var settings:haxefmod.runtime.FmodSettings = {speakerMode: FmodSpeakerMode.QUAD};
		assert(settings.speakerMode == FmodSpeakerMode.QUAD, "FmodSettings.speakerMode takes FmodSpeakerMode");
		var speaker:FmodSpeaker = 3;
		assert(speaker == FmodSpeaker.LOW_FREQUENCY, "FmodSpeaker converts from Int");
		assert((FmodSpeaker.NONE : Int) == -1, "FMOD_SPEAKER_NONE");
		assert((FmodSpeaker.MAX : Int) == 12, "FMOD_SPEAKER_MAX");
		assert((FmodSpeakerMode._7POINT1POINT4 : Int) == 8, "FMOD_SPEAKERMODE_7POINT1POINT4");
		assert((FmodOutputType.WAVWRITER : Int) == 3, "FMOD_OUTPUTTYPE_WAVWRITER");
		assert((FmodOutputType.OHAUDIO : Int) == 21, "FMOD_OUTPUTTYPE_OHAUDIO");
		assert((FmodDriverState.DEFAULT : Int) == 2, "FMOD_DRIVER_STATE_DEFAULT");
		assert((FmodChannelMask._7POINT1 : Int) == 0xFF, "FMOD_CHANNELMASK_7POINT1");
		assert((FmodChannelMask.BACK_CENTER : Int) == 0x100, "FMOD_CHANNELMASK_BACK_CENTER");
		assert((FmodTimeUnit.RAWBYTES : Int) == 8, "FMOD_TIMEUNIT_RAWBYTES");
		assert((FmodTimeUnit.MODPATTERN : Int) == 0x400, "FMOD_TIMEUNIT_MODPATTERN");
		assert((DspChannelMixOutput.ALL7POINT1POINT4 : Int) == 7, "FMOD_DSP_CHANNELMIX_OUTPUT_ALL7POINT1POINT4");
		assert((DspEchoDelayChangeMode.NONE : Int) == 2, "FMOD_DSP_ECHO_DELAYCHANGEMODE_NONE");
		assert((DspFftDownmix.MONO : Int) == 1, "FMOD_DSP_FFT_DOWNMIX_MONO");
		assert((DspFftWindow.BLACKMANHARRIS : Int) == 5, "FMOD_DSP_FFT_WINDOW_BLACKMANHARRIS");
		assert((DspLoudnessMeterState.RESET_INTEGRATED : Int) == -3, "FMOD_DSP_LOUDNESS_METER_STATE_RESET_INTEGRATED");
		assert((DspMultibandDynamicsMode.EXPAND_DOWN : Int) == 4, "FMOD_DSP_MULTIBAND_DYNAMICS_MODE_EXPAND_DOWN");
		assert((DspMultibandEqFilter.HIGHPASS_6DB : Int) == 14, "FMOD_DSP_MULTIBAND_EQ_FILTER_HIGHPASS_6DB");
		assert((DspPanModeType.SURROUND : Int) == 2, "FMOD_DSP_PAN_MODE_SURROUND");
		assert((DspPan2DStereoModeType.DISCRETE : Int) == 1, "FMOD_DSP_PAN_2D_STEREO_MODE_DISCRETE");
		assert((DspPan3DRolloffType.CUSTOM : Int) == 4, "FMOD_DSP_PAN_3D_ROLLOFF_CUSTOM");
		assert((DspPan3DExtentModeType.OFF : Int) == 2, "FMOD_DSP_PAN_3D_EXTENT_MODE_OFF");
		assert((DspThreeEqCrossoverSlope._48DB : Int) == 2, "FMOD_DSP_THREE_EQ_CROSSOVERSLOPE_48DB");
		assert((DspTransceiverSpeakerMode.AUTO : Int) == -1, "FMOD_DSP_TRANSCEIVER_SPEAKERMODE_AUTO");
		// setParameterInt still takes a plain Int, the value enums convert to it
		assert(dsp.setParameterInt(1, DspFftWindow.HANNING) == FmodResult.FMOD_ERR_UNSUPPORTED, "setParameterInt takes a value enum through Int");
	}

	static function testDspParameters():Void {
		// The parameter index enums are plain ints in header order, and the
		// Dsp setters and getters take them without a cast
		assert((DspChannelMix.OUTPUTGROUPING : Int) == 0, "DspChannelMix.OUTPUTGROUPING is 0");
		assert((DspChannelMix.GAIN_CH0 : Int) == 1, "DspChannelMix.GAIN_CH0 is 1");
		assert((DspChannelMix.OUTPUT_CH31 : Int) == 64, "DspChannelMix.OUTPUT_CH31 is 64");
		assert((DspLowpass.CUTOFF : Int) == 0 && (DspLowpass.RESONANCE : Int) == 1, "DspLowpass indices");
		assert((DspOscillator.RATE : Int) == 1, "DspOscillator.RATE is 1");
		assert((DspEcho.DELAYCHANGEMODE : Int) == 4, "DspEcho.DELAYCHANGEMODE is 4");
		assert((DspPan.MODE : Int) == 0 && (DspPan._2D_STEREO_MODE : Int) == 6, "DspPan indices keep the leading underscore");
		assert((DspFft.WINDOW : Int) == 1 && (DspFft.SPECTRUMDATA : Int) == 4, "DspFft indices");
		assert((DspSfxReverb.DECAYTIME : Int) == 0, "DspSfxReverb.DECAYTIME is 0");
		assert((DspObjectPan.OVERRIDE_RANGE : Int) == 10, "DspObjectPan.OVERRIDE_RANGE is 10");
		assert((DspMultibandDynamics.C_RESPONSE_DATA : Int) == 27, "DspMultibandDynamics.C_RESPONSE_DATA is 27");
		var dsp:Dsp = cast 1;
		assert(dsp.setParameter(DspChannelMix.GAIN_CH0, -6) == FmodResult.FMOD_ERR_UNSUPPORTED, "setParameter accepts DspChannelMix");
		assert(dsp.setParameterInt(DspChannelMix.OUTPUTGROUPING, 1) == FmodResult.FMOD_ERR_UNSUPPORTED, "setParameterInt accepts DspChannelMix");
		assert(dsp.setParameterBool(DspFft.IMMEDIATE_MODE, true) == FmodResult.FMOD_ERR_UNSUPPORTED, "setParameterBool accepts DspFft");
		assert(dsp.getParameter(DspLowpass.CUTOFF) == 0, "getParameter accepts DspLowpass");
		assert(dsp.getParameterInt(DspPan.MODE) == 0, "getParameterInt accepts DspPan");
		var index:Int = DspLowpass.RESONANCE;
		assert(index == 1, "DspLowpass converts to Int implicitly");
	}

	static function testGroupDspChain():Void {
		// The stub reports an empty chain and a null unit for every position
		var group:ChannelGroup = cast 1;
		assert(group.getDspCount() == 0, "cg dspCount default");
		assert(group.getDsp(0).isNull(), "cg getDsp default");
		assert(group.getDsp(ChannelGroup.DSP_TAIL).isNull(), "cg getDsp tail default");
		assert(group.getDsp(ChannelGroup.DSP_FADER).isNull(), "cg getDsp fader default");
		assert(group.getDsp(ChannelGroup.DSP_HEAD).isNull(), "cg getDsp head default");
		assert(ChannelGroup.master().getDspCount() == 0, "cg master dspCount default");
	}

	/**
	 * The signatures retyped from Int to the header enums route through
	 * the stub with the enum values, the old Int constants stay usable as
	 * aliases, and the typedef fields carry the new types.
	 */
	static function testTypedSignatures():Void {
		var sound = Sound.fromPcm(haxe.io.Bytes.alloc(4), 48000, 1);
		assert(sound.getOpenState() == FmodOpenState.ERROR, "typed open state on stub is ERROR");
		assert((FmodOpenState.READY : Int) == 0 && (FmodOpenState.MAX : Int) == 8, "open state values");

		var group = SoundGroup.create("typed");
		assert(!group.setMaxAudibleBehavior(SoundGroupBehavior.STEALLOWEST).isOk(), "typed behavior set routes");
		assert(!group.setMaxAudibleBehavior(SoundGroup.BEHAVIOR_MUTE).isOk(), "behavior alias still accepted");
		assert(group.getMaxAudibleBehavior() == SoundGroupBehavior.FAIL, "typed behavior get default");
		assert(SoundGroup.BEHAVIOR_STEAL_LOWEST == SoundGroupBehavior.STEALLOWEST, "behavior alias value");

		var dsp = Dsp.create(DspType.FADER);
		assert(dsp.addInput(dsp, DspConnectionType.SIDECHAIN).isNull(), "typed addInput routes");
		assert(dsp.addInput(dsp, DspConnection.TYPE_SEND).isNull(), "addInput alias still accepted");
		assert(dsp.addInput(dsp).getType() == DspConnectionType.STANDARD, "typed connection type default");
		assert(DspConnection.TYPE_SEND_SIDECHAIN == DspConnectionType.SEND_SIDECHAIN, "connection alias value");
		assert(dsp.getDataParameterIndex(FmodDspParameterDataType.FFT) == -1, "typed data parameter index routes");
		assert(Dsp.PARAMETER_DATA == FmodDspParameterType.DATA, "parameter type alias value");

		assert(ChannelGroup.DSP_HEAD == (ChannelControlDspIndex.HEAD : Int)
			&& ChannelGroup.DSP_FADER == (ChannelControlDspIndex.FADER : Int)
			&& ChannelGroup.DSP_TAIL == (ChannelControlDspIndex.TAIL : Int), "dsp index aliases");

		var info:FmodCommandInfo = {commandName: "", parentCommandIndex: 0, frameNumber: 0, frameTime: 0,
			instanceType: FmodStudioInstanceType.EVENTINSTANCE, outputType: FmodStudioInstanceType.NONE,
			instanceHandle: 0, outputHandle: 0};
		assert((info.instanceType : Int) == 3 && info.outputType == FmodStudioInstanceType.NONE, "command info typed");
		var desc:FmodParameterDescription = {name: "p", id: {data1: 0, data2: 0}, minimum: 0, maximum: 1, defaultValue: 0,
			type: FmodParameterType.GAME_CONTROLLED, flags: 0, guid: "{0225c47b-e69f-4785-b89c-fd321387934a}"};
		assert((desc.guid : String).length == 38 && desc.guid.data1 == 0x0225c47b, "parameter description carries guid");
		var soundInfo:FmodSoundInfo = {name: "Master.bank", mode: ChannelMode.CREATECOMPRESSEDSAMPLE, length: 4800,
			fileOffset: 2844864, initialSubsound: 0, numSubsounds: 1, subSoundIndex: 0};
		assert(soundInfo.mode == 0x200 && soundInfo.length == 4800, "sound info typed");

		assert(ChannelMode.MODE_3D_LINEARROLLOFF == ChannelMode.LINEAR_ROLLOFF_3D
			&& ChannelMode.MODE_3D_HEADRELATIVE == 0x00040000
			&& ChannelMode.VIRTUAL_PLAYFROMSTART == 0x80000000
			&& ChannelMode.DEFAULT == 0, "channel mode header names and aliases");
		assert((FmodLoadBankFlags.UNENCRYPTED : Int) == 4 && (EventCallbackType.ALL : Int) == -1, "flag additions");
	}

	static function testCoreTypes():Void {
		var stub = haxefmod.studio.native.NativeStudioStub;

		// FmodGuid: a String both ways, fields parsed from the text, equality ignores braces and case
		var guid:FmodGuid = "{0225C47B-E69F-4785-B89C-FD321387934A}";
		assert(guid.data1 == 0x0225c47b && guid.data2 == 0xe69f && guid.data3 == 0x4785, "guid data1-3");
		assert(guid.data4.length == 8 && guid.data4[0] == 0xb8 && guid.data4[7] == 0x4a, "guid data4 bytes");
		assert(guid == FmodGuid.fromString("0225c47b-e69f-4785-b89c-fd321387934a"), "guid equality ignores braces and case");
		assert(guid != FmodGuid.fromString("{1225c47b-e69f-4785-b89c-fd321387934a}"), "guid inequality");
		assert(FmodGuid.fromString("nope").isNull() && FmodGuid.fromString("{0225c47b-e69f-4785-b89c-fd32138793}").isNull(), "guid rejects bad text");
		assert(FmodGuid.NULL.isNull() && !guid.isNull(), "guid null check");
		assert(FmodGuid.fromFields(0x0225c47b, 0xe69f, 0x4785, [0xb8, 0x9c, 0xfd, 0x32, 0x13, 0x87, 0x93, 0x4a]) == guid, "guid from fields");
		assert(FmodGuid.fromString(" 0225C47B-E69F-4785-B89C-FD321387934A ").toString() == "{0225c47b-e69f-4785-b89c-fd321387934a}", "guid normalizes to braced lower case");
		var asString:String = guid;
		assert(asString.length == 38, "guid converts to String");
		assert(StudioSystem.lookupID("event:/x").isNull(), "lookupID returns a null guid on the stub");
		assert(StudioSystem.getEventByID("{0225c47b-e69f-4785-b89c-fd321387934a}").isNull(), "getEventByID takes a string literal");

		// FmodSyncPoint: the index in offset order, -1 is NULL
		var point:FmodSyncPoint = 3;
		assert(point.index() == 3 && !point.isNull() && FmodSyncPoint.NULL.isNull(), "sync point handle");
		var asIndex:Int = point;
		assert(asIndex == 3, "sync point converts to Int");

		// Loop points forward a unit per point, the end unit follows the start unit when left out
		var sound = Sound.fromPcm(haxe.io.Bytes.alloc(64), 48000, 1);
		sound.setLoopPoints(0, 100, FmodTimeUnit.PCM);
		assert(stub.testLastLoopUnits[0] == (FmodTimeUnit.PCM : Int) && stub.testLastLoopUnits[1] == (FmodTimeUnit.PCM : Int), "sound loop end unit follows start unit");
		sound.setLoopPoints(0, 100, FmodTimeUnit.PCM, FmodTimeUnit.MS);
		assert(stub.testLastLoopUnits[0] == (FmodTimeUnit.PCM : Int) && stub.testLastLoopUnits[1] == (FmodTimeUnit.MS : Int), "sound loop units separate");
		sound.getLoopPoints(FmodTimeUnit.PCMBYTES);
		assert(stub.testLastLoopUnits[1] == (FmodTimeUnit.PCMBYTES : Int), "sound getLoopPoints end unit follows");
		var channel:Channel = Channel.NULL;
		channel.setLoopPoints(1, 2, FmodTimeUnit.MS, FmodTimeUnit.PCM);
		assert(stub.testLastLoopUnits[0] == (FmodTimeUnit.MS : Int) && stub.testLastLoopUnits[1] == (FmodTimeUnit.PCM : Int), "channel loop units separate");
		channel.getLoopPoints();
		assert(stub.testLastLoopUnits[0] == (FmodTimeUnit.MS : Int) && stub.testLastLoopUnits[1] == (FmodTimeUnit.MS : Int), "channel getLoopPoints defaults to MS");

		// FmodCreateSoundExInfo packs into the int slots in manifest order
		stub.testLastExInfoInts = null;
		Sound.create("x.wav", false, false, 0, 4, {defaultFrequency: 44100, numChannels: 2, format: FmodSoundFormat.PCM16,
			inclusionList: [1, 3], dlsName: "bank.dls", encryptionKey: "k", fsbGuid: guid, fileOffset: 12, decodeBufferSize: 1024,
			suggestedSoundType: FmodSoundType.WAV, initialSeekPosition: 7, initialSeekPosType: FmodTimeUnit.PCM});
		var ints = stub.testLastExInfoInts;
		assert(ints != null && ints[1] == 12 && ints[2] == 2 && ints[3] == 44100 && ints[4] == (FmodSoundFormat.PCM16 : Int)
			&& ints[5] == 1024 && ints[6] == 4 && ints[9] == (FmodSoundType.WAV : Int) && ints[15] == 7
			&& ints[16] == (FmodTimeUnit.PCM : Int), "exinfo int slots");
		assert(ints != null && ints[19] == 2 && ints[20] == 1 && ints[21] == 3, "exinfo inclusion list");
		assert(stub.testLastExInfoStrings[0] == "bank.dls" && stub.testLastExInfoStrings[1] == "k"
			&& stub.testLastExInfoStrings[2] == (guid : String), "exinfo strings");
		stub.testLastExInfoInts = null;
		Sound.create("x.wav", false, false, 0, 4, {initialSubsound: 1});
		assert(stub.testLastExInfoInts[6] == 1, "exinfo initialSubsound wins over the argument");
		Sound.create("x.wav", true, false, 0, -1, {});
		assert(stub.testLastExInfoInts[6] == 0 && stub.testLastExInfoInts[19] == 0 && stub.testLastExInfoStrings[2] == "",
			"empty exinfo packs zeros");
		assert(stub.testLastCreateSoundMode & ChannelMode.LOOP_NORMAL != 0, "exinfo create keeps the loop flag");
		stub.testLastExInfoInts = null;
		Sound.fromMemory(haxe.io.Bytes.alloc(32), ChannelMode.OPENRAW, -1, {numChannels: 1, defaultFrequency: 8000, format: FmodSoundFormat.PCM8});
		assert(stub.testLastMemoryLen == 32 && stub.testLastMemoryMode == ChannelMode.OPENRAW
			&& stub.testLastExInfoInts[2] == 1 && stub.testLastExInfoInts[3] == 8000, "fromMemory exinfo");
		stub.testLastExInfoInts = null;
		Sound.fromMemory(haxe.io.Bytes.alloc(32));
		assert(stub.testLastExInfoInts == null, "fromMemory without exinfo takes the plain path");

		// FmodVersion and the reverb presets under FMOD's names
		assert(FmodVersion.VERSION == 0x00020312, "FmodVersion matches the linked SDK");
		assert(haxefmod.core.Reverb.ReverbPresets.UNDERWATER.decayTime == Reverb.PRESET_UNDERWATER.decayTime
			&& haxefmod.core.Reverb.ReverbPresets.OFF.wetLevel == -80.0, "reverb presets alias the Reverb statics");
		var b:FmodBool = true;
		assert(b, "FmodBool is Bool");
		var plugin:FmodPluginList = {type: FmodPluginType.DSP, description: 0};
		assert(plugin.type == FmodPluginType.DSP, "plugin list entry typed");

		// PcmStream read callback: pumped from the frame hook, filled by
		// the callback, skipped when it declines
		var stream:PcmStream = 77;
		var calls = 0;
		var seenLen = 0;
		stream.setReadCallback(function(s, data, len) {
			calls++;
			seenLen = len;
			return s == stream ? FmodResult.FMOD_OK : FmodResult.FMOD_ERR_INVALID_PARAM;
		});
		assert(stream.hasReadCallback() && CallbackDispatcher.frameHook != null, "read callback installed");
		stub.testPcmSpace = 0;
		stub.testLastPcmWriteLen = -1;
		PcmStream.pump();
		assert(calls == 0, "read callback skipped with no room");
		stub.testPcmSpace = 256;
		PcmStream.pump();
		assert(calls == 1 && seenLen == 256 && stub.testLastPcmWriteLen == 256, "read callback fills the room");
		stream.setReadCallback(function(s, data, len) return FmodResult.FMOD_ERR_INVALID_PARAM);
		stub.testLastPcmWriteLen = -1;
		PcmStream.pump();
		assert(stub.testLastPcmWriteLen == -1, "a declining read callback writes nothing");
		stream.setReadCallback(function(s, data, len) { s.clearReadCallback(); return FmodResult.FMOD_OK; });
		PcmStream.pump();
		assert(!stream.hasReadCallback(), "read callback may remove itself");
		stream.setReadCallback(function(s, data, len) throw "boom");
		PcmStream.pump();
		assert(stream.hasReadCallback(), "a throwing read callback is contained");
		stream.release();
		assert(!stream.hasReadCallback(), "release drops the read callback");
		PcmStream.NULL.setReadCallback(function(s, data, len) return FmodResult.FMOD_OK);
		assert(!PcmStream.NULL.hasReadCallback(), "null stream takes no read callback");
		stub.testPcmSpace = 0;

		// The callback typedefs are the handler types the setters take
		var eventHandler:EventCallback = function(data) {};
		var channelHandler:haxefmod.core.ChannelEvent.ChannelCallback = function(event) {};
		var systemHandler:haxefmod.studio.SystemCallbacks.SystemCallback = function(event) {};
		EventInstance.NULL.setCallback(eventHandler);
		Channel.NULL.setCallback(channelHandler);
		StudioSystem.setSystemCallback(systemHandler);
		StudioSystem.clearSystemCallback();
		assert(true, "callback typedefs accepted");
	}
}
