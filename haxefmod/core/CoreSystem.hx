package haxefmod.core;

import haxefmod.studio.Types;
import haxefmod.studio.FmodResult;
import haxefmod.studio.native.NativeStudio;
import haxefmod.studio.native.Scratch;

/**
 * Core mixer queries and controls that belong to no single object.
 */
class CoreSystem {
    /**
     * Playing channel counts, or null on failure. `all` includes virtual
     * (inaudible) channels, `real` is what the mixer actually processes.
     */
    public static function getChannelsPlaying():Null<{all:Int, real:Int}> {
        var result:FmodResult = NativeStudio.sys_get_channels_playing();
        if (!result.isOk()) return null;
        return {all: Scratch.readI(0), real: Scratch.readI(1)};
    }

    /**
     * Stops the mixer entirely (for app backgrounding on platforms that
     * demand silence). Pair with mixerResume.
     */
    public static inline function mixerSuspend():FmodResult {
        return NativeStudio.sys_mixer_suspend();
    }

    public static inline function mixerResume():FmodResult {
        return NativeStudio.sys_mixer_resume();
    }

    /** The mixer's output format, or null on failure. */
    public static function getSoftwareFormat():Null<{sampleRate:Int, speakerMode:FmodSpeakerMode, rawSpeakers:Int}> {
        var result:FmodResult = NativeStudio.sys_get_software_format();
        if (!result.isOk()) return null;
        return {sampleRate: Scratch.readI(0), speakerMode: Scratch.readI(1), rawSpeakers: Scratch.readI(2)};
    }

    /**
     * Global 3D scale factors: doppler strength, world units per meter,
     * and how aggressively sounds attenuate with distance.
     */
    public static inline function set3DSettings(dopplerScale:Float, distanceFactor:Float, rolloffScale:Float):FmodResult {
        return NativeStudio.sys_set_3d_settings(dopplerScale, distanceFactor, rolloffScale);
    }

    public static function get3DSettings():Null<{dopplerScale:Float, distanceFactor:Float, rolloffScale:Float}> {
        var result:FmodResult = NativeStudio.sys_get_3d_settings();
        if (!result.isOk()) return null;
        return {dopplerScale: Scratch.readF(0), distanceFactor: Scratch.readF(1), rolloffScale: Scratch.readF(2)};
    }

    public static inline function getDriverCount():Int {
        return NativeStudio.sys_get_num_drivers();
    }

    public static inline function getDriverName(index:Int):String {
        return NativeStudio.sys_get_driver_name(index);
    }

    /**
     * Name, GUID, native rate, speaker mode, and channel count of an
     * output driver (see getDriverCount). Null for an index out of range.
     */
    public static function getDriverInfo(index:Int):Null<{name:String, guid:FmodGuid, systemRate:Int, speakerMode:FmodSpeakerMode, speakerModeChannels:Int}> {
        var name = NativeStudio.sys_get_driver_info(index);
        if (!(NativeStudio.sys_last_result() : FmodResult).isOk()) return null;
        var info = {name: name, guid: (FmodGuid.NULL : FmodGuid), systemRate: Scratch.readI(0), speakerMode: (Scratch.readI(1) : FmodSpeakerMode),
            speakerModeChannels: Scratch.readI(2)};
        info.guid = (NativeStudio.sys_get_driver_guid(index) : FmodGuid);
        return info;
    }

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /**
     * Routes a channel group to a console output port (unsupported in
     * HTML5, FMOD_ERR_UNSUPPORTED there). Desktop outputs have no ports
     * either and FMOD reports that in the result. portIndex is
     * FmodPortIndex.NONE for ports without slots, passThru keeps the group
     * in the main mix as well.
     */
    public static macro function attachChannelGroupToPort(portType:haxe.macro.Expr, portIndex:haxe.macro.Expr, group:haxe.macro.Expr, ?passThru:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("CoreSystem.attachChannelGroupToPort", "the web build has no output ports");
    }
    #else
    /**
     * Routes a channel group to a console output port (unsupported in
     * HTML5, FMOD_ERR_UNSUPPORTED there). Desktop outputs have no ports
     * either and FMOD reports that in the result. portIndex is
     * FmodPortIndex.NONE for ports without slots, passThru keeps the group
     * in the main mix as well.
     */
    public static inline function attachChannelGroupToPort(portType:FmodPortType, portIndex:FmodPortIndex, group:ChannelGroup, passThru:Bool = false):FmodResult {
        return NativeStudio.sys_attach_channel_group_to_port(portType, portIndex, group, passThru);
    }
    #end

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /** Takes a channel group off its output port again (unsupported in HTML5, FMOD_ERR_UNSUPPORTED there). */
    public static macro function detachChannelGroupFromPort(group:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("CoreSystem.detachChannelGroupFromPort", "the web build has no output ports");
    }
    #else
    /** Takes a channel group off its output port again (unsupported in HTML5, FMOD_ERR_UNSUPPORTED there). */
    public static inline function detachChannelGroupFromPort(group:ChannelGroup):FmodResult {
        return NativeStudio.sys_detach_channel_group_from_port(group);
    }
    #end

    /** Switches the output device (see getDriverCount/getDriverName). */
    public static inline function setDriver(index:Int):FmodResult {
        return NativeStudio.sys_set_driver(index);
    }

    public static inline function getDriver():Int {
        return NativeStudio.sys_get_driver();
    }

    /**
     * The pool channel at index (see Channel.getIndex). FMOD hands back a
     * reference to the pool slot rather than to the sound playing in it,
     * so this is a separate handle from the one play returned, shared by
     * every call for the same index. The channel may be idle, and every
     * call on an idle channel reports FMOD_ERR_INVALID_HANDLE until FMOD
     * reuses the slot. Stop the handle when done with it to release it.
     * Channel.NULL on failure.
     */
    public static inline function getChannel(index:Int):Channel {
        return NativeStudio.sys_get_channel(index);
    }

    /** The active output type (FMOD_OUTPUTTYPE), -1 on failure. */
    public static inline function getOutput():FmodOutputType {
        return NativeStudio.sys_get_output();
    }

    /** Speaker count of a speaker mode, 0 on failure. */
    public static inline function getSpeakerModeChannels(speakerMode:FmodSpeakerMode):Int {
        return NativeStudio.sys_get_speaker_mode_channels(speakerMode);
    }

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /**
     * FMOD's default upmix or downmix matrix between two FMOD_SPEAKERMODE
     * values, row-major with one row per target channel (unsupported in
     * HTML5, null there). matrixHop widens each row past the source
     * channel count, 0 keeps rows at that count. Null on failure.
     */
    public static macro function getDefaultMixMatrix(sourceSpeakerMode:haxe.macro.Expr, targetSpeakerMode:haxe.macro.Expr, ?matrixHop:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("CoreSystem.getDefaultMixMatrix", "FMOD's web glue binds the matrix as a single float");
    }
    #else
    /**
     * FMOD's default upmix or downmix matrix between two FMOD_SPEAKERMODE
     * values, row-major with one row per target channel (unsupported in
     * HTML5, null there). matrixHop widens each row past the source
     * channel count, 0 keeps rows at that count. Null on failure.
     */
    public static function getDefaultMixMatrix(sourceSpeakerMode:FmodSpeakerMode, targetSpeakerMode:FmodSpeakerMode, matrixHop:Int = 0):Null<Array<Float>> {
        var total = NativeStudio.sys_get_default_mix_matrix(sourceSpeakerMode, targetSpeakerMode, matrixHop);
        if (total <= 0) return null;
        return [for (i in 0...total) Scratch.readF(i)];
    }
    #end
    /** Proxy for FMOD's own network streams, as "host:port" ("user:pass@host:port" with credentials). */
    public static inline function setNetworkProxy(proxy:String):FmodResult {
        return NativeStudio.sys_set_network_proxy(proxy);
    }

    /** The proxy set by setNetworkProxy, "" when none is set or on failure. */
    public static inline function getNetworkProxy():String {
        return NativeStudio.sys_get_network_proxy();
    }

    /** Timeout in milliseconds for FMOD's own network streams. */
    public static inline function setNetworkTimeout(ms:Int):FmodResult {
        return NativeStudio.sys_set_network_timeout(ms);
    }

    /** The network timeout in milliseconds, -1 on failure. */
    public static inline function getNetworkTimeout():Int {
        return NativeStudio.sys_get_network_timeout();
    }

    /**
     * Where one output speaker sits for panning, as x (left -1 to right 1)
     * and y (back -1 to front 1), and whether it is fed at all.
     */
    public static inline function setSpeakerPosition(speaker:FmodSpeaker, x:Float, y:Float, active:Bool):FmodResult {
        return NativeStudio.sys_set_speaker_position(speaker, x, y, active);
    }

    /** The position set for one speaker (see setSpeakerPosition), or null on failure. */
    public static function getSpeakerPosition(speaker:FmodSpeaker):Null<{x:Float, y:Float, active:Bool}> {
        var result:FmodResult = NativeStudio.sys_get_speaker_position(speaker);
        if (!result.isOk()) return null;
        return {x: Scratch.readF(0), y: Scratch.readF(1), active: Scratch.readF(2) != 0};
    }
    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /**
     * The description FMOD registered for a built-in effect type, its
     * name, version, buffer counts and parameter count (unsupported in
     * HTML5, null there). Null for a type FMOD does not know.
     */
    public static macro function getDspInfoByType(type:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("CoreSystem.getDspInfoByType", "embind cannot marshal the description pointer");
    }
    #else
    /**
     * The description FMOD registered for a built-in effect type, its
     * name, version, buffer counts and parameter count (unsupported in
     * HTML5, null there). Null for a type FMOD does not know.
     */
    public static function getDspInfoByType(type:DspType):Null<{name:String, version:Int, inputBuffers:Int, outputBuffers:Int, parameterCount:Int}> {
        var name = NativeStudio.sys_get_dsp_info_by_type(type);
        var result:FmodResult = NativeStudio.sys_last_result();
        if (!result.isOk()) return null;
        return {name: name, version: Scratch.readI(0), inputBuffers: Scratch.readI(1),
            outputBuffers: Scratch.readI(2), parameterCount: Scratch.readI(3)};
    }
    #end

    /** The plugin handle of the output mode in use, 0 on failure. */
    public static inline function getOutputByPlugin():Int {
        return NativeStudio.sys_get_output_by_plugin();
    }

    /**
     * Selects the output mode by plugin handle. FMOD's contract is a call
     * before initialization, which the library owns. On a running native
     * system the current handle reports OK and leaves the output alone,
     * while another handle re-selects the output device on the spot. The
     * web build reports FMOD_ERR_INITIALIZED once running.
     */
    public static inline function setOutputByPlugin(handle:Int):FmodResult {
        return NativeStudio.sys_set_output_by_plugin(handle);
    }

}
