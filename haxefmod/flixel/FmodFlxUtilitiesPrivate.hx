package haxefmod.flixel;

import haxefmod.FmodEvents.FmodCallback;
import haxefmod.FmodEvents.FmodEvent;
import haxefmod.FmodEvents.FmodEventListener;
import haxefmod.FmodManagerPrivate;
import flixel.FlxG;
import flixel.FlxState;

class FmodFlxUtilitiesPrivate implements FmodEventListener {
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

        FmodManager.RegisterCallbacksForSound("SongEventInstance", ()-> {
            FlxG.switchState(state);
        }, FmodCallback.STOPPED);

        FmodManager.StopSong();
    }

    private function TransitionToState(state:FlxState) {
        FlxG.switchState(state);
    }

    public function ReceiveEvent(faxeEvent:FmodEvent) {
        // The eventing system will likely be removed soon
    }
}
