package haxefmod;

import haxefmod.FmodEvents.FmodCallback;
import haxefmod.FmodEvents.FmodEvent;
import haxefmod.FmodEvents.FmodEventListener;
import haxefmod.backends.IFmodBackend;
import haxefmod.backends.IFmodBackend.FmodEventHandle;
import haxefmod.runtime.CallbackDispatcher;
import haxefmod.studio.Callbacks;
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

    // Main song
    private var CurrentSong:String = "";
    private var NextSong:String;
    private var SongEventInstance:String = "SongEventInstance";

    // Events
    private var eventListeners:Array<FmodEventListener> = new Array();

    // Data
    private var soundIdIncrementer:Int = 0;
    private var lastUpdateCall:Float = 0;

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
    }

    private static function GetInstance():FmodManagerPrivate {
        if (instance == null) {
            instance = new FmodManagerPrivate();

            // If the -debug flag is passed into the build, enable debug messages
            #if debug
            instance.backend.setDebug(true);
            #end

            instance.backend.init(128);

            // Enable auto-update by default so FMOD processes changes even when game loop is paused
            // (JS/HTML5 enables this in jaxe.js onRuntimeInitialized)
            #if (cpp || hl)
            instance.backend.setAutoUpdate(true);
            #end

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

    //// Helper: resolve name to handle

    private inline function getHandle(instanceName:String):FmodEventHandle {
        return cache.getHandle(instanceName);
    }

    //// System

    private function EnableDebugMessages() {
        backend.setDebug(true);
    }

    private function IsInitialized():Bool {
        return backend.isInitialized();
    }

    private function SetAutoUpdate(enabled:Bool) {
        backend.setAutoUpdate(enabled);
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

        // Drain the native callback queue and dispatch typed callbacks
        CallbackDispatcher.update();
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

    //// Bus

    private function SetBusVolume(busPath:String, volume:Float) {
        backend.setBusVolume(busPath, volume);
    }

    private function GetBusVolume(busPath:String):Float {
        return backend.getBusVolume(busPath);
    }

    private function SetBusMute(busPath:String, mute:Bool) {
        backend.setBusMute(busPath, mute);
    }

    private function GetBusMute(busPath:String):Bool {
        return backend.getBusMute(busPath);
    }

    //// Music

    private function PlaySong(songPath:String) {
        // Clear out any callbacks when immediately playing a song
        UnregisterCallbacksForSound(SongEventInstance);

        var handle = getHandle(SongEventInstance);

        if (songPath == CurrentSong && handle != FmodCache.INVALID_HANDLE) {
            // If the song passed in is loaded, but not playing, start it again
            if (!backend.isEventInstancePlaying(handle)) {
                backend.playEventInstance(handle);
            }
            return;
        }

        // If we are changing songs, make sure it is not playing, then release it from memory
        if (songPath != CurrentSong && CurrentSong != null && handle != FmodCache.INVALID_HANDLE) {
            if (backend.isEventInstancePlaying(handle)) {
                backend.stopEventInstanceImmediately(handle);
            }
            // Releasing the primary song event instance is causing issues on html5 deployments
            // backend.releaseEventInstance(handle);
            // cache.unregisterEventInstance(SongEventInstance);
        }

        // Create a brand new event instance of the song
        var newHandle = backend.createEventInstance(songPath);
        if (newHandle != FmodCache.INVALID_HANDLE) {
            cache.registerEventInstance(SongEventInstance, songPath, newHandle);
            CurrentSong = songPath;
        }
    }

    private function PlaySongTransition(songPath:String) {
        var handle = getHandle(SongEventInstance);

        if (songPath == CurrentSong && handle != FmodCache.INVALID_HANDLE) {
            // If the song passed in is loaded, but not playing, start it again
            if (!backend.isEventInstancePlaying(handle)) {
                backend.playEventInstance(handle);
            }
            return;
        }

        // If we are changing songs, send a soft stop request to the event
        if (songPath != CurrentSong && CurrentSong != null && handle != FmodCache.INVALID_HANDLE) {
            if (backend.isEventInstancePlaying(handle)) {
                backend.stopEventInstance(handle);
            }
        }

        CheckIfUpdateIsBeingCalled();
        NextSong = songPath;
        RegisterCallbacksForSound(SongEventInstance, () -> {
            PlaySong(NextSong);
        }, FmodCallback.STOPPED);
    }

    private function StopSong() {
        var handle = getHandle(SongEventInstance);
        if (handle != FmodCache.INVALID_HANDLE) {
            backend.stopEventInstance(handle);
        }
    }

    private function StopSongImmediately() {
        var handle = getHandle(SongEventInstance);
        if (handle != FmodCache.INVALID_HANDLE) {
            backend.stopEventInstanceImmediately(handle);
        }
    }

    private function PauseSong() {
        var handle = getHandle(SongEventInstance);
        if (handle != FmodCache.INVALID_HANDLE) {
            backend.setPauseOnEventInstance(handle, true);
            // Send additional update to FMOD to avoid dependency on main game loop
            backend.update();
        }
    }

    private function UnpauseSong() {
        var handle = getHandle(SongEventInstance);
        if (handle != FmodCache.INVALID_HANDLE) {
            backend.setPauseOnEventInstance(handle, false);
        }
    }

    private function ClearAllCallbacks() {
        CallbackDispatcher.clearAll();
    }

    private function GetEventParameterOnSong(parameterName:String):Float {
        var handle = getHandle(SongEventInstance);
        if (handle != FmodCache.INVALID_HANDLE) {
            return backend.getEventInstanceParam(handle, parameterName);
        }
        return 0.0;
    }

    private function SetEventParameterOnSong(parameterName:String, parameterValue:Float) {
        var handle = getHandle(SongEventInstance);
        if (handle != FmodCache.INVALID_HANDLE) {
            backend.setEventInstanceParam(handle, parameterName, parameterValue);
        }
    }

    private function IsSongPlaying():Bool {
        var handle = getHandle(SongEventInstance);
        if (handle != FmodCache.INVALID_HANDLE) {
            return backend.isEventInstancePlaying(handle);
        }
        return false;
    }

    private function GetCurrentSongPath():String {
        return CurrentSong;
    }

    private function GetSongTimelinePosition():Int {
        var handle = getHandle(SongEventInstance);
        if (handle != FmodCache.INVALID_HANDLE) {
            return backend.getTimelinePosition(handle);
        }
        return 0;
    }

    //// Sound effects

    private function PlaySoundOneShot(soundPath:String) {
        backend.createEventInstanceOneShot(soundPath);
    }

    private function PlaySoundWithReference(soundPath:String):String {
        var soundId = '${soundPath}-${soundIdIncrementer}';
        var handle = backend.createEventInstance(soundPath);
        if (handle != FmodCache.INVALID_HANDLE) {
            cache.registerEventInstance(soundId, soundPath, handle);
            soundIdIncrementer++;
            return soundId;
        }
        return "";
    }

    private function PlaySoundAndAssignId(soundPath:String, soundId:String):String {
        var handle = backend.createEventInstance(soundPath);
        if (handle != FmodCache.INVALID_HANDLE) {
            cache.registerEventInstance(soundId, soundPath, handle);
            return soundId;
        }
        return "";
    }

    public function IsSoundLoaded(soundId:String):Bool {
        return cache.hasEventInstance(soundId);
    }

    public function IsSoundPlaying(soundId:String):Bool {
        var handle = getHandle(soundId);
        if (handle != FmodCache.INVALID_HANDLE) {
            return backend.isEventInstancePlaying(handle);
        }
        return false;
    }

    private function StopSound(soundId:String) {
        var handle = getHandle(soundId);
        if (handle != FmodCache.INVALID_HANDLE) {
            backend.stopEventInstance(handle);
        }
    }

    private function StopSoundImmediately(soundId:String) {
        var handle = getHandle(soundId);
        if (handle != FmodCache.INVALID_HANDLE) {
            backend.stopEventInstanceImmediately(handle);
        }
    }

    private function PauseSound(soundId:String) {
        var handle = getHandle(soundId);
        if (handle != FmodCache.INVALID_HANDLE) {
            backend.setPauseOnEventInstance(handle, true);
        }
    }

    private function UnpauseSound(soundId:String) {
        var handle = getHandle(soundId);
        if (handle != FmodCache.INVALID_HANDLE) {
            backend.setPauseOnEventInstance(handle, false);
        }
    }

    private function ReleaseSound(soundId:String) {
        var handle = getHandle(soundId);
        if (handle != FmodCache.INVALID_HANDLE) {
            CallbackDispatcher.remove(handle);
            backend.releaseEventInstance(handle);
        }
        cache.unregisterEventInstance(soundId);
    }

    private function GetEventParameterOnSound(soundId:String, parameterName:String):Float {
        var handle = getHandle(soundId);
        if (handle != FmodCache.INVALID_HANDLE) {
            return backend.getEventInstanceParam(handle, parameterName);
        }
        return 0.0;
    }

    private function SetEventParameterOnSound(soundId:String, parameterName:String, parameterValue:Float) {
        var handle = getHandle(soundId);
        if (handle != FmodCache.INVALID_HANDLE) {
            backend.setEventInstanceParam(handle, parameterName, parameterValue);
        }
    }

    //// Callbacks

    private function RegisterCallbacksForSong(callback:Void->Void, playbackEventMask:UInt) {
        var handle = getHandle(SongEventInstance);
        if (handle == FmodCache.INVALID_HANDLE) return;
        CallbackDispatcher.setCallback(handle, _ -> callback(), playbackEventMask);
    }

    private function UnregisterCallbacksForSong() {
        CallbackDispatcher.remove(getHandle(SongEventInstance));
    }

    private function RegisterCallbacksForSound(soundId:String, callback:Void->Void, playbackEventMask:UInt) {
        var handle = getHandle(soundId);
        if (handle == FmodCache.INVALID_HANDLE) return;
        CallbackDispatcher.setCallback(handle, _ -> callback(), playbackEventMask);
    }

    private function UnregisterCallbacksForSound(soundId:String) {
        CallbackDispatcher.remove(getHandle(soundId));
    }

    /**
     * Registers a typed payload-carrying callback on the current song
     * instance (timeline beats, markers, playback lifecycle).
     */
    private function OnSongEvent(handler:EventCallbackData->Void, ?playbackEventMask:Int) {
        var handle = getHandle(SongEventInstance);
        if (handle == FmodCache.INVALID_HANDLE) return;
        CallbackDispatcher.setCallback(handle, handler, playbackEventMask);
    }

    //// Utility

    private function RegisterEventListener(newEventListener:FmodEventListener) {
        eventListeners.push(newEventListener);
    }
}
