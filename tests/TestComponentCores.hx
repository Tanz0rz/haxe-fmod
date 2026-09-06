package tests;

import haxefmod.runtime.BankLoadTracker;
import haxefmod.runtime.EmitterTracker;
import haxefmod.runtime.FmodRuntime;
import haxefmod.runtime.IFmodPositionProvider;
import haxefmod.runtime.ListenerTracker;
import haxefmod.runtime.ZoneTrigger;
import haxefmod.studio.EventInstance;
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

		// A jump past the teleport distance is a cut, not movement
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
	}

	static function testZoneTrigger():Void {
		var provider = new MovableProvider(50, 50);
		var trigger = new SpyTrigger(provider, 0, 0, 100, 100, "Nope", 1, 0);

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

		// Without an instance the global parameter path is used. The stub
		// rejects every parameter, which is the outcome the pan test pins
		var global = new ZoneTrigger(provider, 0, 0, 10, 10, "Nope", 1, 0);
		global.update();
		assert(!haxefmod.studio.StudioSystem.lastResult().isOk(), "global path reaches StudioSystem.setParameter");
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
		var tracker = new EmitterTracker(fake, provider);
		assert(FmodRuntime.attachedCount() == baseline + 1, "constructing attaches the instance");
		assert(FmodRuntime.isAttachedProvider(provider), "the provider is reported attached");
		// Culling is off by default: update is a no-op with no listener
		tracker.update();
		tracker.stopEventsOutsideMaxDistance = true;
		tracker.cullCheckInterval = 1;
		tracker.update();
		assert(FmodRuntime.attachedCount() == baseline + 1, "culling with no listener attributes changes nothing");

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

		// The listener tracker pushes the provider's position without a
		// provider-less crash
		var listener = new ListenerTracker(null);
		listener.update();
		listener.provider = provider;
		listener.update();
		assert(true, "listener update with and without a provider");
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
