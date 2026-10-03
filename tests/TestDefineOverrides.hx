package tests;

import haxefmod.runtime.FmodSettings;

/**
 * Proves the -D haxefmod_* define plumbing actually reaches the settings
 * resolver. The main suite only ever runs the fallback branches, so a
 * typo in Defines or the resolver would silently ignore every user's
 * project.xml haxedefs. Three hxml files carry the exact CI invocations:
 * tests/build-defines.hxml, tests/build-debug-defaults.hxml, and
 * tests/build-no-live-update.hxml. The last one compiles with -debug and
 * both live update defines, and the off switch must win. The
 * second one compiles with -debug and no haxefmod settings defines, which covers
 * the debug build's liveUpdate default. It also enables the Todo
 * placeholder beep, which must not initialize FMOD. The first one passes these
 * defines:
 *
 *   -D haxefmod_num_channels=64 -D haxefmod_sample_rate=44100
 *   -D haxefmod_log_level=3 -D haxefmod_bank_folder=custom/banks
 *   -D haxefmod_live_update -D haxefmod_no_mute_when_unfocused
 *   -D haxefmod_dsp_buffer_size=1024 -D haxefmod_software_channels=48
 */
class TestDefineOverrides {
	static var passed = 0;
	static var failed = 0;

	static function assert(condition:Bool, name:String):Void {
		if (condition) passed++ else {
			failed++;
			Sys.println('  FAIL: $name');
		}
	}

	public static function main():Void {
		Sys.println("--- Define overrides ---");
		var resolved = FmodSettingsResolver.resolve(null);

		#if haxefmod_no_live_update
		assert(resolved.liveUpdate == false, "haxefmod_no_live_update beats -debug and haxefmod_live_update");
		assert(FmodSettingsResolver.resolve({liveUpdate: true}).liveUpdate, "explicit liveUpdate beats haxefmod_no_live_update");
		#elseif haxefmod_num_channels
		assert(resolved.numChannels == 64, "haxefmod_num_channels reaches the resolver");
		assert(resolved.sampleRate == 44100, "haxefmod_sample_rate reaches the resolver");
		assert(resolved.logLevel == 3, "haxefmod_log_level reaches the resolver");
		assert(resolved.bankFolder == "custom/banks", "haxefmod_bank_folder reaches the resolver");
		assert(resolved.liveUpdate == true, "haxefmod_live_update reaches the resolver");
		assert(resolved.muteWhenUnfocused == false, "haxefmod_no_mute_when_unfocused reaches the resolver");
		assert(resolved.dspBufferSize == 1024, "haxefmod_dsp_buffer_size reaches the resolver");
		assert(resolved.softwareChannels == 48, "haxefmod_software_channels reaches the resolver");
		// Explicit settings beat defines
		var explicit = FmodSettingsResolver.resolve({numChannels: 32, bankFolder: "explicit"});
		assert(explicit.numChannels == 32, "explicit settings beat the channel define");
		assert(explicit.bankFolder == "explicit", "explicit settings beat the folder define");
		haxefmod.runtime.FmodRuntime.init({autoLoadBanks: []});
		assert(!haxefmod.runtime.FmodRuntime.isMuteWhenUnfocused(), "init applies the resolved mute policy");
		#elseif debug
		// The -debug build with no haxefmod settings defines: liveUpdate defaults on
		assert(resolved.liveUpdate == true, "debug builds default liveUpdate on");
		assert(resolved.numChannels == 128, "debug build keeps the channel fallback");
		#if haxefmod_todo_beep
		// The placeholder beep once initialized FMOD with the default
		// settings, so the game's own Initialize call was ignored
		haxefmod.FmodManager.Todo("door creak");
		assert(haxefmod.runtime.FmodRuntime.settings() == null, "a Todo beep before Initialize leaves FMOD uninitialized");
		haxefmod.FmodManager.Initialize({bankFolder: "todo/banks", autoLoadBanks: []});
		var picked = haxefmod.runtime.FmodRuntime.settings();
		assert(picked != null && picked.bankFolder == "todo/banks", "Initialize after a Todo beep takes its settings");
		// Two markers in one frame each play a beep. The second one
		// stopped the first beep's channel, which ended every short-lived
		// handle the game held.
		haxefmod.studio.native.NativeStudioStub.testInitialized = true;
		haxefmod.studio.native.NativeStudioStub.testSyntheticHandles = true;
		haxefmod.studio.native.NativeStudioStub.testChanStopCalls = 0;
		haxefmod.studio.native.NativeStudioStub.testPlayCalls = 0;
		haxefmod.FmodManager.Todo("first marker");
		haxefmod.FmodManager.Todo("second marker");
		assert(haxefmod.studio.native.NativeStudioStub.testPlayCalls == 2, "each Todo site plays one beep");
		assert(haxefmod.studio.native.NativeStudioStub.testChanStopCalls == 0, "a Todo beep stops no channel");
		haxefmod.studio.native.NativeStudioStub.testSyntheticHandles = false;
		haxefmod.studio.native.NativeStudioStub.testInitialized = false;
		#end
		#else
		assert(false, "this suite must be compiled with the define set or -debug (see the hxml files)");
		#end

		Sys.println('  $passed passed, $failed failed');
		Sys.exit(failed == 0 ? 0 : 1);
	}
}
