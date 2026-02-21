package tests;

import haxefmod.FmodCallbackManager;
import haxefmod.FmodEvents.FmodCallback;

class TestFmodCallbackManager {
	static var passed = 0;
	static var failed = 0;

	public static function run():Int {
		Sys.println("--- FmodCallbackManager ---");

		testHasCallbackFalseInitially();
		testRegisterAndHasCallback();
		testUnregisterCallback();
		testGetRegistrationCount();
		testClearAll();
		testGetRegistrationData();
		testProcessCallbacksInvokesMatching();
		testProcessCallbacksSkipsNonMatching();
		testProcessCallbacksMultipleRegistrations();
		testOverwriteRegistration();

		Sys.println('  $passed passed, $failed failed');
		return failed;
	}

	static function setUp():FmodCallbackManager {
		var mgr = FmodCallbackManager.getInstance();
		mgr.clearAll();
		return mgr;
	}

	static function testHasCallbackFalseInitially() {
		var mgr = setUp();
		assert("no callback initially", !mgr.hasCallback("mySound"));
	}

	static function testRegisterAndHasCallback() {
		var mgr = setUp();
		mgr.registerCallback("mySound", "event:/SFX/Jump", 5, () -> {}, FmodCallback.STOPPED);
		assert("hasCallback after register", mgr.hasCallback("mySound"));
	}

	static function testUnregisterCallback() {
		var mgr = setUp();
		mgr.registerCallback("mySound", "event:/SFX/Jump", 5, () -> {}, FmodCallback.STOPPED);
		mgr.unregisterCallback("mySound");
		assert("no callback after unregister", !mgr.hasCallback("mySound"));
	}

	static function testGetRegistrationCount() {
		var mgr = setUp();
		assert("count 0 initially", mgr.getRegistrationCount() == 0);
		mgr.registerCallback("a", "event:/A", 1, () -> {}, FmodCallback.STOPPED);
		assert("count 1 after one register", mgr.getRegistrationCount() == 1);
		mgr.registerCallback("b", "event:/B", 2, () -> {}, FmodCallback.STARTED);
		assert("count 2 after two registers", mgr.getRegistrationCount() == 2);
		mgr.unregisterCallback("a");
		assert("count 1 after unregister", mgr.getRegistrationCount() == 1);
	}

	static function testClearAll() {
		var mgr = setUp();
		mgr.registerCallback("a", "event:/A", 1, () -> {}, FmodCallback.STOPPED);
		mgr.registerCallback("b", "event:/B", 2, () -> {}, FmodCallback.STARTED);
		mgr.clearAll();
		assert("count 0 after clearAll", mgr.getRegistrationCount() == 0);
		assert("hasCallback false after clearAll", !mgr.hasCallback("a"));
	}

	static function testGetRegistrationData() {
		var mgr = setUp();
		var fn = () -> {};
		mgr.registerCallback("mySound", "event:/SFX/Jump", 42, fn, FmodCallback.STOPPED);
		var reg = mgr.getRegistration("mySound");
		assert("registration not null", reg != null);
		assert("registration has correct handle", reg.handle == 42);
		assert("registration has correct eventPath", reg.eventPath == "event:/SFX/Jump");
		assert("registration has correct mask", reg.playbackEventMask == FmodCallback.STOPPED);
		assert("registration has correct callback", reg.callbackFunction == fn);
		assert("getRegistration null for unknown", mgr.getRegistration("nonexistent") == null);
	}

	static function testProcessCallbacksInvokesMatching() {
		var mgr = setUp();
		var callCount = 0;
		mgr.registerCallback("mySound", "event:/SFX/Jump", 5, () -> callCount++, FmodCallback.STOPPED);

		// Simulate native layer saying "yes, callback fired"
		mgr.processCallbacks((handle, mask) -> true);
		assert("callback invoked once", callCount == 1);

		mgr.processCallbacks((handle, mask) -> true);
		assert("callback invoked again on next poll", callCount == 2);
	}

	static function testProcessCallbacksSkipsNonMatching() {
		var mgr = setUp();
		var callCount = 0;
		mgr.registerCallback("mySound", "event:/SFX/Jump", 5, () -> callCount++, FmodCallback.STOPPED);

		// Simulate native layer saying "no, callback didn't fire"
		mgr.processCallbacks((handle, mask) -> false);
		assert("callback not invoked when check returns false", callCount == 0);
	}

	static function testProcessCallbacksMultipleRegistrations() {
		var mgr = setUp();
		var countA = 0;
		var countB = 0;
		mgr.registerCallback("a", "event:/A", 1, () -> countA++, FmodCallback.STOPPED);
		mgr.registerCallback("b", "event:/B", 2, () -> countB++, FmodCallback.STARTED);

		// Only fire for handle 1
		mgr.processCallbacks((handle, mask) -> handle == 1);
		assert("callback A invoked", countA == 1);
		assert("callback B not invoked", countB == 0);
	}

	static function testOverwriteRegistration() {
		var mgr = setUp();
		var countOld = 0;
		var countNew = 0;
		mgr.registerCallback("mySound", "event:/SFX/Jump", 1, () -> countOld++, FmodCallback.STOPPED);
		mgr.registerCallback("mySound", "event:/SFX/Land", 2, () -> countNew++, FmodCallback.STARTED);

		assert("count still 1 after overwrite", mgr.getRegistrationCount() == 1);
		mgr.processCallbacks((handle, mask) -> true);
		assert("old callback not invoked", countOld == 0);
		assert("new callback invoked", countNew == 1);
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
