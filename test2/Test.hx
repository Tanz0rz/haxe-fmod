import faxe.Faxe;

class Test
{
	static function main()
	{
		Faxe.fmod_init(36);

		var file = "accuser_nodrums.wav";
		
		var file = "04 - Flesh And Bones (feat. Benjamin Guerry).mp3";
		var file = "Bomblasta_nodrums.ogg";
		Faxe.fmod_load_sound(file, false, true);
		
		//Faxe.fmod_play_sound("accuser_nodrums.wav" , false );
		var chan : cpp.Pointer<FmodChannel> = Faxe.faxe_play_sound_with_channel(file , false);
		
		
		{
			var f : cpp.Float32 = 0.0;
			chan.ptr.getVolume( cpp.Pointer.addressOf(f) );
			trace(f);
			//chan.ptr.setVolume( 0.1 );
		}
		{	
			chan.ptr.setPosition( 60*1000, FModTimeUnit.FTM_MS);
		}
		
		{	
			var f : cpp.UInt32 = 0;
			chan.ptr.getPosition( cpp.Pointer.addressOf(f), FModTimeUnit.FTM_MS);
			trace(f);
		}
		
		
		// Bad little forever loop to pump FMOD commands
		while (true)
		{
			// trace("event:/testEvent is playing: " + Faxe.fmod_event_is_playing("event:/testEvent"));
			Faxe.fmod_update();
		}
	}
}