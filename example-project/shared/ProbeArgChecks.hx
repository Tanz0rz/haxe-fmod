package;

import fmodtest.ApiProbeScenario;
import haxefmod.core.ChannelGroup;
import haxefmod.core.ChannelMode;
import haxefmod.core.CoreSystem;
import haxefmod.core.Sound;
import haxefmod.runtime.FmodRuntime;
import haxefmod.studio.CallbackDispatcher;
import haxefmod.studio.Callbacks;
import haxefmod.studio.EventInstance;
import haxefmod.studio.FmodResult;
import haxefmod.studio.StudioSystem;
import haxefmod.studio.Types;
import haxefmod.studio.native.NativeStudio;

/**
 * The api-probe section for the argument checks the shims run before
 * FMOD sees a value it crashes on (native/shared/faxe_argcheck.h). Each
 * refused value reports FMOD_ERR_INVALID_PARAM, and the matching call a
 * game makes still works. The section closes with a Destroyed record
 * that drains behind an unrelated bank's unload record and still reads
 * its instance's user data.
 */
class ProbeArgChecks {
    static function refused(sound:Sound):Bool {
        return sound.isNull() && StudioSystem.lastResult() == FmodResult.FMOD_ERR_INVALID_PARAM;
    }

    /** A stereo 16-bit user sample of length bytes with the extra fields set. */
    static function user(length:Int):FmodCreateSoundExInfo {
        return {length: length, numChannels: 2, defaultFrequency: 48000, format: FmodSoundFormat.PCM16};
    }

    public static function run(state:ApiProbeScenario):Void {
        // The description lookups mint persistent handles: warm them
        // before the baseline
        StudioSystem.getEvent(FmodEvents.MusicMainLevel);
        StudioSystem.getEvent(FmodEvents.SFXCoin);
        var baseline = StudioSystem.liveHandleCount();
        exinfo(state);
        recordBuffer(state);
        speakers(state);
        labels(state);
        dspIndexes(state);
        threadType(state);
        destroyedBehindBankUnload(state);
        @:privateAccess state.check("argcheck_no_handle_leaks", StudioSystem.liveHandleCount() == baseline,
            'baseline=$baseline now=${StudioSystem.liveHandleCount()}');
    }

    static function exinfo(state:ApiProbeScenario):Void {
        var wav = @:privateAccess ApiProbeScenario.probeWavBytes();
        var negative = Sound.fromMemory(wav, 0, -1, {numSubsounds: -1});
        var negativeOk = refused(negative);
        var pathNegative = Sound.create("assets/fmod/Jump.wav", false, false, 0, -1, {numSubsounds: -1});
        var pathNegativeOk = refused(pathNegative);
        var huge = user(4000);
        huge.numSubsounds = 0x3FFFFFFF;
        @:privateAccess state.check("argcheck_exinfo_subsounds", negativeOk && pathNegativeOk
            && refused(Sound.create("", false, false, ChannelMode.OPENUSER, -1, huge)),
            'memory=$negativeOk path=$pathNegativeOk result=${StudioSystem.lastResult().toString()}');

        var fileBuffer = user(4000);
        fileBuffer.fileBufferSize = -2;
        @:privateAccess state.check("argcheck_exinfo_file_buffer",
            refused(Sound.create("", false, false, ChannelMode.OPENUSER, -1, fileBuffer)),
            'result=${StudioSystem.lastResult().toString()}');

        var slowStream = user(4000);
        slowStream.defaultFrequency = 1;
        var decode = user(4000);
        decode.decodeBufferSize = 0x3FFFFFFF;
        var slowOk = refused(Sound.create("", false, false, ChannelMode.OPENUSER | ChannelMode.CREATESTREAM, -1, slowStream));
        @:privateAccess state.check("argcheck_exinfo_user_stream", slowOk
            && refused(Sound.create("", false, false, ChannelMode.OPENUSER | ChannelMode.CREATESTREAM, -1, decode)),
            'rate=$slowOk result=${StudioSystem.lastResult().toString()}');

        // FMOD's buffer size wraps on a length near 4 GB
        @:privateAccess state.check("argcheck_exinfo_user_length",
            refused(Sound.create("", false, false, ChannelMode.OPENUSER, -1, user(0xFFFFFFF0))),
            'result=${StudioSystem.lastResult().toString()}');

        // The user sample a game creates, locks, and fills
        var sample = Sound.create("", false, false, ChannelMode.OPENUSER, -1, user(4000));
        var sampleResult = StudioSystem.lastResult();
        #if js
        var filled = true;
        #else
        var locked = sample.isNull() ? null : sample.lock(0, 64);
        var filled = locked != null && locked.length == 64 && sample.unlock(locked).isOk();
        #end
        @:privateAccess state.check("argcheck_exinfo_user_sample_ok", !sample.isNull() && filled,
            'handle=${(sample : Int)} result=${sampleResult.toString()}');
        sample.release();

        var stream = Sound.create("", false, false, ChannelMode.OPENUSER | ChannelMode.CREATESTREAM, -1, user(4000));
        @:privateAccess state.check("argcheck_exinfo_user_stream_ok", !stream.isNull(),
            'result=${StudioSystem.lastResult().toString()}');
        stream.release();

        // Raw PCM from memory, the shape the rest of the probe uses
        var raw = Sound.fromMemory(wav, ChannelMode.OPENRAW, -1,
            {numChannels: 1, defaultFrequency: 8000, format: FmodSoundFormat.PCM16, fileBufferSize: -1});
        @:privateAccess state.check("argcheck_exinfo_raw_memory_ok", !raw.isNull(),
            'result=${StudioSystem.lastResult().toString()}');
        raw.release();
    }

    static function recordBuffer(state:ApiProbeScenario):Void {
        #if js
        @:privateAccess state.info("argcheck_record_buffer", "skipped, the web build has no recording");
        #else
        // 3 hours of 48 kHz stereo passes 2 GB
        var long = Sound.createRecordBuffer(48000, 2, 11185);
        var longOk = refused(long);
        var wrapped = Sound.createRecordBuffer(48000, 2, 22370);
        @:privateAccess state.check("argcheck_record_buffer_length", longOk && refused(wrapped),
            'long=$longOk result=${StudioSystem.lastResult().toString()}');
        var buffer = Sound.createRecordBuffer(48000, 1, 1);
        var length = buffer.isNull() ? -1 : buffer.getLength(FmodTimeUnit.PCMBYTES);
        @:privateAccess state.check("argcheck_record_buffer_ok", !buffer.isNull() && length == 96000,
            'length=$length result=${StudioSystem.lastResult().toString()}');
        buffer.release();
        #end
    }

    static function speakers(state:ApiProbeScenario):Void {
        var set:FmodResult = CoreSystem.setSpeakerPosition(FmodSpeaker.NONE, 0.25, 0.75, true);
        var got = CoreSystem.getSpeakerPosition(FmodSpeaker.NONE);
        var getResult = StudioSystem.lastResult();
        var far:FmodResult = CoreSystem.setSpeakerPosition(cast -65536, 0.25, 0.75, true);
        @:privateAccess state.check("argcheck_speaker_negative", set == FmodResult.FMOD_ERR_INVALID_PARAM && got == null
            && getResult == FmodResult.FMOD_ERR_INVALID_PARAM && far == FmodResult.FMOD_ERR_INVALID_PARAM,
            'set=${set.toString()} get=${getResult.toString()} far=${far.toString()}');
        var front = CoreSystem.getSpeakerPosition(FmodSpeaker.FRONT_LEFT);
        @:privateAccess state.check("argcheck_speaker_ok", front != null, 'result=${StudioSystem.lastResult().toString()}');
    }

    static function labels(state:ApiProbeScenario):Void {
        var music = StudioSystem.getEvent(FmodEvents.MusicMainLevel);
        var byIndex = music.getParameterLabelByIndex(0, -1);
        var byIndexResult = StudioSystem.lastResult();
        var first = music.getParameterDescriptionByIndex(0);
        var byName = first == null ? "missing" : music.getParameterLabelByName(first.name, -1);
        var byNameResult = StudioSystem.lastResult();
        var global = StudioSystem.getParameterLabelByName("Weather", -1);
        var globalResult = StudioSystem.lastResult();
        @:privateAccess state.check("argcheck_label_negative", music.isValid() && first != null
            && byIndex == "" && byIndexResult == FmodResult.FMOD_ERR_INVALID_PARAM
            && byName == "" && byNameResult == FmodResult.FMOD_ERR_INVALID_PARAM
            && global == "" && globalResult == FmodResult.FMOD_ERR_INVALID_PARAM,
            'valid=${music.isValid()} index=${byIndexResult.toString()} name=${byNameResult.toString()} global=${globalResult.toString()}');
        var weather = StudioSystem.getParameterLabelByName("Weather", 0);
        if (weather == "") {
            @:privateAccess state.info("argcheck_label_ok", 'no labeled global parameter Weather here (result=${StudioSystem.lastResult().toString()})');
        } else {
            @:privateAccess state.check("argcheck_label_ok", true, 'label=$weather');
        }
    }

    static function dspIndexes(state:ApiProbeScenario):Void {
        // A group of its own, so the borrowed DSP handles die with it
        var group = ChannelGroup.create("argcheck");
        var below = group.getDsp(-4);
        var belowResult = StudioSystem.lastResult();
        var tail = group.getDsp(ChannelGroup.DSP_TAIL);
        @:privateAccess state.check("argcheck_group_dsp_index", !group.isNull() && below.isNull()
            && belowResult == FmodResult.FMOD_ERR_INVALID_PARAM && !tail.isNull(),
            'below=${belowResult.toString()} tail=${(tail : Int)}');

        var sound = Sound.create("", false, false, ChannelMode.OPENUSER, -1, user(4000));
        var channel = sound.play(true, group);
        var channelBelow = channel.getDsp(-4);
        var channelBelowResult = StudioSystem.lastResult();
        var head = channel.getDsp(ChannelGroup.DSP_HEAD);
        @:privateAccess state.check("argcheck_channel_dsp_index", !channel.isNull() && channelBelow.isNull()
            && channelBelowResult == FmodResult.FMOD_ERR_INVALID_PARAM && !head.isNull(),
            'channel=${(channel : Int)} below=${channelBelowResult.toString()} head=${(head : Int)}');
        channel.stop();
        sound.release();
        group.release();
    }

    static function threadType(state:ApiProbeScenario):Void {
        #if js
        @:privateAccess state.info("argcheck_thread_type", "skipped, the web build has no threads to place");
        #else
        // The type is checked before the system state, so both answers
        // come back after init without touching a thread
        var negative:FmodResult = NativeStudio.sys_thread_set_attributes(-1, FmodThreadPriority.DEFAULT, FmodThreadStackSize.DEFAULT, -1);
        var past:FmodResult = NativeStudio.sys_thread_set_attributes(FmodThreadType.MAX, FmodThreadPriority.DEFAULT, FmodThreadStackSize.DEFAULT, -1);
        var known:FmodResult = NativeStudio.sys_thread_set_attributes(FmodThreadType.MIXER, FmodThreadPriority.DEFAULT, FmodThreadStackSize.DEFAULT, -1);
        @:privateAccess state.check("argcheck_thread_type", negative == FmodResult.FMOD_ERR_INVALID_PARAM
            && past == FmodResult.FMOD_ERR_INVALID_PARAM && known == FmodResult.FMOD_ERR_INITIALIZED,
            'negative=${negative.toString()} past=${past.toString()} known=${known.toString()}');
        #end
    }

    /**
     * Two bank unloads in one drain: Extras raises its record first, then
     * releaseAllInstances destroys an instance of another bank's event.
     * The Destroyed handler runs behind the unload record and reads the
     * instance's user data.
     */
    static function destroyedBehindBankUnload(state:ApiProbeScenario):Void {
        #if js
        @:privateAccess state.info("argcheck_destroyed_behind_bank_unload", "skipped, the web build never delivers Destroyed");
        #else
        var extras = StudioSystem.loadBankFile(FmodRuntime.bankPath("Extras.bank"));
        if (extras.isNull()) {
            @:privateAccess state.info("argcheck_destroyed_behind_bank_unload",
                'Extras bank not loadable here, skipped (result=${StudioSystem.lastResult().toString()})');
            return;
        }
        // Nothing else drains between the two calls below
        CallbackDispatcher.update();
        var coin = StudioSystem.getEvent(FmodEvents.SFXCoin);
        var idle = coin.getInstanceCount() == 0;
        var instance = coin.createInstance();
        var seen:Dynamic = "never delivered";
        instance.setUserData("argcheck payload");
        instance.setCallback(function(data) {
            switch (data) {
                case Destroyed: seen = instance.getUserData();
                default:
            }
        }, EventCallbackType.DESTROYED);
        var unload:FmodResult = extras.unload();
        var released:FmodResult = coin.releaseAllInstances();
        CallbackDispatcher.update();
        @:privateAccess state.check("argcheck_destroyed_behind_bank_unload", idle && !instance.isNull()
            && unload.isOk() && released.isOk() && seen == "argcheck payload",
            'idle=$idle unload=${unload.toString()} released=${released.toString()} seen=$seen');
        @:privateAccess state.check("argcheck_destroyed_userdata_dropped", instance.getUserData() == null, "");
        #end
    }
}
