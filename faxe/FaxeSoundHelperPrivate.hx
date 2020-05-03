package faxe;

import flixel.FlxState;
import faxe.Faxe;
import flixel.FlxG;

enum FaxeSoundHelperAction {
    NONE;
    STOP_SONG_AND_TRANSITION_SCENES;
    STOP_CURRENT_SONG_AND_PLAY_TO_NEW_SONG;
}

class FaxeSoundHelperPrivate {

    // Main song
    private var CurrentSong:String;
    private var NextSong:String;
    private var PrimarySongEventInstanceName:String = "PrimarySongEventInstanceName";

    // Update actions
    private var CurrentAction:FaxeSoundHelperAction = NONE;
    private var DestinationState:FlxState;

    // Data
    private var soundIdIncrementer:Int;

    private static var instance:FaxeSoundHelperPrivate;
    private function new () {}
    private static function GetInstance():FaxeSoundHelperPrivate {
        if (instance == null) {
            instance = new FaxeSoundHelperPrivate();
            Faxe.fmod_init(128);
            Faxe.fmod_load_bank("assets/fmod/Desktop/Master.bank");
            Faxe.fmod_load_bank("assets/fmod/Desktop/Master.strings.bank");
        }
        return instance;
    }

    private function PlaySongPrivate(songName:String) {
        if (songName == CurrentSong){
            // If the song passed in is loaded, but not playing, start it again
            if (!Faxe.fmod_is_event_instance_playing(PrimarySongEventInstanceName)){
                Faxe.fmod_play_event_instance(PrimarySongEventInstanceName);
            } 
            return;
        }
        
        // If we are changing songs, make sure it is not playing, then release it from memory
        if (songName != CurrentSong && CurrentSong != null){
            if (Faxe.fmod_is_event_instance_playing(PrimarySongEventInstanceName)){
                Faxe.fmod_stop_event_instance(PrimarySongEventInstanceName, true);
            }
            Faxe.fmod_release_event_instance(PrimarySongEventInstanceName);
        }

        // Create a brand new event instance of the song
        Faxe.fmod_create_event_instance_named('event:/Music/${songName}', PrimarySongEventInstanceName);
        CurrentSong = songName;
    }

    private function PlaySongTransitionPrivate(songName:String) {
        if (songName == CurrentSong){
            // If the song passed in is loaded, but not playing, start it again
            if (!Faxe.fmod_is_event_instance_playing(PrimarySongEventInstanceName)){
                Faxe.fmod_play_event_instance(PrimarySongEventInstanceName);
            }
            return;
        }

        // If we are changing songs, send a soft stop request to the event
        if (songName != CurrentSong && CurrentSong != null && Faxe.fmod_is_event_instance_playing(PrimarySongEventInstanceName)) {
            Faxe.fmod_stop_event_instance(PrimarySongEventInstanceName, false);
        }

        CurrentAction = STOP_CURRENT_SONG_AND_PLAY_TO_NEW_SONG;
        NextSong = songName;
    }
    
    private function StopSongPrivate(){
        Faxe.fmod_stop_event_instance(PrimarySongEventInstanceName, true);
    }

    private function PauseSongPrivate() {
        Faxe.fmod_set_pause_on_event_instance(PrimarySongEventInstanceName, true);

        // Send additional update to FMOD to avoid dependency on main game loop
		Faxe.fmod_update();
    }

    private function UnpauseSongPrivate() {
		Faxe.fmod_set_pause_on_event_instance(PrimarySongEventInstanceName, false);
    }

    private function SetEventParameterOnSongPrivate(parameterName:String, parameterValue:Float){
        Faxe.fmod_set_event_instance_param(PrimarySongEventInstanceName, parameterName, parameterValue);
    }

    private function PlaySoundOneShotPrivate(soundName:String) {
        Faxe.fmod_create_event_instance_one_shot('event:/SFX/${soundName}');
    }

    private function PlaySoundPrivate(soundName:String):String {
        var soundId = '${soundName}-${soundIdIncrementer}';
        Faxe.fmod_create_event_instance_named('event:/SFX/${soundName}', soundId);
        soundIdIncrementer++;
        return soundId;
    }

    private function StopSoundPrivate(soundId:String){
        Faxe.fmod_stop_event_instance(soundId, false);
    }

    private function StopSoundImmediatelyPrivate(soundId:String){
        Faxe.fmod_stop_event_instance(soundId, true);
    }

    private function TransitionToStateAndStopMusicPrivate(state:FlxState){
        if (Faxe.fmod_is_event_instance_loaded(PrimarySongEventInstanceName) && Faxe.fmod_is_event_instance_playing(PrimarySongEventInstanceName)) {
            Faxe.fmod_stop_event_instance(PrimarySongEventInstanceName, false);
        }
        CurrentAction = STOP_SONG_AND_TRANSITION_SCENES;
        DestinationState = state;
    }

    private function TransitionToStatePrivate(state:FlxState){
        FlxG.switchState(state);
    }

    private function UpdatePrivate() {
        Faxe.fmod_update();

        FlxG.watch.addQuick("Current song name: ", CurrentSong);
        if (Faxe.fmod_is_event_instance_loaded(PrimarySongEventInstanceName)){
            FlxG.watch.addQuick("Current song status: ", FaxeEnums.EventPlaybackStateToString(Faxe.fmod_get_event_instance_playback_state(PrimarySongEventInstanceName)));
        } 
        FlxG.watch.addQuick("Current action: ", CurrentAction);

        if (CurrentAction == STOP_SONG_AND_TRANSITION_SCENES && Faxe.fmod_get_event_instance_playback_state(PrimarySongEventInstanceName) == FMOD_STUDIO_PLAYBACK_STOPPED){
            FlxG.switchState(DestinationState);
            CurrentAction = NONE;
        } else if (CurrentAction == STOP_CURRENT_SONG_AND_PLAY_TO_NEW_SONG && Faxe.fmod_get_event_instance_playback_state(PrimarySongEventInstanceName) == FMOD_STUDIO_PLAYBACK_STOPPED){
            PlaySongPrivate(NextSong);
            CurrentAction = NONE;
        }
    }
}
