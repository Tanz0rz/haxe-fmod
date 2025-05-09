/**
* Faxe - FMOD bindings for Haxe
*
* The MIT License (MIT)
*
* Copyright (c) 2016 Aaron M. Shea
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

#include <hxcpp.h>
#include <fmod_studio.hpp>
#include <fmod_errors.h>
#include <map>
#include <thread> 
#include <csignal>

#include "linc_faxe.h"

namespace linc 
{
	namespace faxe
	{
		// FMOD Sound System
		FMOD::Studio::System* fmodSoundSystem;
		FMOD::System* fmodCoreSoundSystem;

		// Maps to track what has been loaded already
		std::map<::String, FMOD::Studio::Bank*> loadedBanks;
		std::map<::String, FMOD::Sound*> loadedSounds;
		std::map<::String, FMOD::Studio::EventInstance*> loadedEventInstances;
		
		// Callbacks
		std::map<::String, unsigned int> eventCallbacksFlagsMap;

		// Background thread to automatically call FMOD's Update() function
		std::thread autoUpdaterThread;
		bool autoUpdaterThreadShouldExit;

		//// FMOD System

		bool fmod_debug = false;
		void fmod_set_debug(bool onOff){
			fmod_debug = onOff;
		}
		
		bool fmod_is_initialized() {
			return true;
		}

		void fmod_init(int numChannels)
		{
			if (fmod_debug) printf("Initializing HaxeFmod\n");
			// Choose a reasonable default if 0 is passed in
			if (numChannels == 0){
				numChannels = 36;
			}

			// Create our new fmod system
			if (FMOD::Studio::System::create(&fmodSoundSystem) != FMOD_OK)
			{
				if(fmod_debug) printf("Failure starting FMOD sound system!\n");
				return;
			}

			// Initialize system with channel count and startup flags
			auto result = fmodSoundSystem->initialize(numChannels, FMOD_STUDIO_INIT_LIVEUPDATE, FMOD_INIT_NORMAL, nullptr);
			if (result != FMOD_OK)
			{
				printf("FMOD failed to initialize: %s\n", FMOD_ErrorString(result));
				return;
			}
			result = fmodSoundSystem->getCoreSystem(&fmodCoreSoundSystem);
			if (result != FMOD_OK)
			{
				printf("FMOD failed to get core system: %s\n", FMOD_ErrorString(result));
				return;
			}

			autoUpdaterThread = std::thread(update_fmod_async);

			if(fmod_debug) printf("FMOD Sound System Started with %d channels!\n", numChannels);
		};

		void fmod_update() 
		{
			auto result = fmodSoundSystem->update();
			if (result != FMOD_OK)
			{
				printf("FMOD failed to self-update: %s\n", FMOD_ErrorString(result));
				return;
			}
		}

		void update_fmod_async()
		{
   			signal(SIGTERM, [](int signum){autoUpdaterThreadShouldExit = true;}); 

			while (!autoUpdaterThreadShouldExit){
				fmod_update();
				std::this_thread::sleep_for (std::chrono::milliseconds(16));
			}
		}

		//// Sound Banks

		void fmod_load_bank(const ::String& bankFilePath)
		{
			if (loadedBanks.find(bankFilePath) != loadedBanks.end())
			{
				return;
			}

			FMOD::Studio::Bank* tempBank;
			auto result = fmodSoundSystem->loadBankFile(bankFilePath.c_str(), FMOD_STUDIO_LOAD_BANK_NORMAL, &tempBank);
			if (result != FMOD_OK)
			{
				if(fmod_debug) printf("FMOD failed to LOAD sound bank %s: %s\n", bankFilePath.c_str(), FMOD_ErrorString(result));
				return;
			}

			loadedBanks[bankFilePath] = tempBank;
		}

		void fmod_unload_bank(const ::String& bankName)
		{
			auto found = loadedBanks.find(bankName);
			if (found != loadedBanks.end())
			{
				loadedBanks.erase(bankName);
				found->second->unload();
			}
		}

		//// Events

		void fmod_create_event_instance_one_shot(const ::String& eventPath)
		{
			FMOD::Studio::EventDescription* eventDescription;
			auto result = fmodSoundSystem->getEvent(eventPath.c_str(), &eventDescription);
			if (result != FMOD_OK)
			{
				if(fmod_debug) printf("FMOD failed to load event description %s: %s\n", eventPath.c_str(), FMOD_ErrorString(result));
				return;
			}

			FMOD::Studio::EventInstance* tempEvnInst;
			result = eventDescription->createInstance(&tempEvnInst);
			if (result != FMOD_OK)
			{
				if(fmod_debug) printf("FMOD failed to create instance of event %s: %s\n", eventPath.c_str(), FMOD_ErrorString(result));
				return;
			}
			
			result = tempEvnInst->start();
			if (result != FMOD_OK)
			{
				if(fmod_debug) printf("FMOD failed to start instance of event %s: %s\n", eventPath.c_str(), FMOD_ErrorString(result));
				return;
			}

			// Tell FMOD API to clean up memory as soon as the event is over
			result = tempEvnInst->release();
			if (result != FMOD_OK)
			{
				if(fmod_debug) printf("FMOD failed to release instance of event %s: %s\n", eventPath.c_str(), FMOD_ErrorString(result));
				return;
			}
		}

		void fmod_create_event_instance_named(const ::String& eventPath, const ::String& eventInstanceName)
		{
			auto existingEventInstance = loadedEventInstances.find(eventInstanceName);
			if (existingEventInstance != loadedEventInstances.end())
			{
				// Id conflict. Destroy existing sound and create new one in its place
				loadedEventInstances.erase(eventInstanceName);
				existingEventInstance->second->stop(FMOD_STUDIO_STOP_IMMEDIATE);
				existingEventInstance->second->release();
				if(fmod_debug) printf("FMOD request to create a new event instance %s with an existing instance name: %s. Destorying the old instance in preparation for the new one.\n", eventPath.c_str(), eventInstanceName.c_str());
			}

			FMOD::Studio::EventDescription* eventDescription;
			auto result = fmodSoundSystem->getEvent(eventPath.c_str(), &eventDescription);
			if (result != FMOD_OK)
			{
				if(fmod_debug) printf("FMOD failed to load event description %s: %s\n", eventPath.c_str(), FMOD_ErrorString(result));
			}

			FMOD::Studio::EventInstance* eventInstance;
			result = eventDescription->createInstance(&eventInstance);
			if (result != FMOD_OK)
			{
				if(fmod_debug) printf("FMOD failed to create event instance %s: %s\n", eventPath.c_str(), FMOD_ErrorString(result));
				return;
			}

			result = eventInstance->start();
			if (result != FMOD_OK)
			{
				if(fmod_debug) printf("FMOD failed to start event instance %s: %s\n", eventPath.c_str(), FMOD_ErrorString(result));
				return;
			}

			// Storing the event instance in a cache. There is no implicit cleanup of these instances.
			loadedEventInstances[eventInstanceName] = eventInstance;
			if (loadedEventInstances.size() > 25){
				printf("Warn: FMOD - The number of cached sounds is now %zu. ", loadedEventInstances.size());
				printf("Remember to release a sound after it is no longer needed. ");
				printf("If you do not need a reference to a sound after playing it, create it as a one shot. ");
				printf("When the cached sound count gets too high, sound reference corruption can occur\n");
				// https://github.com/Tanz0rz/faxe2/issues/3
			}
		}

		bool fmod_is_event_instance_loaded(const ::String& eventInstanceName)
		{
			if (loadedEventInstances.find(eventInstanceName) != loadedEventInstances.end())
			{
				return true;
			}
			return false;
		}

		void fmod_play_event_instance(const ::String& eventInstanceName)
		{
			auto targetEvent = loadedEventInstances.find(eventInstanceName);
			if (targetEvent != loadedEventInstances.end())
			{
				targetEvent->second->start();
			} else {
				if(fmod_debug) printf("Event %s is not loaded!\n", eventInstanceName.c_str());
			}
		}

		void fmod_set_pause_for_all_events_on_bus(const ::String& busPath, bool shouldBePaused)
		{
			FMOD::Studio::Bus* bus;
			auto result = fmodSoundSystem->getBus(busPath.c_str(), &bus);
			if (result != FMOD_OK)
			{
				if(fmod_debug) printf("FMOD failed to get bus %s: %s\n", busPath.c_str(), FMOD_ErrorString(result));
			}
			result = bus->setPaused(shouldBePaused);
			if (result != FMOD_OK)
			{
				if(fmod_debug) printf("FMOD failed to set pause on all event instances on bus %s: %s\n", busPath.c_str(), FMOD_ErrorString(result));
			}
		}

		void fmod_stop_all_events_on_bus(const ::String& busPath)
		{
			FMOD::Studio::Bus* bus;
			auto result = fmodSoundSystem->getBus(busPath.c_str(), &bus);
			if (result != FMOD_OK)
			{
				if(fmod_debug) printf("FMOD failed to get bus %s: %s\n", busPath.c_str(), FMOD_ErrorString(result));
			}
			result = bus->stopAllEvents(FMOD_STUDIO_STOP_IMMEDIATE);
			if (result != FMOD_OK)
			{
				if(fmod_debug) printf("FMOD failed to stop event instances on bus %s: %s\n", busPath.c_str(), FMOD_ErrorString(result));
			}
		}

		void fmod_set_pause_on_event_instance(const ::String& eventInstanceName, bool shouldBePaused)
		{
			auto targetEvent = loadedEventInstances.find(eventInstanceName);
			if (targetEvent != loadedEventInstances.end())
			{
				targetEvent->second->setPaused(shouldBePaused);
			} else {
				if(fmod_debug) printf("Event %s is not loaded!\n", eventInstanceName.c_str());
			}
		}

		void fmod_stop_event_instance(const ::String& eventInstanceName)
		{
			auto targetStopEvent = loadedEventInstances.find(eventInstanceName);
			if (targetStopEvent != loadedEventInstances.end())
			{
				targetStopEvent->second->stop(FMOD_STUDIO_STOP_ALLOWFADEOUT);
			} else {
				if(fmod_debug) printf("Event %s is not loaded!\n", eventInstanceName.c_str());
			}
		}

		void fmod_stop_event_instance_immediately(const ::String& eventInstanceName)
		{
			auto targetStopEvent = loadedEventInstances.find(eventInstanceName);
			if (targetStopEvent != loadedEventInstances.end())
			{
				targetStopEvent->second->stop(FMOD_STUDIO_STOP_IMMEDIATE);
			} else {
				if(fmod_debug) printf("Event %s is not loaded!\n", eventInstanceName.c_str());
			}
		}

		void fmod_release_event_instance(const ::String& eventInstanceName)
		{
			auto existingEventInstance = loadedEventInstances.find(eventInstanceName);
			if (existingEventInstance != loadedEventInstances.end())
			{
				auto result = existingEventInstance->second->stop(FMOD_STUDIO_STOP_IMMEDIATE);
				if (result != FMOD_OK)
				{
					if(fmod_debug) printf("FMOD failed to stop event instance %s: %s\n", eventInstanceName.c_str(), FMOD_ErrorString(result));
					return;
				}

				result = existingEventInstance->second->release();
				if (result != FMOD_OK)
				{
					if(fmod_debug) printf("FMOD failed to release event instance %s: %s\n", eventInstanceName.c_str(), FMOD_ErrorString(result));
					return;
				}

				loadedEventInstances.erase(eventInstanceName);
			}
		}

		bool fmod_is_event_instance_playing(const ::String& eventInstanceName)
		{
			auto targetEvent = loadedEventInstances.find(eventInstanceName);
			if (targetEvent != loadedEventInstances.end())
			{
				FMOD_STUDIO_PLAYBACK_STATE currentState;
				auto result = targetEvent->second->getPlaybackState(&currentState);

				if (result != FMOD_OK)
				{
					if(fmod_debug) printf("FMOD failed to get playback state of event instance %s: %s\n", eventInstanceName.c_str(), FMOD_ErrorString(result));
					return false;
				}
				
				return (currentState == FMOD_STUDIO_PLAYBACK_PLAYING);
			} else {
				if(fmod_debug) printf("Event %s is not loaded!\n", eventInstanceName.c_str());
				return false;
			}
		}

		FMOD_STUDIO_PLAYBACK_STATE fmod_get_event_instance_playback_state(const ::String& eventInstanceName)
		{
			auto targetEvent = loadedEventInstances.find(eventInstanceName);
			if (targetEvent != loadedEventInstances.end())
			{
				FMOD_STUDIO_PLAYBACK_STATE currentState;
				auto result = targetEvent->second->getPlaybackState(&currentState);

				if (result != FMOD_OK)
				{
					if(fmod_debug) printf("FMOD failed to get playback state of event instance %s: %s\n", eventInstanceName.c_str(), FMOD_ErrorString(result));
					return FMOD_STUDIO_PLAYBACK_FORCEINT;
				}

				return currentState;
			} else {
				if(fmod_debug) printf("Event %s is not loaded!\n", eventInstanceName.c_str());
				return FMOD_STUDIO_PLAYBACK_FORCEINT;
			}
		}

		float fmod_get_event_instance_param(const ::String& eventInstanceName, const ::String& paramName)
		{
			auto targetEvent = loadedEventInstances.find(eventInstanceName);
			if (targetEvent != loadedEventInstances.end())
			{
				float currentValue;
				auto result = targetEvent->second->getParameterByName(paramName.c_str(), &currentValue);

				if (result != FMOD_OK)
				{
					if(fmod_debug) printf("FMOD failed to get param %s of event instance %s: %s\n", paramName.c_str(), eventInstanceName.c_str(), FMOD_ErrorString(result));
					return -1;
				}

				return currentValue;
			} else {
				if(fmod_debug) printf("Event %s is not loaded!\n", eventInstanceName.c_str());
				return -1;
			}
		}

		void fmod_set_event_instance_param(const ::String& eventInstanceName, const ::String& paramName, float value)
		{
			auto targetEvent = loadedEventInstances.find(eventInstanceName);
			if (targetEvent != loadedEventInstances.end())
			{
				auto result = targetEvent->second->setParameterByName(paramName.c_str(), value);

				if (result != FMOD_OK)
				{
					if(fmod_debug) printf("FMOD failed to SET PARAM %s of event instance %s: %s\n", paramName.c_str(), eventInstanceName.c_str(), FMOD_ErrorString(result));
				}
			} else {
				if(fmod_debug) printf("Event %s is not loaded!\n", eventInstanceName.c_str());
			}
		}

		//// Callbacks

		::String GetEventInstancePath(FMOD::Studio::EventInstance* eventInstance) {
			char *path = new char [100];
			int *retrieved = new int;
			FMOD::Studio::EventDescription* eventDescription;
			eventInstance->getDescription(&eventDescription);
			eventDescription->getPath(path, 100, retrieved);
			if (path == NULL){
				printf("Fmod Callback could not find description of event\n");
			}

			// Haxe has a dedicated String class that must be used to convert char* to a string
			::String pathAsString(path, *retrieved);

			return pathAsString;
		}

		// Callback definitions must be defined before they are used in functions
		FMOD_RESULT F_CALL GetCallbackType(FMOD_STUDIO_EVENT_CALLBACK_TYPE type, FMOD_STUDIO_EVENTINSTANCE *event, void *parameters)
		{
			auto eventInstancePath = GetEventInstancePath((FMOD::Studio::EventInstance*) event);
			auto eventWithCallback = eventCallbacksFlagsMap.find(eventInstancePath);
			if (eventWithCallback != eventCallbacksFlagsMap.end()) {
				eventWithCallback->second = eventWithCallback->second | type;
				return FMOD_OK;
			}
			return FMOD_ERR_EVENT_NOTFOUND;
		}

		void fmod_set_callback_tracking_for_event_instance(const ::String& eventInstanceName) {
			auto existingEventInstance = loadedEventInstances.find(eventInstanceName);
			if (existingEventInstance != loadedEventInstances.end())
			{
				existingEventInstance->second->setCallback(GetCallbackType);

				auto eventInstancePath = GetEventInstancePath(existingEventInstance->second);
				if (eventInstancePath.length == 0) 
				{
					printf("Haxefmod-cpp - Fmod Callback could not find description of event\n");
				} else {
					eventCallbacksFlagsMap[eventInstancePath] = 0;
				}
			}
			else 
			{
				if(fmod_debug) printf("Could not set callback tracking on %s because it wasn't found\n", eventInstanceName.c_str());
			}
		}

		bool fmod_check_callbacks_for_event_instance(const ::String& eventInstanceName, unsigned int callbackEventMask){
			auto existingEventInstance = loadedEventInstances.find(eventInstanceName);
			if (existingEventInstance != loadedEventInstances.end())
			{
				auto eventInstancePath = GetEventInstancePath(existingEventInstance->second);
				if (eventInstancePath.length == 0) 
				{
					printf("Fmod Callback could not find description of event\n");
				} else {
					bool eventHappened = eventCallbacksFlagsMap[eventInstancePath] & callbackEventMask;
					eventCallbacksFlagsMap[eventInstancePath] &= ~callbackEventMask;
					return eventHappened;
				}
			}
			else 
			{
				if(fmod_debug) printf("Could not check callback on %s because it wasn't found\n", eventInstanceName.c_str());
			}
			return false;
		}

	} // faxe + fmod namespace
} // linc namespace
