package haxefmod;

// To set these settings, change the struct in the return value of LoadDefaultFmodSettings()
typedef FmodSettings = {
    var SuppressDebugMessages:Bool; // Overwrites the -debug build flag and suppresses all haxefmod debug messages
}

class Settings {
    public static function LoadDefaultFmodSettings():FmodSettings {
        return {
          SuppressDebugMessages : false,
        };
    }
}