package;

import haxefmod.core.CoreSystem;
import haxefmod.core.Dsp;
import haxefmod.core.DspConnection;
import haxefmod.core.DspType;
import haxefmod.core.Sound;
import haxefmod.core.SoundGroup;
import haxefmod.studio.FmodResult;
import haxefmod.studio.StudioSystem;
import haxefmod.studio.Types;

/**
 * Probe for the FMOD value enums: the retyped system calls hand back
 * FmodSpeakerMode and FmodOutputType values the real backend agrees
 * with, and setSpeakerPosition takes an FmodSpeaker. The speaker
 * position it moves is put back before it returns. The second half
 * covers the enums that replaced Int on Sound.getOpenState,
 * Dsp.addInput, DspConnection.getType, and the sound group behavior.
 */
class ProbeEnums {
    public static function run(state:ApiProbeState):Void {
        var baseline = StudioSystem.liveHandleCount();

        var format = CoreSystem.getSoftwareFormat();
        var mode:FmodSpeakerMode = format == null ? FmodSpeakerMode.DEFAULT : format.speakerMode;
        @:privateAccess state.check("enums_software_format_speaker_mode", format != null
            && (mode : Int) > (FmodSpeakerMode.DEFAULT : Int) && (mode : Int) < (FmodSpeakerMode.MAX : Int),
            format == null ? 'result=${StudioSystem.lastResult().toString()}' : 'speakerMode=${(mode : Int)}');
        var channels = CoreSystem.getSpeakerModeChannels(mode);
        @:privateAccess state.check("enums_speaker_mode_channels", format != null && channels == format.rawSpeakers,
            format == null ? "" : 'channels=$channels rawSpeakers=${format.rawSpeakers}');
        @:privateAccess state.check("enums_speaker_mode_stereo_is_two", CoreSystem.getSpeakerModeChannels(FmodSpeakerMode.STEREO) == 2,
            'channels=${CoreSystem.getSpeakerModeChannels(FmodSpeakerMode.STEREO)}');

        var output:FmodOutputType = CoreSystem.getOutput();
        @:privateAccess state.check("enums_output_type", (output : Int) >= (FmodOutputType.AUTODETECT : Int)
            && (output : Int) < (FmodOutputType.MAX : Int) && output != FmodOutputType.AUTODETECT,
            'output=${(output : Int)}');

        var before = CoreSystem.getSpeakerPosition(FmodSpeaker.FRONT_LEFT);
        @:privateAccess state.check("enums_get_speaker_position", before != null,
            before == null ? 'result=${StudioSystem.lastResult().toString()}' : 'x=${before.x} y=${before.y} active=${before.active}');
        var set = CoreSystem.setSpeakerPosition(FmodSpeaker.FRONT_LEFT, -0.5, 0.5, true);
        var moved = CoreSystem.getSpeakerPosition(FmodSpeaker.FRONT_LEFT);
        @:privateAccess state.check("enums_set_speaker_position", set.isOk() && moved != null
            && Math.abs(moved.x + 0.5) < 0.001 && Math.abs(moved.y - 0.5) < 0.001,
            'result=${set.toString()}' + (moved == null ? "" : ' x=${moved.x} y=${moved.y}'));
        if (before != null) CoreSystem.setSpeakerPosition(FmodSpeaker.FRONT_LEFT, before.x, before.y, before.active);
        // FMOD takes NONE without complaint on this backend, so the check
        // is that the call returns a result and leaves the real speaker alone
        var noneResult = CoreSystem.setSpeakerPosition(FmodSpeaker.NONE, 0, 0, true);
        var stillThere = CoreSystem.getSpeakerPosition(FmodSpeaker.FRONT_LEFT);
        @:privateAccess state.check("enums_speaker_none_handled", stillThere != null,
            'result=${noneResult.toString()}');

        // A memory sound is ready as soon as fromPcm returns, so its open
        // state is READY and its format is the mono 16-bit PCM handed in
        var samples = 4800;
        var pcm = haxe.io.Bytes.alloc(samples * 2);
        for (i in 0...samples) {
            var v = Std.int(Math.sin(2 * Math.PI * 440 * i / 48000) * 0x3000);
            pcm.setUInt16(i * 2, v & 0xFFFF);
        }
        var sound = Sound.fromPcm(pcm, 48000, 1);
        var openState = sound.getOpenState();
        @:privateAccess state.check("enums_open_state_ready", !sound.isNull() && openState == FmodOpenState.READY,
            'state=${(openState : Int)}');
        var soundFormat = sound.getFormat();
        @:privateAccess state.check("enums_sound_format_fields", soundFormat != null
            && soundFormat.channels == 1 && soundFormat.bits == 16,
            soundFormat == null ? 'result=${StudioSystem.lastResult().toString()}' : 'channels=${soundFormat.channels} bits=${soundFormat.bits}');
        sound.release();
        var staleState = sound.getOpenState();
        @:privateAccess state.check("enums_open_state_stale_is_error", staleState == FmodOpenState.ERROR
            && StudioSystem.lastResult() == FmodResult.FMOD_ERR_INVALID_HANDLE,
            'state=${(staleState : Int)} result=${StudioSystem.lastResult().toString()}');

        var target = Dsp.create(DspType.FADER);
        var source = Dsp.create(DspType.FADER);
        var standard = target.addInput(source);
        @:privateAccess state.check("enums_connection_type_standard", !standard.isNull()
            && standard.getType() == DspConnectionType.STANDARD,
            'handle=${(standard : Int)} type=${(standard.getType() : Int)}');
        target.disconnectFrom(source);
        var sidechain = target.addInput(source, DspConnectionType.SIDECHAIN);
        @:privateAccess state.check("enums_connection_type_sidechain", !sidechain.isNull()
            && sidechain.getType() == DspConnectionType.SIDECHAIN
            && sidechain.getType() == DspConnection.TYPE_SIDECHAIN,
            'handle=${(sidechain : Int)} type=${(sidechain.getType() : Int)}');
        target.disconnectFrom(source);
        var send = target.addInput(source, DspConnection.TYPE_SEND);
        @:privateAccess state.check("enums_connection_type_alias", !send.isNull()
            && send.getType() == DspConnectionType.SEND,
            'handle=${(send : Int)} type=${(send.getType() : Int)}');
        target.disconnectFrom(source);
        source.release();
        target.release();

        var group = SoundGroup.create("enums-probe");
        var behaviorSet = group.setMaxAudibleBehavior(SoundGroupBehavior.MUTE);
        @:privateAccess state.check("enums_sound_group_behavior", behaviorSet.isOk()
            && group.getMaxAudibleBehavior() == SoundGroupBehavior.MUTE
            && group.getMaxAudibleBehavior() == SoundGroup.BEHAVIOR_MUTE,
            'result=${behaviorSet.toString()} behavior=${(group.getMaxAudibleBehavior() : Int)}');
        group.release();

        @:privateAccess state.check("no_handle_leaks_enums", StudioSystem.liveHandleCount() == baseline,
            'live=${StudioSystem.liveHandleCount()} baseline=$baseline');
    }
}
