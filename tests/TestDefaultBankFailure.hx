package tests;

import haxefmod.runtime.FmodRuntime;

/**
 * A default bank that fails on a native target, on the stub backend.
 * The plain build has the runtime load a bank the stub rejects. The
 * provided_mode build promises the banks and leaves one out. Both end
 * initialized with initFailed() true. A process gets one init, so each
 * build owns its own process.
 */
class TestDefaultBankFailure {
	static var passed = 0;
	static var failed = 0;

	static function assert(condition:Bool, name:String):Void {
		if (condition) passed++ else {
			failed++;
			Sys.println('  FAIL: $name');
		}
	}

	public static function main():Void {
		Sys.println("--- Default bank failure ---");
		var stub = haxefmod.studio.native.NativeStudioStub;
		var traces:Array<String> = [];
		haxe.Log.trace = function(v:Dynamic, ?infos:haxe.PosInfos) traces.push(Std.string(v));
		#if provided_mode
		FmodRuntime.provideBank("Master.bank", haxe.io.Bytes.alloc(8));
		stub.testSyntheticHandles = true;
		FmodRuntime.init({autoLoadBanks: ["Master.bank", "Missing.bank"], banksProvided: true});
		#else
		stub.testSyntheticHandles = false;
		FmodRuntime.init({autoLoadBanks: ["Missing.bank"]});
		#end
		stub.testInitialized = true;
		assert(FmodRuntime.isInitialized(), "initialized without the missing bank");
		assert(FmodRuntime.initFailed(), "a default bank that fails to load is a failure");
		var failedRan = 0;
		FmodRuntime.onceReady(() -> {}, () -> failedRan++);
		assert(failedRan == 1, "the onFailed side runs");
		var reports = traces.filter(t -> t.indexOf("Missing.bank") >= 0);
		assert(reports.length == 1, 'the failure is reported once (${reports.length})');
		Sys.println('  $passed passed, $failed failed');
		if (failed > 0) Sys.exit(1);
	}
}
