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

#include "linc_faxe.h"

#include <csignal>
#include <fmod_errors.h>
#include <fmod_studio.hpp>
#include <map>
#include <thread>

// FMOD Sound System
FMOD::Studio::System *fmodSoundSystem;
FMOD::System *fmodCoreSoundSystem;

// Maps to track what has been loaded already
std::map<const char*, FMOD::Studio::Bank *> loadedBanks;
std::map<const char*, FMOD::Sound *> loadedSounds;
std::map<const char*, FMOD::Studio::EventInstance *> loadedEventInstances;

// Callbacks
std::map<const char*, unsigned int> eventCallbacksFlagsMap;

// Background thread to automatically call FMOD's Update() function
// #if FAXE_HL
// hl_thread *autoUpdaterThread;
// #else
// std::thread autoUpdaterThread;
// #endif
bool autoUpdaterThreadShouldExit;

//// FMOD System

bool fmod_debug = false;
HL_PRIM void HL_NAME(fmod_set_debug)(bool onOff) { fmod_debug = onOff; }

HL_PRIM bool HL_NAME(fmod_is_initialized)() { return true; }

HL_PRIM void HL_NAME(fmod_init)(int numChannels)
{
	if (fmod_debug)
		printf("Initializing HaxeFmod\n");
	// Choose a reasonable default if 0 is passed in
	if (numChannels == 0)
	{
		numChannels = 36;
	}

	// Create our new fmod system
	if (FMOD::Studio::System::create(&fmodSoundSystem) != FMOD_OK)
	{
		if (fmod_debug)
			printf("Failure starting FMOD sound system!\n");
		return;
	}

	// Initialize system with channel count and startup flags
	auto result = fmodSoundSystem->initialize(
		numChannels, FMOD_STUDIO_INIT_LIVEUPDATE, FMOD_INIT_NORMAL, nullptr);
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
	// #if FAXE_HL
	// autoUpdaterThread = hl_thread_start((void*)update_fmod_async,nullptr,true);
	// #else
	// autoUpdaterThread = std::thread(update_fmod_async);
	// #endif

	if (fmod_debug)
		printf("FMOD Sound System Started with %d channels!\n", numChannels);
};

HL_PRIM void HL_NAME(fmod_update)()
{
	auto result = fmodSoundSystem->update();
	if (result != FMOD_OK)
	{
		printf("FMOD failed to self-update: %s\n", FMOD_ErrorString(result));
		return;
	}
}

// #if FAXE_HL
// static bool isThreadRegistered = false;
// #endif

// void update_fmod_async()
// {
// 	#if FAXE_HL
// 	if(!isThreadRegistered){
// 		isThreadRegistered = true;
// 		vdynamic *ret;
// 		hl_register_thread(&ret);
// 	}
// 	#endif
// 	signal(SIGTERM, [](int signum) { autoUpdaterThreadShouldExit = true; });

// 	while (!autoUpdaterThreadShouldExit)
// 	{
// 		faxe_fmod_update();
// 		std::this_thread::sleep_for(std::chrono::milliseconds(16));
// 	}
// }

//// Sound Banks

HL_PRIM void HL_NAME(fmod_load_bank)(const char* bankFilePath)
{
	if (loadedBanks.find(bankFilePath) != loadedBanks.end())
	{
		return;
	}

	FMOD::Studio::Bank *tempBank;
	auto result = fmodSoundSystem->loadBankFile(
		bankFilePath, FMOD_STUDIO_LOAD_BANK_NORMAL, &tempBank);
	if (result != FMOD_OK)
	{
		if (fmod_debug)
			printf("FMOD failed to LOAD sound bank %s: %s\n",
				   bankFilePath, FMOD_ErrorString(result));
		return;
	}

	loadedBanks[bankFilePath] = tempBank;
}

HL_PRIM void HL_NAME(fmod_unload_bank)(const char* bankName)
{
	auto found = loadedBanks.find(bankName);
	if (found != loadedBanks.end())
	{
		loadedBanks.erase(bankName);
		found->second->unload();
	}
}

//// Events

HL_PRIM void
	HL_NAME(fmod_create_event_instance_one_shot)(const char* eventPath)
{
	FMOD::Studio::EventDescription *eventDescription;
	auto result =
		fmodSoundSystem->getEvent(eventPath, &eventDescription);
	if (result != FMOD_OK)
	{
		if (fmod_debug)
			printf("FMOD failed to load event description %s: %s\n",
				   eventPath, FMOD_ErrorString(result));
		return;
	}

	FMOD::Studio::EventInstance *tempEvnInst;
	result = eventDescription->createInstance(&tempEvnInst);
	if (result != FMOD_OK)
	{
		if (fmod_debug)
			printf("FMOD failed to create instance of event %s: %s\n",
				   eventPath, FMOD_ErrorString(result));
		return;
	}

	result = tempEvnInst->start();
	if (result != FMOD_OK)
	{
		if (fmod_debug)
			printf("FMOD failed to start instance of event %s: %s\n",
				   eventPath, FMOD_ErrorString(result));
		return;
	}

	// Tell FMOD API to clean up memory as soon as the event is over
	result = tempEvnInst->release();
	if (result != FMOD_OK)
	{
		if (fmod_debug)
			printf("FMOD failed to release instance of event %s: %s\n",
				   eventPath, FMOD_ErrorString(result));
		return;
	}
}

HL_PRIM void
	HL_NAME(fmod_create_event_instance_named)(const char* eventPath,
											  const char* eventInstanceName)
{
	auto existingEventInstance = loadedEventInstances.find(eventInstanceName);
	if (existingEventInstance != loadedEventInstances.end())
	{
		// Id conflict. Destroy existing sound and create new one in its place
		loadedEventInstances.erase(eventInstanceName);
		existingEventInstance->second->stop(FMOD_STUDIO_STOP_IMMEDIATE);
		existingEventInstance->second->release();
		if (fmod_debug)
			printf("FMOD request to create a new event instance %s with an existing "
				   "instance name: %s. Destorying the old instance in preparation "
				   "for the new one.\n",
				   eventPath, eventInstanceName);
	}

	FMOD::Studio::EventDescription *eventDescription;
	auto result =
		fmodSoundSystem->getEvent(eventPath, &eventDescription);
	if (result != FMOD_OK)
	{
		if (fmod_debug)
			printf("FMOD failed to load event description %s: %s\n",
				   eventPath, FMOD_ErrorString(result));
	}

	FMOD::Studio::EventInstance *eventInstance;
	result = eventDescription->createInstance(&eventInstance);
	if (result != FMOD_OK)
	{
		if (fmod_debug)
			printf("FMOD failed to create event instance %s: %s\n",
				   eventPath, FMOD_ErrorString(result));
		return;
	}

	result = eventInstance->start();
	if (result != FMOD_OK)
	{
		if (fmod_debug)
			printf("FMOD failed to start event instance %s: %s\n",
				   eventPath, FMOD_ErrorString(result));
		return;
	}

	// Storing the event instance in a cache. There is no implicit cleanup of
	// these instances.
	loadedEventInstances[eventInstanceName] = eventInstance;
	if (loadedEventInstances.size() > 25)
	{
		printf("Warn: FMOD - The number of cached sounds is now %zu. ",
			   loadedEventInstances.size());
		printf("Remember to release a sound after it is no longer needed. ");
		printf("If you do not need a reference to a sound after playing it, create "
			   "it as a one shot. ");
		printf("When the cached sound count gets too high, sound reference "
			   "corruption can occur\n");
		// https://github.com/Tanz0rz/faxe2/issues/3
	}
}

HL_PRIM bool
	HL_NAME(fmod_is_event_instance_loaded)(const char* eventInstanceName)
{
	if (loadedEventInstances.find(eventInstanceName) !=
		loadedEventInstances.end())
	{
		return true;
	}
	return false;
}

HL_PRIM void HL_NAME(fmod_play_event_instance)(const char* eventInstanceName)
{
	auto targetEvent = loadedEventInstances.find(eventInstanceName);
	if (targetEvent != loadedEventInstances.end())
	{
		targetEvent->second->start();
	}
	else
	{
		if (fmod_debug)
			printf("Event %s is not loaded!\n", eventInstanceName);
	}
}

HL_PRIM void HL_NAME(fmod_set_pause_for_all_events_on_bus)(const char* busPath, bool shouldBePaused)
{
	FMOD::Studio::Bus* bus;
	auto result = fmodSoundSystem->getBus(busPath, &bus);
	if (result != FMOD_OK)
	{
		if(fmod_debug) printf("FMOD failed to get bus %s: %s\n", busPath, FMOD_ErrorString(result));
	}
	result = bus->setPaused(shouldBePaused);
	if (result != FMOD_OK)
	{
		if(fmod_debug) printf("FMOD failed to set pause on all event instances on bus %s: %s\n", busPath, FMOD_ErrorString(result));
	}
}

HL_PRIM void HL_NAME(fmod_stop_all_events_on_bus)(const char* busPath)
{
	FMOD::Studio::Bus* bus;
	auto result = fmodSoundSystem->getBus(busPath, &bus);
	if (result != FMOD_OK)
	{
		if(fmod_debug) printf("FMOD failed to get bus %s: %s\n", busPath, FMOD_ErrorString(result));
	}
	result = bus->stopAllEvents(FMOD_STUDIO_STOP_IMMEDIATE);
	if (result != FMOD_OK)
	{
		if(fmod_debug) printf("FMOD failed to stop event instances on bus %s: %s\n", busPath, FMOD_ErrorString(result));
	}
}

HL_PRIM void
	HL_NAME(fmod_set_pause_on_event_instance)(const char* eventInstanceName,
											  bool shouldBePaused)
{
	auto targetEvent = loadedEventInstances.find(eventInstanceName);
	if (targetEvent != loadedEventInstances.end())
	{
		targetEvent->second->setPaused(shouldBePaused);
	}
	else
	{
		if (fmod_debug)
			printf("Event %s is not loaded!\n", eventInstanceName);
	}
}

HL_PRIM void HL_NAME(fmod_stop_event_instance)(const char* eventInstanceName)
{
	auto targetStopEvent = loadedEventInstances.find(eventInstanceName);
	if (targetStopEvent != loadedEventInstances.end())
	{
		targetStopEvent->second->stop(FMOD_STUDIO_STOP_ALLOWFADEOUT);
	}
	else
	{
		if (fmod_debug)
			printf("Event %s is not loaded!\n", eventInstanceName);
	}
}

HL_PRIM void
	HL_NAME(fmod_stop_event_instance_immediately)(const char* eventInstanceName)
{
	auto targetStopEvent = loadedEventInstances.find(eventInstanceName);
	if (targetStopEvent != loadedEventInstances.end())
	{
		targetStopEvent->second->stop(FMOD_STUDIO_STOP_IMMEDIATE);
	}
	else
	{
		if (fmod_debug)
			printf("Event %s is not loaded!\n", eventInstanceName);
	}
}

HL_PRIM void
	HL_NAME(fmod_release_event_instance)(const char* eventInstanceName)
{
	auto existingEventInstance = loadedEventInstances.find(eventInstanceName);
	if (existingEventInstance != loadedEventInstances.end())
	{
		auto result =
			existingEventInstance->second->stop(FMOD_STUDIO_STOP_IMMEDIATE);
		if (result != FMOD_OK)
		{
			if (fmod_debug)
				printf("FMOD failed to stop event instance %s: %s\n",
					   eventInstanceName, FMOD_ErrorString(result));
			return;
		}

		result = existingEventInstance->second->release();
		if (result != FMOD_OK)
		{
			if (fmod_debug)
				printf("FMOD failed to release event instance %s: %s\n",
					   eventInstanceName, FMOD_ErrorString(result));
			return;
		}

		loadedEventInstances.erase(eventInstanceName);
	}
}

HL_PRIM bool
	HL_NAME(fmod_is_event_instance_playing)(const char* eventInstanceName)
{
	auto targetEvent = loadedEventInstances.find(eventInstanceName);
	if (targetEvent != loadedEventInstances.end())
	{
		FMOD_STUDIO_PLAYBACK_STATE currentState;
		auto result = targetEvent->second->getPlaybackState(&currentState);

		if (result != FMOD_OK)
		{
			if (fmod_debug)
				printf("FMOD failed to get playback state of event instance %s: %s\n",
					   eventInstanceName, FMOD_ErrorString(result));
			return false;
		}

		return (currentState == FMOD_STUDIO_PLAYBACK_PLAYING);
	}
	else
	{
		if (fmod_debug)
			printf("Event %s is not loaded!\n", eventInstanceName);
		return false;
	}
}

HL_PRIM FMOD_STUDIO_PLAYBACK_STATE
	HL_NAME(fmod_get_event_instance_playback_state)(const char* eventInstanceName)
{
	auto targetEvent = loadedEventInstances.find(eventInstanceName);
	if (targetEvent != loadedEventInstances.end())
	{
		FMOD_STUDIO_PLAYBACK_STATE currentState;
		auto result = targetEvent->second->getPlaybackState(&currentState);

		if (result != FMOD_OK)
		{
			if (fmod_debug)
				printf("FMOD failed to get playback state of event instance %s: %s\n",
					   eventInstanceName, FMOD_ErrorString(result));
			return FMOD_STUDIO_PLAYBACK_FORCEINT;
		}

		return currentState;
	}
	else
	{
		if (fmod_debug)
			printf("Event %s is not loaded!\n", eventInstanceName);
		return FMOD_STUDIO_PLAYBACK_FORCEINT;
	}
}

HL_PRIM float
	HL_NAME(fmod_get_event_instance_param)(const char* eventInstanceName,
										   const char* paramName)
{
	auto targetEvent = loadedEventInstances.find(eventInstanceName);
	if (targetEvent != loadedEventInstances.end())
	{
		float currentValue;
		auto result = targetEvent->second->getParameterByName(
			paramName, &currentValue);

		if (result != FMOD_OK)
		{
			if (fmod_debug)
				printf("FMOD failed to get param %s of event instance %s: %s\n",
					   paramName, eventInstanceName,
					   FMOD_ErrorString(result));
			return -1;
		}

		return currentValue;
	}
	else
	{
		if (fmod_debug)
			printf("Event %s is not loaded!\n", eventInstanceName);
		return -1;
	}
}

HL_PRIM void
	HL_NAME(fmod_set_event_instance_param)(const char* eventInstanceName,
										   const char* paramName, float value)
{
	auto targetEvent = loadedEventInstances.find(eventInstanceName);
	if (targetEvent != loadedEventInstances.end())
	{
		auto result = targetEvent->second->setParameterByName(
			paramName, value);

		if (result != FMOD_OK)
		{
			if (fmod_debug)
				printf("FMOD failed to SET PARAM %s of event instance %s: %s\n",
					   paramName, eventInstanceName,
					   FMOD_ErrorString(result));
		}
	}
	else
	{
		if (fmod_debug)
			printf("Event %s is not loaded!\n", eventInstanceName);
	}
}

//// Callbacks

char* GetEventInstancePath(FMOD::Studio::EventInstance *eventInstance)
{
	char *path = new char[100];
	int retrieved;
	FMOD::Studio::EventDescription *eventDescription;
	eventInstance->getDescription(&eventDescription);
	eventDescription->getPath(path, 100, &retrieved);
	if (path == NULL)
	{
		printf("Fmod Callback could not find description of event\n");
		return "";
	}
	return path;
}

// Callback definitions must be defined before they are used in functions
FMOD_RESULT F_CALLBACK GetCallbackType(FMOD_STUDIO_EVENT_CALLBACK_TYPE type,
									   FMOD_STUDIO_EVENTINSTANCE *event,
									   void *parameters)
{
	auto eventInstancePath =
		GetEventInstancePath((FMOD::Studio::EventInstance *)event);
	auto eventWithCallback = eventCallbacksFlagsMap.find(eventInstancePath);
	if (eventWithCallback != eventCallbacksFlagsMap.end())
	{
		eventWithCallback->second = eventWithCallback->second | type;
		return FMOD_OK;
	}
	return FMOD_ERR_EVENT_NOTFOUND;
}

HL_PRIM void HL_NAME(fmod_set_callback_tracking_for_event_instance)(
	const char* eventInstanceName)
{
	auto existingEventInstance = loadedEventInstances.find(eventInstanceName);
	if (existingEventInstance != loadedEventInstances.end())
	{
		existingEventInstance->second->setCallback(GetCallbackType);

		auto eventInstancePath =
			GetEventInstancePath(existingEventInstance->second);
		if (strlen(eventInstancePath) == 0)
		{
			printf(
				"Haxefmod-cpp - Fmod Callback could not find description of event\n");
		}
		else
		{
			eventCallbacksFlagsMap[eventInstancePath] = 0;
		}
	}
	else
	{
		if (fmod_debug)
			printf("Could not set callback tracking on %s because it wasn't found\n",
				   eventInstanceName);
	}
}

HL_PRIM bool HL_NAME(fmod_check_callbacks_for_event_instance)(
	const char* eventInstanceName, unsigned int callbackEventMask)
{
	auto existingEventInstance = loadedEventInstances.find(eventInstanceName);
	if (existingEventInstance != loadedEventInstances.end())
	{
		auto eventInstancePath =
			GetEventInstancePath(existingEventInstance->second);
		if (strlen(eventInstancePath) == 0)
		{
			printf("Fmod Callback could not find description of event\n");
		}
		else
		{
			bool eventHappened =
				eventCallbacksFlagsMap[eventInstancePath] & callbackEventMask;
			eventCallbacksFlagsMap[eventInstancePath] &= ~callbackEventMask;
			return eventHappened;
		}
	}
	else
	{
		if (fmod_debug)
			printf("Could not check callback on %s because it wasn't found\n",
				   eventInstanceName);
	}
	return false;
}

#ifdef FAXE_HL
DEFINE_PRIM(_VOID, fmod_set_debug, _BOOL)
DEFINE_PRIM(_BOOL, fmod_is_initialized, _NO_ARG)
DEFINE_PRIM(_VOID, fmod_init, _I32)
DEFINE_PRIM(_VOID, fmod_update, _NO_ARG)
DEFINE_PRIM(_VOID, fmod_load_bank, _BYTES)
DEFINE_PRIM(_VOID, fmod_unload_bank, _BYTES)
DEFINE_PRIM(_VOID, fmod_create_event_instance_one_shot, _BYTES)
DEFINE_PRIM(_VOID, fmod_create_event_instance_named, _BYTES _BYTES)
DEFINE_PRIM(_BOOL, fmod_is_event_instance_loaded, _BYTES)
DEFINE_PRIM(_VOID, fmod_play_event_instance, _BYTES)
DEFINE_PRIM(_VOID, fmod_set_pause_for_all_events_on_bus, _BYTES _BOOL)
DEFINE_PRIM(_VOID, fmod_stop_all_events_on_bus, _BYTES)
DEFINE_PRIM(_VOID, fmod_set_pause_on_event_instance, _BYTES _BOOL)
DEFINE_PRIM(_VOID, fmod_stop_event_instance, _BYTES)
DEFINE_PRIM(_VOID, fmod_stop_event_instance_immediately, _BYTES)
DEFINE_PRIM(_VOID, fmod_release_event_instance, _BYTES)
DEFINE_PRIM(_BOOL, fmod_is_event_instance_playing, _BYTES)
DEFINE_PRIM(_I32, fmod_get_event_instance_playback_state, _BYTES)
DEFINE_PRIM(_F32, fmod_get_event_instance_param, _BYTES _BYTES)
DEFINE_PRIM(_VOID, fmod_set_event_instance_param, _BYTES _BYTES _F32)
DEFINE_PRIM(_VOID, fmod_set_callback_tracking_for_event_instance, _BYTES)
DEFINE_PRIM(_BOOL, fmod_check_callbacks_for_event_instance, _BYTES _I32)
#endif
