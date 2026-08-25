package haxefmod.flixel;

import flixel.FlxG;
import flixel.FlxObject;
import flixel.util.typeLimit.NextState;
import haxefmod.FmodManager;
import haxefmod.flixel.FmodFlxEmitter.FlxObjectPositionProvider;
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

        // Once-semantics matter here: a persistent handler would survive on
        // the retained song instance and yank the game into this state
        // again the next time the same song stops
        FmodManager.OnceSongEvent(data -> {
            switch (data) {
                case Stopped:
                    FlxG.switchState(state);
                default:
            }
        }, EventCallbackType.STOPPED);

        FmodManager.StopSong();
    }

    /**
        Convenience wrapper for FlxG.switchState(state)

        Any loaded music will continue to play even after loading the new state
        @param state the state to load
    **/
    public static function TransitionToState(state:NextState):Void {
        FlxG.switchState(state);
    }

    /**
        Fire-and-forget playback that follows a FlxObject (midpoint and
        velocity) until the event ends. Intended for one-shot (self-ending)
        events - a looping event played this way never releases.
        @param soundPath the full event path (e.g. "event:/SFX/Explosion")
        @param target the object the sound follows
    **/
    public static function PlaySoundOneShotAttached(soundPath:String, target:FlxObject):Void {
        FmodManager.PlaySoundOneShotAttached(soundPath, new FlxObjectPositionProvider(target));
    }
}
