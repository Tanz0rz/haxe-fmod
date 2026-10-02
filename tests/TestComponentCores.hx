package tests;

import haxefmod.runtime.BankLoadTracker;
import haxefmod.runtime.EmitterTracker;
import haxefmod.runtime.FmodRuntime;
import haxefmod.runtime.IFmodPositionProvider;
import haxefmod.runtime.ListenerTracker;
import haxefmod.runtime.ZoneTrigger;
import haxefmod.studio.EventInstance;
import haxefmod.studio.Types.FmodStopMode;
import haxefmod.studio.native.NativeStudioStub;

/**
 * Unit tests for the engine-free component cores on the stub backend:
 * derived velocity math, zone edge crossings, bank loader callbacks and
 * emitter attachment bookkeeping. The engine wrappers add nothing but
 * the position source and a frame hook, so this is where the behavior
 * lives.
 */
@:access(haxefmod.runtime.ZoneTrigger)
class TestComponentCores {
	static var passed = 0;
	static var failed = 0;

	public static function run():Int {
		Sys.println("--- Component cores (stub backend) ---");
		testDerivedVelocity();
		testZoneTrigger();
		testBankLoadTracker();
		testEmitterTracker();
		Sys.println('  $passed passed, $failed failed');
		return failed;
	}

	static function assert(condition:Bool, name:String):Void {
		if (condition) passed++ else {
			failed++;
			Sys.println('  FAIL: $name');
		}
	}

	static inline function approx(a:Float, b:Float):Bool {
		return Math.abs(a - b) < 0.0001;
	}

	static function testDerivedVelocity():Void {
		var x = 10.0;
		var y = 20.0;
		var provider = new DerivedVelocityProvider(() -> x, () -> y, 100);

		provider.sample(0.5);
		assert(provider.fmodX() == 10 && provider.fmodY() == 20, "first sample reports the position");
		assert(provider.fmodVelocityX() == 0 && provider.fmodVelocityY() == 0, "first sample seeds with zero velocity");

		x = 40;
		y = 10;
		provider.sample(0.5);
		assert(approx(provider.fmodVelocityX(), 60) && approx(provider.fmodVelocityY(), -20),
			"velocity is the movement over the elapsed time");

		// A jump past the teleport distance is a cut rather than movement
		x = 5000;
		provider.sample(0.5);
		assert(provider.fmodVelocityX() == 0 && provider.fmodVelocityY() == 0, "teleport reports zero velocity");
		assert(provider.fmodX() == 5000, "teleport still reports the new position");

		// Movement after the cut is measured from the cut position
		x = 5010;
		provider.sample(0.5);
		assert(approx(provider.fmodVelocityX(), 20), "tracking resumes after a teleport");

		// reset() makes the next sample a seed again
		provider.reset();
		x = 5100;
		provider.sample(0.5);
		assert(provider.fmodVelocityX() == 0, "reset re-seeds tracking");

		// A zero elapsed frame cannot divide
		x = 5110;
		provider.sample(0);
		assert(provider.fmodVelocityX() == 0, "zero elapsed reports zero velocity");

		// The teleport distance is the straight-line distance. A jump of
		// exactly that much is still movement.
		var bx = 0.0;
		var by = 0.0;
		var edge = new DerivedVelocityProvider(() -> bx, () -> by, 100);
		edge.sample(0.5);
		bx = 60;
		by = 80;
		edge.sample(0.5);
		assert(approx(edge.fmodVelocityX(), 120) && approx(edge.fmodVelocityY(), 160), "a jump of exactly teleportDistance is movement");
		bx = 120;
		by = 160.001;
		edge.sample(0.5);
		assert(edge.fmodVelocityX() == 0 && edge.fmodVelocityY() == 0, "a jump just past teleportDistance is a cut");
	}

	static function testZoneTrigger():Void {
		var stub = NativeStudioStub;
		var savedInit = stub.testInitialized;
		var provider = new MovableProvider(50, 50);
		var trigger = new SpyTrigger(provider, 0, 0, 100, 100, "Nope", 1, 0);

		// An update before FMOD is ready drops the value and latches
		// nothing. The first update after init reports the crossing.
		stub.testInitialized = false;
		trigger.update();
		assert(trigger.applied.length == 0, "an update before init applies nothing");

		stub.testInitialized = true;
		trigger.update();
		assert(trigger.applied.length == 1 && trigger.applied[0] == 1, "first update applies the inside value");

		// No crossing: nothing is re-applied, so a manual change survives
		provider.x = 60;
		trigger.update();
		assert(trigger.applied.length == 1, "no crossing applies nothing");

		// Crossing out applies the outside value once
		provider.x = 150;
		trigger.update();
		trigger.update();
		assert(trigger.applied.length == 2 && trigger.applied[1] == 0, "crossing out applies the outside value once");

		// The edge itself counts as inside
		provider.x = 100;
		trigger.update();
		assert(trigger.applied.length == 3 && trigger.applied[2] == 1, "the zone edge is inside");

		// Without an instance the global parameter path is used. The
		// provider sits at 100, outside this zone, so the outside value is
		// what reaches the global setter.
		stub.testLastGlobalParameter = null;
		var global = new ZoneTrigger(provider, 0, 0, 10, 10, "Nope", 1, 0);
		global.update();
		assert(stub.testLastGlobalParameter == "Nope" && stub.testLastGlobalValue == 0,
			"global path reaches StudioSystem.setParameter with the name and value");
		// With an instance the global parameter stays untouched
		stub.testLastGlobalParameter = null;
		var local = new ZoneTrigger(provider, 0, 0, 10, 10, "Nope", 1, 0, cast 0x10010);
		local.update();
		assert(stub.testLastGlobalParameter == null, "an instance trigger leaves the global parameter alone");

		// PROBE: the vertical extent and every edge count
		var probeProvider = new MovableProvider(50, 150);
		var vertical = new SpyTrigger(probeProvider, 0, 0, 100, 100, "Nope", 1, 0);
		vertical.update();
		assert(vertical.applied.length == 1 && vertical.applied[0] == 0, "PROBE a position below the zone is outside");
		var edges = 0;
		for (pt in [[0.0, 50.0], [50.0, 0.0], [50.0, 100.0]]) {
			var edge = new SpyTrigger(new MovableProvider(pt[0] + 10, pt[1] + 20), 10, 20, 100, 100, "Nope", 1, 0);
			edge.update();
			if (edge.applied.length == 1 && edge.applied[0] == 1) edges++;
		}
		assert(edges == 3, "PROBE the left, top, and bottom edges are inside");
		stub.testInitialized = savedInit;
	}

	static function testBankLoadTracker():Void {
		var stub = NativeStudioStub;
		var savedInit = stub.testInitialized;
		var savedSynthetic = stub.testSyntheticHandles;
		var savedState = stub.testBankLoadingState;
		stub.testInitialized = true;
		stub.testSyntheticHandles = true;
		stub.testBankLoadingState = 3; // LOADED

		var path = FmodRuntime.bankPath("Cores.bank");

		// An empty list is loaded on the first update, exactly once
		var fired = 0;
		var empty = new BankLoadTracker([], () -> fired++);
		empty.update();
		empty.update();
		assert(fired == 1 && empty.loaded, "empty list fires onLoaded once");
		empty.dispose();

		// A load registers a reference the tracker owns until dispose
		var loaded = 0;
		var tracker = new BankLoadTracker(["Cores.bank"], () -> loaded++);
		assert(FmodRuntime.banks.refCount(path) == 0, "nothing loads before the first update");
		tracker.update();
		assert(FmodRuntime.banks.refCount(path) == 1, "the first update starts the load");
		assert(loaded == 1 && tracker.loaded, "loaded banks fire onLoaded");
		tracker.update();
		assert(loaded == 1, "onLoaded fires once");
		tracker.dispose();
		assert(FmodRuntime.banks.refCount(path) == 0, "dispose releases the reference");
		tracker.update();
		assert(loaded == 1, "a disposed tracker never fires");

		// FMOD is not ready: the load waits instead of failing
		stub.testInitialized = false;
		var waiting = new BankLoadTracker(["Cores.bank"], () -> loaded++);
		waiting.update();
		assert(FmodRuntime.banks.refCount(path) == 0, "no load while FMOD is down");
		stub.testInitialized = true;
		waiting.update();
		assert(loaded == 2, "the load starts once FMOD is ready");

		// A refused system never comes up: the loader reports the error once
		stub.testInitialized = false;
		var savedRefused = @:privateAccess FmodRuntime.systemFailed;
		@:privateAccess FmodRuntime.systemFailed = true;
		var refusedErrors = 0;
		var refused = new BankLoadTracker(["Cores.bank"], () -> loaded++, () -> refusedErrors++);
		refused.update();
		refused.update();
		assert(refusedErrors == 1 && loaded == 2, "a refused system fires onError once");
		@:privateAccess FmodRuntime.systemFailed = savedRefused;
		stub.testInitialized = true;
		waiting.dispose();

		// A bank that settles in ERROR reports through onError once
		stub.testBankLoadingState = 4; // ERROR
		var errors = 0;
		var failing = new BankLoadTracker(["Cores.bank"], () -> loaded++, () -> errors++);
		failing.update();
		failing.update();
		assert(errors == 1 && loaded == 2 && !failing.loaded, "an errored bank fires onError once");
		failing.dispose();
		assert(FmodRuntime.banks.refCount(path) == 0, "dispose after an error releases the reference");

		// A tracker disposed before its first update never loads or fires
		stub.testBankLoadingState = 3;
		var early = 0;
		var earlyTracker = new BankLoadTracker(["Cores.bank"], () -> early++);
		earlyTracker.dispose();
		earlyTracker.update();
		assert(early == 0 && FmodRuntime.banks.refCount(path) == 0, "a tracker disposed before its first update never loads or fires");
		// A tracker disposed while its bank loads never fires
		stub.testBankLoadingState = 2;
		var midway = 0;
		var midTracker = new BankLoadTracker(["Cores.bank"], () -> midway++);
		midTracker.update();
		midTracker.dispose();
		midTracker.update();
		assert(midway == 0, "a tracker disposed mid-load never fires");
		stub.testBankLoadingState = 3;
		// A rejected load never releases a reference another holder owns
		stub.testSyntheticHandles = false;
		var rejected = new BankLoadTracker(["Cores.bank"], null, () -> {});
		rejected.update();
		stub.testSyntheticHandles = true;
		var other = FmodRuntime.banks.loadAsync(path);
		rejected.dispose();
		assert(FmodRuntime.banks.refCount(path) == 1, "a rejected load leaves another holder's reference alone");
		FmodRuntime.banks.unload(path);
		stub.testBankLoadingState = savedState;
		stub.testSyntheticHandles = savedSynthetic;
		stub.testInitialized = savedInit;
	}

	static function testEmitterTracker():Void {
		var provider = new MovableProvider(1, 2);
		var baseline = FmodRuntime.attachedCount();

		// A nonzero handle is invalid on the stub backend, so it attaches
		// and would be pruned by the runtime's next update
		var fake:EventInstance = cast 0x10002;
		haxefmod.studio.native.NativeStudioStub.testLast3d = null;
		var tracker = new EmitterTracker(fake, provider);
		var first = haxefmod.studio.native.NativeStudioStub.testLast3d;
		assert(first != null && first[1] == 1 && first[2] == 2, "attaching pushes the position at once");
		// The velocity cap reaches the attach push and the listener push
		var fast = new FastProvider();
		var savedCap = @:privateAccess FmodRuntime.attached.maxVelocity;
		@:privateAccess FmodRuntime.attached.maxVelocity = 10;
		var capped = new EmitterTracker(cast 0x10003, fast);
		var pushed = haxefmod.studio.native.NativeStudioStub.testLast3d;
		assert(pushed != null && Math.abs(pushed[3] - 6) < 0.0001 && Math.abs(pushed[4] - 8) < 0.0001, "the attach push caps the velocity");
		haxefmod.studio.native.NativeStudioStub.testListenerPushes = [];
		haxefmod.studio.native.NativeStudioStub.testRecordListenerPushes = true;
		new ListenerTracker(fast).update();
		var lp = haxefmod.studio.native.NativeStudioStub.testListenerPushes;
		assert(lp.length == 1 && Math.abs(lp[0].vx - 6) < 0.0001 && Math.abs(lp[0].vy - 8) < 0.0001, "the listener push caps the velocity");
		haxefmod.studio.native.NativeStudioStub.testRecordListenerPushes = false;
		@:privateAccess FmodRuntime.attached.maxVelocity = savedCap;
		capped.dispose();
		assert(FmodRuntime.attachedCount() == baseline + 1, "constructing attaches the instance");
		assert(FmodRuntime.isAttachedProvider(provider), "the provider is reported attached");
		// Culling is off by default, and with no listener attributes the
		// cull path has nothing to measure. Both updates run for crashes
		// only, since the attach list is not what the cull path touches.
		tracker.update();
		tracker.stopEventsOutsideMaxDistance = true;
		tracker.cullCheckInterval = 1;
		tracker.update();

		// The authored distance culls a playing 3D event with no explicit
		// distance, and an event the game stopped itself is left alone
		var stub = haxefmod.studio.native.NativeStudioStub;
		stub.testListenerPosition = [0, 0, 0];
		stub.testIs3D = true;
		stub.testMinMaxDistance = [1, 20];
		var savedState = stub.testPlaybackState;
		var far = new MovableProvider(1000, 0);
		var authored = new EmitterTracker(cast 0x10004, far);
		authored.stopEventsOutsideMaxDistance = true;
		authored.cullCheckInterval = 1;
		stub.testPlaybackState = 0; // PLAYING
		stub.testStopCalls = 0;
		authored.update();
		assert(stub.testStopCalls == 1, "the authored distance culls a far 3D event");
		assert(stub.testLastStopMode == (FmodStopMode.ALLOWFADEOUT : Int), "culling lets the event fade out");
		var starts = stub.testStartCalls;
		far.x = 5;
		authored.update();
		assert(stub.testStartCalls == starts + 1, "a culled event restarts inside the authored distance");
		authored.dispose();
		var silent = new EmitterTracker(cast 0x10005, far);
		silent.stopEventsOutsideMaxDistance = true;
		silent.cullCheckInterval = 1;
		stub.testPlaybackState = 2; // STOPPED, by the game
		far.x = 1000;
		stub.testStopCalls = 0;
		silent.update();
		starts = stub.testStartCalls;
		far.x = 5;
		silent.update();
		assert(stub.testStopCalls == 0 && stub.testStartCalls == starts, "an event the game stopped is neither culled nor restarted");
		silent.dispose();

		// Turning culling off restarts the event the emitter culled
		stub.testPlaybackState = 0;
		far.x = 1000;
		var toggled = new EmitterTracker(cast 0x10006, far);
		toggled.stopEventsOutsideMaxDistance = true;
		toggled.cullCheckInterval = 1;
		stub.testStopCalls = 0;
		toggled.update();
		starts = stub.testStartCalls;
		toggled.stopEventsOutsideMaxDistance = false;
		toggled.update();
		assert(stub.testStopCalls == 1 && stub.testStartCalls == starts + 1, "turning culling off restarts the culled event");
		toggled.dispose();

		// Far-off one-shots and 2D events play on. So does an event with a
		// cull distance of zero.
		function culling(handle:Int):EmitterTracker {
			var tracker = new EmitterTracker(cast handle, far);
			tracker.stopEventsOutsideMaxDistance = true;
			tracker.cullCheckInterval = 1;
			return tracker;
		}
		stub.testStopCalls = 0;
		stub.testIsOneshot = true;
		var oneshot = culling(0x10007);
		oneshot.update();
		stub.testIsOneshot = false;
		assert(stub.testStopCalls == 0, "a far one-shot is not culled");
		stub.testIs3D = false;
		var flat = culling(0x10008);
		flat.update();
		stub.testIs3D = true;
		assert(stub.testStopCalls == 0, "a far 2D event is not culled by the authored distance");
		var zero = culling(0x10009);
		zero.cullMaxDistance = 0;
		zero.update();
		assert(stub.testStopCalls == 0, "a cull distance of zero culls nothing");
		for (tracker in [oneshot, flat, zero]) tracker.dispose();

		// The distance is measured against the emitter's own listener
		stub.testListenerIndex = 1;
		stub.testStopCalls = 0;
		var second = new EmitterTracker(cast 0x1000A, far);
		second.listenerIndex = 1;
		second.stopEventsOutsideMaxDistance = true;
		second.cullCheckInterval = 1;
		second.update();
		assert(stub.testStopCalls == 1, "the cull check reads the emitter's listener");
		second.dispose();
		stub.testListenerIndex = 0;
		stub.testPlaybackState = savedState;
		stub.testListenerPosition = null;
		stub.testIs3D = false;
		stub.testMinMaxDistance = null;

		tracker.dispose();
		assert(FmodRuntime.attachedCount() == baseline, "dispose detaches");
		assert(!FmodRuntime.isAttachedProvider(provider), "the provider is no longer attached");
		assert(tracker.instance.isNull(), "dispose clears the instance");
		tracker.dispose();
		assert(FmodRuntime.attachedCount() == baseline, "a second dispose is harmless");

		// A NULL instance never attaches
		var nothing = new EmitterTracker(EventInstance.NULL, provider);
		assert(FmodRuntime.attachedCount() == baseline, "a null instance is not attached");
		nothing.dispose();

		// The listener tracker pushes nothing without a provider, and the
		// provider's position once it has one
		var stub = haxefmod.studio.native.NativeStudioStub;
		stub.testListenerPushes = [];
		stub.testRecordListenerPushes = true;
		var listener = new ListenerTracker(null);
		listener.update();
		assert(stub.testListenerPushes.length == 0, "no listener push without a provider");
		listener.provider = provider;
		listener.update();
		assert(stub.testListenerPushes.length == 1, "one listener push per update with a provider");
		new ListenerTracker(provider, 2).update();
		assert(stub.testListenerPushes.length == 2 && stub.testListenerPushes[1].index == 2,
			"the tracker drives the listener it was given");
		stub.testRecordListenerPushes = false;
	}
}

private class MovableProvider implements IFmodPositionProvider {
	public var x:Float;
	public var y:Float;

	public function new(x:Float, y:Float) {
		this.x = x;
		this.y = y;
	}

	public function fmodX():Float return x;
	public function fmodY():Float return y;
	public function fmodVelocityX():Float return 0;
	public function fmodVelocityY():Float return 0;
}

private class SpyTrigger extends ZoneTrigger {
	public var applied:Array<Float> = [];

	override function apply(value:Float):Void {
		applied.push(value);
	}
}

private class FastProvider implements IFmodPositionProvider {
	public function new() {}
	public function fmodX():Float return 0;
	public function fmodY():Float return 0;
	public function fmodVelocityX():Float return 30;
	public function fmodVelocityY():Float return 40;
}
