package fmodtest;

import haxefmod.studio.Bus;
import haxefmod.studio.StudioSystem;

/**
 * CI test scenario for validating bus volume and mute controls.
 *
 * Drives the master bus through the haxefmod.studio bindings (Bus handle
 * API) so the recorded audio proves the bindings work end to end on every
 * platform.
 *
 * Runs a 3-phase test over 15 seconds of audio time:
 *   Phase 1 (0-5s): Full volume (default)
 *   Phase 2 (5-10s): Volume set to 30%
 *   Phase 3 (10-15s): Muted
 *
 * Uses FMOD's timeline position instead of wall-clock time so that
 * phase transitions align with the audio output regardless of how
 * fast FMOD processes (e.g. WAVWRITER runs faster than real-time).
 *
 * Audio is recorded externally and validated by ci/validate-volume.sh.
 */
class VolumeScenario implements TestScenario {
    var host:TestHost;

    public function new() {}

    var _phase:Int = 0;
    var _complete:Bool = false;
    var _master:Bus;

    public function create(host:TestHost):Void {
        this.host = host;

        FmodManager.EnableDebugMessages();
        FmodManager.PlaySong(FmodEvents.MusicMainLevel);

        _master = StudioSystem.getBus("bus:/");
        trace('VOLUME_TEST: master bus valid=${_master.isValid()} path=${_master.getPath()}');

        host.setStatus("VOLUME_TEST: Starting");

        trace("VOLUME_TEST: Starting");
        trace("VOLUME_TEST: Phase 1 - Full volume (1.0)");
        _phase = 1;
    }

    public function update(elapsed:Float):Void {

        if (_complete)
            return;

        // Use FMOD's audio timeline so phases align with WAVWRITER output
        var posMs = FmodManager.GetSongTimelinePosition();
        var posSec = posMs / 1000.0;

        if (_phase == 1 && posSec >= 5) {
            _phase = 2;
            _master.setVolume(0.3);
            trace('VOLUME_TEST: getVolume=${_master.getVolume()}');
            host.setStatus("VOLUME_TEST: Phase 2 - Volume 30%");
            trace("VOLUME_TEST: Phase 2 - Volume 30%");
        } else if (_phase == 2 && posSec >= 10) {
            _phase = 3;
            _master.setMute(true);
            trace('VOLUME_TEST: getMute=${_master.getMute()}');
            host.setStatus("VOLUME_TEST: Phase 3 - Muted");
            trace("VOLUME_TEST: Phase 3 - Muted");
        } else if (_phase == 3 && posSec >= 15) {
            _complete = true;
            host.setStatus("VOLUME_TEST: Complete");
            trace("VOLUME_TEST: Complete");
            host.exit(0);
        }
    }
}
