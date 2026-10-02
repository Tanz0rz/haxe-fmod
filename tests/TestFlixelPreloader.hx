package tests;

import haxefmod.flixel.FmodFlxPreloader;
import haxefmod.flixel.FmodFlxUpdater;
import haxefmod.runtime.FmodRuntime;
import haxefmod.studio.native.NativeStudioStub;

/**
 * FmodFlxPreloader on the stub backend, against the flixel, openfl and
 * lime stand-ins in tests/stubs-flixel. One default bank is missing from
 * the assets and one is fetched by the preloader. Initialization waits
 * for the fetch, the failure stays up for failureDisplayTime, and the
 * game starts after it. One init per process, so this suite owns its
 * own. Run with haxe tests/build-flixel-preloader.hxml.
 */
class TestFlixelPreloader {
	static var passed = 0;
	static var failed = 0;

	static function assert(name:String, condition:Bool):Void {
		if (condition) passed++ else {
			failed++;
			Sys.println('  FAIL: $name');
		}
	}

	static function main() {
		Sys.println("--- Flixel preloader (stub backend, stub flixel) ---");
		var stub = NativeStudioStub;
		stub.testSyntheticHandles = true;
		stub.testInitialized = true;
		var originalTrace = haxe.Log.trace;
		var traces:Array<String> = [];
		haxe.Log.trace = function(v:Dynamic, ?infos:haxe.PosInfos) traces.push(Std.string(v));

		// Master.bank is not among the assets. Master.strings.bank is, and
		// lime has not preloaded it.
		var stringsPath = FmodRuntime.bankPath("Master.strings.bank", "assets/fmod/Desktop");
		openfl.utils.Assets.files.set(stringsPath, haxe.io.Bytes.alloc(24));
		var fetch = new lime.utils.Assets.PendingBytes();
		lime.utils.Assets.remote.set(stringsPath, fetch);

		var preloader = new ShortFailurePreloader();
		@:privateAccess preloader.create();
		assert("the visuals draw once the stage has a size", preloader.visualsDrawn == 1);
		preloader.frame();
		assert("nothing initializes before the assets are in", stub.testLastInit == null);

		preloader.onLoaded();
		lime.utils.Assets.libraryRegistered = true;
		preloader.frame();
		assert("initialization waits for a bank the preloader fetches", stub.testLastInit == null && !preloader.finished);

		fetch.complete(haxe.io.Bytes.alloc(24));
		var failedFrame = haxe.Timer.stamp();
		preloader.frame();
		assert("the fetched bank loads from its bytes", stub.testLastInit != null && FmodRuntime.providedBankCount() == 1);
		assert("a missing default bank fails initialization", FmodRuntime.initFailed()
			&& traces.filter(t -> t.indexOf("Master.bank could not be provided") >= 0).length == 1);
		assert("the failure shows and the game waits", !preloader.finished && preloader.children.length == 1);

		var limit = failedFrame + 5;
		while (!preloader.finished && haxe.Timer.stamp() < limit) {
			Sys.sleep(0.01);
			preloader.frame();
		}
		var shown = haxe.Timer.stamp() - failedFrame;
		assert('the game starts after the failure display time (finished=${preloader.finished})', preloader.finished);
		assert('the failure stays up for failureDisplayTime (shown=$shown)', shown >= preloader.failureDisplayTime);
		assert("the preloader installs the updater", FmodFlxUpdater.isInstalled());
		assert("destroy removes the failure text", preloader.children.length == 0);

		haxe.Log.trace = originalTrace;
		Sys.println('  $passed passed, $failed failed');
		Sys.exit(failed > 0 ? 1 : 0);
	}
}

private class ShortFailurePreloader extends FmodFlxPreloader {
	public function new() {
		super();
		failureDisplayTime = 0.3;
	}
}
