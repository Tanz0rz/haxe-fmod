package haxefmod;

import haxefmod.FmodEvents.FmodCallback;
import haxefmod.FmodEvents.FmodEvent;
import haxefmod.FmodEvents.FmodEventListener;
import haxefmod.HaxeFmod;
import haxefmod.settings.Settings;

enum FmodManagerAction {
    NONE;
    STOP_CURRENT_SONG_AND_PLAY_NEW_SONG;
}

class FmodManagerPrivate {
    // Main song
    private var CurrentSong:String;
    private var NextSong:String;
    private var SongEventInstance:String = "SongEventInstance";

    // Update actions
    private var CurrentAction:FmodManagerAction = NONE;

    // Events
    private var eventListeners:Array<FmodEventListener> = new Array();

    // Data
    private var soundIdIncrementer:Int = 0;
    private var lastUpdateCall:Float = 0;

    // Settings
    private var settings:FmodSettings;

    private static var instance:FmodManagerPrivate;

    private function new() {}

    private static function GetInstance():FmodManagerPrivate {
        if (instance == null) {
            instance = new FmodManagerPrivate();
            
            instance.settings = Settings.LoadDefaultFmodSettings();
            if (instance.settings.DebugMessages) {
                HaxeFmod.fmod_set_debug(true);
            }
            // If the -debug flag is passed into the build, enable debug messages
            #if debug
            HaxeFmod.fmod_set_debug(true);
            #end

            HaxeFmod.fmod_init(128);
            // For html5 deployments, the banks must be loaded from inside the javascript fmod_init() call
            #if windows
            HaxeFmod.fmod_load_bank("assets/fmod/Desktop/Master.bank");
            HaxeFmod.fmod_load_bank("assets/fmod/Desktop/Master.strings.bank");
            #end
        }
        return instance;
    }

    //// System

    private function EnableDebugMessages() {
        HaxeFmod.fmod_set_debug(true);
    }

    private function IsInitialized():Bool {
        return HaxeFmod.fmod_is_initialized();
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

        // If transitioning songs, play the next song when the current one is stopped
        if (CurrentAction == STOP_CURRENT_SONG_AND_PLAY_NEW_SONG
            && HaxeFmod.fmod_get_event_instance_playback_state(SongEventInstance) == FMOD_STUDIO_PLAYBACK_STOPPED) {
            PlaySong(NextSong);
            CurrentAction = NONE;
        }

        // Whenever a song stops, send out the event to any registered listeners
        if (HaxeFmod.fmod_check_playback_callbacks(FmodCallback.STOPPED)) {
            for (eventListener in eventListeners) {
                eventListener.ReceiveEvent(FmodEvent.MUSIC_STOPPED);
            }
        }
    }

    //// Music

    private function PlaySong(songPath:String) {
        if (songPath == CurrentSong) {
            // If the song passed in is loaded, but not playing, start it again
            if (!HaxeFmod.fmod_is_event_instance_playing(SongEventInstance)) {
                HaxeFmod.fmod_play_event_instance(SongEventInstance);
            }
            return;
        }

        // If we are changing songs, make sure it is not playing, then release it from memory
        if (songPath != CurrentSong && CurrentSong != null) {
            if (HaxeFmod.fmod_is_event_instance_playing(SongEventInstance)) {
                HaxeFmod.fmod_stop_event_instance_immediately(SongEventInstance);
            }
            // Releasing the primary song event instance is causing issues on html5 deployments
            // HaxeFmod.fmod_release_event_instance(SongEventInstance);
        }

        // Create a brand new event instance of the song
        HaxeFmod.fmod_create_event_instance_named(songPath, SongEventInstance);
        HaxeFmod.fmod_set_playback_callback_tracking_for_event_instance(SongEventInstance);
        CurrentSong = songPath;
    }

    private function PlaySongTransition(songPath:String) {
        if (songPath == CurrentSong) {
            // If the song passed in is loaded, but not playing, start it again
            if (!HaxeFmod.fmod_is_event_instance_playing(SongEventInstance)) {
                HaxeFmod.fmod_play_event_instance(SongEventInstance);
            }
            return;
        }

        // If we are changing songs, send a soft stop request to the event
        if (songPath != CurrentSong && CurrentSong != null && HaxeFmod.fmod_is_event_instance_playing(SongEventInstance)) {
            HaxeFmod.fmod_stop_event_instance(SongEventInstance);
        }

        CheckIfUpdateIsBeingCalled();
        CurrentAction = STOP_CURRENT_SONG_AND_PLAY_NEW_SONG;
        NextSong = songPath;
    }

    private function StopSong() {
        HaxeFmod.fmod_stop_event_instance(SongEventInstance);
    }

    private function StopSongImmediately() {
        HaxeFmod.fmod_stop_event_instance_immediately(SongEventInstance);
    }

    private function PauseSong() {
        HaxeFmod.fmod_set_pause_on_event_instance(SongEventInstance, true);

        // Send additional update to FMOD to avoid dependency on main game loop
        HaxeFmod.fmod_update();
    }

    private function UnpauseSong() {
        HaxeFmod.fmod_set_pause_on_event_instance(SongEventInstance, false);
    }

    private function GetEventParameterOnSong(parameterName:String):Float {
        return HaxeFmod.fmod_get_event_instance_param(SongEventInstance, parameterName);
    }

    private function SetEventParameterOnSong(parameterName:String, parameterValue:Float) {
        HaxeFmod.fmod_set_event_instance_param(SongEventInstance, parameterName, parameterValue);
    }

    //// Sound effects

    private function PlaySoundOneShot(soundPath:String) {
        HaxeFmod.fmod_create_event_instance_one_shot(soundPath);
    }

    private function PlaySoundWithReference(soundPath:String):String {
        var soundId = '${soundPath}-${soundIdIncrementer}';
        HaxeFmod.fmod_create_event_instance_named(soundPath, soundId);
        soundIdIncrementer++;
        return soundId;
    }

    private function StopSound(soundId:String) {
        HaxeFmod.fmod_stop_event_instance(soundId);
    }

    private function StopSoundImmediately(soundId:String) {
        HaxeFmod.fmod_stop_event_instance_immediately(soundId);
    }

    private function ReleaseSound(soundId:String) {
        HaxeFmod.fmod_release_event_instance(soundId);
    }

    private function GetEventParameterOnSound(soundId:String, parameterName:String):Float {
        return HaxeFmod.fmod_get_event_instance_param(soundId, parameterName);
    }

    private function SetEventParameterOnSound(soundId:String, parameterName:String, parameterValue:Float) {
        HaxeFmod.fmod_set_event_instance_param(soundId, parameterName, parameterValue);
    }

    //// Utility

    private function RegisterEventListener(newEventListener:FmodEventListener) {
        eventListeners.push(newEventListener);
    }
}
