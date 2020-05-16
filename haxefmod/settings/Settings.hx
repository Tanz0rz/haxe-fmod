package haxefmod.settings;

// To set these settings, change the struct in the return value of LoadDefaultFmodSettings()
typedef FmodSettings = {
    var DebugMessages:Bool; // Displays various debug messages to console when calling into the interal FMOD API. This can be set on a per-build basis with the -debug flag
}

class Settings {
    public static function LoadDefaultFmodSettings():FmodSettings {
        return {
          DebugMessages : true,
        };
    }
}