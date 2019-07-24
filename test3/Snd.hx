import faxe.Faxe;

import SndTV;

class Channel {
	public var 		data : FmodChannelRef 	= null;
	public var 		onEnd : Void -> Void 	= null;
	
	var started 	= true;
	var paused 		= false;
	
	public inline function new( data : cpp.Pointer<FmodChannel> ){
		this.data = cast data.ref;
		started = true;
		paused = false;
	}
	
	public function getData(){
		return data;
	}	
	
	public inline function stop(){
		data.stop();
		started = false;
	}
	
	public inline function pause(){
		paused = false;
		started = true;
		data.setPaused(true);
	}
	
	public inline function resume(){
		paused = true;
		started = true;
		data.setPaused(false);
	}
	
	var disposed = false;
	public inline function dispose(){
		if (disposed) return;
		disposed = true;
		data = null;
	}
	
	public inline function isPlaying(){
		var b : Bool = false;
		data.isPlaying( Cpp.addr(b));
		return b;
	}
	
	//returns in secs
	public inline function getPlayCursor() : Float {
		var pos : cpp.UInt32 = 0;
		var res = data.getPosition( Cpp.addr(pos), faxe.Faxe.FmodTimeUnit.FTM_MS );
		var posF : Float = 1.0 * pos * 1000.0;
		return posF;
	}
	
	public inline function setPlayCursorSec(posSec:Float) {
		setPlayCursorMs( posSec * 1000.0 );
	}
	
	public inline function setPlayCursorMs(posMs:Float) {
		if ( posMs < 0.0) posMs = 0.0;
		var posU : cpp.UInt32 = 0;
		posU = Math.round( posMs );
		var res = data.setPosition( posU, FmodTimeUnit.FTM_MS );
		if ( res != FMOD_OK){
			#if debug
			trace("[SND][Channel] Repositionning S err " + res);
			#end
		}
	}
	
	public inline function setNbLoops(nb:Int){
		data.setMode(FmodMode.FMOD_LOOP_NORMAL);
		data.setLoopCount(nb);
	}
	
	public inline function getVolume():Float{
		var vol : cpp.Float32 = 0.0;
		var res = data.getVolume( Cpp.addr(vol) );
		if ( res != FMOD_OK){
			#if debug
			trace("[SND][Channel] getVolume err " + res);
			#end
		}
		return vol;
	}
	
	public inline function setVolume(v:Float){
		var res = data.setVolume( v );
		if ( res != FMOD_OK){
			#if debug
			trace("[SND][Channel] getVolume err " + res);
			#end
		}
	}
	
	public function onComplete() {
		stop();
		if( onEnd!=null ) {
			var cb = onEnd;
			onEnd = null;
			cb();
		}
	}
	
	public inline function isComplete(){
		return started && !isPlaying();
	}
	
	public function setPan( pan : Float ){
		var res = data.setPan(pan);
		if ( res != FMOD_OK){
			#if debug
			trace("[SND][Channel] setPan err " + res);
			#end
		}
	}
}

class Sound {
	public var length(get, null) 						: Float;
	public var data : FmodSoundRef					 	= null;
	public var id3 	: Dynamic							= null;
	
	public function new( data : cpp.Pointer<faxe.Faxe.FmodSound> ){
		this.data = Cpp.ref(data);
		disposed = false;
	}
	
	public function getData(){
		return data;
	}
	
	//returns in secs
	function get_length() : Float{
		if (disposed) return 0.0;
		
		var pos : cpp.UInt32 = 0;
		var res = data.getLength( Cpp.addr(pos), FmodTimeUnit.FTM_MS );
		if ( res != FMOD_OK ){
			#if debug
			trace("impossible to retrieve sound len");
			#end
		}
		var posF = 1.0 * pos / 1000.0;
		return posF;
	}
	
	var disposed = false;
	public function dispose(){
		if (disposed) return;
		disposed = true;
		data.release();
		data = null;
	}
	
	public function play( ?offsetMs : Float = 0.0, ?nbLoops:Int = 1, ?volume:Float = 1.0, ?pan:Float = 0.0 ) : Channel{
		var nativeChan : cpp.Pointer<FmodChannel> = FaxeRef.playSoundWithHandle( data , false);
		var chan = new Channel( nativeChan );
		
		chan.setPlayCursorMs( offsetMs );
		chan.setVolume( volume );
		chan.setPan( pan );
		if( nbLoops > 1 ) chan.setNbLoops( nbLoops );
		
		return chan;
	}
}

class Snd {
	static var 	PLAYING 			: hxd.Stack<Snd> 	= new hxd.Stack();
	static var 	MUTED 									= false;
	static var 	DISABLED		 						= false;
	static var 	GLOBAL_VOLUME 							= 1.0;
	static var 	TW 										= new SndTV();
	
	public var 	name			: String				;
	public var 	pan				: Float					= 0.0;
	public var 	volume 			: Float 				= 1.0;
	public var 	curPlay 		: Null<Channel> 		= null;
		
	/**
	 * for when stop is called explicitly
	 * allows disposal
	 */
	public var 	onStop 									= new hxd.Signal();
	public var 	sound 		: Sound						= null;
		
	var onEnd				: Null<Void->Void>			= null;
	
	static var fmodSystem 	: FmodSystemRef				= null;
	
	public function new( snd : Sound, ?name:String ) {
		volume = 1;
		pan = 0;
		sound = snd;
		muted = false;
		this.name = name;
		sound = snd;
	}
	
	public function isLoaded() {
		return sound!=null;
	}
	
	public function stop(){
		if ( isPlaying() ) {
			curPlay.stop();
			curPlay = null;
			PLAYING.remove(this);
			onStop.trigger();
		}
	}
	
	public function dispose(){
		if ( curPlay != null) 	{
			curPlay.stop();
			curPlay.dispose();
		}
		
		if ( sound != null) 	sound.dispose();
		onStop.dispose();
		sound = null;
		onEnd = null;
		curPlay = null;
	}
	
	public inline function getPlayCursor() : Float {
		if ( curPlay == null) return 0.0;
		return curPlay.getPlayCursor();
	}
	
	
	public function play(?vol:Float, ?pan:Float) : Snd {
		if( vol == null ) 		vol = volume;
		if( pan == null )		pan = this.pan;

		start(0, vol, pan, 0.0);
		return this;
	}
	
	
	/**
	 * launches the sound, stops previous and rewrite the cur play dropping it into oblivion for the gc
	 */
	public function start(loops:Int=0, vol:Float=1.0, ?pan:Float=0.0, ?startOffsetMs:Float=0.0) {
		if ( DISABLED ) 			{
			#if debug
			trace("[SND] Disabled");
			#end
			return;
		}
		if ( sound == null ){
			#if debug
			trace("[SND] no inner sound");
			#end
			return;
		}

		if ( isPlaying() ){
			stop();
		}
			
		TW.terminate(this);
		
		this.volume = vol;
		this.pan = normalizePanning(pan);
		
		//was removed from playing by stop
		PLAYING.push(this);
		curPlay = sound.play( startOffsetMs, loops, getRealVolume(), pan);
	}
	
	/**
	 * launches the sound and rewrite the cur play dropping it into oblivion for the gc
	 */
	public function startNoStop(?loops:Int=0, ?vol:Float=1.0, ?pan:Float=0.0, ?startOffsetMs:Float=0.0) : Null<Channel>{
		if ( DISABLED ) 			{
			#if debug
			trace("[SND] Disabled");
			#end
			return null;
		}
		if ( sound == null ){
			#if debug
			trace("[SND] no inner sound");
			#end
			return null;
		}
		
		this.volume = vol;
		this.pan = normalizePanning(pan);
		
		curPlay = sound.play( startOffsetMs, loops, getRealVolume(), pan);
		return curPlay;
	}
	
	public inline function getDuration() {
		return sound.length;
	}
	
	public static inline 
	function trunk(v:Float, digit:Int) : Float{
		var hl = Math.pow( 10.0 , digit );
		return Std.int( v * hl ) / hl;
	}
	
	public static function dumpMemory(){
		var v0 : Int = 0;
		var v1 : Int = 0;
		var v2 : Int = 0;
		
		var v0p : cpp.Pointer<Int> = Cpp.addr(v0);
		var v1p : cpp.Pointer<Int> = Cpp.addr(v1);
		var v2p : cpp.Pointer<Int> = Cpp.addr(v2);
		var str = "";
		var res = fmodSystem.getSoundRAM( v0p, v1p, v2p );
		if ( res != FMOD_OK){
			#if debug
			trace("[SND] cannot fetch snd ram dump ");
			#end
		}
		
		inline function f( val :Float) : Float{
			return trunk(val, 2);
		}
		
		if( v2 > 0 ){
			str+="fmod Sound chip RAM all:" + f(v0 / 1024.0) + "KB \t max:" + f(v1 / 1024.0) + "KB \t total: " + f(v2 / 1024.0) + " KB\r\n";
		}
		
		v0 = 0;
		v1 = 0;
		
		var res = FaxeRef.Memory_GetStats( v0p, v1p, false );
		str += "fmod Motherboard chip RAM all:" + f(v0 / 1024.0) + "KB \t max:" + f(v1 / 1024.0) + "KB \t total: " + f(v2 / 1024.0) + " KB";
		return str;
	}
	
	public function playLoop(?loops = 9999, ?vol:Float, ?startOffset = 0.0) {
		if( vol==null )
			vol = volume;

		start(loops, vol, 0, startOffset);
		return this;
	}
	
	public function setVolume(v:Float) {
		volume = v;
		refresh();
	}
	
	public inline function getRealPanning() {
		return pan;
	}

	public function setPanning(p:Float) {
		pan = p;
		refresh();
	}

	public function onEndOnce(cb:Void->Void) {
		onEnd = cb;
	}
	
	public function fadePlay(?fadeDuration = 100, ?endVolume:Float=1.0 ) {
		var p = play(0);
		tweenVolume(endVolume, fadeDuration);
		return p;
	}
	
	public function fadePlayLoop(?fadeDuration = 100, ?endVolume:Float=1.0 , ?loops=9999) {
		var p = playLoop(loops,0);
		tweenVolume(endVolume, fadeDuration);
		return p;
	}
	
	public function fadeStop( ?fadeDuration = 100 ) {
		tweenVolume(0, fadeDuration).onEnd = _stop;
	}
	
	public var muted : Bool = false;
	
	public function toggleMute() {
		muted = !muted;//todo
		setVolume(volume);
	}
	public function mute() {
		muted = true;
		setVolume(volume);
	}
	public function unmute() {
		muted = false;
		setVolume(volume);
	}
	
	public function isPlaying(){
		if ( curPlay == null ) return false;
		return curPlay.isPlaying();
	}
	
	public static function init(){
		#if debug
		trace("[Snd] fmod init");
		#end
		Faxe.fmod_init( 256 );
		fmodSystem = FaxeRef.getSystem();
	}
	
	public static function setGlobalVolume(vol:Float) {
		GLOBAL_VOLUME = normalizeVolume(vol);
		refreshAll();
	}
	
	inline function refresh() {
		if ( isPlaying() ) {
			var lpan = normalizePanning(pan);
			var vol = getRealVolume();
			
			curPlay.setVolume( vol );
			curPlay.setPan( lpan );
		}
		else {
			#if debug
			trace("[Snd] no playin no refresh");
			#end
		}
	}
	
	public function	setPlayCursorSec( pos:Float ) 	if (curPlay != null)	curPlay.setPlayCursorSec(pos);
	public function	setPlayCursorMs( pos:Float ) 	if (curPlay != null) 	curPlay.setPlayCursorMs(pos);
	
	public function tweenVolume(v:Float, ?easing:SndTV.TVType, milliseconds:Float) : TweenV {
		TW.terminate(this);
		if ( easing == null ) easing = TVType.TEase;
		var t = TW.create(this, TVVVolume, v, TEase, milliseconds);
		refresh();
		t.onUpdate = _refresh;
		t.onEnd = _refresh;
		return t;
	}
	
	public function tweenPan(v:Float, ?easing:SndTV.TVType, milliseconds:Float) : TweenV {
		TW.terminate(this);
		if ( easing == null ) easing = TVType.TEase;
		var t = TW.create(this, TVVPan, v, easing, milliseconds);
		refresh();
		t.onUpdate = _refresh;
		t.onEnd = _refresh;
		return t;
	}
	
	public inline function getRealVolume() {
		var v = volume * GLOBAL_VOLUME * (DISABLED?0:1) * (MUTED?0:1) * (muted?0:1);
		return normalizeVolume(v);
	}
	
	static inline function normalizeVolume(f:Float) {
		return Math.max(0, Math.min(1, f));
	}

	static inline function normalizePanning(f:Float) {
		return Math.max(-1, Math.min(1, f));
	}
	
	static var _stop = function(t:TweenV){
		t.parent.stop();
	}
	
	static var _refresh = function(t:TweenV) {
		t.parent.refresh();
	}
	
	static inline function refreshAll() {
		for(s in PLAYING)
			s.refresh();
	}
	
	function onComplete(){
		if (curPlay != null) curPlay.onComplete();
	}
	
	public function isComplete(){
		if ( curPlay == null ) {
			//trace("comp: no cur play");
			return false;
		}
		return curPlay.isComplete();
	}
	
	//////////////////////////////////////
	/////////////////////STATICS//////////
	//////////////////////////////////////
	public static function loadSound( path:String, streaming : Bool  ) : Sound {
		var mode = FMOD_DEFAULT;
		
		if ( streaming )
			mode |= FMOD_CREATESTREAM;
			
		mode |= FmodMode.FMOD_2D;
		
		var snd : cpp.RawPointer<faxe.Faxe.FmodSound> = cast null;
		var sndR :  cpp.RawPointer<cpp.RawPointer<faxe.Faxe.FmodSound>> = cpp.RawPointer.addressOf(snd);
		
		var res : FmodResult = fmodSystem.createSound( 
			Cpp.cstring(path),
			mode,
			Cpp.nullptr(),
			sndR
		);
			
		if ( res != FMOD_OK){
			#if debug
			trace("unable to load " + path + " code:" + res);
			#end
			return null;
		}
			
		return new Sound(cpp.Pointer.fromRaw(snd));
	}
	
	public static function fromFaxe( path:String ) : Snd {
		var s : cpp.Pointer<FmodSound> = faxe.Faxe.fmod_get_sound(path );
		if ( s == null){
			#if debug
			trace("unable to find " + path);
			#end
			return null;
		}
		return new Snd( new Sound(s), path);
	}
	
	public static function loadSfx( path:String ) : Snd {
		var s : Sound = loadSound(path, false);
		if ( s == null) return null;
		return new Snd( s, path);
	}
	
	public static function loadSong( path:String ) : Snd {
		var s : Sound = loadSound(path, true);
		if ( s == null) return null;
		return new Snd( s, path);
	}
	
	public static function terminateTweens() {
		TW.terminateAll();
	}
	
	public static function update() {
		for ( p in PLAYING.backWardIterator())
			if ( p.isComplete()){
				//trace("[Snd] isComplete " + p);
				p.onComplete();
			}
		TW.update();
		Faxe.fmod_update();
	}
}