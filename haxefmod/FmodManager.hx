package haxefmod;

import haxefmod.core.Sound;
import haxefmod.FmodSound;
import haxefmod.studio.CallbackDispatcher;
import haxefmod.runtime.FmodRuntime;
import haxefmod.runtime.FmodSettings;
import haxefmod.studio.Callbacks;
import haxefmod.studio.EventInstance;
import haxefmod.studio.StudioSystem;
import haxefmod.studio.Types;
import haxefmod.studio.native.NativeStudio;

/**
 * The helper class for FMOD. It owns six areas: lifecycle (init, update, and banks), one background song slot, sound effects, the mixer (buses, VCAs, and snapshots), global parameters, and game policy.
 * Every call takes an FMOD Studio path or name and holds no handle. The song slot is the one piece of state, and PlaySound returns the one handle.
 * World space, focus reporting, and everything by handle live in the public layers underneath: haxefmod.runtime.FmodRuntime and haxefmod.studio.
 *
 * Call FmodManager.Update() every frame, or let the engine setup call do it.
 */
class FmodManager {
    // Single music slot
    static var songInstance:EventInstance = EventInstance.NULL;
    static var CurrentSong:String = "";
    static var NextSong:String;

    static var lastUpdateCall:Float = 0;
    static var debug:Bool = false;
    static var initialized:Bool = false;

    //// System

    /**
     * Initializes FMOD. The optional settings control channels, Live Update, the bank folder, the auto-loaded banks, and more.
     * See FmodSettings. Every other FmodManager call initializes with defaults on first use.
     * The first initialization wins. Settings passed to a later call are ignored.
     */
    public static function Initialize(?settings:FmodSettings):Void {
        if (initialized) {
            if (settings != null) log("Initialize called again - already initialized, settings ignored");
            return;
        }
        initialized = true;
        FmodRuntime.init(settings);
        #if debug
        EnableDebugMessages();
        #end
        log("Initialized");
    }

    /** Turns on FMOD debug logging at its most verbose level and traces every FmodManager operation. Debug builds enable it automatically. */
    public static function EnableDebugMessages():Void {
        debug = true;
        NativeStudio.sys_set_debug_level(3); // 3 = log everything (the FmodSettings.logLevel scale)
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
        lastUpdateCall = Date.now().getTime();
        FmodRuntime.update();
    }

    /**
     * Turns the background auto-update on or off. It is on by default and keeps audio running when the game loop stalls.
     * Typed callbacks still arrive only from Update().
     */
    public static function SetAutoUpdate(enabled:Bool):Void {
        ensureInitialized();
        NativeStudio.sys_set_auto_update(enabled);
    }

    //// Banks

    /**
     * Loads a bank, or adds a reference to one that is loaded. The name is a file name resolved against the bank folder setting, for example "Level1.bank", or a full path.
     * Native targets load synchronously. HTML5 loads asynchronously, so poll IsBankLoaded before the first event from the bank.
     * Every LoadBank needs one UnloadBank. Initialize loads the banks named in the autoLoadBanks setting, Master and Master.strings by default.
     */
    public static function LoadBank(bankName:String):Void {
        ensureInitialized();
        if (FmodRuntime.banks.load(FmodRuntime.bankPath(bankName)).isNull()) {
            log('LoadBank: could not load $bankName (${StudioSystem.lastResult().toString()})');
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

    //// Window focus

    /**
     * Chooses whether the master output is muted while the window is unfocused. True, the default, mutes it. False keeps audio playing in the background.
     * The engine setup calls report focus changes through FmodRuntime.setWindowFocused. A game without one reports them there itself.
     */
    public static function SetMuteWhenUnfocused(enabled:Bool):Void {
        ensureInitialized();
        FmodRuntime.setMuteWhenUnfocused(enabled);
    }

    //// Global controls

    /** Stops every event routed through the master bus immediately, the song included. */
    public static function StopAllSounds():Void {
        ensureInitialized();
        StudioSystem.getBus("bus:/").stopAllEvents(IMMEDIATE);
    }

    /**
     * Pauses the master bus and freezes every sound at its position. Call UnpauseAllSounds to resume.
     * This suits a full pause menu. Events started while paused queue up and play on unpause.
     */
    public static function PauseAllSounds():Void {
        ensureInitialized();
        FmodRuntime.pauseAll(true);
    }

    /** Resumes the master bus paused by PauseAllSounds. */
    public static function UnpauseAllSounds():Void {
        ensureInitialized();
        FmodRuntime.pauseAll(false);
    }

    //// Buses

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
     * A pause menu pauses "bus:/SFX" and keeps the music bus running. PauseAllSounds pauses the master bus instead.
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
        SetBusMute("bus:/", mute);
    }

    /** Returns true when the master bus is muted. */
    public static function IsMasterMuted():Bool {
        return IsBusMuted("bus:/");
    }

    @:deprecated("FmodManager.GetBusMute is replaced by IsBusMuted")
    public static function GetBusMute(busPath:String):Bool {
        return IsBusMuted(busPath);
    }

    @:deprecated("FmodManager.SetBusVolumeMaster is replaced by SetMasterVolume")
    public static function SetBusVolumeMaster(volume:Float):Void {
        SetMasterVolume(volume);
    }

    @:deprecated("FmodManager.GetBusVolumeMaster is replaced by GetMasterVolume")
    public static function GetBusVolumeMaster():Float {
        return GetMasterVolume();
    }

    @:deprecated("FmodManager.SetBusMuteMaster is replaced by SetMasterMute")
    public static function SetBusMuteMaster(mute:Bool):Void {
        SetMasterMute(mute);
    }

    @:deprecated("FmodManager.GetBusMuteMaster is replaced by IsMasterMuted")
    public static function GetBusMuteMaster():Bool {
        return IsMasterMuted();
    }

    //// VCAs

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

    //// Snapshots

    /**
     * Applies a snapshot until StopSnapshot. The path comes from FMOD Studio, for example "snapshot:/Paused".
     * A snapshot is a mixer state the sound designer authored. FMOD blends the mixer toward it and back.
     * A snapshot that is already applied is left as it is. FMOD keeps the instance alive while it plays, so no handle is held here.
     */
    public static function StartSnapshot(snapshotPath:String):Void {
        ensureInitialized();
        var description = StudioSystem.getEvent(snapshotPath);
        if (description.isNull()) {
            log('StartSnapshot: no snapshot at $snapshotPath (${StudioSystem.lastResult().toString()})');
            return;
        }
        if (description.getInstanceCount() > 0) return;
        var instance = description.createInstance();
        if (instance.isNull()) {
            log('StartSnapshot: could not create $snapshotPath (${StudioSystem.lastResult().toString()})');
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
        // when its fade completes
        for (instance in description.getInstanceList()) instance.stop(ALLOWFADEOUT);
    }

    /** Removes a snapshot immediately, without its authored fade. */
    public static function StopSnapshotImmediately(snapshotPath:String):Void {
        ensureInitialized();
        var description = StudioSystem.getEvent(snapshotPath);
        if (description.isNull()) return;
        // FMOD's own stop-and-release of every instance. On html5 this is
        // also the sweep that reclaims the dead instances' handle slots
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
     * A parameter on one event instance is set through the FmodSound returned by PlaySound, or through SetSongParameter for the song.
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

    //// Music (single song slot)

    /**
     * Plays a song and replaces the current song immediately with no fade.
     * A second call with the current song does nothing. If that song stopped or is fading out, the call restarts it.
     * A missing event logs a warning and leaves the slot empty.
     */
    public static function PlaySong(songPath:String):Void {
        ensureInitialized();
        // A direct play supersedes any pending transition
        NextSong = null;

        if (songPath == CurrentSong && !songInstance.isNull()) {
            if (needsRestart(songInstance)) {
                songInstance.start();
            }
            return;
        }

        // Replace the current song: hard stop and release the old instance
        if (!songInstance.isNull()) {
            songInstance.stop(IMMEDIATE);
            songInstance.release();
            songInstance = EventInstance.NULL;
        }

        log('PlaySong $songPath');
        var instance = FmodRuntime.createInstance(songPath);
        if (instance.isNull()) {
            trace('Warn: FMOD - PlaySong could not create "' + songPath
                + '" (check the event path, that its bank is loaded, and that FMOD is initialized)');
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
        // transition's fade is still armed
        NextSong = null;

        if (songPath == CurrentSong && !songInstance.isNull()) {
            if (needsRestart(songInstance)) {
                songInstance.start();
            }
            return;
        }

        // Nothing to fade out - just play it
        if (songInstance.isNull() || !isInstancePlaying(songInstance)) {
            PlaySong(songPath);
            return;
        }

        log('PlaySongTransition $songPath');
        NextSong = songPath;
        // The handler arms before the stop: a song already fading (the
        // background update thread processes stops between any two calls
        // here) could otherwise deliver its Stopped in the gap and never
        // hand off
        songInstance.setCallback(data -> {
            switch (data) {
                case Stopped:
                    // StopSong since the transition was armed clears
                    // NextSong, and the completed fade must stay silent
                    if (NextSong != null) {
                        var next = NextSong;
                        NextSong = null;
                        PlaySong(next);
                    }
                default:
            }
        }, EventCallbackType.STOPPED);
        songInstance.stop(ALLOWFADEOUT);
        // The fade can also complete before the handler was installed: no
        // Stopped will ever arrive for it, so hand off directly. NextSong
        // is cleared first, which keeps a queued Stopped a no-op.
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
            var s = FmodRuntime.settings();
            if (s == null || !s.autoUpdate) NativeStudio.sys_update();
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

    /** Returns the event path passed to the last PlaySong. It is empty before the first song. */
    public static function GetCurrentSongPath():String {
        return CurrentSong;
    }

    /** Returns the timeline position of the song in milliseconds. It is 0 with no song. */
    public static function GetSongTimelinePosition():Int {
        ensureInitialized();
        return songInstance.isNull() ? 0 : songInstance.getTimelinePosition();
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

    @:deprecated("FmodManager.GetEventParameterOnSong is replaced by GetSongParameter")
    public static function GetEventParameterOnSong(parameterName:String):Float {
        return GetSongParameter(parameterName);
    }

    @:deprecated("FmodManager.SetEventParameterOnSong is replaced by SetSongParameter")
    public static function SetEventParameterOnSong(parameterName:String, parameterValue:Float):Void {
        SetSongParameter(parameterName, parameterValue);
    }

    @:deprecated("FmodManager.SetEventParameterOnSongWithLabel is replaced by SetSongParameterWithLabel")
    public static function SetEventParameterOnSongWithLabel(parameterName:String, label:String):Void {
        SetSongParameterWithLabel(parameterName, label);
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
            CallbackDispatcher.remove(instance);
            if (!unwanted) handler(data);
        }, mask);
    }

    //// Sound effects

    /** Starts an event and releases it straight away. FMOD destroys it when it finishes. */
    public static function PlaySoundOneShot(soundPath:String):Void {
        ensureInitialized();
        log('PlaySoundOneShot $soundPath');
        FmodRuntime.playOneShot(soundPath);
    }

    /** Starts a one-shot event at a 2D position relative to listener 0. */
    public static function PlaySoundOneShotAt(soundPath:String, x:Float, y:Float):Void {
        ensureInitialized();
        log('PlaySoundOneShotAt $soundPath');
        FmodRuntime.playOneShot(soundPath, x, y);
    }

    /**
     * Starts a one-shot event that follows a moving object until the event ends.
     * Use it for self-ending events only. A looping event never ends, so it never releases.
     * Flixel games can pass a FlxObject through FmodFlxUtilities.PlaySoundOneShotAttached.
     */
    public static function PlaySoundOneShotAttached(soundPath:String, provider:haxefmod.runtime.IFmodPositionProvider):Void {
        ensureInitialized();
        log('PlaySoundOneShotAttached $soundPath');
        FmodRuntime.playOneShotAttached(soundPath, provider);
    }

    /**
     * Plays a sound and returns a typed handle for parameters, callbacks, stop, and pause. Call release() when you are done with the handle.
     * A missing event logs a warning and returns FmodSound.NULL. Every call on that handle is a safe no-op.
     */
    public static function PlaySound(soundPath:String):FmodSound {
        ensureInitialized();
        log('PlaySound $soundPath');
        var instance = FmodRuntime.createInstance(soundPath);
        if (instance.isNull()) {
            trace('Warn: FMOD - PlaySound could not create "' + soundPath
                + '" (check the event path, that its bank is loaded, and that FMOD is initialized)');
            return FmodSound.NULL;
        }
        instance.start();
        return instance;
    }

    /**
     * Removes every registered callback. That covers song and sound handlers, event description handlers, core channel and group handlers, the system callback, and PCM stream read callbacks.
     * Userdata stays.
     */
    public static function ClearAllCallbacks():Void {
        CallbackDispatcher.clearAll();
        haxefmod.studio.EventDescription.clearAllCallbacks();
        haxefmod.core.ChannelCallbacks.clearAll();
        haxefmod.studio.SystemCallbacks.clear();
        haxefmod.core.PcmStream.clearAllReadCallbacks();
    }

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
    // out, and leaves one that is starting, playing, or sustaining alone
    static inline function needsRestart(instance:EventInstance):Bool {
        var state = instance.getPlaybackState();
        return state == FmodPlaybackState.STOPPED || state == FmodPlaybackState.STOPPING;
    }

    // FMOD addresses a global parameter by its bare name, and the generated
    // FmodParameters constants carry the "parameter:/" path form, so the
    // global parameter calls accept both
    static inline function globalParameterName(name:String):String {
        return StringTools.startsWith(name, "parameter:/") ? name.substr("parameter:/".length) : name;
    }

    static function log(message:String):Void {
        if (debug) trace('FMOD: $message');
    }
}
