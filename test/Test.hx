import faxe.Faxe;

class Test
{
	static function main()
	{
		Faxe.fmod_init(36);

		// Load a sound bank
		Faxe.fmod_load_bank("./MasterBank.bank");

		// Make sure to load the STRINGS file to enable loading 
		// stuff by FMOD Path
		Faxe.fmod_load_bank("./MasterBank.strings.bank");

		// Load a test event
		Faxe.fmod_load_event("event:/testEvent","toto");
		Faxe.fmod_play_event("event:/testEvent");

		// Get and set an even parameter to change effect values
		trace("Lowpass param defaults to: " + Faxe.fmod_get_param("event:/testEvent", "Lowpass"));
		trace("Setting Lowpass param to 50.0");
		Faxe.fmod_set_param("event:/testEvent", "Lowpass", 50.0);

		// Bad little forever loop to pump FMOD commands
		while (true)
		{
			// trace("event:/testEvent is playing: " + Faxe.fmod_event_is_playing("event:/testEvent"));
			Faxe.fmod_update();
		}
	}
}
