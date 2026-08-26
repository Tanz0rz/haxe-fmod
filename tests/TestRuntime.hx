package tests;

import haxefmod.runtime.AttachedInstances;
import haxefmod.runtime.BankRegistry;
import haxefmod.runtime.FmodSettings;
import haxefmod.runtime.FmodRuntime;
import haxefmod.runtime.IFmodPositionProvider;
import haxefmod.studio.EventInstance;

/**
 * Unit tests for the M5 runtime pieces on the stub backend: settings
 * resolution precedence, bank registry refcounting behavior around failed
 * loads, and attached-instance bookkeeping.
 */
@:access(haxefmod.runtime.BankRegistry)
class TestRuntime {
	static var passed = 0;
	static var failed = 0;

	public static function run():Int {
		Sys.println("--- Runtime (stub backend) ---");

		testSettingsDefaults();
		testSettingsOverrides();
		testFocusMute();
		testBankRegistry();
		testBankRegistryNormalization();
		testBankRegistryErroredRetry();
		testAttachedInstances();
		testIsInitializedComposition();
		testAttachedOneShotAutoRelease();

		Sys.println('  $passed passed, $failed failed');
		return failed;
	}

	static function assert(condition:Bool, name:String):Void {
		if (condition) passed++ else {
			failed++;
			Sys.println('  FAIL: $name');
		}
	}

	static function testSettingsDefaults():Void {
		var resolved = FmodSettingsResolver.resolve(null);
		assert(resolved.numChannels == 128, "default numChannels");
		assert(resolved.sampleRate == 0, "default sampleRate");
		assert(resolved.speakerMode == 0, "default speakerMode");
		assert(resolved.logLevel == 1, "default logLevel");
		assert(resolved.bankFolder == "assets/fmod/Desktop", "default bankFolder");
		assert(resolved.autoLoadBanks.length == 2, "default autoLoadBanks");
		assert(resolved.autoLoadBanks[0] == "Master.bank", "default master bank");
		assert(resolved.autoLoadBanks[1] == "Master.strings.bank", "default strings bank");
		assert(resolved.autoUpdate == true, "default autoUpdate");
		assert(resolved.muteWhenUnfocused == true, "default muteWhenUnfocused");
		assert(resolved.maxAttachedVelocity == 0.0, "default maxAttachedVelocity");
		// Tests run without -debug, so live update defaults off
		#if debug
		assert(resolved.liveUpdate == true, "default liveUpdate (debug)");
		#else
		assert(resolved.liveUpdate == false, "default liveUpdate (release)");
		#end
	}

	static function testSettingsOverrides():Void {
		var resolved = FmodSettingsResolver.resolve({
			numChannels: 64,
			sampleRate: 48000,
			liveUpdate: true,
			logLevel: 3,
			bankFolder: "sounds",
			autoLoadBanks: [],
			autoUpdate: false,
			muteWhenUnfocused: false,
			maxAttachedVelocity: 250,
		});
		assert(resolved.numChannels == 64, "override numChannels");
		assert(resolved.sampleRate == 48000, "override sampleRate");
		assert(resolved.liveUpdate == true, "override liveUpdate");
		assert(resolved.logLevel == 3, "override logLevel");
		assert(resolved.bankFolder == "sounds", "override bankFolder");
		assert(resolved.autoLoadBanks.length == 0, "override autoLoadBanks");
		assert(resolved.autoUpdate == false, "override autoUpdate");
		assert(resolved.muteWhenUnfocused == false, "override muteWhenUnfocused");
		assert(resolved.maxAttachedVelocity == 250, "override maxAttachedVelocity");

		// Partial overrides keep other defaults
		var partial = FmodSettingsResolver.resolve({liveUpdate: true});
		assert(partial.liveUpdate == true, "partial liveUpdate");
		assert(partial.numChannels == 128, "partial keeps numChannels");
	}

	static function testFocusMute():Void {
		// Defaults: focused, so nothing is focus-muted
		assert(FmodRuntime.isWindowFocused(), "starts focused");
		assert(!FmodRuntime.isFocusMuted(), "focused is not muted");

		// Losing focus mutes. Regaining it unmutes
		FmodRuntime.setWindowFocused(false);
		assert(!FmodRuntime.isWindowFocused(), "unfocused reported");
		assert(FmodRuntime.isFocusMuted(), "unfocused mutes");
		FmodRuntime.setWindowFocused(true);
		assert(!FmodRuntime.isFocusMuted(), "refocus unmutes");

		// Opting out keeps audio playing while unfocused
		FmodRuntime.setMuteWhenUnfocused(false);
		FmodRuntime.setWindowFocused(false);
		assert(!FmodRuntime.isFocusMuted(), "opt-out plays while unfocused");
		// Turning the feature back on while already unfocused mutes right away
		FmodRuntime.setMuteWhenUnfocused(true);
		assert(FmodRuntime.isFocusMuted(), "re-enabling mutes immediately");

		// Restore defaults so later tests / shared state are unaffected
		FmodRuntime.setWindowFocused(true);
		FmodRuntime.setMuteWhenUnfocused(true);
	}

	static function testBankRegistry():Void {
		var registry = new BankRegistry();
		// Stub backend: every load fails with the invalid handle
		var bank = registry.load("assets/fmod/Desktop/Master.bank");
		assert(bank.isNull(), "failed load returns NULL");
		assert(registry.refCount("assets/fmod/Desktop/Master.bank") == 0, "failed load not registered");
		assert(!registry.isLoaded("assets/fmod/Desktop/Master.bank"), "failed load not loaded");
		assert(registry.loadingState("missing.bank") == UNLOADED, "unknown bank state");
		assert(!registry.unload("missing.bank"), "unload of unknown bank");
		assert(!registry.anyLoading(), "nothing loading");
		assert(registry.get("missing.bank").isNull(), "get unknown bank");

		// FMOD bank path derivation: only the trailing .bank extension is
		// stripped, so the strings bank keeps its full dotted name
		assert(BankRegistry.bankPathFor("assets/fmod/Desktop/Master.bank") == "bank:/Master", "bank path simple");
		assert(BankRegistry.bankPathFor("assets/fmod/Desktop/Master.strings.bank") == "bank:/Master.strings", "bank path multi-dot");
		assert(BankRegistry.bankPathFor("Solo.bank") == "bank:/Solo", "bank path bare file");
		assert(BankRegistry.bankPathFor("dir/NoExtension") == "bank:/NoExtension", "bank path no extension");
	}

	static function testBankRegistryNormalization():Void {
		// Two spellings of one file must share one refcount, or unloading
		// either entry to zero destroys the bank under the other's holders
		assert(BankRegistry.normalizePath("assets\\fmod\\Master.bank")
			== "assets/fmod/Master.bank", "backslashes normalize");
		assert(BankRegistry.normalizePath("./assets/./fmod/Master.bank")
			== "assets/fmod/Master.bank", "dot segments collapse");
		assert(BankRegistry.normalizePath("assets//fmod///Master.bank")
			== "assets/fmod/Master.bank", "duplicate slashes collapse");
		assert(BankRegistry.normalizePath("assets/fmod/Master.bank")
			== "assets/fmod/Master.bank", "clean path unchanged");
		assert(BankRegistry.normalizePath("\\\\server\\share\\Master.bank")
			== "//server/share/Master.bank", "UNC root preserved");
		assert(BankRegistry.normalizePath("/abs/Master.bank")
			== "/abs/Master.bank", "absolute root preserved");

		var stub = haxefmod.studio.native.NativeStudioStub;
		stub.testSyntheticHandles = true;
		stub.testBankLoadingState = 3;
		var registry = new BankRegistry();
		var first = registry.load("assets/fmod/Master.bank");
		var second = registry.load("assets\\fmod\\.\\Master.bank");
		assert(!first.isNull(), "synthetic load registers");
		assert((first : Int) == (second : Int), "spellings share one entry");
		assert(registry.refCount("assets/fmod/Master.bank") == 2, "spellings share the refcount");
		assert(!registry.unload(".\\assets\\fmod\\Master.bank"), "first unload keeps the bank");
		assert(registry.refCount("assets/fmod/Master.bank") == 1, "refcount through a third spelling");
		assert(registry.unload("assets/fmod/Master.bank"), "last unload releases");
		stub.testSyntheticHandles = false;
	}

	static function testBankRegistryErroredRetry():Void {
		// A replacement load for an entry that settled in ERROR must unload
		// the dead placeholder first, or its handle slot leaks per retry
		var stub = haxefmod.studio.native.NativeStudioStub;
		stub.testSyntheticHandles = true;
		stub.testBankLoadingState = 4; // ERROR: invalid, not LOADING
		stub.testBankUnloadCalls = 0;
		var registry = new BankRegistry();
		var first = registry.loadAsync("assets/fmod/Level.bank");
		assert(!first.isNull(), "errored placeholder registered");
		var unloadsBefore = stub.testBankUnloadCalls;
		var second = registry.loadAsync("assets/fmod/Level.bank");
		assert(!second.isNull(), "retry starts a replacement load");
		assert((second : Int) != (first : Int), "replacement is a fresh handle");
		assert(stub.testBankUnloadCalls == unloadsBefore + 1,
			"errored placeholder unloaded before the retry");
		assert(registry.anyError(), "errored bank surfaces through anyError");
		stub.testBankLoadingState = 3;
		assert(!registry.anyError(), "loaded banks report no error");

		// Native semantics: an errored NONBLOCKING bank still reports
		// valid until unloaded, and a retry must still replace it instead
		// of refcounting onto the dead load forever
		stub.testBankLoadingState = 4;
		stub.testBankValid = true;
		stub.testBankUnloadCalls = 0;
		var nativeErr = registry.loadAsync("assets/fmod/NativeErr.bank");
		var retried = registry.loadAsync("assets/fmod/NativeErr.bank");
		assert((retried : Int) != (nativeErr : Int), "valid-but-errored bank is replaced on retry");
		assert(stub.testBankUnloadCalls == 1, "valid-but-errored bank unloaded before the retry");
		stub.testBankValid = null;
		stub.testSyntheticHandles = false;
		stub.testBankLoadingState = 3;
		stub.testBankUnloadCalls = 0;
	}

	// Runs last: FmodRuntime.init is a one-shot process-wide latch
	static function testIsInitializedComposition():Void {
		var stub = haxefmod.studio.native.NativeStudioStub;
		stub.testInitialized = false;
		assert(!FmodRuntime.isInitialized(), "not initialized while the system is down");
		// Direct NativeStudio users never call init: with no resolved
		// settings there are no default banks to wait for
		stub.testInitialized = true;
		assert(FmodRuntime.isInitialized(), "system-ready fallback with no settings");
		stub.testInitialized = false;
		FmodRuntime.init({autoLoadBanks: []});
		assert(!FmodRuntime.isInitialized(), "settings alone do not make it initialized");
		stub.testInitialized = true;
		assert(FmodRuntime.isInitialized(), "system ready and default banks latched");
		stub.testInitialized = false;
		assert(!FmodRuntime.isInitialized(), "system gate still applies after init");
	}

	// Runs after the init-composition test (needs the initialized runtime).
	// The attach-and-forget release path is the one instance-leak path the
	// CI handle-leak gates skip: the pan test exits before playout.
	static function testAttachedOneShotAutoRelease():Void {
		var stub = haxefmod.studio.native.NativeStudioStub;
		stub.testSyntheticHandles = true;
		stub.testInitialized = true;
		stub.testReleasedHandles = [];
		stub.testPlaybackState = 0; // PLAYING

		var baseline = FmodRuntime.attachedCount();
		FmodRuntime.playOneShotAttached("event:/OneShot", new StaticProvider(1, 2));
		assert(FmodRuntime.attachedCount() == baseline + 1, "one-shot attaches while playing");

		FmodRuntime.update();
		assert(FmodRuntime.attachedCount() == baseline + 1, "playing one-shot stays attached");
		assert(stub.testReleasedHandles.length == 0, "playing one-shot is not released");

		stub.testPlaybackState = 2; // STOPPED
		FmodRuntime.update();
		assert(FmodRuntime.attachedCount() == baseline, "stopped one-shot detaches itself");
		assert(stub.testReleasedHandles.length == 1, "stopped one-shot releases its instance");

		stub.testPlaybackState = 2; // restore the stub default
		stub.testReleasedHandles = [];
		stub.testInitialized = false;
		stub.testSyntheticHandles = false;
	}

	static function testAttachedInstances():Void {
		var attached = new AttachedInstances();
		var provider:IFmodPositionProvider = new StaticProvider(3, 4);

		attached.attach(EventInstance.NULL, provider);
		assert(attached.count() == 0, "null instance not attached");

		// A nonzero handle is invalid on the stub backend, so it attaches
		// and then prunes on the first update
		var fake:EventInstance = cast 0x10001;
		attached.attach(fake, provider);
		assert(attached.count() == 1, "instance attached");
		attached.attach(fake, provider);
		assert(attached.count() == 1, "re-attach replaces");
		attached.update();
		assert(attached.count() == 0, "invalid instance pruned");

		attached.attach(fake, provider);
		attached.detach(fake);
		assert(attached.count() == 0, "detach removes");

		// Velocity clamp: direction preserved, magnitude capped, disabled at 0
		assert(AttachedInstances.velocityScale(3, 4, 0) == 1.0, "clamp disabled at 0");
		assert(AttachedInstances.velocityScale(3, 4, 10) == 1.0, "clamp inactive under max");
		var scale = AttachedInstances.velocityScale(30, 40, 10);
		assert(Math.abs(30 * scale - 6.0) < 1e-9 && Math.abs(40 * scale - 8.0) < 1e-9, "clamp caps magnitude");
		assert(AttachedInstances.velocityScale(0, 0, 10) == 1.0, "clamp safe on zero velocity");
	}
}

private class StaticProvider implements IFmodPositionProvider {
	var x:Float;
	var y:Float;

	public function new(x:Float, y:Float) {
		this.x = x;
		this.y = y;
	}

	public function fmodX():Float return x;
	public function fmodY():Float return y;
	public function fmodVelocityX():Float return 0;
	public function fmodVelocityY():Float return 0;
}
