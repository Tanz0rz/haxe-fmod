package;

import fmodtest.ApiProbeScenario;
import haxefmod.core.CoreSystem;
import haxefmod.core.Sound;
import haxefmod.studio.FmodResult;
import haxefmod.studio.StudioSystem;

/**
 * The api-probe section for Sound.lock and unlock and the disk busy flag.
 * A raw PCM sound is locked, its samples rewritten through the copy, and
 * a second lock reads the change back. Every rejection path (second lock,
 * unlock without a lock, wrong length, empty range, stale handle) and the
 * release-with-lock-open cleanup are checked too.
 */
class ProbeSoundLock {
    static inline var SAMPLES:Int = 512;

    public static function run(state:ApiProbeScenario):Void {
        var baseline = StudioSystem.liveHandleCount();

        // 16-bit mono ramp, sample i holds the value i
        var pcm = haxe.io.Bytes.alloc(SAMPLES * 2);
        for (i in 0...SAMPLES) pcm.setUInt16(i * 2, i);
        var sound = Sound.fromPcm(pcm, 8000, 1);
        @:privateAccess state.check("sound_lock_fixture", !sound.isNull(), 'result=${StudioSystem.lastResult().toString()}');

        #if js
        @:privateAccess state.check("core_sound_lock_unsupported", sound.lock(0, 64) == null
            && StudioSystem.lastResult() == FmodResult.FMOD_ERR_UNSUPPORTED, 'result=${StudioSystem.lastResult().toString()}');
        @:privateAccess state.check("core_sound_unlock_unsupported",
            sound.unlock(haxe.io.Bytes.alloc(64)) == FmodResult.FMOD_ERR_UNSUPPORTED, "");
        @:privateAccess state.check("sys_set_disk_busy_unsupported", CoreSystem.setDiskBusy(true) == FmodResult.FMOD_ERR_UNSUPPORTED, "");
        @:privateAccess state.check("sys_get_disk_busy_unsupported", !CoreSystem.getDiskBusy()
            && StudioSystem.lastResult() == FmodResult.FMOD_ERR_UNSUPPORTED, 'result=${StudioSystem.lastResult().toString()}');
        #else
        // lock returns a copy of the range that matches what fromPcm stored
        var range = sound.lock(20, 64);
        @:privateAccess state.check("core_sound_lock", range != null && range.length == 64,
            range == null ? 'result=${StudioSystem.lastResult().toString()}' : 'length=${range.length}');
        var copyMatches = range != null;
        if (range != null) for (i in 0...32) if (range.getUInt16(i * 2) != 10 + i) copyMatches = false;
        @:privateAccess state.check("core_sound_lock_copy", copyMatches,
            range == null ? "" : 'first=${range.getUInt16(0)} last=${range.getUInt16(62)}');

        // a second lock while one is open is rejected without touching the first
        @:privateAccess state.check("core_sound_lock_twice_rejected", sound.lock(0, 16) == null
            && StudioSystem.lastResult() == FmodResult.FMOD_ERR_INVALID_PARAM, 'result=${StudioSystem.lastResult().toString()}');

        // the wrong length is rejected and keeps the lock open
        @:privateAccess state.check("core_sound_unlock_wrong_length",
            sound.unlock(haxe.io.Bytes.alloc(63)) == FmodResult.FMOD_ERR_INVALID_PARAM, "");

        // rewrite the samples through the copy and write them back
        if (range != null) for (i in 0...32) range.setUInt16(i * 2, 0x1234);
        var unlocked:FmodResult = range == null ? FmodResult.FMOD_ERR_INVALID_PARAM : sound.unlock(range);
        @:privateAccess state.check("core_sound_unlock", unlocked.isOk(), 'result=${unlocked.toString()}');

        // unlock with nothing open is rejected
        @:privateAccess state.check("core_sound_unlock_without_lock",
            sound.unlock(haxe.io.Bytes.alloc(64)) == FmodResult.FMOD_ERR_INVALID_PARAM, "");

        // a second lock reads the change back, and the samples around the
        // range are untouched
        var again = sound.lock(16, 72);
        var written = again != null && again.length == 72;
        if (written) {
            for (i in 0...36) {
                var expected = i >= 2 && i < 34 ? 0x1234 : 8 + i;
                if (again.getUInt16(i * 2) != expected) written = false;
            }
        }
        @:privateAccess state.check("core_sound_lock_reads_back_write", written,
            again == null ? 'result=${StudioSystem.lastResult().toString()}' : 'first=${again.getUInt16(0)} inside=${again.getUInt16(4)} after=${again.getUInt16(70)}');
        if (again != null) sound.unlock(again);

        // readData decodes from an openOnly file and has nothing to read on
        // a sample buffer, so lock is the only way to see the change
        var readBack = haxe.io.Bytes.alloc(SAMPLES * 2);
        var read = sound.readData(readBack);
        @:privateAccess state.check("core_sound_read_data_not_for_sample_buffers", read == -68,
            'value=$read result=${StudioSystem.lastResult().toString()}');

        // empty and past-the-end ranges
        @:privateAccess state.check("core_sound_lock_empty_rejected", sound.lock(0, 0) == null
            && StudioSystem.lastResult() == FmodResult.FMOD_ERR_INVALID_PARAM, 'result=${StudioSystem.lastResult().toString()}');
        var past = sound.lock(SAMPLES * 2, 16);
        @:privateAccess state.check("core_sound_lock_past_end_rejected", past == null,
            past == null ? 'result=${StudioSystem.lastResult().toString()}' : 'length=${past.length}');
        if (past != null) sound.unlock(past);

        // a stream has no sample buffer to lock
        #if sys
        var wavPath = @:privateAccess ApiProbeScenario.writeProbeWav();
        var stream = Sound.create(wavPath, false, false, haxefmod.core.ChannelMode.CREATESTREAM);
        if (!stream.isNull()) {
            var streamRange = stream.lock(0, 16);
            @:privateAccess state.check("core_sound_lock_stream_rejected", streamRange == null,
                streamRange == null ? 'result=${StudioSystem.lastResult().toString()}' : 'length=${streamRange.length}');
            if (streamRange != null) stream.unlock(streamRange);
            stream.release();
        }
        try sys.FileSystem.deleteFile(wavPath) catch (e:Dynamic) {}
        #end

        // releasing with a lock open unlocks first, and the handle is dead after
        var open = sound.lock(0, 32);
        @:privateAccess state.check("core_sound_lock_before_release", open != null, 'result=${StudioSystem.lastResult().toString()}');
        var released:FmodResult = sound.release();
        @:privateAccess state.check("core_sound_release_with_lock_open", released.isOk(), 'result=${released.toString()}');
        @:privateAccess state.check("core_sound_lock_stale", sound.lock(0, 16) == null
            && StudioSystem.lastResult() == FmodResult.FMOD_ERR_INVALID_HANDLE, 'result=${StudioSystem.lastResult().toString()}');
        @:privateAccess state.check("core_sound_unlock_stale",
            sound.unlock(open) == FmodResult.FMOD_ERR_INVALID_HANDLE, "");

        // the disk busy flag round-trips and is put back
        var setBusy:FmodResult = CoreSystem.setDiskBusy(true);
        @:privateAccess state.check("sys_set_disk_busy", setBusy.isOk(), 'result=${setBusy.toString()}');
        @:privateAccess state.check("sys_get_disk_busy_true", CoreSystem.getDiskBusy(), 'result=${StudioSystem.lastResult().toString()}');
        CoreSystem.setDiskBusy(false);
        @:privateAccess state.check("sys_get_disk_busy_false", !CoreSystem.getDiskBusy(), 'result=${StudioSystem.lastResult().toString()}');
        #end

        #if js
        sound.release();
        #end
        @:privateAccess state.check("no_handle_leaks_sound_lock", StudioSystem.liveHandleCount() == baseline,
            'baseline=$baseline now=${StudioSystem.liveHandleCount()}');
    }
}
