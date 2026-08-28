package tests;

import haxefmod.FmodManager;
import haxefmod.core.Channel;
import haxefmod.core.ChannelGroup;
import haxefmod.core.Dsp;
import haxefmod.core.DspConnection;
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
		assert("pcm get", pcm.getUserData() == "pcm");
		assert("count all kinds", UserData.count() == 14);

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

		// The other release paths clear even though the stub rejects the
		// native call, so the entry never depends on the native result
		var sound:Sound = 301;
		sound.setUserData(1); sound.release();
		assert("sound cleared on release", sound.getUserData() == null);
		var chan:Channel = 302;
		chan.setUserData(1); chan.stop();
		assert("channel cleared on stop", chan.getUserData() == null);
		var group:ChannelGroup = 303;
		group.setUserData(1); group.release();
		assert("group cleared on release", group.getUserData() == null);
		var dsp:Dsp = 304;
		dsp.setUserData(1); dsp.release();
		assert("dsp cleared on release", dsp.getUserData() == null);
		var sg:SoundGroup = 305;
		sg.setUserData(1); sg.release();
		assert("sound group cleared on release", sg.getUserData() == null);
		var r3d:Reverb3D = 306;
		r3d.setUserData(1); r3d.release();
		assert("reverb3d cleared on release", r3d.getUserData() == null);
		var pcm:PcmStream = 307;
		pcm.setUserData(1); pcm.release();
		assert("pcm cleared on release", pcm.getUserData() == null);
		var bank:Bank = 308;
		bank.setUserData(1); bank.unload();
		assert("bank cleared on unload", bank.getUserData() == null);
		var replay:CommandReplay = 309;
		replay.setUserData(1); replay.release();
		assert("replay cleared on release", replay.getUserData() == null);
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
		// The value is still readable from inside the Destroyed handler itself
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
		StudioSystem.unloadAll();
		assert("unloadAll clears system", StudioSystem.getUserData() == null);
		assert("unloadAll clears handles", UserData.count() == 0);
		assert("unloadAll clears description callbacks", !desc.hasCallback());
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
}
