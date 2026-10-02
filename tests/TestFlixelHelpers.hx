package tests;

import flixel.FlxG;
import haxefmod.FmodManager;
import haxefmod.flixel.FmodFlxListener;
import haxefmod.flixel.FmodFlxUpdater;
import haxefmod.flixel.FmodFlxUtilities;
import haxefmod.studio.CallbackDispatcher;
import haxefmod.studio.native.NativeStudioStub;

/**
 * FmodFlxUtilities.TransitionToStateAndStopMusic on the stub backend,
 * against the flixel stand-ins in tests/stubs-flixel. Run with
 * haxe tests/build-flixel-helpers.hxml.
 */
class TestFlixelHelpers {
	static var passed = 0;
	static var failed = 0;

	static inline var RESTARTED = 0x10;
	static inline var STOPPED = 0x20;
	static inline var PLAYING = 0;
	static inline var STOPPED_STATE = 2;
	static inline var STOPPING = 4;

	static function assert(name:String, condition:Bool):Void {
		if (condition) passed++ else {
			failed++;
			Sys.println('  FAIL: $name (switches=${FlxG.switches})');
		}
	}

	static function playSong(path:String):Int {
		FmodManager.PlaySong(path);
		return NativeStudioStub.testNextHandle;
	}

	static function deliver(handle:Int, type:Int):Void {
		CallbackDispatcher.deliver(handle, type, 0, 0, 0, 0, 0, 0.0, "");
	}

	// The updater's own handler stays, every poll a case left behind goes
	static function reset():Void {
		FlxG.switches = [];
		FlxG.signals.postUpdate.handlers = FlxG.signals.postUpdate.handlers.slice(0, 1);
		NativeStudioStub.testPlaybackStateQueue = [];
		NativeStudioStub.testPlaybackState = PLAYING;
	}

	// The camera-follow listener treats a jump past one view width as a
	// cut. The view width is the camera width over its zoom.
	static function testListenerCut():Void {
		FlxG.camera = new flixel.FlxCamera(640, 480, 2);
		var listener = new FmodFlxListener();
		NativeStudioStub.testRecordListenerPushes = true;
		NativeStudioStub.testListenerPushes = [];
		listener.update(0.5);
		FlxG.camera.scroll.x = 320;
		listener.update(0.5);
		var step = NativeStudioStub.testListenerPushes[1];
		assert("a camera move of one view width is movement", step != null && step.vx == 640 && step.x == 640);
		FlxG.camera.scroll.x = 641;
		listener.update(0.5);
		var cut = NativeStudioStub.testListenerPushes[2];
		assert("a camera move past one view width is a cut", cut != null && cut.vx == 0 && cut.x == 961);
		listener.teleportDistance = 400;
		FlxG.camera.scroll.x = 1041;
		listener.update(0.5);
		var set = NativeStudioStub.testListenerPushes[3];
		assert("a set teleportDistance replaces the view width", set != null && set.vx == 800);
		NativeStudioStub.testRecordListenerPushes = false;
		FlxG.camera = null;
	}

	// A removeHook from a listener that runs before the updater in the
	// same dispatch stops the update in that frame. Flixel still calls
	// the removed hook once. The generation check makes it return early.
	static function testUpdaterRemovedInDispatch():Void {
		var updates = 0;
		var savedHook = CallbackDispatcher.frameHook;
		CallbackDispatcher.frameHook = () -> updates++;
		var armed = false;
		var remover = () -> if (armed) {
			armed = false;
			FmodFlxUpdater.removeHook();
		};
		FmodFlxUpdater.removeHook();
		FlxG.signals.postUpdate.add(remover);
		FmodFlxUpdater.init();
		FlxG.frame();
		var before = updates;
		armed = true;
		FlxG.frame();
		assert("a hook removed earlier in the dispatch does not update", updates == before);
		FmodFlxUpdater.init();
		FlxG.frame();
		FlxG.frame();
		assert("init after removeHook updates once per frame", updates == before + 2);
		FlxG.signals.postUpdate.remove(remover);
		CallbackDispatcher.frameHook = savedHook;
	}

	static function main() {
		Sys.println("--- Flixel helpers (stub backend, stub flixel) ---");
		NativeStudioStub.testSyntheticHandles = true;
		NativeStudioStub.testInitialized = true;
		NativeStudioStub.testCallbackMaskResult = 0;
		FmodManager.Initialize();
		FmodFlxUpdater.init();
		NativeStudioStub.testPlaybackState = PLAYING;

		// The fade ends with a Stopped
		var song = playSong("event:/A");
		NativeStudioStub.testLastStopMode = -1;
		FmodFlxUtilities.TransitionToStateAndStopMusic("X");
		assert("the song fades out as authored", NativeStudioStub.testLastStopMode == 0);
		assert("the registration asks for RESTARTED", NativeStudioStub.testLastCallbackMask & RESTARTED != 0);
		NativeStudioStub.testPlaybackState = STOPPED_STATE;
		deliver(song, STOPPED);
		FlxG.frame();
		assert("a completed fade switches once", FlxG.switches.join(",") == "X");
		for (i in 0...10) FlxG.frame();
		assert("the poll leaves after the switch", FlxG.switches.join(",") == "X" && FlxG.signals.postUpdate.handlers.length == 1);

		// A same-song PlaySong during the fade cancels the switch for good
		reset();
		song = playSong("event:/B");
		FmodFlxUtilities.TransitionToStateAndStopMusic("X");
		NativeStudioStub.testPlaybackState = STOPPING;
		FlxG.frame();
		FmodManager.PlaySong("event:/B");
		NativeStudioStub.testPlaybackState = PLAYING;
		deliver(song, RESTARTED);
		for (i in 0...100) FlxG.frame();
		assert("a restart during the fade cancels the switch", FlxG.switches.length == 0);
		assert("the poll leaves after a restart", FlxG.signals.postUpdate.handlers.length == 1);
		FmodManager.StopSongImmediately();
		NativeStudioStub.testPlaybackState = STOPPED_STATE;
		deliver(song, STOPPED);
		FlxG.frame();
		assert("a later stop after a cancelled switch does not switch", FlxG.switches.length == 0);

		// A second call during the fade wins
		reset();
		song = playSong("event:/C");
		FmodFlxUtilities.TransitionToStateAndStopMusic("X");
		NativeStudioStub.testPlaybackState = STOPPING;
		FlxG.frame();
		FmodFlxUtilities.TransitionToStateAndStopMusic("Y");
		FlxG.frame();
		NativeStudioStub.testPlaybackState = STOPPED_STATE;
		deliver(song, STOPPED);
		FlxG.frame();
		assert("a second call during the fade switches to its own state only", FlxG.switches.join(",") == "Y");

		// PlaySongTransition during the fade cancels the switch
		reset();
		song = playSong("event:/D");
		FmodFlxUtilities.TransitionToStateAndStopMusic("X");
		NativeStudioStub.testPlaybackState = STOPPING;
		FlxG.frame();
		FmodManager.PlaySongTransition("event:/E");
		FlxG.frame();
		assert("the poll leaves when a song transition takes the slot", FlxG.signals.postUpdate.handlers.length == 1);
		NativeStudioStub.testPlaybackState = STOPPED_STATE;
		deliver(song, STOPPED);
		NativeStudioStub.testPlaybackState = PLAYING;
		FlxG.frame();
		for (i in 0...50) FlxG.frame();
		FmodManager.StopSong();
		NativeStudioStub.testPlaybackState = STOPPED_STATE;
		FlxG.frame();
		assert("a song transition during the fade cancels the switch", FlxG.switches.length == 0);

		// A bank unload destroys the fading song. No Stopped arrives.
		reset();
		song = playSong("event:/F");
		FmodFlxUtilities.TransitionToStateAndStopMusic("X");
		NativeStudioStub.testPlaybackState = STOPPING;
		FlxG.frame();
		assert("the switch waits while the song fades", FlxG.switches.length == 0);
		NativeStudioStub.testReleasedHandles.push(song);
		NativeStudioStub.testPlaybackState = STOPPED_STATE;
		FlxG.frame();
		assert("a song that died with its bank still switches", FlxG.switches.join(",") == "X");
		assert("the poll leaves after a bank unload switch", FlxG.signals.postUpdate.handlers.length == 1);

		// The game's own song handler during the fade cancels the switch
		reset();
		song = playSong("event:/G");
		FmodFlxUtilities.TransitionToStateAndStopMusic("X");
		NativeStudioStub.testPlaybackState = STOPPING;
		FlxG.frame();
		FmodManager.OnSongEvent(_ -> {});
		NativeStudioStub.testPlaybackState = STOPPED_STATE;
		deliver(song, STOPPED);
		FlxG.frame();
		assert("a song handler set during the fade cancels the switch", FlxG.switches.length == 0);

		// No song plays. The switch is immediate and nothing stays armed.
		reset();
		FmodManager.StopSongImmediately();
		NativeStudioStub.testPlaybackState = STOPPED_STATE;
		FmodFlxUtilities.TransitionToStateAndStopMusic("Z");
		assert("with no song the switch is immediate", FlxG.switches.join(",") == "Z" && FlxG.signals.postUpdate.handlers.length == 1);

		// The fade ended before the handler was armed. No Stopped comes.
		reset();
		song = playSong("event:/J");
		NativeStudioStub.testPlaybackStateQueue = [STOPPING];
		NativeStudioStub.testPlaybackState = STOPPED_STATE;
		FmodFlxUtilities.TransitionToStateAndStopMusic("X");
		assert("a fade that ended before the call switches in the call", FlxG.switches.join(",") == "X" && FlxG.signals.postUpdate.handlers.length == 1);
		NativeStudioStub.testPlaybackState = PLAYING;

		// Another song replaces the fading one
		reset();
		song = playSong("event:/H");
		FmodFlxUtilities.TransitionToStateAndStopMusic("X");
		NativeStudioStub.testPlaybackState = STOPPING;
		FlxG.frame();
		var other = playSong("event:/I");
		NativeStudioStub.testPlaybackState = PLAYING;
		FlxG.frame();
		assert("the poll leaves when another song replaces the fading one", FlxG.signals.postUpdate.handlers.length == 1);
		FmodManager.StopSongImmediately();
		NativeStudioStub.testPlaybackState = STOPPED_STATE;
		deliver(other, STOPPED);
		FlxG.frame();
		assert("another song during the fade cancels the switch", FlxG.switches.length == 0);

		// Regression: a switch by another route during the fade did not
		// cancel the switch, so the game left the new state for the old target.
		// Here the Stopped arrives before the poll runs.
		reset();
		song = playSong("event:/K");
		FmodFlxUtilities.TransitionToStateAndStopMusic("X");
		NativeStudioStub.testPlaybackState = STOPPING;
		FlxG.frame();
		FlxG.state = "Y";
		NativeStudioStub.testPlaybackState = STOPPED_STATE;
		deliver(song, STOPPED);
		FlxG.frame();
		assert("a switch by another route during the fade cancels the switch", FlxG.switches.length == 0);
		FlxG.state = "Start";

		// The poll sees the new state while the song still fades
		reset();
		song = playSong("event:/L");
		FmodFlxUtilities.TransitionToStateAndStopMusic("X");
		NativeStudioStub.testPlaybackState = STOPPING;
		FlxG.frame();
		FlxG.state = "Y";
		FlxG.frame();
		assert("the poll leaves after a switch by another route", FlxG.signals.postUpdate.handlers.length == 1);
		FlxG.state = "Start";

		reset();
		song = playSong("event:/M");
		FmodFlxUtilities.TransitionToStateAndStopMusic("X");
		NativeStudioStub.testPlaybackState = STOPPING;
		FlxG.frame();
		FlxG.state = "Y";
		NativeStudioStub.testReleasedHandles.push(song);
		NativeStudioStub.testPlaybackState = STOPPED_STATE;
		FlxG.frame();
		assert("a switch by another route before a bank unload cancels the switch", FlxG.switches.length == 0);
		FlxG.state = "Start";

		testListenerCut();
		testUpdaterRemovedInDispatch();

		// A component created after removeHook leaves the hook out
		FmodFlxUpdater.removeHook();
		FmodFlxUpdater.initUnlessRemoved();
		assert("a component created after removeHook leaves the hook out", !FmodFlxUpdater.isInstalled());
		FmodFlxUpdater.init();
		FmodFlxUpdater.removeHook();
		FmodFlxUpdater.init();
		FmodFlxUpdater.initUnlessRemoved();
		assert("init puts the hook back for later components", FmodFlxUpdater.isInstalled());

		Sys.println('  $passed passed, $failed failed');
		Sys.exit(failed > 0 ? 1 : 0);
	}
}
