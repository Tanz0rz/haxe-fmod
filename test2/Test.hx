import faxe.Faxe;
import Cpp;

class Test
{
	

	static function main()
	{
		Faxe.fmod_init(36);

		var file = "accuser_nodrums.wav";
		
		var file = "04 - Flesh And Bones (feat. Benjamin Guerry).mp3";
		var file = "Bomblasta_nodrums.ogg";
		var file = "Draculaugh.wav";
		Faxe.fmod_load_sound(file);
		
		var chan : Ptr<FmodChannel> = Faxe.faxe_play_sound_with_channel(file , false);
		
		{
			var f : cpp.Float32 = 0.0;
			chan.ptr.getVolume( Cpp.addr(f) );
			trace(f);
			//chan.ptr.setVolume( 0.1 );
		}
		
		{	//seek
		//	chan.ptr.setPosition( 60*1000, FmodTimeUnit.FTM_MS);
		}
		
		{	
			var f : cpp.UInt32 = 0;
			chan.ptr.getPosition( Cpp.addr(f), FmodTimeUnit.FTM_MS);
			trace(f);
		}
		
		{
			var b : Bool = false;
			chan.ptr.isPlaying( Cpp.addr(b));
			trace(b);
		}
		
		{//set to loop
			chan.ptr.setMode(FmodMode.FMOD_LOOP_NORMAL);
			chan.ptr.setLoopCount(10);
		}
		
		chan.ptr.getVolume;
		chan.ptr.setVolume;
		chan.ptr.getPosition;
		chan.ptr.setPosition;
		chan.ptr.stop;
		chan.ptr.isPlaying;
		chan.ptr.getMode;
		chan.ptr.getLoopCount;
		chan.ptr.setLoopCount;
		chan.ptr.setMode;
		     
		var snd : Ptr<FmodSound> = Faxe.fmod_get_sound(file);
		snd.ptr.getMode;
		snd.ptr.getLoopCount;
		snd.ptr.setLoopCount;
		snd.ptr.setMode;
		snd.ptr.getPosition;
		snd.ptr.setPosition;
		
		
		var s : Ptr<FmodCreateSoundExInfo> = Cpp.nullptr();
		
		var len : cpp.UInt32 = 0;
		var res = snd.ptr.getLength( Cpp.addr(len), FmodTimeUnit.FTM_MS);
		snd.ptr.release;
		
		var ptr : Ptr<FmodSystem> = Faxe.fmod_get_system();
		var sys = ptr.ref;
		sys.getSoundRAM;
		
		var sys : FmodSystemRef = FaxeRef.fmod_get_system();
		sys.getSoundRAM;
		
		// Bad little forever loop to pump FMOD commands
		while (true)
		{
			// trace("event:/testEvent is playing: " + Faxe.fmod_event_is_playing("event:/testEvent"));
			Faxe.fmod_update();
		}
	}
}
