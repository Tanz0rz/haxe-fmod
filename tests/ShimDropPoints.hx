package tests;

import haxefmod.core.PcmStream;
import haxefmod.runtime.FmodRuntime;
import haxefmod.studio.FmodResult;
import haxefmod.studio.StudioSystem;
import haxefmod.studio.Types;
import haxefmod.studio.native.NativeStudio;

/**
 * Shim paths FMOD reaches only on a refusal or with a record device,
 * run on an engine-free HashLink host against an hdll linked with the
 * wrappers in tests/native/hlaxe_test_wraps.c.
 */
class ShimDropPoints {
	static var failed = 0;

	static function check(name:String, ok:Bool, detail:String):Void {
		if (!ok) failed++;
		Sys.println('SHIM_DROP_POINTS: $name pass=$ok $detail');
	}

	static function settle(seconds:Float):Void {
		var end = haxe.Timer.stamp() + seconds;
		while (haxe.Timer.stamp() < end) {
			FmodRuntime.update();
			Sys.sleep(0.01);
		}
	}

	static function main() {
		FmodRuntime.init({autoLoadBanks: [], output: FmodOutputType.NOSOUND, autoUpdate: false});

		// A refused release leaves the stream whole. The reader gets its ring back.
		var stream = PcmStream.create(48000, 1);
		stream.play();
		settle(0.5);
		check("empty_stream_underruns", stream.takeUnderruns() > 0, "");
		stream.setUserData("kept");
		Sys.putEnv("HLAXE_TEST_REFUSE_SOUND_RELEASE", "1");
		var refused:FmodResult = stream.release();
		Sys.putEnv("HLAXE_TEST_REFUSE_SOUND_RELEASE", "0");
		check("pcm_refused_release_reports", refused == FmodResult.FMOD_ERR_NOTREADY, 'result=${refused.toString()}');
		check("pcm_refused_release_keeps_stream", stream.getUserData() == "kept" && stream.space() > 0, 'space=${stream.space()}');
		stream.takeUnderruns();
		settle(0.5);
		var underruns = stream.takeUnderruns();
		check("pcm_refused_release_returns_the_ring", underruns > 0, 'underruns=$underruns');
		var released:FmodResult = stream.release();
		check("pcm_release_after_refusal", released.isOk(), 'result=${released.toString()}');

		// An accepted record stop ends the short-lived handles
		var holder = PcmStream.create(48000, 1);
		var channel = holder.play(true);
		var shortLived = channel.getCurrentSound();
		shortLived.setUserData("short-lived");
		var liveBefore = NativeStudio.debug_handle_is_live(shortLived);
		Sys.putEnv("HLAXE_TEST_ACCEPT_RECORD_STOP", "1");
		var stopped:FmodResult = StudioSystem.recordStop(0);
		Sys.putEnv("HLAXE_TEST_ACCEPT_RECORD_STOP", "0");
		check("short_lived_dies_at_record_stop", !shortLived.isNull() && liveBefore && stopped.isOk()
			&& !NativeStudio.debug_handle_is_live(shortLived) && shortLived.getUserData() == null,
			'sound=${(shortLived : Int)} result=${stopped.toString()} live=${NativeStudio.debug_handle_is_live(shortLived)}');
		holder.release();

		Sys.println('SHIM_DROP_POINTS: COMPLETE failed=$failed');
		Sys.exit(failed == 0 ? 0 : 1);
	}
}
