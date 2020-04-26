package faxe;

import flixel.FlxState;
import faxe.Faxe;
import flixel.FlxG;


enum FaxeSoundHelperAction {
    NOTHING;
    STOPPING_SONG_AND_TRANSITIONING;
}

class FaxeSoundHelper {

    private var PrimarySongName:String;
    private var PrimarySongEventInstance:String = "PrimarySongEventInstance";

    private static var instance:FaxeSoundHelper;

    public var CurrentSong:String;

    public var CurrentAction:FaxeSoundHelperAction = NOTHING;
    public var DestinationState:FlxState;

    private function new () {}

    public static function GetInstance():FaxeSoundHelper {
        if (instance == null) {
            instance = new FaxeSoundHelper();
            Faxe.fmod_init(128);
            Faxe.fmod_load_bank("./Master Bank.bank");
            Faxe.fmod_load_bank("./Master Bank.strings.bank");
            // FlxG.watch.add(this, "CurrentSong", "Current song: ");
        }
        return instance;
    }

    public function PlaySong(songName:String) {
        // If the song passed in is already playing, ignore the request
        if (Faxe.fmod_is_event_playing(PrimarySongEventInstance) && songName == PrimarySongName){
            return;
        }

        Faxe.fmod_load_event('event:/Music/${songName}', PrimarySongEventInstance);
		Faxe.fmod_play_event(PrimarySongEventInstance);
        PrimarySongName = songName;
    }

    // Fadeouts can be added to songs in Fmod Studio via the AHDSR Modulation on the event's main fader
    public function TransitionToStateAndStopMusic(state:FlxState){
        if (Faxe.fmod_is_event_playing(PrimarySongEventInstance)) {
            Faxe.fmod_stop_event(PrimarySongEventInstance, false);
        }
        CurrentAction = STOPPING_SONG_AND_TRANSITIONING;
        DestinationState = state;
    }

    public function Update() {
        Faxe.fmod_update();
        FlxG.watch.addQuick("Current song name: ", PrimarySongName);
        FlxG.watch.addQuick("Current song status: ", FaxeEnums.EventPlaybackStateToString(Faxe.fmod_get_event_playback_state(PrimarySongEventInstance)));
        FlxG.watch.addQuick("Current action: ", CurrentAction);

        if (CurrentAction == STOPPING_SONG_AND_TRANSITIONING && Faxe.fmod_get_event_playback_state(PrimarySongEventInstance) == FMOD_STUDIO_PLAYBACK_STOPPED){
            FlxG.switchState(DestinationState);
            CurrentAction = NOTHING;
        }
    }
}