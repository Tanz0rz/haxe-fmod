package faxe;

import faxe.FaxeEventListener.FaxeEvent;
//TODO understand why this import looks like this
import faxe.FaxeEventListener.FaxeCallback;
import faxe.Faxe;

enum FaxeSoundHelperAction {
    NONE;
    STOP_CURRENT_SONG_AND_PLAY_TO_NEW_SONG;
}

class FaxeSoundHelperPrivate {

    // Main song
    private var CurrentSong:String;
    private var NextSong:String;
    private var PrimarySongEventInstanceName:String = "PrimarySongEventInstanceName";

    // Update actions
    private var CurrentAction:FaxeSoundHelperAction = NONE;

    // Events
    // currently can only handle one event listener, but this will become a list soon
    private var eventListeners:Array<FaxeEventListener> = new Array();

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

    //// Music

    private function PlaySong(songName:String) {
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
        Faxe.fmod_add_playback_listener_to_primary_event_instance(PrimarySongEventInstanceName);
        CurrentSong = songName;
    }

    private function PlaySongTransition(songName:String) {
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
    
    private function StopSong(){
        Faxe.fmod_stop_event_instance(PrimarySongEventInstanceName, false);
    }
    
    private function StopSongImmediately(){
        Faxe.fmod_stop_event_instance(PrimarySongEventInstanceName, true);
    }

    private function PauseSong() {
        Faxe.fmod_set_pause_on_event_instance(PrimarySongEventInstanceName, true);

        // Send additional update to FMOD to avoid dependency on main game loop
        Faxe.fmod_update();
    }

    private function UnpauseSong() {
		Faxe.fmod_set_pause_on_event_instance(PrimarySongEventInstanceName, false);
    }

    private function GetEventParameterOnSong(parameterName:String):Float{
        return Faxe.fmod_get_event_instance_param(PrimarySongEventInstanceName, parameterName);
    }

    private function SetEventParameterOnSong(parameterName:String, parameterValue:Float){
        Faxe.fmod_set_event_instance_param(PrimarySongEventInstanceName, parameterName, parameterValue);
    }

    //// Sound effects
  
    private function PlaySoundOneShot(soundName:String) {
        Faxe.fmod_create_event_instance_one_shot('event:/SFX/${soundName}');
    }

    private function PlaySound(soundName:String):String {
        var soundId = '${soundName}-${soundIdIncrementer}';
        Faxe.fmod_create_event_instance_named('event:/SFX/${soundName}', soundId);
        soundIdIncrementer++;
        return soundId;
    }

    private function StopSound(soundId:String){
        Faxe.fmod_stop_event_instance(soundId, false);
    }

    private function StopSoundImmediately(soundId:String){
        Faxe.fmod_stop_event_instance(soundId, true);
    }

    private function GetEventParameterOnSound(soundId:String, parameterName:String):Float{
        return Faxe.fmod_get_event_instance_param(soundId, parameterName);
    }

    private function SetEventParameterOnSound(soundId:String, parameterName:String, parameterValue:Float){
        Faxe.fmod_set_event_instance_param(soundId, parameterName, parameterValue);
    }

    //// Utility

    private function RegisterEventListener(newEventListener:FaxeEventListener) {
        eventListeners.push(newEventListener);
    }

    //// System

    private function Update() {
        Faxe.fmod_update();

        if (CurrentAction == STOP_CURRENT_SONG_AND_PLAY_TO_NEW_SONG && Faxe.fmod_get_event_instance_playback_state(PrimarySongEventInstanceName) == FMOD_STUDIO_PLAYBACK_STOPPED){
            PlaySong(NextSong);
            CurrentAction = NONE;
        }

        if (Faxe.fmod_check_for_primary_event_instance_callback(FaxeCallback.STOPPED)) {
            for (eventListener in eventListeners) {
                eventListener.ReceiveEvent(FaxeEvent.MUSIC_STOPPED);
            }
        }
    }
}