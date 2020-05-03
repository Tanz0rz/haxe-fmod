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
#pragma once

#define IMPLEMENT_API

#if (defined __MWERKS__)
	#include <SIOUX.h>
#endif

#include <fmod_studio.hpp>

namespace linc
{
	namespace faxe
	{
		//// FMOD System

		/**
		 * Initialization of FMOD sound system
		 * \param[numChannels] number of channels to allocate for this sound system
		 */
		extern void faxe_init(int numChannels = 32);

		/**
		 * Turns on print statements for any errors happening within the FMOD integration
		 * \param[onOff] turns debug messages on or off
		 */
		extern void faxe_set_debug(bool onOff);
		
		/**
		 * Update the FMOD command buffer, should be called once per "tick"
		 */
		extern void faxe_update();

		//// Sound Banks

		/**
		 * Load a FMOD sound bank file
		 * \param[bankName] ::String the file path of the sound bank to load
		 */
		extern void faxe_load_bank(const ::String& bankName);

		/**
		 * Unload a FMOD sound bank file
		 * \param[bankName] ::String the file path of the sound bank to unload
		 */
		extern void faxe_unload_bank(const ::String& bankName);
		
		//// Event Descriptions

		/**
		 * Load an event description from a loaded bank
		 * Event instances are spawned from event descriptions
		 * Event descriptions are loaded automatically when creating event instances
		 * \param[eventPath] ::String the path of the event
		 */
		extern void faxe_load_event_description(const ::String& eventPath);

		/**
		 * Check if an event description is currently loaded
		 * \param[eventDescriptionName] ::String the event description to check
		 */
		extern bool faxe_is_event_description_loaded(const ::String& eventDescriptionName);

		//// Event Instances

		/**
		 * Create and play an event instance in a fire-and-forget fashion
		 * There is no way to interact with these events once they are started
		 * Follows the Master Track rules set in the Event's settings in FMOD Studio (Max Instances, Stealing, and probably more)
		 * \param[eventName] ::String the name of the event to play
		 */
		extern void faxe_create_event_instance_one_shot(const ::String& eventName);

		/**
		 * Create and play an event instance and store a reference to it
		 * Events created with this method can receive other commands via this API (like passing in parameters)
		 * \param[eventName] ::String the event name
		 * \param[eventInstanceName] ::String the name to assign to the new event instance
		 */
		extern void faxe_create_event_instance_named(const ::String& eventName, const ::String& eventInstanceName);

		/**
		 * Check if an event instance is currently loaded
		 * \param[eventInstanceName] ::String the event instance to check
		 */
		extern bool faxe_is_event_instance_loaded(const ::String& eventInstanceName);

		/**
		 * Sends the "play" command to an existing event instance
		 * \param[eventInstanceName] ::String the name of the event instance
		 */
		extern void faxe_play_event_instance(const ::String& eventInstanceName);

		/**
		 * Sends the "pause" or "unpause" command to an existing event instance
		 * \param[eventInstanceName] ::String the name of the event instance
		 * \param[shouldBePaused] bool if the event instance should be paused
		 */
		extern void faxe_set_pause_on_event_instance(const ::String& eventInstanceName, bool shouldBePaused);

		/**
		 * Sends the "stop" command to an existing event instance
		 * \param[eventInstanceName] ::String the name of the event instance
		 * \param[forceStop] ::Bool should we force the event to stop immediately?
		 */
		extern void faxe_stop_event_instance(const ::String& eventInstanceName, bool forceStop = false);

		/**
		 * Release a loaded event instance from memory
		 * \param[eventInstanceName] ::String the name of the event instance
		 */
		extern void faxe_release_event_instance(const ::String& eventInstanceName);

		/**
		 * Check to see if an event instance is currently playing
		 * \param[eventInstanceName] ::String the name of the event instance
		 * \return ::Bool if the event is currently playing
		 */
		extern bool faxe_is_event_instance_playing(const ::String& eventInstanceName);

		/**
		 * Get the playback state of an existing event instance
		 * \param[eventInstanceName] ::String the name of the event instance
		 */
		extern FMOD_STUDIO_PLAYBACK_STATE faxe_get_event_instance_playback_state(const ::String& eventInstanceName);

		/**
		 * Check to see if an event is currently playing
		 * \param[eventInstanceName] ::String the name of the event to get param value from
		 * \param[paramName] ::String the name of the param to GET
		 * \return float the current value of the param from the specified event
		 */
		extern float faxe_get_event_instance_param(const ::String& eventInstanceName, const ::String& paramName);

		/**
		 * Set the parameter value of a loaded event
		 * \param[eventInstanceName] ::String the name of the event that contains the parameter to set
		 * \param[paramName] ::String the name of the param to SET
		 * \param[value] float the new value to set the param to
		 */
		extern void faxe_set_event_instance_param(const ::String& eventInstanceName, const ::String& paramName, float value);
	} // faxe + fmod namespace
} // linc namespace
