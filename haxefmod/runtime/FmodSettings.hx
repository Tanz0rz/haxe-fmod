package haxefmod.runtime;

/**
 * Settings for FmodRuntime.init. Every field is optional; unset fields fall
 * back to compile-time defines, then to the built-in defaults.
 *
 * Compile-time defines (project.xml <haxedef/> or -D):
 *   -D haxefmod_num_channels=128
 *   -D haxefmod_sample_rate=48000
 *   -D haxefmod_live_update        (force live update ON in any build)
 *   -D haxefmod_no_live_update     (force live update OFF in any build)
 *   -D haxefmod_bank_folder=assets/fmod/Desktop
 *   -D haxefmod_log_level=2
 */
typedef FmodSettings = {
    /** Max virtual voices. Default 128. */
    @:optional var numChannels:Int;

    /** Mixer sample rate. Default 0 (FMOD's device default). */
    @:optional var sampleRate:Int;

    /** FMOD_SPEAKERMODE value. Default 0 (device default). */
    @:optional var speakerMode:Int;

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
}

/** FmodSettings with every field resolved. */
typedef ResolvedFmodSettings = {
    var numChannels:Int;
    var sampleRate:Int;
    var speakerMode:Int;
    var liveUpdate:Bool;
    var logLevel:Int;
    var bankFolder:String;
    var autoLoadBanks:Array<String>;
    var autoUpdate:Bool;
}

class FmodSettingsResolver {
    /** Applies define-level and built-in defaults to an optional settings object. */
    public static function resolve(?settings:FmodSettings):ResolvedFmodSettings {
        var defaultLiveUpdate =
            #if haxefmod_no_live_update false
            #elseif haxefmod_live_update true
            #elseif debug true
            #else false #end;

        var defaultChannels = Defines.getInt("haxefmod_num_channels", 128);
        var defaultSampleRate = Defines.getInt("haxefmod_sample_rate", 0);
        var defaultLogLevel = Defines.getInt("haxefmod_log_level", 1);
        var defaultBankFolder = Defines.getString("haxefmod_bank_folder", "assets/fmod/Desktop");

        return {
            numChannels: settings != null && settings.numChannels != null ? settings.numChannels : defaultChannels,
            sampleRate: settings != null && settings.sampleRate != null ? settings.sampleRate : defaultSampleRate,
            speakerMode: settings != null && settings.speakerMode != null ? settings.speakerMode : 0,
            liveUpdate: settings != null && settings.liveUpdate != null ? settings.liveUpdate : defaultLiveUpdate,
            logLevel: settings != null && settings.logLevel != null ? settings.logLevel : defaultLogLevel,
            bankFolder: settings != null && settings.bankFolder != null ? settings.bankFolder : defaultBankFolder,
            autoLoadBanks: settings != null && settings.autoLoadBanks != null
                ? settings.autoLoadBanks
                : ["Master.bank", "Master.strings.bank"],
            autoUpdate: settings != null && settings.autoUpdate != null ? settings.autoUpdate : true,
        };
    }
}
