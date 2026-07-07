package;

import flixel.FlxG;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxefmod.studio.Callbacks;

/**
 * CI test state for payload-carrying callbacks.
 *
 * Plays the song, registers a typed OnSongEvent handler, logs every callback
 * with its payload as a "CB_TEST:" line, then soft-stops the song and waits
 * for the Stopped event to prove the queue delivers end to end.
 *
 * CI gates on "CB_TEST: Stopped" and "CB_TEST: COMPLETE". Beat and marker
 * lines are informational (they only fire if the FMOD project has tempo
 * markers on the event timeline).
 *
 * Select via HAXEFMOD_TEST_STATE=cb-test (native) or ?test=cb-test (HTML5).
 */
class BeatTestState extends FlxState {
    var _stopRequested:Bool = false;
    var _stoppedReceived:Bool = false;
    var _eventCount:Int = 0;
    var _framesSinceStop:Int = 0;
    var _status:FlxText;

    static inline function log(message:String):Void {
        #if js
        js.Browser.console.log(message);
        #else
        trace(message);
        #end
    }

    override public function create():Void {
        super.create();

        FmodManager.EnableDebugMessages();
        FmodManager.PlaySong(FmodSongs.MainLevel);

        _status = new FlxText(0, 0, FlxG.width, "CB_TEST running");
        _status.setFormat(null, 16, FlxColor.WHITE, FlxTextAlign.CENTER, NONE, FlxColor.BLACK);
        _status.y = (FlxG.height / 2) - (_status.height / 2);
        add(_status);

        log("CB_TEST: Starting");

        FmodManager.OnSongEvent(data -> {
            _eventCount++;
            switch (data) {
                case TimelineMarker(name, positionMs):
                    log('CB_TEST: TimelineMarker name=$name position=$positionMs');
                case TimelineBeat(bar, beat, positionMs, tempo):
                    log('CB_TEST: TimelineBeat bar=$bar beat=$beat position=$positionMs tempo=$tempo');
                case NestedTimelineBeat(bar, beat, positionMs, tempo):
                    log('CB_TEST: NestedTimelineBeat bar=$bar beat=$beat position=$positionMs tempo=$tempo');
                case Stopped:
                    log("CB_TEST: Stopped");
                    _stoppedReceived = true;
                case other:
                    log('CB_TEST: $other');
            }
        });
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        // Let the song play for 3 seconds of audio time, then soft-stop it
        if (!_stopRequested && FmodManager.GetSongTimelinePosition() >= 3000) {
            _stopRequested = true;
            log("CB_TEST: Requesting soft stop");
            FmodManager.StopSong();
        }

        if (_stoppedReceived) {
            _framesSinceStop++;
            if (_framesSinceStop == 1) {
                log('CB_TEST: COMPLETE events=$_eventCount');
                _status.text = 'CB_TEST complete: $_eventCount events';
            }
            // Give the renderer a few frames, then exit
            if (_framesSinceStop > 30) {
                #if sys
                Sys.exit(0);
                #end
            }
        }
    }
}
