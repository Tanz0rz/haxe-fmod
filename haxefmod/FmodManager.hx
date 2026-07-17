package haxefmod;

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
 * High-level FMOD facade: one background song slot plus fire-and-forget
 * and handle-based sound effects. Built entirely on the public layers
 * underneath - use haxefmod.runtime.FmodRuntime for banks/3D/settings and
 * haxefmod.studio.* for the complete FMOD Studio API.
 *
 * Call FmodManager.Update() every frame (or add FmodFlxUpdater once).
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
     * Initializes FMOD. Optional settings control channels, live update,
     * bank folder/auto-loading, and more (see FmodSettings). every other
     * FmodManager call initializes with defaults on first use. First
     * initialization wins: settings passed to a later call are ignored.
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

    /** Turns on FMOD debug logging and facade operation traces. */
    public static function EnableDebugMessages():Void {
        debug = true;
        NativeStudio.sys_set_debug_level(3); // 3 = log everything (the FmodSettings.logLevel scale)
    }

    /** True once FMOD is ready (html5 initializes asynchronously). */
    public static function IsInitialized():Bool {
        ensureInitialized();
        return FmodRuntime.isInitialized();
    }

    /**
     * Services FMOD: delivers callbacks, updates attached instances, and
     * drives song transitions. Call once per frame.
     */
    public static function Update():Void {
        ensureInitialized();
        lastUpdateCall = Date.now().getTime();
        FmodRuntime.update();
    }

    /**
     * Toggles the background auto-update that keeps audio running when the
     * game loop stalls (on by default. typed callbacks still only arrive
     * from Update).
     */
    public static function SetAutoUpdate(enabled:Bool):Void {
        ensureInitialized();
        NativeStudio.sys_set_auto_update(enabled);
    }

    //// Window focus

    /**
     * Reports a window focus change to FMOD. While unfocused, the master
     * output is muted so audio doesn't play to a window nobody is looking
     * at - but FMOD keeps mixing, so sounds play out in real time instead of
     * queuing up and blasting out the moment the window regains focus (see
     * SetMuteWhenUnfocused to change that, or the muteWhenUnfocused setting).
     *
     * Call this from wherever your game observes window focus changes.
     * Games that never lose focus can ignore it.
     */
    public static function SetWindowFocused(isFocused:Bool):Void {
        ensureInitialized();
        FmodRuntime.setWindowFocused(isFocused);
    }

    public static function IsWindowFocused():Bool {
        ensureInitialized();
        return FmodRuntime.isWindowFocused();
    }

    /**
     * Chooses whether the master output is muted while the window is
     * unfocused: true (the default) mutes it, false keeps audio playing in
     * the background.
     */
    public static function SetMuteWhenUnfocused(enabled:Bool):Void {
        ensureInitialized();
        FmodRuntime.setMuteWhenUnfocused(enabled);
    }

    //// Global controls

    public static function StopAllSounds():Void {
        ensureInitialized();
        StudioSystem.getBus("bus:/").stopAllEvents(IMMEDIATE);
    }

    /**
     * Pauses the master bus, freezing every sound routed through it at
     * its current position. Pair with UnpauseAllSounds to resume.
     *
     * Intended for a full pause menu where the game's audio should stop
     * completely but temporarily. While this pause state is active, new
     * sound events are queued up and all play the moment the unpause
     * function is called.
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

    public static function SetBusVolume(busPath:String, volume:Float):Void {
        ensureInitialized();
        StudioSystem.getBus(busPath).setVolume(volume);
    }

    public static function GetBusVolume(busPath:String):Float {
        ensureInitialized();
        return StudioSystem.getBus(busPath).getVolume();
    }

    public static function SetBusMute(busPath:String, mute:Bool):Void {
        ensureInitialized();
        StudioSystem.getBus(busPath).setMute(mute);
    }

    public static function GetBusMute(busPath:String):Bool {
        ensureInitialized();
        return StudioSystem.getBus(busPath).getMute();
    }

    /** Master-bus ("bus:/") convenience variants. */
    public static function SetBusVolumeMaster(volume:Float):Void {
        SetBusVolume("bus:/", volume);
    }

    public static function GetBusVolumeMaster():Float {
        return GetBusVolume("bus:/");
    }

    public static function SetBusMuteMaster(mute:Bool):Void {
        SetBusMute("bus:/", mute);
    }

    public static function GetBusMuteMaster():Bool {
        return GetBusMute("bus:/");
    }

    //// Music (single song slot)

    /**
     * Plays a song, immediately replacing any current song. Calling it
     * again with the current song restarts playback only if it stopped.
     */
    public static function PlaySong(songPath:String):Void {
        ensureInitialized();
        // A direct play supersedes any pending transition
        NextSong = null;

        if (songPath == CurrentSong && !songInstance.isNull()) {
            if (!isInstancePlaying(songInstance)) {
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
     * Fades out the current song (as authored), then plays the new one
     * once the Stopped event arrives. Requires Update() every frame.
     *
     * The song has a single callback slot: the transition occupies it
     * until the fade completes, so registering OnSongEvent during the
     * fade cancels the transition, and a second transition during the
     * fade cuts to the new song instead of crossfading.
     */
    public static function PlaySongTransition(songPath:String):Void {
        ensureInitialized();

        if (songPath == CurrentSong && !songInstance.isNull()) {
            if (!isInstancePlaying(songInstance)) {
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
        songInstance.stop(ALLOWFADEOUT);
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
    }

    /** Fades the song out (as authored) and cancels any pending transition. */
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

    public static function UnpauseSong():Void {
        ensureInitialized();
        if (!songInstance.isNull()) songInstance.setPaused(false);
    }

    public static function IsSongPlaying():Bool {
        ensureInitialized();
        return !songInstance.isNull() && isInstancePlaying(songInstance);
    }

    public static function GetCurrentSongPath():String {
        return CurrentSong;
    }

    /** Timeline position of the current song in milliseconds. */
    public static function GetSongTimelinePosition():Int {
        ensureInitialized();
        return songInstance.isNull() ? 0 : songInstance.getTimelinePosition();
    }

    public static function GetEventParameterOnSong(parameterName:String):Float {
        ensureInitialized();
        return songInstance.isNull() ? 0.0 : songInstance.getParameter(parameterName);
    }

    public static function SetEventParameterOnSong(parameterName:String, parameterValue:Float):Void {
        ensureInitialized();
        if (!songInstance.isNull()) songInstance.setParameter(parameterName, parameterValue);
    }

    /**
     * Registers a typed payload callback (beats, markers, lifecycle) on the
     * current song, delivered from Update(). Replaces any previous handler,
     * including a pending PlaySongTransition's completion handler (the
     * transition is then cancelled).
     */
    public static function OnSongEvent(handler:EventCallbackData->Void, ?mask:Int):Void {
        ensureInitialized();
        if (!songInstance.isNull()) songInstance.setCallback(handler, mask);
    }

    /**
     * Registers a song callback that fires for the FIRST delivered event
     * and then removes itself (use the mask to pick which events qualify).
     * Replaces any previous song handler, like OnSongEvent.
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

    /** Fire-and-forget playback (no handle. FMOD reclaims the instance). */
    public static function PlaySoundOneShot(soundPath:String):Void {
        ensureInitialized();
        log('PlaySoundOneShot $soundPath');
        FmodRuntime.playOneShot(soundPath);
    }

    /** Fire-and-forget playback positioned in 2D space (uses listener 0). */
    public static function PlaySoundOneShotAt(soundPath:String, x:Float, y:Float):Void {
        ensureInitialized();
        log('PlaySoundOneShotAt $soundPath');
        FmodRuntime.playOneShot(soundPath, x, y);
    }

    /**
     * Fire-and-forget playback that follows a moving object until the event
     * ends. Intended for one-shot (self-ending) events. Flixel games can
     * pass a FlxObject through FmodFlxUtilities.PlaySoundOneShotAttached.
     */
    public static function PlaySoundOneShotAttached(soundPath:String, provider:haxefmod.runtime.IFmodPositionProvider):Void {
        ensureInitialized();
        log('PlaySoundOneShotAttached $soundPath');
        FmodRuntime.playOneShotAttached(soundPath, provider);
    }

    /**
     * Plays a sound and returns a typed handle for further control
     * (parameters, callbacks, stop/pause). Call release() when done with
     * the handle.
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

    /** Removes every registered callback (song, sounds, and core channels). */
    public static function ClearAllCallbacks():Void {
        CallbackDispatcher.clearAll();
        haxefmod.core.ChannelCallbacks.clearAll();
    }

    /**
     * Marks a spot that needs a sound so audio work can be scheduled
     * later. List every remaining call site with:
     *
     *   haxelib run haxefmod todos
     *
     * Release builds compile the call away. Debug builds trace each call
     * site once. Build with -D haxefmod_todo_beep to also play a short
     * placeholder blip, which makes missing sounds audible during
     * playtesting.
     */
    public static inline function Todo(description:String, ?pos:haxe.PosInfos):Void {
        #if (debug || haxefmod_todo_beep)
        todoImpl(description, pos);
        #end
    }

    #if (debug || haxefmod_todo_beep)
    static var todoSeen:Map<String, Bool> = new Map();
    #if haxefmod_todo_beep
    static var todoBeep:haxefmod.studio.CoreSound = haxefmod.studio.CoreSound.NULL;
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
            todoBeep = haxefmod.studio.CoreSound.fromPcm(pcm, rate, 1);
        }
        if (!todoBeep.isNull()) todoBeep.play();
    }
    #end
    #end

    //// Internals

    static inline function ensureInitialized():Void {
        if (!initialized) Initialize();
    }

    static inline function isInstancePlaying(instance:EventInstance):Bool {
        return instance.getPlaybackState() == FmodPlaybackState.PLAYING;
    }

    static function log(message:String):Void {
        if (debug) trace('FMOD: $message');
    }
}
