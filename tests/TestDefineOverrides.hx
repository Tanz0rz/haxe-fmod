package tests;

import haxefmod.runtime.FmodSettings;

/**
 * Proves the -D haxefmod_* define plumbing actually reaches the settings
 * resolver. The main suite only ever runs the fallback branches, so a
 * typo in Defines or the resolver would silently ignore every user's
 * project.xml haxedefs. Compiled and run by CI with:
 *
 *   -D haxefmod_num_channels=64 -D haxefmod_sample_rate=44100
 *   -D haxefmod_log_level=3 -D haxefmod_bank_folder=custom/banks
 *   -D haxefmod_live_update -D haxefmod_no_mute_when_unfocused
 *
 * and separately with -debug and no haxefmod defines (the debug build's
 * liveUpdate default). tests/build-defines.hxml and
 * tests/build-debug-defaults.hxml carry the exact invocations.
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

		#if haxefmod_num_channels
		assert(resolved.numChannels == 64, "haxefmod_num_channels reaches the resolver");
		assert(resolved.sampleRate == 44100, "haxefmod_sample_rate reaches the resolver");
		assert(resolved.logLevel == 3, "haxefmod_log_level reaches the resolver");
		assert(resolved.bankFolder == "custom/banks", "haxefmod_bank_folder reaches the resolver");
		assert(resolved.liveUpdate == true, "haxefmod_live_update reaches the resolver");
		assert(resolved.muteWhenUnfocused == false, "haxefmod_no_mute_when_unfocused reaches the resolver");
		// Explicit settings still beat defines
		var explicit = FmodSettingsResolver.resolve({numChannels: 32, bankFolder: "explicit"});
		assert(explicit.numChannels == 32, "explicit settings beat the channel define");
		assert(explicit.bankFolder == "explicit", "explicit settings beat the folder define");
		#elseif debug
		// The -debug build with no haxefmod defines: liveUpdate defaults on
		assert(resolved.liveUpdate == true, "debug builds default liveUpdate on");
		assert(resolved.numChannels == 128, "debug build keeps the channel fallback");
		#else
		assert(false, "this suite must be compiled with the define set or -debug (see the hxml files)");
		#end

		Sys.println('  $passed passed, $failed failed');
		Sys.exit(failed == 0 ? 0 : 1);
	}
}
