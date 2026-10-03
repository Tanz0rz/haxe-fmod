package tests;

import haxefmod.FmodEvent;
import haxefmod.runtime.FmodRuntime;
import haxefmod.studio.native.NativeStudioStub;

/**
 * Playback-state predicates and the ready hook, against the stub backend's
 * test hooks. FMOD starts and stops instances asynchronously, so "playing"
 * must cover STARTING, SUSTAINING, and STOPPING as well as PLAYING.
 */
class TestHelperPredicates {
	static var passed = 0;
	static var failed = 0;

	public static function run():Int {
		Sys.println("--- helper class predicates ---");

		testIsPlayingStates();
		testOnceReady();
		probeEvent();

		Sys.println('  $passed passed, $failed failed');
		return failed;
	}

	static function testIsPlayingStates() {
		var sound:FmodEvent = cast 123;

		// FmodPlaybackState: PLAYING=0 SUSTAINING=1 STOPPED=2 STARTING=3 STOPPING=4
		NativeStudioStub.testPlaybackState = 0;
		assert("playing counts as playing", sound.isPlaying());
		NativeStudioStub.testPlaybackState = 3;
		assert("starting counts as playing", sound.isPlaying());
		NativeStudioStub.testPlaybackState = 1;
		assert("sustaining counts as playing", sound.isPlaying());
		NativeStudioStub.testPlaybackState = 4;
		assert("stopping counts as playing", sound.isPlaying());
		NativeStudioStub.testPlaybackState = 2;
		assert("stopped is not playing", !sound.isPlaying());

		NativeStudioStub.testPlaybackState = 2;
	}

	static function testOnceReady() {
		// The ready latch inside FmodRuntime never resets, so the queued
		// path below is testable exactly once per process. This test must
		// run before anything else services FmodRuntime.update while the
		// stub reports initialized.
		// Not ready: the handler queues and fires on the first serviced
		// frame after initialization completes, exactly once
		NativeStudioStub.testInitialized = false;
		var calls = 0;
		FmodRuntime.onceReady(() -> calls++);
		assert("handler waits for ready", calls == 0);
		FmodRuntime.update();
		assert("handler still waiting while uninitialized", calls == 0);
		NativeStudioStub.testInitialized = true;
		FmodRuntime.update();
		assert("handler fired on first ready frame", calls == 1);
		FmodRuntime.update();
		assert("handler fired exactly once", calls == 1);

		// Already ready: the handler runs immediately
		var immediate = 0;
		FmodRuntime.onceReady(() -> immediate++);
		assert("handler immediate when ready", immediate == 1);

		NativeStudioStub.testInitialized = false;
	}


	static function probeEvent() {
		NativeStudioStub.testSyntheticHandles = true;
		var evh = ++NativeStudioStub.testNextHandle;
		var ev:FmodEvent = cast evh;
		var fired = 0;
		ev.onceEvent(_ -> fired++, 0x20);
		haxefmod.studio.CallbackDispatcher.deliver(evh, 0x2, 0, 0, 0, 0, 0, 0.0, "");
		assert("PROBE onceEvent ignores a Destroyed outside its mask and ends", fired == 0 && !haxefmod.studio.CallbackDispatcher.hasHandler(evh));
		var ev2h = ++NativeStudioStub.testNextHandle;
		var ev2:FmodEvent = cast ev2h;
		ev2.onceEvent(_ -> fired++);
		haxefmod.studio.CallbackDispatcher.deliver(ev2h, 0x20, 0, 0, 0, 0, 0, 0.0, "");
		haxefmod.studio.CallbackDispatcher.deliver(ev2h, 0x20, 0, 0, 0, 0, 0, 0.0, "");
		assert("PROBE onceEvent fires once", fired == 1 && !haxefmod.studio.CallbackDispatcher.hasHandler(ev2h));
		NativeStudioStub.testPausedState = null;
		ev.pause();
		var paused = NativeStudioStub.testPausedState;
		ev.unpause();
		assert("PROBE pause and unpause reach the instance", paused == true && NativeStudioStub.testPausedState == false);
		var starts = NativeStudioStub.testStartCalls;
		ev.start();
		assert("PROBE start reaches the instance", NativeStudioStub.testStartCalls == starts + 1);
		ev.setPosition2D(1, 2, 3, 4);
		var last = NativeStudioStub.testLast3d;
		assert("PROBE setPosition2D passes the velocity", last != null && last[3] == 3 && last[4] == 4);
		NativeStudioStub.testLastStopMode = -1;
		ev.stop();
		var fadeMode = NativeStudioStub.testLastStopMode;
		ev.stopImmediately();
		assert("PROBE stop fades out and stopImmediately cuts", fadeMode == (haxefmod.studio.Types.FmodStopMode.ALLOWFADEOUT : Int)
			&& NativeStudioStub.testLastStopMode == (haxefmod.studio.Types.FmodStopMode.IMMEDIATE : Int));
		ev.onEvent(_ -> {}, 0x40);
		assert("PROBE onEvent passes its mask", NativeStudioStub.testLastCallbackMaskHandle == evh && NativeStudioStub.testLastCallbackMask & 0x40 != 0
			&& NativeStudioStub.testLastCallbackMask & 0x20 == 0);
		NativeStudioStub.testReleasedHandles.push(evh);
		assert("PROBE isValid asks the native side", !ev.isValid() && !ev.isNull());
		NativeStudioStub.testReleasedHandles.remove(evh);
		haxefmod.studio.CallbackDispatcher.clearAll();
		NativeStudioStub.testSyntheticHandles = false;
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
