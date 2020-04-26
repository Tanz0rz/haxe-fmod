package faxe;

import flixel.FlxG;

class FaxeSoundHelper {

    private var PrimarySong:String = "PrimarySong";
    private var PrimarySongName:String = "PrimarySong";

    private static var instance:FaxeSoundHelper;

    public var CurrentSong:String;

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
        if (Faxe.fmod_is_event_playing(PrimarySong) && songName == PrimarySongName){
            return;
        }

        Faxe.fmod_load_event('event:/Music/${songName}', PrimarySong);
		Faxe.fmod_play_event(PrimarySong);
        PrimarySongName = songName;
    }

    public function Update() {
        Faxe.fmod_update();
        FlxG.watch.addQuick("Current song name: ", PrimarySongName);
        FlxG.watch.addQuick("Current song status: ", Faxe.fmod_get_event_playback_state(PrimarySong));
    }
}