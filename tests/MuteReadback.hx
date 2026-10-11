package tests;

import haxefmod.FmodManager;
import haxefmod.runtime.FmodRuntime;
import haxefmod.studio.StudioSystem;
import haxefmod.studio.Types;

/**
 * A bus mute is a Studio command. FMOD applies it on its own thread
 * after an update, and a read made while that thread is busy can
 * return the state from before the set. Every test host flushes the
 * command queue before it reads a bus mute back. This program pins the
 * reason on an engine-free HashLink host: the stale read happens, and
 * a flushed read never does.
 */
class MuteReadback {
	static var failed = 0;

	static function check(name:String, ok:Bool, detail:String):Void {
		if (!ok) failed++;
		Sys.println('MUTE_READBACK: $name pass=$ok $detail');
	}

	// Sets then reads in batches. An update and a short sleep between
	// batches give FMOD's thread work to do while the next batch reads.
	static function batch(flush:Bool, reads:Int):Int {
		var stale = 0;
		for (i in 0...reads) {
			var want = (i & 1) == 0;
			FmodManager.SetMasterMute(want);
			if (flush) StudioSystem.flushCommands();
			if (FmodManager.IsMasterMuted() != want) stale++;
		}
		FmodRuntime.update();
		Sys.sleep(0.001);
		return stale;
	}

	static function main() {
		FmodRuntime.init({bankFolder: "example-project/EZPlatformer/assets/fmod/Desktop",
			autoLoadBanks: ["Master.strings.bank", "Master.bank"], output: FmodOutputType.NOSOUND, autoUpdate: false});
		FmodRuntime.update();

		// The stale read shows up within a few batches. The budget covers a
		// slow runner.
		var stale = 0;
		var reads = 0;
		var deadline = haxe.Timer.stamp() + 20;
		while (stale == 0 && haxe.Timer.stamp() < deadline) {
			stale += batch(false, 100);
			reads += 100;
		}
		check("immediate_read_lags_the_set", stale > 0, 'stale=$stale reads=$reads');

		var flushedStale = 0;
		for (i in 0...15) flushedStale += batch(true, 100);
		check("flushed_read_matches_the_set", flushedStale == 0, 'stale=$flushedStale reads=1500');

		FmodManager.SetMasterMute(false);
		StudioSystem.flushCommands();
		Sys.println('MUTE_READBACK: COMPLETE failed=$failed');
		Sys.exit(failed == 0 ? 0 : 1);
	}
}
