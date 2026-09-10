package haxefmod.flixel;

import flixel.FlxG;
import flixel.FlxObject;
import flixel.util.typeLimit.NextState;
import haxefmod.FmodManager;
import haxefmod.flixel.FmodFlxEmitter.FlxObjectPositionProvider;
import haxefmod.studio.Callbacks;

/** Helpers that tie FmodManager to HaxeFlixel objects and states. **/
class FmodFlxUtilities {
    /**
        Sends the "stop" command to the FMOD API and waits for the
        current song to stop before triggering a state transition.

        Switches immediately when no song is playing. Requires
        FmodManager.Update() every frame to deliver the stop event.
        @param state The state to load after the music stops. Pass a
        constructor like PlayState.new or a FlxState instance.
    **/
    public static function TransitionToStateAndStopMusic(state:NextState):Void {
        if (!FmodManager.IsSongPlaying()) {
            FlxG.switchState(state);
            return;
        }

        // Once-semantics matter here. A persistent handler survives on the
        // retained song instance. It yanks the game into this state again
        // the next time the same song stops. RESTARTED is in the mask. A
        // direct PlaySong of the same song during the fade then consumes
        // the registration instead of leaving it armed.
        var consumed = false;
        FmodManager.OnceSongEvent(data -> {
            switch (data) {
                case Stopped:
                    if (!consumed) {
                        consumed = true;
                        FlxG.switchState(state);
                    }
                default:
            }
        }, EventCallbackType.STOPPED | EventCallbackType.RESTARTED);

        FmodManager.StopSong();
        // A fade already in flight can complete before the handler is
        // installed. No Stopped event arrives then, so switch directly.
        if (!FmodManager.IsSongPlaying() && !consumed) {
            consumed = true;
            FmodManager.OnSongEvent(null);
            FlxG.switchState(state);
        }
    }

    /**
        Convenience wrapper for FlxG.switchState(state).

        Any loaded music continues to play after the state loads.
        @param state The state to load.
    **/
    public static function TransitionToState(state:NextState):Void {
        FlxG.switchState(state);
    }

    /**
        Fire-and-forget playback that follows a FlxObject (midpoint and
        velocity) until the event ends. Intended for one-shot (self-ending)
        events. A looping event played this way never releases.
        @param eventPath The full event path, for example "event:/SFX/Explosion".
        @param target The object the event follows.
    **/
    public static function PlayOneShotAttached(eventPath:String, target:FlxObject):Void {
        FmodManager.PlayOneShotAttached(eventPath, new FlxObjectPositionProvider(target));
    }

    /** Deprecated alias of PlayOneShotAttached. **/
    @:deprecated("FmodFlxUtilities.PlaySoundOneShotAttached is now PlayOneShotAttached")
    public static function PlaySoundOneShotAttached(eventPath:String, target:FlxObject):Void {
        PlayOneShotAttached(eventPath, target);
    }
}
