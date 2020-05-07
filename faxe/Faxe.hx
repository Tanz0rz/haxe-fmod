package faxe;

@:keep
@:include('linc_faxe.h')
#if !display
@:build(linc.Linc.touch())
@:build(linc.Linc.xml('faxe'))
#end
extern class Faxe {
	//// FMOD System
	@:native("linc::faxe::faxe_init")
	public static function fmod_init(numChannels:Int = 128):Void;

	@:native("linc::faxe::faxe_set_debug")
	public static function fmod_set_debug(onOff:Bool):Void;

	@:native("linc::faxe::faxe_update")
	public static function fmod_update():Void;

	//// Sound Banks
	@:native("linc::faxe::faxe_load_bank")
	public static function fmod_load_bank(bankFilePath:String):Void;

	@:native("linc::faxe::faxe_unload_bank")
	public static function fmod_unload_bank(bankFilePath:String):Void;

	//// Event Descriptions
	@:native("linc::faxe::faxe_load_event_description")
	public static function fmod_load_event_description(eventPath:String):Void;

	@:native("linc::faxe::faxe_is_event_description_loaded")
	public static function fmod_is_event_description_loaded(eventDescriptionName:String):Bool;

	//// Event Instances
	@:native("linc::faxe::faxe_create_event_instance_one_shot")
	public static function fmod_create_event_instance_one_shot(eventName:String):Void;

	@:native("linc::faxe::faxe_create_event_instance_named")
	public static function fmod_create_event_instance_named(eventName:String, eventInstanceName:String):Void;

	@:native("linc::faxe::faxe_is_event_instance_loaded")
	public static function fmod_is_event_instance_loaded(eventName:String):Bool;

	@:native("linc::faxe::faxe_play_event_instance")
	public static function fmod_play_event_instance(eventInstanceName:String):Void;

	@:native("linc::faxe::faxe_set_pause_on_event_instance")
	public static function fmod_set_pause_on_event_instance(eventInstanceName:String, shouldBePaused:Bool):Void;

	@:native("linc::faxe::faxe_stop_event_instance")
	public static function fmod_stop_event_instance(eventInstanceName:String, forceStop:Bool):Void;

	@:native("linc::faxe::faxe_release_event_instance")
	public static function fmod_release_event_instance(eventInstanceName:String):Void;

	@:native("linc::faxe::faxe_is_event_instance_playing")
	public static function fmod_is_event_instance_playing(eventInstanceName:String):Bool;

	@:native("linc::faxe::faxe_get_event_instance_playback_state")
	public static function fmod_get_event_instance_playback_state(eventInstanceName:String):FmodStudioPlaybackState;

	@:native("linc::faxe::faxe_get_event_instance_param")
	public static function fmod_get_event_instance_param(eventInstanceName:String, paramName:String):Float;

	@:native("linc::faxe::faxe_set_event_instance_param")
	public static function fmod_set_event_instance_param(eventInstanceName:String, paramName:String, value:Float):Void;

	//// Callbacks
	@:native("linc::faxe::faxe_add_playback_listener_to_primary_event_instance")
	public static function fmod_add_playback_listener_to_primary_event_instance(eventInstanceName:String):Void;

	@:native("linc::faxe::faxe_check_for_primary_event_instance_callback")
	public static function fmod_check_for_primary_event_instance_callback(callbackEventMask:UInt):Bool;
}

//// Exported enums
// This enum leverages Haxe 4.x.x syntax to simplify abstract enum declarations
// Eventually, all enums will be converted to this simpler form
enum abstract FmodStudioPlaybackState(Int) {
	var FMOD_STUDIO_PLAYBACK_PLAYING;
	var FMOD_STUDIO_PLAYBACK_SUSTAINING;
	var FMOD_STUDIO_PLAYBACK_STOPPED;
	var FMOD_STUDIO_PLAYBACK_STARTING;
	var FMOD_STUDIO_PLAYBACK_STOPPING;
	// This value comes back from FMOD as 65536, so I am not quite sure how it will map
	var FMOD_STUDIO_PLAYBACK_FORCEINT;
}

@:enum abstract FmodResult(Int) from Int to Int {
	var FMOD_OK = 0;
	var FMOD_ERR_BADCOMMAND = 1;
	var FMOD_ERR_CHANNEL_ALLOC = 2;
	var FMOD_ERR_CHANNEL_STOLEN = 3;
	var FMOD_ERR_DMA = 4;
	var FMOD_ERR_DSP_CONNECTION = 5;
	var FMOD_ERR_DSP_DONTPROCESS = 6;
	var FMOD_ERR_DSP_FORMAT = 7;
	var FMOD_ERR_DSP_INUSE = 8;
	var FMOD_ERR_DSP_NOTFOUND = 9;
	var FMOD_ERR_DSP_RESERVED = 10;
	var FMOD_ERR_DSP_SILENCE = 11;
	var FMOD_ERR_DSP_TYPE = 12;
	var FMOD_ERR_FILE_BAD = 13;
	var FMOD_ERR_FILE_COULDNOTSEEK = 14;
	var FMOD_ERR_FILE_DISKEJECTED = 15;
	var FMOD_ERR_FILE_EOF = 16;
	var FMOD_ERR_FILE_ENDOFDATA = 17;
	var FMOD_ERR_FILE_NOTFOUND = 18;
	var FMOD_ERR_FORMAT = 19;
	var FMOD_ERR_HEADER_MISMATCH = 20;
	var FMOD_ERR_HTTP = 21;
	var FMOD_ERR_HTTP_ACCESS = 22;
	var FMOD_ERR_HTTP_PROXY_AUTH = 23;
	var FMOD_ERR_HTTP_SERVER_ERROR = 24;
	var FMOD_ERR_HTTP_TIMEOUT = 25;
	var FMOD_ERR_INITIALIZATION = 26;
	var FMOD_ERR_INITIALIZED = 27;
	var FMOD_ERR_INTERNAL = 28;
	var FMOD_ERR_INVALID_FLOAT = 29;
	var FMOD_ERR_INVALID_HANDLE = 30;
	var FMOD_ERR_INVALID_PARAM = 31;
	var FMOD_ERR_INVALID_POSITION = 32;
	var FMOD_ERR_INVALID_SPEAKER = 33;
	var FMOD_ERR_INVALID_SYNCPOINT = 34;
	var FMOD_ERR_INVALID_THREAD = 35;
	var FMOD_ERR_INVALID_VECTOR = 36;
	var FMOD_ERR_MAXAUDIBLE = 37;
	var FMOD_ERR_MEMORY = 38;
	var FMOD_ERR_MEMORY_CANTPOINT = 39;
	var FMOD_ERR_NEEDS3D = 40;
	var FMOD_ERR_NEEDSHARDWARE = 41;
	var FMOD_ERR_NET_CONNECT = 42;
	var FMOD_ERR_NET_SOCKET_ERROR = 43;
	var FMOD_ERR_NET_URL = 44;
	var FMOD_ERR_NET_WOULD_BLOCK = 45;
	var FMOD_ERR_NOTREADY = 46;
	var FMOD_ERR_OUTPUT_ALLOCATED = 47;
	var FMOD_ERR_OUTPUT_CREATEBUFFER = 48;
	var FMOD_ERR_OUTPUT_DRIVERCALL = 49;
	var FMOD_ERR_OUTPUT_FORMAT = 50;
	var FMOD_ERR_OUTPUT_INIT = 51;
	var FMOD_ERR_OUTPUT_NODRIVERS = 52;
	var FMOD_ERR_PLUGIN = 53;
	var FMOD_ERR_PLUGIN_MISSING = 54;
	var FMOD_ERR_PLUGIN_RESOURCE = 55;
	var FMOD_ERR_PLUGIN_VERSION = 56;
	var FMOD_ERR_RECORD = 57;
	var FMOD_ERR_REVERB_CHANNELGROUP = 58;
	var FMOD_ERR_REVERB_INSTANCE = 59;
	var FMOD_ERR_SUBSOUNDS = 60;
	var FMOD_ERR_SUBSOUND_ALLOCATED = 61;
	var FMOD_ERR_SUBSOUND_CANTMOVE = 62;
	var FMOD_ERR_TAGNOTFOUND = 63;
	var FMOD_ERR_TOOMANYCHANNELS = 64;
	var FMOD_ERR_TRUNCATED = 65;
	var FMOD_ERR_UNIMPLEMENTED = 66;
	var FMOD_ERR_UNINITIALIZED = 67;
	var FMOD_ERR_UNSUPPORTED = 68;
	var FMOD_ERR_VERSION = 69;
	var FMOD_ERR_EVENT_ALREADY_LOADED = 70;
	var FMOD_ERR_EVENT_LIVEUPDATE_BUSY = 71;
	var FMOD_ERR_EVENT_LIVEUPDATE_MISMATCH = 72;
	var FMOD_ERR_EVENT_LIVEUPDATE_TIMEOUT = 73;
	var FMOD_ERR_EVENT_NOTFOUND = 74;
	var FMOD_ERR_STUDIO_UNINITIALIZED = 75;
	var FMOD_ERR_STUDIO_NOT_LOADED = 76;
	var FMOD_ERR_INVALID_STRING = 77;
	var FMOD_ERR_ALREADY_LOCKED = 78;
	var FMOD_ERR_NOT_LOCKED = 79;
	var FMOD_ERR_RECORD_DISCONNECTED = 80;
	var FMOD_ERR_TOOMANYSAMPLES = 81;
}
