package tests;

import haxefmod.FmodSound;
import haxefmod.runtime.FmodRuntime;
import haxefmod.studio.native.NativeStudioStub;

/**
 * Playback-state predicates and the ready hook, against the stub backend's
 * test hooks. FMOD starts and stops instances asynchronously, so "playing"
 * must cover STARTING, SUSTAINING, and STOPPING, not just PLAYING.
 */
class TestFacadePredicates {
	static var passed = 0;
	static var failed = 0;

	public static function run():Int {
		Sys.println("--- Facade predicates ---");

		testIsPlayingStates();
		testOnceReady();

		Sys.println('  $passed passed, $failed failed');
		return failed;
	}

	static function testIsPlayingStates() {
		var sound:FmodSound = cast 123;

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

	static function assert(name:String, condition:Bool) {
		if (condition) {
			passed++;
		} else {
			failed++;
			Sys.println('  FAIL: $name');
		}
	}
}
