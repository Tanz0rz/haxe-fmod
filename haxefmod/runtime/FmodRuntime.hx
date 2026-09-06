package haxefmod.runtime;

import haxefmod.core.ChannelGroup;
import haxefmod.runtime.FmodSettings;
import haxefmod.studio.CallbackDispatcher;
import haxefmod.studio.Callbacks;
import haxefmod.studio.EventDescription;
import haxefmod.studio.EventInstance;
import haxefmod.studio.FmodResult;
import haxefmod.studio.Types;
import haxefmod.studio.StudioSystem;
import haxefmod.studio.native.NativeStudio;

/**
 * The engine-agnostic FMOD runtime: settings-driven init, bank management,
 * 3D attachment, and per-frame servicing. FmodManager builds its
 * helper class on top of this. Games that want more control use it directly:
 *
 *   FmodRuntime.init({liveUpdate: true});
 *   var jump = FmodRuntime.createInstance("event:/SFX/Jump");
 *
 * Everything here is static - there is exactly one FMOD system per
 * process, created on the first init and alive until the process exits.
 * There is deliberately no shutdown or re-init call: a teardown path
 * would trade a capability games do not use for a whole class of
 * use-after-shutdown bugs, and FMOD releases everything at exit.
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
    // The focus mute we last pushed to the master group, so applyFocusMute
    // only touches (and lazily allocates) the master channel group when the
    // state actually changes - not on every focused startup.
    static var focusMuteApplied:Bool = false;
    static var focusMuteSynced:Bool = false;
    static var readyHandlers:Array<Void->Void> = [];

    /** Expected native binding ABI - lockstep with the manifest "# abi-version:". */
    public static inline var BINDING_ABI:Int = 11;

    /**
     * Initializes FMOD with the given settings (see FmodSettings for the
     * define-driven defaults). First initialization wins: settings passed
     * to any later init call are ignored. On html5 initialization is
     * asynchronous: poll isInitialized(), or just call update() every
     * frame and start playing sounds once it reports true.
     */
    public static function init(?settings:FmodSettings):FmodResult {
        if (initStarted) return FmodResult.FMOD_OK;
        initStarted = true;
        resolved = FmodSettingsResolver.resolve(settings);
        muteWhenUnfocused = resolved.muteWhenUnfocused;
        attached.maxVelocity = resolved.maxAttachedVelocity;

        #if hl
        // A stale hdll usually dies at load with a missing-prim fatal (and
        // PostBuild refuses it even earlier), but lazy prim resolution can
        // let a mismatched hdll limp along - fail here instead.
        if (NativeStudio.binding_abi_version() != BINDING_ABI) {
            trace("Error: FMOD - hlaxe_fmod.hdll binding version "
                + NativeStudio.binding_abi_version() + " does not match this haxefmod ("
                + BINDING_ABI + "). Run: haxelib run haxefmod build-hdll");
            return FmodResult.FMOD_ERR_VERSION;
        }
        #end

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
                return formatResult;
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
        if (!result.isOk()) return result;
        loadDefaultBanks();
        NativeStudio.sys_set_auto_update(resolved.autoUpdate);
        // Honor a focus loss that was reported before init completed.
        applyFocusMute();
        #end
        #if !js
        // Native init loaded the default banks synchronously above (the
        // stub backend has none to load)
        defaultBanksLoaded = true;
        #end
        // html5: init completes asynchronously. The default banks load
        // through the registry once the system is ready, and
        // isInitialized() reports true only when they are usable.
        return result;
    }

    /**
     * True once FMOD is usable: the system is initialized AND the
     * settings' autoLoadBanks are loaded. Native init does both
     * synchronously. On html5 both are asynchronous, so games gate their
     * first state on this.
     */
    public static function isInitialized():Bool {
        if (!NativeStudio.sys_is_initialized()) return false;
        // Direct NativeStudio users never went through init: no settings,
        // nothing to wait for
        if (resolved == null) return true;
        return defaultBanksReady();
    }

    static var defaultBanksLoaded:Bool = false;
    #if js
    static var defaultBankPaths:Array<String> = null;
    static var defaultBankErrorLogged:Bool = false;
    #end

    static function defaultBanksReady():Bool {
        if (defaultBanksLoaded) return true;
        #if js
        // First moment the system is ready: start the async loads through
        // the registry, so the banks are refcounted and observable exactly
        // like every other bank
        if (defaultBankPaths == null) {
            defaultBankPaths = [for (fileName in resolved.autoLoadBanks) bankPath(fileName)];
            for (path in defaultBankPaths) banks.loadAsync(path);
        }
        for (path in defaultBankPaths) {
            if (banks.isLoaded(path)) continue;
            if (banks.loadingState(path) == FmodLoadingState.ERROR && !defaultBankErrorLogged) {
                defaultBankErrorLogged = true;
                trace('Warn: FMOD - default bank failed to load: $path'
                    + ' (check the file is deployed next to the game).'
                    + ' Initialization cannot complete without it.');
            }
            return false;
        }
        defaultBanksLoaded = true;
        #end
        return defaultBanksLoaded;
    }

    /**
     * Runs the handler once FMOD is ready: immediately when initialization
     * already completed, otherwise on the first serviced frame after the
     * asynchronous html5 init finishes. Values pushed to FMOD before that
     * point land on objects that do not exist yet, so wiring that applies
     * state at setup time replays it through this hook.
     */
    public static function onceReady(handler:Void->Void):Void {
        if (focusMuteSynced || isInitialized()) {
            handler();
            return;
        }
        readyHandlers.push(handler);
    }

    /** The resolved settings init ran with (null before init). */
    public static function settings():ResolvedFmodSettings {
        return resolved;
    }

    /**
     * Services FMOD: drains the callback queue and pushes attached-instance
     * positions. Call once per frame (FmodManager.Update does).
     */
    public static function update():Void {
        if (!isInitialized()) return;
        if (!focusMuteSynced) {
            // html5 initialization completes asynchronously, so state
            // reported during init is applied on the first serviced frame
            // (native init applies it directly, so this is a no-op there)
            focusMuteSynced = true;
            applyFocusMute();
            #if js
            // The shim enables auto-update unconditionally when the module
            // becomes ready, so an autoUpdate:false setting is applied here
            if (resolved != null) NativeStudio.sys_set_auto_update(resolved.autoUpdate);
            #end
            var pending = readyHandlers;
            readyHandlers = [];
            for (handler in pending) handler();
        }
        #if (cpp || hl)
        if (resolved == null || !resolved.autoUpdate) NativeStudio.sys_update();
        #end
        attached.update();
        CallbackDispatcher.update();
    }

    //// Window focus

    /**
     * Tells the runtime whether the game window currently has focus.
     *
     * When it loses focus, the master output is muted (see
     * setMuteWhenUnfocused) so audio doesn't play to a window nobody is
     * looking at. FMOD keeps mixing, so sounds still play out in real time
     * and end on schedule instead of piling up and blasting out the moment
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

    /** True when the master output is currently muted because of lost focus. */
    public static function isFocusMuted():Bool {
        return muteWhenUnfocused && !focused;
    }

    // Applies the focus-driven mute to the core master channel group. That is
    // a separate node from the Studio master bus, so it never clobbers a
    // game's own bus:/ mute (or the Flixel volume wiring) - the two mutes
    // compose. A no-op until FMOD is initialized, and until the mute state
    // actually changes - so a game that never loses focus never allocates the
    // master group handle at all.
    static function applyFocusMute():Void {
        if (!isInitialized()) return;
        var shouldMute = isFocusMuted();
        if (shouldMute == focusMuteApplied) return;
        ChannelGroup.master().setMute(shouldMute);
        focusMuteApplied = shouldMute;
    }

    /** Resolves a bank file name against the configured bank folder. */
    public static function bankPath(fileName:String):String {
        var folder = resolved != null ? resolved.bankFolder : "assets/fmod/Desktop";
        if (fileName.indexOf("/") >= 0) return fileName; // already a path
        return '$folder/$fileName';
    }

    /** Creates an instance of an event. EventInstance.NULL on failure. */
    public static function createInstance(eventPath:String):EventInstance {
        var description:EventDescription = StudioSystem.getEvent(eventPath);
        if (description.isNull()) return EventInstance.NULL;
        return description.createInstance();
    }

    /** Fire-and-forget playback, optionally positioned in 2D space. */
    public static function playOneShot(eventPath:String, ?x:Float, ?y:Float):Void {
        var instance = createInstance(eventPath);
        if (instance.isNull()) return;
        if (x != null && y != null) instance.setPosition2D(x, y);
        instance.start();
        instance.release();
    }

    /**
     * Fire-and-forget playback that follows a moving object until the event
     * ends, then releases itself. Intended for one-shot (self-ending)
     * events: a looping event played this way never stops on its own, so it
     * never releases - use attach/detach with an instance you own instead.
     */
    public static function playOneShotAttached(eventPath:String, provider:IFmodPositionProvider):Void {
        var instance = createInstance(eventPath);
        if (instance.isNull()) return;
        // release() cannot happen up front like playOneShot: it invalidates
        // the handle immediately, which would end the position updates. The
        // attach loop releases once the event reports STOPPED instead (a
        // callback registration would not survive ClearAllCallbacks).
        attached.attach(instance, provider, true);
        instance.start();
    }

    /** Keeps an instance's 3D position synced to a moving object every update. */
    public static function attach(instance:EventInstance, provider:IFmodPositionProvider):Void {
        attached.attach(instance, provider);
    }

    public static function detach(instance:EventInstance):Void {
        attached.detach(instance);
    }

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
            banks.load(bankPath(fileName));
        }
    }
}
