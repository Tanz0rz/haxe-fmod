package faxe;

import flixel.FlxState;
import faxe.Faxe;
import flixel.FlxG;

enum FaxeSoundHelperAction {
    NONE;
    STOP_SONG_AND_TRANSITION_SCENES;
    STOP_CURRENT_SONG_AND_PLAY_TO_NEW_SONG;
}

class FaxeSoundHelper {

    public var CurrentSong:String;
    public var NextSong:String;
    private var PrimarySongEventInstance:String = "PrimarySongEventInstance";

    private static var instance:FaxeSoundHelper;


    public var CurrentAction:FaxeSoundHelperAction = NONE;
    public var DestinationState:FlxState;

    private var soundIdIncrementer:Int;

    private function new () {}

    public static function GetInstance():FaxeSoundHelper {
        if (instance == null) {
            instance = new FaxeSoundHelper();
            Faxe.fmod_init(128);
            Faxe.fmod_load_bank("assets/fmod/Desktop/Master.bank");
            Faxe.fmod_load_bank("assets/fmod/Desktop/Master.strings.bank");
        }
        return instance;
    }

    public function PlaySong(songName:String) {
        if (songName == CurrentSong){
            // If the song passed in is loaded, but not playing, start it again
            if (!Faxe.fmod_is_event_instance_playing(PrimarySongEventInstance)){
                Faxe.fmod_play_event_instance(PrimarySongEventInstance);
            } 
            return;
        }
        
        // If we are changing songs, make sure it is not playing, then release it from memory
        if (songName != CurrentSong && CurrentSong != null){
            if (Faxe.fmod_is_event_instance_playing(PrimarySongEventInstance)){
                Faxe.fmod_stop_event_instance(PrimarySongEventInstance, true);
            }
            Faxe.fmod_release_event_instance(PrimarySongEventInstance);
        }

        // Create a brand new event instance of the song
        Faxe.fmod_create_event_instance_named('event:/Music/${songName}', PrimarySongEventInstance);
        CurrentSong = songName;
    }

    // Fadeouts and fadeins can be added to songs in Fmod Studio via the AHDSR Modulation on the event's main fader
    public function PlaySongTransition(songName:String) {
        if (songName == CurrentSong){
            // If the song passed in is loaded, but not playing, start it again
            if (!Faxe.fmod_is_event_instance_playing(PrimarySongEventInstance)){
                Faxe.fmod_play_event_instance(PrimarySongEventInstance);
            }
            return;
        }

        // If we are changing songs, send a soft stop request to the event
        if (songName != CurrentSong && CurrentSong != null && Faxe.fmod_is_event_instance_playing(PrimarySongEventInstance)) {
            Faxe.fmod_stop_event_instance(PrimarySongEventInstance, false);
        }

        CurrentAction = STOP_CURRENT_SONG_AND_PLAY_TO_NEW_SONG;
        NextSong = songName;
    }

    public function StopSong(){
        Faxe.fmod_stop_event_instance(PrimarySongEventInstance, true);
    }

    public function PauseSong() {
        Faxe.fmod_set_pause_on_event_instance(PrimarySongEventInstance, true);

        // Send additional update to FMOD to avoid dependency on main game loop
		Faxe.fmod_update();
    }

    public function UnpauseSong() {
		Faxe.fmod_set_pause_on_event_instance(PrimarySongEventInstance, false);
    }

    // Need to add ability to validate a parameter exists first
    public function SetEventParameterOnSong(parameterName:String, parameterValue:Float){
        Faxe.fmod_set_event_instance_param(PrimarySongEventInstance, parameterName, parameterValue);
    }

    /**
        Plays a sound in a fire-and-forget fashion.
        Follows the rules set in the Event's settings in FMOD Studio
        Do not play a looping sound effect with this call
    **/
    public function PlaySoundOneShot(soundName:String) {
        if (!Faxe.fmod_is_event_description_loaded(soundName)) {
            Faxe.fmod_load_event_description('event:/SFX/${soundName}', soundName);
        }
        Faxe.fmod_create_event_instance_one_shot(soundName);
    }

    /**
        Plays a sound that can be stopped, paused, and restarted using the returned sound Id
        Parameters can be passed to the sound using the sound name as the reference
        If you would like an explicit handle to the sound event, use PlaySoundWithHandle
    **/
    public function PlaySound(soundName:String):String {
        var soundId = '${soundName}-${soundIdIncrementer}';
        Faxe.fmod_create_event_instance_named('event:/SFX/${soundName}', soundId);
        soundIdIncrementer++;
        return soundId;
    }

    public function StopSound(soundId:String){
        Faxe.fmod_stop_event_instance(soundId, false);
    }

    public function StopSoundImmediately(soundId:String){
        Faxe.fmod_stop_event_instance(soundId, true);
    }

    // Fadeouts can be added to songs in Fmod Studio via the AHDSR Modulation on the event's main fader
    public function TransitionToStateAndStopMusic(state:FlxState){
        if (Faxe.fmod_is_event_instance_loaded(PrimarySongEventInstance) && Faxe.fmod_is_event_instance_playing(PrimarySongEventInstance)) {
            Faxe.fmod_stop_event_instance(PrimarySongEventInstance, false);
        }
        CurrentAction = STOP_SONG_AND_TRANSITION_SCENES;
        DestinationState = state;
    }

    // Adding this in so the caller can keep their transition calls consistent
    // Note: This will leave the current music playing
    public function TransitionToState(state:FlxState){
        FlxG.switchState(state);
    }

    public function Update() {
        Faxe.fmod_update();

        FlxG.watch.addQuick("Current song name: ", CurrentSong);
        if (Faxe.fmod_is_event_instance_loaded(PrimarySongEventInstance)){
            FlxG.watch.addQuick("Current song status: ", FaxeEnums.EventPlaybackStateToString(Faxe.fmod_get_event_instance_playback_state(PrimarySongEventInstance)));
        } 
        FlxG.watch.addQuick("Current action: ", CurrentAction);

        if (CurrentAction == STOP_SONG_AND_TRANSITION_SCENES && Faxe.fmod_get_event_instance_playback_state(PrimarySongEventInstance) == FMOD_STUDIO_PLAYBACK_STOPPED){
            FlxG.switchState(DestinationState);
            CurrentAction = NONE;
        } else if (CurrentAction == STOP_CURRENT_SONG_AND_PLAY_TO_NEW_SONG && Faxe.fmod_get_event_instance_playback_state(PrimarySongEventInstance) == FMOD_STUDIO_PLAYBACK_STOPPED){
            PlaySong(NextSong);
            CurrentAction = NONE;
        }
    }
}
