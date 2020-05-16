package haxefmod;

import haxefmod.HaxeFmod;
import haxefmod.FmodEvents.FmodCallback;
import haxefmod.FmodEvents.FmodEvent;
import haxefmod.FmodEvents.FmodEventListener;
import haxefmod.settings.Settings;

enum FmodManagerAction {
    NONE;
    STOP_CURRENT_SONG_AND_PLAY_TO_NEW_SONG;
}

class FmodManagerPrivate {
    // Main song
    private var CurrentSong:String;
    private var NextSong:String;
    private var PrimarySongEventInstanceName:String = "PrimarySongEventInstanceName";

    // Update actions
    private var CurrentAction:FmodManagerAction = NONE;

    // Events
    private var eventListeners:Array<FmodEventListener> = new Array();

    // Data
    private var soundIdIncrementer:Int;

    // Settings
    private var settings:FmodSettings;

    private static var instance:FmodManagerPrivate;

    private function new() {}

    private static function GetInstance():FmodManagerPrivate {
        if (instance == null) {
            instance = new FmodManagerPrivate();
            HaxeFmod.fmod_init(128);
            HaxeFmod.fmod_load_bank("assets/fmod/Desktop/Master.bank");
            HaxeFmod.fmod_load_bank("assets/fmod/Desktop/Master.strings.bank");
            instance.settings = Settings.LoadDefaultFmodSettings();
            if (instance.settings.DebugMessages) {
                instance.EnableDebugMessages();
            }
            // If the -debug flag is passed into the build, enable debug messages
            #if debug
            instance.EnableDebugMessages();
            #end
        }
        return instance;
    }

    //// System

    private function EnableDebugMessages() {
        HaxeFmod.fmod_set_debug(true);
    }

    private function Update() {
        HaxeFmod.fmod_update();

        // If transitioning songs, play the next song when the current one is stopped
        if (CurrentAction == STOP_CURRENT_SONG_AND_PLAY_TO_NEW_SONG
            && HaxeFmod.fmod_get_event_instance_playback_state(PrimarySongEventInstanceName) == FMOD_STUDIO_PLAYBACK_STOPPED) {
            PlaySong(NextSong);
            CurrentAction = NONE;
        }

        // Whenever a song stops, send out the event to any registered listeners
        if (HaxeFmod.fmod_check_for_primary_event_instance_callback(FmodCallback.STOPPED)) {
            for (eventListener in eventListeners) {
                eventListener.ReceiveEvent(FmodEvent.MUSIC_STOPPED);
            }
        }
    }

    //// Music

    private function PlaySong(songName:String) {
        if (songName == CurrentSong) {
            // If the song passed in is loaded, but not playing, start it again
            if (!HaxeFmod.fmod_is_event_instance_playing(PrimarySongEventInstanceName)) {
                HaxeFmod.fmod_play_event_instance(PrimarySongEventInstanceName);
            }
            return;
        }

        // If we are changing songs, make sure it is not playing, then release it from memory
        if (songName != CurrentSong && CurrentSong != null) {
            if (HaxeFmod.fmod_is_event_instance_playing(PrimarySongEventInstanceName)) {
                HaxeFmod.fmod_stop_event_instance(PrimarySongEventInstanceName, true);
            }
            HaxeFmod.fmod_release_event_instance(PrimarySongEventInstanceName);
        }

        // Create a brand new event instance of the song
        HaxeFmod.fmod_create_event_instance_named('event:/Music/${songName}', PrimarySongEventInstanceName);
        HaxeFmod.fmod_add_playback_listener_to_primary_event_instance(PrimarySongEventInstanceName);
        CurrentSong = songName;
    }

    private function PlaySongTransition(songName:String) {
        if (songName == CurrentSong) {
            // If the song passed in is loaded, but not playing, start it again
            if (!HaxeFmod.fmod_is_event_instance_playing(PrimarySongEventInstanceName)) {
                HaxeFmod.fmod_play_event_instance(PrimarySongEventInstanceName);
            }
            return;
        }

        // If we are changing songs, send a soft stop request to the event
        if (songName != CurrentSong && CurrentSong != null && HaxeFmod.fmod_is_event_instance_playing(PrimarySongEventInstanceName)) {
            HaxeFmod.fmod_stop_event_instance(PrimarySongEventInstanceName, false);
        }

        CurrentAction = STOP_CURRENT_SONG_AND_PLAY_TO_NEW_SONG;
        NextSong = songName;
    }

    private function StopSong() {
        HaxeFmod.fmod_stop_event_instance(PrimarySongEventInstanceName, false);
    }

    private function StopSongImmediately() {
        HaxeFmod.fmod_stop_event_instance(PrimarySongEventInstanceName, true);
    }

    private function PauseSong() {
        HaxeFmod.fmod_set_pause_on_event_instance(PrimarySongEventInstanceName, true);

        // Send additional update to FMOD to avoid dependency on main game loop
        HaxeFmod.fmod_update();
    }

    private function UnpauseSong() {
        HaxeFmod.fmod_set_pause_on_event_instance(PrimarySongEventInstanceName, false);
    }

    private function GetEventParameterOnSong(parameterName:String):Float {
        return HaxeFmod.fmod_get_event_instance_param(PrimarySongEventInstanceName, parameterName);
    }

    private function SetEventParameterOnSong(parameterName:String, parameterValue:Float) {
        HaxeFmod.fmod_set_event_instance_param(PrimarySongEventInstanceName, parameterName, parameterValue);
    }

    //// Sound effects

    private function PlaySoundOneShot(soundName:String) {
        HaxeFmod.fmod_create_event_instance_one_shot('event:/SFX/${soundName}');
    }

    private function PlaySoundWithReference(soundName:String):String {
        var soundId = '${soundName}-${soundIdIncrementer}';
        HaxeFmod.fmod_create_event_instance_named('event:/SFX/${soundName}', soundId);
        soundIdIncrementer++;
        return soundId;
    }

    private function StopSound(soundId:String) {
        HaxeFmod.fmod_stop_event_instance(soundId, false);
    }

    private function StopSoundImmediately(soundId:String) {
        HaxeFmod.fmod_stop_event_instance(soundId, true);
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
