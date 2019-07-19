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
	public static function fmod_load_sound(soundPath:String, looping:Bool = false, streaming:Bool = false):Void;

	@:native("linc::faxe::faxe_unload_sound")
	public static function fmod_unload_sound(bankFilePath:String):Void;

	@:native("linc::faxe::faxe_load_event")
	public static function fmod_load_event(eventPath:String, eventName:String):Void;

	@:native("linc::faxe::faxe_play_event")
	public static function fmod_play_event(eventName:String):Void;
	
	
	@:native("linc::faxe::faxe_play_sound")
	public static function fmod_play_sound(soundName:String, paused:Bool):Void;
	
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
}

@:enum abstract FModTimeUnit(Int) from Int to Int {
	var FTM_MS 			= 0x00000001;
	var FTM_PCM 		= 0x00000002;
	var FTM_PCMBYTES 	= 0x00000004;
	var FTM_RAWBYTES 	= 0x00000008;
	var FTM_PCMFRACTION = 0x00000010;
	var FTM_MODORDER 	= 0x00000100;
	var FTM_MODROW		= 0x00000200;
	var FTM_MODPATTERN 	= 0x00000400;
}

@:include('linc_faxe.h')
@:native("FMOD::Channel")
extern class FmodChannel {
	
	@:native('getVolume')
	function getVolume( volume : cpp.Pointer<cpp.Float32> ) : Void;
	
	@:native('setVolume')
	function setVolume( volume : cpp.Float32 ) : Void;
	
	//beware
	@:native('getPosition')
	function getPosition( position : cpp.Pointer<cpp.UInt32>, postype : FModTimeUnit ) : Void;
	
	@:native('setPosition')
	function setPosition( position : cpp.UInt32, postype : FModTimeUnit ) : Void;
}