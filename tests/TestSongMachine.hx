package tests;

import haxefmod.FmodManager;
import haxefmod.studio.CallbackDispatcher;
import haxefmod.studio.Callbacks;
import haxefmod.studio.native.NativeStudioStub;

/**
 * The facade's song state machine against the stub's synthetic handles:
 * same-song restart semantics, the transition handoff (both the callback
 * path and the direct path for a fade that finished before the handler
 * armed), and once-registration consumption. The playback-state queue
 * scripts what each getPlaybackState call observes, so the async gaps the
 * real backends produce become deterministic here.
 */
class TestSongMachine {
	static var passed = 0;
	static var failed = 0;

	public static function run():Int {
		Sys.println("--- Song state machine ---");

		NativeStudioStub.testSyntheticHandles = true;

		testSameSongRestartSemantics();
		testTransitionCallbackHandoff();
		testTransitionDirectHandoff();
		testStopCancelsTransition();
		testOnceConsumedByRestart();

		NativeStudioStub.testSyntheticHandles = false;
		NativeStudioStub.testPlaybackStateQueue = [];
		NativeStudioStub.testPlaybackState = 2;
		CallbackDispatcher.clearAll();

		Sys.println('  $passed passed, $failed failed');
		return failed;
	}

	/** Plays a song and returns its synthetic instance handle. */
	static function playSong(path:String):Int {
		FmodManager.PlaySong(path);
		// PlaySong ends with evd_create_instance, so the counter holds the
		// instance handle
		return NativeStudioStub.testNextHandle;
	}

	static function testSameSongRestartSemantics() {
		// FmodPlaybackState: PLAYING=0 SUSTAINING=1 STOPPED=2 STARTING=3 STOPPING=4
		playSong("event:/Same");
		var startsBefore = NativeStudioStub.testStartCalls;

		// A sustaining, starting, or playing song is left alone
		for (state in [1, 3, 0]) {
			NativeStudioStub.testPlaybackStateQueue = [state];
			FmodManager.PlaySong("event:/Same");
		}
		assert("redundant play leaves an active song alone",
			NativeStudioStub.testStartCalls == startsBefore);

		// A stopped or fading song is restarted
		NativeStudioStub.testPlaybackStateQueue = [2];
		FmodManager.PlaySong("event:/Same");
		NativeStudioStub.testPlaybackStateQueue = [4];
		FmodManager.PlaySong("event:/Same");
		assert("stopped and fading songs restart",
			NativeStudioStub.testStartCalls == startsBefore + 2);

		// Song-level playing predicate over the same states
		for (state in [0, 1, 3, 4]) {
			NativeStudioStub.testPlaybackStateQueue = [state];
			assert('IsSongPlaying true for state $state', FmodManager.IsSongPlaying());
		}
		NativeStudioStub.testPlaybackStateQueue = [2];
		assert("IsSongPlaying false for stopped", !FmodManager.IsSongPlaying());
	}

	static function testTransitionCallbackHandoff() {
		var handleA = playSong("event:/A");
		// Entry check sees a playing song, the post-stop check still sees
		// the fade in progress: the handoff waits for the callback
		NativeStudioStub.testPlaybackStateQueue = [0, 4];
		FmodManager.PlaySongTransition("event:/B");
		assert("transition armed on the current song", CallbackDispatcher.hasHandler(handleA));
		assert("slot unchanged while the fade runs",
			FmodManager.GetCurrentSongPath() == "event:/A");

		// The Stopped event arrives through the queue and hands off
		CallbackDispatcher.deliver(handleA, 0x20, 0, 0, 0, 0, 0, 0.0, "");
		assert("callback handoff played the next song",
			FmodManager.GetCurrentSongPath() == "event:/B");
		assert("old song handler cleaned up", !CallbackDispatcher.hasHandler(handleA));
	}

	static function testTransitionDirectHandoff() {
		var handleA = playSong("event:/A");
		// Entry check sees the song mid-fade, the post-stop check sees the
		// fade already complete: no Stopped will ever arrive for the armed
		// handler, so the transition must hand off directly
		NativeStudioStub.testPlaybackStateQueue = [4, 2];
		FmodManager.PlaySongTransition("event:/B");
		assert("direct handoff played the next song",
			FmodManager.GetCurrentSongPath() == "event:/B");

		// A late queued Stopped for the old song is a harmless no-op
		var pathBefore = FmodManager.GetCurrentSongPath();
		CallbackDispatcher.deliver(handleA, 0x20, 0, 0, 0, 0, 0, 0.0, "");
		assert("late Stopped after the direct handoff changes nothing",
			FmodManager.GetCurrentSongPath() == pathBefore);
	}

	static function testStopCancelsTransition() {
		var handleA = playSong("event:/A");
		NativeStudioStub.testPlaybackStateQueue = [0, 4];
		FmodManager.PlaySongTransition("event:/B");
		FmodManager.StopSong();
		// The stop cleared the pending transition, so the fade completing
		// must stay silent
		CallbackDispatcher.deliver(handleA, 0x20, 0, 0, 0, 0, 0, 0.0, "");
		assert("stop cancels the pending transition",
			FmodManager.GetCurrentSongPath() == "event:/A");
	}

	static function testOnceConsumedByRestart() {
		var handleA = playSong("event:/A");
		var sawStopped = false;
		var calls = 0;
		// The state-transition utility registers exactly this shape:
		// once, masked to STOPPED and RESTARTED
		FmodManager.OnceSongEvent(data -> {
			calls++;
			switch (data) {
				case Stopped: sawStopped = true;
				default:
			}
		}, EventCallbackType.STOPPED | EventCallbackType.RESTARTED);

		// A direct same-song play during the fade delivers RESTARTED: the
		// registration is consumed without acting
		CallbackDispatcher.deliver(handleA, 0x10, 0, 0, 0, 0, 0, 0.0, "");
		assert("restart consumed the once registration",
			!CallbackDispatcher.hasHandler(handleA));
		assert("restart did not act as a stop", calls == 1 && !sawStopped);

		// A later stop cannot re-fire it
		CallbackDispatcher.deliver(handleA, 0x20, 0, 0, 0, 0, 0, 0.0, "");
		assert("consumed registration stays consumed", calls == 1 && !sawStopped);
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
