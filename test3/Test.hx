import faxe.Faxe;
import Cpp;

import SndTV;

class Test{
	
	
	static function main()
	{
		Snd.init();
		
		
		if ( false ){
			var file = "07 - Crush (feat. Jay Kloeckner).mp3";
			Faxe.fmod_load_sound( file );
			
			var s = Faxe.fmod_get_sound(file);
			
			var len : cpp.UInt32 = -1;
			s.ptr.getLength( Cpp.addr(len), FmodTimeUnit.FTM_MS );
			
			trace(len);
			Faxe.fmod_play_sound_with_handle( s );
		}
		
		if ( false ){
			var file = "07 - Crush (feat. Jay Kloeckner).mp3";
			Faxe.fmod_load_sound( file );
			Faxe.fmod_play_sound( file );
		}
		
		if ( false ){
			var file = "07 - Crush (feat. Jay Kloeckner).mp3";
			Faxe.fmod_load_sound( file );
			var sound : Snd = Snd.fromFaxe( file );
			//sound.play();
			
			Faxe.fmod_play_sound_with_handle( cast sound.sound.getData() );
		}
		
		if ( false ){
			var file = "07 - Crush (feat. Jay Kloeckner).mp3";
			Faxe.fmod_load_sound( file );
			var sound : Snd = Snd.fromFaxe( file );
			sound.play();
		}
		
		if( false ){
			var sound : Snd = Snd.loadSfx( "07 - Crush (feat. Jay Kloeckner).mp3");
			if ( sound == null){
				trace("err loading sound!");
			}
			
			trace("len:"+sound.getDuration());
			
			sound.play();
			if(sound.isPlaying())
				trace("playing!");
		}
		
		if( false ){
			var sound : Snd = Snd.loadSfx( "07 - Crush (feat. Jay Kloeckner).mp3");
			sound.play();
			trace(sound.volume);
			haxe.Timer.delay( function(){
				sound.fadeStop( 5000 );
			}, 10 * 1000 );
		}
		
		if( false ){
			var sound : Snd = Snd.loadSfx( "07 - Crush (feat. Jay Kloeckner).mp3");
			sound.play();
			trace(sound.volume);
			haxe.Timer.delay( function(){
				trace("panning");
				sound.tweenPan(1, TEase, 2000);
			}, 5 * 1000 );
		}
		
		if ( false ){
			var file = "snd/music/credits.mp3";
			var file = "snd/music/Hell_master.mp3";
			var file = "snd/music/MUSIC_INTRO.mp3";
			var file = "snd/music/WorldMap_master.mp3";
			var sound : Snd = Snd.loadSfx( file );
			sound.play();
		}
		
		if ( false ){
			var file = "win/snd/music/credits.ogg";
			var file = "win/snd/music/Hell_master.ogg";
			var file = "win/snd/music/MUSIC_INTRO.ogg";
			var file = "win/snd/music/WorldMap_master.ogg";
			var file = "win/music/accuser_cymbals.ogg";
			var file = "win/music/BM3_nodrums.ogg";
			var file = "win/snd/samples/deathmetal1_cymbal1.wav";
			var sound : Snd = Snd.loadSfx( file );
			if (sound!=null) sound.play();
			else {
				trace( "no such sound " + file);
			}
		}
		
		if ( false ){
			var file = "win/snd/samples/deathmetal1_cymbal1.wav";
			var sound : Snd = Snd.loadSfx( file );
			if (sound != null) {
				sound.playLoop(5);
			} else {
				trace( "no such sound " + file);
			}
		}
		
		if ( false ){
			var file = "win/snd/samples/deathmetal1_cymbal1.wav";
			var sound : Snd = Snd.loadSfx( file );
			if (sound != null) {
				var d = 800;
				for( i in 0...10)
					haxe.Timer.delay( function(){
						sound.startNoStop();
					}, i * 200 );
			} else {
				trace( "no such sound " + file);
			}
		}
		
		if ( false ){
			var file = "win/snd/samples/deathmetal1_cymbal1.wav";
			var sound : Snd = Snd.loadSfx( file );
			if (sound != null) {
				var d = 800;
				for( i in 0...10)
					haxe.Timer.delay( function(){
						sound.play();
					}, i * 200 );
			} else {
				trace( "no such sound " + file);
			}
		}
		
		if ( true ){
			trace("reading");
			var all :Map<String,Snd> = new Map();
			var dir = "win/snd/SFX";
			for ( path in sys.FileSystem.readDirectory(dir)){
				var snd = Snd.loadSfx( dir + "/" + path );
				if( snd !=null ) 
					all.set(path, snd);
				else{
					trace("not loaded " + snd);
				}
			}
			all.get("BBdino_grunt4.wav").playLoop( 10 ); 
		}
		
		var h = new haxe.Timer( 15);
		h.run = function(){
			Snd.update();
			//trace("update");
		}
	}
	
	
}
