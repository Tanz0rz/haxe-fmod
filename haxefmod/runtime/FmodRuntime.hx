package haxefmod.runtime;

import haxefmod.core.ChannelGroup;
import haxefmod.runtime.FmodSettings;
import haxefmod.studio.CallbackDispatcher;
import haxefmod.studio.EventDescription;
import haxefmod.studio.EventInstance;
import haxefmod.studio.FmodResult;
import haxefmod.studio.Types;
import haxefmod.studio.StudioSystem;
import haxefmod.studio.native.NativeStudio;

/**
 * The engine-agnostic FMOD runtime: settings-driven init, bank management,
 * 3D attachment, and per-frame servicing. FmodManager is the helper
 * class built on top of this. Games that want more control use it directly:
 *
 *   FmodRuntime.init({liveUpdate: true});
 *   var jump = FmodRuntime.createInstance("event:/SFX/Jump");
 *
 * Everything here is static - there is exactly one FMOD system per
 * process, created on the first init and alive until the process exits.
 * There is deliberately no shutdown or re-init call. A teardown path
 * would trade a capability games do not use for a whole class of
 * use-after-shutdown bugs. FMOD releases everything at exit.
 */
class FmodRuntime {
    /** Refcounted bank loading (paths resolved against settings.bankFolder). */
    public static var banks(default, null):BankRegistry = new BankRegistry();

    static var attached:AttachedInstances = new AttachedInstances();
    static var resolved:ResolvedFmodSettings = null;
    static var initStarted:Bool = false;

    // Window focus tracking. Defaults to focused so games that never report
    // focus (or run before init) are never muted.
    static var focused:Bool = true;
    static var muteWhenUnfocused:Bool = true;
    // The focus mute last pushed to the master group. applyFocusMute only
    // touches (and lazily allocates) the master channel group when the
    // state actually changes, so a focused startup does not allocate it.
    static var focusMuteApplied:Bool = false;
    static var focusMuteSynced:Bool = false;
    // onceReady handlers waiting for readiness. An entry with an onFailed
    // runs that instead when a default bank fails.
    static var pendingHandlers:Array<{ready:Void->Void, failed:Void->Void}> = [];
    // Bank bytes the engine's loader delivered, keyed by bank path (the
    // name as given before init, see settleProvidedKeys). An entry is
    // removed once the runtime loaded it, FMOD copies the data.
    static var providedBanks:Map<String, haxe.io.Bytes> = new Map();
    // Every bank that was ever provided, for allBanksProvided
    static var providedNames:Map<String, Bool> = new Map();
    // Default banks that failed, keyed like providedBanks. A failed bank
    // is reported once and never retried.
    static var failedBanks:Map<String, Bool> = new Map();
    static var defaultBankFailed:Bool = false;
    // The system itself refused to initialize. Nothing gets ready then.
    static var systemFailed:Bool = false;

    /** Expected native binding ABI - lockstep with the manifest "# abi-version:". */
    public static inline var BINDING_ABI:Int = 12;

    /**
     * Initializes FMOD with the given settings (see FmodSettings for the
     * define-driven defaults). First initialization wins: settings passed
     * to any later init call are ignored. On HTML5 initialization is
     * asynchronous: poll isInitialized(), or just call update() every
     * frame and start events once it reports true.
     */
    public static function init(?settings:FmodSettings):FmodResult {
        if (initStarted) return initResult;
        initStarted = true;
        #if hl
        // A stale hdll usually dies at load with a missing-prim fatal, and
        // PostBuild refuses it even earlier. Lazy prim resolution can let a
        // mismatched hdll limp along, so check here instead.
        if (NativeStudio.binding_abi_version() != BINDING_ABI) {
            trace("Error: FMOD - hlaxe_fmod.hdll binding version "
                + NativeStudio.binding_abi_version() + " does not match this haxefmod ("
                + BINDING_ABI + "). Run: haxelib run haxefmod build-hdll");
            systemFailed = true;
            initResult = FmodResult.FMOD_ERR_VERSION;
            return initResult;
        }
        #end
        resolved = FmodSettingsResolver.resolve(settings);
        muteWhenUnfocused = resolved.muteWhenUnfocused;
        attached.maxVelocity = resolved.maxAttachedVelocity;


        // The settings FMOD only takes before the system exists: the log
        // target, the memory pool, and the thread attributes. Native only,
        // the web build has no pool and no threads. A failure is logged
        // and init carries on, FMOD runs fine on its defaults.
        var levelBits = resolved.logLevel <= 0 ? 0 : resolved.logLevel == 1 ? 1 : resolved.logLevel == 2 ? 2 : 4;
        if (resolved.logFile != "") {
            #if js
            trace("Warn: FMOD - logFile is not available on HTML5, the log stays on the console");
            NativeStudio.sys_set_debug_level(resolved.logLevel);
            #else
            var logResult:FmodResult = NativeStudio.sys_debug_initialize(levelBits | resolved.logFlags,
                FmodDebugMode.FILE, resolved.logFile);
            if (!logResult.isOk() && logResult != FmodResult.FMOD_ERR_UNSUPPORTED) {
                trace("Error: FMOD - could not open the log file " + resolved.logFile + ": " + logResult.toString());
            }
            #end
        } else if ((resolved.logFlags : Int) != 0) {
            NativeStudio.sys_debug_initialize(levelBits | resolved.logFlags, FmodDebugMode.TTY, "");
        } else {
            NativeStudio.sys_set_debug_level(resolved.logLevel);
        }
        #if !js
        if (resolved.memoryPoolSize > 0) {
            var poolResult:FmodResult = NativeStudio.sys_memory_initialize(resolved.memoryPoolSize);
            if (!poolResult.isOk()) {
                trace("Error: FMOD - memory pool of " + resolved.memoryPoolSize + " bytes refused: " + poolResult.toString());
            }
        }
        for (thread in resolved.threadAttributes) {
            var threadResult:FmodResult = NativeStudio.sys_thread_set_attributes(thread.type,
                thread.priority != null ? thread.priority : FmodThreadPriority.DEFAULT,
                thread.stackSize != null ? thread.stackSize : FmodThreadStackSize.DEFAULT,
                thread.affinity != null ? thread.affinity : -1);
            if (!threadResult.isOk()) {
                trace("Error: FMOD - thread attributes for thread type " + (thread.type : Int) + " refused: "
                    + threadResult.toString());
            }
        }
        #else
        if (resolved.memoryPoolSize > 0) trace("Warn: FMOD - memoryPoolSize is not available on HTML5, FMOD allocates from the wasm heap");
        if (resolved.threadAttributes.length > 0) trace("Warn: FMOD - threadAttributes are not available on HTML5, the web build has no threads to place");
        #end
        if ((resolved.output : Int) != 0 || (resolved.resamplerMethod : Int) != 0 || resolved.rawSpeakers != 0) {
            var formatResult:FmodResult = NativeStudio.sys_set_init_format(resolved.output, resolved.resamplerMethod,
                resolved.rawSpeakers);
            if (!formatResult.isOk()) {
                trace("Error: FMOD - output type " + (resolved.output : Int) + " refused: " + formatResult.toString());
                systemFailed = true;
                return initResult = formatResult;
            }
        }
        var initFlags = (resolved.profiling ? 1 : 0) | (resolved.distanceFilter ? 2 : 0);
        var studioFlags = (resolved.liveUpdate ? 1 : 0) | (resolved.memoryTracking ? 2 : 0);
        var result:FmodResult = NativeStudio.sys_init_ex(
            resolved.numChannels, resolved.sampleRate, resolved.speakerMode,
            studioFlags,
            resolved.dspBufferSize, resolved.dspNumBuffers, resolved.softwareChannels,
            resolved.streamBufferSize, initFlags,
            resolved.maxMPEGCodecs, resolved.maxVorbisCodecs, resolved.maxFADPCMCodecs, resolved.vol0VirtualVol,
            resolved.defaultDecodeBufferSize, resolved.profilePort, resolved.geometryMaxFadeTime,
            resolved.distanceFilterCenterFreq, resolved.randomSeed,
            resolved.commandQueueSize, resolved.handleInitialSize, resolved.studioUpdatePeriod,
            resolved.idleSampleDataPoolSize, resolved.streamingScheduleDelay, resolved.encryptionKey);

        #if (cpp || hl)
        if (!result.isOk()) {
            systemFailed = true;
            return initResult = result;
        }
        #end
        settleProvidedKeys();
        #if !js
        // Native init loads the default banks synchronously. The stub
        // backend runs the same path, so the unit tests cover it. A bank
        // that failed is reported, and the system is usable without it.
        loadDefaultBanks();
        defaultBanksLoaded = true;
        #end
        #if (cpp || hl)
        NativeStudio.sys_set_auto_update(resolved.autoUpdate);
        // Honor a focus loss that was reported before init completed.
        applyFocusMute();
        #end
        // HTML5: init completes asynchronously. The default banks load
        // through the registry once the system is ready, and
        // isInitialized() reports true only when they are usable.
        return initResult = result;
    }

    // The result of the first init, returned by every later call
    static var initResult:FmodResult = FmodResult.FMOD_OK;

    /**
     * True once FMOD is usable: the system is initialized AND every bank
     * in the settings' autoLoadBanks is loaded or has failed. Native init
     * does both synchronously. On HTML5 both are asynchronous, so games
     * gate their first state on this. A failed default bank is reported
     * by initFailed(), so a game checks that first.
     */
    public static function isInitialized():Bool {
        if (!NativeStudio.sys_is_initialized()) return false;
        #if js
        // The HTML5 shim cannot refuse inside init, since the module loads
        // later. A refused initialize is read here once the module is up.
        if (!systemFailed) {
            var refused:Int = js.Syntax.code("(typeof jaxe !== 'undefined' && jaxe.gInitFailure) ? jaxe.gInitFailure : 0");
            if (refused != 0) {
                systemFailed = true;
                initResult = cast refused;
                trace('Error: FMOD - the system refused to initialize ($initResult). The game runs without audio.');
            }
        }
        if (systemFailed) return false;
        #end
        // Direct NativeStudio users never went through init: no settings,
        // nothing to wait for
        if (resolved == null) return true;
        return defaultBanksReady();
    }

    static var defaultBanksLoaded:Bool = false;
    #if js
    static var defaultLoadsStarted:Bool = false;
    #end

    /**
     * Hands the runtime the bytes of a default bank, so initialization
     * loads it from memory instead of fetching the file. The engine
     * preloaders call this with what the engine's own loader delivered.
     * The name is the entry in autoLoadBanks, with or without the folder.
     * Call it before or after init, the bank is used either way. FMOD
     * copies the data, so the bytes are released after the load. A bank
     * provided after the runtime fetched it is ignored. A name that is
     * not in autoLoadBanks is dropped with a warning. Null bytes count
     * as a failed bank.
     */
    public static function provideBank(fileName:String, bytes:haxe.io.Bytes):Void {
        var key = bankKey(fileName);
        if (resolved != null && !isDefaultBank(key)) {
            warnUnexpected(fileName);
            return;
        }
        if (bytes == null) {
            provideBankFailed(fileName, "the loader delivered no bytes");
            return;
        }
        // A bank already handled, loaded or failed, takes no more bytes
        if (failedBanks.exists(key)) return;
        if (resolved != null && banks.isRegistered(key)) return;
        providedNames.set(key, true);
        providedBanks.set(key, bytes);
    }

    /**
     * Reports that a default bank cannot be provided: the engine's loader
     * found no such asset or its fetch failed. The runtime traces the
     * reason once, initFailed() turns true, and initialization completes
     * without that bank. The engine preloaders call this.
     */
    public static function provideBankFailed(fileName:String, reason:String):Void {
        var key = bankKey(fileName);
        if (resolved != null && !isDefaultBank(key)) {
            warnUnexpected(fileName);
            return;
        }
        if (failedBanks.exists(key)) return;
        failedBanks.set(key, true);
        defaultBankFailed = true;
        providedBanks.remove(key);
        providedNames.remove(key);
        trace('Error: FMOD - the default bank $fileName could not be provided: $reason. The game runs without it.');
    }

    /** True when the bytes of every bank in autoLoadBanks were provided. */
    public static function allBanksProvided():Bool {
        if (resolved == null) return false;
        for (fileName in resolved.autoLoadBanks) {
            if (!providedNames.exists(bankPath(fileName))) return false;
        }
        return true;
    }

    /** How many default banks were loaded from provided bytes. */
    public static function providedBankCount():Int {
        return providedBankLoads;
    }

    static var providedBankLoads:Int = 0;

    static function bankFileName(fileName:String):String {
        var slash = fileName.lastIndexOf("/");
        var back = fileName.lastIndexOf("\\");
        if (back > slash) slash = back;
        return slash >= 0 ? fileName.substr(slash + 1) : fileName;
    }

    // The key a provided name is stored under: the path of its
    // autoLoadBanks entry. Before init the name is kept as given, and
    // init moves it to that key.
    static function bankKey(fileName:String):String {
        if (resolved == null) return fileName;
        var entry = defaultBankEntry(fileName);
        return entry != null ? bankPath(entry) : bankPath(fileName);
    }

    // The autoLoadBanks entry a provided name stands for. A name with a
    // folder matches on the full path, a bare name on the file name.
    // Two entries with one file name in different folders take bare
    // names in order, the ones still open first.
    static function defaultBankEntry(name:String):Null<String> {
        var withFolder = name.indexOf("/") >= 0 || name.indexOf("\\") >= 0;
        var wanted = BankRegistry.normalizePath(bankPath(name));
        var first:Null<String> = null;
        for (entry in resolved.autoLoadBanks) {
            if (withFolder) {
                if (BankRegistry.normalizePath(bankPath(entry)) == wanted) return entry;
                continue;
            }
            if (bankFileName(entry) != name) continue;
            var key = bankPath(entry);
            if (!providedNames.exists(key) && !failedBanks.exists(key)) return entry;
            if (first == null) first = entry;
        }
        return first;
    }

    static function isDefaultBank(key:String):Bool {
        for (entry in resolved.autoLoadBanks) {
            if (bankPath(entry) == key) return true;
        }
        return false;
    }

    static function warnUnexpected(name:String):Void {
        trace('Warning: FMOD - $name was provided but is not in autoLoadBanks (${resolved.autoLoadBanks.join(", ")}). Dropped.');
    }

    // Names reported before init move to the keys of their entries at
    // init. A name that is not a default bank is dropped, bytes and
    // failure alike, with the warning provideBank gives after init.
    static function settleProvidedKeys():Void {
        var bytes = providedBanks;
        var names = providedNames;
        var failed = failedBanks;
        providedBanks = new Map();
        providedNames = new Map();
        failedBanks = new Map();
        for (name in names.keys()) {
            var entry = defaultBankEntry(name);
            if (entry == null) {
                warnUnexpected(name);
                continue;
            }
            var key = bankPath(entry);
            providedNames.set(key, true);
            if (bytes.exists(name)) providedBanks.set(key, bytes.get(name));
        }
        defaultBankFailed = false;
        for (name in failed.keys()) {
            var entry = defaultBankEntry(name);
            if (entry == null) {
                warnUnexpected(name);
                continue;
            }
            failedBanks.set(bankPath(entry), true);
            defaultBankFailed = true;
        }
    }

    /**
     * Loads one default bank from provided bytes and releases them.
     * Returns false when the load failed. A failure is final: the bank
     * is marked failed and never retried.
     */
    static function loadProvidedBank(fileName:String):Bool {
        var name = bankPath(fileName);
        var bytes = providedBanks.get(name);
        providedBanks.remove(name);
        var path = bankPath(fileName);
        if (bytes == null || banks.loadMemory(path, bytes).isNull()) {
            failedBanks.set(name, true);
            providedNames.remove(name);
            defaultBankFailed = true;
            trace('Error: FMOD - default bank $path failed to load from the bytes the preloader provided'
                + ' (${StudioSystem.lastResult()}). The game runs without it.');
            return false;
        }
        providedBankLoads++;
        return true;
    }

    static function defaultBanksReady():Bool {
        if (defaultBanksLoaded) return true;
        #if js
        // First moment the system is ready: start the loads through the
        // registry, so the banks are refcounted and observable exactly
        // like every other bank. A provided bank loads from memory at
        // once. With banksProvided the rest wait for their bytes instead
        // of being fetched.
        if (!defaultLoadsStarted) {
            defaultLoadsStarted = true;
            for (fileName in resolved.autoLoadBanks) {
                var path = bankPath(fileName);
                var name = bankPath(fileName);
                if (failedBanks.exists(name)) continue;
                if (providedBanks.exists(name)) {
                    loadProvidedBank(fileName);
                } else if (!resolved.banksProvided && banks.loadAsync(path).isNull()) {
                    // The shim refused the load, so nothing is in flight
                    failedBanks.set(name, true);
                    defaultBankFailed = true;
                    trace('Error: FMOD - default bank $path could not start loading (${StudioSystem.lastResult()}). The game runs without it.');
                }
            }
        }
        // A bank that failed is settled: initialization completes without
        // it, and initFailed() reports the failure.
        var ready = true;
        for (fileName in resolved.autoLoadBanks) {
            var path = bankPath(fileName);
            var name = bankPath(fileName);
            if (banks.isLoaded(path) || failedBanks.exists(name)) continue;
            if (resolved.banksProvided && !banks.isRegistered(path)) {
                // Waiting for the engine's loader to provide it
                if (providedBanks.exists(name) && loadProvidedBank(fileName)) continue;
                ready = false;
                continue;
            }
            // The registry's own warning stays quiet: the runtime reports
            // a default bank itself
            if (banks.loadingState(path, true) == FmodLoadingState.ERROR) {
                failedBanks.set(name, true);
                defaultBankFailed = true;
                trace('Error: FMOD - default bank failed to load: $path.'
                    + ' The browser fetches it relative to the page, from the bank folder setting.'
                    + ' A refused FMOD initialize fails every load too, and the console names that.'
                    + ' Check the path in the network tab. The game runs without it.');
                continue;
            }
            ready = false;
        }
        if (!ready) return false;
        defaultBanksLoaded = true;
        #end
        return defaultBanksLoaded;
    }

    /**
     * Runs the handler once FMOD is ready: immediately when initialization
     * already completed, otherwise on the first serviced frame after the
     * asynchronous HTML5 init finishes. Values pushed to FMOD before that
     * point land on objects that do not exist yet. Wiring that applies
     * state at setup time replays it through this hook. The optional
     * onFailed runs instead when a default bank failed to load or the
     * system refused (initFailed). Both run once initialization settled
     * (initSettled), at once when it already has and otherwise from
     * update(). A handler with no onFailed runs either way, with or
     * without audio. A game that waits for FMOD on HTML5 calls update()
     * every frame.
     */
    public static function onceReady(handler:Void->Void, ?onFailed:Void->Void):Void {
        // The readiness poll runs first. On HTML5 it is what discovers a
        // failed bank, so the failure check reads a settled state.
        var ready = focusMuteSynced || isInitialized();
        if (ready || systemFailed) {
            if (onFailed != null && initFailed()) onFailed();
            else handler();
            return;
        }
        pendingHandlers.push({ready: handler, failed: onFailed});
    }

    /**
     * True once initialization has run its course. Either the system is
     * up and every default bank is loaded or has failed, or the system
     * refused to initialize. The pending onceReady handlers run then.
     */
    public static function initSettled():Bool {
        return systemFailed || isInitialized();
    }

    // Runs every pending handler once initialization settled. A pair
    // runs its onFailed when a default bank failed, the ready side
    // otherwise. A handler with no onFailed runs either way.
    static function dispatchPending():Void {
        if (pendingHandlers.length == 0) return;
        var pending = pendingHandlers;
        pendingHandlers = [];
        var failed = initFailed();
        for (pair in pending) {
            if (failed && pair.failed != null) pair.failed();
            else pair.ready();
        }
    }

    /** The resolved settings init ran with (null before init). */
    public static function settings():ResolvedFmodSettings {
        return resolved;
    }

    /**
     * Turns the background auto-update thread on or off after init. The
     * resolved setting follows, so update() ticks FMOD itself while the
     * thread is off.
     */
    public static function setAutoUpdate(enabled:Bool):Void {
        if (resolved != null) resolved.autoUpdate = enabled;
        if (isInitialized()) NativeStudio.sys_set_auto_update(enabled);
    }

    /**
     * True when a default bank failed to load or was never provided, or
     * when the system itself refused to initialize. A missing bank
     * leaves the system initialized and running without it, so
     * isInitialized() turns true as well. Check this first. The console
     * names the bank and the reason.
     */
    public static function initFailed():Bool {
        return defaultBankFailed || systemFailed;
    }

    static var debugLevel:Int = -1;

    /**
     * Sets FMOD's log level on the FmodSettings.logLevel scale. On HTML5
     * the call waits for the module, and the 2.03.12 web package then
     * reports it unsupported, since it exports no logger.
     */
    public static function setDebugLevel(level:Int):Void {
        debugLevel = level;
        #if js
        if (NativeStudio.sys_is_initialized()) NativeStudio.sys_set_debug_level(level);
        #else
        NativeStudio.sys_set_debug_level(level);
        #end
    }

    /** The velocity cap attached instances and listeners apply, 0 for none. */
    public static function maxAttachedVelocity():Float {
        return attached.maxVelocity;
    }

    /** True while the background auto-update thread is on. */
    public static function isAutoUpdate():Bool {
        return resolved == null || resolved.autoUpdate;
    }

    /**
     * Services FMOD: drains the callback queue and pushes attached-instance
     * positions. Call once per frame (FmodManager.Update does).
     */
    public static function update():Void {
        // On HTML5 the readiness poll is what discovers a failed bank, so
        // it runs before the pending handlers are dispatched
        var ready = isInitialized();
        if (!ready) {
            // A refused system never gets ready. The handlers run now, so
            // a game gated on them starts without audio.
            if (systemFailed) dispatchPending();
            return;
        }
        if (!focusMuteSynced) {
            // HTML5 initialization completes asynchronously, so the first
            // serviced frame applies state reported during init. Native
            // init applies it directly, so this is a no-op there.
            focusMuteSynced = true;
            applyFocusMute();
            #if js
            // The shim enables auto-update unconditionally when the module
            // becomes ready, so an autoUpdate:false setting is applied here.
            // The debug level set before the module existed lands now too.
            if (resolved != null) NativeStudio.sys_set_auto_update(resolved.autoUpdate);
            if (debugLevel >= 0) NativeStudio.sys_set_debug_level(debugLevel);
            #end
        }
        dispatchPending();
        // A mute FMOD refused (no master group handle yet) is retried here.
        // The call returns at once while the applied state matches.
        applyFocusMute();
        // Manual mode ticks FMOD here on every backend. On HTML5 the shim's
        // timer is the only other caller, and it is off in manual mode.
        if (resolved == null || !resolved.autoUpdate) NativeStudio.sys_update();
        attached.update();
        CallbackDispatcher.update();
    }

    //// Window focus

    /**
     * Tells the runtime whether the game window currently has focus.
     *
     * When it loses focus, the master output is muted (see
     * setMuteWhenUnfocused) so audio does not play to a window nobody is
     * looking at. FMOD keeps mixing, so sounds still play out in real time
     * and end on schedule. They do not pile up and blast out the moment
     * focus returns.
     *
     * Call this from wherever the game observes window focus changes.
     * Idempotent. Games that never lose focus can ignore it entirely.
     */
    public static function setWindowFocused(isFocused:Bool):Void {
        if (focused == isFocused) return;
        focused = isFocused;
        applyFocusMute();
    }

    /** Reports the last focus state passed to setWindowFocused. It is true until the game reports otherwise. */
    public static function isWindowFocused():Bool {
        return focused;
    }

    /**
     * Controls whether the master output is muted while the window is
     * unfocused: true (the default) mutes it, false keeps audio playing in
     * the background. Also settable at init via FmodSettings.muteWhenUnfocused.
     */
    public static function setMuteWhenUnfocused(enabled:Bool):Void {
        muteWhenUnfocused = enabled;
        applyFocusMute();
    }

    /** True when the focus state and the policy call for the master output to be muted. */
    public static function isFocusMuted():Bool {
        return muteWhenUnfocused && !focused;
    }

    /** True when a focus loss mutes the master output. */
    public static function isMuteWhenUnfocused():Bool {
        return muteWhenUnfocused;
    }

    // Applies the focus-driven mute to the core master channel group. That is
    // a separate node from the Studio master bus, so it never clobbers a
    // game's own bus:/ mute or the Flixel volume wiring. The two mutes
    // compose. A no-op until FMOD is initialized, and until the mute state
    // actually changes. A game that never loses focus never allocates the
    // master group handle at all.
    static function applyFocusMute():Void {
        if (!isInitialized()) return;
        var shouldMute = isFocusMuted();
        if (shouldMute == focusMuteApplied) return;
        // A refused mute (no master group handle) is retried on the next
        // change or update, so the flag only follows a mute that landed
        if (ChannelGroup.master().setMute(shouldMute).isOk()) focusMuteApplied = shouldMute;
    }

    /**
     * Resolves a bank file name against the configured bank folder. Before
     * init, pass the folder the settings name, or the default applies.
     * A name that already holds a slash or a backslash is a path and comes back as is.
     */
    public static function bankPath(fileName:String, ?folder:String):String {
        if (folder == null) folder = resolved != null ? resolved.bankFolder : "assets/fmod/Desktop";
        // Already a path, with either separator
        if (fileName.indexOf("/") >= 0 || fileName.indexOf("\\") >= 0) return fileName;
        return '$folder/$fileName';
    }

    /** Creates an instance of an event. EventInstance.NULL on failure. */
    public static function createInstance(eventPath:String):EventInstance {
        var description:EventDescription = StudioSystem.getEvent(eventPath);
        if (description.isNull()) return EventInstance.NULL;
        return description.createInstance();
    }

    /** Fire-and-forget playback, optionally positioned in 2D space. Returns false when FMOD cannot create the event. */
    public static function playOneShot(eventPath:String, ?x:Float, ?y:Float):Bool {
        var instance = createInstance(eventPath);
        if (instance.isNull()) return false;
        if (x != null && y != null) instance.setPosition2D(x, y);
        instance.start();
        instance.release();
        return true;
    }

    /**
     * Fire-and-forget playback that follows a moving object until the event
     * ends, then releases itself. Intended for one-shot (self-ending)
     * events. A looping event played this way never stops on its own, so it
     * never releases. Use attach/detach with an instance you own instead.
     * Returns false when FMOD cannot create the event.
     */
    public static function playOneShotAttached(eventPath:String, provider:IFmodPositionProvider):Bool {
        var instance = createInstance(eventPath);
        if (instance.isNull()) return false;
        // release() cannot happen up front like playOneShot: it invalidates
        // the handle immediately, which would end the position updates. The
        // attach loop releases once the event reports STOPPED instead (a
        // callback registration would not survive ClearAllCallbacks).
        attached.attach(instance, provider, true);
        instance.start();
        return true;
    }

    /** Keeps an instance's 3D position synced to a moving object every update. */
    public static function attach(instance:EventInstance, provider:IFmodPositionProvider):Void {
        attached.attach(instance, provider);
    }

    /** Stops an instance from following its position provider. The instance keeps playing where it is. */
    public static function detach(instance:EventInstance):Void {
        attached.detach(instance);
    }

    /** The number of instances that follow a position provider. */
    public static function attachedCount():Int {
        return attached.count();
    }

    /** True while an attached instance still follows this provider. */
    public static function isAttachedProvider(provider:IFmodPositionProvider):Bool {
        return attached.hasProvider(provider);
    }

    /** Positions a listener in 2D space (index 0 unless using multiple listeners). */
    public static function setListenerPosition(index:Int, x:Float, y:Float):FmodResult {
        return StudioSystem.setListenerPosition2D(index, x, y);
    }

    /** Pauses or unpauses everything routed through the master bus. */
    public static function pauseAll(paused:Bool):FmodResult {
        return StudioSystem.getBus("bus:/").setPaused(paused);
    }

    /** Mutes or unmutes the master bus. */
    public static function muteAll(muted:Bool):FmodResult {
        return StudioSystem.getBus("bus:/").setMute(muted);
    }

    static function loadDefaultBanks():Void {
        if (resolved == null) return;
        for (fileName in resolved.autoLoadBanks) {
            var name = bankPath(fileName);
            if (failedBanks.exists(name)) {
                // The preloader reported it already
            } else if (providedBanks.exists(name)) {
                loadProvidedBank(fileName);
            } else if (resolved.banksProvided) {
                // Native init cannot wait: a bank the preloader did not
                // hand over before init is a failure
                provideBankFailed(fileName, "the settings say the preloader provides the banks, but it was not provided before init");
            } else if (banks.load(bankPath(fileName)).isNull()) {
                failedBanks.set(name, true);
                defaultBankFailed = true;
                trace('Error: FMOD - default bank failed to load: ${bankPath(fileName)} (${StudioSystem.lastResult()}). Check the file and the bank folder setting. The game runs without it.');
            }
        }
    }
}
