package faxe;

import faxe.FaxeEvents.FaxeEvent;
import faxe.FaxeEvents.FaxeEventListener;
import faxe.FaxeSoundHelperPrivate;
import flixel.FlxG;
import flixel.FlxState;

class FaxeUtilitiesFlixelPrivate implements FaxeEventListener {
    private var DestinationState:FlxState;
    private var listeningForMusicStoppedEvent:Bool;

    private static var instance:FaxeUtilitiesFlixelPrivate;

    private function new() {}

    private static function GetInstance():FaxeUtilitiesFlixelPrivate {
        if (instance == null) {
            instance = new FaxeUtilitiesFlixelPrivate();
            FaxeSoundHelper.RegisterEventListener(instance);
        }
        return instance;
    }

    private function TransitionToStateAndStopMusic(state:FlxState) {
        listeningForMusicStoppedEvent = true;
        DestinationState = state;
        FaxeSoundHelper.StopSong();
    }

    private function TransitionToState(state:FlxState) {
        FlxG.switchState(state);
    }

    public function ReceiveEvent(faxeEvent:FaxeEvent) {
        if (listeningForMusicStoppedEvent && faxeEvent == FaxeEvent.MUSIC_STOPPED) {
            FlxG.switchState(DestinationState);
            listeningForMusicStoppedEvent = false;
        }
    }
}
