package haxefmod.runtime;

import haxefmod.core.ChannelGroup;
import haxefmod.runtime.FmodSettings;
import haxefmod.studio.CallbackDispatcher;
import haxefmod.studio.Callbacks;
import haxefmod.studio.EventDescription;
import haxefmod.studio.EventInstance;
import haxefmod.studio.FmodResult;
import haxefmod.studio.StudioSystem;
import haxefmod.studio.native.NativeStudio;

/**
 * The engine-agnostic FMOD runtime: settings-driven init, bank management,
 * 3D attachment, and per-frame servicing. FmodManager builds its
 * facade on top of this. games that want more control use it directly:
 *
 *   FmodRuntime.init({liveUpdate: true});
 *   var jump = FmodRuntime.createInstance("event:/SFX/Jump");
 *
 * Everything here is static - there is exactly one FMOD system per process.
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

    /** Expected native binding ABI - lockstep with the manifest "# abi-version:". */
    public static inline var BINDING_ABI:Int = 8;

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

        NativeStudio.sys_set_debug_level(resolved.logLevel);
        var result:FmodResult = NativeStudio.sys_init_ex(
            resolved.numChannels, resolved.sampleRate, resolved.speakerMode,
            resolved.liveUpdate ? 1 : 0);

        #if (cpp || hl)
        if (!result.isOk()) return result;
        loadDefaultBanks();
        NativeStudio.sys_set_auto_update(resolved.autoUpdate);
        // Honor a focus loss that was reported before init completed.
        applyFocusMute();
        #end
        // html5: init completes asynchronously. The shim loads the default
        // banks and enables auto-update itself once the module is ready.
        return result;
    }

    public static function isInitialized():Bool {
        return NativeStudio.sys_is_initialized();
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
            // html5 initialization completes asynchronously, so a focus
            // loss reported during init is applied on the first serviced
            // frame (native init applies it directly, this is a no-op there)
            focusMuteSynced = true;
            applyFocusMute();
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
