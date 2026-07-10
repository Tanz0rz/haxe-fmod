package haxefmod.flixel;

import flixel.FlxG;
import flixel.util.typeLimit.NextState;
import haxefmod.FmodManager;
import haxefmod.studio.Callbacks;

class FmodFlxUtilities {
    /**
        Sends the "stop" command to the FMOD API and waits for the
        current song to stop before triggering a state transition.

        Switches immediately when no song is playing. Requires
        FmodManager.Update() every frame to deliver the stop event.
        @param state the state to load after the music stops (either a
        constructor like PlayState.new or a FlxState instance)
        @see https://tanneris.me/FMOD-AHDSR
    **/
    public static function TransitionToStateAndStopMusic(state:NextState):Void {
        if (!FmodManager.IsSongPlaying()) {
            FlxG.switchState(state);
            return;
        }

        FmodManager.OnSongEvent(data -> {
            switch (data) {
                case Stopped:
                    FlxG.switchState(state);
                default:
            }
        }, EventCallbackType.STOPPED);

        FmodManager.StopSong();
    }

    /**
        Convenience method that simply calls FlxG.switchState(state)

        Any loaded music will continue to play even after loading the new state
        @param state the state to load
    **/
    public static function TransitionToState(state:NextState):Void {
        FlxG.switchState(state);
    }
}
