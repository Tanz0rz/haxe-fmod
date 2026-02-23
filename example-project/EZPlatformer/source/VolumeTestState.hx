package;

import flixel.FlxG;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;

/**
 * CI test state for validating bus volume and mute controls.
 *
 * Runs a 3-phase test over 30 seconds:
 *   Phase 1 (0-10s): Full volume (default)
 *   Phase 2 (10-20s): Volume set to 30%
 *   Phase 3 (20-30s): Muted
 *
 * Audio is recorded externally and validated by ci/validate-volume.sh.
 */
class VolumeTestState extends FlxState {
    var _elapsed:Float = 0;
    var _phase:Int = 0;
    var _status:FlxText;
    var _complete:Bool = false;

    override public function create():Void {
        super.create();

        FmodManager.EnableDebugMessages();
        FmodManager.PlaySong(FmodSongs.MainLevel);

        _status = new FlxText(0, 0, FlxG.width, "VOLUME_TEST: Starting");
        _status.setFormat(null, 16, FlxColor.WHITE, FlxTextAlign.CENTER, NONE, FlxColor.BLACK);
        _status.y = (FlxG.height / 2) - (_status.height / 2);
        add(_status);

        trace("VOLUME_TEST: Starting");
        trace("VOLUME_TEST: Phase 1 - Full volume (1.0)");
        _phase = 1;
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (_complete)
            return;

        _elapsed += elapsed;

        if (_phase == 1 && _elapsed >= 10) {
            _phase = 2;
            FmodManager.SetMasterVolume(0.3);
            _status.text = "VOLUME_TEST: Phase 2 - Volume 30%";
            trace("VOLUME_TEST: Phase 2 - Volume 30%");
        } else if (_phase == 2 && _elapsed >= 20) {
            _phase = 3;
            FmodManager.SetMasterMute(true);
            _status.text = "VOLUME_TEST: Phase 3 - Muted";
            trace("VOLUME_TEST: Phase 3 - Muted");
        } else if (_phase == 3 && _elapsed >= 30) {
            _complete = true;
            _status.text = "VOLUME_TEST: Complete";
            trace("VOLUME_TEST: Complete");
            #if sys
            Sys.exit(0);
            #end
        }
    }
}
