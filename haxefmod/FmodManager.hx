package haxefmod;

import haxefmod.FmodSound;
import haxefmod.runtime.CallbackDispatcher;
import haxefmod.runtime.FmodRuntime;
import haxefmod.runtime.FmodSettings;
import haxefmod.studio.Callbacks;
import haxefmod.studio.EventInstance;
import haxefmod.studio.StudioSystem;
import haxefmod.studio.Types;
import haxefmod.studio.native.NativeStudio;

/**
 * The friendly FMOD facade: one background song slot plus fire-and-forget
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
     * bank folder/auto-loading, and more (see FmodSettings); every other
     * FmodManager call initializes with defaults on first use.
     */
    public static function Initialize(?settings:FmodSettings):Void {
        if (initialized) return;
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
        NativeStudio.sys_set_debug_level(3);
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
     * game loop stalls (on by default; typed callbacks still only arrive
     * from Update).
     */
    public static function SetAutoUpdate(enabled:Bool):Void {
        ensureInitialized();
        NativeStudio.sys_set_auto_update(enabled);
    }

    //// Global controls

    public static function StopAllSounds():Void {
        ensureInitialized();
        StudioSystem.getBus("bus:/").stopAllEvents(IMMEDIATE);
    }

    public static function PauseAllSounds():Void {
        ensureInitialized();
        FmodRuntime.pauseAll(true);
    }

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
        if (instance.isNull()) return;
        instance.start();
        songInstance = instance;
        CurrentSong = songPath;
    }

    /**
     * Fades out the current song (as authored), then plays the new one
     * once the Stopped event arrives. Requires Update() every frame.
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
                    PlaySong(NextSong);
                default:
            }
        }, EventCallbackType.STOPPED);
    }

    public static function StopSong():Void {
        ensureInitialized();
        if (!songInstance.isNull()) songInstance.stop(ALLOWFADEOUT);
    }

    public static function StopSongImmediately():Void {
        ensureInitialized();
        if (!songInstance.isNull()) songInstance.stop(IMMEDIATE);
    }

    public static function PauseSong():Void {
        ensureInitialized();
        if (!songInstance.isNull()) {
            songInstance.setPaused(true);
            // Push the pause through FMOD immediately, independent of the game loop
            NativeStudio.sys_update();
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
     * current song. Replaces any previous handler; delivered from Update().
     */
    public static function OnSongEvent(handler:EventCallbackData->Void, ?playbackEventMask:Int):Void {
        ensureInitialized();
        if (!songInstance.isNull()) songInstance.setCallback(handler, playbackEventMask);
    }

    /**
     * Registers a song callback that fires for the FIRST delivered event
     * and then removes itself (use the mask to pick which events qualify).
     * Replaces any previous song handler, like OnSongEvent.
     */
    public static function OnceSongEvent(handler:EventCallbackData->Void, ?playbackEventMask:Int):Void {
        ensureInitialized();
        if (songInstance.isNull()) return;
        var instance = songInstance;
        instance.setCallback(data -> {
            CallbackDispatcher.remove(instance);
            handler(data);
        }, playbackEventMask);
    }

    //// Sound effects

    /** Fire-and-forget playback (no handle; FMOD reclaims the instance). */
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
     * Plays a sound and returns a typed handle for further control
     * (parameters, callbacks, stop/pause). Call release() when done with
     * the handle. Replaces the 1.x string-ID PlaySoundWithReference family.
     */
    public static function PlaySound(soundPath:String):FmodSound {
        ensureInitialized();
        log('PlaySound $soundPath');
        var instance = FmodRuntime.createInstance(soundPath);
        if (instance.isNull()) return FmodSound.NULL;
        instance.start();
        return instance;
    }

    /** Removes every registered event callback (song and sounds). */
    public static function ClearAllCallbacks():Void {
        CallbackDispatcher.clearAll();
    }

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
