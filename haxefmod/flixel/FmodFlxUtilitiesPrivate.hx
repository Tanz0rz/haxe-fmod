package haxefmod.flixel;

import haxefmod.FmodEvents.FmodEvent;
import haxefmod.FmodEvents.FmodEventListener;
import haxefmod.FmodManagerPrivate;
import flixel.FlxG;
import flixel.FlxState;

class FmodFlxUtilitiesPrivate implements FmodEventListener {
    private var DestinationState:FlxState;
    private var listeningForMusicStoppedEvent:Bool;

    private static var instance:FmodFlxUtilitiesPrivate;

    private function new() {}

    private static function GetInstance():FmodFlxUtilitiesPrivate {
        if (instance == null) {
            instance = new FmodFlxUtilitiesPrivate();
            FmodManager.RegisterEventListener(instance);
        }
        return instance;
    }

    private function TransitionToStateAndStopMusic(state:FlxState) {
        if (!FmodManager.IsSongPlaying()) {
            FlxG.switchState(state);
            return;
        }

        FmodManager.CheckIfUpdateIsBeingCalled();
        
        listeningForMusicStoppedEvent = true;
        DestinationState = state;
        FmodManager.StopSong();
    }

    private function TransitionToState(state:FlxState) {
        FlxG.switchState(state);
    }

    public function ReceiveEvent(faxeEvent:FmodEvent) {
        if (listeningForMusicStoppedEvent && faxeEvent == FmodEvent.MUSIC_STOPPED) {
            FlxG.switchState(DestinationState);
            listeningForMusicStoppedEvent = false;
        }
    }
}
