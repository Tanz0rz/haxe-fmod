package tests;

import haxefmod.heaps.FmodHeapsUpdater;
import haxefmod.kha.FmodKhaUpdater;
import haxefmod.studio.native.NativeStudioStub;

/**
 * The Heaps and Kha frame drivers on the stub backend. Both compile
 * without their engine. The Heaps hook rides the interpreter's event
 * loop, and the Kha task runs on the scheduler stub in tests/stubs.
 * A game that removed the hook drives update() itself, and components
 * created after that must not put the hook back.
 */
class TestEngineUpdaters {
	static var passed = 0;
	static var failed = 0;
	static var updates = 0;

	public static function run():Int {
		Sys.println("--- Engine updaters (stub backend) ---");
		var stub = NativeStudioStub;
		var savedInit = stub.testInitialized;
		var savedHook = haxefmod.studio.CallbackDispatcher.frameHook;
		// FmodManager.Update drains the dispatcher once per call, so the
		// frame hook counts the updates
		stub.testInitialized = true;
		haxefmod.studio.CallbackDispatcher.frameHook = () -> updates++;
		testHeapsUpdater();
		testKhaUpdater();
		testUpdaterDeltas();
		haxefmod.studio.CallbackDispatcher.frameHook = savedHook;
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

	// One pass of the event loop is one frame. The loop runs a repeat
	// only once the clock moved past its due time.
	static function pumpHeaps(frames:Int):Void {
		for (i in 0...frames) {
			Sys.sleep(0.005);
			sys.thread.Thread.current().events.progress();
		}
	}

	static function testHeapsUpdater():Void {
		var ticker = new HeapsTicker();
		FmodHeapsUpdater.add(ticker);
		assert(FmodHeapsUpdater.isInstalled() && FmodHeapsUpdater.installCount == 1, "heaps: the first component installs the hook");
		var ticks = ticker.ticks;
		var before = updates;
		pumpHeaps(3);
		assert(ticker.ticks == ticks + 3 && updates == before + 3,
			'heaps: the hook ticks the components and runs FmodManager.Update (ticks=${ticker.ticks - ticks} updates=${updates - before})');

		// A removeHook then init inside a tick keeps one hook
		ticker.onTick = () -> {
			ticker.onTick = null;
			FmodHeapsUpdater.removeHook();
			FmodHeapsUpdater.init();
		};
		// Haxe 4.3.6 runs the new repeat in the pass that installed it and
		// 4.3.7 does not, so that pass alone may tick twice. Every pass
		// after it ticks once, which two hooks would not.
		pumpHeaps(1);
		ticks = ticker.ticks;
		pumpHeaps(4);
		assert(FmodHeapsUpdater.isInstalled() && ticker.ticks == ticks + 4,
			'heaps: a reinstall inside a tick keeps one hook (ticks=${ticker.ticks - ticks})');

		// The game drives the updater itself after removeHook
		FmodHeapsUpdater.removeHook();
		var late = new HeapsTicker();
		FmodHeapsUpdater.add(late);
		assert(!FmodHeapsUpdater.isInstalled(), "heaps: a component added after removeHook leaves the hook out");
		ticks = ticker.ticks;
		pumpHeaps(2);
		assert(ticker.ticks == ticks && late.ticks == 0, "heaps: nothing ticks without the hook");
		before = updates;
		FmodHeapsUpdater.update();
		assert(ticker.ticks == ticks + 1 && late.ticks == 1 && updates == before + 1,
			"heaps: update() ticks every component and runs FmodManager.Update once");
		var installs = FmodHeapsUpdater.installCount;
		FmodHeapsUpdater.init();
		assert(FmodHeapsUpdater.isInstalled() && FmodHeapsUpdater.installCount == installs + 1, "heaps: init installs the hook again");

		// The interpreter runs its event loop at exit, so no hook may stay
		FmodHeapsUpdater.removeHook();
		// A component that an earlier tick disposed ticked once more in
		// that frame
		var lateTicks = late.ticks;
		ticker.onTick = () -> FmodHeapsUpdater.remove(late);
		FmodHeapsUpdater.update();
		ticker.onTick = null;
		assert(late.ticks == lateTicks, 'heaps: a component removed during the frame does not tick (ticks=${late.ticks - lateTicks})');
		FmodHeapsUpdater.remove(ticker);
		FmodHeapsUpdater.remove(late);
		assert(FmodHeapsUpdater.count() == 0, "heaps: remove unregisters the components");
	}

	static function testUpdaterDeltas():Void {
		// The earlier cases end with manual updates. A removeHook of an
		// installed hook forgets the last frame time.
		FmodHeapsUpdater.init();
		FmodHeapsUpdater.removeHook();
		var heaps = new HeapsTicker();
		FmodHeapsUpdater.init();
		FmodHeapsUpdater.add(heaps);
		pumpHeaps(2);
		assert(heaps.dts.length == 2 && heaps.dts[0] == 0 && heaps.dts[1] > 0 && heaps.dts[1] < 1,
			'heaps: the first frame passes 0 seconds and the next the time between them (dts=${heaps.dts})');
		FmodHeapsUpdater.removeHook();
		Sys.sleep(0.05);
		FmodHeapsUpdater.init();
		pumpHeaps(1);
		assert(heaps.dts.length == 3 && heaps.dts[2] == 0, 'heaps: the first frame after a reinstall passes 0 seconds (dts=${heaps.dts})');
		FmodHeapsUpdater.removeHook();
		FmodHeapsUpdater.remove(heaps);

		FmodKhaUpdater.init();
		FmodKhaUpdater.removeHook();
		var khaTicker = new KhaTicker();
		FmodKhaUpdater.init();
		FmodKhaUpdater.add(khaTicker);
		kha.Scheduler.runFrame();
		kha.Scheduler.runFrame();
		assert(khaTicker.dts.length == 2 && khaTicker.dts[0] == 0 && Math.abs(khaTicker.dts[1] - 1 / 60) < 1e-9,
			'kha: the first frame passes 0 seconds and the next one frame of real time (dts=${khaTicker.dts})');
		FmodKhaUpdater.removeHook();
		kha.Scheduler.runFrame();
		FmodKhaUpdater.init();
		kha.Scheduler.runFrame();
		assert(khaTicker.dts.length == 3 && khaTicker.dts[2] == 0, 'kha: the first frame after a reinstall passes 0 seconds (dts=${khaTicker.dts})');
		FmodKhaUpdater.removeHook();
		FmodKhaUpdater.remove(khaTicker);
	}

	static function testKhaUpdater():Void {
		var ticker = new KhaTicker();
		FmodKhaUpdater.add(ticker);
		assert(FmodKhaUpdater.isInstalled() && FmodKhaUpdater.installCount == 1 && kha.Scheduler.taskCount() == 1,
			"kha: the first component installs the frame task");
		var before = updates;
		kha.Scheduler.runFrame();
		assert(ticker.ticks == 1 && updates == before + 1, "kha: the frame task ticks the components and runs FmodManager.Update");

		// A removeHook then init inside a tick adds a task to the running
		// frame. The frame still ticks once.
		ticker.onTick = () -> {
			ticker.onTick = null;
			FmodKhaUpdater.removeHook();
			FmodKhaUpdater.init();
		};
		before = updates;
		kha.Scheduler.runFrame();
		assert(ticker.ticks == 2 && updates == before + 1 && kha.Scheduler.taskCount() == 1,
			'kha: a reinstall inside a tick keeps one task and one tick (ticks=${ticker.ticks} tasks=${kha.Scheduler.taskCount()})');

		// The game drives the updater itself after removeHook
		FmodKhaUpdater.removeHook();
		var late = new KhaTicker();
		FmodKhaUpdater.add(late);
		assert(!FmodKhaUpdater.isInstalled() && kha.Scheduler.taskCount() == 0,
			"kha: a component added after removeHook leaves the frame task out");
		kha.Scheduler.runFrame();
		assert(ticker.ticks == 2 && late.ticks == 0, "kha: nothing ticks without the frame task");
		before = updates;
		FmodKhaUpdater.update();
		assert(ticker.ticks == 3 && late.ticks == 1 && updates == before + 1,
			"kha: update() ticks every component and runs FmodManager.Update once");
		var installs = FmodKhaUpdater.installCount;
		FmodKhaUpdater.init();
		assert(FmodKhaUpdater.isInstalled() && FmodKhaUpdater.installCount == installs + 1 && kha.Scheduler.taskCount() == 1,
			"kha: init installs the frame task again");

		// A manual update and an init in one frame still update once. Kha
		// runs a task added to the running frame.
		FmodKhaUpdater.removeHook();
		var gameTask = kha.Scheduler.addFrameTask(() -> {
			FmodKhaUpdater.update();
			FmodKhaUpdater.init();
		}, 0);
		before = updates;
		kha.Scheduler.runFrame();
		assert(updates == before + 1, 'kha: an init after a manual update in one frame updates once (updates=${updates - before})');
		kha.Scheduler.removeFrameTask(gameTask);

		FmodKhaUpdater.removeHook();
		// A component that an earlier tick disposed ticked once more in
		// that frame
		var lateTicks = late.ticks;
		ticker.onTick = () -> FmodKhaUpdater.remove(late);
		FmodKhaUpdater.update();
		ticker.onTick = null;
		assert(late.ticks == lateTicks, 'kha: a component removed during the frame does not tick (ticks=${late.ticks - lateTicks})');
		FmodKhaUpdater.remove(ticker);
		FmodKhaUpdater.remove(late);
		assert(FmodKhaUpdater.count() == 0, "kha: remove unregisters the components");
	}
}

private class HeapsTicker implements FmodHeapsUpdater.IHeapsTicker {
	public var ticks:Int = 0;
	public var dts:Array<Float> = [];
	public var onTick:Void->Void = null;

	public function new() {}

	public function tick(dt:Float):Void {
		ticks++;
		dts.push(dt);
		if (onTick != null) onTick();
	}
}

private class KhaTicker implements FmodKhaUpdater.IKhaTicker {
	public var ticks:Int = 0;
	public var dts:Array<Float> = [];
	public var onTick:Void->Void = null;

	public function new() {}

	public function tick(dt:Float):Void {
		ticks++;
		dts.push(dt);
		if (onTick != null) onTick();
	}
}
