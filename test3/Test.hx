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
		
		if ( false ){
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
		
		if ( false ){
			trace("reading");
			var t0 = haxe.Timer.stamp();
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
			var t1 = haxe.Timer.stamp();
			trace("time to load" + (t1 - t0) + "sec");
			all.get("wind1_loop.wav").fadePlay( 10000 );
		}
		
		
		if ( false ){
			var file = "win/snd/music/Hell_master.ogg";
			var sound : Snd = Snd.loadSfx( file );
			if (sound != null) {
				sound.play();
				
				sound.onStop.addOnce(function(){
					trace("disposing");
					sound.dispose();
				});
				
				haxe.Timer.delay( function(){
					trace("fading...");
					sound.fadeStop( 10000 );
				},1000);
			}
			else {
				trace( "no such sound " + file);
			}
		}
		
		if ( false ){
			var file = "win/snd/music/Hell_master.ogg";
			var sound : Snd = Snd.loadSfx( file );
			if (sound != null) {
				sound.play();
				haxe.Timer.delay( function(){
					trace("lower");
					Snd.setGlobalVolume( 0.5 );
				}, 5000);
				
				haxe.Timer.delay( function(){
					trace("top");
					Snd.setGlobalVolume( 1.0 );
				}, 10000);
				
				haxe.Timer.delay( function(){
					trace("zero");
					Snd.setGlobalVolume( 0.0 );
				}, 15000);
			}
			else {
				trace( "no such sound " + file);
			}
		}
		
		if ( false ){
			var file = "win/snd/music/Hell_master.ogg";
			var sound : Snd = Snd.loadSong( file );
			if (sound != null) {
				sound.play();
				haxe.Timer.delay( function(){
					sound.setPlayCursorSec( 60 );
				}, 5000);
			}
			else {
				trace( "no such sound " + file);
			}
			
		}
		
		if ( false ){
			var file = "win/snd/music/Hell_master.ogg";
			var fmod = FaxeRef.getSystem();
			trace("fm init mem:\t" + Snd.dumpMemory());
			var sound : Snd = Snd.loadSfx( file );
			trace("load mem:\t\t" + Snd.dumpMemory());
			
			if (sound != null) {
				sound.play();
				
				haxe.Timer.delay( function(){
					trace("playin mem:\t" + Snd.dumpMemory());
					sound.dispose();
					trace("dispose mem:\t" + Snd.dumpMemory());
					cpp.vm.Gc.run(true);
					trace("gc runmem:" + Snd.dumpMemory());
				},5000);
				
				haxe.Timer.delay( function(){
					trace("long aftermem: \t" + Snd.dumpMemory());
					Sys.command("pause");
					Sys.exit(0);
				},10000);
			}
			else {
				trace( "no such sound " + file);
			}
		}
		
		if ( true ){
			var file = "win/snd/music/Hell_master.ogg";
			var fmod = FaxeRef.getSystem();
			trace("fm init mem:\t" + Snd.dumpMemory());
			var sound : Snd = Snd.loadSong( file );
			trace("load mem:\t\t" + Snd.dumpMemory());
			
			if (sound != null) {
				sound.play();
				
				haxe.Timer.delay( function(){
					trace("playin mem:\t" + Snd.dumpMemory());
					sound.dispose();
					trace("dispose mem:\t" + Snd.dumpMemory());
					cpp.vm.Gc.run(true);
					trace("gc runmem:\t" + Snd.dumpMemory());
				},5000);
				
				haxe.Timer.delay( function(){
					trace("long aftermem:\t" + Snd.dumpMemory());
					Sys.command("pause");
					Sys.exit(0);
				},10000);
			}
			else {
				trace( "no such sound " + file);
			}
		}
		
		var h = new haxe.Timer( 15);
		h.run = function(){
			Snd.update();
			//trace("update");
		}
	}
	
	
}
