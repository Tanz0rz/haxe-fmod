package haxefmod;

import haxefmod.studio.Bus;
import haxefmod.studio.CallbackDispatcher;
import haxefmod.studio.EventDescription;
import haxefmod.runtime.FmodRuntime;
import haxefmod.runtime.FmodSettings;
import haxefmod.studio.Callbacks;
import haxefmod.studio.EventInstance;
import haxefmod.studio.StudioSystem;
import haxefmod.studio.Types;
import haxefmod.studio.Vca;
import haxefmod.studio.native.NativeStudio;

/**
 * The helper class for FMOD. It owns six areas. They are lifecycle (init, update, and banks), one background song slot, events, the mixer (buses, VCAs, and snapshots), global parameters, and game policy.
 * Every call takes an FMOD Studio path or name and holds no handle. The song slot is the one piece of state.
 * PlayEvent and CreateEvent return an FmodEvent, the one handle with a lifetime. GetBus, GetVCA, and GetEventDescription return FMOD's own objects, which need no release, for everything beyond the path calls.
 * World space and focus reporting live in haxefmod.runtime.FmodRuntime. Every FMOD object is one lookup away in haxefmod.studio.
 *
 * Call FmodManager.Update() every frame, or let the engine setup call do it.
 */
class FmodManager {
    // Single music slot
    static var songInstance:EventInstance = EventInstance.NULL;
    static var CurrentSong:String = "";
    static var NextSong:String;

    static var debug:Bool = false;
    static var initialized:Bool = false;

    //// Lifecycle

    /**
     * Initializes FMOD. The optional settings control channels, Live Update, the bank folder, the auto-loaded banks, and more.
     * See FmodSettings. Every other FmodManager call initializes with defaults on first use.
     * The first initialization wins. Settings passed to a later call are ignored.
     */
    public static function Initialize(?settings:FmodSettings):Void {
        if (initialized) {
            if (settings != null) log("Initialize: already initialized, settings ignored");
            return;
        }
        initialized = true;
        var result = FmodRuntime.init(settings);
        if (!result.isOk()) trace('Warn: FMOD - Initialize failed ($result). Audio calls are no-ops until the cause is fixed');
        #if debug
        EnableDebugMessages();
        #end
        log("Initialized");
    }

    /** Turns on FMOD debug logging at its most verbose level and traces every FmodManager operation. Debug builds enable it automatically. */
    public static function EnableDebugMessages():Void {
        debug = true;
        FmodRuntime.setDebugLevel(3); // 3 = log everything (the FmodSettings.logLevel scale)
    }

    /**
     * Reports true once FMOD and the default banks are usable. Native targets are ready immediately.
     * HTML5 initializes asynchronously, so poll this before the first scene.
     */
    public static function IsInitialized():Bool {
        ensureInitialized();
        return FmodRuntime.isInitialized();
    }

    /** Services FMOD. It delivers callbacks, updates attached instances, and drives song transitions. Call it once per frame. */
    public static function Update():Void {
        ensureInitialized();
        FmodRuntime.update();
    }

    /**
     * Turns the background auto-update on or off. It is on by default and keeps audio running when the game loop stalls.
     * Typed callbacks still arrive only from Update().
     */
    public static function SetAutoUpdate(enabled:Bool):Void {
        ensureInitialized();
        FmodRuntime.setAutoUpdate(enabled);
    }

    /**
     * True when a default bank failed to load or was never provided, or
     * when the system refused to initialize. A missing bank leaves the
     * system running without it, so IsInitialized() turns true too. The
     * engine preloaders check this first and report it.
     */
    public static function InitializeFailed():Bool {
        ensureInitialized();
        return FmodRuntime.initFailed();
    }

    /**
     * True once initialization has run its course: FMOD is up and every
     * default bank is loaded or has failed, or FMOD refused to
     * initialize. A loading scene starts the game on this.
     */
    public static function InitializeSettled():Bool {
        ensureInitialized();
        return FmodRuntime.initSettled();
    }

    /** True while the background auto-update is on. */
    public static function IsAutoUpdate():Bool {
        return FmodRuntime.isAutoUpdate();
    }

    //// Lifecycle: banks

    /**
     * Loads a bank, or adds a reference to one that is loaded. The name is a file name resolved against the bank folder setting, for example "Level1.bank", or a full path.
     * Native targets load synchronously. HTML5 loads asynchronously, so poll IsBankLoaded before the first event from the bank.
     * Every LoadBank needs one UnloadBank. Initialize loads the banks named in the autoLoadBanks setting, Master and Master.strings by default.
     */
    public static function LoadBank(bankName:String):Void {
        ensureInitialized();
        if (FmodRuntime.banks.load(FmodRuntime.bankPath(bankName)).isNull()) {
            warn('LoadBank could not load "$bankName". Check the file name and the bank folder setting');
        }
    }

    /** Releases one reference to a bank. The bank unloads when its last reference goes, and its events stop. */
    public static function UnloadBank(bankName:String):Void {
        ensureInitialized();
        FmodRuntime.banks.unload(FmodRuntime.bankPath(bankName));
    }

    /** Returns true once a bank is loaded and its events are usable. */
    public static function IsBankLoaded(bankName:String):Bool {
        ensureInitialized();
        return FmodRuntime.banks.isLoaded(FmodRuntime.bankPath(bankName));
    }

    /** True when a bank load ended in error, for example a file that is missing. HTML5 reports the error after the fetch settles. */
    public static function AnyBankFailed():Bool {
        ensureInitialized();
        return FmodRuntime.banks.anyError();
    }

    /** Returns true while any bank loaded through this class or FmodRuntime is still loading. */
    public static function IsAnyBankLoading():Bool {
        ensureInitialized();
        return FmodRuntime.banks.anyLoading();
    }

    /**
     * Blocks until every pending bank and sample load has completed.
     * HTML5 cannot block, so the call returns at once there. Poll IsAnyBankLoading or IsBankLoaded from Update instead.
     */
    public static function WaitForBanks():Void {
        ensureInitialized();
        StudioSystem.flushSampleLoading();
    }

    //// Game policy: window focus

    /**
     * Chooses whether the master output is muted while the window is unfocused. True, the default, mutes it. False keeps audio playing in the background.
     * The engine setup calls report focus changes through FmodRuntime.setWindowFocused. A game without one reports them there itself.
     */
    public static function SetMuteWhenUnfocused(enabled:Bool):Void {
        ensureInitialized();
        FmodRuntime.setMuteWhenUnfocused(enabled);
    }

    /** True when the master output mutes while the window is unfocused. */
    public static function IsMuteWhenUnfocused():Bool {
        return FmodRuntime.isMuteWhenUnfocused();
    }

    //// Mixer: the whole mix

    /** Stops every event routed through the master bus immediately, the song included. */
    public static function StopAllEvents():Void {
        ensureInitialized();
        StudioSystem.getBus("bus:/").stopAllEvents(IMMEDIATE);
    }

    /**
     * Pauses the master bus and freezes every event at its position. Call UnpauseAllEvents to resume.
     * This suits a full pause menu. Events started while paused queue up and play on unpause.
     */
    public static function PauseAllEvents():Void {
        ensureInitialized();
        FmodRuntime.pauseAll(true);
    }

    /** Resumes the master bus paused by PauseAllEvents. */
    public static function UnpauseAllEvents():Void {
        ensureInitialized();
        FmodRuntime.pauseAll(false);
    }

    //// Mixer: buses

    /**
     * Sets the volume of a bus. The path comes from FMOD Studio, for example "bus:/SFX".
     * Volume runs from 0.0, silent, to 1.0, full.
     */
    public static function SetBusVolume(busPath:String, volume:Float):Void {
        ensureInitialized();
        StudioSystem.getBus(busPath).setVolume(volume);
    }

    /** Returns the volume of a bus, from 0.0 to 1.0. */
    public static function GetBusVolume(busPath:String):Float {
        ensureInitialized();
        return StudioSystem.getBus(busPath).getVolume();
    }

    /** Mutes or unmutes a bus. The volume survives a mute and unmute round trip. */
    public static function SetBusMute(busPath:String, mute:Bool):Void {
        ensureInitialized();
        StudioSystem.getBus(busPath).setMute(mute);
    }

    /** Returns true when the bus is muted. */
    public static function IsBusMuted(busPath:String):Bool {
        ensureInitialized();
        return StudioSystem.getBus(busPath).getMute();
    }

    /**
     * Pauses or resumes one bus. Every event routed through it freezes at its position and resumes from there.
     * A pause menu pauses "bus:/SFX" and keeps the music bus running. PauseAllEvents pauses the master bus instead.
     */
    public static function SetBusPaused(busPath:String, paused:Bool):Void {
        ensureInitialized();
        StudioSystem.getBus(busPath).setPaused(paused);
    }

    /** Returns true when the bus is paused. */
    public static function IsBusPaused(busPath:String):Bool {
        ensureInitialized();
        return StudioSystem.getBus(busPath).getPaused();
    }

    /** Sets the volume of the master bus, "bus:/", from 0.0 to 1.0. */
    public static function SetMasterVolume(volume:Float):Void {
        SetBusVolume("bus:/", volume);
    }

    /** Returns the volume of the master bus, from 0.0 to 1.0. */
    public static function GetMasterVolume():Float {
        return GetBusVolume("bus:/");
    }

    /** Mutes or unmutes the master bus. */
    public static function SetMasterMute(mute:Bool):Void {
        ensureInitialized();
        FmodRuntime.muteAll(mute);
    }

    /** Returns true when the master bus is muted. */
    public static function IsMasterMuted():Bool {
        return IsBusMuted("bus:/");
    }

    //// Mixer: VCAs

    /**
     * Sets the volume of a VCA. The path comes from FMOD Studio, for example "vca:/Music".
     * Volume runs from 0.0, silent, to 1.0, full. A VCA scales every bus assigned to it.
     */
    public static function SetVCAVolume(vcaPath:String, volume:Float):Void {
        ensureInitialized();
        StudioSystem.getVCA(vcaPath).setVolume(volume);
    }

    /** Returns the volume of a VCA, from 0.0 to 1.0. */
    public static function GetVCAVolume(vcaPath:String):Float {
        ensureInitialized();
        return StudioSystem.getVCA(vcaPath).getVolume();
    }

    //// Mixer: bus and VCA objects

    /**
     * Returns the bus at a path, for everything the bus calls above do not cover. Examples are the final volume after VCAs and snapshots, the channel group under the bus, and profiling.
     * The object belongs to FMOD and needs no release. A bad path returns Bus.NULL, and every call on it is a safe no-op.
     */
    public static function GetBus(busPath:String):Bus {
        ensureInitialized();
        return StudioSystem.getBus(busPath);
    }

    /** Returns the VCA at a path. The object belongs to FMOD and needs no release. A bad path returns Vca.NULL. */
    public static function GetVCA(vcaPath:String):Vca {
        ensureInitialized();
        return StudioSystem.getVCA(vcaPath);
    }

    //// Mixer: snapshots

    /**
     * Applies a snapshot until StopSnapshot. The path comes from FMOD Studio, for example "snapshot:/Paused".
     * A snapshot is a mixer state the sound designer authored. FMOD blends the mixer toward it and back.
     * A snapshot that is already applied is left as it is. FMOD keeps the instance alive while it plays, so no handle is held here.
     */
    public static function StartSnapshot(snapshotPath:String):Void {
        ensureInitialized();
        var description = StudioSystem.getEvent(snapshotPath);
        if (description.isNull()) {
            warnMissing("StartSnapshot", snapshotPath);
            return;
        }
        // A running instance keeps the snapshot applied. One that is
        // fading out after StopSnapshot restarts in place instead of
        // ending while a second instance begins.
        var instances = description.getInstanceList();
        if (instances.length > 0) {
            for (existing in instances) {
                if (existing.getPlaybackState() == FmodPlaybackState.STOPPING) existing.start();
            }
            return;
        }
        var instance = description.createInstance();
        if (instance.isNull()) {
            warnMissing("StartSnapshot", snapshotPath);
            return;
        }
        instance.start();
        instance.release();
    }

    /** Removes a snapshot with its authored fade. It does nothing when the snapshot is not applied. */
    public static function StopSnapshot(snapshotPath:String):Void {
        ensureInitialized();
        var description = StudioSystem.getEvent(snapshotPath);
        if (description.isNull()) return;
        // The instances were released at start, so FMOD destroys each one
        // when its fade completes.
        for (instance in description.getInstanceList()) instance.stop(ALLOWFADEOUT);
    }

    /** Removes a snapshot immediately, without its authored fade. */
    public static function StopSnapshotImmediately(snapshotPath:String):Void {
        ensureInitialized();
        var description = StudioSystem.getEvent(snapshotPath);
        if (description.isNull()) return;
        // FMOD's own stop-and-release of every instance. On HTML5 this is
        // also the sweep that reclaims the dead instances' handle slots.
        description.releaseAllInstances();
    }

    /** Returns true while a snapshot is applied. It stays true through the fade out of StopSnapshot. */
    public static function IsSnapshotActive(snapshotPath:String):Bool {
        ensureInitialized();
        return StudioSystem.getEvent(snapshotPath).getInstanceCount() > 0;
    }

    //// Global parameters

    /**
     * Sets a global parameter. Global parameters are shared by every event in the project.
     * The name comes from FMOD Studio, for example "Intensity". The generated FmodParameters constants, which hold "parameter:/" paths, are accepted too.
     * A parameter on one event instance is set through the FmodEvent returned by PlayEvent, or through SetSongParameter for the song.
     */
    public static function SetGlobalParameter(parameterName:String, parameterValue:Float):Void {
        ensureInitialized();
        StudioSystem.setParameter(globalParameterName(parameterName), parameterValue);
    }

    /** Returns the value of a global parameter. It is 0 for a name FMOD does not know. */
    public static function GetGlobalParameter(parameterName:String):Float {
        ensureInitialized();
        return StudioSystem.getParameter(globalParameterName(parameterName));
    }

    /**
     * Sets a labeled global parameter by its label text, for example "Weather" to "Rain".
     * The labels are the ones authored in FMOD Studio. The name takes the same forms as SetGlobalParameter.
     */
    public static function SetGlobalParameterWithLabel(parameterName:String, label:String):Void {
        ensureInitialized();
        StudioSystem.setParameterWithLabel(globalParameterName(parameterName), label);
    }

    //// Song slot

    /**
     * Plays a song and replaces the current song immediately with no fade.
     * A second call with the current song does nothing. If that song stopped or is fading out, the call restarts it.
     * A missing event logs a warning and leaves the slot empty.
     */
    public static function PlaySong(songPath:String):Void {
        ensureInitialized();
        // A direct play supersedes any pending transition.
        NextSong = null;

        if (songPath == CurrentSong && !songInstance.isNull()) {
            if (needsRestart(songInstance)) {
                songInstance.start();
            }
            return;
        }

        // Replace the current song: hard stop and release the old instance.
        if (!songInstance.isNull()) {
            songInstance.stop(IMMEDIATE);
            songInstance.release();
            songInstance = EventInstance.NULL;
            CurrentSong = "";
        }

        log('PlaySong $songPath');
        var instance = FmodRuntime.createInstance(songPath);
        if (instance.isNull()) {
            warnMissing("PlaySong", songPath);
            return;
        }
        instance.start();
        songInstance = instance;
        CurrentSong = songPath;
    }

    /**
     * Fades the current song out as authored, then plays the new one when the fade completes. It needs Update() every frame.
     * The song has one callback slot and the transition holds it until the fade completes.
     * OnSongEvent during the fade cancels the transition. A second transition during the fade cuts to the newest song.
     */
    public static function PlaySongTransition(songPath:String):Void {
        ensureInitialized();
        // Asking for a song supersedes any transition already pending,
        // including asking for the current song again while an earlier
        // transition's fade is still armed.
        NextSong = null;

        if (songPath == CurrentSong && !songInstance.isNull()) {
            if (needsRestart(songInstance)) {
                songInstance.start();
            }
            return;
        }

        // Nothing to fade out - just play it.
        if (songInstance.isNull() || !isInstancePlaying(songInstance)) {
            PlaySong(songPath);
            return;
        }

        log('PlaySongTransition $songPath');
        NextSong = songPath;
        // The handler arms before the stop. A song already fading could
        // otherwise deliver its Stopped in the gap and never hand off.
        // The background update thread processes stops between any two
        // calls here.
        songInstance.setCallback(data -> {
            switch (data) {
                case Stopped:
                    // StopSong since the transition was armed clears
                    // NextSong, and the completed fade must stay silent.
                    if (NextSong != null) {
                        var next = NextSong;
                        NextSong = null;
                        PlaySong(next);
                    }
                default:
            }
        }, EventCallbackType.STOPPED);
        songInstance.stop(ALLOWFADEOUT);
        // The fade can also complete before the handler was installed. No
        // Stopped arrives for it, so hand off directly. NextSong is cleared
        // first, which keeps a queued Stopped a no-op.
        if (NextSong != null
            && songInstance.getPlaybackState() == FmodPlaybackState.STOPPED) {
            var next = NextSong;
            NextSong = null;
            PlaySong(next);
        }
    }

    /** Fades the song out as authored and cancels any pending transition. */
    public static function StopSong():Void {
        ensureInitialized();
        NextSong = null;
        if (!songInstance.isNull()) songInstance.stop(ALLOWFADEOUT);
    }

    /** Stops the song with no fade and cancels any pending transition. */
    public static function StopSongImmediately():Void {
        ensureInitialized();
        NextSong = null;
        if (!songInstance.isNull()) songInstance.stop(IMMEDIATE);
    }

    /** Freezes the song at its position. */
    public static function PauseSong():Void {
        ensureInitialized();
        if (!songInstance.isNull()) {
            songInstance.setPaused(true);
            // Push the pause through FMOD immediately, independent of the
            // game loop. The auto-update thread already ticks within ~16ms,
            // so only manual-update setups need the push.
            if (!FmodRuntime.isAutoUpdate()) NativeStudio.sys_update();
        }
    }

    /** Resumes a song paused by PauseSong. */
    public static function UnpauseSong():Void {
        ensureInitialized();
        if (!songInstance.isNull()) songInstance.setPaused(false);
    }

    /** Returns true while the song is starting, playing, sustaining, or fading out. Only a fully stopped song returns false. */
    public static function IsSongPlaying():Bool {
        ensureInitialized();
        return !songInstance.isNull() && isInstancePlaying(songInstance);
    }

    /** Returns the path of the song PlaySong last started. It is empty before the first song and after a failed PlaySong. */
    public static function GetCurrentSongPath():String {
        return CurrentSong;
    }

    /** Returns the timeline position of the song in milliseconds. It is 0 with no song. */
    public static function GetSongTimelinePosition():Int {
        ensureInitialized();
        return songInstance.isNull() ? 0 : songInstance.getTimelinePosition();
    }

    /** Moves the song to a timeline position in milliseconds. It does nothing with no song. */
    public static function SetSongTimelinePosition(positionMs:Int):Void {
        ensureInitialized();
        if (!songInstance.isNull()) songInstance.setTimelinePosition(positionMs);
    }

    /** Returns the value of a parameter on the song. It is 0 with no song. */
    public static function GetSongParameter(parameterName:String):Float {
        ensureInitialized();
        return songInstance.isNull() ? 0.0 : songInstance.getParameter(parameterName);
    }

    /** Sets a parameter on the song. It does nothing with no song. */
    public static function SetSongParameter(parameterName:String, parameterValue:Float):Void {
        ensureInitialized();
        if (!songInstance.isNull()) songInstance.setParameter(parameterName, parameterValue);
    }

    /** Sets a labeled parameter on the song by its label text, for example "Section" to "Chorus". It does nothing with no song. */
    public static function SetSongParameterWithLabel(parameterName:String, label:String):Void {
        ensureInitialized();
        if (!songInstance.isNull()) songInstance.setParameterWithLabel(parameterName, label);
    }

    /**
     * Registers a typed callback on the song. Beats, markers, and lifecycle events arrive from Update() as EventCallbackData values.
     * The optional mask limits the delivered EventCallbackType bits.
     * A new registration replaces the previous handler. That includes the handler a pending PlaySongTransition uses, so the transition is cancelled.
     */
    public static function OnSongEvent(handler:EventCallbackData->Void, ?mask:Int):Void {
        ensureInitialized();
        if (!songInstance.isNull()) songInstance.setCallback(handler, mask);
    }

    /**
     * Registers a song callback that fires for the first delivered event and then removes itself.
     * The mask picks which events qualify. It replaces any previous song handler, like OnSongEvent.
     */
    public static function OnceSongEvent(handler:EventCallbackData->Void, ?mask:Int):Void {
        ensureInitialized();
        if (songInstance.isNull()) return;
        var instance = songInstance;
        instance.setCallback(data -> {
            // The dispatcher force-subscribes DESTROYED for cleanup. It only
            // consumes the single shot when the caller asked for it, but
            // either way the instance is gone and the registration ends.
            var unwanted = switch (data) {
                case Destroyed: mask != null && (mask & EventCallbackType.DESTROYED) == 0;
                default: false;
            }
            // setCallback(null) drops the handler and shrinks the native
            // mask, so a beat-heavy song stops filling the queue.
            instance.setCallback(null);
            if (!unwanted) handler(data);
        }, mask);
    }

    //// Events

    /** Starts an event and releases it straight away. FMOD destroys it when it finishes. */
    public static function PlayOneShot(eventPath:String):Void {
        ensureInitialized();
        log('PlayOneShot $eventPath');
        if (!FmodRuntime.playOneShot(eventPath)) warnMissing("PlayOneShot", eventPath);
    }

    /** Starts a one-shot event at a 2D position relative to listener 0. */
    public static function PlayOneShotAt(eventPath:String, x:Float, y:Float):Void {
        ensureInitialized();
        log('PlayOneShotAt $eventPath');
        if (!FmodRuntime.playOneShot(eventPath, x, y)) warnMissing("PlayOneShotAt", eventPath);
    }

    /**
     * Starts a one-shot event that follows a moving object until the event ends.
     * Use it for self-ending events only. A looping event never ends, so it never releases.
     * Flixel games can pass a FlxObject through FmodFlxUtilities.PlayOneShotAttached.
     */
    public static function PlayOneShotAttached(eventPath:String, provider:haxefmod.runtime.IFmodPositionProvider):Void {
        ensureInitialized();
        log('PlayOneShotAttached $eventPath');
        if (!FmodRuntime.playOneShotAttached(eventPath, provider)) warnMissing("PlayOneShotAttached", eventPath);
    }

    /**
     * Returns the event description at a path, for the authored facts about an event: length, distances, parameters and their labels, user properties, sample data preloading.
     * The object belongs to FMOD and needs no release. A bad path returns EventDescription.NULL.
     */
    public static function GetEventDescription(eventPath:String):EventDescription {
        ensureInitialized();
        return StudioSystem.getEvent(eventPath);
    }

    /**
     * Creates an event without starting it, so parameters and a position can be set before the first frame plays. Call start() on the handle when ready.
     * Everything else matches PlayEvent, including FmodEvent.NULL for a path FMOD cannot create.
     */
    public static function CreateEvent(eventPath:String):FmodEvent {
        ensureInitialized();
        var instance = FmodRuntime.createInstance(eventPath);
        if (instance.isNull()) {
            warnMissing("CreateEvent", eventPath);
            return FmodEvent.NULL;
        }
        return instance;
    }

    /**
     * Plays an event and returns a typed handle for parameters, callbacks, stop, and pause. Call release() when you are done with the handle.
     * A missing event logs a warning and returns FmodEvent.NULL. Every call on that handle is a safe no-op.
     */
    public static function PlayEvent(eventPath:String):FmodEvent {
        ensureInitialized();
        log('PlayEvent $eventPath');
        var instance = FmodRuntime.createInstance(eventPath);
        if (instance.isNull()) {
            warnMissing("PlayEvent", eventPath);
            return FmodEvent.NULL;
        }
        instance.start();
        return instance;
    }

    /**
     * Removes every registered callback. That covers song and event handlers, event description handlers, core channel and group handlers, the system callback, and PCM stream read callbacks.
     * Userdata stays.
     */
    public static function ClearAllCallbacks():Void {
        // No ensureInitialized: clearing registrations needs no system,
        // and a teardown path calls this after shutdown.
        CallbackDispatcher.clearAll();
        haxefmod.studio.EventDescription.clearAllCallbacks();
        haxefmod.core.ChannelCallbacks.clearAll();
        haxefmod.studio.SystemCallbacks.clear();
        haxefmod.core.PcmStream.clearAllReadCallbacks();
    }

    //// Game policy: development markers

    /**
     * Marks a spot in game code that still needs a sound.
     * Release builds compile the call away. Debug builds trace each call site once.
     * A build with -D haxefmod_todo_beep also plays a short placeholder blip, so missing sounds are audible during playtesting.
     * List every remaining marker with `haxelib run haxefmod todos`.
     */
    public static inline function Todo(description:String, ?pos:haxe.PosInfos):Void {
        #if (debug || haxefmod_todo_beep)
        todoImpl(description, pos);
        #end
    }

    #if (debug || haxefmod_todo_beep)
    static var todoSeen:Map<String, Bool> = new Map();
    #if haxefmod_todo_beep
    static var todoBeep:haxefmod.core.Sound = haxefmod.core.Sound.NULL;
    #end

    static function todoImpl(description:String, pos:haxe.PosInfos):Void {
        var site = pos == null ? description : '${pos.fileName}:${pos.lineNumber}';
        if (todoSeen.exists(site)) return;
        todoSeen.set(site, true);
        var location = pos == null ? "" : ' (${pos.fileName}:${pos.lineNumber})';
        trace('FMOD TODO: $description$location');
        #if haxefmod_todo_beep
        playTodoBeep();
        #end
    }

    #if haxefmod_todo_beep
    static function playTodoBeep():Void {
        if (!IsInitialized()) return;
        if (todoBeep.isNull()) {
            var rate = 32000;
            var samples = Std.int(rate * 0.09);
            var pcm = haxe.io.Bytes.alloc(samples * 2);
            for (i in 0...samples) {
                var envelope = 1.0 - i / samples;
                var value = Std.int(12000.0 * envelope * Math.sin(i * 2.0 * Math.PI * 880.0 / rate));
                pcm.setUInt16(i * 2, value & 0xFFFF);
            }
            todoBeep = haxefmod.core.Sound.fromPcm(pcm, rate, 1);
        }
        if (!todoBeep.isNull()) {
            // The previous beep's channel is long finished (the blip is
            // 90ms and beeps fire once per unique site). Stopping it here
            // frees its handle slot, per the Channel contract.
            todoBeepChannel.stop();
            todoBeepChannel = todoBeep.play();
        }
    }

    static var todoBeepChannel:haxefmod.core.Channel = haxefmod.core.Channel.NULL;
    #end
    #end

    //// Deprecated names, removed in the next major release

    @:deprecated("FmodManager.GetBusMute is now IsBusMuted")
    public static function GetBusMute(busPath:String):Bool {
        return IsBusMuted(busPath);
    }

    @:deprecated("FmodManager.SetBusVolumeMaster is now SetMasterVolume")
    public static function SetBusVolumeMaster(volume:Float):Void {
        SetMasterVolume(volume);
    }

    @:deprecated("FmodManager.GetBusVolumeMaster is now GetMasterVolume")
    public static function GetBusVolumeMaster():Float {
        return GetMasterVolume();
    }

    @:deprecated("FmodManager.SetBusMuteMaster is now SetMasterMute")
    public static function SetBusMuteMaster(mute:Bool):Void {
        SetMasterMute(mute);
    }

    @:deprecated("FmodManager.GetBusMuteMaster is now IsMasterMuted")
    public static function GetBusMuteMaster():Bool {
        return IsMasterMuted();
    }

    @:deprecated("FmodManager.GetEventParameterOnSong is now GetSongParameter")
    public static function GetEventParameterOnSong(parameterName:String):Float {
        return GetSongParameter(parameterName);
    }

    @:deprecated("FmodManager.SetEventParameterOnSong is now SetSongParameter")
    public static function SetEventParameterOnSong(parameterName:String, parameterValue:Float):Void {
        SetSongParameter(parameterName, parameterValue);
    }

    @:deprecated("FmodManager.PlaySound is now PlayEvent")
    public static function PlaySound(eventPath:String):FmodEvent {
        return PlayEvent(eventPath);
    }

    @:deprecated("FmodManager.CreateSound is now CreateEvent")
    public static function CreateSound(eventPath:String):FmodEvent {
        return CreateEvent(eventPath);
    }

    @:deprecated("FmodManager.PlaySoundOneShot is now PlayOneShot")
    public static function PlaySoundOneShot(eventPath:String):Void {
        PlayOneShot(eventPath);
    }

    @:deprecated("FmodManager.PlaySoundOneShotAt is now PlayOneShotAt")
    public static function PlaySoundOneShotAt(eventPath:String, x:Float, y:Float):Void {
        PlayOneShotAt(eventPath, x, y);
    }

    @:deprecated("FmodManager.PlaySoundOneShotAttached is now PlayOneShotAttached")
    public static function PlaySoundOneShotAttached(eventPath:String, provider:haxefmod.runtime.IFmodPositionProvider):Void {
        PlayOneShotAttached(eventPath, provider);
    }

    @:deprecated("FmodManager.StopAllSounds is now StopAllEvents")
    public static function StopAllSounds():Void {
        StopAllEvents();
    }

    @:deprecated("FmodManager.PauseAllSounds is now PauseAllEvents")
    public static function PauseAllSounds():Void {
        PauseAllEvents();
    }

    @:deprecated("FmodManager.UnpauseAllSounds is now UnpauseAllEvents")
    public static function UnpauseAllSounds():Void {
        UnpauseAllEvents();
    }

    //// Internals

    static inline function ensureInitialized():Void {
        if (!initialized) Initialize();
    }

    // A song mid-start or holding at a sustain point counts as playing.
    // Matching FMOD's own integration, only a fully stopped instance does
    // not. PLAYING alone would misread the STARTING frames right after
    // start() and adaptive-music sustain holds.
    static inline function isInstancePlaying(instance:EventInstance):Bool {
        return instance.getPlaybackState() != FmodPlaybackState.STOPPED;
    }

    // The same-song fast path restarts a song that stopped or is fading
    // out, and leaves one that is starting, playing, or sustaining alone.
    static inline function needsRestart(instance:EventInstance):Bool {
        var state = instance.getPlaybackState();
        return state == FmodPlaybackState.STOPPED || state == FmodPlaybackState.STOPPING;
    }

    // FMOD addresses a global parameter by its bare name. The generated
    // FmodParameters constants carry the "parameter:/" path form, so the
    // global parameter calls accept both.
    static inline function globalParameterName(name:String):String {
        return EventInstance.bareParameterName(name);
    }

    static function log(message:String):Void {
        if (debug) trace('FMOD: $message');
    }

    // A bad path is a game bug, so every call reports it in every build.
    static function warnMissing(call:String, path:String):Void {
        trace('Warn: FMOD - $call could not create "$path" (${StudioSystem.lastResult().toString()}). '
            + "Check the event path, that its bank is loaded, and that FMOD is initialized.");
    }

    static function warn(message:String):Void {
        trace('Warn: FMOD - $message (${StudioSystem.lastResult().toString()})');
    }
}
