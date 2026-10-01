package tests;

import haxefmod.FmodManager;
import haxefmod.core.Channel;
import haxefmod.core.ChannelGroup;
import haxefmod.core.Dsp;
import haxefmod.core.DspConnection;
import haxefmod.core.Geometry;
import haxefmod.core.PcmStream;
import haxefmod.core.Reverb3D;
import haxefmod.core.SoundGroup;
import haxefmod.studio.Bank;
import haxefmod.studio.Bus;
import haxefmod.studio.CallbackDispatcher;
import haxefmod.studio.Callbacks;
import haxefmod.studio.CommandReplay;
import haxefmod.core.Sound;
import haxefmod.studio.EventDescription;
import haxefmod.studio.EventInstance;
import haxefmod.studio.FmodResult;
import haxefmod.studio.StudioSystem;
import haxefmod.studio.UserData;
import haxefmod.studio.Vca;
import haxefmod.studio.native.NativeStudioStub;

class TestUserData {
	static var passed = 0;
	static var failed = 0;

	public static function run():Int {
		Sys.println("--- UserData ---");

		testSetGetClearPerKind();
		testNullHandleAndNullValue();
		testClearedOnRelease();
		testClearedOnDestroyed();
		testSystemAndUnloadAll();
		testDescriptionCallback();
		testClearAllCallbacksLeavesUserData();
		testBorrowedHandlesDieWithOwner();

		Sys.println('  $passed passed, $failed failed');
		return failed;
	}

	static function assert(name:String, condition:Bool):Void {
		if (condition) passed++ else {
			failed++;
			Sys.println('  FAIL: $name');
		}
	}

	static function reset():Void {
		UserData.clearAll();
		CallbackDispatcher.clearAll();
		EventDescription.clearAllCallbacks();
		NativeStudioStub.testSyntheticHandles = false;
		NativeStudioStub.testCallbackMaskResult = 68;
		NativeStudioStub.testReleasedHandles = [];
		NativeStudioStub.testReleaseResult = 68;
		NativeStudioStub.testOwnedHandles = [];
		NativeStudioStub.testPcmReleaseResult = 68;
		NativeStudioStub.testUnloadAllResult = 68;
		NativeStudioStub.testDeadHandles = [];
		NativeStudioStub.testOwnerOf = new Map();
	}

	static function testSetGetClearPerKind():Void {
		reset();
		var evd:EventDescription = 101;
		var evi:EventInstance = 101;
		var bank:Bank = 101;
		var bus:Bus = 101;
		var vca:Vca = 101;
		var replay:CommandReplay = 101;
		var sound:Sound = 101;
		var chan:Channel = 101;
		var group:ChannelGroup = 101;
		var dsp:Dsp = 101;
		var conn:DspConnection = 101;
		var sg:SoundGroup = 101;
		var r3d:Reverb3D = 101;
		var geo:Geometry = 101;
		var pcm:PcmStream = 101;

		evd.setUserData("evd");
		evi.setUserData("evi");
		bank.setUserData("bank");
		bus.setUserData("bus");
		vca.setUserData("vca");
		replay.setUserData("replay");
		sound.setUserData("sound");
		chan.setUserData("chan");
		group.setUserData("group");
		dsp.setUserData("dsp");
		conn.setUserData("conn");
		sg.setUserData("sg");
		r3d.setUserData("r3d");
		geo.setUserData("geo");
		pcm.setUserData("pcm");

		// The same handle int in every family reads back its own value
		assert("evd get", evd.getUserData() == "evd");
		assert("evi get", evi.getUserData() == "evi");
		assert("bank get", bank.getUserData() == "bank");
		assert("bus get", bus.getUserData() == "bus");
		assert("vca get", vca.getUserData() == "vca");
		assert("replay get", replay.getUserData() == "replay");
		assert("sound get", sound.getUserData() == "sound");
		assert("chan get", chan.getUserData() == "chan");
		assert("group get", group.getUserData() == "group");
		assert("dsp get", dsp.getUserData() == "dsp");
		assert("conn get", conn.getUserData() == "conn");
		assert("sg get", sg.getUserData() == "sg");
		assert("r3d get", r3d.getUserData() == "r3d");
		assert("geo get", geo.getUserData() == "geo");
		assert("pcm get", pcm.getUserData() == "pcm");
		// One entry per family, so every kind in UserDataKind is covered above
		assert("count all kinds", UserData.count() == UserDataKind.COUNT);

		UserData.clear(UserDataKind.Dsp, 101);
		assert("clear one kind", dsp.getUserData() == null && conn.getUserData() == "conn");
		UserData.clearKind(UserDataKind.Channel);
		assert("clear kind", chan.getUserData() == null && group.getUserData() == "group");

		// Any value type goes in
		var obj = {hp: 3};
		evi.setUserData(obj);
		assert("object value", evi.getUserData() == obj);
		evi.setUserData(7);
		assert("int value replaces", evi.getUserData() == 7);

		UserData.clearAll();
		assert("clearAll", UserData.count() == 0 && evd.getUserData() == null);
	}

	static function testNullHandleAndNullValue():Void {
		reset();
		EventInstance.NULL.setUserData("x");
		assert("null handle stores nothing", UserData.count() == 0);
		assert("null handle reads null", EventInstance.NULL.getUserData() == null);
		var evi:EventInstance = 5;
		evi.setUserData("x");
		evi.setUserData(null);
		assert("null value removes", UserData.count() == 0);
		assert("unknown handle reads null", (cast 6 : EventInstance).getUserData() == null);
	}

	static function testClearedOnRelease():Void {
		reset();
		NativeStudioStub.testSyntheticHandles = true;
		var desc = StudioSystem.getEvent("event:/x");
		var inst = desc.createInstance();
		inst.setUserData("live");
		assert("instance value before release", inst.getUserData() == "live");
		inst.release();
		assert("instance cleared on release", inst.getUserData() == null);
		assert("stub saw the release", NativeStudioStub.testReleasedHandles.contains(inst));

		// The core release paths clear once FMOD accepted the release, or
		// reported the handle dead already. A refused release keeps the
		// object, so the entry stays with it.
		var sound:Sound = 301;
		var group:ChannelGroup = 303;
		var dsp:Dsp = 304;
		var sg:SoundGroup = 305;
		var r3d:Reverb3D = 306;
		var geo:Geometry = 310;
		var chan:Channel = 302;
		chan.setUserData(1); chan.stop();
		assert("channel cleared on stop", chan.getUserData() == null);
		var ended:Channel = 312;
		ended.setUserData(1);
		haxefmod.core.ChannelCallbacks.deliver((ended : Int), haxefmod.core.ChannelCallbacks.TYPE_END, 0, 0);
		assert("channel cleared on End", ended.getUserData() == null);
		NativeStudioStub.testReleaseResult = 31; // FMOD_ERR_INVALID_PARAM
		sound.setUserData(1); assert("refused sound release reports the result", sound.release() == 31);
		assert("refused sound release keeps the entry", sound.getUserData() == 1);
		// A library-owned sound is refused before the native release runs
		NativeStudioStub.testReleaseResult = 0;
		NativeStudioStub.testOwnedHandles = [sound];
		NativeStudioStub.testNumSubSounds = 2;
		NativeStudioStub.testSubSoundLookups = 0;
		assert("owned sound release is refused", sound.release() == 31);
		assert("owned sound release keeps the entry", sound.getUserData() == 1);
		assert("owned sound release mints no subsound handle", NativeStudioStub.testSubSoundLookups == 0);
		NativeStudioStub.testOwnedHandles = [];
		var sub:Sound = 9000;
		sub.setUserData(1);
		sound.release();
		assert("release walks the subsounds", NativeStudioStub.testSubSoundLookups == 2);
		assert("release clears the subsound entries", sub.getUserData() == null);
		NativeStudioStub.testNumSubSounds = -1;
		NativeStudioStub.testReleaseResult = 31;
		group.setUserData(1); group.release();
		assert("refused group release keeps the entry", group.getUserData() == 1);
		dsp.setUserData(1); dsp.release();
		assert("refused dsp release keeps the entry", dsp.getUserData() == 1);
		sg.setUserData(1); sg.release();
		assert("refused sound group release keeps the entry", sg.getUserData() == 1);
		r3d.setUserData(1); r3d.release();
		assert("refused reverb3d release keeps the entry", r3d.getUserData() == 1);
		geo.setUserData(1); geo.release();
		assert("refused geometry release keeps the entry", geo.getUserData() == 1);
		NativeStudioStub.testReleaseResult = 0;
		sound.release();
		assert("sound cleared on release", sound.getUserData() == null);
		group.release();
		assert("group cleared on release", group.getUserData() == null);
		dsp.release();
		assert("dsp cleared on release", dsp.getUserData() == null);
		sg.release();
		assert("sound group cleared on release", sg.getUserData() == null);
		r3d.release();
		assert("reverb3d cleared on release", r3d.getUserData() == null);
		geo.release();
		assert("geometry cleared on release", geo.getUserData() == null);
		// A dead handle drops the entry too, since the object is gone
		NativeStudioStub.testReleaseResult = 30; // FMOD_ERR_INVALID_HANDLE
		dsp.setUserData(1); dsp.release();
		assert("dead dsp handle drops the entry", dsp.getUserData() == null);
		NativeStudioStub.testReleaseResult = 68;
		var pcm:PcmStream = 307;
		// A refused release keeps the stream, so the stub accepts this one
		haxefmod.studio.native.NativeStudioStub.testPcmReleaseResult = 0;
		pcm.setUserData(1); pcm.release();
		haxefmod.studio.native.NativeStudioStub.testPcmReleaseResult = 68;
		assert("pcm cleared on release", pcm.getUserData() == null);
		// A dead handle drops the entry as well, since the stream is gone
		haxefmod.studio.native.NativeStudioStub.testPcmReleaseResult = 30;
		pcm.setUserData(1); pcm.release();
		haxefmod.studio.native.NativeStudioStub.testPcmReleaseResult = 68;
		assert("dead pcm handle drops the entry", pcm.getUserData() == null);
		// A refused unload or release keeps the entry, an accepted one drops it
		var bank:Bank = 308;
		var replay:CommandReplay = 309;
		bank.setUserData(1); bank.unload();
		assert("refused bank unload keeps the entry", bank.getUserData() == 1);
		replay.setUserData(1); replay.release();
		assert("refused replay release keeps the entry", replay.getUserData() == 1);
		NativeStudioStub.testReleaseResult = 0;
		bank.unload();
		assert("bank cleared on unload", bank.getUserData() == null);
		replay.release();
		assert("replay cleared on release", replay.getUserData() == null);
		NativeStudioStub.testReleaseResult = 68;
		assert("nothing left", UserData.count() == 0);
	}

	static function testClearedOnDestroyed():Void {
		reset();
		var evi:EventInstance = 777;
		var other:EventInstance = 778;
		evi.setUserData("doomed");
		other.setUserData("keep");
		// A Started record leaves the entry alone
		CallbackDispatcher.deliver(777, EventCallbackType.STARTED, 0, 0, 0, 0, 0, 0, "");
		assert("started keeps userdata", evi.getUserData() == "doomed");
		// Destroyed clears it even with no handler registered
		CallbackDispatcher.deliver(777, EventCallbackType.DESTROYED, 0, 0, 0, 0, 0, 0, "");
		assert("destroyed clears userdata", evi.getUserData() == null);
		assert("destroyed leaves other handles", other.getUserData() == "keep");
		// The value remains readable from inside the Destroyed handler itself
		var seen:Dynamic = null;
		NativeStudioStub.testCallbackMaskResult = 0;
		other.setCallback(function(data) {
			if (data == Destroyed) seen = other.getUserData();
		});
		CallbackDispatcher.deliver(778, EventCallbackType.DESTROYED, 0, 0, 0, 0, 0, 0, "");
		assert("handler reads value before clear", seen == "keep");
		assert("cleared after handler", other.getUserData() == null);
	}

	static function testSystemAndUnloadAll():Void {
		reset();
		StudioSystem.setUserData("sys");
		assert("system get", StudioSystem.getUserData() == "sys");
		var bank:Bank = 400;
		bank.setUserData("b");
		var desc:EventDescription = 401;
		desc.setUserData("d");
		desc.setCallback(function(_) {});
		var evi:EventInstance = 402;
		var hits = 0;
		evi.setCallback(function(_) hits++);
		// The stub refuses the unload, so every bank stays and so does the state
		assert("refused unloadAll reports the result", StudioSystem.unloadAll() == 68);
		assert("refused unloadAll keeps system", StudioSystem.getUserData() == "sys");
		assert("refused unloadAll keeps handles", UserData.count() == 2);
		assert("refused unloadAll keeps description callbacks", desc.hasCallback());
		CallbackDispatcher.deliver(402, EventCallbackType.STOPPED, 0, 0, 0, 0, 0, 0, "");
		assert("refused unloadAll keeps instance callbacks", hits == 1);
		var pinEvi:EventInstance = 403; pinEvi.setUserData("i");
		var pinBus:Bus = 404; pinBus.setUserData("b");
		var pinVca:Vca = 405; pinVca.setUserData("v");
		var pinDeadGroup:ChannelGroup = 406; pinDeadGroup.setUserData("g");
		var pinDeadChannel:Channel = 407; pinDeadChannel.setUserData("c");
		var keepSound:Sound = 408; keepSound.setUserData("s");
		var keepDsp:Dsp = 409; keepDsp.setUserData("d");
		var keepChannel:Channel = 410; keepChannel.setUserData("c");
		NativeStudioStub.testDeadHandles = [406, 407];
		NativeStudioStub.testUnloadAllResult = 0;
		StudioSystem.unloadAll();
		NativeStudioStub.testUnloadAllResult = 68;
		NativeStudioStub.testDeadHandles = [];
		assert("unloadAll drops instance userdata", pinEvi.getUserData() == null);
		assert("unloadAll drops bus userdata", pinBus.getUserData() == null);
		assert("unloadAll drops vca userdata", pinVca.getUserData() == null);
		assert("unloadAll drops a dead group's userdata", pinDeadGroup.getUserData() == null);
		assert("unloadAll drops a dead channel's userdata", pinDeadChannel.getUserData() == null);
		assert("unloadAll keeps the system value", StudioSystem.getUserData() == "sys");
		assert("unloadAll keeps the userdata of a sound, DSP, and channel that survived",
			keepSound.getUserData() == "s" && keepDsp.getUserData() == "d" && keepChannel.getUserData() == "c");
		keepSound.setUserData(null); keepDsp.setUserData(null); keepChannel.setUserData(null);
		StudioSystem.setUserData(null);
		assert("unloadAll clears handles", UserData.count() == 0);
		assert("unloadAll clears description callbacks", !desc.hasCallback());
		CallbackDispatcher.deliver(402, EventCallbackType.STOPPED, 0, 0, 0, 0, 0, 0, "");
		assert("unloadAll clears instance callbacks", hits == 1);
	}

	static function testDescriptionCallback():Void {
		reset();
		NativeStudioStub.testSyntheticHandles = true;
		NativeStudioStub.testCallbackMaskResult = 0;
		var desc = StudioSystem.getEvent("event:/x");

		var before = desc.createInstance();
		assert("no handler without setCallback", !CallbackDispatcher.hasHandler(before));

		var hits = 0;
		desc.setCallback(function(data) { if (data == Started) hits++; }, EventCallbackType.STARTED);
		assert("description remembers handler", desc.hasCallback());
		assert("earlier instance untouched", !CallbackDispatcher.hasHandler(before));

		var after = desc.createInstance();
		assert("new instance registered", CallbackDispatcher.hasHandler(after));
		assert("mask forwarded with destroyed bit",
			NativeStudioStub.testLastCallbackMaskHandle == (after : Int)
			&& NativeStudioStub.testLastCallbackMask == (EventCallbackType.STARTED | EventCallbackType.DESTROYED));
		CallbackDispatcher.deliver(after, EventCallbackType.STARTED, 0, 0, 0, 0, 0, 0, "");
		CallbackDispatcher.deliver(before, EventCallbackType.STARTED, 0, 0, 0, 0, 0, 0, "");
		assert("only the new instance fires", hits == 1);

		// A second description does not share the handler
		var otherDesc = StudioSystem.getEvent("event:/y");
		var otherInst = otherDesc.createInstance();
		assert("other description unaffected", !CallbackDispatcher.hasHandler(otherInst));

		desc.clearCallback();
		assert("clearCallback forgets", !desc.hasCallback());
		var late = desc.createInstance();
		assert("no handler after clear", !CallbackDispatcher.hasHandler(late));
		assert("existing registration survives clear", CallbackDispatcher.hasHandler(after));

		desc.setCallback(function(_) {});
		desc.setCallback(null);
		assert("null handler clears", !desc.hasCallback());
		EventDescription.NULL.setCallback(function(_) {});
		assert("null description ignored", !EventDescription.NULL.hasCallback());
	}

	static function testClearAllCallbacksLeavesUserData():Void {
		reset();
		var desc:EventDescription = 500;
		desc.setUserData("d");
		desc.setCallback(function(_) {});
		FmodManager.ClearAllCallbacks();
		assert("ClearAllCallbacks drops description handler", !desc.hasCallback());
		assert("ClearAllCallbacks keeps userdata", desc.getUserData() == "d");
	}

	// A handle the game reached through another one (a walked group, a
	// group's DSP, a channel's sound) died natively with that handle, and
	// its Haxe entries outlived it. FMOD then reused the address and the
	// stale handle drove another instance's group with the old userdata.
	static function testBorrowedHandlesDieWithOwner():Void {
		reset();
		NativeStudioStub.testSyntheticHandles = true;
		NativeStudioStub.testReleaseResult = 0;
		var group:ChannelGroup = ++NativeStudioStub.testNextHandle;
		var child = group.getGroup(0);
		var fader = group.getDsp(0);
		assert("a walked group is borrowed", !child.isNull() && NativeStudioStub.testOwnedHandles.contains(child));
		assert("a borrowed group refuses release", child.release() == FmodResult.FMOD_ERR_INVALID_PARAM);
		assert("a borrowed DSP refuses release", fader.release() == FmodResult.FMOD_ERR_INVALID_PARAM);
		child.setUserData("child");
		fader.setUserData("fader");
		haxefmod.core.ChannelCallbacks.setGroup(child, function(_) {});
		var keep:Dsp = ++NativeStudioStub.testNextHandle;
		keep.setUserData("keep");
		assert("release of the owner reports FMOD's result", group.release() == FmodResult.FMOD_OK);
		assert("the walked group's userdata died with its owner", child.getUserData() == null);
		assert("the DSP's userdata died with its owner", fader.getUserData() == null);
		assert("the walked group's handler died with its owner", !@:privateAccess haxefmod.core.ChannelCallbacks.handlers.exists(child));
		assert("an unrelated handle keeps its userdata", keep.getUserData() == "keep");

		// A channel's borrowed sound and DSP go with the channel
		var channel:Channel = ++NativeStudioStub.testNextHandle;
		var sound = channel.getCurrentSound();
		var channelDsp = channel.getDsp(0);
		assert("a channel's sound is borrowed", sound.release() == FmodResult.FMOD_ERR_INVALID_PARAM);
		sound.setUserData("sound");
		channelDsp.setUserData("dsp");
		// The parent of the channel's sound (a bank's sample data) is
		// borrowed from that sound
		var bankSound = sound.getSubSoundParent();
		assert("the parent of a borrowed sound is borrowed", !bankSound.isNull() && bankSound.release() == FmodResult.FMOD_ERR_INVALID_PARAM);
		bankSound.setUserData("bank");
		assert("a refused parent release keeps its userdata", bankSound.getUserData() == "bank");
		channel.stop();
		assert("stop drops the borrowed parent's userdata", bankSound.getUserData() == null);
		assert("stop drops the borrowed sound's userdata", sound.getUserData() == null);
		assert("stop drops the borrowed DSP's userdata", channelDsp.getUserData() == null);

		// An instance FMOD destroyed: the native drain freed what hangs off
		// it, and the Haxe drain drops the entries once per update
		var inst:EventInstance = ++NativeStudioStub.testNextHandle;
		var instGroup:ChannelGroup = ++NativeStudioStub.testNextHandle;
		NativeStudioStub.testOwnerOf.set(instGroup, inst);
		var walked = instGroup.getParentGroup();
		walked.setUserData("walked");
		NativeStudioStub.testFree(inst);
		CallbackDispatcher.deliver(inst, EventCallbackType.DESTROYED, 0, 0, 0, 0, 0, 0, "");
		CallbackDispatcher.update();
		assert("the destroyed instance's walked group loses its userdata", walked.getUserData() == null);

		// A DSP, sound, or stream release drops the entries of handles that died with it
		var dspOwner:Dsp = ++NativeStudioStub.testNextHandle;
		var input:Dsp = ++NativeStudioStub.testNextHandle;
		NativeStudioStub.testOwnerOf.set(input, dspOwner);
		input.setUserData("input");
		dspOwner.release();
		assert("a DSP release drops its walked input's userdata", input.getUserData() == null);
		var soundOwner:Sound = ++NativeStudioStub.testNextHandle;
		var reached:Sound = ++NativeStudioStub.testNextHandle;
		NativeStudioStub.testOwnerOf.set(reached, soundOwner);
		reached.setUserData("reached");
		soundOwner.release();
		assert("a sound release drops a borrowed sound's userdata", reached.getUserData() == null);
		var stream:haxefmod.core.PcmStream = ++NativeStudioStub.testNextHandle;
		var streamSound:Sound = ++NativeStudioStub.testNextHandle;
		streamSound.setUserData("ss");
		NativeStudioStub.testPcmReleaseResult = 0;
		NativeStudioStub.testDeadHandles.push(streamSound);
		stream.release();
		NativeStudioStub.testPcmReleaseResult = 68;
		assert("a stream release drops its sound's userdata", streamSound.getUserData() == null);
		// A refused release keeps every entry
		var refused:ChannelGroup = ++NativeStudioStub.testNextHandle;
		var refusedChild = refused.getGroup(0);
		refusedChild.setUserData("kept");
		NativeStudioStub.testReleaseResult = 31;
		refused.release();
		assert("a refused release keeps the borrowed entries", refusedChild.getUserData() == "kept");
		refusedChild.setUserData(null);
		keep.setUserData(null);
		NativeStudioStub.testReleaseResult = 68;
		NativeStudioStub.testSyntheticHandles = false;
		NativeStudioStub.testDeadHandles = [];
		assert("nothing left", UserData.count() == 0);
	}
}
