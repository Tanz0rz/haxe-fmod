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

	// Callback flags
	static primaryEventCallbackFlags = 0x00000000;

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
		jaxe.CHECK_RESULT(result, 'update() failed');
	}
	static fmod_load_bank(bankFilePath){
		console.log('fmod_load_bank');
		
		var result;
		var outval = {};
		result = jaxe.gSystem.loadBankFile("/" + bankFilePath, jaxe.FMOD.STUDIO_LOAD_BANK_NORMAL, outval);
		jaxe.CHECK_RESULT(result, 'loadBankFile() call failed for ' + bankFilePath);
		jaxe.loadedBanks[bankFilePath] = outval.val;
	}
	static fmod_unload_bank(bankFilePath){
		console.log('fmod_unload_bank');
		var result;
		result = jaxe.loadedBanks[bankFilePath].unload();
		jaxe.CHECK_RESULT(result, 'unload() call failed for ' + jaxe.loadedBanks[bankFilePath]);
		jaxe.loadedBanks[bankFilePath] = undefined;
	}
	static fmod_create_event_instance_one_shot(eventPath){

		console.log('fmod_create_event_instance_one_shot');
		
		var result = {};

		var description = {};
		result = jaxe.gSystem.getEvent(eventPath, description);
		jaxe.CHECK_RESULT(result, 'getEvent() call failed for ' + eventPath);

		var instance = {};
		result = description.val.createInstance(instance);
		jaxe.CHECK_RESULT(result, 'createInstance() call failed for ' + description.val);

		result = instance.val.start();
		jaxe.CHECK_RESULT(result, 'start() call failed for ' + instance.val);

		result = instance.val.release();
		jaxe.CHECK_RESULT(result, 'release() call failed for ' + instance.val);

	}
	static fmod_create_event_instance_named(eventPath, eventInstanceName){
		console.log('Creating event instance for ' + eventPath);

		if (jaxe.loadedEventInstances[eventInstanceName]) {
			console.log('Event instance is already loaded: ' + eventPath);
		}

		var description = {};
		var result = {};
		console.log('Getting event description for ' + eventPath);
		result = jaxe.gSystem.getEvent(eventPath, description);
		jaxe.CHECK_RESULT(result, 'getEvent() call failed for ' + eventPath);

		var instance = {};
		console.log('Creating event instance for ' + eventPath);
		result = description.val.createInstance(instance);
		jaxe.CHECK_RESULT(result, 'createInstance() call failed for ' + eventPath);

		console.log('Starting event instance ' + eventPath);
		result = instance.val.start();
		jaxe.CHECK_RESULT(result, 'start() call failed for ' + eventPath);

		jaxe.loadedEventInstances[eventInstanceName] = instance.val;
	}
	static fmod_is_event_instance_loaded(eventInstanceName){
		console.log('fmod_is_event_instance_loaded');
		return !!jaxe.loadedEventInstances[eventInstanceName]
	}
	static fmod_play_event_instance(eventInstanceName){
		console.log('fmod_play_event_instance');
		if (!jaxe.loadedEventInstances[eventInstanceName]) {
			console.log("Event instance " + eventInstanceName + "is not loaded!");
			return;
		}
		var result;
		result = jaxe.loadedEventInstances[eventInstanceName].start()
		jaxe.CHECK_RESULT(result, 'start() call failed for ' + jaxe.loadedEventInstances[eventInstanceName]);
	}
	static fmod_set_pause_on_event_instance(eventInstanceName, shouldBePaused){
		console.log('fmod_set_pause_on_event_instance');
		if (!jaxe.loadedEventInstances[eventInstanceName]) {
			console.log("Event instance " + eventInstanceName + "is not loaded!");
			return;
		}
		var result;
		result = jaxe.loadedEventInstances[eventInstanceName].setPaused(shouldBePaused);
		jaxe.CHECK_RESULT(result, 'setPaused() call failed for ' + jaxe.loadedEventInstances[eventInstanceName]);
	}
	static fmod_stop_event_instance(eventInstanceName, forceStop){
		console.log('fmod_stop_event_instance');
		if (!jaxe.loadedEventInstances[eventInstanceName]) {
			console.log("Event instance " + eventInstanceName + "is not loaded!");
			return;
		}

		var stopMode;

		if (forceStop){
			stopMode = jaxe.FMOD.STUDIO_STOP_IMMEDIATE;
		} else {
			stopMode = jaxe.FMOD.STUDIO_STOP_ALLOWFADEOUT;
		}

		var result;
		result = jaxe.loadedEventInstances[eventInstanceName].stop(stopMode);
		jaxe.CHECK_RESULT(result, 'stop() call failed for ' + jaxe.loadedEventInstances[eventInstanceName]);

	}
	static fmod_release_event_instance(eventInstanceName){
		console.log('fmod_release_event_instance: ' + eventInstanceName);
		if (!jaxe.loadedEventInstances[eventInstanceName]) {
			console.log("Event instance " + eventInstanceName + "is not loaded!");
			return;
		}

		var result;
		result = jaxe.loadedEventInstances[eventInstanceName].stop(jaxe.FMOD.STUDIO_STOP_IMMEDIATE);
		jaxe.CHECK_RESULT(result);

		result = jaxe.loadedEventInstances[eventInstanceName].release();
		jaxe.CHECK_RESULT(result);

		jaxe.loadedEventInstances[eventInstanceName] = undefined;
	}
	static fmod_is_event_instance_playing(eventInstanceName){
		console.log('fmod_is_event_instance_playing');
		if (!jaxe.loadedEventInstances[eventInstanceName]) {
			console.log("Event instance " + eventInstanceName + "is not loaded!");
			return;
		}

		var result;
		var outval = {};
		result = jaxe.loadedEventInstances[eventInstanceName].getPlaybackState(outval);
		jaxe.CHECK_RESULT(result);

		return (outval.val == jaxe.FMOD.STUDIO_PLAYBACK_PLAYING);
	}
	static fmod_get_event_instance_playback_state(eventInstanceName){
		console.log('fmod_get_event_instance_playback_state');
		if (!jaxe.loadedEventInstances[eventInstanceName]) {
			console.log("Event instance " + eventInstanceName + "is not loaded!");
			return;
		}

		var result;
		var outval = {};
		result = jaxe.loadedEventInstances[eventInstanceName].getPlaybackState(outval);
		jaxe.CHECK_RESULT(result);

		return outval.val;
	}
	static fmod_get_event_instance_param(eventInstanceName, paramName){
		console.log('fmod_get_event_instance_param');
		if (!jaxe.loadedEventInstances[eventInstanceName]) {
			console.log("Event instance " + eventInstanceName + "is not loaded!");
			return;
		}

		var result;
		var outval = {};
		result = jaxe.loadedEventInstances[eventInstanceName].getParameterByName(paramName, outval);
		jaxe.CHECK_RESULT(result);

		return outval.val;
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

	static GetCallbackType(type, event, parameters)
	{
		jaxe.primaryEventCallbackFlags = jaxe.primaryEventCallbackFlags | type;
		return jaxe.FMOD.OK;
	}

	static fmod_add_playback_listener_to_primary_event_instance(eventInstanceName){
		console.log('fmod_add_playback_listener_to_primary_event_instance');
		if(!jaxe.loadedEventInstances[eventInstanceName]){
			console.log('Cannot find event instance: ' + eventInstanceName);
			return;
		}
		jaxe.primaryEventCallbackFlags = 0x00000000;
		
		var result = {};
		result = jaxe.loadedEventInstances[eventInstanceName].setCallback(jaxe.GetCallbackType, jaxe.FMOD.STUDIO_EVENT_CALLBACK_ALL);
		jaxe.CHECK_RESULT(result);

	}
	static fmod_check_for_primary_event_instance_callback(callbackEventMask){
		var eventHappened;
		eventHappened = jaxe.primaryEventCallbackFlags & callbackEventMask;
		jaxe.primaryEventCallbackFlags &= ~callbackEventMask;
		return eventHappened;
	}

	// Simple error checking function for all FMOD return values.
	static CHECK_RESULT(result, message='')
	{
		if (result != jaxe.FMOD.OK)
		{
			if (message == ''){
				console.log(jaxe.FMOD.ErrorString(result));
			} else {
				console.log(message + ': ' + jaxe.FMOD.ErrorString(result));
			}
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
	    console.log("set DSP Buffer size.\n");
	    result = jaxe.gSystemCore.setDSPBufferSize(2048, 2);
	    jaxe.CHECK_RESULT(result);
		
		// Optional.  Set sample rate of mixer to be the same as the OS output rate.
		// This can save CPU time and latency by avoiding the automatic insertion of a resampler at the output stage.
		console.log("Set mixer sample rate");
		result = jaxe.gSystemCore.getDriverInfo(0, null, null, outval, null, null);
		jaxe.CHECK_RESULT(result);
		result = jaxe.gSystemCore.setSoftwareFormat(outval.val, jaxe.FMOD.SPEAKERMODE_DEFAULT, 0)
		jaxe.CHECK_RESULT(result);
	
		function resumeAudio() 
		{
			if (!jaxe.gAudioResumed)
			{
				console.log("Resetting audio driver based on user input.");
	
				result = jaxe.gSystemCore.mixerSuspend();
				jaxe.CHECK_RESULT(result);
				result = jaxe.gSystemCore.mixerResume();
				jaxe.CHECK_RESULT(result);
	
				jaxe.gAudioResumed = true;
			}
		}
        document.addEventListener('click', resumeAudio);

		console.log("initialize FMOD\n");
	
		// 1024 virtual channels
		result = jaxe.gSystem.initialize(1024, jaxe.FMOD.STUDIO_INIT_NORMAL, jaxe.FMOD.INIT_NORMAL, null);
		jaxe.CHECK_RESULT(result);
		
		// Starting up your typical JavaScript application loop
		console.log("initialize Application\n");

		// Set the framerate to 50 frames per second, or 20ms.
		console.log("Start game loop\n");
		
		window.setInterval(jaxe.updateFmod, 20);

		result = jaxe.gSystem.loadBankFile("/" + "Master.bank", jaxe.FMOD.STUDIO_LOAD_BANK_NORMAL, outval);
		jaxe.CHECK_RESULT(result);
		jaxe.loadedBanks["Master.bank"] = outval.val;

		result = jaxe.gSystem.loadBankFile("/" + "Master.strings.bank", jaxe.FMOD.STUDIO_LOAD_BANK_NORMAL, outval);
		jaxe.CHECK_RESULT(result);
		jaxe.loadedBanks["Master.strings.bank"] = outval.val;
		jaxe.FmodIsInitialized = true;
	
		return jaxe.FMOD.OK;
  }

  // Needs to be a local function to play nicely with setInterval
  static updateFmod() {
	  jaxe.gSystem.update();
  }
}