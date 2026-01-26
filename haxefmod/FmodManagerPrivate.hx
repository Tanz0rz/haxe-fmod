package haxefmod;

import haxefmod.FmodEvents.FmodCallback;
import haxefmod.FmodEvents.FmodEvent;
import haxefmod.FmodEvents.FmodEventListener;
import haxefmod.Settings;
import haxefmod.backends.IFmodBackend;
#if cpp
import haxefmod.backends.CppBackend;
#elseif js
import haxefmod.backends.JsBackend;
#elseif hl
import haxefmod.backends.HlBackend;
#end

class FmodManagerPrivate {
    // Backend
    private var backend:IFmodBackend;
    private var cache:FmodCache;
    private var callbackManager:FmodCallbackManager;

    // Main song
    private var CurrentSong:String = "";
    private var NextSong:String;
    private var SongEventInstance:String = "SongEventInstance";

    // Events
    private var eventListeners:Array<FmodEventListener> = new Array();

    // Data
    private var soundIdIncrementer:Int = 0;
    private var lastUpdateCall:Float = 0;

    // Settings
    private var settings:FmodSettings;

    private static var instance:FmodManagerPrivate;

    private function new() {
        // Initialize the appropriate backend for this platform
        #if cpp
        backend = new CppBackend();
        #elseif js
        backend = new JsBackend();
        #elseif hl
        backend = new HlBackend();
        #else
        throw "No FMOD backend available for this platform";
        #end

        cache = FmodCache.getInstance();
        callbackManager = FmodCallbackManager.getInstance();
    }

    private static function GetInstance():FmodManagerPrivate {
        if (instance == null) {
            instance = new FmodManagerPrivate();
            instance.settings = Settings.LoadDefaultFmodSettings();

            // If the -debug flag is passed into the build, enable debug messages
            #if debug
            instance.backend.setDebug(true);

            // Suppress debug messages if specified in the settings file
            if (instance.settings.SuppressDebugMessages) {
                instance.backend.setDebug(false);
            }
            #end

            instance.backend.init(128);

            // For html5 deployments, the banks must be loaded from inside the javascript fmod_init() call
            #if (cpp || hl)
            instance.backend.loadBank("assets/fmod/Desktop/Master.bank");
            instance.backend.loadBank("assets/fmod/Desktop/Master.strings.bank");
            instance.cache.registerBank("assets/fmod/Desktop/Master.bank");
            instance.cache.registerBank("assets/fmod/Desktop/Master.strings.bank");
            #end
        }
        return instance;
    }

    //// System

    private function EnableDebugMessages() {
        backend.setDebug(true);
    }

    private function IsInitialized():Bool {
        return backend.isInitialized();
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

        // Call native FMOD update
        backend.update();

        // Process callbacks using the callback manager
        callbackManager.processCallbacks((instanceName, mask) -> {
            return backend.checkCallbacksForEventInstance(instanceName, mask);
        });
    }

    private function StopAllSounds() {
        backend.stopAllEventsOnBus("bus:/");
    }

    private function PauseAllSounds() {
        backend.setPauseForAllEventsOnBus("bus:/", true);
    }

    private function UnpauseAllSounds() {
        backend.setPauseForAllEventsOnBus("bus:/", false);
    }

    //// Music

    private function PlaySong(songPath:String) {
        // Clear out any callbacks when immediately playing a song
        UnregisterCallbacksForSound(SongEventInstance);

        if (songPath == CurrentSong) {
            // If the song passed in is loaded, but not playing, start it again
            if (!backend.isEventInstancePlaying(SongEventInstance)) {
                backend.playEventInstance(SongEventInstance);
            }
            return;
        }

        // If we are changing songs, make sure it is not playing, then release it from memory
        if (songPath != CurrentSong && CurrentSong != null) {
            if (backend.isEventInstancePlaying(SongEventInstance)) {
                backend.stopEventInstanceImmediately(SongEventInstance);
            }
            // Releasing the primary song event instance is causing issues on html5 deployments
            // backend.releaseEventInstance(SongEventInstance);
        }

        // Create a brand new event instance of the song
        backend.createEventInstanceNamed(songPath, SongEventInstance);
        cache.registerEventInstance(SongEventInstance, songPath);
        CurrentSong = songPath;
    }

    private function PlaySongTransition(songPath:String) {
        if (songPath == CurrentSong) {
            // If the song passed in is loaded, but not playing, start it again
            if (!backend.isEventInstancePlaying(SongEventInstance)) {
                backend.playEventInstance(SongEventInstance);
            }
            return;
        }

        // If we are changing songs, send a soft stop request to the event
        if (songPath != CurrentSong && CurrentSong != null && backend.isEventInstancePlaying(SongEventInstance)) {
            backend.stopEventInstance(SongEventInstance);
        }

        CheckIfUpdateIsBeingCalled();
        NextSong = songPath;
        RegisterCallbacksForSound(SongEventInstance, () -> {
            PlaySong(NextSong);
        }, FmodCallback.STOPPED);
    }

    private function StopSong() {
        backend.stopEventInstance(SongEventInstance);
    }

    private function StopSongImmediately() {
        backend.stopEventInstanceImmediately(SongEventInstance);
    }

    private function PauseSong() {
        backend.setPauseOnEventInstance(SongEventInstance, true);

        // Send additional update to FMOD to avoid dependency on main game loop
        backend.update();
    }

    private function UnpauseSong() {
        backend.setPauseOnEventInstance(SongEventInstance, false);
    }

    private function ClearAllCallbacks() {
        callbackManager.clearAll();
    }

    private function GetEventParameterOnSong(parameterName:String):Float {
        return backend.getEventInstanceParam(SongEventInstance, parameterName);
    }

    private function SetEventParameterOnSong(parameterName:String, parameterValue:Float) {
        backend.setEventInstanceParam(SongEventInstance, parameterName, parameterValue);
    }

    private function IsSongPlaying():Bool {
        return backend.isEventInstancePlaying(SongEventInstance);
    }

    private function GetCurrentSongPath():String {
        return CurrentSong;
    }

    //// Sound effects

    private function PlaySoundOneShot(soundPath:String) {
        backend.createEventInstanceOneShot(soundPath);
    }

    private function PlaySoundWithReference(soundPath:String):String {
        var soundId = '${soundPath}-${soundIdIncrementer}';
        backend.createEventInstanceNamed(soundPath, soundId);
        cache.registerEventInstance(soundId, soundPath);
        soundIdIncrementer++;
        return soundId;
    }

    private function PlaySoundAndAssignId(soundPath:String, soundId:String):String {
        backend.createEventInstanceNamed(soundPath, soundId);
        cache.registerEventInstance(soundId, soundPath);
        return soundId;
    }

    public function IsSoundLoaded(soundId:String):Bool {
        // Check Haxe cache first, fall back to native for backwards compatibility
        if (cache.hasEventInstance(soundId)) {
            return true;
        }
        return backend.isEventInstanceLoaded(soundId);
    }

    public function IsSoundPlaying(soundId:String):Bool {
        return backend.isEventInstancePlaying(soundId);
    }

    private function StopSound(soundId:String) {
        backend.stopEventInstance(soundId);
    }

    private function StopSoundImmediately(soundId:String) {
        backend.stopEventInstanceImmediately(soundId);
    }

    private function PauseSound(soundId:String) {
        backend.setPauseOnEventInstance(soundId, true);
    }

    private function UnpauseSound(soundId:String) {
        backend.setPauseOnEventInstance(soundId, false);
    }

    private function ReleaseSound(soundId:String) {
        backend.releaseEventInstance(soundId);
        cache.unregisterEventInstance(soundId);
        callbackManager.unregisterCallback(soundId);
    }

    private function GetEventParameterOnSound(soundId:String, parameterName:String):Float {
        return backend.getEventInstanceParam(soundId, parameterName);
    }

    private function SetEventParameterOnSound(soundId:String, parameterName:String, parameterValue:Float) {
        backend.setEventInstanceParam(soundId, parameterName, parameterValue);
    }

    //// Callbacks

    private function RegisterCallbacksForSong(callback:Void->Void, playbackEventMask:UInt) {
        var eventPath = cache.getEventPath(SongEventInstance);
        if (eventPath == null) eventPath = CurrentSong;
        callbackManager.registerCallback(SongEventInstance, eventPath, callback, playbackEventMask);
        backend.setCallbackTrackingForEventInstance(SongEventInstance);
    }

    private function UnregisterCallbacksForSong() {
        callbackManager.unregisterCallback(SongEventInstance);
    }

    private function RegisterCallbacksForSound(soundId:String, callback:Void->Void, playbackEventMask:UInt) {
        var eventPath = cache.getEventPath(soundId);
        if (eventPath == null) eventPath = soundId;
        callbackManager.registerCallback(soundId, eventPath, callback, playbackEventMask);
        backend.setCallbackTrackingForEventInstance(soundId);
    }

    private function UnregisterCallbacksForSound(soundId:String) {
        callbackManager.unregisterCallback(soundId);
    }

    //// Utility

    private function RegisterEventListener(newEventListener:FmodEventListener) {
        eventListeners.push(newEventListener);
    }
}
