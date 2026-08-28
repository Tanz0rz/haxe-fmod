package haxefmod.runtime;

/**
 * Settings for FmodRuntime.init. Every field is optional. Unset fields fall
 * back to compile-time defines, then to the built-in defaults.
 *
 * Compile-time defines (project.xml <haxedef/> or -D):
 *   -D haxefmod_num_channels=128
 *   -D haxefmod_sample_rate=48000
 *   -D haxefmod_live_update        (force live update ON in any build)
 *   -D haxefmod_no_live_update     (force live update OFF in any build)
 *   -D haxefmod_no_mute_when_unfocused  (keep audio playing when unfocused)
 *   -D haxefmod_bank_folder=assets/fmod/Desktop
 *   -D haxefmod_log_level=2
 *   -D haxefmod_dsp_buffer_size=1024
 *   -D haxefmod_software_channels=64
 */
typedef FmodSettings = {
    /** Max virtual voices. Default 128. */
    @:optional var numChannels:Int;

    /** Mixer sample rate. Default 0 (FMOD's device default). */
    @:optional var sampleRate:Int;

    /** FMOD_SPEAKERMODE value. Default 0 (device default). */
    @:optional var speakerMode:Int;

    /**
     * Mixer block size in samples (System::setDSPBufferSize). Smaller
     * buffers cut latency and cost CPU. Default 0 (FMOD's default). HTML5
     * ignores this, the web build fixes the buffer at 2048 samples.
     */
    @:optional var dspBufferSize:Int;

    /** Number of mixer blocks queued ahead. Default 0 (FMOD's default, 2). Ignored on HTML5. */
    @:optional var dspNumBuffers:Int;

    /**
     * Real (audible) voices the mixer runs at once (System::setSoftwareChannels).
     * Voices past this cap go virtual. Default 0 (FMOD's default, 64).
     */
    @:optional var softwareChannels:Int;

    /**
     * File buffer size in bytes for streamed sounds (System::setStreamBufferSize).
     * Default 0 (FMOD's default, 16384).
     */
    @:optional var streamBufferSize:Int;

    /**
     * Turns on FMOD profiling (FMOD_INIT_PROFILE_ENABLE). Needed for
     * Bus.getCpuUsage, EventInstance.getCpuUsage, and Dsp.getCpuUsage to
     * report anything, and lets the FMOD Profiler connect. Default false.
     */
    @:optional var profiling:Bool;

    /**
     * Turns on the per-channel distance lowpass (FMOD_INIT_CHANNEL_DISTANCEFILTER).
     * 3D channels then muffle with distance, and Channel.set3DDistanceFilter
     * tunes it. Default false.
     */
    @:optional var distanceFilter:Bool;

    /**
     * Enables the FMOD Studio Live Update TCP connection (port 9264).
     * Default: true in -debug builds, false otherwise. Opens a firewall
     * prompt on Mac/Windows when enabled.
     */
    @:optional var liveUpdate:Bool;

    /** FMOD debug logging level: 0=none, 1=error, 2=warning, 3=log. Default 1. */
    @:optional var logLevel:Int;

    /** Folder the auto-loaded banks live in. Default "assets/fmod/Desktop". */
    @:optional var bankFolder:String;

    /**
     * Bank file names to load during init, resolved against bankFolder.
     * Default ["Master.bank", "Master.strings.bank"]. Pass [] to manage
     * all bank loading yourself through FmodRuntime.banks.
     */
    @:optional var autoLoadBanks:Array<String>;

    /**
     * Drives FMOD from a background thread (native) or timer (html5) so
     * audio keeps running when the game loop stalls. Default true.
     * Typed callbacks are still only delivered from update().
     */
    @:optional var autoUpdate:Bool;

    /**
     * Mutes the master output while the game window is unfocused, so audio
     * doesn't play to a window nobody is looking at. FMOD keeps mixing, so
     * sounds play out in real time instead of queuing up and blasting out
     * the instant focus returns. Default true.
     *
     * The game must report focus changes via FmodManager.SetWindowFocused
     * (or FmodRuntime.setWindowFocused) for this to take effect. Set false
     * (or -D haxefmod_no_mute_when_unfocused) to keep audio playing in the
     * background.
     */
    @:optional var muteWhenUnfocused:Bool;

    /**
     * Clamps the velocity magnitude pushed for attached instances and the
     * flixel listener, in game units per second. Fast-moving objects can
     * produce audible doppler pitch flutter, and this caps the velocity
     * FMOD sees without touching the position. Default 0 (no clamp).
     */
    @:optional var maxAttachedVelocity:Float;
}

/** FmodSettings with every field resolved. */
typedef ResolvedFmodSettings = {
    var numChannels:Int;
    var sampleRate:Int;
    var speakerMode:Int;
    var dspBufferSize:Int;
    var dspNumBuffers:Int;
    var softwareChannels:Int;
    var streamBufferSize:Int;
    var profiling:Bool;
    var distanceFilter:Bool;
    var liveUpdate:Bool;
    var logLevel:Int;
    var bankFolder:String;
    var autoLoadBanks:Array<String>;
    var autoUpdate:Bool;
    var muteWhenUnfocused:Bool;
    var maxAttachedVelocity:Float;
}

class FmodSettingsResolver {
    /** Applies define-level and built-in defaults to an optional settings object. */
    public static function resolve(?settings:FmodSettings):ResolvedFmodSettings {
        var defaultLiveUpdate =
            #if haxefmod_no_live_update false
            #elseif haxefmod_live_update true
            #elseif debug true
            #else false #end;

        var defaultMuteWhenUnfocused =
            #if haxefmod_no_mute_when_unfocused false
            #else true #end;

        var defaultChannels = Defines.getInt("haxefmod_num_channels", 128);
        var defaultSampleRate = Defines.getInt("haxefmod_sample_rate", 0);
        var defaultLogLevel = Defines.getInt("haxefmod_log_level", 1);
        var defaultBankFolder = Defines.getString("haxefmod_bank_folder", "assets/fmod/Desktop");
        var defaultDspBufferSize = Defines.getInt("haxefmod_dsp_buffer_size", 0);
        var defaultSoftwareChannels = Defines.getInt("haxefmod_software_channels", 0);

        return {
            numChannels: settings != null && settings.numChannels != null ? settings.numChannels : defaultChannels,
            sampleRate: settings != null && settings.sampleRate != null ? settings.sampleRate : defaultSampleRate,
            speakerMode: settings != null && settings.speakerMode != null ? settings.speakerMode : 0,
            dspBufferSize: settings != null && settings.dspBufferSize != null ? settings.dspBufferSize : defaultDspBufferSize,
            dspNumBuffers: settings != null && settings.dspNumBuffers != null ? settings.dspNumBuffers : 0,
            softwareChannels: settings != null && settings.softwareChannels != null
                ? settings.softwareChannels
                : defaultSoftwareChannels,
            streamBufferSize: settings != null && settings.streamBufferSize != null ? settings.streamBufferSize : 0,
            profiling: settings != null && settings.profiling != null ? settings.profiling : false,
            distanceFilter: settings != null && settings.distanceFilter != null ? settings.distanceFilter : false,
            liveUpdate: settings != null && settings.liveUpdate != null ? settings.liveUpdate : defaultLiveUpdate,
            logLevel: settings != null && settings.logLevel != null ? settings.logLevel : defaultLogLevel,
            bankFolder: settings != null && settings.bankFolder != null ? settings.bankFolder : defaultBankFolder,
            autoLoadBanks: settings != null && settings.autoLoadBanks != null
                ? settings.autoLoadBanks
                : ["Master.bank", "Master.strings.bank"],
            autoUpdate: settings != null && settings.autoUpdate != null ? settings.autoUpdate : true,
            muteWhenUnfocused: settings != null && settings.muteWhenUnfocused != null
                ? settings.muteWhenUnfocused
                : defaultMuteWhenUnfocused,
            maxAttachedVelocity: settings != null && settings.maxAttachedVelocity != null
                ? settings.maxAttachedVelocity
                : 0.0,
        };
    }
}
