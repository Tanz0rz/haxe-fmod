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
		std::map<::String, FMOD::Studio::EventDescription*> loadedEventDescriptions;
		
		bool faxe_debug = true;
		void faxe_set_debug(bool onOff){
			faxe_debug = onOff;
		}

		//// FMOD System

		void faxe_init(int numChannels)
		{
			// Choose a reasonable default if 0 is passed in
			if (numChannels == 0){
				numChannels = 36;
			}

			// Create our new fmod system
			if (FMOD::Studio::System::create(&fmodSoundSystem) != FMOD_OK)
			{
				if(faxe_debug) printf("Failure starting FMOD sound system!");
				return;
			}

			// Initialize system with channel count and startup flags
			fmodSoundSystem->initialize(numChannels, FMOD_STUDIO_INIT_LIVEUPDATE, FMOD_INIT_NORMAL, nullptr);
			fmodSoundSystem->getCoreSystem(&fmodCoreSoundSystem);
			if(faxe_debug) printf("FMOD Sound System Started with %d channels!\n", numChannels);
		}

		void faxe_update()
		{
			fmodSoundSystem->update();
		}

		//// Sound Banks

		void faxe_load_bank(const ::String& bankFilePath)
		{
			if (loadedBanks.find(bankFilePath) != loadedBanks.end())
			{
				return;
			}

			FMOD::Studio::Bank* tempBank;
			auto result = fmodSoundSystem->loadBankFile(bankFilePath.c_str(), FMOD_STUDIO_LOAD_BANK_NORMAL, &tempBank);
			if (result != FMOD_OK)
			{
				if(faxe_debug) printf("FMOD failed to LOAD sound bank %s: %s\n", bankFilePath.c_str(), FMOD_ErrorString(result));
				return;
			}

			loadedBanks[bankFilePath] = tempBank;
		}

		void faxe_unload_bank(const ::String& bankName)
		{
			auto found = loadedBanks.find(bankName);
			if (found != loadedBanks.end())
			{
				loadedBanks.erase(bankName);
				found->second->unload();
			}
		}

		//// Event Descriptions

		void faxe_load_event_description(const ::String& eventPath)
		{
			if (loadedEventDescriptions.find(eventPath) != loadedEventDescriptions.end())
			{
				if(faxe_debug) printf("FMOD event description already loaded\n");
				return;
			}

			FMOD::Studio::EventDescription* tempEvnDesc;
			auto result = fmodSoundSystem->getEvent(eventPath.c_str(), &tempEvnDesc);
			if (result != FMOD_OK)
			{
				if(faxe_debug) printf("FMOD failed to load event description %s: %s\n", eventPath.c_str(), FMOD_ErrorString(result));
				return;
			}

			loadedEventDescriptions[eventPath] = tempEvnDesc;
		}

		bool faxe_is_event_description_loaded(const ::String& eventDescriptionName)
		{
			if (loadedEventDescriptions.find(eventDescriptionName) != loadedEventDescriptions.end())
			{
				return true;
			}
			return false;
		}

		// Check cache for event description and try to load if missing
		FMOD::Studio::EventDescription* internal_only_GetEventDescription(const ::String& eventPath) {
			FMOD::Studio::EventDescription* eventDescription;
			auto eventDescriptionMapEntry = loadedEventDescriptions.find(eventPath);
			if (eventDescriptionMapEntry != loadedEventDescriptions.end()){
				eventDescription = eventDescriptionMapEntry->second;
			}
			else
			{
				auto result = fmodSoundSystem->getEvent(eventPath.c_str(), &eventDescription);
				if (result != FMOD_OK)
				{
					if(faxe_debug) printf("FMOD failed to load event description %s: %s\n", eventPath.c_str(), FMOD_ErrorString(result));
					return NULL;
				}
				loadedEventDescriptions[eventPath] = eventDescription;
			}
			return eventDescription;
		}

		//// Event Instances

		void faxe_create_event_instance_one_shot(const ::String& eventPath)
		{
			FMOD::Studio::EventDescription* eventDescription = internal_only_GetEventDescription(eventPath);
			if (eventDescription == NULL){
				if(faxe_debug) printf("FMOD did not play one shot because event description was missing\n");
				return;
			}

			FMOD::Studio::EventInstance* tempEvnInst;
			auto result = eventDescription->createInstance(&tempEvnInst);
			if (result != FMOD_OK)
			{
				if(faxe_debug) printf("FMOD failed to create instance of event %s: %s\n", eventPath.c_str(), FMOD_ErrorString(result));
				return;
			}
			
			result = tempEvnInst->start();
			if (result != FMOD_OK)
			{
				if(faxe_debug) printf("FMOD failed to start instance of event %s: %s\n", eventPath.c_str(), FMOD_ErrorString(result));
				return;
			}

			// Tell FMOD API to clean up memory as soon as the event is over
			result = tempEvnInst->release();
			if (result != FMOD_OK)
			{
				if(faxe_debug) printf("FMOD failed to release instance of event %s: %s\n", eventPath.c_str(), FMOD_ErrorString(result));
				return;
			}
		}

		void faxe_create_event_instance_named(const ::String& eventPath, const ::String& eventInstanceName)
		{
			auto existingEventInstance = loadedEventInstances.find(eventInstanceName);
			if (existingEventInstance != loadedEventInstances.end())
			{
				// Id conflict. Destroy existing sound and create new one in its place
				loadedEventInstances.erase(eventInstanceName);
				existingEventInstance->second->stop(FMOD_STUDIO_STOP_IMMEDIATE);
				existingEventInstance->second->release();
				if(faxe_debug) printf("FMOD request to create a new event instance %s with an existing instance name: %s. Destorying the old instance in preparation for the new one.\n", eventPath.c_str(), eventInstanceName.c_str());
			}

			FMOD::Studio::EventDescription* eventDescription = internal_only_GetEventDescription(eventPath);
			if (eventDescription == NULL){
				return;
			}

			FMOD::Studio::EventInstance* eventInstance;
			auto result = eventDescription->createInstance(&eventInstance);
			if (result != FMOD_OK)
			{
				if(faxe_debug) printf("FMOD failed to create event instance %s: %s\n", eventPath.c_str(), FMOD_ErrorString(result));
				return;
			}

			result = eventInstance->start();
			if (result != FMOD_OK)
			{
				if(faxe_debug) printf("FMOD failed to start event instance %s: %s\n", eventPath.c_str(), FMOD_ErrorString(result));
				return;
			}
			if(faxe_debug) printf("FMOD created new named event instance %s\n", eventPath.c_str());

			// Storing the event instance in a cache. There is no implicit cleanup of these instances.
			loadedEventInstances[eventInstanceName] = eventInstance;
		}

		bool faxe_is_event_instance_loaded(const ::String& eventInstanceName)
		{
			if (loadedEventInstances.find(eventInstanceName) != loadedEventInstances.end())
			{
				return true;
			}
			return false;
		}

		void faxe_play_event_instance(const ::String& eventInstanceName)
		{
			auto targetEvent = loadedEventInstances.find(eventInstanceName);
			if (targetEvent != loadedEventInstances.end())
			{
				targetEvent->second->start();
			} else {
				if(faxe_debug) printf("Event %s is not loaded!\n", eventInstanceName.c_str());
			}
		}

		void faxe_set_pause_on_event_instance(const ::String& eventInstanceName, bool shouldBePaused)
		{
			auto targetEvent = loadedEventInstances.find(eventInstanceName);
			if (targetEvent != loadedEventInstances.end())
			{
				targetEvent->second->setPaused(shouldBePaused);
			} else {
				if(faxe_debug) printf("Event %s is not loaded!\n", eventInstanceName.c_str());
			}
		}

		void faxe_stop_event_instance(const ::String& eventInstanceName, bool forceStop)
		{
			auto targetStopEvent = loadedEventInstances.find(eventInstanceName);
			if (targetStopEvent != loadedEventInstances.end())
			{
				FMOD_STUDIO_STOP_MODE stopMode;

				if (forceStop)
				{
					stopMode = FMOD_STUDIO_STOP_IMMEDIATE;
				} else {
					stopMode = FMOD_STUDIO_STOP_ALLOWFADEOUT;
				}

				targetStopEvent->second->stop(stopMode);
			} else {
				if(faxe_debug) printf("Event %s is not loaded!\n", eventInstanceName.c_str());
			}
		}

		void faxe_release_event_instance(const ::String& eventInstanceName)
		{
			auto found = loadedEventInstances.find(eventInstanceName);
			if (found != loadedEventInstances.end())
			{
				loadedEventInstances.erase(eventInstanceName);
				found->second->release();
			}
		}

		bool faxe_is_event_instance_playing(const ::String& eventInstanceName)
		{
			auto targetEvent = loadedEventInstances.find(eventInstanceName);
			if (targetEvent != loadedEventInstances.end())
			{
				FMOD_STUDIO_PLAYBACK_STATE currentState;
				auto result = targetEvent->second->getPlaybackState(&currentState);

				if (result != FMOD_OK)
				{
					if(faxe_debug) printf("FMOD failed to get playback state of event instance %s: %s\n", eventInstanceName.c_str(), FMOD_ErrorString(result));
					return false;
				}
				
				return (currentState == FMOD_STUDIO_PLAYBACK_PLAYING);
			} else {
				if(faxe_debug) printf("Event %s is not loaded!\n", eventInstanceName.c_str());
				return false;
			}
		}

		FMOD_STUDIO_PLAYBACK_STATE faxe_get_event_instance_playback_state(const ::String& eventInstanceName)
		{
			auto targetEvent = loadedEventInstances.find(eventInstanceName);
			if (targetEvent != loadedEventInstances.end())
			{
				FMOD_STUDIO_PLAYBACK_STATE currentState;
				auto result = targetEvent->second->getPlaybackState(&currentState);

				if (result != FMOD_OK)
				{
					if(faxe_debug) printf("FMOD failed to get playback state of event instance %s: %s\n", eventInstanceName.c_str(), FMOD_ErrorString(result));
					return FMOD_STUDIO_PLAYBACK_FORCEINT;
				}

				return currentState;
			} else {
				if(faxe_debug) printf("Event %s is not loaded!\n", eventInstanceName.c_str());
				return FMOD_STUDIO_PLAYBACK_FORCEINT;
			}
		}

		float faxe_get_event_instance_param(const ::String& eventInstanceName, const ::String& paramName)
		{
			auto targetEvent = loadedEventInstances.find(eventInstanceName);
			if (targetEvent != loadedEventInstances.end())
			{
				float currentValue;
				auto result = targetEvent->second->getParameterByName(paramName.c_str(), &currentValue);

				if (result != FMOD_OK)
				{
					if(faxe_debug) printf("FMOD failed to get param %s of event instance %s: %s\n", paramName.c_str(), eventInstanceName.c_str(), FMOD_ErrorString(result));
					return -1;
				}

				return currentValue;
			} else {
				if(faxe_debug) printf("Event %s is not loaded!\n", eventInstanceName.c_str());
				return -1;
			}
		}

		void faxe_set_event_instance_param(const ::String& eventInstanceName, const ::String& paramName, float value)
		{
			auto targetEvent = loadedEventInstances.find(eventInstanceName);
			if (targetEvent != loadedEventInstances.end())
			{
				auto result = targetEvent->second->setParameterByName(paramName.c_str(), value);

				if (result != FMOD_OK)
				{
					if(faxe_debug) printf("FMOD failed to SET PARAM %s of event instance %s: %s\n", paramName.c_str(), eventInstanceName.c_str(), FMOD_ErrorString(result));
				}
			} else {
				if(faxe_debug) printf("Event %s is not loaded!\n", eventInstanceName.c_str());
			}
		}

	} // faxe + fmod namespace
} // linc namespace
