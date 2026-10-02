package tests;

import flixel.FlxG;
import haxefmod.FmodManager;
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
		FmodFlxUtilities.TransitionToStateAndStopMusic("X");
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

		Sys.println('  $passed passed, $failed failed');
		Sys.exit(failed > 0 ? 1 : 0);
	}
}
