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
class TestRuntime {
	static var passed = 0;
	static var failed = 0;

	public static function run():Int {
		Sys.println("--- Runtime (stub backend) ---");

		testSettingsDefaults();
		testSettingsOverrides();
		testFocusMute();
		testBankRegistry();
		testAttachedInstances();

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
		});
		assert(resolved.numChannels == 64, "override numChannels");
		assert(resolved.sampleRate == 48000, "override sampleRate");
		assert(resolved.liveUpdate == true, "override liveUpdate");
		assert(resolved.logLevel == 3, "override logLevel");
		assert(resolved.bankFolder == "sounds", "override bankFolder");
		assert(resolved.autoLoadBanks.length == 0, "override autoLoadBanks");
		assert(resolved.autoUpdate == false, "override autoUpdate");
		assert(resolved.muteWhenUnfocused == false, "override muteWhenUnfocused");

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
