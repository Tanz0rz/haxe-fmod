package haxefmod;

import haxefmod.FmodEvents.FmodCallback;
import haxefmod.FmodEvents.FmodEventListener;
import haxefmod.runtime.CallbackDispatcher;
import haxefmod.runtime.FmodRuntime;
import haxefmod.studio.Callbacks;
import haxefmod.studio.EventInstance;
import haxefmod.studio.StudioSystem;
import haxefmod.studio.Types;
import haxefmod.studio.native.NativeStudio;

class FmodManagerPrivate {
    /** Named event instances (single music slot + referenced sounds) */
    private var instances:Map<String, EventInstance>;

    // Main song
    private var CurrentSong:String = "";
    private var NextSong:String;
    private var SongEventInstance:String = "SongEventInstance";

    // Events
    private var eventListeners:Array<FmodEventListener> = new Array();

    // Data
    private var soundIdIncrementer:Int = 0;
    private var lastUpdateCall:Float = 0;
    private var debug:Bool = false;

    /** Warning threshold for too many tracked instances */
    private static inline var MAX_INSTANCES_WARNING:Int = 25;

    private static var instance:FmodManagerPrivate;

    private function new() {
        instances = new Map<String, EventInstance>();
    }

    private static function GetInstance():FmodManagerPrivate {
        if (instance == null) {
            instance = new FmodManagerPrivate();

            // Defaults auto-load the Master and strings banks from
            // assets/fmod/Desktop and enable auto-update on native targets.
            // For html5 deployments, the shim loads the banks and enables
            // auto-update during its asynchronous init.
            FmodRuntime.init();

            // If the -debug flag is passed into the build, enable debug messages
            #if debug
            instance.EnableDebugMessages();
            #end

            instance.log("Initialized");
        }
        return instance;
    }

    //// Helpers

    private inline function log(msg:String) {
        if (debug) trace('FMOD: $msg');
    }

    /** Resolves an instance name to its event instance (EventInstance.NULL if unknown) */
    private inline function getEventInstance(instanceName:String):EventInstance {
        var eventInstance = instances.get(instanceName);
        return eventInstance == null ? EventInstance.NULL : eventInstance;
    }

    private function registerEventInstance(instanceName:String, eventInstance:EventInstance) {
        instances.set(instanceName, eventInstance);

        var count = 0;
        for (_ in instances) count++;
        if (count > MAX_INSTANCES_WARNING) {
            trace('Warn: FMOD - The number of cached sounds is now $count. '
                + 'Remember to call ReleaseSound() after a sound is no longer needed to avoid memory issues.');
        }
    }

    private inline function isPlaying(eventInstance:EventInstance):Bool {
        return eventInstance.getPlaybackState() == FmodPlaybackState.PLAYING;
    }

    //// System

    private function EnableDebugMessages() {
        debug = true;
        NativeStudio.sys_set_debug_level(3);
        log("Debug messages enabled");
    }

    private function IsInitialized():Bool {
        return FmodRuntime.isInitialized();
    }

    private function SetAutoUpdate(enabled:Bool) {
        NativeStudio.sys_set_auto_update(enabled);
    }

    private function CheckIfUpdateIsBeingCalled() {
        var timeSinceLastUpdate:Float = DateTools.delta(Date.now(), -lastUpdateCall).getTime();
        if (timeSinceLastUpdate > 1000) {
            trace("Warn: Is FmodManager.Update() in your game loop? It has been " + timeSinceLastUpdate + " milliseconds since it was last called. "
                + "Song transitions and callback events will not work unless this function is called in your game loop.");
        }
    }

    private function Update() {
        lastUpdateCall = Date.now().getTime();

        // Services FMOD and drains the native callback queue
        FmodRuntime.update();
    }

    private function StopAllSounds() {
        StudioSystem.getBus("bus:/").stopAllEvents(IMMEDIATE);
    }

    private function PauseAllSounds() {
        StudioSystem.getBus("bus:/").setPaused(true);
    }

    private function UnpauseAllSounds() {
        StudioSystem.getBus("bus:/").setPaused(false);
    }

    //// Bus

    private function SetBusVolume(busPath:String, volume:Float) {
        StudioSystem.getBus(busPath).setVolume(volume);
    }

    private function GetBusVolume(busPath:String):Float {
        return StudioSystem.getBus(busPath).getVolume();
    }

    private function SetBusMute(busPath:String, mute:Bool) {
        StudioSystem.getBus(busPath).setMute(mute);
    }

    private function GetBusMute(busPath:String):Bool {
        return StudioSystem.getBus(busPath).getMute();
    }

    //// Music

    private function PlaySong(songPath:String) {
        log('PlaySong $songPath');

        // Clear out any callbacks when immediately playing a song
        UnregisterCallbacksForSound(SongEventInstance);

        var song = getEventInstance(SongEventInstance);

        if (songPath == CurrentSong && !song.isNull()) {
            // If the song passed in is loaded, but not playing, start it again
            if (!isPlaying(song)) {
                song.start();
            }
            return;
        }

        // If we are changing songs, make sure it is not playing, then release it from memory
        if (songPath != CurrentSong && CurrentSong != null && !song.isNull()) {
            if (isPlaying(song)) {
                song.stop(IMMEDIATE);
            }
            // Releasing the primary song event instance is causing issues on html5 deployments
            // song.release();
            // instances.remove(SongEventInstance);
        }

        // Create a brand new event instance of the song
        var newSong = FmodRuntime.createInstance(songPath);
        if (!newSong.isNull()) {
            registerEventInstance(SongEventInstance, newSong);
            CurrentSong = songPath;
        }
    }

    private function PlaySongTransition(songPath:String) {
        log('PlaySongTransition $songPath');

        var song = getEventInstance(SongEventInstance);

        if (songPath == CurrentSong && !song.isNull()) {
            // If the song passed in is loaded, but not playing, start it again
            if (!isPlaying(song)) {
                song.start();
            }
            return;
        }

        // If we are changing songs, send a soft stop request to the event
        if (songPath != CurrentSong && CurrentSong != null && !song.isNull()) {
            if (isPlaying(song)) {
                song.stop();
            }
        }

        CheckIfUpdateIsBeingCalled();
        NextSong = songPath;
        RegisterCallbacksForSound(SongEventInstance, () -> {
            PlaySong(NextSong);
        }, FmodCallback.STOPPED);
    }

    private function StopSong() {
        var song = getEventInstance(SongEventInstance);
        if (!song.isNull()) {
            song.stop();
        }
    }

    private function StopSongImmediately() {
        var song = getEventInstance(SongEventInstance);
        if (!song.isNull()) {
            song.stop(IMMEDIATE);
        }
    }

    private function PauseSong() {
        var song = getEventInstance(SongEventInstance);
        if (!song.isNull()) {
            song.setPaused(true);
            // Send additional update to FMOD to avoid dependency on main game loop
            NativeStudio.sys_update();
        }
    }

    private function UnpauseSong() {
        var song = getEventInstance(SongEventInstance);
        if (!song.isNull()) {
            song.setPaused(false);
        }
    }

    private function ClearAllCallbacks() {
        CallbackDispatcher.clearAll();
    }

    private function GetEventParameterOnSong(parameterName:String):Float {
        var song = getEventInstance(SongEventInstance);
        if (!song.isNull()) {
            return song.getParameter(parameterName);
        }
        return 0.0;
    }

    private function SetEventParameterOnSong(parameterName:String, parameterValue:Float) {
        var song = getEventInstance(SongEventInstance);
        if (!song.isNull()) {
            song.setParameter(parameterName, parameterValue);
        }
    }

    private function IsSongPlaying():Bool {
        var song = getEventInstance(SongEventInstance);
        if (!song.isNull()) {
            return isPlaying(song);
        }
        return false;
    }

    private function GetCurrentSongPath():String {
        return CurrentSong;
    }

    private function GetSongTimelinePosition():Int {
        var song = getEventInstance(SongEventInstance);
        if (!song.isNull()) {
            return song.getTimelinePosition();
        }
        return 0;
    }

    //// Sound effects

    private function PlaySoundOneShot(soundPath:String) {
        log('PlaySoundOneShot $soundPath');
        FmodRuntime.playOneShot(soundPath);
    }

    private function PlaySoundWithReference(soundPath:String):String {
        log('PlaySoundWithReference $soundPath');
        var soundId = '${soundPath}-${soundIdIncrementer}';
        var sound = FmodRuntime.createInstance(soundPath);
        if (!sound.isNull()) {
            registerEventInstance(soundId, sound);
            soundIdIncrementer++;
            return soundId;
        }
        return "";
    }

    private function PlaySoundAndAssignId(soundPath:String, soundId:String):String {
        log('PlaySoundAndAssignId $soundPath as $soundId');
        var sound = FmodRuntime.createInstance(soundPath);
        if (!sound.isNull()) {
            registerEventInstance(soundId, sound);
            return soundId;
        }
        return "";
    }

    public function IsSoundLoaded(soundId:String):Bool {
        return instances.exists(soundId);
    }

    public function IsSoundPlaying(soundId:String):Bool {
        var sound = getEventInstance(soundId);
        if (!sound.isNull()) {
            return isPlaying(sound);
        }
        return false;
    }

    private function StopSound(soundId:String) {
        var sound = getEventInstance(soundId);
        if (!sound.isNull()) {
            sound.stop();
        }
    }

    private function StopSoundImmediately(soundId:String) {
        var sound = getEventInstance(soundId);
        if (!sound.isNull()) {
            sound.stop(IMMEDIATE);
        }
    }

    private function PauseSound(soundId:String) {
        var sound = getEventInstance(soundId);
        if (!sound.isNull()) {
            sound.setPaused(true);
        }
    }

    private function UnpauseSound(soundId:String) {
        var sound = getEventInstance(soundId);
        if (!sound.isNull()) {
            sound.setPaused(false);
        }
    }

    private function ReleaseSound(soundId:String) {
        var sound = getEventInstance(soundId);
        if (!sound.isNull()) {
            // release() also removes any registered callback for this instance
            sound.release();
        }
        instances.remove(soundId);
    }

    private function GetEventParameterOnSound(soundId:String, parameterName:String):Float {
        var sound = getEventInstance(soundId);
        if (!sound.isNull()) {
            return sound.getParameter(parameterName);
        }
        return 0.0;
    }

    private function SetEventParameterOnSound(soundId:String, parameterName:String, parameterValue:Float) {
        var sound = getEventInstance(soundId);
        if (!sound.isNull()) {
            sound.setParameter(parameterName, parameterValue);
        }
    }

    //// Callbacks

    private function RegisterCallbacksForSong(callback:Void->Void, playbackEventMask:UInt) {
        var song = getEventInstance(SongEventInstance);
        if (song.isNull()) return;
        CallbackDispatcher.setCallback(song, _ -> callback(), playbackEventMask);
    }

    private function UnregisterCallbacksForSong() {
        CallbackDispatcher.remove(getEventInstance(SongEventInstance));
    }

    private function RegisterCallbacksForSound(soundId:String, callback:Void->Void, playbackEventMask:UInt) {
        var sound = getEventInstance(soundId);
        if (sound.isNull()) return;
        CallbackDispatcher.setCallback(sound, _ -> callback(), playbackEventMask);
    }

    private function UnregisterCallbacksForSound(soundId:String) {
        CallbackDispatcher.remove(getEventInstance(soundId));
    }

    /**
     * Registers a typed payload-carrying callback on the current song
     * instance (timeline beats, markers, playback lifecycle).
     */
    private function OnSongEvent(handler:EventCallbackData->Void, ?playbackEventMask:Int) {
        var song = getEventInstance(SongEventInstance);
        if (song.isNull()) return;
        CallbackDispatcher.setCallback(song, handler, playbackEventMask);
    }

    //// Utility

    private function RegisterEventListener(newEventListener:FmodEventListener) {
        eventListeners.push(newEventListener);
    }
}
