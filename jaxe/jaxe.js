/**
* Jaxe - FMOD bindings for Haxe
*
* The MIT License (MIT)
*
* Copyright (c) 2020 Tanner Moore
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
* THE SOFTWARE.
*/

class jaxe {
	// FMOD engine
	static FMOD = {};
	// Loaded bank dictionary
	static loadedBanks = {};
	// Fmod System
	static gSystem = {};
	// Fmod Core System
	static gSystemCore = {};
	// Variable used to enable audio once the screen has been clicked
	static gAudioResumed = false;        
	// Variable used to let the game know when FMOD is ready to be used
	static FmodIsInitialized = false;      
	// Cache of any named event instances
	static loadedEventInstances = {};

	static fmod_set_debug(onOff){
		console.log('fmod_set_debug');
	}
	static fmod_is_initialized() {
		return jaxe.FmodIsInitialized;
	}
	static fmod_init(numChannels){ 
		jaxe.FMOD['preRun'] = jaxe.preRun;                             // Will be called before FMOD runs, but after the Emscripten runtime has initialized
		jaxe.FMOD['onRuntimeInitialized'] = jaxe.onRuntimeInitialized; // Called when the Emscripten runtime has initialized
		jaxe.FMOD['TOTAL_MEMORY'] = 64*1024*1024;                      // Allocates an arbitrarily large amount of memory for the FMOD audio engine
		FMODModule(jaxe.FMOD);
	}
	static fmod_update(){
		var result;
		result = jaxe.gSystem.update();
		jaxe.CHECK_RESULT(result);
	}
	static fmod_load_bank(bankFilePath){
		console.log('fmod_load_bank');
		
		// loadBankFile is not available here for some reason. Need to debug and try again

		// var result;
		// var outval = {};
		// result = jaxe.gSystem.loadBankFile("/" + bankFilePath, jaxe.FMOD.STUDIO_LOAD_BANK_NORMAL, outval);
		// jaxe.CHECK_RESULT(result);
		// jaxe.loadedBanks[bankFilePath] = outval.val;
	}
	static fmod_unload_bank(bankFilePath){
		console.log('fmod_unload_bank');
	}
	static fmod_create_event_instance_one_shot(eventPath){

		console.log('fmod_create_event_instance_one_shot');

		if (!jaxe.gAudioResumed)
		{
			console.log("Resetting audio driver based on user input.");

			result = jaxe.gSystemCore.mixerSuspend();
			jaxe.CHECK_RESULT(result);
			result = jaxe.gSystemCore.mixerResume();
			jaxe.CHECK_RESULT(result);

			jaxe.gAudioResumed = true;
		}
		
		var result = {};

		var description = {};
		result = jaxe.gSystem.getEvent(eventPath, description);
		jaxe.CHECK_RESULT(result);

		var instance = {};
		result = description.val.createInstance(instance);
		jaxe.CHECK_RESULT(result);

		result = instance.val.start();
		jaxe.CHECK_RESULT(result);

		result = instance.val.release();
		jaxe.CHECK_RESULT(result);

	}
	static fmod_create_event_instance_named(eventPath, eventInstanceName){
		console.log('fmod_create_event_instance_named');

		if (!jaxe.gAudioResumed)
		{
			console.log("Resetting audio driver based on user input.");

			result = jaxe.gSystemCore.mixerSuspend();
			jaxe.CHECK_RESULT(result);
			result = jaxe.gSystemCore.mixerResume();
			jaxe.CHECK_RESULT(result);

			jaxe.gAudioResumed = true;
		}

		if (jaxe.loadedEventInstances[eventInstanceName]) {
			console.log(eventInstanceName + ' is already loaded');
		}

		var description = {};
		var result = {};
		result = jaxe.gSystem.getEvent(eventPath, description);
		jaxe.CHECK_RESULT(result);

		var instance = {};
		result = description.val.createInstance(instance);
		jaxe.CHECK_RESULT(result);

		result = instance.val.start();
		jaxe.CHECK_RESULT(result);

		jaxe.loadedEventInstances[eventInstanceName] = instance.val;

		console.log(jaxe.loadedEventInstances);
		
	}
	static fmod_is_event_instance_loaded(eventPath){
		console.log('fmod_is_event_instance_loaded');
	}
	static fmod_play_event_instance(eventInstanceName){
		console.log('fmod_play_event_instance');
	}
	static fmod_set_pause_on_event_instance(eventInstanceName, shouldBePaused){
		console.log('fmod_set_pause_on_event_instance');
	}
	static fmod_stop_event_instance(eventInstanceName, forceStop){
		console.log('fmod_stop_event_instance');
	}
	static fmod_release_event_instance(eventInstanceName){
		console.log('fmod_release_event_instance');
	}
	static fmod_is_event_instance_playing(eventInstanceName){
		console.log('fmod_is_event_instance_playing');
	}
	static fmod_get_event_instance_playback_state(eventInstanceName){
		console.log('fmod_get_event_instance_playback_state');
	}
	static fmod_get_event_instance_param(eventInstanceName, paramName){
		console.log('fmod_get_event_instance_param');
	}
	static fmod_set_event_instance_param(eventInstanceName, paramName, value){
		console.log('fmod_set_event_instance_param');

		if(!jaxe.loadedEventInstances[eventInstanceName]){
			console.log('Cannot find event instance: ' + eventInstanceName);
			return;
		}

		var result = {};
		result = jaxe.loadedEventInstances[eventInstanceName].setParameterByName(paramName, value, false);
		jaxe.CHECK_RESULT(result);

	}
	static fmod_add_playback_listener_to_primary_event_instance(eventInstanceName){
		console.log('fmod_add_playback_listener_to_primary_event_instance');
	}
	static fmod_check_for_primary_event_instance_callback(callbackEventMask){
		// console.log('fmod_check_for_primary_event_instance_callback');
	}

	// Simple error checking function for all FMOD return values.
	static CHECK_RESULT(result)
	{
		if (result != jaxe.FMOD.OK)
		{
			console.log(jaxe.FMOD.ErrorString(result));
		}
	}

	static preRun = function() {
		var fileUrl = "/assets/fmod/Desktop/";
		var fileName;
		var folderName = "/";
		var canRead = true;
		var canWrite = false;
	
		fileName = [
			"Master.bank",
			"Master.strings.bank",
		];
	
		for (var count = 0; count < fileName.length; count++)
		{
			console.log('Mounting bank file: ' + fileName[count])

			// Mounts a local file so that FMOD can recognize it when calling a function that uses a filename (ie loadBank/createSound)
			jaxe.FMOD.FS_createPreloadedFile(folderName, fileName[count], fileUrl + fileName[count], canRead, canWrite);
		}
	}
	static onRuntimeInitialized = function(){
		// A temporary empty object to hold our system
		var outval = {};
		var result;
	
		console.log("Creating FMOD System object\n");
	
		// Create the system and check the result
		result = jaxe.FMOD.Studio_System_Create(outval);
		jaxe.CHECK_RESULT(result);
	
		console.log("grabbing system object from temporary and storing it\n");
	
		// Take out our System object
		jaxe.gSystem = outval.val;
	
		result = jaxe.gSystem.getCoreSystem(outval);
		jaxe.CHECK_RESULT(result);
	
		jaxe.gSystemCore = outval.val;
		
		// Optional.  Setting DSP Buffer size can affect latency and stability.
		// Processing is currently done in the main thread so anything lower than 2048 samples can cause stuttering on some devices.
	  //   console.log("set DSP Buffer size.\n");
	  //   result = gSystemCore.setDSPBufferSize(2048, 2);
	  //   jaxe.CHECK_RESULT(result);
		
		// Optional.  Set sample rate of mixer to be the same as the OS output rate.
		// This can save CPU time and latency by avoiding the automatic insertion of a resampler at the output stage.
		// console.log("Set mixer sample rate");
		// result = gSystemCore.getDriverInfo(0, null, null, outval, null, null);
		// jaxe.CHECK_RESULT(result);
		// result = gSystemCore.setSoftwareFormat(outval.val, FMOD.SPEAKERMODE_DEFAULT, 0)
		// jaxe.CHECK_RESULT(result);
	
		console.log("initialize FMOD\n");
	
		// 1024 virtual channels
		result = jaxe.gSystem.initialize(1024, jaxe.FMOD.STUDIO_INIT_NORMAL, jaxe.FMOD.INIT_NORMAL, null);
		jaxe.CHECK_RESULT(result);
		
		// Starting up your typical JavaScript application loop
		console.log("initialize Application\n");

		// Set the framerate to 50 frames per second, or 20ms.
		console.log("Start game loop\n");
		
		result = jaxe.gSystem.loadBankFile("/" + "Master.bank", jaxe.FMOD.STUDIO_LOAD_BANK_NORMAL, outval);
		jaxe.CHECK_RESULT(result);
		jaxe.loadedBanks["Master.bank"] = outval.val;

		result = jaxe.gSystem.loadBankFile("/" + "Master.strings.bank", jaxe.FMOD.STUDIO_LOAD_BANK_NORMAL, outval);
		jaxe.CHECK_RESULT(result);
		jaxe.loadedBanks["Master.strings.bank"] = outval.val;
		jaxe.FmodIsInitialized = true;
	
		return jaxe.FMOD.OK;
  }
}