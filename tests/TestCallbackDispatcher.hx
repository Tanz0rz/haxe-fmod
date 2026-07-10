package tests;

import haxefmod.runtime.CallbackDispatcher;
import haxefmod.studio.Callbacks;

class TestCallbackDispatcher {
	static var passed = 0;
	static var failed = 0;

	public static function run():Int {
		Sys.println("--- CallbackDispatcher ---");

		testDecodeLifecycle();
		testDecodeMarker();
		testDecodeBeat();
		testDecodeNestedBeat();
		testDecodeUnknown();
		testRegistration();
		testReentrancy();

		Sys.println('  $passed passed, $failed failed');
		return failed;
	}

	static function testDecodeLifecycle() {
		assert("decode CREATED", CallbackDispatcher.decode(0x1, 0, 0, 0, 0, "") == Created);
		assert("decode DESTROYED", CallbackDispatcher.decode(0x2, 0, 0, 0, 0, "") == Destroyed);
		assert("decode STARTING", CallbackDispatcher.decode(0x4, 0, 0, 0, 0, "") == Starting);
		assert("decode STARTED", CallbackDispatcher.decode(0x8, 0, 0, 0, 0, "") == Started);
		assert("decode RESTARTED", CallbackDispatcher.decode(0x10, 0, 0, 0, 0, "") == Restarted);
		assert("decode STOPPED", CallbackDispatcher.decode(0x20, 0, 0, 0, 0, "") == Stopped);
		assert("decode START_FAILED", CallbackDispatcher.decode(0x40, 0, 0, 0, 0, "") == StartFailed);
		assert("decode SOUND_PLAYED", CallbackDispatcher.decode(0x2000, 0, 0, 0, 0, "") == SoundPlayed);
		assert("decode SOUND_STOPPED", CallbackDispatcher.decode(0x4000, 0, 0, 0, 0, "") == SoundStopped);
		assert("decode REAL_TO_VIRTUAL", CallbackDispatcher.decode(0x8000, 0, 0, 0, 0, "") == RealToVirtual);
		assert("decode VIRTUAL_TO_REAL", CallbackDispatcher.decode(0x10000, 0, 0, 0, 0, "") == VirtualToReal);
	}

	static function testDecodeMarker() {
		var data = CallbackDispatcher.decode(0x800, 1500, 0, 0, 0, "verse-1");
		switch (data) {
			case TimelineMarker(name, positionMs):
				assert("marker name", name == "verse-1");
				assert("marker position", positionMs == 1500);
			default:
				assert("marker decoded", false);
		}
	}

	static function testDecodeBeat() {
		var data = CallbackDispatcher.decode(0x1000, 4, 2, 8250, 120.5, "");
		switch (data) {
			case TimelineBeat(bar, beat, positionMs, tempo):
				assert("beat bar", bar == 4);
				assert("beat beat", beat == 2);
				assert("beat position", positionMs == 8250);
				assert("beat tempo", Math.abs(tempo - 120.5) < 0.001);
			default:
				assert("beat decoded", false);
		}
	}

	static function testDecodeNestedBeat() {
		var data = CallbackDispatcher.decode(0x40000, 1, 3, 500, 90.0, "");
		switch (data) {
			case NestedTimelineBeat(bar, beat, positionMs, tempo):
				assert("nested beat fields", bar == 1 && beat == 3 && positionMs == 500 && tempo == 90.0);
			default:
				assert("nested beat decoded", false);
		}
	}

	static function testDecodeUnknown() {
		var data = CallbackDispatcher.decode(0x200, 0, 0, 0, 0, "");
		switch (data) {
			case Other(type):
				assert("unknown type preserved", (type : Int) == 0x200);
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
		CallbackDispatcher.deliver(10, 0x20, 0, 0, 0, 0.0, "");
		assert("self-removing handler ran once", selfRemoveCalls == 1);
		assert("self-removing handler gone", !CallbackDispatcher.hasHandler(10));
		CallbackDispatcher.deliver(10, 0x20, 0, 0, 0, 0.0, "");
		assert("removed handler not called again", selfRemoveCalls == 1);

		// A handler that registers a DIFFERENT handle mid-delivery
		var secondCalls = 0;
		CallbackDispatcher.setCallback(20, _ -> {
			CallbackDispatcher.setCallback(21, _ -> secondCalls++, 0x20);
		}, 0x20);
		CallbackDispatcher.deliver(20, 0x20, 0, 0, 0, 0.0, "");
		assert("handler registered during delivery exists", CallbackDispatcher.hasHandler(21));
		CallbackDispatcher.deliver(21, 0x20, 0, 0, 0, 0.0, "");
		assert("handler registered during delivery fires", secondCalls == 1);

		// A handler that REPLACES itself mid-delivery
		var oldCalls = 0;
		var newCalls = 0;
		CallbackDispatcher.setCallback(30, _ -> {
			oldCalls++;
			CallbackDispatcher.setCallback(30, _ -> newCalls++, 0x20);
		}, 0x20);
		CallbackDispatcher.deliver(30, 0x20, 0, 0, 0, 0.0, "");
		CallbackDispatcher.deliver(30, 0x20, 0, 0, 0, 0.0, "");
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
		CallbackDispatcher.deliver(40, 0x02, 0, 0, 0, 0.0, "");
		assert("destroyed delivered", destroyedSeen);
		assert("destroyed handle auto-removed", !CallbackDispatcher.hasHandler(40));
		assert("registration from destroyed handler survives", CallbackDispatcher.hasHandler(41));

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
