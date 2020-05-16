package haxefmod;

#if windows
@:keep
@:include('linc_faxe.h')
#if !display
@:build(linc.Linc.touch())
@:build(linc.Linc.xml('faxe'))
#end
extern class HaxeFmod {

    //// FMOD System

    @:native("linc::faxe::fmod_set_debug")
    public static function fmod_set_debug(onOff:Bool):Void;

    @:native("linc::faxe::fmod_init")
    public static function fmod_init(numChannels:Int = 128):Void;

    @:native("linc::faxe::fmod_update")
    public static function fmod_update():Void;

    //// Sound Banks

    @:native("linc::faxe::fmod_load_bank")
    public static function fmod_load_bank(bankFilePath:String):Void;

    @:native("linc::faxe::fmod_unload_bank")
    public static function fmod_unload_bank(bankFilePath:String):Void;

    //// Event Descriptions

    @:native("linc::faxe::fmod_load_event_description")
    public static function fmod_load_event_description(eventPath:String):Void;

    @:native("linc::faxe::fmod_is_event_description_loaded")
    public static function fmod_is_event_description_loaded(eventDescriptionName:String):Bool;

    //// Event Instances

    @:native("linc::faxe::fmod_create_event_instance_one_shot")
    public static function fmod_create_event_instance_one_shot(eventName:String):Void;

    @:native("linc::faxe::fmod_create_event_instance_named")
    public static function fmod_create_event_instance_named(eventName:String, eventInstanceName:String):Void;

    @:native("linc::faxe::fmod_is_event_instance_loaded")
    public static function fmod_is_event_instance_loaded(eventName:String):Bool;

    @:native("linc::faxe::fmod_play_event_instance")
    public static function fmod_play_event_instance(eventInstanceName:String):Void;

    @:native("linc::faxe::fmod_set_pause_on_event_instance")
    public static function fmod_set_pause_on_event_instance(eventInstanceName:String, shouldBePaused:Bool):Void;

    @:native("linc::faxe::fmod_stop_event_instance")
    public static function fmod_stop_event_instance(eventInstanceName:String, forceStop:Bool):Void;

    @:native("linc::faxe::fmod_release_event_instance")
    public static function fmod_release_event_instance(eventInstanceName:String):Void;

    @:native("linc::faxe::fmod_is_event_instance_playing")
    public static function fmod_is_event_instance_playing(eventInstanceName:String):Bool;

    @:native("linc::faxe::fmod_get_event_instance_playback_state")
    public static function fmod_get_event_instance_playback_state(eventInstanceName:String):FmodStudioPlaybackState;

    @:native("linc::faxe::fmod_get_event_instance_param")
    public static function fmod_get_event_instance_param(eventInstanceName:String, paramName:String):Float;

    @:native("linc::faxe::fmod_set_event_instance_param")
    public static function fmod_set_event_instance_param(eventInstanceName:String, paramName:String, value:Float):Void;

    //// Callbacks

    @:native("linc::faxe::fmod_add_playback_listener_to_primary_event_instance")
    public static function fmod_add_playback_listener_to_primary_event_instance(eventInstanceName:String):Void;

    @:native("linc::faxe::fmod_check_for_primary_event_instance_callback")
    public static function fmod_check_for_primary_event_instance_callback(callbackEventMask:UInt):Bool;
}

#elseif html5
class HaxeFmod {
    public static function fmod_set_debug(onOff:Bool):Void {}
    public static function fmod_init(numChannels:Int = 128):Void {}
    public static function fmod_update():Void {}
    public static function fmod_load_bank(bankFilePath:String):Void {}
    public static function fmod_unload_bank(bankFilePath:String):Void {}
    public static function fmod_load_event_description(eventPath:String):Void {}
    public static function fmod_is_event_description_loaded(eventDescriptionName:String):Bool {return true;}
    public static function fmod_create_event_instance_one_shot(eventName:String):Void {trace("Tried to play a sound effect");}
    public static function fmod_create_event_instance_named(eventName:String, eventInstanceName:String):Void {}
    public static function fmod_is_event_instance_loaded(eventName:String):Bool {return true;}
    public static function fmod_play_event_instance(eventInstanceName:String):Void {}
    public static function fmod_set_pause_on_event_instance(eventInstanceName:String, shouldBePaused:Bool):Void {}
    public static function fmod_stop_event_instance(eventInstanceName:String, forceStop:Bool):Void {}
    public static function fmod_release_event_instance(eventInstanceName:String):Void {}
    public static function fmod_is_event_instance_playing(eventInstanceName:String):Bool {return true;}
    public static function fmod_get_event_instance_playback_state(eventInstanceName:String):FmodStudioPlaybackState {return FMOD_STUDIO_PLAYBACK_PLAYING;}
    public static function fmod_get_event_instance_param(eventInstanceName:String, paramName:String):Float {return 1.0;}
    public static function fmod_set_event_instance_param(eventInstanceName:String, paramName:String, value:Float):Void {}
    public static function fmod_add_playback_listener_to_primary_event_instance(eventInstanceName:String):Void {}
    public static function fmod_check_for_primary_event_instance_callback(callbackEventMask:UInt):Bool {return true;}
}
#end

//// Exported enums

enum abstract FmodStudioPlaybackState(Int) {
    var FMOD_STUDIO_PLAYBACK_PLAYING;
    var FMOD_STUDIO_PLAYBACK_SUSTAINING;
    var FMOD_STUDIO_PLAYBACK_STOPPED;
    var FMOD_STUDIO_PLAYBACK_STARTING;
    var FMOD_STUDIO_PLAYBACK_STOPPING;
    // This value comes back from FMOD as 65536, so I am not quite sure how it will map
    var FMOD_STUDIO_PLAYBACK_FORCEINT;
}

enum abstract FmodResult(Int) {
    var FMOD_OK;
    var FMOD_ERR_BADCOMMAND;
    var FMOD_ERR_CHANNEL_ALLOC;
    var FMOD_ERR_CHANNEL_STOLEN;
    var FMOD_ERR_DMA;
    var FMOD_ERR_DSP_CONNECTION;
    var FMOD_ERR_DSP_DONTPROCESS;
    var FMOD_ERR_DSP_FORMAT;
    var FMOD_ERR_DSP_INUSE;
    var FMOD_ERR_DSP_NOTFOUND;
    var FMOD_ERR_DSP_RESERVED;
    var FMOD_ERR_DSP_SILENCE;
    var FMOD_ERR_DSP_TYPE;
    var FMOD_ERR_FILE_BAD;
    var FMOD_ERR_FILE_COULDNOTSEEK;
    var FMOD_ERR_FILE_DISKEJECTED;
    var FMOD_ERR_FILE_EOF;
    var FMOD_ERR_FILE_ENDOFDATA;
    var FMOD_ERR_FILE_NOTFOUND;
    var FMOD_ERR_FORMAT;
    var FMOD_ERR_HEADER_MISMATCH;
    var FMOD_ERR_HTTP;
    var FMOD_ERR_HTTP_ACCESS;
    var FMOD_ERR_HTTP_PROXY_AUTH;
    var FMOD_ERR_HTTP_SERVER_ERROR;
    var FMOD_ERR_HTTP_TIMEOUT;
    var FMOD_ERR_INITIALIZATION;
    var FMOD_ERR_INITIALIZED;
    var FMOD_ERR_INTERNAL;
    var FMOD_ERR_INVALID_FLOAT;
    var FMOD_ERR_INVALID_HANDLE;
    var FMOD_ERR_INVALID_PARAM;
    var FMOD_ERR_INVALID_POSITION;
    var FMOD_ERR_INVALID_SPEAKER;
    var FMOD_ERR_INVALID_SYNCPOINT;
    var FMOD_ERR_INVALID_THREAD;
    var FMOD_ERR_INVALID_VECTOR;
    var FMOD_ERR_MAXAUDIBLE;
    var FMOD_ERR_MEMORY;
    var FMOD_ERR_MEMORY_CANTPOINT;
    var FMOD_ERR_NEEDS3D;
    var FMOD_ERR_NEEDSHARDWARE;
    var FMOD_ERR_NET_CONNECT;
    var FMOD_ERR_NET_SOCKET_ERROR;
    var FMOD_ERR_NET_URL;
    var FMOD_ERR_NET_WOULD_BLOCK;
    var FMOD_ERR_NOTREADY;
    var FMOD_ERR_OUTPUT_ALLOCATED;
    var FMOD_ERR_OUTPUT_CREATEBUFFER;
    var FMOD_ERR_OUTPUT_DRIVERCALL;
    var FMOD_ERR_OUTPUT_FORMAT;
    var FMOD_ERR_OUTPUT_INIT;
    var FMOD_ERR_OUTPUT_NODRIVERS;
    var FMOD_ERR_PLUGIN;
    var FMOD_ERR_PLUGIN_MISSING;
    var FMOD_ERR_PLUGIN_RESOURCE;
    var FMOD_ERR_PLUGIN_VERSION;
    var FMOD_ERR_RECORD;
    var FMOD_ERR_REVERB_CHANNELGROUP;
    var FMOD_ERR_REVERB_INSTANCE;
    var FMOD_ERR_SUBSOUNDS;
    var FMOD_ERR_SUBSOUND_ALLOCATED;
    var FMOD_ERR_SUBSOUND_CANTMOVE;
    var FMOD_ERR_TAGNOTFOUND;
    var FMOD_ERR_TOOMANYCHANNELS;
    var FMOD_ERR_TRUNCATED;
    var FMOD_ERR_UNIMPLEMENTED;
    var FMOD_ERR_UNINITIALIZED;
    var FMOD_ERR_UNSUPPORTED;
    var FMOD_ERR_VERSION;
    var FMOD_ERR_EVENT_ALREADY_LOADED;
    var FMOD_ERR_EVENT_LIVEUPDATE_BUSY;
    var FMOD_ERR_EVENT_LIVEUPDATE_MISMATCH;
    var FMOD_ERR_EVENT_LIVEUPDATE_TIMEOUT;
    var FMOD_ERR_EVENT_NOTFOUND;
    var FMOD_ERR_STUDIO_UNINITIALIZED;
    var FMOD_ERR_STUDIO_NOT_LOADED;
    var FMOD_ERR_INVALID_STRING;
    var FMOD_ERR_ALREADY_LOCKED;
    var FMOD_ERR_NOT_LOCKED;
    var FMOD_ERR_RECORD_DISCONNECTED;
    var FMOD_ERR_TOOMANYSAMPLES;
}
