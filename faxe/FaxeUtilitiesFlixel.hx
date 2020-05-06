package faxe;

import flixel.FlxState;
import faxe.Faxe;

@:access(faxe.FaxeUtilitiesFlixelPrivate)
class FaxeUtilitiesFlixel {
    /**
        Sends the "stop" command to the FMOD API and waits for the
        current song to stop before triggering a state transition
        @param state the state to load after the music stops
        @see https://tanneris.me/FMOD-AHDSR
    **/
    public static function TransitionToStateAndStopMusic(state:FlxState){
        FaxeUtilitiesFlixelPrivate.GetInstance().TransitionToStateAndStopMusic(state);
    }
   
    /**
        Convenience method that simply calls FlxG.switchState(state)

        Any loaded music will continue to play even after loading the new state
        @param state the state to load
    **/
    public static function TransitionToState(state:FlxState){
        FaxeUtilitiesFlixelPrivate.GetInstance().TransitionToState(state);
    }
}
