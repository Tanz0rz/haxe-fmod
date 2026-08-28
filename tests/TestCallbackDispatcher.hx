package tests;

import haxefmod.studio.CallbackDispatcher;
import haxefmod.studio.Callbacks;
import haxefmod.studio.native.NativeStudioStub;

class TestCallbackDispatcher {
	static var passed = 0;
	static var failed = 0;

	public static function run():Int {
		Sys.println("--- CallbackDispatcher ---");

		testDecodeLifecycle();
		testDecodeMarker();
		testDecodeBeat();
		testDecodeNestedBeat();
		testDecodePlugin();
		testDecodeUnknown();
		testRegistration();
		testReentrancy();
		testFaultIsolation();
		testStaleRegistrationGate();
		testSystemRouting();

		Sys.println('  $passed passed, $failed failed');
		return failed;
	}

	static function testDecodeLifecycle() {
		assert("decode CREATED", CallbackDispatcher.decode(0x1, 0, 0, 0, 0, 0, 0, "") == Created);
		assert("decode DESTROYED", CallbackDispatcher.decode(0x2, 0, 0, 0, 0, 0, 0, "") == Destroyed);
		assert("decode STARTING", CallbackDispatcher.decode(0x4, 0, 0, 0, 0, 0, 0, "") == Starting);
		assert("decode STARTED", CallbackDispatcher.decode(0x8, 0, 0, 0, 0, 0, 0, "") == Started);
		assert("decode RESTARTED", CallbackDispatcher.decode(0x10, 0, 0, 0, 0, 0, 0, "") == Restarted);
		assert("decode STOPPED", CallbackDispatcher.decode(0x20, 0, 0, 0, 0, 0, 0, "") == Stopped);
		assert("decode START_FAILED", CallbackDispatcher.decode(0x40, 0, 0, 0, 0, 0, 0, "") == StartFailed);
		assert("decode SOUND_PLAYED", CallbackDispatcher.decode(0x2000, 0, 0, 0, 0, 0, 0, "") == SoundPlayed);
		assert("decode SOUND_STOPPED", CallbackDispatcher.decode(0x4000, 0, 0, 0, 0, 0, 0, "") == SoundStopped);
		assert("decode REAL_TO_VIRTUAL", CallbackDispatcher.decode(0x8000, 0, 0, 0, 0, 0, 0, "") == RealToVirtual);
		assert("decode VIRTUAL_TO_REAL", CallbackDispatcher.decode(0x10000, 0, 0, 0, 0, 0, 0, "") == VirtualToReal);
	}

	static function testDecodeMarker() {
		var data = CallbackDispatcher.decode(0x800, 1500, 0, 0, 0, 0, 0, "verse-1");
		switch (data) {
			case TimelineMarker(properties):
				assert("marker name", properties.name == "verse-1");
				assert("marker position", properties.position == 1500);
			default:
				assert("marker decoded", false);
		}
	}

	static function testDecodeBeat() {
		var data = CallbackDispatcher.decode(0x1000, 4, 2, 8250, 3, 8, 120.5, "");
		switch (data) {
			case TimelineBeat(properties):
				assert("beat bar", properties.bar == 4);
				assert("beat beat", properties.beat == 2);
				assert("beat position", properties.position == 8250);
				assert("beat tempo", Math.abs(properties.tempo - 120.5) < 0.001);
				assert("beat time signature", properties.timeSignatureUpper == 3 && properties.timeSignatureLower == 8);
			default:
				assert("beat decoded", false);
		}
	}

	static function testDecodeNestedBeat() {
		var guid = "{0225c47b-e69f-4785-b89c-fd321387934a}";
		var data = CallbackDispatcher.decode(0x40000, 1, 3, 500, 6, 8, 90.0, guid);
		switch (data) {
			case NestedTimelineBeat(nested):
				var beat = nested.properties;
				assert("nested beat fields", beat.bar == 1 && beat.beat == 3 && beat.position == 500 && beat.tempo == 90.0);
				assert("nested beat time signature", beat.timeSignatureUpper == 6 && beat.timeSignatureLower == 8);
				assert("nested beat event id", nested.eventId == guid);
			default:
				assert("nested beat decoded", false);
		}
	}

	// The drain writes the plugin DSP handle into i1 and the plugin name
	// into str before the record reaches decode
	static function testDecodePlugin() {
		var created = CallbackDispatcher.decode(0x200, 0x10007, 0, 0, 0, 0, 0, "fmod_gain");
		switch (created) {
			case PluginCreated(properties):
				assert("plugin created name", properties.name == "fmod_gain");
				assert("plugin created dsp handle", (properties.dsp : Int) == 0x10007);
			default:
				assert("plugin created decoded", false);
		}
		var destroyed = CallbackDispatcher.decode(0x400, 0x10007, 0, 0, 0, 0, 0, "fmod_gain");
		switch (destroyed) {
			case PluginDestroyed(properties):
				assert("plugin destroyed name", properties.name == "fmod_gain");
				assert("plugin destroyed dsp handle", (properties.dsp : Int) == 0x10007);
			default:
				assert("plugin destroyed decoded", false);
		}
	}

	static function testDecodeUnknown() {
		var data = CallbackDispatcher.decode(0x20000, 0, 0, 0, 0, 0, 0, "");
		switch (data) {
			case Other(type):
				assert("unknown type preserved", (type : Int) == 0x20000);
			default:
				assert("unknown decoded as Other", false);
		}
	}

	static function testRegistration() {
		CallbackDispatcher.clearAll();
		assert("no handler initially", !CallbackDispatcher.hasHandler(42));

		// Registration works even though the stub backend ignores the mask
		CallbackDispatcher.setCallback(42, _ -> {}, 0x20);
		assert("handler registered", CallbackDispatcher.hasHandler(42));

		CallbackDispatcher.setCallback(0, _ -> {}, 0x20);
		assert("invalid handle not registered", !CallbackDispatcher.hasHandler(0));

		CallbackDispatcher.remove(42);
		assert("handler removed", !CallbackDispatcher.hasHandler(42));

		CallbackDispatcher.setCallback(7, _ -> {});
		CallbackDispatcher.clearAll();
		assert("clearAll removes handlers", !CallbackDispatcher.hasHandler(7));

		// A null handler removes the registration
		CallbackDispatcher.setCallback(8, _ -> {}, 0x20);
		CallbackDispatcher.setCallback(8, null);
		assert("null handler removes registration", !CallbackDispatcher.hasHandler(8));

		// Channel-namespace records never reach event dispatch, even with
		// no router installed and an event handler on the same int
		var savedRouter = CallbackDispatcher.channelRouter;
		CallbackDispatcher.channelRouter = null;
		var wrongDeliveries = 0;
		CallbackDispatcher.setCallback(70, _ -> wrongDeliveries++, 0x20);
		CallbackDispatcher.deliver(70, 0x40000001, 0, 0, 0, 0, 0, 0.0, "");
		assert("channel record dropped without router", wrongDeliveries == 0);
		CallbackDispatcher.remove(70);
		CallbackDispatcher.channelRouter = savedRouter;

		// The facade clear covers both registries (events and channels)
		CallbackDispatcher.setCallback(50, _ -> {}, 0x20);
		var chanEvents = 0;
		haxefmod.core.ChannelCallbacks.set(60, _ -> chanEvents++);
		haxefmod.FmodManager.ClearAllCallbacks();
		assert("facade clear removes event handlers", !CallbackDispatcher.hasHandler(50));
		haxefmod.core.ChannelCallbacks.deliver(60, haxefmod.core.ChannelCallbacks.TYPE_END, 0);
		assert("facade clear removes channel handlers", chanEvents == 0);
	}

	static function testReentrancy() {
		// Handlers may mutate registrations during delivery: remove
		// themselves, register other handles, or re-register the same
		// handle. None of it may crash or corrupt the registration map.
		CallbackDispatcher.clearAll();

		// A handler that removes itself mid-delivery
		var selfRemoveCalls = 0;
		CallbackDispatcher.setCallback(10, _ -> {
			selfRemoveCalls++;
			CallbackDispatcher.remove(10);
		}, 0x20);
		CallbackDispatcher.deliver(10, 0x20, 0, 0, 0, 0, 0, 0.0, "");
		assert("self-removing handler ran once", selfRemoveCalls == 1);
		assert("self-removing handler gone", !CallbackDispatcher.hasHandler(10));
		CallbackDispatcher.deliver(10, 0x20, 0, 0, 0, 0, 0, 0.0, "");
		assert("removed handler not called again", selfRemoveCalls == 1);

		// A handler that registers a DIFFERENT handle mid-delivery
		var secondCalls = 0;
		CallbackDispatcher.setCallback(20, _ -> {
			CallbackDispatcher.setCallback(21, _ -> secondCalls++, 0x20);
		}, 0x20);
		CallbackDispatcher.deliver(20, 0x20, 0, 0, 0, 0, 0, 0.0, "");
		assert("handler registered during delivery exists", CallbackDispatcher.hasHandler(21));
		CallbackDispatcher.deliver(21, 0x20, 0, 0, 0, 0, 0, 0.0, "");
		assert("handler registered during delivery fires", secondCalls == 1);

		// A handler that REPLACES itself mid-delivery
		var oldCalls = 0;
		var newCalls = 0;
		CallbackDispatcher.setCallback(30, _ -> {
			oldCalls++;
			CallbackDispatcher.setCallback(30, _ -> newCalls++, 0x20);
		}, 0x20);
		CallbackDispatcher.deliver(30, 0x20, 0, 0, 0, 0, 0, 0.0, "");
		CallbackDispatcher.deliver(30, 0x20, 0, 0, 0, 0, 0, 0.0, "");
		assert("replaced handler ran once", oldCalls == 1);
		assert("replacement handler took over", newCalls == 1);

		// DESTROYED cleans up even when the handler mutates registrations
		var destroyedSeen = false;
		CallbackDispatcher.setCallback(40, data -> {
			switch (data) {
				case Destroyed:
					destroyedSeen = true;
					CallbackDispatcher.setCallback(41, _ -> {}, 0x20);
				default:
			}
		}, 0x02);
		CallbackDispatcher.deliver(40, 0x02, 0, 0, 0, 0, 0, 0.0, "");
		assert("destroyed delivered", destroyedSeen);
		assert("destroyed handle auto-removed", !CallbackDispatcher.hasHandler(40));
		assert("registration from destroyed handler survives", CallbackDispatcher.hasHandler(41));

		CallbackDispatcher.clearAll();
	}

	static function testFaultIsolation() {
		// A throwing handler must be contained: nothing may propagate out
		// of delivery, and DESTROYED cleanup must still run (no second
		// DESTROYED will ever come for that instance)
		CallbackDispatcher.clearAll();
		CallbackDispatcher.setCallback(90, _ -> throw new haxe.Exception("handler boom"), 0x20);
		var threw = false;
		try {
			CallbackDispatcher.deliver(90, 0x20, 0, 0, 0, 0, 0, 0.0, "");
		} catch (e:haxe.Exception) {
			threw = true;
		}
		assert("throwing handler contained", !threw);
		assert("registration survives a non-terminal throw", CallbackDispatcher.hasHandler(90));

		var destroyedThrew = false;
		try {
			CallbackDispatcher.deliver(90, 0x2, 0, 0, 0, 0, 0, 0.0, "");
		} catch (e:haxe.Exception) {
			destroyedThrew = true;
		}
		assert("throwing DESTROYED handler contained", !destroyedThrew);
		assert("destroyed cleanup despite throw", !CallbackDispatcher.hasHandler(90));
	}

	static function testSystemRouting() {
		var SC = haxefmod.studio.SystemCallbacks;
		var received:Array<haxefmod.studio.SystemCallbacks.SystemEvent> = [];
		haxefmod.studio.StudioSystem.setSystemCallback(function(e) received.push(e));
		assert("system router self-installed", CallbackDispatcher.systemRouter != null);
		assert("system handler installed", SC.isSet());
		CallbackDispatcher.deliver(0, SC.TYPE_DEVICELISTCHANGED, 0, 0, 0, 0, 0, 0.0, "");
		CallbackDispatcher.deliver(0, SC.TYPE_DEVICELOST, 0, 0, 0, 0, 0, 0.0, "");
		CallbackDispatcher.deliver(0, SC.TYPE_PREUPDATE, 0, 0, 0, 0, 0, 0.0, "");
		CallbackDispatcher.deliver(0, SC.TYPE_POSTUPDATE, 0, 0, 0, 0, 0, 0.0, "");
		CallbackDispatcher.deliver(0, SC.TYPE_BANK_UNLOAD, 0, 0, 0, 0, 0, 0.0, "bank:/Master");
		CallbackDispatcher.deliver(0, SC.TYPE_LIVEUPDATE_CONNECTED, 0, 0, 0, 0, 0, 0.0, "");
		CallbackDispatcher.deliver(0, SC.TYPE_LIVEUPDATE_DISCONNECTED, 0, 0, 0, 0, 0, 0.0, "");
		// An unknown type inside the namespace is dropped, never delivered
		CallbackDispatcher.deliver(0, SC.TYPE_NAMESPACE | 0x80, 0, 0, 0, 0, 0, 0.0, "");
		assert("system events delivered", received.length == 7);
		if (received.length == 7) {
			assert("system DeviceListChanged", received[0].match(DeviceListChanged));
			assert("system DeviceLost", received[1].match(DeviceLost));
			assert("system PreUpdate", received[2].match(PreUpdate));
			assert("system PostUpdate", received[3].match(PostUpdate));
			assert("system BankUnload path", received[4].match(BankUnload("bank:/Master")));
			assert("system LiveUpdateConnected", received[5].match(LiveUpdateConnected));
			assert("system LiveUpdateDisconnected", received[6].match(LiveUpdateDisconnected));
		}
		// A system record never reaches an event handler registered on
		// handle 0, and studio types cannot alias core types
		assert("system types disjoint", SC.TYPE_PREUPDATE != SC.TYPE_DEVICELISTCHANGED
			&& SC.TYPE_POSTUPDATE != SC.TYPE_DEVICELOST);
		// A throwing handler is contained
		haxefmod.studio.StudioSystem.setSystemCallback(function(e) throw "boom");
		CallbackDispatcher.deliver(0, SC.TYPE_PREUPDATE, 0, 0, 0, 0, 0, 0.0, "");
		assert("system handler fault contained", true);
		// The facade clear removes the system handler as well
		var after = 0;
		haxefmod.studio.StudioSystem.setSystemCallback(function(e) after++);
		haxefmod.FmodManager.ClearAllCallbacks();
		assert("facade clear removes system handler", !SC.isSet());
		CallbackDispatcher.deliver(0, SC.TYPE_PREUPDATE, 0, 0, 0, 0, 0, 0.0, "");
		assert("cleared system handler silent", after == 0);
		// Explicit clear after a set, and a null handler equals clear
		haxefmod.studio.StudioSystem.setSystemCallback(function(e) after++);
		haxefmod.studio.StudioSystem.clearSystemCallback();
		assert("clearSystemCallback removes handler", !SC.isSet());
		haxefmod.studio.StudioSystem.setSystemCallback(null);
		assert("null system handler clears", !SC.isSet());
	}

	static function testStaleRegistrationGate() {
		CallbackDispatcher.clearAll();

		// A stale handle reports INVALID_HANDLE from the native mask call.
		// No DESTROYED will ever arrive for it, so registering the handler
		// anyway would leak the closure for the rest of the session.
		NativeStudioStub.testCallbackMaskResult = 30;
		CallbackDispatcher.setCallback(91, _ -> {}, 0x20);
		assert("stale handle registration refused", !CallbackDispatcher.hasHandler(91));

		NativeStudioStub.testCallbackMaskResult = 68;
		CallbackDispatcher.setCallback(91, _ -> {}, 0x20);
		assert("healthy registration accepted", CallbackDispatcher.hasHandler(91));

		// Removing through the null-handler path shrinks the native mask so
		// unconsumed records stop filling the queue
		CallbackDispatcher.setCallback(91, null);
		assert("null handler removed registration", !CallbackDispatcher.hasHandler(91));
		assert("null handler cleared the native mask",
			NativeStudioStub.testLastCallbackMask == 0
			&& NativeStudioStub.testLastCallbackMaskHandle == 91);

		CallbackDispatcher.clearAll();
	}

	static function assert(name:String, condition:Bool) {
		if (condition) {
			passed++;
		} else {
			failed++;
			Sys.println('  FAIL: $name');
		}
	}
}
