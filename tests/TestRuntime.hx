package tests;

import haxefmod.runtime.AttachedInstances;
import haxefmod.runtime.BankRegistry;
import haxefmod.runtime.FmodSettings;
import haxefmod.runtime.FmodRuntime;
import haxefmod.studio.Types;
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
		testBankRegistryAliases();
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
		assert(resolved.dspBufferSize == 0, "default dspBufferSize");
		assert(resolved.dspNumBuffers == 0, "default dspNumBuffers");
		assert(resolved.rawSpeakers == 0, "default rawSpeakers");
		assert(resolved.output == FmodOutputType.AUTODETECT, "default output");
		assert(resolved.resamplerMethod == FmodDspResampler.DEFAULT, "default resamplerMethod");
		assert(resolved.memoryPoolSize == 0, "default memoryPoolSize");
		assert(resolved.memoryTracking == false, "default memoryTracking");
		assert(resolved.threadAttributes.length == 0, "default threadAttributes");
		assert(resolved.logFile == "", "default logFile");
		assert((resolved.logFlags : Int) == 0, "default logFlags");
		assert(resolved.softwareChannels == 0, "default softwareChannels");
		assert(resolved.streamBufferSize == 0, "default streamBufferSize");
		assert(resolved.profiling == false, "default profiling");
		assert(resolved.distanceFilter == false, "default distanceFilter");
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
			dspBufferSize: 512,
			dspNumBuffers: 4,
			rawSpeakers: 6,
			output: FmodOutputType.NOSOUND_NRT,
			resamplerMethod: FmodDspResampler.CUBIC,
			memoryPoolSize: 1000,
			memoryTracking: true,
			threadAttributes: [{type: FmodThreadType.MIXER, priority: FmodThreadPriority.HIGH}],
			logFile: "fmod.log",
			logFlags: FmodDebugFlags.TYPE_FILE | FmodDebugFlags.DISPLAY_TIMESTAMPS,
			softwareChannels: 32,
			streamBufferSize: 65536,
			profiling: true,
			distanceFilter: true,
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
		assert(resolved.dspBufferSize == 512, "override dspBufferSize");
		assert(resolved.dspNumBuffers == 4, "override dspNumBuffers");
		assert(resolved.rawSpeakers == 6, "override rawSpeakers");
		assert(resolved.output == FmodOutputType.NOSOUND_NRT, "override output");
		assert(resolved.resamplerMethod == FmodDspResampler.CUBIC, "override resamplerMethod");
		assert(resolved.memoryPoolSize == 1000, "override memoryPoolSize");
		assert(resolved.memoryTracking == true, "override memoryTracking");
		assert(resolved.threadAttributes.length == 1 && resolved.threadAttributes[0].type == FmodThreadType.MIXER
			&& resolved.threadAttributes[0].priority == FmodThreadPriority.HIGH
			&& resolved.threadAttributes[0].stackSize == null, "override threadAttributes");
		assert(resolved.logFile == "fmod.log", "override logFile");
		assert((resolved.logFlags : Int) == (0x200 | 0x10000), "override logFlags");
		assert(resolved.softwareChannels == 32, "override softwareChannels");
		assert(resolved.streamBufferSize == 65536, "override streamBufferSize");
		assert(resolved.profiling == true, "override profiling");
		assert(resolved.distanceFilter == true, "override distanceFilter");
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

	static function testBankRegistryAliases():Void {
		// FMOD reports a second spelling of a loaded bank as already
		// loaded. The registry shares one entry between the spellings.
		var stub = haxefmod.studio.native.NativeStudioStub;
		stub.testSyntheticHandles = true;
		stub.testBankLoadingState = 3;
		stub.testBankValid = null;
		var registry = new BankRegistry();
		var desktop = "assets/fmod/Desktop/Music.bank";
		var mobile = "assets/fmod/Mobile/Music.bank";
		var first = registry.load(desktop);
		assert(!first.isNull(), "the first spelling loads");
		stub.testSyntheticHandles = false;
		stub.testLastResult = 70; // FMOD_ERR_EVENT_ALREADY_LOADED
		stub.testGetBankHandle = first;
		var second = registry.load(mobile);
		stub.testSyntheticHandles = true;
		assert(second == first, "the second spelling adopts the loaded bank");
		assert(registry.refCount(desktop) == 2 && registry.refCount(mobile) == 2, "both spellings share one count");
		var unloads = stub.testBankUnloadCalls;
		assert(!registry.unload(mobile) && stub.testBankUnloadCalls == unloads, "the first unload keeps the bank");
		assert(registry.refCount(desktop) == 1, "the shared count drops once");
		assert(registry.unload(desktop) && stub.testBankUnloadCalls == unloads + 1, "the last unload unloads once");
		assert(!registry.isRegistered(desktop) && !registry.isRegistered(mobile), "every spelling goes with the entry");

		// A shared entry whose bank died is replaced in place, so every
		// spelling follows the reload and the count carries over
		first = registry.load(desktop);
		stub.testSyntheticHandles = false;
		stub.testGetBankHandle = first;
		registry.load(mobile);
		stub.testSyntheticHandles = true;
		stub.testLastResult = 68; // FMOD_ERR_UNSUPPORTED, the stub default
		stub.testGetBankHandle = 0;
		stub.testBankValid = false;
		unloads = stub.testBankUnloadCalls;
		var reloaded = registry.load(mobile);
		stub.testBankValid = null;
		assert(!reloaded.isNull() && reloaded != first, "a dead shared bank is loaded afresh");
		assert(stub.testBankUnloadCalls == unloads + 1, "the dead bank is unloaded once");
		assert(registry.get(desktop) == reloaded && registry.get(mobile) == reloaded, "both spellings follow the reload");
		assert(registry.refCount(desktop) == 3 && registry.refCount(mobile) == 3, "the holders of both spellings carry over");
		registry.unload(desktop);
		registry.unload(desktop);
		assert(registry.unload(mobile) && !registry.isRegistered(desktop), "three unloads release the shared bank");

		// A stale entry that adopts a live one merges into it: the count
		// carries over and every spelling of the stale entry follows
		var reg2 = new BankRegistry();
		stub.testSyntheticHandles = true;
		stub.testBankValid = null;
		stub.testBankLoadingState = 3;
		var owner = reg2.load("a/M.bank");
		stub.testSyntheticHandles = false;
		stub.testLastResult = 70;
		stub.testGetBankHandle = owner;
		reg2.load("a2/M.bank");
		stub.testSyntheticHandles = true;
		stub.testLastResult = 68;
		stub.testGetBankHandle = 0;
		var doomed = reg2.load("b/M.bank");
		stub.testSyntheticHandles = false;
		stub.testLastResult = 70;
		stub.testGetBankHandle = doomed;
		reg2.load("b2/M.bank");
		stub.testSyntheticHandles = true;
		stub.testLastResult = 68;
		stub.testGetBankHandle = 0;
		assert(reg2.refCount("a/M.bank") == 2 && reg2.refCount("b/M.bank") == 2, "two aliased entries stand");
		// b's bank dies, and the retry finds a's bank loaded already
		stub.testBankValid = false;
		stub.testSyntheticHandles = false;
		stub.testLastResult = 70;
		stub.testGetBankHandle = owner;
		var adopted = reg2.load("b/M.bank");
		stub.testSyntheticHandles = true;
		stub.testBankValid = null;
		stub.testLastResult = 68;
		stub.testGetBankHandle = 0;
		assert((adopted : Int) == (owner : Int), "the retry adopts the live bank");
		assert(reg2.refCount("a/M.bank") == 5 && reg2.refCount("b/M.bank") == 5,
			'adopt carries the stale holders (a=${reg2.refCount("a/M.bank")} b=${reg2.refCount("b/M.bank")})');
		assert(reg2.refCount("b2/M.bank") == 5 && (reg2.get("b2/M.bank") : Int) == (owner : Int),
			'every stale spelling follows the adopt (b2=${reg2.refCount("b2/M.bank")})');

		// A failed retry forgets every spelling of the stale entry
		var reg3 = new BankRegistry();
		stub.testSyntheticHandles = true;
		var lost = reg3.load("c/M.bank");
		stub.testSyntheticHandles = false;
		stub.testLastResult = 70;
		stub.testGetBankHandle = lost;
		reg3.load("c2/M.bank");
		stub.testLastResult = 68;
		stub.testGetBankHandle = 0;
		stub.testBankValid = false;
		reg3.load("c/M.bank");
		stub.testBankValid = null;
		assert(!reg3.isRegistered("c/M.bank") && !reg3.isRegistered("c2/M.bank"),
			"a failed retry forgets every spelling");
		// The stub defaults the later tests count on
		stub.testSyntheticHandles = false;
		stub.testBankLoadingState = 3;
		stub.testBankUnloadCalls = 0;
		stub.testGetBankHandle = 0;
	}

	static function testBankRegistryNormalization():Void {
		// Every spelling of a path lands on the same registry entry, so
		// refcounts cannot split across separators or dot segments
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
		stub.testBankLoadingState = 4; // ERROR: invalid rather than LOADING
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

		// Native semantics: an errored NONBLOCKING bank reports valid
		// until unloaded. The dedup check has to look at the loading
		// state or this retry would just bump the dead refcount
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
		stub.testLastInit = null;
		stub.testPreInitCalls = [];

		// Provided banks: the engine preloader hands bytes over, and init
		// loads them from memory under the path a file load would use
		var registry = new BankRegistry();
		stub.testSyntheticHandles = true;
		stub.testBankMemoryLoads = [];
		var memoryBank = registry.loadMemory("assets/fmod/Desktop/Mem.bank", haxe.io.Bytes.alloc(16));
		assert(!memoryBank.isNull(), "loadMemory returns a bank");
		assert(stub.testBankMemoryLoads.length == 1 && stub.testBankMemoryLoads[0] == 16, "loadMemory hands the byte count to native");
		assert(registry.isRegistered("assets/fmod/Desktop/Mem.bank") && registry.refCount("./assets/fmod/Desktop/Mem.bank") == 1,
			"loadMemory registers under the normalized path");
		assert((registry.loadMemory("assets/fmod/Desktop/Mem.bank", haxe.io.Bytes.alloc(1)) : Int) == (memoryBank : Int)
			&& registry.refCount("assets/fmod/Desktop/Mem.bank") == 2, "a second loadMemory bumps the refcount");
		// loadMemory takes the same two paths: a dead entry is unloaded
		// before the replacement, and a bank FMOD already holds is adopted
		var reg4 = new BankRegistry();
		stub.testSyntheticHandles = true;
		stub.testBankMemoryLoads = [];
		var mem = reg4.loadMemory("m/M.bank", haxe.io.Bytes.alloc(8));
		stub.testBankValid = false;
		stub.testBankUnloadCalls = 0;
		var memAgain = reg4.loadMemory("m/M.bank", haxe.io.Bytes.alloc(8));
		stub.testBankValid = null;
		assert((memAgain : Int) != (mem : Int) && stub.testBankUnloadCalls == 1,
			'loadMemory unloads the dead entry before the replacement (unloads=${stub.testBankUnloadCalls})');
		assert(reg4.refCount("m/M.bank") == 2, 'loadMemory carries the holders (refs=${reg4.refCount("m/M.bank")})');
		stub.testBankValid = false;
		stub.testSyntheticHandles = false;
		stub.testLastResult = 70;
		stub.testGetBankHandle = memAgain;
		var memAdopted = reg4.loadMemory("m/M.bank", haxe.io.Bytes.alloc(8));
		stub.testSyntheticHandles = true;
		stub.testBankValid = null;
		stub.testLastResult = 68;
		stub.testGetBankHandle = 0;
		assert((memAdopted : Int) == (memAgain : Int) && reg4.isRegistered("m/M.bank")
			&& reg4.refCount("m/M.bank") == 3,
			'loadMemory adopts a bank FMOD already holds (handle=${(memAdopted : Int)} refs=${reg4.refCount("m/M.bank")})');
		stub.testBankUnloadCalls = 0;
		assert(!FmodRuntime.allBanksProvided(), "nothing is provided before init resolves the settings");
		FmodRuntime.provideBank("assets/fmod/Desktop/Master.bank", haxe.io.Bytes.alloc(32));
		assert(FmodRuntime.bankPath("Master.bank", "custom/banks") == "custom/banks/Master.bank", "bankPath takes the folder before init");
		assert(FmodRuntime.providedBankCount() == 0, "no provided bank is loaded before init");
		stub.testBankMemoryLoads = [];
		FmodRuntime.init({autoLoadBanks: ["Master.bank"], banksProvided: true, dspBufferSize: 1024, dspNumBuffers: 3,
			output: FmodOutputType.NOSOUND, resamplerMethod: FmodDspResampler.SPLINE, rawSpeakers: 4,
			memoryTracking: true, memoryPoolSize: 1000, logFile: "fmod-test.log", logLevel: 3,
			logFlags: FmodDebugFlags.TYPE_MEMORY,
			threadAttributes: [
				{type: FmodThreadType.MIXER, priority: FmodThreadPriority.EXTREME, stackSize: FmodThreadStackSize.MIXER, affinity: FmodThreadAffinity.CORE_1},
				{type: FmodThreadType.STUDIO_UPDATE}
			],
			softwareChannels: 48, streamBufferSize: 32768, profiling: true, distanceFilter: true,
			maxMPEGCodecs: 8, maxVorbisCodecs: 9, maxFADPCMCodecs: 10, vol0VirtualVol: 0.01,
			defaultDecodeBufferSize: 800, profilePort: 9300, geometryMaxFadeTime: 250,
			distanceFilterCenterFreq: 2000, randomSeed: 12345, commandQueueSize: 65536,
			handleInitialSize: 16384, studioUpdatePeriod: 30, idleSampleDataPoolSize: 524288,
			streamingScheduleDelay: 4096, encryptionKey: "secret"});
		assert(!FmodRuntime.isInitialized(), "settings alone do not make it initialized");
		assert(FmodRuntime.settings().banksProvided, "banksProvided reaches the resolved settings");
		assert(FmodRuntime.allBanksProvided(), "the provided bank is found by its file name");
		assert(FmodRuntime.providedBankCount() == 1 && stub.testBankMemoryLoads.length == 1 && stub.testBankMemoryLoads[0] == 32,
			"init loads the provided bank from memory");
		assert(FmodRuntime.banks.isRegistered("assets/fmod/Desktop/Master.bank"), "the provided bank is registered under the file path");
		assert(!FmodRuntime.initFailed(), "a provided bank that loads is not a failure");
		stub.testSyntheticHandles = false;
		// The one init call this suite gets also proves the settings reach
		// the native call in the right slots
		var init = stub.testLastInit;
		assert(init != null, "init reaches sys_init_ex");
		assert(init != null && init.numChannels == 128, "init forwards numChannels");
		assert(init != null && init.dspBufferLength == 1024, "init forwards dspBufferSize");
		assert(init != null && init.dspNumBuffers == 3, "init forwards dspNumBuffers");
		assert(init != null && init.softwareChannels == 48, "init forwards softwareChannels");
		assert(init != null && init.streamBufferSize == 32768, "init forwards streamBufferSize");
		assert(init != null && init.initFlags == 3, "init packs profiling and distanceFilter into initFlags");
		assert(init != null && init.maxMPEGCodecs == 8 && init.maxVorbisCodecs == 9 && init.maxFADPCMCodecs == 10,
			"init forwards the codec limits");
		assert(init != null && Math.abs(init.vol0VirtualVol - 0.01) < 0.0001, "init forwards vol0VirtualVol");
		assert(init != null && init.defaultDecodeBufferSize == 800 && init.profilePort == 9300
			&& init.geometryMaxFadeTime == 250, "init forwards decode buffer, profile port, and geometry fade");
		assert(init != null && Math.abs(init.distanceFilterCenterFreq - 2000) < 0.001, "init forwards distanceFilterCenterFreq");
		assert(init != null && init.randomSeed == 12345, "init forwards randomSeed");
		assert(init != null && init.commandQueueSize == 65536 && init.handleInitialSize == 16384
			&& init.studioUpdatePeriod == 30 && init.idleSampleDataPoolSize == 524288
			&& init.streamingScheduleDelay == 4096, "init forwards the studio advanced settings");
		assert(init != null && init.encryptionKey == "secret", "init forwards encryptionKey");
		assert(init != null && init.studioFlags == 2, "init packs memoryTracking into studioFlags bit1");
		// The pre-create calls run in order before sys_init_ex. The log file
		// goes first. The pool follows, rounded by the shim, so the raw size
		// crosses. Then comes one thread call per entry with FMOD's defaults
		// filled in. The output format goes last for sys_init_ex to pick up.
		var pre = stub.testPreInitCalls;
		assert(pre.length == 5, 'pre-init call count ${pre.length}');
		assert(pre.length == 5 && pre[0] == "debug:260,1,fmod-test.log", 'log file call ${pre[0]}');
		assert(pre.length == 5 && pre[1] == "memory:1000", 'memory pool call ${pre[1]}');
		assert(pre.length == 5 && pre[2] == "thread:0,-32774,81920,2", 'mixer thread call ${pre[2]}');
		assert(pre.length == 5 && pre[3] == "thread:8,-32769,0,-1", 'studio update thread call with defaults ${pre[3]}');
		assert(pre.length == 5 && pre[4] == "format:2,4,4", 'output format call ${pre[4]}');
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
		// A serviced frame drains the dispatcher, which runs the frame hook
		var drains = 0;
		var savedHook = haxefmod.studio.CallbackDispatcher.frameHook;
		haxefmod.studio.CallbackDispatcher.frameHook = function() drains++;
		FmodRuntime.update();
		haxefmod.studio.CallbackDispatcher.frameHook = savedHook;
		assert(drains == 1, "update drains the callback dispatcher once");
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
