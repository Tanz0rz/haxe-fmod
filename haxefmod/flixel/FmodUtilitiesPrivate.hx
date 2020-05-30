package haxefmod.flixel;

import haxefmod.FmodEvents.FmodEvent;
import haxefmod.FmodEvents.FmodEventListener;
import haxefmod.FmodManagerPrivate;
import flixel.FlxG;
import flixel.FlxState;

class FmodUtilitiesPrivate implements FmodEventListener {
    private var DestinationState:FlxState;
    private var listeningForMusicStoppedEvent:Bool;

    private static var instance:FmodUtilitiesPrivate;

    private function new() {}

    private static function GetInstance():FmodUtilitiesPrivate {
        if (instance == null) {
            instance = new FmodUtilitiesPrivate();
            FmodManager.RegisterEventListener(instance);
        }
        return instance;
    }

    private function TransitionToStateAndStopMusic(state:FlxState) {
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
