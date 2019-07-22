package faxe;

@:keep
@:include('linc_faxe.h')
@:build(linc.Linc.touch())
@:build(linc.Linc.xml('faxe'))

extern class Faxe
{
	@:native("linc::faxe::faxe_init")
	public static function fmod_init(numChannels:Int = 128):Void;

	@:native("linc::faxe::faxe_update")
	public static function fmod_update():Void;

	@:native("linc::faxe::faxe_load_bank")
	public static function fmod_load_bank(bankFilePath:String):Void;

	@:native("linc::faxe::faxe_unload_bank")
	public static function fmod_unload_bank(bankFilePath:String):Void;

	@:native("linc::faxe::faxe_load_sound")
	public static function fmod_load_sound(soundPath:String, looping:Bool = false, streaming:Bool = false):FmodResult;

	@:native("linc::faxe::faxe_get_sound")
	public static function fmod_get_sound(soundPath:String):cpp.Pointer<FmodSound>;
	
	@:native("linc::faxe::faxe_unload_sound")
	public static function fmod_unload_sound(bankFilePath:String):Void;

	@:native("linc::faxe::faxe_load_event")
	public static function fmod_load_event(eventPath:String, eventName:String):Void;

	@:native("linc::faxe::faxe_play_event")
	public static function fmod_play_event(eventName:String):Void;
	
	@:native("linc::faxe::faxe_play_sound")
	public static function fmod_play_sound(soundName:String, paused:Bool = false):FmodResult;
	
	@:native("linc::faxe::faxe_play_sound_with_channel")
	public static function faxe_play_sound_with_channel(soundName:String, paused:Bool): cpp.Pointer<FmodChannel>;

	@:native("linc::faxe::faxe_stop_event")
	public static function fmod_stop_event(eventName:String, forceStop:Bool):Void;

	@:native("linc::faxe::faxe_event_playing")
	public static function fmod_event_is_playing(eventName:String):Bool;

	@:native("linc::faxe::faxe_get_event_param")
	public static function fmod_get_param(eventName:String, paramName:String):Float;

	@:native("linc::faxe::faxe_set_event_param")
	public static function fmod_set_param(eventName:String, paramName:String, sValue:Float):Void;
	
	@:native("linc::faxe::faxe_get_system")
	public static function fmod_get_system() : cpp.Pointer<FmodSystem>;
	
	@:native("linc::faxe::faxe_set_debug")
	public static function fmod_set_debug(onOff : Bool):Void;
}

@:enum abstract FmodTimeUnit(Int) from Int to Int {
	var FTM_MS 			= 0x00000001;
	var FTM_PCM 		= 0x00000002;
	var FTM_PCMBYTES 	= 0x00000004;
	var FTM_RAWBYTES 	= 0x00000008;
	var FTM_PCMFRACTION = 0x00000010;
	var FTM_MODORDER 	= 0x00000100;
	var FTM_MODROW		= 0x00000200;
	var FTM_MODPATTERN 	= 0x00000400;
}

@:enum abstract FmodResult(Int) from Int to Int {
	var FMOD_OK													= 0;
	var FMOD_ERR_BADCOMMAND										= 1;
	var FMOD_ERR_CHANNEL_ALLOC									= 2;
	var FMOD_ERR_CHANNEL_STOLEN									= 3;
	var FMOD_ERR_DMA											= 4;
	var FMOD_ERR_DSP_CONNECTION									= 5;
	var FMOD_ERR_DSP_DONTPROCESS								= 6;
	var FMOD_ERR_DSP_FORMAT										= 7;
	var FMOD_ERR_DSP_INUSE										= 8;
	var FMOD_ERR_DSP_NOTFOUND									= 9;
	var FMOD_ERR_DSP_RESERVED									= 10;
	var FMOD_ERR_DSP_SILENCE									= 11;
	var FMOD_ERR_DSP_TYPE										= 12;
	var FMOD_ERR_FILE_BAD										= 13;
	var FMOD_ERR_FILE_COULDNOTSEEK								= 14;
	var FMOD_ERR_FILE_DISKEJECTED								= 15;
	var FMOD_ERR_FILE_EOF										= 16;
	var FMOD_ERR_FILE_ENDOFDATA									= 17;
	var FMOD_ERR_FILE_NOTFOUND									= 18;
	var FMOD_ERR_FORMAT											= 19;
	var FMOD_ERR_HEADER_MISMATCH								= 20;
	var FMOD_ERR_HTTP											= 21;
	var FMOD_ERR_HTTP_ACCESS									= 22;
	var FMOD_ERR_HTTP_PROXY_AUTH								= 23;
	var FMOD_ERR_HTTP_SERVER_ERROR								= 24;
	var FMOD_ERR_HTTP_TIMEOUT									= 25;
	var FMOD_ERR_INITIALIZATION									= 26;
	var FMOD_ERR_INITIALIZED									= 27;
	var FMOD_ERR_INTERNAL										= 28;
	var FMOD_ERR_INVALID_FLOAT									= 29;
	var FMOD_ERR_INVALID_HANDLE									= 30;
	var FMOD_ERR_INVALID_PARAM									= 31;
	var FMOD_ERR_INVALID_POSITION								= 32;
	var FMOD_ERR_INVALID_SPEAKER								= 33;
	var FMOD_ERR_INVALID_SYNCPOINT								= 34;
	var FMOD_ERR_INVALID_THREAD									= 35;
	var FMOD_ERR_INVALID_VECTOR									= 36;
	var FMOD_ERR_MAXAUDIBLE										= 37;
	var FMOD_ERR_MEMORY											= 38;
	var FMOD_ERR_MEMORY_CANTPOINT								= 39;
	var FMOD_ERR_NEEDS3D										= 40;
	var FMOD_ERR_NEEDSHARDWARE									= 41;
	var FMOD_ERR_NET_CONNECT									= 42;
	var FMOD_ERR_NET_SOCKET_ERROR								= 43;
	var FMOD_ERR_NET_URL										= 44;
	var FMOD_ERR_NET_WOULD_BLOCK								= 45;
	var FMOD_ERR_NOTREADY										= 46;
	var FMOD_ERR_OUTPUT_ALLOCATED								= 47;
	var FMOD_ERR_OUTPUT_CREATEBUFFER							= 48;
	var FMOD_ERR_OUTPUT_DRIVERCALL								= 49;
	var FMOD_ERR_OUTPUT_FORMAT									= 50;
	var FMOD_ERR_OUTPUT_INIT									= 51;
	var FMOD_ERR_OUTPUT_NODRIVERS								= 52;
	var FMOD_ERR_PLUGIN											= 53;
	var FMOD_ERR_PLUGIN_MISSING									= 54;
	var FMOD_ERR_PLUGIN_RESOURCE								= 55;
	var FMOD_ERR_PLUGIN_VERSION									= 56;
	var FMOD_ERR_RECORD											= 57;
	var FMOD_ERR_REVERB_CHANNELGROUP							= 58;
	var FMOD_ERR_REVERB_INSTANCE								= 59;
	var FMOD_ERR_SUBSOUNDS										= 60;
	var FMOD_ERR_SUBSOUND_ALLOCATED								= 61;
	var FMOD_ERR_SUBSOUND_CANTMOVE								= 62;
	var FMOD_ERR_TAGNOTFOUND									= 63;
	var FMOD_ERR_TOOMANYCHANNELS								= 64;
	var FMOD_ERR_TRUNCATED										= 65;
	var FMOD_ERR_UNIMPLEMENTED									= 66;
	var FMOD_ERR_UNINITIALIZED									= 67;
	var FMOD_ERR_UNSUPPORTED									= 68;
	var FMOD_ERR_VERSION										= 69;
	var FMOD_ERR_EVENT_ALREADY_LOADED							= 70;
	var FMOD_ERR_EVENT_LIVEUPDATE_BUSY							= 71;
	var FMOD_ERR_EVENT_LIVEUPDATE_MISMATCH						= 72;
	var FMOD_ERR_EVENT_LIVEUPDATE_TIMEOUT						= 73;
	var FMOD_ERR_EVENT_NOTFOUND									= 74;
	var FMOD_ERR_STUDIO_UNINITIALIZED							= 75;
	var FMOD_ERR_STUDIO_NOT_LOADED								= 76;
	var FMOD_ERR_INVALID_STRING									= 77;
	var FMOD_ERR_ALREADY_LOCKED									= 78;
	var FMOD_ERR_NOT_LOCKED										= 79;
	var FMOD_ERR_RECORD_DISCONNECTED							= 80;
	var FMOD_ERR_TOOMANYSAMPLES									= 81;
}

@:enum abstract FmodMode(Int) from Int to Int {
	var FMOD_DEFAULT 		 				= 0x00000000;
	var FMOD_LOOP_OFF 		 				= 0x00000001;
	var FMOD_LOOP_NORMAL 	 				= 0x00000002;
	var FMOD_LOOP_BIDI 		 				= 0x00000004;
	var FMOD_2D  			 				= 0x00000008;
	var FMOD_3D  			 				= 0x00000010;
	var FMOD_CREATESTREAM  					= 0x00000080;
	var FMOD_CREATESAMPLE 					= 0x00000100;
	var FMOD_CREATECOMPRESSEDSAMPLE 		= 0x00000200;
	var FMOD_OPENUSER  			 			= 0x00000400;
	var FMOD_OPENMEMORY  			 		= 0x00000800;
	var FMOD_OPENMEMORY_POINT  			 	= 0x10000000;
	var FMOD_OPENRAW  			 			= 0x00001000;
	var FMOD_OPENONLY  			 			= 0x00002000;
	var FMOD_ACCURATETIME  			 		= 0x00004000;
	var FMOD_MPEGSEARCH  			 		= 0x00008000;
	var FMOD_NONBLOCKING  			 		= 0x00010000;
	var FMOD_UNIQUE  			 			= 0x00020000;
	var FMOD_3D_HEADRELATIVE  			 	= 0x00040000;
	var FMOD_3D_WORLDRELATIVE  			 	= 0x00080000;
	var FMOD_3D_INVERSEROLLOFF  			= 0x00100000;
	var FMOD_3D_LINEARROLLOFF  			 	= 0x00200000;
	var FMOD_3D_LINEARSQUAREROLLOFF 		= 0x00400000;
	var FMOD_3D_INVERSETAPEREDROLLOFF  		= 0x00800000;
	var FMOD_3D_CUSTOMROLLOFF  			 	= 0x04000000;
	var FMOD_3D_IGNOREGEOMETRY  			= 0x40000000;
	var FMOD_IGNORETAGS  			 		= 0x02000000;
	var FMOD_LOWMEM  			 			= 0x08000000;
	var FMOD_LOADSECONDARYRAM  			 	= 0x20000000;
	var FMOD_VIRTUAL_PLAYFROMSTART 			= 0x80000000;
}

@:include('linc_faxe.h')
@:native("FMOD::Channel")
extern class FmodSound {
	@:native('getMode')
	function getMode( mode : cpp.Pointer<FmodMode> ) : FmodResult;
	
	@:native('getLoopCount')
	function getLoopCount( nb:cpp.Pointer<Int> ) : FmodResult;
	
	@:native('setLoopCount')
	function setLoopCount( nb:Int ) : FmodResult;
	
	@:native('setMode')
	function setMode( mode:FmodMode ) : FmodResult;
	
	@:native('getPosition')
	function getPosition( position : cpp.Pointer<cpp.UInt32>, postype : FmodTimeUnit ) : FmodResult;
	
	@:native('setPosition')
	function setPosition( position : cpp.UInt32, postype : FmodTimeUnit ) : FmodResult;
	
	//use faxe release to fully release memory
	@:native('release')
	function release() : FmodResult;
}

@:include('linc_faxe.h')
@:native("FMOD::Channel")
extern class FmodChannel {
	
	@:native('getVolume')
	function getVolume( volume : cpp.Pointer<cpp.Float32> ) : FmodResult;
	
	@:native('setVolume')
	function setVolume( volume : cpp.Float32 ) : FmodResult;
	
	@:native('getPosition')
	function getPosition( position : cpp.Pointer<cpp.UInt32>, postype : FmodTimeUnit ) : FmodResult;
	
	@:native('setPosition')
	function setPosition( position : cpp.UInt32, postype : FmodTimeUnit ) : FmodResult;
	
	/**
	 * Stops the channel (or all channels in the channel group) from playing. Makes it available for re-use by the priority system.
	 */
	@:native('stop')
	function stop() : FmodResult;
	
	@:native('isPlaying')
	function isPlaying( isPlaying : cpp.Pointer<Bool> ) : FmodResult;
	
	@:native('getMode')
	function getMode( mode : cpp.Pointer<FmodMode> ) : FmodResult;
	
	@:native('getLoopCount')
	function getLoopCount( nb:cpp.Pointer<Int> ) : FmodResult;
	
	@:native('setLoopCount')
	function setLoopCount( nb:Int ) : FmodResult;
	
	@:native('setMode')
	function setMode( mode:FmodMode ) : FmodResult;
	
}

@:include('linc_faxe.h')
@:native("FMOD::System")
extern class FmodSystem {
	
	@:native('close')
	function close() : FmodResult;
	
	@:native('createSound')
	function createSound( 
		name_or_data : cpp.ConstCharStar, 
		mode : FmodMode, 
		createExInfo : cpp.Pointer<FmodCreateSoundExInfo>, 
		sound:cpp.Pointer<cpp.Pointer<FmodSound>>) : FmodResult;
		
		
	@:native('getSoundRAM')
	function getSoundRAM(
		currentAlloced:cpp.Pointer<Int>,
		maxAlloced:cpp.Pointer<Int>,
		total:cpp.Pointer<Int>
	) : FmodResult;
}

@:include('linc_faxe.h')
@:native("FMOD::FMOD_CREATESOUNDEXINFO")
extern class FmodCreateSoundExInfo {
	
}