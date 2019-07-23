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
		
		var chan : FmodChannelRef = FaxeRef.playSound(file , false);
		
		{
			var f : cpp.Float32 = 0.0;
			chan.getVolume( Cpp.addr(f) );
			trace(f);
			//chan.ptr.setVolume( 0.1 );
		}
		
		{	//seek
			chan.setPosition( 60*1000, FmodTimeUnit.FTM_MS);
		}
		
		{	
			var f : cpp.UInt32 = 0;
			chan.getPosition( Cpp.addr(f), FmodTimeUnit.FTM_MS);
			trace(f);
		}
		
		{
			var b : Bool = false;
			chan.isPlaying( Cpp.addr(b));
			trace(b);
		}
		
		{//set to loop
			chan.setMode(FmodMode.FMOD_LOOP_NORMAL);
			chan.setLoopCount(10);
		}
		
		chan.getVolume;
		chan.setVolume;
		chan.getPosition;
		chan.setPosition;
		chan.stop;
		chan.isPlaying;
		chan.getMode;
		chan.getLoopCount;
		chan.setLoopCount;
		chan.setMode;
		     
		var snd : FmodSoundRef = FaxeRef.getSound(file);
		snd.getMode;
		snd.getLoopCount;
		snd.setLoopCount;
		snd.setMode;
		snd.getPosition;
		snd.setPosition;
		
		var s : Ptr<FmodCreateSoundExInfo> = Cpp.nullptr();
		
		var len : cpp.UInt32 = 0;
		var res = snd.getLength( Cpp.addr(len), FmodTimeUnit.FTM_MS);
		snd.release;
		
		var ptr : Ptr<FmodSystem> = Faxe.fmod_get_system();
		var sys = ptr.ref;
		sys.getSoundRAM;
		
		var sys : FmodSystemRef = FaxeRef.getSystem();
		sys.getSoundRAM;
		
		// Bad little forever loop to pump FMOD commands
		while (true)
		{
			// trace("event:/testEvent is playing: " + Faxe.fmod_event_is_playing("event:/testEvent"));
			Faxe.fmod_update();
		}
	}
}
