package faxe;

import faxe.FaxeEventListener.FaxeEvent;
import faxe.FaxeSoundHelperPrivate;
import flixel.FlxState;
import faxe.Faxe;
import flixel.FlxG;

class FaxeUtilitiesFlixelPrivate implements FaxeEventListener {

    private var DestinationState:FlxState;
    private var transitioningWhenMusicIsStopped:Bool;

    private static var instance:FaxeUtilitiesFlixelPrivate;
    private function new () {}
    private static function GetInstance():FaxeUtilitiesFlixelPrivate {
        if (instance == null) {
            instance = new FaxeUtilitiesFlixelPrivate();
            FaxeSoundHelper.RegisterEventListener(instance);
        }
        return instance;
    }

    private function TransitionToStateAndStopMusic(state:FlxState){
        transitioningWhenMusicIsStopped = true;
        DestinationState = state;
        FaxeSoundHelper.StopSong();
    }

    private function TransitionToState(state:FlxState){
        FlxG.switchState(state);
    }

    public function ReceiveEvent(faxeEvent:FaxeEvent) {
        if (faxeEvent == FaxeEvent.MUSIC_STOPPED && transitioningWhenMusicIsStopped) {
            FlxG.switchState(DestinationState);
            transitioningWhenMusicIsStopped = false;
        } 
    }
}
