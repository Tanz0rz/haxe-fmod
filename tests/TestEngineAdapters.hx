package tests;

import h2d.col.Bounds;
import haxefmod.heaps.FmodHeapsBankLoader;
import haxefmod.heaps.FmodHeapsEmitter;
import haxefmod.heaps.FmodHeapsParameterTrigger;
import haxefmod.heaps.FmodHeapsUpdater;
import haxefmod.heaps.FmodHeapsUtilities;
import haxefmod.kha.FmodKhaBankLoader;
import haxefmod.kha.FmodKhaEmitter;
import haxefmod.kha.FmodKhaParameterTrigger;
import haxefmod.kha.FmodKhaSetup;
import haxefmod.kha.FmodKhaUpdater;
import haxefmod.kha.FmodKhaUtilities;
import haxefmod.runtime.FmodRuntime;
import haxefmod.studio.native.NativeStudioStub;

/**
 * The Heaps and Kha emitters, zone triggers, attached one-shots and
 * bank loaders on the stub backend, against the stand-ins in
 * tests/stubs. The hooks stay out, so the tests tick the components
 * and run the updaters' update() by hand.
 */
class TestEngineAdapters {
	static var passed = 0;
	static var failed = 0;
	static var stub = NativeStudioStub;

	public static function run():Int {
		Sys.println("--- Engine adapters (stub backend) ---");
		FmodHeapsUpdater.removeHook();
		FmodKhaUpdater.removeHook();
		var savedInit = stub.testInitialized;
		var savedSynthetic = stub.testSyntheticHandles;
		var savedState = stub.testPlaybackState;
		var savedBankState = stub.testBankLoadingState;
		stub.testInitialized = true;
		// Earlier suites attach handles that read as dead without
		// synthetic handles. One update prunes them, so the last 3D push
		// is the one a case makes.
		stub.testSyntheticHandles = false;
		FmodRuntime.update();
		stub.testSyntheticHandles = true;
		stub.testPlaybackState = 0; // PLAYING
		stub.testBankLoadingState = 3; // LOADED
		testHeaps();
		testKha();
		testKhaBlobName();
		stub.testBankLoadingState = savedBankState;
		stub.testPlaybackState = savedState;
		stub.testSyntheticHandles = false;
		FmodRuntime.update();
		stub.testSyntheticHandles = savedSynthetic;
		stub.testInitialized = savedInit;
		Sys.println('  $passed passed, $failed failed');
		return failed;
	}

	static function assert(condition:Bool, name:String):Void {
		if (condition) passed++ else {
			failed++;
			Sys.println('  FAIL: $name');
		}
	}

	static function pushed():String {
		var p = stub.testLast3d;
		return p == null ? "none" : '(${p[1]}, ${p[2]}) v=(${p[3]}, ${p[4]})';
	}

	static function object(x:Float, y:Float, width:Float, height:Float):h2d.Object {
		var o = new h2d.Object();
		o.x = x;
		o.y = y;
		o.width = width;
		o.height = height;
		return o;
	}

	static function testHeaps():Void {
		// The emitter's attach push carries the object's center
		var car = object(40, 60, 10, 20);
		var tickers = FmodHeapsUpdater.count();
		stub.testLast3d = null;
		var emitter = FmodHeapsEmitter.play("event:/Adapters/Engine", car);
		var p = stub.testLast3d;
		assert(p != null && p[1] == 45 && p[2] == 70, 'heaps: an emitter starts at the object center ${pushed()}');
		assert(FmodHeapsUpdater.count() == tickers + 1, "heaps: an emitter registers with the updater");
		// A set teleportDistance reaches the velocity derivation
		emitter.teleportDistance = 1000;
		car.x += 600;
		emitter.tick(4);
		FmodRuntime.update();
		p = stub.testLast3d;
		assert(p != null && p[1] == 645 && p[3] == 150, 'heaps: an emitter teleportDistance replaces the default ${pushed()}');
		emitter.dispose();
		assert(FmodHeapsUpdater.count() == tickers && FmodRuntime.attachedCount() == 0,
			'heaps: dispose unregisters the emitter and detaches it (tickers=${FmodHeapsUpdater.count() - tickers})');

		// A wide zone stays wide. The center (300, 50) is inside 400 x 100.
		var body = object(295, 45, 10, 10);
		stub.testLastGlobalParameter = null;
		var trigger = new FmodHeapsParameterTrigger(body, Bounds.fromValues(0, 0, 400, 100), "Zone", 1, 0);
		trigger.tick(0);
		assert(stub.testLastGlobalParameter == "Zone" && stub.testLastGlobalValue == 1,
			'heaps: a zone keeps its width and height (value=${stub.testLastGlobalValue})');
		body.x = 995;
		trigger.tick(0);
		assert(stub.testLastGlobalValue == 0, "heaps: leaving the zone applies the outside value");
		tickers = FmodHeapsUpdater.count();
		trigger.dispose();
		stub.testLastGlobalParameter = null;
		body.x = 295;
		FmodHeapsUpdater.update();
		assert(FmodHeapsUpdater.count() == tickers - 1 && stub.testLastGlobalParameter == null,
			'heaps: a disposed trigger leaves the parameter alone (set=${stub.testLastGlobalParameter})');

		// The attached one-shot starts at the center, follows the object
		// while it plays, and its sampler leaves once it ended
		var mover = object(10, 20, 4, 6);
		tickers = FmodHeapsUpdater.count();
		stub.testLast3d = null;
		FmodHeapsUtilities.PlayOneShotAttached("event:/Adapters/Jump", mover);
		p = stub.testLast3d;
		assert(p != null && p[1] == 12 && p[2] == 23, 'heaps: an attached one-shot starts at the object center ${pushed()}');
		mover.x = 110;
		FmodHeapsUpdater.update();
		mover.x = 210;
		FmodHeapsUpdater.update();
		p = stub.testLast3d;
		assert(p != null && p[1] == 212 && FmodHeapsUpdater.count() == tickers + 1,
			'heaps: an attached one-shot follows the object while it plays ${pushed()}');
		stub.testPlaybackState = 2; // STOPPED
		FmodHeapsUpdater.update();
		FmodHeapsUpdater.update();
		assert(FmodRuntime.attachedCount() == 0 && FmodHeapsUpdater.count() == tickers,
			'heaps: the one-shot sampler leaves once the one-shot ended (tickers=${FmodHeapsUpdater.count() - tickers})');
		stub.testPlaybackState = 0;

		// The loader reports loaded and dispose gives its banks back
		var path = FmodRuntime.bankPath("HeapsAdapters.bank");
		var fired = 0;
		var loader = new FmodHeapsBankLoader(["HeapsAdapters.bank"], () -> fired++);
		assert(!loader.loaded, "heaps: a loader is not loaded before its first tick");
		loader.tick(0);
		assert(fired == 1 && loader.loaded && FmodRuntime.banks.refCount(path) == 1, "heaps: a loader loads, fires once and reports loaded");
		tickers = FmodHeapsUpdater.count();
		loader.dispose();
		assert(FmodRuntime.banks.refCount(path) == 0 && FmodHeapsUpdater.count() == tickers - 1,
			'heaps: dispose releases the loader banks and unregisters it (refs=${FmodRuntime.banks.refCount(path)})');
	}

	static function testKha():Void {
		var car = {x: 40.0, y: 60.0, width: 10.0, height: 20.0};
		var tickers = FmodKhaUpdater.count();
		stub.testLast3d = null;
		var emitter = FmodKhaEmitter.play("event:/Adapters/Engine", car);
		var p = stub.testLast3d;
		assert(p != null && p[1] == 45 && p[2] == 70, 'kha: an emitter starts at the body midpoint ${pushed()}');
		assert(FmodKhaUpdater.count() == tickers + 1, "kha: an emitter registers with the updater");
		emitter.teleportDistance = 1000;
		car.x += 600;
		emitter.tick(4);
		FmodRuntime.update();
		p = stub.testLast3d;
		assert(p != null && p[1] == 645 && p[3] == 150, 'kha: an emitter teleportDistance replaces the default ${pushed()}');
		emitter.dispose();
		assert(FmodKhaUpdater.count() == tickers && FmodRuntime.attachedCount() == 0,
			'kha: dispose unregisters the emitter and detaches it (tickers=${FmodKhaUpdater.count() - tickers})');

		var body = {x: 295.0, y: 45.0, width: 10.0, height: 10.0};
		stub.testLastGlobalParameter = null;
		var trigger = new FmodKhaParameterTrigger(body, 0, 0, 400, 100, "Zone", 1, 0);
		trigger.tick(0);
		assert(stub.testLastGlobalParameter == "Zone" && stub.testLastGlobalValue == 1,
			'kha: a zone keeps its width and height (value=${stub.testLastGlobalValue})');
		body.x = 995;
		trigger.tick(0);
		assert(stub.testLastGlobalValue == 0, "kha: leaving the zone applies the outside value");
		tickers = FmodKhaUpdater.count();
		trigger.dispose();
		stub.testLastGlobalParameter = null;
		body.x = 295;
		FmodKhaUpdater.update();
		assert(FmodKhaUpdater.count() == tickers - 1 && stub.testLastGlobalParameter == null,
			'kha: a disposed trigger leaves the parameter alone (set=${stub.testLastGlobalParameter})');

		var mover = {x: 10.0, y: 20.0, width: 4.0, height: 6.0};
		tickers = FmodKhaUpdater.count();
		stub.testLast3d = null;
		FmodKhaUtilities.PlayOneShotAttached("event:/Adapters/Jump", mover);
		p = stub.testLast3d;
		assert(p != null && p[1] == 12 && p[2] == 23, 'kha: an attached one-shot starts at the body midpoint ${pushed()}');
		mover.x = 110;
		FmodKhaUpdater.update();
		mover.x = 210;
		FmodKhaUpdater.update();
		p = stub.testLast3d;
		assert(p != null && p[1] == 212 && FmodKhaUpdater.count() == tickers + 1,
			'kha: an attached one-shot follows the body while it plays ${pushed()}');
		stub.testPlaybackState = 2;
		FmodKhaUpdater.update();
		FmodKhaUpdater.update();
		assert(FmodRuntime.attachedCount() == 0 && FmodKhaUpdater.count() == tickers,
			'kha: the one-shot sampler leaves once the one-shot ended (tickers=${FmodKhaUpdater.count() - tickers})');
		stub.testPlaybackState = 0;

		var path = FmodRuntime.bankPath("KhaAdapters.bank");
		var fired = 0;
		var loader = new FmodKhaBankLoader(["KhaAdapters.bank"], () -> fired++);
		assert(!loader.loaded, "kha: a loader is not loaded before its first tick");
		loader.tick(0);
		assert(fired == 1 && loader.loaded && FmodRuntime.banks.refCount(path) == 1, "kha: a loader loads, fires once and reports loaded");
		tickers = FmodKhaUpdater.count();
		loader.dispose();
		assert(FmodRuntime.banks.refCount(path) == 0 && FmodKhaUpdater.count() == tickers - 1,
			'kha: dispose releases the loader banks and unregisters it (refs=${FmodRuntime.banks.refCount(path)})');
	}

	// khamake's fixName in Tools/khamake/out/main.js turns dashes, at
	// signs, spaces, dots and slashes into underscores. It puts an
	// underscore in front of a leading digit.
	static function testKhaBlobName():Void {
		assert(FmodKhaSetup.blobName("Master.strings.bank") == "Master_strings_bank", "kha: a bank blob name replaces the dots");
		var name = FmodKhaSetup.blobName("banks/2-Level Music@x.bank");
		assert(name == "_2_Level_Music_x_bank", 'kha: a bank blob name follows khamake for dashes, spaces, at signs and a leading digit ($name)');
	}
}
