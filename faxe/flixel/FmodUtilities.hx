package faxe.flixel;

import flixel.FlxState;

@:access(faxe.flixel.FmodUtilitiesPrivate)
class FmodUtilities {
    /** 
        Sends the "stop" command to the FMOD API and waits for the
        current song to stop before triggering a state transition
        @param state the state to load after the music stops
        @see https://tanneris.me/FMOD-AHDSR
    **/
    public static function TransitionToStateAndStopMusic(state:FlxState) {
        FmodUtilitiesPrivate.GetInstance().TransitionToStateAndStopMusic(state);
    }

    /**
        Convenience method that simply calls FlxG.switchState(state)

        Any loaded music will continue to play even after loading the new state
        @param state the state to load
    **/
    public static function TransitionToState(state:FlxState) {
        FmodUtilitiesPrivate.GetInstance().TransitionToState(state);
    }
}
