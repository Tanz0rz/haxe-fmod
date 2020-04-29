package faxe;

import flixel.FlxState;
import faxe.Faxe;
import flixel.FlxG;

enum FaxeSoundHelperAction {
    NONE;
    STOPPING_SONG_AND_TRANSITIONING;
}

class FaxeSoundHelper {

    private var PrimarySongName:String;
    private var PrimarySongEventInstance:String = "PrimarySongEventInstance";

    private static var instance:FaxeSoundHelper;

    public var CurrentSong:String;

    public var CurrentAction:FaxeSoundHelperAction = NONE;
    public var DestinationState:FlxState;

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

    // This load-as-we-go approach may cause songs to have a slight delay while they are loaded into memory
    // It may make more sense to let all songs stay in memory and add an additional function to preload them
    // More testing is needed
    public function PlaySong(songName:String) {
        // If the song passed in is already playing, ignore the request
        if (songName == PrimarySongName && Faxe.fmod_is_event_playing(PrimarySongEventInstance)){
            return;
        }
        
        // If we are changing songs, stop the current one immediately and release it from memory
        if (songName != PrimarySongName && Faxe.fmod_is_event_loaded(PrimarySongEventInstance)){
            Faxe.fmod_stop_event(PrimarySongEventInstance, true);
            Faxe.fmod_release_event(PrimarySongEventInstance);
        }

        Faxe.fmod_load_event('event:/Music/${songName}', PrimarySongEventInstance);
        Faxe.fmod_play_event(PrimarySongEventInstance);
        PrimarySongName = songName;
    }

    // Need to add ability to validate a parameter exists first
    public function SetEventParameterOnSong(parameterName:String, parameterValue:Float){
        Faxe.fmod_set_event_param(PrimarySongEventInstance, parameterName, parameterValue);
    }

    public function PreloadSound(soundName:String) {
        Faxe.fmod_load_event('event:/SFX/${soundName}', soundName);
    }

    public function PlaySound(soundName:String) {
        if (!Faxe.fmod_is_event_loaded(soundName)) {
            Faxe.fmod_load_event('event:/SFX/${soundName}', soundName);
        }
        Faxe.fmod_play_event(soundName);
    }

    // Fadeouts can be added to songs in Fmod Studio via the AHDSR Modulation on the event's main fader
    public function TransitionToStateAndStopMusic(state:FlxState){
        if (Faxe.fmod_is_event_playing(PrimarySongEventInstance)) {
            Faxe.fmod_stop_event(PrimarySongEventInstance, false);
        }
        CurrentAction = STOPPING_SONG_AND_TRANSITIONING;
        DestinationState = state;
    }

    public function TransitionToState(state:FlxState){
        FlxG.switchState(state);
    }

    public function Update() {
        Faxe.fmod_update();
        FlxG.watch.addQuick("Current song name: ", PrimarySongName);
        FlxG.watch.addQuick("Current song status: ", FaxeEnums.EventPlaybackStateToString(Faxe.fmod_get_event_playback_state(PrimarySongEventInstance)));
        FlxG.watch.addQuick("Current action: ", CurrentAction);

        if (CurrentAction == STOPPING_SONG_AND_TRANSITIONING && Faxe.fmod_get_event_playback_state(PrimarySongEventInstance) == FMOD_STUDIO_PLAYBACK_STOPPED){
            FlxG.switchState(DestinationState);
            CurrentAction = NONE;
        }
    }
}
